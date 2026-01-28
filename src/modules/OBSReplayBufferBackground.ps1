# OBS Replay Buffer Background Worker Script
# This script is executed in a background job to start OBS replay buffer asynchronously
# to avoid blocking the main game launch sequence

param(
    [Parameter(Mandatory = $true)]
    [object] $OBSConfig,

    [Parameter(Mandatory = $true)]
    [object] $Messages,

    [Parameter(Mandatory = $false)]
    [string] $LogFilePath,

    [Parameter(Mandatory = $false)]
    [int] $WaitBeforeConnect = 3000
)

# Import required modules
$scriptRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path -Path $scriptRoot -ChildPath "scripts/LanguageHelper.ps1")
. (Join-Path -Path $scriptRoot -ChildPath "src/modules/WebSocketAppManagerBase.ps1")
. (Join-Path -Path $scriptRoot -ChildPath "src/modules/OBSManager.ps1")

# Helper function to log to file if path provided
function Write-BackgroundLog {
    param(
        [string] $Message,
        [string] $Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [OBSBackground] $Message"

    if ($LogFilePath) {
        try {
            Add-Content -Path $LogFilePath -Value $logMessage -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }

    Write-Host $logMessage
}

try {
    Write-BackgroundLog "OBS Replay Buffer background worker started"

    # Create OBS Manager
    $obsManager = New-OBSManager -OBSConfig $OBSConfig -Messages $Messages

    if (-not $obsManager) {
        Write-BackgroundLog "Failed to create OBS Manager" "ERROR"
        return $false
    }

    # Wait before attempting connection to allow OBS to fully start
    if ($WaitBeforeConnect -gt 0) {
        Write-BackgroundLog "Waiting $($WaitBeforeConnect)ms before connecting to OBS WebSocket"
        Start-Sleep -Milliseconds $WaitBeforeConnect
    }

    # Connect to OBS WebSocket
    Write-BackgroundLog "Attempting to connect to OBS WebSocket"
    $connected = $obsManager.Connect()

    if (-not $connected) {
        Write-BackgroundLog "Failed to connect to OBS WebSocket" "WARNING"
        return $false
    }

    Write-BackgroundLog "Successfully connected to OBS WebSocket"

    # Start Replay Buffer
    Write-BackgroundLog "Starting OBS Replay Buffer"
    $success = $obsManager.StartReplayBuffer()

    if ($success) {
        Write-BackgroundLog "OBS Replay Buffer started successfully" "OK"
    } else {
        Write-BackgroundLog "Failed to start OBS Replay Buffer" "WARNING"
    }

    # Disconnect
    $obsManager.Disconnect()
    Write-BackgroundLog "Disconnected from OBS WebSocket"

    return $success

} catch {
    Write-BackgroundLog "Exception in background worker: $_" "ERROR"
    return $false
} finally {
    Write-BackgroundLog "OBS Replay Buffer background worker completed"
}
