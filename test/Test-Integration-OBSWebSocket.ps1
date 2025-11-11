<#
.SYNOPSIS
    OBSManager module integration test script.

.DESCRIPTION
    This script tests the OBSManager module's WebSocket connection and
    authentication logic from the FocusGameDeck project.

    It loads the actual OBSManager.ps1 module and verifies:
    - Connection to OBS WebSocket server
    - DPAPI encrypted password decryption
    - WebSocket authentication flow
    - Replay Buffer control (optional, if enabled in config)

    This test validates the actual implementation of OBSManager.ps1,
    not a standalone test implementation.

.PARAMETER None
    This script does not accept parameters. Configuration is read from config/config.json.

.EXAMPLE
    .\test\Test-Integration-OBSWebSocket.ps1

    Runs the OBS WebSocket integration test using the configuration from config.json.

.NOTES
    File Name      : Test-Integration-OBSWebSocket.ps1
    Prerequisite   : OBS Studio must be running with WebSocket server enabled
    Required Files :
        - config/config.json (OBS configuration)
        - localization/messages.json (Localized messages)
        - src/modules/OBSManager.ps1 (OBSManager module)

    Before running:
    1. Ensure OBS Studio is running
    2. Enable WebSocket server in OBS (Tools -> WebSocket Server Settings)
    3. Verify config.json contains correct host, port, and password
    4. If password was recently changed, re-save via GUI to ensure DPAPI encryption

.LINK
    https://github.com/beive60/focus-game-deck

.OUTPUTS
    Exit Code 0: Test successful
    Exit Code 1: Test failed
#>

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
if (-not $config.integrations.obs) {
    Write-Host "Error: 'integrations.obs' configuration is missing in config.json"
    exit 1
}

# Load localization messages (required by OBSManager)
$messagesPath = Join-Path $projectRoot "localization/messages.json"
if (-not (Test-Path $messagesPath)) {
    Write-Host "Error: messages.json not found at $messagesPath"
    exit 1
}

$messagesData = Get-Content -Path $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Determine language (default to 'ja' for this test, or use config setting)
$language = if ($config.language) { $config.language } else { "ja" }
$messages = $messagesData.$language

if (-not $messages) {
    Write-Host "Warning: Language '$language' not found in messages.json, falling back to 'ja'"
    $messages = $messagesData.ja
}

# Load OBSManager module
$obsManagerPath = Join-Path $projectRoot "src/modules/OBSManager.ps1"
if (-not (Test-Path $obsManagerPath)) {
    Write-Host "Error: OBSManager.ps1 not found at $obsManagerPath"
    exit 1
}

Write-Host "Loading OBSManager module from: $obsManagerPath"
. $obsManagerPath

# Run the test
Write-Host "`n--- Starting OBS WebSocket Connection Test ---"
Write-Host "Testing OBSManager module functionality"
Write-Host "OBS Config:"
Write-Host "  Host: $($config.integrations.obs.websocket.host)"
Write-Host "  Port: $($config.integrations.obs.websocket.port)"
Write-Host "  Password: $(if ($config.integrations.obs.websocket.password) { '***' } else { '(not set)' })"
Write-Host ""

try {
    # Create OBSManager instance
    Write-Host "Creating OBSManager instance..."
    $obsManager = New-OBSManager -OBSConfig $config.integrations.obs -Messages $messages

    if (-not $obsManager) {
        Write-Host "Error: Failed to create OBSManager instance"
        exit 1
    }

    Write-Host "OBSManager instance created successfully"
    Write-Host ""

    # Test connection
    Write-Host "Attempting to connect to OBS WebSocket..."
    $connected = $obsManager.Connect()

    if ($connected) {
        Write-Host "`n✓ Test Result: SUCCESS" -ForegroundColor Green
        Write-Host "OBS WebSocket connection and authentication successful!"

        # Optional: Test replay buffer commands if enabled
        if ($config.integrations.obs.replayBuffer) {
            Write-Host "`nTesting Replay Buffer commands..."

            Write-Host "  Starting Replay Buffer..."
            $startResult = $obsManager.StartReplayBuffer()
            if ($startResult) {
                Write-Host "  ✓ Replay Buffer started successfully" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Failed to start Replay Buffer" -ForegroundColor Yellow
            }

            Start-Sleep -Seconds 2

            Write-Host "  Stopping Replay Buffer..."
            $stopResult = $obsManager.StopReplayBuffer()
            if ($stopResult) {
                Write-Host "  ✓ Replay Buffer stopped successfully" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Failed to stop Replay Buffer" -ForegroundColor Yellow
            }
        }

        # Disconnect
        Write-Host "`nDisconnecting from OBS WebSocket..."
        $obsManager.Disconnect()
        Write-Host "Disconnected successfully"

    } else {
        Write-Host "`n✗ Test Result: FAILED" -ForegroundColor Red
        Write-Host "Failed to connect or authenticate to OBS WebSocket"
        Write-Host ""
        Write-Host "Troubleshooting steps:"
        Write-Host "1. Ensure OBS is running"
        Write-Host "2. Verify WebSocket server is enabled in OBS (Tools -> WebSocket Server Settings)"
        Write-Host "3. Check that host/port/password in config.json match OBS settings"
        Write-Host "4. If password was recently changed, re-save it via the GUI to ensure proper encryption"
        exit 1
    }

} catch {
    Write-Host "`n✗ Test Result: FAILED" -ForegroundColor Red
    Write-Host "Exception occurred during test: $_"
    Write-Host $_.Exception.Message
    Write-Host $_.ScriptStackTrace
    exit 1
}

Write-Host "`n--- Test Finished ---"
exit 0


# OBSOLETE CODE BELOW - Kept for reference only
# =============================================================================
# The following functions were previously used for standalone testing.
# They are no longer used as we now import OBSManager.ps1 directly.
# =============================================================================

<#
function Receive-OBSWebSocketResponse {
    param (
        [System.Net.WebSockets.ClientWebSocket]$WebSocket,
        [int]$TimeoutSeconds = 5
    )
    # ... implementation omitted ...
}

function Connect-OBSWebSocket {
    param (
        [string]$HostName = "localhost",
        [int]$Port = 4455,
        [System.Security.SecureString]$Password
    )
    # ... implementation omitted ...
}
#>
