# Test-ConfigEditorDebug.ps1
# ConfigEditor debug test script
# Tests initialization and collects warning information

param(
    [int]$AutoCloseSeconds = 3,
    [switch]$Verbose
)


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
# Set encoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-BuildLog "=== ConfigEditor Debug Test ==="
Write-BuildLog "Auto-close timer: $AutoCloseSeconds seconds"
Write-Host ""

# Prepare warning collection
$warnings = @()
$errors = @()

# Redirect warnings and errors to our collection
$warningVar = [System.Collections.ArrayList]::new()
$errorVar = [System.Collections.ArrayList]::new()

# Run ConfigEditor with debug mode
try {
    $output = & {
        $WarningPreference = 'Continue'
        $ErrorActionPreference = 'Continue'

        $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $configEditorPath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.ps1"
        & $configEditorPath -DebugMode -AutoCloseSeconds $AutoCloseSeconds 2>&1 3>&1
    }

    # Collect warnings and errors from output
    foreach ($line in $output) {
        if ($line -match '^WARNING:') {
            $warningVar.Add($line) | Out-Null
        } elseif ($line -match '^Write-Error:|^Error:') {
            $errorVar.Add($line) | Out-Null
        }
    }

    # Display collected information
    Write-Host ""
    Write-BuildLog "=== Test Results ==="
    Write-Host ""

    if ($errorVar.Count -gt 0) {
        Write-BuildLog "ERRORS ($($errorVar.Count)):"
        $errorVar | ForEach-Object { Write-BuildLog "  $_" }
        Write-Host ""
    }

    if ($warningVar.Count -gt 0) {
        Write-BuildLog "WARNINGS ($($warningVar.Count)):"

        # Group warnings by type
        $localizationWarnings = $warningVar | Where-Object { $_ -match 'GetLocalizedMessage' }
        $otherWarnings = $warningVar | Where-Object { $_ -notmatch 'GetLocalizedMessage' }

        if ($otherWarnings.Count -gt 0) {
            Write-Host ""
            Write-BuildLog "  Other Warnings:"
            $otherWarnings | ForEach-Object { Write-BuildLog "    $_" }
        }

        if ($localizationWarnings.Count -gt 0) {
            Write-Host ""
            Write-BuildLog "  Localization Warnings ($($localizationWarnings.Count)):"

            # Extract unique missing keys
            $missingKeys = $localizationWarnings | ForEach-Object {
                if ($_ -match "key: '([^']+)'") {
                    $matches[1]
                }
            } | Select-Object -Unique | Sort-Object

            Write-BuildLog "    Missing localization keys: $($missingKeys.Count)"

            if ($Verbose) {
                $missingKeys | ForEach-Object { Write-BuildLog "      - $_" }
            } else {
                Write-BuildLog "    (Use -Verbose to see all missing keys)"
            }
        }
    } else {
        Write-BuildLog "No warnings detected!"
    }

    Write-BuildLog ""
    Write-BuildLog "=== Summary ==="
    $errorLevel = if ($errorVar.Count -eq 0) { "Success" } else { "Error" }
    Write-BuildLog "  Errors:   $($errorVar.Count)" -Level $errorLevel
    $warningLevel = if ($warningVar.Count -eq 0) { "Success" } else { "Warning" }
    Write-BuildLog "  Warnings: $($warningVar.Count)" -Level $warningLevel
    Write-BuildLog ""

    if ($errorVar.Count -eq 0 -and $warningVar.Count -eq 0) {
        Write-BuildLog "Test PASSED - No issues detected!"
        exit 0
    } elseif ($errorVar.Count -eq 0) {
        Write-BuildLog "Test PASSED with warnings"
        exit 0
    } else {
        Write-BuildLog "Test FAILED - Errors detected"
        exit 1
    }

} catch {
    Write-Host ""
    Write-BuildLog "Test FAILED with exception:"
    Write-BuildLog $_.Exception.Message
    exit 1
}
