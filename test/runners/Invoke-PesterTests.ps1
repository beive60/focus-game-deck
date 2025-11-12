<#
.SYNOPSIS
    Execute Pester tests with various options
.DESCRIPTION
    This script wraps existing Test-*.ps1 scripts with Pester framework
    providing unified reporting without modifying existing test logic
.EXAMPLE
    ./test/runners/Invoke-PesterTests.ps1
.EXAMPLE
    ./test/runners/Invoke-PesterTests.ps1 -Tag "Core"
.EXAMPLE
    ./test/runners/Invoke-PesterTests.ps1 -ExcludeTag "Integration"
.EXAMPLE
    ./test/runners/Invoke-PesterTests.ps1 -OnlyWrappers
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Tag = @(),

    [Parameter()]
    [string[]]$ExcludeTag = @(),

    [Parameter()]
    [switch]$OnlyWrappers,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Verbosity = 'Detailed'
)

$ErrorActionPreference = "Stop"

# Check if Pester 5.0+ is installed
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]"5.0.0" }

if (-not $pesterModule) {
    Write-Host "[INFO] PesterRunner: Pester 5.0+ not found. Installing Pester module"
    try {
        Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
        Write-Host "[INFO] PesterRunner: Pester module installed successfully"
    }
    catch {
        Write-Host "[ERROR] PesterRunner: Failed to install Pester module"
        Write-Host "[ERROR] Error: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Please install Pester manually:"
        Write-Host "  Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser"
        Write-Host ""
        exit 1
    }
}

try {
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    Write-Host "[INFO] PesterRunner: Pester module loaded successfully"
}
catch {
    Write-Host "[ERROR] PesterRunner: Failed to import Pester module"
    Write-Host "[ERROR] Error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Pester 5.0 or higher is required. Please install it:"
    Write-Host "  Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser"
    Write-Host ""
    exit 1
}

# Navigate up two levels from test/runners/ to project root
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Configure Pester
$config = New-PesterConfiguration

# Only run wrapper tests (*.Wrapper.Tests.ps1) or all Pester tests
if ($OnlyWrappers) {
    $config.Run.Path = @(
        (Join-Path -Path $ProjectRoot -ChildPath "test/pester/Core.Wrapper.Tests.ps1"),
        (Join-Path -Path $ProjectRoot -ChildPath "test/pester/GUI.Wrapper.Tests.ps1"),
        (Join-Path -Path $ProjectRoot -ChildPath "test/pester/Integration.Wrapper.Tests.ps1")
    )
} else {
    $config.Run.Path = Join-Path -Path $ProjectRoot -ChildPath "test/pester"
}

$config.Run.Exit = $false
$config.Run.PassThru = $true

if ($Tag.Count -gt 0) {
    $config.Filter.Tag = $Tag
}

if ($ExcludeTag.Count -gt 0) {
    $config.Filter.ExcludeTag = $ExcludeTag
}

$config.Output.Verbosity = $Verbosity

$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = Join-Path -Path $ProjectRoot -ChildPath "test/test-results.xml"

Write-Host ""
Write-Host "========================================"
Write-Host "Running Pester Tests"
if ($OnlyWrappers) {
    Write-Host "(Wrapper mode - using existing Test-*.ps1 scripts)"
}
Write-Host "========================================"
Write-Host ""

if ($Tag.Count -gt 0) {
    Write-Host "Tags: $($Tag -join ', ')"
}
if ($ExcludeTag.Count -gt 0) {
    Write-Host "Excluding: $($ExcludeTag -join ', ')"
}

# Run tests
$result = Invoke-Pester -Configuration $config

# Summary
Write-Host ""
Write-Host "========================================"
Write-Host "Test Summary"
Write-Host "========================================"
Write-Host "Total:   $($result.TotalCount)"
Write-Host "Passed:  $($result.PassedCount)"
Write-Host "Failed:  $($result.FailedCount)"
Write-Host "Skipped: $($result.SkippedCount)"
Write-Host "Duration: $($result.Duration.TotalSeconds)s"

if ($result.FailedCount -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:"
    foreach ($test in $result.Failed) {
        Write-Host "  - $($test.ExpandedPath)"
    }
}

Write-Host "Test results: test/test-results.xml"
Write-Host "========================================"
Write-Host ""

# Exit with appropriate code
exit $result.FailedCount
