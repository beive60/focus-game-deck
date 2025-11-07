# Test About Dialog Placeholder Replacement
# このスクリプトは Get-LocalizedMessage 関数のプレースホルダー置換機能をテストします

param(
    [switch]$Verbose
)

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Set encoding for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== About Dialog Placeholder Replacement Test ===" -ForegroundColor Cyan

try {
    # Import required modules
    $VersionModulePath = Join-Path $PSScriptRoot "Version.ps1"
    if (Test-Path $VersionModulePath) {
        . $VersionModulePath
        Write-Host "✓ Version module loaded successfully" -ForegroundColor Green
    } else {
        throw "Version module not found: $VersionModulePath"
    }

    $LanguageHelperPath = Join-Path $PSScriptRoot "scripts/LanguageHelper.ps1"
    if (Test-Path $LanguageHelperPath) {
        . $LanguageHelperPath
        Write-Host "✓ Language helper loaded successfully" -ForegroundColor Green
    } else {
        throw "Language helper not found: $LanguageHelperPath"
    }

    # Test version information retrieval
    Write-Host "--- Step 1: Testing version information ---" -ForegroundColor Yellow
    $versionInfo = Get-ProjectVersionInfo
    Write-Host "Version Info Type: $($versionInfo.GetType().Name)" -ForegroundColor Cyan
    Write-Host "Full Version: '$($versionInfo.FullVersion)'" -ForegroundColor Cyan
    Write-Host "Version String Length: $($versionInfo.FullVersion.Length)" -ForegroundColor Cyan

    # Test message loading
    Write-Host "--- Step 2: Testing message loading ---" -ForegroundColor Yellow
    $messagesPath = Join-Path $PSScriptRoot "../localization/messages.json"
    if (-not (Test-Path $messagesPath)) {
        throw "Messages file not found: $messagesPath"
    }

    $messagesContent = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "✓ Messages loaded successfully" -ForegroundColor Green

    # Test for each supported language
    $languages = @("ja", "en", "zh-CN")

    foreach ($lang in $languages) {
        Write-Host "--- Step 3: Testing language '$lang' ---" -ForegroundColor Yellow

        if (-not $messagesContent.$lang) {
            Write-Warning "Language '$lang' not found in messages"
            continue
        }

        $messages = $messagesContent.$lang
        $aboutTemplate = $messages.aboutMessage

        if (-not $aboutTemplate) {
            Write-Warning "aboutMessage not found for language '$lang'"
            continue
        }

        Write-Host "Original template: '$aboutTemplate'" -ForegroundColor Cyan
        Write-Host "Contains {0}: $($aboutTemplate -like '*{0}*')" -ForegroundColor Cyan

        # Test manual replacement
        $testVersion = $versionInfo.FullVersion
        $replacedMessage = $aboutTemplate -replace '\{0\}', $testVersion

        Write-Host "Test version: '$testVersion'" -ForegroundColor Magenta
        Write-Host "Manual replacement result: '$replacedMessage'" -ForegroundColor Green

        # Verify replacement worked
        $replacementWorked = $replacedMessage -ne $aboutTemplate -and -not ($replacedMessage -like '*{0}*')
        Write-Host "Replacement successful: $replacementWorked" -ForegroundColor $(if ($replacementWorked) { "Green" } else { "Red" })

        if ($replacementWorked) {
            Write-Host "✓ Language '$lang': SUCCESS" -ForegroundColor Green
        } else {
            Write-Host "✗ Language '$lang': FAILED" -ForegroundColor Red
        }
        Write-Host ""
    }

    # Test the actual Get-LocalizedMessage function from ConfigEditor
    Write-Host "--- Step 4: Testing Get-LocalizedMessage function ---" -ForegroundColor Yellow

    # Import the ConfigEditor script to access its functions
    $configEditorPath = Join-Path $PSScriptRoot "../gui/ConfigEditor.ps1"
    if (Test-Path $configEditorPath) {
        # Read the script content and extract just the Get-LocalizedMessage function
        $scriptContent = Get-Content $configEditorPath -Raw

        # Extract the function definition
        $functionPattern = '(?s)function Get-LocalizedMessage \{.*?^}'
        if ($scriptContent -match $functionPattern) {
            $functionCode = $matches[0]

            # Create a test environment
            $script:Messages = $messagesContent.ja  # Use Japanese for testing
            $script:CurrentLanguage = "ja"

            # Execute the function definition
            Invoke-Expression $functionCode

            # Test the function
            Write-Host "Testing Get-LocalizedMessage function..." -ForegroundColor Cyan
            $testResult = Get-LocalizedMessage -Key "aboutMessage" -Args @($versionInfo.FullVersion)
            Write-Host "Function result: '$testResult'" -ForegroundColor Green

            $functionWorked = $testResult -ne "aboutMessage" -and -not ($testResult -like '*{0}*')
            Write-Host "Function test successful: $functionWorked" -ForegroundColor $(if ($functionWorked) { "Green" } else { "Red" })

        } else {
            Write-Warning "Could not extract Get-LocalizedMessage function from ConfigEditor.ps1"
        }
    }

    Write-Host "=== Test Complete ===" -ForegroundColor Cyan

} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Exception details:" -ForegroundColor Red
    Write-Host $_.Exception -ForegroundColor Red
    exit 1
}
