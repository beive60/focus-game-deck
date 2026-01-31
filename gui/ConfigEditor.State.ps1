class ConfigEditorState {
    # Properties
    [string]$ConfigPath
    [PSCustomObject]$ConfigData
    [string]$OriginalConfigData

    # Additional properties for refactoring from global variables
    [Object]$Window
    [string]$CurrentGameId
    [string]$CurrentAppId
    [PSCustomObject]$Messages
    [string]$CurrentLanguage
    [bool]$HasUnsavedChanges

    # Constructor
    ConfigEditorState([string]$configPath) {
        Write-Verbose "[INFO] ConfigEditorState constructor called with configPath: '$configPath'"

        if ([string]::IsNullOrEmpty($configPath)) {
            Write-Warning "[WARNING] ConfigPath is null or empty in constructor"
        }

        $this.ConfigPath = $configPath
        $this.ConfigData = $null
        $this.OriginalConfigData = $null

        # Initialize additional properties
        $this.Window = $null
        $this.CurrentGameId = ""
        $this.CurrentAppId = ""
        $this.Messages = $null
        $this.CurrentLanguage = "en"  # Default language
        $this.HasUnsavedChanges = $false

        Write-Verbose "[INFO] ConfigEditorState constructor completed successfully"
    }

    # Load configuration from file
    [void] LoadConfiguration() {
        try {
            Write-Verbose "[INFO] LoadConfiguration started. ConfigPath: '$($this.ConfigPath)'"

            if (Test-Path $this.ConfigPath) {
                $jsonContent = Get-Content $this.ConfigPath -Raw -Encoding UTF8
                $this.ConfigData = $jsonContent | ConvertFrom-Json
                Write-Verbose "[INFO] Loaded config from: $($this.ConfigPath)"
            } else {
                Write-Verbose "[INFO] Config file not found, generating default configuration"

                # Generate default configuration programmatically
                $this.ConfigData = $this.GetDefaultConfig()
                Write-Verbose "[INFO] Default configuration created"

                # Auto-save the default configuration to disk
                try {
                    # Ensure the config directory exists
                    $configDir = Split-Path $this.ConfigPath -Parent
                    if (-not (Test-Path $configDir)) {
                        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                        Write-Verbose "[INFO] Created config directory: $configDir"
                    }

                    # Save the configuration using the JSON helper
                    Save-ConfigJson -ConfigData $this.ConfigData -ConfigPath $this.ConfigPath
                    Write-Verbose "[INFO] Auto-saved default configuration to: $($this.ConfigPath)"
                } catch {
                    Write-Warning "[WARNING] Failed to auto-save default configuration: $($_.Exception.Message)"
                    # Continue anyway - the in-memory config is still valid
                }
            }

            Write-Verbose "[INFO] Config data loaded, initializing order arrays"

            # Initialize games._order array for improved version
            $this.InitializeGameOrder()

            # Initialize managedApps._order array for improved version
            $this.InitializeAppOrder()

            Write-Verbose "[INFO] LoadConfiguration completed successfully"

        } catch {
            Write-Error "[ERROR] LoadConfiguration failed with error: $($_.Exception.Message)"
            Show-SafeMessage -MessageKey "configLoadError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
            # Create default config
            $this.ConfigData = [PSCustomObject]@{
                language = ""
                obs = [PSCustomObject]@{
                    websocket = [PSCustomObject]@{
                        host = "127.0.0.1"
                        port = 4455
                        password = ""
                    }
                    replayBuffer = $true
                }
                managedApps = [PSCustomObject]@{}
                games = [PSCustomObject]@{}
                paths = [PSCustomObject]@{
                    steam = ""
                    obs = ""
                }
            }
            Write-Verbose "[INFO] Default config created"
        }
    }

    [void] SetModified() {
        $this.HasUnsavedChanges = $true
    }

    <#
    .SYNOPSIS
        Clears the modified flag.

    .DESCRIPTION
        Marks the configuration as not having unsaved changes.
        Useful when saving configuration or when intentionally discarding changes.
    #>
    [void] ClearModified() {
        $this.HasUnsavedChanges = $false
        Write-Verbose "[INFO] Configuration marked as not modified"
    }

    [bool] TestHasUnsavedChanges() {
        return $this.HasUnsavedChanges
    }

    <#
    .SYNOPSIS
        Returns the default configuration structure.

    .DESCRIPTION
        Provides a programmatically-defined default configuration as a PSCustomObject.
        This eliminates the need for an external config.json.sample file.

    .OUTPUTS
        PSCustomObject - Complete default configuration structure
    #>
    hidden [PSCustomObject] GetDefaultConfig() {
        Write-Verbose "[INFO] Creating default configuration structure"

        $defaultConfig = [PSCustomObject]@{
            managedApps = [PSCustomObject]@{
                _order = @("noWinKey")
                noWinKey = [PSCustomObject]@{
                    path = "C:/Apps/NoWinKey/NoWinKey.exe"
                    processName = "NoWinKey"
                    arguments = ""
                    gameStartAction = "start-process"
                    gameEndAction = "stop-process"
                    terminationMethod = "force"
                    gracefulTimeoutMs = 5000
                    displayName = "noWinKey"
                    _comment = ""
                }
            }
            games = [PSCustomObject]@{
                _order = @("mock-calc", "apex", "valorant", "fallguys")
                "mock-calc" = [PSCustomObject]@{
                    _comment = "A lightweight mock game for development and testing. Uses the calculator instead of a real game"
                    name = "Test Game (Calculator)"
                    platform = "direct"
                    executablePath = "C:/Windows/System32/calc.exe"
                    processName = "CalculatorApp*"
                    appsToManage = @()
                    steamAppId = ""
                    epicGameId = ""
                    riotGameId = ""
                    integrations = [PSCustomObject]@{
                        useOBS = $true
                        useDiscord = $false
                        useVTubeStudio = $false
                    }
                }
                valorant = [PSCustomObject]@{
                    name = "VALORANT"
                    platform = "riot"
                    riotGameId = "valorant"
                    processName = "VALORANT-Win64-Shipping*"
                    appsToManage = @()
                    integrations = [PSCustomObject]@{
                        useOBS = $true
                        useDiscord = $false
                        useVTubeStudio = $true
                    }
                    steamAppId = ""
                    epicGameId = ""
                    executablePath = ""
                }
                apex = [PSCustomObject]@{
                    name = "Apex Legends"
                    platform = "steam"
                    steamAppId = "1172470"
                    processName = "r5apex*"
                    appsToManage = @()
                    epicGameId = ""
                    riotGameId = ""
                    executablePath = ""
                    integrations = [PSCustomObject]@{
                        useOBS = $true
                        useDiscord = $false
                        useVTubeStudio = $false
                    }
                }
                "fall-guys" = [PSCustomObject]@{
                    name = "Fall Guys"
                    platform = "epic"
                    steamAppId = ""
                    epicGameId = "apps/50118b7f954e450f8823df1614b24e80%3A38ec4849ea4f4de6aa7b6fb0f2d278e1%3A0a2d9f6403244d12969e11da6713137b?action=launch&silent=true"
                    riotGameId = ""
                    processName = "FallGuys*"
                    appsToManage = @()
                    executablePath = ""
                    integrations = [PSCustomObject]@{
                        useOBS = $false
                        useDiscord = $false
                        useVTubeStudio = $false
                    }
                }
            }
            paths = [PSCustomObject]@{
                steam = "C:/Program Files (x86)/Steam/steam.exe"
                epic = "C:/Program Files (x86)/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe"
                riot = "C:/Riot Games/Riot Client/RiotClientElectron/Riot Client.exe"
            }
            integrations = [PSCustomObject]@{
                obs = [PSCustomObject]@{
                    path = "C:/Program Files/obs-studio/bin/64bit/obs64.exe"
                    processName = "obs64"
                    gameStartAction = "enter-game-mode"
                    gameEndAction = "exit-game-mode"
                    arguments = ""
                    terminationMethod = "graceful"
                    gracefulTimeoutMs = 5000
                    websocket = [PSCustomObject]@{
                        host = "127.0.0.1"
                        port = 4455
                        password = ""
                    }
                    replayBuffer = $true
                }
                discord = [PSCustomObject]@{
                    path = "%LOCALAPPDATA%/Discord/app-*/Discord.exe"
                    processName = "Discord"
                    gameStartAction = "enter-game-mode"
                    gameEndAction = "stop-process"
                    arguments = ""
                    terminationMethod = "graceful"
                    gracefulTimeoutMs = 8000
                    _comment = "Set a longer timeout in graceful mode for Discord, as it may be in the middle of a call or saving settings."
                    discord = [PSCustomObject]@{
                        statusOnGameStart = "dnd"
                        statusOnGameEnd = "online"
                        disableOverlay = $true
                        customPresence = [PSCustomObject]@{
                            enabled = $false
                            state = "Focus Gaming Mode"
                        }
                        rpc = [PSCustomObject]@{
                            enabled = $false
                            applicationId = ""
                        }
                    }
                }
                vtubeStudio = [PSCustomObject]@{
                    path = "C:/Program Files (x86)/Steam/steam.exe"
                    processName = "VTube Studio"
                    gameStartAction = "enter-game-mode"
                    gameEndAction = "exit-game-mode"
                    arguments = ""
                    steamPath = ""
                    websocket = [PSCustomObject]@{
                        host = "127.0.0.1"
                        port = 8001
                        enabled = $false
                    }
                }
            }
            logging = [PSCustomObject]@{
                level = "Debug"
                _comment = "Logging levels: Trace, Debug, Info, Warning, Error, Critical"
                enableFileLogging = $true
                enableConsoleLogging = $true
                filePath = ""
                logRetentionDays = 30
                enableNotarization = $false
                firebase = [PSCustomObject]@{
                    projectId = ""
                    apiKey = ""
                    databaseURL = ""
                }
            }
            tabVisibility = [PSCustomObject]@{
                showOBS = $true
                showDiscord = $true
                showVTubeStudio = $true
                showVoiceMeeter = $true
            }
            language = ""
        }

        Write-Verbose "[INFO] Default configuration structure created successfully"
        return $defaultConfig
    }

    # Initialize games._order array with enhanced version structure
    [void] InitializeGameOrder() {
        try {
            Write-Verbose "[INFO] InitializeGameOrder started"

            if (-not $this.ConfigData.games) {
                $this.ConfigData.games = [PSCustomObject]@{}
                Write-Verbose "[INFO] Created empty games object"
            }

            # Check if _order exists and is valid
            if (-not $this.ConfigData.games.PSObject.Properties['_order'] -or -not $this.ConfigData.games._order) {
                Write-Verbose "[INFO] games._order not found in config. Initializing."
                $gameIds = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                Write-Verbose "[INFO] Found $($gameIds.Count) existing games"
                $this.ConfigData.games | Add-Member -MemberType NoteProperty -Name "_order" -Value $gameIds -Force
            } else {
                Write-Verbose "[INFO] games._order exists, validating..."
                # Validate existing _order against actual games
                $existingGames = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                $validGameOrder = @()

                # Keep games that exist in both _order and games
                foreach ($gameId in $this.ConfigData.games._order) {
                    if ($gameId -in $existingGames) {
                        $validGameOrder += $gameId
                    }
                }

                # Add games that exist but are not in _order
                foreach ($gameId in $existingGames) {
                    if ($gameId -notin $validGameOrder) {
                        $validGameOrder += $gameId
                    }
                }

                # Update _order if changes were made
                if ($validGameOrder.Count -ne $this.ConfigData.games._order.Count -or
                    (Compare-Object $validGameOrder $this.ConfigData.games._order)) {
                    Write-Verbose "[INFO] Updating games._order with validated games"
                    $this.ConfigData.games._order = $validGameOrder
                }
            }
            Write-Verbose "[INFO] InitializeGameOrder completed"
        } catch {
            Write-Error "[ERROR] Failed to initialize game order: $($_.Exception.Message)"
            Write-Error "[ERROR] InitializeGameOrder exception details: $($_.Exception.ToString())"
            # Fallback to simple array of existing games
            $gameIds = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
            $this.ConfigData.games | Add-Member -MemberType NoteProperty -Name "_order" -Value $gameIds -Force
        }
    }

    # Initialize managedApps._order array with enhanced version structure
    [void] InitializeAppOrder() {
        try {
            Write-Verbose "[INFO] InitializeAppOrder started"

            if (-not $this.ConfigData.managedApps) {
                $this.ConfigData.managedApps = [PSCustomObject]@{}
                Write-Verbose "[INFO] Created empty managedApps object"
            }

            # Check if _order exists and is valid
            if (-not $this.ConfigData.managedApps.PSObject.Properties['_order'] -or -not $this.ConfigData.managedApps._order) {
                Write-Verbose "[INFO] managedApps._order not found in config. Initializing."
                $appIds = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                Write-Verbose "[INFO] Found $($appIds.Count) existing apps"
                $this.ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name "_order" -Value $appIds -Force
            } else {
                Write-Verbose "[INFO] managedApps._order exists, validating..."
                # Validate existing _order against actual apps
                $existingApps = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                $validAppOrder = @()

                # Keep apps that exist in both _order and managedApps
                foreach ($appId in $this.ConfigData.managedApps._order) {
                    if ($appId -in $existingApps) {
                        $validAppOrder += $appId
                    }
                }

                # Add apps that exist but are not in _order
                foreach ($appId in $existingApps) {
                    if ($appId -notin $validAppOrder) {
                        $validAppOrder += $appId
                    }
                }

                # Update _order if changes were made
                if ($validAppOrder.Count -ne $this.ConfigData.managedApps._order.Count -or
                    (Compare-Object $validAppOrder $this.ConfigData.managedApps._order)) {
                    Write-Verbose "[INFO] Updating managedApps._order with validated apps"
                    $this.ConfigData.managedApps._order = $validAppOrder
                }
            }
            Write-Verbose "[INFO] InitializeAppOrder completed"
        } catch {
            Write-Error "[ERROR] Failed to initialize app order: $($_.Exception.Message)"
            Write-Error "[ERROR] InitializeAppOrder exception details: $($_.Exception.ToString())"
            # Fallback to simple array of existing apps
            $appIds = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
            $this.ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name "_order" -Value $appIds -Force
        }
    }

    # Store original configuration for comparison
    [void] SaveOriginalConfig() {
        try {
            Write-Verbose "[INFO] SaveOriginalConfig started"

            if ($this.ConfigData) {
                $this.OriginalConfigData = ConvertTo-Json4Space -InputObject $this.ConfigData -Depth 10
                Write-Verbose "[INFO] Original configuration saved for change tracking"
                Write-Verbose "[INFO] Original config saved successfully"
            } else {
                Write-Verbose "[INFO] No configuration data to save for change tracking"
                Write-Verbose "[INFO] No config data to save"
                $this.OriginalConfigData = $null
            }
        } catch {
            Write-Warning "[WARNING] Failed to save original configuration: $($_.Exception.Message)"
            Write-Error "[ERROR] SaveOriginalConfig exception details: $($_.Exception.ToString())"
            $this.OriginalConfigData = $null
            # Don't throw - this should not cause initialization to fail
        }
    }
}
