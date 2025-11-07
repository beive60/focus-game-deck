# Simple Config Test Check
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

Write-Host "OBS Host: '$($config.obs.websocket.host)'"
Write-Host "OBS Port: $($config.obs.websocket.port)"
Write-Host "Language: '$($config.language)'"

# Check for test changes
Write-Host "`nTest Results:"
if ($config.obs.websocket.host -eq "testhost") {
    Write-Host "[OK] OBS Host changed to testhost"
} elseif ($config.obs.websocket.host -eq "localhost") {
    Write-Host "- OBS Host unchanged (localhost)"
} else {
    Write-Host "? OBS Host set to: $($config.obs.websocket.host)"
}

if ($config.obs.websocket.port -eq 4456) {
    Write-Host "[OK] OBS Port changed to 4456"
} elseif ($config.obs.websocket.port -eq 4455) {
    Write-Host "- OBS Port unchanged (4455)"
} else {
    Write-Host "? OBS Port set to: $($config.obs.websocket.port)"
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
