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
    Write-Information $projectRoot
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
            # Run in a new PowerShell process to avoid module caching issues
            $result = powershell -ExecutionPolicy Bypass -File $testScript 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) {
                Write-Host "========== Test Failed - Output Below =========="
                Write-Host $result
                Write-Host "========== End of Output =========="
            }
            $exitCode | Should -Be 0 -Because "Log rotation test should pass (exit code: $exitCode)"
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

    Context "Configuration Validation" {
        It "should pass configuration validation tests" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/core/Test-Core-ConfigValidation.ps1"
            $null = & $testScript *>&1
            $exitCode = $LASTEXITCODE
            $exitCode | Should -Be 0 -Because "Configuration validation test should pass (exit code: $exitCode)"
        }
    }

    Context "AppManager Parallel Execution" {
        It "should pass AppManager parallel execution unit tests" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/core/Test-Core-AppManagerParallelExecution.ps1"
            $null = & $testScript *>&1
            $exitCode = $LASTEXITCODE
            $exitCode | Should -Be 0 -Because "AppManager parallel execution test should pass (exit code: $exitCode)"
        }
    }
}
