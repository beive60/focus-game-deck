<#
.SYNOPSIS
    Diagnostic script to identify specific localization control issues.

.DESCRIPTION
    This script analyzes the current localization implementation to identify
    specific problems with XAML element mapping and string replacement control.
#>

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"


# Determine paths - test is now in test/scripts/gui/ directory
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$MappingsPath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.Mappings.ps1"

# Import required modules for analysis
if (Test-Path $MappingsPath) {
    . $MappingsPath
} else {
    Write-BuildLog "ConfigEditor.Mappings.ps1 not found at: $MappingsPath" -Level Warning
}

<#
.SYNOPSIS
    Analyzes the current localization control flow to identify issues.

.DESCRIPTION
    Examines each component of the localization system to identify where
    the XAML name to JSON key mapping and string replacement is failing.

.OUTPUTS
    Hashtable containing detailed analysis results.
#>
function Test-LocalizationControlFlow {
    try {
        $analysis = @{
            MappingIntegrity = @{}
            JsonKeyValidation = @{}
            XamlElementAccess = @{}
            StringReplacementFlow = @{}
            ModularizationImpact = @{}
        }

        # 1. Test mapping table integrity
        Write-BuildLog "=== Testing Mapping Table Integrity ==="

        $analysis.MappingIntegrity = Test-MappingTableIntegrity

        # 2. Validate JSON key structure
        Write-BuildLog "=== Validating JSON Key Structure ==="

        $analysis.JsonKeyValidation = Test-JsonKeyStructure

        # 3. Test XAML element access
        Write-BuildLog "=== Testing XAML Element Access ==="

        $analysis.XamlElementAccess = Test-XamlElementAccess

        # 4. Analyze string replacement flow
        Write-BuildLog "=== Analyzing String Replacement Flow ==="

        $analysis.StringReplacementFlow = Test-StringReplacementFlow

        # 5. Assess modularization impact
        Write-BuildLog "=== Assessing Modularization Impact ==="

        $analysis.ModularizationImpact = Test-ModularizationImpact

        return $analysis
    } catch {
        Write-BuildLog "Error in localization control flow analysis: $($_.Exception.Message)" -Level Error
        return $null
    }
}

<#
.SYNOPSIS
    Tests the integrity of mapping tables.

.DESCRIPTION
    Validates that all mapping tables are properly structured and contain expected data.

.OUTPUTS
    Hashtable containing mapping table test results.
#>
function Test-MappingTableIntegrity {
    $results = @{
        Issues = @()
        Statistics = @{}
        Duplicates = @{}
    }

    try {
        # Check if mapping variables exist and are properly typed
        $mappingVariables = @(
            'CrudButtonMappings',
            'BrowserButtonMappings',
            'AutoDetectButtonMappings',
            'ActionButtonMappings',
            'MovementButtonMappings',
            'ButtonMappings',
            'LabelMappings',
            'TabMappings',
            'TextMappings',
            'CheckBoxMappings',
            'MenuItemMappings',
            'TooltipMappings'
        )

        foreach ($varName in $mappingVariables) {
            if (-not (Get-Variable -Name $varName -ErrorAction SilentlyContinue)) {
                $results.Issues += "Missing variable: $varName"
            } else {
                $var = Get-Variable -Name $varName
                if ($var.Value -isnot [hashtable]) {
                    $results.Issues += "Variable $varName is not a hashtable"
                } else {
                    $results.Statistics[$varName] = $var.Value.Count
                }
            }
        }

        # Check for duplicate keys across different mapping tables
        $allKeys = @()
        $keySource = @{}

        foreach ($varName in $mappingVariables) {
            if (Get-Variable -Name $varName -ErrorAction SilentlyContinue) {
                $mapping = (Get-Variable -Name $varName).Value
                foreach ($key in $mapping.Keys) {
                    if ($key -in $allKeys) {
                        if (-not $results.Duplicates.ContainsKey($key)) {
                            $results.Duplicates[$key] = @()
                        }
                        $results.Duplicates[$key] += $keySource[$key]
                        $results.Duplicates[$key] += $varName
                    } else {
                        $allKeys += $key
                        $keySource[$key] = $varName
                    }
                }
            }
        }

        # Check ButtonMappings consolidation
        if (Get-Variable -Name 'ButtonMappings' -ErrorAction SilentlyContinue) {
            $consolidatedCount = $ButtonMappings.Count
            $individualCounts = 0

            @('CrudButtonMappings', 'BrowserButtonMappings', 'AutoDetectButtonMappings',
                'ActionButtonMappings', 'MovementButtonMappings') | ForEach-Object {
                if (Get-Variable -Name $_ -ErrorAction SilentlyContinue) {
                    $individualCounts += (Get-Variable -Name $_).Value.Count
                }
            }

            if ($consolidatedCount -ne $individualCounts) {
                $results.Issues += "ButtonMappings consolidation mismatch: Expected $individualCounts, Got $consolidatedCount"
            }
        }

        return $results
    } catch {
        $results.Issues += "Exception in mapping integrity test: $($_.Exception.Message)"
        return $results
    }
}

<#
.SYNOPSIS
    Validates JSON key structure and accessibility.

.DESCRIPTION
    Tests whether JSON localization files exist and contain expected keys.

.OUTPUTS
    Hashtable containing JSON validation results.
#>
function Test-JsonKeyStructure {
    $results = @{
        Issues = @()
        FoundFiles = @()
        MissingKeys = @()
        KeyCoverage = @{}
    }

    try {
        # Look for JSON localization files - using already computed $projectRoot
        $localizationPaths = @(
            (Join-Path -Path $projectRoot -ChildPath "gui/localization"),
            (Join-Path -Path $projectRoot -ChildPath "localization"),
            (Join-Path -Path $projectRoot -ChildPath "resources/localization")
        )

        $jsonFiles = @()
        foreach ($path in $localizationPaths) {
            if (Test-Path $path) {
                $jsonFiles += Get-ChildItem -Path $path -Filter "*.json" -ErrorAction SilentlyContinue
                $results.FoundFiles += $path
            }
        }

        if ($jsonFiles.Count -eq 0) {
            $results.Issues += "No JSON localization files found in expected locations"
            return $results
        }

        # Test each JSON file
        foreach ($jsonFile in $jsonFiles) {
            try {
                $jsonContent = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
                $jsonKeys = $jsonContent.PSObject.Properties.Name
                $results.KeyCoverage[$jsonFile.Name] = @{
                    TotalKeys = $jsonKeys.Count
                    MappedKeys = 0
                    UnmappedKeys = @()
                }

                # Check which mapping keys are present in JSON
                $allMappingKeys = @()
                if (Get-Variable -Name 'ButtonMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $ButtonMappings.Values
                }
                if (Get-Variable -Name 'LabelMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $LabelMappings.Values
                }
                if (Get-Variable -Name 'TabMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $TabMappings.Values
                }
                if (Get-Variable -Name 'TextMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $TextMappings.Values
                }

                foreach ($mappingKey in ($allMappingKeys | Sort-Object -Unique)) {
                    if ($jsonContent.PSObject.Properties.Name -contains $mappingKey) {
                        $results.KeyCoverage[$jsonFile.Name].MappedKeys++
                    } else {
                        $results.MissingKeys += "$($jsonFile.Name): $mappingKey"
                    }
                }

                # Check for JSON keys not in mappings
                foreach ($jsonKey in $jsonKeys) {
                    if ($jsonKey -notin $allMappingKeys) {
                        $results.KeyCoverage[$jsonFile.Name].UnmappedKeys += $jsonKey
                    }
                }
            } catch {
                $results.Issues += "Error reading JSON file $($jsonFile.Name): $($_.Exception.Message)"
            }
        }

        return $results
    } catch {
        $results.Issues += "Exception in JSON key structure test: $($_.Exception.Message)"
        return $results
    }
}

<#
.SYNOPSIS
    Tests XAML element access mechanisms.

.DESCRIPTION
    Analyzes whether XAML elements can be properly accessed and identified.

.OUTPUTS
    Hashtable containing XAML access test results.
#>
function Test-XamlElementAccess {
    $results = @{
        Issues = @()
        XamlFiles = @()
        ElementAnalysis = @{}
    }

    try {
        # Find XAML files - using already computed $projectRoot
        $xamlFiles = Get-ChildItem -Path $projectRoot -Filter "*.xaml" -Recurse -ErrorAction SilentlyContinue

        if ($xamlFiles.Count -eq 0) {
            $results.Issues += "No XAML files found in project"
            return $results
        }

        foreach ($xamlFile in $xamlFiles) {
            $results.XamlFiles += $xamlFile.FullName

            try {
                $xamlContent = Get-Content -Path $xamlFile.FullName -Raw

                # Extract named elements using regex
                $namedElements = [regex]::Matches($xamlContent, 'Name="([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value }

                $results.ElementAnalysis[$xamlFile.Name] = @{
                    TotalNamedElements = $namedElements.Count
                    MappedElements = 0
                    UnmappedElements = @()
                    Elements = $namedElements
                }

                # Check which elements have mappings
                $allMappingKeys = @()
                if (Get-Variable -Name 'ButtonMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $ButtonMappings.Keys
                }
                if (Get-Variable -Name 'LabelMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $LabelMappings.Keys
                }
                if (Get-Variable -Name 'TabMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $TabMappings.Keys
                }
                if (Get-Variable -Name 'TextMappings' -ErrorAction SilentlyContinue) {
                    $allMappingKeys += $TextMappings.Keys
                }

                foreach ($element in $namedElements) {
                    if ($element -in $allMappingKeys) {
                        $results.ElementAnalysis[$xamlFile.Name].MappedElements++
                    } else {
                        $results.ElementAnalysis[$xamlFile.Name].UnmappedElements += $element
                    }
                }
            } catch {
                $results.Issues += "Error analyzing XAML file $($xamlFile.Name): $($_.Exception.Message)"
            }
        }

        return $results
    } catch {
        $results.Issues += "Exception in XAML element access test: $($_.Exception.Message)"
        return $results
    }
}

<#
.SYNOPSIS
    Tests the string replacement control flow.

.DESCRIPTION
    Analyzes the mechanisms used for replacing UI element properties with localized strings.

.OUTPUTS
    Hashtable containing string replacement flow analysis.
#>
function Test-StringReplacementFlow {
    $results = @{
        Issues = @()
        ControlMechanisms = @{}
        FunctionAvailability = @{}
    }

    try {
        # Check for localization control functions
        $expectedFunctions = @(
            'Get-LocalizationKey',
            'Get-ElementsForKey',
            'Get-ButtonMappingsByCategory'
        )

        foreach ($functionName in $expectedFunctions) {
            $function = Get-Command -Name $functionName -ErrorAction SilentlyContinue
            $results.FunctionAvailability[$functionName] = $function -ne $null

            if (-not $function) {
                $results.Issues += "Missing function: $functionName"
            }
        }

        # Test Get-LocalizationKey function if available
        if ($results.FunctionAvailability['Get-LocalizationKey']) {
            try {
                # Test with known mapping
                $testKey = Get-LocalizationKey -ElementName "AddGameButton" -ElementType "Button"
                if ($testKey -eq "addButton") {
                    $results.ControlMechanisms['Get-LocalizationKey'] = "Working correctly"
                } else {
                    $results.Issues += "Get-LocalizationKey not returning expected results"
                    $results.ControlMechanisms['Get-LocalizationKey'] = "Incorrect results"
                }
            } catch {
                $results.Issues += "Error testing Get-LocalizationKey: $($_.Exception.Message)"
                $results.ControlMechanisms['Get-LocalizationKey'] = "Exception thrown"
            }
        }

        # Check for main localization application mechanism - using computed $projectRoot
        $mainConfigEditor = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.ps1"
        if (Test-Path $mainConfigEditor) {
            $configEditorContent = Get-Content -Path $mainConfigEditor -Raw

            # Look for localization application patterns
            $patterns = @{
                'DotSourceMappings' = '\.\s*["\$].*ConfigEditor\.Mappings\.ps1'
                'LocalizationCall' = 'Set-.*Localization|Apply.*Localization|.*locali[sz]ation'
                'JsonLoading' = 'ConvertFrom-Json|Get-LocalizedStrings'
                'ElementPropertySetting' = '\.Content\s*=|\.Header\s*=|\.Text\s*='
            }

            foreach ($pattern in $patterns.GetEnumerator()) {
                if ($configEditorContent -match $pattern.Value) {
                    $results.ControlMechanisms[$pattern.Key] = "Found"
                } else {
                    $results.ControlMechanisms[$pattern.Key] = "Missing"
                    $results.Issues += "Missing pattern in ConfigEditor.ps1: $($pattern.Key)"
                }
            }
        } else {
            $results.Issues += "Main ConfigEditor.ps1 file not found"
        }

        return $results
    } catch {
        $results.Issues += "Exception in string replacement flow test: $($_.Exception.Message)"
        return $results
    }
}

<#
.SYNOPSIS
    Assesses the impact of modularization on localization functionality.

.DESCRIPTION
    Analyzes how the refactoring into separate modules affects the localization control flow.

.OUTPUTS
    Hashtable containing modularization impact analysis.
#>
function Test-ModularizationImpact {
    $results = @{
        Issues = @()
        ModuleFiles = @()
        DependencyChain = @{}
        Integration = @{}
    }

    try {
        # Find all ConfigEditor.*.ps1 files - search in gui directory
        $modulePattern = "ConfigEditor.*.ps1"
        $guiPath = Join-Path -Path $projectRoot -ChildPath "gui"
        $moduleFiles = Get-ChildItem -Path $guiPath -Filter $modulePattern -ErrorAction SilentlyContinue

        foreach ($moduleFile in $moduleFiles) {
            $results.ModuleFiles += $moduleFile.Name

            try {
                $moduleContent = Get-Content -Path $moduleFile.FullName -Raw

                # Analyze dependencies (dot-sourcing, function calls)
                $dependencies = @()

                # Look for dot-sourcing
                $dotSourceMatches = [regex]::Matches($moduleContent, '\.\s*["\$].*?\.ps1')
                foreach ($match in $dotSourceMatches) {
                    $dependencies += $match.Value
                }

                # Look for function definitions
                $functionMatches = [regex]::Matches($moduleContent, 'function\s+([^\s\{]+)')
                $exportedFunctions = $functionMatches | ForEach-Object { $_.Groups[1].Value }

                $results.DependencyChain[$moduleFile.Name] = @{
                    Dependencies = $dependencies
                    ExportedFunctions = $exportedFunctions
                    Size = $moduleContent.Length
                }
            } catch {
                $results.Issues += "Error analyzing module $($moduleFile.Name): $($_.Exception.Message)"
            }
        }

        # Check for circular dependencies
        foreach ($module in $results.DependencyChain.Keys) {
            $deps = $results.DependencyChain[$module].Dependencies
            foreach ($dep in $deps) {
                if ($dep -match $module) {
                    $results.Issues += "Potential circular dependency detected in $module"
                }
            }
        }

        # Check integration completeness
        $hasLocalizationModule = $results.ModuleFiles -contains "ConfigEditor.Localization.ps1"
        $hasMappingsModule = $results.ModuleFiles -contains "ConfigEditor.Mappings.ps1"

        $results.Integration['HasLocalizationModule'] = $hasLocalizationModule
        $results.Integration['HasMappingsModule'] = $hasMappingsModule

        if (-not $hasLocalizationModule) {
            $results.Issues += "Missing ConfigEditor.Localization.ps1 module"
        }

        if (-not $hasMappingsModule) {
            $results.Issues += "Missing ConfigEditor.Mappings.ps1 module"
        }

        return $results
    } catch {
        $results.Issues += "Exception in modularization impact test: $($_.Exception.Message)"
        return $results
    }
}

<#
.SYNOPSIS
    Generates a comprehensive report of all localization issues.

.DESCRIPTION
    Creates a formatted report summarizing all identified issues and recommendations.

.PARAMETER Analysis
    The analysis results from Test-LocalizationControlFlow.

.OUTPUTS
    None. Outputs report to console.
#>
function Write-LocalizationDiagnosticReport {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Analysis
    )

    # Separator removed
    Write-BuildLog "LOCALIZATION DIAGNOSTIC REPORT"
    # Separator removed

    # Summary
    $totalIssues = 0
    foreach ($section in $Analysis.Values) {
        if ($section -is [hashtable] -and $section.ContainsKey('Issues')) {
            $totalIssues += $section.Issues.Count
        }
    }

    Write-BuildLog "SUMMARY:"
    Write-BuildLog "Total Issues Found: $totalIssues"

    # Detailed sections
    foreach ($sectionName in $Analysis.Keys) {
        $section = $Analysis[$sectionName]

        Write-BuildLog "$($sectionName.ToUpper()):"

        if ($section.Issues.Count -gt 0) {
            Write-BuildLog "Issues ($($section.Issues.Count)):"
            foreach ($issue in $section.Issues) {
                Write-BuildLog "  - $issue"
            }
        } else {
            Write-BuildLog "  No issues found"
        }

        # Additional details for each section
        foreach ($key in $section.Keys) {
            if ($key -ne 'Issues' -and $section[$key]) {
                Write-BuildLog "$key :"
                if ($section[$key] -is [hashtable]) {
                    foreach ($subKey in $section[$key].Keys) {
                        Write-BuildLog "  $subKey`: $($section[$key][$subKey])"
                    }
                } elseif ($section[$key] -is [array]) {
                    foreach ($item in $section[$key]) {
                        Write-BuildLog "  - $item"
                    }
                }
            }
        }
    }

    # Separator removed
}

# Run the diagnostic if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Write-BuildLog "(MyInvocation.InvocationName -ne '.') is TRUE"
}
Write-BuildLog "Starting localization diagnostic..."
$analysis = Test-LocalizationControlFlow

if ($analysis) {
    Write-LocalizationDiagnosticReport -Analysis $analysis

    # Output analysis to file for further review - save to test directory
    $outputDir = Join-Path -Path $projectRoot -ChildPath "test"
    $outputPath = Join-Path -Path $outputDir -ChildPath "localization-diagnostic.json"
    $analysis | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputPath -Encoding UTF8 -Force
    Write-BuildLog "Detailed analysis saved to: $outputPath"

    # Calculate total issues for test result
    $totalIssues = 0
    foreach ($section in $analysis.Values) {
        if ($section -is [hashtable] -and $section.ContainsKey('Issues')) {
            $totalIssues += $section.Issues.Count
        }
    }

    # Return appropriate exit code
    # Exit with 0 (success) but output issue count for Pester to evaluate
    Write-BuildLog "[TEST RESULT] Total Issues: $totalIssues"
    if ($totalIssues -eq 0) {
        Write-BuildLog "[PASS] Localization integrity test passed with no issues"
        exit 0
    } else {
        Write-BuildLog "[INFO] Localization diagnostic completed with $totalIssues issues (see report for details)"
        exit 0
    }
} else {
    Write-BuildLog "[FAIL] Diagnostic failed to complete"
    exit 1
}
