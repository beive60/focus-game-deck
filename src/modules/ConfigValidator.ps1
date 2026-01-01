# Configuration Validator Module
# Enhanced configuration validation with detailed error reporting and dependency chain validation
#
# This module validates configuration using the pure ValidationRules module and implements
# dependency chain validation - only checking what's actually needed for the game being launched.

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

    # Main validation method with dependency chain validation
    # When gameId is provided, validates only what's needed for that specific game
    [bool] ValidateConfiguration([string] $gameId = $null) {
        $this.Errors = @()
        $this.Warnings = @()

        # Validate basic structure
        $this.ValidateBasicStructure()

        if ($gameId) {
            # Dependency Chain Validation: Only validate what this game needs
            $this.ValidateGameWithDependencies($gameId)
        } else {
            # Full validation mode (when no specific game is provided)
            $this.ValidateAllPaths()
            $this.ValidateAllManagedApps()
            $this.ValidateAllIntegrations()
        }

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

    # Dependency Chain Validation: Validate a game and all its dependencies
    [void] ValidateGameWithDependencies([string] $gameId) {
        if (-not $this.Config.games.$gameId) {
            $this.Errors += "Game ID '$gameId' not found in configuration"
            return
        }

        $gameConfig = $this.Config.games.$gameId

        # 1. Validate the game configuration itself
        $this.ValidateGameConfiguration($gameId)

        # 2. Validate only the platform used by this game
        $platform = if ($gameConfig.platform) { $gameConfig.platform } else { "steam" }
        $this.ValidatePlatformForGame($platform)

        # 3. Validate only the managed apps referenced by this game
        if ($gameConfig.appsToManage) {
            foreach ($appId in $gameConfig.appsToManage) {
                if ($appId -eq "obs") {
                    continue  # OBS is handled specially in integrations
                }
                $this.ValidateManagedApp($appId)
            }
        }

        # 4. Validate only the integrations used by this game
        if ($gameConfig.integrations) {
            if ($gameConfig.integrations.useOBS) {
                $this.ValidateOBSConfiguration()
            }
            if ($gameConfig.integrations.useDiscord) {
                $this.ValidateDiscordConfiguration()
            }
            if ($gameConfig.integrations.useVTubeStudio) {
                $this.ValidateVTubeStudioConfiguration()
            }
        }

        # Also check if OBS is in appsToManage
        if ($gameConfig.appsToManage -and "obs" -in $gameConfig.appsToManage) {
            $this.ValidateOBSConfiguration()
        }
    }

    # Validate platform-specific path for a given platform
    [void] ValidatePlatformForGame([string] $platform) {
        if (-not $this.Config.paths) {
            $this.Errors += "Missing 'paths' section in configuration"
            return
        }

        switch ($platform) {
            "steam" {
                if (-not $this.Config.paths.steam) {
                    $this.Errors += "Steam path is required in 'paths.steam' for Steam platform"
                } elseif (-not (Test-Path $this.Config.paths.steam)) {
                    $this.Errors += "Steam path does not exist: '$($this.Config.paths.steam)'"
                }
            }
            "epic" {
                if (-not $this.Config.paths.epic) {
                    $this.Warnings += "Epic platform path not configured in 'paths.epic' - will attempt auto-detection"
                } elseif (-not (Test-Path $this.Config.paths.epic)) {
                    $this.Warnings += "Epic path does not exist: '$($this.Config.paths.epic)' - will attempt auto-detection"
                }
            }
            "riot" {
                if (-not $this.Config.paths.riot) {
                    $this.Warnings += "Riot platform path not configured in 'paths.riot' - will attempt auto-detection"
                } elseif (-not (Test-Path $this.Config.paths.riot)) {
                    $this.Warnings += "Riot path does not exist: '$($this.Config.paths.riot)' - will attempt auto-detection"
                }
            }
            { $_ -in "standalone", "direct" } {
                # For standalone/direct, executable path is part of game config, already validated
            }
        }
    }

    # Validate a single managed application
    [void] ValidateManagedApp([string] $appId) {
        if (-not $this.Config.managedApps.$appId) {
            $this.Errors += "Game references undefined application: '$appId'"
            return
        }

        $appConfig = $this.Config.managedApps.$appId
        $validActions = @("start-process", "stop-process", "none")

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

    # Full validation methods (used when no specific game is provided)
    
    [void] ValidateAllPaths() {
        if (-not $this.Config.paths) {
            return
        }

        # Validate Steam path (always required as default platform)
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

    [void] ValidateAllManagedApps() {
        if (-not $this.Config.managedApps) {
            return
        }

        $validActions = @("start-process", "stop-process", "none")

        foreach ($appProperty in $this.Config.managedApps.PSObject.Properties) {
            $appId = $appProperty.Name
            if ($appId -eq '_order') { continue }  # Skip order metadata
            
            $this.ValidateManagedApp($appId)
        }
    }

    [void] ValidateAllIntegrations() {
        # Check if any game uses integrations
        $this.ValidateOBSConfiguration()
        $this.ValidateDiscordConfiguration()
        $this.ValidateVTubeStudioConfiguration()
    }

    # Validate specific game configuration (using ValidationRules module)
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

        # Determine platform (default to Steam)
        $platform = if ($gameConfig.platform) { $gameConfig.platform } else { "steam" }

        # Use ValidationRules module for format validation
        $validationParams = @{
            GameId = $gameId
            Platform = $platform
        }

        # Add platform-specific parameters
        switch ($platform) {
            "steam" {
                $validationParams['SteamAppId'] = if ($gameConfig.steamAppId) { $gameConfig.steamAppId } else { "" }
            }
            "epic" {
                $validationParams['EpicGameId'] = if ($gameConfig.epicGameId) { $gameConfig.epicGameId } else { "" }
            }
            "riot" {
                $validationParams['RiotGameId'] = if ($gameConfig.riotGameId) { $gameConfig.riotGameId } else { "" }
            }
            { $_ -in "standalone", "direct" } {
                $validationParams['ExecutablePath'] = if ($gameConfig.executablePath) { $gameConfig.executablePath } else { "" }
            }
        }

        # Perform validation using ValidationRules
        $result = Test-GameConfiguration @validationParams
        
        # Add any validation errors to our error list
        foreach ($error in $result.Errors) {
            # Convert control-based errors to human-readable messages
            $errorMsg = switch ($error.Key) {
                'gameIdRequired' { "Game '$gameId' has empty Game ID" }
                'gameIdInvalidCharacters' { "Game '$gameId' has invalid characters in Game ID" }
                'steamAppIdRequired' { "Game '$gameId' requires Steam AppID" }
                'steamAppIdMust7Digits' { "Game '$gameId' has invalid Steam AppID format (must be 7 digits)" }
                'epicGameIdRequired' { "Game '$gameId' requires Epic Game ID" }
                'epicGameIdInvalidFormat' { "Game '$gameId' has invalid Epic Game ID format" }
                'riotGameIdRequired' { "Game '$gameId' requires Riot Game ID" }
                'executablePathRequired' { "Game '$gameId' requires executable path" }
                'executablePathNotFound' { "Game '$gameId' executable path does not exist: '$($gameConfig.executablePath)'" }
                default { "Game '$gameId' validation error: $($error.Key)" }
            }
            $this.Errors += $errorMsg
        }

        # Validate appsToManage references
        if ($gameConfig.appsToManage) {
            foreach ($appId in $gameConfig.appsToManage) {
                if ($appId -eq "obs") {
                    # OBS is handled specially, skip validation here
                    continue
                }

                if (-not $this.Config.managedApps.$appId) {
                    $this.Errors += "Game '$gameId' references undefined application: '$appId'"
                }
            }
        } else {
            $this.Warnings += "Game '$gameId' has no applications to manage (appsToManage is empty)"
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

        # Validate gameStartAction and gameEndAction
        $validIntegrationActions = @("enter-game-mode", "exit-game-mode", "none")

        if ($this.Config.integrations.obs.gameStartAction) {
            if ($this.Config.integrations.obs.gameStartAction -notin $validIntegrationActions) {
                $this.Errors += "OBS has invalid gameStartAction: '$($this.Config.integrations.obs.gameStartAction)'. Valid values: $($validIntegrationActions -join ', ')"
            }
        }

        if ($this.Config.integrations.obs.gameEndAction) {
            if ($this.Config.integrations.obs.gameEndAction -notin $validIntegrationActions) {
                $this.Errors += "OBS has invalid gameEndAction: '$($this.Config.integrations.obs.gameEndAction)'. Valid values: $($validIntegrationActions -join ', ')"
            }
        }
    }

    # Validate Discord configuration
    [void] ValidateDiscordConfiguration() {
        # Check if any game uses Discord
        $discordUsed = $false
        if ($this.Config.games) {
            foreach ($gameProperty in $this.Config.games.PSObject.Properties) {
                $gameConfig = $gameProperty.Value
                if ($gameConfig.integrations -and $gameConfig.integrations.useDiscord) {
                    $discordUsed = $true
                    break
                }
            }
        }

        if (-not $discordUsed) {
            return
        }

        # Validate Discord integration exists
        if (-not $this.Config.integrations.discord) {
            $this.Errors += "Discord is used but 'integrations.discord' configuration section is missing"
            return
        }

        # Validate Discord path
        if (-not $this.Config.integrations.discord.path) {
            $this.Warnings += "Discord path not configured in 'integrations.discord.path' - will attempt auto-detection"
        }

        # Validate gameStartAction and gameEndAction
        $validIntegrationActions = @("enter-game-mode", "exit-game-mode", "none")

        if ($this.Config.integrations.discord.gameStartAction) {
            if ($this.Config.integrations.discord.gameStartAction -notin $validIntegrationActions) {
                $this.Errors += "Discord has invalid gameStartAction: '$($this.Config.integrations.discord.gameStartAction)'. Valid values: $($validIntegrationActions -join ', ')"
            }
        }

        if ($this.Config.integrations.discord.gameEndAction) {
            if ($this.Config.integrations.discord.gameEndAction -notin $validIntegrationActions) {
                $this.Errors += "Discord has invalid gameEndAction: '$($this.Config.integrations.discord.gameEndAction)'. Valid values: $($validIntegrationActions -join ', ')"
            }
        }
    }

    # Validate VTube Studio configuration
    [void] ValidateVTubeStudioConfiguration() {
        # Check if any game uses VTube Studio
        $vtubeUsed = $false
        if ($this.Config.games) {
            foreach ($gameProperty in $this.Config.games.PSObject.Properties) {
                $gameConfig = $gameProperty.Value
                if ($gameConfig.integrations -and $gameConfig.integrations.useVTubeStudio) {
                    $vtubeUsed = $true
                    break
                }
            }
        }

        if (-not $vtubeUsed) {
            return
        }

        # Validate VTube Studio integration exists
        if (-not $this.Config.integrations.vtubeStudio) {
            $this.Errors += "VTube Studio is used but 'integrations.vtubeStudio' configuration section is missing"
            return
        }

        # Validate VTube Studio path
        if (-not $this.Config.integrations.vtubeStudio.path) {
            $this.Warnings += "VTube Studio path not configured in 'integrations.vtubeStudio.path' - will attempt auto-detection"
        }

        # Validate gameStartAction and gameEndAction
        $validIntegrationActions = @("enter-game-mode", "exit-game-mode", "none")

        if ($this.Config.integrations.vtubeStudio.gameStartAction) {
            if ($this.Config.integrations.vtubeStudio.gameStartAction -notin $validIntegrationActions) {
                $this.Errors += "VTube Studio has invalid gameStartAction: '$($this.Config.integrations.vtubeStudio.gameStartAction)'. Valid values: $($validIntegrationActions -join ', ')"
            }
        }

        if ($this.Config.integrations.vtubeStudio.gameEndAction) {
            if ($this.Config.integrations.vtubeStudio.gameEndAction -notin $validIntegrationActions) {
                $this.Errors += "VTube Studio has invalid gameEndAction: '$($this.Config.integrations.vtubeStudio.gameEndAction)'. Valid values: $($validIntegrationActions -join ', ')"
            }
        }
    }

    # Get validation report
    [hashtable] GetValidationReport() {
        return @{
            IsValid = ($this.Errors.Count -eq 0)
            ErrorCount = $this.Errors.Count
            WarningCount = $this.Warnings.Count
            Errors = $this.Errors
            Warnings = $this.Warnings
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
                    "C:/Program Files (x86)/Steam/steam.exe",
                    "C:/Program Files/Steam/steam.exe"
                )
                RegistryPath = "HKCU:/Software/Valve/Steam"
                RegistryValue = "SteamExe"
            }
            "epic" = @{
                Paths = @(
                    "C:/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe",
                    "C:/Program Files/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
                )
            }
            "ea" = @{
                Paths = @(
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
            Write-Host "[OK] ConfigValidator: $($this.Messages.config_validation_passed)"
            return
        }

        if ($this.Errors.Count -gt 0) {
            Write-Host "[ERROR] ConfigValidator: $($this.Messages.config_validation_failed)"
            foreach ($errorMsg in $this.Errors) {
                Write-Host "[ERROR] ConfigValidator: $errorMsg"
            }
        }

        if ($this.Warnings.Count -gt 0) {
            foreach ($warning in $this.Warnings) {
                Write-Host "[WARN] ConfigValidator: $warning"
            }
        }

        if ($this.Errors.Count -eq 0) {
            Write-Host "[OK] ConfigValidator: $($this.Messages.config_validation_passed)"
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
