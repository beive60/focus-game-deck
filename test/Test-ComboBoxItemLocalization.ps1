<#
.SYNOPSIS
    Test script to verify ComboBoxItem localization functionality.

.DESCRIPTION
    This script tests that ComboBoxItem elements in MainWindow.xaml are properly
    localized using the mappings in ConfigEditor.Mappings.ps1 and messages in messages.json.
#>

param(
    [Parameter()]
    [ValidateSet("ja", "en", "zh-CN")]
    [string]$Language = "ja"
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Define project root and script paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GuiPath = Join-Path $ProjectRoot "gui"
$MappingsPath = Join-Path $GuiPath "ConfigEditor.Mappings.ps1"
$MessagesPath = Join-Path $GuiPath "messages.json"
$XamlPath = Join-Path $GuiPath "MainWindow.xaml"

Write-Host "=== ComboBoxItem Localization Test ===" -ForegroundColor Cyan
Write-Host "Testing language: $Language" -ForegroundColor Yellow
Write-Host ""

# Load WPF assemblies
Write-Host "[1/6] Loading WPF assemblies..." -ForegroundColor Cyan
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Load mappings
Write-Host "[2/6] Loading mappings..." -ForegroundColor Cyan
. $MappingsPath

# Load messages
Write-Host "[3/6] Loading messages..." -ForegroundColor Cyan
$messagesJson = Get-Content $MessagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$messages = $messagesJson.$Language

Write-Host "Messages loaded for '$Language'. Total message count: $($messages.PSObject.Properties.Count)" -ForegroundColor Green
Write-Host ""

# Load XAML
Write-Host "[4/6] Loading and parsing XAML..." -ForegroundColor Cyan
$xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
$xmlReader.Close()

Write-Host "XAML parsed successfully" -ForegroundColor Green
Write-Host ""

# Test ComboBoxItem localization
Write-Host "[5/6] Testing ComboBoxItem localization..." -ForegroundColor Cyan
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
                Write-Host "  [OK] $itemName" -ForegroundColor Green
                Write-Host "       Before: '$($result.BeforeContent)'" -ForegroundColor DarkGray
                Write-Host "       After : '$($result.AfterContent)'" -ForegroundColor DarkGray
            } else {
                $testResults.Failed++
                Write-Host "  [FAIL] $itemName - Content not updated correctly" -ForegroundColor Red
            }
        } else {
            $testResults.Failed++
            Write-Host "  [FAIL] $itemName - Message key '$messageKey' not found in messages" -ForegroundColor Red
        }
    } else {
        $testResults.Failed++
        Write-Host "  [FAIL] $itemName - Element not found in XAML" -ForegroundColor Red
    }

    $testResults.Details += $result
}

Write-Host ""
Write-Host "[6/6] Test Summary" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Total ComboBoxItems tested: $($testResults.Total)" -ForegroundColor White
Write-Host "Successful: $($testResults.Success)" -ForegroundColor Green
Write-Host "Failed: $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -eq 0) { "Green" } else { "Red" })

if ($testResults.Failed -gt 0) {
    Write-Host ""
    Write-Host "Failed items:" -ForegroundColor Red
    foreach ($detail in $testResults.Details | Where-Object { -not $_.Success }) {
        Write-Host "  - $($detail.ItemName)" -ForegroundColor Red
        if (-not $detail.Found) {
            Write-Host "    Reason: Element not found in XAML" -ForegroundColor DarkRed
        } elseif (-not $detail.HasMessage) {
            Write-Host "    Reason: Message key '$($detail.MessageKey)' not found" -ForegroundColor DarkRed
        } else {
            Write-Host "    Reason: Content update failed" -ForegroundColor DarkRed
        }
    }
}

Write-Host ""
if ($testResults.Failed -eq 0) {
    Write-Host "All ComboBoxItem localization tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some ComboBoxItem localization tests failed." -ForegroundColor Red
    exit 1
}
