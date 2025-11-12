# Discord Integration MVP Test Script
# Test basic Discord process control functionality

Write-Host "=== Discord Integration MVP Test ==="

# Load required modules
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$discordManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/DiscordManager.ps1"
. $discordManagerPath

# Load config for testing
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Config file not found: $configPath"
    exit 1
}

try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Config loaded successfully"
} catch {
    Write-Host "[ERROR] Failed to load config: $_"
    exit 1
}

# Test Discord configuration
if (-not $config.managedApps.discord) {
    Write-Host "[ERROR] Discord configuration not found in config"
    exit 1
}

Write-Host "[OK] Discord configuration found"

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $discordManager = New-DiscordManager -DiscordConfig $config.managedApps.discord -Messages $messages
    Write-Host "[OK] DiscordManager created successfully"
} catch {
    Write-Host "[ERROR] Failed to create DiscordManager: $_"
    exit 1
}

# Test Discord detection
Write-Host "`n--- Testing Discord Detection ---"
$status = $discordManager.GetStatus()
Write-Host "Discord Path: $($status.Path)"
Write-Host "Is Running: $($status.IsRunning)"
Write-Host "Process Count: $($status.ProcessCount)"

# Test Gaming Mode (MVP)
Write-Host "`n--- Testing Gaming Mode (MVP) ---"
$result = $discordManager.SetGamingMode("Test Game")
if ($result) {
    Write-Host "[OK] Gaming Mode set successfully"
} else {
    Write-Host "[ERROR] Failed to set Gaming Mode"
}

# Wait a moment
Start-Sleep -Seconds 2

# Test Normal Mode restore
Write-Host "`n--- Testing Normal Mode Restore ---"
$result = $discordManager.RestoreNormalMode()
if ($result) {
    Write-Host "[OK] Normal Mode restored successfully"
} else {
    Write-Host "[ERROR] Failed to restore Normal Mode"
}

# Final status check
Write-Host "`n--- Final Status Check ---"
$finalStatus = $discordManager.GetStatus()
Write-Host "Final Discord Status:"
Write-Host "  Is Running: $($finalStatus.IsRunning)"
Write-Host "  Process Count: $($finalStatus.ProcessCount)"

Write-Host "`n=== MVP Test Complete ==="

if ($finalStatus.IsRunning) {
    Write-Host "[OK] Discord MVP integration working correctly"
} else {
    Write-Host "[WARNING] Discord may not be running - check manually"
}
