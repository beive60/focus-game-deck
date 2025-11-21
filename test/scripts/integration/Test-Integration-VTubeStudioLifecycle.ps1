# VTube Studio Startup/Shutdown Test Script
# Tests actual VTube Studio startup and shutdown functionality

Write-Host "=== VTube Studio Startup/Shutdown Test ==="

# Load required modules
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$vtubeStudioManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/VTubeStudioManager.ps1"
. $vtubeStudioManagerPath

# Load configuration
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Create VTubeStudioManager instance
$vtubeManager = New-VTubeStudioManager -VTubeConfig $config.managedApps.vtubeStudio -Messages @{}

# Test startup
Write-Host "Testing VTube Studio startup..."
$startResult = $vtubeManager.StartVTubeStudio()
Write-Host "Start result: $startResult"

if ($startResult) {
    Write-Host "[OK] VTube Studio started successfully"

    # Wait a few seconds to ensure it's fully started
    Write-Host "Waiting 5 seconds for full startup..."
    Start-Sleep -Seconds 5

    # Check if it's running
    $isRunning = $vtubeManager.IsVTubeStudioRunning()
    Write-Host "Is VTube Studio running: $isRunning"

    # Test shutdown
    Write-Host "Testing VTube Studio shutdown..."
    $stopResult = $vtubeManager.StopVTubeStudio()
    Write-Host "Stop result: $stopResult"

    if ($stopResult) {
        Write-Host "[OK] VTube Studio stopped successfully"
    } else {
        Write-Host "[ERROR] VTube Studio shutdown failed"
    }

    # Final check
    Start-Sleep -Seconds 2
    $isRunningAfterStop = $vtubeManager.IsVTubeStudioRunning()
    Write-Host "Is VTube Studio running after stop: $isRunningAfterStop"

} else {
    Write-Host "[ERROR] VTube Studio startup failed"
}

Write-Host "=== Test Complete ==="
