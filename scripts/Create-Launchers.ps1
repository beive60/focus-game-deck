# This script reads the config.json file and automatically generates
# a .bat launcher for each game defined in it.

# Check if running from GUI (parameter to suppress pause)
param(
    [switch]$NoInteractive
)

# Get the directory where the script is located
$scriptDir = $PSScriptRoot
$rootDir = Split-Path $scriptDir -Parent
$configPath = Join-Path $rootDir "config\config.json"
$coreScriptPath = Join-Path $rootDir "src\Invoke-FocusGameDeck.ps1"

# Check if config.json exists
if (-not (Test-Path $configPath)) {
    Write-Host "Error: config\config.json not found."
    Write-Host "Please copy config\config.json.sample to config\config.json and configure it."
    if (-not $NoInteractive) {
        pause
    }
    exit 1
}

# --- Optional: Clean up old launchers ---
# Remove all existing launch_*.bat files to avoid leaving old ones.
Get-ChildItem -Path $rootDir -Filter "launch_*.bat" | ForEach-Object {
    Write-Host "Removing old launcher: $($_.Name)"
    Remove-Item $_.FullName
}

# Load the configuration file
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Get all game entries
# Use PSObject.Properties to reliably get all keys
$games = $config.games.PSObject.Properties

Write-Host "Found $($games.Count) games. Generating launchers..."

# Loop through each game and create a launcher
foreach ($game in $games) {
    $gameId = $game.Name
    $gameDisplayName = $game.Value.name
    $launcherPath = Join-Path $rootDir "launch_$($gameId).bat"

    # Content of the batch file
    $batchContent = @"
@echo off
echo Launching: $gameDisplayName
powershell -NoProfile -ExecutionPolicy Bypass -File "$coreScriptPath" -GameId $gameId
pause
"@

    # Create the .bat file
    Set-Content -Path $launcherPath -Value $batchContent -Encoding Oem
    Write-Host "Successfully created: $($launcherPath)"
}

Write-Host "`nAll launchers have been generated!"
Write-Host "You can now double-click the 'launch_GAMEID.bat' files to start your games."
if (-not $NoInteractive) {
    pause
}
