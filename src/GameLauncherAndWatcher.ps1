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

# Function to toggle Clibor hotkey
function Switch-CliborHotkey {
    param(
        [string]$Action = "toggle"  # "enable" or "disable" or "toggle"
    )
    
    Start-Process -FilePath $config.paths.clibor -ArgumentList "/hs"
    
    $actionText = switch ($Action) {
        "enable" { "enabled" }
        "disable" { "disabled" }
        default { "toggled" }
    }
    Write-Host "Clibor hotkey has been ${actionText}"
}

# Common cleanup process for game exit
function Invoke-GameCleanup {
    param(
        [bool]$IsInterrupted = $false
    )
    
    if ($IsInterrupted) {
        Write-Host "`nScript was interrupted. Executing rollback..."
    }
    
    # Manage Clibor hotkey (if configured)
    if ($gameConfig.features.manageCliborHotkey) {
        Switch-CliborHotkey -Action "enable"
        Write-Host "Clibor hotkey has been enabled"
    }
    
    # Game-specific exit processing
    if ($gameConfig.features.manageWinKey) {
        $noWinKeyProcessName = (Get-Item -Path $config.paths.noWinKey).BaseName
        if (Get-Process -Name $noWinKeyProcessName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $noWinKeyProcessName -Force
            Write-Host "NoWinKey has been terminated"
        }
    }
    
    if ($gameConfig.features.manageAutoHotkey) {
        & $config.paths.autoHotkey
        Write-Host "AutoHotkey script has been launched"
    }
    
    # Stop OBS replay buffer (if configured)
    if ($gameConfig.features.manageObsReplayBuffer -and $config.obs.replayBuffer) {
        $ws = Connect-OBSWebSocket -HostName $config.obs.websocket.host -Port $config.obs.websocket.port -Password $config.obs.websocket.password
        if ($ws) {
            Stop-OBSReplayBuffer -WebSocket $ws
            $ws.Dispose()
        }
    }
}

# Handle Ctrl+C press
trap [System.Management.Automation.PipelineStoppedException] {
    Invoke-GameCleanup -IsInterrupted $true
    exit
}

# AutoHotkey management (if configured)
if ($gameConfig.features.manageAutoHotkey) {
    $autoHotkeyProcesses = @("AutoHotkeyU64", "AutoHotkey", "AutoHotkey64")
    foreach ($processName in $autoHotkeyProcesses) {
        try {
            Stop-Process -Name $processName -Force -ErrorAction Stop
            Write-Host "AutoHotkey: Process '$processName' has been stopped."
        }
        catch {
            Write-Host "AutoHotkey: Process '$processName' is not running."
        }
    }
}

if ($gameConfig.features.manageLuna) {
    try {
        Stop-Process -Name "Luna" -Force -ErrorAction Stop
        Write-Host "Luna: Process has been stopped."
    }
    catch {
        Write-Host "Luna: Process is not running."
    }
}

# Clibor hotkey management (if configured)
if ($gameConfig.features.manageCliborHotkey) {
    Switch-CliborHotkey -Action "disable"
    Write-Host "Clibor hotkey has been disabled"
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

# Start and configure OBS Studio (if configured)
if ($gameConfig.features.manageObs) {
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
    if ($gameConfig.features.manageObsReplayBuffer -and $config.obs.replayBuffer) {
        $ws = Connect-OBSWebSocket -HostName $config.obs.websocket.host -Port $config.obs.websocket.port -Password $config.obs.websocket.password
        if ($ws) {
            Start-OBSReplayBuffer -WebSocket $ws
            $ws.Dispose()
        }
    }
}

# Disable WinKey (if configured)
if ($gameConfig.features.manageWinKey) {
    Start-Process -FilePath $config.paths.noWinKey
    Write-Host "WinKey has been disabled"
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
