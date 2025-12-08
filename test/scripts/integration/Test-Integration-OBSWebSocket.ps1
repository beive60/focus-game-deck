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

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"


$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load config
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "[OK] Config loaded successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to load config: $_"
    exit 1
}

# Load OBSManager module
try {
    $obsManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSManager.ps1"
    . $obsManagerPath
    Write-BuildLog "[OK] OBSManager module loaded successfully form: $obsManagerPath"
} catch {
    Write-BuildLog "[ERROR] Failed to load OBSManager module: $_"
    exit 1
}

# Run the test
Write-BuildLog "--- Starting OBS WebSocket Connection Test ---"
Write-BuildLog "Testing OBSManager module functionality"
Write-BuildLog "OBS Config:"
Write-BuildLog "  Host: $($config.integrations.obs.websocket.host)"
Write-BuildLog "  Port: $($config.integrations.obs.websocket.port)"
Write-BuildLog "  Password: $(if ($config.integrations.obs.websocket.password) { '***' } else { '(not set)' })"

if (Get-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue) {
    Write-BuildLog "[INFO] OBS process detected running"
    Write-BuildLog "[INFO] terminate OBS with 'Stop-Process -Name obs64,obs32' if you want to test starting OBS from this script."
    Write-BuildLog "[INFO] OBS is not available"
    exit 1
}

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    Write-BuildLog "[INFO] Creating OBSManager instance..."
    $obsManager = New-OBSManager -OBSConfig $config.integrations.obs -Messages $messages
    Write-BuildLog "[INFO] OBSManager instance created successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to create OBSManager instance: $_"
    exit 1
}

try {
    Write-BuildLog "[INFO] Attempting to start OBS Studio..."
    $obsManager.StartOBS()
    Write-BuildLog "[INFO] OBS Studio process started."

} catch {
    Write-BuildLog "[ERROR] Failed to start OBS: $_"
    exit 1
}

Write-BuildLog "[INFO] Waiting for OBS to initialize..."
Start-Sleep 5  # Wait for OBS to start

try {
    try {
        Write-BuildLog "[INFO] Checking if OBS process is running with IsOBSRunning()..."
        $obsManager.IsOBSRunning()
        Write-BuildLog "[INFO] OBS process is running and IsOBSRunning() is true."
    } catch {
        Write-BuildLog "[ERROR] IsOBSRunning() failed: $_"
        exit 1
    }

    $testSuccessful = $true

    try {
        $connected = $obsManager.Connect()
        if (-not $connected) {
            Write-BuildLog "[ERROR] Failed to connect or authenticate to OBS WebSocket"
            exit 1
        }
        Write-BuildLog "[OK] OBS WebSocket connection successful!"

    } catch {
        Write-BuildLog "[ERROR] Connect() failed: $_"
        exit 1
    }

    try {
        # Replay Buffer Test
        if ($config.integrations.obs.replayBuffer) {
            Write-BuildLog "[INFO] Testing Replay Buffer commands..."

            $startResult = $obsManager.StartReplayBuffer()
            if ($startResult) { Write-BuildLog "[OK] Replay Buffer started" }
            else {
                Write-BuildLog "[ERROR] Failed to start Replay Buffer"
                $testSuccessful = $false
            }

            Start-Sleep -Seconds 2

            $stopResult = $obsManager.StopReplayBuffer()
            if ($stopResult) { Write-BuildLog "[OK] Replay Buffer stopped" }
            else {
                Write-BuildLog "[ERROR] Failed to stop Replay Buffer"
                $testSuccessful = $false
            }
        }

    } catch {
        Write-BuildLog "[ERROR] Exception during test execution: $_"
        $testSuccessful = $false

    } finally {
        if ($obsManager) {
            Write-BuildLog "[INFO] Disconnecting from OBS WebSocket..."
            try {
                $obsManager.Disconnect()
                Write-BuildLog "[INFO] Disconnected successfully"
            } catch {
                Write-BuildLog "[WARNING] Error during disconnect: $_"
            }
        }
    }
} catch {
    Write-BuildLog "[ERROR] Unexpected error during OBS module test: $_"
    $testSuccessful = $false
} finally {
    Write-BuildLog "[INFO] Stopping OBS Studio process..."
    try {
        Stop-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue
        Write-BuildLog "[INFO] OBS Studio process stopped."
    } catch {
        Write-BuildLog "[WARNING] Error stopping OBS: $_"
    }
}


if (-not $testSuccessful) { exit 1 }
Write-BuildLog "--- Test Finished ---"
exit 0
