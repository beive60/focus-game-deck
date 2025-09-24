# Focus Game Deck - Platform Manager Module
# v1.0 Multi-Platform Support: Steam, Epic Games, Riot Client
# Design Philosophy: Lightweight, Configuration-Driven, Modular

class PlatformManager {
    [hashtable] $Platforms
    [hashtable] $Config
    [object] $Messages
    [object] $Logger
    
    PlatformManager([object] $Config, [object] $Messages, [object] $Logger = $null) {
        # Convert PSCustomObject to Hashtable if needed
        if ($Config -is [PSCustomObject]) {
            $this.Config = @{}
            $Config.PSObject.Properties | ForEach-Object {
                $this.Config[$_.Name] = $_.Value
            }
        } else {
            $this.Config = $Config
        }
        
        $this.Messages = $Messages
        $this.Logger = $Logger
        $this.Platforms = @{}
        $this.InitializePlatforms()
    }
    
    [void] InitializePlatforms() {
        # Steam Platform (existing support continued)
        $this.Platforms["steam"] = @{
            Name = "Steam"
            DetectPath = { $this.DetectSteamPath() }
            LaunchCommand = { param($gamePath, $gameId) 
                $steamPath = $this.Config.paths.steam
                if (-not $steamPath -or -not (Test-Path $steamPath)) {
                    throw "Steam executable not found at configured path: $steamPath"
                }
                Start-Process $steamPath -ArgumentList "-applaunch $gameId"
                if ($this.Logger) { $this.Logger.Info("Launched via Steam: AppID $gameId", "PLATFORM") }
            }
            GameIdProperty = "steamAppId"
            ProcessCheck = "steam"
            Required = $true
        }
        
        # Epic Games Platform (v1.0 new support)
        $this.Platforms["epic"] = @{
            Name = "Epic Games"
            DetectPath = { $this.DetectEpicPath() }
            LaunchCommand = { param($gamePath, $gameId)
                # Try multiple Epic Games Launcher launch methods
                try {
                    # Method 1: Direct executable launch (recommended)
                    if ($gamePath -and (Test-Path $gamePath)) {
                        Start-Process -FilePath $gamePath -ArgumentList "-epicapp=$gameId"
                        if ($this.Logger) { $this.Logger.Info("Launched via Epic Games executable: GameID $gameId", "PLATFORM") }
                    } else {
                        throw "Epic Games executable not found"
                    }
                } catch {
                    # Method 2: Epic Games URI (fixed version)
                    $epicUri = "com.epicgames.launcher://apps/$gameId`?action=launch`&silent=true"
                    $tempBat = "$env:TEMP\launch_epic_$gameId.bat"
                    "@echo off`nstart `"Epic Games`" `"$epicUri`"" | Out-File -FilePath $tempBat -Encoding ASCII
                    Start-Process -FilePath $tempBat -WindowStyle Hidden
                    if ($this.Logger) { $this.Logger.Info("Launched via Epic Games URI: GameID $gameId", "PLATFORM") }
                }
            }
            GameIdProperty = "epicGameId"
            ProcessCheck = "EpicGamesLauncher"
            Required = $false
        }
        
        # Riot Client Platform (v1.0 new support)
        $this.Platforms["riot"] = @{
            Name = "Riot Client"
            DetectPath = { $this.DetectRiotPath() }
            LaunchCommand = { param($gamePath, $gameId)
                $riotPath = $this.Config.paths.riot
                if (-not $riotPath -or -not (Test-Path $riotPath)) {
                    # Fallback: try auto-detection
                    $riotPath = $this.DetectRiotPath()
                    if (-not $riotPath) {
                        throw "Riot Client executable not found"
                    }
                }
                # Riot Client launch command
                Start-Process $riotPath -ArgumentList "--launch-product=$gameId --launch-patchline=live"
                if ($this.Logger) { $this.Logger.Info("Launched via Riot Client: Product $gameId", "PLATFORM") }
            }
            GameIdProperty = "riotGameId"
            ProcessCheck = "RiotClientServices"
            Required = $false
        }
    }
    
    [string] DetectSteamPath() {
        $steamPaths = @(
            "C:\Program Files (x86)\Steam\steam.exe",
            "C:\Program Files\Steam\steam.exe",
            (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamExe" -ErrorAction SilentlyContinue).SteamExe
        )
        
        foreach ($path in $steamPaths) {
            if ($path -and (Test-Path $path)) {
                return $path
            }
        }
        return $null
    }
    
    [string] DetectEpicPath() {
        # Epic Games Launcher detection logic
        $epicPaths = @(
            "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe",
            "C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe"
        )
        
        foreach ($path in $epicPaths) {
            if (Test-Path $path) {
                if ($this.Logger) { $this.Logger.Info("Epic Games Launcher detected at: $path", "PLATFORM") }
                return $path
            }
        }
        
        if ($this.Logger) { $this.Logger.Warning("Epic Games Launcher not found in standard locations", "PLATFORM") }
        return $null
    }
    
    [string] DetectEAPath() {
        $eaPaths = @(
            "C:\Program Files\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
            "C:\Program Files (x86)\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
            "C:\Program Files\EA Games\EA Desktop\EA Desktop\EADesktop.exe"
        )
        
        foreach ($path in $eaPaths) {
            if (Test-Path $path) {
                return $path
            }
        }
        return $null
    }
    
    [string] DetectRiotPath() {
        # Riot Client detection logic
        $riotPaths = @(
            "C:\Riot Games\Riot Client\RiotClientServices.exe",
            "$env:LOCALAPPDATA\Riot Games\Riot Client\RiotClientServices.exe"
        )
        
        foreach ($path in $riotPaths) {
            if (Test-Path $path) {
                if ($this.Logger) { $this.Logger.Info("Riot Client detected at: $path", "PLATFORM") }
                return $path
            }
        }
        
        if ($this.Logger) { $this.Logger.Warning("Riot Client not found in standard locations", "PLATFORM") }
        return $null
    }
    
    [hashtable] DetectAllPlatforms() {
        $detectedPlatforms = @{}
        
        foreach ($platformKey in $this.Platforms.Keys) {
            $platform = $this.Platforms[$platformKey]
            $detectedPath = & $platform.DetectPath
            
            if ($detectedPath) {
                $detectedPlatforms[$platformKey] = @{
                    Name = $platform.Name
                    Path = $detectedPath
                    Available = $true
                }
            } else {
                $detectedPlatforms[$platformKey] = @{
                    Name = $platform.Name
                    Path = $null
                    Available = $false
                }
            }
        }
        
        return $detectedPlatforms
    }
    
    [bool] IsPlatformAvailable([string] $platformKey) {
        if (-not $this.Platforms.ContainsKey($platformKey)) {
            return $false
        }
        
        $platform = $this.Platforms[$platformKey]
        $detectedPath = & $platform.DetectPath
        return $null -ne $detectedPath
    }
    
    [void] LaunchGame([string] $platformKey, [object] $gameConfig) {
        if (-not $this.Platforms.ContainsKey($platformKey)) {
            throw "Unsupported platform: $platformKey"
        }
        
        # Convert PSCustomObject to Hashtable
        if ($gameConfig -is [PSCustomObject]) {
            $configHash = @{}
            $gameConfig.PSObject.Properties | ForEach-Object {
                $configHash[$_.Name] = $_.Value
            }
            $gameConfig = $configHash
        }
        
        $platform = $this.Platforms[$platformKey]
        $gameIdProperty = $platform.GameIdProperty
        
        if (-not $gameConfig.ContainsKey($gameIdProperty)) {
            throw "Game configuration missing required field: $gameIdProperty for platform: $platformKey"
        }
        
        $gameId = $gameConfig[$gameIdProperty]
        
        if ($this.Logger) { 
            $this.Logger.Info("Launching game via $($platform.Name): $gameId", "PLATFORM") 
        }
        
        try {
            & $platform.LaunchCommand $null $gameId
        }
        catch {
            if ($this.Logger) { 
                $this.Logger.Error("Failed to launch game via $($platform.Name): $_", "PLATFORM") 
            }
            throw
        }
    }
    
    [string[]] GetSupportedPlatforms() {
        return $this.Platforms.Keys
    }
}

# Factory function for PowerShell module compatibility
function New-PlatformManager {
    param(
        [object] $Config,
        [object] $Messages,
        [object] $Logger = $null
    )
    
    return [PlatformManager]::new($Config, $Messages, $Logger)
}