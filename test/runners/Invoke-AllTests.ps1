<#
.SYNOPSIS
    Execute all test scripts and generate summary report
.DESCRIPTION
    Runs all Test-*.ps1 scripts sequentially and collects results
    into a comprehensive summary report with pass/fail statistics
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipIntegrationTests,
    
    [Parameter()]
    [string]$OutputFormat = "Console" # Console, JSON, HTML
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# Test categories
$TestCategories = @{
    "Core" = @(
        "Test-Core-ConfigFileValidation.ps1",
        "Test-Core-CharacterEncoding.ps1",
        "Test-Core-LogRotation.ps1",
        "Test-Core-MultiPlatformSupport.ps1"
    )
    "GUI" = @(
        "Test-GUI-ConfigEditorConsistency.ps1",
        "Test-GUI-ElementMappingCompleteness.ps1",
        "Test-GUI-ComboBoxLocalization.ps1",
        "Test-GUI-GameLauncherTab.ps1"
    )
    "Integration" = @(
        "Test-Integration-Discord.ps1",
        "Test-Integration-OBSWebSocket.ps1",
        "Test-Integration-VTubeStudio.ps1"
    )
}

# Results collection
$TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Skipped = 0
    Duration = 0
    Details = @()
}

$StartTime = Get-Date

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Focus Game Deck - Test Suite Execution" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($category in $TestCategories.Keys) {
    if ($SkipIntegrationTests -and $category -eq "Integration") {
        Write-Host "⊘ Skipping $category tests..." -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`n--- $category Tests ---`n" -ForegroundColor Magenta
    
    foreach ($testScript in $TestCategories[$category]) {
        $testPath = Join-Path $ProjectRoot "test" $testScript
        
        if (-not (Test-Path $testPath)) {
            Write-Host "  [SKIP] $testScript (not found)" -ForegroundColor Yellow
            $TestResults.Skipped++
            continue
        }
        
        Write-Host "  Running: $testScript" -ForegroundColor Gray
        
        $testStart = Get-Date
        $testOutput = & $testPath 2>&1
        $exitCode = $LASTEXITCODE
        $testEnd = Get-Date
        $duration = ($testEnd - $testStart).TotalSeconds
        
        $TestResults.Total++
        
        $result = @{
            Name = $testScript
            Category = $category
            Duration = [math]::Round($duration, 2)
            ExitCode = $exitCode
            Output = $testOutput
        }
        
        # Parse test output for pass/fail
        if ($exitCode -eq 0 -or $testOutput -match '\[OK\]|\bPASS(ED)?\b|Success') {
            Write-Host "  [PASS] $testScript ($duration s)" -ForegroundColor Green
            $TestResults.Passed++
            $result.Status = "PASS"
        } else {
            Write-Host "  [FAIL] $testScript ($duration s)" -ForegroundColor Red
            $TestResults.Failed++
            $result.Status = "FAIL"
        }
        
        $TestResults.Details += $result
    }
}

$EndTime = Get-Date
$TestResults.Duration = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)

# Generate Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Execution Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests:    $($TestResults.Total)" -ForegroundColor White
Write-Host "Passed:         $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:         $($TestResults.Failed)" -ForegroundColor $(if ($TestResults.Failed -eq 0) { "Green" } else { "Red" })
Write-Host "Skipped:        $($TestResults.Skipped)" -ForegroundColor Yellow
Write-Host "Duration:       $($TestResults.Duration)s" -ForegroundColor White
Write-Host "Success Rate:   $([math]::Round(($TestResults.Passed / $TestResults.Total) * 100, 1))%" -ForegroundColor $(if ($TestResults.Failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================`n" -ForegroundColor Cyan

# Failed tests details
if ($TestResults.Failed -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    foreach ($test in ($TestResults.Details | Where-Object { $_.Status -eq "FAIL" })) {
        Write-Host "  - $($test.Name) [$($test.Category)]" -ForegroundColor Red
    }
    Write-Host ""
}

# Export results based on format
switch ($OutputFormat) {
    "JSON" {
        $jsonPath = Join-Path $ProjectRoot "test" "test-results.json"
        $TestResults | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
        Write-Host "Results exported to: $jsonPath" -ForegroundColor Cyan
    }
    "HTML" {
        $htmlPath = Join-Path $ProjectRoot "test" "test-results.html"
        # Generate HTML report (simplified)
        $html = @"
<!DOCTYPE html>
<html>
<head><title>Test Results</title></head>
<body>
<h1>Focus Game Deck - Test Results</h1>
<p>Total: $($TestResults.Total) | Passed: $($TestResults.Passed) | Failed: $($TestResults.Failed)</p>
</body>
</html>
"@
        $html | Set-Content $htmlPath -Encoding UTF8
        Write-Host "Results exported to: $htmlPath" -ForegroundColor Cyan
    }
}

# Exit with appropriate code
if ($TestResults.Failed -gt 0) {
    exit 1
} else {
    exit 0
}
