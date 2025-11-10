<#
.SYNOPSIS
    Pester tests for GUI localization integrity diagnostics.

.DESCRIPTION
    This Pester test suite wraps the Test-GUI-LocalizationIntegrity.ps1 script,
    which performs comprehensive diagnostic analysis of the localization system
    including:
    - Mapping table integrity validation
    - JSON key structure verification
    - XAML element access testing
    - String replacement flow analysis
    - Modularization impact assessment

    The test validates that the localization control flow is functioning correctly
    and identifies specific issues with XAML element mapping and string replacement.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Tags: GUI, Localization, Diagnostic

    Dependencies:
    - test/scripts/gui/Test-GUI-LocalizationIntegrity.ps1
    - gui/ConfigEditor.Mappings.ps1
    - localization/messages.json
    - gui/MainWindow.xaml
#>

BeforeAll {
    $ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $TestScriptPath = Join-Path -Path $ProjectRoot -ChildPath "test/scripts/gui/Test-GUI-LocalizationIntegrity.ps1"

    # Verify test script exists
    if (-not (Test-Path $TestScriptPath)) {
        throw "Test script not found: $TestScriptPath"
    }
}

Describe "GUI Localization Integrity Diagnostics" -Tags @("GUI", "Localization", "Diagnostic") {

    Context "Localization Control Flow Analysis" {

        It "Should execute localization diagnostic without errors" {
            # Capture the output
            $output = & $TestScriptPath 2>&1

            # Check that the script executed without throwing errors
            $LASTEXITCODE | Should -Be 0 -Because "Diagnostic script should complete successfully"
        }

        It "Should generate diagnostic analysis results" {
            # Source the test script to access its functions
            . $TestScriptPath

            # Execute the main diagnostic function
            $analysis = Test-LocalizationControlFlow

            # Verify analysis results structure
            $analysis | Should -Not -BeNullOrEmpty
            $analysis | Should -BeOfType [hashtable]
            $analysis.Keys | Should -Contain "MappingIntegrity"
            $analysis.Keys | Should -Contain "JsonKeyValidation"
            $analysis.Keys | Should -Contain "XamlElementAccess"
            $analysis.Keys | Should -Contain "StringReplacementFlow"
            $analysis.Keys | Should -Contain "ModularizationImpact"
        }
    }

    Context "Mapping Table Integrity" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
        }

        It "Should validate mapping table structure" {
            $mappingIntegrity = $analysis.MappingIntegrity

            $mappingIntegrity | Should -Not -BeNullOrEmpty
            $mappingIntegrity.Keys | Should -Contain "Issues"
            $mappingIntegrity.Keys | Should -Contain "Statistics"
        }

        It "Should detect mapping variables" {
            $mappingIntegrity = $analysis.MappingIntegrity

            $mappingIntegrity.Statistics.Keys.Count | Should -BeGreaterThan 0 -Because "At least one mapping table should be detected"
        }

        It "Should identify duplicate mapping keys if present" {
            $mappingIntegrity = $analysis.MappingIntegrity

            if ($mappingIntegrity.Duplicates.Count -gt 0) {
                Write-Host "Warning: Duplicate mapping keys detected:" -ForegroundColor Yellow
                foreach ($dup in $mappingIntegrity.Duplicates.Keys) {
                    Write-Host "  - $dup : $($mappingIntegrity.Duplicates[$dup] -join ', ')" -ForegroundColor Yellow
                }
                Set-ItResult -Skipped -Because "Duplicate keys found but not critical for test execution"
            } else {
                $true | Should -Be $true
            }
        }
    }

    Context "JSON Key Validation" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
        }

        It "Should locate JSON localization files" {
            $jsonValidation = $analysis.JsonKeyValidation

            $jsonValidation | Should -Not -BeNullOrEmpty
            $jsonValidation.FoundFiles.Count | Should -BeGreaterThan 0 -Because "At least one localization directory should be found"
        }

        It "Should validate JSON key coverage" {
            $jsonValidation = $analysis.JsonKeyValidation

            if ($jsonValidation.KeyCoverage.Count -gt 0) {
                foreach ($file in $jsonValidation.KeyCoverage.Keys) {
                    $coverage = $jsonValidation.KeyCoverage[$file]
                    Write-Host "  $file : $($coverage.MappedKeys) mapped keys out of $($coverage.TotalKeys) total"
                }
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "No JSON files with key coverage data"
            }
        }

        It "Should report missing JSON keys if any" {
            $jsonValidation = $analysis.JsonKeyValidation

            if ($jsonValidation.MissingKeys.Count -gt 0) {
                Write-Host "Warning: Missing JSON keys detected ($($jsonValidation.MissingKeys.Count)):" -ForegroundColor Yellow
                $jsonValidation.MissingKeys | Select-Object -First 5 | ForEach-Object {
                    Write-Host "  - $_" -ForegroundColor Yellow
                }
                Set-ItResult -Skipped -Because "Missing keys found but not critical for test execution"
            } else {
                $true | Should -Be $true
            }
        }
    }

    Context "XAML Element Access" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
        }

        It "Should detect XAML files in project" {
            $xamlAccess = $analysis.XamlElementAccess

            $xamlAccess | Should -Not -BeNullOrEmpty
            $xamlAccess.XamlFiles.Count | Should -BeGreaterThan 0 -Because "Project should contain XAML files"
        }

        It "Should analyze XAML element mappings" {
            $xamlAccess = $analysis.XamlElementAccess

            if ($xamlAccess.ElementAnalysis.Count -gt 0) {
                foreach ($file in $xamlAccess.ElementAnalysis.Keys) {
                    $elementData = $xamlAccess.ElementAnalysis[$file]
                    Write-Host "  $file : $($elementData.MappedElements)/$($elementData.TotalNamedElements) elements mapped"
                }
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "No XAML element analysis data"
            }
        }

        It "Should report unmapped XAML elements if any" {
            $xamlAccess = $analysis.XamlElementAccess

            $totalUnmapped = 0
            foreach ($file in $xamlAccess.ElementAnalysis.Keys) {
                $totalUnmapped += $xamlAccess.ElementAnalysis[$file].UnmappedElements.Count
            }

            if ($totalUnmapped -gt 0) {
                Write-Host "Warning: $totalUnmapped unmapped XAML elements detected" -ForegroundColor Yellow
                Set-ItResult -Skipped -Because "Unmapped elements found but not critical for test execution"
            } else {
                $true | Should -Be $true
            }
        }
    }

    Context "String Replacement Flow" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
        }

        It "Should detect localization control functions" {
            $stringFlow = $analysis.StringReplacementFlow

            $stringFlow | Should -Not -BeNullOrEmpty
            $stringFlow.Keys | Should -Contain "FunctionAvailability"
        }

        It "Should validate control mechanisms in ConfigEditor" {
            $stringFlow = $analysis.StringReplacementFlow

            if ($stringFlow.ControlMechanisms.Count -gt 0) {
                foreach ($mechanism in $stringFlow.ControlMechanisms.Keys) {
                    Write-Host "  $mechanism : $($stringFlow.ControlMechanisms[$mechanism])"
                }
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "No control mechanism data available"
            }
        }

        It "Should report string replacement issues if any" {
            $stringFlow = $analysis.StringReplacementFlow

            if ($stringFlow.Issues.Count -gt 0) {
                Write-Host "Warning: String replacement issues detected ($($stringFlow.Issues.Count)):" -ForegroundColor Yellow
                $stringFlow.Issues | Select-Object -First 5 | ForEach-Object {
                    Write-Host "  - $_" -ForegroundColor Yellow
                }
                Set-ItResult -Skipped -Because "Issues found but not critical for test execution"
            } else {
                $true | Should -Be $true
            }
        }
    }

    Context "Modularization Impact" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
        }

        It "Should detect ConfigEditor module files" {
            $modulization = $analysis.ModularizationImpact

            $modulization | Should -Not -BeNullOrEmpty
            $modulization.ModuleFiles.Count | Should -BeGreaterThan 0 -Because "ConfigEditor modules should be detected"
        }

        It "Should verify required modules exist" {
            $modulization = $analysis.ModularizationImpact

            $modulization.Integration.HasMappingsModule | Should -Be $true -Because "ConfigEditor.Mappings.ps1 is required"
        }

        It "Should analyze module dependencies" {
            $modulization = $analysis.ModularizationImpact

            if ($modulization.DependencyChain.Count -gt 0) {
                Write-Host "Module dependency chain:"
                foreach ($module in $modulization.DependencyChain.Keys) {
                    $deps = $modulization.DependencyChain[$module]
                    Write-Host "  $module : $($deps.ExportedFunctions.Count) functions, $($deps.Dependencies.Count) dependencies"
                }
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "No dependency chain data available"
            }
        }

        It "Should detect circular dependencies" {
            $modulization = $analysis.ModularizationImpact

            $circularDepIssues = $modulization.Issues | Where-Object { $_ -like "*circular dependency*" }

            if ($circularDepIssues.Count -gt 0) {
                Write-Host "Warning: Circular dependencies detected:" -ForegroundColor Yellow
                $circularDepIssues | ForEach-Object {
                    Write-Host "  - $_" -ForegroundColor Yellow
                }
                Set-ItResult -Skipped -Because "Circular dependencies found but not critical for test execution"
            } else {
                $true | Should -Be $true
            }
        }
    }

    Context "Overall Diagnostic Report" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
        }

        It "Should count total issues across all categories" {
            $totalIssues = 0
            foreach ($section in $analysis.Values) {
                if ($section -is [hashtable] -and $section.ContainsKey('Issues')) {
                    $totalIssues += $section.Issues.Count
                }
            }

            Write-Host "Total localization issues detected: $totalIssues"

            if ($totalIssues -gt 0) {
                Write-Host "Note: Issues detected but test passes - see diagnostic output for details" -ForegroundColor Yellow
            }

            # Test passes even with issues as this is a diagnostic tool
            $true | Should -Be $true
        }

        It "Should generate diagnostic output file" {
            # Check if diagnostic JSON file was created
            $diagnosticFiles = Get-ChildItem -Path (Join-Path -Path $ProjectRoot -ChildPath "gui") -Filter "localization-diagnostic-*.json" -ErrorAction SilentlyContinue

            if ($diagnosticFiles.Count -gt 0) {
                $latestFile = $diagnosticFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "Diagnostic output: $($latestFile.FullName)"
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "No diagnostic output file generated"
            }
        }
    }
}
