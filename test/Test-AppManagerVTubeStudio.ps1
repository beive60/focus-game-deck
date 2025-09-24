# AppManager VTube Studio Integration Test Script
# Tests VTube Studio startup/shutdown through AppManager

Write-Host "=== AppManager VTube Studio Integration Test ===" -ForegroundColor Cyan

# Load required modules
. "$PSScriptRoot\..\src\modules\AppManager.ps1"
. "$PSScriptRoot\..\src\modules\VTubeStudioManager.ps1"

# Load configuration
$config = Get-Content "$PSScriptRoot\..\config\config.json" | ConvertFrom-Json

# Create AppManager instance
$appManager = New-AppManager -Config $config -Messages @{}

Write-Host "Testing AppManager VTube Studio integration..." -ForegroundColor Yellow

# Test startup via AppManager
Write-Host "`nStarting VTube Studio via AppManager..." -ForegroundColor Cyan
$startResult = $appManager.InvokeAction('vtubeStudio', 'start-vtube-studio')
Write-Host "Start result: $startResult" -ForegroundColor White

if ($startResult) {
    Write-Host "[OK] VTube Studio started successfully via AppManager" -ForegroundColor Green
    
    # Wait a few seconds
    Write-Host "Waiting 3 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3
    
    # Test shutdown via AppManager
    Write-Host "`nStopping VTube Studio via AppManager..." -ForegroundColor Cyan
    $stopResult = $appManager.InvokeAction('vtubeStudio', 'stop-vtube-studio')
    Write-Host "Stop result: $stopResult" -ForegroundColor White
    
    if ($stopResult) {
        Write-Host "[OK] VTube Studio stopped successfully via AppManager" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] VTube Studio shutdown failed via AppManager" -ForegroundColor Red
    }
} else {
    Write-Host "[ERROR] VTube Studio startup failed via AppManager" -ForegroundColor Red
}

Write-Host "`n=== AppManager Integration Test Complete ===" -ForegroundColor Cyan