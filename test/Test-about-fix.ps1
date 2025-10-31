# Comprehensive test for the fixed Get-LocalizedMessage function
# このスクリプトは修正されたGet-LocalizedMessage関数の動作を包括的にテストします

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

Write-Host "=== Focus Game Deck - About Dialog Fix Test ===" -ForegroundColor Cyan
Write-Host "Testing the fix for placeholder replacement in Get-LocalizedMessage" -ForegroundColor White
Write-Host ""

try {
    # Load required modules
    . "$PSScriptRoot/Version.ps1"

    # Load messages
    $messagesPath = Join-Path $PSScriptRoot "../localization/messages.json"
    $messagesContent = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Get version info
    $versionInfo = Get-ProjectVersionInfo
    Write-Host "Project Version: $($versionInfo.FullVersion)" -ForegroundColor Yellow
    Write-Host ""

    # Test each language
    $languages = @("ja", "en", "zh-CN")

    foreach ($lang in $languages) {
        Write-Host "--- Testing Language: $lang ---" -ForegroundColor Green

        # Set up script variables
        $script:Messages = $messagesContent.$lang
        $script:CurrentLanguage = $lang

        # Load the fixed Get-LocalizedMessage function from ConfigEditor.ps1
        $configEditorContent = Get-Content "../gui/ConfigEditor.ps1" -Raw
        $functionMatch = [regex]::Match($configEditorContent, '(?s)function Get-LocalizedMessage \{.*?^}', [System.Text.RegularExpressions.RegexOptions]::Multiline)

        if ($functionMatch.Success) {
            $functionCode = $functionMatch.Value
            Invoke-Expression $functionCode

            # Test the function
            Write-Host "Original template:" -ForegroundColor Cyan
            Write-Host "'$($script:Messages.aboutMessage)'" -ForegroundColor White
            Write-Host ""

            Write-Host "Calling Get-LocalizedMessage with version '$($versionInfo.FullVersion)'..." -ForegroundColor Magenta
            $result = Get-LocalizedMessage -Key "aboutMessage" -Arguments @($versionInfo.FullVersion)

            Write-Host ""
            Write-Host "Result:" -ForegroundColor Green
            Write-Host "'$result'" -ForegroundColor White
            Write-Host ""

            # Verify the replacement
            $hasPlaceholder = $result -like '*{0}*'
            $hasVersion = $result -like "*$($versionInfo.FullVersion)*"
            $success = (-not $hasPlaceholder) -and $hasVersion

            Write-Host "Verification:" -ForegroundColor Yellow
            Write-Host "  Contains {0}: $hasPlaceholder $(if ($hasPlaceholder) { '[❌ FAIL]' } else { '[✅ PASS]' })" -ForegroundColor $(if ($hasPlaceholder) { "Red" } else { "Green" })
            Write-Host "  Contains version: $hasVersion $(if ($hasVersion) { '[✅ PASS]' } else { '[❌ FAIL]' })" -ForegroundColor $(if ($hasVersion) { "Green" } else { "Red" })
            Write-Host "  Overall: $success $(if ($success) { '[✅ SUCCESS]' } else { '[❌ FAILED]' })" -ForegroundColor $(if ($success) { "Green" } else { "Red" })

            if (-not $success) {
                Write-Host "❌ Test failed for language $lang" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Warning "Could not extract Get-LocalizedMessage function from ConfigEditor.ps1"
            exit 1
        }

        Write-Host ""
    }

    Write-Host "✅ All tests passed! The About dialog placeholder replacement has been fixed." -ForegroundColor Green
    Write-Host ""

    if ($Interactive) {
        Write-Host "Interactive test mode - launching ConfigEditor..." -ForegroundColor Cyan
        Write-Host "1. Open the ConfigEditor GUI" -ForegroundColor Yellow
        Write-Host "2. Go to Help menu > About Focus Game Deck" -ForegroundColor Yellow
        Write-Host "3. Verify that the version is displayed correctly as 'バージョン: 1.0.1-alpha'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press Enter to launch ConfigEditor..." -ForegroundColor White
        Read-Host

        Start-Process -FilePath "pwsh" -ArgumentList @("-ExecutionPolicy", "Bypass", "-File", "../gui/ConfigEditor.ps1")
    }

    Write-Host "=== Test Complete ===" -ForegroundColor Cyan

} catch {
    Write-Host "❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception -ForegroundColor Red
    exit 1
}
