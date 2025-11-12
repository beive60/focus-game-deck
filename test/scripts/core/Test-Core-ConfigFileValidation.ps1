<#
.SYNOPSIS
    Simple configuration file validation and change detection test.

.DESCRIPTION
    This test script provides a quick verification of the configuration file (config.json) state.
    It checks file modification timestamps, file size, and validates key configuration values
    to ensure the Config Editor or other tools are properly updating the configuration.

    The test performs the following checks:
    - File metadata (modification time, size)
    - Time since last modification (recent update detection)
    - OBS WebSocket configuration (host, port)
    - Language settings
    - Game entries (total count, test game detection)

    Test Categories:
    1. File Info - Checks modification time and file size
    2. Config Values - Validates OBS host, port, and language settings
    3. Test Results - Compares current values against expected test values
    4. Games - Counts total games and identifies test game entries

.EXAMPLE
    .\Test-ConfigSimple.ps1
    Runs basic configuration file checks and displays current values.

.EXAMPLE
    .\Test-ConfigSimple.ps1 | Tee-Object -FilePath test-results.log
    Runs checks and saves output to a log file.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0

    Purpose:
    - Quick validation of config.json integrity
    - Detection of recent configuration changes
    - Verification of Config Editor functionality

    Dependencies:
    - config/config.json (main configuration file)

    Expected Values for Test Mode:
    - OBS Host: "testhost" (test) or "localhost" (default)
    - OBS Port: 4456 (test) or 4455 (default)
    - Language: "ja" (test) or "" (auto/default)

    Recovery:
    If configuration needs to be restored, use:
    Copy-Item config/config.json.backup-* config/config.json
#>

Write-Host "Config Editor Test Results"

# Check file modification time
$configFile = Get-Item config/config.json
Write-Host "`nFile Info:"
Write-Host "Last Modified: $($configFile.LastWriteTime)"
Write-Host "Size: $($configFile.Length) bytes"

# Check time difference
$timeDiff = (Get-Date) - $configFile.LastWriteTime
Write-Host "Time since last change: $([math]::Round($timeDiff.TotalMinutes, 1)) minutes ago"

if ($timeDiff.TotalMinutes -lt 10) {
    Write-Host "[OK] File was recently updated"
} else {
    Write-Host "File may not have been updated"
}

# Load and check config
Write-Host "`nConfig Values:"
$config = Get-Content config/config.json -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "OBS Host: '$($config.integrations.obs.websocket.host)'"
Write-Host "OBS Port: $($config.integrations.obs.websocket.port)"
Write-Host "Language: '$($config.language)'"

# Check for test changes
Write-Host "`nTest Results:"
if ($config.integrations.obs.websocket.host -eq "testhost") {
    Write-Host "[OK] OBS Host changed to testhost"
} elseif ($config.integrations.obs.websocket.host -eq "localhost") {
    Write-Host "- OBS Host unchanged (localhost)"
} else {
    Write-Host "? OBS Host set to: $($config.integrations.obs.websocket.host)"
}

if ($config.integrations.obs.websocket.port -eq 4456) {
    Write-Host "[OK] OBS Port changed to 4456"
} elseif ($config.integrations.obs.websocket.port -eq 4455) {
    Write-Host "- OBS Port unchanged (4455)"
} else {
    Write-Host "? OBS Port set to: $($config.integrations.obs.websocket.port)"
}

if ($config.language -eq "ja") {
    Write-Host "[OK] Language changed to Japanese"
} elseif ($config.language -eq "") {
    Write-Host "- Language unchanged (auto)"
} else {
    Write-Host "? Language set to: '$($config.language)'"
}

# Check games
$gameCount = ($config.games.PSObject.Properties | Measure-Object).Count
Write-Host "`nGames: $gameCount total"

# Look for test games
$testGames = $config.games.PSObject.Properties | Where-Object { $_.Value.name -like "*Test*" }
if ($testGames) {
    Write-Host "[OK] Test game(s) found:"
    foreach ($game in $testGames) {
        Write-Host "  - $($game.Value.name) (ID: $($game.Name))"
    }
} else {
    Write-Host "- No test games found"
}

Write-Host "`nTo restore original config:"
Write-Host "Copy-Item config/config.json.backup-* config/config.json"
