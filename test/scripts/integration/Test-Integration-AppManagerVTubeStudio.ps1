# AppManager VTube Studio Integration Test Script
# Tests VTube Studio startup/shutdown through AppManager

Write-Host "=== AppManager VTube Studio Integration Test ==="

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

Write-Host "Testing AppManager VTube Studio integration..."

# Test startup via AppManager
Write-Host "Starting VTube Studio via AppManager..."
$startResult = $appManager.InvokeAction('vtubeStudio', 'start-vtube-studio')
Write-Host "Start result: $startResult"

if ($startResult) {
    Write-Host "[OK] VTube Studio started successfully via AppManager"

    # Wait a few seconds
    Write-Host "Waiting 3 seconds..."
    Start-Sleep -Seconds 3

    # Test shutdown via AppManager
    Write-Host "Stopping VTube Studio via AppManager..."
    $stopResult = $appManager.InvokeAction('vtubeStudio', 'stop-vtube-studio')
    Write-Host "Stop result: $stopResult"

    if ($stopResult) {
        Write-Host "[OK] VTube Studio stopped successfully via AppManager"
    } else {
        Write-Host "[ERROR] VTube Studio shutdown failed via AppManager"
    }
} else {
    Write-Host "[ERROR] VTube Studio startup failed via AppManager"
}

Write-Host "=== AppManager Integration Test Complete ==="
