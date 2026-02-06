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

    # Phase 2: Auto-backup timer properties
    [System.Timers.Timer]$AutoBackupTimer
    [string]$AutoSavePath
    [string]$LockFilePath

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

        # Phase 2: Initialize auto-backup properties
        $this.AutoBackupTimer = $null
        $this.AutoSavePath = "$configPath.autosave"
        $this.LockFilePath = "$configPath.lock"

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
        Provides a minimal default configuration as a PSCustomObject.
        Users should add games and managed apps through the GUI after initial setup.
        Eliminates the need for an external config.json.sample file.

    .OUTPUTS
        PSCustomObject - Minimal default configuration structure with empty collections
    #>
    hidden [PSCustomObject] GetDefaultConfig() {
        Write-Verbose "[INFO] Creating minimal default configuration structure"

        $defaultConfig = [PSCustomObject]@{
            managedApps = [PSCustomObject]@{
                _order = @()
            }
            games = [PSCustomObject]@{
                _order = @()
            }
            paths = [PSCustomObject]@{
                steam = ""
                epic = ""
                riot = ""
            }
            integrations = [PSCustomObject]@{
                obs = [PSCustomObject]@{
                    path = ""
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
                    path = ""
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
                    path = ""
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

    # Phase 2: Start auto-backup timer (1-minute interval)
    [void] StartAutoBackupTimer() {
        try {
            if ($this.AutoBackupTimer) {
                Write-Verbose "[INFO] Auto-backup timer already running"
                return
            }

            Write-Verbose "[INFO] Starting auto-backup timer (60-second interval)"

            # Create timer with 60-second interval (1 minute)
            $this.AutoBackupTimer = New-Object System.Timers.Timer
            $this.AutoBackupTimer.Interval = 60000  # 60 seconds in milliseconds
            $this.AutoBackupTimer.AutoReset = $true

            # Capture this object for the timer callback
            $stateManager = $this

            # Register elapsed event handler
            $timerAction = {
                try {
                    $stateManager = $Event.MessageData
                    if ($stateManager.HasUnsavedChanges) {
                        Write-Verbose "[AUTO-BACKUP] Changes detected, creating auto-backup"

                        # Save to .autosave file
                        Save-ConfigJson -ConfigData $stateManager.ConfigData -ConfigPath $stateManager.AutoSavePath -Depth 10

                        Write-Verbose "[AUTO-BACKUP] Auto-backup saved to: $($stateManager.AutoSavePath)"
                    } else {
                        Write-Verbose "[AUTO-BACKUP] No unsaved changes, skipping backup"
                    }
                } catch {
                    Write-Warning "[AUTO-BACKUP] Failed to create auto-backup: $($_.Exception.Message)"
                }
            }

            Register-ObjectEvent -InputObject $this.AutoBackupTimer -EventName Elapsed -Action $timerAction -MessageData $stateManager | Out-Null

            # Start the timer
            $this.AutoBackupTimer.Start()

            Write-Verbose "[INFO] Auto-backup timer started successfully"
        } catch {
            Write-Warning "[WARNING] Failed to start auto-backup timer: $($_.Exception.Message)"
            $this.AutoBackupTimer = $null
        }
    }

    # Phase 2: Stop auto-backup timer
    [void] StopAutoBackupTimer() {
        try {
            if ($this.AutoBackupTimer) {
                Write-Verbose "[INFO] Stopping auto-backup timer"
                $this.AutoBackupTimer.Stop()
                $this.AutoBackupTimer.Dispose()
                $this.AutoBackupTimer = $null

                # Unregister event
                Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.Timers.Timer] } | Unregister-Event

                Write-Verbose "[INFO] Auto-backup timer stopped"
            }
        } catch {
            Write-Warning "[WARNING] Error stopping auto-backup timer: $($_.Exception.Message)"
        }
    }

    # Phase 2: Create lock file to prevent multiple instances
    [bool] CreateLockFile() {
        try {
            if (Test-Path $this.LockFilePath) {
                # Check if the lock file is stale (process no longer exists)
                try {
                    $lockContent = Get-Content $this.LockFilePath -Raw
                    $lockPid = [int]$lockContent

                    # Check if process with this PID exists
                    $process = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
                    if ($process) {
                        Write-Warning "[WARNING] Another instance is already running (PID: $lockPid)"
                        return $false
                    } else {
                        Write-Verbose "[INFO] Stale lock file found (PID $lockPid no longer exists), removing"
                        Remove-Item $this.LockFilePath -Force
                    }
                } catch {
                    Write-Verbose "[INFO] Invalid lock file format, removing"
                    Remove-Item $this.LockFilePath -Force -ErrorAction SilentlyContinue
                }
            }

            # Create new lock file with current PID
            $PID | Out-File -FilePath $this.LockFilePath -Encoding ASCII -Force
            Write-Verbose "[INFO] Lock file created: $($this.LockFilePath) (PID: $PID)"
            return $true
        } catch {
            Write-Warning "[WARNING] Failed to create lock file: $($_.Exception.Message)"
            return $true  # Don't block startup if lock file creation fails
        }
    }

    # Phase 2: Remove lock file on clean exit
    [void] RemoveLockFile() {
        try {
            if (Test-Path $this.LockFilePath) {
                Remove-Item $this.LockFilePath -Force
                Write-Verbose "[INFO] Lock file removed: $($this.LockFilePath)"
            }
        } catch {
            Write-Warning "[WARNING] Failed to remove lock file: $($_.Exception.Message)"
        }
    }

    # Phase 2: Check if auto-save file exists
    [bool] HasAutoSaveFile() {
        return (Test-Path $this.AutoSavePath)
    }

    # Phase 2: Get auto-save file timestamp
    [DateTime] GetAutoSaveFileTime() {
        if ($this.HasAutoSaveFile()) {
            return (Get-Item $this.AutoSavePath).LastWriteTime
        }
        return [DateTime]::MinValue
    }

    # Phase 2: Load configuration from auto-save file
    [void] LoadFromAutoSave() {
        try {
            if ($this.HasAutoSaveFile()) {
                Write-Verbose "[INFO] Loading configuration from auto-save file"
                $jsonContent = Get-Content $this.AutoSavePath -Raw -Encoding UTF8
                $this.ConfigData = $jsonContent | ConvertFrom-Json

                # Initialize order arrays
                $this.InitializeGameOrder()
                $this.InitializeAppOrder()

                Write-Verbose "[INFO] Configuration loaded from auto-save successfully"
                $this.SetModified()  # Mark as modified since it's from autosave
            }
        } catch {
            Write-Error "[ERROR] Failed to load from auto-save: $($_.Exception.Message)"
            throw
        }
    }

    # Phase 2: Delete auto-save file
    [void] DeleteAutoSaveFile() {
        try {
            if (Test-Path $this.AutoSavePath) {
                Remove-Item $this.AutoSavePath -Force
                Write-Verbose "[INFO] Auto-save file deleted: $($this.AutoSavePath)"
            }
        } catch {
            Write-Warning "[WARNING] Failed to delete auto-save file: $($_.Exception.Message)"
        }
    }
}
