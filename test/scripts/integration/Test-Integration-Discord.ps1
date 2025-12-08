# Discord Integration MVP Test Script
# Test basic Discord process control functionality

Write-BuildLog "=== Discord Integration MVP Test ==="

# Load required modules
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$discordManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/DiscordManager.ps1"
. $discordManagerPath

# Load config
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "[OK] Config loaded successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to load config: $_"
    exit 1
}

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $discordManager = New-DiscordManager -DiscordConfig $config.integrations.discord -Messages $messages
    Write-BuildLog "[OK] DiscordManager created successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to create DiscordManager: $_"
    exit 1
}

# Test Discord detection
Write-BuildLog "--- Testing Discord Detection ---"
$status = $discordManager.GetStatus()
Write-BuildLog "Discord Path: $($status.Path)"
Write-BuildLog "Is Running: $($status.IsRunning)"
Write-BuildLog "Process Count: $($status.ProcessCount)"

try {
    $discordManager.StartDiscord()
    Write-BuildLog "[OK] Discord started successfully"
} catch {
    Write-BuildLog "[WARNING] Discord cannot be started: $_"
}

# Test Gaming Mode (MVP)
try {
    $discordManager.SetGamingMode("Test Game")
    Write-BuildLog "[OK] Gaming Mode set successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to set Gaming Mode: $_"
}

# Wait a moment
Start-Sleep -Seconds 2

# Test Normal Mode restore
try {
    $discordManager.RestoreNormalMode()
    Write-BuildLog "[OK] Normal Mode restored successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to restore Normal Mode: $_"
}

# Final status check
try {
    $finalStatus = $discordManager.GetStatus()
} catch {
    Write-BuildLog "[ERROR] Failed to get final Discord status: $_"
    exit 1
}
Write-BuildLog "Final Discord Status:"
Write-BuildLog "  Is Running: $($finalStatus.IsRunning)"
Write-BuildLog "  Process Count: $($finalStatus.ProcessCount)"

if ($finalStatus.IsRunning) {
    Write-BuildLog "[OK] Discord MVP integration working correctly"
} else {
    Write-BuildLog "[WARNING] Discord may not be running - check manually"
}

try {
    $discordManager.DisconnectRPC()
    Write-BuildLog "[OK] DiscordManager Disconnected RPC successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to dispose DiscordManager: $_"
}

try {
    $discordManager.StopDiscord()
    Write-BuildLog "[OK] Discord stopped successfully"
} catch {
    Write-BuildLog "[WARNING] Discord cannot be stopped: $_"
}
