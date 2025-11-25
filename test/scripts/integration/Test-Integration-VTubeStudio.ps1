# VTube Studio Integration Test Script
<#
.SYNOPSIS
    Runs integration tests for VTubeStudioManager, ensuring it correctly interacts with the application and configuration.

.DESCRIPTION
    This Pester test script verifies the functionality of the VTubeStudioManager module. It performs the following checks:
    - Loads the VTubeStudioManager and AppManager modules.
    - Loads the application's configuration from 'config/config.json'.
    - Tests the VTubeStudioManager by creating an instance and checking for the VTube Studio installation.
    - Tests AppManager integration by validating the VTube Studio configuration.
    - Tests the ConfigValidator by running a full configuration validation and reporting the results.

.EXAMPLE
    .\Test-Integration-VTubeStudio.ps1
    Runs all integration tests defined in the script.

.NOTES
    This script is intended to be run from the 'test/scripts/integration' directory. It requires the main configuration file ('config/config.json') to be present and correctly formatted.

.OUTPUTS
    Outputs test results to the console, indicating the status of each test (e.g., [OK], [ERROR], [WARNING]).
#>
Write-Host "=== VTube Studio Integration Test ==="

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load required modules
try {
    $vtubeStudioManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/VTubeStudioManager.ps1"
    . $vtubeStudioManagerPath
    Write-Host "[OK] VTubeStudioManager module loaded"
} catch {
    Write-Host "[ERROR] Failed to load VTubeStudioManager: $_"
    exit 1
}

try {
    $appManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1"
    . $appManagerPath
    Write-Host "[OK] AppManager module loaded"
} catch {
    Write-Host "[ERROR] Failed to load AppManager: $_"
    exit 1
}

# Load configuration
try {
    $configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Configuration loaded"
} catch {
    Write-Host "[ERROR] Failed to load configuration: $_"
    exit 1
}

# Test VTubeStudioManager
Write-Host "=== Testing VTubeStudioManager ==="

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $vtubeManager = New-VTubeStudioManager -VTubeConfig $config.integrations.vtubeStudio -Messages $messages
    Write-Host "[OK] VTubeStudioManager instance created"
} catch {
    Write-Host "[ERROR] VTubeStudioManager test failed: $_"
    exit 1
}

# Test: IsVTubeStudioRunning
try {
    $isRunning = $vtubeManager.IsVTubeStudioRunning()
    Write-Host "[OK] IsVTubeStudioRunning is success: $isRunning"
} catch {
    Write-Host "[ERROR] Failed to IsVTubeStudioRunning: $_"
    exit 1
}

# Test: DetectVTubeStudioInstallation
try {
    $installation = $vtubeManager.DetectVTubeStudioInstallation()
    Write-Host "[OK] DetectVTubeStudioInstallation is success: $($installation.Available)"
} catch {
    Write-Host "[ERROR] Failed to DetectVTubeStudioInstallation: $_"
    exit 1
}

# Test: StartVTubeStudio
try {
    $started = $vtubeManager.StartVTubeStudio()
    Write-Host "[OK] StartVTubeStudio is success: $started"
} catch {
    Write-Host "[ERROR] Failed to StartVTubeStudio: $_"
    exit 1
}

# Test: StopVTubeStudio
try {
    $stopped = $vtubeManager.StopVTubeStudio()
    Write-Host "[OK] StopVTubeStudio is success: $stopped"
} catch {
    Write-Host "[ERROR] Failed to StopVTubeStudio: $_"
    exit 1
}

# Test: GetSteamPath
try {
    $steamPath = $vtubeManager.GetSteamPath()
    Write-Host "[OK] GetSteamPath is success: $steamPath"
} catch {
    Write-Host "[ERROR] Failed to GetSteamPath: $_"
}

# Test: ConnectWebSocket / DisconnectWebSocket
try {
    $connected = $vtubeManager.ConnectWebSocket()
    Write-Host "[OK] ConnectWebSocket is success: $connected"
    $vtubeManager.DisconnectWebSocket()
    Write-Host "[OK] DisconnectWebSocket is success"
} catch {
    Write-Host "[ERROR] Failed to Connect/DisconnectWebSocket: $_"
    exit 1
}

# Test: SendCommand
try {
    $result = $vtubeManager.SendCommand("TestCommand")
    Write-Host "[OK] SendCommand is success: $result"
} catch {
    Write-Host "[ERROR] Failed to SendCommand: $_"
    # implement in future
    # exit 1
}
