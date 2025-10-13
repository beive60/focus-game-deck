class ConfigEditorEvents {
    $uiManager
    $stateManager

    ConfigEditorEvents($ui, $state) {
        $this.uiManager = $ui
        $this.stateManager = $state
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

            if ($gameData) {
                # Load game details into form
                $script:Window.FindName("GameDisplayNameTextBox").Text = if ($gameData.displayName) { $gameData.displayName } else { "" }
                $script:Window.FindName("GameAppIdTextBox").Text = if ($gameData.appId) { $gameData.appId } else { "" }
                $script:Window.FindName("SteamAppIdTextBox").Text = if ($gameData.steamAppId) { $gameData.steamAppId } else { "" }
                $script:Window.FindName("EpicGameIdTextBox").Text = if ($gameData.epicGameId) { $gameData.epicGameId } else { "" }
                $script:Window.FindName("RiotGameIdTextBox").Text = if ($gameData.riotGameId) { $gameData.riotGameId } else { "" }
                $script:Window.FindName("ExecutablePathTextBox").Text = if ($gameData.executablePath) { $gameData.executablePath } else { "" }

                # Set platform
                $platformCombo = $script:Window.FindName("PlatformComboBox")
                $platform = if ($gameData.platform) { $gameData.platform } else { "standalone" }
                for ($i = 0; $i -lt $platformCombo.Items.Count; $i++) {
                    if ($platformCombo.Items[$i].Tag -eq $platform) {
                        $platformCombo.SelectedIndex = $i
                        break
                    }
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

                $gameStartActionCombo.SelectedItem = if ($gameData.managedApps.gameStartAction) { $gameData.managedApps.gameStartAction } else { "none" }
                $gameEndActionCombo.SelectedItem = if ($gameData.managedApps.gameEndAction) { $gameData.managedApps.gameEndAction } else { "none" }

                # Load termination settings
                $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
                $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")

                $terminationMethodCombo.SelectedItem = if ($gameData.managedApps.terminationMethod) { $gameData.managedApps.terminationMethod } else { "auto" }
                $gracefulTimeoutTextBox.Text = if ($gameData.managedApps.gracefulTimeout) { $gameData.managedApps.gracefulTimeout.ToString() } else { "5" }

                # Update termination settings visibility
                Update-TerminationSettingsVisibility

                # Enable buttons
                $script:Window.FindName("DuplicateGameButton").IsEnabled = $true
                $script:Window.FindName("DeleteGameButton").IsEnabled = $true

                # Update move button states
                Update-MoveButtonStates

                Write-Verbose "Loaded game data for: $selectedGame"
            }
        } else {
            # No game selected, clear the form
            $script:CurrentGameId = ""
            $script:Window.FindName("GameDisplayNameTextBox").Text = ""
            $script:Window.FindName("GameAppIdTextBox").Text = ""
            $script:Window.FindName("SteamAppIdTextBox").Text = ""
            $script:Window.FindName("EpicGameIdTextBox").Text = ""
            $script:Window.FindName("RiotGameIdTextBox").Text = ""
            $script:Window.FindName("ExecutablePathTextBox").Text = ""

            # Reset platform to standalone
            $platformCombo = $script:Window.FindName("PlatformComboBox")
            $platformCombo.SelectedIndex = 0
            Update-PlatformFields -Platform "standalone"

            # Reset action combos
            $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
            $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
            $gameStartActionCombo.SelectedItem = "none"
            $gameEndActionCombo.SelectedItem = "none"

            # Reset termination settings
            $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
            $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
            $terminationMethodCombo.SelectedItem = "auto"
            $gracefulTimeoutTextBox.Text = "5"

            # Update termination settings visibility
            Update-TerminationSettingsVisibility

            # Disable buttons
            $script:Window.FindName("DuplicateGameButton").IsEnabled = $false
            $script:Window.FindName("DeleteGameButton").IsEnabled = $false

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

            if ($appData) {
                # Load app details into form
                $script:Window.FindName("AppDisplayNameTextBox").Text = if ($appData.displayName) { $appData.displayName } else { "" }
                $script:Window.FindName("AppProcessNamesTextBox").Text = if ($appData.processNames) {
                    if ($appData.processNames -is [array]) {
                        $appData.processNames -join "|"
                    } else {
                        $appData.processNames
                    }
                } else { "" }
                $script:Window.FindName("AppStartActionCombo").SelectedItem = if ($appData.startAction) { $appData.startAction } else { "start-process" }
                $script:Window.FindName("AppEndActionCombo").SelectedItem = if ($appData.endAction) { $appData.endAction } else { "stop-process" }
                $script:Window.FindName("AppExecutablePathTextBox").Text = if ($appData.executablePath) { $appData.executablePath } else { "" }

                # Load termination settings
                $script:Window.FindName("AppTerminationMethodCombo").SelectedItem = if ($appData.terminationMethod) { $appData.terminationMethod } else { "auto" }
                $script:Window.FindName("AppGracefulTimeoutTextBox").Text = if ($appData.gracefulTimeout) { $appData.gracefulTimeout.ToString() } else { "5" }

                # Enable buttons
                $script:Window.FindName("DuplicateAppButton").IsEnabled = $true
                $script:Window.FindName("DeleteAppButton").IsEnabled = $true

                # Update move button states
                Update-MoveAppButtonStates

                Write-Verbose "Loaded app data for: $selectedApp"
            }
        } else {
            # No app selected, clear the form
            $script:CurrentAppId = ""
            $script:Window.FindName("AppDisplayNameTextBox").Text = ""
            $script:Window.FindName("AppProcessNamesTextBox").Text = ""
            $script:Window.FindName("AppStartActionCombo").SelectedItem = "start-process"
            $script:Window.FindName("AppEndActionCombo").SelectedItem = "stop-process"
            $script:Window.FindName("AppExecutablePathTextBox").Text = ""
            $script:Window.FindName("AppTerminationMethodCombo").SelectedItem = "auto"
            $script:Window.FindName("AppGracefulTimeoutTextBox").Text = "5"

            # Disable buttons
            $script:Window.FindName("DuplicateAppButton").IsEnabled = $false
            $script:Window.FindName("DeleteAppButton").IsEnabled = $false

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
        Initialize-GameOrder

        # Refresh games list
        $this.uiManager.UpdateGamesList()

        # Select the new game
        $gamesList = $script:Window.FindName("GamesList")
        for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
            if ($gamesList.Items[$i] -eq $newGameId) {
                $gamesList.SelectedIndex = $i
                break
            }
        }

        # Mark as modified
        $self.stateManager.SetModified()

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
            Initialize-GameOrder

            # Refresh games list and apps to manage panel
            $this.uiManager.UpdateGamesList()
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
            $this.uiManager.UpdateGamesList()
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
            Initialize-GameOrder
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
            $this.uiManager.UpdateGamesList()

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
        Initialize-AppOrder

        # Refresh managed apps list and apps to manage panel
        $this.uiManager.UpdateManagedAppsList()
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
            Initialize-AppOrder

            # Refresh managed apps list and apps to manage panel
            $this.uiManager.UpdateManagedAppsList()
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
            $this.uiManager.UpdateManagedAppsList()
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
            Initialize-AppOrder
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
            $this.uiManager.UpdateManagedAppsList()

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

    # Handle browse executable path
    [void] HandleBrowseExecutablePath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = Get-LocalizedMessage -Key "selectExecutable"

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("ExecutablePathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle add new game from launcher
    [void] HandleAddNewGameFromLauncher() {
        # Switch to Games tab
        $tabControl = $script:Window.FindName("MainTabControl")
        $tabControl.SelectedIndex = 1  # Games tab

        # Add a new game
        $this.HandleAddGame()

        Write-Verbose "Added new game from launcher tab and switched to Games tab"
    }

    # Handle check update
    [void] HandleCheckUpdate() {
        try {
            Write-Host "=== Update Check DEBUG START ===" -ForegroundColor Cyan

            # Get current version
            $currentVersion = Get-ProjectVersion
            Write-Host "Current version: $currentVersion" -ForegroundColor Yellow

            # Check for updates
            Write-Host "Checking for updates..." -ForegroundColor Green
            $updateInfo = Test-UpdateAvailable -CurrentVersion $currentVersion

            if ($updateInfo) {
                Write-Host "Update info received:" -ForegroundColor Magenta
                Write-Host ($updateInfo | ConvertTo-Json -Depth 3) -ForegroundColor Magenta

                if ($updateInfo.UpdateAvailable) {
                    # Show update available dialog
                    $message = Get-LocalizedMessage -Key "updateAvailable" -FormatArgs @($updateInfo.LatestVersion, $currentVersion)
                    $title = Get-LocalizedMessage -Key "updateCheckTitle"

                    $result = [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)

                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        # Open the release page
                        if ($updateInfo.ReleaseUrl) {
                            Write-Host "Opening release page: $($updateInfo.ReleaseUrl)" -ForegroundColor Green
                            Start-Process $updateInfo.ReleaseUrl
                        } else {
                            Write-Warning "No release URL provided in update info"
                        }
                    }
                } else {
                    # No update available
                    $message = Get-LocalizedMessage -Key "noUpdateAvailable" -FormatArgs @($currentVersion)
                    $title = Get-LocalizedMessage -Key "updateCheckTitle"

                    [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
            } else {
                Write-Warning "No update info received"
                # Handle case where update check failed
                $message = Get-LocalizedMessage -Key "updateCheckFailed"
                $title = Get-LocalizedMessage -Key "updateCheckTitle"

                [System.Windows.MessageBox]::Show($message, $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            }

            Write-Host "=== Update Check DEBUG END ===" -ForegroundColor Cyan

        } catch {
            Write-Error "Update check failed: $_"
            Write-Host "Update check error: $_" -ForegroundColor Red

            # Show error message
            $message = Get-LocalizedMessage -Key "updateCheckError" -FormatArgs @($_.Exception.Message)
            $title = Get-LocalizedMessage -Key "updateCheckTitle"

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
                $message = Get-LocalizedMessage -Key "noPathDetected" -FormatArgs @($Platform)
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

                $message = Get-LocalizedMessage -Key "pathDetected" -FormatArgs @($Platform, $selectedPath)
                Show-SafeMessage -Message $message -MessageType "Information"
                Write-Verbose "Auto-detected $Platform path: $selectedPath"
            }

        } catch {
            Write-Error "Auto-detection failed for ${Platform}: $_"
            $message = Get-LocalizedMessage -Key "autoDetectError" -FormatArgs @($Platform, $_.Exception.Message)
            Show-SafeMessage -Message $message -MessageType "Error"
        }
    }

    # Handle language selection changed
    [void] HandleLanguageSelectionChanged() {
        $languageCombo = $script:Window.FindName("LanguageCombo")
        if (-not $languageCombo.SelectedItem) {
            return
        }

        $selectedLanguageCode = $languageCombo.SelectedItem.Tag

        # Check if language actually changed
        if ($selectedLanguageCode -eq $script:CurrentLanguage) {
            return
        }

        # Save the language setting to configuration
        if (-not $this.stateManager.ConfigData.PSObject.Properties["language"]) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "language" -NotePropertyValue $selectedLanguageCode
        } else {
            $this.stateManager.ConfigData.language = $selectedLanguageCode
        }

        # Mark configuration as modified
        Set-ConfigModified

        # Show restart message and restart if user agrees
        Show-LanguageChangeRestartMessage

        Write-Verbose "Language changed to: $selectedLanguageCode"
    }

    # Handle apply config (legacy function)
    [void] HandleApplyConfig() {
        try {
            $this.HandleSaveConfig()
        } catch {
            Write-Error "Failed to apply configuration: $_"
            Show-SafeMessage -Key "configSaveFailed" -MessageType "Error"
        }
    }

    # Handle OK config (legacy function)
    [void] HandleOKConfig() {
        try {
            if (Test-HasUnsavedChanges) {
                $this.HandleSaveConfig()
            }

            # Close the window
            if ($script:Window) {
                $script:Window.Close()
            }
        } catch {
            Write-Error "Failed to save and close: $_"
            Show-SafeMessage -Key "configSaveFailed" -MessageType "Error"
        }
    }

    # Handle cancel config (legacy function)
    [void] HandleCancelConfig() {
        if (Test-HasUnsavedChanges) {
            $result = Show-SafeMessage -Key "confirmDiscardChanges" -MessageType "Question" -Button "YesNoCancel" -DefaultResult "Cancel"

            if ($result -ne "Yes") {
                return  # User cancelled or chose No
            }
        }

        # Close the window without saving
        if ($script:Window) {
            $script:Window.Close()
        }
    }

    # Handle window closing
    [void] HandleWindowClosing([System.ComponentModel.CancelEventArgs]$Event) {
        try {
            Write-Host "DEBUG: HandleWindowClosing called" -ForegroundColor Cyan

            if ($self.stateManager.TestHasUnsavedChanges()) {
                $result = Show-SafeMessage -Key "confirmDiscardChanges" -MessageType "Question" -Button "YesNoCancel" -DefaultResult "Cancel"

                if ($result -ne "Yes") {
                    Write-Host "DEBUG: User cancelled window closing" -ForegroundColor Yellow
                    $Event.Cancel = $true
                    return
                }
            }

            Write-Host "DEBUG: Window closing approved" -ForegroundColor Green
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
            $this.uiManager.UpdateGamesList()

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
            $this.uiManager.UpdateManagedAppsList()

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

    # Handle about dialog
    [void] HandleAbout() {
        try {
            Write-Host "=== Handle-About DEBUG START ===" -ForegroundColor Cyan

            # Get version information
            $version = Get-ProjectVersion
            $buildDate = Get-Date -Format "yyyy-MM-dd"

            Write-Host "Version: $version" -ForegroundColor Yellow
            Write-Host "Build Date: $buildDate" -ForegroundColor Yellow

            # Create about message
            $aboutMessage = Get-LocalizedMessage -Key "aboutMessage" -FormatArgs @($version, $buildDate)
            $aboutTitle = Get-LocalizedMessage -Key "aboutTitle"

            Write-Host "About Message: $aboutMessage" -ForegroundColor Green
            Write-Host "About Title: $aboutTitle" -ForegroundColor Green

            # Show the about dialog
            [System.Windows.MessageBox]::Show($aboutMessage, $aboutTitle, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)

            Write-Host "=== Handle-About DEBUG END ===" -ForegroundColor Cyan

        } catch {
            Write-Error "About dialog failed: $_"
            Write-Host "About dialog error: $_" -ForegroundColor Red
        }
    }

    # Handle close window (legacy function)
    [void] HandleCloseWindow() {
        if ($script:Window) {
            $script:Window.Close()
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
            Write-Host "Creating launchers for games: $gameIds" -ForegroundColor Green

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
            Write-Host "Registering all UI event handlers..." -ForegroundColor Yellow

            $self = $this

            # --- Window Events ---
            $self.uiManager.Window.add_Closing({
                param($sender, $e)
                try {
                    Write-Host "DEBUG: Window Closing event fired" -ForegroundColor Cyan
                    $self.HandleWindowClosing($e)
                } catch {
                    Write-Warning "Error in window closing event: $($_.Exception.Message)"
                }
            }.GetNewClosure())

            # --- Game Settings Tab ---
            $self.uiManager.Window.FindName("GamesList").add_SelectionChanged({ $self.HandleGameSelectionChanged() }.GetNewClosure())
            $self.uiManager.Window.FindName("PlatformComboBox").add_SelectionChanged({ $self.HandlePlatformSelectionChanged() }.GetNewClosure())
            $self.uiManager.Window.FindName("AddGameButton").add_Click({ $self.HandleAddGame() }.GetNewClosure())
            $self.uiManager.Window.FindName("DuplicateGameButton").add_Click({ $self.HandleDuplicateGame() }.GetNewClosure())
            $self.uiManager.Window.FindName("DeleteGameButton").add_Click({ $self.HandleDeleteGame() }.GetNewClosure())
            $self.uiManager.Window.FindName("BrowseExecutablePathButton").add_Click({ $self.HandleBrowseExecutablePath() }.GetNewClosure())
            $self.uiManager.Window.FindName("SaveGameSettingsButton").add_Click({ $self.HandleSaveGameSettings() }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveGameTopButton").add_Click({ $self.HandleMoveGame("Top") }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveGameUpButton").add_Click({ $self.HandleMoveGame("Up") }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveGameDownButton").add_Click({ $self.HandleMoveGame("Down") }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveGameBottomButton").add_Click({ $self.HandleMoveGame("Bottom") }.GetNewClosure())

            # --- Managed Apps Tab ---
            $self.uiManager.Window.FindName("ManagedAppsList").add_SelectionChanged({ $self.HandleAppSelectionChanged() }.GetNewClosure())
            $self.uiManager.Window.FindName("AddAppButton").add_Click({ $self.HandleAddApp() }.GetNewClosure())
            $self.uiManager.Window.FindName("DuplicateAppButton").add_Click({ $self.HandleDuplicateApp() }.GetNewClosure())
            $self.uiManager.Window.FindName("DeleteAppButton").add_Click({ $self.HandleDeleteApp() }.GetNewClosure())
            $self.uiManager.Window.FindName("BrowseAppPathButton").add_Click({ $self.HandleBrowseExecutablePath() }.GetNewClosure())
            $self.uiManager.Window.FindName("SaveManagedAppsButton").add_Click({ $self.HandleSaveManagedApps() }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveAppTopButton").add_Click({ $self.HandleMoveApp("Top") }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveAppUpButton").add_Click({ $self.HandleMoveApp("Up") }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveAppDownButton").add_Click({ $self.HandleMoveApp("Down") }.GetNewClosure())
            $self.uiManager.Window.FindName("MoveAppBottomButton").add_Click({ $self.HandleMoveApp("Bottom") }.GetNewClosure())

            # --- Global Settings Tab ---
            $self.uiManager.Window.FindName("LanguageCombo").add_SelectionChanged({ $self.HandleLanguageSelectionChanged() }.GetNewClosure())
            $self.uiManager.Window.FindName("SaveGlobalSettingsButton").add_Click({ $self.HandleSaveGlobalSettings() }.GetNewClosure())
            $self.uiManager.Window.FindName("AutoDetectSteamButton").add_Click({ $self.HandleAutoDetectPath("Steam") }.GetNewClosure())
            $self.uiManager.Window.FindName("AutoDetectEpicButton").add_Click({ $self.HandleAutoDetectPath("Epic") }.GetNewClosure())
            $self.uiManager.Window.FindName("AutoDetectRiotButton").add_Click({ $self.HandleAutoDetectPath("Riot") }.GetNewClosure())
            $self.uiManager.Window.FindName("AutoDetectObsButton").add_Click({ $self.HandleAutoDetectPath("Obs") }.GetNewClosure())

            # --- Menu Items ---
            $self.uiManager.Window.FindName("CheckUpdateMenuItem").add_Click({ $self.HandleCheckUpdate() }.GetNewClosure())
            $self.uiManager.Window.FindName("AboutMenuItem").add_Click({ $self.HandleAbout() }.GetNewClosure())

            Write-Host "All UI event handlers registered successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to register event handlers: $($_.Exception.Message)"
            throw $_
        }
    }
}
