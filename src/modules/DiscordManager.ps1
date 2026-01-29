# Discord Manager Module
# Handles Discord integration and control

class DiscordManager {
    [object] $Config
    [object] $Messages
    [object] $Logger
    [string] $DetectedDiscordPath
    [object] $DiscordConfig
    [object] $RPCClient
    [string] $OriginalStatus

    # Constructor
    DiscordManager([object] $discordConfig, [object] $messages, [object] $logger = $null) {
        $this.Config = $discordConfig
        $this.Messages = $messages
        $this.Logger = $logger
        $this.DiscordConfig = $discordConfig
        $this.DetectedDiscordPath = $this.DetectDiscordPath()
        $this.RPCClient = $null
        $this.OriginalStatus = "online"

        # Load RPC Client if RPC is enabled
        if ($this.DiscordConfig -and $this.DiscordConfig.rpc -and $this.DiscordConfig.rpc.enabled) {
            $this.InitializeRPCClient()
        }
    }

    # Detect Discord installation path
    [string] DetectDiscordPath() {
        # Auto detection of Discord path.
        <#
        $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
        $discordBaseDir = Join-Path $localAppData "Discord"
        if (Test-Path $discordBaseDir) {
            # Find the latest Discord app version
            $appDirs = Get-ChildItem -Path $discordBaseDir -Directory -Name "app-*" | Sort-Object -Descending
            if ($appDirs.Count -gt 0) {
                $latestAppDir = $appDirs[0]
                $discordExe = Join-Path $discordBaseDir "$latestAppDir/Discord.exe"
                if (Test-Path $discordExe) {
                    return $discordExe
                }
            }
        }
        #>

        # Fallback to configured path
        if ($this.DiscordConfig.path -and ($this.DiscordConfig.path -ne "")) {
            # Handle wildcard paths (e.g., "%LOCALAPPDATA%/Discord/app-*/Discord.exe")
            $discordPathWithWildcard = $this.DiscordConfig.path

            # Expand environment variables
            $expandedPath = [Environment]::ExpandEnvironmentVariables($discordPathWithWildcard)

            # Extract base directory and pattern
            $parentDir = Split-Path -Parent (Split-Path -Parent $expandedPath)
            $wildcardPattern = Split-Path -Leaf (Split-Path -Parent $expandedPath)

            if (Test-Path $parentDir) {
                if ($wildcardPattern -notlike "*`**") {
                    # No wildcard, return the path directly if it exists
                    if (Test-Path $expandedPath) {
                        return $expandedPath
                    } else {
                        return ""
                    }
                } else {
                    # Find all directories matching the wildcard pattern (e.g., app-*)
                    $appDirs = Get-ChildItem -Path $parentDir -Directory -Filter $wildcardPattern -ErrorAction SilentlyContinue |
                    Sort-Object -Property Name -Descending

                    if ($appDirs.Count -gt 0) {
                        # Get the latest version directory
                        $latestAppDir = $appDirs[0]
                        $discordExePath = Join-Path $latestAppDir.FullName "Discord.exe"

                        if (Test-Path $discordExePath) {
                            return $discordExePath
                        }
                    }
                }

            }
        }

        return ""
    }

    # Check if Discord is running
    [bool] IsDiscordRunning() {
        $processes = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
        return $null -ne $processes -and $processes.Count -gt 0
    }

    # Start Discord process
    [bool] StartDiscord() {
        if ($this.IsDiscordRunning()) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_already_running" -Default "Discord is already running" -Level "INFO" -Component "DiscordManager"
            return $true
        }

        if (-not $this.DetectedDiscordPath -or -not (Test-Path $this.DetectedDiscordPath)) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_executable_not_found" -Default "Discord executable not found" -Level "WARNING" -Component "DiscordManager"
            return $false
        }

        try {
            Start-Process -FilePath $this.DetectedDiscordPath
            Write-LocalizedHost -Messages $this.Messages -Key "discord_started_successfully" -Default "Discord started successfully" -Level "OK" -Component "DiscordManager"
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_failed_to_start" -Args @($_) -Default "Failed to start Discord: {0}" -Level "WARNING" -Component "DiscordManager"
            return $false
        }
    }

    # Stop Discord process
    [bool] StopDiscord() {
        try {
            $processes = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
            if ($processes) {
                foreach ($process in $processes) {
                    $process.CloseMainWindow()
                    Start-Sleep -Milliseconds 500
                    if (-not $process.HasExited) {
                        $process.Kill()
                    }
                }
                Write-LocalizedHost -Messages $this.Messages -Key "discord_stopped_successfully" -Default "Discord stopped successfully" -Level "OK" -Component "DiscordManager"
                return $true
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "discord_not_running" -Default "Discord is not running" -Level "INFO" -Component "DiscordManager"
                return $true
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_failed_to_stop" -Args @($_) -Default "Failed to stop Discord: {0}" -Level "WARNING" -Component "DiscordManager"
            return $false
        }
    }

    # Initialize RPC Client
    [void] InitializeRPCClient() {
        if ($this.DiscordConfig.rpc.applicationId -and $this.DiscordConfig.rpc.applicationId -ne "") {
            try {
                # Load RPC Client module
                $rpcModulePath = Join-Path $PSScriptRoot "DiscordRPCClient.ps1"
                if (Test-Path $rpcModulePath) {
                    . $rpcModulePath
                    $this.RPCClient = New-DiscordRPCClient -ApplicationId $this.DiscordConfig.rpc.applicationId -Logger $this.Logger
                    Write-LocalizedHost -Messages $this.Messages -Key "discord_rpc_client_initialized" -Default "Discord RPC Client initialized" -Level "OK" -Component "DiscordManager"
                } else {
                    Write-LocalizedHost -Messages $this.Messages -Key "discord_rpc_client_module_not_found" -Default "Discord RPC Client module not found" -Level "WARNING" -Component "DiscordManager"
                }
            } catch {
                Write-LocalizedHost -Messages $this.Messages -Key "discord_rpc_client_initialization_failed" -Args @($_) -Default "Failed to initialize Discord RPC Client: {0}" -Level "WARNING" -Component "DiscordManager"
            }
        }
    }

    # Connect to Discord RPC
    [bool] ConnectRPC() {
        if ($this.RPCClient) {
            return $this.RPCClient.Connect()
        }
        return $false
    }

    # Set Discord status via RPC
    [bool] SetDiscordStatus([string] $status) {
        if ($this.RPCClient -and $this.RPCClient.Connected) {
            return $this.RPCClient.SetStatus($status)
        } elseif ($this.RPCClient) {
            if ($this.ConnectRPC()) {
                return $this.RPCClient.SetStatus($status)
            }
        }
        Write-LocalizedHost -Messages $this.Messages -Key "discord_rpc_not_available" -Default "Discord RPC not available - status change skipped" -Level "INFO" -Component "DiscordManager"
        return $false
    }

    # Set Rich Presence with game details (Advanced)
    [bool] SetRichPresence([string] $gameName, [string] $gameDetails = "", [string] $gameState = "") {
        if (-not $this.RPCClient) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_rpc_not_available_for_presence" -Default "Discord RPC not available for Rich Presence" -Level "WARNING" -Component "DiscordManager"
            return $false
        }

        if (-not $this.RPCClient.Connected -and -not $this.ConnectRPC()) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_failed_connect_to_rpc" -Default "Failed to connect to Discord RPC for Rich Presence" -Level "WARNING" -Component "DiscordManager"
            return $false
        }

        try {
            $activity = @{
                details = if ($gameDetails) { $gameDetails } else { "Playing $gameName" }
                state = if ($gameState) { $gameState } else { "Focus Gaming Mode" }
                timestamps = @{
                    start = [int64]((Get-Date) - (Get-Date "1970-01-01")).TotalSeconds
                }
                assets = @{
                    large_image = "focus_game_deck_logo"
                    large_text = "Focus Game Deck"
                    small_image = "gaming_mode"
                    small_text = "Gaming Mode Active"
                }
            }

            return $this.RPCClient.SetRichPresence($activity)
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_failed_set_rich_presence" -Args @($_) -Default "Failed to set Rich Presence: {0}" -Level "WARNING" -Component "DiscordManager"
            return $false
        }
    }

    # Control Discord overlay (Advanced)
    [bool] SetOverlayEnabled([bool] $enabled) {
        $status = if ($enabled) { 'Enabled' } else { 'Disabled' }
        Write-LocalizedHost -Messages $this.Messages -Key "discord_overlay_control" -Args @($status) -Default "Discord overlay control: {0}" -Level "INFO" -Component "DiscordManager"

        # Note: Discord doesn't provide direct API to disable overlay programmatically
        # This is a placeholder for potential future implementation or registry-based control

        if ($this.DiscordConfig -and $null -ne $this.DiscordConfig.disableOverlay) {
            $shouldDisable = $this.DiscordConfig.disableOverlay
            if ($shouldDisable -and $enabled) {
                Write-LocalizedHost -Messages $this.Messages -Key "discord_overlay_should_be_disabled" -Default "Overlay should be disabled according to configuration" -Level "WARNING" -Component "DiscordManager"
                return $false
            }
        }

        Write-LocalizedHost -Messages $this.Messages -Key "discord_overlay_setting_applied" -Default "Overlay setting applied (Advanced feature - manual user configuration may be required)" -Level "INFO" -Component "DiscordManager"
        return $true
    }

    # Advanced error recovery
    [bool] RecoverFromError() {
        Write-LocalizedHost -Messages $this.Messages -Key "discord_attempting_error_recovery" -Default "Attempting Discord error recovery..." -Level "INFO" -Component "DiscordManager"

        try {
            # Disconnect and reconnect RPC
            if ($this.RPCClient) {
                $this.RPCClient.Disconnect()
                Start-Sleep -Seconds 2
                if ($this.ConnectRPC()) {
                    Write-LocalizedHost -Messages $this.Messages -Key "discord_rpc_reconnected_successfully" -Default "Discord RPC reconnected successfully" -Level "OK" -Component "DiscordManager"
                    return $true
                }
            }

            # If RPC fails, try process restart
            if ($this.IsDiscordRunning()) {
                Write-LocalizedHost -Messages $this.Messages -Key "discord_attempting_process_recovery" -Default "Attempting Discord process recovery..." -Level "INFO" -Component "DiscordManager"
                $this.StopDiscord()
                Start-Sleep -Seconds 3
                return $this.StartDiscord()
            }

            return $false
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_error_recovery_failed" -Args @($_) -Default "Error recovery failed: {0}" -Level "WARNING" -Component "DiscordManager"
            return $false
        }
    }

    # Set Discord to Gaming Mode (Advanced - Full feature integration)
    [bool] SetGamingMode([string] $gameName = "Focus Game Deck") {
        Write-LocalizedHost -Messages $this.Messages -Key "discord_setting_gaming_mode" -Default "Setting Discord to Gaming Mode (Advanced: Full integration)" -Level "INFO" -Component "DiscordManager"

        $success = $true
        $retryCount = 0
        $maxRetries = 3

        while ($retryCount -lt $maxRetries) {
            try {
                # Ensure Discord is running
                if (-not $this.IsDiscordRunning()) {
                    Write-LocalizedHost -Messages $this.Messages -Key "discord_not_running_starting" -Default "Discord is not running, starting it..." -Level "INFO" -Component "DiscordManager"
                    if (-not $this.StartDiscord()) {
                        throw "Discord startup failed"
                    }
                    # Wait for Discord to fully start
                    Start-Sleep -Seconds 3
                }

                # Control overlay if configured
                if ($this.DiscordConfig -and $this.DiscordConfig.disableOverlay) {
                    $this.SetOverlayEnabled($false)
                }

                # Apply RPC-based features if enabled
                if ($this.DiscordConfig -and $this.DiscordConfig.rpc -and $this.DiscordConfig.rpc.enabled) {
                    # Set Rich Presence with game details
                    if ($this.DiscordConfig.customPresence -and $this.DiscordConfig.customPresence.enabled) {
                        $gameDetails = "Focus Gaming Mode Active"
                        $gameState = $this.DiscordConfig.customPresence.state

                        if (-not $this.SetRichPresence($gameName, $gameDetails, $gameState)) {
                            Write-LocalizedHost -Messages $this.Messages -Key "discord_failed_set_rich_presence" -Default "Failed to set Rich Presence, falling back to simple status" -Level "WARNING" -Component "DiscordManager"
                            if (-not $this.SetDiscordStatus("Gaming Mode - $gameName")) {
                                throw "Discord status setup failed"
                            }
                        }
                    } else {
                        # Simple status update
                        if (-not $this.SetDiscordStatus("Gaming Mode - $gameName")) {
                            throw "Discord status setup failed"
                        }
                    }
                }

                Write-LocalizedHost -Messages $this.Messages -Key "discord_gaming_mode_applied_successfully" -Default "Discord Advanced Gaming mode applied successfully" -Level "OK" -Component "DiscordManager"
                return $true

            } catch {
                $retryCount++
                Write-LocalizedHost -Messages $this.Messages -Key "discord_attempt_failed" -Args @($retryCount, $_) -Default "Attempt {0} failed: {1}" -Level "WARNING" -Component "DiscordManager"

                if ($retryCount -lt $maxRetries) {
                    Write-LocalizedHost -Messages $this.Messages -Key "discord_attempting_recovery" -Default "Attempting error recovery..." -Level "INFO" -Component "DiscordManager"
                    if ($this.RecoverFromError()) {
                        Write-LocalizedHost -Messages $this.Messages -Key "discord_recovery_successful_retrying" -Default "Recovery successful, retrying..." -Level "INFO" -Component "DiscordManager"
                        continue
                    }
                }

                $success = $false
            }

            break
        }

        if (-not $success) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_gaming_mode_applied_with_limitations" -Default "Discord Gaming mode applied with limitations" -Level "WARNING" -Component "DiscordManager"
        }

        return $success
    }

    # Restore Discord to normal mode (Enhanced - RPC + Process control)
    [bool] RestoreNormalMode() {
        Write-LocalizedHost -Messages $this.Messages -Key "discord_restoring_normal_mode" -Default "Restoring Discord to normal mode (Enhanced: RPC + Process control)" -Level "INFO" -Component "DiscordManager"

        $success = $true

        # Restore RPC-based status if enabled
        if ($this.DiscordConfig -and $this.DiscordConfig.rpc -and $this.DiscordConfig.rpc.enabled) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_clearing_custom_status" -Default "Clearing Discord custom status" -Level "INFO" -Component "DiscordManager"

            if ($this.RPCClient -and $this.RPCClient.Connected) {
                if (-not $this.RPCClient.ClearActivity()) {
                    Write-LocalizedHost -Messages $this.Messages -Key "discord_failed_clear_activity" -Default "Failed to clear Discord activity" -Level "WARNING" -Component "DiscordManager"
                    $success = $false
                }
            }
        }

        # Ensure Discord is still running
        if (-not $this.IsDiscordRunning()) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_starting_for_normal_mode" -Default "Discord is not running, starting it..." -Level "INFO" -Component "DiscordManager"
            if (-not $this.StartDiscord()) {
                return $false
            }
        }

        if ($success) {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_normal_mode_restored_successfully" -Default "Discord normal mode restored successfully" -Level "OK" -Component "DiscordManager"
        }

        return $success
    }

    # Disconnect RPC when done
    [bool] DisconnectRPC() {
        try {
            if ($this.RPCClient) {
                $this.RPCClient.Disconnect()
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "discord_error_disconnecting_rpc" -Args @($_) -Default "Error disconnecting RPC: {0}" -Level "WARNING" -Component "DiscordManager"
            return $false
        }
        return $true
    }

    # Get Discord status
    [object] GetStatus() {
        return @{
            IsRunning = $this.IsDiscordRunning()
            Path = $this.DetectedDiscordPath
            ProcessCount = (Get-Process -Name "Discord" -ErrorAction SilentlyContinue).Count
        }
    }
}

# Public function for Discord management
function New-DiscordManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $DiscordConfig,

        [Parameter(Mandatory = $true)]
        [object] $Messages,

        [Parameter(Mandatory = $false)]
        [object] $Logger = $null
    )

    return [DiscordManager]::new($DiscordConfig, $Messages, $Logger)
}

# Functions are available via dot-sourcing
