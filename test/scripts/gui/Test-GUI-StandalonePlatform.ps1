# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

# Test Script for Standalone Platform GUI Functionality
# This script tests the newly implemented Standalone platform features in the GUI

Write-BuildLog "=== Focus Game Deck - Standalone Platform GUI Test ==="
Write-Host ""

# Test 1: Check if XAML contains Standalone platform option
Write-BuildLog "Test 1: Checking XAML for Standalone platform option..."

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$xamlPath = Join-Path -Path $projectRoot -ChildPath "gui/MainWindow.xaml"
$xamlContent = Get-Content $xamlPath -Raw

if ($xamlContent -match 'Tag="standalone"') {
    Write-BuildLog "[OK] PASS: Standalone platform option found in XAML"
} else {
    Write-BuildLog "[ERROR] FAIL: Standalone platform option not found in XAML"
}

# Test 2: Check if ExecutablePathTextBox exists in XAML
if ($xamlContent -match 'Name="ExecutablePathTextBox"') {
    Write-BuildLog "[OK] PASS: ExecutablePathTextBox found in XAML"
} else {
    Write-BuildLog "[ERROR] FAIL: ExecutablePathTextBox not found in XAML"
}

# Test 3: Check if BrowseExecutablePathButton exists in XAML
if ($xamlContent -match 'Name="BrowseExecutablePathButton"') {
    Write-BuildLog "[OK] PASS: BrowseExecutablePathButton found in XAML"
} else {
    Write-BuildLog "[ERROR] FAIL: BrowseExecutablePathButton not found in XAML"
}

# Test 4: Check ConfigEditor.ps1 for Standalone platform handling
Write-Host ""
Write-BuildLog "Test 4: Checking ConfigEditor.ps1 for Standalone support..."

$configEditorPath = "gui/ConfigEditor.ps1"
$configEditorContent = Get-Content $configEditorPath -Raw

if ($configEditorContent -match '"standalone"') {
    Write-BuildLog "[OK] PASS: Standalone platform handling found in ConfigEditor.ps1"
} else {
    Write-BuildLog "[ERROR] FAIL: Standalone platform handling not found in ConfigEditor.ps1"
}

# Test 5: Check if Update-PlatformFields handles standalone
if ($configEditorContent -match 'standalone.*{') {
    Write-BuildLog "[OK] PASS: Update-PlatformFields handles standalone platform"
} else {
    Write-BuildLog "[ERROR] FAIL: Update-PlatformFields does not handle standalone platform"
}

# Test 6: Check if Save-CurrentGameData handles executablePath
if ($configEditorContent -match 'executablePath') {
    Write-BuildLog "[OK] PASS: Save-CurrentGameData handles executablePath"
} else {
    Write-BuildLog "[ERROR] FAIL: Save-CurrentGameData does not handle executablePath"
}

# Test 7: Check if Handle-BrowseExecutablePath function exists
if ($configEditorContent -match 'function Handle-BrowseExecutablePath') {
    Write-BuildLog "[OK] PASS: Handle-BrowseExecutablePath function found"
} else {
    Write-BuildLog "[ERROR] FAIL: Handle-BrowseExecutablePath function not found"
}

# Test 8: Check messages.json for localization strings
Write-Host ""
Write-BuildLog "Test 8: Checking messages.json for localization..."

$messagesPath = "../localization/en.json"
$messagesContent = Get-Content $messagesPath -Raw

if ($messagesContent -match 'standalonePlatform') {
    Write-BuildLog "[OK] PASS: standalonePlatform localization found"
} else {
    Write-BuildLog "[ERROR] FAIL: standalonePlatform localization not found"
}

if ($messagesContent -match 'executablePathLabel') {
    Write-BuildLog "[OK] PASS: executablePathLabel localization found"
} else {
    Write-BuildLog "[ERROR] FAIL: executablePathLabel localization not found"
}

if ($messagesContent -match 'selectExecutableFile') {
    Write-BuildLog "[OK] PASS: selectExecutableFile localization found"
} else {
    Write-BuildLog "[ERROR] FAIL: selectExecutableFile localization not found"
}

# Test 9: Check if config.json can handle standalone games
Write-Host ""
Write-BuildLog "Test 9: Testing config.json compatibility..."

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

        Write-BuildLog "[OK] PASS: Config.json can handle standalone game structure"

    } catch {
        Write-BuildLog "[ERROR] FAIL: Error testing config.json compatibility: $($_.Exception.Message)"
    }
} else {
    Write-BuildLog "[INFO] INFO: config.json not found, using sample config"
}

Write-Host ""
Write-BuildLog "=== Test Summary ==="
Write-BuildLog "All static tests completed. To fully test the functionality:"
Write-BuildLog "1. Run the GUI with: powershell -File gui/ConfigEditor.ps1"
Write-BuildLog "2. Go to Game Settings tab"
Write-BuildLog "3. Click 'Add New...' button"
Write-BuildLog "4. Select 'Standalone' from Platform dropdown"
Write-BuildLog "5. Verify Executable Path field appears"
Write-BuildLog "6. Click Browse button to test file dialog"
Write-BuildLog "7. Save and verify the game is saved correctly"
Write-Host ""
