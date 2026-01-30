<#
.SYNOPSIS
    Application Manager Module - Unified application lifecycle management.

.DESCRIPTION
    This module provides centralized management for application processes,
    including starting, stopping, and executing custom actions on managed applications.

.NOTES
    File Name  : AppManager.ps1
    Author     : Focus Game Deck Team
    Requires   : PowerShell 5.1 or later
#>

<#
.SYNOPSIS
    Main class for managing application lifecycles.

.DESCRIPTION
    Handles starting, stopping, and validating application configurations.
    Supports various application actions including process management, hotkey toggling,
    and integration with other services like VTube Studio and Discord.

.EXAMPLE
    $appManager = [AppManager]::new($config, $messages)
    $appManager.InvokeAction("discord", "start-process")

.EXAMPLE
    $appManager = [AppManager]::new($config, $messages)
    $appManager.StopProcess("vtube-studio", $appConfig)
#>
class AppManager {
    [object] $Config
    [object] $Messages
    [object] $Logger
    [object] $GameConfig
    [object] $ManagedApps
    [hashtable] $IntegrationManagers
    [string] $PreviousOBSScene

    <#
    .SYNOPSIS
        Initializes a new AppManager instance.

    .DESCRIPTION
        Creates an application manager with the provided configuration and localization messages.

    .PARAMETER config
        Configuration object containing managed apps settings

    .PARAMETER messages
        Localization messages object for internationalized output

    .EXAMPLE
        $appManager = [AppManager]::new($config, $messages)
    #>
    # Constructor
    AppManager([object] $config, [object] $messages, [object] $logger) {
        $this.Config = $config
        $this.Messages = $messages
        $this.Logger = $logger
        $this.ManagedApps = $config.managedApps
        $this.IntegrationManagers = @{}
    }

    <#
    .SYNOPSIS
        Sets the game context and initializes integration managers.

    .DESCRIPTION
        Configures the AppManager for a specific game by setting the game configuration
        and initializing integration managers based on the game's integration settings.

    .PARAMETER gameConfig
        The game configuration object containing integration settings

    .EXAMPLE
        $appManager.SetGameContext($gameConfig)
    #>
    [void] SetGameContext([object] $gameConfig) {
        $this.GameConfig = $gameConfig
        [void]$this.InitializeIntegrationManagers()
    }

    <#
    .SYNOPSIS
        Initializes integration managers based on game configuration.

    .DESCRIPTION
        Creates manager instances for enabled integrations (OBS, Discord, VTube Studio).
        Only initializes managers for integrations that are both enabled in the game
        configuration and properly configured in the main configuration.

    .EXAMPLE
        $appManager.InitializeIntegrationManagers()
    #>
    [void] InitializeIntegrationManagers() {
        $this.IntegrationManagers.Clear()

        if (-not $this.GameConfig) {
            return
        }

        # OBS Manager
        if ($this.GameConfig.integrations.useOBS -and $this.Config.integrations.obs) {
            $this.IntegrationManagers['obs'] = New-OBSManager `
                -OBSConfig $this.Config.integrations.obs `
                -Messages $this.Messages
            if ($this.Logger) {
                $this.Logger.Info("OBS manager initialized", "APP")
            }
        }

        # TODO: Re-enable in future release
        # Disabled for v1.0 - Discord integration has known bugs
        # Discord Manager
        if ($false) { # Disabled for v1.0
            if ($this.GameConfig.integrations.useDiscord -and $this.Config.integrations.discord) {
                $this.IntegrationManagers['discord'] = New-DiscordManager `
                    -DiscordConfig $this.Config.integrations.discord `
                    -Messages $this.Messages
                if ($this.Logger) {
                    $this.Logger.Info("Discord manager initialized", "APP")
                }
            }
        }

        # VTube Studio Manager
        if ($this.GameConfig.integrations.useVTubeStudio -and $this.Config.integrations.vtubeStudio) {
            $this.IntegrationManagers['vtubeStudio'] = New-VTubeStudioManager `
                -VTubeConfig $this.Config.integrations.vtubeStudio `
                -Messages $this.Messages
            if ($this.Logger) {
                $this.Logger.Info("VTube Studio manager initialized", "APP")
            }
        }

        # VoiceMeeter Manager
        if ($this.GameConfig.integrations.useVoiceMeeter -and $this.Config.integrations.voiceMeeter) {
            $this.IntegrationManagers['voiceMeeter'] = New-VoiceMeeterManager `
                -VoiceMeeterConfig $this.Config.integrations.voiceMeeter `
                -Messages $this.Messages `
                -Logger $this.Logger
            if ($this.Logger) {
                $this.Logger.Info("VoiceMeeter manager initialized", "APP")
            }
        }
    }

    <#
    .SYNOPSIS
        Builds the complete list of applications to manage for the current game.

    .DESCRIPTION
        Combines game-specific applications with enabled integration applications
        to create a unified list for startup/shutdown sequences.

    .OUTPUTS
        Array of application IDs to manage

    .EXAMPLE
        $apps = $appManager.GetManagedApplications()
    #>
    [array] GetManagedApplications() {
        $orderedApps = [System.Collections.ArrayList]::new()
        $addedApps = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        if (-not $this.GameConfig) {
            return $orderedApps
        }

        if ($this.GameConfig.appsToManage) {
            foreach ($appId in $this.GameConfig.appsToManage) {
                if ($addedApps.Add($appId)) {
                    [void]$orderedApps.Add($appId)
                }
            }
        }

        # add integration apps that are enabled but not already in the list
        foreach ($integrationKey in $this.IntegrationManagers.Keys) {
            if ($addedApps.Add($integrationKey)) {
                [void]$orderedApps.Add($integrationKey)
            }
        }

        return $orderedApps.ToArray()
    }

    <#
    .SYNOPSIS
        Executes an action on a managed application.

    .DESCRIPTION
        Validates the application configuration and executes the specified action.
        Supported actions include:
        - start-process: Start the application process
        - stop-process: Stop the application process
        - toggle-hotkeys: Toggle hotkey functionality
        - start-vtube-studio: Start VTube Studio integration
        - stop-vtube-studio: Stop VTube Studio integration
        - set-discord-gaming-mode: Enable Discord gaming mode
        - restore-discord-normal: Restore Discord to normal mode
        - pause-wallpaper: Pause wallpaper animations
        - play-wallpaper: Resume wallpaper animations
        - none: No action (returns true)

    .PARAMETER appId
        The application ID to perform the action on

    .PARAMETER action
        The action to execute

    .OUTPUTS
        Boolean indicating whether the action was successful

    .EXAMPLE
        $success = $appManager.InvokeAction("discord", "start-process")
    #>
    # Execute application action
    [bool] InvokeAction([string] $appId, [string] $action) {
        # Check if this is an integration
        if ($this.IntegrationManagers.ContainsKey($appId)) {
            return $this.InvokeIntegrationAction($appId, $action)
        }

        $appConfig = $this.ManagedApps.$appId

        switch ($action) {
            "start-process" {
                return $this.StartProcess($appId, $appConfig)
            }
            "stop-process" {
                return $this.StopProcess($appId, $appConfig)
            }
            "none" {
                return $true
            }
            default {
                Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_action" -Args @($action, $appId) -Default ("Unknown action '{0}' for app '{1}'" -f $action, $appId) -Level "WARNING" -Component "AppManager"
                return $false
            }
        }
        return $false
    }

    <#
    .SYNOPSIS
        Handles integration-specific actions.

    .DESCRIPTION
        Routes integration actions to the appropriate handler based on integration type.
        Supports OBS, Discord, and VTube Studio integrations.

    .PARAMETER integrationId
        The integration ID (obs, discord, vtubeStudio)

    .PARAMETER action
        The action to execute

    .OUTPUTS
        Boolean indicating whether the action was successful

    .EXAMPLE
        $success = $appManager.InvokeIntegrationAction("obs", "start-process")
    #>
    [bool] InvokeIntegrationAction([string] $integrationId, [string] $action) {
        $manager = $this.IntegrationManagers[$integrationId]
        $integrationConfig = $this.Config.integrations.$integrationId

        if (-not $manager) {
            Write-LocalizedHost -Messages $this.Messages -Key "console_integration_not_found" -Args @($integrationId) -Default ("Integration manager not found: {0}" -f $integrationId) -Level "WARNING" -Component "AppManager"
            return $false
        }

        switch ($integrationId) {
            "obs" {
                return $this.HandleOBSAction($manager, $integrationConfig, $action)
            }
            "discord" {
                return $this.HandleDiscordAction($manager, $integrationConfig, $action)
            }
            "vtubeStudio" {
                return $this.HandleVTubeStudioAction($manager, $integrationConfig, $action)
            }
            "voiceMeeter" {
                return $this.HandleVoiceMeeterAction($manager, $integrationConfig, $action)
            }
            default {
                Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_integration" -Args @($integrationId) -Default ("Unknown integration: {0}" -f $integrationId) -Level "WARNING" -Component "AppManager"
                return $false
            }
        }

        return $false
    }

    <#
    .SYNOPSIS
        Handles OBS-specific actions.

    .DESCRIPTION
        Manages OBS startup and shutdown including replay buffer control.

    .PARAMETER manager
        The OBS manager instance

    .PARAMETER config
        The OBS configuration object

    .PARAMETER action
        The action to execute

    .OUTPUTS
        Boolean indicating whether the action was successful

    .EXAMPLE
        $success = $appManager.HandleOBSAction($obsManager, $config, "start-process")
    #>
    [bool] HandleOBSAction([object] $manager, [object] $config, [string] $action) {
        switch ($action) {
            "enter-game-mode" {
                if ($this.Logger) { $this.Logger.Info("Starting OBS integration", "OBS") }

                $success = $manager.StartOBS()
                if ($success) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_obs_started" -Default "OBS started successfully" -Level "OK" -Component "OBSManager"
                    if ($this.Logger) { $this.Logger.Info("OBS started successfully", "OBS") }
                } else {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_obs_failed" -Default "Failed to start OBS" -Level "WARNING" -Component "OBSManager"
                    if ($this.Logger) { $this.Logger.Warning("Failed to start OBS", "OBS") }
                    return $success
                }

                # Evaluate replay buffer behavior
                $shouldStartReplayBuffer = $false
                $gameObsSettings = if ($this.GameConfig.integrations.obsSettings) { $this.GameConfig.integrations.obsSettings } else { $null }
                $replayBufferBehavior = if ($gameObsSettings -and $gameObsSettings.replayBufferBehavior) { $gameObsSettings.replayBufferBehavior } else { "UseGlobal" }

                switch ($replayBufferBehavior) {
                    "Enable" {
                        $shouldStartReplayBuffer = $true
                        if ($this.Logger) { $this.Logger.Info("Game-specific OBS setting: Force enable replay buffer", "OBS") }
                    }
                    "Disable" {
                        $shouldStartReplayBuffer = $false
                        if ($this.Logger) { $this.Logger.Info("Game-specific OBS setting: Force disable replay buffer", "OBS") }
                    }
                    default {
                        # UseGlobal
                        $shouldStartReplayBuffer = $config.replayBuffer -eq $true
                        if ($this.Logger) { $this.Logger.Info("Using global OBS replay buffer setting: $($config.replayBuffer)", "OBS") }
                    }
                }

                # Handle scene switching
                $targetSceneName = if ($gameObsSettings -and $gameObsSettings.targetSceneName) { $gameObsSettings.targetSceneName.Trim() } else { "" }
                $enableRollback = ($gameObsSettings -and $gameObsSettings.enableRollback) -eq $true

                if ($targetSceneName) {
                    Start-Sleep -Milliseconds 2000
                    $connectSuccess = $manager.Connect()
                    if ($connectSuccess) {
                        try {
                            # Get current scene before switching (for rollback)
                            if ($enableRollback) {
                                $this.PreviousOBSScene = $manager.GetCurrentProgramScene()
                                if ($this.PreviousOBSScene) {
                                    if ($this.Logger) { $this.Logger.Info("Saved current OBS scene for rollback: $($this.PreviousOBSScene)", "OBS") }
                                }
                            }

                            # Switch to target scene
                            $sceneSuccess = $manager.SetCurrentProgramScene($targetSceneName)
                            if ($sceneSuccess) {
                                if ($this.Logger) { $this.Logger.Info("Switched OBS scene to: $targetSceneName", "OBS") }
                            } else {
                                if ($this.Logger) { $this.Logger.Warning("Failed to switch OBS scene", "OBS") }
                            }
                        } finally {
                            if (-not $shouldStartReplayBuffer) {
                                $manager.Disconnect()
                            }
                        }
                    } else {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_obs_websocket_failed" -Default "Failed to connect to OBS websocket" -Level "WARNING" -Component "OBSManager"
                        if ($this.Logger) { $this.Logger.Warning("Failed to connect to OBS websocket for scene switching", "OBS") }
                    }
                }

                # Handle replay buffer if needed
                if ($shouldStartReplayBuffer) {
                    # Start replay buffer in background job to avoid blocking game launch
                    Write-LocalizedHost -Messages $this.Messages -Key "console_obs_replay_buffer_starting_async" -Default "Starting OBS replay buffer asynchronously..." -Level "INFO" -Component "OBSManager"
                    if ($this.Logger) { $this.Logger.Info("Starting OBS replay buffer in background job", "OBS") }

                    # Determine application root
                    $currentProcess = Get-Process -Id $PID
                    $isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'
                    if ($isExecutable) {
                        $appRoot = Split-Path -Parent $currentProcess.Path
                    } else {
                        # For script mode: AppManager.ps1 is in src/modules, need to go up two levels
                        $appRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
                    }

                    # Prepare parameters for background script
                    $backgroundScriptPath = Join-Path -Path $appRoot -ChildPath "src/modules/OBSReplayBufferBackground.ps1"
                    $logFilePath = if ($this.Logger -and $this.Logger.FilePath) { $this.Logger.FilePath } else { $null }

                    # Start background job
                    $jobStarted = $false
                    try {
                        $job = Start-Job -ScriptBlock {
                            param($scriptPath, $obsConfig, $messages, $logPath, $appRootPath)
                            & $scriptPath -OBSConfig $obsConfig -Messages $messages -LogFilePath $logPath -WaitBeforeConnect 3000 -AppRoot $appRootPath
                        } -ArgumentList $backgroundScriptPath, $config, $this.Messages, $logFilePath, $appRoot

                        $jobStarted = $true
                        if ($this.Logger) {
                            $this.Logger.Info("Background job started for OBS replay buffer (Job ID: $($job.Id))", "OBS")
                        }

                        # Store job reference for potential cleanup
                        if (-not $this.Config.PSObject.Properties['BackgroundJobs']) {
                            $this.Config | Add-Member -NotePropertyName 'BackgroundJobs' -NotePropertyValue @{} -Force
                        }
                        $this.Config.BackgroundJobs['OBSReplayBuffer'] = $job

                        Write-LocalizedHost -Messages $this.Messages -Key "console_obs_replay_buffer_async_started" -Default "OBS replay buffer starting in background (non-blocking)" -Level "OK" -Component "OBSManager"
                    } catch {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_obs_replay_buffer_job_failed" -Default "Failed to start background job for replay buffer" -Level "WARNING" -Component "OBSManager"
                        if ($this.Logger) { $this.Logger.Warning("Failed to start background job for OBS replay buffer: $_", "OBS") }
                        return $false
                    }

                    # Return success only if job was started
                    return $jobStarted
                }

                return $true
            }
            "exit-game-mode" {
                $success = $true

                # Evaluate replay buffer behavior for stopping
                $gameObsSettings = if ($this.GameConfig.integrations.obsSettings) { $this.GameConfig.integrations.obsSettings } else { $null }
                $replayBufferBehavior = if ($gameObsSettings -and $gameObsSettings.replayBufferBehavior) { $gameObsSettings.replayBufferBehavior } else { "UseGlobal" }

                $shouldStopReplayBuffer = $false
                switch ($replayBufferBehavior) {
                    "Enable" {
                        $shouldStopReplayBuffer = $true
                    }
                    "Disable" {
                        $shouldStopReplayBuffer = $false
                    }
                    default {
                        # UseGlobal
                        $shouldStopReplayBuffer = $config.replayBuffer -eq $true
                    }
                }

                # Handle scene rollback
                $enableRollback = ($gameObsSettings -and $gameObsSettings.enableRollback) -eq $true
                if ($enableRollback -and $this.PreviousOBSScene) {
                    if ($manager.Connect()) {
                        try {
                            $success = $manager.SetCurrentProgramScene($this.PreviousOBSScene)
                            if ($success) {
                                Write-LocalizedHost -Messages $this.Messages -Key "obs_scene_restored" -Args @($this.PreviousOBSScene) -Default "OBS scene restored to: {0}" -Level "OK" -Component "OBSManager"
                                if ($this.Logger) { $this.Logger.Info("Restored OBS scene to: $($this.PreviousOBSScene)", "OBS") }
                            }
                            $this.PreviousOBSScene = $null
                        } finally {
                            if (-not $shouldStopReplayBuffer) {
                                $manager.Disconnect()
                            }
                        }
                    }
                }

                # Handle replay buffer shutdown
                if ($shouldStopReplayBuffer) {
                    if (-not $manager.WebSocket -or $manager.WebSocket.State -ne "Open") {
                        if ($manager.Connect()) {
                            $success = $manager.StopReplayBuffer()
                            $manager.Disconnect()
                            if ($this.Logger) { $this.Logger.Info("OBS replay buffer stopped", "OBS") }
                        } else {
                            if ($this.Logger) { $this.Logger.Warning("Failed to stop OBS replay buffer", "OBS") }
                        }
                    } else {
                        $success = $manager.StopReplayBuffer()
                        $manager.Disconnect()
                        if ($this.Logger) { $this.Logger.Info("OBS replay buffer stopped", "OBS") }
                    }
                }

                return $success

                # # Stop OBS process
                # $processConfig = @{
                #     processName = $config.processName
                #     terminationMethod = if ($config.terminationMethod) { $config.terminationMethod } else { "graceful" }
                #     gracefulTimeoutMs = if ($config.gracefulTimeoutMs) { $config.gracefulTimeoutMs } else { 5000 }
                # }
                # return $this.StopProcess("obs", $processConfig)
            }
            "none" {
                return $true
            }
            default {
                Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_obs_action" -Args @($action) -Default ("Unknown action: {0}" -f $action) -Level "WARNING" -Component "OBSManager"
                return $false
            }
        }
        return $false
    }

    <#
    .SYNOPSIS
        Handles Discord-specific actions.

    .DESCRIPTION
        Manages Discord startup and shutdown including status changes.

    .PARAMETER manager
        The Discord manager instance

    .PARAMETER config
        The Discord configuration object

    .PARAMETER action
        The action to execute

    .OUTPUTS
        Boolean indicating whether the action was successful

    .EXAMPLE
        $success = $appManager.HandleDiscordAction($discordManager, $config, "start-process")
    #>
    [bool] HandleDiscordAction([object] $manager, [object] $config, [string] $action) {
        # TODO: Re-enable in future release
        # Disabled for v1.0 - Discord integration has known bugs
        if ($false) { # Disabled for v1.0
            switch ($action) {
                "enter-game-mode" {
                    if ($this.Logger) { $this.Logger.Info("Starting Discord integration", "Discord") }

                    $success = $manager.StartDiscord()

                    if ($success) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_discord_started" -Default "Discord started successfully" -Level "OK" -Component "DiscordManager"
                        if ($this.Logger) { $this.Logger.Info("Discord started successfully", "Discord") }
                    }

                    return $success
                }
                "exit-game-mode" {
                    if ($this.Logger) { $this.Logger.Info("Stopping Discord integration", "Discord") }

                    $success = $manager.StopDiscord()

                    if ($success) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_discord_stopped" -Default "Discord stopped successfully" -Level "OK" -Component "DiscordManager"
                        if ($this.Logger) { $this.Logger.Info("Discord stopped successfully", "Discord") }
                    }

                    return $success
                }
                "none" {
                    return $true
                }
                default {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_discord_action" -Args @($action) -Default ("Unknown action: {0}" -f $action) -Level "WARNING" -Component "DiscordManager"
                    return $false
                }
            }
            return $false
        }
        # When Discord is disabled, accept "none" action and reject all others
        return ($action -eq "none")
    }

    <#
    .SYNOPSIS
        Handles VTube Studio-specific actions.

    .DESCRIPTION
        Manages VTube Studio startup and shutdown using the dedicated manager.

    .PARAMETER manager
        The VTube Studio manager instance

    .PARAMETER config
        The VTube Studio configuration object

    .PARAMETER action
        The action to execute

    .OUTPUTS
        Boolean indicating whether the action was successful

    .EXAMPLE
        $success = $appManager.HandleVTubeStudioAction($vtubeManager, $config, "start-process")
    #>
    [bool] HandleVTubeStudioAction([object] $manager, [object] $config, [string] $action) {
        switch ($action) {
            "enter-game-mode" {
                if ($this.Logger) { $this.Logger.Info("Starting VTube Studio integration", "VTube") }

                # Start VTube Studio application
                $success = $manager.StartVTubeStudio()
                if (-not $success) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_startup_failed" -Default "Failed to start VTube Studio" -Level "WARNING" -Component "VTubeStudioManager"
                    if ($this.Logger) { $this.Logger.Warning("Failed to start VTube Studio", "VTube") }
                    return $false
                }

                # Get game-specific VTube Studio settings
                $vtubeSettings = $null
                if ($this.GameConfig -and $this.GameConfig.integrations -and $this.GameConfig.integrations.vtubeStudioSettings) {
                    $vtubeSettings = $this.GameConfig.integrations.vtubeStudioSettings
                }

                # Load model if specified
                if ($vtubeSettings -and $vtubeSettings.modelId) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_loading_model" -Args @($vtubeSettings.modelId) -Default "Loading VTube Studio model: {0}" -Level "INFO" -Component "VTubeStudioManager"
                    if ($this.Logger) { $this.Logger.Info("Loading model: $($vtubeSettings.modelId)", "VTube") }

                    $modelSuccess = $manager.LoadModel($vtubeSettings.modelId)
                    if (-not $modelSuccess) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_model_load_failed" -Args @($vtubeSettings.modelId) -Default "Failed to load model: {0}" -Level "WARNING" -Component "VTubeStudioManager"
                        if ($this.Logger) { $this.Logger.Warning("Failed to load model: $($vtubeSettings.modelId)", "VTube") }
                    }
                }

                # Trigger onLaunch hotkeys if specified
                if ($vtubeSettings -and $vtubeSettings.onLaunchHotkeys -and $vtubeSettings.onLaunchHotkeys.Count -gt 0) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_triggering_launch_hotkeys" -Default "Triggering VTube Studio launch hotkeys" -Level "INFO" -Component "VTubeStudioManager"
                    if ($this.Logger) { $this.Logger.Info("Triggering launch hotkeys", "VTube") }

                    $hotkeySuccess = $manager.TriggerHotkeys($vtubeSettings.onLaunchHotkeys)
                    if (-not $hotkeySuccess) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_hotkey_trigger_failed" -Default "Failed to trigger some hotkeys" -Level "WARNING" -Component "VTubeStudioManager"
                        if ($this.Logger) { $this.Logger.Warning("Failed to trigger some launch hotkeys", "VTube") }
                    }
                }

                return $success
            }
            "exit-game-mode" {
                if ($this.Logger) { $this.Logger.Info("Stopping VTube Studio integration", "VTube") }

                # Get game-specific VTube Studio settings
                $vtubeSettings = $null
                if ($this.GameConfig -and $this.GameConfig.integrations -and $this.GameConfig.integrations.vtubeStudioSettings) {
                    $vtubeSettings = $this.GameConfig.integrations.vtubeStudioSettings
                }

                # Trigger onExit hotkeys if specified
                if ($vtubeSettings -and $vtubeSettings.onExitHotkeys -and $vtubeSettings.onExitHotkeys.Count -gt 0) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_triggering_exit_hotkeys" -Default "Triggering VTube Studio exit hotkeys" -Level "INFO" -Component "VTubeStudioManager"
                    if ($this.Logger) { $this.Logger.Info("Triggering exit hotkeys", "VTube") }

                    $hotkeySuccess = $manager.TriggerHotkeys($vtubeSettings.onExitHotkeys)
                    if (-not $hotkeySuccess) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_exit_hotkey_failed" -Default "Failed to trigger some exit hotkeys" -Level "WARNING" -Component "VTubeStudioManager"
                        if ($this.Logger) { $this.Logger.Warning("Failed to trigger some exit hotkeys", "VTube") }
                    }
                }

                # Rollback to default model if configured
                $defaultModelId = $null
                if ($config -and $config.defaultModelId) {
                    $defaultModelId = $config.defaultModelId
                }

                if ($defaultModelId) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_restoring_default_model" -Args @($defaultModelId) -Default "Restoring default VTube Studio model: {0}" -Level "INFO" -Component "VTubeStudioManager"
                    if ($this.Logger) { $this.Logger.Info("Restoring default model: $defaultModelId", "VTube") }

                    $rollbackSuccess = $manager.LoadModel($defaultModelId)
                    if (-not $rollbackSuccess) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_vtube_default_model_failed" -Args @($defaultModelId) -Default "Failed to restore default model: {0}" -Level "WARNING" -Component "VTubeStudioManager"
                        if ($this.Logger) { $this.Logger.Warning("Failed to restore default model: $defaultModelId", "VTube") }
                    }
                }

                # Disconnect WebSocket to clean up resources
                $manager.DisconnectWebSocket()

                return $true
            }
            "none" {
                return $true
            }
            default {
                Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_vtube_action" -Args @($action) -Default ("Unknown action: {0}" -f $action) -Level "WARNING" -Component "VTubeStudioManager"
                return $false
            }
        }

        return $false
    }

    <#
    .SYNOPSIS
        Handles VoiceMeeter-specific actions.

    .DESCRIPTION
        Manages VoiceMeeter startup and shutdown including profile loading and parameter control.

    .PARAMETER manager
        The VoiceMeeter manager instance

    .PARAMETER config
        The VoiceMeeter configuration object

    .PARAMETER action
        The action to execute

    .OUTPUTS
        Boolean indicating whether the action was successful

    .EXAMPLE
        $success = $appManager.HandleVoiceMeeterAction($voiceMeeterManager, $config, "enter-game-mode")
    #>
    [bool] HandleVoiceMeeterAction([object] $manager, [object] $config, [string] $action) {
        switch ($action) {
            "enter-game-mode" {
                if ($this.Logger) { $this.Logger.Info("Starting VoiceMeeter integration", "VOICEMEETER") }

                # Connect to VoiceMeeter
                $success = $manager.Connect()
                if (-not $success) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_voicemeeter_connect_failed" -Default "Failed to connect to VoiceMeeter" -Level "WARNING" -Component "VoiceMeeterManager"
                    if ($this.Logger) { $this.Logger.Warning("Failed to connect to VoiceMeeter", "VOICEMEETER") }
                    return $false
                }

                # Get game-specific VoiceMeeter settings
                $voiceMeeterSettings = $null
                if ($this.GameConfig -and $this.GameConfig.integrations -and $this.GameConfig.integrations.voiceMeeterSettings) {
                    $voiceMeeterSettings = $this.GameConfig.integrations.voiceMeeterSettings
                }

                # Apply game settings or use default
                $applySuccess = $manager.ApplyGameSettings($voiceMeeterSettings)
                if ($applySuccess) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_voicemeeter_settings_applied" -Default "VoiceMeeter settings applied successfully" -Level "OK" -Component "VoiceMeeterManager"
                    if ($this.Logger) { $this.Logger.Info("VoiceMeeter settings applied successfully", "VOICEMEETER") }
                } else {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_voicemeeter_settings_failed" -Default "Failed to apply VoiceMeeter settings" -Level "WARNING" -Component "VoiceMeeterManager"
                    if ($this.Logger) { $this.Logger.Warning("Failed to apply VoiceMeeter settings", "VOICEMEETER") }
                }

                return $applySuccess
            }
            "exit-game-mode" {
                if ($this.Logger) { $this.Logger.Info("Stopping VoiceMeeter integration", "VOICEMEETER") }

                # Restore default settings
                $success = $manager.RestoreDefaultSettings()
                if ($success) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_voicemeeter_restored" -Default "VoiceMeeter settings restored" -Level "OK" -Component "VoiceMeeterManager"
                    if ($this.Logger) { $this.Logger.Info("VoiceMeeter settings restored", "VOICEMEETER") }
                } else {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_voicemeeter_restore_failed" -Default "Failed to restore VoiceMeeter settings" -Level "WARNING" -Component "VoiceMeeterManager"
                    if ($this.Logger) { $this.Logger.Warning("Failed to restore VoiceMeeter settings", "VOICEMEETER") }
                }

                # Disconnect from VoiceMeeter
                $manager.Disconnect()

                return $success
            }
            "none" {
                return $true
            }
            default {
                Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_voicemeeter_action" -Args @($action) -Default ("Unknown action: {0}" -f $action) -Level "WARNING" -Component "VoiceMeeterManager"
                return $false
            }
        }

        return $false
    }

    <#
    .SYNOPSIS
        Starts an application process.

    .DESCRIPTION
        Launches the application using its configured path and optional arguments.
        Validates the path exists before attempting to start the process.

    .PARAMETER appId
        The application ID to start

    .PARAMETER appConfig
        The application configuration object containing path and arguments

    .OUTPUTS
        Boolean indicating whether the process started successfully

    .EXAMPLE
        $success = $appManager.StartProcess("discord", $appConfig)

    .NOTES
        Supports applications with or without command-line arguments.
    #>
    # Start application process
    [bool] StartProcess([string] $appId, [object] $appConfig) {
        if (-not $appConfig.path -or $appConfig.path -eq "") {
            Write-LocalizedHost -Messages $this.Messages -Key "console_app_no_path" -Args @($appId) -Default ("No path specified for app '{0}'" -f $appId) -Level "WARNING" -Component "AppManager"
            return $false
        }

        if (-not (Test-Path $appConfig.path)) {
            Write-LocalizedHost -Messages $this.Messages -Key "console_app_path_not_found" -Args @($appConfig.path) -Default ("Application path not found: {0}" -f $appConfig.path) -Level "WARNING" -Component "AppManager"
            return $false
        }

        try {
            # Build Start-Process parameters
            $processParams = @{
                FilePath = $appConfig.path
            }

            # Add arguments if specified
            if ($appConfig.arguments -and $appConfig.arguments -ne "") {
                $processParams['ArgumentList'] = $appConfig.arguments
            }

            # Add working directory if specified and valid
            if ($appConfig.workingDirectory -and $appConfig.workingDirectory -ne "") {
                if (Test-Path -Path $appConfig.workingDirectory -PathType Container) {
                    $processParams['WorkingDirectory'] = $appConfig.workingDirectory
                }
            }

            # Start process with built parameters
            Start-Process @processParams
            Write-LocalizedHost -Messages $this.Messages -Key "console_app_started" -Args @($appId) -Default ("Application started: {0}" -f $appId) -Level "OK" -Component "AppManager"
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "console_app_start_failed" -Args @($appId) -Default ("Failed to start app: {0}" -f $appId) -Level "WARNING" -Component "AppManager"
            return $false
        }
    }

    <#
    .SYNOPSIS
        Stops an application process.

    .DESCRIPTION
        Terminates the application process(es) using the configured termination method.
        Supports multiple process names separated by | character.
        Uses graceful shutdown with configurable timeout before forceful termination.

    .PARAMETER appId
        The application ID to stop

    .PARAMETER appConfig
        The application configuration object containing processName and termination settings

    .OUTPUTS
        Boolean indicating whether the process was successfully stopped

    .EXAMPLE
        $success = $appManager.StopProcess("discord", $appConfig)

    .NOTES
        Default termination method is "auto" (graceful then forceful).
        Default graceful timeout is 3000ms (3 seconds).
        Supports pipe-separated process names for multi-process applications.
    #>
    # Stop application process
    [bool] StopProcess([string] $appId, [object] $appConfig) {
        if (-not $appConfig.processName -or $appConfig.processName -eq "") {
            Write-LocalizedHost -Messages $this.Messages -Key "console_app_no_process" -Args @($appId) -Default ("No process name specified for app '{0}'" -f $appId) -Level "WARNING" -Component "AppManager"
            return $false
        }

        # Get termination method (default: auto for backward compatibility)
        $terminationMethod = if ($appConfig.terminationMethod) { $appConfig.terminationMethod } else { "auto" }

        # Get graceful shutdown timeout (default: 3 seconds)
        $gracefulTimeoutMs = if ($appConfig.gracefulTimeoutMs) { $appConfig.gracefulTimeoutMs } else { 3000 }

        # Handle multiple process names separated by |
        $processNames = $appConfig.processName -split '\|'
        $processFound = $false

        foreach ($processName in $processNames) {
            $processName = $processName.Trim()
            try {
                $processes = Get-Process -Name $processName -ErrorAction Stop
                if ($processes) {
                    $success = $this.TerminateProcess($processName, $terminationMethod, $gracefulTimeoutMs, $appId)
                    if ($success) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_app_process_stopped" -Args @($appId, $processName) -Default ("Application process stopped: {0} ({1})" -f $appId, $processName) -Level "OK" -Component "AppManager"
                        $processFound = $true
                    }
                }
            } catch {
                # Process not found, continue to next
                Write-LocalizedHost -Messages $this.Messages -Key "console_app_process_not_found" -Args @($processName) -Default ("Application process not found: {0}" -f $processName) -Level "INFO" -Component "AppManager"
            }
        }

        if (-not $processFound) {
            Write-LocalizedHost -Messages $this.Messages -Key "console_app_process_not_running" -Args @($appId) -Default ("Application process not running: {0}" -f $appId) -Level "INFO" -Component "AppManager"
        }

        return $true
    }

    # Terminate process based on specified method
    [bool] TerminateProcess([string] $processName, [string] $method, [int] $timeoutMs, [string] $appId) {
        switch ($method.ToLower()) {
            "graceful" {
                return $this.GracefulTermination($processName, $timeoutMs, $appId)
            }
            "force" {
                return $this.ForceTermination($processName, $appId)
            }
            "auto" {
                # Try graceful first, then force if needed
                $gracefulSuccess = $this.GracefulTermination($processName, $timeoutMs, $appId)
                if (-not $gracefulSuccess) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_graceful_failed_using_force" -Args @($processName) -Default ("Graceful shutdown failed, attempting force termination for {0}" -f $processName) -Level "WARNING" -Component "AppManager"
                    return $this.ForceTermination($processName, $appId)
                }
                return $true
            }
            default {
                Write-LocalizedHost -Messages $this.Messages -Key "console_unknown_termination_method" -Args @($method, $appId) -Default ("Unknown termination method '{0}' for app '{1}' - Using 'auto' as fallback" -f $method, $appId) -Level "WARNING" -Component "AppManager"
                return $this.TerminateProcess($processName, "auto", $timeoutMs, $appId)
            }
        }
        # This should never be reached, but PowerShell requires all code paths to return a value
        return $false
    }

    # Graceful process termination (allows user dialogs)
    [bool] GracefulTermination([string] $processName, [int] $timeoutMs, [string] $appId) {
        try {
            # Send graceful termination signal
            Stop-Process -Name $processName -ErrorAction Stop

            Write-LocalizedHost -Messages $this.Messages -Key "console_graceful_shutdown_initiated" -Args @($processName, ($timeoutMs / 1000)) -Default ("Graceful shutdown initiated for {0} ({1}s timeout)" -f $processName, ($timeoutMs / 1000)) -Level "INFO" -Component "AppManager"

            # Wait for process to exit gracefully
            $waitInterval = 100  # Check every 100ms
            $elapsedMs = 0

            while ($elapsedMs -lt $timeoutMs) {
                Start-Sleep -Milliseconds $waitInterval
                $elapsedMs += $waitInterval

                # Check if process still exists
                $remainingProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if (-not $remainingProcesses) {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_graceful_shutdown_success" -Args @($processName) -Default ("Graceful shutdown successful: {0}" -f $processName) -Level "OK" -Component "AppManager"
                    return $true
                }
            }

            # Timeout reached
            Write-LocalizedHost -Messages $this.Messages -Key "console_graceful_shutdown_timeout" -Args @($processName, ($timeoutMs / 1000)) -Default ("Graceful shutdown timeout for {0} ({1}s)" -f $processName, ($timeoutMs / 1000)) -Level "WARNING" -Component "AppManager"
            return $false
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "console_graceful_shutdown_failed" -Args @($processName, $_) -Default ("Graceful shutdown failed for {0}: {1}" -f $processName, $_) -Level "WARNING" -Component "AppManager"
            return $false
        }
    }

    # Force process termination (immediate)
    [bool] ForceTermination([string] $processName, [string] $appId) {
        try {
            Stop-Process -Name $processName -Force -ErrorAction Stop
            Write-LocalizedHost -Messages $this.Messages -Key "console_force_termination_success" -Args @($processName) -Default ("Process forcefully terminated: {0}" -f $processName) -Level "OK" -Component "AppManager"
            return $true
        } catch {
            # Check if error is Access Denied (NativeErrorCode 5)
            if ($_.Exception.InnerException -is [System.ComponentModel.Win32Exception] -and
                $_.Exception.InnerException.NativeErrorCode -eq 5) {

                try {
                    Write-LocalizedHost -Messages $this.Messages -Key "console_elevating_termination" -Args @($processName) -Default ("Access denied. Attempting to terminate with admin privileges: {0}" -f $processName) -Level "WARNING" -Component "AppManager"

                    # Start PowerShell with admin privileges to terminate the process
                    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-Command", "Stop-Process -Name '$processName' -Force" -WindowStyle Hidden -Wait

                    # Verify process has been terminated
                    if (-not (Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
                        Write-LocalizedHost -Messages $this.Messages -Key "console_elevated_termination_success" -Args @($processName) -Default ("Process terminated with admin privileges: {0}" -f $processName) -Level "OK" -Component "AppManager"
                        return $true
                    }
                } catch {
                    # UAC cancelled or other error
                    Write-LocalizedHost -Messages $this.Messages -Key "console_elevated_termination_failed" -Args @($processName, $_) -Default ("Elevated termination failed for {0}: {1}" -f $processName, $_) -Level "WARNING" -Component "AppManager"
                }
            }

            Write-LocalizedHost -Messages $this.Messages -Key "console_force_termination_failed" -Args @($processName, $_) -Default ("Force termination failed for {0}: {1}" -f $processName, $_) -Level "WARNING" -Component "AppManager"
            return $false
        }
    }

    # Start VTube Studio (special action)
    [bool] StartVTubeStudio([string] $appId, [object] $appConfig) {
        try {
            # Create VTubeStudioManager instance
            $vtubeManager = New-VTubeStudioManager -VTubeConfig $appConfig -Messages $this.Messages

            # Start VTube Studio
            return $vtubeManager.StartVTubeStudio()
        } catch {
            Write-Host "[ERROR] VTubeStudioManager: Failed to start VTube Studio - $_"
            return $false
        }
    }

    # Stop VTube Studio (special action)
    [bool] StopVTubeStudio([string] $appId, [object] $appConfig) {
        try {
            # Load VTubeStudioManager if not already loaded
            $modulePath = Join-Path $PSScriptRoot "VTubeStudioManager.ps1"
            if (Test-Path $modulePath) {
                . $modulePath
            } else {
                Write-Host "[ERROR] VTubeStudioManager: Module not found at - $modulePath"
                return $false
            }

            # Create VTubeStudioManager instance
            $vtubeManager = New-VTubeStudioManager -VTubeConfig $appConfig -Messages $this.Messages

            # Stop VTube Studio
            return $vtubeManager.StopVTubeStudio()
        } catch {
            Write-Host "[ERROR] VTubeStudioManager: Failed to stop VTube Studio - $_"
            return $false
        }
    }

    # Set Discord Gaming Mode (special action)
    [bool] SetDiscordGamingMode([string] $appId, [object] $appConfig) {
        # TODO: Re-enable in future release
        # Disabled for v1.0 - Discord integration has known bugs
        if ($false) { # Disabled for v1.0
            try {
                # Load DiscordManager if not already loaded
                $modulePath = Join-Path $PSScriptRoot "DiscordManager.ps1"
                if (Test-Path $modulePath) {
                    . $modulePath
                } else {
                    Write-Host "[ERROR] DiscordManager: Module not found at - $modulePath"
                    return $false
                }

                # Create DiscordManager instance
                $discordManager = New-DiscordManager -DiscordConfig $appConfig -Messages $this.Messages

                # Set Gaming Mode
                return $discordManager.SetGamingMode($this.GameConfig.name)
            } catch {
                Write-Host "[ERROR] DiscordManager: Failed to set Discord Gaming Mode - $_"
                return $false
            }
        }
        # Return true (no-op success) to avoid breaking application flow when feature is disabled
        return $true
    }

    # Restore Discord Normal Mode (special action)
    [bool] RestoreDiscordNormal([string] $appId, [object] $appConfig) {
        # TODO: Re-enable in future release
        # Disabled for v1.0 - Discord integration has known bugs
        if ($false) { # Disabled for v1.0
            try {
                # Load DiscordManager if not already loaded
                $modulePath = Join-Path $PSScriptRoot "DiscordManager.ps1"
                if (Test-Path $modulePath) {
                    . $modulePath
                } else {
                    Write-Host "[ERROR] DiscordManager: Module not found at - $modulePath"
                    return $false
                }

                # Create DiscordManager instance
                $discordManager = New-DiscordManager -DiscordConfig $appConfig -Messages $this.Messages

                # Restore Normal Mode
                return $discordManager.RestoreNormalMode()
            } catch {
                Write-Host "[ERROR] DiscordManager: Failed to restore Discord Normal Mode - $_"
                return $false
            }
        }
        # Return true (no-op success) to avoid breaking application flow when feature is disabled
        return $true
    }

    # Check if application process is running
    [bool] IsProcessRunning([string] $processName) {
        return $null -ne (Get-Process -Name $processName -ErrorAction SilentlyContinue)
    }

    # Get application startup action
    [string] GetStartupAction([string] $appId) {
        # Check if this is an integration
        if ($this.IntegrationManagers.ContainsKey($appId)) {
            $integrationConfig = $this.Config.integrations.$appId
            if ($integrationConfig -and $integrationConfig.gameStartAction) {
                return $integrationConfig.gameStartAction
            }
            return "none"
        }

        # Standard managed app
        if ($this.ManagedApps.$appId -and $this.ManagedApps.$appId.gameStartAction) {
            return $this.ManagedApps.$appId.gameStartAction
        }
        return "none"
    }

    # Get application shutdown action
    [string] GetShutdownAction([string] $appId) {
        # Check if this is an integration
        if ($this.IntegrationManagers.ContainsKey($appId)) {
            $integrationConfig = $this.Config.integrations.$appId
            if ($integrationConfig -and $integrationConfig.gameEndAction) {
                return $integrationConfig.gameEndAction
            }
            return "none"
        }

        # Standard managed app
        if ($this.ManagedApps.$appId -and $this.ManagedApps.$appId.gameEndAction) {
            return $this.ManagedApps.$appId.gameEndAction
        }
        return "none"
    }

    # Process application startup sequence
    [bool] ProcessStartupSequence() {
        $apps = $this.GetManagedApplications()
        $allSuccess = $true

        if ($apps.Count -eq 0) {
            if ($this.Logger) { $this.Logger.Info("No application to manage for startup", "APP") }
            return $true
        }

        foreach ($appId in $apps) {
            $action = $this.GetStartupAction($appId)

            if ($this.Logger) { $this.Logger.Info("Processing startup for $appId (Action: $action)", "APP") }

            $success = $this.InvokeAction($appId, $action)

            if (-not $success) {
                $allSuccess = $false
                Write-LocalizedHost -Messages $this.Messages -Key "console_app_start_action_failed" -Args @($appId, $action) -Default ("Failed to start app '{0}' with action: {1}" -f $appId, $action) -Level "WARNING" -Component "AppManager"
                if ($this.Logger) { $this.Logger.Warning("Failed to start $appId with action: $action", "APP") }
            }
        }

        return $allSuccess
    }

    # Process application shutdown sequence
    [bool] ProcessShutdownSequence() {
        $apps = $this.GetManagedApplications()
        $allSuccess = $true

        if ($apps.Count -eq 0) {
            if ($this.Logger) { $this.Logger.Info("No applications to manage for shutdown", "APP") }
        } else {
            foreach ($appId in $apps) {
                $action = $this.GetShutdownAction($appId)
                $success = $this.InvokeAction($appId, $action)
                if (-not $success) {
                    $allSuccess = $false
                    Write-LocalizedHost -Messages $this.Messages -Key "console_app_shutdown_action_failed" -Args @($appId, $action) -Default ("Failed to shutdown app '{0}' with action: {1}" -f $appId, $action) -Level "WARNING" -Component "AppManager"
                    if ($this.Logger) { $this.Logger.Warning("Failed to shutdown $appId with action: $action", "APP") }
                }
            }
        }

        # Clean up any background jobs
        if ($this.Config.PSObject.Properties['BackgroundJobs'] -and $this.Config.BackgroundJobs) {
            # Create a copy of keys to avoid collection modification during iteration
            $jobKeys = @($this.Config.BackgroundJobs.Keys)
            foreach ($jobKey in $jobKeys) {
                $job = $this.Config.BackgroundJobs[$jobKey]
                if ($job) {
                    switch ($job.State) {
                        'Running' {
                            if ($this.Logger) { $this.Logger.Info("Waiting for background job '$jobKey' to complete (Job ID: $($job.Id))...", "APP") }
                            # Wait for up to 10 seconds for the job to complete
                            $null = Wait-Job -Job $job -Timeout 10

                            if ($job.State -eq 'Completed') {
                                $jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
                                if ($this.Logger) { $this.Logger.Info("Background job '$jobKey' completed successfully. Result: $jobResult", "APP") }
                            } else {
                                if ($this.Logger) { $this.Logger.Warning("Background job '$jobKey' did not complete within timeout, stopping job", "APP") }
                                Stop-Job -Job $job -ErrorAction SilentlyContinue
                            }
                        }
                        'NotStarted' {
                            if ($this.Logger) { $this.Logger.Info("Background job '$jobKey' never started, removing", "APP") }
                        }
                        'Completed' {
                            $jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
                            if ($this.Logger) { $this.Logger.Info("Background job '$jobKey' was already completed. Result: $jobResult", "APP") }
                        }
                        'Failed' {
                            if ($this.Logger) { $this.Logger.Warning("Background job '$jobKey' had failed", "APP") }
                        }
                        default {
                            if ($this.Logger) { $this.Logger.Info("Background job '$jobKey' in state: $($job.State)", "APP") }
                        }
                    }
                    
                    # Remove the job
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
            $this.Config.BackgroundJobs.Clear()
        }

        return $allSuccess
    }
}

# Public function for App management
function New-AppManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,

        [Parameter(Mandatory = $true)]
        [object] $Messages,

        [Parameter(Mandatory = $false)]
        [object] $Logger = $null
    )

    return [AppManager]::new($Config, $Messages, $Logger)
}

# Functions are available via dot-sourcing
