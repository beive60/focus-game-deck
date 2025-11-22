# Discord Integration MVP Test Script
# Test basic Discord process control functionality

Write-Host "=== Discord Integration MVP Test ==="

# Load required modules
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
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

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $discordManager = New-DiscordManager -DiscordConfig $config.integrations.discord -Messages $messages
    Write-Host "[OK] DiscordManager created successfully"
} catch {
    Write-Host "[ERROR] Failed to create DiscordManager: $_"
    exit 1
}

# Test Discord detection
Write-Host "--- Testing Discord Detection ---"
$status = $discordManager.GetStatus()
Write-Host "Discord Path: $($status.Path)"
Write-Host "Is Running: $($status.IsRunning)"
Write-Host "Process Count: $($status.ProcessCount)"

try {
    $discordManager.StartDiscord()
    Write-Host "[OK] Discord started successfully"
} catch {
    Write-Host "[WARNING] Discord cannot be started: $_"
}

# Test Gaming Mode (MVP)
try {
    $discordManager.SetGamingMode("Test Game")
    Write-Host "[OK] Gaming Mode set successfully"
} catch {
    Write-Host "[ERROR] Failed to set Gaming Mode: $_"
}

# Wait a moment
Start-Sleep -Seconds 2

# Test Normal Mode restore
try {
    $discordManager.RestoreNormalMode()
    Write-Host "[OK] Normal Mode restored successfully"
} catch {
    Write-Host "[ERROR] Failed to restore Normal Mode: $_"
}

# Final status check
try {
    $finalStatus = $discordManager.GetStatus()
} catch {
    Write-Host "[ERROR] Failed to get final Discord status: $_"
    exit 1
}
Write-Host "Final Discord Status:"
Write-Host "  Is Running: $($finalStatus.IsRunning)"
Write-Host "  Process Count: $($finalStatus.ProcessCount)"

if ($finalStatus.IsRunning) {
    Write-Host "[OK] Discord MVP integration working correctly"
} else {
    Write-Host "[WARNING] Discord may not be running - check manually"
}

try {
    $discordManager.DisconnectRPC()
    Write-Host "[OK] DiscordManager Disconnected RPC successfully"
} catch {
    Write-Host "[ERROR] Failed to dispose DiscordManager: $_"
}

try {
    $discordManager.StopDiscord()
    Write-Host "[OK] Discord stopped successfully"
} catch {
    Write-Host "[WARNING] Discord cannot be stopped: $_"
}
