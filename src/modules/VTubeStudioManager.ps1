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
            $baseModulePath = Join-Path $PSScriptRoot "WebSocketAppManagerBase.ps1"
            if (Test-Path $baseModulePath) {
                . $baseModulePath
                $this.BaseHelper = New-WebSocketAppManagerBase -Config $vtubeConfig -Messages $messages -Logger $logger -AppName "VTubeStudio"
            } else {
                Write-Warning "WebSocketAppManagerBase.ps1 not found, using fallback methods"
                $this.BaseHelper = $null
            }
        }
        catch {
            Write-Warning "Failed to load WebSocketAppManagerBase: $_"
            $this.BaseHelper = $null
        }
    }

    # Check if VTube Studio process is running
    [bool] IsVTubeStudioRunning() {
        if ($this.BaseHelper) {
            return $this.BaseHelper.IsProcessRunning($this.ProcessName)
        } else {
            # Fallback to original implementation
            $process = Get-Process -Name $this.ProcessName -ErrorAction SilentlyContinue
            return $null -ne $process
        }
    }

    # Detect VTube Studio installation type and path
    [hashtable] DetectVTubeStudioInstallation() {
        $result = @{
            Type = $null
            Path = $null
            Available = $false
        }

        # First, check for Steam version
        try {
            $steamAppPath = $null
            
            # Method 1: Check Steam registry
            $steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue
            if ($steamPath) {
                $steamAppsPath = Join-Path $steamPath.SteamPath "steamapps\common\VTube Studio"
                $steamExePath = Join-Path $steamAppsPath "VTube Studio.exe"
                if (Test-Path $steamExePath) {
                    $steamAppPath = $steamExePath
                }
            }

            # Method 2: Check common Steam installation paths
            if (-not $steamAppPath) {
                $commonSteamPaths = @(
                    "C:\Program Files (x86)\Steam\steamapps\common\VTube Studio\VTube Studio.exe",
                    "C:\Program Files\Steam\steamapps\common\VTube Studio\VTube Studio.exe"
                )
                foreach ($path in $commonSteamPaths) {
                    if (Test-Path $path) {
                        $steamAppPath = $path
                        break
                    }
                }
            }

            if ($steamAppPath) {
                $result.Type = "Steam"
                $result.Path = $steamAppPath
                $result.Available = $true
                if ($this.Logger) { 
                    $this.Logger.Info("VTube Studio Steam version detected at: $steamAppPath", "VTUBE") 
                }
                return $result
            }
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Warning("Failed to detect Steam VTube Studio: $_", "VTUBE") 
            }
        }

        # Check for standalone version if configured
        if ($this.Config.path -and (Test-Path $this.Config.path)) {
            $result.Type = "Standalone"
            $result.Path = $this.Config.path
            $result.Available = $true
            if ($this.Logger) { 
                $this.Logger.Info("VTube Studio standalone version detected at: $($this.Config.path)", "VTUBE") 
            }
            return $result
        }

        # Check common standalone installation paths
        $commonStandaloPaths = @(
            "$env:USERPROFILE\AppData\Local\VTube Studio\VTube Studio.exe",
            "C:\Program Files\VTube Studio\VTube Studio.exe",
            "C:\Program Files (x86)\VTube Studio\VTube Studio.exe"
        )
        
        foreach ($path in $commonStandaloPaths) {
            if (Test-Path $path) {
                $result.Type = "Standalone"
                $result.Path = $path
                $result.Available = $true
                if ($this.Logger) { 
                    $this.Logger.Info("VTube Studio standalone version detected at: $path", "VTUBE") 
                }
                return $result
            }
        }

        if ($this.Logger) { 
            $this.Logger.Warning("VTube Studio installation not found", "VTUBE") 
        }
        return $result
    }

    # Start VTube Studio application
    [bool] StartVTubeStudio() {
        if ($this.IsVTubeStudioRunning()) {
            Write-Host "VTube Studio is already running"
            if ($this.Logger) { 
                $this.Logger.Info("VTube Studio already running, skipping startup", "VTUBE") 
            }
            return $true
        }

        $installation = $this.DetectVTubeStudioInstallation()
        if (-not $installation.Available) {
            Write-Host "VTube Studio installation not found"
            if ($this.Logger) { 
                $this.Logger.Error("VTube Studio installation not found", "VTUBE") 
            }
            return $false
        }

        try {
            if ($installation.Type -eq "Steam") {
                # Launch via Steam to ensure proper DRM handling
                $steamPath = $this.GetSteamPath()
                if ($steamPath -and (Test-Path $steamPath)) {
                    Write-Host "Starting VTube Studio via Steam..."
                    Start-Process $steamPath -ArgumentList "-applaunch $($this.SteamAppId)"
                    if ($this.Logger) { 
                        $this.Logger.Info("Started VTube Studio via Steam (AppID: $($this.SteamAppId))", "VTUBE") 
                    }
                } else {
                    Write-Host "Steam not found, launching VTube Studio directly..."
                    Start-Process -FilePath $installation.Path
                    if ($this.Logger) { 
                        $this.Logger.Info("Started VTube Studio directly: $($installation.Path)", "VTUBE") 
                    }
                }
            } else {
                # Launch standalone version directly
                Write-Host "Starting VTube Studio (standalone)..."
                $arguments = $this.Config.arguments -or ""
                Start-Process -FilePath $installation.Path -ArgumentList $arguments
                if ($this.Logger) { 
                    $this.Logger.Info("Started VTube Studio standalone: $($installation.Path)", "VTUBE") 
                }
            }

            # Wait for VTube Studio to start
            $retryCount = 0
            $maxRetries = 15  # VTube Studio can take longer to start than OBS
            Write-Host "Waiting for VTube Studio to start..."
            
            while (-not $this.IsVTubeStudioRunning() -and ($retryCount -lt $maxRetries)) {
                Start-Sleep -Seconds 2
                $retryCount++
            }
            
            if ($this.IsVTubeStudioRunning()) {
                Write-Host "VTube Studio startup complete"
                if ($this.Logger) { 
                    $this.Logger.Info("VTube Studio startup completed successfully", "VTUBE") 
                }
                # Give VTube Studio time to fully initialize before WebSocket operations
                Start-Sleep -Seconds 3
                return $true
            } else {
                Write-Host "VTube Studio startup failed or timed out"
                if ($this.Logger) { 
                    $this.Logger.Error("VTube Studio startup failed or timed out", "VTUBE") 
                }
                return $false
            }
        }
        catch {
            Write-Host "Failed to start VTube Studio: $_"
            if ($this.Logger) { 
                $this.Logger.Error("Failed to start VTube Studio: $_", "VTUBE") 
            }
            return $false
        }
    }

    # Stop VTube Studio application
    [bool] StopVTubeStudio() {
        Write-Host "Stopping VTube Studio..."
        
        if ($this.BaseHelper) {
            # Use base helper for advanced shutdown
            $result = $this.BaseHelper.StopApplicationGracefully($this.ProcessName, 5000)
            
            if ($result) {
                Write-Host "VTube Studio stopped successfully"
            } else {
                Write-Host "Failed to stop VTube Studio"
            }
            
            return $result
        } else {
            # Fallback to original implementation
            if (-not $this.IsVTubeStudioRunning()) {
                Write-Host "VTube Studio is not running"
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

                Write-Host "VTube Studio stopped successfully"
                if ($this.Logger) { 
                    $this.Logger.Info("VTube Studio stopped successfully", "VTUBE") 
                }
                return $true
            }
            catch {
                Write-Host "Failed to stop VTube Studio: $_"
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
        if ($this.Config.steamPath -and (Test-Path $this.Config.steamPath)) {
            return $this.Config.steamPath
        }

        # Auto-detect Steam path
        $steamPaths = @(
            "C:\Program Files (x86)\Steam\steam.exe",
            "C:\Program Files\Steam\steam.exe"
        )

        foreach ($path in $steamPaths) {
            if (Test-Path $path) {
                return $path
            }
        }

        # Try registry
        try {
            $steamReg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamExe" -ErrorAction SilentlyContinue
            if ($steamReg -and (Test-Path $steamReg.SteamExe)) {
                return $steamReg.SteamExe
            }
        }
        catch {
            # Ignore registry errors
        }

        return $null
    }

    # WebSocket connection methods (for future expansion)
    # These methods provide the foundation for VTube Studio API integration

    # Connect to VTube Studio WebSocket API
    [bool] ConnectWebSocket() {
        # Future implementation: Connect to ws://localhost:8001
        # This will be implemented when WebSocket features are needed
        Write-Host "WebSocket connection feature coming soon..."
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
                }
                catch {
                    # Ignore errors during disconnect
                }
                finally {
                    $this.WebSocket.Dispose()
                }
            }
        }
        $this.WebSocket = $null
    }

    # Send command to VTube Studio (placeholder for future WebSocket commands)
    [bool] SendCommand([string] $command, [object] $parameters = $null) {
        # Future implementation: Send WebSocket commands to VTube Studio API
        Write-Host "WebSocket command feature coming soon: $command"
        if ($this.Logger) { 
            $this.Logger.Info("WebSocket command requested: $command (feature pending)", "VTUBE") 
        }
        return $false
    }

    # Get VTube Studio status and information
    [object] GetStatus() {
        return @{
            IsRunning = $this.IsVTubeStudioRunning()
            Installation = $this.DetectVTubeStudioInstallation()
            WebSocketConnected = $false  # Will be updated when WebSocket is implemented
        }
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