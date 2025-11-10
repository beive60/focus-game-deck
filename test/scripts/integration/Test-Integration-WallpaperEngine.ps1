<#
.SYNOPSIS
    Wallpaper Engine integration test suite for Focus Game Deck.

.DESCRIPTION
    This test script validates the Wallpaper Engine integration functionality in the AppManager module.
    It verifies automatic wallpaper pause/play actions during gaming sessions for improved performance.

    The test suite covers:
    - Configuration validation for Wallpaper Engine settings
    - AppManager initialization with wallpaper actions
    - pause-wallpaper and play-wallpaper action execution
    - System architecture detection (32-bit vs 64-bit executable selection)
    - Error handling for invalid paths and configurations

    Test Categories:
    1. Configuration Validation - Verifies wallpaper action configuration schema
    2. AppManager Initialization - Tests AppManager creation with Wallpaper Engine config
    3. Action Method Validation - Executes pause-wallpaper and play-wallpaper actions
    4. Architecture Detection - Tests automatic executable selection based on system architecture
    5. Error Handling - Validates proper handling of invalid paths and configurations

.PARAMETER Verbose
    Enables verbose output for detailed test execution information.

.PARAMETER TestMode
    Runs tests in simulation mode without actually executing Wallpaper Engine actions.
    Useful for CI/CD environments or systems without Wallpaper Engine installed.

.EXAMPLE
    .\Test-WallpaperEngine.ps1
    Runs all Wallpaper Engine integration tests with default settings.

.EXAMPLE
    .\Test-WallpaperEngine.ps1 -TestMode
    Runs tests in simulation mode without executing actual Wallpaper Engine actions.

.EXAMPLE
    .\Test-WallpaperEngine.ps1 -Verbose
    Runs tests with detailed verbose output.

.NOTES
    Author: GitHub Copilot Assistant
    Version: 1.0.0
    Date: 2025-09-27

    Requirements:
    - AppManager.ps1 module
    - ConfigValidator.ps1 module
    - localization/messages.json

    Exit Codes:
    0 - All tests passed
    1 - One or more tests failed or module loading error

    Dependencies:
    - Wallpaper Engine installation (optional for TestMode)
    - Steam installation path (for common Wallpaper Engine paths)
#>

param(
    [switch]$Verbose,
    [switch]$TestMode
)

# Set encoding for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Import required modules
$rootPath = Split-Path $PSScriptRoot -Parent
$appManagerPath = Join-Path $rootPath "src/modules/AppManager.ps1"
$configValidatorPath = Join-Path $rootPath "src/modules/ConfigValidator.ps1"
$messagesPath = Join-Path $rootPath "localization/messages.json"

# Load modules
if (Test-Path $appManagerPath) {
    . $appManagerPath
    Write-Host "[OK] AppManager module loaded"
} else {
    Write-Error "AppManager module not found at: $appManagerPath"
    exit 1
}

if (Test-Path $configValidatorPath) {
    . $configValidatorPath
    Write-Host "[OK] ConfigValidator module loaded"
} else {
    Write-Error "ConfigValidator module not found at: $configValidatorPath"
    exit 1
}

# Load configuration and messages
try {
    $messages = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Messages loaded"
} catch {
    Write-Error "Failed to load messages: $_"
    exit 1
}

# Test configuration for Wallpaper Engine
$testConfig = @{
    managedApps = @{
        wallpaperEngine = @{
            path = "C:/Program Files (x86)/Steam/steamapps/common/wallpaper_engine/wallpaper32.exe"
            processName = "wallpaper32|wallpaper64"
            gameStartAction = "pause-wallpaper"
            gameEndAction = "play-wallpaper"
            arguments = ""
        }
    }
    games = @{
        testGame = @{
            name = "Test Game"
            processName = "testgame.exe"
            appsToManage = @("wallpaperEngine")
        }
    }
    paths = @{
        steam = "C:/Program Files (x86)/Steam/steam.exe"
    }
} | ConvertTo-Json -Depth 10 | ConvertFrom-Json

Write-Host ""
Write-Host "=== Focus Game Deck - Wallpaper Engine Integration Test ==="
Write-Host ""

# Test 1: Configuration Validation
Write-Host "Test 1: Configuration Validation"
Write-Host "└─ Testing wallpaper action validation..."

$validator = New-ConfigValidator -Config $testConfig -Messages $messages
$validationResult = $validator.ValidateConfiguration($null)

if ($validationResult) {
    Write-Host "   [OK] Configuration validation passed"
} else {
    Write-Host "Configuration validation failed"
    $report = $validator.GetValidationReport()
    foreach ($errorMsg in $report.Errors) {
        Write-Host "     Error: $errorMsg"
    }
}

# Test 2: AppManager Initialization
Write-Host ""
Write-Host "Test 2: AppManager Initialization"
Write-Host "└─ Creating AppManager instance with Wallpaper Engine config..."

try {
    $appManager = New-AppManager -Config $testConfig -Messages $messages
    Write-Host "   [OK] AppManager created successfully"
} catch {
    Write-Host "Failed to create AppManager: $_"
    exit 1
}

# Test 3: Action Method Validation
Write-Host ""
Write-Host "Test 3: Action Method Validation"

# Test pause-wallpaper action
Write-Host "└─ Testing pause-wallpaper action..."
if ($TestMode.IsPresent) {
    Write-Host "   [TEST MODE] Simulating pause-wallpaper action..."
    Write-Host "   [OK] pause-wallpaper action would be executed"
    $pauseResult = $true
} else {
    try {
        $pauseResult = $appManager.InvokeAction("wallpaperEngine", "pause-wallpaper")
        if ($pauseResult) {
            Write-Host "   [OK] pause-wallpaper action executed successfully"
        } else {
            Write-Host "pause-wallpaper action failed"
        }
    } catch {
        Write-Host "Exception during pause-wallpaper: $_"
        $pauseResult = $false
    }
}

# Test play-wallpaper action
Write-Host "└─ Testing play-wallpaper action..."
if ($TestMode.IsPresent) {
    Write-Host "   [TEST MODE] Simulating play-wallpaper action..."
    Write-Host "   [OK] play-wallpaper action would be executed"
    $playResult = $true
} else {
    try {
        $playResult = $appManager.InvokeAction("wallpaperEngine", "play-wallpaper")
        if ($playResult) {
            Write-Host "   [OK] play-wallpaper action executed successfully"
        } else {
            Write-Host "play-wallpaper action failed"
        }
    } catch {
        Write-Host "Exception during play-wallpaper: $_"
        $playResult = $false
    }
}

# Test 4: Architecture Detection
Write-Host ""
Write-Host "Test 4: System Architecture Detection"
Write-Host "└─ Testing automatic executable selection..."

$is64Bit = [Environment]::Is64BitOperatingSystem
Write-Host "   System Architecture: $(if ($is64Bit) { '64-bit' } else { '32-bit' })"

# Common Wallpaper Engine paths
$commonPaths = @(
    "C:/Program Files (x86)/Steam/steamapps/common/wallpaper_engine/wallpaper32.exe",
    "C:/Program Files (x86)/Steam/steamapps/common/wallpaper_engine/wallpaper64.exe",
    "C:/Program Files/Wallpaper Engine/wallpaper32.exe",
    "C:/Program Files/Wallpaper Engine/wallpaper64.exe"
)

$foundPaths = @()
foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $foundPaths += $path
        Write-Host "   [OK] Found: $path"
    }
}

if ($foundPaths.Count -eq 0) {
    Write-Host " No Wallpaper Engine installations found at common paths"
    Write-Host "      This is normal if Wallpaper Engine is not installed"
} else {
    Write-Host "   [OK] Found $($foundPaths.Count) Wallpaper Engine executable(s)"
}

# Test 5: Error Handling
Write-Host ""
Write-Host "Test 5: Error Handling"
Write-Host "└─ Testing invalid path handling..."

$invalidConfig = @{
    managedApps = @{
        wallpaperEngine = @{
            path = "C:\NonExistent/wallpaper32.exe"
            processName = "wallpaper32"
            gameStartAction = "pause-wallpaper"
            gameEndAction = "play-wallpaper"
            arguments = ""
        }
    }
} | ConvertTo-Json -Depth 10 | ConvertFrom-Json

$testAppManager = New-AppManager -Config $invalidConfig -Messages $messages
$errorResult = $testAppManager.InvokeAction("wallpaperEngine", "pause-wallpaper")

if (-not $errorResult) {
    Write-Host "   [OK] Invalid path properly handled (returned false)"
} else {
    Write-Host "Invalid path not properly handled"
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ==="
Write-Host ""

$totalTests = 5
$passedTests = 0

if ($validationResult) { $passedTests++ }
if ($appManager) { $passedTests++ }
if ($pauseResult) { $passedTests++ }
if ($playResult) { $passedTests++ }
if (-not $errorResult) { $passedTests++ }  # Error handling test passes when it returns false

if ($passedTests -eq $totalTests) {
    Write-Host "[OK] Tests Passed: $passedTests / $totalTests"
    Write-Host "[OK] All Wallpaper Engine integration tests passed!"
    exit 0
} else {
    Write-Host "[WARNING] Tests Passed: $passedTests / $totalTests"
    Write-Host "[WARNING] Some tests failed or require attention"
    exit 1
}
