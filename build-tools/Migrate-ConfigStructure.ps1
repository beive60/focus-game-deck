#Requires -Version 5.1

<#
.SYNOPSIS
    Migrates config.json from old structure to new integration-based structure.

.DESCRIPTION
    This script converts the configuration file structure from the old format where
    specialized integrations (OBS, Discord, VTube Studio) were in managedApps to a
    new format where they have dedicated integration sections.

    Changes made:
    - Moves obs, discord, vtubeStudio from managedApps to new integrations section
    - Updates games[].appsToManage to remove specialized apps
    - Adds games[].integrations with boolean flags (useOBS, useDiscord, useVTubeStudio)
    - Preserves all other configuration settings

.PARAMETER ConfigPath
    Path to the config.json file to migrate. Defaults to ./config/config.json

.PARAMETER BackupPath
    Path to save backup of original config. If not specified, creates backup with timestamp.

.PARAMETER Force
    Skip confirmation prompt and proceed with migration.

.EXAMPLE
    ./Migrate-ConfigStructure.ps1

.EXAMPLE
    ./Migrate-ConfigStructure.ps1 -ConfigPath "C:/custom/config.json" -Force

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ConfigPath,

    [Parameter()]
    [string]$BackupPath,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Determine script directory and project root
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Path $scriptDir -Parent

# Set default config path if not provided
if (-not $ConfigPath) {
    $ConfigPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
}

# Import required modules
$modulesPath = Join-Path -Path $projectRoot -ChildPath "src/modules"

# Helper function to load JSON with proper error handling
function Get-ConfigJson {
    param([string]$Path)


# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"
    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }

    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        return $content | ConvertFrom-Json
    } catch {
        throw "Failed to parse configuration file: $_"
    }
}

# Helper function to save JSON with proper formatting
function Save-ConfigJson {
    param(
        [Parameter(Mandatory)]
        $ConfigData,

        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $json = $ConfigData | ConvertTo-Json -Depth 10 -Compress:$false
        $json | Set-Content -Path $Path -Encoding UTF8 -NoNewline
        Write-Verbose "Configuration saved to: $Path"
    } catch {
        throw "Failed to save configuration: $_"
    }
}

# Main migration logic
function Invoke-ConfigMigration {
    param(
        [Parameter(Mandatory)]
        $Config
    )

    Write-BuildLog "Starting configuration migration..."

    # Check if already migrated
    if ($Config.PSObject.Properties.Name -contains "integrations") {
        Write-BuildLog "Configuration appears to already be migrated (integrations section exists)"
        Write-BuildLog "Skipping migration to avoid data loss"
        return $null
    }

    $migrated = $false
    $specializedApps = @("obs", "discord", "vtubeStudio")

    # Create new integrations section
    $integrations = @{}

    # Migrate specialized apps from managedApps to integrations
    if ($Config.managedApps) {
        foreach ($appName in $specializedApps) {
            if ($Config.managedApps.PSObject.Properties.Name -contains $appName) {
                Write-BuildLog "  Migrating '$appName' from managedApps to integrations..."

                # Copy the app configuration to integrations
                $integrations[$appName] = $Config.managedApps.$appName

                # Remove specialized actions (they will be controlled by checkboxes now)
                if ($integrations[$appName].PSObject.Properties.Name -contains "gameStartAction") {
                    $integrations[$appName].gameStartAction = "none"
                }
                if ($integrations[$appName].PSObject.Properties.Name -contains "gameEndAction") {
                    $integrations[$appName].gameEndAction = "none"
                }

                # Remove from managedApps
                $Config.managedApps.PSObject.Properties.Remove($appName)

                # Remove from _order if it exists
                if ($Config.managedApps._order) {
                    $Config.managedApps._order = @($Config.managedApps._order | Where-Object { $_ -ne $appName })
                }

                $migrated = $true
            }
        }
    }

    # Add integrations section to config if we migrated anything
    if ($migrated) {
        $Config | Add-Member -NotePropertyName "integrations" -NotePropertyValue ([PSCustomObject]$integrations) -Force
        Write-BuildLog "  Created 'integrations' section"
    }

    # Update games to use new integrations structure
    if ($Config.games) {
        foreach ($gameProperty in $Config.games.PSObject.Properties) {
            $gameId = $gameProperty.Name

            # Skip _order property
            if ($gameId -eq "_order") {
                continue
            }

            $game = $gameProperty.Value

            # Check if game has appsToManage
            if ($game.appsToManage) {
                # Create integrations object for this game
                $gameIntegrations = @{
                    useOBS = $game.appsToManage -contains "obs"
                    useDiscord = $game.appsToManage -contains "discord"
                    useVTubeStudio = $game.appsToManage -contains "vtubeStudio"
                }

                # Add integrations to game
                $game | Add-Member -NotePropertyName "integrations" -NotePropertyValue ([PSCustomObject]$gameIntegrations) -Force

                # Remove specialized apps from appsToManage
                $game.appsToManage = @($game.appsToManage | Where-Object { $_ -notin $specializedApps })

                Write-BuildLog "  Updated game '$gameId' with integrations"
                $migrated = $true
            }
        }
    }

    if ($migrated) {
        Write-BuildLog "Migration completed successfully!"
        return $Config
    } else {
        Write-BuildLog "No changes needed - configuration is already in correct format"
        return $null
    }
}

# Main execution
try {
    Write-Host ""
    Write-BuildLog "========================================"
    Write-BuildLog "  Config Structure Migration Tool"
    Write-BuildLog "========================================"
    Write-Host ""

    # Resolve full path
    $ConfigPath = Resolve-Path $ConfigPath -ErrorAction Stop

    Write-BuildLog "Configuration file: $ConfigPath"
    Write-Host ""

    # Load current configuration
    Write-BuildLog "Loading configuration..."
    $config = Get-ConfigJson -Path $ConfigPath

    # Create backup
    if (-not $BackupPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath = $ConfigPath -replace '\.json$', "_backup_$timestamp.json"
    }

    Write-BuildLog "Creating backup: $BackupPath"
    Copy-Item -Path $ConfigPath -Destination $BackupPath -Force
    Write-BuildLog "Backup created successfully"
    Write-Host ""

    # Confirm migration unless -Force is used
    if (-not $Force) {
        Write-BuildLog "This will migrate your configuration to the new structure."
        Write-BuildLog "A backup has been created at: $BackupPath"
        Write-Host ""
        $response = Read-Host "Do you want to proceed? (Y/N)"
        if ($response -notmatch '^[Yy]') {
            Write-BuildLog "Migration cancelled by user"
            exit 0
        }
    }

    # Perform migration
    $migratedConfig = Invoke-ConfigMigration -Config $config

    if ($migratedConfig) {
        # Save migrated configuration
        Write-Host ""
        Write-BuildLog "Saving migrated configuration..."
        Save-ConfigJson -ConfigData $migratedConfig -Path $ConfigPath

        Write-Host ""
        Write-BuildLog "========================================"
        Write-BuildLog "  Migration completed successfully!"
        Write-BuildLog "========================================"
        Write-Host ""
        Write-BuildLog "Original config backed up to:"
        Write-BuildLog "  $BackupPath"
        Write-Host ""
        Write-BuildLog "Updated config saved to:"
        Write-BuildLog "  $ConfigPath"
        Write-Host ""
    } else {
        Write-Host ""
        Write-BuildLog "No migration performed"
        Write-Host ""
    }

} catch {
    Write-Host ""
    Write-BuildLog "========================================"
    Write-BuildLog "  Migration failed!"
    Write-BuildLog "========================================"
    Write-Host ""
    Write-BuildLog "Error: $($_.Exception.Message)"
    Write-Host ""

    if ($BackupPath -and (Test-Path $BackupPath)) {
        Write-BuildLog "Your original configuration is safe at:"
        Write-BuildLog "  $BackupPath"
        Write-Host ""
    }

    exit 1
}
