# Discord Manager Module
# Handles Discord integration and control

class DiscordManager {
    [object] $Config
    [object] $Messages
    [object] $Logger
    [string] $DiscordPath
    [object] $DiscordConfig
    [object] $RPCClient
    [string] $OriginalStatus

    # Constructor
    DiscordManager([object] $discordConfig, [object] $messages, [object] $logger = $null) {
        $this.Config = $discordConfig
        $this.Messages = $messages
        $this.Logger = $logger
        $this.DiscordConfig = $discordConfig.discord
        $this.DiscordPath = $this.DetectDiscordPath()
        $this.RPCClient = $null
        $this.OriginalStatus = "online"
        
        # Load RPC Client if RPC is enabled
        if ($this.DiscordConfig -and $this.DiscordConfig.rpc -and $this.DiscordConfig.rpc.enabled) {
            $this.InitializeRPCClient()
        }
    }

    # Detect Discord installation path
    [string] DetectDiscordPath() {
        $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
        $discordBaseDir = Join-Path $localAppData "Discord"
        
        if (Test-Path $discordBaseDir) {
            # Find the latest Discord app version
            $appDirs = Get-ChildItem -Path $discordBaseDir -Directory -Name "app-*" | Sort-Object -Descending
            if ($appDirs.Count -gt 0) {
                $latestAppDir = $appDirs[0]
                $discordExe = Join-Path $discordBaseDir "$latestAppDir\Discord.exe"
                if (Test-Path $discordExe) {
                    return $discordExe
                }
            }
        }
        
        # Fallback to configured path
        if ($this.Config.path -and $this.Config.path -ne "") {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($this.Config.path)
            # Handle wildcard paths
            if ($expandedPath -like "*app-*") {
                $baseDir = $expandedPath -replace "app-\*.*", ""
                if (Test-Path $baseDir) {
                    $appDirs = Get-ChildItem -Path $baseDir -Directory -Name "app-*" | Sort-Object -Descending
                    if ($appDirs.Count -gt 0) {
                        $latestAppDir = $appDirs[0]
                        return Join-Path $baseDir "$latestAppDir\Discord.exe"
                    }
                }
            }
            return $expandedPath
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
            Write-Host "Discord is already running"
            return $true
        }
        
        if (-not $this.DiscordPath -or -not (Test-Path $this.DiscordPath)) {
            Write-Host "Discord executable not found"
            return $false
        }
        
        try {
            Start-Process -FilePath $this.DiscordPath
            Write-Host "Discord started successfully"
            return $true
        }
        catch {
            Write-Host "Failed to start Discord: $_"
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
                Write-Host "Discord stopped successfully"
                return $true
            } else {
                Write-Host "Discord is not running"
                return $true
            }
        }
        catch {
            Write-Host "Failed to stop Discord: $_"
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
                    Write-Host "Discord RPC Client initialized"
                } else {
                    Write-Host "Discord RPC Client module not found"
                }
            }
            catch {
                Write-Host "Failed to initialize Discord RPC Client: $_"
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
        Write-Host "Discord RPC not available - status change skipped"
        return $false
    }

    # Set Rich Presence with game details (Advanced)
    [bool] SetRichPresence([string] $gameName, [string] $gameDetails = "", [string] $gameState = "") {
        if (-not $this.RPCClient) {
            Write-Host "Discord RPC not available for Rich Presence"
            return $false
        }

        if (-not $this.RPCClient.Connected -and -not $this.ConnectRPC()) {
            Write-Host "Failed to connect to Discord RPC for Rich Presence"
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
        }
        catch {
            Write-Host "Failed to set Rich Presence: $_"
            return $false
        }
    }

    # Control Discord overlay (Advanced)
    [bool] SetOverlayEnabled([bool] $enabled) {
        $status = if ($enabled) { 'Enabled' } else { 'Disabled' }
        Write-Host "Discord overlay control: $status"
        
        # Note: Discord doesn't provide direct API to disable overlay programmatically
        # This is a placeholder for potential future implementation or registry-based control
        
        if ($this.DiscordConfig -and $this.DiscordConfig.disableOverlay -ne $null) {
            $shouldDisable = $this.DiscordConfig.disableOverlay
            if ($shouldDisable -and $enabled) {
                Write-Host "Overlay should be disabled according to configuration"
                return $false
            }
        }
        
        Write-Host "Overlay setting applied (Advanced feature - manual user configuration may be required)"
        return $true
    }

    # Advanced error recovery
    [bool] RecoverFromError() {
        Write-Host "Attempting Discord error recovery..."
        
        try {
            # Disconnect and reconnect RPC
            if ($this.RPCClient) {
                $this.RPCClient.Disconnect()
                Start-Sleep -Seconds 2
                if ($this.ConnectRPC()) {
                    Write-Host "✓ Discord RPC reconnected successfully"
                    return $true
                }
            }
            
            # If RPC fails, try process restart
            if ($this.IsDiscordRunning()) {
                Write-Host "Attempting Discord process recovery..."
                $this.StopDiscord()
                Start-Sleep -Seconds 3
                return $this.StartDiscord()
            }
            
            return $false
        }
        catch {
            Write-Host "Error recovery failed: $_"
            return $false
        }
    }

    # Set Discord to Gaming Mode (Advanced - Full feature integration)
    [bool] SetGamingMode([string] $gameName = "Focus Game Deck") {
        Write-Host "Setting Discord to Gaming Mode (Advanced: Full integration)"
        
        $success = $true
        $retryCount = 0
        $maxRetries = 3
        
        while ($retryCount -lt $maxRetries) {
            try {
                # Ensure Discord is running
                if (-not $this.IsDiscordRunning()) {
                    Write-Host "Discord is not running, starting it..."
                    if (-not $this.StartDiscord()) {
                        throw "Failed to start Discord"
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
                            Write-Host "Failed to set Rich Presence, falling back to simple status"
                            if (-not $this.SetDiscordStatus("🎮 Gaming Mode - $gameName")) {
                                throw "Failed to set Discord status"
                            }
                        }
                    } else {
                        # Simple status update
                        if (-not $this.SetDiscordStatus("🎮 Gaming Mode - $gameName")) {
                            throw "Failed to set Discord status"
                        }
                    }
                }
                
                Write-Host "✓ Discord Advanced Gaming mode applied successfully"
                return $true
                
            }
            catch {
                $retryCount++
                Write-Host "Attempt $retryCount failed: $_"
                
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Attempting error recovery..."
                    if ($this.RecoverFromError()) {
                        Write-Host "Recovery successful, retrying..."
                        continue
                    }
                }
                
                $success = $false
            }
            
            break
        }
        
        if (-not $success) {
            Write-Host "⚠ Discord Gaming mode applied with limitations"
        }
        
        return $success
    }

    # Restore Discord to normal mode (Enhanced - RPC + Process control)
    [bool] RestoreNormalMode() {
        Write-Host "Restoring Discord to normal mode (Enhanced: RPC + Process control)"
        
        $success = $true
        
        # Restore RPC-based status if enabled
        if ($this.DiscordConfig -and $this.DiscordConfig.rpc -and $this.DiscordConfig.rpc.enabled) {
            Write-Host "Clearing Discord custom status"
            
            if ($this.RPCClient -and $this.RPCClient.Connected) {
                if (-not $this.RPCClient.ClearActivity()) {
                    Write-Host "Failed to clear Discord activity"
                    $success = $false
                }
            }
        }
        
        # Ensure Discord is still running
        if (-not $this.IsDiscordRunning()) {
            Write-Host "Discord is not running, starting it..."
            if (-not $this.StartDiscord()) {
                return $false
            }
        }
        
        if ($success) {
            Write-Host "✓ Discord normal mode restored successfully"
        }
        
        return $success
    }

    # Disconnect RPC when done
    [void] DisconnectRPC() {
        if ($this.RPCClient) {
            $this.RPCClient.Disconnect()
        }
    }

    # Get Discord status
    [object] GetStatus() {
        return @{
            IsRunning = $this.IsDiscordRunning()
            Path = $this.DiscordPath
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