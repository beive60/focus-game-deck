<#
.SYNOPSIS
    Configuration mappings for ConfigEditor UI components, organized by functionality.

.DESCRIPTION
    This file contains mappings between UI element names and their corresponding
    localization keys, organized by element type and functionality for better maintainability.
#>

# CRUD operation buttons (Add, Duplicate, Delete)
$script:CrudButtonMappings = @{
    "AddGameButton" = "addButton"
    "DuplicateGameButton" = "duplicateButton"
    "DeleteGameButton" = "deleteButton"
    "AddAppButton" = "addButton"
    "DuplicateAppButton" = "duplicateButton"
    "DeleteAppButton" = "deleteButton"
}

# File browser buttons
$script:BrowserButtonMappings = @{
    "BrowseAppPathButton" = "browseButton"
    "BrowseWorkingDirectoryButton" = "browseFolderButton"
    "BrowseExecutablePathButton" = "browseButton"
    "BrowseSteamPathButton" = "browseButton"
    "BrowseEpicPathButton" = "browseButton"
    "BrowseRiotPathButton" = "browseButton"
    "BrowseOBSPathButton" = "browseButton"
    "BrowseDiscordPathButton" = "browseButton"
    "BrowseVTubePathButton" = "browseButton"
}

# Auto-detection buttons
$script:AutoDetectButtonMappings = @{
    "AutoDetectSteamButton" = "autoDetectButton"
    "AutoDetectEpicButton" = "autoDetectButton"
    "AutoDetectRiotButton" = "autoDetectButton"
    "AutoDetectOBSButton" = "autoDetectButton"
    "AutoDetectDiscordButton" = "autoDetectButton"
    "AutoDetectVTubeButton" = "autoDetectButton"
}

# Save and action buttons
$script:ActionButtonMappings = @{
    "SaveGameSettingsButton" = "saveButton"
    "SaveManagedAppsButton" = "saveButton"
    "SaveGlobalSettingsButton" = "saveButton"
    "SaveOBSSettingsButton" = "saveButton"
    "SaveDiscordSettingsButton" = "saveButton"
    "SaveVTubeStudioSettingsButton" = "saveButton"
    "GenerateLaunchersButton" = "generateLaunchers"
    "OpenOBSTabButton" = "openIntegrationSettings"
    "OpenDiscordTabButton" = "openIntegrationSettings"
    "OpenVTubeStudioTabButton" = "openIntegrationSettings"
}

# List movement buttons
$script:MovementButtonMappings = @{
    "MoveGameTopButton" = "moveTopButton"
    "MoveGameUpButton" = "moveUpButton"
    "MoveGameDownButton" = "moveDownButton"
    "MoveGameBottomButton" = "moveBottomButton"
    "MoveAppTopButton" = "moveTopButton"
    "MoveAppUpButton" = "moveUpButton"
    "MoveAppDownButton" = "moveDownButton"
    "MoveAppBottomButton" = "moveBottomButton"
}

# Combined mapping for backward compatibility
$script:ButtonMappings = @{}
$script:CrudButtonMappings.GetEnumerator() | ForEach-Object { $script:ButtonMappings[$_.Key] = $_.Value }
$script:BrowserButtonMappings.GetEnumerator() | ForEach-Object { $script:ButtonMappings[$_.Key] = $_.Value }
$script:AutoDetectButtonMappings.GetEnumerator() | ForEach-Object { $script:ButtonMappings[$_.Key] = $_.Value }
$script:ActionButtonMappings.GetEnumerator() | ForEach-Object { $script:ButtonMappings[$_.Key] = $_.Value }
$script:MovementButtonMappings.GetEnumerator() | ForEach-Object { $script:ButtonMappings[$_.Key] = $_.Value }

# Label and GroupBox header mappings
$script:LabelMappings = @{
    "GamesListLabel" = "gamesListLabel"
    "GameDetailsLabel" = "gameDetailsLabel"
    "GameIdLabel" = "gameIdLabel"
    "GameNameLabel" = "gameNameLabel"
    "PlatformLabel" = "platformLabel"
    "SteamAppIdLabel" = "steamAppIdLabel"
    "EpicGameIdLabel" = "epicGameIdLabel"
    "RiotGameIdLabel" = "riotGameIdLabel"
    "ProcessNameLabel" = "processNameLabel"
    "AppsToManageLabel" = "appsToManageLabel"
    "ObsSettingsGroup" = "obsSettingsGroup"
    "PathSettingsGroup" = "pathSettingsGroup"
    "GeneralSettingsGroup" = "generalSettingsGroup"
    "HostLabel" = "hostLabel"
    "PortLabel" = "portLabel"
    "PasswordLabel" = "passwordLabel"
    "SteamPathLabel" = "steamPathLabel"
    "EpicPathLabel" = "epicPathLabel"
    "RiotPathLabel" = "riotPathLabel"
    "ObsPathLabel" = "obsPathLabel"
    "LanguageLabel" = "languageLabel"
    "AppsListLabel" = "appsListLabel"
    "AppDetailsLabel" = "appDetailsLabel"
    "AppIdLabel" = "appIdLabel"
    "AppPathLabel" = "appPathLabel"
    "WorkingDirectoryLabel" = "workingDirectoryLabel"
    "AppDisplayNameLabel" = "appDisplayNameLabel"
    "AppProcessNameLabel" = "processNameLabel"
    "GameStartActionLabel" = "gameStartActionLabel"
    "GameEndActionLabel" = "gameEndActionLabel"
    "AppArgumentsLabel" = "argumentsLabel"
    "TerminationMethodLabel" = "terminationMethodLabel"
    "GracefulTimeoutLabel" = "gracefulTimeoutLabel"
    "AppCommentLabel" = "commentLabel"
    "GameCommentLabel" = "commentLabel"
    "LauncherTypeLabel" = "launcherTypeLabel"
    "LauncherTypeLabel2" = "launcherTypeLabel"
    "LogRetentionLabel" = "logRetentionLabel"
    "ExecutablePathLabel" = "executablePathLabel"
    "ObsGameIntegrationGroup" = "gameIntegrationGroup"
    "ObsExecutableGroup" = "executableFileGroup"
    "DiscordGameIntegrationGroup" = "gameIntegrationGroup"
    "DiscordExecutableGroup" = "executableFileGroup"
    "DiscordStatusOnStartLabel" = "discordStatusOnStart"
    "DiscordStatusOnEndLabel" = "discordStatusOnEnd"
    "DiscordRichPresenceGroup" = "discordRichPresenceGroup"
    "DiscordAppIdLabel" = "discordAppIdLabel"
    "VTubeGameIntegrationGroup" = "gameIntegrationGroup"
    "VTubeWebSocketGroup" = "vtubeWebsocketGroup"
    "VTubeLaunchMethodGroup" = "vtubeLaunchMethodGroup"
    "VTubeSteamAppIdLabel" = "vtubeSteamAppIdLabel"
    "VTubeHostLabel" = "hostLabel"
    "VTubePortLabel" = "portLabel"
    "GameIntegrationSectionLabel" = "gameIntegrationSectionLabel"
}

# Tab header mappings
$script:TabMappings = @{
    "GameLauncherTab" = "gameLauncherTabHeader"
    "GamesTab" = "gamesTabHeader"
    "ManagedAppsTab" = "managedAppsTabHeader"
    "OBSTab" = "obsTabHeader"
    "DiscordTab" = "discordTabHeader"
    "VTubeStudioTab" = "vtubestudioTabHeader"
    "GlobalSettingsTab" = "globalSettingsTabHeader"
}

# TextBlock and Text element mappings
$script:TextMappings = @{
    "VersionLabel" = "versionLabel"
    "LauncherWelcomeText" = "launcherWelcomeText"
    "LauncherSubtitleText" = "launcherSubtitleText"
    "LauncherStatusText" = "readyToLaunch"
    "LauncherHintText" = "launcherHintText"
    "LauncherHelpText" = "launcherHelpText"
    "GameIntegrationDescriptionText" = "gameIntegrationDescription"
    "DiscordPathInfoText" = "discordPathInfo"
    "ObsIntegrationTitle" = "integrationTitleObs"
    "DiscordIntegrationTitle" = "integrationTitleDiscord"
    "VTubeStudioIntegrationTitle" = "integrationTitleVtube"
    "GamesDragDropHint" = "dragDropReorderHint"
    "AppsDragDropHint" = "dragDropReorderHint"
}

# CheckBox content mappings
$script:CheckBoxMappings = @{
    "OBSAutoStartCheckBox" = "gameStartObsLabel"
    "OBSAutoStopCheckBox" = "gameStopReplayBufferLabel"
    "OBSReplayBufferCheckBox" = "replayBufferLabel"
    "EnableLogNotarizationCheckBox" = "enableLogNotarization"
    "DiscordEnableGameModeCheckBox" = "discordEnableAutoControl"
    "DiscordDisableOverlayCheckBox" = "discordDisableOverlay"
    "DiscordRPCEnableCheckBox" = "discordEnableRichPresence"
    "VTubeAutoStartCheckBox" = "vtubeAutoStart"
    "VTubeAutoStopCheckBox" = "vtubeAutoStop"
    "VTubeWebSocketEnableCheckBox" = "vtubeEnableWebsocket"
}

# RadioButton content mappings
$script:RadioButtonMappings = @{
    "VTubeLaunchViaSteamRadio" = "vtubeLaunchViaSteam"
    "VTubeLaunchDirectRadio" = "vtubeLaunchDirect"
}

# MenuItem mappings
$script:MenuItemMappings = @{
    "RefreshMenu" = "refreshMenuHeader"
    "RefreshGameListMenuItem" = "refreshGameListMenuItem"
    "RefreshManagedAppsListMenuItem" = "refreshManagedAppsListMenuItem"
    "RefreshAllMenuItem" = "refreshAllMenuItem"
    "ToolsMenu" = "toolsMenuHeader"
    "CreateAllShortcutsMenuItem" = "createAllShortcuts"
    "HelpMenu" = "helpMenuHeader"
    "CheckUpdateMenuItem" = "checkUpdateMenuItem"
    "FeedbackMenuItem" = "feedbackMenuItem"
    "AboutMenuItem" = "aboutMenuItem"
}

# Tooltip mappings for elements that don't have visible text but need tooltips
$script:TooltipMappings = @{
    # Movement button tooltips (Games tab)
    "MoveGameTopButton" = "moveTopTooltip"
    "MoveGameUpButton" = "moveUpTooltip"
    "MoveGameDownButton" = "moveDownTooltip"
    "MoveGameBottomButton" = "moveBottomTooltip"
    # Movement button tooltips (Managed Apps tab)
    "MoveAppTopButton" = "moveTopTooltip"
    "MoveAppUpButton" = "moveUpTooltip"
    "MoveAppDownButton" = "moveDownTooltip"
    "MoveAppBottomButton" = "moveBottomTooltip"

    # Auto-detect tooltip TextBlocks
    "AutoDetectSteamTooltip" = "autoDetectSteamTooltip"
    "AutoDetectEpicTooltip" = "autoDetectEpicTooltip"
    "AutoDetectRiotTooltip" = "autoDetectRiotTooltip"
    "AutoDetectObsTooltip" = "autoDetectObsTooltip"
    "AutoDetectDiscordTooltip" = "autoDetectDiscordTooltip"
    "AutoDetectVTubeStudioTooltip" = "autoDetectVTubeStudioTooltip"

    # Game configuration tooltip TextBlocks (? icons)
    "GameIdTooltip" = "tooltipGameId"
    "GameNameTooltip" = "tooltipDisplayName"
    "SteamAppIdTooltip" = "tooltipSteamAppId"
    "EpicGameIdTooltip" = "tooltipEpicGameId"
    "RiotGameIdTooltip" = "tooltipRiotGameId"
    "ExecutablePathTooltip" = "tooltipExecutablePath"
    "ProcessNameTooltip" = "tooltipProcessName"

    # Managed App configuration tooltip TextBlocks (? icons)
    "AppIdTooltip" = "tooltipAppId"
    "AppProcessNameTooltip" = "tooltipProcessName"
    "GameStartActionTooltip" = "tooltipGameActions"
    "GameEndActionTooltip" = "tooltipGameActions"
    "AppArgumentsTooltip" = "tooltipLaunchArguments"
    "TerminationMethodTooltip" = "tooltipTerminationMethod"
    "GracefulTimeoutTooltip" = "tooltipGracefulTimeout"

    # StackPanel tooltips (for entire label+tooltip rows)
    "GameIdLabelPanel" = "tooltipGameId"
    "GameNameLabelPanel" = "tooltipDisplayName"
    "SteamAppIdLabelPanel" = "tooltipSteamAppId"
    "EpicGameIdLabelPanel" = "tooltipEpicGameId"
    "RiotGameIdLabelPanel" = "tooltipRiotGameId"
    "ExecutablePathLabelPanel" = "tooltipExecutablePath"
    "ProcessNameLabelPanel" = "tooltipProcessName"
    "GameCommentLabelPanel" = "tooltip_comment"
    "AppsToManageLabelPanel" = "tooltip_apps_to_manage"
    "IntegrationsLabelPanel" = "tooltip_integrations"
    "AppIdLabelPanel" = "tooltipAppId"
    "AppProcessNameLabelPanel" = "tooltipProcessName"
    "WorkingDirectoryLabelPanel" = "tooltipWorkingDirectory"
    "GameStartActionLabelPanel" = "tooltipGameActions"
    "GameEndActionLabelPanel" = "tooltipGameActions"
    "AppArgumentsLabelPanel" = "tooltipLaunchArguments"
    "TerminationMethodLabelPanel" = "tooltipTerminationMethod"
    "GracefulTimeoutLabelPanel" = "tooltipGracefulTimeout"
}

# ComboBoxItem content mappings
# Note: Only includes ComboBoxItems that are statically defined in MainWindow.xaml
# Dynamic ComboBoxItems (e.g., game actions) are localized separately in InitializeGameActionCombos()
$script:ComboBoxItemMappings = @{
    "LogRetention7Item" = "logRetention7"
    "LogRetention30Item" = "logRetention30"
    "LogRetention180Item" = "logRetention180"
    "LogRetentionUnlimitedItem" = "logRetentionUnlimited"
    "LauncherTypeEnhancedItem" = "enhancedShortcuts"
    "LauncherTypeTraditionalItem" = "traditionalBatch"
    "GameLauncherTypeEnhancedItem" = "enhancedShortcuts"
    "GameLauncherTypeTraditionalItem" = "traditionalBatch"
    "PlatformStandaloneItem" = "standalonePlatform"
    "PlatformSteamItem" = "steamPlatform"
    "PlatformEpicItem" = "epicPlatform"
    "PlatformRiotItem" = "riotPlatform"
    "DiscordStatusOnStartOnlineItem" = "discordStatusOnline"
    "DiscordStatusOnStartDndItem" = "discordStatusDnd"
    "DiscordStatusOnStartIdleItem" = "discordStatusIdle"
    "DiscordStatusOnStartInvisibleItem" = "discordStatusInvisible"
    "DiscordStatusOnEndOnlineItem" = "discordStatusOnline"
    "DiscordStatusOnEndDndItem" = "discordStatusDnd"
    "DiscordStatusOnEndIdleItem" = "discordStatusIdle"
    "DiscordStatusOnEndInvisibleItem" = "discordStatusInvisible"
}

# Game action message key mappings (used for dynamic ComboBoxItem creation)
# These are not x:Name values but message keys used in InitializeGameActionCombos()
# Simplified to core actions only: none, start-process, stop-process
# Application-specific integrations (OBS, Discord, VTube Studio) are configured in dedicated tabs
# and use abstract actions: enter-game-mode, exit-game-mode
$script:GameActionMessageKeys = @{
    "none" = "gameActionNone"
    "start-process" = "gameActionStartProcess"
    "stop-process" = "gameActionStopProcess"
}

# Termination method options mapping
$script:TerminationMethodMessageKeys = @{
    "auto" = "terminationMethodAuto"
    "graceful" = "terminationMethodGraceful"
    "force" = "terminationMethodForce"
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
            "Crud" { return $script:CrudButtonMappings }
            "Browser" { return $script:BrowserButtonMappings }
            "AutoDetect" { return $script:AutoDetectButtonMappings }
            "Action" { return $script:ActionButtonMappings }
            "Movement" { return $script:MovementButtonMappings }
            "All" { return $script:ButtonMappings }
            default { return @{} }
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
        [ValidateSet("Button", "Label", "Tab", "Text", "CheckBox", "RadioButton", "MenuItem", "Tooltip", "ComboBoxItem")]
        [string]$ElementType
    )

    try {
        # Define mapping table lookup based on element type
        $mappingTables = switch ($ElementType) {
            "Button" { @($script:ButtonMappings) }
            "Label" { @($script:LabelMappings) }
            "Tab" { @($script:TabMappings) }
            "Text" { @($script:TextMappings) }
            "CheckBox" { @($script:CheckBoxMappings) }
            "RadioButton" { @($script:RadioButtonMappings) }
            "MenuItem" { @($script:MenuItemMappings) }
            "Tooltip" { @($script:TooltipMappings) }
            "ComboBoxItem" { @($script:ComboBoxItemMappings) }
            default { @($script:ButtonMappings, $script:LabelMappings, $script:TabMappings, $script:TextMappings, $script:CheckBoxMappings, $script:RadioButtonMappings, $script:MenuItemMappings, $script:TooltipMappings, $script:ComboBoxItemMappings) }
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
        $allMappings = @($script:ButtonMappings, $script:LabelMappings, $script:TabMappings, $script:TextMappings, $script:CheckBoxMappings, $script:MenuItemMappings, $script:TooltipMappings, $script:ComboBoxItemMappings)

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

<#
.SYNOPSIS
    Gets the localization key for ComboBoxItem elements.

.DESCRIPTION
    This function specifically handles ComboBoxItem elements and returns
    the appropriate localization key for their Content property.

.PARAMETER ElementName
    The x:Name of the ComboBoxItem element.

.OUTPUTS
    String
        Returns the localization key if found, otherwise returns null.
#>
function Get-ComboBoxItemLocalizationKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementName
    )

    try {
        if ($script:ComboBoxItemMappings.ContainsKey($ElementName)) {
            return $script:ComboBoxItemMappings[$ElementName]
        }
        return $null
    } catch {
        Write-Warning "Error getting ComboBoxItem localization key for '$ElementName': $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Validates that all ComboBoxItems in the mappings have corresponding message keys.

.DESCRIPTION
    This function checks if all ComboBoxItem mappings have valid message keys
    in the provided messages hashtable. Also validates game action message keys.

.PARAMETER Messages
    The messages hashtable containing localized strings.

.PARAMETER Language
    The language code to validate (e.g., 'ja', 'en', 'zh-CN').

.OUTPUTS
    Array
        Returns an array of missing message keys.
#>
function Test-ComboBoxItemMappings {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Messages,

        [Parameter(Mandatory = $true)]
        [string]$Language
    )

    try {
        $missingKeys = @()

        if (-not $Messages.ContainsKey($Language)) {
            Write-Warning "Language '$Language' not found in messages"
            return @("Language '$Language' not found")
        }

        $languageMessages = $Messages[$Language]

        # Validate static ComboBoxItem mappings
        foreach ($kvp in $script:ComboBoxItemMappings.GetEnumerator()) {
            $elementName = $kvp.Key
            $messageKey = $kvp.Value

            if (-not $languageMessages.ContainsKey($messageKey)) {
                $missingKeys += "Missing message key '$messageKey' for ComboBoxItem '$elementName'"
            }
        }

        # Validate game action message keys
        foreach ($kvp in $script:GameActionMessageKeys.GetEnumerator()) {
            $actionTag = $kvp.Key
            $messageKey = $kvp.Value

            if (-not $languageMessages.ContainsKey($messageKey)) {
                $missingKeys += "Missing message key '$messageKey' for game action '$actionTag'"
            }
        }

        return $missingKeys
    } catch {
        Write-Warning "Error validating ComboBoxItem mappings: $($_.Exception.Message)"
        return @("Validation error: $($_.Exception.Message)")
    }
}

# Variables are automatically available in the caller's scope when dot-sourced
# No Export-ModuleMember needed for dot-sourced scripts
Write-Verbose "ConfigEditor.Mappings.ps1 loaded successfully with $($script:ButtonMappings.Count) button mappings, $($script:LabelMappings.Count) label mappings, $($script:TabMappings.Count) tab mappings, $($script:TextMappings.Count) text mappings, $($script:CheckBoxMappings.Count) checkbox mappings, $($script:RadioButtonMappings.Count) radio button mappings, $($script:MenuItemMappings.Count) menu item mappings, $($script:TooltipMappings.Count) tooltip mappings, $($script:ComboBoxItemMappings.Count) static ComboBoxItem mappings, and $($script:GameActionMessageKeys.Count) game action message keys"
