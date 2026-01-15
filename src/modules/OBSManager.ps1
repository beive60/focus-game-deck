# OBS WebSocket Manager Module
# Handles all OBS-related operations including connection, authentication, and replay buffer control

class OBSManager {
    [System.Net.WebSockets.ClientWebSocket] $WebSocket
    [object] $Config
    [object] $Messages
    [string] $HostName
    [int] $Port
    [System.Security.SecureString] $Password

    # Constructor
    OBSManager([object] $obsConfig, [object] $messages) {
        $this.Config = $obsConfig
        $this.Messages = $messages

        # WebSocket config is nested in 'websocket' property
        if ($obsConfig.websocket) {
            $this.HostName = $obsConfig.websocket.host
            $this.Port = $obsConfig.websocket.port

            if ($obsConfig.websocket.password) {
                try {
                    # Try to decrypt DPAPI-encrypted password (new format)
                    $this.Password = ConvertTo-SecureString -String $obsConfig.websocket.password
                } catch {
                    # Fall back to plain text conversion (old format for backward compatibility)
                    $this.Password = $this.ConvertToSecureStringSafe($obsConfig.websocket.password)
                    Write-LocalizedHost -Messages $this.Messages -Key "plaintext_password_detected" -Default "Plain text password detected in config - consider using the GUI to re-save with encryption" -Level "WARNING" -Component "OBSManager"
                }
            }
        }
    }

    # Helper method for secure string conversion
    [System.Security.SecureString] ConvertToSecureStringSafe([string] $PlainText) {
        try {
            return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "secure_string_conversion_failed" -Args @($_) -Default "ConvertTo-SecureString failed, attempting alternative method: {0}" -Level "WARNING" -Component "OBSManager"
            $secureString = New-Object System.Security.SecureString
            foreach ($char in $PlainText.ToCharArray()) {
                $secureString.AppendChar($char)
            }
            $secureString.MakeReadOnly()
            return $secureString
        }
    }

    # Receive WebSocket response with timeout
    [object] ReceiveWebSocketResponse([int] $TimeoutSeconds = 5) {
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter($TimeoutSeconds * 1000)
        $buffer = New-Object byte[] 8192
        $segment = New-Object ArraySegment[byte](, $buffer)
        $resultText = ""

        try {
            while ($this.WebSocket.State -eq "Open") {
                $receiveTask = $this.WebSocket.ReceiveAsync($segment, $cts.Token)
                $receiveTask.Wait()
                $result = $receiveTask.Result

                $resultText += [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)

                if ($result.EndOfMessage) {
                    break
                }
            }
            return $resultText | ConvertFrom-Json
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "error_receive_websocket" -Args @($_) -Default "WebSocket receive error: {0}" -Level "WARNING" -Component "OBSManager"
            return $null
        }
    }

    # Connect to OBS WebSocket
    [bool] Connect() {
        try {
            Write-LocalizedHost -Messages $this.Messages -Key "attempting_obs_connection" -Args @($this.HostName, $this.Port) -Default "Attempting OBS WebSocket connection to {0}:{1}..." -Level "INFO" -Component "OBSManager"
            $this.WebSocket = New-Object System.Net.WebSockets.ClientWebSocket
            $cts = New-Object System.Threading.CancellationTokenSource
            $cts.CancelAfter(5000)

            $uri = "ws://$($this.HostName):$($this.Port)"
            $this.WebSocket.ConnectAsync($uri, $cts.Token).Wait()

            if ($this.WebSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-LocalizedHost -Messages $this.Messages -Key "failed_connect_obs" -Default "Failed to connect to OBS" -Level "WARNING" -Component "OBSManager"
                return $false
            }

            Write-LocalizedHost -Messages $this.Messages -Key "connected_obs_websocket" -Default "Connected to OBS WebSocket" -Level "OK" -Component "OBSManager"

            # Wait for Hello message (Op 0)
            Write-LocalizedHost -Messages $this.Messages -Key "waiting_hello_message" -Default "Waiting for Hello message from OBS..." -Level "INFO" -Component "OBSManager"
            $hello = $this.ReceiveWebSocketResponse(5)
            if (-not $hello -or $hello.op -ne 0) {
                Write-LocalizedHost -Messages $this.Messages -Key "error_receive_hello" -Default "Error receiving Hello message" -Level "WARNING" -Component "OBSManager"
                $this.Disconnect()
                return $false
            }

            # Send Identify message (Op 1)
            Write-LocalizedHost -Messages $this.Messages -Key "sending_identify_message" -Default "Sending Identify message to OBS..." -Level "INFO" -Component "OBSManager"
            $identifyPayload = @{
                op = 1
                d = @{
                    rpcVersion = 1
                }
            }

            # Handle authentication if required
            if ($hello.d.authentication) {
                Write-LocalizedHost -Messages $this.Messages -Key "auth_required" -Default "Authentication required" -Level "INFO" -Component "OBSManager"
                $authResponse = $this.HandleAuthentication($hello.d.authentication)
                if (-not $authResponse) {
                    $this.Disconnect()
                    return $false
                }
                $identifyPayload.d.authentication = $authResponse
            }

            # Send identify message
            $this.SendMessage($identifyPayload)

            # Wait for Identified message (Op 2)
            $identified = $this.ReceiveWebSocketResponse(5)
            if (-not $identified -or $identified.op -ne 2) {
                Write-LocalizedHost -Messages $this.Messages -Key "obs_auth_failed" -Default "OBS authentication failed" -Level "WARNING" -Component "OBSManager"
                $this.Disconnect()
                return $false
            }

            Write-LocalizedHost -Messages $this.Messages -Key "obs_auth_successful" -Default "OBS authentication successful" -Level "OK" -Component "OBSManager"
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "obs_connection_error" -Args @($_) -Default "OBS connection error: {0}" -Level "WARNING" -Component "OBSManager"
            return $false
        }
    }

    # Handle OBS authentication challenge
    [string] HandleAuthentication([object] $authData) {
        try {
            $salt = $authData.salt
            $challenge = $authData.challenge
            $sha256 = [System.Security.Cryptography.SHA256]::Create()

            # Convert SecureString to plain text for hashing
            $plainTextPassword = ''
            if ($this.Password -and $this.Password.Length -gt 0) {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.Password)
                $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }

            # Calculate secret = base64(sha256(password + salt))
            $secretBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plainTextPassword + $salt))
            $secret = [System.Convert]::ToBase64String($secretBytes)

            # Calculate authResponse = base64(sha256(secret + challenge))
            $authResponseBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($secret + $challenge))
            return [System.Convert]::ToBase64String($authResponseBytes)
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "authentication_calculation_failed" -Args @($_) -Default "Authentication calculation failed: {0}" -Level "WARNING" -Component "OBSManager"
            return $null
        }
    }

    # Send message to OBS WebSocket
    [void] SendMessage([object] $message) {
        $json = $message | ConvertTo-Json -Depth 5
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $sendSegment = New-Object ArraySegment[byte](, $buffer)
        [void] $this.WebSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
    }

    # Start OBS Replay Buffer
    [bool] StartReplayBuffer() {
        try {
            Write-LocalizedHost -Messages $this.Messages -Key "sending_replay_buffer_start" -Default "Sending StartReplayBuffer command to OBS..." -Level "INFO" -Component "OBSManager"
            $requestId = [System.Guid]::NewGuid().ToString()
            $command = @{
                op = 6
                d = @{
                    requestType = "StartReplayBuffer"
                    requestId = $requestId
                }
            }

            $this.SendMessage($command)

            # Wait for response to verify success
            $response = $this.ReceiveWebSocketResponse(5)
            if ($response -and $response.op -eq 7) {
                if ($response.d.requestStatus.result) {
                    Write-LocalizedHost -Messages $this.Messages -Key "obs_replay_buffer_started" -Default "OBS replay buffer started" -Level "OK" -Component "OBSManager"
                    return $true
                } else {
                    $errorCode = if ($response.d.requestStatus.code) { $response.d.requestStatus.code } else { "Unknown" }
                    $errorComment = if ($response.d.requestStatus.comment) { $response.d.requestStatus.comment } else { "No details" }
                    Write-LocalizedHost -Messages $this.Messages -Key "replay_buffer_start_failed_response" -Args @($errorCode, $errorComment) -Default "Replay buffer start failed - Code: {0}, Details: {1}" -Level "WARNING" -Component "OBSManager"
                    return $false
                }
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "replay_buffer_no_response" -Default "No response received for replay buffer start command" -Level "WARNING" -Component "OBSManager"
                return $false
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "replay_buffer_start_error" -Args @($_) -Default "Replay buffer start error: {0}" -Level "WARNING" -Component "OBSManager"
            return $false
        }
    }

    # Stop OBS Replay Buffer
    [bool] StopReplayBuffer() {
        try {
            $requestId = [System.Guid]::NewGuid().ToString()
            $command = @{
                op = 6
                d = @{
                    requestType = "StopReplayBuffer"
                    requestId = $requestId
                }
            }

            $this.SendMessage($command)
            Write-LocalizedHost -Messages $this.Messages -Key "obs_replay_buffer_stopped" -Default "OBS replay buffer stopped" -Level "OK" -Component "OBSManager"
            return $true
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "replay_buffer_stop_error" -Args @($_) -Default "Replay buffer stop error: {0}" -Level "WARNING" -Component "OBSManager"
            return $false
        }
    }

    # Get current program scene
    [string] GetCurrentProgramScene() {
        try {
            $requestId = [System.Guid]::NewGuid().ToString()
            $command = @{
                op = 6
                d = @{
                    requestType = "GetCurrentProgramScene"
                    requestId = $requestId
                }
            }

            $this.SendMessage($command)
            $response = $this.ReceiveWebSocketResponse(5)

            if ($response -and $response.op -eq 7 -and $response.d.requestStatus.result) {
                $sceneName = $response.d.responseData.currentProgramSceneName
                Write-LocalizedHost -Messages $this.Messages -Key "obs_current_scene" -Args @($sceneName) -Default "Current OBS scene: {0}" -Level "INFO" -Component "OBSManager"
                return $sceneName
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "obs_get_scene_failed" -Args @("No valid response") -Default "Failed to get current OBS scene: {0}" -Level "WARNING" -Component "OBSManager"
                return $null
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "obs_get_scene_failed" -Args @($_) -Default "Failed to get current OBS scene: {0}" -Level "WARNING" -Component "OBSManager"
            return $null
        }
    }

    # Set current program scene
    [bool] SetCurrentProgramScene([string] $sceneName) {
        try {
            $requestId = [System.Guid]::NewGuid().ToString()
            $command = @{
                op = 6
                d = @{
                    requestType = "SetCurrentProgramScene"
                    requestId = $requestId
                    requestData = @{
                        sceneName = $sceneName
                    }
                }
            }

            $this.SendMessage($command)
            $response = $this.ReceiveWebSocketResponse(5)

            if ($response -and $response.op -eq 7 -and $response.d.requestStatus.result) {
                Write-LocalizedHost -Messages $this.Messages -Key "obs_scene_switched" -Args @($sceneName) -Default "OBS scene switched to: {0}" -Level "OK" -Component "OBSManager"
                return $true
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "obs_scene_switch_failed" -Args @("Request failed") -Default "Failed to switch OBS scene: {0}" -Level "WARNING" -Component "OBSManager"
                return $false
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "obs_scene_switch_failed" -Args @($_) -Default "Failed to switch OBS scene: {0}" -Level "WARNING" -Component "OBSManager"
            return $false
        }
    }

    # Disconnect from OBS WebSocket
    [void] Disconnect() {
        if ($this.WebSocket) {
            try {
                $this.WebSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Disconnecting", [System.Threading.CancellationToken]::None).Wait()
            } catch {
                # Ignore errors during disconnect
            } finally {
                $this.WebSocket.Dispose()
                $this.WebSocket = $null
            }
        }
    }

    # Check if OBS process is running
    [bool] IsOBSRunning() {
        $procName = if ($this.Config.processName) { $this.Config.processName } else { "obs64" }
        return $null -ne (Get-Process -Name $procName -ErrorAction SilentlyContinue)
    }

    # Start OBS application
    [bool] StartOBS( ) {

        if ($this.IsOBSRunning()) {
            Write-LocalizedHost -Messages $this.Messages -Key "obs_already_running" -Default "OBS is already running" -Level "INFO" -Component "OBSManager"
            return $true
        }

        $obsPath = $this.Config.path
        if (-not $obsPath -or -not (Test-Path $obsPath)) {
            Write-LocalizedHost -Messages $this.Messages -Key "obs_path_not_found_or_invalid" -Args @($obsPath) -Default "OBS path not found or invalid: {0}" -Level "WARNING" -Component "OBSManager"
            return $false
        }

        try {
            Start-Process -FilePath $obsPath -WorkingDirectory (Split-Path -Parent $obsPath)
            Write-LocalizedHost -Messages $this.Messages -Key "starting_obs" -Default "Starting OBS..." -Level "INFO" -Component "OBSManager"

            # Wait for OBS startup
            $retryCount = 0
            $maxRetries = 15
            $waitInterval = 2

            Write-LocalizedHost -Messages $this.Messages -Key "waiting_obs_startup" -Default "Waiting for OBS to start..." -Level "INFO" -Component "OBSManager"

            while (-not $this.IsOBSRunning() -and ($retryCount -lt $maxRetries)) {
                Start-Sleep -Seconds $waitInterval
                $retryCount++
                Write-LocalizedHost -Messages $this.Messages -Key "waiting_obs_startup_retry" -Args @($retryCount, $maxRetries) -Default "Waiting for OBS startup... ({0}/{1})" -Level "INFO" -Component "OBSManager"
            }

            if ($this.IsOBSRunning()) {
                Write-LocalizedHost -Messages $this.Messages -Key "obs_process_detected" -Default "OBS process detected" -Level "OK" -Component "OBSManager"

                # Wait for WebSocket server startup
                $wsWaitTime = 10
                Write-LocalizedHost -Messages $this.Messages -Key "waiting_obs_websocket" -Args @($wsWaitTime) -Default "Waiting {0} seconds for OBS WebSocket server to start..." -Level "INFO" -Component "OBSManager"
                Start-Sleep -Seconds $wsWaitTime

                Write-LocalizedHost -Messages $this.Messages -Key "obs_startup_complete" -Default "OBS startup complete" -Level "OK" -Component "OBSManager"
                return $true
            } else {
                Write-LocalizedHost -Messages $this.Messages -Key "obs_startup_timeout" -Args @(($maxRetries * $waitInterval)) -Default "OBS startup timeout after {0} seconds" -Level "WARNING" -Component "OBSManager"
                return $false
            }
        } catch {
            Write-LocalizedHost -Messages $this.Messages -Key "obs_startup_error" -Args @($_.Exception.Message) -Default "Failed to start OBS: {0}" -Level "WARNING" -Component "OBSManager"
            return $false
        }
    }
}

# Public function for OBS management
function New-OBSManager {
    param(
        [Parameter(Mandatory = $true)]
        [object] $OBSConfig,

        [Parameter(Mandatory = $true)]
        [object] $Messages
    )

    return [OBSManager]::new($OBSConfig, $Messages)
}
