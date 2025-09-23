param(
    [Parameter(Mandatory = $true)]
    [string]$GameId
)

# Import required modules if not already loaded
if (-not (Get-Module -Name Microsoft.PowerShell.Security)) {
    try {
        Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    }
    catch {
        # Module loading failed, but we'll try to continue
        Write-Warning "Failed to load Microsoft.PowerShell.Security module: $_"
    }
}

# Helper function for secure string conversion
function ConvertTo-SecureStringSafe {
    param(
        [string]$PlainText
    )
    
    try {
        return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    }
    catch {
        Write-Warning "ConvertTo-SecureString failed, attempting alternative method: $_"
        # Alternative: create SecureString manually
        $secureString = New-Object System.Security.SecureString
        foreach ($char in $PlainText.ToCharArray()) {
            $secureString.AppendChar($char)
        }
        $secureString.MakeReadOnly()
        return $secureString
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
        Write-Host ($msg.error_receive_websocket -f $_)
        return $null
    }
}

# OBS WebSocket related functions
function Connect-OBSWebSocket {
    param (
        [string]$HostName = "localhost",
        [int]$Port = 4455,
        [System.Security.SecureString]$Password
    )
    
    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter(5000) # 5 second timeout
        
        $uri = "ws://${HostName}:${Port}"
        $ws.ConnectAsync($uri, $cts.Token).Wait()
        
        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            Write-Host $msg.failed_connect_obs
            return $null
        }

        Write-Host $msg.connected_obs_websocket

        # Wait for Hello message (Op 0) from server
        $hello = Receive-OBSWebSocketResponse -WebSocket $ws
        if (-not $hello -or $hello.op -ne 0) {
            Write-Host $msg.error_receive_hello
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
            Write-Host $msg.auth_required
            $salt = $hello.d.authentication.salt
            $challenge = $hello.d.authentication.challenge

            $sha256 = [System.Security.Cryptography.SHA256]::Create()

            # Convert SecureString to plain text for hashing
            $plainTextPassword = ''
            if ($Password -and $Password.Length -gt 0) {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
            
            # secret = base64(sha256(password + salt))
            $secretBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plainTextPassword + $salt))
            $secret = [System.Convert]::ToBase64String($secretBytes)
            
            # authResponse = base64(sha256(secret + challenge))
            $authResponseBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($secret + $challenge))
            $authResponse = [System.Convert]::ToBase64String($authResponseBytes)
            
            $identifyPayload.d.authentication = $authResponse
        }

        $identifyJson = $identifyPayload | ConvertTo-Json -Depth 5
        $identifyBuffer = [System.Text.Encoding]::UTF8.GetBytes($identifyJson)
        $sendSegment = New-Object ArraySegment[byte](, $identifyBuffer)
        $ws.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()

        # Wait for Identified message (Op 2) from server
        $identified = Receive-OBSWebSocketResponse -WebSocket $ws
        if (-not $identified -or $identified.op -ne 2) {
            Write-Host $msg.obs_auth_failed
            $ws.Dispose()
            return $null
        }

        Write-Host $msg.obs_auth_successful
        return $ws
    }
    catch {
        Write-Host ($msg.obs_connection_error -f $_)
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
        $sendSegment = New-Object ArraySegment[byte](, $buffer)
        $WebSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
        
        Write-Host $msg.obs_replay_buffer_started
    }
    catch {
        Write-Host ($msg.replay_buffer_start_error -f $_)
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
        $sendSegment = New-Object ArraySegment[byte](, $buffer)
        $WebSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
        
        Write-Host $msg.obs_replay_buffer_stopped
    }
    catch {
        Write-Host ($msg.replay_buffer_stop_error -f $_)
    }
}

# Load configuration file
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "..\config\config.json"
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Import language helper functions
$languageHelperPath = Join-Path $scriptDir "..\scripts\LanguageHelper.ps1"
if (Test-Path $languageHelperPath) {
    . $languageHelperPath
} else {
    Write-Warning "Language helper not found: $languageHelperPath"
}

# Detect language using centralized logic
$langCode = Get-DetectedLanguage -ConfigData $config

# Set appropriate culture for the detected language
Set-CultureByLanguage -LanguageCode $langCode

# Load localized messages
$messagesPath = Join-Path $scriptDir "..\config\messages.json"
$msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    Write-Host ($msg.error_game_id_not_found -f $GameId)
    Write-Host ($msg.available_game_ids -f ($config.games.PSObject.Properties.Name -join ', '))
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
            if ($appId -eq "obs") {
                # Special case for OBS - skip validation
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
                if (-not $appConfig.PSObject.Properties.Name -contains "gameStartAction") {
                    $errors += "Application '$appId' is missing 'gameStartAction' property"
                }
                if (-not $appConfig.PSObject.Properties.Name -contains "gameEndAction") {
                    $errors += "Application '$appId' is missing 'gameEndAction' property"
                }
                
                # Validate action values
                $validActions = @("start-process", "stop-process", "toggle-hotkeys", "none")
                if ($appConfig.gameStartAction -and $appConfig.gameStartAction -notin $validActions) {
                    $errors += "Application '$appId' has invalid gameStartAction: '$($appConfig.gameStartAction)'. Valid values: $($validActions -join ', ')"
                }
                if ($appConfig.gameEndAction -and $appConfig.gameEndAction -notin $validActions) {
                    $errors += "Application '$appId' has invalid gameEndAction: '$($appConfig.gameEndAction)'. Valid values: $($validActions -join ', ')"
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
    Write-Host $msg.config_validation_failed -ForegroundColor Red
    foreach ($errorMsg in $configErrors) {
        Write-Host "  - $errorMsg" -ForegroundColor Red
    }
    exit 1
}

Write-Host $msg.config_validation_passed -ForegroundColor Green

# Function to manage generic applications
function Invoke-AppAction {
    param(
        [string]$AppId,
        [string]$Action,  # "start-process", "stop-process", "toggle-hotkeys", "none"
        [string]$SpecialMode = $null  # For backward compatibility
    )
    
    # Validate app exists in managedApps
    if (-not $config.managedApps.$AppId) {
        Write-Host ($msg.warning_app_not_defined -f $AppId)
        return
    }
    
    $appConfig = $config.managedApps.$AppId
    
    # Handle different action types
    switch ($Action) {
        "start-process" {
            if ($appConfig.path -and $appConfig.path -ne "") {
                $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") { $appConfig.arguments } else { $null }
                if ($arguments) {
                    Start-Process -FilePath $appConfig.path -ArgumentList $arguments
                } else {
                    Start-Process -FilePath $appConfig.path
                }
                Write-Host ($msg.app_started -f $AppId)
            } else {
                Write-Host ($msg.warning_no_path_specified -f $AppId)
            }
        }
        "stop-process" {
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
                            Write-Host ($msg.app_process_stopped -f $AppId, $processName)
                            $processFound = $true
                        }
                    }
                    catch {
                        # Process not found, continue to next
                    }
                }
                
                if (-not $processFound) {
                    Write-Host ($msg.app_process_not_running -f $AppId)
                }
            } else {
                Write-Host ($msg.warning_no_process_name -f $AppId)
            }
        }
        "toggle-hotkeys" {
            # Special handling for applications that need hotkey toggling (like Clibor)
            if ($appConfig.path -and $appConfig.path -ne "") {
                $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") { $appConfig.arguments } else { "/hs" }
                Start-Process -FilePath $appConfig.path -ArgumentList $arguments
                
                Write-Host ($msg.app_hotkey_toggled -f $AppId, $msg.clibor_action_toggled)
            } else {
                Write-Host ($msg.warning_no_path_specified -f $AppId)
            }
        }
        "none" {
            # Do nothing
        }
        default {
            Write-Host "Unknown action: $Action for app: $AppId"
        }
    }
}

# Common cleanup process for game exit
function Invoke-GameCleanup {
    param(
        [bool]$IsInterrupted = $false
    )
    
    if ($IsInterrupted) {
        Write-Host $msg.cleanup_initiated_interrupted
    }
    
    # Handle Clibor hotkey (using unified app action)
    if ("clibor" -in $gameConfig.appsToManage) {
        Invoke-AppAction -AppId "clibor" -Action "toggle-hotkeys"
    }
    
    # Process all managed apps for shutdown
    foreach ($appId in $gameConfig.appsToManage) {
        if ($appId -eq "obs") {
            # Special handling for OBS replay buffer
            if ($config.obs.replayBuffer) {
                $securePassword = ConvertTo-SecureStringSafe -PlainText ($config.obs.websocket.password -as [string])
                $ws = Connect-OBSWebSocket -HostName $config.obs.websocket.host -Port $config.obs.websocket.port -Password $securePassword
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
            $action = $appConfig.gameEndAction
            
            Invoke-AppAction -AppId $appId -Action $action
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
            Write-Host $msg.starting_obs
            
            # Wait for OBS startup completion
            $retryCount = 0
            $maxRetries = 10
            while (!(Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue) -and ($retryCount -lt $maxRetries)) {
                Start-Sleep -Seconds 2
                $retryCount++
            }
            
            if (Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue) {
                Write-Host $msg.obs_startup_complete
                Start-Sleep -Seconds 5  # Wait for OBS WebSocket server startup
            }
            else {
                Write-Host $msg.obs_startup_failed
            }
        }
        else {
            Write-Host $msg.obs_already_running
        }
        
        # Control replay buffer (if configured)
        if ($config.obs.replayBuffer) {
            $securePassword = ConvertTo-SecureStringSafe -PlainText ($config.obs.websocket.password -as [string])
            $ws = Connect-OBSWebSocket -HostName $config.obs.websocket.host -Port $config.obs.websocket.port -Password $securePassword
            if ($ws) {
                Start-OBSReplayBuffer -WebSocket $ws
                $ws.Dispose()
            }
        }
        continue
    }
    
    if ($appId -eq "clibor") {
        # Use unified app action for Clibor hotkey
        Invoke-AppAction -AppId "clibor" -Action "toggle-hotkeys"
        continue
    }
    
    # Get app configuration
    if ($config.managedApps.$appId) {
        $appConfig = $config.managedApps.$appId
        $action = $appConfig.gameStartAction
        
        Invoke-AppAction -AppId $appId -Action $action
    } else {
        Write-Host ($msg.warning_app_not_defined -f $appId)
    }
}

# Launch game
Start-Process $config.paths.steam -ArgumentList "-applaunch $($gameConfig.steamAppId)"
Write-Host ($msg.starting_game -f $gameConfig.name)

# Wait for game process to start
while (!(Get-Process $gameConfig.processName -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 30
}
Write-Host ($msg.monitoring_process -f $gameConfig.name)

# Wait for game process to end
while (Get-Process $gameConfig.processName -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 10
}
Write-Host ($msg.game_exited -f $gameConfig.name)

# Execute cleanup processing when game exits
Invoke-GameCleanup
