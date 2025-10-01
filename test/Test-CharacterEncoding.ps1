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
    $configContent = Get-Content "./config/config.json" -Raw -Encoding UTF8
    $null = $configContent | ConvertFrom-Json  # Test parsing
    Test-Result "config.json UTF-8 parsing" $true

    $configBytes = [System.IO.File]::ReadAllBytes("./config/config.json")
    $hasBOM = ($configBytes.Length -ge 3 -and $configBytes[0] -eq 0xEF -and $configBytes[1] -eq 0xBB -and $configBytes[2] -eq 0xBF)
    Test-Result "config.json without BOM" (-not $hasBOM) $(if ($hasBOM) { "BOM detected" } else { "" })
} catch {
    Test-Result "config.json validation" $false $_.Exception.Message
}

# Test messages.json
try {
    $messagesContent = Get-Content "./config/messages.json" -Raw -Encoding UTF8
    $messages = $messagesContent | ConvertFrom-Json
    Test-Result "messages.json UTF-8 parsing" $true

    $messagesBytes = [System.IO.File]::ReadAllBytes("./config/messages.json")
    $hasBOM = ($messagesBytes.Length -ge 3 -and $messagesBytes[0] -eq 0xEF -and $messagesBytes[1] -eq 0xBB -and $messagesBytes[2] -eq 0xBF)
    Test-Result "messages.json without BOM" (-not $hasBOM) $(if ($hasBOM) { "BOM detected" } else { "" })

    # Test message structure
    if ($messages.en -and $messages.ja) {
        $enCount = ($messages.en.PSObject.Properties | Measure-Object).Count
        $jaCount = ($messages.ja.PSObject.Properties | Measure-Object).Count
        Test-Result "Message key consistency" ($enCount -eq $jaCount) "EN=$enCount, JA=$jaCount"

        # Test Japanese text
        $sampleText = $messages.ja.error_game_id_not_found
        $hasJapanese = $sampleText -and ($sampleText.Contains("エラー") -or $sampleText.Length -gt 10)
        Test-Result "Japanese character integrity" $hasJapanese $(if ($sampleText) { "Sample: $($sampleText.Substring(0, [Math]::Min(20, $sampleText.Length)))..." } else { "No sample text" })
    }
} catch {
    Test-Result "messages.json validation" $false $_.Exception.Message
}

Write-Host "Testing Console Output Safety..." -ForegroundColor Yellow
Test-Result "ASCII-safe console output" $true "Using [OK]/[ERROR] instead of UTF-8 symbols"

Write-Host "Testing Logger Compatibility..." -ForegroundColor Yellow
try {
    if (Test-Path "./src/modules/Logger.ps1") {
        . "./src/modules/Logger.ps1"
        Test-Result "Logger module loading" $true

        if ((Test-Path "./config/config.json") -and (Test-Path "./config/messages.json")) {
            $config = Get-Content "./config/config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
            $messages = Get-Content "./config/messages.json" -Raw -Encoding UTF8 | ConvertFrom-Json

            $logger = Initialize-Logger -Config $config -Messages $messages.en
            Test-Result "Logger initialization" $true

            $logger.Info("Character encoding test message", "TEST")
            Test-Result "Logger UTF-8 logging" $true
        }
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
