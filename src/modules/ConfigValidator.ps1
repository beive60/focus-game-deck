# Configuration Validator Module
# Enhanced configuration validation with detailed error reporting

class ConfigValidator {
    [object] $Config
    [object] $Messages
    [array] $Errors
    [array] $Warnings

    # Constructor
    ConfigValidator([object] $config, [object] $messages) {
        $this.Config = $config
        $this.Messages = $messages
        $this.Errors = @()
        $this.Warnings = @()
    }

    # Main validation method
    [bool] ValidateConfiguration([string] $gameId = $null) {
        $this.Errors = @()
        $this.Warnings = @()

        # Validate basic structure
        $this.ValidateBasicStructure()

        # Validate paths
        $this.ValidatePaths()

        # Validate managed apps
        $this.ValidateManagedApps()

        # Validate specific game if provided
        if ($gameId) {
            $this.ValidateGameConfiguration($gameId)
        }

        # Validate OBS configuration if OBS is used
        $this.ValidateOBSConfiguration()

        # Return true if no errors (warnings are acceptable)
        return $this.Errors.Count -eq 0
    }

    # Validate basic configuration structure
    [void] ValidateBasicStructure() {
        # Check required top-level sections
        $requiredSections = @("games", "managedApps", "paths")

        foreach ($section in $requiredSections) {
            if (-not $this.Config.$section) {
                $this.Errors += "Missing required section: '$section'"
            }
        }

        # Check if games section has at least one game
        if ($this.Config.games -and $this.Config.games.PSObject.Properties.Count -eq 0) {
            $this.Warnings += "No games configured in 'games' section"
        }

        # Check if managedApps section has at least one app
        if ($this.Config.managedApps -and $this.Config.managedApps.PSObject.Properties.Count -eq 0) {
            $this.Warnings += "No applications configured in 'managedApps' section"
        }
    }

    # Validate paths configuration
    [void] ValidatePaths() {
        if (-not $this.Config.paths) {
            return
        }

        # Validate Steam path
        if ($this.Config.paths.steam) {
            if (-not (Test-Path $this.Config.paths.steam)) {
                $this.Errors += "Steam path does not exist: '$($this.Config.paths.steam)'"
            }
        } else {
            $this.Errors += "Steam path is required in 'paths.steam'"
        }

        # Validate OBS path if present (now in integrations.obs.path)
        if ($this.Config.integrations.obs.path) {
            if (-not (Test-Path $this.Config.integrations.obs.path)) {
                $this.Warnings += "OBS path does not exist: '$($this.Config.integrations.obs.path)'"
            }
        }
    }

    # Validate managed applications
    [void] ValidateManagedApps() {
        if (-not $this.Config.managedApps) {
            return
        }

        $validActions = @("start-process", "stop-process", "none")

        foreach ($appProperty in $this.Config.managedApps.PSObject.Properties) {
            $appId = $appProperty.Name
            $appConfig = $appProperty.Value

            # Validate required properties
            if (-not $appConfig.PSObject.Properties.Name -contains "processName") {
                $this.Errors += "Application '$appId' is missing 'processName' property"
            }

            if (-not $appConfig.PSObject.Properties.Name -contains "gameStartAction") {
                $this.Errors += "Application '$appId' is missing 'gameStartAction' property"
            }

            if (-not $appConfig.PSObject.Properties.Name -contains "gameEndAction") {
                $this.Errors += "Application '$appId' is missing 'gameEndAction' property"
            }

            # Validate action values
            if ($appConfig.gameStartAction -and $appConfig.gameStartAction -notin $validActions) {
                $this.Errors += "Application '$appId' has invalid gameStartAction: '$($appConfig.gameStartAction)'. Valid values: $($validActions -join ', ')"
            }

            if ($appConfig.gameEndAction -and $appConfig.gameEndAction -notin $validActions) {
                $this.Errors += "Application '$appId' has invalid gameEndAction: '$($appConfig.gameEndAction)'. Valid values: $($validActions -join ', ')"
            }

            # Validate path if needed for start-process action
            $needsPath = @("start-process")
            if (($appConfig.gameStartAction -in $needsPath) -or ($appConfig.gameEndAction -in $needsPath)) {
                if (-not $appConfig.path -or $appConfig.path -eq "") {
                    $this.Errors += "Application '$appId' requires 'path' property for its configured actions"
                } elseif (-not (Test-Path $appConfig.path)) {
                    $this.Warnings += "Application '$appId' path does not exist: '$($appConfig.path)'"
                }
            }

            # Validate process name if needed for stop-process action
            if (($appConfig.gameStartAction -eq "stop-process") -or ($appConfig.gameEndAction -eq "stop-process")) {
                if (-not $appConfig.processName -or $appConfig.processName -eq "") {
                    $this.Errors += "Application '$appId' requires 'processName' property for stop-process action"
                }
            }
        }
    }

    # Validate specific game configuration (Multi-Platform Support)
    [void] ValidateGameConfiguration([string] $gameId) {
        if (-not $this.Config.games.$gameId) {
            $this.Errors += "Game ID '$gameId' not found in configuration"
            return
        }

        $gameConfig = $this.Config.games.$gameId

        # Validate basic required properties
        $basicRequiredProperties = @("name", "processName")
        foreach ($prop in $basicRequiredProperties) {
            if (-not $gameConfig.PSObject.Properties.Name -contains $prop) {
                $this.Errors += "Game '$gameId' is missing required property: '$prop'"
            }
        }

        # Validate platform-specific requirements (Multi-Platform Support)
        $platform = if ($gameConfig.platform) { $gameConfig.platform } else { "steam" }  # Default to Steam

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
                $this.Errors += "Game '$gameId' has unsupported platform: '$platform'. Supported platforms: steam, epic, ea, riot, direct"
            }
        }

        # Validate appsToManage
        if (-not $gameConfig.appsToManage) {
            $this.Warnings += "Game '$gameId' has no applications to manage (appsToManage is empty)"
        } else {
            foreach ($appId in $gameConfig.appsToManage) {
                if ($appId -eq "obs") {
                    # OBS is handled specially, skip validation here
                    continue
                }

                if (-not $this.Config.managedApps.$appId) {
                    $this.Errors += "Game '$gameId' references undefined application: '$appId'"
                }
            }
        }
    }

    # Validate OBS configuration
    [void] ValidateOBSConfiguration() {
        # Check if any game uses OBS
        $obsUsed = $false
        if ($this.Config.games) {
            foreach ($gameProperty in $this.Config.games.PSObject.Properties) {
                $gameConfig = $gameProperty.Value
                if ($gameConfig.appsToManage -and "obs" -in $gameConfig.appsToManage) {
                    $obsUsed = $true
                    break
                }
            }
        }

        if (-not $obsUsed) {
            return
        }

        # Validate OBS integration exists
        if (-not $this.Config.integrations.obs) {
            $this.Errors += "OBS is used but 'integrations.obs' configuration section is missing"
            return
        }

        # Validate OBS path
        if (-not $this.Config.integrations.obs.path) {
            $this.Errors += "OBS is used but 'integrations.obs.path' is not configured"
        }

        # Validate WebSocket configuration
        if (-not $this.Config.integrations.obs.websocket) {
            $this.Errors += "OBS WebSocket configuration is missing"
        } else {
            if (-not $this.Config.integrations.obs.websocket.host) {
                $this.Warnings += "OBS WebSocket host not specified, using default 'localhost'"
            }

            if (-not $this.Config.integrations.obs.websocket.port) {
                $this.Warnings += "OBS WebSocket port not specified, using default 4455"
            }
        }

        # Validate replay buffer setting
        if ($this.Config.integrations.obs.PSObject.Properties.Name -contains "replayBuffer") {
            if ($this.Config.integrations.obs.replayBuffer -isnot [bool]) {
                $this.Warnings += "OBS replayBuffer should be a boolean value (true/false)"
            }
        }
    }

    # Get validation report
    [hashtable] GetValidationReport() {
        return @{
            IsValid      = ($this.Errors.Count -eq 0)
            ErrorCount   = $this.Errors.Count
            WarningCount = $this.Warnings.Count
            Errors       = $this.Errors
            Warnings     = $this.Warnings
        }
    }

    # Platform detection validation method
    [hashtable] ValidatePlatformAvailability() {
        $platformResults = @{
            Available   = @()
            Unavailable = @()
            Errors      = @()
        }

        # Platform detection paths
        $platformChecks = @{
            "steam" = @{
                Paths         = @(
                    "C:/Program Files (x86)/Steam/steam.exe",
                    "C:/Program Files/Steam/steam.exe"
                )
                RegistryPath  = "HKCU:/Software/Valve/Steam"
                RegistryValue = "SteamExe"
            }
            "epic"  = @{
                Paths = @(
                    "C:/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe",
                    "C:/Program Files/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
                )
            }
            "ea"    = @{
                Paths = @(
                    "C:/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe",
                    "C:/Program Files (x86)/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe"
                )
            }
            "riot"  = @{
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
                        Path     = $path
                        Method   = "File System"
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
                            Path     = $regValue.($check.RegistryValue)
                            Method   = "Registry"
                        }
                        $found = $true
                    }
                } catch {
                    # Registry check failed, but continue
                }
            }

            if (-not $found) {
                $platformResults.Unavailable += $platformKey
            }
        }

        return $platformResults
    }

    # Display validation results
    [void] DisplayResults() {
        if ($this.Errors.Count -eq 0 -and $this.Warnings.Count -eq 0) {
            Write-Host $this.Messages.config_validation_passed
            return
        }

        if ($this.Errors.Count -gt 0) {
            Write-Host $this.Messages.config_validation_failed
            foreach ($errorMsg in $this.Errors) {
                Write-Host "  ERROR: $errorMsg"
            }
        }

        if ($this.Warnings.Count -gt 0) {
            Write-Host "Configuration Warnings:"
            foreach ($warning in $this.Warnings) {
                Write-Host "  WARNING: $warning"
            }
        }

        if ($this.Errors.Count -eq 0) {
            Write-Host "Configuration is valid (with warnings)"
        }
    }
}

# Public function for configuration validation
function New-ConfigValidator {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,

        [Parameter(Mandatory = $true)]
        [object] $Messages
    )

    return [ConfigValidator]::new($Config, $Messages)
}

# Convenience function for quick validation
function Test-FocusGameDeckConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,

        [Parameter(Mandatory = $true)]
        [object] $Messages,

        [string] $GameId = $null
    )

    $validator = New-ConfigValidator -Config $Config -Messages $Messages
    $validator.ValidateConfiguration($GameId) | Out-Null
    $validator.DisplayResults()

    return $validator.GetValidationReport()
}

# Functions are available via dot-sourcing
