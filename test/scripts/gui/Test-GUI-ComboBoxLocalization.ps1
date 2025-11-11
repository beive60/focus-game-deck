<#
.SYNOPSIS
    Test script to verify ComboBoxItem localization functionality.

.DESCRIPTION
    This script tests that ComboBoxItem elements in MainWindow.xaml are properly
    localized using the mappings in ConfigEditor.Mappings.ps1 and messages in messages.json.

    The test performs the following validations:
    - Loads WPF assemblies and XAML definitions
    - Reads ComboBoxItem mappings from ConfigEditor.Mappings.ps1
    - Loads localized messages for the specified language
    - Verifies each ComboBoxItem can be found in XAML
    - Validates message keys exist in messages.json
    - Tests that Content property updates correctly with localized text

    This ensures the ConfigEditor GUI displays properly localized ComboBox options
    for all supported languages.

.PARAMETER Language
    The language code to test. Valid values are "ja" (Japanese), "en" (English),
    or "zh-CN" (Chinese Simplified). Defaults to "ja".

.EXAMPLE
    .\Test-ComboBoxItemLocalization.ps1
    Tests ComboBoxItem localization using Japanese language (default).

.EXAMPLE
    .\Test-ComboBoxItemLocalization.ps1 -Language en
    Tests ComboBoxItem localization using English language.

.EXAMPLE
    .\Test-ComboBoxItemLocalization.ps1 -Language zh-CN
    Tests ComboBoxItem localization using Chinese Simplified language.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0

    Test Steps:
    1. Load WPF assemblies (PresentationFramework, PresentationCore, WindowsBase)
    2. Load ComboBoxItem mappings from ConfigEditor.Mappings.ps1
    3. Load localized messages from messages.json
    4. Parse MainWindow.xaml
    5. Validate each ComboBoxItem element and its localization
    6. Generate test summary report

    Exit Codes:
    - 0: All ComboBoxItem localization tests passed
    - 1: One or more tests failed

    Dependencies:
    - gui/ConfigEditor.Mappings.ps1 (ComboBoxItem mapping definitions)
    - localization/messages.json (localized message strings)
    - gui/MainWindow.xaml (GUI layout definition)
    - .NET WPF assemblies
#>

param(
    [Parameter()]
    [ValidateSet("ja", "en", "zh-CN")]
    [string]$Language = "ja"
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Define project root and script paths
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$GuiPath = Join-Path -Path $projectRoot -ChildPath "gui"
$MappingsPath = Join-Path -Path $GuiPath -ChildPath "ConfigEditor.Mappings.ps1"
$MessagesPath = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
$XamlPath = Join-Path -Path $GuiPath -ChildPath "MainWindow.xaml"

Write-Host "=== ComboBoxItem Localization Test ==="
Write-Host "Testing language: $Language"
Write-Host ""

# Load WPF assemblies
Write-Host "[1/6] Loading WPF assemblies..."
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Load mappings
Write-Host "[2/6] Loading mappings..."
. $MappingsPath

# Load messages
Write-Host "[3/6] Loading messages..."
$messagesJson = Get-Content $MessagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$messages = $messagesJson.$Language

Write-Host "Messages loaded for '$Language'. Total message count: $($messages.PSObject.Properties.Count)"
Write-Host ""

# Load XAML
Write-Host "[4/6] Loading and parsing XAML..."
$xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
$xmlReader.Close()

Write-Host "XAML parsed successfully"
Write-Host ""

# Test ComboBoxItem localization
Write-Host "[5/6] Testing ComboBoxItem localization..."
$comboBoxItemMappings = $script:ComboBoxItemMappings

$testResults = @{
    Total   = 0
    Success = 0
    Failed  = 0
    Details = @()
}

foreach ($itemName in $comboBoxItemMappings.Keys) {
    $testResults.Total++
    $messageKey = $comboBoxItemMappings[$itemName]
    $element = $window.FindName($itemName)

    $result = @{
        ItemName      = $itemName
        MessageKey    = $messageKey
        Found         = $false
        HasMessage    = $false
        BeforeContent = ""
        AfterContent  = ""
        Success       = $false
    }

    if ($element) {
        $result.Found = $true
        $result.BeforeContent = $element.Content

        if ($messages.PSObject.Properties[$messageKey]) {
            $result.HasMessage = $true
            $localizedText = $messages.$messageKey
            $element.Content = $localizedText
            $result.AfterContent = $element.Content

            if ($element.Content -eq $localizedText) {
                $result.Success = $true
                $testResults.Success++
                Write-Host "  [OK] $itemName"
                Write-Host "       Before: '$($result.BeforeContent)'"
                Write-Host "       After : '$($result.AfterContent)'"
            } else {
                $testResults.Failed++
                Write-Host "  [FAIL] $itemName - Content not updated correctly"
            }
        } else {
            $testResults.Failed++
            Write-Host "  [FAIL] $itemName - Message key '$messageKey' not found in messages"
        }
    } else {
        $testResults.Failed++
        Write-Host "  [FAIL] $itemName - Element not found in XAML"
    }

    $testResults.Details += $result
}

Write-Host ""
Write-Host "[6/6] Test Summary"
Write-Host "=================="
Write-Host "Total ComboBoxItems tested: $($testResults.Total)"
Write-Host "Successful: $($testResults.Success)"
if ($testResults.Failed -eq 0) {
    Write-Host "[OK] Failed: $($testResults.Failed)"
} else {
    Write-Host "[ERROR] Failed: $($testResults.Failed)"
}

if ($testResults.Failed -gt 0) {
    Write-Host ""
    Write-Host "Failed items:"
    foreach ($detail in $testResults.Details | Where-Object { -not $_.Success }) {
        Write-Host "  - $($detail.ItemName)"
        if (-not $detail.Found) {
            Write-Host "    Reason: Element not found in XAML"
        } elseif (-not $detail.HasMessage) {
            Write-Host "    Reason: Message key '$($detail.MessageKey)' not found"
        } else {
            Write-Host "    Reason: Content update failed"
        }
    }
}

Write-Host ""
if ($testResults.Failed -eq 0) {
    Write-Host "[OK] All ComboBoxItem localization tests passed!"
    exit 0
} else {
    Write-Host "[ERROR] Some ComboBoxItem localization tests failed."
    exit 1
}
