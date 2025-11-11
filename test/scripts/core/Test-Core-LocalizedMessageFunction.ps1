<#
.SYNOPSIS
    Direct test of Get-LocalizedMessage function placeholder replacement.

.DESCRIPTION
    This script performs a direct test of the Get-LocalizedMessage function by recreating
    the exact function definition from ConfigEditor.ps1 and testing its placeholder
    replacement functionality in an isolated environment.

    The test validates:
    - Version information retrieval and format
    - Message template loading from messages.json
    - Placeholder pattern detection ({0}, {1}, etc.)
    - String replacement using regex with proper escaping
    - Verbose logging of the replacement process
    - Final result validation (no remaining placeholders, version present)

    This is a low-level test that provides detailed debugging output through verbose
    mode, making it useful for troubleshooting localization issues.

.PARAMETER Verbose
    Enables verbose output showing detailed debugging information about the
    placeholder replacement process, including intermediate states and pattern matching.

.EXAMPLE
    .\Test-LocalizedMessage.ps1
    Runs the direct Get-LocalizedMessage function test with verbose output enabled.

.EXAMPLE
    .\Test-LocalizedMessage.ps1 -Verbose
    Runs the test with explicit verbose flag (verbose is enabled by default in this script).

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0

    Test Process:
    1. Load Version.ps1 module for version information
    2. Load messages.json and extract Japanese messages
    3. Set up script-scope variables (Messages, CurrentLanguage)
    4. Define Get-LocalizedMessage function (exact copy from ConfigEditor.ps1)
    5. Create test arguments array with version information
    6. Call function and analyze results
    7. Validate placeholder replacement success

    Validation Checks:
    - Arguments array structure and type
    - Message template format
    - Placeholder detection and replacement
    - No remaining placeholders in result
    - Version number presence in result

    Exit Behavior:
    - Does not exit with error codes (displays results only)
    - Useful for interactive debugging sessions

    Dependencies:
    - Version.ps1 module for Get-ProjectVersionInfo function
    - localization/messages.json for message templates
#>

param(
    [switch]$Verbose
)

# Enable verbose output
$VerbosePreference = "Continue"

# Set encoding for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Direct Get-LocalizedMessage Function Test ==="

try {
    # Import required modules
    $projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
    $VersionModulePath = Join-Path -Path $projectRoot -ChildPath "build-tools/Version.ps1"
    if (Test-Path $VersionModulePath) {
        . $VersionModulePath
    }

    # Load messages
    $messagesPath = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
    $messagesContent = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Set up script variables as they would be in ConfigEditor
    $script:Messages = $messagesContent.ja
    $script:CurrentLanguage = "ja"

    # Get version info
    $versionInfo = Get-ProjectVersionInfo
    Write-Host "Version to use: '$($versionInfo.FullVersion)'"

    # Define the Get-LocalizedMessage function exactly as it is in ConfigEditor.ps1
    function Get-LocalizedMessage {
        param(
            [string]$Key,
            [array]$Arguments = @()
        )

        Write-Verbose "Debug: Function called with Key='$Key', Arguments.Length=$($Arguments.Length)"
        Write-Verbose "Debug: Arguments content: $($Arguments -join ', ')"

        if ($script:Messages -and $script:Messages.PSObject.Properties[$Key]) {
            $message = $script:Messages.$Key

            # Replace placeholders if args provided
            if ($Arguments.Length -gt 0) {
                Write-Verbose "Debug: Processing message '$Key' with $($Arguments.Length) arguments"
                Write-Verbose "Debug: Original message template: '$message'"
                Write-Verbose "Debug: Message type: $($message.GetType().Name)"

                for ($i = 0; $i -lt $Arguments.Length; $i++) {
                    $placeholder = "{$i}"
                    $replacement = if ($null -ne $Arguments[$i]) {
                        # Ensure safe string conversion - preserve newlines for proper message formatting
                        [string]$Arguments[$i]
                    } else {
                        ""
                    }

                    Write-Verbose "Debug: Looking for placeholder '$placeholder' in message"
                    Write-Verbose "Debug: Replacement value: '$replacement'"
                    Write-Verbose "Debug: Message contains placeholder check: $($message -like "*$placeholder*")"

                    # Use -replace operator with literal pattern matching for more reliable replacement
                    if ($message -like "*$placeholder*") {
                        $oldMessage = $message
                        # Use literal string replacement to avoid regex interpretation issues
                        $message = $message -replace [regex]::Escape($placeholder), $replacement
                        Write-Verbose "Debug: Successfully replaced '$placeholder' with '$replacement'"
                        Write-Verbose "Debug: Message before: '$oldMessage'"
                        Write-Verbose "Debug: Message after:  '$message'"
                    } else {
                        Write-Verbose "Debug: Placeholder '$placeholder' not found in message template: '$message'"
                    }
                }
                Write-Verbose "Debug: Final processed message: '$message'"
            } else {
                Write-Verbose "Debug: No arguments provided for message '$Key', returning original message"
            }

            return $message
        } else {
            # Fallback to English if message not found
            Write-Warning "Debug: Message key '$Key' not found in current language messages"
            return $Key
        }
    }

    # Test the function
    Write-Host "--- Testing Get-LocalizedMessage function ---"
    Write-Host "Message template before calling function:"
    Write-Host "'$($script:Messages.aboutMessage)'"
    Write-Host ""

    # Create args array and examine it
    $argsArray = @($versionInfo.FullVersion)
    Write-Host "Args Array Details:"
    Write-Host "  - Array type: $($argsArray.GetType().Name)"
    Write-Host "  - Array length: $($argsArray.Length)"
    Write-Host "  - Array count: $($argsArray.Count)"
    Write-Host "  - First element: '$($argsArray[0])'"
    Write-Host "  - First element type: $($argsArray[0].GetType().Name)"
    Write-Host ""

    Write-Host "Calling function with args..."
    $result = Get-LocalizedMessage -Key "aboutMessage" -Arguments $argsArray

    Write-Host ""
    Write-Host "Final result:"
    Write-Host "'$result'"
    Write-Host ""

    # Check if replacement worked
    $hasPlaceholder = $result -like '*{0}*'
    $hasVersionNumber = $result -like "*$($versionInfo.FullVersion)*"

    Write-Host "Analysis:"
    if ($hasPlaceholder) {
        Write-Host "  [ERROR] - Result contains {0}: $hasPlaceholder"
    } else {
        Write-Host "  [OK] - Result contains {0}: $hasPlaceholder"
    }

    if ($hasVersionNumber) {
        Write-Host "  [OK] - Result contains version: $hasVersionNumber"
    } else {
        Write-Host "  [ERROR] - Result contains version: $hasVersionNumber"
    }

    if ((-not $hasPlaceholder) -and $hasVersionNumber) {
        Write-Host "  [OK] - Replacement successful: True"
    } else {
        Write-Host "  [ERROR] - Replacement successful: False"
    }

} catch {
    Write-Host "[ERROR] Test failed: $($_.Exception.Message)"
    Write-Host $_.Exception
}
