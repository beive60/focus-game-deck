# WebSocket Application Manager Base Module
# Provides common functionality for WebSocket-based application managers
# Used by OBSManager and VTubeStudioManager for shared operations

class WebSocketAppManagerBase {
    [System.Net.WebSockets.ClientWebSocket] $WebSocket
    [object] $Config
    [object] $Messages
    [object] $Logger
    [string] $AppName
    [hashtable] $WebSocketConfig

    # Constructor
    WebSocketAppManagerBase([object] $config, [object] $messages, [object] $logger = $null, [string] $appName = "Unknown") {
        $this.Config = $config
        $this.Messages = $messages
        $this.Logger = $logger
        $this.AppName = $appName
        $this.WebSocketConfig = @{}
    }

    # Common WebSocket operations
    [System.Net.WebSockets.ClientWebSocket] CreateWebSocketClient() {
        return New-Object System.Net.WebSockets.ClientWebSocket
    }

    # Generic WebSocket response receiver with timeout
    [object] ReceiveWebSocketResponse([int] $TimeoutSeconds = 5) {
        if (-not $this.WebSocket -or $this.WebSocket.State -ne "Open") {
            if ($this.Logger) { 
                $this.Logger.Warning("WebSocket not connected for $($this.AppName)", $this.AppName.ToUpper()) 
            }
            return $null
        }

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
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Error("WebSocket receive error for $($this.AppName): $_", $this.AppName.ToUpper()) 
            }
            return $null
        }
    }

    # Generic WebSocket message sender
    [bool] SendWebSocketMessage([object] $message) {
        if (-not $this.WebSocket -or $this.WebSocket.State -ne "Open") {
            if ($this.Logger) { 
                $this.Logger.Warning("WebSocket not connected for $($this.AppName)", $this.AppName.ToUpper()) 
            }
            return $false
        }

        try {
            $json = $message | ConvertTo-Json -Depth 5
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $sendSegment = New-Object ArraySegment[byte](, $buffer)
            $this.WebSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
            return $true
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Error("WebSocket send error for $($this.AppName): $_", $this.AppName.ToUpper()) 
            }
            return $false
        }
    }

    # Common WebSocket connection setup
    [System.Net.WebSockets.ClientWebSocket] EstablishWebSocketConnection([string] $uri, [int] $timeoutMs = 5000) {
        try {
            $newWebSocket = $this.CreateWebSocketClient()
            $cts = New-Object System.Threading.CancellationTokenSource
            $cts.CancelAfter($timeoutMs)
            
            $newWebSocket.ConnectAsync($uri, $cts.Token).Wait()
            
            if ($newWebSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                if ($this.Logger) { 
                    $this.Logger.Info("WebSocket connected to $uri for $($this.AppName)", $this.AppName.ToUpper()) 
                }
                return $newWebSocket
            } else {
                if ($this.Logger) { 
                    $this.Logger.Error("WebSocket connection failed for $($this.AppName)", $this.AppName.ToUpper()) 
                }
                $newWebSocket.Dispose()
                return $null
            }
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Error("WebSocket connection error for $($this.AppName): $_", $this.AppName.ToUpper()) 
            }
            return $null
        }
    }

    # Common WebSocket cleanup
    [void] CleanupWebSocket([System.Net.WebSockets.ClientWebSocket] $webSocket = $null) {
        $socketToClean = if ($webSocket) { $webSocket } else { $this.WebSocket }
        
        if ($socketToClean) {
            try {
                if ($socketToClean.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                    $socketToClean.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Disconnecting", [System.Threading.CancellationToken]::None).Wait()
                }
            }
            catch {
                # Ignore errors during disconnect
                if ($this.Logger) { 
                    $this.Logger.Warning("WebSocket cleanup warning for $($this.AppName): $_", $this.AppName.ToUpper()) 
                }
            }
            finally {
                $socketToClean.Dispose()
                if ($socketToClean -eq $this.WebSocket) {
                    $this.WebSocket = $null
                }
            }
        }
    }

    # Common process checking utility
    [bool] IsProcessRunning([string] $processName) {
        if ([string]::IsNullOrEmpty($processName)) {
            return $false
        }

        # Handle multiple process names separated by |
        $processNames = $processName -split '\|'
        
        foreach ($name in $processNames) {
            $name = $name.Trim()
            if ($name -and (Get-Process -Name $name -ErrorAction SilentlyContinue)) {
                return $true
            }
        }
        
        return $false
    }

    # Common application startup utility with retry logic
    [bool] StartApplicationWithRetry([string] $appPath, [string] $arguments = "", [string] $processName = "", [int] $maxRetries = 10, [int] $retryDelaySeconds = 2) {
        if (-not $appPath -or -not (Test-Path $appPath)) {
            if ($this.Logger) { 
                $this.Logger.Error("Application path not found for $($this.AppName): $appPath", $this.AppName.ToUpper()) 
            }
            return $false
        }

        try {
            # Start the application
            if ($arguments) {
                Start-Process -FilePath $appPath -ArgumentList $arguments
            } else {
                Start-Process -FilePath $appPath
            }

            if ($this.Logger) { 
                $this.Logger.Info("Started $($this.AppName) process: $appPath", $this.AppName.ToUpper()) 
            }
            
            # Wait for startup if process name is provided
            if ($processName) {
                $retryCount = 0
                while (-not $this.IsProcessRunning($processName) -and ($retryCount -lt $maxRetries)) {
                    Start-Sleep -Seconds $retryDelaySeconds
                    $retryCount++
                }
                
                if ($this.IsProcessRunning($processName)) {
                    if ($this.Logger) { 
                        $this.Logger.Info("$($this.AppName) startup verified successfully", $this.AppName.ToUpper()) 
                    }
                    return $true
                } else {
                    if ($this.Logger) { 
                        $this.Logger.Error("$($this.AppName) startup verification failed (timeout)", $this.AppName.ToUpper()) 
                    }
                    return $false
                }
            }
            
            return $true
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Error("Failed to start $($this.AppName): $_", $this.AppName.ToUpper()) 
            }
            return $false
        }
    }

    # Common application shutdown utility with graceful handling
    [bool] StopApplicationGracefully([string] $processName, [int] $gracefulTimeoutMs = 5000) {
        if ([string]::IsNullOrEmpty($processName)) {
            if ($this.Logger) { 
                $this.Logger.Warning("No process name provided for $($this.AppName) shutdown", $this.AppName.ToUpper()) 
            }
            return $false
        }

        if (-not $this.IsProcessRunning($processName)) {
            if ($this.Logger) { 
                $this.Logger.Info("$($this.AppName) is not running, skipping shutdown", $this.AppName.ToUpper()) 
            }
            return $true
        }

        try {
            # Handle multiple process names separated by |
            $processNames = $processName -split '\|'
            $shutdownSuccess = $true
            
            foreach ($name in $processNames) {
                $name = $name.Trim()
                if (-not $name) { continue }
                
                $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
                foreach ($process in $processes) {
                    try {
                        # Try graceful shutdown first
                        $process.CloseMainWindow()
                        if (-not $process.WaitForExit($gracefulTimeoutMs)) {
                            # Force kill if graceful shutdown fails
                            $process.Kill()
                            $process.WaitForExit()
                            if ($this.Logger) { 
                                $this.Logger.Warning("Force killed $($this.AppName) process: $name", $this.AppName.ToUpper()) 
                            }
                        } else {
                            if ($this.Logger) { 
                                $this.Logger.Info("Gracefully stopped $($this.AppName) process: $name", $this.AppName.ToUpper()) 
                            }
                        }
                    }
                    catch {
                        if ($this.Logger) { 
                            $this.Logger.Error("Failed to stop $($this.AppName) process $name : $_", $this.AppName.ToUpper()) 
                        }
                        $shutdownSuccess = $false
                    }
                }
            }
            
            return $shutdownSuccess
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Error("Error during $($this.AppName) shutdown: $_", $this.AppName.ToUpper()) 
            }
            return $false
        }
    }

    # Utility method for secure string handling
    [System.Security.SecureString] ConvertToSecureStringSafe([string] $PlainText) {
        if ([string]::IsNullOrEmpty($PlainText)) {
            return $null
        }

        try {
            return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Warning("ConvertTo-SecureString failed for $($this.AppName), using alternative method: $_", $this.AppName.ToUpper()) 
            }
            
            $secureString = New-Object System.Security.SecureString
            foreach ($char in $PlainText.ToCharArray()) {
                $secureString.AppendChar($char)
            }
            $secureString.MakeReadOnly()
            return $secureString
        }
    }

    # Generic status report
    [hashtable] GetBaseStatus() {
        return @{
            AppName = $this.AppName
            WebSocketConnected = ($this.WebSocket -and $this.WebSocket.State -eq "Open")
            ConfigLoaded = ($null -ne $this.Config)
            LastUpdate = Get-Date
        }
    }
}

# Public function for creating base manager
function New-WebSocketAppManagerBase {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,
        
        [Parameter(Mandatory = $true)]
        [object] $Messages,

        [Parameter(Mandatory = $false)]
        [object] $Logger = $null,

        [Parameter(Mandatory = $false)]
        [string] $AppName = "Unknown"
    )
    
    return [WebSocketAppManagerBase]::new($Config, $Messages, $Logger, $AppName)
}

# Functions are available via dot-sourcing