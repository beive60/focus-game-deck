# Config Editor Manual Test Guide

## Current Configuration Values (Before Testing)

- OBS Host: localhost
- OBS Port: 4455
- Language Setting: (empty)

## Test Procedures

### 1. GUI Launch Verification

[OK] Config Editor launches normally
[OK] Display of 4 tabs (Game Launcher, Game Settings, Management App Settings, Global Settings)
[OK] UI displays correctly in system language

### 2. Global Settings Tab Test

Make the following changes:

- Change OBS Host from "localhost" to "testhost"
- Change OBS Port from "4455" to "4456"
- Change Language Setting from "Auto (System Language)" to "Japanese (ja)"

### 3. Game Settings Tab Test

- Verify existing games (apex, dbd) display correctly
- Click "Add New Game" button
- Enter new game details:
  - Game Name: "Test Game"
  - Steam App ID: "999999"
  - Process Name: "testgame.exe"

### 4. Game Launcher Tab Test

- Verify game cards display for configured games
- Test game launch functionality (if Steam is available)
- Verify status indicators and launch buttons work correctly

### 5. Standalone Platform Test

- Verify "Standalone" platform option appears in Platform dropdown
- Test executable path field visibility when standalone is selected
- Click "Browse" button to test file dialog functionality
- Enter standalone game details:
  - Game Name: "Test Standalone Game"
  - Platform: "Standalone"
  - Executable Path: Browse to select an .exe file
  - Process Name: "testgame"
- Save and verify the standalone game is saved correctly in config.json

### 6. Management App Settings Tab Test

- Verify existing apps (noWinKey, autoHotkey, clibor, luna) display correctly
- Select any app and verify details display

### 7. Save Functionality Test

- Click "Save Settings" button
- Verify save completion message displays in selected language

### 8. Application Exit

- Click "Close" button to exit application

## Post-Test Verification

After saving this file, run the following PowerShell commands to verify config.json changes:

```powershell
# Check configuration file modification time
Get-Item config/config.json | Select-Object Name, Length, LastWriteTime

# Check changed configuration values
$config = Get-Content config/config.json -Raw | ConvertFrom-Json
Write-Host "Updated OBS Host: $($config.obs.websocket.host)"
Write-Host "Updated OBS Port: $($config.obs.websocket.port)"
Write-Host "Updated Language Setting: '$($config.language)'"

# Check newly added game
if ($config.games.PSObject.Properties | Where-Object { $_.Value.name -eq "Test Game" }) {
    Write-Host "[OK] Test game added successfully" -ForegroundColor Green
} else {
    Write-Host " Test game not found" -ForegroundColor Red
}
```

## Expected Results

- config.json file last modified time is close to current time
- OBS Host changed to "testhost"
- OBS Port changed to "4456"
- Language setting changed to "ja"
- New test game added to games section
- All localized messages display correctly
- Game launcher tab functions properly with configured games

This test verifies that the Config Editor's basic editing and saving functionality, character encoding support, and integrated game launcher work correctly.
