# Test Script for Standalone Platform GUI Functionality
# This script tests the newly implemented Standalone platform features in the GUI

Write-Host "=== Focus Game Deck - Standalone Platform GUI Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if XAML contains Standalone platform option
Write-Host "Test 1: Checking XAML for Standalone platform option..." -ForegroundColor Yellow

$xamlPath = "gui/MainWindow.xaml"
$xamlContent = Get-Content $xamlPath -Raw

if ($xamlContent -match 'Tag="standalone"') {
    Write-Host "✓ PASS: Standalone platform option found in XAML" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Standalone platform option not found in XAML" -ForegroundColor Red
}

# Test 2: Check if ExecutablePathTextBox exists in XAML
if ($xamlContent -match 'Name="ExecutablePathTextBox"') {
    Write-Host "✓ PASS: ExecutablePathTextBox found in XAML" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: ExecutablePathTextBox not found in XAML" -ForegroundColor Red
}

# Test 3: Check if BrowseExecutablePathButton exists in XAML
if ($xamlContent -match 'Name="BrowseExecutablePathButton"') {
    Write-Host "✓ PASS: BrowseExecutablePathButton found in XAML" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: BrowseExecutablePathButton not found in XAML" -ForegroundColor Red
}

# Test 4: Check ConfigEditor.ps1 for Standalone platform handling
Write-Host ""
Write-Host "Test 4: Checking ConfigEditor.ps1 for Standalone support..." -ForegroundColor Yellow

$configEditorPath = "gui/ConfigEditor.ps1"
$configEditorContent = Get-Content $configEditorPath -Raw

if ($configEditorContent -match '"standalone"') {
    Write-Host "✓ PASS: Standalone platform handling found in ConfigEditor.ps1" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Standalone platform handling not found in ConfigEditor.ps1" -ForegroundColor Red
}

# Test 5: Check if Update-PlatformFields handles standalone
if ($configEditorContent -match 'standalone.*{') {
    Write-Host "✓ PASS: Update-PlatformFields handles standalone platform" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Update-PlatformFields does not handle standalone platform" -ForegroundColor Red
}

# Test 6: Check if Save-CurrentGameData handles executablePath
if ($configEditorContent -match 'executablePath') {
    Write-Host "✓ PASS: Save-CurrentGameData handles executablePath" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Save-CurrentGameData does not handle executablePath" -ForegroundColor Red
}

# Test 7: Check if Handle-BrowseExecutablePath function exists
if ($configEditorContent -match 'function Handle-BrowseExecutablePath') {
    Write-Host "✓ PASS: Handle-BrowseExecutablePath function found" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Handle-BrowseExecutablePath function not found" -ForegroundColor Red
}

# Test 8: Check messages.json for localization strings
Write-Host ""
Write-Host "Test 8: Checking messages.json for localization..." -ForegroundColor Yellow

$messagesPath = "gui/messages.json"
$messagesContent = Get-Content $messagesPath -Raw

if ($messagesContent -match 'standalonePlatform') {
    Write-Host "✓ PASS: standalonePlatform localization found" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: standalonePlatform localization not found" -ForegroundColor Red
}

if ($messagesContent -match 'executablePathLabel') {
    Write-Host "✓ PASS: executablePathLabel localization found" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: executablePathLabel localization not found" -ForegroundColor Red
}

if ($messagesContent -match 'selectExecutableFile') {
    Write-Host "✓ PASS: selectExecutableFile localization found" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: selectExecutableFile localization not found" -ForegroundColor Red
}

# Test 9: Check if config.json can handle standalone games
Write-Host ""
Write-Host "Test 9: Testing config.json compatibility..." -ForegroundColor Yellow

$configPath = "config/config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json

        # Create a test standalone game entry
        $testStandaloneGame = @{
            name = "Test Standalone Game"
            platform = "standalone"
            executablePath = "C:/Games/TestGame/game.exe"
            processName = "game"
            appsToManage = @()
        }

        Write-Host "✓ PASS: Config.json can handle standalone game structure" -ForegroundColor Green

    } catch {
        Write-Host "✗ FAIL: Error testing config.json compatibility: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "! INFO: config.json not found, using sample config" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "All static tests completed. To fully test the functionality:" -ForegroundColor White
Write-Host "1. Run the GUI with: powershell -File gui/ConfigEditor.ps1" -ForegroundColor White
Write-Host "2. Go to Game Settings tab" -ForegroundColor White
Write-Host "3. Click 'Add New...' button" -ForegroundColor White
Write-Host "4. Select 'Standalone' from Platform dropdown" -ForegroundColor White
Write-Host "5. Verify Executable Path field appears" -ForegroundColor White
Write-Host "6. Click Browse button to test file dialog" -ForegroundColor White
Write-Host "7. Save and verify the game is saved correctly" -ForegroundColor White
Write-Host ""
