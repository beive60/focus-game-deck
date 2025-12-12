<#
.SYNOPSIS
    ConfigEditor UI Module - Main UI class for Focus Game Deck configuration editor.

.DESCRIPTION
    This module provides the ConfigEditorUI class which manages the WPF-based graphical
    user interface for editing game configurations, integrations, and application settings.

.NOTES
    File Name  : ConfigEditor.UI.ps1
    Author     : Focus Game Deck Team
    Requires   : PowerShell 5.1 or later, WPF assemblies
#>

<#
.SYNOPSIS
    Main UI class for the Focus Game Deck configuration editor.

.DESCRIPTION
    Manages the WPF window, UI controls, localization, and user interactions for
    the configuration editor. Provides methods for loading/saving configuration data,
    updating UI elements, and handling user events.

.EXAMPLE
    $ui = [ConfigEditorUI]::new($stateManager, $mappings, $localization)
    $ui.LoadDataToUI($configData)
    $ui.Window.ShowDialog()
#>
class ConfigEditorUI {
    # Properties
    [ConfigEditorState]$State
    [Object]$Window
    [hashtable]$Mappings
    [string]$CurrentGameId
    [string]$CurrentAppId
    [PSObject]$Messages
    [string]$CurrentLanguage
    [bool]$HasUnsavedChanges
    [PSObject]$EventHandler
    [string]$appRoot
    [Object]$NotificationTimer

    <#
    .SYNOPSIS
        Initializes a new ConfigEditorUI instance.

    .DESCRIPTION
        Creates the main WPF window from XAML, initializes all UI components,
        sets up event handlers, and prepares the interface for user interaction.

    .PARAMETER stateManager
        ConfigEditorState instance for managing application state

    .PARAMETER allMappings
        Hashtable containing UI element to message key mappings

    .PARAMETER localization
        ConfigEditorLocalization instance for multi-language support

    .EXAMPLE
        $ui = [ConfigEditorUI]::new($state, $mappings, $localization)

    .NOTES
        Automatically loads XAML from MainWindow.xaml in the script directory.
    #>
    # Constructor
    ConfigEditorUI([ConfigEditorState]$stateManager, [hashtable]$allMappings, [ConfigEditorLocalization]$localization, [string]$appRoot) {
        try {
            Write-Verbose "[DEBUG] ConfigEditorUI: Constructor started"
            $this.State = $stateManager
            $this.Mappings = $allMappings
            $this.Messages = $localization.Messages
            $this.CurrentLanguage = $localization.CurrentLanguage
            # Store project root for internal file path construction (classes cannot access outer script variables)
            $this.appRoot = $appRoot
            Write-Verbose "[DEBUG] ConfigEditorUI: State manager, mappings, and localization assigned"

            # Load XAML (use project root defined in main script)
            Write-Verbose "[DEBUG] ConfigEditorUI: Step 1/6 - Loading XAML"
            $xamlContent = $null

            # Check if embedded XAML variable exists (production/bundled mode)
            if ($Global:Xaml_MainWindow) {
                Write-Verbose "[DEBUG] ConfigEditorUI: Using embedded XAML from `$Global:Xaml_MainWindow"
                $xamlContent = $Global:Xaml_MainWindow
            } else {
                # Fallback to file-based loading (development mode)
                Write-Verbose "[DEBUG] ConfigEditorUI: Loading XAML from file (development mode)"
                $xamlPath = Join-Path -Path $this.appRoot -ChildPath "gui/MainWindow.xaml"
                if (-not (Test-Path $xamlPath)) {
                    throw "XAML file not found: $xamlPath"
                }
                $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
            }

            if ([string]::IsNullOrWhiteSpace($xamlContent)) {
                throw "XAML content is empty or null"
            }

            Write-Verbose "[DEBUG] ConfigEditorUI: Step 2/6 - XAML content loaded - Length: $($xamlContent.Length)"

            # Parse XAML
            Write-Verbose "[DEBUG] ConfigEditorUI: Step 3/6 - Parsing XAML"
            $xamlLoader = [ScriptBlock]::Create('
                param($xmlReader)
                return [System.Windows.Markup.XamlReader]::Load($xmlReader)
            ')

            # Create XmlReader from content
            $stringReader = New-Object System.IO.StringReader($xamlContent)
            $xmlReader = [System.Xml.XmlReader]::Create($stringReader)

            $this.Window = $xamlLoader.Invoke($xmlReader)[0]
            $xmlReader.Close()
            $stringReader.Close()
            Write-Verbose "[DEBUG] ConfigEditorUI: Step 4/6 - XAML parsed successfully"

            if ($null -eq $this.Window) {
                throw "Failed to create Window from XAML"
            }

            # Set up proper window closing behavior
            Write-Verbose "[DEBUG] ConfigEditorUI: Step 5/6 - Adding window event handlers"
            $selfRef = $this
            $this.Window.add_Closed({
                    param($s, $e)
                    Write-Verbose "[DEBUG] ConfigEditorUI: Window closed event triggered"
                    try {
                        $selfRef.Cleanup()
                    } catch {
                        Write-Verbose "[WARNING] ConfigEditorUI: Error during cleanup - $($_.Exception.Message)"
                    }
                }.GetNewClosure())

            # Initialize other components
            Write-Verbose "[DEBUG] ConfigEditorUI: Step 6/6 - Initializing other components"
            $this.InitializeComponents()
            $this.InitializeNotificationTimer()
            # NOTE: InitializeGameActionCombos moved to LoadDataToUI to avoid premature SelectedIndex setting
            Write-Verbose "[OK] ConfigEditorUI: Constructor completed successfully"

        } catch {
            Write-Verbose "[ERROR] ConfigEditorUI: Constructor failed - $($_.Exception.Message)"
            Write-Verbose "[DEBUG] ConfigEditorUI: Exception type - $($_.Exception.GetType().Name)"
            if ($_.Exception.InnerException) {
                Write-Verbose "[DEBUG] ConfigEditorUI: Inner exception - $($_.Exception.InnerException.Message)"
            }
            Write-Verbose "[DEBUG] ConfigEditorUI: Stack trace - $($_.Exception.StackTrace)"
            throw
        }
    }

    <#
    .SYNOPSIS
        Initializes UI components and sets default values.
    #>
    [void]InitializeComponents() {
        try {
            Write-Verbose "[DEBUG] ConfigEditorUI: InitializeComponents started"
            $this.CurrentGameId = ""
            $this.CurrentAppId = ""
            # NOTE: Do NOT reset CurrentLanguage here - it was properly initialized in the constructor
            # from the localization object. Resetting it to "en" breaks language change detection.
            # $this.CurrentLanguage = "en"  # REMOVED - breaks HandleLanguageSelectionChanged()
            $this.HasUnsavedChanges = $false
            # messages are now passed in constructor
            $this.Window.DataContext = $this
            Write-Verbose "[OK] ConfigEditorUI: InitializeComponents completed - CurrentLanguage preserved: $($this.CurrentLanguage)"
        } catch {
            Write-Verbose "[ERROR] ConfigEditorUI: InitializeComponents failed - $($_.Exception.Message)"
            throw
        }
    }

    [void] InitializeNotificationTimer() {
        try {
            $this.NotificationTimer = New-Object System.Windows.Threading.DispatcherTimer
            $this.NotificationTimer.Interval = [TimeSpan]::FromSeconds(3)

            $overlay = $this.Window.FindName("NotificationOverlay")
            $timer = $this.NotificationTimer

            $this.NotificationTimer.add_Tick({
                    if ($overlay) {
                        $overlay.Visibility = ("System.Windows.Visibility" -as [type])::Collapsed
                    }
                    $timer.Stop()
                }.GetNewClosure())
        } catch {
            Write-Warning "[InitializeNotificationTimer] Failed to initialize notification timer: $($_.Exception.Message)"
        }
    }

    [void] ShowNotification([string]$Message, [string]$Type = "Info") {
        try {
            $overlay = $this.Window.FindName("NotificationOverlay")
            $textBlock = $this.Window.FindName("NotificationText")

            if (-not $overlay -or -not $textBlock) { return }

            $textBlock.Text = $Message

            switch ($Type) {
                "Error" {
                    $overlay.Background = ("System.Windows.Media.Brushes" -as [type])::White
                    $overlay.BorderBrush = ("System.Windows.Media.Brushes" -as [type])::Red
                    $textBlock.Foreground = ("System.Windows.Media.Brushes" -as [type])::Red
                }
                "Success" {
                    $overlay.Background = ("System.Windows.Media.Brushes" -as [type])::White
                    $overlay.BorderBrush = ("System.Windows.Media.Brushes" -as [type])::Green
                    $textBlock.Foreground = ("System.Windows.Media.Brushes" -as [type])::Green
                }
                default {
                    $overlay.Background = ("System.Windows.Media.Brushes" -as [type])::White
                    $overlay.BorderBrush = ("System.Windows.Media.Brushes" -as [type])::Black
                    $textBlock.Foreground = ("System.Windows.Media.Brushes" -as [type])::Black
                }
            }

            $overlay.Visibility = ("System.Windows.Visibility" -as [type])::Visible

            $this.NotificationTimer.Stop()
            $this.NotificationTimer.Start()
        } catch {
            Write-Warning "[ShowNotification] Error displaying notification: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Toggles error state for an input control.

    .DESCRIPTION
        Shows or hides an error message below an input control and updates the control's
        border styling to indicate validation errors. Error TextBlock must be named
        "{ControlName}ErrorText" by convention.

    .PARAMETER ControlName
        Name of the input control (TextBox, ComboBox, etc.)

    .PARAMETER Message
        Error message to display. If empty or null, clears the error state.

    .EXAMPLE
        $this.SetInputError("GameIdTextBox", "Game ID cannot be empty")
        $this.SetInputError("GameIdTextBox", "") # Clear error

    .NOTES
        Requires error TextBlock in XAML named "{ControlName}ErrorText"
    #>
    [void] SetInputError([string]$ControlName, [string]$Message) {
        try {
            $errorTextName = "${ControlName}ErrorText"

            $inputControl = $this.Window.FindName($ControlName)
            $errorTextBlock = $this.Window.FindName($errorTextName)

            if (-not $inputControl -or -not $errorTextBlock) {
                Write-Verbose "[SetInputError] Control '$ControlName' or error text '$errorTextName' not found"
                return
            }

            if ([string]::IsNullOrEmpty($Message)) {
                $errorTextBlock.Visibility = ("System.Windows.Visibility" -as [type])::Collapsed
                $inputControl.BorderBrush = ("System.Windows.Media.Brushes" -as [type])::Gray
                $inputControl.BorderThickness = ("System.Windows.Thickness" -as [type])::new(1)
                Write-Verbose "[SetInputError] Cleared error for '$ControlName'"
            } else {
                $errorTextBlock.Text = $Message
                $errorTextBlock.Visibility = ("System.Windows.Visibility" -as [type])::Visible
                $inputControl.BorderBrush = ("System.Windows.Media.Brushes" -as [type])::Red
                $inputControl.BorderThickness = ("System.Windows.Thickness" -as [type])::new(2)
                Write-Verbose "[SetInputError] Set error for '$ControlName': $Message"
            }
        } catch {
            Write-Warning "[SetInputError] Failed to set error state for '$ControlName': $($_.Exception.Message)"
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
    [double]MeasureButtonTextWidth([string]$Text, [Object]$Button) {
        if ([string]::IsNullOrEmpty($Text) -or -not $Button) { return 0 }
        try {
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = $Text
            $textBlock.FontFamily = $Button.FontFamily
            $textBlock.FontSize = $Button.FontSize
            $textBlock.FontWeight = $Button.FontWeight
            $textBlock.FontStyle = $Button.FontStyle
            $textBlock.Measure((New-Object System.Windows.Size([double]::PositiveInfinity, [double]::PositiveInfinity)))
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
    [void]SetButtonContentWithTooltip([Object]$Button, [string]$FullText) {
        if (-not $Button -or [string]::IsNullOrEmpty($FullText)) { return }
        try {
            $Button.Content = $FullText
            $Button.UpdateLayout()
            $Button.Dispatcher.Invoke("Background", [action] {})
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

            # Set placeholder for AppArgumentsTextBox
            Write-Verbose "Setting placeholder for AppArgumentsTextBox..."
            $appArgumentsTextBox = $this.Window.FindName("AppArgumentsTextBox")
            if ($appArgumentsTextBox -and $appArgumentsTextBox.Tag) {
                $placeholderKey = $appArgumentsTextBox.Tag -replace '^\[|\]$', ''
                $placeholderText = $this.GetLocalizedMessage($placeholderKey)
                if ($placeholderText -and $placeholderText -ne $placeholderKey) {
                    # Use a TextBlock as watermark/placeholder
                    Add-Type -AssemblyName PresentationFramework
                    $watermark = New-Object System.Windows.Controls.TextBlock
                    $watermark.Text = $placeholderText
                    $watermark.Foreground = "Gray"
                    $watermark.FontStyle = "Italic"
                    $watermark.VerticalAlignment = "Center"
                    $watermark.Margin = New-Object System.Windows.Thickness(5, 0, 0, 0)
                    $watermark.IsHitTestVisible = $false

                    # Set watermark visibility based on text content
                    $appArgumentsTextBox.add_TextChanged({
                            param($s, $e)
                            $watermark.Visibility = if ([string]::IsNullOrEmpty($s.Text)) {
                                "Visible"
                            } else {
                                "Hidden"
                            }
                        }.GetNewClosure())

                    # Add watermark to parent grid
                    $parent = $appArgumentsTextBox.Parent
                    if ($parent -and $parent.GetType() -eq "System.Windows.Controls.Grid") {
                        $gridType = $parent.GetType()

                        $row = $gridType::GetRow($appArgumentsTextBox)
                        $col = $gridType::GetColumn($appArgumentsTextBox)

                        $gridType::SetRow($watermark, $row)
                        $gridType::SetColumn($watermark, $col)

                        $parent.Children.Add($watermark) | Out-Null

                        # Set initial visibility
                        $watermark.Visibility = if ([string]::IsNullOrEmpty($appArgumentsTextBox.Text)) {
                            "Visible"
                        } else {
                            "Hidden"
                        }

                        Write-Verbose "Placeholder set for AppArgumentsTextBox: '$placeholderText'"
                    }
                }
            }

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
                            "TextBlock" {
                                if ($elementType -eq "Tooltip") {
                                    $propToSet = "ToolTip"
                                    $currentValue = $element.ToolTip
                                } else {
                                    $propToSet = "Text"
                                    $currentValue = $element.Text
                                }
                            }
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
        Checks for application updates asynchronously on startup.

    .DESCRIPTION
        Runs a non-blocking asynchronous update check when the application starts.
        If an update is available, displays a notification to the user with the option
        to download it. This method uses PowerShell Tasks to prevent UI freezing.

    .OUTPUTS
        None

    .NOTES
        This method is automatically called from LoadDataToUI and runs asynchronously
        to avoid blocking UI initialization. Uses the global Test-UpdateAvailable function
        if available through $global:TestUpdateAvailableFunc.
    #>
    [void]CheckUpdateOnStartup() {
        try {
            # Verify that required functions are available globally
            if (-not $global:GetProjectVersionFunc) {
                Write-Verbose "[CheckUpdateOnStartup] Get-ProjectVersion function not available, skipping startup update check"
                return
            }

            if (-not $global:TestUpdateAvailableFunc) {
                Write-Verbose "[CheckUpdateOnStartup] Test-UpdateAvailable function not available, skipping startup update check"
                return
            }

            Write-Verbose "[CheckUpdateOnStartup] Starting asynchronous update check on startup"

            # Create and start an async task for update checking
            $updateCheckTask = [System.Threading.Tasks.Task]::Run({
                    try {
                        # Capture necessary context for the task
                        $getVersionFunc = $using:global:GetProjectVersionFunc
                        $testUpdateFunc = $using:global:TestUpdateAvailableFunc

                        # Get current version
                        $currentVersion = & $getVersionFunc

                        Write-Verbose "[CheckUpdateOnStartup-Task] Current version: $currentVersion"

                        # Check for updates
                        $updateInfo = & $testUpdateFunc

                        if ($updateInfo -and $updateInfo.UpdateAvailable) {
                            Write-Verbose "[CheckUpdateOnStartup-Task] Update available: $($updateInfo.LatestVersion)"
                            return $updateInfo
                        } else {
                            Write-Verbose "[CheckUpdateOnStartup-Task] No update available"
                            return $null
                        }

                    } catch {
                        Write-Verbose "[CheckUpdateOnStartup-Task] Error during update check: $($_.Exception.Message)"
                        return $null
                    }
                })

            # Handle task completion without blocking UI
            $updateCheckTask.ContinueWith({
                    param($task)
                    try {
                        if ($task.IsCompletedSuccessfully) {
                            $updateInfo = $task.Result

                            if ($updateInfo) {
                                # Marshal back to UI thread for MessageBox
                                $this.Window.Dispatcher.Invoke([System.Action] {
                                        try {
                                            $message = $this.GetLocalizedMessage("updateAvailable") -f $updateInfo.LatestVersion, (& $global:GetProjectVersionFunc)
                                            $title = $this.GetLocalizedMessage("updateCheckTitle")

                                            $result = ("System.Windows.MessageBox" -as [type])::Show(
                                                $this.Window,
                                                $message,
                                                $title,
                                                "YesNo",
                                                "Question"
                                            )

                                            if ($result -eq "Yes") {
                                                if ($updateInfo.ReleaseUrl) {
                                                    Write-Verbose "[INFO] CheckUpdateOnStartup: Opening release page - $($updateInfo.ReleaseUrl)"
                                                    Start-Process $updateInfo.ReleaseUrl
                                                }
                                            }

                                            Write-Verbose "[CheckUpdateOnStartup] Update notification completed"

                                        } catch {
                                            Write-Verbose "[CheckUpdateOnStartup-UIThread] Error showing update notification: $($_.Exception.Message)"
                                        }
                                    })
                            }
                        } else {
                            Write-Verbose "[CheckUpdateOnStartup] Task did not complete successfully"
                        }

                    } catch {
                        Write-Verbose "[CheckUpdateOnStartup-Continuation] Error in task continuation: $($_.Exception.Message)"
                    }

                }) | Out-Null

        } catch {
            Write-Verbose "[CheckUpdateOnStartup] Error starting async update check: $($_.Exception.Message)"
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

            # Start automatic update check asynchronously (non-blocking)
            $this.CheckUpdateOnStartup()

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
                    ("System.Windows.Controls.Grid" -as [type])::SetColumn($infoPanel, 0)

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
                    ("System.Windows.Controls.Grid" -as [type])::SetColumn($launchButton, 1)

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
            Write-Verbose "[DEBUG] ConfigEditorUI: Starting UI cleanup"

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

            Write-Verbose "[OK] ConfigEditorUI: UI cleanup completed"
        } catch {
            Write-Verbose "[WARNING] ConfigEditorUI: Error during UI cleanup - $($_.Exception.Message)"
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

                $obsHostTextBox = $self.Window.FindName("OBSHostTextBox")
                if ($obsHostTextBox -and $ConfigData.integrations.obs.websocket) {
                    $obsHostTextBox.Text = $ConfigData.integrations.obs.websocket.host
                }

                $obsPortTextBox = $self.Window.FindName("OBSPortTextBox")
                if ($obsPortTextBox -and $ConfigData.integrations.obs.websocket) {
                    $obsPortTextBox.Text = $ConfigData.integrations.obs.websocket.port
                }

                $obsPasswordBox = $self.Window.FindName("OBSPasswordBox")
                if ($obsPasswordBox -and $ConfigData.integrations.obs.websocket) {
                    if ($ConfigData.integrations.obs.websocket.password) {
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
                                # use static property reference to string (type converter will handle)
                                $placeholderText.Foreground = "Gray"
                                $placeholderText.IsHitTestVisible = $false
                                $placeholderText.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
                                # use static property reference to string (type converter will handle)
                                $placeholderText.VerticalAlignment = "Center"

                                # Set Grid position to match PasswordBox
                                # use dynamic type resolution for static method calls
                                ("System.Windows.Controls.Grid" -as [type])::SetRow($placeholderText, ("System.Windows.Controls.Grid" -as [type])::GetRow($obsPasswordBox))
                                ("System.Windows.Controls.Grid" -as [type])::SetColumn($placeholderText, ("System.Windows.Controls.Grid" -as [type])::GetColumn($obsPasswordBox))

                                $passwordPanel.Children.Add($placeholderText) | Out-Null

                                # Add event handler to hide placeholder when user types
                                $obsPasswordBox.add_PasswordChanged({
                                        param($s, $e)
                                        $placeholder = $s.Parent.Children | Where-Object { $_.Name -eq "ObsPasswordPlaceholder" }
                                        if ($placeholder) {
                                            # use static property reference to string (type converter will handle)
                                            $placeholder.Visibility = if ($s.Password.Length -eq 0) {
                                                "Visible"
                                            } else {
                                                "Collapsed"
                                            }
                                        }
                                        # Clear SAVED tag when user starts typing
                                        if ($s.Password.Length -gt 0) {
                                            $s.Tag = $null
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

                $replayBufferCheckBox = $self.Window.FindName("OBSReplayBufferCheckBox")
                if ($replayBufferCheckBox -and $ConfigData.integrations.obs) {
                    $replayBufferCheckBox.IsChecked = [bool]$ConfigData.integrations.obs.replayBuffer
                }

                # Load OBS auto start/stop checkboxes based on gameStartAction/gameEndAction
                $obsAutoStartCheckBox = $self.Window.FindName("OBSAutoStartCheckBox")
                if ($obsAutoStartCheckBox -and $ConfigData.integrations.obs) {
                    $obsAutoStartCheckBox.IsChecked = ($ConfigData.integrations.obs.gameStartAction -eq "enter-game-mode")
                }

                $obsAutoStopCheckBox = $self.Window.FindName("OBSAutoStopCheckBox")
                if ($obsAutoStopCheckBox -and $ConfigData.integrations.obs) {
                    $obsAutoStopCheckBox.IsChecked = ($ConfigData.integrations.obs.gameEndAction -eq "exit-game-mode")
                }

                if ($ConfigData.paths) {
                    $steamPathTextBox = $self.Window.FindName("SteamPathTextBox")
                    if ($steamPathTextBox) { $steamPathTextBox.Text = $ConfigData.paths.steam }

                    $epicPathTextBox = $self.Window.FindName("EpicPathTextBox")
                    if ($epicPathTextBox) { $epicPathTextBox.Text = $ConfigData.paths.epic }

                    $riotPathTextBox = $self.Window.FindName("RiotPathTextBox")
                    if ($riotPathTextBox) { $riotPathTextBox.Text = $ConfigData.paths.riot }
                }

                if ($ConfigData.integrations.obs) {
                    $obsPathTextBox = $self.Window.FindName("OBSPathTextBox")
                    if ($obsPathTextBox) { $obsPathTextBox.Text = $ConfigData.integrations.obs.path }
                }

                # Load Discord settings
                if ($ConfigData.integrations.discord) {
                    $discordPathTextBox = $self.Window.FindName("DiscordPathTextBox")
                    if ($discordPathTextBox) {
                        $discordPathTextBox.Text = $ConfigData.integrations.discord.path
                        Write-Verbose "Loaded Discord path: $($ConfigData.integrations.discord.path)"
                    }

                    # Load Discord game mode checkbox based on gameStartAction
                    $enableGameModeCheckBox = $self.Window.FindName("DiscordEnableGameModeCheckBox")
                    if ($enableGameModeCheckBox) {
                        $enableGameModeCheckBox.IsChecked = ($ConfigData.integrations.discord.gameStartAction -eq "enter-game-mode")
                    }

                    $statusOnStartCombo = $self.Window.FindName("DiscordStatusOnStartCombo")
                    if ($statusOnStartCombo -and $ConfigData.integrations.discord.statusOnStart) {
                        for ($i = 0; $i -lt $statusOnStartCombo.Items.Count; $i++) {
                            if ($statusOnStartCombo.Items[$i].Tag -eq $ConfigData.integrations.discord.statusOnStart) {
                                $statusOnStartCombo.SelectedIndex = $i
                                break
                            }
                        }
                    }

                    $statusOnEndCombo = $self.Window.FindName("DiscordStatusOnEndCombo")
                    if ($statusOnEndCombo -and $ConfigData.integrations.discord.statusOnEnd) {
                        for ($i = 0; $i -lt $statusOnEndCombo.Items.Count; $i++) {
                            if ($statusOnEndCombo.Items[$i].Tag -eq $ConfigData.integrations.discord.statusOnEnd) {
                                $statusOnEndCombo.SelectedIndex = $i
                                break
                            }
                        }
                    }

                    $disableOverlayCheckBox = $self.Window.FindName("DiscordDisableOverlayCheckBox")
                    if ($disableOverlayCheckBox) {
                        $disableOverlayCheckBox.IsChecked = [bool]$ConfigData.integrations.discord.disableOverlay
                    }

                    # Load Rich Presence settings
                    if ($ConfigData.integrations.discord.rpc) {
                        $rpcEnableCheckBox = $self.Window.FindName("DiscordRPCEnableCheckBox")
                        if ($rpcEnableCheckBox) {
                            $rpcEnableCheckBox.IsChecked = [bool]$ConfigData.integrations.discord.rpc.enabled
                        }

                        $rpcAppIdTextBox = $self.Window.FindName("DiscordRPCAppIdTextBox")
                        if ($rpcAppIdTextBox) {
                            $rpcAppIdTextBox.Text = $ConfigData.integrations.discord.rpc.applicationId
                        }
                    }
                }

                # Load VTube Studio settings
                if ($ConfigData.integrations.vtubeStudio) {
                    $vtubePathTextBox = $self.Window.FindName("VTubePathTextBox")
                    if ($vtubePathTextBox) {
                        $vtubePathTextBox.Text = $ConfigData.integrations.vtubeStudio.path
                        Write-Verbose "Loaded VTube Studio path: $($ConfigData.integrations.vtubeStudio.path)"
                    }

                    # Load VTube Studio auto start/stop checkboxes based on gameStartAction/gameEndAction
                    $vtubeAutoStartCheckBox = $self.Window.FindName("VTubeAutoStartCheckBox")
                    if ($vtubeAutoStartCheckBox) {
                        $vtubeAutoStartCheckBox.IsChecked = ($ConfigData.integrations.vtubeStudio.gameStartAction -eq "enter-game-mode")
                    }

                    $vtubeAutoStopCheckBox = $self.Window.FindName("VTubeAutoStopCheckBox")
                    if ($vtubeAutoStopCheckBox) {
                        $vtubeAutoStopCheckBox.IsChecked = ($ConfigData.integrations.vtubeStudio.gameEndAction -eq "exit-game-mode")
                    }
                }

                $langCombo = $self.Window.FindName("LanguageCombo")
                if ($langCombo) {
                    # Disconnect SelectionChanged event during initialization
                    # This prevents HandleLanguageSelectionChanged from triggering during UI setup
                    # Note: Events are registered in ConfigEditor.ps1 AFTER LoadDataToUI is called
                    # But we need to ensure no events fire during the initial population

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

                    # IMPORTANT: Update UIManager.CurrentLanguage to match the config language
                    # This ensures consistency between the combobox selection and the CurrentLanguage property
                    # This must be done BEFORE events are registered
                    if ($ConfigData.language) {
                        $self.CurrentLanguage = $ConfigData.language
                        Write-Verbose "UIManager.CurrentLanguage updated to: $($self.CurrentLanguage)"
                    }
                }

                Write-Verbose "Language combo initialized - events will be registered after LoadDataToUI completes"

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
    [void]AddComboBoxActionItem([Object]$comboBox, [string]$content, [string]$tag) {
        try {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $content
            $item.Tag = $tag
            $comboBox.Items.Add($item) | Out-Null
        } catch {
            Write-Verbose "[ERROR] ConfigEditorUI: Error adding ComboBox item - $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
    Event handler for platform selection changes.
    .DESCRIPTION
    Updates game action combo boxes when the platform selection changes
    to show appropriate actions for the selected platform.
    .PARAMETER s
    The ComboBox that triggered the event.
    .PARAMETER e
    Selection changed event arguments.
    #>
    [void]OnPlatformSelectionChanged([object]$s, [Object]$e) {
        try {
            if ($s.SelectedItem -and $s.SelectedItem.Tag) {
                $selectedPlatform = $s.SelectedItem.Tag.ToString()
                $currentPermissions = $this.GetCurrentUserPermissions()
                $this.InitializeGameActionCombos($selectedPlatform, $currentPermissions)
            }
        } catch {
            Write-Verbose "[ERROR] ConfigEditorUI: Error handling platform selection change - $($_.Exception.Message)"
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
        Switches to the game settings tab and selects a specific game.

    .DESCRIPTION
        Navigates to the game settings tab and automatically selects the specified game
        for editing. Useful for programmatically opening game configuration.

    .PARAMETER GameId
        The ID of the game to select for editing

    .EXAMPLE
        $ui.SwitchToGameTab("valorant")

    .NOTES
        Assumes GamesList control exists and game ID is valid.
    #>
    [void]SwitchToGameTab([string]$GameId) {
        # Implementation would go here
    }

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

                # use MessageBox invocation to dynamic resolution and stringified Enum
                ("System.Windows.MessageBox" -as [type])::Show($message, $this.GetLocalizedMessage("error"), "OK", "Error")
            }

        } catch {
            Write-Warning "Failed to launch game '$GameId': $($_.Exception.Message)"

            # Show error message
            $errorMessage = $this.GetLocalizedMessage("launchFailed") -f $GameId, $_.Exception.Message

            # use MessageBox invocation to dynamic resolution and stringified Enum
            ("System.Windows.MessageBox" -as [type])::Show($errorMessage, $this.GetLocalizedMessage("launchError"), "OK", "Error")
        }
    }
}
