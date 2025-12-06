# VTube Studio Manager Module
# Handles VTube Studio integration including application management and WebSocket API communication

class VTubeStudioManager {
    [System.Net.WebSockets.ClientWebSocket] $WebSocket
    [object] $Config
    [object] $Messages
    [object] $Logger
    [string] $ProcessName = "VTube Studio"
    [string] $SteamAppId = "1325860"
    [object] $BaseHelper

    # Constructor
    VTubeStudioManager([object] $vtubeConfig, [object] $messages, [object] $logger = $null) {
        $this.Config = $vtubeConfig
        $this.Messages = $messages
        $this.Logger = $logger

        # Load and initialize base helper for common operations
        try {
            $this.BaseHelper = New-WebSocketAppManagerBase`
            -Config $vtubeConfig -Messages $messages -Logger $logger`
            -AppName "VTubeStudio"
        } catch {
            Write-LocalizedHost -Messages $messages -Key "vtube_startup_failed_error" -Args @($_) -Default "Failed to start VTube Studio: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            $this.BaseHelper = $null
        }
    }

    # Check if VTube Studio process is running
    [bool] IsVTubeStudioRunning() {
        $process = Get-Process -Name $this.ProcessName -ErrorAction SilentlyContinue
        return $null -ne $process
    }

    # Start VTube Studio application
    [bool] StartVTubeStudio() {
        if ($this.IsVTubeStudioRunning()) {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_already_running" -Default "VTube Studio is already running" -Level "INFO" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Info("VTube Studio already running, skipping startup", "VTUBE")
            }
            return $true
        }

        try {
            $steamPath = $this.GetSteamPath()
            if ($steamPath -and (Test-Path $steamPath)) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_starting_via_steam" -Default "Starting VTube Studio via Steam..." -Level "INFO" -Component "VTubeStudioManager"
                Start-Process $steamPath -ArgumentList "-applaunch $($this.SteamAppId)"
                if ($this.Logger) {
                    $this.Logger.Info("Started VTube Studio via Steam (AppID: $($this.SteamAppId))", "VTUBE")
                }
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_steam_not_found" -Default "Steam not found" -Level "WARNING" -Component "VTubeStudioManager"
                return $false
            }

            # Wait for VTube Studio to start
            $retryCount = 0
            $maxRetries = 15  # VTube Studio can take longer to start than OBS
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_waiting_for_startup" -Default "Waiting for VTube Studio to start..." -Level "INFO" -Component "VTubeStudioManager"

            while (-not $this.IsVTubeStudioRunning() -and ($retryCount -lt $maxRetries)) {
                Start-Sleep -Seconds 2
                $retryCount++
            }

            if ($this.IsVTubeStudioRunning()) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_startup_complete" -Default "VTube Studio startup complete" -Level "OK" -Component "VTubeStudioManager"
                if ($this.Logger) {
                    $this.Logger.Info("VTube Studio startup completed successfully", "VTUBE")
                }
                # Give VTube Studio time to fully initialize before WebSocket operations
                Start-Sleep -Seconds 3
                return $true
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_startup_failed" -Default "VTube Studio startup failed or timed out" -Level "WARNING" -Component "VTubeStudioManager"
                if ($this.Logger) {
                    $this.Logger.Error("VTube Studio startup failed or timed out", "VTUBE")
                }
                return $false
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_startup_failed_error" -Args @($_) -Default "Failed to start VTube Studio: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("Failed to start VTube Studio: $_", "VTUBE")
            }
            return $false
        }
    }

    # Stop VTube Studio application
    [bool] StopVTubeStudio() {
        Write-LocalizedHost -Messages $this.Messages -Key "vtube_stopping" -Default "Stopping VTube Studio..." -Level "INFO" -Component "VTubeStudioManager"

        if ($this.BaseHelper) {
            # Use base helper for advanced shutdown
            $result = $this.BaseHelper.StopApplicationGracefully($this.ProcessName, 5000)

            if ($result) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_stopped_successfully" -Default "VTube Studio stopped successfully" -Level "OK" -Component "VTubeStudioManager"
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_failed_to_stop" -Default "Failed to stop VTube Studio" -Level "WARNING" -Component "VTubeStudioManager"
            }

            return $result
        } else {
            # Fallback to original implementation
            if (-not $this.IsVTubeStudioRunning()) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_not_running" -Default "VTube Studio is not running" -Level "INFO" -Component "VTubeStudioManager"
                if ($this.Logger) {
                    $this.Logger.Info("VTube Studio not running, skipping shutdown", "VTUBE")
                }
                return $true
            }

            try {
                $processes = Get-Process -Name $this.ProcessName -ErrorAction SilentlyContinue
                foreach ($process in $processes) {
                    # Try graceful shutdown first
                    $process.CloseMainWindow()
                    if (-not $process.WaitForExit(5000)) {
                        # Force kill if graceful shutdown fails
                        $process.Kill()
                        $process.WaitForExit()
                    }
                }

                Write-LocalizedHost -Messages $this.Messages -Key "vtube_stopped_successfully" -Default "VTube Studio stopped successfully" -Level "OK" -Component "VTubeStudioManager"
                if ($this.Logger) {
                    $this.Logger.Info("VTube Studio stopped successfully", "VTUBE")
                }
                return $true
            } catch {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_failed_to_stop_error" -Args @($_) -Default "Failed to stop VTube Studio: {0}" -Level "WARNING" -Component "VTubeStudioManager"
                if ($this.Logger) {
                    $this.Logger.Error("Failed to stop VTube Studio: $_", "VTUBE")
                }
                return $false
            }
        }
    }

    # Get Steam installation path
    [string] GetSteamPath() {
        # Try configured path first
        if ($this.Config.path -and (Test-Path $this.Config.path)) {
            return $this.Config.path
        }

        # # Auto-detect Steam path
        # $steamPaths = @(
        #     "C:/Program Files (x86)/Steam/steam.exe",
        #     "C:/Program Files/Steam/steam.exe"
        # )

        # foreach ($path in $steamPaths) {
        #     if (Test-Path $path) {
        #         return $path
        #     }
        # }

        # # Try registry
        # try {
        #     $steamReg = Get-ItemProperty -Path "HKCU:/Software/Valve/Steam" -Name "SteamExe" -ErrorAction SilentlyContinue
        #     if ($steamReg -and (Test-Path $steamReg.SteamExe)) {
        #         return $steamReg.SteamExe
        #     }
        # } catch {
        #     # Ignore registry errors
        # }

        return $null
    }

    # WebSocket connection methods (for future expansion)
    # These methods provide the foundation for VTube Studio API integration

    # Connect to VTube Studio WebSocket API
    [bool] ConnectWebSocket() {
        # Future implementation: Connect to ws://localhost:8001
        # This will be implemented when WebSocket features are needed
        Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_feature_coming_soon" -Default "WebSocket connection feature coming soon..." -Level "INFO" -Component "VTubeStudioManager"
        if ($this.Logger) {
            $this.Logger.Info("WebSocket connection requested (feature pending)", "VTUBE")
        }
        return $false
    }

    # Disconnect from VTube Studio WebSocket API
    [void] DisconnectWebSocket() {
        if ($this.BaseHelper) {
            # Use base helper for WebSocket cleanup
            $this.BaseHelper.CleanupWebSocket($this.WebSocket)
        } else {
            # Fallback to original implementation
            if ($this.WebSocket) {
                try {
                    $this.WebSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Disconnecting", [System.Threading.CancellationToken]::None).Wait()
                } catch {
                    # Ignore errors during disconnect
                } finally {
                    $this.WebSocket.Dispose()
                }
            }
        }
        $this.WebSocket = $null
    }

    # Send command to VTube Studio (placeholder for future WebSocket commands)
    [bool] SendCommand([string] $command, [object] $parameters = $null) {
        # Future implementation: Send WebSocket commands to VTube Studio API
        Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_command_coming_soon" -Args @($command) -Default "WebSocket command feature coming soon: {0}" -Level "INFO" -Component "VTubeStudioManager"
        if ($this.Logger) {
            $this.Logger.Info("WebSocket command requested: $command (feature pending)", "VTUBE")
        }
        return $false
    }
}

# Public function for VTube Studio management
function New-VTubeStudioManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $VTubeConfig,

        [Parameter(Mandatory = $true)]
        [object] $Messages,

        [Parameter(Mandatory = $false)]
        [object] $Logger = $null
    )

    return [VTubeStudioManager]::new($VTubeConfig, $Messages, $Logger)
}

# Functions are available via dot-sourcing
