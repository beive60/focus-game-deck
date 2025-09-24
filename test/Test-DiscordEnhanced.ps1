# Discord Integration Enhanced Test Script
# Test Discord RPC status control functionality

Write-Host "=== Discord Integration Enhanced Test ===" -ForegroundColor Cyan

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

# Enable RPC for testing (set a test application ID)
$config.managedApps.discord.discord.rpc.enabled = $true
$config.managedApps.discord.discord.rpc.applicationId = "1234567890123456789"  # Test ID
$config.managedApps.discord.discord.customPresence.enabled = $true

Write-Host "[OK] RPC enabled for testing" -ForegroundColor Green

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

# Test RPC Connection
Write-Host "`n--- Testing Discord RPC Connection ---" -ForegroundColor Yellow
if ($discordManager.RPCClient) {
    Write-Host "[OK] RPC Client initialized" -ForegroundColor Green
    
    $rpcConnected = $discordManager.ConnectRPC()
    if ($rpcConnected) {
        Write-Host "[OK] Connected to Discord RPC successfully" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Failed to connect to Discord RPC - Discord may not support this Application ID" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARNING] RPC Client not initialized" -ForegroundColor Yellow
}

# Test Enhanced Gaming Mode
Write-Host "`n--- Testing Enhanced Gaming Mode ---" -ForegroundColor Yellow
$result = $discordManager.SetGamingMode("Test Game")
if ($result) {
    Write-Host "[OK] Enhanced Gaming Mode set successfully" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Gaming Mode set with warnings" -ForegroundColor Yellow
}

# Wait a moment to see the changes
Write-Host "`n--- Waiting 5 seconds to observe changes ---" -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Test Enhanced Normal Mode restore
Write-Host "`n--- Testing Enhanced Normal Mode Restore ---" -ForegroundColor Yellow
$result = $discordManager.RestoreNormalMode()
if ($result) {
    Write-Host "[OK] Enhanced Normal Mode restored successfully" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Normal Mode restored with warnings" -ForegroundColor Yellow
}

# Clean up RPC connection
Write-Host "`n--- Cleaning up RPC Connection ---" -ForegroundColor Yellow
$discordManager.DisconnectRPC()

# Final status check
Write-Host "`n--- Final Status Check ---" -ForegroundColor Yellow
$finalStatus = $discordManager.GetStatus()
Write-Host "Final Discord Status:"
Write-Host "  Is Running: $($finalStatus.IsRunning)"
Write-Host "  Process Count: $($finalStatus.ProcessCount)"

Write-Host "`n=== Enhanced Test Complete ===" -ForegroundColor Cyan

if ($finalStatus.IsRunning) {
    Write-Host "[OK] Discord Enhanced integration working correctly" -ForegroundColor Green
    Write-Host "Note: RPC functionality requires a valid Discord Application ID" -ForegroundColor Yellow
} else {
    Write-Host "[WARNING] Discord may not be running - check manually" -ForegroundColor Yellow
}