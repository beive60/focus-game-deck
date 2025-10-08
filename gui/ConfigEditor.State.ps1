class ConfigEditorState {
    # Properties
    [string]$ConfigPath
    [PSCustomObject]$ConfigData

    # Constructor
    ConfigEditorState([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.ConfigData = $null
    }

    # Load configuration from file
    [void] LoadConfiguration() {
        try {
            if (Test-Path $this.ConfigPath) {
                $jsonContent = Get-Content $this.ConfigPath -Raw -Encoding UTF8
                $this.ConfigData = $jsonContent | ConvertFrom-Json
                Write-Host "Loaded config from: $($this.ConfigPath)"
            } else {
                # Load from sample if config doesn't exist
                $configSamplePath = Join-Path (Split-Path $PSScriptRoot) "config/config.json.sample"
                if (Test-Path $configSamplePath) {
                    $jsonContent = Get-Content $configSamplePath -Raw -Encoding UTF8
                    $this.ConfigData = $jsonContent | ConvertFrom-Json
                    Write-Host "Loaded config from sample: $configSamplePath"
                } else {
                    throw "configNotFound"
                }
            }

            # Initialize games._order array for improved version
            $this.InitializeGameOrder()

            # Initialize managedApps._order array for improved version
            $this.InitializeAppOrder()

        } catch {
            Show-SafeMessage -MessageKey "configLoadError" -TitleKey "error" -Arguments @($_.Exception.Message) -Icon Error
            # Create default config
            $this.ConfigData = [PSCustomObject]@{
                language    = ""
                obs         = [PSCustomObject]@{
                    websocket    = [PSCustomObject]@{
                        host     = "localhost"
                        port     = 4455
                        password = ""
                    }
                    replayBuffer = $true
                }
                managedApps = [PSCustomObject]@{}
                games       = [PSCustomObject]@{}
                paths       = [PSCustomObject]@{
                    steam = ""
                    obs   = ""
                }
            }
        }
    }

    # Initialize games._order array with enhanced version structure
    [void] InitializeGameOrder() {
        try {
            if (-not $this.ConfigData.games) {
                $this.ConfigData.games = [PSCustomObject]@{}
            }

            # Check if _order exists and is valid
            if (-not $this.ConfigData.games.PSObject.Properties['_order'] -or -not $this.ConfigData.games._order) {
                Write-Host "games._order not found in config. Initializing." -ForegroundColor Yellow
                $gameIds = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                $this.ConfigData.games | Add-Member -MemberType NoteProperty -Name "_order" -Value $gameIds -Force
                Set-ConfigModified
            } else {
                # Validate existing _order against actual games
                $existingGames = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                $validGameOrder = @()

                # Keep games that exist in both _order and games
                foreach ($gameId in $this.ConfigData.games._order) {
                    if ($gameId -in $existingGames) {
                        $validGameOrder += $gameId
                    }
                }

                # Add games that exist but are not in _order
                foreach ($gameId in $existingGames) {
                    if ($gameId -notin $validGameOrder) {
                        $validGameOrder += $gameId
                    }
                }

                # Update _order if changes were made
                if ($validGameOrder.Count -ne $this.ConfigData.games._order.Count -or
                    (Compare-Object $validGameOrder $this.ConfigData.games._order)) {
                    $this.ConfigData.games._order = $validGameOrder
                    Set-ConfigModified
                }
            }
        } catch {
            Write-Error "Failed to initialize game order: $($_.Exception.Message)"
            # Fallback to simple array of existing games
            $gameIds = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
            $this.ConfigData.games | Add-Member -MemberType NoteProperty -Name "_order" -Value $gameIds -Force
        }
    }

    # Initialize managedApps._order array with enhanced version structure
    [void] InitializeAppOrder() {
        try {
            if (-not $this.ConfigData.managedApps) {
                $this.ConfigData.managedApps = [PSCustomObject]@{}
            }

            # Check if _order exists and is valid
            if (-not $this.ConfigData.managedApps.PSObject.Properties['_order'] -or -not $this.ConfigData.managedApps._order) {
                Write-Host "managedApps._order not found in config. Initializing." -ForegroundColor Yellow
                $appIds = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                $this.ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name "_order" -Value $appIds -Force
                Set-ConfigModified
            } else {
                # Validate existing _order against actual apps
                $existingApps = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                $validAppOrder = @()

                # Keep apps that exist in both _order and managedApps
                foreach ($appId in $this.ConfigData.managedApps._order) {
                    if ($appId -in $existingApps) {
                        $validAppOrder += $appId
                    }
                }

                # Add apps that exist but are not in _order
                foreach ($appId in $existingApps) {
                    if ($appId -notin $validAppOrder) {
                        $validAppOrder += $appId
                    }
                }

                # Update _order if changes were made
                if ($validAppOrder.Count -ne $this.ConfigData.managedApps._order.Count -or
                    (Compare-Object $validAppOrder $this.ConfigData.managedApps._order)) {
                    $this.ConfigData.managedApps._order = $validAppOrder
                    Set-ConfigModified
                }
            }
        } catch {
            Write-Error "Failed to initialize app order: $($_.Exception.Message)"
            # Fallback to simple array of existing apps
            $appIds = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
            $this.ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name "_order" -Value $appIds -Force
        }
    }
}
