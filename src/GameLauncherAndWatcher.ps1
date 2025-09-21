param(
    [Parameter(Mandatory = $true)]
    [string]$GameId
)

# Load configuration file
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "..\config.json"
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    Write-Host "Error: The specified game ID '$GameId' does not exist in the configuration file."
    Write-Host "Available game IDs: $($config.games.PSObject.Properties.Name -join ', ')"
    exit 1
}

# Validate configuration structure
function Test-ConfigStructure {
    $errors = @()
    
    # Check if managedApps section exists
    if (-not $config.managedApps) {
        $errors += "Missing 'managedApps' section in configuration"
    }
    
    # Check if appsToManage exists for this game
    if (-not $gameConfig.appsToManage) {
        $errors += "Missing 'appsToManage' array for game '$GameId'"
    } else {
        # Validate each app in appsToManage
        foreach ($appId in $gameConfig.appsToManage) {
            if ($appId -eq "obs" -or $appId -eq "clibor") {
                # Special cases - skip validation
                continue
            }
            
            if (-not $config.managedApps.$appId) {
                $errors += "Application '$appId' is referenced in game '$GameId' but not defined in managedApps"
            } else {
                $appConfig = $config.managedApps.$appId
                
                # Validate required properties
                if (-not $appConfig.PSObject.Properties.Name -contains "processName") {
                    $errors += "Application '$appId' is missing 'processName' property"
                }
                if (-not $appConfig.PSObject.Properties.Name -contains "startupAction") {
                    $errors += "Application '$appId' is missing 'startupAction' property"
                }
                if (-not $appConfig.PSObject.Properties.Name -contains "shutdownAction") {
                    $errors += "Application '$appId' is missing 'shutdownAction' property"
                }
                
                # Validate action values
                $validActions = @("start", "stop", "none")
                if ($appConfig.startupAction -and $appConfig.startupAction -notin $validActions) {
                    $errors += "Application '$appId' has invalid startupAction: '$($appConfig.startupAction)'. Valid values: $($validActions -join ', ')"
                }
                if ($appConfig.shutdownAction -and $appConfig.shutdownAction -notin $validActions) {
                    $errors += "Application '$appId' has invalid shutdownAction: '$($appConfig.shutdownAction)'. Valid values: $($validActions -join ', ')"
                }
            }
        }
    }
    
    # Check required paths
    if (-not $config.paths.steam) {
        $errors += "Missing 'paths.steam' in configuration"
    }
    
    # Check OBS-specific configuration if OBS is managed
    if ("obs" -in $gameConfig.appsToManage) {
        if (-not $config.paths.obs) {
            $errors += "OBS is managed but 'paths.obs' is not defined"
        }
        if (-not $config.obs) {
            $errors += "OBS is managed but 'obs' configuration section is missing"
        }
    }
    
    return $errors
}

# Validate configuration
$configErrors = Test-ConfigStructure
if ($configErrors.Count -gt 0) {
    Write-Host "Configuration validation failed:" -ForegroundColor Red
    foreach ($errorMsg in $configErrors) {
        Write-Host "  - $errorMsg" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Configuration validation passed" -ForegroundColor Green

# Function to manage generic applications
function Invoke-AppAction {
    param(
        [string]$AppId,
        [string]$Action  # "start" or "stop"
    )
    
    # Validate app exists in managedApps
    if (-not $config.managedApps.$AppId) {
        Write-Host "Warning: Application '$AppId' is not defined in managedApps configuration. Skipping."
        return
    }
    
    $appConfig = $config.managedApps.$AppId
    
    if ($Action -eq "start") {
        if ($appConfig.path -and $appConfig.path -ne "") {
            $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") { $appConfig.arguments } else { $null }
            if ($arguments) {
                Start-Process -FilePath $appConfig.path -ArgumentList $arguments
            } else {
                Start-Process -FilePath $appConfig.path
            }
            Write-Host "$AppId has been started"
        } else {
            Write-Host "Warning: No path specified for $AppId, cannot start application"
        }
    }
    elseif ($Action -eq "stop") {
        if ($appConfig.processName -and $appConfig.processName -ne "") {
            # Handle multiple process names separated by |
            $processNames = $appConfig.processName -split '\|'
            $processFound = $false
            
            foreach ($processName in $processNames) {
                $processName = $processName.Trim()
                try {
                    $processes = Get-Process -Name $processName -ErrorAction Stop
                    if ($processes) {
                        Stop-Process -Name $processName -Force
                        Write-Host "${AppId}: Process '$processName' has been stopped"
                        $processFound = $true
                    }
                }
                catch {
                    # Process not found, continue to next
                }
            }
            
            if (-not $processFound) {
                Write-Host "${AppId}: Process is not running"
            }
        } else {
            Write-Host "Warning: No process name specified for $AppId, cannot stop process"
        }
    }
}

# Function to handle Clibor hotkey toggle (special case)
function Switch-CliborHotkey {
    param(
        [string]$Action = "toggle"  # "enable" or "disable" or "toggle"
    )
    
    if (-not $config.managedApps.clibor) {
        Write-Host "Warning: Clibor is not defined in managedApps configuration"
        return
    }
    
    $cliborConfig = $config.managedApps.clibor
    if ($cliborConfig.path -and $cliborConfig.path -ne "") {
        $arguments = if ($cliborConfig.arguments -and $cliborConfig.arguments -ne "") { $cliborConfig.arguments } else { "/hs" }
        Start-Process -FilePath $cliborConfig.path -ArgumentList $arguments
        
        $actionText = switch ($Action) {
            "enable" { "enabled" }
            "disable" { "disabled" }
            default { "toggled" }
        }
        Write-Host "Clibor hotkey has been ${actionText}"
    } else {
        Write-Host "Warning: No path specified for Clibor, cannot toggle hotkey"
    }
}

# Common cleanup process for game exit
function Invoke-GameCleanup {
    param(
        [bool]$IsInterrupted = $false
    )
    
    if ($IsInterrupted) {
        Write-Host "`nScript was interrupted. Executing rollback..."
    }
    
    # Handle Clibor hotkey (special case)
    if ("clibor" -in $gameConfig.appsToManage) {
        Switch-CliborHotkey -Action "enable"
    }
    
    # Process all managed apps for shutdown
    foreach ($appId in $gameConfig.appsToManage) {
        if ($appId -eq "obs") {
            # Special handling for OBS replay buffer
            if ($config.obs.replayBuffer) {
                $ws = Connect-OBSWebSocket -HostName $config.obs.websocket.host -Port $config.obs.websocket.port -Password $config.obs.websocket.password
                if ($ws) {
                    Stop-OBSReplayBuffer -WebSocket $ws
                    $ws.Dispose()
                }
            }
            continue
        }
        
        if ($appId -eq "clibor") {
            # Already handled above as special case
            continue
        }
        
        # Get app configuration
        if ($config.managedApps.$appId) {
            $appConfig = $config.managedApps.$appId
            $action = $appConfig.shutdownAction
            
            if ($action -eq "start") {
                Invoke-AppAction -AppId $appId -Action "start"
            }
            elseif ($action -eq "stop") {
                Invoke-AppAction -AppId $appId -Action "stop"
            }
            # If action is "none", do nothing
        }
    }
}

# Handle Ctrl+C press
trap [System.Management.Automation.PipelineStoppedException] {
    Invoke-GameCleanup -IsInterrupted $true
    exit
}

# Process all managed apps for startup
foreach ($appId in $gameConfig.appsToManage) {
    if ($appId -eq "obs") {
        # Special handling for OBS
        $obsProcessName = "obs64"
        if (!(Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath $config.paths.obs
            Write-Host "Starting OBS Studio..."
            
            # Wait for OBS startup completion
            $retryCount = 0
            $maxRetries = 10
            while (!(Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue) -and ($retryCount -lt $maxRetries)) {
                Start-Sleep -Seconds 2
                $retryCount++
            }
            
            if (Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue) {
                Write-Host "OBS Studio startup completed"
                Start-Sleep -Seconds 5  # Wait for OBS WebSocket server startup
            }
            else {
                Write-Host "Warning: Could not confirm OBS Studio startup"
            }
        }
        else {
            Write-Host "OBS Studio is already running"
        }
        
        # Control replay buffer (if configured)
        if ($config.obs.replayBuffer) {
            $ws = Connect-OBSWebSocket -HostName $config.obs.websocket.host -Port $config.obs.websocket.port -Password $config.obs.websocket.password
            if ($ws) {
                Start-OBSReplayBuffer -WebSocket $ws
                $ws.Dispose()
            }
        }
        continue
    }
    
    if ($appId -eq "clibor") {
        # Special handling for Clibor hotkey
        Switch-CliborHotkey -Action "disable"
        continue
    }
    
    # Get app configuration
    if ($config.managedApps.$appId) {
        $appConfig = $config.managedApps.$appId
        $action = $appConfig.startupAction
        
        if ($action -eq "start") {
            Invoke-AppAction -AppId $appId -Action "start"
        }
        elseif ($action -eq "stop") {
            Invoke-AppAction -AppId $appId -Action "stop"
        }
        # If action is "none", do nothing
    } else {
        Write-Host "Warning: Application '$appId' is not defined in managedApps configuration. Skipping."
    }
}

# WebSocket helper functions
function Receive-OBSWebSocketResponse {
    param (
        [System.Net.WebSockets.ClientWebSocket]$WebSocket,
        [int]$TimeoutSeconds = 5
    )
    $cts = New-Object System.Threading.CancellationTokenSource
    $cts.CancelAfter($TimeoutSeconds * 1000)
    $buffer = New-Object byte[] 8192 # 8KB buffer
    $segment = New-Object ArraySegment[byte](, $buffer)
    $resultText = ""
    
    try {
        while ($WebSocket.State -eq "Open") {
            $receiveTask = $WebSocket.ReceiveAsync($segment, $cts.Token)
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
        Write-Host "Error receiving from OBS WebSocket or timeout: $_"
        return $null
    }
}

# OBS WebSocket related functions
function Connect-OBSWebSocket {
    param (
        [string]$HostName = "localhost",
        [int]$Port = 4455,
        [string]$Password = ""
    )
    
    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter(5000) # 5 second timeout
        
        $uri = "ws://${HostName}:${Port}"
        $ws.ConnectAsync($uri, $cts.Token).Wait()
        
        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            Write-Host "Failed to connect to OBS WebSocket"
            return $null
        }

        Write-Host "Connected to OBS WebSocket. Starting handshake..."

        # Wait for Hello message (Op 0) from server
        $hello = Receive-OBSWebSocketResponse -WebSocket $ws
        if (-not $hello -or $hello.op -ne 0) {
            Write-Host "Error: Could not receive valid Hello message from server."
            $ws.Dispose()
            return $null
        }

        # Send Identify message (Op 1)
        $identifyPayload = @{
            op = 1
            d = @{
                rpcVersion = 1
            }
        }

        # If authentication is required
        if ($hello.d.authentication) {
            Write-Host "Authentication required. Generating authentication information..."
            $salt = $hello.d.authentication.salt
            $challenge = $hello.d.authentication.challenge

            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            
            # secret = base64(sha256(password + salt))
            $secretBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Password + $salt))
            $secret = [System.Convert]::ToBase64String($secretBytes)
            
            # authResponse = base64(sha256(secret + challenge))
            $authResponseBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($secret + $challenge))
            $authResponse = [System.Convert]::ToBase64String($authResponseBytes)
            
            $identifyPayload.d.authentication = $authResponse
        }

        $identifyJson = $identifyPayload | ConvertTo-Json -Depth 5
        $identifyBuffer = [System.Text.Encoding]::UTF8.GetBytes($identifyJson)
        $ws.SendAsync($identifyBuffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()

        # Wait for Identified message (Op 2) from server
        $identified = Receive-OBSWebSocketResponse -WebSocket $ws
        if (-not $identified -or $identified.op -ne 2) {
            Write-Host "Error: WebSocket authentication failed."
            $ws.Dispose()
            return $null
        }

        Write-Host "OBS WebSocket authentication successful."
        return $ws
    }
    catch {
        Write-Host "OBS WebSocket connection/authentication error: $_"
        return $null
    }
}

function Start-OBSReplayBuffer {
    param (
        [System.Net.WebSockets.ClientWebSocket]$WebSocket
    )
    try {
        $requestId = [System.Guid]::NewGuid().ToString()
        $command = @{
            op = 6 # Request
            d = @{
                requestType = "StartReplayBuffer"
                requestId = $requestId
            }
        } | ConvertTo-Json -Depth 3
        
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($command)
        $WebSocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
        
        Write-Host "Sent OBS replay buffer start request"
    }
    catch {
        Write-Host "Replay buffer start request error: $_"
    }
}

function Stop-OBSReplayBuffer {
    param (
        [System.Net.WebSockets.ClientWebSocket]$WebSocket
    )
    try {
        $requestId = [System.Guid]::NewGuid().ToString()
        $command = @{
            op = 6 # Request
            d = @{
                requestType = "StopReplayBuffer"
                requestId = $requestId
            }
        } | ConvertTo-Json -Depth 3

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($command)
        $WebSocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
        
        Write-Host "Sent OBS replay buffer stop request"
    }
    catch {
        Write-Host "Replay buffer stop request error: $_"
    }
}

# Launch game
Start-Process $config.paths.steam -ArgumentList "-applaunch $($gameConfig.steamAppId)"
Write-Host "Starting $($gameConfig.name)..."

# Wait for game process to start
while (!(Get-Process $gameConfig.processName -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 30
}
Write-Host "Monitoring $($gameConfig.name) process"

# Wait for game process to end
while (Get-Process $gameConfig.processName -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 10
}
Write-Host "$($gameConfig.name) has exited..."

# Execute cleanup processing when game exits
Invoke-GameCleanup
