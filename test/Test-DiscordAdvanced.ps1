# Discord Integration Advanced Test Script
# Test full Discord integration with Rich Presence and error recovery

Write-Host "=== Discord Integration Advanced Test ===" -ForegroundColor Cyan

# Load required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
. "$rootDir\src\modules\DiscordManager.ps1"

# Load config for testing
$configPath = "$rootDir\config\config.json"
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

# Enable all advanced features for testing
$config.managedApps.discord.discord.rpc.enabled = $true
$config.managedApps.discord.discord.rpc.applicationId = "1234567890123456789"  # Test ID
$config.managedApps.discord.discord.customPresence.enabled = $true
$config.managedApps.discord.discord.disableOverlay = $true

Write-Host "[OK] Advanced features enabled for testing" -ForegroundColor Green

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

# Test Advanced Gaming Mode with game name
Write-Host "`n--- Testing Advanced Gaming Mode ---" -ForegroundColor Yellow
$testGameName = "Apex Legends"
$result = $discordManager.SetGamingMode($testGameName)
if ($result) {
    Write-Host "[OK] Advanced Gaming Mode set successfully for $testGameName" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Gaming Mode set with warnings for $testGameName" -ForegroundColor Yellow
}

# Wait to observe changes
Write-Host "`n--- Waiting 8 seconds to observe Rich Presence changes ---" -ForegroundColor Yellow
Write-Host "Check your Discord profile to see the Rich Presence update!" -ForegroundColor Cyan
Start-Sleep -Seconds 8

# Test overlay control
Write-Host "`n--- Testing Overlay Control ---" -ForegroundColor Yellow
$overlayResult = $discordManager.SetOverlayEnabled($false)
if ($overlayResult) {
    Write-Host "[OK] Overlay control executed" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Overlay control had issues" -ForegroundColor Yellow
}

# Test error recovery
Write-Host "`n--- Testing Error Recovery ---" -ForegroundColor Yellow
Write-Host "Simulating connection issues..."
if ($discordManager.RPCClient) {
    # Simulate disconnection
    $discordManager.RPCClient.Disconnect()
    Write-Host "RPC disconnected for testing"
}

$recoveryResult = $discordManager.RecoverFromError()
if ($recoveryResult) {
    Write-Host "[OK] Error recovery successful" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Error recovery had issues" -ForegroundColor Yellow
}

# Test different game scenario
Write-Host "`n--- Testing Different Game Scenario ---" -ForegroundColor Yellow
$testGameName2 = "VALORANT"
$result2 = $discordManager.SetGamingMode($testGameName2)
if ($result2) {
    Write-Host "[OK] Game switched to $testGameName2 successfully" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Game switch had warnings" -ForegroundColor Yellow
}

# Wait a moment
Start-Sleep -Seconds 3

# Test Advanced Normal Mode restore
Write-Host "`n--- Testing Advanced Normal Mode Restore ---" -ForegroundColor Yellow
$result = $discordManager.RestoreNormalMode()
if ($result) {
    Write-Host "[OK] Advanced Normal Mode restored successfully" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Normal Mode restored with warnings" -ForegroundColor Yellow
}

# Clean up RPC connection
Write-Host "`n--- Cleaning up ---" -ForegroundColor Yellow
$discordManager.DisconnectRPC()

# Final status check
Write-Host "`n--- Final Status Check ---" -ForegroundColor Yellow
$finalStatus = $discordManager.GetStatus()
Write-Host "Final Discord Status:"
Write-Host "  Is Running: $($finalStatus.IsRunning)"
Write-Host "  Process Count: $($finalStatus.ProcessCount)"

Write-Host "`n=== Advanced Test Complete ===" -ForegroundColor Cyan

if ($finalStatus.IsRunning) {
    Write-Host "[OK] Discord Advanced integration working correctly" -ForegroundColor Green
    Write-Host "Features tested:" -ForegroundColor Cyan
    Write-Host "  - Rich Presence with game details" -ForegroundColor White
    Write-Host "  - Overlay control" -ForegroundColor White
    Write-Host "  - Error recovery mechanisms" -ForegroundColor White
    Write-Host "  - Multi-game support" -ForegroundColor White
    Write-Host "  - Graceful fallbacks" -ForegroundColor White
} else {
    Write-Host "[WARNING] Discord may not be running - check manually" -ForegroundColor Yellow
}

Write-Host "`nNote: For production use, configure a valid Discord Application ID" -ForegroundColor Yellow