<#
.SYNOPSIS
    Tests consistency between MainWindow.xaml and ConfigEditor.Mappings.ps1

.DESCRIPTION
    This test verifies that all UI elements with placeholders in MainWindow.xaml
    have corresponding mappings defined in ConfigEditor.Mappings.ps1
    This ensures the localization system works properly

.PARAMETER ShowDetails
    Enable detailed output showing mapping information

.EXAMPLE
    .\Test-ConfigEditorConsistency.ps1

.EXAMPLE
    .\Test-ConfigEditorConsistency.ps1 -ShowDetails

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.1
    Created: 2025-10-12
#>

[CmdletBinding()]
param(
    [switch]$ShowDetails
)


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
# Set error action preference
$ErrorActionPreference = 'Stop'

# Define paths
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$MappingsPath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.Mappings.ps1"
$MessagesPath = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
$XamlPath = Join-Path -Path $projectRoot -ChildPath "gui/MainWindow.xaml"
$ConfigEditorPath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.ps1"

Write-BuildLog "=== Focus Game Deck - ConfigEditor Consistency Test ==="

# Check if required files exist
if (-not (Test-Path $XamlPath)) {
    Write-BuildLog "MainWindow.xaml not found at: $XamlPath" -Level Error
    exit 1
}

if (-not (Test-Path $MappingsPath)) {
    Write-BuildLog "ConfigEditor.Mappings.ps1 not found at: $MappingsPath" -Level Error
    exit 1
}

Write-BuildLog "Checking files:"
Write-BuildLog "- MainWindow.xaml: $MainWindowPath"
Write-BuildLog "- Mappings file:   $MappingsPath"

try {
    # Load mappings
    Write-BuildLog "Loading ConfigEditor mappings"
    . $MappingsPath
    Write-BuildLog "[OK] Mappings loaded successfully"

    # Extract UI elements and their placeholders from MainWindow.xaml
    Write-BuildLog "Analyzing MainWindow.xaml"
    $content = Get-Content -Path $MainWindowPath -Encoding UTF8 -Raw
    $regex = '<[\w\.:]+\s+(?=[^>]*\bx:Name\s*=\s*"[^"]*")(?=[^>]*\b(Content|Text|Header|ToolTip)\s*=\s*"[^"]*")[^>]*?/?>'
    $matches = [regex]::Matches($content, $regex)

    $uiElements = @{}
    foreach ($match in $matches) {
        $elementText = $match.Value
        $nameMatch = [regex]::Match($elementText, '\bx:Name\s*=\s*"([^"]*)"')
        $placeholderMatch = [regex]::Match($elementText, '\b(?:Content|Text|Header|ToolTip)\s*=\s*"([^"]*)"')

        if ($nameMatch.Success -and $placeholderMatch.Success) {
            $elementName = $nameMatch.Groups[1].Value
            $placeholder = $placeholderMatch.Groups[1].Value
            $uiElements[$elementName] = $placeholder
        }
    }

    Write-BuildLog "[OK] Extracted $($uiElements.Count) UI elements with placeholders"

    if ($ShowDetails) {
        Write-Host ""
        Write-BuildLog "UI Elements found:"
        $uiElements.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-BuildLog "$($_.Key) -> [$($_.Value)]"
        }
    }
    Write-Host ""

    # Check mapping completeness
    Write-BuildLog "Checking mapping completeness"
    $missingMappings = @()
    $foundMappings = @()

    $allMappingTables = @{
        Button = $ButtonMappings
        Label = $LabelMappings
        Tab = $TabMappings
        Text = $TextMappings
        CheckBox = $CheckBoxMappings
        RadioButton = $RadioButtonMappings
        MenuItem = $MenuItemMappings
        Tooltip = $TooltipMappings
    }

    foreach ($elementName in $uiElements.Keys) {
        $found = $false
        foreach ($type in $allMappingTables.Keys) {
            $mappingTable = $allMappingTables[$type]
            if ($mappingTable.ContainsKey($elementName)) {
                $found = $true
                $mappingKey = $mappingTable[$elementName]

                $foundMappings += [PSCustomObject]@{
                    ElementName = $elementName
                    Placeholder = $uiElements[$elementName]
                    MappingKey = $mappingKey
                    Type = $type
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
    $uiElementsCount = $uiElements.Count
    $foundMappingsCount = $foundMappings.Count
    $missingMappingsCount = $missingMappings.Count

    Write-BuildLog "Mapping Analysis Results:"
    Write-BuildLog "- Total UI elements: $($uiElementsCount)"
    Write-BuildLog "- Mapped elements:   $($foundMappingsCount)"
    if ($missingMappingsCount -eq 0) {
        Write-BuildLog "[OK] - Missing mappings:  $($missingMappingsCount)"
    } else {
        Write-BuildLog "[ERROR] - Missing mappings:  $($missingMappingsCount)"
    }
    Write-Host ""

    if ($ShowDetails -and $foundMappingsCount -gt 0) {
        Write-BuildLog "[OK] Successfully mapped elements:"
        $foundMappings | Sort-Object ElementName | ForEach-Object {
            Write-BuildLog "   [$($_.Type)] $($_.ElementName) -> $($_.MappingKey)"
        }
        Write-Host ""
    }

    # Show mapping statistics by type
    if ($ShowDetails) {
        Write-BuildLog "Mapping statistics by type:"
        $foundMappings | Group-Object Type | Sort-Object Name | ForEach-Object {
            Write-BuildLog "   $($_.Name): $($_.Count) elements"
        }
        Write-Host ""
    }

    # Final result
    if ($missingMappingsCount -eq 0) {
        Write-BuildLog "[OK] TEST PASSED: All UI elements have corresponding mappings!"
        Write-BuildLog "[OK] - ConfigEditor localization system is consistent"
        exit 0
    } else {
        Write-BuildLog "[ERROR] TEST FAILED: Missing mappings detected!"
        Write-BuildLog "[ERROR] Elements requiring mappings:"
        $missingMappings | Sort-Object ElementName | ForEach-Object {
            Write-BuildLog "   - $($_.ElementName) [Placeholder: $($_.Placeholder)]"
        }
        Write-BuildLog "Please add the missing mappings to ConfigEditor.Mappings.ps1"
        exit 1
    }

} catch {
    Write-BuildLog "[NG] TEST ERROR: $($_.Exception.Message)"
    Write-BuildLog "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
