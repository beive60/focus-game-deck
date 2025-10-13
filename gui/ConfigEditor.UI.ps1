# Import mappings at the top of the file
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MappingsPath = Join-Path $ProjectRoot "gui/ConfigEditor.Mappings.ps1"

. $MappingsPath

class ConfigEditorUI {
    # Properties
    [ConfigEditorState]$State
    [System.Windows.Window]$Window
    [string]$CurrentGameId
    [string]$CurrentAppId
    [PSObject]$Messages
    [string]$CurrentLanguage
    [bool]$HasUnsavedChanges

    # Constructor
    ConfigEditorUI([ConfigEditorState]$stateManager) {
        try {
            Write-Host "DEBUG: ConfigEditorUI constructor started" -ForegroundColor Cyan
            $this.State = $stateManager
            Write-Host "DEBUG: State manager assigned successfully" -ForegroundColor Cyan

            # Load XAML
            Write-Host "DEBUG: Loading XAML file..." -ForegroundColor Cyan
            $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
            Write-Host "DEBUG: XAML path: $xamlPath" -ForegroundColor Cyan

            if (-not (Test-Path $xamlPath)) {
                throw "XAML file not found: $xamlPath"
            }
            Write-Host "DEBUG: XAML file exists" -ForegroundColor Cyan

            $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
            Write-Host "DEBUG: XAML content loaded, length: $($xamlContent.Length)" -ForegroundColor Cyan

            # Parse XAML
            Write-Host "DEBUG: Parsing XAML..." -ForegroundColor Cyan
            $xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
            $this.Window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
            $xmlReader.Close()  # Properly close the XML reader
            Write-Host "DEBUG: XAML parsed successfully" -ForegroundColor Cyan

            if ($null -eq $this.Window) {
                throw "Failed to create Window from XAML"
            }
            Write-Host "DEBUG: Window created successfully, type: $($this.Window.GetType().Name)" -ForegroundColor Cyan

            # Set up proper window closing behavior
            $this.Window.add_Closed({
                param($sender, $e)
                Write-Host "DEBUG: Window closed event triggered" -ForegroundColor Yellow
                try {
                    # Clean up resources
                    $this.Cleanup()
                } catch {
                    Write-Warning "Error during cleanup: $($_.Exception.Message)"
                }
            })

            # Initialize other components
            $this.InitializeComponents()
            Write-Host "DEBUG: ConfigEditorUI constructor completed successfully" -ForegroundColor Cyan

        } catch {
            Write-Host "DEBUG: ConfigEditorUI constructor failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "DEBUG: Exception type: $($_.Exception.GetType().Name)" -ForegroundColor Red
            if ($_.Exception.InnerException) {
                Write-Host "DEBUG: Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }
            Write-Host "DEBUG: Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
            throw
        }
    }

    <#
    .SYNOPSIS
        Initializes UI components and sets default values.

    .DESCRIPTION
        Initializes properties, localization, and window data context for the ConfigEditor UI.
        Sets up fallback values for localization if initialization fails.

    .OUTPUTS
        None
    #>
    [void]InitializeComponents() {
        try {
            Write-Host "DEBUG: InitializeComponents started" -ForegroundColor Cyan

            # Initialize properties
            $this.CurrentGameId = ""
            $this.CurrentAppId = ""
            $this.CurrentLanguage = "en"
            $this.HasUnsavedChanges = $false

            # Initialize messages - simplified initialization
            Write-Host "DEBUG: Initializing localization..." -ForegroundColor Cyan
            try {
                # Initialize with empty message object (fallback)
                $this.Messages = @{}
                Write-Host "DEBUG: Messages initialized with empty fallback" -ForegroundColor Cyan
            } catch {
                Write-Host "DEBUG: Localization initialization failed: $($_.Exception.Message)" -ForegroundColor Red
                $this.Messages = @{}  # Fallback
            }

            # Initialize Window properties
            $this.Window.DataContext = $this

            Write-Host "DEBUG: InitializeComponents completed" -ForegroundColor Cyan
        } catch {
            Write-Host "DEBUG: InitializeComponents failed: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    <#
    .SYNOPSIS
        Gets a localized message for the specified key.

    .DESCRIPTION
        Retrieves a localized message from the messages collection or falls back to using the localization service.

    .PARAMETER Key
        The message key to retrieve.

    .OUTPUTS
        String
            Returns the localized message string, or the key itself if no message is found.
    #>
    [string]GetLocalizedMessage([string]$Key) {
        try {
            # First try to get from cached messages
            if ($this.Messages -and $this.Messages.ContainsKey($Key)) {
                return $this.Messages[$Key]
            }

            # Fallback: try to get from localization service directly - but prevent recursion
            try {
                # Use a static flag to prevent infinite recursion
                if (-not $script:LocalizationInProgress) {
                    $script:LocalizationInProgress = $true

                    $localization = [ConfigEditorLocalization]::new()
                    if ($localization | Get-Member -Name "GetMessage" -MemberType Method) {
                        $message = $localization.GetMessage($Key)
                        $script:LocalizationInProgress = $false
                        return $message
                    }

                    $script:LocalizationInProgress = $false
                }
            } catch {
                $script:LocalizationInProgress = $false
                Write-Verbose "Failed to get message from localization service: $($_.Exception.Message)"
            }

            # Final fallback: return the key itself
            Write-Verbose "No localized message found for key: $Key"
            return $Key
        } catch {
            $script:LocalizationInProgress = $false
            Write-Verbose "Error getting localized message for key '$Key': $($_.Exception.Message)"
            return $Key
        }
    }

    <#
    .SYNOPSIS
        Measures the text width for a button.

    .DESCRIPTION
        Creates a temporary TextBlock to measure the actual rendered width of text for a button,
        considering font properties and adding padding.

    .PARAMETER Text
        The text to measure.

    .PARAMETER Button
        The button whose font properties to use for measurement.

    .OUTPUTS
        Double
            Returns the estimated width in pixels, including padding.
    #>
    [double]MeasureButtonTextWidth([string]$Text, [System.Windows.Controls.Button]$Button) {
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

    <#
    .SYNOPSIS
        Gets a mapping variable from script scope.

    .DESCRIPTION
        Helper method to safely retrieve mapping variables from script scope since
        class methods cannot directly access global variables.

    .PARAMETER MappingName
        The name of the mapping variable to retrieve.

    .OUTPUTS
        Hashtable
            Returns the mapping hashtable or empty hashtable if not found.
    #>
    [hashtable]GetMappingFromScope([string]$MappingName) {
        try {
            $mapping = Get-Variable -Name $MappingName -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if ($mapping -and $mapping -is [hashtable]) {
                return $mapping
            }
            return @{}
        } catch {
            Write-Verbose "Failed to get mapping '$MappingName': $($_.Exception.Message)"
            return @{}
        }
    }

    <#
    .SYNOPSIS
        Sets button content with smart tooltip based on text width.

    .DESCRIPTION
        Sets the button content and intelligently determines whether a tooltip is needed
        based on the text width compared to available button space.

    .PARAMETER Button
        The button to update.

    .PARAMETER FullText
        The full text to display and potentially use as tooltip.

    .OUTPUTS
        None
    #>
    [void]SetButtonContentWithTooltip([System.Windows.Controls.Button]$Button, [string]$FullText) {
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
            $textWidth = $this.MeasureButtonTextWidth($FullText, $Button)

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
            Write-Warning "Debug: Error in SetButtonContentWithTooltip for '$($Button.Name)': $($_.Exception.Message)"
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

    <#
    .SYNOPSIS
        Updates tooltips for a specific category of buttons.

    .DESCRIPTION
        Updates button tooltips for buttons in a specific functional category, allowing for more granular control.

    .PARAMETER CategoryName
        The name of the button category for logging purposes.

    .PARAMETER CategoryMappings
        The hashtable containing the button mappings for this category.

    .OUTPUTS
        None
    #>
    [void]UpdateButtonCategory([string]$CategoryName, [hashtable]$CategoryMappings) {
        try {
            Write-Verbose "Debug: Updating $CategoryName buttons ($($CategoryMappings.Count) buttons)"

            foreach ($buttonName in $CategoryMappings.Keys) {
                $button = $this.Window.FindName($buttonName)
                if ($button) {
                    $messageKey = $CategoryMappings[$buttonName]
                    $fullText = $this.GetLocalizedMessage($messageKey)
                    Write-Verbose "Debug: Processing $CategoryName button '$buttonName' with key '$messageKey' -> text '$fullText'"
                    $this.SetButtonContentWithTooltip($button, $fullText)
                } else {
                    Write-Verbose "Debug: $CategoryName button '$buttonName' not found in window"
                }
            }
        } catch {
            Write-Warning "Failed to update $CategoryName button category: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates smart tooltips for all buttons using categorized mappings.

    .DESCRIPTION
        Applies smart tooltips to all buttons organized by functional categories from the mappings file.
        Uses categorized approach for better maintainability and targeted updates.

    .OUTPUTS
        None
    #>
    [void]UpdateAllButtonTooltips() {
        try {
            Write-Verbose "Debug: Starting categorized tooltip update"

            # Get mappings using helper method
            $crudMappings = $this.GetMappingFromScope("CrudButtonMappings")
            $browserMappings = $this.GetMappingFromScope("BrowserButtonMappings")
            $autoDetectMappings = $this.GetMappingFromScope("AutoDetectButtonMappings")
            $actionMappings = $this.GetMappingFromScope("ActionButtonMappings")
            $movementMappings = $this.GetMappingFromScope("MovementButtonMappings")

            # Update different button categories using imported mappings
            if ($crudMappings.Count -gt 0) { $this.UpdateButtonCategory("Crud", $crudMappings) }
            if ($browserMappings.Count -gt 0) { $this.UpdateButtonCategory("Browser", $browserMappings) }
            if ($autoDetectMappings.Count -gt 0) { $this.UpdateButtonCategory("AutoDetect", $autoDetectMappings) }
            if ($actionMappings.Count -gt 0) { $this.UpdateButtonCategory("Action", $actionMappings) }
            if ($movementMappings.Count -gt 0) { $this.UpdateButtonCategory("Movement", $movementMappings) }

            Write-Verbose "Debug: Categorized button tooltip update completed"
        } catch {
            Write-Warning "Failed to update button tooltips: $($_.Exception.Message)"
        }
    }    <#
    .SYNOPSIS
        Updates UI texts based on current language using mappings.

    .DESCRIPTION
        Updates all UI text elements (buttons, labels, tabs, etc.) using the centralized mapping system
        for better maintainability and consistency.

    .PARAMETER ConfigData
        The configuration data containing language and other settings.

    .OUTPUTS
        None
    #>
    [void]UpdateUITexts([PSObject]$ConfigData) {
        try {
            # Update window title
            $this.Window.Title = $this.GetLocalizedMessage("windowTitle")

            # Update all button tooltips using the mapping
            $this.UpdateAllButtonTooltips()

            # Update other UI elements using mappings
            $this.UpdateElementsFromMappings()

            Write-Verbose "UI texts updated for language: $($this.CurrentLanguage)"
        } catch {
            Write-Warning "Failed to update UI texts: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates UI elements from centralized mappings.

    .DESCRIPTION
        Updates various UI element types (tabs, labels, checkboxes, etc.) using the mappings
        defined in ConfigEditor.Mappings.ps1 for centralized maintenance.

    .OUTPUTS
        None
    #>
    [void]UpdateElementsFromMappings() {
        try {
            # Update tab headers
            $tabMappings = @{
                "GamesTab"          = "gamesTabHeader"
                "ManagedAppsTab"    = "managedAppsTabHeader"
                "GlobalSettingsTab" = "globalSettingsTabHeader"
            }

            foreach ($elementName in $tabMappings.Keys) {
                $element = $this.Window.FindName($elementName)
                if ($element) {
                    $messageKey = $tabMappings[$elementName]
                    $element.Header = $this.GetLocalizedMessage($messageKey)
                }
            }

            # Update labels using centralized approach
            $this.UpdateLabelsFromMappings()

            # Update group boxes
            $this.UpdateGroupBoxesFromMappings()

            # Update checkboxes
            $this.UpdateCheckBoxesFromMappings()

            # Update text elements
            $this.UpdateTextElementsFromMappings()

            # Update menu items
            $this.UpdateMenuItemsFromMappings()

        } catch {
            Write-Warning "Failed to update elements from mappings: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates label elements from mappings.

    .DESCRIPTION
        Updates all label elements using a centralized mapping approach for consistency.

    .OUTPUTS
        None
    #>
    [void]UpdateLabelsFromMappings() {
        try {
            $labelMappings = @{
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
                "LogRetentionLabel"      = "logRetentionLabel"
                "ExecutablePathLabel"    = "executablePathLabel"
            }

            foreach ($elementName in $labelMappings.Keys) {
                $element = $this.Window.FindName($elementName)
                if ($element) {
                    $messageKey = $labelMappings[$elementName]
                    $element.Content = $this.GetLocalizedMessage($messageKey)
                }
            }
        } catch {
            Write-Warning "Failed to update labels from mappings: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates group box headers from mappings.

    .DESCRIPTION
        Updates group box header text using centralized mappings.

    .OUTPUTS
        None
    #>
    [void]UpdateGroupBoxesFromMappings() {
        try {
            $groupBoxMappings = @{
                "ObsSettingsGroup"     = "obsSettingsGroup"
                "PathSettingsGroup"    = "pathSettingsGroup"
                "GeneralSettingsGroup" = "generalSettingsGroup"
            }

            foreach ($elementName in $groupBoxMappings.Keys) {
                $element = $this.Window.FindName($elementName)
                if ($element) {
                    $messageKey = $groupBoxMappings[$elementName]
                    $element.Header = $this.GetLocalizedMessage($messageKey)
                }
            }
        } catch {
            Write-Warning "Failed to update group boxes from mappings: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates checkbox content from mappings.

    .DESCRIPTION
        Updates checkbox content text using centralized mappings.

    .OUTPUTS
        None
    #>
    [void]UpdateCheckBoxesFromMappings() {
        try {
            $checkBoxMappings = @{
                "ReplayBufferCheckBox"          = "replayBufferLabel"
                "EnableLogNotarizationCheckBox" = "enableLogNotarization"
            }

            foreach ($elementName in $checkBoxMappings.Keys) {
                $element = $this.Window.FindName($elementName)
                if ($element) {
                    $messageKey = $checkBoxMappings[$elementName]
                    $element.Content = $this.GetLocalizedMessage($messageKey)
                }
            }
        } catch {
            Write-Warning "Failed to update checkboxes from mappings: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates text elements from mappings.

    .DESCRIPTION
        Updates TextBlock and other text elements using centralized mappings.

    .OUTPUTS
        None
    #>
    [void]UpdateTextElementsFromMappings() {
        try {
            $textMappings = @{
                "VersionLabel"         = "versionLabel"
                "LauncherWelcomeText"  = "launcherWelcomeText"
                "LauncherSubtitleText" = "launcherSubtitleText"
                "LauncherStatusText"   = "readyToLaunch"
                "LauncherHintText"     = "launcherHintText"
                "LauncherHelpText"     = "launcherHelpText"
            }

            foreach ($elementName in $textMappings.Keys) {
                $element = $this.Window.FindName($elementName)
                if ($element) {
                    $messageKey = $textMappings[$elementName]
                    $element.Text = $this.GetLocalizedMessage($messageKey)
                }
            }
        } catch {
            Write-Warning "Failed to update text elements from mappings: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates menu item headers from mappings.

    .DESCRIPTION
        Updates menu item header text using centralized mappings.

    .OUTPUTS
        None
    #>
    [void]UpdateMenuItemsFromMappings() {
        try {
            $menuItemMappings = $this.GetMappingFromScope("MenuItemMappings")

            Write-Host "DEBUG: MenuItemMappings count: $($menuItemMappings.Count)" -ForegroundColor Cyan

            foreach ($elementName in $menuItemMappings.Keys) {
                $element = $this.Window.FindName($elementName)
                $messageKey = $menuItemMappings[$elementName]
                $localizedText = $this.GetLocalizedMessage($messageKey)

                Write-Host "DEBUG: Processing menu item '$elementName' -> key '$messageKey' -> text '$localizedText'" -ForegroundColor Yellow

                if ($element) {
                    $oldHeader = $element.Header
                    $element.Header = $localizedText
                    Write-Host "DEBUG: Menu item '$elementName' header changed from '$oldHeader' to '$($element.Header)'" -ForegroundColor Green

                    # UI更新を強制
                    $element.UpdateLayout()
                } else {
                    Write-Host "DEBUG: Menu item '$elementName' not found in window" -ForegroundColor Red
                }
            }
        } catch {
            Write-Warning "Failed to update menu items from mappings: $($_.Exception.Message)"
            Write-Host "DEBUG: Exception details: $($_.Exception)" -ForegroundColor Red
        }
    }

    <#
    .SYNOPSIS
        Initializes version display in the UI.

    .DESCRIPTION
        Retrieves project version information and displays it in the version text element.

    .OUTPUTS
        None
    #>
    [void]InitializeVersionDisplay() {
        try {
            $versionInfo = Get-ProjectVersionInfo
            $versionText = $this.Window.FindName("VersionText")
            if ($versionText) {
                $versionText.Text = $versionInfo.FullVersion
            }

            Write-Verbose "Version display initialized: $($versionInfo.FullVersion)"
        } catch {
            Write-Warning "Failed to initialize version display: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Loads configuration data into UI controls.

    .DESCRIPTION
        Loads all configuration data into the appropriate UI controls, including global settings,
        UI texts, and various lists.

    .PARAMETER ConfigData
        The configuration data to load into the UI.

    .OUTPUTS
        None
    #>
    [void]LoadDataToUI([PSObject]$ConfigData) {
        try {
            # Load global settings
            $this.LoadGlobalSettings($ConfigData)

            # Update UI texts
            $this.UpdateUITexts($ConfigData)

            # Update lists
            $this.UpdateGamesList($ConfigData)
            $this.UpdateManagedAppsList($ConfigData)
            $this.UpdateGameLauncherList($ConfigData)

            # Other initialization
            $this.InitializeLauncherTabTexts()
            $this.InitializeVersionDisplay()

            Write-Verbose "Data loaded to UI successfully"
        } catch {
            Write-Error "Failed to load data to UI: $($_.Exception.Message)"
            throw
        }
    }

    <#
    .SYNOPSIS
        Loads global settings into UI controls.

    .DESCRIPTION
        Loads global settings from configuration data into the appropriate UI controls
        using a callback function for better organization.

    .PARAMETER ConfigData
        The configuration data containing global settings.

    .OUTPUTS
        None
    #>
    [void]LoadGlobalSettings([PSObject]$ConfigData) {
        $callback = $this.CreateLoadGlobalSettingsCallback($ConfigData)
        & $callback
    }

    <#
    .SYNOPSIS
        Updates the games list UI control.

    .DESCRIPTION
        Updates the games list control with games from configuration data, respecting the order
        defined in the _order property if available.

    .PARAMETER ConfigData
        The configuration data containing games information.

    .OUTPUTS
        None
    #>
    [void]UpdateGamesList([PSObject]$ConfigData) {
        $gamesList = $this.Window.FindName("GamesList")
        $gamesList.Items.Clear()

        if ($ConfigData.games) {
            # Use games._order for ordering if available
            if ($ConfigData.games._order) {
                foreach ($gameId in $ConfigData.games._order) {
                    # Verify the game still exists in the games object
                    if ($ConfigData.games.PSObject.Properties[$gameId]) {
                        $gamesList.Items.Add($gameId)
                    }
                }
            } else {
                # Fallback to original behavior if _order doesn't exist
                $ConfigData.games.PSObject.Properties | ForEach-Object {
                    if ($_.Name -ne '_order') {
                        $gamesList.Items.Add($_.Name)
                    }
                }
            }

            # Auto-select the first game if games exist - but don't trigger events manually
            if ($gamesList.Items.Count -gt 0) {
                try {
                    $gamesList.SelectedIndex = 0
                    # Let the event handler system handle the selection change
                } catch {
                    Write-Verbose "Failed to set initial game selection: $($_.Exception.Message)"
                }
            }
        }
    }

    <#
    .SYNOPSIS
        Updates the managed apps list UI control.

    .DESCRIPTION
        Updates the managed apps list control with apps from configuration data, respecting the order
        defined in the _order property if available.

    .PARAMETER ConfigData
        The configuration data containing managed apps information.

    .OUTPUTS
        None
    #>
    [void]UpdateManagedAppsList([PSObject]$ConfigData) {
        $managedAppsList = $this.Window.FindName("ManagedAppsList")
        $managedAppsList.Items.Clear()

        if ($ConfigData.managedApps) {
            # Use managedApps._order for ordering if available
            if ($ConfigData.managedApps._order) {
                foreach ($appId in $ConfigData.managedApps._order) {
                    # Verify the app still exists in the managedApps object
                    if ($ConfigData.managedApps.PSObject.Properties[$appId]) {
                        $managedAppsList.Items.Add($appId)
                    }
                }
            } else {
                # Fallback to original behavior if _order doesn't exist
                $ConfigData.managedApps.PSObject.Properties | ForEach-Object {
                    if ($_.Name -ne '_order') {
                        $managedAppsList.Items.Add($_.Name)
                    }
                }
            }

            # Auto-select the first app if apps exist - but don't trigger events manually
            if ($managedAppsList.Items.Count -gt 0) {
                try {
                    $managedAppsList.SelectedIndex = 0
                    # Let the event handler system handle the selection change
                } catch {
                    Write-Verbose "Failed to set initial app selection: $($_.Exception.Message)"
                }
            }
        }
    }

    <#
    .SYNOPSIS
        Updates the game launcher list UI control.

    .DESCRIPTION
        Updates the game launcher list control with games from configuration data,
        creating game cards for the launcher interface.

    .PARAMETER ConfigData
        The configuration data containing games information.

    .OUTPUTS
        None
    #>
    [void]UpdateGameLauncherList([PSObject]$ConfigData) {
        try {
            $gameLauncherList = $this.Window.FindName("GameLauncherList")
            if (-not $gameLauncherList) {
                Write-Warning "GameLauncherList control not found"
                return
            }

            # Clear existing items
            $gameLauncherList.Items.Clear()

            # Check if games are configured
            if (-not $ConfigData.games -or $ConfigData.games.PSObject.Properties.Count -eq 0) {
                # Show "no games" message
                $noGamesPanel = New-Object System.Windows.Controls.StackPanel
                $noGamesPanel.HorizontalAlignment = "Center"
                $noGamesPanel.VerticalAlignment = "Center"
                $noGamesPanel.Margin = "20"

                $noGamesText = New-Object System.Windows.Controls.TextBlock
                $noGamesText.Text = $this.GetLocalizedMessage("noGamesConfigured")
                $noGamesText.FontSize = 16
                $noGamesText.Foreground = "#666"
                $noGamesText.HorizontalAlignment = "Center"

                $noGamesPanel.Children.Add($noGamesText)
                $gameLauncherList.Items.Add($noGamesPanel)
                return
            }

            # Create game cards for each configured game in order
            $gameCount = 0
            $gameOrder = if ($ConfigData.games._order) { $ConfigData.games._order } else { @($ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' }) }

            foreach ($gameId in $gameOrder) {
                if (-not $ConfigData.games.PSObject.Properties[$gameId]) { continue }
                $gameData = $ConfigData.games.$gameId
                $platform = if ($gameData.platform) { $gameData.platform } else { "steam" }

                Write-Verbose "Creating game card for: $gameId (Name: $($gameData.name), Platform: $platform)"

                # Create game item data object
                $gameItem = New-Object PSObject -Property @{
                    GameId      = $gameId
                    DisplayName = $gameData.name
                    Platform    = $platform.ToUpper()
                    ProcessName = $gameData.processName
                }

                # Note: Actual UI element creation should be handled externally or via callback
                # as it involves complex UI construction
                $gameCount++
            }

            Write-Verbose "Game launcher list updated with $gameCount games"
        } catch {
            Write-Warning "Failed to update game launcher list: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Initializes launcher tab text elements.

    .DESCRIPTION
        Initializes various text elements specific to the launcher tab with localized content.

    .OUTPUTS
        None
    #>
    [void]InitializeLauncherTabTexts() {
        try {
            # Initialize launcher welcome and subtitle texts
            $launcherWelcomeText = $this.Window.FindName("LauncherWelcomeText")
            if ($launcherWelcomeText) {
                $launcherWelcomeText.Text = $this.GetLocalizedMessage("launcherWelcomeText")
            }

            $launcherSubtitleText = $this.Window.FindName("LauncherSubtitleText")
            if ($launcherSubtitleText) {
                $launcherSubtitleText.Text = $this.GetLocalizedMessage("launcherSubtitleText")
            }

            # Initialize launcher status text
            $launcherStatusText = $this.Window.FindName("LauncherStatusText")
            if ($launcherStatusText) {
                $launcherStatusText.Text = $this.GetLocalizedMessage("readyToLaunch")
            }

            # Initialize launcher hint text
            $launcherHintText = $this.Window.FindName("LauncherHintText")
            if ($launcherHintText) {
                $launcherHintText.Text = $this.GetLocalizedMessage("launcherHintText")
            }

            Write-Verbose "Launcher tab texts initialized"
        } catch {
            Write-Warning "Failed to initialize launcher tab texts: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Cleans up resources and references to prevent memory leaks.

    .DESCRIPTION
        Properly disposes of resources, clears references, and performs cleanup operations
        to prevent PowerShell from crashing on window close.

    .OUTPUTS
        None
    #>
    [void]Cleanup() {
        try {
            Write-Host "DEBUG: Starting UI cleanup" -ForegroundColor Yellow

            # Clear references to prevent circular dependencies
            if ($this.State) {
                $this.State = $null
            }

            # Clear messages
            if ($this.Messages) {
                $this.Messages = $null
            }

            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()

            Write-Host "DEBUG: UI cleanup completed" -ForegroundColor Green
        } catch {
            Write-Warning "Error during UI cleanup: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Creates a callback function to load global settings into UI controls.

    .DESCRIPTION
        This function generates a scriptblock callback that loads global settings from the provided configuration data into the corresponding UI controls.

    .PARAMETER ConfigData
        The configuration data (as a PSObject) containing global settings to be loaded.

    .OUTPUTS
        ScriptBlock
            Returns a scriptblock that performs the loading of global settings into the UI.

    .EXAMPLE
        $callback = New-GlobalSettingsLoader -ConfigData $config
        $callback.Invoke()
    #>
    [scriptblock]CreateLoadGlobalSettingsCallback([PSObject]$ConfigData) {
        return {
            try {
                Write-Verbose "Loading global settings into UI controls"

                # Load OBS settings
                if ($ConfigData.globalSettings.obs) {
                    $hostTextBox = $this.Window.FindName("HostTextBox")
                    if ($hostTextBox -and $ConfigData.globalSettings.obs.host) {
                        $hostTextBox.Text = $ConfigData.globalSettings.obs.host
                    }

                    $portTextBox = $this.Window.FindName("PortTextBox")
                    if ($portTextBox -and $ConfigData.globalSettings.obs.port) {
                        $portTextBox.Text = $ConfigData.globalSettings.obs.port.ToString()
                    }

                    $passwordBox = $this.Window.FindName("PasswordBox")
                    if ($passwordBox -and $ConfigData.globalSettings.obs.password) {
                        $passwordBox.Password = $ConfigData.globalSettings.obs.password
                    }

                    $replayBufferCheckBox = $this.Window.FindName("ReplayBufferCheckBox")
                    if ($replayBufferCheckBox) {
                        $replayBufferCheckBox.IsChecked = $ConfigData.globalSettings.obs.enableReplayBuffer -eq $true
                    }
                }

                # Load path settings
                if ($ConfigData.globalSettings.paths) {
                    $steamPathTextBox = $this.Window.FindName("SteamPathTextBox")
                    if ($steamPathTextBox -and $ConfigData.globalSettings.paths.steam) {
                        $steamPathTextBox.Text = $ConfigData.globalSettings.paths.steam
                    }

                    $epicPathTextBox = $this.Window.FindName("EpicPathTextBox")
                    if ($epicPathTextBox -and $ConfigData.globalSettings.paths.epic) {
                        $epicPathTextBox.Text = $ConfigData.globalSettings.paths.epic
                    }

                    $riotPathTextBox = $this.Window.FindName("RiotPathTextBox")
                    if ($riotPathTextBox -and $ConfigData.globalSettings.paths.riot) {
                        $riotPathTextBox.Text = $ConfigData.globalSettings.paths.riot
                    }

                    $obsPathTextBox = $this.Window.FindName("ObsPathTextBox")
                    if ($obsPathTextBox -and $ConfigData.globalSettings.paths.obs) {
                        $obsPathTextBox.Text = $ConfigData.globalSettings.paths.obs
                    }
                }

                # Load general settings
                if ($ConfigData.globalSettings) {
                    # Load language setting and update current language
                    $languageComboBox = $this.Window.FindName("LanguageComboBox")
                    if ($languageComboBox -and $ConfigData.globalSettings.language) {
                        $this.CurrentLanguage = $ConfigData.globalSettings.language
                        $languageComboBox.SelectedValue = $ConfigData.globalSettings.language
                    }

                    # Load log retention setting
                    $logRetentionTextBox = $this.Window.FindName("LogRetentionTextBox")
                    if ($logRetentionTextBox -and $ConfigData.globalSettings.logRetentionDays) {
                        $logRetentionTextBox.Text = $ConfigData.globalSettings.logRetentionDays.ToString()
                    }

                    # Load log notarization setting
                    $enableLogNotarizationCheckBox = $this.Window.FindName("EnableLogNotarizationCheckBox")
                    if ($enableLogNotarizationCheckBox) {
                        $enableLogNotarizationCheckBox.IsChecked = $ConfigData.globalSettings.enableLogNotarization -eq $true
                    }
                }

                Write-Verbose "Global settings loaded successfully"
            } catch {
                Write-Warning "Failed to load global settings: $($_.Exception.Message)"
            }
        }.GetNewClosure()
    }
}
