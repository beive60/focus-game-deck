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
            "AddGameButton"            = "addButton"
            "DuplicateGameButton"      = "duplicateButton"
            "DeleteGameButton"         = "deleteButton"
            "AddAppButton"             = "addButton"
            "DuplicateAppButton"       = "duplicateButton"
            "DeleteAppButton"          = "deleteButton"
            "BrowseAppPathButton"      = "browseButton"
            "BrowseSteamPathButton"    = "browseButton"
            "BrowseEpicPathButton"     = "browseButton"
            "BrowseRiotPathButton"     = "browseButton"
            "BrowseObsPathButton"      = "browseButton"
            "GenerateLaunchersButton"  = "generateLaunchers"
            # "CheckUpdateButton"       = "checkUpdateButton"  # Moved to menu
            "SaveGameSettingsButton"   = "saveButton"
            "SaveManagedAppsButton"    = "saveButton"
            "SaveGlobalSettingsButton" = "saveButton"
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
            $configSamplePath = Join-Path (Split-Path $PSScriptRoot) "config/config.json.sample"
            if (Test-Path $configSamplePath) {
                $jsonContent = Get-Content $configSamplePath -Raw -Encoding UTF8
                $script:ConfigData = $jsonContent | ConvertFrom-Json
                Write-Host "Loaded config from sample: $configSamplePath"
            } else {
                throw "configNotFound"
            }
        }
    } catch {
        Show-SafeMessage -MessageKey "configLoadError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
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

    # Get localized language names from messages
    $autoLanguageText = Get-LocalizedMessage -Key "autoLanguage"
    $chineseSimplifiedText = Get-LocalizedMessage -Key "languageChineseSimplified"
    $japaneseText = Get-LocalizedMessage -Key "languageJapanese"
    $englishText = Get-LocalizedMessage -Key "languageEnglish"

    $languages = @(
        $autoLanguageText,
        $chineseSimplifiedText,
        $japaneseText,
        $englishText
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

    # Game Launcher tab events
    $refreshGameListButton = $script:Window.FindName("RefreshGameListButton")
    if ($refreshGameListButton) {
        $refreshGameListButton.add_Click({ Update-GameLauncherList })
    }

    $addNewGameButton = $script:Window.FindName("AddNewGameButton")
    if ($addNewGameButton) {
        $addNewGameButton.add_Click({ Handle-AddNewGameFromLauncher })
    }

    $openConfigButton = $script:Window.FindName("OpenConfigButton")
    if ($openConfigButton) {
        $openConfigButton.add_Click({ Switch-ToGameSettingsTab })
    }

    # Footer buttons - REMOVED: Apply, OK, Cancel (replaced with tab-specific Save buttons)
    # $applyButton = $script:Window.FindName("ApplyButton")
    # $applyButton.add_Click({ Handle-ApplyConfig })
    # $okButton = $script:Window.FindName("OKButton")
    # $okButton.add_Click({ Handle-OKConfig })
    # $cancelButton = $script:Window.FindName("CancelButton")
    # $cancelButton.add_Click({ Handle-CancelConfig })

    # Tab-specific Save button events
    $saveGameSettingsButton = $script:Window.FindName("SaveGameSettingsButton")
    if ($saveGameSettingsButton) {
        $saveGameSettingsButton.add_Click({ Handle-SaveGameSettings })
    }

    $saveManagedAppsButton = $script:Window.FindName("SaveManagedAppsButton")
    if ($saveManagedAppsButton) {
        $saveManagedAppsButton.add_Click({ Handle-SaveManagedApps })
    }

    $saveGlobalSettingsButton = $script:Window.FindName("SaveGlobalSettingsButton")
    if ($saveGlobalSettingsButton) {
        $saveGlobalSettingsButton.add_Click({ Handle-SaveGlobalSettings })
    }

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

    $duplicateAppButton = $script:Window.FindName("DuplicateAppButton")
    $duplicateAppButton.add_Click({ Handle-DuplicateApp })

    $deleteAppButton = $script:Window.FindName("DeleteAppButton")
    $deleteAppButton.add_Click({ Handle-DeleteApp })

    # Menu item events
    $checkUpdateMenuItem = $script:Window.FindName("CheckUpdateMenuItem")
    if ($checkUpdateMenuItem) {
        $checkUpdateMenuItem.add_Click({ Handle-CheckUpdate })
    }

    $aboutMenuItem = $script:Window.FindName("AboutMenuItem")
    if ($aboutMenuItem) {
        $aboutMenuItem.add_Click({ Handle-About })
    }

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

    # Window closing event (×ボタン)
    $script:Window.add_Closing({ param($sender, $e); Handle-WindowClosing -Event $e })

    # Setup change tracking event handlers
    Setup-ChangeTrackingEventHandlers
}

# Setup change tracking event handlers for UI elements
function Setup-ChangeTrackingEventHandlers {
    param()

    try {
        # Helper function to safely add event handlers
        function Add-SafeEventHandler {
            param(
                [string]$ControlName,
                [string]$EventType,
                [scriptblock]$Handler
            )

            try {
                $control = $script:Window.FindName($ControlName)
                if ($control) {
                    switch ($EventType) {
                        "TextChanged" { $control.add_TextChanged($Handler) }
                        "SelectionChanged" { $control.add_SelectionChanged($Handler) }
                        "Checked" { $control.add_Checked($Handler) }
                        "Unchecked" { $control.add_Unchecked($Handler) }
                        "PasswordChanged" { $control.add_PasswordChanged($Handler) }
                        default { Write-Warning "Unknown event type: $EventType for control $ControlName" }
                    }
                    Write-Verbose "Successfully added $EventType event handler to $ControlName"
                } else {
                    Write-Verbose "Control '$ControlName' not found - skipping event handler setup"
                }
            } catch {
                Write-Warning "Failed to add $EventType event handler to $ControlName`: $($_.Exception.Message)"
            }
        }

        # Text boxes in Games tab
        Add-SafeEventHandler "GameIdTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "GameNameTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "ProcessNameTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "SteamAppIdTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "EpicGameIdTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "RiotGameIdTextBox" "TextChanged" { Set-ConfigModified }

        # Platform combo box
        Add-SafeEventHandler "PlatformComboBox" "SelectionChanged" { Set-ConfigModified }

        # Text boxes and controls in Managed Apps tab
        Add-SafeEventHandler "AppIdTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "AppPathTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "AppProcessNameTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "AppArgumentsTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "GameStartActionCombo" "SelectionChanged" { Set-ConfigModified }
        Add-SafeEventHandler "GameEndActionCombo" "SelectionChanged" { Set-ConfigModified }
        Add-SafeEventHandler "TerminationMethodCombo" "SelectionChanged" { Set-ConfigModified }
        Add-SafeEventHandler "GracefulTimeoutTextBox" "TextChanged" { Set-ConfigModified }

        # Global settings controls
        Add-SafeEventHandler "ObsHostTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "ObsPortTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "ObsPasswordBox" "PasswordChanged" { Set-ConfigModified }
        Add-SafeEventHandler "ReplayBufferCheckBox" "Checked" { Set-ConfigModified }
        Add-SafeEventHandler "ReplayBufferCheckBox" "Unchecked" { Set-ConfigModified }

        Add-SafeEventHandler "SteamPathTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "EpicPathTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "RiotPathTextBox" "TextChanged" { Set-ConfigModified }
        Add-SafeEventHandler "ObsPathTextBox" "TextChanged" { Set-ConfigModified }

        Add-SafeEventHandler "LanguageCombo" "SelectionChanged" { Set-ConfigModified }
        Add-SafeEventHandler "LogRetentionCombo" "SelectionChanged" { Set-ConfigModified }
        Add-SafeEventHandler "EnableLogNotarizationCheckBox" "Checked" { Set-ConfigModified }
        Add-SafeEventHandler "EnableLogNotarizationCheckBox" "Unchecked" { Set-ConfigModified }

        Write-Verbose "Change tracking event handlers setup completed successfully"

    } catch {
        Write-Warning "Error in Setup-ChangeTrackingEventHandlers: $($_.Exception.Message)"
        # Don't throw - continue with initialization even if some event handlers fail
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

    # Initialize game launcher list
    Update-GameLauncherList

    # Initialize launcher tab status texts
    Initialize-LauncherTabTexts

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

        $duplicateAppButton = $script:Window.FindName("DuplicateAppButton")
        if ($duplicateAppButton) { Set-ButtonContentWithTooltip -Button $duplicateAppButton -FullText (Get-LocalizedMessage -Key "duplicateButton") }

        $deleteAppButton = $script:Window.FindName("DeleteAppButton")
        if ($deleteAppButton) { Set-ButtonContentWithTooltip -Button $deleteAppButton -FullText (Get-LocalizedMessage -Key "deleteButton") }

        $applyButton = $script:Window.FindName("ApplyButton")
        if ($applyButton) { Set-ButtonContentWithTooltip -Button $applyButton -FullText (Get-LocalizedMessage -Key "applyButton") }

        $okButton = $script:Window.FindName("OKButton")
        if ($okButton) { Set-ButtonContentWithTooltip -Button $okButton -FullText (Get-LocalizedMessage -Key "okButton") }

        $cancelButton = $script:Window.FindName("CancelButton")
        if ($cancelButton) { Set-ButtonContentWithTooltip -Button $cancelButton -FullText (Get-LocalizedMessage -Key "cancelButton") }

        # Update tab-specific Save buttons
        $saveGameSettingsButton = $script:Window.FindName("SaveGameSettingsButton")
        if ($saveGameSettingsButton) { Set-ButtonContentWithTooltip -Button $saveGameSettingsButton -FullText (Get-LocalizedMessage -Key "saveButton") }

        $saveManagedAppsButton = $script:Window.FindName("SaveManagedAppsButton")
        if ($saveManagedAppsButton) { Set-ButtonContentWithTooltip -Button $saveManagedAppsButton -FullText (Get-LocalizedMessage -Key "saveButton") }

        $saveGlobalSettingsButton = $script:Window.FindName("SaveGlobalSettingsButton")
        if ($saveGlobalSettingsButton) { Set-ButtonContentWithTooltip -Button $saveGlobalSettingsButton -FullText (Get-LocalizedMessage -Key "saveButton") }

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

        # CheckUpdateButton moved to Help menu
        # Menu items are updated via XAML placeholder replacement

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
        $languageCombo.SelectedIndex = 0  # Auto (System Language)
    } elseif ($currentLang -eq "zh-CN") {
        $languageCombo.SelectedIndex = 1  # 简体中文
    } elseif ($currentLang -eq "ja") {
        $languageCombo.SelectedIndex = 2  # 日本語
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

    # Ensure games section exists
    if (-not $script:ConfigData.games) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "games" -Value ([PSCustomObject]@{})
    }

    # Generate unique game ID
    $newGameId = New-UniqueConfigId -Collection $script:ConfigData.games -Prefix "newGame"

    # Add to config data
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
        $sourceGameData = if ($selectedGame) { $script:ConfigData.games.$selectedGame } else { $null }

        # Validate selection and source data
        if (-not (Test-DuplicateSource -SelectedItem $selectedGame -SourceData $sourceGameData -ItemType "Game")) {
            return
        }

        # Ensure games section exists
        if (-not $script:ConfigData.games) {
            $script:ConfigData | Add-Member -MemberType NoteProperty -Name "games" -Value ([PSCustomObject]@{})
        }

        # Generate new unique game ID
        $newGameId = New-UniqueConfigId -Collection $script:ConfigData.games -Prefix "duplicated"

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

        # Show success message
        Show-DuplicateResult -OriginalId $selectedGame -NewId $newGameId -ItemType "Game" -Success $true

    } catch {
        Show-DuplicateResult -OriginalId $selectedGame -NewId "" -ItemType "Game" -Success $false -ErrorMessage $_.Exception.Message
    }
}

# Handle delete game
function Handle-DeleteGame {
    param()

    $gamesList = $script:Window.FindName("GamesList")
    $selectedGame = $gamesList.SelectedItem

    if ($selectedGame) {
        $result = Show-SafeMessage -MessageKey "deleteGameConfirm" -TitleKey "confirmation" -Arguments @($selectedGame) -Button YesNo -Icon Question
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

    # Ensure managedApps section exists
    if (-not $script:ConfigData.managedApps) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "managedApps" -Value ([PSCustomObject]@{})
    }

    # Generate unique app ID
    $newAppId = New-UniqueConfigId -Collection $script:ConfigData.managedApps -Prefix "newApp"

    # Add to config data
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

# Handle duplicate app
<#
.SYNOPSIS
    Duplicates the currently selected managed app with all its settings except the App ID

.DESCRIPTION
    Creates a copy of the selected managed app with a new unique App ID while preserving
    all other configuration data including path, process name, actions, arguments,
    and termination settings. Provides user feedback on success or failure.
#>
function Handle-DuplicateApp {
    param()

    try {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem
        $sourceAppData = if ($selectedApp) { $script:ConfigData.managedApps.$selectedApp } else { $null }

        # Validate selection and source data
        if (-not (Test-DuplicateSource -SelectedItem $selectedApp -SourceData $sourceAppData -ItemType "App")) {
            return
        }

        # Ensure managedApps section exists
        if (-not $script:ConfigData.managedApps) {
            $script:ConfigData | Add-Member -MemberType NoteProperty -Name "managedApps" -Value ([PSCustomObject]@{})
        }

        # Generate new unique app ID
        $newAppId = New-UniqueConfigId -Collection $script:ConfigData.managedApps -Prefix "duplicated"

        # Create a deep copy of the source app data
        $duplicatedAppData = [PSCustomObject]@{
            path              = $sourceAppData.path
            processName       = $sourceAppData.processName
            gameStartAction   = if ($sourceAppData.gameStartAction) { $sourceAppData.gameStartAction } else { "none" }
            gameEndAction     = if ($sourceAppData.gameEndAction) { $sourceAppData.gameEndAction } else { "none" }
            arguments         = if ($sourceAppData.arguments) { $sourceAppData.arguments } else { "" }
            terminationMethod = if ($sourceAppData.terminationMethod) { $sourceAppData.terminationMethod } else { "auto" }
            gracefulTimeoutMs = if ($sourceAppData.gracefulTimeoutMs) { $sourceAppData.gracefulTimeoutMs } else { 3000 }
        }

        # Add the duplicated app to config data
        $script:ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name $newAppId -Value $duplicatedAppData

        # Update all relevant lists and UI components
        Update-ManagedAppsList
        Update-AppsToManagePanel  # Update Game Settings tab checkboxes

        # Select the newly duplicated app
        $managedAppsList.SelectedItem = $newAppId

        # Update action combo boxes for the duplicated app
        Update-ActionComboBoxes -AppId $newAppId -ExecutablePath $duplicatedAppData.path

        # Show success message
        Show-DuplicateResult -OriginalId $selectedApp -NewId $newAppId -ItemType "App" -Success $true

    } catch {
        Show-DuplicateResult -OriginalId $selectedApp -NewId "" -ItemType "App" -Success $false -ErrorMessage $_.Exception.Message
    }
}

# Handle delete app
function Handle-DeleteApp {
    param()

    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $selectedApp = $managedAppsList.SelectedItem

    if ($selectedApp) {
        $result = Show-SafeMessage -MessageKey "deleteAppConfirm" -TitleKey "confirmation" -Arguments @($selectedApp) -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:ConfigData.managedApps.PSObject.Properties.Remove($selectedApp)

            # Clear current app ID if the deleted app was selected
            if ($script:CurrentAppId -eq $selectedApp) {
                $script:CurrentAppId = ""
            }

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
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
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

        # Save current app if selected and valid
        if ($script:CurrentAppId -and $script:CurrentAppId -ne "") {
            # Check if the app ID still exists in the TextBox (it might have been cleared during deletion)
            $appIdTextBox = $script:Window.FindName("AppIdTextBox")
            if ($appIdTextBox -and $appIdTextBox.Text -and $appIdTextBox.Text -ne "") {
                Write-Verbose "Debug: Saving current app data for ID: $script:CurrentAppId"
                Save-CurrentAppData
            } else {
                Write-Verbose "Debug: Skipping app data save - App ID TextBox is empty (likely after deletion)"
                $script:CurrentAppId = ""
            }
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
        0 { "" }         # Auto (System Language)
        1 { "zh-CN" }    # 简体中文
        2 { "ja" }       # 日本語
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

# Initialize launcher tab texts
function Initialize-LauncherTabTexts {
    param()

    try {
        # Initialize launcher welcome and subtitle texts
        $launcherWelcomeText = $script:Window.FindName("LauncherWelcomeText")
        if ($launcherWelcomeText) {
            $launcherWelcomeText.Text = Get-LocalizedMessage -Key "launcherWelcomeText"
        }

        $launcherSubtitleText = $script:Window.FindName("LauncherSubtitleText")
        if ($launcherSubtitleText) {
            $launcherSubtitleText.Text = Get-LocalizedMessage -Key "launcherSubtitleText"
        }

        # Initialize launcher status text (this will be updated by Update-GameLauncherList)
        $launcherStatusText = $script:Window.FindName("LauncherStatusText")
        if ($launcherStatusText) {
            $launcherStatusText.Text = Get-LocalizedMessage -Key "readyToLaunch"
        }

        # Initialize launcher hint text
        $launcherHintText = $script:Window.FindName("LauncherHintText")
        if ($launcherHintText) {
            $launcherHintText.Text = Get-LocalizedMessage -Key "launcherHintText"
        }

        Write-Verbose "Launcher tab texts initialized"
    } catch {
        Write-Warning "Failed to initialize launcher tab texts: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Updates the game launcher list with configured games

.DESCRIPTION
    Refreshes the game launcher tab with current game configurations,
    creating interactive game cards for each configured game.
#>
function Update-GameLauncherList {
    param()

    try {
        # Update launcher status
        $statusText = $script:Window.FindName("LauncherStatusText")
        if ($statusText) {
            $statusText.Text = Get-LocalizedMessage -Key "refreshingGameList"
        }

        $gameLauncherList = $script:Window.FindName("GameLauncherList")
        if (-not $gameLauncherList) {
            Write-Warning "GameLauncherList control not found"
            if ($statusText) {
                $statusText.Text = Get-LocalizedMessage -Key "gameListError"
            }
            return
        }

        # Clear existing items
        $gameLauncherList.Items.Clear()

        # Check if games are configured
        if (-not $script:ConfigData.games -or $script:ConfigData.games.PSObject.Properties.Count -eq 0) {
            # Show "no games" message
            $noGamesPanel = New-Object System.Windows.Controls.StackPanel
            $noGamesPanel.HorizontalAlignment = "Center"
            $noGamesPanel.VerticalAlignment = "Center"
            $noGamesPanel.Margin = "20"

            $noGamesText = New-Object System.Windows.Controls.TextBlock
            $noGamesText.Text = Get-LocalizedMessage -Key "noGamesConfigured"
            $noGamesText.FontSize = 16
            $noGamesText.Foreground = "#666"
            $noGamesText.HorizontalAlignment = "Center"

            $noGamesPanel.Children.Add($noGamesText)
            $gameLauncherList.Items.Add($noGamesPanel)

            # Update status text for no games
            if ($statusText) {
                $statusText.Text = Get-LocalizedMessage -Key "noGamesFound"
            }
            return
        }

        # Create game cards for each configured game
        $gameCount = 0
        $script:ConfigData.games.PSObject.Properties | ForEach-Object {
            $gameId = $_.Name
            $gameData = $_.Value
            $platform = if ($gameData.platform) { $gameData.platform } else { "steam" }

            Write-Verbose "Creating game card for: $gameId (Name: $($gameData.name), Platform: $platform)"

            # Create game item data object
            $gameItem = New-Object PSObject -Property @{
                GameId      = $gameId
                DisplayName = $gameData.name
                Platform    = $platform.ToUpper()
                ProcessName = $gameData.processName
            }

            # Create the UI element for this game inline to avoid output capture issues
            try {
                # Create main border
                $border = New-Object System.Windows.Controls.Border
                $border.Background = "#F8F9FA"
                $border.BorderBrush = "#E1E5E9"
                $border.BorderThickness = 1
                $border.CornerRadius = 8
                $border.Margin = "0,0,0,10"
                $border.Padding = 15

                # Add hover effect to game card
                $border.add_MouseEnter({
                        $this.Background = "#F1F3F5"
                        $this.BorderBrush = "#D1D9E0"
                    })
                $border.add_MouseLeave({
                        $this.Background = "#F8F9FA"
                        $this.BorderBrush = "#E1E5E9"
                    })

                # Create main grid
                $grid = New-Object System.Windows.Controls.Grid

                # Define columns
                $col1 = New-Object System.Windows.Controls.ColumnDefinition
                $col1.Width = "*"
                $col2 = New-Object System.Windows.Controls.ColumnDefinition
                $col2.Width = "Auto"
                $col3 = New-Object System.Windows.Controls.ColumnDefinition
                $col3.Width = "Auto"

                $grid.ColumnDefinitions.Add($col1)
                $grid.ColumnDefinitions.Add($col2)
                $grid.ColumnDefinitions.Add($col3)

                # Game info section
                $infoPanel = New-Object System.Windows.Controls.StackPanel
                $infoPanel.VerticalAlignment = "Center"
                [System.Windows.Controls.Grid]::SetColumn($infoPanel, 0)

                # Game name
                $nameText = New-Object System.Windows.Controls.TextBlock
                $nameText.Text = $gameItem.DisplayName
                $nameText.FontSize = 14
                $nameText.FontWeight = "SemiBold"
                $nameText.Foreground = "#333"
                $infoPanel.Children.Add($nameText)

                # Game details
                $detailsPanel = New-Object System.Windows.Controls.StackPanel
                $detailsPanel.Orientation = "Horizontal"
                $detailsPanel.Margin = "0,4,0,0"

                $platformLabel = New-Object System.Windows.Controls.TextBlock
                $platformLabel.Text = "Platform: "
                $platformLabel.FontSize = 11
                $platformLabel.Foreground = "#666"
                $detailsPanel.Children.Add($platformLabel)

                $platformValue = New-Object System.Windows.Controls.TextBlock
                $platformValue.Text = $gameItem.Platform
                $platformValue.FontSize = 11
                $platformValue.Foreground = "#0078D4"
                $platformValue.FontWeight = "SemiBold"
                $detailsPanel.Children.Add($platformValue)

                $idLabel = New-Object System.Windows.Controls.TextBlock
                $idLabel.Text = " | ID: "
                $idLabel.FontSize = 11
                $idLabel.Foreground = "#666"
                $idLabel.Margin = "10,0,0,0"
                $detailsPanel.Children.Add($idLabel)

                $idValue = New-Object System.Windows.Controls.TextBlock
                $idValue.Text = $gameItem.GameId
                $idValue.FontSize = 11
                $idValue.Foreground = "#666"
                $idValue.FontFamily = "Consolas"
                $detailsPanel.Children.Add($idValue)

                $infoPanel.Children.Add($detailsPanel)
                $grid.Children.Add($infoPanel)

                # Edit button
                $editButton = New-Object System.Windows.Controls.Button
                $editButton.Content = Get-LocalizedMessage -Key "editButton"
                $editButton.Width = 70
                $editButton.Height = 32
                $editButton.Margin = "10,0"
                $editButton.Background = "#F1F3F4"
                $editButton.BorderBrush = "#D0D7DE"
                $editButton.FontSize = 11
                $editButton.Cursor = "Hand"
                [System.Windows.Controls.Grid]::SetColumn($editButton, 1)

                # Add hover effects to edit button
                $editButton.add_MouseEnter({
                        $this.Background = "#E8EAED"
                        $this.BorderBrush = "#C1C8CD"
                    })
                $editButton.add_MouseLeave({
                        $this.Background = "#F1F3F4"
                        $this.BorderBrush = "#D0D7DE"
                    })

                # Edit button click handler
                $editButton.add_Click({
                        Switch-ToGameSettingsTab -GameId $gameId
                    }.GetNewClosure())

                $grid.Children.Add($editButton)

                # Launch button
                $launchButton = New-Object System.Windows.Controls.Button
                $launchButton.Content = Get-LocalizedMessage -Key "launchButton"
                $launchButton.Width = 80
                $launchButton.Height = 32
                $launchButton.Background = "#0078D4"
                $launchButton.Foreground = "White"
                $launchButton.BorderBrush = "#0078D4"
                $launchButton.FontWeight = "SemiBold"
                $launchButton.FontSize = 12
                $launchButton.Cursor = "Hand"
                [System.Windows.Controls.Grid]::SetColumn($launchButton, 2)

                # Add hover effects to launch button
                $launchButton.add_MouseEnter({
                        $this.Background = "#106EBE"
                        $this.BorderBrush = "#106EBE"
                    })
                $launchButton.add_MouseLeave({
                        $this.Background = "#0078D4"
                        $this.BorderBrush = "#0078D4"
                    })

                # Launch button click handler
                $launchButton.add_Click({
                        Start-GameFromLauncher -GameId $gameId
                    }.GetNewClosure())

                $grid.Children.Add($launchButton)

                $border.Child = $grid

                # Add the border directly to ItemsControl
                Write-Verbose "Game card created successfully for: $gameId"
                Write-Verbose "Game card type: $($border.GetType().FullName)"
                $gameLauncherList.Items.Add($border)
                $gameCount++
                Write-Verbose "Game card added to list. Total items in ItemsControl: $($gameLauncherList.Items.Count)"

            } catch {
                Write-Warning "Failed to create game card for: $gameId - $($_.Exception.Message)"
            }
        }

        # Update status text with game count
        if ($statusText) {
            if ($gameCount -eq 1) {
                $statusText.Text = Get-LocalizedMessage -Key "oneGameReady"
            } else {
                $statusText.Text = Get-LocalizedMessage -Key "multipleGamesReady" -Arguments @($gameCount.ToString())
            }
        }

        Write-Verbose "Game launcher list updated with $gameCount games"

    } catch {
        Write-Warning "Failed to update game launcher list: $($_.Exception.Message)"
        $statusText = $script:Window.FindName("LauncherStatusText")
        if ($statusText) {
            $statusText.Text = Get-LocalizedMessage -Key "gameListUpdateError"
        }
    }
}

<#
.SYNOPSIS
    Creates a game launcher card UI element

.DESCRIPTION
    Creates an interactive game card with launch and edit buttons
    for the game launcher tab interface.
#>

<#
.SYNOPSIS
    Switches to the Game Settings tab for editing

.DESCRIPTION
    Switches to the Games tab and optionally selects a specific game
    for editing in the configuration interface.
#>
function Switch-ToGameSettingsTab {
    param(
        [string]$GameId = ""
    )

    try {
        $mainTabControl = $script:Window.FindName("MainTabControl")
        $gamesTab = $script:Window.FindName("GamesTab")

        if ($mainTabControl -and $gamesTab) {
            $mainTabControl.SelectedItem = $gamesTab

            # If GameId specified, select that game
            if (-not [string]::IsNullOrEmpty($GameId)) {
                # Use dispatcher to ensure UI is updated after tab switch
                $script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action] {
                        $gamesList = $script:Window.FindName("GamesList")
                        if ($gamesList) {
                            # First ensure the games list is updated
                            Update-GamesList

                            # Find and select the game
                            for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
                                if ($gamesList.Items[$i] -eq $GameId) {
                                    $gamesList.SelectedIndex = $i
                                    break
                                }
                            }

                            # Ensure focus on the selected game
                            if ($gamesList.SelectedItem -eq $GameId) {
                                Write-Verbose "Game '$GameId' selected in Games tab"
                            }
                        }
                    })
            }
        }

    } catch {
        Write-Warning "Failed to switch to game settings tab: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Handles adding a new game from the launcher tab

.DESCRIPTION
    Switches to the Games tab and initiates the process of adding
    a new game configuration.
#>
function Handle-AddNewGameFromLauncher {
    param()

    try {
        # Switch to Games tab
        Switch-ToGameSettingsTab

        # Add new game
        Handle-AddGame

    } catch {
        Write-Warning "Failed to add new game from launcher: $($_.Exception.Message)"
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
            $message = Get-LocalizedMessage -Key "updateAvailable" -Arguments @($updateResult.LatestVersion, $updateResult.CurrentVersion)
            if ($updateStatusText) {
                $updateStatusText.Text = $message
                $updateStatusText.Foreground = "#FF6600"
            }

            # Ask user if they want to open the releases page
            $result = Show-SafeMessage -MessageKey "updateAvailableConfirm" -TitleKey "updateAvailableTitle" -Arguments @($updateResult.LatestVersion) -Button YesNo -Icon Question
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
            $continueRestart = Show-SafeMessage -MessageKey "continueRestartConfirm" -TitleKey "saveBeforeRestartErrorTitle" -Button YesNo -Icon Warning

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

# Global variable to track changes
$script:HasUnsavedChanges = $false
$script:OriginalConfigData = $null

# Mark configuration as modified
function Set-ConfigModified {
    param([bool]$IsModified = $true)

    try {
        # Initialize the variable if it doesn't exist
        if (-not (Get-Variable -Name "HasUnsavedChanges" -Scope Script -ErrorAction SilentlyContinue)) {
            $script:HasUnsavedChanges = $false
        }

        $script:HasUnsavedChanges = $IsModified

        # Update window title to show unsaved changes
        if ($script:Window) {
            try {
                $baseTitle = Get-LocalizedMessage -Key "windowTitle"
                if ($IsModified) {
                    $script:Window.Title = "$baseTitle *"
                } else {
                    $script:Window.Title = $baseTitle
                }
            } catch {
                Write-Verbose "Warning: Failed to update window title: $($_.Exception.Message)"
                # Fallback title
                if ($IsModified) {
                    $script:Window.Title = "Focus Game Deck Configuration *"
                } else {
                    $script:Window.Title = "Focus Game Deck Configuration"
                }
            }
        }
    } catch {
        Write-Verbose "Warning: Error in Set-ConfigModified: $($_.Exception.Message)"
        # Don't throw - this should not cause initialization to fail
    }
}

# Check if there are unsaved changes
function Test-HasUnsavedChanges {
    try {
        # Initialize the variable if it doesn't exist
        if (-not (Get-Variable -Name "HasUnsavedChanges" -Scope Script -ErrorAction SilentlyContinue)) {
            $script:HasUnsavedChanges = $false
        }
        return $script:HasUnsavedChanges
    } catch {
        Write-Verbose "Warning: Error in Test-HasUnsavedChanges: $($_.Exception.Message)"
        return $false  # Default to no unsaved changes if there's an error
    }
}

# Store original configuration for comparison
function Save-OriginalConfig {
    try {
        if ($script:ConfigData) {
            $script:OriginalConfigData = $script:ConfigData | ConvertTo-Json -Depth 10
            Write-Verbose "Original configuration saved for change tracking"
        } else {
            Write-Verbose "No configuration data to save for change tracking"
            $script:OriginalConfigData = $null
        }
    } catch {
        Write-Warning "Failed to save original configuration: $($_.Exception.Message)"
        $script:OriginalConfigData = $null
        # Don't throw - this should not cause initialization to fail
    }
}

# Handle Apply button - save changes but keep window open
function Handle-ApplyConfig {
    param()

    try {
        # Save current UI data back to config object
        Save-UIDataToConfig

        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

        # Update original config data and mark as not modified
        Save-OriginalConfig
        Set-ConfigModified -IsModified $false

        # After successful save, refresh all UI lists to ensure consistency
        Update-ManagedAppsList
        Update-GamesList
        Update-AppsToManagePanel

        # If a game is currently selected, update its Apps to Manage checkboxes
        if ($script:CurrentGameId) {
            Handle-GameSelectionChanged
        }

        Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"
        Write-Verbose "Configuration applied successfully"

    } catch {
        Write-Host "Debug: Apply config error - $($_.Exception.Message)" -ForegroundColor Red
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
    }
}

# Handle OK button - save changes and close window
function Handle-OKConfig {
    param()

    try {
        # Save current UI data back to config object
        Save-UIDataToConfig

        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

        # Update original config data and mark as not modified
        Save-OriginalConfig
        Set-ConfigModified -IsModified $false

        Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"
        Write-Verbose "Configuration saved successfully"

        # Close window
        $script:Window.Close()

    } catch {
        Write-Host "Debug: OK config error - $($_.Exception.Message)" -ForegroundColor Red
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
    }
}

# Handle Cancel button - discard unsaved changes and close window
function Handle-CancelConfig {
    param()

    if (Test-HasUnsavedChanges) {
        # Ask user to confirm discarding changes
        $result = Show-SafeMessage -MessageKey "discardChangesConfirm" -TitleKey "confirmation" -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            # Discard changes and close
            Set-ConfigModified -IsModified $false
            $script:Window.Close()
        }
        # If No, don't close the window
    } else {
        # No unsaved changes, just close
        $script:Window.Close()
    }
}

# Handle window closing event (×ボタン)
function Handle-WindowClosing {
    param($Event)

    if (Test-HasUnsavedChanges) {
        # Ask user to confirm discarding changes
        $result = Show-SafeMessage -MessageKey "discardChangesConfirm" -TitleKey "confirmation" -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::No) {
            # Cancel the close operation
            $Event.Cancel = $true
            return
        }
    }

    # Allow window to close
    Set-ConfigModified -IsModified $false
}

# Tab-specific Save button handlers

# Handle Game Settings tab Save button
function Handle-SaveGameSettings {
    param()

    try {
        # Save only the game settings data
        if ($script:CurrentGameId -and $script:CurrentGameId -ne "") {
            Save-CurrentGameData
        }

        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

        # Refresh games list to ensure consistency
        Update-GamesList
        Update-AppsToManagePanel

        # If a game is currently selected, refresh its data
        if ($script:CurrentGameId) {
            Handle-GameSelectionChanged
        }

        Show-SafeMessage -MessageKey "gameSettingsSaved" -TitleKey "info"
        Write-Verbose "Game settings saved successfully"

    } catch {
        Write-Host "Debug: Save game settings error - $($_.Exception.Message)" -ForegroundColor Red
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
    }
}

# Handle Managed Apps tab Save button
function Handle-SaveManagedApps {
    param()

    try {
        # Save only the managed apps data
        if ($script:CurrentAppId -and $script:CurrentAppId -ne "") {
            # Check if the app ID still exists in the TextBox (it might have been cleared during deletion)
            $appIdTextBox = $script:Window.FindName("AppIdTextBox")
            if ($appIdTextBox -and $appIdTextBox.Text -and $appIdTextBox.Text -ne "") {
                Save-CurrentAppData
            }
        }

        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

        # Refresh managed apps list to ensure consistency
        Update-ManagedAppsList
        Update-AppsToManagePanel

        # If an app is currently selected, refresh its data
        if ($script:CurrentAppId) {
            Handle-AppSelectionChanged
        }

        Show-SafeMessage -MessageKey "managedAppsSettingsSaved" -TitleKey "info"
        Write-Verbose "Managed apps settings saved successfully"

    } catch {
        Write-Host "Debug: Save managed apps settings error - $($_.Exception.Message)" -ForegroundColor Red
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
    }
}

# Handle Global Settings tab Save button
function Handle-SaveGlobalSettings {
    param()

    try {
        # Save only the global settings data
        Save-GlobalSettingsData

        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8

        Show-SafeMessage -MessageKey "globalSettingsSaved" -TitleKey "info"
        Write-Verbose "Global settings saved successfully"

    } catch {
        Write-Host "Debug: Save global settings error - $($_.Exception.Message)" -ForegroundColor Red
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
    }
}

# Handle About menu item
function Handle-About {
    param()

    try {
        Write-Host "=== Handle-About DEBUG START ===" -ForegroundColor Cyan

        # Get version information
        $versionInfo = Get-ProjectVersionInfo
        Write-Host "Debug: About dialog - versionInfo type: $($versionInfo.GetType().Name)" -ForegroundColor Yellow
        Write-Host "Debug: About dialog - versionInfo.FullVersion: '$($versionInfo.FullVersion)'" -ForegroundColor Yellow

        # Create args array and verify its contents
        $argsArray = @($versionInfo.FullVersion)
        Write-Host "Debug: About dialog - Args array length: $($argsArray.Length)" -ForegroundColor Yellow
        Write-Host "Debug: About dialog - Args[0]: '$($argsArray[0])'" -ForegroundColor Yellow
        Write-Host "Debug: About dialog - Args[0] type: $($argsArray[0].GetType().Name)" -ForegroundColor Yellow

        # Test message retrieval with verbose output
        Write-Host "Debug: Testing Get-LocalizedMessage directly..." -ForegroundColor Green
        $testMessage = Get-LocalizedMessage -Key "aboutMessage" -Args $argsArray
        Write-Host "Debug: Direct call result: '$testMessage'" -ForegroundColor Green

        Write-Host "Debug: Calling Show-SafeMessage..." -ForegroundColor Magenta
        Show-SafeMessage -MessageKey "aboutMessage" -TitleKey "aboutTitle" -Arguments $argsArray

        Write-Host "=== Handle-About DEBUG END ===" -ForegroundColor Cyan

    } catch {
        Write-Warning "Failed to show about dialog: $($_.Exception.Message)"
        Write-Warning "Exception details: $($_.Exception)"
        $fallbackVersion = if ($versionInfo) { $versionInfo.FullVersion } else { "Unknown" }
        [System.Windows.MessageBox]::Show("Focus Game Deck`nVersion: $fallbackVersion", "About", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
}

# Handle close window (legacy function for backward compatibility)
function Handle-CloseWindow {
    param()

    Handle-CancelConfig
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
        # Get UI elements (Use Global Settings tab LauncherTypeCombo for generating launchers)
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
            $scriptPath = Join-Path $rootDir "scripts/Create-Launchers-Enhanced.ps1"
        } else {
            $scriptPath = Join-Path $rootDir "scripts/Create-Launchers.ps1"
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

        # Run the script and capture both success and error output
        try {
            $scriptOutput = & $scriptPath -NoInteractive 2>&1
            $scriptExitCode = $LASTEXITCODE

            Write-Verbose "Script execution completed with exit code: $scriptExitCode"

            # Process output for display
            if ($scriptOutput) {
                $output = $scriptOutput -join "`n"
                Write-Verbose "Script output: $output"
            } else {
                $output = ""
            }
        } catch {
            Write-Error "Failed to execute launcher script: $($_.Exception.Message)"
            Show-SafeMessage -MessageKey "launcherCreationError" -TitleKey "error" -Icon Error
            return
        }

        # Check if launchers were created successfully
        $launcherPattern = if ($launcherType -eq "lnk") { "launch_*.lnk" } else { "launch_*.bat" }
        $createdLaunchers = Get-ChildItem -Path $rootDir -Filter $launcherPattern -ErrorAction SilentlyContinue

        if ($createdLaunchers -and $createdLaunchers.Count -gt 0) {
            $messageKey = if ($launcherType -eq "lnk") { "launchersCreatedEnhanced" } else { "launchersCreatedTraditional" }

            Show-SafeMessage -MessageKey $messageKey -TitleKey "success" -Arguments @($createdLaunchers.Count.ToString()) -Icon Information

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

# Start the application only if not suppressed
if (-not $NoAutoStart) {
    if (Test-Prerequisites) {
        Initialize-ConfigEditor
    } else {
        Write-Host "Cannot start ConfigEditor due to missing prerequisites" -ForegroundColor Red
        exit 1
    }
}
