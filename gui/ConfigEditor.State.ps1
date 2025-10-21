class ConfigEditorState {
    # Properties
    [string]$ConfigPath
    [PSCustomObject]$ConfigData
    [string]$OriginalConfigData

    # Additional properties for refactoring from global variables
    [System.Windows.Window]$Window
    [string]$CurrentGameId
    [string]$CurrentAppId
    [PSCustomObject]$Messages
    [string]$CurrentLanguage
    [bool]$HasUnsavedChanges

    # Constructor
    ConfigEditorState([string]$configPath) {
        Write-Host "DEBUG: ConfigEditorState constructor called with configPath: '$configPath'" -ForegroundColor Cyan

        if ([string]::IsNullOrEmpty($configPath)) {
            Write-Warning "DEBUG: ConfigPath is null or empty in constructor"
        }

        $this.ConfigPath = $configPath
        $this.ConfigData = $null
        $this.OriginalConfigData = $null

        # Initialize additional properties
        $this.Window = $null
        $this.CurrentGameId = ""
        $this.CurrentAppId = ""
        $this.Messages = $null
        $this.CurrentLanguage = "en"  # Default language
        $this.HasUnsavedChanges = $false

        Write-Host "DEBUG: ConfigEditorState constructor completed successfully" -ForegroundColor Cyan
    }

    # Load configuration from file
    [void] LoadConfiguration() {
        try {
            Write-Host "DEBUG: LoadConfiguration started. ConfigPath: '$($this.ConfigPath)'" -ForegroundColor Cyan

            if (Test-Path $this.ConfigPath) {
                $jsonContent = Get-Content $this.ConfigPath -Raw -Encoding UTF8
                $this.ConfigData = $jsonContent | ConvertFrom-Json
                Write-Host "Loaded config from: $($this.ConfigPath)"
            } else {
                Write-Host "DEBUG: Config file not found, loading from sample" -ForegroundColor Yellow
                # Load from sample if config doesn't exist
                $configSamplePath = Join-Path (Split-Path $PSScriptRoot) "config/config.json.sample"
                Write-Host "DEBUG: Sample path: '$configSamplePath'" -ForegroundColor Yellow

                if (Test-Path $configSamplePath) {
                    $jsonContent = Get-Content $configSamplePath -Raw -Encoding UTF8
                    $this.ConfigData = $jsonContent | ConvertFrom-Json
                    Write-Host "Loaded config from sample: $configSamplePath"
                } else {
                    Write-Error "DEBUG: Sample config file not found at: $configSamplePath"
                    throw "configNotFound"
                }
            }

            Write-Host "DEBUG: Config data loaded, initializing order arrays" -ForegroundColor Cyan

            # Initialize games._order array for improved version
            $this.InitializeGameOrder()

            # Initialize managedApps._order array for improved version
            $this.InitializeAppOrder()

            Write-Host "DEBUG: LoadConfiguration completed successfully" -ForegroundColor Cyan

        } catch {
            Write-Error "DEBUG: LoadConfiguration failed with error: $($_.Exception.Message)"
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
            Write-Host "DEBUG: Default config created" -ForegroundColor Yellow
        }
    }

    [void] SetModified() {
        $this.HasUnsavedChanges = $true
    }

    <#
    .SYNOPSIS
        Clears the modified flag.

    .DESCRIPTION
        Marks the configuration as not having unsaved changes.
        Useful when saving configuration or when intentionally discarding changes.
    #>
    [void] ClearModified() {
        $this.HasUnsavedChanges = $false
        Write-Verbose "Configuration marked as not modified"
    }

    [bool] TestHasUnsavedChanges() {
        return $this.HasUnsavedChanges
    }

    # Initialize games._order array with enhanced version structure
    [void] InitializeGameOrder() {
        try {
            Write-Host "DEBUG: InitializeGameOrder started" -ForegroundColor Cyan

            if (-not $this.ConfigData.games) {
                $this.ConfigData.games = [PSCustomObject]@{}
                Write-Host "DEBUG: Created empty games object" -ForegroundColor Yellow
            }

            # Check if _order exists and is valid
            if (-not $this.ConfigData.games.PSObject.Properties['_order'] -or -not $this.ConfigData.games._order) {
                Write-Host "games._order not found in config. Initializing." -ForegroundColor Yellow
                $gameIds = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                Write-Host "DEBUG: Found $($gameIds.Count) existing games" -ForegroundColor Cyan
                $this.ConfigData.games | Add-Member -MemberType NoteProperty -Name "_order" -Value $gameIds -Force
                } else {
                Write-Host "DEBUG: games._order exists, validating..." -ForegroundColor Cyan
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
                    Write-Host "DEBUG: Updating games._order with validated games" -ForegroundColor Yellow
                    $this.ConfigData.games._order = $validGameOrder
                }
            }
            Write-Host "DEBUG: InitializeGameOrder completed" -ForegroundColor Cyan
        } catch {
            Write-Error "Failed to initialize game order: $($_.Exception.Message)"
            Write-Error "DEBUG: InitializeGameOrder exception details: $($_.Exception.ToString())"
            # Fallback to simple array of existing games
            $gameIds = @($this.ConfigData.games.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
            $this.ConfigData.games | Add-Member -MemberType NoteProperty -Name "_order" -Value $gameIds -Force
        }
    }

    # Initialize managedApps._order array with enhanced version structure
    [void] InitializeAppOrder() {
        try {
            Write-Host "DEBUG: InitializeAppOrder started" -ForegroundColor Cyan

            if (-not $this.ConfigData.managedApps) {
                $this.ConfigData.managedApps = [PSCustomObject]@{}
                Write-Host "DEBUG: Created empty managedApps object" -ForegroundColor Yellow
            }

            # Check if _order exists and is valid
            if (-not $this.ConfigData.managedApps.PSObject.Properties['_order'] -or -not $this.ConfigData.managedApps._order) {
                Write-Host "managedApps._order not found in config. Initializing." -ForegroundColor Yellow
                $appIds = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
                Write-Host "DEBUG: Found $($appIds.Count) existing apps" -ForegroundColor Cyan
                $this.ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name "_order" -Value $appIds -Force
                } else {
                Write-Host "DEBUG: managedApps._order exists, validating..." -ForegroundColor Cyan
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
                    Write-Host "DEBUG: Updating managedApps._order with validated apps" -ForegroundColor Yellow
                    $this.ConfigData.managedApps._order = $validAppOrder
                }
            }
            Write-Host "DEBUG: InitializeAppOrder completed" -ForegroundColor Cyan
        } catch {
            Write-Error "Failed to initialize app order: $($_.Exception.Message)"
            Write-Error "DEBUG: InitializeAppOrder exception details: $($_.Exception.ToString())"
            # Fallback to simple array of existing apps
            $appIds = @($this.ConfigData.managedApps.PSObject.Properties.Name | Where-Object { $_ -ne '_order' })
            $this.ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name "_order" -Value $appIds -Force
        }
    }

    # Store original configuration for comparison
    [void] SaveOriginalConfig() {
        try {
            Write-Host "DEBUG: SaveOriginalConfig started" -ForegroundColor Cyan

            if ($this.ConfigData) {
                $this.OriginalConfigData = $this.ConfigData | ConvertTo-Json -Depth 10
                Write-Verbose "Original configuration saved for change tracking"
                Write-Host "DEBUG: Original config saved successfully" -ForegroundColor Cyan
            } else {
                Write-Verbose "No configuration data to save for change tracking"
                Write-Host "DEBUG: No config data to save" -ForegroundColor Yellow
                $this.OriginalConfigData = $null
            }
        } catch {
            Write-Warning "Failed to save original configuration: $($_.Exception.Message)"
            Write-Error "DEBUG: SaveOriginalConfig exception details: $($_.Exception.ToString())"
            $this.OriginalConfigData = $null
            # Don't throw - this should not cause initialization to fail
        }
    }
}
