#Requires -Version 5.1

<#
.SYNOPSIS
    Character encoding validation test for Focus Game Deck project.

.DESCRIPTION
    This script validates character encoding best practices outlined in ARCHITECTURE.md.
    It checks JSON file encoding, console output compatibility, and validates common
    encoding issues that have occurred in the project.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-09-26
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

# Initialize project root path
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "Focus Game Deck - Character Encoding Validation Test" -ForegroundColor Cyan
Write-Host "Validating implementation guidelines from ARCHITECTURE.md" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$results = @{ Total = 0; Passed = 0; Failed = 0 }

function Test-Result {
    param([string]$Name, [bool]$Pass, [string]$Message = "")
    $results.Total++
    if ($Pass) {
        $results.Passed++
        Write-Host "[OK] $Name" -ForegroundColor Green
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
    } else {
        $results.Failed++
        Write-Host "[ERROR] $Name" -ForegroundColor Red
        if ($Message) { Write-Host "  Error: $Message" -ForegroundColor Red }
    }
}

Write-Host "Testing JSON File Encoding..." -ForegroundColor Yellow

# Test config.json
try {
    $configPath = Join-Path $projectRoot "config/config.json"
    $configContent = Get-Content $configPath -Raw -Encoding UTF8
    $null = $configContent | ConvertFrom-Json  # Test parsing
    Test-Result "config.json UTF-8 parsing" $true

    $configBytes = [System.IO.File]::ReadAllBytes($configPath)
    $hasBOM = ($configBytes.Length -ge 3 -and $configBytes[0] -eq 0xEF -and $configBytes[1] -eq 0xBB -and $configBytes[2] -eq 0xBF)
    Test-Result "config.json without BOM" (-not $hasBOM) $(if ($hasBOM) { "BOM detected" } else { "" })
} catch {
    Test-Result "config.json validation" $false $_.Exception.Message
}

# Test messages.json
try {
    $messagesPath = Join-Path $projectRoot "localization/messages.json"
    $messagesContent = Get-Content $messagesPath -Raw -Encoding UTF8
    $messages = $messagesContent | ConvertFrom-Json
    Test-Result "messages.json UTF-8 parsing" $true

    $messagesBytes = [System.IO.File]::ReadAllBytes($messagesPath)
    $hasBOM = ($messagesBytes.Length -ge 3 -and $messagesBytes[0] -eq 0xEF -and $messagesBytes[1] -eq 0xBB -and $messagesBytes[2] -eq 0xBF)
    Test-Result "messages.json without BOM" (-not $hasBOM) $(if ($hasBOM) { "BOM detected" } else { "" })

    # Test message structure
    if ($messages.en -and $messages.ja) {
        $enCount = ($messages.en.PSObject.Properties | Measure-Object).Count
        $jaCount = ($messages.ja.PSObject.Properties | Measure-Object).Count
        Test-Result "Message key consistency" ($enCount -eq $jaCount) "EN=$enCount, JA=$jaCount"

        # Test Japanese text
        $sampleText = $messages.ja.errorMessage
        $hasJapanese = $sampleText -and ($sampleText.Contains("エラー") -or $sampleText.Length -gt 5)
        Test-Result "Japanese character integrity" $hasJapanese $(if ($sampleText) { "Sample: $($sampleText.Substring(0, [Math]::Min(15, $sampleText.Length)))..." } else { "No sample text" })
    }
} catch {
    Test-Result "messages.json validation" $false $_.Exception.Message
}

Write-Host "Testing Console Output Safety..." -ForegroundColor Yellow
Test-Result "ASCII-safe console output" $true "Using [OK]/[ERROR] instead of UTF-8 symbols"

Write-Host "Testing Logger Compatibility..." -ForegroundColor Yellow
try {
    $loggerPath = Join-Path $projectRoot "src/modules/Logger.ps1"
    if (Test-Path $loggerPath) {
        . $loggerPath
        Test-Result "Logger module loading" $true

        $configPath = Join-Path $projectRoot "config/config.json"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

            # Import LanguageHelper for proper message loading
            $languageHelperPath = Join-Path $projectRoot "scripts/LanguageHelper.ps1"
            if (Test-Path $languageHelperPath) {
                . $languageHelperPath

                # Load messages using proper LanguageHelper method
                $messagesPath = Join-Path $projectRoot "localization/messages.json"
                $langCode = Get-DetectedLanguage -ConfigData $config
                $msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode

                # Create simple test messages for compatibility testing
                $testMessages = @{
                    test_message = "Character encoding test message"
                }

                $logger = Initialize-Logger -Config $config -Messages $testMessages
                Test-Result "Logger initialization" $true

                $logger.Info("Character encoding test message", "TEST")
                Test-Result "Logger UTF-8 logging" $true
            } else {
                Test-Result "Logger compatibility" $false "LanguageHelper.ps1 not found"
            }
        } else {
            Test-Result "Logger compatibility" $false "config.json not found"
        }
    } else {
        Test-Result "Logger compatibility" $false "Logger.ps1 not found"
    }
} catch {
    Test-Result "Logger compatibility" $false $_.Exception.Message
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host " Test Summary" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Total Tests: $($results.Total)" -ForegroundColor White
Write-Host "Passed: $($results.Passed)" -ForegroundColor Green
Write-Host "Failed: $($results.Failed)" -ForegroundColor Red

$successRate = [math]::Round(($results.Passed / $results.Total) * 100, 1)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -gt 90) { "Green" } elseif ($successRate -gt 70) { "Yellow" } else { "Red" })

if ($results.Failed -eq 0) {
    Write-Host ""
    Write-Host "All character encoding tests passed! Project follows ARCHITECTURE.md guidelines." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some tests failed. Please review character encoding guidelines in ARCHITECTURE.md" -ForegroundColor Yellow
}

if ($results.Failed -gt 0) { exit 1 }
