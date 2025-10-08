class ConfigEditorUI {
    # Properties
    [ConfigEditorState]$State
    [System.Windows.Window]$Window
    [string]$CurrentGameId
    [string]$CurrentAppId
    [string[]]$Messages
    [string]$CurrentLanguage
    [bool]$HasUnsavedChanges

    # Constructor
    ConfigEditorUI([ConfigEditorState]$state) {
        $this.State = $state
        $this.Window = $null
        $this.CurrentGameId = ""
        $this.CurrentAppId = ""
        $this.Messages = @()
        $this.CurrentLanguage = "en"
        $this.HasUnsavedChanges = $false
    }

    # Get localized message from messages array
    [string]GetLocalizedMessage([string]$Key, [array]$Arguments = @()) {
        if ($this.Messages -and $this.Messages.PSObject.Properties[$Key]) {
            $message = $this.Messages.$Key

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

    # Helper function to set button content with smart tooltip
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

    # Helper function to apply smart tooltips to all buttons
    [void]UpdateAllButtonTooltips() {
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
                "SaveGameSettingsButton"     = "saveButton"
                "SaveManagedAppsButton"      = "saveButton"
                "SaveGlobalSettingsButton"   = "saveButton"
            }

            # Apply smart tooltips to each button with full localized text
            Write-Verbose "Debug: Starting tooltip update for $($buttonMappings.Count) buttons"
            foreach ($buttonName in $buttonMappings.Keys) {
                $button = $this.Window.FindName($buttonName)
                if ($button) {
                    $messageKey = $buttonMappings[$buttonName]
                    $fullText = $this.GetLocalizedMessage($messageKey)
                    Write-Verbose "Debug: Processing button '$buttonName' with key '$messageKey' -> text '$fullText'"
                    $this.SetButtonContentWithTooltip($button, $fullText)
                } else {
                    Write-Verbose "Debug: Button '$buttonName' not found in window"
                }
            }

            Write-Verbose "Debug: Button tooltip update completed"
        } catch {
            Write-Warning "Failed to update button tooltips: $($_.Exception.Message)"
        }
    }

    # Update UI texts based on current language
    [void]UpdateUITexts([PSObject]$ConfigData) {
        try {
            # Update window title
            $this.Window.Title = $this.GetLocalizedMessage("windowTitle")

            # Update tab headers
            $this.Window.FindName("GamesTab").Header = $this.GetLocalizedMessage("gamesTabHeader")
            $this.Window.FindName("ManagedAppsTab").Header = $this.GetLocalizedMessage("managedAppsTabHeader")
            $this.Window.FindName("GlobalSettingsTab").Header = $this.GetLocalizedMessage("globalSettingsTabHeader")

            # Update buttons with smart tooltips
            $addGameButton = $this.Window.FindName("AddGameButton")
            if ($addGameButton) { $this.SetButtonContentWithTooltip($addGameButton, $this.GetLocalizedMessage("addButton")) }

            $duplicateGameButton = $this.Window.FindName("DuplicateGameButton")
            if ($duplicateGameButton) { $this.SetButtonContentWithTooltip($duplicateGameButton, $this.GetLocalizedMessage("duplicateButton")) }

            $deleteGameButton = $this.Window.FindName("DeleteGameButton")
            if ($deleteGameButton) { $this.SetButtonContentWithTooltip($deleteGameButton, $this.GetLocalizedMessage("deleteButton")) }

            $addAppButton = $this.Window.FindName("AddAppButton")
            if ($addAppButton) { $this.SetButtonContentWithTooltip($addAppButton, $this.GetLocalizedMessage("addButton")) }

            $duplicateAppButton = $this.Window.FindName("DuplicateAppButton")
            if ($duplicateAppButton) { $this.SetButtonContentWithTooltip($duplicateAppButton, $this.GetLocalizedMessage("duplicateButton")) }

            $deleteAppButton = $this.Window.FindName("DeleteAppButton")
            if ($deleteAppButton) { $this.SetButtonContentWithTooltip($deleteAppButton, $this.GetLocalizedMessage("deleteButton")) }

            $applyButton = $this.Window.FindName("ApplyButton")
            if ($applyButton) { $this.SetButtonContentWithTooltip($applyButton, $this.GetLocalizedMessage("applyButton")) }

            $okButton = $this.Window.FindName("OKButton")
            if ($okButton) { $this.SetButtonContentWithTooltip($okButton, $this.GetLocalizedMessage("okButton")) }

            $cancelButton = $this.Window.FindName("CancelButton")
            if ($cancelButton) { $this.SetButtonContentWithTooltip($cancelButton, $this.GetLocalizedMessage("cancelButton")) }

            # Update tab-specific Save buttons
            $saveGameSettingsButton = $this.Window.FindName("SaveGameSettingsButton")
            if ($saveGameSettingsButton) { $this.SetButtonContentWithTooltip($saveGameSettingsButton, $this.GetLocalizedMessage("saveButton")) }

            $saveManagedAppsButton = $this.Window.FindName("SaveManagedAppsButton")
            if ($saveManagedAppsButton) { $this.SetButtonContentWithTooltip($saveManagedAppsButton, $this.GetLocalizedMessage("saveButton")) }

            $saveGlobalSettingsButton = $this.Window.FindName("SaveGlobalSettingsButton")
            if ($saveGlobalSettingsButton) { $this.SetButtonContentWithTooltip($saveGlobalSettingsButton, $this.GetLocalizedMessage("saveButton")) }

            # Update labels - Games tab
            $gamesListLabel = $this.Window.FindName("GamesListLabel")
            if ($gamesListLabel) { $gamesListLabel.Content = $this.GetLocalizedMessage("gamesListLabel") }

            $gameDetailsLabel = $this.Window.FindName("GameDetailsLabel")
            if ($gameDetailsLabel) { $gameDetailsLabel.Content = $this.GetLocalizedMessage("gameDetailsLabel") }

            $gameIdLabel = $this.Window.FindName("GameIdLabel")
            if ($gameIdLabel) { $gameIdLabel.Content = $this.GetLocalizedMessage("gameIdLabel") }

            $gameNameLabel = $this.Window.FindName("GameNameLabel")
            if ($gameNameLabel) { $gameNameLabel.Content = $this.GetLocalizedMessage("gameNameLabel") }

            $platformLabel = $this.Window.FindName("PlatformLabel")
            if ($platformLabel) { $platformLabel.Content = $this.GetLocalizedMessage("platformLabel") }

            $steamAppIdLabel = $this.Window.FindName("SteamAppIdLabel")
            if ($steamAppIdLabel) { $steamAppIdLabel.Content = $this.GetLocalizedMessage("steamAppIdLabel") }

            $epicGameIdLabel = $this.Window.FindName("EpicGameIdLabel")
            if ($epicGameIdLabel) { $epicGameIdLabel.Content = $this.GetLocalizedMessage("epicGameIdLabel") }

            $riotGameIdLabel = $this.Window.FindName("RiotGameIdLabel")
            if ($riotGameIdLabel) { $riotGameIdLabel.Content = $this.GetLocalizedMessage("riotGameIdLabel") }

            $processNameLabel = $this.Window.FindName("ProcessNameLabel")
            if ($processNameLabel) { $processNameLabel.Content = $this.GetLocalizedMessage("processNameLabel") }

            $appsToManageLabel = $this.Window.FindName("AppsToManageLabel")
            if ($appsToManageLabel) { $appsToManageLabel.Content = $this.GetLocalizedMessage("appsToManageLabel") }

            # Update group boxes - Global Settings tab
            $obsSettingsGroup = $this.Window.FindName("ObsSettingsGroup")
            if ($obsSettingsGroup) { $obsSettingsGroup.Header = $this.GetLocalizedMessage("obsSettingsGroup") }

            $pathSettingsGroup = $this.Window.FindName("PathSettingsGroup")
            if ($pathSettingsGroup) { $pathSettingsGroup.Header = $this.GetLocalizedMessage("pathSettingsGroup") }

            $generalSettingsGroup = $this.Window.FindName("GeneralSettingsGroup")
            if ($generalSettingsGroup) { $generalSettingsGroup.Header = $this.GetLocalizedMessage("generalSettingsGroup") }

            # Update labels - Global Settings tab
            $hostLabel = $this.Window.FindName("HostLabel")
            if ($hostLabel) { $hostLabel.Content = $this.GetLocalizedMessage("hostLabel") }

            $portLabel = $this.Window.FindName("PortLabel")
            if ($portLabel) { $portLabel.Content = $this.GetLocalizedMessage("portLabel") }

            $passwordLabel = $this.Window.FindName("PasswordLabel")
            if ($passwordLabel) { $passwordLabel.Content = $this.GetLocalizedMessage("passwordLabel") }

            $replayBufferCheckBox = $this.Window.FindName("ReplayBufferCheckBox")
            if ($replayBufferCheckBox) { $replayBufferCheckBox.Content = $this.GetLocalizedMessage("replayBufferLabel") }

            $steamPathLabel = $this.Window.FindName("SteamPathLabel")
            if ($steamPathLabel) { $steamPathLabel.Content = $this.GetLocalizedMessage("steamPathLabel") }

            $epicPathLabel = $this.Window.FindName("EpicPathLabel")
            if ($epicPathLabel) { $epicPathLabel.Content = $this.GetLocalizedMessage("epicPathLabel") }

            $riotPathLabel = $this.Window.FindName("RiotPathLabel")
            if ($riotPathLabel) { $riotPathLabel.Content = $this.GetLocalizedMessage("riotPathLabel") }

            $obsPathLabel = $this.Window.FindName("ObsPathLabel")
            if ($obsPathLabel) { $obsPathLabel.Content = $this.GetLocalizedMessage("obsPathLabel") }

            $languageLabel = $this.Window.FindName("LanguageLabel")
            if ($languageLabel) { $languageLabel.Content = $this.GetLocalizedMessage("languageLabel") }

            # Update browse buttons with smart tooltips
            $browseSteamPathButton = $this.Window.FindName("BrowseSteamPathButton")
            if ($browseSteamPathButton) { $this.SetButtonContentWithTooltip($browseSteamPathButton, $this.GetLocalizedMessage("browseButton")) }

            $browseEpicPathButton = $this.Window.FindName("BrowseEpicPathButton")
            if ($browseEpicPathButton) { $this.SetButtonContentWithTooltip($browseEpicPathButton, $this.GetLocalizedMessage("browseButton")) }

            $browseRiotPathButton = $this.Window.FindName("BrowseRiotPathButton")
            if ($browseRiotPathButton) { $this.SetButtonContentWithTooltip($browseRiotPathButton, $this.GetLocalizedMessage("browseButton")) }

            $browseObsPathButton = $this.Window.FindName("BrowseObsPathButton")
            if ($browseObsPathButton) { $this.SetButtonContentWithTooltip($browseObsPathButton, $this.GetLocalizedMessage("browseButton")) }

            # Update labels - Managed Apps tab
            $appsListLabel = $this.Window.FindName("AppsListLabel")
            if ($appsListLabel) { $appsListLabel.Content = $this.GetLocalizedMessage("appsListLabel") }

            $appDetailsLabel = $this.Window.FindName("AppDetailsLabel")
            if ($appDetailsLabel) { $appDetailsLabel.Content = $this.GetLocalizedMessage("appDetailsLabel") }

            $appIdLabel = $this.Window.FindName("AppIdLabel")
            if ($appIdLabel) { $appIdLabel.Content = $this.GetLocalizedMessage("appIdLabel") }

            $appPathLabel = $this.Window.FindName("AppPathLabel")
            if ($appPathLabel) { $appPathLabel.Content = $this.GetLocalizedMessage("appPathLabel") }

            $appProcessNameLabel = $this.Window.FindName("AppProcessNameLabel")
            if ($appProcessNameLabel) { $appProcessNameLabel.Content = $this.GetLocalizedMessage("processNameLabel") }

            $gameStartActionLabel = $this.Window.FindName("GameStartActionLabel")
            if ($gameStartActionLabel) { $gameStartActionLabel.Content = $this.GetLocalizedMessage("gameStartActionLabel") }

            $gameEndActionLabel = $this.Window.FindName("GameEndActionLabel")
            if ($gameEndActionLabel) { $gameEndActionLabel.Content = $this.GetLocalizedMessage("gameEndActionLabel") }

            $appArgumentsLabel = $this.Window.FindName("AppArgumentsLabel")
            if ($appArgumentsLabel) { $appArgumentsLabel.Content = $this.GetLocalizedMessage("argumentsLabel") }

            $terminationMethodLabel = $this.Window.FindName("TerminationMethodLabel")
            if ($terminationMethodLabel) { $terminationMethodLabel.Content = $this.GetLocalizedMessage("terminationMethodLabel") }

            $gracefulTimeoutLabel = $this.Window.FindName("GracefulTimeoutLabel")
            if ($gracefulTimeoutLabel) { $gracefulTimeoutLabel.Content = $this.GetLocalizedMessage("gracefulTimeoutLabel") }

            $browseAppPathButton = $this.Window.FindName("BrowseAppPathButton")
            if ($browseAppPathButton) { $this.SetButtonContentWithTooltip($browseAppPathButton, $this.GetLocalizedMessage("browseButton")) }

            $browseExecutablePathButton = $this.Window.FindName("BrowseExecutablePathButton")
            if ($browseExecutablePathButton) { $this.SetButtonContentWithTooltip($browseExecutablePathButton, $this.GetLocalizedMessage("browseButton")) }

            # Update version and update-related texts
            $versionLabel = $this.Window.FindName("VersionLabel")
            if ($versionLabel) { $versionLabel.Text = $this.GetLocalizedMessage("versionLabel") }

            # Update launcher-related labels and buttons
            $launcherTypeLabel = $this.Window.FindName("LauncherTypeLabel")
            if ($launcherTypeLabel) { $launcherTypeLabel.Content = $this.GetLocalizedMessage("launcherTypeLabel") }

            $generateLaunchersButton = $this.Window.FindName("GenerateLaunchersButton")
            if ($generateLaunchersButton) { $this.SetButtonContentWithTooltip($generateLaunchersButton, $this.GetLocalizedMessage("generateLaunchers")) }

            $launcherHelpText = $this.Window.FindName("LauncherHelpText")
            if ($launcherHelpText) { $launcherHelpText.Text = $this.GetLocalizedMessage("launcherHelpText") }

            # Update log retention label
            $logRetentionLabel = $this.Window.FindName("LogRetentionLabel")
            if ($logRetentionLabel) { $logRetentionLabel.Content = $this.GetLocalizedMessage("logRetentionLabel") }

            # Update log notarization checkbox
            $enableLogNotarizationCheckBox = $this.Window.FindName("EnableLogNotarizationCheckBox")
            if ($enableLogNotarizationCheckBox) { $enableLogNotarizationCheckBox.Content = $this.GetLocalizedMessage("enableLogNotarization") }

            # Update smart tooltips after text changes
            $this.UpdateAllButtonTooltips()

            Write-Verbose "UI texts updated for language: $($this.CurrentLanguage)"
        } catch {
            Write-Warning "Failed to update UI texts: $($_.Exception.Message)"
        }
    }

    # Initialize version display
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

    # Load data into UI controls
    [void]LoadDataToUI([PSObject]$ConfigData, [scriptblock]$LoadGlobalSettingsCallback) {
        # Load global settings first (this may update the current language)
        # This is handled by callback since it's data layer responsibility
        if ($LoadGlobalSettingsCallback) {
            & $LoadGlobalSettingsCallback
        }

        # Update UI text with current language (after global settings are loaded)
        $this.UpdateUITexts($ConfigData)

        # Load games list
        $this.UpdateGamesList($ConfigData)

        # Load managed apps list
        $this.UpdateManagedAppsList($ConfigData)

        # Initialize game launcher list
        $this.UpdateGameLauncherList($ConfigData)

        # Initialize launcher tab status texts
        $this.InitializeLauncherTabTexts()

        # Initialize version display
        $this.InitializeVersionDisplay()
    }

    # Update games list
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

            # Auto-select the first game if games exist
            if ($gamesList.Items.Count -gt 0) {
                $gamesList.SelectedIndex = 0
                # Note: Manual trigger of selection changed event should be handled externally
            }
        }
    }

    # Update managed apps list
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

            # Auto-select the first app if apps exist
            if ($managedAppsList.Items.Count -gt 0) {
                $managedAppsList.SelectedIndex = 0
                # Note: Manual trigger of selection changed event should be handled externally
            }
        }
    }

    # Update game launcher list
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

    # Initialize launcher tab texts
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
}
