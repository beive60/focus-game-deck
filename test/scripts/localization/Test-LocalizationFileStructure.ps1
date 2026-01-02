<#
.SYNOPSIS
    Test the new individual language file structure

.DESCRIPTION
    Validates the new localization file structure where each language has its own
    JSON file instead of a monolithic messages.json. Tests include:
    - Presence of manifest.json
    - Individual language files exist
    - File size validation (should be smaller than monolithic file)
    - Content integrity (all required keys present)
    - Backward compatibility with legacy messages.json

.EXAMPLE
    .\Test-LocalizationFileStructure.ps1

.EXAMPLE
    .\Test-LocalizationFileStructure.ps1 -Verbose

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-12-22
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Get project root (navigate up from test/scripts/localization)
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Write-Host "=== Focus Game Deck - Localization File Structure Test ===" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )

    if ($Condition) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        $script:testsPassed++
        return $true
    } else {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($FailureMessage) {
            Write-Host "       $FailureMessage" -ForegroundColor Yellow
        }
        $script:testsFailed++
        return $false
    }
}

# Test 1: Localization directory exists
Write-Host "Test 1: Localization directory structure" -ForegroundColor Yellow
$localizationDir = Join-Path $projectRoot "localization"
Test-Assert "Localization directory exists" (Test-Path $localizationDir) "Directory not found: $localizationDir"

# Test 2: Manifest file exists
Write-Host "`nTest 2: Manifest file" -ForegroundColor Yellow
$manifestPath = Join-Path $localizationDir "manifest.json"
if (Test-Assert "manifest.json exists" (Test-Path $manifestPath)) {
    try {
        $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Test-Assert "Manifest has version" ($null -ne $manifest.version)
        Test-Assert "Manifest has supportedLanguages" ($null -ne $manifest.supportedLanguages)
        Test-Assert "Manifest has defaultLanguage" ($null -ne $manifest.defaultLanguage)

        $languageCount = $manifest.supportedLanguages.Count
        Write-Verbose "Supported languages: $languageCount"
        Test-Assert "Manifest has at least 5 languages" ($languageCount -ge 5) "Only $languageCount languages found"
    } catch {
        Test-Assert "Manifest is valid JSON" $false $_.Exception.Message
    }
}

# Test 3: Individual language files exist and key count consistency
Write-Host "`nTest 3: Individual language files and key consistency" -ForegroundColor Yellow
$expectedLanguages = @("ja", "en", "zh-CN", "ru", "fr", "es", "pt-BR", "id-ID")
$languageKeyCounts = @{}
$languageFileSizes = @{}

foreach ($lang in $expectedLanguages) {
    $langFile = Join-Path $localizationDir "$lang.json"
    if (Test-Assert "Language file exists: $lang.json" (Test-Path $langFile)) {
        $fileInfo = Get-Item $langFile
        $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
        $languageFileSizes[$lang] = $sizeKB
        Write-Verbose "  $lang.json size: $sizeKB KB"

        # Count keys in the language file
        try {
            $langData = Get-Content $langFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $keyCount = @($langData.PSObject.Properties).Count
            $languageKeyCounts[$lang] = $keyCount
            Write-Verbose "  $lang.json keys: $keyCount"

            # Test file is not empty and has reasonable key count (at least 100 keys)
            Test-Assert "  $lang.json has reasonable key count" ($keyCount -gt 100) "Keys: $keyCount"
        } catch {
            Test-Assert "  $lang.json is valid JSON" $false $_.Exception.Message
        }
    }
}

# Verify all languages have the same number of keys
Write-Host "`nTest 3b: Key count consistency across languages" -ForegroundColor Yellow
if ($languageKeyCounts.Count -gt 0) {
    $baseKeyCount = $languageKeyCounts["en"]
    $allConsistent = $true

    foreach ($lang in $expectedLanguages) {
        if ($languageKeyCounts.ContainsKey($lang)) {
            $keyCount = $languageKeyCounts[$lang]
            $matches = ($keyCount -eq $baseKeyCount)

            if (-not $matches) {
                $diff = $keyCount - $baseKeyCount
                $diffStr = if ($diff -gt 0) { "+$diff" } else { "$diff" }
                Test-Assert "  $lang key count matches baseline (en)" $false "Expected: $baseKeyCount, Got: $keyCount ($diffStr)"
                $allConsistent = $false
            } else {
                Write-Verbose "  ${lang}: $keyCount keys (matches baseline)"
            }
        }
    }

    if ($allConsistent) {
        Test-Assert "All languages have consistent key count" $true "All $($expectedLanguages.Count) languages have $baseKeyCount keys"
    }
}

# Verify file sizes are within reasonable range (detect outliers)
Write-Host "`nTest 3c: File size outlier detection" -ForegroundColor Yellow
if ($languageFileSizes.Count -gt 0) {
    $sizes = $languageFileSizes.Values
    $avgSize = ($sizes | Measure-Object -Average).Average
    $maxSize = ($sizes | Measure-Object -Maximum).Maximum
    $minSize = ($sizes | Measure-Object -Minimum).Minimum

    Write-Verbose "  Average size: $([math]::Round($avgSize, 2)) KB"
    Write-Verbose "  Min size: $minSize KB, Max size: $maxSize KB"

    # Allow 30% variance from average (accounts for language verbosity differences)
    $lowerBound = $avgSize * 0.7
    $upperBound = $avgSize * 1.3

    foreach ($lang in $expectedLanguages) {
        if ($languageFileSizes.ContainsKey($lang)) {
            $size = $languageFileSizes[$lang]
            $isWithinRange = ($size -ge $lowerBound) -and ($size -le $upperBound)
            $variance = [math]::Round((($size - $avgSize) / $avgSize) * 100, 1)

            Test-Assert "  $lang.json size within acceptable range" $isWithinRange "Size: $size KB (${variance}% from average)"
        }
    }
}

# Test 4: Load individual files using LanguageHelper
Write-Host "`nTest 4: Load messages using LanguageHelper" -ForegroundColor Yellow
$languageHelperPath = Join-Path $projectRoot "scripts/LanguageHelper.ps1"

if (Test-Assert "LanguageHelper.ps1 exists" (Test-Path $languageHelperPath)) {
    . $languageHelperPath

    foreach ($lang in @("ja", "en", "zh-CN")) {
        try {
            $messages = Get-LocalizedMessages -MessagesPath $localizationDir -LanguageCode $lang
            Test-Assert "Load $lang messages" ($null -ne $messages)

            # Verify common keys exist
            $requiredKeys = @("windowTitle", "gamesTabHeader", "okButton", "cancelButton")
            $allKeysPresent = $true
            foreach ($key in $requiredKeys) {
                if (-not ($messages.PSObject.Properties.Name -contains $key)) {
                    $allKeysPresent = $false
                    Write-Verbose "  Missing key: $key in $lang"
                }
            }
            Test-Assert "  $lang has required keys" $allKeysPresent "Some required keys are missing"
        } catch {
            Test-Assert "Load $lang messages" $false $_.Exception.Message
        }
    }
}

# Test 5: File size comparison with legacy format
Write-Host "`nTest 5: Performance - File size comparison" -ForegroundColor Yellow
$legacyFile = Join-Path $localizationDir "messages.json"

if (Test-Path $legacyFile) {
    $legacySize = (Get-Item $legacyFile).Length
    $legacySizeKB = [math]::Round($legacySize / 1KB, 2)

    # Calculate average individual file size
    $individualFiles = Get-ChildItem -Path $localizationDir -Filter "*.json" |
    Where-Object { $_.Name -match "^[a-z]{2}(-[A-Z]{2})?\.json$" }

    $totalIndividualSize = ($individualFiles | Measure-Object -Property Length -Sum).Sum
    $avgIndividualSize = $totalIndividualSize / $individualFiles.Count
    $avgIndividualSizeKB = [math]::Round($avgIndividualSize / 1KB, 2)

    $reduction = [math]::Round((1 - ($avgIndividualSize / $legacySize)) * 100, 1)

    Write-Host "  Legacy messages.json: $legacySizeKB KB" -ForegroundColor Cyan
    Write-Host "  Average individual file: $avgIndividualSizeKB KB" -ForegroundColor Cyan
    Write-Host "  Reduction per load: $reduction%" -ForegroundColor Green

    Test-Assert "Individual files are smaller" ($avgIndividualSize -lt $legacySize) "Expected smaller files"
    Test-Assert "Reduction is significant (>80%)" ($reduction -gt 80) "Reduction: $reduction%"
}

# Test 6: Backward compatibility
Write-Host "`nTest 6: Backward compatibility" -ForegroundColor Yellow
if (Test-Path $legacyFile) {
    try {
        # Try loading with legacy path
        . $languageHelperPath
        $messagesLegacy = Get-LocalizedMessages -MessagesPath $legacyFile -LanguageCode "en"
        Test-Assert "Can load from legacy messages.json" ($null -ne $messagesLegacy)
    } catch {
        Test-Assert "Can load from legacy messages.json" $false $_.Exception.Message
    }
} else {
    Write-Host "  [SKIP] Legacy messages.json not found (OK for new format only)" -ForegroundColor Yellow
}

# Test 7: Content consistency between formats
Write-Host "`nTest 7: Content consistency" -ForegroundColor Yellow
if (Test-Path $legacyFile) {
    try {
        # Load from both formats
        $legacyData = Get-Content $legacyFile -Raw -Encoding UTF8 | ConvertFrom-Json

        foreach ($lang in @("ja", "en")) {
            $legacyMessages = $legacyData.$lang
            $newMessages = Get-LocalizedMessages -MessagesPath $localizationDir -LanguageCode $lang

            $legacyKeys = @($legacyMessages.PSObject.Properties)
            $newKeys = @($newMessages.PSObject.Properties)

            $legacyKeyCount = $legacyKeys.Count
            $newKeyCount = $newKeys.Count

            $keysMatch = ($legacyKeyCount -eq $newKeyCount)
            Test-Assert "  $lang key count matches" $keysMatch "Legacy: $legacyKeyCount, New: $newKeyCount"
        }
    } catch {
        Test-Assert "Content consistency check" $false $_.Exception.Message
    }
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "[SUCCESS] All localization file structure tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILURE] Some tests failed. Please review the output above." -ForegroundColor Red
    exit 1
}
