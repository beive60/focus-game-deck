<#
.SYNOPSIS
    Pester wrapper for Localization functionality tests

.DESCRIPTION
    Wraps localization test scripts without modifying them.
    This wrapper enables unified test reporting via Pester framework
    for localization-specific tests including:
    - File structure validation
    - Language file integrity
    - Performance metrics
    - Backward compatibility

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Tags: Localization, Core

    Dependencies:
    - test/scripts/localization/Test-LocalizationFileStructure.ps1
    - scripts/LanguageHelper.ps1
    - localization/ directory with individual language files
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Write-Information $projectRoot
}

Describe "Localization Functionality Tests" -Tag "Unit", "Localization" {

    Context "File Structure" {
        It "should pass localization file structure validation" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/localization/Test-LocalizationFileStructure.ps1"
            $null = & $testScript *>&1
            $exitCode = $LASTEXITCODE
            $exitCode | Should -Be 0 -Because "Localization file structure test should pass (exit code: $exitCode)"
        }
    }
}
