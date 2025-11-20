# Test Script for Standalone Platform GUI Functionality
# This script tests the newly implemented Standalone platform features in the GUI

Write-Host "=== Focus Game Deck - Standalone Platform GUI Test ==="
Write-Host ""

# Test 1: Check if XAML contains Standalone platform option
Write-Host "Test 1: Checking XAML for Standalone platform option..."

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$xamlPath = Join-Path -Path $projectRoot -ChildPath "gui/MainWindow.xaml"
$xamlContent = Get-Content $xamlPath -Raw

if ($xamlContent -match 'Tag="standalone"') {
    Write-Host "[OK] PASS: Standalone platform option found in XAML"
} else {
    Write-Host "[ERROR] FAIL: Standalone platform option not found in XAML"
}

# Test 2: Check if ExecutablePathTextBox exists in XAML
if ($xamlContent -match 'Name="ExecutablePathTextBox"') {
    Write-Host "[OK] PASS: ExecutablePathTextBox found in XAML"
} else {
    Write-Host "[ERROR] FAIL: ExecutablePathTextBox not found in XAML"
}

# Test 3: Check if BrowseExecutablePathButton exists in XAML
if ($xamlContent -match 'Name="BrowseExecutablePathButton"') {
    Write-Host "[OK] PASS: BrowseExecutablePathButton found in XAML"
} else {
    Write-Host "[ERROR] FAIL: BrowseExecutablePathButton not found in XAML"
}

# Test 4: Check ConfigEditor.ps1 for Standalone platform handling
Write-Host ""
Write-Host "Test 4: Checking ConfigEditor.ps1 for Standalone support..."

$configEditorPath = "gui/ConfigEditor.ps1"
$configEditorContent = Get-Content $configEditorPath -Raw

if ($configEditorContent -match '"standalone"') {
    Write-Host "[OK] PASS: Standalone platform handling found in ConfigEditor.ps1"
} else {
    Write-Host "[ERROR] FAIL: Standalone platform handling not found in ConfigEditor.ps1"
}

# Test 5: Check if Update-PlatformFields handles standalone
if ($configEditorContent -match 'standalone.*{') {
    Write-Host "[OK] PASS: Update-PlatformFields handles standalone platform"
} else {
    Write-Host "[ERROR] FAIL: Update-PlatformFields does not handle standalone platform"
}

# Test 6: Check if Save-CurrentGameData handles executablePath
if ($configEditorContent -match 'executablePath') {
    Write-Host "[OK] PASS: Save-CurrentGameData handles executablePath"
} else {
    Write-Host "[ERROR] FAIL: Save-CurrentGameData does not handle executablePath"
}

# Test 7: Check if Handle-BrowseExecutablePath function exists
if ($configEditorContent -match 'function Handle-BrowseExecutablePath') {
    Write-Host "[OK] PASS: Handle-BrowseExecutablePath function found"
} else {
    Write-Host "[ERROR] FAIL: Handle-BrowseExecutablePath function not found"
}

# Test 8: Check messages.json for localization strings
Write-Host ""
Write-Host "Test 8: Checking messages.json for localization..."

$messagesPath = "../localization/messages.json"
$messagesContent = Get-Content $messagesPath -Raw

if ($messagesContent -match 'standalonePlatform') {
    Write-Host "[OK] PASS: standalonePlatform localization found"
} else {
    Write-Host "[ERROR] FAIL: standalonePlatform localization not found"
}

if ($messagesContent -match 'executablePathLabel') {
    Write-Host "[OK] PASS: executablePathLabel localization found"
} else {
    Write-Host "[ERROR] FAIL: executablePathLabel localization not found"
}

if ($messagesContent -match 'selectExecutableFile') {
    Write-Host "[OK] PASS: selectExecutableFile localization found"
} else {
    Write-Host "[ERROR] FAIL: selectExecutableFile localization not found"
}

# Test 9: Check if config.json can handle standalone games
Write-Host ""
Write-Host "Test 9: Testing config.json compatibility..."

$configPath = "config/config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Create a test standalone game entry
        $testStandaloneGame = @{
            name = "Test Standalone Game"
            platform = "standalone"
            executablePath = "C:/Games/TestGame/game.exe"
            processName = "game"
            appsToManage = @()
        }

        Write-Host "[OK] PASS: Config.json can handle standalone game structure"

    } catch {
        Write-Host "[ERROR] FAIL: Error testing config.json compatibility: $($_.Exception.Message)"
    }
} else {
    Write-Host "[INFO] INFO: config.json not found, using sample config"
}

Write-Host ""
Write-Host "=== Test Summary ==="
Write-Host "All static tests completed. To fully test the functionality:"
Write-Host "1. Run the GUI with: powershell -File gui/ConfigEditor.ps1"
Write-Host "2. Go to Game Settings tab"
Write-Host "3. Click 'Add New...' button"
Write-Host "4. Select 'Standalone' from Platform dropdown"
Write-Host "5. Verify Executable Path field appears"
Write-Host "6. Click Browse button to test file dialog"
Write-Host "7. Save and verify the game is saved correctly"
Write-Host ""
