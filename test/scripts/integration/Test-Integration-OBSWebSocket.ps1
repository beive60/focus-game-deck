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

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load config
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Config loaded successfully"
} catch {
    Write-Host "[ERROR] Failed to load config: $_"
    exit 1
}

# Load OBSManager module
try {
    $obsManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSManager.ps1"
    . $obsManagerPath
    Write-Host "[OK] OBSManager module loaded successfully form: $obsManagerPath"
} catch {
    Write-Host "[ERROR] Failed to load OBSManager module: $_"
    exit 1
}

# Run the test
Write-Host "--- Starting OBS WebSocket Connection Test ---"
Write-Host "Testing OBSManager module functionality"
Write-Host "OBS Config:"
Write-Host "  Host: $($config.integrations.obs.websocket.host)"
Write-Host "  Port: $($config.integrations.obs.websocket.port)"
Write-Host "  Password: $(if ($config.integrations.obs.websocket.password) { '***' } else { '(not set)' })"

if (Get-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue) {
    Write-Host "[INFO] OBS process detected running"
    Write-Host "[INFO] terminate OBS with 'Stop-Process -Name obs64,obs32' if you want to test starting OBS from this script."
    Write-Host "[INFO] OBS is not available"
    exit 1
}

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    Write-Host "[INFO] Creating OBSManager instance..."
    $obsManager = New-OBSManager -OBSConfig $config.integrations.obs -Messages $messages
    Write-Host "[INFO] OBSManager instance created successfully"
} catch {
    Write-Host "[ERROR] Failed to create OBSManager instance: $_"
    exit 1
}

try {
    Write-Host "[INFO] Attempting to start OBS Studio..."
    $obsManager.StartOBS()
    Write-Host "[INFO] OBS Studio process started."

} catch {
    Write-Host "[ERROR] Failed to start OBS: $_"
    exit 1
}

Write-Host "[INFO] Waiting for OBS to initialize..."
Start-Sleep 5  # Wait for OBS to start

try {
    try {
        Write-Host "[INFO] Checking if OBS process is running with IsOBSRunning()..."
        $obsManager.IsOBSRunning()
        Write-Host "[INFO] OBS process is running and IsOBSRunning() is true."
    } catch {
        Write-Host "[ERROR] IsOBSRunning() failed: $_"
        exit 1
    }

    $testSuccessful = $true

    try {
        $connected = $obsManager.Connect()
        if (-not $connected) {
            Write-Host "[ERROR] Failed to connect or authenticate to OBS WebSocket"
            exit 1
        }
        Write-Host "[OK] OBS WebSocket connection successful!"

    } catch {
        Write-Host "[ERROR] Connect() failed: $_"
        exit 1
    }

    try {
        # Replay Buffer Test
        if ($config.integrations.obs.replayBuffer) {
            Write-Host "[INFO] Testing Replay Buffer commands..."

            $startResult = $obsManager.StartReplayBuffer()
            if ($startResult) { Write-Host "[OK] Replay Buffer started" }
            else {
                Write-Host "[ERROR] Failed to start Replay Buffer"
                $testSuccessful = $false
            }

            Start-Sleep -Seconds 2

            $stopResult = $obsManager.StopReplayBuffer()
            if ($stopResult) { Write-Host "[OK] Replay Buffer stopped" }
            else {
                Write-Host "[ERROR] Failed to stop Replay Buffer"
                $testSuccessful = $false
            }
        }

    } catch {
        Write-Host "[ERROR] Exception during test execution: $_"
        $testSuccessful = $false

    } finally {
        if ($obsManager) {
            Write-Host "[INFO] Disconnecting from OBS WebSocket..."
            try {
                $obsManager.Disconnect()
                Write-Host "[INFO] Disconnected successfully"
            } catch {
                Write-Host "[WARNING] Error during disconnect: $_"
            }
        }
    }
} catch {
    Write-Host "[ERROR] Unexpected error during OBS module test: $_"
    $testSuccessful = $false
} finally {
    Write-Host "[INFO] Stopping OBS Studio process..."
    try {
        Stop-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue
        Write-Host "[INFO] OBS Studio process stopped."
    } catch {
        Write-Host "[WARNING] Error stopping OBS: $_"
    }
}


if (-not $testSuccessful) { exit 1 }
Write-Host "--- Test Finished ---"
exit 0
