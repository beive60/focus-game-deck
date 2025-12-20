<#
.SYNOPSIS
    Standalone test script for configuration validation logic

.DESCRIPTION
    Tests the centralized Invoke-ConfigurationValidation module.
    This script can be run directly or wrapped by Pester tests.

    Tests validation rules for:
    - Game ID format and requirements
    - Platform-specific identifiers (Steam, Epic, Riot)
    - Executable path validation
    - Error message structure

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0

    This script follows the existing test pattern and can be executed:
    1. Directly: .\Test-Core-ConfigValidation.ps1
    2. Via Pester: Wrapped in Core.Wrapper.Tests.ps1
#>

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

# Initialize project root path
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Import the validation module
. "$projectRoot/scripts/Invoke-ConfigurationValidation.ps1"

Write-BuildLog "[INFO] ConfigValidation Test: Starting standalone validation tests"

$testsPassed = 0
$testsFailed = 0
$testsTotal = 0

function Test-ValidationResult {
    param(
        [string]$TestName,
        [array]$Errors,
        [int]$ExpectedCount,
        [string]$ExpectedControl = $null,
        [string]$ExpectedKey = $null
    )

    $script:testsTotal++

    if ($Errors.Count -ne $ExpectedCount) {
        Write-BuildLog "[FAIL] $TestName - Expected $ExpectedCount errors, got $($Errors.Count)"
        $script:testsFailed++
        return $false
    }

    if ($ExpectedControl -and $Errors.Count -gt 0) {
        if ($Errors[0].Control -ne $ExpectedControl) {
            Write-BuildLog "[FAIL] $TestName - Expected control '$ExpectedControl', got '$($Errors[0].Control)'"
            $script:testsFailed++
            return $false
        }
    }

    if ($ExpectedKey -and $Errors.Count -gt 0) {
        if ($Errors[0].Key -ne $ExpectedKey) {
            Write-BuildLog "[FAIL] $TestName - Expected key '$ExpectedKey', got '$($Errors[0].Key)'"
            $script:testsFailed++
            return $false
        }
    }

    Write-BuildLog "[PASS] $TestName"
    $script:testsPassed++
    return $true
}

Write-Host ""
Write-BuildLog "=== Game ID Validation Tests ==="

# Test valid Game IDs
$errors = Invoke-ConfigurationValidation -GameId "apex-legends-2024"
Test-ValidationResult -TestName "Valid Game ID with hyphens and numbers" -Errors $errors -ExpectedCount 0

$errors = Invoke-ConfigurationValidation -GameId "league_of_legends"
Test-ValidationResult -TestName "Valid Game ID with underscores" -Errors $errors -ExpectedCount 0

$errors = Invoke-ConfigurationValidation -GameId "CS2"
Test-ValidationResult -TestName "Valid Game ID alphanumeric" -Errors $errors -ExpectedCount 0

# Test invalid Game IDs
$errors = Invoke-ConfigurationValidation -GameId ""
Test-ValidationResult -TestName "Empty Game ID" -Errors $errors -ExpectedCount 1 -ExpectedControl "GameIdTextBox" -ExpectedKey "gameIdRequired"

$errors = Invoke-ConfigurationValidation -GameId "apex legends"
Test-ValidationResult -TestName "Game ID with spaces" -Errors $errors -ExpectedCount 1 -ExpectedControl "GameIdTextBox" -ExpectedKey "gameIdInvalidCharacters"

$errors = Invoke-ConfigurationValidation -GameId "apex@legends!"
Test-ValidationResult -TestName "Game ID with special characters" -Errors $errors -ExpectedCount 1 -ExpectedControl "GameIdTextBox" -ExpectedKey "gameIdInvalidCharacters"

$errors = Invoke-ConfigurationValidation -GameId "ゲーム"
Test-ValidationResult -TestName "Game ID with Japanese characters" -Errors $errors -ExpectedCount 1 -ExpectedControl "GameIdTextBox" -ExpectedKey "gameIdInvalidCharacters"

Write-Host ""
Write-BuildLog "=== Steam Platform Validation Tests ==="

# Test valid Steam configurations
$errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "1172470"
Test-ValidationResult -TestName "Valid Steam AppID (7 digits)" -Errors $errors -ExpectedCount 0

# Test invalid Steam configurations
$errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId ""
Test-ValidationResult -TestName "Empty Steam AppID" -Errors $errors -ExpectedCount 1 -ExpectedControl "SteamAppIdTextBox" -ExpectedKey "steamAppIdRequired"

$errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "123456"
Test-ValidationResult -TestName "Steam AppID with 6 digits" -Errors $errors -ExpectedCount 1 -ExpectedControl "SteamAppIdTextBox" -ExpectedKey "steamAppIdMust7Digits"

$errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "12345678"
Test-ValidationResult -TestName "Steam AppID with 8 digits" -Errors $errors -ExpectedCount 1 -ExpectedControl "SteamAppIdTextBox" -ExpectedKey "steamAppIdMust7Digits"

$errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "117247a"
Test-ValidationResult -TestName "Steam AppID with non-numeric characters" -Errors $errors -ExpectedCount 1 -ExpectedControl "SteamAppIdTextBox" -ExpectedKey "steamAppIdMust7Digits"

Write-Host ""
Write-BuildLog "=== Epic Platform Validation Tests ==="

# Test valid Epic configurations
$errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "apps/fortnite"
Test-ValidationResult -TestName "Valid Epic Game ID with apps/ prefix" -Errors $errors -ExpectedCount 0

$errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "com.epicgames.launcher://apps/fortnite"
Test-ValidationResult -TestName "Valid Epic Game ID with full launcher URL" -Errors $errors -ExpectedCount 0

# Test invalid Epic configurations
$errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId ""
Test-ValidationResult -TestName "Empty Epic Game ID" -Errors $errors -ExpectedCount 1 -ExpectedControl "EpicGameIdTextBox" -ExpectedKey "epicGameIdRequired"

$errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "fortnite"
Test-ValidationResult -TestName "Epic Game ID without prefix" -Errors $errors -ExpectedCount 1 -ExpectedControl "EpicGameIdTextBox" -ExpectedKey "epicGameIdInvalidFormat"

$errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "game/fortnite"
Test-ValidationResult -TestName "Epic Game ID with invalid prefix" -Errors $errors -ExpectedCount 1 -ExpectedControl "EpicGameIdTextBox" -ExpectedKey "epicGameIdInvalidFormat"

Write-Host ""
Write-BuildLog "=== Riot Platform Validation Tests ==="

# Test valid Riot configurations
$errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId "valorant"
Test-ValidationResult -TestName "Valid Riot Game ID 'valorant'" -Errors $errors -ExpectedCount 0

$errors = Invoke-ConfigurationValidation -GameId "lor" -Platform "riot" -RiotGameId "bacon"
Test-ValidationResult -TestName "Valid Riot Game ID 'bacon' (LoR)" -Errors $errors -ExpectedCount 0

$errors = Invoke-ConfigurationValidation -GameId "lol" -Platform "riot" -RiotGameId "league_of_legends"
Test-ValidationResult -TestName "Valid Riot Game ID with underscores" -Errors $errors -ExpectedCount 0

# Test invalid Riot configurations
$errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId ""
Test-ValidationResult -TestName "Empty Riot Game ID" -Errors $errors -ExpectedCount 1 -ExpectedControl "RiotGameIdTextBox" -ExpectedKey "riotGameIdRequired"

$errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId "   "
Test-ValidationResult -TestName "Whitespace-only Riot Game ID" -Errors $errors -ExpectedCount 1 -ExpectedControl "RiotGameIdTextBox" -ExpectedKey "riotGameIdRequired"

Write-Host ""
Write-BuildLog "=== Standalone/Direct Platform Validation Tests ==="

# Create temporary test files
$testExePath = Join-Path -Path $env:TEMP -ChildPath "test-validation-game-$([guid]::NewGuid().ToString()).exe"
New-Item -Path $testExePath -ItemType File -Force | Out-Null

try {
    # Test valid standalone configuration
    $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "standalone" -ExecutablePath $testExePath
    Test-ValidationResult -TestName "Valid executable path for standalone" -Errors $errors -ExpectedCount 0

    # Test valid direct configuration
    $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "direct" -ExecutablePath $testExePath
    Test-ValidationResult -TestName "Valid executable path for direct" -Errors $errors -ExpectedCount 0

    # Test invalid configurations
    $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "standalone" -ExecutablePath ""
    Test-ValidationResult -TestName "Empty executable path for standalone" -Errors $errors -ExpectedCount 1 -ExpectedControl "ExecutablePathTextBox" -ExpectedKey "executablePathRequired"

    $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "direct" -ExecutablePath ""
    Test-ValidationResult -TestName "Empty executable path for direct" -Errors $errors -ExpectedCount 1 -ExpectedControl "ExecutablePathTextBox" -ExpectedKey "executablePathRequired"

    $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "standalone" -ExecutablePath "C:/NonExistent/game.exe"
    Test-ValidationResult -TestName "Non-existent executable path for standalone" -Errors $errors -ExpectedCount 1 -ExpectedControl "ExecutablePathTextBox" -ExpectedKey "executablePathNotFound"

    $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "direct" -ExecutablePath "C:/NonExistent/game.exe"
    Test-ValidationResult -TestName "Non-existent executable path for direct" -Errors $errors -ExpectedCount 1 -ExpectedControl "ExecutablePathTextBox" -ExpectedKey "executablePathNotFound"
} finally {
    # Clean up temporary file
    if (Test-Path $testExePath) {
        Remove-Item -Path $testExePath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-BuildLog "=== Multiple Errors Tests ==="

$errors = Invoke-ConfigurationValidation -GameId "" -Platform "steam" -SteamAppId "invalid"
Test-ValidationResult -TestName "Multiple errors: empty Game ID and invalid Steam AppID" -Errors $errors -ExpectedCount 2

$errors = Invoke-ConfigurationValidation -GameId "game with spaces" -Platform "epic" -EpicGameId ""
Test-ValidationResult -TestName "Multiple errors: invalid Game ID and empty Epic Game ID" -Errors $errors -ExpectedCount 2

Write-Host ""
Write-BuildLog "=== Edge Cases Tests ==="

$errors = Invoke-ConfigurationValidation -GameId "a"
Test-ValidationResult -TestName "Minimum valid Game ID (single character)" -Errors $errors -ExpectedCount 0

$longId = "a" * 100
$errors = Invoke-ConfigurationValidation -GameId $longId
Test-ValidationResult -TestName "Very long valid Game ID (100 characters)" -Errors $errors -ExpectedCount 0

$errors = Invoke-ConfigurationValidation -GameId "test" -Platform "" -SteamAppId "1234567"
Test-ValidationResult -TestName "Empty platform string" -Errors $errors -ExpectedCount 0

Write-Host ""
Write-BuildLog "=== Error Structure Tests ==="

$errors = Invoke-ConfigurationValidation -GameId "" -Platform "steam" -SteamAppId ""
$testsTotal++
if ($errors.Count -eq 2) {
    $allValid = $true
    foreach ($error in $errors) {
        if (-not $error.ContainsKey("Control") -or -not $error.ContainsKey("Key")) {
            $allValid = $false
            break
        }
        if ([string]::IsNullOrEmpty($error.Control) -or [string]::IsNullOrEmpty($error.Key)) {
            $allValid = $false
            break
        }
    }

    if ($allValid) {
        Write-BuildLog "[PASS] Error objects have required Control and Key properties"
        $testsPassed++
    } else {
        Write-BuildLog "[FAIL] Error objects missing or invalid Control/Key properties"
        $testsFailed++
    }
} else {
    Write-BuildLog "[FAIL] Error structure test - unexpected error count"
    $testsFailed++
}

# Summary
Write-Host ""
Write-BuildLog "========================================"
Write-BuildLog "Configuration Validation Test Summary"
Write-BuildLog "========================================"
Write-BuildLog "Total:  $testsTotal"
Write-BuildLog "Passed: $testsPassed"
Write-BuildLog "Failed: $testsFailed"
Write-BuildLog "========================================"

if ($testsFailed -gt 0) {
    Write-Host ""
    Write-BuildLog "[ERROR] Some tests failed!"
    exit 1
} else {
    Write-Host ""
    Write-BuildLog "[SUCCESS] All tests passed!"
    exit 0
}
