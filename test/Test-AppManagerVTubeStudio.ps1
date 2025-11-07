# AppManager VTube Studio Integration Test Script
# Tests VTube Studio startup/shutdown through AppManager

Write-Host "=== AppManager VTube Studio Integration Test ==="

# Load required modules
. "$PSScriptRoot/../src/modules/AppManager.ps1"
. "$PSScriptRoot/../src/modules/VTubeStudioManager.ps1"

# Load configuration
$config = Get-Content "$PSScriptRoot/../config/config.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# Create AppManager instance
$appManager = New-AppManager -Config $config -Messages @{}

Write-Host "Testing AppManager VTube Studio integration..."

# Test startup via AppManager
Write-Host "`nStarting VTube Studio via AppManager..."
$startResult = $appManager.InvokeAction('vtubeStudio', 'start-vtube-studio')
Write-Host "Start result: $startResult"

if ($startResult) {
    Write-Host "[OK] VTube Studio started successfully via AppManager"

    # Wait a few seconds
    Write-Host "Waiting 3 seconds..."
    Start-Sleep -Seconds 3

    # Test shutdown via AppManager
    Write-Host "`nStopping VTube Studio via AppManager..."
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

Write-Host "`n=== AppManager Integration Test Complete ==="
