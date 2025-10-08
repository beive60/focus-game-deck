# Focus Game Deck - Configuration Editor
# PowerShell + WPF GUI for editing config.json
#
# Design Philosophy:
# 1. Lightweight & Simple - Uses Windows native WPF, no additional runtime required
# 2. Maintainable & Extensible - Configuration-driven design with modular structure
# 3. User-Friendly - Intuitive 3-tab GUI with proper internationalization support

# Script parameters
param(
    [switch]$NoAutoStart
)
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

. "$PSScriptRoot/ConfigEditor.State.ps1"
. "$PSScriptRoot/ConfigEditor.UI.ps1"
. "$PSScriptRoot/ConfigEditor.Events.ps1"

try {
    # 状態管理クラスを初期化
    $stateManager = [ConfigEditor.State]::new()

    # UI管理クラスを初期化（XAMLを読み込み、Windowオブジェクトを生成）
    $uiManager = [ConfigEditor.UI]::new($stateManager.Messages)
    $window = $uiManager.Window

    # イベントハンドラクラスを初期化
    $eventHandler = [ConfigEditor.Events]::new($uiManager, $stateManager)
    $eventHandler.RegisterAll()

    # データをUIにロード
    $uiManager.LoadDataToUI($stateManager.ConfigData)

    # ウィンドウを表示
    $window.ShowDialog()

} catch {
    # エラー処理
}

# Import language helper functions
$LanguageHelperPath = Join-Path (Split-Path $PSScriptRoot) "scripts/LanguageHelper.ps1"
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

$UpdateCheckerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "src/modules/UpdateChecker.ps1"
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
$script:HasUnsavedChanges = $false  # Initialize change tracking variable
$script:OriginalConfigData = $null  # Initialize original config tracking

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
        [array]$Arguments = @()
    )

    if ($script:Messages -and $script:Messages.PSObject.Properties[$Key]) {
        $message = $script:Messages.$Key

        # Replace placeholders if args provided
        if ($Arguments.Length -gt 0) {
            Write-Verbose "Debug: Processing message '$Key' with $($Arguments.Length) arguments"
            Write-Verbose "Debug: Original message template: '$message'"
            Write-Verbose "Debug: Message type: $($message.GetType().Name)"

            for ($i = 0; $i -lt $Arguments.Length; $i++) {
                $placeholder = "{$i}"
                $replacement = if ($null -ne $Arguments[$i]) {
                    # Ensure safe string conversion - preserve newlines for proper message formatting
                    [string]$Arguments[$i]
                } else {
                    ""
                }

                Write-Verbose "Debug: Looking for placeholder '$placeholder' in message"
                Write-Verbose "Debug: Replacement value: '$replacement'"
                Write-Verbose "Debug: Message contains placeholder check: $($message -like "*$placeholder*")"

                # Use -replace operator with literal pattern matching for more reliable replacement
                if ($message -like "*$placeholder*") {
                    $oldMessage = $message
                    # Use literal string replacement to avoid regex interpretation issues
                    $message = $message -replace [regex]::Escape($placeholder), $replacement
                    Write-Verbose "Debug: Successfully replaced '$placeholder' with '$replacement'"
                    Write-Verbose "Debug: Message before: '$oldMessage'"
                    Write-Verbose "Debug: Message after:  '$message'"
                } else {
                    Write-Verbose "Debug: Placeholder '$placeholder' not found in message template: '$message'"
                }
            }
            Write-Verbose "Debug: Final processed message: '$message'"
        } else {
            Write-Verbose "Debug: No arguments provided for message '$Key', returning original message"
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
            "AddGameButton"              = "addButton"
            "DuplicateGameButton"        = "duplicateButton"
            "DeleteGameButton"           = "deleteButton"
            "AddAppButton"               = "addButton"
            "DuplicateAppButton"         = "duplicateButton"
            "DeleteAppButton"            = "deleteButton"
            "BrowseAppPathButton"        = "browseButton"
            "BrowseExecutablePathButton" = "browseButton"
            "BrowseSteamPathButton"      = "browseButton"
            "BrowseEpicPathButton"       = "browseButton"
            "BrowseRiotPathButton"       = "browseButton"
            "BrowseObsPathButton"        = "browseButton"
            "AutoDetectSteamButton"      = "autoDetectButton"
            "AutoDetectEpicButton"       = "autoDetectButton"
            "AutoDetectRiotButton"       = "autoDetectButton"
            "AutoDetectObsButton"        = "autoDetectButton"
            "GenerateLaunchersButton"    = "generateLaunchers"
            # "CheckUpdateButton"       = "checkUpdateButton"  # Moved to menu
            "SaveGameSettingsButton"     = "saveButton"
            "SaveManagedAppsButton"      = "saveButton"
            "SaveGlobalSettingsButton"   = "saveButton"
            # Legacy footer buttons - now commented out in XAML
            # "ApplyButton"             = "applyButton"
            # "OKButton"                = "okButton"
            # "CancelButton"            = "cancelButton"
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
        [array]$Arguments = @(),
        [System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )

    try {
        # Get localized strings from JSON resources
        $message = Get-LocalizedMessage -Key $MessageKey -Arguments $Arguments
        $title = Get-LocalizedMessage -Key $TitleKey

        # Debug output for error messages only
        if ($Icon -eq [System.Windows.MessageBoxImage]::Error) {
            Write-Host "=== ERROR MESSAGE DEBUG ===" -ForegroundColor Red
            Write-Host "MessageKey: $MessageKey" -ForegroundColor Yellow
            Write-Host "Arguments Count: $($Arguments.Count)" -ForegroundColor Yellow
            Write-Host "Arguments Values: $($Arguments -join ', ')" -ForegroundColor Yellow
            Write-Host "Final Message: $message" -ForegroundColor Cyan
            Write-Host "Final Title: $title" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Red
        }

        return [System.Windows.MessageBox]::Show($message, $title, $Button, $Icon)
    } catch {
        # Fallback to key names if JSON loading fails
        Write-Warning "Debug: Show-SafeMessage failed, using fallback: $($_.Exception.Message)"
        Write-Warning "Arguments passed: $($Arguments -join ', ')"
        return [System.Windows.MessageBox]::Show($MessageKey, $TitleKey, $Button, $Icon)
    }
}

# Add validation function for prerequisites
function Test-Prerequisites {
    param()

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell version 5.0 or higher required. Current: $($PSVersionTable.PSVersion)"
    }

    # Check essential files
    $requiredFiles = @(
        (Join-Path $PSScriptRoot "MainWindow.xaml"),
        (Join-Path $PSScriptRoot "messages.json"),
        (Join-Path (Split-Path $PSScriptRoot) "config/config.json")
    )

    # Also check for sample config if main config doesn't exist
    if (-not (Test-Path (Join-Path (Split-Path $PSScriptRoot) "config/config.json"))) {
        $requiredFiles += (Join-Path (Split-Path $PSScriptRoot) "config/config.json.sample")
    }

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            $issues += "Required file missing: $file"
        }
    }

    # Check .NET Framework version for WPF
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    } catch {
        $issues += "WPF assemblies not available: $($_.Exception.Message)"
    }

    if ($issues.Count -gt 0) {
        Write-Host "=== PREREQUISITES CHECK FAILED ===" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        Write-Host "================================" -ForegroundColor Red
        return $false
    }

    Write-Host "Prerequisites check passed" -ForegroundColor Green
    return $true
}

<#
.SYNOPSIS
    Launches a game from the launcher tab

.DESCRIPTION
    Initiates game launch using the main game launcher script
    and provides user feedback during the process.
#>
function Start-GameFromLauncher {
    param(
        [Parameter(Mandatory)]
        [string]$GameId
    )

    try {
        # Update status immediately for responsive feedback
        $statusText = $script:Window.FindName("LauncherStatusText")
        if ($statusText) {
            $statusText.Text = Get-LocalizedMessage -Key "launchingGame" -Arguments @($GameId)
            $statusText.Foreground = "#0066CC"  # Blue color for launching state
        }

        # Validate game exists in configuration
        if (-not $script:ConfigData.games -or -not $script:ConfigData.games.PSObject.Properties[$GameId]) {
            Show-SafeMessage -MessageKey "gameNotFound" -TitleKey "error" -Arguments @($GameId) -Icon Error
            if ($statusText) {
                $statusText.Text = Get-LocalizedMessage -Key "launchError"
                $statusText.Foreground = "#CC0000"  # Red color for error
            }
            return
        }

        # Use the direct game launcher to avoid recursive ConfigEditor launches
        $gameLauncherPath = Join-Path $PSScriptRoot "../src/Invoke-FocusGameDeck.ps1"

        if (-not (Test-Path $gameLauncherPath)) {
            Show-SafeMessage -MessageKey "launcherNotFound" -TitleKey "error" -Icon Error
            if ($statusText) {
                $statusText.Text = Get-LocalizedMessage -Key "launchError"
                $statusText.Foreground = "#CC0000"  # Red color for error
            }
            return
        }

        Write-Host "Launching game from GUI: $GameId" -ForegroundColor Cyan

        # Launch the game using PowerShell - bypass Main.ps1 to prevent recursive ConfigEditor launch
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList @(
            "-ExecutionPolicy", "Bypass",
            "-File", $gameLauncherPath,
            "-GameId", $GameId
        ) -WindowStyle Minimized -PassThru

        # Provide immediate non-intrusive feedback
        if ($process) {
            Write-Verbose "Game launch process started with PID: $($process.Id)"

            # Update status with success message - no modal dialog
            if ($statusText) {
                $statusText.Text = Get-LocalizedMessage -Key "gameLaunched" -Arguments @($GameId)
                $statusText.Foreground = "#009900"  # Green color for success
            }
        }

        # Reset status after delay without interrupting user workflow
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(5)  # Longer delay for user to see feedback
        $timer.add_Tick({
                if ($statusText) {
                    $statusText.Text = Get-LocalizedMessage -Key "readyToLaunch"
                    $statusText.Foreground = "#333333"  # Reset to default color
                }
                $timer.Stop()
            })
        $timer.Start()

    } catch {
        Write-Warning "Failed to launch game '$GameId': $($_.Exception.Message)"

        # Only show modal dialog for actual errors that need user attention
        Show-SafeMessage -MessageKey "launchFailed" -TitleKey "error" -Arguments @($GameId, $_.Exception.Message) -Icon Error

        # Update status for error
        $statusText = $script:Window.FindName("LauncherStatusText")
        if ($statusText) {
            $statusText.Text = Get-LocalizedMessage -Key "launchError"
            $statusText.Foreground = "#CC0000"  # Red color for error
        }
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
            "[GAME_LAUNCHER_TAB_HEADER]"   = Get-LocalizedMessage -Key "gameLauncherTabHeader"
            "[GAMES_TAB_HEADER]"           = Get-LocalizedMessage -Key "gamesTabHeader"
            "[MANAGED_APPS_TAB_HEADER]"    = Get-LocalizedMessage -Key "managedAppsTabHeader"
            "[GLOBAL_SETTINGS_TAB_HEADER]" = Get-LocalizedMessage -Key "globalSettingsTabHeader"
            "[STEAM_PLATFORM]"             = Get-LocalizedMessage -Key "steamPlatform"
            "[EPIC_PLATFORM]"              = Get-LocalizedMessage -Key "epicPlatform"
            "[RIOT_PLATFORM]"              = Get-LocalizedMessage -Key "riotPlatform"
            "[STANDALONE_PLATFORM]"        = Get-LocalizedMessage -Key "standalonePlatform"
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
            "[APPLY_BUTTON]"               = Get-LocalizedMessage -Key "applyButton"
            "[OK_BUTTON]"                  = Get-LocalizedMessage -Key "okButton"
            "[CANCEL_BUTTON]"              = Get-LocalizedMessage -Key "cancelButton"
            "[SAVE_BUTTON]"                = Get-LocalizedMessage -Key "saveButton"
            "[CLOSE_BUTTON]"               = Get-LocalizedMessage -Key "closeButton"
            "[TOOLTIP_TERMINATION_METHOD]" = Get-LocalizedMessage -Key "tooltipTerminationMethod"
            "[TOOLTIP_GRACEFUL_TIMEOUT]"   = Get-LocalizedMessage -Key "tooltipGracefulTimeout"
            "[TOOLTIP_PROCESS_NAME]"       = Get-LocalizedMessage -Key "tooltipProcessName"
            "[TOOLTIP_STEAM_APP_ID]"       = Get-LocalizedMessage -Key "tooltipSteamAppId"
            "[TOOLTIP_EPIC_GAME_ID]"       = Get-LocalizedMessage -Key "tooltipEpicGameId"
            "[TOOLTIP_RIOT_GAME_ID]"       = Get-LocalizedMessage -Key "tooltipRiotGameId"
            "[TOOLTIP_EXECUTABLE_PATH]"    = Get-LocalizedMessage -Key "tooltipExecutablePath"
            "[TOOLTIP_LAUNCH_ARGUMENTS]"   = Get-LocalizedMessage -Key "tooltipLaunchArguments"
            "[TOOLTIP_GAME_ACTIONS]"       = Get-LocalizedMessage -Key "tooltipGameActions"
            "[TOOLTIP_APP_ID]"             = Get-LocalizedMessage -Key "tooltipAppId"
            "[TOOLTIP_GAME_ID]"            = Get-LocalizedMessage -Key "tooltipGameId"
            "[TOOLTIP_DISPLAY_NAME]"       = Get-LocalizedMessage -Key "tooltipDisplayName"
            "[LAUNCHER_WELCOME_TEXT]"      = Get-LocalizedMessage -Key "launcherWelcomeText"
            "[LAUNCHER_SUBTITLE_TEXT]"     = Get-LocalizedMessage -Key "launcherSubtitleText"
            "[REFRESH_BUTTON]"             = Get-LocalizedMessage -Key "refreshButton"
            "[EDIT_BUTTON]"                = Get-LocalizedMessage -Key "editButton"
            "[LAUNCH_BUTTON]"              = Get-LocalizedMessage -Key "launchButton"
            "[READY_TO_LAUNCH]"            = Get-LocalizedMessage -Key "readyToLaunch"
            "[LAUNCHER_HINT_TEXT]"         = Get-LocalizedMessage -Key "launcherHintText"
            "[ADD_GAME_BUTTON]"            = Get-LocalizedMessage -Key "addGameButton"
            "[OPEN_CONFIG_BUTTON]"         = Get-LocalizedMessage -Key "openConfigButton"
            "[HELP_MENU_HEADER]"           = Get-LocalizedMessage -Key "helpMenuHeader"
            "[CHECK_UPDATE_MENU_ITEM]"     = Get-LocalizedMessage -Key "checkUpdateMenuItem"
            "[ABOUT_MENU_ITEM]"            = Get-LocalizedMessage -Key "aboutMenuItem"
            "[moveTopButton]"              = Get-LocalizedMessage -Key "moveTopButton"
            "[moveUpButton]"               = Get-LocalizedMessage -Key "moveUpButton"
            "[moveDownButton]"             = Get-LocalizedMessage -Key "moveDownButton"
            "[moveBottomButton]"           = Get-LocalizedMessage -Key "moveBottomButton"
            "[moveTopTooltip]"             = Get-LocalizedMessage -Key "moveTopTooltip"
            "[moveUpTooltip]"              = Get-LocalizedMessage -Key "moveUpTooltip"
            "[moveDownTooltip]"            = Get-LocalizedMessage -Key "moveDownTooltip"
            "[moveBottomTooltip]"          = Get-LocalizedMessage -Key "moveBottomTooltip"
            "[AUTO_DETECT_BUTTON]"         = Get-LocalizedMessage -Key "autoDetectButton"
            "[AUTO_DETECT_STEAM_TOOLTIP]"  = Get-LocalizedMessage -Key "autoDetectSteamTooltip"
            "[AUTO_DETECT_EPIC_TOOLTIP]"   = Get-LocalizedMessage -Key "autoDetectEpicTooltip"
            "[AUTO_DETECT_RIOT_TOOLTIP]"   = Get-LocalizedMessage -Key "autoDetectRiotTooltip"
            "[AUTO_DETECT_OBS_TOOLTIP]"    = Get-LocalizedMessage -Key "autoDetectObsTooltip"
        }

        # Replace all placeholders
        foreach ($placeholder in $placeholders.GetEnumerator()) {
            $oldValue = $placeholder.Key
            $newValue = $placeholder.Value

            # For menu items, preserve & character for access keys
            $isMenuPlaceholder = $oldValue -match "_MENU_|_MENU_ITEM"

            Write-Verbose "Debug: Placeholder '$oldValue' -> '$newValue' (isMenu: $isMenuPlaceholder)"

            if (-not $isMenuPlaceholder) {
                # Escape XML special characters for non-menu items
                $newValue = $newValue -replace "&", "&amp;"
                $newValue = $newValue -replace "<", "&lt;"
                $newValue = $newValue -replace ">", "&gt;"
                $newValue = $newValue -replace '"', "&quot;"
                $newValue = $newValue -replace "'", "&apos;"

                # Also escape parentheses that might cause XML parsing issues
                $newValue = $newValue -replace "\(", "&#40;"
                $newValue = $newValue -replace "\)", "&#41;"
            } else {
                # For menu items, escape XML characters but handle & specially for WPF
                $newValue = $newValue -replace "<", "&lt;"
                $newValue = $newValue -replace ">", "&gt;"
                $newValue = $newValue -replace '"', "&quot;"
                # For WPF menus, use _ instead of & for access keys
                $newValue = $newValue -replace "&", "_"
            }

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
        Write-Host "=== ConfigEditor initialization started ===" -ForegroundColor Green

        # Step 1: Load WPF assemblies
        try {
            Write-Host "Step 1: Loading WPF assemblies" -ForegroundColor Yellow
            Add-Type -AssemblyName PresentationFramework
            Add-Type -AssemblyName PresentationCore
            Add-Type -AssemblyName WindowsBase
            Write-Host "Step 1: WPF assemblies loaded successfully" -ForegroundColor Green
        } catch {
            Write-Host "Step 1 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "WPF assembly loading failed: $($_.Exception.Message)"
        }

        # Step 2: Initialize config path
        try {
            Write-Host "Step 2: Initializing config path" -ForegroundColor Yellow
            $script:ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config/config.json"
            Write-Host "Step 2: Config path set to: $script:ConfigPath" -ForegroundColor Green
        } catch {
            Write-Host "Step 2 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "Config path initialization failed: $($_.Exception.Message)"
        }

        # Step 3: Load configuration
        try {
            Write-Host "Step 3: Loading configuration" -ForegroundColor Yellow
            Load-Configuration
            Write-Host "Step 3: Configuration loaded successfully" -ForegroundColor Green
        } catch {
            Write-Host "Step 3 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "Configuration loading failed: $($_.Exception.Message)"
        }

        # Step 4: Load messages
        try {
            Write-Host "Step 4: Loading messages" -ForegroundColor Yellow
            Load-Messages
            Write-Host "Step 4: Messages loaded successfully for language: $script:CurrentLanguage" -ForegroundColor Green
        } catch {
            Write-Host "Step 4 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "Message loading failed: $($_.Exception.Message)"
        }

        # Step 5: Load and process XAML
        try {
            Write-Host "Step 5: Loading XAML" -ForegroundColor Yellow
            $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"

            if (-not (Test-Path $xamlPath)) {
                throw "XAML file not found: $xamlPath"
            }

            $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
            Write-Host "Step 5a: XAML content loaded, length: $($xamlContent.Length)" -ForegroundColor Cyan

            $xamlContent = Replace-XamlPlaceholders -XamlContent $xamlContent
            Write-Host "Step 5b: XAML placeholders replaced" -ForegroundColor Cyan

            $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
            Write-Host "Step 5c: XML Reader created successfully" -ForegroundColor Cyan

            $script:Window = [Windows.Markup.XamlReader]::Load($reader)
            Write-Host "Step 5d: XamlReader.Load completed" -ForegroundColor Cyan

            if (-not $script:Window) {
                throw "XamlReader returned null window object"
            }

            Write-Host "Step 5: XAML loaded successfully, window type: $($script:Window.GetType().FullName)" -ForegroundColor Green
        } catch {
            Write-Host "Step 5 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.Exception.InnerException) {
                Write-Host "Step 5 Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }
            throw "XAML loading failed: $($_.Exception.Message)"
        }

        # Step 6: Setup UI controls
        try {
            Write-Host "Step 6: Setting up UI controls" -ForegroundColor Yellow
            Setup-UIControls
            Write-Host "Step 6: UI controls setup completed" -ForegroundColor Green
        } catch {
            Write-Host "Step 6 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "UI controls setup failed: $($_.Exception.Message)"
        }

        # Step 7: Setup event handlers
        try {
            Write-Host "Step 7: Setting up event handlers" -ForegroundColor Yellow
            Setup-EventHandlers
            Write-Host "Step 7: Event handlers setup completed" -ForegroundColor Green
        } catch {
            Write-Host "Step 7 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "Event handlers setup failed: $($_.Exception.Message)"
        }

        # Step 8: Load data into UI
        try {
            Write-Host "Step 8: Loading data into UI" -ForegroundColor Yellow
            Load-DataToUI
            Write-Host "Step 8: Data loading completed" -ForegroundColor Green
        } catch {
            Write-Host "Step 8 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "Data loading failed: $($_.Exception.Message)"
        }

        # Step 9: Setup change tracking
        try {
            Write-Host "Step 9: Setting up change tracking" -ForegroundColor Yellow
            Save-OriginalConfig
            Set-ConfigModified -IsModified $false
            Write-Host "Step 9: Change tracking setup completed" -ForegroundColor Green
        } catch {
            Write-Host "Step 9 WARNING: $($_.Exception.Message)" -ForegroundColor Magenta
            Write-Warning "Configuration change tracking disabled due to setup failure"
        }

        # Step 10: Setup window event handlers
        try {
            Write-Host "Step 10: Setting up window event handlers" -ForegroundColor Yellow
            $script:Window.add_Loaded({
                    try {
                        Write-Verbose "Debug: Window loaded event triggered"
                        Update-AllButtonTooltips
                        Write-Verbose "Debug: Button tooltips updated after window load"
                    } catch {
                        Write-Warning "Failed to update tooltips after window load: $($_.Exception.Message)"
                    }
                })

            $script:Window.add_ContentRendered({
                    try {
                        Write-Verbose "Debug: Window content rendered event triggered"
                        Update-AllButtonTooltips
                        Write-Verbose "Debug: Button tooltips updated after content render"
                    } catch {
                        Write-Warning "Failed to update tooltips after content render: $($_.Exception.Message)"
                    }
                })
            Write-Host "Step 10: Window event handlers setup completed" -ForegroundColor Green
        } catch {
            Write-Host "Step 10 FAILED: $($_.Exception.Message)" -ForegroundColor Red
            throw "Window event handlers setup failed: $($_.Exception.Message)"
        }

        # Step 11: Show window
        try {
            Write-Host "Step 11: Showing window" -ForegroundColor Yellow
            $dialogResult = $script:Window.ShowDialog()
            Write-Host "Step 11: Window displayed successfully" -ForegroundColor Green
        } catch {
            Write-Host "Step 11 ShowDialog failed, trying alternative method: $($_.Exception.Message)" -ForegroundColor Yellow
            try {
                $script:Window.Show()
                Write-Host "Step 11: Alternative Show() method succeeded" -ForegroundColor Green

                # Keep window alive with event loop
                try {
                    while ($script:Window.IsVisible) {
                        Start-Sleep -Milliseconds 100
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                } catch {
                    Write-Verbose "Window event loop interrupted: $($_.Exception.Message)"
                }
            } catch {
                Write-Host "Step 11 FAILED: $($_.Exception.Message)" -ForegroundColor Red
                throw "Failed to display window: $($_.Exception.Message)"
            }
        }

        Write-Host "=== ConfigEditor initialization completed ===" -ForegroundColor Green

    } catch {
        Write-Host "=== INITIALIZATION FAILED ===" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Location: Line $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        Write-Host "Full exception details:" -ForegroundColor Red
        Write-Host ($_.Exception | Format-List * -Force | Out-String) -ForegroundColor Red
        Write-Host "Call stack:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        Write-Host "================================" -ForegroundColor Red

        try {
            Show-SafeMessage -MessageKey "initError" -TitleKey "error" -Icon Error
        } catch {
            Write-Host "Debug: Failed to show error message: $($_.Exception.Message)" -ForegroundColor Red
            [System.Windows.MessageBox]::Show("Initialization error occurred: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
}

# Common Helper Functions for Config Item Management

<#
.SYNOPSIS
    Generates a unique ID for configuration items

.DESCRIPTION
    Creates a unique identifier with the specified prefix, ensuring no collision
    with existing items in the provided collection. Uses random number generation
    with collision detection for uniqueness.
#>
function New-UniqueConfigId {
    param(
        [Parameter(Mandatory)]
        [object]$Collection,
        [string]$Prefix = "new",
        [int]$MinRandom = 1000,
        [int]$MaxRandom = 9999
    )

    do {
        $newId = "${Prefix}$(Get-Random -Minimum $MinRandom -Maximum $MaxRandom)"
    } while ($Collection.PSObject.Properties[$newId])

    return $newId
}

<#
.SYNOPSIS
    Validates the selected item for duplication operations

.DESCRIPTION
    Checks if an item is selected and if its source data exists in the configuration.
    Returns validation result and displays appropriate error messages.
#>
function Test-DuplicateSource {
    param(
        [string]$SelectedItem,
        [object]$SourceData,
        [string]$ItemType  # "game" or "app"
    )

    if (-not $SelectedItem) {
        Show-SafeMessage -MessageKey "no${ItemType}Selected" -TitleKey "warning" -Icon Warning
        return $false
    }

    if (-not $SourceData) {
        Show-SafeMessage -MessageKey "${ItemType}DuplicateError" -TitleKey "error" -Arguments @("Source ${ItemType} data not found") -Icon Error
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Shows duplication result messages

.DESCRIPTION
    Displays success or error messages for duplication operations with proper
    localization and error handling.
#>
function Show-DuplicateResult {
    param(
        [string]$OriginalId,
        [string]$NewId,
        [string]$ItemType,  # "Game" or "App"
        [bool]$Success,
        [string]$ErrorMessage = ""
    )

    if ($Success) {
        Show-SafeMessage -MessageKey "${ItemType.ToLower()}Duplicated" -TitleKey "info" -Arguments @($OriginalId, $NewId)
        Write-Verbose "Successfully duplicated ${ItemType.ToLower()} '$OriginalId' to '$NewId'"
    } else {
        Write-Error "Failed to duplicate ${ItemType.ToLower()}: $ErrorMessage"
        Show-SafeMessage -MessageKey "${ItemType.ToLower()}DuplicateError" -TitleKey "error" -Arguments @($ErrorMessage) -Icon Error
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

# Check if action requires process termination settings
function Is-StopProcessAction {
    param([string]$Action)

    # Actions that involve stopping processes and may use termination settings
    $stopProcessActions = @("stop-process")
    return $Action -in $stopProcessActions
}

# Global variable to track changes
$script:HasUnsavedChanges = $false
$script:OriginalConfigData = $null

# Start the application only if not suppressed
if (-not $NoAutoStart) {
    if (Test-Prerequisites) {
        Initialize-ConfigEditor
    } else {
        Write-Host "Cannot start ConfigEditor due to missing prerequisites" -ForegroundColor Red
        exit 1
    }
}
