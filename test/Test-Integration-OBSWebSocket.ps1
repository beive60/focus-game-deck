# =============================================================================
# Test-OBSConnection.ps1
#
# This script is a standalone test for the OBS WebSocket connection and
# authentication logic from the FocusGameDeck project.
#
# It reads the OBS WebSocket configuration from config.json, attempts to
# connect and authenticate, and reports the result.
#
# Usage:
# 1. Ensure OBS is running.
# 2. Ensure the OBS WebSocket server is enabled (Tools -> WebSocket Server Settings).
# 3. Run this script from the project's root directory:
#    .\Test-OBSConnection.ps1
# =============================================================================

# --- Start of Functions from Invoke-FocusGameDeck.ps1 ---

# WebSocket helper functions
function Receive-OBSWebSocketResponse {
    param (
        [System.Net.WebSockets.ClientWebSocket]$WebSocket,
        [int]$TimeoutSeconds = 5
    )
    $cts = New-Object System.Threading.CancellationTokenSource
    $cts.CancelAfter($TimeoutSeconds * 1000)
    $buffer = New-Object byte[] 8192 # 8KB buffer
    $segment = New-Object ArraySegment[byte](, $buffer)
    $resultText = ""

    try {
        while ($WebSocket.State -eq "Open") {
            $receiveTask = $WebSocket.ReceiveAsync($segment, $cts.Token)
            $receiveTask.Wait()
            $result = $receiveTask.Result

            $resultText += [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)

            if ($result.EndOfMessage) {
                break
            }
        }
        return $resultText | ConvertFrom-Json
    } catch {
        Write-Host "Error receiving from OBS WebSocket or timeout: $_"
        return $null
    }
}

# OBS WebSocket related functions
function Connect-OBSWebSocket {
    param (
        [string]$HostName = "localhost",
        [int]$Port = 4455,
        [System.Security.SecureString]$Password
    )

    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter(5000) # 5 second timeout

        $uri = "ws://${HostName}:${Port}"
        $ws.ConnectAsync($uri, $cts.Token).Wait()

        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            Write-Host "Failed to connect to OBS WebSocket"
            return $null
        }

        Write-Host "Connected to OBS WebSocket. Starting handshake..."

        # Wait for Hello message (Op 0) from server
        $hello = Receive-OBSWebSocketResponse -WebSocket $ws
        if (-not $hello -or $hello.op -ne 0) {
            Write-Host "Error: Could not receive valid Hello message from server."
            $ws.Dispose()
            return $null
        }

        # Send Identify message (Op 1)
        $identifyPayload = @{
            op = 1
            d  = @{
                rpcVersion = 1
            }
        }

        # If authentication is required
        if ($hello.d.authentication) {
            Write-Host "Authentication required. Generating authentication information..."
            $salt = $hello.d.authentication.salt
            $challenge = $hello.d.authentication.challenge

            $sha256 = [System.Security.Cryptography.SHA256]::Create()

            # Convert SecureString to plain text for hashing
            $plainTextPassword = ''
            if ($Password -and $Password.Length -gt 0) {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }

            # secret = base64(sha256(password + salt))
            $secretBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plainTextPassword + $salt))
            $secret = [System.Convert]::ToBase64String($secretBytes)

            # authResponse = base64(sha256(secret + challenge))
            $authResponseBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($secret + $challenge))
            $authResponse = [System.Convert]::ToBase64String($authResponseBytes)

            $identifyPayload.d.authentication = $authResponse
        }

        $identifyJson = $identifyPayload | ConvertTo-Json -Depth 5
        $identifyBuffer = [System.Text.Encoding]::UTF8.GetBytes($identifyJson)
        $sendSegment = New-Object ArraySegment[byte](, $identifyBuffer)
        $ws.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()

        # Wait for Identified message (Op 2) from server
        $identified = Receive-OBSWebSocketResponse -WebSocket $ws
        if (-not $identified -or $identified.op -ne 2) {
            Write-Host "Error: WebSocket authentication failed."
            $ws.Dispose()
            return $null
        }

        Write-Host "OBS WebSocket authentication successful."
        return $ws
    } catch {
        Write-Host "OBS WebSocket connection/authentication error: $_"
        return $null
    }
}

# --- End of Functions ---


# --- Main Test Logic ---

# Load configuration file
$projectRoot = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $projectRoot "config/config.json"

if (-not (Test-Path $configPath)) {
    Write-Host "Error: config.json not found at $configPath"
    Write-Host "Please ensure config.json exists in the config/ directory."
    exit 1
}
$config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Check for OBS configuration
if (-not $config.obs.websocket) {
    Write-Host "Error: 'obs.websocket' configuration is missing in config.json"
    exit 1
}

# Run the test
Write-Host "--- Starting OBS WebSocket Connection Test ---"
$obsConfig = $config.obs.websocket

$securePassword = ConvertTo-SecureString -String ($obsConfig.password -as [string]) -AsPlainText -Force

$ws = Connect-OBSWebSocket -HostName $obsConfig.host -Port $obsConfig.port -Password $securePassword

if ($ws) {
    Write-Host "`nTest Result: SUCCESS"
    $ws.Dispose()
} else {
    Write-Host "`nTest Result: FAILED"
}

Write-Host "--- Test Finished ---"
