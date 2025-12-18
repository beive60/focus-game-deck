<#
.SYNOPSIS
    [DEPRECATED] Validates localization key consistency across all supported languages.

.DESCRIPTION
    DEPRECATED: This script has been moved to ./test/Test-LocalizationConsistency.ps1
    The new version supports both application and website message files.

    Please use: ./test/Test-LocalizationConsistency.ps1 -Target App

    This script checks that all language files in messages.json have the same set of keys.
    It compares all supported languages (en, ja, zh-cn, ru, fr, es) and reports:
    - Missing keys in each language
    - Extra keys that shouldn't exist
    - Summary statistics for all languages

.PARAMETER MessagesPath
    Path to the messages.json file (default: ./localization/messages.json)

.PARAMETER BaseLanguage
    Base language to compare against (default: "en")

.PARAMETER ShowDetails
    Show detailed key differences for each language pair

.PARAMETER ExportReport
    Export results to a JSON report file at the specified path

.EXAMPLE
    .\Test-LocalizationConsistency.ps1
    Basic check with summary output

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -ShowDetails
    Show detailed missing/extra keys for each language

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -BaseLanguage "ja" -ShowDetails
    Use Japanese as base language and show details

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -ExportReport "report.json"
    Export validation results to a JSON file

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-12-17
#>

param(
    [string]$MessagesPath = (Join-Path $PSScriptRoot "messages.json"),
    [string]$BaseLanguage = "en",
    [switch]$ShowDetails,
    [string]$ExportReport = ""
)

$ErrorActionPreference = "Stop"

# Show deprecation warning
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Yellow
Write-Host "  DEPRECATION WARNING" -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Yellow
Write-Host "This script has been moved to: ./test/Test-LocalizationConsistency.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "The new version supports both application and website message files." -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  ./test/Test-LocalizationConsistency.ps1           # Check all files" -ForegroundColor White
Write-Host "  ./test/Test-LocalizationConsistency.ps1 -Target App     # App only" -ForegroundColor White
Write-Host "  ./test/Test-LocalizationConsistency.ps1 -Target Website # Website only" -ForegroundColor White
Write-Host ""
Write-Host "Continuing with legacy behavior (app messages only)..." -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 2

# ANSI color codes for better readability
$colorReset = "`e[0m"
$colorRed = "`e[91m"
$colorGreen = "`e[92m"
$colorYellow = "`e[93m"
$colorBlue = "`e[94m"
$colorCyan = "`e[96m"

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = $colorReset
    )
    Write-Host "${Color}${Message}${colorReset}"
}

function Get-LanguageKeyCount {
    param(
        [PSCustomObject]$Messages,
        [string]$Language
    )

    if (-not $Messages.$Language) {
        return 0
    }

    return ($Messages.$Language.PSObject.Properties | Measure-Object).Count
}

function Compare-LanguageKeys {
    param(
        [string[]]$BaseKeys,
        [string[]]$CompareKeys,
        [string]$BaseLang,
        [string]$CompareLang
    )

    $missingInCompare = Compare-Object $BaseKeys $CompareKeys | Where-Object { $_.SideIndicator -eq '<=' }
    $extraInCompare = Compare-Object $BaseKeys $CompareKeys | Where-Object { $_.SideIndicator -eq '=>' }

    return @{
        BaseLang = $BaseLang
        CompareLang = $CompareLang
        MissingKeys = @($missingInCompare | ForEach-Object { $_.InputObject })
        ExtraKeys = @($extraInCompare | ForEach-Object { $_.InputObject })
        MissingCount = ($missingInCompare | Measure-Object).Count
        ExtraCount = ($extraInCompare | Measure-Object).Count
    }
}

try {
    Write-ColorMessage "`n==================================================================" $colorCyan
    Write-ColorMessage "  Localization Key Consistency Validator" $colorCyan
    Write-ColorMessage "==================================================================" $colorCyan
    Write-Host ""

    # Check if messages.json exists
    if (-not (Test-Path $MessagesPath)) {
        Write-ColorMessage "Error: messages.json not found at: $MessagesPath" $colorRed
        exit 1
    }

    Write-ColorMessage "Loading messages from: $MessagesPath" $colorBlue
    $messages = Get-Content $MessagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Define supported languages
    $supportedLanguages = @("en", "ja", "zh-cn", "ru", "fr", "es")

    # Verify base language exists
    if (-not $messages.$BaseLanguage) {
        Write-ColorMessage "Error: Base language '$BaseLanguage' not found in messages.json" $colorRed
        exit 1
    }

    Write-ColorMessage "Base language: $BaseLanguage" $colorGreen
    Write-Host ""

    # Get keys for all languages
    $languageKeys = @{}
    $languageCounts = @{}

    foreach ($lang in $supportedLanguages) {
        if ($messages.$lang) {
            $keys = $messages.$lang.PSObject.Properties.Name | Sort-Object
            $languageKeys[$lang] = $keys
            $languageCounts[$lang] = $keys.Count
        } else {
            Write-ColorMessage "Warning: Language '$lang' not found in messages.json" $colorYellow
            $languageKeys[$lang] = @()
            $languageCounts[$lang] = 0
        }
    }

    # Display key counts
    Write-ColorMessage "Key Counts by Language:" $colorCyan
    Write-ColorMessage ("─" * 50) $colorCyan

    $baseKeyCount = $languageCounts[$BaseLanguage]
    $allMatch = $true

    foreach ($lang in $supportedLanguages) {
        $count = $languageCounts[$lang]
        if ($count -eq $baseKeyCount) {
            Write-Host "  $lang : $count keys " -NoNewline
            Write-ColorMessage "[OK]" $colorGreen
        } else {
            $allMatch = $false
            $diff = $count - $baseKeyCount
            $diffStr = if ($diff -gt 0) { "+$diff" } else { "$diff" }
            Write-Host "  $lang : $count keys ($diffStr) " -NoNewline
            Write-ColorMessage "[MISMATCH]" $colorRed
        }
    }

    Write-Host ""

    # Compare each language with base language
    $comparisonResults = @()
    $hasInconsistencies = $false

    foreach ($lang in $supportedLanguages) {
        if ($lang -eq $BaseLanguage) { continue }

        $comparison = Compare-LanguageKeys `
            -BaseKeys $languageKeys[$BaseLanguage] `
            -CompareKeys $languageKeys[$lang] `
            -BaseLang $BaseLanguage `
            -CompareLang $lang

        $comparisonResults += $comparison

        if ($comparison.MissingCount -gt 0 -or $comparison.ExtraCount -gt 0) {
            $hasInconsistencies = $true
        }
    }

    # Display summary
    Write-ColorMessage "Consistency Check Results:" $colorCyan
    Write-ColorMessage ("-" * 50) $colorCyan

    if ($allMatch -and -not $hasInconsistencies) {
        Write-ColorMessage "[OK] All languages have consistent keys!" $colorGreen
        Write-ColorMessage "  Total keys: $baseKeyCount" $colorGreen
    } else {
        Write-ColorMessage "[ERROR] Inconsistencies detected!" $colorRed
        Write-Host ""

        foreach ($result in $comparisonResults) {
            if ($result.MissingCount -gt 0 -or $result.ExtraCount -gt 0) {
                Write-ColorMessage "Language: $($result.CompareLang)" $colorYellow

                if ($result.MissingCount -gt 0) {
                    Write-ColorMessage "  Missing keys: $($result.MissingCount)" $colorRed
                }

                if ($result.ExtraCount -gt 0) {
                    Write-ColorMessage "  Extra keys: $($result.ExtraCount)" $colorYellow
                }

                # Show details if requested
                if ($ShowDetails) {
                    if ($result.MissingKeys.Count -gt 0) {
                        Write-ColorMessage "  Missing keys in $($result.CompareLang):" $colorRed
                        foreach ($key in $result.MissingKeys) {
                            Write-Host "    - $key"
                        }
                    }

                    if ($result.ExtraKeys.Count -gt 0) {
                        Write-ColorMessage "  Extra keys in $($result.CompareLang):" $colorYellow
                        foreach ($key in $result.ExtraKeys) {
                            Write-Host "    - $key"
                        }
                    }
                }

                Write-Host ""
            }
        }
    }

    # Export report if requested
    if ($ExportReport) {
        $reportPath = $ExportReport
        if (-not [System.IO.Path]::IsPathRooted($reportPath)) {
            $reportPath = Join-Path (Get-Location) $reportPath
        }

        $report = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            BaseLanguage = $BaseLanguage
            SupportedLanguages = $supportedLanguages
            KeyCounts = $languageCounts
            ComparisonResults = $comparisonResults
            AllConsistent = ($allMatch -and -not $hasInconsistencies)
        }

        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
        Write-ColorMessage "Report exported to: $reportPath" $colorBlue
    }

    Write-Host ""
    Write-ColorMessage ("=" * 66) $colorCyan

    # Exit with appropriate code
    if ($allMatch -and -not $hasInconsistencies) {
        Write-ColorMessage "Status: PASSED - All localization keys are consistent" $colorGreen
        Write-ColorMessage ("=" * 66) $colorCyan
        exit 0
    } else {
        Write-ColorMessage "Status: FAILED - Please add missing keys to inconsistent languages" $colorRed
        Write-ColorMessage ("=" * 66) $colorCyan
        exit 1
    }

} catch {
    Write-ColorMessage "`nError: $($_.Exception.Message)" $colorRed
    Write-ColorMessage $_.ScriptStackTrace $colorRed
    exit 1
}
