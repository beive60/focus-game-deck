# Focus Game Deck - Configuration Editor
# PowerShell + WPF GUI for editing config.json
#
# Design Philosophy:
# 1. Lightweight & Simple - Uses Windows native WPF, no additional runtime required
# 2. Maintainable & Extensible - Configuration-driven design with modular structure
# 3. User-Friendly - Intuitive 3-tab GUI with proper internationalization support
#
# Technical Architecture:
# - PowerShell + WPF: Windows-native GUI technology for lightweight implementation
# - Dynamic Language Detection: Automatic language detection based on config.json and OS settings
# - Configuration-Driven: All behavior controlled through config.json
# - Event-Driven: UI operations handled through PowerShell event handlers
#
# Language Support:
# This implementation uses dynamic language detection following the priority:
# 1. config.json language setting (if exists and valid)
# 2. OS display language (if supported)
# 3. English fallback (default)
#
# Author: GitHub Copilot Assistant
# Version: 1.1.0 - Dynamic Language Detection and English Support
# Date: 2025-09-23

# Import language helper functions
$LanguageHelperPath = Join-Path (Split-Path $PSScriptRoot) "scripts\LanguageHelper.ps1"
if (Test-Path $LanguageHelperPath) {
    . $LanguageHelperPath
} else {
    Write-Warning "Language helper not found: $LanguageHelperPath"
}

# Import version and update checker modules
$VersionModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Version.ps1"
if (Test-Path $VersionModulePath) {
    . $VersionModulePath
} else {
    Write-Warning "Version module not found: $VersionModulePath"
}

$UpdateCheckerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "src\modules\UpdateChecker.ps1"
if (Test-Path $UpdateCheckerPath) {
    . $UpdateCheckerPath
} else {
    Write-Warning "Update checker module not found: $UpdateCheckerPath"
}

# Set system-level encoding settings for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Add WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Global variables
$script:ConfigData = $null
$script:ConfigPath = ""
$script:Window = $null
$script:CurrentGameId = ""
$script:CurrentAppId = ""
$script:Messages = $null
$script:CurrentLanguage = "en"  # Default language

# Load messages from JSON file with language detection
function Load-Messages {
    param()

    try {
        # Detect language first
        $script:CurrentLanguage = Get-DetectedLanguage -ConfigData $script:ConfigData

        # Set appropriate culture
        Set-CultureByLanguage -LanguageCode $script:CurrentLanguage

        # Load messages
        $messagesPath = Join-Path $PSScriptRoot "messages.json"
        $script:Messages = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $script:CurrentLanguage

        Write-Host "Loaded messages for language: $script:CurrentLanguage"

    } catch {
        Write-Error "Failed to load messages: $($_.Exception.Message)"
        $script:Messages = [PSCustomObject]@{}
        $script:CurrentLanguage = "en"
    }
}

# Get localized message
function Get-LocalizedMessage {
    param(
        [string]$Key,
        [string[]]$Args = @()
    )

    if ($script:Messages -and $script:Messages.PSObject.Properties[$Key]) {
        $message = $script:Messages.$Key

        # Replace placeholders if args provided
        if ($Args.Length -gt 0) {
            Write-Verbose "Debug: Processing message '$Key' with $($Args.Length) arguments"

            for ($i = 0; $i -lt $Args.Length; $i++) {
                $placeholder = "{$i}"
                $replacement = if ($null -ne $Args[$i]) {
                    # Ensure safe string conversion and escape any problematic characters
                    $Args[$i].ToString().Replace("`r", "").Replace("`n", " ")
                } else {
                    ""
                }

                if ($message.Contains($placeholder)) {
                    $message = $message.Replace($placeholder, $replacement)
                    Write-Verbose "Debug: Successfully replaced '$placeholder' with '$replacement'"
                } else {
                    Write-Verbose "Debug: Placeholder '$placeholder' not found in message template"
                }
            }
        }

        return $message
    } else {
        # Fallback to English if message not found
        Write-Warning "Debug: Message key '$Key' not found in current language messages"
        return $Key
    }
}

# Helper function to measure button text width
function Measure-ButtonTextWidth {
    param(
        [string]$Text,
        [System.Windows.Controls.Button]$Button
    )

    if ([string]::IsNullOrEmpty($Text) -or -not $Button) {
        return 0
    }

    try {
        # Create a temporary TextBlock to measure text size
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $Text
        $textBlock.FontFamily = $Button.FontFamily
        $textBlock.FontSize = $Button.FontSize
        $textBlock.FontWeight = $Button.FontWeight
        $textBlock.FontStyle = $Button.FontStyle

        # Measure the text
        $textBlock.Measure([System.Windows.Size]::new([double]::PositiveInfinity, [double]::PositiveInfinity))

        # Add some padding (approximately 10-15 pixels for button padding)
        return $textBlock.DesiredSize.Width + 15
    } catch {
        # Fallback: estimate based on character count
        return $Text.Length * 7
    }
}

# Helper function to set button content with smart tooltip
function Set-ButtonContentWithTooltip {
    param(
        [System.Windows.Controls.Button]$Button,
        [string]$FullText
    )

    if (-not $Button -or [string]::IsNullOrEmpty($FullText)) {
        return
    }

    try {
        # Always set the full text as button content first
        $Button.Content = $FullText

        # Force UI update to ensure button width is calculated
        $Button.UpdateLayout()
        $Button.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action] {})

        # Get button's available width (considering margins and padding)
        $buttonWidth = $Button.ActualWidth
        if ($buttonWidth -eq 0) {
            $buttonWidth = $Button.Width
        }
        $availableWidth = $buttonWidth - 15  # Account for internal padding and margins

        Write-Verbose "Debug: Button '$($Button.Name)' - ActualWidth: $($Button.ActualWidth), Width: $($Button.Width), Available: $availableWidth"

        # Measure actual text width
        $textWidth = Measure-ButtonTextWidth -Text $FullText -Button $Button

        Write-Verbose "Debug: Button '$($Button.Name)' - Text: '$FullText', TextWidth: $textWidth, AvailableWidth: $availableWidth"

        # Set tooltip based on text width comparison or text length as fallback
        $shouldShowTooltip = $false

        if ($availableWidth -gt 0 -and $textWidth -gt $availableWidth) {
            $shouldShowTooltip = $true
            Write-Verbose "Debug: Tooltip needed due to width: $textWidth > $availableWidth"
        } elseif ($availableWidth -le 0 -and $FullText.Length -gt 12) {
            $shouldShowTooltip = $true
            Write-Verbose "Debug: Tooltip needed due to text length: $($FullText.Length) > 12 (width measurement unavailable)"
        }

        if ($shouldShowTooltip) {
            $Button.ToolTip = $FullText
            Write-Verbose "Smart tooltip set for button '$($Button.Name)': '$FullText'"
        } else {
            $Button.ToolTip = $null
            Write-Verbose "Debug: No tooltip needed for button '$($Button.Name)': '$FullText'"
        }
    } catch {
        Write-Warning "Debug: Error in Set-ButtonContentWithTooltip for '$($Button.Name)': $($_.Exception.Message)"
        # Fallback: Set tooltip based on text length
        $Button.Content = $FullText
        if ($FullText.Length -gt 10) {
            $Button.ToolTip = $FullText
            Write-Verbose "Fallback tooltip set for button '$($Button.Name)': '$FullText' (length: $($FullText.Length))"
        } else {
            $Button.ToolTip = $null
            Write-Verbose "Fallback: No tooltip for button '$($Button.Name)': '$FullText' (length: $($FullText.Length))"
        }
    }
}

# Helper function to set smart tooltip for buttons (legacy compatibility)
function Set-SmartTooltip {
    param(
        [System.Windows.Controls.Button]$Button,
        [string]$Content = ""
    )

    if (-not $Button) {
        return
    }

    # Use button's current content if no content specified
    $textToCheck = if ([string]::IsNullOrEmpty($Content)) { $Button.Content } else { $Content }

    # Use the new function
    Set-ButtonContentWithTooltip -Button $Button -FullText $textToCheck
}

# Helper function to apply smart tooltips to all buttons
function Update-AllButtonTooltips {
    param()

    try {
        # Define button name to message key mappings
        $buttonMappings = @{
            "AddGameButton"           = "addButton"
            "DuplicateGameButton"     = "duplicateButton"
            "DeleteGameButton"        = "deleteButton"
            "AddAppButton"            = "addButton"
            "DeleteAppButton"         = "deleteButton"
            "BrowseAppPathButton"     = "browseButton"
            "BrowseSteamPathButton"   = "browseButton"
            "BrowseEpicPathButton"    = "browseButton"
            "BrowseRiotPathButton"    = "browseButton"
            "BrowseObsPathButton"     = "browseButton"
            "GenerateLaunchersButton" = "generateLaunchers"
            "CheckUpdateButton"       = "checkUpdateButton"
            "SaveButton"              = "saveButton"
            "CloseButton"             = "closeButton"
        }

        # Apply smart tooltips to each button with full localized text
        Write-Verbose "Debug: Starting tooltip update for $($buttonMappings.Count) buttons"
        foreach ($buttonName in $buttonMappings.Keys) {
            $button = $script:Window.FindName($buttonName)
            if ($button) {
                $messageKey = $buttonMappings[$buttonName]
                $fullText = Get-LocalizedMessage -Key $messageKey
                Write-Verbose "Debug: Processing button '$buttonName' with key '$messageKey' -> text '$fullText'"
                Set-ButtonContentWithTooltip -Button $button -FullText $fullText
            } else {
                Write-Verbose "Debug: Button '$buttonName' not found in window"
            }
        }

        Write-Verbose "Smart tooltips updated for all buttons with full localized text"
    } catch {
        Write-Warning "Failed to update button tooltips: $($_.Exception.Message)"
    }
}

# Helper function for safe message display using JSON resources
function Show-SafeMessage {
    param(
        [string]$MessageKey,
        [string]$TitleKey = "info",
        [string[]]$Args = @(),
        [System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )

    try {
        # Get localized strings from JSON resources
        $message = Get-LocalizedMessage -Key $MessageKey -Args $Args
        $title = Get-LocalizedMessage -Key $TitleKey

        # Debug output for error messages only
        if ($Icon -eq [System.Windows.MessageBoxImage]::Error) {
            Write-Host "=== ERROR MESSAGE DEBUG ===" -ForegroundColor Red
            Write-Host "MessageKey: $MessageKey" -ForegroundColor Yellow
            Write-Host "Args Count: $($Args.Count)" -ForegroundColor Yellow
            Write-Host "Args Values: $($Args -join ', ')" -ForegroundColor Yellow
            Write-Host "Final Message: $message" -ForegroundColor Cyan
            Write-Host "Final Title: $title" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Red
        }

        return [System.Windows.MessageBox]::Show($message, $title, $Button, $Icon)
    } catch {
        # Fallback to key names if JSON loading fails
        Write-Warning "Debug: Show-SafeMessage failed, using fallback: $($_.Exception.Message)"
        return [System.Windows.MessageBox]::Show($MessageKey, $TitleKey, $Button, $Icon)
    }
}

# Replace XAML placeholders with localized text
function Replace-XamlPlaceholders {
    param(
        [string]$XamlContent
    )

    try {
        # Define placeholder mappings
        $placeholders = @{
            "[WINDOW_TITLE]"               = Get-LocalizedMessage -Key "windowTitle"
            "[GAMES_TAB_HEADER]"           = Get-LocalizedMessage -Key "gamesTabHeader"
            "[MANAGED_APPS_TAB_HEADER]"    = Get-LocalizedMessage -Key "managedAppsTabHeader"
            "[GLOBAL_SETTINGS_TAB_HEADER]" = Get-LocalizedMessage -Key "globalSettingsTabHeader"
            "[STEAM_PLATFORM]"             = Get-LocalizedMessage -Key "steamPlatform"
            "[EPIC_PLATFORM]"              = Get-LocalizedMessage -Key "epicPlatform"
            "[RIOT_PLATFORM]"              = Get-LocalizedMessage -Key "riotPlatform"
            "[BROWSE_BUTTON]"              = Get-LocalizedMessage -Key "browseButton"
            "[DUPLICATE_BUTTON]"           = Get-LocalizedMessage -Key "duplicateButton"
            "[OBS_SETTINGS_GROUP]"         = Get-LocalizedMessage -Key "obsSettingsGroup"
            "[PATH_SETTINGS_GROUP]"        = Get-LocalizedMessage -Key "pathSettingsGroup"
            "[GENERAL_SETTINGS_GROUP]"     = Get-LocalizedMessage -Key "generalSettingsGroup"
            "[REPLAY_BUFFER_LABEL]"        = Get-LocalizedMessage -Key "replayBufferLabel"
            "[LOG_RETENTION_LABEL]"        = Get-LocalizedMessage -Key "logRetentionLabel"
            "[LOG_RETENTION_30]"           = Get-LocalizedMessage -Key "logRetention30"
            "[LOG_RETENTION_90]"           = Get-LocalizedMessage -Key "logRetention90"
            "[LOG_RETENTION_180]"          = Get-LocalizedMessage -Key "logRetention180"
            "[LOG_RETENTION_UNLIMITED]"    = Get-LocalizedMessage -Key "logRetentionUnlimited"
            "[ENABLE_LOG_NOTARIZATION]"    = Get-LocalizedMessage -Key "enableLogNotarization"
            "[ENHANCED_SHORTCUTS]"         = Get-LocalizedMessage -Key "enhancedShortcuts"
            "[TRADITIONAL_BATCH]"          = Get-LocalizedMessage -Key "traditionalBatch"
            "[GENERATE_LAUNCHERS]"         = Get-LocalizedMessage -Key "generateLaunchers"
            "[LAUNCHER_HELP_TEXT]"         = Get-LocalizedMessage -Key "launcherHelpText"
            "[VERSION_LABEL]"              = Get-LocalizedMessage -Key "versionLabel"
            "[CHECK_UPDATE_BUTTON]"        = Get-LocalizedMessage -Key "checkUpdateButton"
            "[SAVE_BUTTON]"                = Get-LocalizedMessage -Key "saveButton"
            "[CLOSE_BUTTON]"               = Get-LocalizedMessage -Key "closeButton"
        }

        # Replace all placeholders
        foreach ($placeholder in $placeholders.GetEnumerator()) {
            $oldValue = $placeholder.Key
            $newValue = $placeholder.Value

            # Escape XML special characters in the replacement value
            $newValue = $newValue -replace "&", "&amp;"
            $newValue = $newValue -replace "<", "&lt;"
            $newValue = $newValue -replace ">", "&gt;"
            $newValue = $newValue -replace '"', "&quot;"
            $newValue = $newValue -replace "'", "&apos;"

            # Also escape parentheses that might cause XML parsing issues
            $newValue = $newValue -replace "\(", "&#40;"
            $newValue = $newValue -replace "\)", "&#41;"

            $XamlContent = $XamlContent -replace [regex]::Escape($oldValue), $newValue
        }

        return $XamlContent
    } catch {
        Write-Warning "Failed to replace XAML placeholders: $($_.Exception.Message)"
        return $XamlContent
    }
}

# Initialize the application
function Initialize-ConfigEditor {
    param()

    try {
        # Enable verbose output for debugging
        $VerbosePreference = "Continue"
        Write-Verbose "Debug: ConfigEditor initialization started"

        # Initialize config path first
        $script:ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\config.json"

        # Load configuration first (needed for language detection)
        Load-Configuration

        # Load messages with detected language
        Load-Messages

        # Load XAML
        $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8

        # Replace placeholders with localized text
        $xamlContent = Replace-XamlPlaceholders -XamlContent $xamlContent

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
        $script:Window = [Windows.Markup.XamlReader]::Load($reader)

        # Setup UI controls
        Setup-UIControls

        # Setup event handlers
        Setup-EventHandlers

        # Load data into UI
        Load-DataToUI

        # Add event handler for when window is loaded and rendered
        $script:Window.add_Loaded({
                # Delay tooltip application to ensure UI is fully rendered
                $script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action] {
                        Write-Verbose "Debug: Applying tooltips after window load event"
                        Update-AllButtonTooltips
                    })
            })

        # Add event handler for when window content is rendered
        $script:Window.add_ContentRendered({
                Write-Verbose "Debug: Window content rendered - applying tooltips"
                $script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ApplicationIdle, [action] {
                        Write-Verbose "Debug: Applying tooltips after content rendered"
                        Update-AllButtonTooltips
                    })
            })

        # Show window
        $script:Window.ShowDialog() | Out-Null

    } catch {
        Write-Host "Debug: Exception caught in Initialize-ConfigEditor" -ForegroundColor Red
        Write-Host "Debug: Exception message: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Debug: Exception location: Line $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red

        try {
            Show-SafeMessage -MessageKey "initError" -TitleKey "error" -Icon Error
        } catch {
            Write-Host "Debug: Failed to show error message: $($_.Exception.Message)" -ForegroundColor Red
            [System.Windows.MessageBox]::Show("Initialization error occurred: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
}

# Load configuration from file
function Load-Configuration {
    param()

    try {
        if (Test-Path $script:ConfigPath) {
            $jsonContent = Get-Content $script:ConfigPath -Raw -Encoding UTF8
            $script:ConfigData = $jsonContent | ConvertFrom-Json
            Write-Host "Loaded config from: $script:ConfigPath"
        } else {
            # Load from sample if config doesn't exist
            $configSamplePath = Join-Path (Split-Path $PSScriptRoot) "config\config.json.sample"
            if (Test-Path $configSamplePath) {
                $jsonContent = Get-Content $configSamplePath -Raw -Encoding UTF8
                $script:ConfigData = $jsonContent | ConvertFrom-Json
                Write-Host "Loaded config from sample: $configSamplePath"
            } else {
                throw "configNotFound"
            }
        }
    } catch {
        Show-SafeMessage -MessageKey "configLoadError" -TitleKey "error" -Args @($_.Exception.Message) -Icon Error
        # Create default config
        $script:ConfigData = [PSCustomObject]@{
            language    = ""
            obs         = [PSCustomObject]@{
                websocket    = [PSCustomObject]@{
                    host     = "localhost"
                    port     = 4455
                    password = ""
                }
                replayBuffer = $true
            }
            managedApps = [PSCustomObject]@{}
            games       = [PSCustomObject]@{}
            paths       = [PSCustomObject]@{
                steam = ""
                obs   = ""
            }
        }
    }
}

# Get available actions for specific app (Dynamic Action Selection)
function Get-AvailableActionsForApp {
    param(
        [string]$AppId,
        [string]$ExecutablePath = ""
    )

    # Base actions available to all applications
    $baseActions = @("start-process", "stop-process", "none")

    # Application-specific actions
    $specificActions = @()

    # Check by Application ID (primary method)
    switch ($AppId) {
        "discord" {
            $specificActions += @("set-discord-gaming-mode", "restore-discord-normal")
        }
        "vtubeStudio" {
            $specificActions += @("start-vtube-studio", "stop-vtube-studio")
        }
        "clibor" {
            $specificActions += @("toggle-hotkeys")
        }
        default {
            # Check by executable path as fallback for future extensibility
            if ($ExecutablePath -like "*Discord*") {
                $specificActions += @("set-discord-gaming-mode", "restore-discord-normal")
            } elseif ($ExecutablePath -like "*VTube Studio*") {
                $specificActions += @("start-vtube-studio", "stop-vtube-studio")
            } elseif ($ExecutablePath -like "*Clibor*" -or $ExecutablePath -like "*clibor*") {
                $specificActions += @("toggle-hotkeys")
            }
            # Generic applications get no additional actions beyond base actions
        }
    }

    return $baseActions + $specificActions
}

# Update action combo boxes based on selected app
function Update-ActionComboBoxes {
    param([string]$AppId, [string]$ExecutablePath = "")

    $availableActions = Get-AvailableActionsForApp -AppId $AppId -ExecutablePath $ExecutablePath

    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

    # Preserve current selections if they are still valid
    $currentStartAction = $gameStartActionCombo.SelectedItem
    $currentEndAction = $gameEndActionCombo.SelectedItem

    # Clear and repopulate combo boxes
    $gameStartActionCombo.Items.Clear()
    $gameEndActionCombo.Items.Clear()

    foreach ($action in $availableActions) {
        $gameStartActionCombo.Items.Add($action)
        $gameEndActionCombo.Items.Add($action)
    }

    # Restore selections if they are still available
    if ($currentStartAction -in $availableActions) {
        $gameStartActionCombo.SelectedItem = $currentStartAction
    } else {
        $gameStartActionCombo.SelectedIndex = $availableActions.Count - 1  # Default to "none"
    }

    if ($currentEndAction -in $availableActions) {
        $gameEndActionCombo.SelectedItem = $currentEndAction
    } else {
        $gameEndActionCombo.SelectedIndex = $availableActions.Count - 1  # Default to "none"
    }
}

# Setup UI controls (dropdown lists, etc.)
function Setup-UIControls {
    param()

    # Setup Action combo boxes with default actions (will be updated dynamically)
    $defaultActions = @("start-process", "stop-process", "none")
    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

    foreach ($action in $defaultActions) {
        $gameStartActionCombo.Items.Add($action)
        $gameEndActionCombo.Items.Add($action)
    }

    # Setup Termination Method combo box
    $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
    $terminationMethods = @("auto", "graceful", "force")
    foreach ($method in $terminationMethods) {
        $terminationMethodCombo.Items.Add($method)
    }
    $terminationMethodCombo.SelectedItem = "auto"  # Default to auto

    # Initialize termination settings visibility (initially disabled until stop-process action is selected)
    Update-TerminationSettingsVisibility

    # Setup Language combo box
    $languageCombo = $script:Window.FindName("LanguageCombo")
    $languages = @(
        "Auto (System Language)",
        "Chinese Simplified (zh-CN)",
        "Japanese (ja)",
        "English (en)"
    )

    foreach ($lang in $languages) {
        $languageCombo.Items.Add($lang)
    }
}

# Check if action requires process termination settings
function Is-StopProcessAction {
    param([string]$Action)

    # Actions that involve stopping processes and may use termination settings
    $stopProcessActions = @("stop-process")
    return $Action -in $stopProcessActions
}

# Update termination settings visibility based on selected actions
function Update-TerminationSettingsVisibility {
    param()

    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
    $terminationMethodLabel = $script:Window.FindName("TerminationMethodLabel")
    $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
    $gracefulTimeoutLabel = $script:Window.FindName("GracefulTimeoutLabel")
    $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")

    # Check if either start or end action requires termination settings
    $showTerminationSettings = $false

    if ($gameStartActionCombo.SelectedItem) {
        $showTerminationSettings = $showTerminationSettings -or (Is-StopProcessAction -Action $gameStartActionCombo.SelectedItem)
    }

    if ($gameEndActionCombo.SelectedItem) {
        $showTerminationSettings = $showTerminationSettings -or (Is-StopProcessAction -Action $gameEndActionCombo.SelectedItem)
    }

    # Enable/disable termination settings controls
    if ($terminationMethodLabel) { $terminationMethodLabel.IsEnabled = $showTerminationSettings }
    if ($terminationMethodCombo) { $terminationMethodCombo.IsEnabled = $showTerminationSettings }
    if ($gracefulTimeoutLabel) { $gracefulTimeoutLabel.IsEnabled = $showTerminationSettings }
    if ($gracefulTimeoutTextBox) { $gracefulTimeoutTextBox.IsEnabled = $showTerminationSettings }

    # Visual indication (grayed out when disabled)
    $opacity = if ($showTerminationSettings) { 1.0 } else { 0.5 }
    if ($terminationMethodLabel) { $terminationMethodLabel.Opacity = $opacity }
    if ($terminationMethodCombo) { $terminationMethodCombo.Opacity = $opacity }
    if ($gracefulTimeoutLabel) { $gracefulTimeoutLabel.Opacity = $opacity }
    if ($gracefulTimeoutTextBox) { $gracefulTimeoutTextBox.Opacity = $opacity }
}

# Setup event handlers
function Setup-EventHandlers {
    param()

    # Footer buttons
    $saveButton = $script:Window.FindName("SaveButton")
    $saveButton.add_Click({ Handle-SaveConfig })

    $closeButton = $script:Window.FindName("CloseButton")
    $closeButton.add_Click({ Handle-CloseWindow })

    # Games tab events
    $gamesList = $script:Window.FindName("GamesList")
    $gamesList.add_SelectionChanged({ Handle-GameSelectionChanged })

    $addGameButton = $script:Window.FindName("AddGameButton")
    $addGameButton.add_Click({ Handle-AddGame })

    $duplicateGameButton = $script:Window.FindName("DuplicateGameButton")
    $duplicateGameButton.add_Click({ Handle-DuplicateGame })

    $deleteGameButton = $script:Window.FindName("DeleteGameButton")
    $deleteGameButton.add_Click({ Handle-DeleteGame })

    # Platform selection event
    $platformCombo = $script:Window.FindName("PlatformComboBox")
    $platformCombo.add_SelectionChanged({ Handle-PlatformSelectionChanged })

    # Managed Apps tab events
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $managedAppsList.add_SelectionChanged({ Handle-AppSelectionChanged })

    $addAppButton = $script:Window.FindName("AddAppButton")
    $addAppButton.add_Click({ Handle-AddApp })

    $deleteAppButton = $script:Window.FindName("DeleteAppButton")
    $deleteAppButton.add_Click({ Handle-DeleteApp })

    # Update check button event
    $checkUpdateButton = $script:Window.FindName("CheckUpdateButton")
    $checkUpdateButton.add_Click({ Handle-CheckUpdate })

    # Generate launchers button event
    $generateLaunchersButton = $script:Window.FindName("GenerateLaunchersButton")
    $generateLaunchersButton.add_Click({ Handle-GenerateLaunchers })

    # Action selection change events (for dynamic termination settings visibility)
    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    if ($gameStartActionCombo) {
        $gameStartActionCombo.add_SelectionChanged({ Update-TerminationSettingsVisibility })
    }

    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
    if ($gameEndActionCombo) {
        $gameEndActionCombo.add_SelectionChanged({ Update-TerminationSettingsVisibility })
    }

    # Language selection change event
    $languageCombo = $script:Window.FindName("LanguageCombo")
    if ($languageCombo) {
        $languageCombo.add_SelectionChanged({ Handle-LanguageSelectionChanged })
    } else {
        Write-Warning "LanguageCombo not found during event handler setup"
    }
}

# Load data into UI controls
function Load-DataToUI {
    param()

    # Load global settings first (this may update the current language)
    Load-GlobalSettings

    # Update UI text with current language (after global settings are loaded)
    Update-UITexts

    # Load games list
    Update-GamesList

    # Load managed apps list
    Update-ManagedAppsList

    # Initialize version display
    Initialize-VersionDisplay
}

# Update UI texts based on current language
function Update-UITexts {
    param()

    try {
        # Update window title
        $script:Window.Title = Get-LocalizedMessage -Key "windowTitle"

        # Update tab headers
        $script:Window.FindName("GamesTab").Header = Get-LocalizedMessage -Key "gamesTabHeader"
        $script:Window.FindName("ManagedAppsTab").Header = Get-LocalizedMessage -Key "managedAppsTabHeader"
        $script:Window.FindName("GlobalSettingsTab").Header = Get-LocalizedMessage -Key "globalSettingsTabHeader"

        # Update buttons with smart tooltips
        $addGameButton = $script:Window.FindName("AddGameButton")
        if ($addGameButton) { Set-ButtonContentWithTooltip -Button $addGameButton -FullText (Get-LocalizedMessage -Key "addButton") }

        $duplicateGameButton = $script:Window.FindName("DuplicateGameButton")
        if ($duplicateGameButton) { Set-ButtonContentWithTooltip -Button $duplicateGameButton -FullText (Get-LocalizedMessage -Key "duplicateButton") }

        $deleteGameButton = $script:Window.FindName("DeleteGameButton")
        if ($deleteGameButton) { Set-ButtonContentWithTooltip -Button $deleteGameButton -FullText (Get-LocalizedMessage -Key "deleteButton") }

        $addAppButton = $script:Window.FindName("AddAppButton")
        if ($addAppButton) { Set-ButtonContentWithTooltip -Button $addAppButton -FullText (Get-LocalizedMessage -Key "addButton") }

        $deleteAppButton = $script:Window.FindName("DeleteAppButton")
        if ($deleteAppButton) { Set-ButtonContentWithTooltip -Button $deleteAppButton -FullText (Get-LocalizedMessage -Key "deleteButton") }

        $saveButton = $script:Window.FindName("SaveButton")
        if ($saveButton) { Set-ButtonContentWithTooltip -Button $saveButton -FullText (Get-LocalizedMessage -Key "saveButton") }

        $closeButton = $script:Window.FindName("CloseButton")
        if ($closeButton) { Set-ButtonContentWithTooltip -Button $closeButton -FullText (Get-LocalizedMessage -Key "closeButton") }

        # Update labels - Games tab
        $gamesListLabel = $script:Window.FindName("GamesListLabel")
        if ($gamesListLabel) { $gamesListLabel.Content = Get-LocalizedMessage -Key "gamesListLabel" }

        $gameDetailsLabel = $script:Window.FindName("GameDetailsLabel")
        if ($gameDetailsLabel) { $gameDetailsLabel.Content = Get-LocalizedMessage -Key "gameDetailsLabel" }

        $gameIdLabel = $script:Window.FindName("GameIdLabel")
        if ($gameIdLabel) { $gameIdLabel.Content = Get-LocalizedMessage -Key "gameIdLabel" }

        $gameNameLabel = $script:Window.FindName("GameNameLabel")
        if ($gameNameLabel) { $gameNameLabel.Content = Get-LocalizedMessage -Key "gameNameLabel" }

        $platformLabel = $script:Window.FindName("PlatformLabel")
        if ($platformLabel) { $platformLabel.Content = Get-LocalizedMessage -Key "platformLabel" }

        $steamAppIdLabel = $script:Window.FindName("SteamAppIdLabel")
        if ($steamAppIdLabel) { $steamAppIdLabel.Content = Get-LocalizedMessage -Key "steamAppIdLabel" }

        $epicGameIdLabel = $script:Window.FindName("EpicGameIdLabel")
        if ($epicGameIdLabel) { $epicGameIdLabel.Content = Get-LocalizedMessage -Key "epicGameIdLabel" }

        $riotGameIdLabel = $script:Window.FindName("RiotGameIdLabel")
        if ($riotGameIdLabel) { $riotGameIdLabel.Content = Get-LocalizedMessage -Key "riotGameIdLabel" }

        $processNameLabel = $script:Window.FindName("ProcessNameLabel")
        if ($processNameLabel) { $processNameLabel.Content = Get-LocalizedMessage -Key "processNameLabel" }

        $appsToManageLabel = $script:Window.FindName("AppsToManageLabel")
        if ($appsToManageLabel) { $appsToManageLabel.Content = Get-LocalizedMessage -Key "appsToManageLabel" }

        # Update group boxes - Global Settings tab
        $obsSettingsGroup = $script:Window.FindName("ObsSettingsGroup")
        if ($obsSettingsGroup) { $obsSettingsGroup.Header = Get-LocalizedMessage -Key "obsSettingsGroup" }

        $pathSettingsGroup = $script:Window.FindName("PathSettingsGroup")
        if ($pathSettingsGroup) { $pathSettingsGroup.Header = Get-LocalizedMessage -Key "pathSettingsGroup" }

        $generalSettingsGroup = $script:Window.FindName("GeneralSettingsGroup")
        if ($generalSettingsGroup) { $generalSettingsGroup.Header = Get-LocalizedMessage -Key "generalSettingsGroup" }

        # Update labels - Global Settings tab
        $hostLabel = $script:Window.FindName("HostLabel")
        if ($hostLabel) { $hostLabel.Content = Get-LocalizedMessage -Key "hostLabel" }

        $portLabel = $script:Window.FindName("PortLabel")
        if ($portLabel) { $portLabel.Content = Get-LocalizedMessage -Key "portLabel" }

        $passwordLabel = $script:Window.FindName("PasswordLabel")
        if ($passwordLabel) { $passwordLabel.Content = Get-LocalizedMessage -Key "passwordLabel" }

        $replayBufferCheckBox = $script:Window.FindName("ReplayBufferCheckBox")
        if ($replayBufferCheckBox) { $replayBufferCheckBox.Content = Get-LocalizedMessage -Key "replayBufferLabel" }

        $steamPathLabel = $script:Window.FindName("SteamPathLabel")
        if ($steamPathLabel) { $steamPathLabel.Content = Get-LocalizedMessage -Key "steamPathLabel" }

        $epicPathLabel = $script:Window.FindName("EpicPathLabel")
        if ($epicPathLabel) { $epicPathLabel.Content = Get-LocalizedMessage -Key "epicPathLabel" }

        $riotPathLabel = $script:Window.FindName("RiotPathLabel")
        if ($riotPathLabel) { $riotPathLabel.Content = Get-LocalizedMessage -Key "riotPathLabel" }

        $obsPathLabel = $script:Window.FindName("ObsPathLabel")
        if ($obsPathLabel) { $obsPathLabel.Content = Get-LocalizedMessage -Key "obsPathLabel" }

        $languageLabel = $script:Window.FindName("LanguageLabel")
        if ($languageLabel) { $languageLabel.Content = Get-LocalizedMessage -Key "languageLabel" }

        # Update browse buttons with smart tooltips
        $browseSteamPathButton = $script:Window.FindName("BrowseSteamPathButton")
        if ($browseSteamPathButton) { Set-ButtonContentWithTooltip -Button $browseSteamPathButton -FullText (Get-LocalizedMessage -Key "browseButton") }

        $browseEpicPathButton = $script:Window.FindName("BrowseEpicPathButton")
        if ($browseEpicPathButton) { Set-ButtonContentWithTooltip -Button $browseEpicPathButton -FullText (Get-LocalizedMessage -Key "browseButton") }

        $browseRiotPathButton = $script:Window.FindName("BrowseRiotPathButton")
        if ($browseRiotPathButton) { Set-ButtonContentWithTooltip -Button $browseRiotPathButton -FullText (Get-LocalizedMessage -Key "browseButton") }

        $browseObsPathButton = $script:Window.FindName("BrowseObsPathButton")
        if ($browseObsPathButton) { Set-ButtonContentWithTooltip -Button $browseObsPathButton -FullText (Get-LocalizedMessage -Key "browseButton") }

        # Update labels - Managed Apps tab
        $appsListLabel = $script:Window.FindName("AppsListLabel")
        if ($appsListLabel) { $appsListLabel.Content = Get-LocalizedMessage -Key "appsListLabel" }

        $appDetailsLabel = $script:Window.FindName("AppDetailsLabel")
        if ($appDetailsLabel) { $appDetailsLabel.Content = Get-LocalizedMessage -Key "appDetailsLabel" }

        $appIdLabel = $script:Window.FindName("AppIdLabel")
        if ($appIdLabel) { $appIdLabel.Content = Get-LocalizedMessage -Key "appIdLabel" }

        $appPathLabel = $script:Window.FindName("AppPathLabel")
        if ($appPathLabel) { $appPathLabel.Content = Get-LocalizedMessage -Key "appPathLabel" }

        $appProcessNameLabel = $script:Window.FindName("AppProcessNameLabel")
        if ($appProcessNameLabel) { $appProcessNameLabel.Content = Get-LocalizedMessage -Key "processNameLabel" }

        $gameStartActionLabel = $script:Window.FindName("GameStartActionLabel")
        if ($gameStartActionLabel) { $gameStartActionLabel.Content = Get-LocalizedMessage -Key "gameStartActionLabel" }

        $gameEndActionLabel = $script:Window.FindName("GameEndActionLabel")
        if ($gameEndActionLabel) { $gameEndActionLabel.Content = Get-LocalizedMessage -Key "gameEndActionLabel" }

        $appArgumentsLabel = $script:Window.FindName("AppArgumentsLabel")
        if ($appArgumentsLabel) { $appArgumentsLabel.Content = Get-LocalizedMessage -Key "argumentsLabel" }

        $terminationMethodLabel = $script:Window.FindName("TerminationMethodLabel")
        if ($terminationMethodLabel) { $terminationMethodLabel.Content = Get-LocalizedMessage -Key "terminationMethodLabel" }

        $gracefulTimeoutLabel = $script:Window.FindName("GracefulTimeoutLabel")
        if ($gracefulTimeoutLabel) { $gracefulTimeoutLabel.Content = Get-LocalizedMessage -Key "gracefulTimeoutLabel" }

        $browseAppPathButton = $script:Window.FindName("BrowseAppPathButton")
        if ($browseAppPathButton) { Set-ButtonContentWithTooltip -Button $browseAppPathButton -FullText (Get-LocalizedMessage -Key "browseButton") }

        # Update version and update-related texts
        $versionLabel = $script:Window.FindName("VersionLabel")
        if ($versionLabel) { $versionLabel.Text = Get-LocalizedMessage -Key "versionLabel" }

        $checkUpdateButton = $script:Window.FindName("CheckUpdateButton")
        if ($checkUpdateButton) { Set-ButtonContentWithTooltip -Button $checkUpdateButton -FullText (Get-LocalizedMessage -Key "checkUpdateButton") }

        # Update launcher-related labels and buttons
        $launcherTypeLabel = $script:Window.FindName("LauncherTypeLabel")
        if ($launcherTypeLabel) { $launcherTypeLabel.Content = Get-LocalizedMessage -Key "launcherTypeLabel" }

        $generateLaunchersButton = $script:Window.FindName("GenerateLaunchersButton")
        if ($generateLaunchersButton) { Set-ButtonContentWithTooltip -Button $generateLaunchersButton -FullText (Get-LocalizedMessage -Key "generateLaunchers") }

        $launcherHelpText = $script:Window.FindName("LauncherHelpText")
        if ($launcherHelpText) { $launcherHelpText.Text = Get-LocalizedMessage -Key "launcherHelpText" }

        # Update log retention label
        $logRetentionLabel = $script:Window.FindName("LogRetentionLabel")
        if ($logRetentionLabel) { $logRetentionLabel.Content = Get-LocalizedMessage -Key "logRetentionLabel" }

        # Update log notarization checkbox
        $enableLogNotarizationCheckBox = $script:Window.FindName("EnableLogNotarizationCheckBox")
        if ($enableLogNotarizationCheckBox) { $enableLogNotarizationCheckBox.Content = Get-LocalizedMessage -Key "enableLogNotarization" }

        # Update smart tooltips after text changes
        Update-AllButtonTooltips

        Write-Verbose "UI texts updated for language: $script:CurrentLanguage"
    } catch {
        Write-Warning "Failed to update UI texts: $($_.Exception.Message)"
    }
}

# Update games list
function Update-GamesList {
    param()

    $gamesList = $script:Window.FindName("GamesList")
    $gamesList.Items.Clear()

    if ($script:ConfigData.games) {
        $script:ConfigData.games.PSObject.Properties | ForEach-Object {
            $gamesList.Items.Add($_.Name)
        }
    }
}

# Update managed apps list
function Update-ManagedAppsList {
    param()

    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $managedAppsList.Items.Clear()

    if ($script:ConfigData.managedApps) {
        $script:ConfigData.managedApps.PSObject.Properties | ForEach-Object {
            $managedAppsList.Items.Add($_.Name)
        }
    }

    # Update apps to manage checkboxes
    Update-AppsToManagePanel
}

# Update apps to manage panel with checkboxes
function Update-AppsToManagePanel {
    param()

    $panel = $script:Window.FindName("AppsToManagePanel")
    $panel.Children.Clear()

    if ($script:ConfigData.managedApps) {
        $script:ConfigData.managedApps.PSObject.Properties | ForEach-Object {
            $checkBox = New-Object System.Windows.Controls.CheckBox
            $checkBox.Content = $_.Name
            $checkBox.Name = "App_$($_.Name)"
            $checkBox.Margin = "0,2"
            $panel.Children.Add($checkBox)
        }
    }
}

# Load global settings
function Load-GlobalSettings {
    param()

    # OBS Settings
    $script:Window.FindName("ObsHostTextBox").Text = $script:ConfigData.obs.websocket.host
    $script:Window.FindName("ObsPortTextBox").Text = $script:ConfigData.obs.websocket.port.ToString()

    # Handle password loading - support both encrypted and plain text for backward compatibility
    $passwordBox = $script:Window.FindName("ObsPasswordBox")
    $configPassword = $script:ConfigData.obs.websocket.password

    if ($configPassword) {
        try {
            # Attempt to convert from encrypted string (new format)
            $securePassword = $configPassword | ConvertTo-SecureString
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
            $passwordBox.Password = $plainPassword
        } catch {
            # If conversion fails, treat as plain text (old format)
            $passwordBox.Password = $configPassword
            Write-Warning "Plain text password detected - it will be encrypted on next save"
        }
    } else {
        $passwordBox.Password = ""
    }

    $script:Window.FindName("ReplayBufferCheckBox").IsChecked = $script:ConfigData.obs.replayBuffer

    # Path Settings (Multi-Platform)
    $script:Window.FindName("SteamPathTextBox").Text = if ($script:ConfigData.paths.steam) { $script:ConfigData.paths.steam } else { "" }
    $script:Window.FindName("EpicPathTextBox").Text = if ($script:ConfigData.paths.epic) { $script:ConfigData.paths.epic } else { "" }
    $script:Window.FindName("RiotPathTextBox").Text = if ($script:ConfigData.paths.riot) { $script:ConfigData.paths.riot } else { "" }
    $script:Window.FindName("ObsPathTextBox").Text = if ($script:ConfigData.paths.obs) { $script:ConfigData.paths.obs } else { "" }

    # Language Setting
    $languageCombo = $script:Window.FindName("LanguageCombo")
    $currentLang = $script:ConfigData.language
    if ($currentLang -eq "" -or $null -eq $currentLang) {
        $languageCombo.SelectedIndex = 0  # Auto
    } elseif ($currentLang -eq "zh-CN") {
        $languageCombo.SelectedIndex = 1  # Chinese Simplified
    } elseif ($currentLang -eq "ja") {
        $languageCombo.SelectedIndex = 2  # Japanese
    } elseif ($currentLang -eq "en") {
        $languageCombo.SelectedIndex = 3  # English
    }

    # Reload messages with the correct language from config and update UI texts
    # This ensures that when the config editor restarts, it displays in the correct language
    $detectedLang = Get-DetectedLanguage -ConfigData $script:ConfigData
    if ($detectedLang -ne $script:CurrentLanguage) {
        $script:CurrentLanguage = $detectedLang
        Set-CultureByLanguage -LanguageCode $script:CurrentLanguage

        # Reload messages for the detected language
        $messagesPath = Join-Path $PSScriptRoot "messages.json"
        $script:Messages = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $script:CurrentLanguage

        Write-Verbose "Language updated during settings load: $script:CurrentLanguage"

        # Update UI texts to reflect the correct language
        # Note: This will be called after Load-GlobalSettings in Load-DataToUI
    }

    # Log Retention Setting
    $logRetentionCombo = $script:Window.FindName("LogRetentionCombo")
    if ($logRetentionCombo) {
        $retentionDays = if ($script:ConfigData.logging -and $script:ConfigData.logging.logRetentionDays) {
            $script:ConfigData.logging.logRetentionDays
        } else {
            90  # Default value
        }

        # Select appropriate combo box item based on retention days
        switch ($retentionDays) {
            30 { $logRetentionCombo.SelectedIndex = 0 }
            90 { $logRetentionCombo.SelectedIndex = 1 }
            180 { $logRetentionCombo.SelectedIndex = 2 }
            -1 { $logRetentionCombo.SelectedIndex = 3 }
            default { $logRetentionCombo.SelectedIndex = 1 }  # Default to 90 days
        }
    }

    # Log Notarization Setting
    $logNotarizationCheckBox = $script:Window.FindName("EnableLogNotarizationCheckBox")
    if ($logNotarizationCheckBox) {
        $logNotarizationCheckBox.IsChecked = if ($script:ConfigData.logging -and $script:ConfigData.logging.enableNotarization) {
            $script:ConfigData.logging.enableNotarization
        } else {
            $false
        }
    }
}

# Update platform-specific field visibility
function Update-PlatformFields {
    param([string]$Platform)

    # Hide all platform-specific fields first
    $script:Window.FindName("SteamAppIdLabel").Visibility = "Collapsed"
    $script:Window.FindName("SteamAppIdTextBox").Visibility = "Collapsed"
    $script:Window.FindName("EpicGameIdLabel").Visibility = "Collapsed"
    $script:Window.FindName("EpicGameIdTextBox").Visibility = "Collapsed"
    $script:Window.FindName("RiotGameIdLabel").Visibility = "Collapsed"
    $script:Window.FindName("RiotGameIdTextBox").Visibility = "Collapsed"

    # Show platform-specific fields based on selection
    switch ($Platform) {
        "steam" {
            $script:Window.FindName("SteamAppIdLabel").Visibility = "Visible"
            $script:Window.FindName("SteamAppIdTextBox").Visibility = "Visible"
        }
        "epic" {
            $script:Window.FindName("EpicGameIdLabel").Visibility = "Visible"
            $script:Window.FindName("EpicGameIdTextBox").Visibility = "Visible"
        }
        "riot" {
            $script:Window.FindName("RiotGameIdLabel").Visibility = "Visible"
            $script:Window.FindName("RiotGameIdTextBox").Visibility = "Visible"
        }
    }
}

# Handle platform selection changed
function Handle-PlatformSelectionChanged {
    param()

    $platformCombo = $script:Window.FindName("PlatformComboBox")
    if ($platformCombo.SelectedItem -and $platformCombo.SelectedItem.Tag) {
        $selectedPlatform = $platformCombo.SelectedItem.Tag
        Update-PlatformFields -Platform $selectedPlatform
    }
}

# Handle game selection changed
function Handle-GameSelectionChanged {
    param()

    $gamesList = $script:Window.FindName("GamesList")
    $selectedGame = $gamesList.SelectedItem

    if ($selectedGame) {
        $script:CurrentGameId = $selectedGame
        $gameData = $script:ConfigData.games.$selectedGame

        # Load game details
        $script:Window.FindName("GameIdTextBox").Text = $selectedGame
        $script:Window.FindName("GameNameTextBox").Text = $gameData.name
        $script:Window.FindName("ProcessNameTextBox").Text = $gameData.processName

        # Load platform-specific fields
        if ($gameData.platform) {
            $platformCombo = $script:Window.FindName("PlatformComboBox")
            $found = $false
            for ($i = 0; $i -lt $platformCombo.Items.Count; $i++) {
                if ($platformCombo.Items[$i].Tag -eq $gameData.platform) {
                    $platformCombo.SelectedIndex = $i
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $platformCombo.SelectedIndex = 0  # Steam as fallback
            }
            Update-PlatformFields -Platform $gameData.platform
        } else {
            # Default to Steam for backward compatibility
            $platformCombo = $script:Window.FindName("PlatformComboBox")
            $platformCombo.SelectedIndex = 0  # Steam
            Update-PlatformFields -Platform "steam"
        }

        # Load platform-specific IDs
        $script:Window.FindName("SteamAppIdTextBox").Text = if ($gameData.steamAppId) { $gameData.steamAppId } else { "" }
        $script:Window.FindName("EpicGameIdTextBox").Text = if ($gameData.epicGameId) { $gameData.epicGameId } else { "" }
        $script:Window.FindName("RiotGameIdTextBox").Text = if ($gameData.riotGameId) { $gameData.riotGameId } else { "" }

        # Update apps to manage checkboxes
        $panel = $script:Window.FindName("AppsToManagePanel")
        foreach ($child in $panel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $appName = $child.Content
                $child.IsChecked = $gameData.appsToManage -contains $appName
            }
        }
    }
}

# Handle managed app selection changed
function Handle-AppSelectionChanged {
    param()

    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $selectedApp = $managedAppsList.SelectedItem

    if ($selectedApp) {
        $script:CurrentAppId = $selectedApp
        $appData = $script:ConfigData.managedApps.$selectedApp

        # Load app details
        $script:Window.FindName("AppIdTextBox").Text = $selectedApp
        $script:Window.FindName("AppPathTextBox").Text = $appData.path
        $script:Window.FindName("AppProcessNameTextBox").Text = $appData.processName
        $script:Window.FindName("AppArgumentsTextBox").Text = $appData.arguments

        # Load termination settings
        $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
        $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")

        $terminationMethodCombo.SelectedItem = if ($appData.terminationMethod) { $appData.terminationMethod } else { "auto" }
        $gracefulTimeoutTextBox.Text = if ($appData.gracefulTimeoutMs) { $appData.gracefulTimeoutMs } else { "3000" }

        # Update action combo boxes dynamically based on selected app
        Update-ActionComboBoxes -AppId $selectedApp -ExecutablePath $appData.path

        # Set combo box selections (after dynamic update)
        $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
        $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

        $gameStartActionCombo.SelectedItem = $appData.gameStartAction
        $gameEndActionCombo.SelectedItem = $appData.gameEndAction

        # Update termination settings visibility based on selected actions
        Update-TerminationSettingsVisibility
    }
}

# Handle add game
function Handle-AddGame {
    param()

    $newGameId = "newGame$(Get-Random -Minimum 1000 -Maximum 9999)"

    # Add to config data
    if (-not $script:ConfigData.games) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "games" -Value ([PSCustomObject]@{})
    }

    $script:ConfigData.games | Add-Member -MemberType NoteProperty -Name $newGameId -Value ([PSCustomObject]@{
            name         = "New Game"
            platform     = "steam"  # Default to Steam
            steamAppId   = ""
            epicGameId   = ""
            riotGameId   = ""
            processName  = ""
            appsToManage = @()
        })

    Update-GamesList

    # Select the new game
    $gamesList = $script:Window.FindName("GamesList")
    $gamesList.SelectedItem = $newGameId

    Show-SafeMessage -MessageKey "gameAdded" -TitleKey "info"
}

<#
.SYNOPSIS
    Duplicates the currently selected game with all its settings except the Game ID

.DESCRIPTION
    Creates a copy of the selected game with a new unique Game ID while preserving
    all other configuration data including name, platform, app IDs, process name,
    and apps to manage settings. Provides user feedback on success or failure.
#>
function Handle-DuplicateGame {
    param()

    try {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not $selectedGame) {
            Show-SafeMessage -MessageKey "noGameSelected" -TitleKey "warning" -Icon Warning
            return
        }

        # Get the source game data
        $sourceGameData = $script:ConfigData.games.$selectedGame

        if (-not $sourceGameData) {
            Show-SafeMessage -MessageKey "gameDuplicateError" -TitleKey "error" -Args @("Source game data not found") -Icon Error
            return
        }

        # Generate new unique game ID
        $newGameId = "duplicated_$(Get-Random -Minimum 1000 -Maximum 9999)"

        # Ensure the new ID is unique
        while ($script:ConfigData.games.PSObject.Properties[$newGameId]) {
            $newGameId = "duplicated_$(Get-Random -Minimum 1000 -Maximum 9999)"
        }

        # Ensure games section exists
        if (-not $script:ConfigData.games) {
            $script:ConfigData | Add-Member -MemberType NoteProperty -Name "games" -Value ([PSCustomObject]@{})
        }

        # Create a deep copy of the source game data
        $duplicatedGameData = [PSCustomObject]@{
            name         = $sourceGameData.name + " (Copy)"
            platform     = $sourceGameData.platform
            steamAppId   = $sourceGameData.steamAppId
            epicGameId   = $sourceGameData.epicGameId
            riotGameId   = $sourceGameData.riotGameId
            processName  = $sourceGameData.processName
            appsToManage = @($sourceGameData.appsToManage)  # Create a new array copy
        }

        # Add the duplicated game to config data
        $script:ConfigData.games | Add-Member -MemberType NoteProperty -Name $newGameId -Value $duplicatedGameData

        # Update the games list to reflect the new game
        Update-GamesList

        # Select the newly duplicated game
        $gamesList.SelectedItem = $newGameId

        # Show success message with both old and new game IDs
        Show-SafeMessage -MessageKey "gameDuplicated" -TitleKey "info" -Args @($selectedGame, $newGameId)

        Write-Verbose "Successfully duplicated game '$selectedGame' to '$newGameId'"

    } catch {
        Write-Error "Failed to duplicate game: $($_.Exception.Message)"
        Show-SafeMessage -MessageKey "gameDuplicateError" -TitleKey "error" -Args @($_.Exception.Message) -Icon Error
    }
}

# Handle delete game
function Handle-DeleteGame {
    param()

    $gamesList = $script:Window.FindName("GamesList")
    $selectedGame = $gamesList.SelectedItem

    if ($selectedGame) {
        $result = Show-SafeMessage -MessageKey "deleteGameConfirm" -TitleKey "confirmation" -Args @($selectedGame) -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:ConfigData.games.PSObject.Properties.Remove($selectedGame)
            Update-GamesList

            # Clear details
            $script:Window.FindName("GameIdTextBox").Text = ""
            $script:Window.FindName("GameNameTextBox").Text = ""
            $script:Window.FindName("SteamAppIdTextBox").Text = ""
            $script:Window.FindName("EpicGameIdTextBox").Text = ""
            $script:Window.FindName("RiotGameIdTextBox").Text = ""
            $script:Window.FindName("ProcessNameTextBox").Text = ""

            # Reset platform selection
            $platformCombo = $script:Window.FindName("PlatformComboBox")
            $platformCombo.SelectedIndex = 0  # Steam
            Update-PlatformFields -Platform "steam"

            Show-SafeMessage -MessageKey "gameRemoved" -TitleKey "info"
        }
    }
}

# Handle add app
function Handle-AddApp {
    param()

    $newAppId = "newApp$(Get-Random -Minimum 1000 -Maximum 9999)"

    # Add to config data
    if (-not $script:ConfigData.managedApps) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "managedApps" -Value ([PSCustomObject]@{})
    }

    $script:ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name $newAppId -Value ([PSCustomObject]@{
            path            = ""
            processName     = ""
            gameStartAction = "none"
            gameEndAction   = "none"
            arguments       = ""
        })

    # Update all relevant lists and UI components
    Update-ManagedAppsList
    Update-AppsToManagePanel  # Update Game Settings tab checkboxes

    # Select the new app
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $managedAppsList.SelectedItem = $newAppId

    # Update action combo boxes for the new app (default to base actions)
    Update-ActionComboBoxes -AppId $newAppId -ExecutablePath ""

    Show-SafeMessage -MessageKey "appAdded" -TitleKey "info"
}

# Handle delete app
function Handle-DeleteApp {
    param()

    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $selectedApp = $managedAppsList.SelectedItem

    if ($selectedApp) {
        $result = Show-SafeMessage -MessageKey "deleteAppConfirm" -TitleKey "confirmation" -Args @($selectedApp) -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:ConfigData.managedApps.PSObject.Properties.Remove($selectedApp)

            # Update all relevant lists and UI components
            Update-ManagedAppsList
            Update-AppsToManagePanel  # Update Game Settings tab checkboxes

            # Clear details
            $script:Window.FindName("AppIdTextBox").Text = ""
            $script:Window.FindName("AppPathTextBox").Text = ""
            $script:Window.FindName("AppProcessNameTextBox").Text = ""
            $script:Window.FindName("AppArgumentsTextBox").Text = ""

            Show-SafeMessage -MessageKey "appRemoved" -TitleKey "info"
        }
    }
}

# Handle save configuration
function Handle-SaveConfig {
    param()

    try {
        # Save current UI data back to config object
        Save-UIDataToConfig

        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

        # After successful save, refresh all UI lists to ensure consistency
        Update-ManagedAppsList
        Update-GamesList
        Update-AppsToManagePanel  # Refresh Game Settings tab checkboxes

        # If a game is currently selected, update its Apps to Manage checkboxes
        if ($script:CurrentGameId) {
            Handle-GameSelectionChanged
        }

        Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"

    } catch {
        # Debug: Log the actual error message to help troubleshoot
        Write-Host "Debug: Save config error - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Debug: Error type - $($_.Exception.GetType().Name)" -ForegroundColor Red

        # Show error message with proper error details
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Args @($_.Exception.Message) -Icon Error
    }
}

# Save UI data back to config object
function Save-UIDataToConfig {
    param()

    try {
        # Ensure ConfigData exists before attempting to save
        if (-not $script:ConfigData) {
            throw "Configuration data is not loaded or is null"
        }

        # Save current game if selected
        if ($script:CurrentGameId -and $script:CurrentGameId -ne "") {
            Write-Verbose "Debug: Saving current game data for ID: $script:CurrentGameId"
            Save-CurrentGameData
        }

        # Save current app if selected
        if ($script:CurrentAppId -and $script:CurrentAppId -ne "") {
            Write-Verbose "Debug: Saving current app data for ID: $script:CurrentAppId"
            Save-CurrentAppData
        }

        # Save global settings
        Write-Verbose "Debug: Saving global settings data"
        Save-GlobalSettingsData

    } catch {
        Write-Error "Failed to save UI data to config: $($_.Exception.Message)"
        throw
    }
}

# Save current game data
function Save-CurrentGameData {
    param()

    $gameId = $script:Window.FindName("GameIdTextBox").Text
    $gameName = $script:Window.FindName("GameNameTextBox").Text
    $processName = $script:Window.FindName("ProcessNameTextBox").Text

    # Get platform selection
    $platformCombo = $script:Window.FindName("PlatformComboBox")
    $selectedPlatform = "steam"  # Default
    if ($platformCombo.SelectedItem -and $platformCombo.SelectedItem.Tag) {
        $selectedPlatform = $platformCombo.SelectedItem.Tag
    }

    # Get platform-specific IDs
    $steamAppId = $script:Window.FindName("SteamAppIdTextBox").Text
    $epicGameId = $script:Window.FindName("EpicGameIdTextBox").Text
    $riotGameId = $script:Window.FindName("RiotGameIdTextBox").Text

    # Get selected apps to manage
    $appsToManage = @()
    $panel = $script:Window.FindName("AppsToManagePanel")
    foreach ($child in $panel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
            $appsToManage += $child.Content
        }
    }

    # Update config data
    if ($gameId -ne $script:CurrentGameId) {
        # Game ID changed, remove old and add new
        $oldGameData = $script:ConfigData.games.$script:CurrentGameId
        $script:ConfigData.games.PSObject.Properties.Remove($script:CurrentGameId)
        $script:ConfigData.games | Add-Member -MemberType NoteProperty -Name $gameId -Value $oldGameData
    }

    # Safely update basic game properties
    $gameObject = $script:ConfigData.games.$gameId

    # Ensure all basic properties exist
    if (-not $gameObject.PSObject.Properties['name']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'name' -Value "" -Force
    }
    if (-not $gameObject.PSObject.Properties['platform']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'platform' -Value "steam" -Force
    }
    if (-not $gameObject.PSObject.Properties['processName']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'processName' -Value "" -Force
    }
    if (-not $gameObject.PSObject.Properties['appsToManage']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'appsToManage' -Value @() -Force
    }

    # Now safely set the values
    $gameObject.name = $gameName
    $gameObject.platform = $selectedPlatform
    $gameObject.processName = $processName
    $gameObject.appsToManage = $appsToManage

    # Update platform-specific IDs - ensure properties exist before setting them
    $gameObject = $script:ConfigData.games.$gameId

    # Add properties if they don't exist
    if (-not $gameObject.PSObject.Properties['steamAppId']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'steamAppId' -Value "" -Force
    }
    if (-not $gameObject.PSObject.Properties['epicGameId']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'epicGameId' -Value "" -Force
    }
    if (-not $gameObject.PSObject.Properties['riotGameId']) {
        $gameObject | Add-Member -MemberType NoteProperty -Name 'riotGameId' -Value "" -Force
    }

    # Now safely set the values
    $gameObject.steamAppId = $steamAppId
    $gameObject.epicGameId = $epicGameId
    $gameObject.riotGameId = $riotGameId
}

# Save current app data
function Save-CurrentAppData {
    param()

    try {
        # Get UI control values with validation
        $appIdControl = $script:Window.FindName("AppIdTextBox")
        $appPathControl = $script:Window.FindName("AppPathTextBox")
        $processNameControl = $script:Window.FindName("AppProcessNameTextBox")
        $argumentsControl = $script:Window.FindName("AppArgumentsTextBox")
        $gameStartActionControl = $script:Window.FindName("GameStartActionCombo")
        $gameEndActionControl = $script:Window.FindName("GameEndActionCombo")
        $terminationMethodControl = $script:Window.FindName("TerminationMethodCombo")
        $gracefulTimeoutControl = $script:Window.FindName("GracefulTimeoutTextBox")

        if (-not $appIdControl) {
            throw "AppIdTextBox control not found"
        }

        $appId = $appIdControl.Text
        $appPath = if ($appPathControl) { $appPathControl.Text } else { "" }
        $processName = if ($processNameControl) { $processNameControl.Text } else { "" }
        $arguments = if ($argumentsControl) { $argumentsControl.Text } else { "" }
        $gameStartAction = if ($gameStartActionControl -and $gameStartActionControl.SelectedItem) { $gameStartActionControl.SelectedItem } else { "none" }
        $gameEndAction = if ($gameEndActionControl -and $gameEndActionControl.SelectedItem) { $gameEndActionControl.SelectedItem } else { "none" }
        $terminationMethod = if ($terminationMethodControl -and $terminationMethodControl.SelectedItem) { $terminationMethodControl.SelectedItem } else { "auto" }
        $gracefulTimeoutText = if ($gracefulTimeoutControl) { $gracefulTimeoutControl.Text } else { "3000" }

        Write-Verbose "Debug: Saving app data - ID: '$appId', Path: '$appPath'"

        # Validate app ID
        if ([string]::IsNullOrWhiteSpace($appId)) {
            throw "App ID cannot be empty"
        }

        # Ensure managedApps section exists
        if (-not $script:ConfigData.managedApps) {
            $script:ConfigData | Add-Member -MemberType NoteProperty -Name "managedApps" -Value ([PSCustomObject]@{}) -Force
        }

        # Update config data
        if ($appId -ne $script:CurrentAppId -and -not [string]::IsNullOrEmpty($script:CurrentAppId)) {
            # App ID changed, remove old and add new
            Write-Verbose "Debug: App ID changed from '$script:CurrentAppId' to '$appId'"
            if ($script:ConfigData.managedApps.PSObject.Properties[$script:CurrentAppId]) {
                $oldAppData = $script:ConfigData.managedApps.$script:CurrentAppId
                $script:ConfigData.managedApps.PSObject.Properties.Remove($script:CurrentAppId)
                $script:ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name $appId -Value $oldAppData -Force
            }
        }

        # Ensure the app entry exists
        if (-not $script:ConfigData.managedApps.PSObject.Properties[$appId]) {
            Write-Verbose "Debug: Creating new app entry for '$appId'"
            $script:ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name $appId -Value ([PSCustomObject]@{}) -Force
        }

        # Update all properties
        $appData = $script:ConfigData.managedApps.$appId
        $appData | Add-Member -MemberType NoteProperty -Name "path" -Value $appPath -Force
        $appData | Add-Member -MemberType NoteProperty -Name "processName" -Value $processName -Force
        $appData | Add-Member -MemberType NoteProperty -Name "arguments" -Value $arguments -Force
        $appData | Add-Member -MemberType NoteProperty -Name "gameStartAction" -Value $gameStartAction -Force
        $appData | Add-Member -MemberType NoteProperty -Name "gameEndAction" -Value $gameEndAction -Force
        $appData | Add-Member -MemberType NoteProperty -Name "terminationMethod" -Value $terminationMethod -Force

        # Handle graceful timeout conversion
        try {
            $gracefulTimeoutInt = [int]$gracefulTimeoutText
        } catch {
            Write-Warning "Invalid graceful timeout value '$gracefulTimeoutText', using default 3000"
            $gracefulTimeoutInt = 3000
        }
        $appData | Add-Member -MemberType NoteProperty -Name "gracefulTimeoutMs" -Value $gracefulTimeoutInt -Force

        Write-Verbose "Debug: Successfully saved app data for '$appId'"

    } catch {
        Write-Error "Failed to save current app data: $($_.Exception.Message)"
        throw
    }
}

# Save global settings data
function Save-GlobalSettingsData {
    param()

    # Ensure OBS section and subsections exist
    if (-not $script:ConfigData.obs) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "obs" -Value ([PSCustomObject]@{}) -Force
    }
    if (-not $script:ConfigData.obs.PSObject.Properties['websocket']) {
        $script:ConfigData.obs | Add-Member -MemberType NoteProperty -Name "websocket" -Value ([PSCustomObject]@{}) -Force
    }

    # OBS Settings - safely set properties
    $obsWebsocket = $script:ConfigData.obs.websocket
    $obsWebsocket | Add-Member -MemberType NoteProperty -Name "host" -Value $script:Window.FindName("ObsHostTextBox").Text -Force
    $obsWebsocket | Add-Member -MemberType NoteProperty -Name "port" -Value ([int]$script:Window.FindName("ObsPortTextBox").Text) -Force

    # Handle password encryption
    $passwordBox = $script:Window.FindName("ObsPasswordBox")
    if ($passwordBox.Password -and $passwordBox.Password.Length -gt 0) {
        # Convert plain text password to encrypted string for storage
        $securePassword = ConvertTo-SecureString -String $passwordBox.Password -AsPlainText -Force
        $obsWebsocket | Add-Member -MemberType NoteProperty -Name "password" -Value ($securePassword | ConvertFrom-SecureString) -Force
    } else {
        $obsWebsocket | Add-Member -MemberType NoteProperty -Name "password" -Value "" -Force
    }

    $script:ConfigData.obs | Add-Member -MemberType NoteProperty -Name "replayBuffer" -Value $script:Window.FindName("ReplayBufferCheckBox").IsChecked -Force

    # Ensure paths section exists
    if (-not $script:ConfigData.paths) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "paths" -Value ([PSCustomObject]@{}) -Force
    }

    # Path Settings (Multi-Platform) - safely set properties
    $paths = $script:ConfigData.paths
    $paths | Add-Member -MemberType NoteProperty -Name "steam" -Value $script:Window.FindName("SteamPathTextBox").Text -Force
    $paths | Add-Member -MemberType NoteProperty -Name "epic" -Value $script:Window.FindName("EpicPathTextBox").Text -Force
    $paths | Add-Member -MemberType NoteProperty -Name "riot" -Value $script:Window.FindName("RiotPathTextBox").Text -Force
    $paths | Add-Member -MemberType NoteProperty -Name "obs" -Value $script:Window.FindName("ObsPathTextBox").Text -Force

    # Language Setting (language change detection is handled in real-time by event handler)
    $languageCombo = $script:Window.FindName("LanguageCombo")
    $selectedIndex = $languageCombo.SelectedIndex
    $languageValue = switch ($selectedIndex) {
        0 { "" }         # Auto
        1 { "zh-CN" }    # Chinese Simplified
        2 { "ja" }       # Japanese
        3 { "en" }       # English
        default { "" }
    }
    $script:ConfigData | Add-Member -MemberType NoteProperty -Name "language" -Value $languageValue -Force

    # Initialize logging section if it doesn't exist
    if (-not $script:ConfigData.logging) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "logging" -Value ([PSCustomObject]@{})
    }

    # Log Retention Setting
    $logRetentionCombo = $script:Window.FindName("LogRetentionCombo")
    if ($logRetentionCombo -and $logRetentionCombo.SelectedItem) {
        $selectedTag = $logRetentionCombo.SelectedItem.Tag
        $retentionDays = [int]$selectedTag

        # Add or update the logRetentionDays property
        if ($script:ConfigData.logging.PSObject.Properties["logRetentionDays"]) {
            $script:ConfigData.logging.logRetentionDays = $retentionDays
        } else {
            $script:ConfigData.logging | Add-Member -MemberType NoteProperty -Name "logRetentionDays" -Value $retentionDays
        }
    }

    # Log Notarization Setting
    $logNotarizationCheckBox = $script:Window.FindName("EnableLogNotarizationCheckBox")
    if ($logNotarizationCheckBox) {
        if ($script:ConfigData.logging.PSObject.Properties["enableNotarization"]) {
            $script:ConfigData.logging.enableNotarization = $logNotarizationCheckBox.IsChecked
        } else {
            $script:ConfigData.logging | Add-Member -MemberType NoteProperty -Name "enableNotarization" -Value $logNotarizationCheckBox.IsChecked
        }
    }
}

# Initialize version display
function Initialize-VersionDisplay {
    param()

    try {
        $versionInfo = Get-ProjectVersionInfo
        $versionText = $script:Window.FindName("VersionText")
        if ($versionText) {
            $versionText.Text = $versionInfo.FullVersion
        }

        Write-Verbose "Version display initialized: $($versionInfo.FullVersion)"
    } catch {
        Write-Warning "Failed to initialize version display: $($_.Exception.Message)"
    }
}

# Handle check update button click
function Handle-CheckUpdate {
    param()

    try {
        # Show checking status
        $updateStatusText = $script:Window.FindName("UpdateStatusText")
        $checkUpdateButton = $script:Window.FindName("CheckUpdateButton")

        if ($updateStatusText) {
            $updateStatusText.Text = Get-LocalizedMessage -Key "checkingUpdate"
            $updateStatusText.Foreground = "#0066CC"
        }

        if ($checkUpdateButton) {
            $checkUpdateButton.IsEnabled = $false
            Set-ButtonContentWithTooltip -Button $checkUpdateButton -FullText (Get-LocalizedMessage -Key "checkingUpdate")
        }

        # Refresh the UI immediately
        $script:Window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action] {})

        # Check for updates (async-like operation)
        $updateResult = Test-UpdateAvailable

        # Process results
        if ($updateResult.UpdateAvailable) {
            # Update available
            $message = Get-LocalizedMessage -Key "updateAvailable" -Args @($updateResult.LatestVersion, $updateResult.CurrentVersion)
            if ($updateStatusText) {
                $updateStatusText.Text = $message
                $updateStatusText.Foreground = "#FF6600"
            }

            # Ask user if they want to open the releases page
            $result = Show-SafeMessage -MessageKey "updateAvailableConfirm" -TitleKey "updateAvailableTitle" -Args @($updateResult.LatestVersion) -Button YesNo -Icon Question
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                if (-not (Open-ReleasesPage)) {
                    Show-SafeMessage -MessageKey "browserOpenError" -TitleKey "error" -Icon Warning
                }
            }

        } elseif ($updateResult.ContainsKey("ErrorMessage")) {
            # Error occurred
            $messageKey = switch ($updateResult.ErrorType) {
                "NetworkError" { "networkError" }
                "TimeoutError" { "timeoutError" }
                default { "unknownError" }
            }

            $message = Get-LocalizedMessage -Key $messageKey
            if ($updateStatusText) {
                $updateStatusText.Text = $message
                $updateStatusText.Foreground = "#CC0000"
            }

            Show-SafeMessage -MessageKey $messageKey -TitleKey "updateCheckError" -Icon Warning

        } else {
            # Up to date
            $message = Get-LocalizedMessage -Key "upToDate"
            if ($updateStatusText) {
                $updateStatusText.Text = $message
                $updateStatusText.Foreground = "#009900"
            }

            Show-SafeMessage -MessageKey "upToDate" -TitleKey "info"
        }

    } catch {
        Write-Warning "Update check failed: $($_.Exception.Message)"

        $updateStatusText = $script:Window.FindName("UpdateStatusText")
        if ($updateStatusText) {
            $updateStatusText.Text = Get-LocalizedMessage -Key "updateCheckFailed"
            $updateStatusText.Foreground = "#CC0000"
        }

        Show-SafeMessage -MessageKey "updateCheckFailed" -TitleKey "error" -Icon Error

    } finally {
        # Re-enable the button
        $checkUpdateButton = $script:Window.FindName("CheckUpdateButton")
        if ($checkUpdateButton) {
            $checkUpdateButton.IsEnabled = $true
            Set-ButtonContentWithTooltip -Button $checkUpdateButton -FullText (Get-LocalizedMessage -Key "checkUpdateButton")
        }
    }
}

# Handle language selection changed
function Handle-LanguageSelectionChanged {
    param()

    try {
        # Get current language selection
        $languageCombo = $script:Window.FindName("LanguageCombo")
        if (-not $languageCombo) {
            Write-Warning "LanguageCombo not found in Handle-LanguageSelectionChanged"
            return
        }

        if ($languageCombo.SelectedIndex -eq -1) {
            return  # No selection made yet
        }

        # Determine new language based on selection
        $selectedIndex = $languageCombo.SelectedIndex
        $newLanguage = ""
        switch ($selectedIndex) {
            0 { $newLanguage = "" }         # Auto
            1 { $newLanguage = "zh-CN" }    # Chinese Simplified
            2 { $newLanguage = "ja" }       # Japanese
            3 { $newLanguage = "en" }       # English
            default { $newLanguage = "" }
        }

        # Check if language has actually changed
        $oldLanguage = $script:ConfigData.language
        if ($oldLanguage -ne $newLanguage) {
            Write-Verbose "Language changed from '$oldLanguage' to '$newLanguage'"

            # Update config data temporarily
            $script:ConfigData.language = $newLanguage

            # Show restart message
            Show-LanguageChangeRestartMessage -NewLanguage $newLanguage
        }
    } catch {
        Write-Warning "Failed to handle language selection change: $($_.Exception.Message)"
    }
}

# Show language change restart message
function Show-LanguageChangeRestartMessage {
    param([string]$NewLanguage)

    try {
        # Temporarily switch to the new language to show the message in the new language
        $oldCurrentLanguage = $script:CurrentLanguage
        $oldMessages = $script:Messages

        # Detect and load messages for the new language
        $tempConfigData = $script:ConfigData.PSObject.Copy()
        $tempConfigData.language = $NewLanguage
        $detectedLanguage = Get-DetectedLanguage -ConfigData $tempConfigData

        # Load messages for the new language
        $messagesPath = Join-Path $PSScriptRoot "messages.json"
        $newLanguageMessages = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $detectedLanguage

        # Show message in the new language
        if ($newLanguageMessages -and $newLanguageMessages.PSObject.Properties["languageChangeRestart"]) {
            $message = $newLanguageMessages.languageChangeRestart
            $title = $newLanguageMessages.languageChanged
            $restartNow = $newLanguageMessages.restartNow
            $restartLater = $newLanguageMessages.restartLater
        } else {
            # Fallback to English
            $message = "To fully apply the language setting change, please restart the configuration editor.`n`nWould you like to restart now?"
            $title = "Language Setting Changed"
        }

        # Create custom message box with Yes/No buttons
        $result = [System.Windows.MessageBox]::Show(
            $message,
            $title,
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        # Handle user response
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            # User wants to restart now
            Restart-ConfigEditor
        }
        # If user selects No, continue without restart

        # Restore original language settings
        $script:CurrentLanguage = $oldCurrentLanguage
        $script:Messages = $oldMessages

    } catch {
        Write-Warning "Failed to show language change message: $($_.Exception.Message)"
    }
}

# Restart the configuration editor
function Restart-ConfigEditor {
    param()

    try {
        # Save current configuration to file before restarting
        try {
            # Save current UI data back to config object
            Save-UIDataToConfig

            # Convert to JSON and save
            $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

            Write-Verbose "Configuration saved before restart"
        } catch {
            Write-Warning "Failed to save configuration before restart: $($_.Exception.Message)"
            # Show error and ask if user still wants to restart
            $continueRestart = [System.Windows.MessageBox]::Show(
                "Failed to save configuration before restart. Continue with restart anyway?",
                "Save Error",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )

            if ($continueRestart -ne [System.Windows.MessageBoxResult]::Yes) {
                return  # Cancel restart
            }
        }

        # Save current window position and size for better UX
        $currentWindow = $script:Window

        # Start new instance of the configuration editor
        $configEditorPath = $PSCommandPath
        Start-Process -FilePath "powershell.exe" -ArgumentList @(
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$configEditorPath`""
        )

        # Close current window
        $script:Window.Close()

    } catch {
        Write-Error "Failed to restart configuration editor: $($_.Exception.Message)"
        # Show fallback message
        [System.Windows.MessageBox]::Show(
            "Please manually restart the configuration editor to apply language changes.",
            "Manual Restart Required",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
}

# Handle close window
function Handle-CloseWindow {
    param()

    $script:Window.Close()
}

<#
.SYNOPSIS
    Handles launcher generation based on user selection

.DESCRIPTION
    Generates game launchers using either enhanced (.lnk) or traditional (.bat) format
    based on user selection in the GUI. Provides user feedback and error handling.
#>
function Handle-GenerateLaunchers {
    param()

    try {
        # Get UI elements
        $launcherTypeCombo = $script:Window.FindName("LauncherTypeCombo")
        $generateButton = $script:Window.FindName("GenerateLaunchersButton")

        if (-not $launcherTypeCombo -or -not $generateButton) {
            Show-SafeMessage -MessageKey "uiElementNotFound" -TitleKey "error" -Icon Error
            return
        }

        # Disable button during generation
        $generateButton.IsEnabled = $false
        $generateButton.Content = Get-LocalizedMessage -Key "generating"
        Set-SmartTooltip -Button $generateButton

        # Get selected launcher type
        $selectedItem = $launcherTypeCombo.SelectedItem
        $launcherType = $selectedItem.Tag

        # Determine script path based on launcher type
        $rootDir = Split-Path $PSScriptRoot -Parent
        if ($launcherType -eq "lnk") {
            $scriptPath = Join-Path $rootDir "scripts\Create-Launchers-Enhanced.ps1"
        } else {
            $scriptPath = Join-Path $rootDir "scripts\Create-Launchers.ps1"
        }

        # Check if script exists
        if (-not (Test-Path $scriptPath)) {
            Show-SafeMessage -MessageKey "launcherScriptNotFound" -TitleKey "error" -Icon Error
            return
        }

        # Save current configuration before generating launchers
        try {
            Save-UIDataToConfig
            $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8
            Write-Verbose "Configuration saved before launcher generation"
        } catch {
            Write-Warning "Failed to save configuration before launcher generation: $($_.Exception.Message)"
            Show-SafeMessage -MessageKey "saveBeforeLaunchers" -TitleKey "warning" -Icon Warning
            return
        }

        # Execute launcher creation script
        Write-Host "Generating launchers with script: $scriptPath"

        # Run the script and capture output
        $output = & $scriptPath 2>&1

        # Check if launchers were created successfully
        $launcherPattern = if ($launcherType -eq "lnk") { "launch_*.lnk" } else { "launch_*.bat" }
        $createdLaunchers = Get-ChildItem -Path $rootDir -Filter $launcherPattern -ErrorAction SilentlyContinue

        if ($createdLaunchers -and $createdLaunchers.Count -gt 0) {
            $messageKey = if ($launcherType -eq "lnk") { "launchersCreatedEnhanced" } else { "launchersCreatedTraditional" }
            $title = Get-LocalizedMessage -Key "success"
            $message = (Get-LocalizedMessage -Key $messageKey) -f $createdLaunchers.Count

            Show-SafeMessage -MessageKey $messageKey -TitleKey "success" -Icon Information

            Write-Host "Successfully created $($createdLaunchers.Count) launchers:"
            $createdLaunchers | ForEach-Object { Write-Host "  - $($_.Name)" }

        } else {
            Show-SafeMessage -MessageKey "launcherCreationFailed" -TitleKey "error" -Icon Error
            Write-Warning "No launchers were created. Script output: $output"
        }

    } catch {
        Write-Error "Launcher generation failed: $($_.Exception.Message)"
        Show-SafeMessage -MessageKey "launcherCreationError" -TitleKey "error" -Icon Error
    } finally {
        # Re-enable button
        if ($generateButton) {
            $generateButton.IsEnabled = $true
            $generateButton.Content = Get-LocalizedMessage -Key "generateLaunchers"
            Set-SmartTooltip -Button $generateButton
        }
    }
}

# Start the application
Initialize-ConfigEditor
