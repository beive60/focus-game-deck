<#
.SYNOPSIS
    Tests consistency between MainWindow.xaml and ConfigEditor.Mappings.ps1

.DESCRIPTION
    This test verifies that all UI elements with placeholders in MainWindow.xaml
    have corresponding mappings defined in ConfigEditor.Mappings.ps1.
    This ensures the localization system works properly.

.PARAMETER ShowDetails
    Enable detailed output showing mapping information.

.EXAMPLE
    .\Test-ConfigEditorConsistency.ps1

.EXAMPLE
    .\Test-ConfigEditorConsistency.ps1 -ShowDetails

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Created: 2025-10-12
#>

[CmdletBinding()]
param(
    [switch]$ShowDetails
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Define paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
$MainWindowPath = Join-Path $ProjectRoot "gui/MainWindow.xaml"
$MappingsPath = Join-Path $ProjectRoot "gui/ConfigEditor.Mappings.ps1"

Write-Host "🔍 Focus Game Deck - ConfigEditor Consistency Test" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Check if required files exist
if (-not (Test-Path $MainWindowPath)) {
    Write-Error "MainWindow.xaml not found at: $MainWindowPath"
    exit 1
}

if (-not (Test-Path $MappingsPath)) {
    Write-Error "ConfigEditor.Mappings.ps1 not found at: $MappingsPath"
    exit 1
}

Write-Host "📂 Checking files:" -ForegroundColor Yellow
Write-Host "   MainWindow.xaml: $MainWindowPath" -ForegroundColor Gray
Write-Host "   Mappings file:   $MappingsPath" -ForegroundColor Gray
Write-Host ""

try {
    # Load mappings
    Write-Host "📥 Loading ConfigEditor mappings..." -ForegroundColor Yellow
    . $MappingsPath
    Write-Host "   ✅ Mappings loaded successfully" -ForegroundColor Green
    Write-Host ""

    # Extract UI elements and their placeholders from MainWindow.xaml
    Write-Host "🔍 Analyzing MainWindow.xaml..." -ForegroundColor Yellow
    $content = Get-Content $MainWindowPath -Raw
    $matches = [regex]::Matches($content, 'Name="([^"]+)"[^>]*(?:Content|Text|Header)="\[([^]]+)\]"')

    $uiElements = @{}
    foreach ($match in $matches) {
        $elementName = $match.Groups[1].Value
        $placeholder = $match.Groups[2].Value
        $uiElements[$elementName] = $placeholder
    }

    Write-Host "   ✅ Found $($uiElements.Count) UI elements with placeholders" -ForegroundColor Green

    if ($ShowDetails) {
        Write-Host ""
        Write-Host "📋 UI Elements found:" -ForegroundColor Blue
        $uiElements.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "   $($_.Key) -> [$($_.Value)]" -ForegroundColor Gray
        }
    }
    Write-Host ""

    # Check mapping completeness
    Write-Host "🔍 Checking mapping completeness..." -ForegroundColor Yellow
    $missingMappings = @()
    $foundMappings = @()

    $allMappingTables = @($ButtonMappings, $LabelMappings, $TabMappings, $TextMappings, $CheckBoxMappings, $MenuItemMappings)

    foreach ($elementName in $uiElements.Keys) {
        $found = $false
        $mappingType = ""

        foreach ($mappingTable in $allMappingTables) {
            if ($mappingTable.ContainsKey($elementName)) {
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
                    MappingKey = $mappingKey
                    Type = $mappingType
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
    Write-Host "📊 Mapping Analysis Results:" -ForegroundColor Blue
    Write-Host "   Total UI elements: $($uiElements.Count)" -ForegroundColor Gray
    Write-Host "   Mapped elements:   $($foundMappings.Count)" -ForegroundColor Green
    Write-Host "   Missing mappings:  $($missingMappings.Count)" -ForegroundColor $(if ($missingMappings.Count -eq 0) { "Green" } else { "Red" })
    Write-Host ""

    if ($ShowDetails -and $foundMappings.Count -gt 0) {
        Write-Host "✅ Successfully mapped elements:" -ForegroundColor Green
        $foundMappings | Sort-Object ElementName | ForEach-Object {
            Write-Host "   [$($_.Type)] $($_.ElementName) -> $($_.MappingKey)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Show mapping statistics by type
    if ($ShowDetails) {
        Write-Host "📈 Mapping statistics by type:" -ForegroundColor Blue
        $typeStats = $foundMappings | Group-Object Type | Sort-Object Name
        foreach ($stat in $typeStats) {
            Write-Host "   $($stat.Name): $($stat.Count) elements" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Final result
    if ($missingMappings.Count -eq 0) {
        Write-Host "🎉 TEST PASSED: All UI elements have corresponding mappings!" -ForegroundColor Green
        Write-Host "   ConfigEditor localization system is consistent." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ TEST FAILED: Missing mappings detected!" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Elements requiring mappings:" -ForegroundColor Yellow
        $missingMappings | Sort-Object ElementName | ForEach-Object {
            Write-Host "   - $($_.ElementName) [Placeholder: $($_.Placeholder)]" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "💡 Please add the missing mappings to ConfigEditor.Mappings.ps1" -ForegroundColor Yellow
        exit 1
    }

} catch {
    Write-Host "❌ TEST ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
