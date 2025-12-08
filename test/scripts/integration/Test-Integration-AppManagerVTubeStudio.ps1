# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

# AppManager VTube Studio Integration Test Script
# Tests VTube Studio startup/shutdown through AppManager

Write-BuildLog "=== AppManager VTube Studio Integration Test ==="

# Load required modules
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$appManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1"
$vtubeStudioManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/VTubeStudioManager.ps1"
. $appManagerPath
. $vtubeStudioManagerPath

# Load configuration
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Create AppManager instance
$appManager = New-AppManager -Config $config -Messages @{}

Write-BuildLog "Testing AppManager VTube Studio integration..."

# Test startup via AppManager
Write-BuildLog "Starting VTube Studio via AppManager..."
$startResult = $appManager.InvokeAction('vtubeStudio', 'start-vtube-studio')
Write-BuildLog "Start result: $startResult"

if ($startResult) {
    Write-BuildLog "[OK] VTube Studio started successfully via AppManager"

    # Wait a few seconds
    Write-BuildLog "Waiting 3 seconds..."
    Start-Sleep -Seconds 3

    # Test shutdown via AppManager
    Write-BuildLog "Stopping VTube Studio via AppManager..."
    $stopResult = $appManager.InvokeAction('vtubeStudio', 'stop-vtube-studio')
    Write-BuildLog "Stop result: $stopResult"

    if ($stopResult) {
        Write-BuildLog "[OK] VTube Studio stopped successfully via AppManager"
    } else {
        Write-BuildLog "[ERROR] VTube Studio shutdown failed via AppManager"
    }
} else {
    Write-BuildLog "[ERROR] VTube Studio startup failed via AppManager"
}

Write-BuildLog "=== AppManager Integration Test Complete ==="
