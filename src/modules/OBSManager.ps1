# OBS WebSocket Manager Module
# Handles all OBS-related operations including connection, authentication, and replay buffer control

class OBSManager {
    [System.Net.WebSockets.ClientWebSocket] $WebSocket
    [object] $Config
    [object] $Messages
    [string] $HostName
    [int] $Port
    [System.Security.SecureString] $Password

    # Constructor
    OBSManager([object] $obsConfig, [object] $messages) {
        $this.Config = $obsConfig
        $this.Messages = $messages
        $this.HostName = $obsConfig.websocket.host
        $this.Port = $obsConfig.websocket.port

        if ($obsConfig.websocket.password) {
            try {
                # Try to decrypt DPAPI-encrypted password (new format)
                $this.Password = ConvertTo-SecureString -String $obsConfig.websocket.password
                Write-Verbose "OBSManager: Loaded encrypted password from config"
            } catch {
                # Fall back to plain text conversion (old format for backward compatibility)
                Write-Verbose "OBSManager: Password is not encrypted, treating as plain text"
                $this.Password = $this.ConvertToSecureStringSafe($obsConfig.websocket.password)
                Write-Warning "Plain text password detected in config - consider using the GUI to re-save with encryption"
            }
        }
    }

    # Helper method for secure string conversion
    [System.Security.SecureString] ConvertToSecureStringSafe([string] $PlainText) {
        try {
            return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
        } catch {
            Write-Warning "ConvertTo-SecureString failed, attempting alternative method: $_"
            $secureString = New-Object System.Security.SecureString
            foreach ($char in $PlainText.ToCharArray()) {
                $secureString.AppendChar($char)
            }
            $secureString.MakeReadOnly()
            return $secureString
        }
    }

    # Receive WebSocket response with timeout
    [object] ReceiveWebSocketResponse([int] $TimeoutSeconds = 5) {
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter($TimeoutSeconds * 1000)
        $buffer = New-Object byte[] 8192
        $segment = New-Object ArraySegment[byte](, $buffer)
        $resultText = ""

        try {
            while ($this.WebSocket.State -eq "Open") {
                $receiveTask = $this.WebSocket.ReceiveAsync($segment, $cts.Token)
                $receiveTask.Wait()
                $result = $receiveTask.Result

                $resultText += [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)

                if ($result.EndOfMessage) {
                    break
                }
            }
            return $resultText | ConvertFrom-Json
        } catch {
            Write-Host ($this.Messages.error_receive_websocket -f $_)
            return $null
        }
    }

    # Connect to OBS WebSocket
    [bool] Connect() {
        try {
            $this.WebSocket = New-Object System.Net.WebSockets.ClientWebSocket
            $cts = New-Object System.Threading.CancellationTokenSource
            $cts.CancelAfter(5000)

            $uri = "ws://$($this.HostName):$($this.Port)"
            $this.WebSocket.ConnectAsync($uri, $cts.Token).Wait()

            if ($this.WebSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Host $this.Messages.failed_connect_obs
                return $false
            }

            Write-Host $this.Messages.connected_obs_websocket

            # Wait for Hello message (Op 0)
            $hello = $this.ReceiveWebSocketResponse(5)
            if (-not $hello -or $hello.op -ne 0) {
                Write-Host $this.Messages.error_receive_hello
                $this.Disconnect()
                return $false
            }

            # Send Identify message (Op 1)
            $identifyPayload = @{
                op = 1
                d = @{
                    rpcVersion = 1
                }
            }

            # Handle authentication if required
            if ($hello.d.authentication) {
                Write-Host $this.Messages.auth_required
                $authResponse = $this.HandleAuthentication($hello.d.authentication)
                if (-not $authResponse) {
                    $this.Disconnect()
                    return $false
                }
                $identifyPayload.d.authentication = $authResponse
            }

            # Send identify message
            $this.SendMessage($identifyPayload)

            # Wait for Identified message (Op 2)
            $identified = $this.ReceiveWebSocketResponse(5)
            if (-not $identified -or $identified.op -ne 2) {
                Write-Host $this.Messages.obs_auth_failed
                $this.Disconnect()
                return $false
            }

            Write-Host $this.Messages.obs_auth_successful
            return $true
        } catch {
            Write-Host ($this.Messages.obs_connection_error -f $_)
            return $false
        }
    }

    # Handle OBS authentication challenge
    [string] HandleAuthentication([object] $authData) {
        try {
            $salt = $authData.salt
            $challenge = $authData.challenge
            $sha256 = [System.Security.Cryptography.SHA256]::Create()

            # Convert SecureString to plain text for hashing
            $plainTextPassword = ''
            if ($this.Password -and $this.Password.Length -gt 0) {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.Password)
                $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }

            # Calculate secret = base64(sha256(password + salt))
            $secretBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plainTextPassword + $salt))
            $secret = [System.Convert]::ToBase64String($secretBytes)

            # Calculate authResponse = base64(sha256(secret + challenge))
            $authResponseBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($secret + $challenge))
            return [System.Convert]::ToBase64String($authResponseBytes)
        } catch {
            Write-Warning "Authentication calculation failed: $_"
            return $null
        }
    }

    # Send message to OBS WebSocket
    [void] SendMessage([object] $message) {
        $json = $message | ConvertTo-Json -Depth 5
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $sendSegment = New-Object ArraySegment[byte](, $buffer)
        $this.WebSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
    }

    # Start OBS Replay Buffer
    [bool] StartReplayBuffer() {
        try {
            $requestId = [System.Guid]::NewGuid().ToString()
            $command = @{
                op = 6
                d = @{
                    requestType = "StartReplayBuffer"
                    requestId = $requestId
                }
            }

            $this.SendMessage($command)
            Write-Host $this.Messages.obs_replay_buffer_started
            return $true
        } catch {
            Write-Host ($this.Messages.replay_buffer_start_error -f $_)
            return $false
        }
    }

    # Stop OBS Replay Buffer
    [bool] StopReplayBuffer() {
        try {
            $requestId = [System.Guid]::NewGuid().ToString()
            $command = @{
                op = 6
                d = @{
                    requestType = "StopReplayBuffer"
                    requestId = $requestId
                }
            }

            $this.SendMessage($command)
            Write-Host $this.Messages.obs_replay_buffer_stopped
            return $true
        } catch {
            Write-Host ($this.Messages.replay_buffer_stop_error -f $_)
            return $false
        }
    }

    # Disconnect from OBS WebSocket
    [void] Disconnect() {
        if ($this.WebSocket) {
            try {
                $this.WebSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Disconnecting", [System.Threading.CancellationToken]::None).Wait()
            } catch {
                # Ignore errors during disconnect
            } finally {
                $this.WebSocket.Dispose()
                $this.WebSocket = $null
            }
        }
    }

    # Check if OBS process is running
    [bool] IsOBSRunning() {
        return $null -ne (Get-Process -Name "obs64" -ErrorAction SilentlyContinue)
    }

    # Start OBS application
    [bool] StartOBS([string] $obsPath) {
        if ($this.IsOBSRunning()) {
            Write-Host $this.Messages.obs_already_running
            return $true
        }

        if (-not $obsPath -or -not (Test-Path $obsPath)) {
            Write-Host "OBS path not found or invalid: $obsPath"
            return $false
        }

        try {
            Start-Process -FilePath $obsPath
            Write-Host $this.Messages.starting_obs

            # Wait for OBS startup
            $retryCount = 0
            $maxRetries = 10
            while (-not $this.IsOBSRunning() -and ($retryCount -lt $maxRetries)) {
                Start-Sleep -Seconds 2
                $retryCount++
            }

            if ($this.IsOBSRunning()) {
                Write-Host $this.Messages.obs_startup_complete
                Start-Sleep -Seconds 5  # Wait for WebSocket server startup
                return $true
            } else {
                Write-Host $this.Messages.obs_startup_failed
                return $false
            }
        } catch {
            Write-Host "Failed to start OBS: $_"
            return $false
        }
    }
}

# Public function for OBS management
function New-OBSManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $OBSConfig,

        [Parameter(Mandatory = $true)]
        [object] $Messages
    )

    return [OBSManager]::new($OBSConfig, $Messages)
}

# Functions are available via dot-sourcing
