<#
.SYNOPSIS
    Validates localization key consistency across all supported languages.

.DESCRIPTION
    This script checks that all language files in messages JSON files have the same set of keys.
    It supports both application messages (localization/messages.json) and website messages
    (website/messages-website.json). Compares all supported languages (en, ja, zh-cn, ru, fr, es)
    and reports:
    - Missing keys in each language
    - Extra keys that shouldn't exist
    - Summary statistics for all languages

.PARAMETER Path
    Path to a specific messages JSON file to validate. If not specified, validates all known
    message files (localization/messages.json and website/messages-website.json).

.PARAMETER Target
    Specifies which message files to validate: "App", "Website", or "All" (default: "All").

.PARAMETER BaseLanguage
    Base language to compare against (default: "en")

.PARAMETER ShowDetails
    Show detailed key differences for each language pair

.PARAMETER ExportReport
    Export results to a JSON report file at the specified path

.EXAMPLE
    .\Test-LocalizationConsistency.ps1
    Validates all message files (app and website) with summary output

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -Target App -ShowDetails
    Validates only application messages and shows detailed missing/extra keys

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -Target Website
    Validates only website messages

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -Path "./localization/messages.json" -ShowDetails
    Validates a specific message file with detailed output

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -BaseLanguage "ja" -ShowDetails
    Use Japanese as base language and show details

.EXAMPLE
    .\Test-LocalizationConsistency.ps1 -ExportReport "report.json"
    Export validation results to a JSON file

.NOTES
    Author: Focus Game Deck Team
    Version: 2.0.0
    Created: 2025-12-17
    Updated: 2025-12-18
#>

param(
    [string]$Path = "",
    [ValidateSet("All", "App", "Website")]
    [string]$Target = "All",
    [string]$BaseLanguage = "en",
    [switch]$ShowDetails,
    [string]$ExportReport = ""
)

$ErrorActionPreference = "Stop"

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

function Test-MessageFile {
    param(
        [string]$FilePath,
        [string]$BaseLanguage,
        [switch]$ShowDetails
    )

    Write-ColorMessage "`nValidating: $FilePath" $colorBlue

    if (-not (Test-Path $FilePath)) {
        Write-ColorMessage "  File not found: $FilePath" $colorRed
        return @{
            FilePath = $FilePath
            Success = $false
            Error = "File not found"
        }
    }

    try {
        $messages = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-ColorMessage "  Failed to parse JSON: $($_.Exception.Message)" $colorRed
        return @{
            FilePath = $FilePath
            Success = $false
            Error = "JSON parse error: $($_.Exception.Message)"
        }
    }

    # Define supported languages
    $supportedLanguages = @("en", "ja", "zh-cn", "ru", "fr", "es")

    # Verify base language exists
    if (-not $messages.$BaseLanguage) {
        Write-ColorMessage "  Base language '$BaseLanguage' not found" $colorRed
        return @{
            FilePath = $FilePath
            Success = $false
            Error = "Base language '$BaseLanguage' not found"
        }
    }

    # Get keys for all languages
    $languageKeys = @{}
    $languageCounts = @{}

    foreach ($lang in $supportedLanguages) {
        if ($messages.$lang) {
            $keys = $messages.$lang.PSObject.Properties.Name | Sort-Object
            $languageKeys[$lang] = $keys
            $languageCounts[$lang] = $keys.Count
        } else {
            Write-ColorMessage "  Warning: Language '$lang' not found" $colorYellow
            $languageKeys[$lang] = @()
            $languageCounts[$lang] = 0
        }
    }

    # Display key counts
    Write-ColorMessage "  Key Counts by Language:" $colorCyan
    Write-ColorMessage ("  " + ("─" * 48)) $colorCyan

    $baseKeyCount = $languageCounts[$BaseLanguage]
    $allMatch = $true

    foreach ($lang in $supportedLanguages) {
        $count = $languageCounts[$lang]
        if ($count -eq $baseKeyCount) {
            Write-Host "    $lang : $count keys " -NoNewline
            Write-ColorMessage "[OK]" $colorGreen
        } else {
            $allMatch = $false
            $diff = $count - $baseKeyCount
            $diffStr = if ($diff -gt 0) { "+$diff" } else { "$diff" }
            Write-Host "    $lang : $count keys ($diffStr) " -NoNewline
            Write-ColorMessage "[MISMATCH]" $colorRed
        }
    }

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

    # Display inconsistencies if found
    if ($hasInconsistencies) {
        Write-Host ""
        foreach ($result in $comparisonResults) {
            if ($result.MissingCount -gt 0 -or $result.ExtraCount -gt 0) {
                Write-ColorMessage "  Language: $($result.CompareLang)" $colorYellow

                if ($result.MissingCount -gt 0) {
                    Write-ColorMessage "    Missing keys: $($result.MissingCount)" $colorRed
                }

                if ($result.ExtraCount -gt 0) {
                    Write-ColorMessage "    Extra keys: $($result.ExtraCount)" $colorYellow
                }

                # Show details if requested
                if ($ShowDetails) {
                    if ($result.MissingKeys.Count -gt 0) {
                        Write-ColorMessage "    Missing keys in $($result.CompareLang):" $colorRed
                        foreach ($key in $result.MissingKeys) {
                            Write-Host "      - $key"
                        }
                    }

                    if ($result.ExtraKeys.Count -gt 0) {
                        Write-ColorMessage "    Extra keys in $($result.CompareLang):" $colorYellow
                        foreach ($key in $result.ExtraKeys) {
                            Write-Host "      - $key"
                        }
                    }
                }

                Write-Host ""
            }
        }
    }

    return @{
        FilePath = $FilePath
        Success = ($allMatch -and -not $hasInconsistencies)
        AllMatch = $allMatch
        HasInconsistencies = $hasInconsistencies
        KeyCounts = $languageCounts
        ComparisonResults = $comparisonResults
    }
}

try {
    Write-ColorMessage "`n==================================================================" $colorCyan
    Write-ColorMessage "  Localization Key Consistency Validator" $colorCyan
    Write-ColorMessage "==================================================================" $colorCyan
    Write-Host ""

    $projectRoot = Split-Path -Parent $PSScriptRoot

    # Determine which files to check
    $filesToCheck = @()

    if ($Path) {
        # Specific path provided
        if ([System.IO.Path]::IsPathRooted($Path)) {
            $filesToCheck += $Path
        } else {
            $filesToCheck += Join-Path $projectRoot $Path
        }
    } else {
        # Check based on Target parameter
        $appMessagesPath = Join-Path $projectRoot "localization/messages.json"
        $websiteMessagesPath = Join-Path $projectRoot "website/messages-website.json"

        switch ($Target) {
            "App" {
                if (Test-Path $appMessagesPath) {
                    $filesToCheck += $appMessagesPath
                }
            }
            "Website" {
                if (Test-Path $websiteMessagesPath) {
                    $filesToCheck += $websiteMessagesPath
                }
            }
            "All" {
                if (Test-Path $appMessagesPath) {
                    $filesToCheck += $appMessagesPath
                }
                if (Test-Path $websiteMessagesPath) {
                    $filesToCheck += $websiteMessagesPath
                }
            }
        }
    }

    if ($filesToCheck.Count -eq 0) {
        Write-ColorMessage "Error: No message files found to validate" $colorRed
        exit 1
    }

    Write-ColorMessage "Base language: $BaseLanguage" $colorGreen
    Write-ColorMessage "Files to check: $($filesToCheck.Count)" $colorBlue

    # Test each file
    $allResults = @()
    $overallSuccess = $true

    foreach ($file in $filesToCheck) {
        $result = Test-MessageFile -FilePath $file -BaseLanguage $BaseLanguage -ShowDetails:$ShowDetails
        $allResults += $result

        if (-not $result.Success) {
            $overallSuccess = $false
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
            Target = $Target
            FilesChecked = $filesToCheck.Count
            Results = $allResults
            OverallSuccess = $overallSuccess
        }

        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
        Write-ColorMessage "`nReport exported to: $reportPath" $colorBlue
    }

    Write-Host ""
    Write-ColorMessage ("=" * 66) $colorCyan

    # Exit with appropriate code
    if ($overallSuccess) {
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
