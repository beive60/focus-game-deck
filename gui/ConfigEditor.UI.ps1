# ConfigEditor.UI.ps1
# UI Manager class for Focus Game Deck Configuration Editor

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
    [PSObject]$EventHandler

    # Constructor
    ConfigEditorUI([ConfigEditorState]$stateManager, [hashtable]$allMappings, [ConfigEditorLocalization]$localization) {
        try {
            Write-Host "[DEBUG] ConfigEditorUI: Constructor started"
            $this.State = $stateManager
            $this.Mappings = $allMappings
            $this.Messages = $localization.Messages
            $this.CurrentLanguage = $localization.CurrentLanguage
            Write-Host "[DEBUG] ConfigEditorUI: State manager, mappings, and localization assigned"

            # Load XAML
            Write-Host "[DEBUG] ConfigEditorUI: Step 1/6 - Loading XAML file"
            $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
            if (-not (Test-Path $xamlPath)) {
                throw "XAML file not found: $xamlPath"
            }
            $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
            Write-Host "[DEBUG] ConfigEditorUI: Step 2/6 - XAML content loaded - Length: $($xamlContent.Length)"

            # Parse XAML
            Write-Host "[DEBUG] ConfigEditorUI: Step 3/6 - Parsing XAML"
            $xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
            $this.Window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
            $xmlReader.Close()
            Write-Host "[DEBUG] ConfigEditorUI: Step 4/6 - XAML parsed successfully"

            if ($null -eq $this.Window) {
                throw "Failed to create Window from XAML"
            }

            # Set up proper window closing behavior
            Write-Host "[DEBUG] ConfigEditorUI: Step 5/6 - Adding window event handlers"
            $selfRef = $this
            $this.Window.add_Closed({
                    param($sender, $e)
                    Write-Host "[DEBUG] ConfigEditorUI: Window closed event triggered"
                    try {
                        $selfRef.Cleanup()
                    } catch {
                        Write-Host "[WARNING] ConfigEditorUI: Error during cleanup - $($_.Exception.Message)"
                    }
                }.GetNewClosure())

            # Initialize other components
            Write-Host "[DEBUG] ConfigEditorUI: Step 6/6 - Initializing other components"
            $this.InitializeComponents()
            # NOTE: InitializeGameActionCombos moved to LoadDataToUI to avoid premature SelectedIndex setting
            Write-Host "[OK] ConfigEditorUI: Constructor completed successfully"

        } catch {
            Write-Host "[ERROR] ConfigEditorUI: Constructor failed - $($_.Exception.Message)"
            Write-Host "[DEBUG] ConfigEditorUI: Exception type - $($_.Exception.GetType().Name)"
            if ($_.Exception.InnerException) {
                Write-Host "[DEBUG] ConfigEditorUI: Inner exception - $($_.Exception.InnerException.Message)"
            }
            Write-Host "[DEBUG] ConfigEditorUI: Stack trace - $($_.Exception.StackTrace)"
            throw
        }
    }

    <#
    .SYNOPSIS
        Initializes UI components and sets default values.
    #>
    [void]InitializeComponents() {
        try {
            Write-Host "[DEBUG] ConfigEditorUI: InitializeComponents started"
            $this.CurrentGameId = ""
            $this.CurrentAppId = ""
            $this.CurrentLanguage = "en"
            $this.HasUnsavedChanges = $false
            # messages are now passed in constructor
            $this.Window.DataContext = $this
            Write-Host "[OK] ConfigEditorUI: InitializeComponents completed"
        } catch {
            Write-Host "[ERROR] ConfigEditorUI: InitializeComponents failed - $($_.Exception.Message)"
            throw
        }
    }

    <#
    .SYNOPSIS
        Gets a localized message for the specified key.
    #>
    [string]GetLocalizedMessage([string]$Key) {
        try {
            # MODIFIED: Use PSCustomObject property check instead of ContainsKey
            if ($this.Messages -and $this.Messages.PSObject.Properties[$Key]) {
                $message = $this.Messages.$Key
                Write-Verbose "[GetLocalizedMessage] Found key '$Key' in cached messages. Value: '$message'"
                return $message
            }
        } catch {
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
                            "ComboBoxItem" { $propToSet = "Content"; $currentValue = $element.Content }
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
            # Initialize game action combos FIRST before loading data
            $this.InitializeGameActionCombos()

            # Initialize managed app action combos
            $this.InitializeManagedAppActionCombos()

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
        if (-not $gamesList) {
            Write-Verbose "GamesList control not found, skipping update"
            return
        }

        try {
            $gamesList.Items.Clear()
        } catch {
            Write-Verbose "Failed to clear GamesList items: $($_.Exception.Message)"
            return
        }

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

            # Auto-select first item if list is not empty to prevent "no selection" state
            # This ensures users always have context and prevents saving to fail
            if ($gamesList.Items.Count -gt 0) {
                $gamesList.SelectedIndex = 0
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
        if (-not $managedAppsList) {
            Write-Verbose "ManagedAppsList control not found, skipping update"
            return
        }

        try {
            $managedAppsList.Items.Clear()
        } catch {
            Write-Verbose "Failed to clear ManagedAppsList items: $($_.Exception.Message)"
            return
        }

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

            # Auto-select first item if list is not empty to prevent "no selection" state
            # This ensures users always have context and prevents saving to fail
            if ($managedAppsList.Items.Count -gt 0) {
                $managedAppsList.SelectedIndex = 0
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
            # Update launcher status
            $statusText = $this.Window.FindName("LauncherStatusText")
            if ($statusText) {
                $statusText.Text = $this.GetLocalizedMessage("refreshingGameList")
            }

            $gameLauncherList = $this.Window.FindName("GameLauncherList")
            if (-not $gameLauncherList) {
                Write-Warning "GameLauncherList control not found"
                if ($statusText) {
                    $statusText.Text = $this.GetLocalizedMessage("gameListError")
                }
                return
            }

            # Clear existing items
            try {
                $gameLauncherList.Items.Clear()
            } catch {
                Write-Verbose "Failed to clear GameLauncherList items: $($_.Exception.Message)"
                if ($statusText) {
                    $statusText.Text = $this.GetLocalizedMessage("gameListError")
                }
                return
            }

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

                # Update status text for no games
                if ($statusText) {
                    $statusText.Text = $this.GetLocalizedMessage("noGamesFound")
                }
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
                    GameId = $gameId
                    DisplayName = $gameData.name
                    Platform = $platform.ToUpper()
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

                    $grid.ColumnDefinitions.Add($col1)
                    $grid.ColumnDefinitions.Add($col2)

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

                    # Launch button
                    $launchButton = New-Object System.Windows.Controls.Button
                    $launchButton.Content = $this.GetLocalizedMessage("launchButton")
                    $launchButton.Width = 80
                    $launchButton.Height = 32
                    $launchButton.Background = "#0078D4"
                    $launchButton.Foreground = "White"
                    $launchButton.BorderBrush = "#0078D4"
                    $launchButton.FontWeight = "SemiBold"
                    $launchButton.FontSize = 12
                    $launchButton.Cursor = "Hand"
                    [System.Windows.Controls.Grid]::SetColumn($launchButton, 1)

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
                    $launchButton.Tag = @{ GameId = $gameId; FormInstance = $this }
                    $launchButton.add_Click({
                            try {
                                $gameId = $this.Tag.GameId
                                $formInstance = $this.Tag.FormInstance
                                $formInstance.StartGameFromLauncher($gameId)
                            } catch {
                                Write-Warning "Error in launch button click: $($_.Exception.Message)"
                            }
                        })

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
                    $statusText.Text = $this.GetLocalizedMessage("oneGameReady")
                } else {
                    $statusText.Text = $this.GetLocalizedMessage("multipleGamesReady") -f $gameCount.ToString()
                }
            }

            Write-Verbose "Game launcher list updated with $gameCount games"

        } catch {
            Write-Warning "Failed to update game launcher list: $($_.Exception.Message)"
            $statusText = $this.Window.FindName("LauncherStatusText")
            if ($statusText) {
                $statusText.Text = $this.GetLocalizedMessage("gameListUpdateError")
            }
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
            foreach ($key in $launcherKeys) {
                if ($textMappings.ContainsKey($key)) {
                    $element = $this.Window.FindName($key)
                    if ($element) {
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
            Write-Host "[DEBUG] ConfigEditorUI: Starting UI cleanup"

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

            Write-Host "[OK] ConfigEditorUI: UI cleanup completed"
        } catch {
            Write-Host "[WARNING] ConfigEditorUI: Error during UI cleanup - $($_.Exception.Message)"
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
        $self = $this
        return {
            try {
                Write-Verbose "Loading global settings into UI controls"

                $obsHostTextBox = $self.Window.FindName("ObsHostTextBox")
                if ($obsHostTextBox -and $ConfigData.obs.websocket) {
                    $obsHostTextBox.Text = $ConfigData.obs.websocket.host
                }

                $obsPortTextBox = $self.Window.FindName("ObsPortTextBox")
                if ($obsPortTextBox -and $ConfigData.obs.websocket) {
                    $obsPortTextBox.Text = $ConfigData.obs.websocket.port
                }

                $obsPasswordBox = $self.Window.FindName("ObsPasswordBox")
                if ($obsPasswordBox -and $ConfigData.obs.websocket) {
                    if ($ConfigData.obs.websocket.password) {
                        # Password is saved - show placeholder text using a helper TextBlock
                        # Set Tag to indicate password exists (will be used during save)
                        $obsPasswordBox.Tag = "SAVED"

                        # Clear the PasswordBox but mark it as having a saved password
                        $obsPasswordBox.Password = ""

                        # Create helper TextBlock for placeholder effect if it doesn't exist
                        $passwordPanel = $obsPasswordBox.Parent
                        if ($passwordPanel) {
                            $existingPlaceholder = $passwordPanel.Children | Where-Object { $_.Name -eq "ObsPasswordPlaceholder" }
                            if (-not $existingPlaceholder) {
                                $placeholderText = New-Object System.Windows.Controls.TextBlock
                                $placeholderText.Name = "ObsPasswordPlaceholder"
                                $placeholderText.Text = $self.Messages.passwordSavedPlaceholder
                                $placeholderText.Foreground = [System.Windows.Media.Brushes]::Gray
                                $placeholderText.IsHitTestVisible = $false
                                $placeholderText.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
                                $placeholderText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

                                # Set Grid position to match PasswordBox
                                [System.Windows.Controls.Grid]::SetRow($placeholderText, [System.Windows.Controls.Grid]::GetRow($obsPasswordBox))
                                [System.Windows.Controls.Grid]::SetColumn($placeholderText, [System.Windows.Controls.Grid]::GetColumn($obsPasswordBox))

                                $passwordPanel.Children.Add($placeholderText) | Out-Null

                                # Add event handler to hide placeholder when user types
                                $obsPasswordBox.add_PasswordChanged({
                                        param($sender, $e)
                                        $placeholder = $sender.Parent.Children | Where-Object { $_.Name -eq "ObsPasswordPlaceholder" }
                                        if ($placeholder) {
                                            $placeholder.Visibility = if ($sender.Password.Length -eq 0) {
                                                [System.Windows.Visibility]::Visible
                                            } else {
                                                [System.Windows.Visibility]::Collapsed
                                            }
                                        }
                                        # Clear SAVED tag when user starts typing
                                        if ($sender.Password.Length -gt 0) {
                                            $sender.Tag = $null
                                        }
                                    }.GetNewClosure())
                            }
                        }
                    } else {
                        # No password saved
                        $obsPasswordBox.Password = ""
                        $obsPasswordBox.Tag = $null
                    }
                }

                $replayBufferCheckBox = $self.Window.FindName("ReplayBufferCheckBox")
                if ($replayBufferCheckBox -and $ConfigData.obs) {
                    $replayBufferCheckBox.IsChecked = [bool]$ConfigData.obs.replayBuffer
                }

                if ($ConfigData.paths) {
                    $steamPathTextBox = $self.Window.FindName("SteamPathTextBox")
                    if ($steamPathTextBox) { $steamPathTextBox.Text = $ConfigData.paths.steam }

                    $epicPathTextBox = $self.Window.FindName("EpicPathTextBox")
                    if ($epicPathTextBox) { $epicPathTextBox.Text = $ConfigData.paths.epic }

                    $riotPathTextBox = $self.Window.FindName("RiotPathTextBox")
                    if ($riotPathTextBox) { $riotPathTextBox.Text = $ConfigData.paths.riot }

                    $obsPathTextBox = $self.Window.FindName("ObsPathTextBox")
                    if ($obsPathTextBox) { $obsPathTextBox.Text = $ConfigData.paths.obs }
                }

                $langCombo = $self.Window.FindName("LanguageCombo")
                if ($langCombo) {
                    # Temporarily disable SelectionChanged event during initialization
                    # This prevents HandleLanguageSelectionChanged from triggering during UI setup
                    $langCombo.IsEnabled = $false

                    # Clear existing items
                    $langCombo.Items.Clear()

                    # Add language options as ComboBoxItems
                    # Each language is displayed in its native language
                    $languages = @(
                        @{ Code = "en"; Name = "English" }
                        @{ Code = "ja"; Name = "日本語" }
                        @{ Code = "zh-CN"; Name = "中文（简体）" }
                    )

                    $selectedIndex = 0
                    $currentIndex = 0
                    foreach ($lang in $languages) {
                        $item = New-Object System.Windows.Controls.ComboBoxItem
                        $item.Content = $lang.Name
                        $item.Tag = $lang.Code
                        $langCombo.Items.Add($item) | Out-Null

                        # Track which item should be selected
                        if ($ConfigData.language -eq $lang.Code) {
                            $selectedIndex = $currentIndex
                        }
                        $currentIndex++
                    }

                    # Set selection by index to avoid triggering SelectionChanged multiple times
                    if ($langCombo.Items.Count -gt 0) {
                        $langCombo.SelectedIndex = $selectedIndex
                    }

                    # Re-enable the ComboBox after initialization
                    $langCombo.IsEnabled = $true
                }

                $launcherTypeCombo = $self.Window.FindName("LauncherTypeCombo")
                if ($launcherTypeCombo) {
                    # Implement selection logic
                }

                $logRetentionCombo = $self.Window.FindName("LogRetentionCombo")
                if ($logRetentionCombo) {
                    # Implement selection logic
                }

                $enableLogNotarizationCheckBox = $self.Window.FindName("EnableLogNotarizationCheckBox")
                if ($enableLogNotarizationCheckBox -and $ConfigData.logging) {
                    $enableLogNotarizationCheckBox.IsChecked = [bool]$ConfigData.logging.enableNotarization
                }

                Write-Verbose "Global settings loaded successfully"
            } catch {
                Write-Warning "Failed to load global settings: $($_.Exception.Message)"
            }
        }.GetNewClosure()
    }

    <#
    .SYNOPSIS
    Initializes the game action combo boxes with available actions.
    .DESCRIPTION
    Populates the GameStartActionCombo and GameEndActionCombo with predefined action options
    using localized ComboBoxItems from GameActionMessageKeys mapping.
    .OUTPUTS
    None
    .EXAMPLE
    $this.InitializeGameActionCombos()
    #>
    [void]InitializeGameActionCombos() {
        try {
            Write-Verbose "InitializeGameActionCombos: Starting initialization"
            $gameStartActionCombo = $this.Window.FindName("GameStartActionCombo")
            $gameEndActionCombo = $this.Window.FindName("GameEndActionCombo")
            $terminationMethodCombo = $this.Window.FindName("TerminationMethodCombo")

            if (-not $gameStartActionCombo) {
                Write-Warning "GameStartActionCombo not found"
                return
            }
            if (-not $gameEndActionCombo) {
                Write-Warning "GameEndActionCombo not found"
                return
            }
            if (-not $terminationMethodCombo) {
                Write-Warning "TerminationMethodCombo not found"
            }

            # Get game action mappings from script scope
            $gameActionMappings = $this.GetMappingFromScope("GameActionMessageKeys")
            $terminationMethodMappings = $this.GetMappingFromScope("TerminationMethodMessageKeys")

            if ($gameActionMappings.Count -eq 0) {
                Write-Warning "GameActionMessageKeys mapping not found or empty"
                return
            }

            # Clear existing items safely
            try {
                $gameStartActionCombo.Items.Clear()
                $gameEndActionCombo.Items.Clear()
                if ($terminationMethodCombo) {
                    $terminationMethodCombo.Items.Clear()
                }
            } catch {
                Write-Warning "Failed to clear combo box items: $($_.Exception.Message)"
                return
            }

            # Add localized ComboBoxItems using the mapping
            foreach ($kvp in $gameActionMappings.GetEnumerator()) {
                $actionTag = $kvp.Key
                $messageKey = $kvp.Value
                $localizedText = $this.GetLocalizedMessage($messageKey)

                # Create ComboBoxItem for start action combo
                $startItem = New-Object System.Windows.Controls.ComboBoxItem
                $startItem.Content = $localizedText
                $startItem.Tag = $actionTag
                $gameStartActionCombo.Items.Add($startItem) | Out-Null

                # Create ComboBoxItem for end action combo
                $endItem = New-Object System.Windows.Controls.ComboBoxItem
                $endItem.Content = $localizedText
                $endItem.Tag = $actionTag
                $gameEndActionCombo.Items.Add($endItem) | Out-Null

                Write-Verbose "Added game action: Tag='$actionTag', Key='$messageKey', Text='$localizedText'"
            }

            # Add termination method options
            if ($terminationMethodCombo -and $terminationMethodMappings.Count -gt 0) {
                foreach ($kvp in $terminationMethodMappings.GetEnumerator()) {
                    $methodTag = $kvp.Key
                    $messageKey = $kvp.Value
                    $localizedText = $this.GetLocalizedMessage($messageKey)

                    $methodItem = New-Object System.Windows.Controls.ComboBoxItem
                    $methodItem.Content = $localizedText
                    $methodItem.Tag = $methodTag
                    $terminationMethodCombo.Items.Add($methodItem) | Out-Null

                    Write-Verbose "Added termination method: Tag='$methodTag', Key='$messageKey', Text='$localizedText'"
                }
            }

            # DO NOT set default selection - let it be unselected initially
            # This prevents SelectedItem property issues during window initialization
            Write-Verbose "Game action combo boxes initialized successfully with $($gameActionMappings.Count) localized actions (no default selection)"
        } catch {
            Write-Warning "Failed to initialize game action combo boxes: $($_.Exception.Message)"
            Write-Warning "Stack trace: $($_.Exception.StackTrace)"
        }
    }

    <#
    .SYNOPSIS
    Initializes the managed app action combo boxes with available actions.
    .DESCRIPTION
    Populates the AppStartActionCombo, AppEndActionCombo, and AppTerminationMethodCombo
    with predefined action options using localized ComboBoxItems.
    .OUTPUTS
    None
    .EXAMPLE
    $this.InitializeManagedAppActionCombos()
    #>
    [void]InitializeManagedAppActionCombos() {
        try {
            Write-Verbose "InitializeManagedAppActionCombos: Starting initialization"

            # NOTE: Managed Apps tab uses the same ComboBox names as Game tab
            # GameStartActionCombo, GameEndActionCombo, TerminationMethodCombo
            # These are already initialized by InitializeGameActionCombos()
            # So this method is actually redundant but kept for clarity and future extensibility

            Write-Verbose "Managed app action combo boxes use same controls as game tab - already initialized"
        } catch {
            Write-Warning "Failed to initialize managed app action combo boxes: $($_.Exception.Message)"
            Write-Warning "Stack trace: $($_.Exception.StackTrace)"
        }
    }

    <#
    .SYNOPSIS
    Gets available game actions based on platform and permissions.
    .DESCRIPTION
    Returns an array of action objects containing Content and Tag properties
    based on the specified platform and user permission level.
    .PARAMETER platform
    The gaming platform (steam, standalone, epic, riot).
    .PARAMETER permissions
    User permission level (Standard, Advanced).
    .OUTPUTS
    Array of hashtables with Content and Tag properties.
    #>
    [array]GetAvailableGameActions([string]$platform, [string]$permissions) {
        # Base actions always available
        $baseActions = @(
            @{ Content = "[NO_ACTION]"; Tag = "none" }
        )

        # Conditional actions based on platform and permissions
        $conditionalActions = @()

        if ($platform -eq "steam" -or $platform -eq "standalone") {
            $conditionalActions += @{ Content = "[START_PROCESS]"; Tag = "start_process" }
            $conditionalActions += @{ Content = "[STOP_PROCESS]"; Tag = "stop_process" }
        }

        if ($permissions -eq "Advanced") {
            $conditionalActions += @{ Content = "[Invoke_COMMAND_WITH_PARAMETERS]"; Tag = "invoke_command_with_parameters" }
        }

        return $baseActions + $conditionalActions
    }

    <#
    .SYNOPSIS
    Adds a ComboBoxItem to the specified ComboBox control.
    .DESCRIPTION
    Creates and adds a new ComboBoxItem with the specified content and tag
    to the provided ComboBox control.
    .PARAMETER comboBox
    The ComboBox control to add the item to.
    .PARAMETER content
    The display text for the ComboBoxItem.
    .PARAMETER tag
    The tag value for the ComboBoxItem.
    #>
    [void]AddComboBoxActionItem([System.Windows.Controls.ComboBox]$comboBox, [string]$content, [string]$tag) {
        try {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $content
            $item.Tag = $tag
            $comboBox.Items.Add($item) | Out-Null
        } catch {
            Write-Host "[ERROR] ConfigEditorUI: Error adding ComboBox item - $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
    Event handler for platform selection changes.
    .DESCRIPTION
    Updates game action combo boxes when the platform selection changes
    to show appropriate actions for the selected platform.
    .PARAMETER sender
    The ComboBox that triggered the event.
    .PARAMETER e
    Selection changed event arguments.
    #>
    [void]OnPlatformSelectionChanged([object]$sender, [System.Windows.Controls.SelectionChangedEventArgs]$e) {
        try {
            if ($sender.SelectedItem -and $sender.SelectedItem.Tag) {
                $selectedPlatform = $sender.SelectedItem.Tag.ToString()
                $currentPermissions = $this.GetCurrentUserPermissions()
                $this.InitializeGameActionCombos($selectedPlatform, $currentPermissions)
            }
        } catch {
            Write-Host "[ERROR] ConfigEditorUI: Error handling platform selection change - $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
    Gets the current user permission level.
    .DESCRIPTION
    Determines the current user's permission level for action availability.
    This is a placeholder function that should be implemented based on your
    application's permission system.
    .OUTPUTS
    String representing permission level (Standard or Advanced).
    #>
    [string]GetCurrentUserPermissions() {
        # TODO: Implement actual permission logic
        return "Standard"
    }

    <#
    .SYNOPSIS
        Switches to the game settings tab and selects the specified game.

    .DESCRIPTION
        This method switches to the game settings tab and automatically selects the specified game for editing.

    .PARAMETER GameId
        The ID of the game to select for editing.
    #>
    <#
    .SYNOPSIS
        Starts a game from the game launcher.

    .DESCRIPTION
        This method attempts to launch the specified game using the appropriate launcher mechanism.

    .PARAMETER GameId
        The ID of the game to launch.
    #>
    [void]StartGameFromLauncher([string]$GameId) {
        try {
            Write-Verbose "Attempting to launch game: $GameId"

            # Delegate to event handler if available
            if ($this.EventHandler) {
                $this.EventHandler.HandleLaunchGame($GameId)
            } else {
                Write-Warning "Event handler not initialized, cannot launch game"
                $message = $this.GetLocalizedMessage("launchError")
                [System.Windows.MessageBox]::Show($message, $this.GetLocalizedMessage("error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }

        } catch {
            Write-Warning "Failed to launch game '$GameId': $($_.Exception.Message)"

            # Show error message
            $errorMessage = $this.GetLocalizedMessage("launchFailed") -f $GameId, $_.Exception.Message
            [System.Windows.MessageBox]::Show($errorMessage, $this.GetLocalizedMessage("launchError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
}
