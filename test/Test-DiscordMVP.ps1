# Discord Integration MVP Test Script
# Test basic Discord process control functionality

Write-Host "=== Discord Integration MVP Test ===" -ForegroundColor Cyan

# Load required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
. "$rootDir/src/modules/DiscordManager.ps1"

# Load config for testing
$configPath = "$rootDir/config/config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Config loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load config: $_" -ForegroundColor Red
    exit 1
}

# Test Discord configuration
if (-not $config.managedApps.discord) {
    Write-Host "[ERROR] Discord configuration not found in config" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Discord configuration found" -ForegroundColor Green

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $discordManager = New-DiscordManager -DiscordConfig $config.managedApps.discord -Messages $messages
    Write-Host "[OK] DiscordManager created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create DiscordManager: $_" -ForegroundColor Red
    exit 1
}

# Test Discord detection
Write-Host "`n--- Testing Discord Detection ---" -ForegroundColor Yellow
$status = $discordManager.GetStatus()
Write-Host "Discord Path: $($status.Path)"
Write-Host "Is Running: $($status.IsRunning)"
Write-Host "Process Count: $($status.ProcessCount)"

# Test Gaming Mode (MVP)
Write-Host "`n--- Testing Gaming Mode (MVP) ---" -ForegroundColor Yellow
$result = $discordManager.SetGamingMode("Test Game")
if ($result) {
    Write-Host "[OK] Gaming Mode set successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to set Gaming Mode" -ForegroundColor Red
}

# Wait a moment
Start-Sleep -Seconds 2

# Test Normal Mode restore
Write-Host "`n--- Testing Normal Mode Restore ---" -ForegroundColor Yellow
$result = $discordManager.RestoreNormalMode()
if ($result) {
    Write-Host "[OK] Normal Mode restored successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to restore Normal Mode" -ForegroundColor Red
}

# Final status check
Write-Host "`n--- Final Status Check ---" -ForegroundColor Yellow
$finalStatus = $discordManager.GetStatus()
Write-Host "Final Discord Status:"
Write-Host "  Is Running: $($finalStatus.IsRunning)"
Write-Host "  Process Count: $($finalStatus.ProcessCount)"

Write-Host "`n=== MVP Test Complete ===" -ForegroundColor Cyan

if ($finalStatus.IsRunning) {
    Write-Host "[OK] Discord MVP integration working correctly" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Discord may not be running - check manually" -ForegroundColor Yellow
}
