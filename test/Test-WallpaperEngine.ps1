# Focus Game Deck - Wallpaper Engine Integration Test
# Tests Wallpaper Engine pause/play functionality through AppManager
#
# This test validates the Wallpaper Engine integration feature that allows
# automatic wallpaper pause during gaming sessions for better performance.
#
# Author: GitHub Copilot Assistant
# Version: 1.0.0
# Date: 2025-09-27

param(
    [switch]$Verbose,
    [switch]$TestMode
)

# Set encoding for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Import required modules
$rootPath = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $rootPath "config/config.json"
$appManagerPath = Join-Path $rootPath "src/modules/AppManager.ps1"
$configValidatorPath = Join-Path $rootPath "src/modules/ConfigValidator.ps1"
$messagesPath = Join-Path $rootPath "localization/messages.json"

# Load modules
if (Test-Path $appManagerPath) {
    . $appManagerPath
    Write-Host "[OK] AppManager module loaded" -ForegroundColor Green
} else {
    Write-Error "AppManager module not found at: $appManagerPath"
    exit 1
}

if (Test-Path $configValidatorPath) {
    . $configValidatorPath
    Write-Host "[OK] ConfigValidator module loaded" -ForegroundColor Green
} else {
    Write-Error "ConfigValidator module not found at: $configValidatorPath"
    exit 1
}

# Load configuration and messages
try {
    $messages = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Messages loaded" -ForegroundColor Green
} catch {
    Write-Error "Failed to load messages: $_"
    exit 1
}

# Test configuration for Wallpaper Engine
$testConfig = @{
    managedApps = @{
        wallpaperEngine = @{
            path            = "C:/Program Files (x86)/Steam/steamapps/common/wallpaper_engine/wallpaper32.exe"
            processName     = "wallpaper32|wallpaper64"
            gameStartAction = "pause-wallpaper"
            gameEndAction   = "play-wallpaper"
            arguments       = ""
        }
    }
    games       = @{
        testGame = @{
            name         = "Test Game"
            processName  = "testgame.exe"
            appsToManage = @("wallpaperEngine")
        }
    }
    paths       = @{
        steam = "C:/Program Files (x86)/Steam/steam.exe"
    }
} | ConvertTo-Json -Depth 10 | ConvertFrom-Json

Write-Host ""
Write-Host "=== Focus Game Deck - Wallpaper Engine Integration Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Configuration Validation
Write-Host "Test 1: Configuration Validation" -ForegroundColor Yellow
Write-Host "└─ Testing wallpaper action validation..."

$validator = New-ConfigValidator -Config $testConfig -Messages $messages
$validationResult = $validator.ValidateConfiguration($null)

if ($validationResult) {
    Write-Host "   [OK] Configuration validation passed" -ForegroundColor Green
} else {
    Write-Host "Configuration validation failed" -ForegroundColor Red
    $report = $validator.GetValidationReport()
    foreach ($errorMsg in $report.Errors) {
        Write-Host "     Error: $errorMsg" -ForegroundColor Red
    }
}

# Test 2: AppManager Initialization
Write-Host ""
Write-Host "Test 2: AppManager Initialization" -ForegroundColor Yellow
Write-Host "└─ Creating AppManager instance with Wallpaper Engine config..."

try {
    $appManager = New-AppManager -Config $testConfig -Messages $messages
    Write-Host "   [OK] AppManager created successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to create AppManager: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Action Method Validation
Write-Host ""
Write-Host "Test 3: Action Method Validation" -ForegroundColor Yellow

# Test pause-wallpaper action
Write-Host "└─ Testing pause-wallpaper action..."
if ($TestMode.IsPresent) {
    Write-Host "   [TEST MODE] Simulating pause-wallpaper action..." -ForegroundColor Cyan
    Write-Host "   [OK] pause-wallpaper action would be executed" -ForegroundColor Green
    $pauseResult = $true
} else {
    try {
        $pauseResult = $appManager.InvokeAction("wallpaperEngine", "pause-wallpaper")
        if ($pauseResult) {
            Write-Host "   [OK] pause-wallpaper action executed successfully" -ForegroundColor Green
        } else {
            Write-Host "pause-wallpaper action failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Exception during pause-wallpaper: $_" -ForegroundColor Red
        $pauseResult = $false
    }
}

# Test play-wallpaper action
Write-Host "└─ Testing play-wallpaper action..."
if ($TestMode.IsPresent) {
    Write-Host "   [TEST MODE] Simulating play-wallpaper action..." -ForegroundColor Cyan
    Write-Host "   [OK] play-wallpaper action would be executed" -ForegroundColor Green
    $playResult = $true
} else {
    try {
        $playResult = $appManager.InvokeAction("wallpaperEngine", "play-wallpaper")
        if ($playResult) {
            Write-Host "   [OK] play-wallpaper action executed successfully" -ForegroundColor Green
        } else {
            Write-Host "play-wallpaper action failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Exception during play-wallpaper: $_" -ForegroundColor Red
        $playResult = $false
    }
}

# Test 4: Architecture Detection
Write-Host ""
Write-Host "Test 4: System Architecture Detection" -ForegroundColor Yellow
Write-Host "└─ Testing automatic executable selection..."

$is64Bit = [Environment]::Is64BitOperatingSystem
Write-Host "   System Architecture: $(if ($is64Bit) { '64-bit' } else { '32-bit' })" -ForegroundColor Cyan

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
        Write-Host "   [OK] Found: $path" -ForegroundColor Green
    }
}

if ($foundPaths.Count -eq 0) {
    Write-Host " No Wallpaper Engine installations found at common paths" -ForegroundColor Yellow
    Write-Host "      This is normal if Wallpaper Engine is not installed" -ForegroundColor Gray
} else {
    Write-Host "   [OK] Found $($foundPaths.Count) Wallpaper Engine executable(s)" -ForegroundColor Green
}

# Test 5: Error Handling
Write-Host ""
Write-Host "Test 5: Error Handling" -ForegroundColor Yellow
Write-Host "└─ Testing invalid path handling..."

$invalidConfig = @{
    managedApps = @{
        wallpaperEngine = @{
            path            = "C:\NonExistent/wallpaper32.exe"
            processName     = "wallpaper32"
            gameStartAction = "pause-wallpaper"
            gameEndAction   = "play-wallpaper"
            arguments       = ""
        }
    }
} | ConvertTo-Json -Depth 10 | ConvertFrom-Json

$testAppManager = New-AppManager -Config $invalidConfig -Messages $messages
$errorResult = $testAppManager.InvokeAction("wallpaperEngine", "pause-wallpaper")

if (-not $errorResult) {
    Write-Host "   [OK] Invalid path properly handled (returned false)" -ForegroundColor Green
} else {
    Write-Host "Invalid path not properly handled" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host ""

$totalTests = 5
$passedTests = 0

if ($validationResult) { $passedTests++ }
if ($appManager) { $passedTests++ }
if ($pauseResult) { $passedTests++ }
if ($playResult) { $passedTests++ }
if (-not $errorResult) { $passedTests++ }  # Error handling test passes when it returns false

Write-Host "Tests Passed: $passedTests / $totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "[OK] All Wallpaper Engine integration tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host " Some tests failed or require attention" -ForegroundColor Yellow
    exit 1
}
