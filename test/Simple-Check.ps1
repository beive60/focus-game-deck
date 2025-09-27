# Simple Config Test Check
Write-Host "Config Editor Test Results" -ForegroundColor Cyan

# Check file modification time
$configFile = Get-Item config\config.json
Write-Host "`nFile Info:" -ForegroundColor Yellow
Write-Host "Last Modified: $($configFile.LastWriteTime)"
Write-Host "Size: $($configFile.Length) bytes"

# Check time difference
$timeDiff = (Get-Date) - $configFile.LastWriteTime
Write-Host "Time since last change: $([math]::Round($timeDiff.TotalMinutes, 1)) minutes ago"

if ($timeDiff.TotalMinutes -lt 10) {
    Write-Host "✓ File was recently updated" -ForegroundColor Green
} else {
    Write-Host "File may not have been updated" -ForegroundColor Yellow
}

# Load and check config
Write-Host "`nConfig Values:" -ForegroundColor Yellow
$config = Get-Content config\config.json -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "OBS Host: '$($config.obs.websocket.host)'"
Write-Host "OBS Port: $($config.obs.websocket.port)"
Write-Host "Language: '$($config.language)'"

# Check for test changes
Write-Host "`nTest Results:" -ForegroundColor Yellow
if ($config.obs.websocket.host -eq "testhost") {
    Write-Host "✓ OBS Host changed to testhost" -ForegroundColor Green
} elseif ($config.obs.websocket.host -eq "localhost") {
    Write-Host "- OBS Host unchanged (localhost)" -ForegroundColor White
} else {
    Write-Host "? OBS Host set to: $($config.obs.websocket.host)" -ForegroundColor Cyan
}

if ($config.obs.websocket.port -eq 4456) {
    Write-Host "✓ OBS Port changed to 4456" -ForegroundColor Green
} elseif ($config.obs.websocket.port -eq 4455) {
    Write-Host "- OBS Port unchanged (4455)" -ForegroundColor White
} else {
    Write-Host "? OBS Port set to: $($config.obs.websocket.port)" -ForegroundColor Cyan
}

if ($config.language -eq "ja") {
    Write-Host "✓ Language changed to Japanese" -ForegroundColor Green
} elseif ($config.language -eq "") {
    Write-Host "- Language unchanged (auto)" -ForegroundColor White
} else {
    Write-Host "? Language set to: '$($config.language)'" -ForegroundColor Cyan
}

# Check games
$gameCount = ($config.games.PSObject.Properties | Measure-Object).Count
Write-Host "`nGames: $gameCount total" -ForegroundColor Yellow

# Look for test games
$testGames = $config.games.PSObject.Properties | Where-Object { $_.Value.name -like "*Test*" }
if ($testGames) {
    Write-Host "✓ Test game(s) found:" -ForegroundColor Green
    foreach ($game in $testGames) {
        Write-Host "  - $($game.Value.name) (ID: $($game.Name))" -ForegroundColor White
    }
} else {
    Write-Host "- No test games found" -ForegroundColor White
}

Write-Host "`nTo restore original config:" -ForegroundColor Magenta
Write-Host "Copy-Item config\config.json.backup-* config\config.json" -ForegroundColor Gray
