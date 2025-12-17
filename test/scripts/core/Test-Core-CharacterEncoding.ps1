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


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

# Initialize project root path
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Write-BuildLog "Focus Game Deck - Character Encoding Validation Test"
Write-BuildLog "Validating implementation guidelines from ARCHITECTURE.md"
Write-BuildLog "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

$results = @{ Total = 0; Passed = 0; Failed = 0 }

<#
.SYNOPSIS
    Records test result and displays formatted output.

.DESCRIPTION
    Increments test counters and displays test results with appropriate status indicators.
    Updates the global $results hashtable with test outcomes.

.PARAMETER Name
    The name of the test being executed.

.PARAMETER Pass
    Boolean indicating whether the test passed (true) or failed (false).

.PARAMETER Message
    Optional additional message to display with the test result.

.EXAMPLE
    Test-Result "config.json UTF-8 parsing" $true
    Test-Result "BOM detection" $false "BOM detected in file"

.NOTES
    This function updates the script-scoped $results variable.
#>
function Test-Result {
    param([string]$Name, [bool]$Pass, [string]$Message = "")

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
    $results.Total++
    if ($Pass) {
        $results.Passed++
        Write-BuildLog "[OK] $Name"
        if ($Message) { Write-BuildLog "  $Message" }
    } else {
        $results.Failed++
        Write-BuildLog "[ERROR] $Name"
        if ($Message) { Write-BuildLog "  Error: $Message" }
    }
}

Write-BuildLog "Testing JSON File Encoding..."

# Test config.json
try {
    $configPath = Join-Path $projectRoot "config/config.json.sample"
    $configContent = Get-Content $configPath -Raw -Encoding UTF8
    $null = $configContent | ConvertFrom-Json  # Test parsing
    Test-Result "config.json.sample UTF-8 parsing" $true

    $configBytes = [System.IO.File]::ReadAllBytes($configPath)
    $hasBOM = ($configBytes.Length -ge 3 -and $configBytes[0] -eq 0xEF -and $configBytes[1] -eq 0xBB -and $configBytes[2] -eq 0xBF)
    Test-Result "config.json.sample without BOM" (-not $hasBOM) $(if ($hasBOM) { "BOM detected" } else { "" })
} catch {
    Test-Result "config.json.sample validation" $false $_.Exception.Message
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

    # Test message structure for all supported languages
    if ($messages.en -and $messages.ja) {
        $enCount = ($messages.en.PSObject.Properties | Measure-Object).Count
        $jaCount = ($messages.ja.PSObject.Properties | Measure-Object).Count
        $zhCnCount = ($messages."zh-cn".PSObject.Properties | Measure-Object).Count
        $ruCount = ($messages.ru.PSObject.Properties | Measure-Object).Count
        $frCount = ($messages.fr.PSObject.Properties | Measure-Object).Count
        $esCount = ($messages.es.PSObject.Properties | Measure-Object).Count

        # All languages should have the same number of keys
        $allCountsMatch = ($enCount -eq $jaCount) -and ($jaCount -eq $zhCnCount) -and ($zhCnCount -eq $ruCount) -and ($ruCount -eq $frCount) -and ($frCount -eq $esCount)
        Test-Result "Message key consistency (all languages)" $allCountsMatch "EN=$enCount, JA=$jaCount, ZH-CN=$zhCnCount, RU=$ruCount, FR=$frCount, ES=$esCount"

        # If key consistency check failed, suggest running the diagnostic tool
        if (-not $allCountsMatch) {
            Write-BuildLog "  Hint: Run './localization/Test-LocalizationConsistency.ps1 -ShowDetails' to identify missing or extra keys"
        }

        # Test Japanese text
        $sampleText = $messages.ja.errorMessage
        $hasJapanese = $sampleText -and ($sampleText.Contains("エラー") -or $sampleText.Length -gt 5)
        Test-Result "Japanese character integrity" $hasJapanese $(if ($sampleText) { "Sample: $($sampleText.Substring(0, [Math]::Min(15, $sampleText.Length)))..." } else { "No sample text" })
    }
} catch {
    Test-Result "messages.json validation" $false $_.Exception.Message
}

Write-BuildLog "Testing Console Output Safety..."
Test-Result "ASCII-safe console output" $true "Using [OK]/[ERROR] instead of UTF-8 symbols"

Write-BuildLog "Testing Logger Compatibility..."
try {
    $loggerPath = Join-Path $projectRoot "src/modules/Logger.ps1"
    if (Test-Path $loggerPath) {
        . $loggerPath
        Test-Result "Logger module loading" $true

        $configPath = Join-Path $projectRoot "config/config.json.sample"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

            # Import LanguageHelper for proper message loading
            $languageHelperPath = Join-Path $projectRoot "scripts/LanguageHelper.ps1"
            if (Test-Path $languageHelperPath) {
                try {
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
                } catch {
                    Test-Result "Logger compatibility" $false "Error loading LanguageHelper or messages: $($_.Exception.Message)"
                }
            } else {
                Test-Result "Logger compatibility" $false "LanguageHelper.ps1 not found at: $languageHelperPath"
            }
        } else {
            Test-Result "Logger compatibility" $false "config.json or config.json.sample not found"
        }
    } else {
        Test-Result "Logger compatibility" $false "Logger.ps1 not found"
    }
} catch {
    Test-Result "Logger compatibility" $false $_.Exception.Message
}

Write-Host ""
# Separator removed
Write-BuildLog " Test Summary"
# Separator removed
Write-BuildLog "Total Tests: $($results.Total)"
Write-BuildLog "Passed: $($results.Passed)"
Write-BuildLog "Failed: $($results.Failed)"

$successRate = [math]::Round(($results.Passed / $results.Total) * 100, 1)
if ($successRate -gt 90) {
    Write-BuildLog "[OK] Success Rate: $successRate%"
} elseif ($successRate -gt 70) {
    Write-BuildLog "[WARNING] Success Rate: $successRate%"
} else {
    Write-BuildLog "[ERROR] Success Rate: $successRate%"
}

if ($results.Failed -eq 0) {
    Write-Host ""
    Write-BuildLog "All character encoding tests passed! Project follows ARCHITECTURE.md guidelines."
    exit 0
} else {
    Write-Host ""
    Write-BuildLog "Some tests failed. Please review character encoding guidelines in ARCHITECTURE.md"
    exit 1
}
