# Discord RPC Client for PowerShell
# Handles Discord Rich Presence Protocol communication

# Check PowerShell version and load appropriate assemblies
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell Core/7+
    Add-Type -AssemblyName System.IO.Pipes
} else {
    # Windows PowerShell 5.1
    Add-Type -AssemblyName System.Core
}

class DiscordRPCClient {
    [System.IO.Pipes.NamedPipeClientStream] $Pipe
    [string] $ApplicationId
    [bool] $Connected
    [int] $RequestId
    [object] $Logger

    # Constructor
    DiscordRPCClient([string] $applicationId, [object] $logger = $null) {
        $this.ApplicationId = $applicationId
        $this.Connected = $false
        $this.RequestId = 0
        $this.Logger = $logger
        $this.Pipe = $null
    }

    # Connect to Discord RPC
    [bool] Connect() {
        try {
            # Try different pipe names that Discord uses
            $pipeNames = @("discord-ipc-0", "discord-ipc-1", "discord-ipc-2", "discord-ipc-3")
            
            foreach ($pipeName in $pipeNames) {
                try {
                    $this.Pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
                    $this.Pipe.Connect(5000)  # 5 second timeout
                    
                    if ($this.Pipe.IsConnected) {
                        Write-Host "Connected to Discord RPC via $pipeName"
                        $this.Connected = $true
                        
                        # Send handshake
                        $handshake = @{
                            v = 1
                            client_id = $this.ApplicationId
                        } | ConvertTo-Json -Compress
                        
                        $this.SendMessage(0, $handshake)  # Opcode 0 = Handshake
                        return $true
                    }
                }
                catch {
                    if ($this.Pipe) {
                        $this.Pipe.Dispose()
                        $this.Pipe = $null
                    }
                    continue  # Try next pipe
                }
            }
            
            Write-Host "Failed to connect to Discord RPC - Discord may not be running"
            return $false
        }
        catch {
            Write-Host "Discord RPC connection error: $_"
            return $false
        }
    }

    # Send message to Discord RPC
    [void] SendMessage([int] $opcode, [string] $payload) {
        if (-not $this.Connected -or -not $this.Pipe) {
            throw "Not connected to Discord RPC"
        }

        try {
            $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $header = [byte[]]::new(8)
            
            # Opcode (4 bytes, little endian)
            [System.BitConverter]::GetBytes($opcode).CopyTo($header, 0)
            # Length (4 bytes, little endian)
            [System.BitConverter]::GetBytes($payloadBytes.Length).CopyTo($header, 4)
            
            $this.Pipe.Write($header, 0, 8)
            $this.Pipe.Write($payloadBytes, 0, $payloadBytes.Length)
            $this.Pipe.Flush()
        }
        catch {
            Write-Host "Failed to send RPC message: $_"
            $this.Connected = $false
        }
    }

    # Set Discord status
    [bool] SetStatus([string] $status) {
        if (-not $this.Connected) {
            Write-Host "Not connected to Discord RPC"
            return $false
        }

        try {
            $this.RequestId++
            $command = @{
                cmd = "SET_ACTIVITY"
                nonce = $this.RequestId.ToString()
                args = @{
                    pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
                    activity = @{
                        state = $status
                        details = "Focus Game Deck"
                        timestamps = @{
                            start = [int64]((Get-Date) - (Get-Date "1970-01-01")).TotalSeconds
                        }
                    }
                }
            } | ConvertTo-Json -Depth 10 -Compress

            $this.SendMessage(1, $command)  # Opcode 1 = Frame
            Write-Host "Discord status set to: $status"
            return $true
        }
        catch {
            Write-Host "Failed to set Discord status: $_"
            return $false
        }
    }

    # Set Rich Presence (Advanced)
    [bool] SetRichPresence([object] $activity) {
        if (-not $this.Connected) {
            Write-Host "Not connected to Discord RPC"
            return $false
        }

        try {
            $this.RequestId++
            $command = @{
                cmd = "SET_ACTIVITY"
                nonce = $this.RequestId.ToString()
                args = @{
                    pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
                    activity = $activity
                }
            } | ConvertTo-Json -Depth 10 -Compress

            $this.SendMessage(1, $command)  # Opcode 1 = Frame
            Write-Host "Discord Rich Presence updated"
            return $true
        }
        catch {
            Write-Host "Failed to set Discord Rich Presence: $_"
            return $false
        }
    }

    # Clear Discord activity
    [bool] ClearActivity() {
        if (-not $this.Connected) {
            Write-Host "Not connected to Discord RPC"
            return $false
        }

        try {
            $this.RequestId++
            $command = @{
                cmd = "SET_ACTIVITY"
                nonce = $this.RequestId.ToString()
                args = @{
                    pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
                    activity = $null
                }
            } | ConvertTo-Json -Depth 10 -Compress

            $this.SendMessage(1, $command)  # Opcode 1 = Frame
            Write-Host "Discord activity cleared"
            return $true
        }
        catch {
            Write-Host "Failed to clear Discord activity: $_"
            return $false
        }
    }

    # Disconnect from Discord RPC
    [void] Disconnect() {
        if ($this.Pipe) {
            try {
                $this.Pipe.Close()
                $this.Pipe.Dispose()
            }
            catch {
                # Ignore errors during disconnect
            }
            $this.Pipe = $null
        }
        $this.Connected = $false
        Write-Host "Disconnected from Discord RPC"
    }
}

# Function to create RPC client
function New-DiscordRPCClient {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ApplicationId,
        
        [Parameter(Mandatory = $false)]
        [object] $Logger = $null
    )
    
    return [DiscordRPCClient]::new($ApplicationId, $Logger)
}