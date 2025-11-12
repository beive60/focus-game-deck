# Test-ConfigEditorDebug.ps1
# ConfigEditor debug test script
# Tests initialization and collects warning information

param(
    [int]$AutoCloseSeconds = 3,
    [switch]$Verbose
)

# Set encoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== ConfigEditor Debug Test ==="
Write-Host "Auto-close timer: $AutoCloseSeconds seconds"
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

        $projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
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
    Write-Host "=== Test Results ==="
    Write-Host ""

    if ($errorVar.Count -gt 0) {
        Write-Host "ERRORS ($($errorVar.Count)):"
        $errorVar | ForEach-Object { Write-Host "  $_"}
        Write-Host ""
    }

    if ($warningVar.Count -gt 0) {
        Write-Host "WARNINGS ($($warningVar.Count)):"

        # Group warnings by type
        $localizationWarnings = $warningVar | Where-Object { $_ -match 'GetLocalizedMessage' }
        $otherWarnings = $warningVar | Where-Object { $_ -notmatch 'GetLocalizedMessage' }

        if ($otherWarnings.Count -gt 0) {
            Write-Host ""
            Write-Host "  Other Warnings:"
            $otherWarnings | ForEach-Object { Write-Host "    $_"}
        }

        if ($localizationWarnings.Count -gt 0) {
            Write-Host ""
            Write-Host "  Localization Warnings ($($localizationWarnings.Count)):"

            # Extract unique missing keys
            $missingKeys = $localizationWarnings | ForEach-Object {
                if ($_ -match "key: '([^']+)'") {
                    $matches[1]
                }
            } | Select-Object -Unique | Sort-Object

            Write-Host "    Missing localization keys: $($missingKeys.Count)"

            if ($Verbose) {
                $missingKeys | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
            } else {
                Write-Host "    (Use -Verbose to see all missing keys)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No warnings detected!"
    }

    Write-Host ""
    Write-Host "=== Summary ==="
    Write-Host "  Errors:   $($errorVar.Count)" -ForegroundColor $(if ($errorVar.Count -eq 0) { "Green" } else { "Red" })
    Write-Host "  Warnings: $($warningVar.Count)" -ForegroundColor $(if ($warningVar.Count -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""

    if ($errorVar.Count -eq 0 -and $warningVar.Count -eq 0) {
        Write-Host "Test PASSED - No issues detected!"
        exit 0
    } elseif ($errorVar.Count -eq 0) {
        Write-Host "Test PASSED with warnings"
        exit 0
    } else {
        Write-Host "Test FAILED - Errors detected"
        exit 1
    }

} catch {
    Write-Host ""
    Write-Host "Test FAILED with exception:"
    Write-Host $_.Exception.Message
    exit 1
}
