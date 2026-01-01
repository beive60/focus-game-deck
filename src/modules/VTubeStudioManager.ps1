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
            $this.BaseHelper = New-WebSocketAppManagerBase -Config $vtubeConfig -Messages $messages -Logger $logger -AppName "VTubeStudio"
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

    # WebSocket connection and API methods

    # Connect to VTube Studio WebSocket API
    [bool] ConnectWebSocket() {
        try {
            # Check if WebSocket is enabled in config
            if (-not $this.Config.websocket -or -not $this.Config.websocket.enabled) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_disabled" -Default "VTube Studio WebSocket integration is disabled" -Level "INFO" -Component "VTubeStudioManager"
                if ($this.Logger) {
                    $this.Logger.Info("WebSocket integration disabled in config", "VTUBE")
                }
                return $false
            }

            # Use 127.0.0.1 instead of localhost to avoid IPv6 issues
            $host = if ($this.Config.websocket.host) { $this.Config.websocket.host } else { "127.0.0.1" }
            $port = if ($this.Config.websocket.port) { $this.Config.websocket.port } else { 8001 }
            
            $this.WebSocket = New-Object System.Net.WebSockets.ClientWebSocket
            $uri = "ws://${host}:${port}"
            
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_connecting_websocket" -Args @($uri) -Default "Connecting to VTube Studio WebSocket: {0}" -Level "INFO" -Component "VTubeStudioManager"
            
            $cts = New-Object System.Threading.CancellationTokenSource
            $cts.CancelAfter(5000)
            
            $this.WebSocket.ConnectAsync($uri, $cts.Token).Wait()
            
            if ($this.WebSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_connection_failed" -Default "Failed to connect to VTube Studio WebSocket" -Level "WARNING" -Component "VTubeStudioManager"
                return $false
            }
            
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_connected" -Default "Connected to VTube Studio WebSocket" -Level "OK" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Info("WebSocket connected to $uri", "VTUBE")
            }
            
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_connection_error" -Args @($_) -Default "VTube Studio WebSocket connection error: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("WebSocket connection error: $_", "VTUBE")
            }
            return $false
        }
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

    # Send WebSocket message to VTube Studio
    [bool] SendWebSocketMessage([object] $message) {
        if (-not $this.WebSocket -or $this.WebSocket.State -ne "Open") {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_not_connected" -Default "VTube Studio WebSocket not connected" -Level "WARNING" -Component "VTubeStudioManager"
            return $false
        }

        try {
            $json = $message | ConvertTo-Json -Depth 5 -Compress
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $sendSegment = New-Object ArraySegment[byte](, $buffer)
            
            # Use timeout for send operation
            $cts = New-Object System.Threading.CancellationTokenSource
            $cts.CancelAfter(5000)
            
            $this.WebSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_send_error" -Args @($_) -Default "VTube Studio WebSocket send error: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("WebSocket send error: $_", "VTUBE")
            }
            return $false
        }
    }

    # Receive WebSocket response from VTube Studio
    [object] ReceiveWebSocketResponse([int] $TimeoutSeconds = 5) {
        if (-not $this.WebSocket -or $this.WebSocket.State -ne "Open") {
            return $null
        }

        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter($TimeoutSeconds * 1000)
        $buffer = New-Object byte[] 8192
        $segment = New-Object ArraySegment[byte](, $buffer)
        $resultText = ""
        $maxIterations = 100  # Prevent infinite loops

        try {
            $iteration = 0
            while ($this.WebSocket.State -eq "Open" -and $iteration -lt $maxIterations) {
                $receiveTask = $this.WebSocket.ReceiveAsync($segment, $cts.Token)
                $receiveTask.Wait()
                $result = $receiveTask.Result

                $resultText += [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)

                if ($result.EndOfMessage) {
                    break
                }
                $iteration++
            }
            
            if ($iteration -ge $maxIterations) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_message_too_large" -Default "VTube Studio message exceeded size limit" -Level "WARNING" -Component "VTubeStudioManager"
                return $null
            }
            
            return $resultText | ConvertFrom-Json
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_websocket_receive_error" -Args @($_) -Default "VTube Studio WebSocket receive error: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("WebSocket receive error: $_", "VTUBE")
            }
            return $null
        }
    }

    # Authenticate with VTube Studio API
    [bool] Authenticate() {
        try {
            # Get authentication token from config
            $authToken = $null
            if ($this.Config.authenticationToken) {
                try {
                    # Try to decrypt DPAPI-encrypted token (new format)
                    $secureToken = ConvertTo-SecureString -String $this.Config.authenticationToken
                    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
                    $authToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                } catch {
                    # Fall back to plain text (old format for backward compatibility)
                    $authToken = $this.Config.authenticationToken
                    Write-LocalizedHost -Messages $this.Messages -Key "vtube_plaintext_token_detected" -Default "Plain text authentication token detected - consider re-saving with encryption" -Level "WARNING" -Component "VTubeStudioManager"
                }
            }

            # If no token, request a new one
            if (-not $authToken) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_requesting_token" -Default "Requesting authentication token from VTube Studio..." -Level "INFO" -Component "VTubeStudioManager"
                
                $tokenRequest = @{
                    apiName = "FocusGameDeck"
                    apiVersion = "1.0"
                    requestID = "AuthenticationTokenRequest"
                    messageType = "AuthenticationTokenRequest"
                    data = @{
                        pluginName = "Focus Game Deck"
                        pluginDeveloper = "Focus Game Deck Team"
                    }
                }
                
                if (-not $this.SendWebSocketMessage($tokenRequest)) {
                    return $false
                }
                
                $tokenResponse = $this.ReceiveWebSocketResponse(10)
                if (-not $tokenResponse -or $tokenResponse.messageType -ne "AuthenticationTokenResponse") {
                    Write-LocalizedHost -Messages $this.Messages -Key "vtube_token_request_failed" -Default "Failed to obtain authentication token from VTube Studio" -Level "WARNING" -Component "VTubeStudioManager"
                    return $false
                }
                
                $authToken = $tokenResponse.data.authenticationToken
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_token_received" -Default "Authentication token received from VTube Studio" -Level "OK" -Component "VTubeStudioManager"
            }

            # Authenticate with the token
            $authRequest = @{
                apiName = "FocusGameDeck"
                apiVersion = "1.0"
                requestID = "AuthenticationRequest"
                messageType = "AuthenticationRequest"
                data = @{
                    pluginName = "Focus Game Deck"
                    pluginDeveloper = "Focus Game Deck Team"
                    authenticationToken = $authToken
                }
            }
            
            if (-not $this.SendWebSocketMessage($authRequest)) {
                return $false
            }
            
            $authResponse = $this.ReceiveWebSocketResponse(5)
            if (-not $authResponse -or $authResponse.messageType -ne "AuthenticationResponse") {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_auth_failed" -Default "VTube Studio authentication failed" -Level "WARNING" -Component "VTubeStudioManager"
                return $false
            }
            
            if (-not $authResponse.data.authenticated) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_auth_rejected" -Default "VTube Studio authentication rejected" -Level "WARNING" -Component "VTubeStudioManager"
                return $false
            }
            
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_auth_successful" -Default "VTube Studio authentication successful" -Level "OK" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Info("Authentication successful", "VTUBE")
            }
            
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_auth_error" -Args @($_) -Default "VTube Studio authentication error: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("Authentication error: $_", "VTUBE")
            }
            return $false
        }
    }

    # Load a VTube Studio model by ID
    [bool] LoadModel([string] $modelID) {
        if ([string]::IsNullOrWhiteSpace($modelID)) {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_model_id_required" -Default "Model ID is required" -Level "WARNING" -Component "VTubeStudioManager"
            return $false
        }

        try {
            # Connect and authenticate if not already connected
            if (-not $this.WebSocket -or $this.WebSocket.State -ne "Open") {
                if (-not $this.ConnectWebSocket()) {
                    return $false
                }
                if (-not $this.Authenticate()) {
                    $this.DisconnectWebSocket()
                    return $false
                }
            }

            Write-LocalizedHost -Messages $this.Messages -Key "vtube_loading_model" -Args @($modelID) -Default "Loading VTube Studio model: {0}" -Level "INFO" -Component "VTubeStudioManager"
            
            $loadModelRequest = @{
                apiName = "FocusGameDeck"
                apiVersion = "1.0"
                requestID = "ModelLoadRequest"
                messageType = "ModelLoadRequest"
                data = @{
                    modelID = $modelID
                }
            }
            
            if (-not $this.SendWebSocketMessage($loadModelRequest)) {
                return $false
            }
            
            $loadResponse = $this.ReceiveWebSocketResponse(10)
            if (-not $loadResponse -or $loadResponse.messageType -ne "ModelLoadResponse") {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_model_load_failed" -Default "Failed to load VTube Studio model" -Level "WARNING" -Component "VTubeStudioManager"
                return $false
            }
            
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_model_loaded" -Args @($modelID) -Default "VTube Studio model loaded: {0}" -Level "OK" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Info("Model loaded: $modelID", "VTUBE")
            }
            
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_model_load_error" -Args @($modelID, $_) -Default "Error loading VTube Studio model {0}: {1}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("Model load error for $modelID : $_", "VTUBE")
            }
            return $false
        }
    }

    # Trigger VTube Studio hotkeys
    [bool] TriggerHotkeys([array] $hotkeyIDs) {
        if (-not $hotkeyIDs -or $hotkeyIDs.Count -eq 0) {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_hotkey_ids_required" -Default "Hotkey IDs are required" -Level "WARNING" -Component "VTubeStudioManager"
            return $false
        }

        try {
            # Connect and authenticate if not already connected
            if (-not $this.WebSocket -or $this.WebSocket.State -ne "Open") {
                if (-not $this.ConnectWebSocket()) {
                    return $false
                }
                if (-not $this.Authenticate()) {
                    $this.DisconnectWebSocket()
                    return $false
                }
            }

            Write-LocalizedHost -Messages $this.Messages -Key "vtube_triggering_hotkeys" -Args @($hotkeyIDs.Count) -Default "Triggering {0} VTube Studio hotkey(s)" -Level "INFO" -Component "VTubeStudioManager"
            
            $allSuccess = $true
            foreach ($hotkeyID in $hotkeyIDs) {
                if ([string]::IsNullOrWhiteSpace($hotkeyID)) {
                    continue
                }
                
                $triggerRequest = @{
                    apiName = "FocusGameDeck"
                    apiVersion = "1.0"
                    requestID = "HotkeyTriggerRequest_$hotkeyID"
                    messageType = "HotkeyTriggerRequest"
                    data = @{
                        hotkeyID = $hotkeyID
                    }
                }
                
                if (-not $this.SendWebSocketMessage($triggerRequest)) {
                    $allSuccess = $false
                    continue
                }
                
                $triggerResponse = $this.ReceiveWebSocketResponse(5)
                if (-not $triggerResponse -or $triggerResponse.messageType -ne "HotkeyTriggerResponse") {
                    Write-LocalizedHost -Messages $this.Messages -Key "vtube_hotkey_trigger_failed" -Args @($hotkeyID) -Default "Failed to trigger VTube Studio hotkey: {0}" -Level "WARNING" -Component "VTubeStudioManager"
                    $allSuccess = $false
                    continue
                }
                
                if ($this.Logger) {
                    $this.Logger.Info("Hotkey triggered: $hotkeyID", "VTUBE")
                }
            }
            
            if ($allSuccess) {
                Write-LocalizedHost -Messages $this.Messages -Key "vtube_hotkeys_triggered" -Args @($hotkeyIDs.Count) -Default "Triggered {0} VTube Studio hotkey(s) successfully" -Level "OK" -Component "VTubeStudioManager"
            }
            
            return $allSuccess
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "vtube_hotkey_trigger_error" -Args @($_) -Default "Error triggering VTube Studio hotkeys: {0}" -Level "WARNING" -Component "VTubeStudioManager"
            if ($this.Logger) {
                $this.Logger.Error("Hotkey trigger error: $_", "VTUBE")
            }
            return $false
        }
    }

    # Send command to VTube Studio (legacy method for backward compatibility)
    [bool] SendCommand([string] $command, [object] $parameters = $null) {
        Write-LocalizedHost -Messages $this.Messages -Key "vtube_send_command_deprecated" -Args @($command) -Default "SendCommand is deprecated, use specific API methods instead: {0}" -Level "WARNING" -Component "VTubeStudioManager"
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
