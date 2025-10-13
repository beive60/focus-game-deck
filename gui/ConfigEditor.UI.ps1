# Import mappings at the top of the file
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MappingsPath = Join-Path $ProjectRoot "gui/ConfigEditor.Mappings.ps1"

. $MappingsPath

class ConfigEditorUI {
    # Properties
    [ConfigEditorState]$State
    [System.Windows.Window]$Window
    [hashtable]$Mappings
    [string]$CurrentGameId
    [string]$CurrentAppId
    [PSObject]$Messages
    [string]$CurrentLanguage
    [bool]$HasUnsavedChanges

    # Constructor
    ConfigEditorUI([ConfigEditorState]$stateManager, [hashtable]$allMappings) {
        try {
            Write-Host "DEBUG: ConfigEditorUI constructor started" -ForegroundColor Cyan
            $this.State = $stateManager
            $this.Mappings = $allMappings
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
    #>
    [void]InitializeComponents() {
        try {
            Write-Host "DEBUG: InitializeComponents started" -ForegroundColor Cyan
            $this.CurrentGameId = ""
            $this.CurrentAppId = ""
            $this.CurrentLanguage = "en"
            $this.HasUnsavedChanges = $false
            $this.Messages = @{}
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
    #>
    [string]GetLocalizedMessage([string]$Key) {
        try {
            if ($this.Messages -and $this.Messages.ContainsKey($Key)) {
                $message = $this.Messages[$Key]
                Write-Verbose "[GetLocalizedMessage] Found key '$Key' in cached messages. Value: '$message'"
                return $message
            }

            if (-not $script:LocalizationInProgress) {
                $script:LocalizationInProgress = $true
                $localization = [ConfigEditorLocalization]::new()
                if ($localization | Get-Member -Name "GetMessage" -MemberType Method) {
                    $message = $localization.GetMessage($Key)
                    $script:LocalizationInProgress = $false
                    Write-Verbose "[GetLocalizedMessage] Found key '$Key' via service. Value: '$message'"
                    return $message
                }
                $script:LocalizationInProgress = $false
            }
        } catch {
            $script:LocalizationInProgress = $false
            Write-Warning "[GetLocalizedMessage] Error getting message for key '$Key': $($_.Exception.Message)"
        }

        Write-Warning "[GetLocalizedMessage] No localized message found for key: '$Key'. Returning key itself."
        return $Key
    }

    <#
    .SYNOPSIS
        Measures the text width for a button.
    #>
    [double]MeasureButtonTextWidth([string]$Text, [System.Windows.Controls.Button]$Button) {
        if ([string]::IsNullOrEmpty($Text) -or -not $Button) { return 0 }
        try {
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = $Text
            $textBlock.FontFamily = $Button.FontFamily
            $textBlock.FontSize = $Button.FontSize
            $textBlock.FontWeight = $Button.FontWeight
            $textBlock.FontStyle = $Button.FontStyle
            $textBlock.Measure([System.Windows.Size]::new([double]::PositiveInfinity, [double]::PositiveInfinity))
            return $textBlock.DesiredSize.Width + 15
        } catch {
            return $Text.Length * 7
        }
    }

    <#
    .SYNOPSIS
        Gets a mapping variable from script scope.
    #>
    [hashtable]GetMappingFromScope([string]$MappingName) {
        try {
            $mapping = Get-Variable -Name $MappingName -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if ($mapping -and $mapping -is [hashtable]) {
                return $mapping
            }
            Write-Warning "[GetMappingFromScope] Mapping '$MappingName' not found or is not a hashtable."
            return @{}
        } catch {
            Write-Warning "[GetMappingFromScope] Failed to get mapping '$MappingName': $($_.Exception.Message)"
            return @{}
        }
    }

    <#
    .SYNOPSIS
        Sets button content with smart tooltip based on text width.
    #>
    [void]SetButtonContentWithTooltip([System.Windows.Controls.Button]$Button, [string]$FullText) {
        if (-not $Button -or [string]::IsNullOrEmpty($FullText)) { return }
        try {
            $Button.Content = $FullText
            $Button.UpdateLayout()
            $Button.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action] {})
            $buttonWidth = $Button.ActualWidth
            if ($buttonWidth -eq 0) { $buttonWidth = $Button.Width }
            $availableWidth = $buttonWidth - 15
            $textWidth = $this.MeasureButtonTextWidth($FullText, $Button)
            $shouldShowTooltip = ($availableWidth -gt 0 -and $textWidth -gt $availableWidth) -or ($availableWidth -le 0 -and $FullText.Length -gt 12)
            if ($shouldShowTooltip) {
                $Button.ToolTip = $FullText
                Write-Verbose "[SetButtonContentWithTooltip] Set tooltip for '$($Button.Name)': '$FullText'"
            } else {
                $Button.ToolTip = $null
            }
        } catch {
            Write-Warning "[SetButtonContentWithTooltip] Error for '$($Button.Name)': $($_.Exception.Message)"
            $Button.Content = $FullText
            if ($FullText.Length -gt 10) { $Button.ToolTip = $FullText } else { $Button.ToolTip = $null }
        }
    }

    <#
    .SYNOPSIS
        Updates UI texts based on current language using mappings.
    #>
    [void]UpdateUITexts([PSObject]$ConfigData) {
        try {
            Write-Verbose "--- Starting UI Text Update for language: $($this.CurrentLanguage) ---"

            # Update window title
            $this.Window.Title = $this.GetLocalizedMessage("windowTitle")
            Write-Verbose "Window Title set to: '$($this.Window.Title)'"

            # Update all button contents and tooltips
            Write-Verbose "Updating all buttons..."
            $allButtonMappings = $this.Mappings['Button']
            foreach ($buttonName in $allButtonMappings.Keys) {
                $button = $this.Window.FindName($buttonName)
                if ($button) {
                    $messageKey = $allButtonMappings[$buttonName]
                    $fullText = $this.GetLocalizedMessage($messageKey)
                    Write-Verbose "  - Button '$buttonName': Key='$messageKey', Text='$fullText'"
                    $this.SetButtonContentWithTooltip($button, $fullText)
                } else {
                    Write-Verbose "  - Button '$buttonName' not found in XAML."
                }
            }

            # Update other UI elements
            Write-Verbose "Updating other UI elements (Labels, Tabs, etc.)..."
            $this.UpdateElementsFromMappings()

            Write-Verbose "--- UI Text Update Completed ---"
        } catch {
            Write-Warning "Failed to update UI texts: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates UI elements from centralized mappings.
    #>
    [void]UpdateElementsFromMappings() {
        try {
            $allMappings = $this.Mappings

            foreach ($elementType in $allMappings.Keys) {
                $mappingTable = $allMappings[$elementType]
                Write-Verbose "Processing '$elementType' mappings (count: $($mappingTable.Count))..."
                foreach ($elementName in $mappingTable.Keys) {
                    $element = $this.Window.FindName($elementName)
                    if ($element) {
                        $messageKey = $mappingTable[$elementName]
                        $localizedText = $this.GetLocalizedMessage($messageKey)
                        $propToSet = ""
                        $currentValue = ""

                        switch ($element.GetType().Name) {
                            "TabItem" { $propToSet = "Header"; $currentValue = $element.Header }
                            "Label" { $propToSet = "Content"; $currentValue = $element.Content }
                            "GroupBox" { $propToSet = "Header"; $currentValue = $element.Header }
                            "CheckBox" { $propToSet = "Content"; $currentValue = $element.Content }
                            "TextBlock" { $propToSet = "Text"; $currentValue = $element.Text }
                            "MenuItem" { $propToSet = "Header"; $currentValue = $element.Header }
                            "Button" { if ($elementType -eq "Tooltip") { $propToSet = "ToolTip"; $currentValue = $element.ToolTip } }
                            default {
                                if ($element | Get-Member -Name "Header" -MemberType Property) { $propToSet = "Header"; $currentValue = $element.Header }
                                elseif ($element | Get-Member -Name "Content" -MemberType Property) { $propToSet = "Content"; $currentValue = $element.Content }
                                elseif ($element | Get-Member -Name "Text" -MemberType Property) { $propToSet = "Text"; $currentValue = $element.Text }
                                elseif ($element | Get-Member -Name "ToolTip" -MemberType Property) { $propToSet = "ToolTip"; $currentValue = $element.ToolTip }
                            }
                        }

                        if ($propToSet) {
                            Write-Verbose "  - Updating '$elementName' ($($element.GetType().Name)). Key: '$messageKey', Prop: '$propToSet', Text: '$localizedText'"
                            Write-Verbose "    Before: '$currentValue'"
                            $element.$propToSet = $localizedText
                            Write-Verbose "    After : '$($element.$propToSet)'"
                        } else {
                            Write-Verbose "  - Skipped '$elementName' of type '$($element.GetType().Name)' - no property to set."
                        }

                    } else {
                        Write-Verbose "  - Element '$elementName' not found in XAML for '$elementType' mapping."
                    }
                }
            }
        } catch {
            Write-Warning "Failed to update elements from mappings: $($_.Exception.Message)"
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
            # Version.ps1 should be loaded by the main script
            if (Get-Command -Name Get-ProjectVersionInfo -ErrorAction SilentlyContinue) {
                $versionInfo = Get-ProjectVersionInfo
                $versionText = $this.Window.FindName("VersionText")
                if ($versionText) {
                    $versionText.Text = $versionInfo.FullVersion
                }
                Write-Verbose "Version display initialized: $($versionInfo.FullVersion)"
            }
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
            if (-not $ConfigData.games -or $ConfigData.games.PSObject.Properties.Count -eq 1) { # checking for 1 to account for _order
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

                # This is where you would create the complex UI for the game card
                # For now, we just add a placeholder.
                $gameLauncherList.Items.Add("Game: " + $gameData.name)
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
            # This is now handled by UpdateElementsFromMappings, but we can keep it for clarity
            # or for elements not covered by the generic mapping.
            $textMappings = $this.GetMappingFromScope("TextMappings")
            $launcherKeys = @("LauncherWelcomeText", "LauncherSubtitleText", "LauncherStatusText", "LauncherHintText")
            foreach($key in $launcherKeys) {
                if($textMappings.ContainsKey($key)) {
                    $element = $this.Window.FindName($key)
                    if($element) {
                        $element.Text = $this.GetLocalizedMessage($textMappings[$key])
                    }
                }
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
                if ($ConfigData.obs.websocket) {
                    $this.Window.FindName("ObsHostTextBox").Text = $ConfigData.obs.websocket.host
                    $this.Window.FindName("ObsPortTextBox").Text = $ConfigData.obs.websocket.port
                    $this.Window.FindName("ObsPasswordBox").Password = $ConfigData.obs.websocket.password
                }
                if ($ConfigData.obs) {
                    $this.Window.FindName("ReplayBufferCheckBox").IsChecked = [bool]$ConfigData.obs.replayBuffer
                }


                # Load path settings
                if ($ConfigData.paths) {
                    $this.Window.FindName("SteamPathTextBox").Text = $ConfigData.paths.steam
                    $this.Window.FindName("EpicPathTextBox").Text = $ConfigData.paths.epic
                    $this.Window.FindName("RiotPathTextBox").Text = $ConfigData.paths.riot
                    $this.Window.FindName("ObsPathTextBox").Text = $ConfigData.paths.obs
                }

                # Load general settings
                $langCombo = $this.Window.FindName("LanguageCombo")
                $selectedLang = if($ConfigData.language) {$ConfigData.language} else {""}
                # This needs to be improved to handle the actual items in the combobox
                # For now, we just log it.
                Write-Verbose "Configured language: $selectedLang"


                $launcherTypeCombo = $this.Window.FindName("LauncherTypeCombo")
                # Similar logic for launcher type

                $logRetentionCombo = $this.Window.FindName("LogRetentionCombo")
                # Similar logic for log retention

                $this.Window.FindName("EnableLogNotarizationCheckBox").IsChecked = [bool]$ConfigData.logging.enableNotarization

                Write-Verbose "Global settings loaded successfully"
            } catch {
                Write-Warning "Failed to load global settings: $($_.Exception.Message)"
            }
        }.GetNewClosure()
    }
}
