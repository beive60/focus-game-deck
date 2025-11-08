class ConfigEditorEvents {
    $uiManager
    $stateManager

    ConfigEditorEvents($ui, $state) {
        $this.uiManager = $ui
        $this.stateManager = $state
    }

    # Helper method to set ComboBox selection by matching Tag property
    [void] SetComboBoxSelectionByTag([System.Windows.Controls.ComboBox]$ComboBox, [string]$TagValue) {
        if (-not $ComboBox) {
            Write-Warning "ComboBox is null, cannot set selection"
            return
        }

        try {
            # Find the ComboBoxItem with matching Tag
            $matchingItem = $null
            foreach ($item in $ComboBox.Items) {
                if ($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Tag -eq $TagValue) {
                    $matchingItem = $item
                    break
                }
            }

            if ($matchingItem) {
                $ComboBox.SelectedItem = $matchingItem
                Write-Verbose "Set ComboBox selection to Tag: $TagValue"
            } else {
                Write-Verbose "No ComboBoxItem found with Tag: $TagValue in ComboBox: $($ComboBox.Name)"
                $ComboBox.SelectedIndex = -1
            }
        } catch {
            Write-Warning "Failed to set ComboBox selection: $($_.Exception.Message)"
        }
    }

    # Helper method to update TerminationMethod ComboBox enabled state
    # Should be enabled only when either start or end action is "stop-process"
    [void] UpdateTerminationMethodState() {
        $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
        $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
        $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
        $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")

        if (-not $terminationMethodCombo) {
            Write-Verbose "TerminationMethodCombo not found"
            return
        }

        # Get selected actions
        $startAction = if ($gameStartActionCombo -and $gameStartActionCombo.SelectedItem) {
            $gameStartActionCombo.SelectedItem.Tag
        } else {
            "none"
        }

        $endAction = if ($gameEndActionCombo -and $gameEndActionCombo.SelectedItem) {
            $gameEndActionCombo.SelectedItem.Tag
        } else {
            "none"
        }

        # Enable only if either action is "stop-process"
        $shouldEnable = ($startAction -eq "stop-process") -or ($endAction -eq "stop-process")
        
        # Store current selection before disabling
        if (-not $shouldEnable -and $terminationMethodCombo.SelectedItem) {
            # Save the current selection
            if (-not $script:SavedTerminationMethod) {
                $script:SavedTerminationMethod = $terminationMethodCombo.SelectedItem.Tag
            }
            # Clear selection when disabled
            $terminationMethodCombo.SelectedIndex = -1
        } elseif ($shouldEnable -and $terminationMethodCombo.SelectedIndex -eq -1) {
            # Restore saved selection when re-enabled, or use default
            $savedValue = if ($script:SavedTerminationMethod) { 
                $script:SavedTerminationMethod 
            } else { 
                "auto" 
            }
            $this.SetComboBoxSelectionByTag($terminationMethodCombo, $savedValue)
        }
        
        $terminationMethodCombo.IsEnabled = $shouldEnable
        if ($gracefulTimeoutTextBox) {
            $gracefulTimeoutTextBox.IsEnabled = $shouldEnable
        }

        Write-Verbose "TerminationMethod enabled: $shouldEnable (StartAction: $startAction, EndAction: $endAction)"
    }

    # Handle platform selection changed
    [void] HandlePlatformSelectionChanged() {
        $platformCombo = $script:Window.FindName("PlatformComboBox")
        if ($platformCombo.SelectedItem -and $platformCombo.SelectedItem.Tag) {
            $selectedPlatform = $platformCombo.SelectedItem.Tag
            Update-PlatformFields -Platform $selectedPlatform
        }
    }

    # Handle game selection changed
    [void] HandleGameSelectionChanged() {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if ($selectedGame) {
            $script:CurrentGameId = $selectedGame
            $gameData = $this.stateManager.ConfigData.games.$selectedGame

            Write-Verbose "HandleGameSelectionChanged: Selected game = $selectedGame"
            
            if ($gameData) {
                Write-Verbose "HandleGameSelectionChanged: Game data found for $selectedGame"
                Write-Verbose "  - name: $($gameData.name)"
                Write-Verbose "  - platform: $($gameData.platform)"
                Write-Verbose "  - steamAppId: $($gameData.steamAppId)"
                Write-Verbose "  - executablePath: $($gameData.executablePath)"
                
                # Load game details into form
                $gameNameTextBox = $script:Window.FindName("GameNameTextBox")
                if ($gameNameTextBox) { 
                    # Check for both 'name' and 'displayName' for compatibility
                    $displayName = if ($gameData.name) { $gameData.name } elseif ($gameData.displayName) { $gameData.displayName } else { "" }
                    $gameNameTextBox.Text = $displayName
                    Write-Verbose "  Set GameNameTextBox: $displayName"
                }
                
                $gameIdTextBox = $script:Window.FindName("GameIdTextBox")
                if ($gameIdTextBox) { 
                    $appId = if ($gameData.appId) { $gameData.appId } else { $selectedGame }
                    $gameIdTextBox.Text = $appId
                    Write-Verbose "  Set GameIdTextBox: $appId"
                }
                
                $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
                if ($steamAppIdTextBox) { 
                    $steamAppIdTextBox.Text = if ($gameData.steamAppId) { $gameData.steamAppId } else { "" } 
                    Write-Verbose "  Set SteamAppIdTextBox: $($gameData.steamAppId)"
                }
                
                $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
                if ($epicGameIdTextBox) { 
                    $epicGameIdTextBox.Text = if ($gameData.epicGameId) { $gameData.epicGameId } else { "" }
                    Write-Verbose "  Set EpicGameIdTextBox: $($gameData.epicGameId)"
                }
                
                $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
                if ($riotGameIdTextBox) { 
                    $riotGameIdTextBox.Text = if ($gameData.riotGameId) { $gameData.riotGameId } else { "" }
                    Write-Verbose "  Set RiotGameIdTextBox: $($gameData.riotGameId)"
                }
                
                $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
                if ($executablePathTextBox) { 
                    $executablePathTextBox.Text = if ($gameData.executablePath) { $gameData.executablePath } else { "" }
                    Write-Verbose "  Set ExecutablePathTextBox: $($gameData.executablePath)"
                }

                # Set process name
                $processNameTextBox = $script:Window.FindName("ProcessNameTextBox")
                if ($processNameTextBox) {
                    $processNameTextBox.Text = if ($gameData.processName) { $gameData.processName } else { "" }
                    Write-Verbose "  Set ProcessNameTextBox: $($gameData.processName)"
                }

                # Set platform
                $platformCombo = $script:Window.FindName("PlatformComboBox")
                # Normalize platform value: "direct" is an alias for "standalone"
                $platform = if ($gameData.platform) { 
                    if ($gameData.platform -eq "direct") { "standalone" } else { $gameData.platform }
                } else { 
                    "standalone" 
                }
                
                Write-Verbose "  Platform: $platform (original: $($gameData.platform))"
                
                $platformFound = $false
                for ($i = 0; $i -lt $platformCombo.Items.Count; $i++) {
                    if ($platformCombo.Items[$i].Tag -eq $platform) {
                        $platformCombo.SelectedIndex = $i
                        $platformFound = $true
                        Write-Verbose "  Set PlatformComboBox to index $i ($platform)"
                        break
                    }
                }
                
                if (-not $platformFound) {
                    Write-Warning "Platform '$platform' not found in ComboBox, defaulting to standalone (index 0)"
                    $platformCombo.SelectedIndex = 0
                }

                # Update platform-specific fields
                Update-PlatformFields -Platform $platform

                # Update available actions for this game
                $appId = if ($gameData.appId) { $gameData.appId } else { $selectedGame }
                $executablePath = if ($gameData.executablePath) { $gameData.executablePath } else { "" }
                Update-ActionComboBoxes -AppId $appId -ExecutablePath $executablePath

                # Load managed apps settings
                $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
                $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

                $gameStartAction = if ($gameData.managedApps.gameStartAction) { $gameData.managedApps.gameStartAction } else { "none" }
                $gameEndAction = if ($gameData.managedApps.gameEndAction) { $gameData.managedApps.gameEndAction } else { "none" }
                $this.SetComboBoxSelectionByTag($gameStartActionCombo, $gameStartAction)
                $this.SetComboBoxSelectionByTag($gameEndActionCombo, $gameEndAction)

                # Load termination settings
                $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
                $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")

                if ($terminationMethodCombo) {
                    $terminationMethod = if ($gameData.managedApps.terminationMethod) { $gameData.managedApps.terminationMethod } else { "auto" }
                    # Clear saved value and set the actual value from config
                    $script:SavedTerminationMethod = $terminationMethod
                    $this.SetComboBoxSelectionByTag($terminationMethodCombo, $terminationMethod)
                }
                
                if ($gracefulTimeoutTextBox) {
                    $gracefulTimeoutTextBox.Text = if ($gameData.managedApps.gracefulTimeout) { $gameData.managedApps.gracefulTimeout.ToString() } else { "5" }
                }

                # Update termination settings visibility
                Update-TerminationSettingsVisibility

                # Update termination method enabled state based on selected actions
                $this.UpdateTerminationMethodState()

                # Update apps to manage panel with current game's app list
                Update-AppsToManagePanel

                # Enable buttons
                $duplicateGameButton = $script:Window.FindName("DuplicateGameButton")
                if ($duplicateGameButton) { $duplicateGameButton.IsEnabled = $true }
                
                $deleteGameButton = $script:Window.FindName("DeleteGameButton")
                if ($deleteGameButton) { $deleteGameButton.IsEnabled = $true }

                # Update move button states
                Update-MoveButtonStates

                Write-Verbose "Loaded game data for: $selectedGame"
            }
        } else {
            # No game selected, clear the form
            $script:CurrentGameId = ""
            
            $gameNameTextBox = $script:Window.FindName("GameNameTextBox")
            if ($gameNameTextBox) { $gameNameTextBox.Text = "" }
            
            $gameIdTextBox = $script:Window.FindName("GameIdTextBox")
            if ($gameIdTextBox) { $gameIdTextBox.Text = "" }
            
            $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
            if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
            
            $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
            if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
            
            $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
            if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
            
            $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
            if ($executablePathTextBox) { $executablePathTextBox.Text = "" }

            # Reset process name
            $processNameTextBox = $script:Window.FindName("ProcessNameTextBox")
            if ($processNameTextBox) { $processNameTextBox.Text = "" }

            # Reset platform to standalone
            $platformCombo = $script:Window.FindName("PlatformComboBox")
            if ($platformCombo) {
                $platformCombo.SelectedIndex = 0
                Update-PlatformFields -Platform "standalone"
            }

            # Reset action combos
            $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
            $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
            if ($gameStartActionCombo) { $this.SetComboBoxSelectionByTag($gameStartActionCombo, "none") }
            if ($gameEndActionCombo) { $this.SetComboBoxSelectionByTag($gameEndActionCombo, "none") }

            # Reset termination settings
            $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
            $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
            if ($terminationMethodCombo) { $this.SetComboBoxSelectionByTag($terminationMethodCombo, "auto") }
            if ($gracefulTimeoutTextBox) { $gracefulTimeoutTextBox.Text = "5" }

            # Update termination settings visibility
            Update-TerminationSettingsVisibility

            # Disable buttons
            $duplicateGameButton = $script:Window.FindName("DuplicateGameButton")
            if ($duplicateGameButton) { $duplicateGameButton.IsEnabled = $false }
            
            $deleteGameButton = $script:Window.FindName("DeleteGameButton")
            if ($deleteGameButton) { $deleteGameButton.IsEnabled = $false }

            # Update move button states
            Update-MoveButtonStates
        }
    }

    # Handle managed app selection changed
    [void] HandleAppSelectionChanged() {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if ($selectedApp) {
            $script:CurrentAppId = $selectedApp
            $appData = $this.stateManager.ConfigData.managedApps.$selectedApp

            Write-Verbose "HandleAppSelectionChanged: Selected app = $selectedApp"
            
            if ($appData) {
                Write-Verbose "HandleAppSelectionChanged: App data found for $selectedApp"
                Write-Verbose "  - displayName: $($appData.displayName)"
                Write-Verbose "  - processName: $($appData.processName)"
                Write-Verbose "  - path: $($appData.path)"
                Write-Verbose "  - gameStartAction: $($appData.gameStartAction)"
                Write-Verbose "  - gameEndAction: $($appData.gameEndAction)"
                Write-Verbose "  - terminationMethod: $($appData.terminationMethod)"
                Write-Verbose "  - gracefulTimeoutMs: $($appData.gracefulTimeoutMs)"
                
                # Load app details into form
                $appIdTextBox = $script:Window.FindName("AppIdTextBox")
                if ($appIdTextBox) {
                    $appIdTextBox.Text = if ($appData.displayName) { $appData.displayName } else { $selectedApp }
                }
                
                $appProcessNameTextBox = $script:Window.FindName("AppProcessNameTextBox")
                if ($appProcessNameTextBox) {
                    # Check for both processName (singular) and processNames (plural) for compatibility
                    $processNameValue = if ($appData.processNames) {
                        if ($appData.processNames -is [array]) {
                            $appData.processNames -join "|"
                        } else {
                            $appData.processNames
                        }
                    } elseif ($appData.processName) {
                        $appData.processName
                    } else {
                        ""
                    }
                    $appProcessNameTextBox.Text = $processNameValue
                }

                # Set ComboBox selections using helper function to find matching ComboBoxItem by Tag
                # NOTE: Managed Apps tab uses same ComboBox controls as Game tab
                $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
                $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
                
                if ($gameStartActionCombo) {
                    # Check for both startAction and gameStartAction for compatibility
                    $appStartAction = if ($appData.startAction) { 
                        $appData.startAction 
                    } elseif ($appData.gameStartAction) { 
                        $appData.gameStartAction 
                    } else { 
                        "start-process" 
                    }
                    $this.SetComboBoxSelectionByTag($gameStartActionCombo, $appStartAction)
                }
                
                if ($gameEndActionCombo) {
                    # Check for both endAction and gameEndAction for compatibility
                    $appEndAction = if ($appData.endAction) { 
                        $appData.endAction 
                    } elseif ($appData.gameEndAction) { 
                        $appData.gameEndAction 
                    } else { 
                        "stop-process" 
                    }
                    $this.SetComboBoxSelectionByTag($gameEndActionCombo, $appEndAction)
                }
                
                $appPathTextBox = $script:Window.FindName("AppPathTextBox")
                if ($appPathTextBox) {
                    # Check for both executablePath and path for compatibility
                    $pathValue = if ($appData.executablePath) { 
                        $appData.executablePath 
                    } elseif ($appData.path) { 
                        $appData.path 
                    } else { 
                        "" 
                    }
                    $appPathTextBox.Text = $pathValue
                }

                # Load arguments
                $appArgumentsTextBox = $script:Window.FindName("AppArgumentsTextBox")
                if ($appArgumentsTextBox) {
                    $appArgumentsTextBox.Text = if ($appData.arguments) { $appData.arguments } else { "" }
                }

                # Load termination settings
                $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
                if ($terminationMethodCombo) {
                    $appTerminationMethod = if ($appData.terminationMethod) { $appData.terminationMethod } else { "auto" }
                    # Clear saved value and set the actual value from config
                    $script:SavedTerminationMethod = $appTerminationMethod
                    $this.SetComboBoxSelectionByTag($terminationMethodCombo, $appTerminationMethod)
                }
                
                $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
                if ($gracefulTimeoutTextBox) {
                    # Check for both gracefulTimeout and gracefulTimeoutMs for compatibility
                    $timeoutValue = if ($appData.gracefulTimeout) { 
                        $appData.gracefulTimeout.ToString() 
                    } elseif ($appData.gracefulTimeoutMs) { 
                        # Convert milliseconds to seconds for display
                        ([int]($appData.gracefulTimeoutMs / 1000)).ToString()
                    } else { 
                        "5" 
                    }
                    $gracefulTimeoutTextBox.Text = $timeoutValue
                }

                # Enable buttons
                $duplicateAppButton = $script:Window.FindName("DuplicateAppButton")
                if ($duplicateAppButton) { $duplicateAppButton.IsEnabled = $true }
                
                $deleteAppButton = $script:Window.FindName("DeleteAppButton")
                if ($deleteAppButton) { $deleteAppButton.IsEnabled = $true }

                # Update move button states
                Update-MoveAppButtonStates

                # Update termination method enabled state based on selected actions
                $this.UpdateTerminationMethodState()

                Write-Verbose "Loaded app data for: $selectedApp"
            }
        } else {
            # No app selected, clear the form
            $script:CurrentAppId = ""
            
            $appIdTextBox = $script:Window.FindName("AppIdTextBox")
            if ($appIdTextBox) { $appIdTextBox.Text = "" }
            
            $appProcessNameTextBox = $script:Window.FindName("AppProcessNameTextBox")
            if ($appProcessNameTextBox) { $appProcessNameTextBox.Text = "" }
            
            $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
            if ($gameStartActionCombo) { $this.SetComboBoxSelectionByTag($gameStartActionCombo, "start-process") }
            
            $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
            if ($gameEndActionCombo) { $this.SetComboBoxSelectionByTag($gameEndActionCombo, "stop-process") }
            
            $appPathTextBox = $script:Window.FindName("AppPathTextBox")
            if ($appPathTextBox) { $appPathTextBox.Text = "" }
            
            $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
            if ($terminationMethodCombo) { $this.SetComboBoxSelectionByTag($terminationMethodCombo, "auto") }
            
            $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
            if ($gracefulTimeoutTextBox) { $gracefulTimeoutTextBox.Text = "5" }

            # Disable buttons
            $duplicateAppButton = $script:Window.FindName("DuplicateAppButton")
            if ($duplicateAppButton) { $duplicateAppButton.IsEnabled = $false }
            
            $deleteAppButton = $script:Window.FindName("DeleteAppButton")
            if ($deleteAppButton) { $deleteAppButton.IsEnabled = $false }

            # Update move button states
            Update-MoveAppButtonStates
        }
    }

    # Handle add game
    [void] HandleAddGame() {
        $newGameId = New-UniqueConfigId -Prefix "game-" -Collection $this.stateManager.ConfigData.games

        # Create new game with default values
        $newGame = @{
            displayName = "New Game"
            platform    = "standalone"
            appId       = $newGameId
            managedApps = @{
                gameStartAction   = "none"
                gameEndAction     = "none"
                terminationMethod = "auto"
                gracefulTimeout   = 5
            }
        }

        # Add to configuration
        if (-not $this.stateManager.ConfigData.games) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "games" -NotePropertyValue @{}
        }
        $this.stateManager.ConfigData.games | Add-Member -NotePropertyName $newGameId -NotePropertyValue $newGame

        # Initialize/update games order
        $this.stateManager.InitializeGameOrder()

        # Refresh games list
        $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

        # Select the new game
        $gamesList = $script:Window.FindName("GamesList")
        for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
            if ($gamesList.Items[$i] -eq $newGameId) {
                $gamesList.SelectedIndex = $i
                break
            }
        }

        # Mark as modified
        $this.stateManager.SetModified()

        Show-SafeMessage -Key "gameAdded" -MessageType "Information"
        Write-Verbose "Added new game: $newGameId"
    }

    # Handle duplicate game
    [void] HandleDuplicateGame() {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not (Test-DuplicateSource -SelectedItem $selectedGame -SourceData $this.stateManager.ConfigData.games.$selectedGame -ItemType "Game")) {
            return
        }

        try {
            # Generate unique ID for the duplicated game
            $newGameId = New-UniqueConfigId -Prefix "game-" -Collection $this.stateManager.ConfigData.games

            # Deep copy the selected game data
            $originalGameData = $this.stateManager.ConfigData.games.$selectedGame
            $duplicatedGameData = $originalGameData | ConvertTo-Json -Depth 10 | ConvertFrom-Json

            # Modify the display name to indicate it's a copy
            $originalDisplayName = if ($duplicatedGameData.displayName) { $duplicatedGameData.displayName } else { $selectedGame }
            $duplicatedGameData.displayName = "$originalDisplayName (Copy)"

            # Update appId to match the new game ID
            $duplicatedGameData.appId = $newGameId

            # Add to configuration
            $this.stateManager.ConfigData.games | Add-Member -NotePropertyName $newGameId -NotePropertyValue $duplicatedGameData

            # Initialize/update games order
            $this.stateManager.InitializeGameOrder()

            # Refresh games list and apps to manage panel
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)
            Update-AppsToManagePanel

            # Select the new duplicated game
            $gamesList = $script:Window.FindName("GamesList")
            for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
                if ($gamesList.Items[$i] -eq $newGameId) {
                    $gamesList.SelectedIndex = $i
                    break
                }
            }



            Show-DuplicateResult -Success $true -ItemType "Game" -OriginalId $selectedGame -NewId $newGameId

        } catch {
            Write-Error "Failed to duplicate game: $_"
            Show-DuplicateResult -Success $false -ItemType "Game" -OriginalId $selectedGame
        }
    }

    # Handle delete game
    [void] HandleDeleteGame() {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not $selectedGame) {
            Show-SafeMessage -Key "noGameSelected" -MessageType "Warning"
            return
        }

        $gameDisplayName = if ($this.stateManager.ConfigData.games.$selectedGame.displayName) {
            $this.stateManager.ConfigData.games.$selectedGame.displayName
        } else {
            $selectedGame
        }

        $result = Show-SafeMessage -Key "confirmDeleteGame" -MessageType "Question" -Button "YesNo" -DefaultResult "No" -FormatArgs @($gameDisplayName)

        if ($result -eq "Yes") {
            # Remove from configuration
            $this.stateManager.ConfigData.games.PSObject.Properties.Remove($selectedGame)

            # Update games order
            if ($this.stateManager.ConfigData.games._order -and $selectedGame -in $this.stateManager.ConfigData.games._order) {
                $this.stateManager.ConfigData.games._order = $this.stateManager.ConfigData.games._order | Where-Object { $_ -ne $selectedGame }
            }

            # Refresh games list and apps to manage panel
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)
            Update-AppsToManagePanel



            Show-SafeMessage -Key "gameDeleted" -MessageType "Information"
            Write-Verbose "Deleted game: $selectedGame"
        }
    }

    # Handle move game
    [void] HandleMoveGame([string]$Direction) {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not $selectedGame) {
            Show-SafeMessage -Key "noGameSelected" -MessageType "Warning"
            return
        }

        # Ensure games order exists
        if (-not $this.stateManager.ConfigData.games._order) {
            $this.stateManager.InitializeGameOrder()
        }

        $currentOrder = $this.stateManager.ConfigData.games._order
        $currentIndex = $currentOrder.IndexOf($selectedGame)

        if ($currentIndex -eq -1) {
            Write-Warning "Selected game not found in order array"
            return
        }

        $newIndex = $currentIndex
        switch ($Direction) {
            "Top" { $newIndex = 0 }
            "Up" { $newIndex = [Math]::Max(0, $currentIndex - 1) }
            "Down" { $newIndex = [Math]::Min($currentOrder.Count - 1, $currentIndex + 1) }
            "Bottom" { $newIndex = $currentOrder.Count - 1 }
        }

        # Only proceed if position actually changes
        if ($newIndex -ne $currentIndex) {
            # Create a new array with the item moved
            $newOrder = @($currentOrder)
            $gameToMove = $newOrder[$currentIndex]
            $newOrder = $newOrder | Where-Object { $_ -ne $gameToMove }

            # Insert at new position
            if ($newIndex -eq 0) {
                $newOrder = @($gameToMove) + $newOrder
            } elseif ($newIndex -ge $newOrder.Count) {
                $newOrder = $newOrder + @($gameToMove)
            } else {
                $beforeItems = $newOrder[0..($newIndex - 1)]
                $afterItems = $newOrder[$newIndex..($newOrder.Count - 1)]
                $newOrder = $beforeItems + @($gameToMove) + $afterItems
            }

            # Update the configuration
            $this.stateManager.ConfigData.games._order = $newOrder

            # Refresh the games list
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

            # Restore selection
            $gamesList = $script:Window.FindName("GamesList")
            for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
                if ($gamesList.Items[$i] -eq $selectedGame) {
                    $gamesList.SelectedIndex = $i
                    break
                }
            }



            Write-Verbose "Moved game '$selectedGame' $Direction (from index $currentIndex to $newIndex)"
        }
    }

    # Handle add app
    [void] HandleAddApp() {
        $newAppId = New-UniqueConfigId -Prefix "app-" -Collection $this.stateManager.ConfigData.managedApps

        # Create new app with default values
        $newApp = @{
            displayName       = "New App"
            processNames      = @("notepad.exe")
            startAction       = "start-process"
            endAction         = "stop-process"
            terminationMethod = "auto"
            gracefulTimeout   = 5
        }

        # Add to configuration
        if (-not $this.stateManager.ConfigData.managedApps) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "managedApps" -NotePropertyValue @{}
        }
        $this.stateManager.ConfigData.managedApps | Add-Member -NotePropertyName $newAppId -NotePropertyValue $newApp

        # Initialize/update apps order
        $this.stateManager.InitializeAppOrder()

        # Refresh managed apps list and apps to manage panel
        $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)
        Update-AppsToManagePanel

        # Select the new app
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
            if ($managedAppsList.Items[$i] -eq $newAppId) {
                $managedAppsList.SelectedIndex = $i
                break
            }
        }

        # Mark as modified
        Set-ConfigModified

        Show-SafeMessage -Key "appAdded" -MessageType "Information"
        Write-Verbose "Added new app: $newAppId"
    }

    # Handle duplicate app
    [void] HandleDuplicateApp() {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if (-not (Test-DuplicateSource -SelectedItem $selectedApp -SourceData $this.stateManager.ConfigData.managedApps.$selectedApp -ItemType "App")) {
            return
        }

        try {
            # Generate unique ID for the duplicated app
            $newAppId = New-UniqueConfigId -Prefix "app-" -Collection $this.stateManager.ConfigData.managedApps

            # Deep copy the selected app data
            $originalAppData = $this.stateManager.ConfigData.managedApps.$selectedApp
            $duplicatedAppData = $originalAppData | ConvertTo-Json -Depth 10 | ConvertFrom-Json

            # Modify the display name to indicate it's a copy
            $originalDisplayName = if ($duplicatedAppData.displayName) { $duplicatedAppData.displayName } else { $selectedApp }
            $duplicatedAppData.displayName = "$originalDisplayName (Copy)"

            # Add to configuration
            $this.stateManager.ConfigData.managedApps | Add-Member -NotePropertyName $newAppId -NotePropertyValue $duplicatedAppData

            # Initialize/update apps order
            $this.stateManager.InitializeAppOrder()

            # Refresh managed apps list and apps to manage panel
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)
            Update-AppsToManagePanel

            # Select the new duplicated app
            $managedAppsList = $script:Window.FindName("ManagedAppsList")
            for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
                if ($managedAppsList.Items[$i] -eq $newAppId) {
                    $managedAppsList.SelectedIndex = $i
                    break
                }
            }



            Show-DuplicateResult -Success $true -ItemType "App" -OriginalId $selectedApp -NewId $newAppId

        } catch {
            Write-Error "Failed to duplicate app: $_"
            Show-DuplicateResult -Success $false -ItemType "App" -OriginalId $selectedApp
        }
    }

    # Handle delete app
    [void] HandleDeleteApp() {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if (-not $selectedApp) {
            Show-SafeMessage -Key "noAppSelected" -MessageType "Warning"
            return
        }

        $appDisplayName = if ($this.stateManager.ConfigData.managedApps.$selectedApp.displayName) {
            $this.stateManager.ConfigData.managedApps.$selectedApp.displayName
        } else {
            $selectedApp
        }

        $result = Show-SafeMessage -Key "confirmDeleteApp" -MessageType "Question" -Button "YesNo" -DefaultResult "No" -FormatArgs @($appDisplayName)

        if ($result -eq "Yes") {
            # Remove from configuration
            $this.stateManager.ConfigData.managedApps.PSObject.Properties.Remove($selectedApp)

            # Update apps order
            if ($this.stateManager.ConfigData.managedApps._order -and $selectedApp -in $this.stateManager.ConfigData.managedApps._order) {
                $this.stateManager.ConfigData.managedApps._order = $this.stateManager.ConfigData.managedApps._order | Where-Object { $_ -ne $selectedApp }
            }

            # Refresh managed apps list and apps to manage panel
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)
            Update-AppsToManagePanel



            Show-SafeMessage -Key "appDeleted" -MessageType "Information"
            Write-Verbose "Deleted app: $selectedApp"
        }
    }

    # Handle move app
    [void] HandleMoveApp([string]$Direction) {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if (-not $selectedApp) {
            Show-SafeMessage -Key "noAppSelected" -MessageType "Warning"
            return
        }

        # Ensure apps order exists
        if (-not $this.stateManager.ConfigData.managedApps._order) {
            $this.stateManager.InitializeAppOrder()
        }

        $currentOrder = $this.stateManager.ConfigData.managedApps._order
        $currentIndex = $currentOrder.IndexOf($selectedApp)

        if ($currentIndex -eq -1) {
            Write-Warning "Selected app not found in order array"
            return
        }

        $newIndex = $currentIndex
        switch ($Direction) {
            "Top" { $newIndex = 0 }
            "Up" { $newIndex = [Math]::Max(0, $currentIndex - 1) }
            "Down" { $newIndex = [Math]::Min($currentOrder.Count - 1, $currentIndex + 1) }
            "Bottom" { $newIndex = $currentOrder.Count - 1 }
        }

        # Only proceed if position actually changes
        if ($newIndex -ne $currentIndex) {
            # Create a new array with the item moved
            $newOrder = @($currentOrder)
            $appToMove = $newOrder[$currentIndex]
            $newOrder = $newOrder | Where-Object { $_ -ne $appToMove }

            # Insert at new position
            if ($newIndex -eq 0) {
                $newOrder = @($appToMove) + $newOrder
            } elseif ($newIndex -ge $newOrder.Count) {
                $newOrder = $newOrder + @($appToMove)
            } else {
                $beforeItems = $newOrder[0..($newIndex - 1)]
                $afterItems = $newOrder[$newIndex..($newOrder.Count - 1)]
                $newOrder = $beforeItems + @($appToMove) + $afterItems
            }

            # Update the configuration
            $this.stateManager.ConfigData.managedApps._order = $newOrder

            # Refresh the managed apps list
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)

            # Restore selection
            $managedAppsList = $script:Window.FindName("ManagedAppsList")
            for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
                if ($managedAppsList.Items[$i] -eq $selectedApp) {
                    $managedAppsList.SelectedIndex = $i
                    break
                }
            }
            Write-Verbose "Moved app '$selectedApp' $Direction (from index $currentIndex to $newIndex)"
        }
    }

    # Handle save configuration
    [void] HandleSaveConfig() {
        try {
            # Save current data to config object
            Save-UIDataToConfig

            # Write to file
            $configJson = $this.stateManager.ConfigData | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $configJson -Encoding UTF8

            # Update original config and clear modified flag
            Save-OriginalConfig
            $script:HasUnsavedChanges = $false

            Show-SafeMessage -Key "configSaved" -MessageType "Information"
            Write-Verbose "Configuration saved to: $script:ConfigPath"

        } catch {
            Write-Error "Failed to save configuration: $_"
            Show-SafeMessage -Key "configSaveFailed" -MessageType "Error"
        }
    }

    # Handle browse executable path (for Games tab)
    [void] HandleBrowseExecutablePath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("ExecutablePathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected game executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle browse app path (for Managed Apps tab)
    [void] HandleBrowseAppPath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("AppPathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected app executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle check update
    [void] HandleCheckUpdate() {
        try {
            Write-Host "=== Update Check DEBUG START ==="

            # Get current version - use global function reference
            $currentVersion = if ($global:GetProjectVersionFunc) {
                & $global:GetProjectVersionFunc
            } else {
                Write-Warning "Get-ProjectVersion not available"
                "Unknown"
            }
            Write-Host "Current version: $currentVersion"

            # Check for updates - use global function reference
            if (-not $global:TestUpdateAvailableFunc) {
                Write-Warning "Update checker not available"
                $message = $this.uiManager.GetLocalizedMessage("updateCheckFailed")
                $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")
                [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }

            Write-Host "Checking for updates..."
            $updateInfo = & $global:TestUpdateAvailableFunc -CurrentVersion $currentVersion

            if ($updateInfo) {
                Write-Host "Update info received:"
                Write-Host ($updateInfo | ConvertTo-Json -Depth 3)

                if ($updateInfo.UpdateAvailable) {
                    # Show update available dialog
                    $message = $this.uiManager.GetLocalizedMessage("updateAvailable") -f $updateInfo.LatestVersion, $currentVersion
                    $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

                    $result = [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)

                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        # Open the release page
                        if ($updateInfo.ReleaseUrl) {
                            Write-Host "Opening release page: $($updateInfo.ReleaseUrl)"
                            Start-Process $updateInfo.ReleaseUrl
                        } else {
                            Write-Warning "No release URL provided in update info"
                        }
                    }
                } else {
                    # No update available
                    $message = $this.uiManager.GetLocalizedMessage("noUpdateAvailable") -f $currentVersion
                    $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

                    [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
            } else {
                Write-Warning "No update info received"
                # Handle case where update check failed
                $message = $this.uiManager.GetLocalizedMessage("updateCheckFailed")
                $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

                [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            }

            Write-Host "=== Update Check DEBUG END ==="

        } catch {
            Write-Error "Update check failed: $_"
            Write-Host "Update check error: $_"

            # Show error message
            $message = $this.uiManager.GetLocalizedMessage("updateCheckError") -f $_.Exception.Message
            $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

            [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }

    # Handle auto detect path
    [void] HandleAutoDetectPath([string]$Platform) {
        try {
            $detectedPaths = @()

            switch ($Platform) {
                "Steam" {
                    $commonPaths = @(
                        "${env:ProgramFiles(x86)}/Steam/steam.exe",
                        "${env:ProgramFiles}/Steam/steam.exe",
                        "C:/Program Files (x86)/Steam/steam.exe",
                        "C:/Program Files/Steam/steam.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "Epic" {
                    $commonPaths = @(
                        "${env:ProgramFiles(x86)}/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe",
                        "${env:ProgramFiles}/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe",
                        "C:/Program Files (x86)/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe",
                        "C:/Program Files/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "Riot" {
                    $commonPaths = @(
                        "${env:ProgramFiles}/Riot Games/Riot Client/RiotClientServices.exe",
                        "${env:ProgramFiles(x86)}/Riot Games/Riot Client/RiotClientServices.exe",
                        "C:/Program Files/Riot Games/Riot Client/RiotClientServices.exe",
                        "C:/Program Files (x86)/Riot Games/Riot Client/RiotClientServices.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "Obs" {
                    $commonPaths = @(
                        "${env:ProgramFiles}/obs-studio/bin/64bit/obs64.exe",
                        "${env:ProgramFiles(x86)}/obs-studio/bin/64bit/obs64.exe",
                        "C:/Program Files/obs-studio/bin/64bit/obs64.exe",
                        "C:/Program Files (x86)/obs-studio/bin/64bit/obs64.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
            }

            if ($detectedPaths.Count -eq 0) {
                $message = $this.uiManager.GetLocalizedMessage("noPathDetected") -f $Platform
                Show-SafeMessage -Message $message -MessageType "Information"
                return
            }

            # If only one path detected, use it directly
            $selectedPath = if ($detectedPaths.Count -eq 1) {
                $detectedPaths[0]
            } else {
                # Multiple paths detected, let user choose
                Show-PathSelectionDialog -Paths $detectedPaths -Platform $Platform
            }

            if ($selectedPath) {
                # Set the appropriate text box
                switch ($Platform) {
                    "Steam" { $script:Window.FindName("SteamPathTextBox").Text = $selectedPath }
                    "Epic" { $script:Window.FindName("EpicPathTextBox").Text = $selectedPath }
                    "Riot" { $script:Window.FindName("RiotPathTextBox").Text = $selectedPath }
                    "Obs" { $script:Window.FindName("ObsPathTextBox").Text = $selectedPath }
                }

                $message = $this.uiManager.GetLocalizedMessage("pathDetected") -f $Platform, $selectedPath
                Show-SafeMessage -Message $message -MessageType "Information"
                Write-Verbose "Auto-detected $Platform path: $selectedPath"
            }

        } catch {
            Write-Error "Auto-detection failed for ${Platform}: $_"
            $message = $this.uiManager.GetLocalizedMessage("autoDetectError") -f $Platform, $_.Exception.Message
            Show-SafeMessage -Message $message -MessageType "Error"
        }
    }

    # Handle language selection changed
    [void] HandleLanguageSelectionChanged() {
        # Skip if still initializing to avoid triggering restart during startup
        if (-not $script:IsInitializationComplete) {
            Write-Verbose "Skipping language change handler - initialization not complete"
            return
        }

        $languageCombo = $this.uiManager.Window.FindName("LanguageCombo")
        if (-not $languageCombo.SelectedItem) {
            return
        }

        $selectedLanguageCode = $languageCombo.SelectedItem.Tag

        # Check if language actually changed
        if ($selectedLanguageCode -eq $this.uiManager.CurrentLanguage) {
            Write-Verbose "Language not changed, skipping restart prompt"
            return
        }

        Write-Host "Language changed from '$($this.uiManager.CurrentLanguage)' to '$selectedLanguageCode'"

        # Save the language setting to configuration
        if (-not $this.stateManager.ConfigData.PSObject.Properties["language"]) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "language" -NotePropertyValue $selectedLanguageCode
        } else {
            $this.stateManager.ConfigData.language = $selectedLanguageCode
        }

        # DO NOT mark as modified here - the restart process will save the configuration
        # This prevents the "unsaved changes" dialog from appearing during restart
        # $this.stateManager.SetModified()

        # Show restart message and restart if user agrees
        Show-LanguageChangeRestartMessage

        Write-Verbose "Language changed to: $selectedLanguageCode"
    }

    # Handle window closing
    [void] HandleWindowClosing([System.ComponentModel.CancelEventArgs]$Event) {
        try {
            Write-Host "DEBUG: HandleWindowClosing called"

            if ($this.stateManager.TestHasUnsavedChanges()) {
                $result = Show-SafeMessage -Key "confirmDiscardChanges" -MessageType "Question" -Button "YesNoCancel" -DefaultResult "Cancel"

                if ($result -ne "Yes") {
                    Write-Host "DEBUG: User cancelled window closing"
                    $Event.Cancel = $true
                    return
                }
            }

            Write-Host "DEBUG: Window closing approved"
        } catch {
            Write-Warning "Error in HandleWindowClosing: $($_.Exception.Message)"
            # Don't cancel on error - allow window to close
        }
    }

    # Handle save game settings
    [void] HandleSaveGameSettings() {
        try {
            # Save current game data
            Save-CurrentGameData

            # Write to file
            $configJson = $this.stateManager.ConfigData | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $configJson -Encoding UTF8

            # Update original config and clear modified flag
            Save-OriginalConfig
            $script:HasUnsavedChanges = $false

            # Refresh games list to reflect any changes
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

            Show-SafeMessage -Key "gameSettingsSaved" -MessageType "Information"
            Write-Verbose "Game settings saved"

        } catch {
            Write-Error "Failed to save game settings: $_"
            Show-SafeMessage -Key "gameSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save managed apps
    [void] HandleSaveManagedApps() {
        try {
            # Save current app data
            Save-CurrentAppData

            # Save global apps to manage settings
            $appsToManagePanel = $script:Window.FindName("AppsToManagePanel")
            $appsToManage = @()

            foreach ($child in $appsToManagePanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                    $appsToManage += $child.Tag
                }
            }

            if (-not $this.stateManager.ConfigData.PSObject.Properties["appsToManage"]) {
                $this.stateManager.ConfigData | Add-Member -NotePropertyName "appsToManage" -NotePropertyValue $appsToManage
            } else {
                $this.stateManager.ConfigData.appsToManage = $appsToManage
            }

            # Write to file
            $configJson = $this.stateManager.ConfigData | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $configJson -Encoding UTF8

            # Update original config and clear modified flag
            Save-OriginalConfig
            $script:HasUnsavedChanges = $false

            # Refresh managed apps list to reflect any changes
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)

            Show-SafeMessage -Key "managedAppsSaved" -MessageType "Information"
            Write-Verbose "Managed apps settings saved"

        } catch {
            Write-Error "Failed to save managed apps settings: $_"
            Show-SafeMessage -Key "managedAppsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save global settings
    [void] HandleSaveGlobalSettings() {
        try {
            # Save global settings data
            Save-GlobalSettingsData

            # Write to file
            $configJson = $this.stateManager.ConfigData | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $configJson -Encoding UTF8

            # Update original config and clear modified flag
            Save-OriginalConfig
            $script:HasUnsavedChanges = $false

            Show-SafeMessage -Key "globalSettingsSaved" -MessageType "Information"
            Write-Verbose "Global settings saved"

        } catch {
            Write-Error "Failed to save global settings: $_"
            Show-SafeMessage -Key "globalSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle refresh game list button click
    [void] HandleRefreshGameList() {
        try {
            Write-Verbose "Refreshing game list"
            $this.uiManager.UpdateGameLauncherList($this.stateManager.ConfigData)
        } catch {
            Write-Warning "Failed to refresh game list: $($_.Exception.Message)"
        }
    }

    # Handle add new game from launcher
    [void] HandleAddNewGameFromLauncher() {
        try {
            Write-Verbose "Adding new game from launcher"
            # Switch to Games tab and trigger add game
            $mainTabControl = $this.uiManager.Window.FindName("MainTabControl")
            $gamesTab = $this.uiManager.Window.FindName("GamesTab")

            if ($mainTabControl -and $gamesTab) {
                $mainTabControl.SelectedItem = $gamesTab
                # Trigger add game functionality
                $this.HandleAddGame()
            }
        } catch {
            Write-Warning "Failed to add new game from launcher: $($_.Exception.Message)"
        }
    }

    # Handle open config from launcher
    [void] HandleOpenConfigFromLauncher() {
        try {
            Write-Verbose "Opening config from launcher"
            # Switch to Global Settings tab
            $mainTabControl = $this.uiManager.Window.FindName("MainTabControl")
            $globalSettingsTab = $this.uiManager.Window.FindName("GlobalSettingsTab")

            if ($mainTabControl -and $globalSettingsTab) {
                $mainTabControl.SelectedItem = $globalSettingsTab
            }
        } catch {
            Write-Warning "Failed to open config from launcher: $($_.Exception.Message)"
        }
    }

    # Handle launch game from launcher tab
    [void] HandleLaunchGame([string]$GameId) {
        try {
            # Update status immediately for responsive feedback
            $statusText = $this.uiManager.Window.FindName("LauncherStatusText")
            if ($statusText) {
                $launchingMessage = $this.uiManager.GetLocalizedMessage("launchingGame")
                $statusText.Text = $launchingMessage -f $GameId
                $statusText.Foreground = "#0066CC"
            }

            # Validate game exists in configuration
            if (-not $this.stateManager.ConfigData.games -or -not $this.stateManager.ConfigData.games.PSObject.Properties[$GameId]) {
                Show-SafeMessage -Key "gameNotFound" -MessageType "Error" -FormatArgs @($GameId)
                if ($statusText) {
                    $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                    $statusText.Foreground = "#CC0000"
                }
                return
            }

            # Use the direct game launcher to avoid recursive ConfigEditor launches
            $gameLauncherPath = Join-Path (Split-Path $PSScriptRoot) "src/Invoke-FocusGameDeck.ps1"

            if (-not (Test-Path $gameLauncherPath)) {
                Show-SafeMessage -Key "launcherNotFound" -MessageType "Error"
                if ($statusText) {
                    $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                    $statusText.Foreground = "#CC0000"
                }
                return
            }

            Write-Host "Launching game from GUI: $GameId"

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
                    $launchedMessage = $this.uiManager.GetLocalizedMessage("gameLaunched")
                    $statusText.Text = $launchedMessage -f $GameId
                    $statusText.Foreground = "#009900"
                }
            }

            # Reset status after delay without interrupting user workflow
            $uiManagerRef = $this.uiManager
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(5)
            $timer.add_Tick({
                    param($sender, $e)
                    $statusText = $uiManagerRef.Window.FindName("LauncherStatusText")
                    if ($statusText) {
                        $statusText.Text = $uiManagerRef.GetLocalizedMessage("readyToLaunch")
                        $statusText.Foreground = "#333333"
                    }
                    $sender.Stop()
                }.GetNewClosure())
            $timer.Start()

        } catch {
            Write-Warning "Failed to launch game '$GameId': $($_.Exception.Message)"

            # Only show modal dialog for actual errors that need user attention
            Show-SafeMessage -Key "launchFailed" -MessageType "Error" -FormatArgs @($GameId, $_.Exception.Message)

            # Update status for error
            $statusText = $this.uiManager.Window.FindName("LauncherStatusText")
            if ($statusText) {
                $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                $statusText.Foreground = "#CC0000"
            }
        }
    }

    # Handle about dialog
    [void] HandleAbout() {
        try {
            Write-Host "=== Handle-About DEBUG START ==="

            # Get version information - use global function reference
            $version = if ($global:GetProjectVersionFunc) {
                & $global:GetProjectVersionFunc
            } else {
                Write-Warning "Get-ProjectVersion not available"
                "Unknown"
            }
            $buildDate = Get-Date -Format "yyyy-MM-dd"

            Write-Host "Version: $version"
            Write-Host "Build Date: $buildDate"

            # Create about message
            $aboutMessage = $this.uiManager.GetLocalizedMessage("aboutMessage") -f $version, $buildDate
            $aboutTitle = $this.uiManager.GetLocalizedMessage("aboutTitle")

            Write-Host "About Message: $aboutMessage"
            Write-Host "About Title: $aboutTitle"

            # Show the about dialog
            [System.Windows.MessageBox]::Show($aboutMessage, $aboutTitle, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)

            Write-Host "=== Handle-About DEBUG END ==="

        } catch {
            Write-Error "About dialog failed: $_"
            Write-Host "About dialog error: $_"
        }
    }

    # Handle generate launchers
    [void] HandleGenerateLaunchers() {
        try {
            # Get the selected games from the launcher list
            $gameLauncherList = $script:Window.FindName("GameLauncherList")
            $selectedGames = @()

            foreach ($child in $gameLauncherList.Children) {
                if ($child -is [System.Windows.Controls.Border]) {
                    $grid = $child.Child
                    if ($grid -is [System.Windows.Controls.Grid]) {
                        $checkBox = $grid.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] } | Select-Object -First 1
                        if ($checkBox -and $checkBox.IsChecked -and $checkBox.Tag) {
                            $selectedGames += $checkBox.Tag
                        }
                    }
                }
            }

            if ($selectedGames.Count -eq 0) {
                Show-SafeMessage -Key "noGamesSelectedForLaunchers" -MessageType "Warning"
                return
            }

            # Use the enhanced launcher creation script
            $launcherScriptPath = Join-Path (Split-Path $PSScriptRoot) "scripts/Create-Launchers-Enhanced.ps1"

            if (-not (Test-Path $launcherScriptPath)) {
                # Fallback to basic launcher script
                $launcherScriptPath = Join-Path (Split-Path $PSScriptRoot) "scripts/Create-Launchers.ps1"
                if (-not (Test-Path $launcherScriptPath)) {
                    Show-SafeMessage -Key "launcherScriptNotFound" -MessageType "Error"
                    return
                }
            }

            # Execute the launcher creation script
            $gameIds = $selectedGames -join ","
            Write-Host "Creating launchers for games: $gameIds"

            try {
                & $launcherScriptPath -GameIds $gameIds -ConfigPath $script:ConfigPath
                Show-SafeMessage -Key "launchersGenerated" -MessageType "Information" -FormatArgs @($selectedGames.Count)
                Write-Verbose "Generated launchers for $($selectedGames.Count) games"
            } catch {
                Write-Error "Launcher generation failed: $_"
                Show-SafeMessage -Key "launcherGenerationFailed" -MessageType "Error" -FormatArgs @($_.Exception.Message)
            }

        } catch {
            Write-Error "Failed to generate launchers: $_"
            Show-SafeMessage -Key "launcherGenerationFailed" -MessageType "Error" -FormatArgs @($_.Exception.Message)
        }
    }

    # Register all UI event handlers
    [void] RegisterAll() {
        try {
            Write-Host "Registering all UI event handlers..."

            $self = $this

            # --- Window Events ---
            $this.uiManager.Window.add_Closing({
                    param($sender, $e)
                    try {
                        Write-Host "DEBUG: Window Closing event fired"
                        $self.HandleWindowClosing($e)
                    } catch {
                        Write-Warning "Error in window closing event: $($_.Exception.Message)"
                    }
                }.GetNewClosure())

            # --- Game Launcher Tab ---
            $this.uiManager.Window.FindName("RefreshGameListButton").add_Click({ $self.HandleRefreshGameList() }.GetNewClosure())
            $this.uiManager.Window.FindName("AddNewGameButton").add_Click({ $self.HandleAddNewGameFromLauncher() }.GetNewClosure())
            $this.uiManager.Window.FindName("OpenConfigButton").add_Click({ $self.HandleOpenConfigFromLauncher() }.GetNewClosure())
            $this.uiManager.Window.FindName("GenerateLaunchersButton").add_Click({ $self.HandleGenerateLaunchers() }.GetNewClosure())

            # Add tab selection event to update game list when switching to launcher tab
            $mainTabControl = $this.uiManager.Window.FindName("MainTabControl")
            if ($mainTabControl) {
                $mainTabControl.add_SelectionChanged({
                        try {
                            $selectedTab = $this.SelectedItem
                            if ($selectedTab -and $selectedTab.Name -eq "GameLauncherTab") {
                                $self.HandleRefreshGameList()
                            }
                        } catch {
                            Write-Warning "Error in tab selection changed: $($_.Exception.Message)"
                        }
                    }.GetNewClosure())
            }

            # --- Game Settings Tab ---
            $this.uiManager.Window.FindName("GamesList").add_SelectionChanged({ $self.HandleGameSelectionChanged() }.GetNewClosure())
            $this.uiManager.Window.FindName("PlatformComboBox").add_SelectionChanged({ $self.HandlePlatformSelectionChanged() }.GetNewClosure())
            $this.uiManager.Window.FindName("GameStartActionCombo").add_SelectionChanged({ $self.UpdateTerminationMethodState() }.GetNewClosure())
            $this.uiManager.Window.FindName("GameEndActionCombo").add_SelectionChanged({ $self.UpdateTerminationMethodState() }.GetNewClosure())
            $this.uiManager.Window.FindName("AddGameButton").add_Click({ $self.HandleAddGame() }.GetNewClosure())
            $this.uiManager.Window.FindName("DuplicateGameButton").add_Click({ $self.HandleDuplicateGame() }.GetNewClosure())
            $this.uiManager.Window.FindName("DeleteGameButton").add_Click({ $self.HandleDeleteGame() }.GetNewClosure())
            $this.uiManager.Window.FindName("BrowseExecutablePathButton").add_Click({ $self.HandleBrowseExecutablePath() }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveGameSettingsButton").add_Click({ $self.HandleSaveGameSettings() }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveGameTopButton").add_Click({ $self.HandleMoveGame("Top") }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveGameUpButton").add_Click({ $self.HandleMoveGame("Up") }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveGameDownButton").add_Click({ $self.HandleMoveGame("Down") }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveGameBottomButton").add_Click({ $self.HandleMoveGame("Bottom") }.GetNewClosure())

            # --- Managed Apps Tab ---
            $this.uiManager.Window.FindName("ManagedAppsList").add_SelectionChanged({ $self.HandleAppSelectionChanged() }.GetNewClosure())
            $this.uiManager.Window.FindName("AddAppButton").add_Click({ $self.HandleAddApp() }.GetNewClosure())
            $this.uiManager.Window.FindName("DuplicateAppButton").add_Click({ $self.HandleDuplicateApp() }.GetNewClosure())
            $this.uiManager.Window.FindName("DeleteAppButton").add_Click({ $self.HandleDeleteApp() }.GetNewClosure())
            $this.uiManager.Window.FindName("BrowseAppPathButton").add_Click({ $self.HandleBrowseAppPath() }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveManagedAppsButton").add_Click({ $self.HandleSaveManagedApps() }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveAppTopButton").add_Click({ $self.HandleMoveApp("Top") }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveAppUpButton").add_Click({ $self.HandleMoveApp("Up") }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveAppDownButton").add_Click({ $self.HandleMoveApp("Down") }.GetNewClosure())
            $this.uiManager.Window.FindName("MoveAppBottomButton").add_Click({ $self.HandleMoveApp("Bottom") }.GetNewClosure())

            # --- Global Settings Tab ---
            $this.uiManager.Window.FindName("LanguageCombo").add_SelectionChanged({ $self.HandleLanguageSelectionChanged() }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveGlobalSettingsButton").add_Click({ $self.HandleSaveGlobalSettings() }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectSteamButton").add_Click({ $self.HandleAutoDetectPath("Steam") }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectEpicButton").add_Click({ $self.HandleAutoDetectPath("Epic") }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectRiotButton").add_Click({ $self.HandleAutoDetectPath("Riot") }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectObsButton").add_Click({ $self.HandleAutoDetectPath("Obs") }.GetNewClosure())

            # --- Menu Items ---
            $this.uiManager.Window.FindName("CheckUpdateMenuItem").add_Click({ $self.HandleCheckUpdate() }.GetNewClosure())
            $this.uiManager.Window.FindName("AboutMenuItem").add_Click({ $self.HandleAbout() }.GetNewClosure())

            Write-Host "All UI event handlers registered successfully."
        } catch {
            Write-Error "Failed to register event handlers: $($_.Exception.Message)"
            throw $_
        }
    }
}
