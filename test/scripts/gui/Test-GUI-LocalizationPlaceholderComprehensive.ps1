<#
.SYNOPSIS
    Comprehensive test for the fixed Get-LocalizedMessage function.

.DESCRIPTION
    This script performs comprehensive testing of the corrected Get-LocalizedMessage function's
    placeholder replacement functionality. It validates that version information is correctly
    inserted into localized About dialog messages across all supported languages (Japanese,
    English, Chinese Simplified). The test extracts the actual Get-LocalizedMessage function
    from ConfigEditor.ps1 and validates its behavior in a controlled environment.

.PARAMETER Interactive
    Enables interactive test mode. When specified, the script will prompt to launch the
    ConfigEditor GUI after successful test completion, allowing manual verification of
    the About dialog display.

.EXAMPLE
    .\Test-about-fix.ps1
    Runs the comprehensive placeholder replacement test in automated mode.

.EXAMPLE
    .\Test-about-fix.ps1 -Interactive
    Runs the test and prompts to launch ConfigEditor for manual verification.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0

    Test Coverage:
    - Version information retrieval from Version.ps1
    - Message template loading from messages.json
    - Placeholder replacement for Japanese (ja)
    - Placeholder replacement for English (en)
    - Placeholder replacement for Chinese Simplified (zh-CN)
    - Actual Get-LocalizedMessage function extraction and validation

    Exit Codes:
    - 0: All tests passed successfully
    - 1: One or more tests failed

    Dependencies:
    - Version.ps1 module for version information
    - localization/messages.json for message templates
    - gui/ConfigEditor.ps1 for Get-LocalizedMessage function source
#>

param(
    [switch]$Interactive
)

# Set encoding for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Enable verbose output
$VerbosePreference = "Continue"

Write-Host "=== Focus Game Deck - About Dialog Fix Test ==="
Write-Host "Testing the fix for placeholder replacement in Get-LocalizedMessage"
Write-Host ""

try {
    # Load required modules
    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $versionModulePath = Join-Path -Path $projectRoot -ChildPath "build-tools/Version.ps1"
    . $versionModulePath

    # Load messages
    $messagesPath = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
    $messagesContent = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Get version info
    $versionInfo = Get-ProjectVersionInfo
    Write-Host "Project Version: $($versionInfo.FullVersion)"
    Write-Host ""

    # Test each language
    $languages = @("ja", "en", "zh-CN")

    foreach ($lang in $languages) {
        Write-Host "--- Testing Language: $lang ---"

        # Set up script variables
        $script:Messages = $messagesContent.$lang
        $script:CurrentLanguage = $lang

        # Load the fixed Get-LocalizedMessage function from ConfigEditor.ps1
        $configEditorContent = Get-Content "../gui/ConfigEditor.ps1" -Raw -Encoding UTF8
        $functionMatch = [regex]::Match($configEditorContent, '(?s)function Get-LocalizedMessage \{.*?^}', [System.Text.RegularExpressions.RegexOptions]::Multiline)

        if ($functionMatch.Success) {
            $functionCode = $functionMatch.Value
            Invoke-Expression $functionCode

            # Test the function
            Write-Host "Original template:"
            Write-Host "'$($script:Messages.aboutMessage)'"
            Write-Host ""

            Write-Host "Calling Get-LocalizedMessage with version '$($versionInfo.FullVersion)'..."
            $result = Get-LocalizedMessage -Key "aboutMessage" -Arguments @($versionInfo.FullVersion)

            Write-Host ""
            Write-Host "Result:"
            Write-Host "'$result'"
            Write-Host ""

            # Verify the replacement
            $hasPlaceholder = $result -like '*{0}*'
            $hasVersion = $result -like "*$($versionInfo.FullVersion)*"
            $success = (-not $hasPlaceholder) -and $hasVersion

            Write-Host "Verification:"
            Write-Host "  Contains {0}: $hasPlaceholder $(if ($hasPlaceholder) { '[ERROR]' } else { '[OK]' })"
            Write-Host "  Contains version: $hasVersion $(if ($hasVersion) { '[OK]' } else { '[ERROR]' })"
            Write-Host "  Overall: $success $(if ($success) { '[OK] SUCCESS' } else { '[ERROR] FAILED' })"

            if (-not $success) {
                Write-Host "[ERROR] Test failed for language $lang"
                exit 1
            }
        } else {
            Write-Warning "Could not extract Get-LocalizedMessage function from ConfigEditor.ps1"
            exit 1
        }

        Write-Host ""
    }

    Write-Host "[OK] All tests passed! The About dialog placeholder replacement has been fixed."
    Write-Host ""

    if ($Interactive) {
        Write-Host "Interactive test mode - launching ConfigEditor..."
        Write-Host "1. Open the ConfigEditor GUI"
        Write-Host "2. Go to Help menu > About Focus Game Deck"
        Write-Host "3. Verify that the version is displayed correctly as 'バージョン: 1.0.1-alpha'"
        Write-Host ""
        Write-Host "Press Enter to launch ConfigEditor..."
        Read-Host

        Start-Process -FilePath "pwsh" -ArgumentList @("-ExecutionPolicy", "Bypass", "-File", "../gui/ConfigEditor.ps1")
    }

    Write-Host "=== Test Complete ==="

} catch {
    Write-Host "[ERROR] Test failed with error: $($_.Exception.Message)"
    Write-Host $_.Exception
    exit 1
}
