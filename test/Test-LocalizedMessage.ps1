# Direct test of Get-LocalizedMessage function
# このスクリプトは Get-LocalizedMessage 関数を直接テストします

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
    $VersionModulePath = Join-Path $PSScriptRoot "Version.ps1"
    if (Test-Path $VersionModulePath) {
        . $VersionModulePath
    }

    # Load messages
    $messagesPath = Join-Path $PSScriptRoot "../localization/messages.json"
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
    Write-Host "  - Result contains {0}: $hasPlaceholder" -ForegroundColor $(if ($hasPlaceholder) { "Red" } else { "Green" })
    Write-Host "  - Result contains version: $hasVersionNumber" -ForegroundColor $(if ($hasVersionNumber) { "Green" } else { "Red" })
    Write-Host "  - Replacement successful: $((-not $hasPlaceholder) -and $hasVersionNumber)" -ForegroundColor $(if ((-not $hasPlaceholder) -and $hasVersionNumber) { "Green" } else { "Red" })

} catch {
    Write-Host "[ERROR] Test failed: $($_.Exception.Message)"
    Write-Host $_.Exception
}
