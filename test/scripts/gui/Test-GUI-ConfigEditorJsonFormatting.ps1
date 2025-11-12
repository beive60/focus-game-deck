<#
.SYNOPSIS
    Integration test for JSON formatting in ConfigEditor.

.DESCRIPTION
    Tests that ConfigEditor maintains 4-space indentation when saving config.json.

.EXAMPLE
    .\test\Test-ConfigEditorJsonFormatting.ps1
#>

$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== ConfigEditor JSON Formatting Integration Test ==="
Write-Host ""

# Get project root
$projectRoot = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $projectRoot "config/config.json"
$backupPath = Join-Path $projectRoot "config/config.json.backup-test"

# Backup original config
if (Test-Path $configPath) {
    Copy-Item $configPath $backupPath -Force
    Write-Host "[OK] Original config backed up to: $backupPath"
} else {
    Write-Host "[FAIL] Config file not found: $configPath"
    exit 1
}

try {
    # Load the config
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Make a small modification
    $testTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    if (-not $config.PSObject.Properties['_test']) {
        $config | Add-Member -NotePropertyName "_test" -NotePropertyValue $testTimestamp
    } else {
        $config._test = $testTimestamp
    }

    Write-Host "[INFO] Modified config with test timestamp: $testTimestamp"

    # Save using the JsonHelper
    $jsonHelperPath = Join-Path $projectRoot "gui/ConfigEditor.JsonHelper.ps1"
    . $jsonHelperPath

    Save-ConfigJson -ConfigData $config -ConfigPath $configPath -Depth 10
    Write-Host "[OK] Config saved using Save-ConfigJson"

    # Verify the indentation
    $savedJson = Get-Content $configPath -Raw
    $lines = $savedJson -split "`n"
    $indentationIssues = @()

    foreach ($line in $lines) {
        if ($line -match '^( +)') {
            $spaces = $matches[1].Length
            if ($spaces % 4 -ne 0) {
                $indentationIssues += "Line has $spaces spaces (not a multiple of 4): $($line.Substring(0, [Math]::Min(50, $line.Length)))"
            }
        }
    }

    if ($indentationIssues.Count -eq 0) {
        Write-Host "[PASS] Saved config.json has correct 4-space indentation"
    } else {
        Write-Host "[FAIL] Found indentation issues in saved config.json:"
        foreach ($issue in $indentationIssues) {
            Write-Host "  - $issue"
        }

        # Restore backup
        Copy-Item $backupPath $configPath -Force
        Write-Host "[INFO] Restored original config"
        Remove-Item $backupPath -Force
        exit 1
    }

    # Sample check - show first 20 lines
    Write-Host ""
    Write-Host "Sample of saved config.json (first 20 lines):"
    $lines[0..19] | ForEach-Object {
        if ($_ -match '^( +)') {
            $indent = $matches[1]
            $content = $_ -replace '^( +)', ''
            Write-Host ("{0}{1}" -f (' ' * $indent.Length), $content)
        } else {
            Write-Host $_
        }
    }

    Write-Host ""
    Write-Host "=== Test Summary ==="
    Write-Host "[PASS] ConfigEditor JSON formatting integration test passed!"

} finally {
    # Restore original config
    if (Test-Path $backupPath) {
        Copy-Item $backupPath $configPath -Force
        Remove-Item $backupPath -Force
        Write-Host "[OK] Original config restored"
    }
}

exit 0
