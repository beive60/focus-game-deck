# ConfigValidator update for multi-platform support
# This is an extension to the existing ConfigValidator.ps1

# Add this method to the ConfigValidator class

[void] ValidateMultiPlatformGameConfiguration([string] $gameId) {
    if (-not $this.Config.games.$gameId) {
        $this.Errors += "Game ID '$gameId' not found in configuration"
        return
    }

    $gameConfig = $this.Config.games.$gameId

    # Validate required game properties
    $requiredGameProperties = @("name", "processName", "platform")
    foreach ($property in $requiredGameProperties) {
        if (-not $gameConfig.$property -or $gameConfig.$property -eq "") {
            $this.Errors += "Game '$gameId' missing required property: '$property'"
        }
    }

    # Validate platform-specific requirements
    $platform = $gameConfig.platform
    if ($platform) {
        switch ($platform) {
            "steam" {
                if (-not $gameConfig.steamAppId) {
                    $this.Errors += "Game '$gameId' with Steam platform requires 'steamAppId' property"
                }
                if (-not $this.Config.paths.steam) {
                    $this.Errors += "Steam platform requires 'paths.steam' configuration"
                }
            }
            "epic" {
                if (-not $gameConfig.epicGameId) {
                    $this.Errors += "Game '$gameId' with Epic platform requires 'epicGameId' property"
                }
                if (-not $this.Config.paths.epic) {
                    $this.Warnings += "Epic platform path not configured in 'paths.epic' - will attempt auto-detection"
                }
            }
            "ea" {
                if (-not $gameConfig.eaGameId) {
                    $this.Errors += "Game '$gameId' with EA platform requires 'eaGameId' property"
                }
                if (-not $this.Config.paths.ea) {
                    $this.Warnings += "EA platform path not configured in 'paths.ea' - will attempt auto-detection"
                }
            }
            "riot" {
                if (-not $gameConfig.riotGameId) {
                    $this.Errors += "Game '$gameId' with Riot platform requires 'riotGameId' property"
                }
                if (-not $this.Config.paths.riot) {
                    $this.Warnings += "Riot platform path not configured in 'paths.riot' - will attempt auto-detection"
                }
            }
            "direct" {
                if (-not $gameConfig.executablePath) {
                    $this.Errors += "Game '$gameId' with direct platform requires 'executablePath' property"
                } elseif (-not (Test-Path $gameConfig.executablePath)) {
                    $this.Errors += "Game '$gameId' executable path does not exist: '$($gameConfig.executablePath)'"
                }
            }
            default {
                $this.Errors += "Game '$gameId' has unsupported platform: '$platform'"
            }
        }
    } else {
        # Backward compatibility: assume Steam if no platform specified
        if (-not $gameConfig.steamAppId) {
            $this.Warnings += "Game '$gameId' has no platform specified and no steamAppId - assuming Steam platform"
        }
    }

    # Validate appsToManage references
    if ($gameConfig.appsToManage) {
        foreach ($appId in $gameConfig.appsToManage) {
            if ($appId -notin @("obs", "clibor") -and -not $this.Config.managedApps.$appId) {
                $this.Errors += "Game '$gameId' references undefined managed app: '$appId'"
            }
        }
    }
}

# Platform detection validation method
[hashtable] ValidatePlatformAvailability() {
    $platformResults = @{
        Available = @()
        Unavailable = @()
        Errors = @()
    }
    
    # Platform detection paths
    $platformChecks = @{
        "steam" = @{
            Paths = @(
                "C:\Program Files (x86)\Steam\steam.exe",
                "C:\Program Files\Steam\steam.exe"
            )
            RegistryPath = "HKCU:\Software\Valve\Steam"
            RegistryValue = "SteamExe"
        }
        "epic" = @{
            Paths = @(
                "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe",
                "C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe"
            )
        }
        "ea" = @{
            Paths = @(
                "C:\Program Files\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
                "C:\Program Files (x86)\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe"
            )
        }
        "riot" = @{
            Paths = @(
                "C:\Riot Games\Riot Client\RiotClientServices.exe",
                "$env:LOCALAPPDATA\Riot Games\Riot Client\RiotClientServices.exe"
            )
        }
    }
    
    foreach ($platformKey in $platformChecks.Keys) {
        $check = $platformChecks[$platformKey]
        $found = $false
        
        # Check standard paths
        foreach ($path in $check.Paths) {
            if ($path -and (Test-Path $path)) {
                $platformResults.Available += @{
                    Platform = $platformKey
                    Path = $path
                    Method = "File System"
                }
                $found = $true
                break
            }
        }
        
        # Check registry if available and not found yet
        if (-not $found -and $check.RegistryPath) {
            try {
                $regValue = Get-ItemProperty -Path $check.RegistryPath -Name $check.RegistryValue -ErrorAction SilentlyContinue
                if ($regValue -and $regValue.($check.RegistryValue) -and (Test-Path $regValue.($check.RegistryValue))) {
                    $platformResults.Available += @{
                        Platform = $platformKey
                        Path = $regValue.($check.RegistryValue)
                        Method = "Registry"
                    }
                    $found = $true
                }
            }
            catch {
                # Registry check failed, but continue
            }
        }
        
        if (-not $found) {
            $platformResults.Unavailable += $platformKey
        }
    }
    
    return $platformResults
}