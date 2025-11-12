<#
.SYNOPSIS
    Test script to verify that all UI element mappings are complete and consistent.

.DESCRIPTION
    This comprehensive test script validates the integrity and completeness of the
    ConfigEditor localization mapping system. It ensures that all UI elements in
    MainWindow.xaml have corresponding mappings to localized message keys, and that
    all message keys exist in messages.json.

    The test performs six major validation checks:
    1. Mappings file loading and structure validation
    2. All mapping categories are included in $allMappings collection
    3. All mapped UI element names exist in MainWindow.xaml
    4. All message keys referenced in mappings exist in messages.json
    5. ConfigEditor.ps1 uses the correct $allMappings variable
    6. No UI elements in XAML are missing from mappings (excluding known exceptions)

    This test is critical for maintaining the internationalization (i18n) system
    integrity as it catches:
    - Orphaned mappings (pointing to non-existent UI elements)
    - Missing mappings (UI elements without localization)
    - Invalid message keys (references to non-existent messages)
    - Inconsistencies between mapping definitions and usage

.PARAMETER ShowDetails
    When specified, enables verbose output showing detailed information about
    each mapping category, successfully mapped elements, and mapping statistics
    by type (Label, Button, TextBlock, etc.).

.EXAMPLE
    .\Test-MappingCompleteness.ps1
    Runs the mapping completeness test with standard output showing pass/fail results.

.EXAMPLE
    .\Test-MappingCompleteness.ps1 -ShowDetails
    Runs the test with detailed output including all successfully mapped elements
    and statistics by UI element type.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0

    Test Categories:
    - LabelMappings: Label elements in the UI
    - TextBlockMappings: TextBlock elements for static text
    - ButtonMappings: Button elements and their Content
    - GroupBoxMappings: GroupBox headers
    - CheckBoxMappings: CheckBox labels
    - ComboBoxItemMappings: ComboBox item options
    - TabItemMappings: Tab headers in TabControl
    - MenuItemMappings: Menu items in the application menu
    - ToolTipMappings: Tooltip text for UI elements

    Excluded Elements:
    - Dynamic elements (lists, input fields)
    - Elements without localization needs (containers, panels)
    - Tooltip TextBlocks (mapped separately via ToolTipMappings)
    - StackPanels used for label/tooltip combinations

    Exit Codes:
    - 0: All tests passed (warnings allowed)
    - 1: One or more tests failed

    Dependencies:
    - gui/ConfigEditor.Mappings.ps1 (mapping definitions)
    - gui/messages.json (localized message strings)
    - gui/MainWindow.xaml (UI layout definition)
    - gui/ConfigEditor.ps1 (main application code)
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

<#
.SYNOPSIS
    Records a test result and updates the test results structure.

.DESCRIPTION
    Adds a test result to the global test results tracking structure and displays
    formatted output to the console. Supports three result types: PASS, FAIL, and WARN.

    Test results are categorized as:
    - PASS: Test succeeded, increments Passed counter
    - FAIL: Test failed, increments Failed counter and records details
    - WARN: Non-critical issue detected, increments Warnings counter

    Failed tests and warnings are stored with their messages for detailed reporting
    in the test summary.

.PARAMETER TestName
    The name or description of the test being reported.

.PARAMETER Passed
    Boolean indicating whether the test passed (true) or failed (false).
    Ignored when IsWarning is true.

.PARAMETER Message
    Optional detailed message providing context about the test result,
    error details, or warning information.

.PARAMETER IsWarning
    When true, records the result as a warning instead of a pass/fail.
    Warnings indicate potential issues that don't cause test failure.

.EXAMPLE
    Add-TestResult -TestName "All mappings loaded" -Passed $true
    Add-TestResult -TestName "Element exists" -Passed $false -Message "Element 'MyButton' not found"
    Add-TestResult -TestName "Unused mapping" -Passed $false -Message "Element never referenced" -IsWarning $true

.NOTES
    Updates the script-scoped $testResults hashtable with counters and details.
    Output format: [PASS], [FAIL], or [WARN] prefix with test name and optional message.
#>
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
if ($testResults.Failed -eq 0) {
    Write-Host "[OK] Failed: $($testResults.Failed)"
} else {
    Write-Host "[ERROR] Failed: $($testResults.Failed)"
}
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
