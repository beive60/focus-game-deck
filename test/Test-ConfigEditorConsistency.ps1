<#
SYNOPSIS
    Tests consistency between MainWindowxaml and ConfigEditorMappingsps1

DESCRIPTION
    This test verifies that all UI elements with placeholders in MainWindowxaml
    have corresponding mappings defined in ConfigEditorMappingsps1
    This ensures the localization system works properly

PARAMETER ShowDetails
    Enable detailed output showing mapping information

EXAMPLE
    \Test-ConfigEditorConsistencyps1

EXAMPLE
    \Test-ConfigEditorConsistencyps1 -ShowDetails

NOTES
    Author: Focus Game Deck Development Team
    Version: 100
    Created: 2025-10-12
#>

[CmdletBinding()]
param(
    [switch]$ShowDetails
    )

# Set error action preference
$ErrorActionPreference = 'Stop'

# Define paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MainWindowPath = Join-Path $ProjectRoot "gui/MainWindow.xaml"
$MappingsPath = Join-Path $ProjectRoot "gui/ConfigEditor.Mappings.ps1"

Write-Host "=== Focus Game Deck - ConfigEditor Consistency Test ===" -ForegroundColor Cyan

# Check if required files exist
if (-not (Test-Path $MainWindowPath)) {
    Write-Error "Main.Window.xaml not found at: $MainWindowPath"
    exit 1
}

if (-not (Test-Path $MappingsPath)) {
    Write-Error "ConfigEditor.Mappings.ps1 not found at: $MappingsPath"
    exit 1
}

Write-Host "Checking files:" -ForegroundColor Yellow
Write-Host "- Main.Window.xaml: $MainWindowPath" -ForegroundColor Gray
Write-Host "- Mappings file:   $MappingsPath" -ForegroundColor Gray

try {
    # Load mappings
    Write-Host "Loading ConfigEditor mappings" -ForegroundColor Yellow
    $MappingsPath
    Write-Host "[OK] Mappings loaded successfully" -ForegroundColor Green

    # Extract UI elements and their placeholders from Main.Window.xaml
    Write-Host "Analyzing Main.Window.xaml" -ForegroundColor Yellow
    $content = Get-Content -Path $MainWindowPath -Encoding UTF8 -Raw
    $regex = '<[\w\.:]+\s+(?=[^>]*\bx:Name\s*=\s*"[^"]*")(?=[^>]*\b(Content|Text|Header)\s*=\s*"[^"]*")[^>]*?/?>'
    $matches = [regex]::Matches($content, $regex)

    $uiElements = @{}
    foreach ($match in $matches) {
        $elementText = $match.Value
        $nameMatch = [regex]::Match($elementText, '\bx:Name\s*=\s*"([^"]*)"')
        $placeholderMatch = [regex]::Match($elementText, '\b(?:Content|Text|Header)\s*=\s*"([^"]*)"')

        if ($nameMatch.Success -and $placeholderMatch.Success) {
            $elementName = $nameMatch.Groups[1].Value
            $placeholder = $placeholderMatch.Groups[1].Value
            $uiElements[$elementName] = $placeholder
        }
    }

    Write-Host "[OK] Extracted $($uiElements.Count) UI elements with placeholders" -ForegroundColor Green

    if ($ShowDetails) {
        Write-Host ""
        Write-Host "UI Elements found:" -ForegroundColor Blue
        $uiElements.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "$($_.Key) -> [$($_.Value)]" -ForegroundColor Gray
        }
    }
    Write-Host ""

    # Check mapping completeness
    Write-Host "Checking mapping completeness" -ForegroundColor Yellow
    $missingMappings = @()
    $foundMappings = @()

    $allMappingTables = @($ButtonMappings, $LabelMappings, $TabMappings, $TextMappings, $CheckBoxMappings, $MenuItemMappings)

    foreach ($elementName in $uiElementsKeys) {
        $found = $false
        $mappingType = ""

        foreach ($mappingTable in $allMappingTables) {
            if ($mappingTableContainsKey[$elementName]) {
                $found = $true
                $mappingKey = $mappingTable[$elementName]

                # Determine mapping type
                switch ($mappingTable) {
                    { $_ -eq $ButtonMappings } { $mappingType = "Button" }
                    { $_ -eq $LabelMappings } { $mappingType = "Label" }
                    { $_ -eq $TabMappings } { $mappingType = "Tab" }
                    { $_ -eq $TextMappings } { $mappingType = "Text" }
                    { $_ -eq $CheckBoxMappings } { $mappingType = "CheckBox" }
                    { $_ -eq $MenuItemMappings } { $mappingType = "MenuItem" }
                }

                $foundMappings += [PSCustomObject]@{
                    ElementName = $elementName
                    Placeholder = $uiElements[$elementName]
                    MappingKey  = $mappingKey
                    Type        = $mappingType
                }
                break
            }
        }

        if (-not $found) {
            $missingMappings += [PSCustomObject]@{
                ElementName = $elementName
                Placeholder = $uiElements[$elementName]
            }
        }
    }

    # Display results
    Write-Host "Mapping Analysis Results:" -ForegroundColor Blue
    Write-Host "- Total UI elements: $($uiElementsCount)" -ForegroundColor Gray
    Write-Host "- Mapped elements:   $($foundMappingsCount)" -ForegroundColor Green
    Write-Host "- Missing mappings:  $($missingMappingsCount)" -ForegroundColor $(if ($missingMappingsCount -eq 0) { "Green" } else { "Red" })
    Write-Host ""

    if ($ShowDetails -and $foundMappingsCount -gt 0) {
        Write-Host "[OK] Successfully mapped elements:" -ForegroundColor Green
        $foundMappings | Sort-Object ElementName | ForEach-Object {
            Write-Host "   [$($_Type)] $($_ElementName) -> $($_MappingKey)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Show mapping statistics by type
    if ($ShowDetails) {
        Write-Host "Mapping statistics by type:" -ForegroundColor Blue
        $typeStats = $foundMappings | Group-Object Type | Sort-Object Name
        foreach ($stat in $typeStats) {
            Write-Host "   $($statName): $($statCount) elements" -ForegroundColor Gray
        }
    }

    # Final result
    if ($missingMappingsCount -eq 0) {
        Write-Host "TEST PASSED: All UI elements have corresponding mappings!" -ForegroundColor Green
        Write-Host "- ConfigEditor localization system is consistent" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[NG] TEST FAILED: Missing mappings detected!" -ForegroundColor Red
        Write-Host "Elements requiring mappings:" -ForegroundColor Yellow
        $missingMappings | Sort-Object ElementName | ForEach-Object {
            Write-Host "   - $($_ElementName) [Placeholder: $($_Placeholder)]" -ForegroundColor Red
        }
        Write-Host "Please add the missing mappings to ConfigEditor.Mappings.ps1" -ForegroundColor Yellow
        exit 1
    }

} catch {
    Write-Host "[NG] TEST ERROR: $($_ExceptionMessage)" -ForegroundColor Red
    Write-Host "Stack trace: $($_ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
