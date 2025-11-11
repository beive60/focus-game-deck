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

Write-Host "=== JSON Formatting Test ===" -ForegroundColor Cyan
Write-Host ""

# Get project root
$projectRoot = Split-Path $PSScriptRoot -Parent

# Load the JSON helper
$jsonHelperPath = Join-Path $projectRoot "gui/ConfigEditor.JsonHelper.ps1"
if (-not (Test-Path $jsonHelperPath)) {
    Write-Host "[FAIL] JSON helper not found: $jsonHelperPath" -ForegroundColor Red
    exit 1
}

. $jsonHelperPath
Write-Host "[OK] JSON helper loaded" -ForegroundColor Green

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

Write-Host "[INFO] Testing ConvertTo-Json4Space function..." -ForegroundColor Yellow

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
    Write-Host "[PASS] All indentation is correct (multiples of 4 spaces)" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Found indentation issues:" -ForegroundColor Red
    foreach ($issue in $indentationIssues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
    exit 1
}

# Display sample of the formatted JSON
Write-Host ""
Write-Host "Sample JSON output (first 15 lines):" -ForegroundColor Cyan
$lines[0..14] | ForEach-Object {
    # Highlight indentation
    if ($_ -match '^( +)(.*)$') {
        $indent = $matches[1]
        $content = $matches[2]
        Write-Host "$indent" -NoNewline -ForegroundColor DarkGray
        Write-Host "$content" -ForegroundColor White
    } else {
        Write-Host $_ -ForegroundColor White
    }
}

# Test Save-ConfigJson function
Write-Host ""
Write-Host "[INFO] Testing Save-ConfigJson function..." -ForegroundColor Yellow

$tempConfigPath = Join-Path $env:TEMP "test-config-$(Get-Random).json"

try {
    Save-ConfigJson -ConfigData $testData -ConfigPath $tempConfigPath -Depth 5
    
    if (Test-Path $tempConfigPath) {
        Write-Host "[PASS] Configuration saved successfully to: $tempConfigPath" -ForegroundColor Green
        
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
            Write-Host "[PASS] Saved file has correct indentation (multiples of 4 spaces)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Saved file has indentation issues:" -ForegroundColor Red
            foreach ($issue in $savedIndentationIssues) {
                Write-Host "  - $issue" -ForegroundColor Red
            }
            exit 1
        }
        
        # Clean up
        Remove-Item $tempConfigPath -Force
        Write-Host "[OK] Temporary file cleaned up" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Configuration file was not created" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[FAIL] Error during Save-ConfigJson test: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "[PASS] All JSON formatting tests passed!" -ForegroundColor Green
Write-Host "  - ConvertTo-Json4Space produces 4-space indentation" -ForegroundColor Green
Write-Host "  - Save-ConfigJson saves files with 4-space indentation" -ForegroundColor Green
Write-Host ""

exit 0
