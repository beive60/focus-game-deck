# VTube Studio Startup/Shutdown Test Script
# Tests actual VTube Studio startup and shutdown functionality

Write-Host "=== VTube Studio Startup/Shutdown Test ===" -ForegroundColor Cyan

# Load required modules
. "$PSScriptRoot/../src/modules/VTubeStudioManager.ps1"

# Load configuration
$config = Get-Content "$PSScriptRoot/../config/config.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# Create VTubeStudioManager instance
$vtubeManager = New-VTubeStudioManager -VTubeConfig $config.managedApps.vtubeStudio -Messages @{}

# Test startup
Write-Host "`nTesting VTube Studio startup..." -ForegroundColor Yellow
$startResult = $vtubeManager.StartVTubeStudio()
Write-Host "Start result: $startResult" -ForegroundColor White

if ($startResult) {
    Write-Host "[OK] VTube Studio started successfully" -ForegroundColor Green

    # Wait a few seconds to ensure it's fully started
    Write-Host "Waiting 5 seconds for full startup..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5

    # Check if it's running
    $isRunning = $vtubeManager.IsVTubeStudioRunning()
    Write-Host "Is VTube Studio running: $isRunning" -ForegroundColor White

    # Test shutdown
    Write-Host "`nTesting VTube Studio shutdown..." -ForegroundColor Yellow
    $stopResult = $vtubeManager.StopVTubeStudio()
    Write-Host "Stop result: $stopResult" -ForegroundColor White

    if ($stopResult) {
        Write-Host "[OK] VTube Studio stopped successfully" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] VTube Studio shutdown failed" -ForegroundColor Red
    }

    # Final check
    Start-Sleep -Seconds 2
    $isRunningAfterStop = $vtubeManager.IsVTubeStudioRunning()
    Write-Host "Is VTube Studio running after stop: $isRunningAfterStop" -ForegroundColor White

} else {
    Write-Host "[ERROR] VTube Studio startup failed" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
