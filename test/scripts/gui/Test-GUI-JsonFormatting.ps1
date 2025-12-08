<#
.SYNOPSIS
    Tests JSON formatting to ensure 4-space indentation is maintained.

.DESCRIPTION
    This test script verifies that the ConfigEditor properly saves JSON files
    with 4-space indentation (not 2-space indentation).

.EXAMPLE
    .\test\Test-JsonFormatting.ps1
#>

# Set execution policy and encoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-BuildLog "=== JSON Formatting Test ==="
Write-Host ""

# Get project root
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load the JSON helper
$jsonHelperPath = Join-Path $projectRoot "gui/ConfigEditor.JsonHelper.ps1"
if (-not (Test-Path $jsonHelperPath)) {
    Write-BuildLog "[FAIL] JSON helper not found: $jsonHelperPath"
    exit 1
}

. $jsonHelperPath
Write-BuildLog "[OK] JSON helper loaded"

# Create test data
$testData = [PSCustomObject]@{
    level1 = "value1"
    nested = [PSCustomObject]@{
        level2 = "value2"
        deepNested = [PSCustomObject]@{
            level3 = "value3"
            array = @("item1", "item2", "item3")
        }
    }
    simpleArray = @(1, 2, 3, 4, 5)
}

Write-BuildLog "[INFO] Testing ConvertTo-Json4Space function..."

# Convert to JSON with 4-space indentation
$json = ConvertTo-Json4Space -InputObject $testData -Depth 5

# Check indentation
$lines = $json -split "`n"
$indentationIssues = @()

foreach ($line in $lines) {
    if ($line -match '^( +)') {
        $spaces = $matches[1].Length
        if ($spaces % 4 -ne 0) {
            $indentationIssues += "Line has $spaces spaces (not a multiple of 4): $line"
        }
    }
}

if ($indentationIssues.Count -eq 0) {
    Write-BuildLog "[PASS] All indentation is correct (multiples of 4 spaces)"
} else {
    Write-BuildLog "[FAIL] Found indentation issues:"
    foreach ($issue in $indentationIssues) {
        Write-BuildLog "  - $issue"
    }
    exit 1
}

# Display sample of the formatted JSON
Write-Host ""
Write-BuildLog "Sample JSON output (first 15 lines):"
$lines[0..14] | ForEach-Object {
    # Highlight indentation
    if ($_ -match '^( +)(.*)$') {
        $indent = $matches[1]
        $content = $matches[2]
        Write-BuildLog "$indent" -NoNewline
        Write-BuildLog "$content"
    } else {
        Write-BuildLog $_
    }
}

# Test Save-ConfigJson function
Write-Host ""
Write-BuildLog "[INFO] Testing Save-ConfigJson function..."

$tempConfigPath = Join-Path $env:TEMP "test-config-$(Get-Random).json"

try {
    Save-ConfigJson -ConfigData $testData -ConfigPath $tempConfigPath -Depth 5

    if (Test-Path $tempConfigPath) {
        Write-BuildLog "[PASS] Configuration saved successfully to: $tempConfigPath"

        # Verify the saved file has correct indentation
        $savedJson = Get-Content $tempConfigPath -Raw
        $savedLines = $savedJson -split "`n"
        $savedIndentationIssues = @()

        foreach ($line in $savedLines) {
            if ($line -match '^( +)') {
                $spaces = $matches[1].Length
                if ($spaces % 4 -ne 0) {
                    $savedIndentationIssues += "Line has $spaces spaces (not a multiple of 4): $line"
                }
            }
        }

        if ($savedIndentationIssues.Count -eq 0) {
            Write-BuildLog "[PASS] Saved file has correct indentation (multiples of 4 spaces)"
        } else {
            Write-BuildLog "[FAIL] Saved file has indentation issues:"
            foreach ($issue in $savedIndentationIssues) {
                Write-BuildLog "  - $issue"
            }
            exit 1
        }

        # Clean up
        Remove-Item $tempConfigPath -Force
        Write-BuildLog "[OK] Temporary file cleaned up"
    } else {
        Write-BuildLog "[FAIL] Configuration file was not created"
        exit 1
    }
} catch {
    Write-BuildLog "[FAIL] Error during Save-ConfigJson test: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-BuildLog "=== Test Summary ==="
Write-BuildLog "[PASS] All JSON formatting tests passed!"
Write-BuildLog "  - ConvertTo-Json4Space produces 4-space indentation"
Write-BuildLog "  - Save-ConfigJson saves files with 4-space indentation"
Write-Host ""

exit 0
