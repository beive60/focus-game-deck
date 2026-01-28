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
    .\Test-LocalizationConsistency.ps1 -Path "./localization" -ShowDetails
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

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
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

function Test-IndividualLanguageFiles {
    param(
        [string]$LocalizationDir,
        [string]$BaseLanguage,
        [switch]$ShowDetails
    )

    Write-ColorMessage "`nValidating: Individual language files in $LocalizationDir" "Blue"

    if (-not (Test-Path $LocalizationDir)) {
        Write-ColorMessage "  Directory not found: $LocalizationDir" "Red"
        return @{
            Directory = $LocalizationDir
            Success = $false
            Error = "Directory not found"
        }
    }

    # Map file names to language codes
    $fileToLangMap = @{
        "en.json" = "en"
        "ja.json" = "ja"
        "zh-CN.json" = "zh-cn"
        "ru.json" = "ru"
        "fr.json" = "fr"
        "es.json" = "es"
        "id-ID.json" = "id-id"
        "pt-BR.json" = "pt-br"
    }

    # Define supported languages
    $supportedLanguages = @("en", "ja", "zh-cn", "ru", "fr", "es", "id-id", "pt-br")

    # Load all language files
    $languageKeys = @{}
    $languageCounts = @{}
    $loadErrors = @()

    foreach ($lang in $supportedLanguages) {
        # Find the file for this language
        $fileName = ($fileToLangMap.GetEnumerator() | Where-Object { $_.Value -eq $lang }).Name
        $filePath = Join-Path $LocalizationDir $fileName

        if (Test-Path $filePath) {
            try {
                $content = Get-Content $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
                $keys = $content.PSObject.Properties.Name | Sort-Object
                $languageKeys[$lang] = $keys
                $languageCounts[$lang] = $keys.Count
            } catch {
                $loadErrors += "Failed to load ${fileName}: $($_.Exception.Message)"
                $languageKeys[$lang] = @()
                $languageCounts[$lang] = 0
            }
        } else {
            Write-ColorMessage "  Warning: Language file not found: $fileName" "Yellow"
            $languageKeys[$lang] = @()
            $languageCounts[$lang] = 0
        }
    }

    # Check if base language exists
    if (-not $languageKeys[$BaseLanguage] -or $languageKeys[$BaseLanguage].Count -eq 0) {
        Write-ColorMessage "  Base language '$BaseLanguage' not found or empty" "Red"
        return @{
            Directory = $LocalizationDir
            Success = $false
            Error = "Base language '$BaseLanguage' not found or empty"
        }
    }

    # Display any load errors
    if ($loadErrors.Count -gt 0) {
        Write-ColorMessage "  Load Errors:" "Red"
        foreach ($error in $loadErrors) {
            Write-Host "    $error"
        }
    }

    # Display key counts
    Write-ColorMessage "  Key Counts by Language:" "Cyan"
    Write-ColorMessage ("  " + ("-" * 48)) "Cyan"

    $baseKeyCount = $languageCounts[$BaseLanguage]
    $allMatch = $true

    foreach ($lang in $supportedLanguages) {
        $count = $languageCounts[$lang]
        if ($count -eq 0) {
            Write-Host "    $lang : $count keys " -NoNewline
            Write-ColorMessage "[NOT FOUND]" "Yellow"
            $allMatch = $false
        } elseif ($count -eq $baseKeyCount) {
            Write-Host "    $lang : $count keys " -NoNewline
            Write-ColorMessage "[OK]" "Green"
        } else {
            $allMatch = $false
            $diff = $count - $baseKeyCount
            $diffStr = if ($diff -gt 0) { "+$diff" } else { "$diff" }
            Write-Host "    $lang : $count keys ($diffStr) " -NoNewline
            Write-ColorMessage "[MISMATCH]" "Red"
        }
    }

    # Compare each language with base language
    $comparisonResults = @()
    $hasInconsistencies = $false

    foreach ($lang in $supportedLanguages) {
        if ($lang -eq $BaseLanguage) { continue }
        if ($languageKeys[$lang].Count -eq 0) { continue }

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
                Write-ColorMessage "  Language: $($result.CompareLang)" "Yellow"

                if ($result.MissingCount -gt 0) {
                    Write-ColorMessage "    Missing keys: $($result.MissingCount)" "Red"
                }

                if ($result.ExtraCount -gt 0) {
                    Write-ColorMessage "    Extra keys: $($result.ExtraCount)" "Yellow"
                }

                # Show details if requested
                if ($ShowDetails) {
                    if ($result.MissingKeys.Count -gt 0) {
                        Write-ColorMessage "    Missing keys in $($result.CompareLang):" "Red"
                        foreach ($key in $result.MissingKeys) {
                            Write-Host "      - $key"
                        }
                    }

                    if ($result.ExtraKeys.Count -gt 0) {
                        Write-ColorMessage "    Extra keys in $($result.CompareLang):" "Yellow"
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
        Directory = $LocalizationDir
        Success = ($allMatch -and -not $hasInconsistencies -and $loadErrors.Count -eq 0)
        AllMatch = $allMatch
        HasInconsistencies = $hasInconsistencies
        KeyCounts = $languageCounts
        ComparisonResults = $comparisonResults
        LoadErrors = $loadErrors
    }
}

function Test-MessageFile {
    param(
        [string]$FilePath,
        [string]$BaseLanguage,
        [switch]$ShowDetails
    )

    Write-ColorMessage "`nValidating: $FilePath" "Blue"

    if (-not (Test-Path $FilePath)) {
        Write-ColorMessage "  File not found: $FilePath" "Red"
        return @{
            FilePath = $FilePath
            Success = $false
            Error = "File not found"
        }
    }

    try {
        $messages = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-ColorMessage "  Failed to parse JSON: $($_.Exception.Message)" "Red"
        return @{
            FilePath = $FilePath
            Success = $false
            Error = "JSON parse error: $($_.Exception.Message)"
        }
    }

    # Define supported languages
    $supportedLanguages = @("en", "ja", "zh-cn", "ru", "fr", "es", "id-id", "pt-br")

    # Verify base language exists
    if (-not $messages.$BaseLanguage) {
        Write-ColorMessage "  Base language '$BaseLanguage' not found" "Red"
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
            Write-ColorMessage "  Warning: Language '$lang' not found" "Yellow"
            $languageKeys[$lang] = @()
            $languageCounts[$lang] = 0
        }
    }

    # Display key counts
    Write-ColorMessage "  Key Counts by Language:" "Cyan"
    Write-ColorMessage ("  " + ("-" * 48)) "Cyan"

    $baseKeyCount = $languageCounts[$BaseLanguage]
    $allMatch = $true

    foreach ($lang in $supportedLanguages) {
        $count = $languageCounts[$lang]
        if ($count -eq $baseKeyCount) {
            Write-Host "    $lang : $count keys " -NoNewline
            Write-ColorMessage "[OK]" "Green"
        } else {
            $allMatch = $false
            $diff = $count - $baseKeyCount
            $diffStr = if ($diff -gt 0) { "+$diff" } else { "$diff" }
            Write-Host "    $lang : $count keys ($diffStr) " -NoNewline
            Write-ColorMessage "[MISMATCH]" "Red"
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
                Write-ColorMessage "  Language: $($result.CompareLang)" "Yellow"

                if ($result.MissingCount -gt 0) {
                    Write-ColorMessage "    Missing keys: $($result.MissingCount)" "Red"
                }

                if ($result.ExtraCount -gt 0) {
                    Write-ColorMessage "    Extra keys: $($result.ExtraCount)" "Yellow"
                }

                # Show details if requested
                if ($ShowDetails) {
                    if ($result.MissingKeys.Count -gt 0) {
                        Write-ColorMessage "    Missing keys in $($result.CompareLang):" "Red"
                        foreach ($key in $result.MissingKeys) {
                            Write-Host "      - $key"
                        }
                    }

                    if ($result.ExtraKeys.Count -gt 0) {
                        Write-ColorMessage "    Extra keys in $($result.CompareLang):" "Yellow"
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
    Write-ColorMessage "`n==================================================================" "Cyan"
    Write-ColorMessage "  Localization Key Consistency Validator" "Cyan"
    Write-ColorMessage "==================================================================" "Cyan"
    Write-Host ""

    # Get project root (navigate up from test/scripts/localization)
    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

    # Determine what to check
    $checkIndividualFiles = $false
    $localizationDirToCheck = ""
    $filesToCheck = @()

    if ($Path) {
        # Specific path provided
        $resolvedPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $projectRoot $Path }

        if (Test-Path $resolvedPath -PathType Container) {
            # It's a directory - check for individual files
            $manifestPath = Join-Path $resolvedPath "manifest.json"
            if (Test-Path $manifestPath) {
                $checkIndividualFiles = $true
                $localizationDirToCheck = $resolvedPath
            } else {
                Write-ColorMessage "Error: Directory does not contain manifest.json: $resolvedPath" "Red"
                exit 1
            }
        } else {
            # It's a file - use legacy format
            $filesToCheck += $resolvedPath
        }
    } else {
        # Check based on Target parameter
        $appMessagesDir = Join-Path $projectRoot "localization"
        $websiteMessagesPath = Join-Path $projectRoot "website/messages-website.json"

        # Check if new format (individual files) or legacy format (messages.json)
        $manifestPath = Join-Path $appMessagesDir "manifest.json"
        if (Test-Path $manifestPath) {
            Write-Verbose "Using new individual language file format"
            $useNewFormat = $true
        } else {
            Write-Verbose "Using legacy monolithic messages.json format"
            $useNewFormat = $false
            $appMessagesPath = Join-Path $projectRoot "localization/messages.json"
        }

        switch ($Target) {
            "App" {
                if ($useNewFormat) {
                    $checkIndividualFiles = $true
                    $localizationDirToCheck = $appMessagesDir
                } elseif (Test-Path $appMessagesPath) {
                    $filesToCheck += $appMessagesPath
                }
            }
            "Website" {
                if (Test-Path $websiteMessagesPath) {
                    $filesToCheck += $websiteMessagesPath
                }
            }
            "All" {
                if ($useNewFormat) {
                    $checkIndividualFiles = $true
                    $localizationDirToCheck = $appMessagesDir
                } elseif (Test-Path $appMessagesPath) {
                    $filesToCheck += $appMessagesPath
                }
                if (Test-Path $websiteMessagesPath) {
                    $filesToCheck += $websiteMessagesPath
                }
            }
        }
    }

    if (-not $checkIndividualFiles -and $filesToCheck.Count -eq 0) {
        Write-ColorMessage "Error: No message files found to validate" "Red"
        exit 1
    }

    Write-ColorMessage "Base language: $BaseLanguage" "Green"
    if ($checkIndividualFiles) {
        Write-ColorMessage "Checking: Individual language files" "Blue"
    } else {
        Write-ColorMessage "Files to check: $($filesToCheck.Count)" "Blue"
    }

    # Test files
    $allResults = @()
    $overallSuccess = $true

    # Check individual files if using new format
    if ($checkIndividualFiles) {
        $result = Test-IndividualLanguageFiles -LocalizationDir $localizationDirToCheck -BaseLanguage $BaseLanguage -ShowDetails:$ShowDetails
        $allResults += $result
        if (-not $result.Success) {
            $overallSuccess = $false
        }
    }

    # Check legacy format files
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
        Write-ColorMessage "`nReport exported to: $reportPath" "Blue"
    }

    Write-Host ""
    Write-ColorMessage ("=" * 66) "Cyan"

    # Exit with appropriate code
    if ($overallSuccess) {
        Write-ColorMessage "Status: PASSED - All localization keys are consistent" "Green"
        Write-ColorMessage ("=" * 66) "Cyan"
        exit 0
    } else {
        Write-ColorMessage "Status: FAILED - Please add missing keys to inconsistent languages" "Red"
        Write-ColorMessage ("=" * 66) "Cyan"
        exit 1
    }

} catch {
    Write-ColorMessage "`nError: $($_.Exception.Message)" "Red"
    Write-ColorMessage $_.ScriptStackTrace "Red"
    exit 1
}
