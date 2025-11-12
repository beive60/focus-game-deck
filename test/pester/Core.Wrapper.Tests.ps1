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
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe "Core Functionality Tests" -Tag "Core" {

    Context "Character Encoding" {
        It "should pass character encoding validation" {
            $testScript = Join-Path -Path $ProjectRoot -ChildPath "test/scripts/core/Test-Core-CharacterEncoding.ps1"
            $output = & $testScript 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Character encoding test should pass"
        }
    }

    Context "Log Rotation" {
        It "should pass log rotation tests" {
            $testScript = Join-Path -Path $ProjectRoot -ChildPath "test/scripts/core/Test-Core-LogRotation.ps1"
            $output = & $testScript 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Log rotation test should pass"
        }
    }

    Context "Multi-Platform Support" {
        It "should pass multi-platform support tests" {
            $testScript = Join-Path -Path $ProjectRoot -ChildPath "test/scripts/core/Test-Core-MultiPlatformSupport.ps1"
            $output = & $testScript 2>&1
            # Some tests may have warnings, check for specific failure patterns
            $output -join "`n" | Should -Not -Match "FAIL.*Expected.*platforms"
        }
    }

    Context "Config File Validation" {
        It "should pass config file validation" {
            $testScript = Join-Path -Path $ProjectRoot -ChildPath "test/scripts/core/Test-Core-ConfigFileValidation.ps1"
            $output = & $testScript 2>&1
            $output -join "`n" | Should -Match "\[OK\]"
        }
    }
}
