<#
.SYNOPSIS
    Test script to verify that all UI element mappings are complete and consistent.

.DESCRIPTION
    This script validates that:
    1. All mappings defined in ConfigEditor.Mappings.ps1 are included in $allMappings
    2. All mapped elements exist in MainWindow.xaml
    3. All message keys referenced in mappings exist in messages.json
    4. No UI elements with x:Name in XAML are missing from mappings (with exceptions)
#>

param(
    [Parameter()]
    [switch]$ShowDetails
)

$ErrorActionPreference = "Stop"
if ($ShowDetails) {
    $VerbosePreference = "Continue"
}

# Define project root and script paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GuiPath = Join-Path $ProjectRoot "gui"
$MappingsPath = Join-Path $GuiPath "ConfigEditor.Mappings.ps1"
$MessagesPath = Join-Path $GuiPath "messages.json"
$XamlPath = Join-Path $GuiPath "MainWindow.xaml"
$ConfigEditorPath = Join-Path $GuiPath "ConfigEditor.ps1"

Write-Host "=== Mapping Completeness Test ==="
Write-Host ""

# Test results structure
$testResults = @{
    Total           = 0
    Passed          = 0
    Failed          = 0
    Warnings        = 0
    FailedTests     = @()
    WarningMessages = @()
}

function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [bool]$IsWarning = $false
    )

    $testResults.Total++

    if ($IsWarning) {
        $testResults.Warnings++
        $testResults.WarningMessages += @{
            TestName = $TestName
            Message  = $Message
        }
        Write-Host "  [WARN] $TestName"
        if ($Message) {
            Write-Host "         $Message"
        }
    } elseif ($Passed) {
        $testResults.Passed++
        Write-Host "  [PASS] $TestName"
    } else {
        $testResults.Failed++
        $testResults.FailedTests += @{
            TestName = $TestName
            Message  = $Message
        }
        Write-Host "  [FAIL] $TestName"
        if ($Message) {
            Write-Host "         $Message"
        }
    }
}

# Test 1: Load mappings
Write-Host "[1/6] Loading mappings from ConfigEditor.Mappings.ps1..."
try {
    . $MappingsPath
    Add-TestResult "Load ConfigEditor.Mappings.ps1" $true
} catch {
    Add-TestResult "Load ConfigEditor.Mappings.ps1" $false "Failed to load: $($_.Exception.Message)"
    exit 1
}

# Test 2: Verify all mapping variables exist
Write-Host ""
Write-Host "[2/6] Verifying mapping variables exist..."

$expectedMappings = @(
    "ButtonMappings",
    "LabelMappings",
    "TabMappings",
    "TextMappings",
    "CheckBoxMappings",
    "MenuItemMappings",
    "TooltipMappings",
    "ComboBoxItemMappings",
    "GameActionMessageKeys"
)

foreach ($mappingName in $expectedMappings) {
    $mapping = Get-Variable -Name $mappingName -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($mapping -and $mapping -is [hashtable]) {
        Add-TestResult "Mapping variable '$mappingName' exists" $true
        Write-Verbose "  ${mappingName}: $($mapping.Count) items"
    } else {
        Add-TestResult "Mapping variable '$mappingName' exists" $false "Variable not found or is not a hashtable"
    }
}

# Test 3: Verify ConfigEditor.ps1 includes all mappings in $allMappings
Write-Host ""
Write-Host "[3/6] Verifying $allMappings completeness in ConfigEditor.ps1..."

$configEditorContent = Get-Content $ConfigEditorPath -Raw
$allMappingsPattern = '\$allMappings\s*=\s*@\{([^}]+)\}'
if ($configEditorContent -match $allMappingsPattern) {
    $allMappingsBlock = $Matches[1]

    # Check each mapping type (excluding GameActionMessageKeys as it's not directly in $allMappings)
    $mappingsToCheck = @(
        @{ Name = "Button"; Pattern = "Button\s*=" }
        @{ Name = "Label"; Pattern = "Label\s*=" }
        @{ Name = "Tab"; Pattern = "Tab\s*=" }
        @{ Name = "Text"; Pattern = "Text\s*=" }
        @{ Name = "CheckBox"; Pattern = "CheckBox\s*=" }
        @{ Name = "MenuItem"; Pattern = "MenuItem\s*=" }
        @{ Name = "Tooltip"; Pattern = "Tooltip\s*=" }
        @{ Name = "ComboBoxItem"; Pattern = "ComboBoxItem\s*=" }
    )

    foreach ($mappingCheck in $mappingsToCheck) {
        if ($allMappingsBlock -match $mappingCheck.Pattern) {
            Add-TestResult "$($mappingCheck.Name) mapping in `$allMappings" $true
        } else {
            Add-TestResult "$($mappingCheck.Name) mapping in `$allMappings" $false "Not found in ConfigEditor.ps1 `$allMappings"
        }
    }
} else {
    Add-TestResult "Find `$allMappings in ConfigEditor.ps1" $false "Could not find `$allMappings definition"
}

# Test 4: Load XAML and verify mapped elements exist
Write-Host ""
Write-Host "[4/6] Verifying mapped elements exist in XAML..."

Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
$xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
$xmlReader.Close()

$allMappingsToCheck = @{
    Button       = $script:ButtonMappings
    Label        = $script:LabelMappings
    Tab          = $script:TabMappings
    Text         = $script:TextMappings
    CheckBox     = $script:CheckBoxMappings
    MenuItem     = $script:MenuItemMappings
    ComboBoxItem = $script:ComboBoxItemMappings
}

$missingElements = @()
foreach ($mappingType in $allMappingsToCheck.Keys) {
    $mapping = $allMappingsToCheck[$mappingType]
    foreach ($elementName in $mapping.Keys) {
        $element = $window.FindName($elementName)
        if (-not $element) {
            $missingElements += "$mappingType : $elementName"
        }
    }
}

if ($missingElements.Count -eq 0) {
    Add-TestResult "All mapped elements exist in XAML" $true
} else {
    Add-TestResult "All mapped elements exist in XAML" $false "$($missingElements.Count) elements not found"
    foreach ($missing in $missingElements) {
        Write-Verbose "  Missing: $missing"
    }
}

# Test 5: Verify all message keys exist in messages.json
Write-Host ""
Write-Host "[5/6] Verifying message keys exist in messages.json..."

$messagesJson = Get-Content $MessagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$languages = @("ja", "en", "zh-CN")

$missingKeys = @()
foreach ($lang in $languages) {
    if (-not $messagesJson.PSObject.Properties[$lang]) {
        Add-TestResult "Language '$lang' exists in messages.json" $false
        continue
    }

    $languageMessages = $messagesJson.$lang

    # Check all mappings except GameActionMessageKeys (checked separately)
    foreach ($mappingType in $allMappingsToCheck.Keys) {
        $mapping = $allMappingsToCheck[$mappingType]
        foreach ($kvp in $mapping.GetEnumerator()) {
            $messageKey = $kvp.Value
            if (-not $languageMessages.PSObject.Properties[$messageKey]) {
                $missingKeys += "$lang : $messageKey (from $mappingType.$($kvp.Key))"
            }
        }
    }

    # Check GameActionMessageKeys
    foreach ($kvp in $script:GameActionMessageKeys.GetEnumerator()) {
        $messageKey = $kvp.Value
        if (-not $languageMessages.PSObject.Properties[$messageKey]) {
            $missingKeys += "$lang : $messageKey (from GameActionMessageKeys.$($kvp.Key))"
        }
    }
}

if ($missingKeys.Count -eq 0) {
    Add-TestResult "All message keys exist in messages.json" $true
} else {
    Add-TestResult "All message keys exist in messages.json" $false "$($missingKeys.Count) keys missing"
    foreach ($missing in $missingKeys | Select-Object -First 10) {
        Write-Verbose "  Missing: $missing"
    }
    if ($missingKeys.Count -gt 10) {
        Write-Verbose "  ... and $($missingKeys.Count - 10) more"
    }
}

# Test 6: Find potentially unmapped elements in XAML
Write-Host ""
Write-Host "[6/6] Checking for potentially unmapped elements in XAML..."

# Elements that are dynamically created or don't need localization
$excludedElements = @(
    "MainTabControl",
    "GamesList",
    "ManagedAppsList",
    "GameLauncherList",
    "GameIdTextBox",
    "GameNameTextBox",
    "SteamAppIdTextBox",
    "EpicGameIdTextBox",
    "RiotGameIdTextBox",
    "ExecutablePathTextBox",
    "ProcessNameTextBox",
    "AppIdTextBox",
    "AppPathTextBox",
    "AppProcessNameTextBox",
    "AppArgumentsTextBox",
    "GracefulTimeoutTextBox",
    "ObsHostTextBox",
    "ObsPortTextBox",
    "ObsPasswordBox",
    "SteamPathTextBox",
    "EpicPathTextBox",
    "RiotPathTextBox",
    "ObsPathTextBox",
    "LanguageCombo",
    "LauncherTypeCombo",
    "LogRetentionCombo",
    "PlatformComboBox",
    "GameLauncherTypeCombo",
    "GameStartActionCombo",
    "GameEndActionCombo",
    "TerminationMethodCombo",
    "VersionText",
    "AppsToManagePanel",
    "ManagedAppsBottomGrid",
    # Tooltip TextBlocks
    "GameIdTooltip",
    "GameNameTooltip",
    "SteamAppIdTooltip",
    "EpicGameIdTooltip",
    "RiotGameIdTooltip",
    "ExecutablePathTooltip",
    "ProcessNameTooltip",
    "AppIdTooltip",
    "AppProcessNameTooltip",
    "GameStartActionTooltip",
    "GameEndActionTooltip",
    "AppArgumentsTooltip",
    "TerminationMethodTooltip",
    "GracefulTimeoutTooltip",
    "AutoDetectSteamTooltip",
    "AutoDetectEpicTooltip",
    "AutoDetectRiotTooltip",
    "AutoDetectObsTooltip",
    # StackPanels for labels with tooltips
    "GameIdLabelPanel",
    "GameNameLabelPanel",
    "SteamAppIdLabelPanel",
    "EpicGameIdLabelPanel",
    "RiotGameIdLabelPanel",
    "ExecutablePathLabelPanel",
    "ProcessNameLabelPanel",
    "ExecutablePathInputGrid",
    "AppIdLabelPanel",
    "AppProcessNameLabelPanel",
    "GameStartActionLabelPanel",
    "GameEndActionLabelPanel",
    "AppArgumentsLabelPanel",
    "TerminationMethodLabelPanel",
    "GracefulTimeoutLabelPanel"
)

# Extract all x:Name attributes from XAML
$xNamePattern = 'x:Name="([^"]+)"'
$xNameMatches = [regex]::Matches($xamlContent, $xNamePattern)
$xamlElementNames = $xNameMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

# Find elements not in any mapping
$allMappedElements = @()
foreach ($mapping in $allMappingsToCheck.Values) {
    $allMappedElements += $mapping.Keys
}
$allMappedElements += $excludedElements
$allMappedElements = $allMappedElements | Sort-Object -Unique

$unmappedElements = $xamlElementNames | Where-Object { $_ -notin $allMappedElements }

if ($unmappedElements.Count -eq 0) {
    Add-TestResult "All XAML elements are mapped or excluded" $true
} else {
    Add-TestResult "Potentially unmapped XAML elements found" $false "" $true
    foreach ($unmapped in $unmappedElements) {
        Write-Verbose "  Unmapped: $unmapped"
    }
}

# Summary
Write-Host ""
Write-Host "==================="
Write-Host "Test Summary"
Write-Host "==================="
Write-Host "Total Tests: $($testResults.Total)"
Write-Host "Passed: $($testResults.Passed)"
Write-Host "Failed: $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -eq 0) { "Green" } else { "Red" })
Write-Host "Warnings: $($testResults.Warnings)"

if ($testResults.Failed -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:"
    foreach ($failed in $testResults.FailedTests) {
        Write-Host "  - $($failed.TestName)"
        if ($failed.Message) {
            Write-Host "    $($failed.Message)"
        }
    }
}

if ($testResults.Warnings -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($warning in $testResults.WarningMessages) {
        Write-Host "  - $($warning.TestName)"
        if ($warning.Message) {
            Write-Host "    $($warning.Message)"
        }
    }
}

Write-Host ""
if ($testResults.Failed -eq 0) {
    Write-Host "All critical tests passed!"
    if ($testResults.Warnings -gt 0) {
        Write-Host "Note: There are $($testResults.Warnings) warning(s) that may need attention."
    }
    exit 0
} else {
    Write-Host "Some tests failed. Please review and fix the issues."
    exit 1
}
