<#
.SYNOPSIS
    Configuration mappings for ConfigEditor UI components, organized by functionality.

.DESCRIPTION
    This file contains mappings between UI element names and their corresponding
    localization keys, organized by element type and functionality for better maintainability.
#>

# CRUD operation buttons (Add, Duplicate, Delete)
$CrudButtonMappings = @{
    "AddGameButton"       = "addButton"
    "DuplicateGameButton" = "duplicateButton"
    "DeleteGameButton"    = "deleteButton"
    "AddAppButton"        = "addButton"
    "DuplicateAppButton"  = "duplicateButton"
    "DeleteAppButton"     = "deleteButton"
    "AddNewGameButton"    = "addGameButton"
}

# File browser buttons
$BrowserButtonMappings = @{
    "BrowseAppPathButton"        = "browseButton"
    "BrowseExecutablePathButton" = "browseButton"
    "BrowseSteamPathButton"      = "browseButton"
    "BrowseEpicPathButton"       = "browseButton"
    "BrowseRiotPathButton"       = "browseButton"
    "BrowseObsPathButton"        = "browseButton"
}

# Auto-detection buttons
$AutoDetectButtonMappings = @{
    "AutoDetectSteamButton" = "autoDetectButton"
    "AutoDetectEpicButton"  = "autoDetectButton"
    "AutoDetectRiotButton"  = "autoDetectButton"
    "AutoDetectObsButton"   = "autoDetectButton"
}

# Save and action buttons
$ActionButtonMappings = @{
    "SaveGameSettingsButton"   = "saveButton"
    "SaveManagedAppsButton"    = "saveButton"
    "SaveGlobalSettingsButton" = "saveButton"
    "GenerateLaunchersButton"  = "generateLaunchers"
    "RefreshGameListButton"    = "refreshButton"
    "OpenConfigButton"         = "openConfigButton"
}

# List movement buttons
$MovementButtonMappings = @{
    "MoveGameTopButton"    = "moveTopButton"
    "MoveGameUpButton"     = "moveUpButton"
    "MoveGameDownButton"   = "moveDownButton"
    "MoveGameBottomButton" = "moveBottomButton"
    "MoveAppTopButton"     = "moveTopButton"
    "MoveAppUpButton"      = "moveUpButton"
    "MoveAppDownButton"    = "moveDownButton"
    "MoveAppBottomButton"  = "moveBottomButton"
}

# Combined mapping for backward compatibility
$ButtonMappings = @{}
$CrudButtonMappings.GetEnumerator() | ForEach-Object { $ButtonMappings[$_.Key] = $_.Value }
$BrowserButtonMappings.GetEnumerator() | ForEach-Object { $ButtonMappings[$_.Key] = $_.Value }
$AutoDetectButtonMappings.GetEnumerator() | ForEach-Object { $ButtonMappings[$_.Key] = $_.Value }
$ActionButtonMappings.GetEnumerator() | ForEach-Object { $ButtonMappings[$_.Key] = $_.Value }
$MovementButtonMappings.GetEnumerator() | ForEach-Object { $ButtonMappings[$_.Key] = $_.Value }

# Label and GroupBox header mappings
$LabelMappings = @{
    "GamesListLabel"         = "gamesListLabel"
    "GameDetailsLabel"       = "gameDetailsLabel"
    "GameIdLabel"            = "gameIdLabel"
    "GameNameLabel"          = "gameNameLabel"
    "PlatformLabel"          = "platformLabel"
    "SteamAppIdLabel"        = "steamAppIdLabel"
    "EpicGameIdLabel"        = "epicGameIdLabel"
    "RiotGameIdLabel"        = "riotGameIdLabel"
    "ProcessNameLabel"       = "processNameLabel"
    "AppsToManageLabel"      = "appsToManageLabel"
    "ObsSettingsGroup"       = "obsSettingsGroup"
    "PathSettingsGroup"      = "pathSettingsGroup"
    "GeneralSettingsGroup"   = "generalSettingsGroup"
    "HostLabel"              = "hostLabel"
    "PortLabel"              = "portLabel"
    "PasswordLabel"          = "passwordLabel"
    "SteamPathLabel"         = "steamPathLabel"
    "EpicPathLabel"          = "epicPathLabel"
    "RiotPathLabel"          = "riotPathLabel"
    "ObsPathLabel"           = "obsPathLabel"
    "LanguageLabel"          = "languageLabel"
    "AppsListLabel"          = "appsListLabel"
    "AppDetailsLabel"        = "appDetailsLabel"
    "AppIdLabel"             = "appIdLabel"
    "AppPathLabel"           = "appPathLabel"
    "AppProcessNameLabel"    = "processNameLabel"
    "GameStartActionLabel"   = "gameStartActionLabel"
    "GameEndActionLabel"     = "gameEndActionLabel"
    "AppArgumentsLabel"      = "argumentsLabel"
    "TerminationMethodLabel" = "terminationMethodLabel"
    "GracefulTimeoutLabel"   = "gracefulTimeoutLabel"
    "LauncherTypeLabel"      = "launcherTypeLabel"
    "LauncherTypeLabel2"     = "launcherTypeLabel"
    "LogRetentionLabel"      = "logRetentionLabel"
    "ExecutablePathLabel"    = "executablePathLabel"
}

# Tab header mappings
$TabMappings = @{
    "GameLauncherTab"   = "gameLauncherTabHeader"
    "GamesTab"          = "gamesTabHeader"
    "ManagedAppsTab"    = "managedAppsTabHeader"
    "GlobalSettingsTab" = "globalSettingsTabHeader"
}

# TextBlock and Text element mappings
$TextMappings = @{
    "VersionLabel"         = "versionLabel"
    "LauncherWelcomeText"  = "launcherWelcomeText"
    "LauncherSubtitleText" = "launcherSubtitleText"
    "LauncherStatusText"   = "readyToLaunch"
    "LauncherHintText"     = "launcherHintText"
    "LauncherHelpText"     = "launcherHelpText"
}

# CheckBox content mappings
$CheckBoxMappings = @{
    "ReplayBufferCheckBox"          = "replayBufferLabel"
    "EnableLogNotarizationCheckBox" = "enableLogNotarization"
}

# MenuItem mappings
$MenuItemMappings = @{
    "CheckUpdateMenuItem" = "checkUpdateMenuItem"
    "AboutMenuItem"       = "aboutMenuItem"
}

# Tooltip mappings for elements that don't have visible text but need tooltips
$TooltipMappings = @{
    "MoveGameTopButton"    = "moveTopTooltip"
    "MoveGameUpButton"     = "moveUpTooltip"
    "MoveGameDownButton"   = "moveDownTooltip"
    "MoveGameBottomButton" = "moveBottomTooltip"
    "MoveAppTopButton"     = "moveTopTooltip"
    "MoveAppUpButton"      = "moveUpTooltip"
    "MoveAppDownButton"    = "moveDownTooltip"
    "MoveAppBottomButton"  = "moveBottomTooltip"
}

<#
.SYNOPSIS
    Gets button mappings by functionality category.

.DESCRIPTION
    Retrieves button mappings for a specific functional category, allowing for more targeted updates.

.PARAMETER Category
    The category of buttons to retrieve mappings for.

.OUTPUTS
    Hashtable
        Returns the hashtable containing button mappings for the specified category.
#>
function Get-ButtonMappingsByCategory {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Crud", "Browser", "AutoDetect", "Action", "Movement", "All")]
        [string]$Category
    )

    try {
        switch ($Category) {
            "Crud"       { return $CrudButtonMappings }
            "Browser"    { return $BrowserButtonMappings }
            "AutoDetect" { return $AutoDetectButtonMappings }
            "Action"     { return $ActionButtonMappings }
            "Movement"   { return $MovementButtonMappings }
            "All"        { return $ButtonMappings }
            default      { return @{} }
        }
    } catch {
        Write-Warning "Error getting button mappings for category '$Category': $($_.Exception.Message)"
        return @{}
    }
}

<#
.SYNOPSIS
    Gets the localization key for a UI element by name and type.

.DESCRIPTION
    This function searches through all mapping tables to find the appropriate
    localization key for a given UI element name.

.PARAMETER ElementName
    The name of the UI element to find the localization key for.

.PARAMETER ElementType
    Optional. The specific type of element to search for (Button, Label, etc.).
    If not specified, searches all mappings.

.OUTPUTS
    String
        Returns the localization key if found, otherwise returns null.
#>
function Get-LocalizationKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Button", "Label", "Tab", "Text", "CheckBox", "MenuItem", "Tooltip")]
        [string]$ElementType
    )

    try {
        # Define mapping table lookup based on element type
        $mappingTables = switch ($ElementType) {
            "Button"   { @($ButtonMappings) }
            "Label"    { @($LabelMappings) }
            "Tab"      { @($TabMappings) }
            "Text"     { @($TextMappings) }
            "CheckBox" { @($CheckBoxMappings) }
            "MenuItem" { @($MenuItemMappings) }
            "Tooltip"  { @($TooltipMappings) }
            default    { @($ButtonMappings, $LabelMappings, $TabMappings, $TextMappings, $CheckBoxMappings, $MenuItemMappings, $TooltipMappings) }
        }

        # Search through the specified mapping tables
        foreach ($table in $mappingTables) {
            if ($table.ContainsKey($ElementName)) {
                return $table[$ElementName]
            }
        }

        return $null
    } catch {
        Write-Warning "Error getting localization key for element '$ElementName': $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Gets all UI elements that use a specific localization key.

.DESCRIPTION
    This function searches through all mapping tables to find UI elements
    that are mapped to a specific localization key.

.PARAMETER LocalizationKey
    The localization key to search for.

.OUTPUTS
    Array
        Returns an array of element names that use the specified localization key.
#>
function Get-ElementsForKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalizationKey
    )

    try {
        $elements = @()
        $allMappings = @($ButtonMappings, $LabelMappings, $TabMappings, $TextMappings, $CheckBoxMappings, $MenuItemMappings, $TooltipMappings)

        foreach ($mapping in $allMappings) {
            foreach ($kvp in $mapping.GetEnumerator()) {
                if ($kvp.Value -eq $LocalizationKey) {
                    $elements += $kvp.Key
                }
            }
        }

        return $elements
    } catch {
        Write-Warning "Error getting elements for localization key '$LocalizationKey': $($_.Exception.Message)"
        return @()
    }
}

# Variables are automatically available in the caller's scope when dot-sourced
# No Export-ModuleMember needed for dot-sourced scripts
Write-Verbose "ConfigEditor.Mappings.ps1 loaded successfully with $($ButtonMappings.Count) button mappings"
