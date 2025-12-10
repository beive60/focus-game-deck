# Test About Dialog Placeholder Replacement
# This script tests the replacement of placeholders in the About dialog messages

param(
    [switch]$Verbose
)


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Set encoding for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-BuildLog "=== About Dialog Placeholder Replacement Test ==="
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$VersionModulePath = Join-Path -Path $projectRoot -ChildPath "build-tools/Version.ps1"

try {
    # Import required modules
    if (Test-Path $VersionModulePath) {
        . $VersionModulePath
        Write-BuildLog "[OK] Version module loaded successfully"
    } else {
        throw "Version module not found: $VersionModulePath"
    }

    $LanguageHelperPath = Join-Path -Path $projectRoot -ChildPath "scripts/LanguageHelper.ps1"
    if (Test-Path $LanguageHelperPath) {
        . $LanguageHelperPath
        Write-BuildLog "[OK] Language helper loaded successfully"
    } else {
        throw "Language helper not found: $LanguageHelperPath"
    }

    # Test version information retrieval
    Write-BuildLog "--- Step 1: Testing version information ---"
    $versionInfo = Get-ProjectVersionInfo
    Write-BuildLog "Version Info Type: $($versionInfo.GetType().Name)"
    Write-BuildLog "Full Version: '$($versionInfo.FullVersion)'"
    Write-BuildLog "Version String Length: $($versionInfo.FullVersion.Length)"

    # Test message loading
    Write-BuildLog "--- Step 2: Testing message loading ---"
    $messagesPath = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
    if (-not (Test-Path $messagesPath)) {
        throw "Messages file not found: $messagesPath"
    }

    $messagesContent = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "[OK] Messages loaded successfully"

    # Test for each supported language
    $languages = @("ja", "en", "zh-CN")

    foreach ($lang in $languages) {
        Write-BuildLog "--- Step 3: Testing language '$lang' ---"

        if (-not $messagesContent.$lang) {
            Write-BuildLog "Language '$lang' not found in messages" -Level Warning
            continue
        }

        $messages = $messagesContent.$lang
        $aboutTemplate = $messages.aboutMessage

        if (-not $aboutTemplate) {
            Write-BuildLog "aboutMessage not found for language '$lang'" -Level Warning
            continue
        }

        Write-BuildLog "Original template: '$aboutTemplate'"
        Write-BuildLog "Contains {0}: $($aboutTemplate -like '*{0}*')"

        # Test manual replacement
        $testVersion = $versionInfo.FullVersion
        $replacedMessage = $aboutTemplate -replace '\{0\}', $testVersion

        Write-BuildLog "Test version: '$testVersion'"
        Write-BuildLog "Manual replacement result: '$replacedMessage'"

        # Verify replacement worked
        $replacementWorked = $replacedMessage -ne $aboutTemplate -and -not ($replacedMessage -like '*{0}*')
        $level = if ($replacementWorked) { "Success" } else { "Error" }
        Write-BuildLog "Replacement successful: $replacementWorked" -Level $level

        if ($replacementWorked) {
            Write-BuildLog "[OK] Language '$lang': SUCCESS"
        } else {
            Write-BuildLog "[FAILED] Language '$lang': FAILED"
        }
        Write-Host ""
    }

    # Test the actual Get-LocalizedMessage function from ConfigEditor
    Write-BuildLog "--- Step 4: Testing Get-LocalizedMessage function ---"

    # Import the ConfigEditor script to access its functions
    $configEditorPath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.ps1"
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
            Write-BuildLog "Testing Get-LocalizedMessage function..."
            $testResult = Get-LocalizedMessage -Key "aboutMessage" -Args @($versionInfo.FullVersion)
            Write-BuildLog "Function result: '$testResult'"

            $functionWorked = $testResult -ne "aboutMessage" -and -not ($testResult -like '*{0}*')
            $level = if ($functionWorked) { "Success" } else { "Error" }
            Write-BuildLog "Function test successful: $functionWorked" -Level $level

        } else {
            Write-BuildLog "Could not extract Get-LocalizedMessage function from ConfigEditor.ps1" -Level Warning
        }
    }

    Write-BuildLog "=== Test Complete ==="

} catch {
    Write-BuildLog "[ERROR] Test failed: $($_.Exception.Message)"
    Write-BuildLog "Exception details:"
    Write-BuildLog $_.Exception
    exit 1
}
