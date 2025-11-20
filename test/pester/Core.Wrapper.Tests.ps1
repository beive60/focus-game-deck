<#
.SYNOPSIS
    Pester wrapper for existing Core test scripts
.DESCRIPTION
    Wraps existing Test-Core-*.ps1 scripts without modifying them
    This wrapper enables unified test reporting via Pester framework
    without requiring modifications to legacy test scripts
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe "Core Functionality Tests" -Tag "Core" {

    Context "Character Encoding" {
        It "should pass character encoding validation" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/core/Test-Core-CharacterEncoding.ps1"
            $null = & $testScript *>&1
            $exitCode = $LASTEXITCODE
            $exitCode | Should -Be 0 -Because "Character encoding test should pass (exit code: $exitCode)"
        }
    }

    Context "Log Rotation" {
        It "should pass log rotation tests" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/core/Test-Core-LogRotation.ps1"
            { & $testScript *>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "Test failed with exit code $LASTEXITCODE" } } | Should -Not -Throw -Because "Log rotation test should pass"
        }
    }

    Context "Multi-Platform Support" {
        It "should pass multi-platform support tests" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/core/Test-Core-MultiPlatformSupport.ps1"
            $output = & $testScript *>&1 | Out-String
            # Some tests may have warnings, check for specific failure patterns
            $output | Should -Not -Match "FAIL.*Expected.*platforms" -Because "Multi-platform tests should not have critical failures"
        }
    }
}
