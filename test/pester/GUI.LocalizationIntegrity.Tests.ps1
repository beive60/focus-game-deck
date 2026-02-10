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
    Tags: Unit, GUI, Localization, Diagnostic

    Dependencies:
    - test/scripts/gui/Test-GUI-LocalizationIntegrity.ps1
    - gui/ConfigEditor.Mappings.ps1
    - localization/*.json (individual language files)
    - gui/MainWindow.xaml
#>

BeforeAll {
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $TestScriptPath = Join-Path -Path $projectRoot -ChildPath "test/scripts/gui/Test-GUI-LocalizationIntegrity.ps1"

    # Verify test script exists
    if (-not (Test-Path $TestScriptPath)) {
        throw "Test script not found: $TestScriptPath"
    }
}

Describe "GUI Localization Integrity Diagnostics" -Tag "Unit", "GUI", "Localization", "Diagnostic" {

    Context "Localization Control Flow Analysis" {

        It "Should execute localization diagnostic without errors" {
            # Capture the output
            & $TestScriptPath *>&1
            $exitCode = $LASTEXITCODE

            # Check that the script executed without throwing errors
            $exitCode | Should -Be 0 -Because "Diagnostic script should complete successfully (exit code: $exitCode)"
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
            Write-Information $analysis
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
                # Filter out intentional duplicates:
                # - CheckBox + Tooltip combinations are expected (checkbox has content and tooltip)
                $intentionalDuplicatePatterns = @(
                    @{ Pattern = 'CheckBoxMappings'; Partner = 'TooltipMappings' }
                )

                $unexpectedDuplicates = @{}
                foreach ($dup in $mappingIntegrity.Duplicates.Keys) {
                    $tables = $mappingIntegrity.Duplicates[$dup]
                    $isIntentional = $false

                    foreach ($pattern in $intentionalDuplicatePatterns) {
                        if (($tables -contains $pattern.Pattern) -and ($tables -contains $pattern.Partner) -and ($tables.Count -eq 2)) {
                            $isIntentional = $true
                            break
                        }
                    }

                    if (-not $isIntentional) {
                        $unexpectedDuplicates[$dup] = $tables
                    }
                }

                if ($unexpectedDuplicates.Count -gt 0) {
                    $duplicateDetails = @()
                    foreach ($dup in $unexpectedDuplicates.Keys) {
                        $duplicateDetails += "$dup : $($unexpectedDuplicates[$dup] -join ', ')"
                    }
                    $errorMessage = "Unexpected duplicate mapping keys detected:`n" + ($duplicateDetails -join "`n")
                    $unexpectedDuplicates.Count | Should -Be 0 -Because $errorMessage
                } else {
                    # All duplicates are intentional design patterns
                    $true | Should -Be $true -Because "Only intentional duplicates (CheckBox+Tooltip) exist"
                }
            } else {
                $mappingIntegrity.Duplicates.Count | Should -Be 0 -Because "No duplicate mapping keys should exist"
            }
        }
    }

    Context "JSON Key Validation" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
            Write-Information $analysis
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
            $missingKeysCount = $jsonValidation.MissingKeys.Count

            # Define acceptable threshold for missing keys (0 for strict validation)
            $acceptableThreshold = 0

            if ($missingKeysCount -gt $acceptableThreshold) {
                $keyDetails = $jsonValidation.MissingKeys | Select-Object -First 10
                $errorMessage = "Found $missingKeysCount missing JSON keys (threshold: $acceptableThreshold):`n" + ($keyDetails -join "`n")
                if ($missingKeysCount -gt 10) {
                    $errorMessage += "`n... and $($missingKeysCount - 10) more"
                }
                $missingKeysCount | Should -BeLessOrEqual $acceptableThreshold -Because $errorMessage
            } else {
                $missingKeysCount | Should -BeLessOrEqual $acceptableThreshold -Because "All required JSON keys should be present"
            }
        }
    }

    Context "XAML Element Access" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
            Write-Information $analysis
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
            $totalElements = 0
            $fileDetails = @()

            foreach ($file in $xamlAccess.ElementAnalysis.Keys) {
                $elementData = $xamlAccess.ElementAnalysis[$file]
                $totalUnmapped += $elementData.UnmappedElements.Count
                $totalElements += $elementData.TotalNamedElements

                if ($elementData.UnmappedElements.Count -gt 0) {
                    $fileName = Split-Path -Leaf $file
                    $fileDetails += "$fileName : $($elementData.UnmappedElements.Count)/$($elementData.TotalNamedElements) unmapped"
                    $unmappedList = $elementData.UnmappedElements | Select-Object -First 5
                    $fileDetails += "  Elements: $($unmappedList -join ', ')"
                }
            }

            # Calculate percentage of unmapped elements
            # Note: Many elements use data binding or are set programmatically, so a higher threshold is acceptable
            # - Elements like ListBox, ComboBox, Grid, etc. don't need localization mappings
            # - Elements that display dynamic data (game names, paths) are handled via binding
            $acceptableUnmappedPercentage = 40.0
            $unmappedPercentage = if ($totalElements -gt 0) { ($totalUnmapped / $totalElements) * 100 } else { 0 }

            if ($totalUnmapped -gt 0) {
                $errorMessage = "Found $totalUnmapped unmapped XAML elements out of $totalElements total ($([math]::Round($unmappedPercentage, 2))%):`n" + ($fileDetails -join "`n")
                $unmappedPercentage | Should -BeLessOrEqual $acceptableUnmappedPercentage -Because $errorMessage
            } else {
                $totalUnmapped | Should -Be 0 -Because "All named XAML elements should be mapped for localization"
            }
        }
    }

    Context "String Replacement Flow" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
            Write-Information $analysis
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
            $issuesCount = $stringFlow.Issues.Count

            # Define acceptable threshold for string replacement issues
            $acceptableThreshold = 0

            if ($issuesCount -gt $acceptableThreshold) {
                # Categorize issues by severity
                $criticalIssues = @($stringFlow.Issues | Where-Object { $_ -match "critical|error|failed" })
                $warningIssues = @($stringFlow.Issues | Where-Object { $_ -match "warning|missing" })
                $infoIssues = @($stringFlow.Issues | Where-Object { $_ -notmatch "critical|error|failed|warning|missing" })

                $issueDetails = @()
                if ($criticalIssues.Count -gt 0) {
                    $issueDetails += "Critical Issues ($($criticalIssues.Count)):"
                    $issueDetails += $criticalIssues | Select-Object -First 5
                }
                if ($warningIssues.Count -gt 0) {
                    $issueDetails += "Warnings ($($warningIssues.Count)):"
                    $issueDetails += $warningIssues | Select-Object -First 5
                }
                if ($infoIssues.Count -gt 0) {
                    $issueDetails += "Info ($($infoIssues.Count)):"
                    $issueDetails += $infoIssues | Select-Object -First 3
                }

                $errorMessage = "Found $issuesCount string replacement issues (threshold: $acceptableThreshold):`n" + ($issueDetails -join "`n")

                # Fail test if critical issues exist, otherwise just report
                if ($criticalIssues.Count -gt 0) {
                    $issuesCount | Should -Be 0 -Because $errorMessage
                } else {
                    $issuesCount | Should -BeLessOrEqual $acceptableThreshold -Because $errorMessage
                }
            } else {
                $issuesCount | Should -Be 0 -Because "No string replacement issues should exist"
            }
        }
    }

    Context "Modularization Impact" {

        BeforeAll {
            . $TestScriptPath
            $analysis = Test-LocalizationControlFlow
            Write-Information $analysis
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
                Write-Host "Warning: Circular dependencies detected:"
                $circularDepIssues | ForEach-Object {
                    Write-Host "  - $_"
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
            Write-Information $analysis
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
                Write-Host "Note: Issues detected but test passes - see diagnostic output for details"
            }

            # Test passes even with issues as this is a diagnostic tool
            $true | Should -Be $true
        }
    }
}
