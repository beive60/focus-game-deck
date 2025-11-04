# Focus Game Deck - Unified Main Entry Point
# PowerShell script that serves as the single entry point for all Focus Game Deck functionality
#
# Usage:
#   Focus-Game-Deck.exe                    # Launch GUI configuration editor
#   Focus-Game-Deck.exe --config          # Launch GUI configuration editor (explicit)
#   Focus-Game-Deck.exe <GameId>          # Launch specific game
#   Focus-Game-Deck.exe --list           # List available games
#   Focus-Game-Deck.exe --help           # Show help information
#
# Author: GitHub Copilot Assistant
# Version: 2.0.0 - Unified Architecture with Enhanced UX
# Date: 2025-10-01

param(
    [Parameter(Position = 0)]
    [string]$GameId = "",

    [switch]$Config,        # Force launch configuration editor
    [switch]$List,          # List available games
    [switch]$Help,          # Show help information
    [switch]$Version        # Show version information
)

#Requires -Version 5.1

# Initialize script variables
# Handle both script execution and compiled executable scenarios
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$executableDir = if ($MyInvocation.MyCommand.Path -like "*.exe") { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $scriptDir }

# For compiled executable, use config files from the same directory or subdirectories
if ($MyInvocation.MyCommand.Path -like "*.exe") {
    $configPath = Join-Path $executableDir "config/config.json"
    $languageHelperPath = Join-Path $executableDir "scripts/LanguageHelper.ps1"
    $messagesPath = Join-Path $executableDir "gui/messages.json"
    $gameLauncherPath = Join-Path $executableDir "Invoke-FocusGameDeck.ps1"
    $configEditorPath = Join-Path $executableDir "gui/ConfigEditor.ps1"
    $versionScriptPath = Join-Path $executableDir "Version.ps1"
} else {
    # Original paths for script execution
    $configPath = Join-Path $scriptDir "../config/config.json"
    $languageHelperPath = Join-Path $scriptDir "../scripts/LanguageHelper.ps1"
    $messagesPath = Join-Path $scriptDir "../localization/messages.json"
    $gameLauncherPath = Join-Path $scriptDir "Invoke-FocusGameDeck.ps1"
    $configEditorPath = Join-Path $scriptDir "../gui/ConfigEditor.ps1"
    $versionScriptPath = Join-Path $scriptDir "../Version.ps1"
}

# Import required modules if not already loaded
if (-not (Get-Module -Name Microsoft.PowerShell.Security)) {
    try {
        Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to load Microsoft.PowerShell.Security module: $_"
    }
}

# Import version helper if available
if (Test-Path $versionScriptPath) {
    try {
        . $versionScriptPath
    } catch {
        Write-Warning "Failed to load version script: $_"
    }
}

# Import language helper functions
if (Test-Path $languageHelperPath) {
    try {
        . $languageHelperPath
    } catch {
        Write-Warning "Failed to load language helper: $_"
    }
} else {
    Write-Warning "Language helper not found: $languageHelperPath"
    # Provide fallback functions for basic operation
    function Get-DetectedLanguage { param($ConfigData) return "en" }
    function Get-LocalizedMessages { param($MessagesPath, $LanguageCode) return $null }
}

<#
.SYNOPSIS
    Shows help information for Focus Game Deck

.DESCRIPTION
    Displays usage information, available commands, and examples for the
    Focus Game Deck application in the user's preferred language.
#>
function Show-Help {
    param()

    try {
        # Try to load messages for help display
        $config = Get-Content -Path $configPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        $langCode = if ($config) { Get-DetectedLanguage -ConfigData $config } else { "en" }
        $msg = if (Test-Path $messagesPath) { Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode } else { $null }

        # Get version info if available
        $versionInfo = if (Get-Command "Get-ProjectVersionInfo" -ErrorAction SilentlyContinue) {
            Get-ProjectVersionInfo
        } else {
            @{ FullVersion = "Unknown" }
        }

        Write-Host ""
        Write-Host "Focus Game Deck v$($versionInfo.FullVersion)" -ForegroundColor Cyan
        Write-Host "==================================" -ForegroundColor Cyan
        Write-Host ""

        if ($msg -and $msg.help_description) {
            Write-Host $msg.help_description
        } else {
            Write-Host "A multi-platform game launcher with application management capabilities."
        }

        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  Focus-Game-Deck.exe                    # Launch GUI configuration editor" -ForegroundColor White
        Write-Host "  Focus-Game-Deck.exe --config          # Launch GUI configuration editor (explicit)" -ForegroundColor White
        Write-Host "  Focus-Game-Deck.exe <GameId>          # Launch specific game" -ForegroundColor White
        Write-Host "  Focus-Game-Deck.exe --list           # List available games" -ForegroundColor White
        Write-Host "  Focus-Game-Deck.exe --help           # Show this help information" -ForegroundColor White
        Write-Host "  Focus-Game-Deck.exe --version        # Show version information" -ForegroundColor White
        Write-Host ""

        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  Focus-Game-Deck.exe apex              # Launch Apex Legends" -ForegroundColor Gray
        Write-Host "  Focus-Game-Deck.exe valorant          # Launch Valorant" -ForegroundColor Gray
        Write-Host "  Focus-Game-Deck.exe dbd               # Launch Dead by Daylight" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Configuration:" -ForegroundColor Yellow
        Write-Host "  Configuration file: config/config.json" -ForegroundColor Gray
        Write-Host "  Use the GUI editor for easy configuration management." -ForegroundColor Gray
        Write-Host ""

    } catch {
        Write-Host "Focus Game Deck - Multi-Platform Game Launcher" -ForegroundColor Cyan
        Write-Host "Usage: Focus-Game-Deck.exe [GameId|--config|--list|--help|--version]" -ForegroundColor White
        Write-Host "Run without arguments to open the configuration editor." -ForegroundColor Gray
    }
}

<#
.SYNOPSIS
    Shows version information for Focus Game Deck

.DESCRIPTION
    Displays detailed version information including build number, date, and features.
#>
function Show-Version {
    param()

    try {
        if (Get-Command "Get-ProjectVersionInfo" -ErrorAction SilentlyContinue) {
            $versionInfo = Get-ProjectVersionInfo
            Write-Host "Focus Game Deck v$($versionInfo.FullVersion)" -ForegroundColor Cyan
            if ($versionInfo.BuildDate) {
                Write-Host "Build Date: $($versionInfo.BuildDate)" -ForegroundColor Gray
            }
            if ($versionInfo.GitCommit) {
                Write-Host "Git Commit: $($versionInfo.GitCommit)" -ForegroundColor Gray
            }
        } else {
            Write-Host "Focus Game Deck" -ForegroundColor Cyan
            Write-Host "Version information not available." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Focus Game Deck" -ForegroundColor Cyan
        Write-Host "Version: Unknown" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Lists all available games from configuration

.DESCRIPTION
    Reads the configuration file and displays all configured games with their
    display names, platforms, and Game IDs for easy reference.
#>
function Show-GameList {
    param()

    try {
        # Load configuration
        if (-not (Test-Path $configPath)) {
            Write-Host "Configuration file not found: $configPath" -ForegroundColor Red
            Write-Host "Please run the configuration editor to set up your games." -ForegroundColor Yellow
            return
        }

        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

        # Load messages for localization
        $langCode = Get-DetectedLanguage -ConfigData $config
        $msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode

        if (-not $config.games -or $config.games.PSObject.Properties.Count -eq 0) {
            if ($msg -and $msg.no_games_configured) {
                Write-Host $msg.no_games_configured -ForegroundColor Yellow
            } else {
                Write-Host "No games are configured. Use --config to set up your games." -ForegroundColor Yellow
            }
            return
        }

        Write-Host ""
        if ($msg -and $msg.available_games) {
            Write-Host $msg.available_games -ForegroundColor Cyan
        } else {
            Write-Host "Available Games:" -ForegroundColor Cyan
        }
        Write-Host ("=" * 50) -ForegroundColor Cyan
        Write-Host ""

        # Display each game with formatted output
        $config.games.PSObject.Properties | ForEach-Object {
            $gameId = $_.Name
            $gameData = $_.Value
            $platform = if ($gameData.platform) { $gameData.platform } else { "steam" }

            Write-Host "Game ID: " -NoNewline -ForegroundColor White
            Write-Host $gameId -ForegroundColor Green
            Write-Host "  Name: " -NoNewline -ForegroundColor Gray
            Write-Host $gameData.name -ForegroundColor White
            Write-Host "  Platform: " -NoNewline -ForegroundColor Gray
            Write-Host $platform -ForegroundColor Cyan
            if ($gameData.processName) {
                Write-Host "  Process: " -NoNewline -ForegroundColor Gray
                Write-Host $gameData.processName -ForegroundColor Yellow
            }
            Write-Host ""
        }

        Write-Host "Usage: Focus-Game-Deck.exe <GameId>" -ForegroundColor Gray
        Write-Host ""

    } catch {
        Write-Host "Failed to load game list: $_" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Launches the ConfigEditor with enhanced game launcher functionality

.DESCRIPTION
    Starts the ConfigEditor GUI with optional game launcher mode enabled.
    This provides a unified interface for both configuration and game launching.
#>
function Start-ConfigEditor {
    param(
        [switch]$WithGameLauncher
    )

    try {
        # Check if running as compiled executable
        if ($MyInvocation.MyCommand.Path -like "*.exe") {
            Write-Host "Configuration Editor Integration (Unified Executable Mode)" -ForegroundColor Cyan
            Write-Host "=========================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "This unified executable includes integrated configuration editing capabilities." -ForegroundColor White
            Write-Host ""
            Write-Host "For now, please use the standalone GUI editor for configuration:" -ForegroundColor Yellow
            Write-Host "  powershell -ExecutionPolicy Bypass -File gui/ConfigEditor.ps1" -ForegroundColor Gray
            Write-Host ""
            Write-Host "The full GUI integration is planned for the next release." -ForegroundColor Green
            return
        }

        # Original behavior for script execution
        if (-not (Test-Path $configEditorPath)) {
            Write-Host "Configuration editor not found: $configEditorPath" -ForegroundColor Red
            return
        }

        Write-Host "Starting Focus Game Deck Configuration Editor..." -ForegroundColor Cyan

        if ($WithGameLauncher) {
            # Future: Pass parameter to enable game launcher tab by default
            & powershell.exe -ExecutionPolicy Bypass -File $configEditorPath
        } else {
            & powershell.exe -ExecutionPolicy Bypass -File $configEditorPath
        }

    } catch {
        Write-Host "Failed to start configuration editor: $_" -ForegroundColor Red
        exit 1
    }
}

<#
.SYNOPSIS
    Launches a specific game using the existing game launcher

.DESCRIPTION
    Validates the game ID and delegates to the existing Invoke-FocusGameDeck.ps1
    script for actual game launching functionality.
#>
function Start-Game {
    param(
        [Parameter(Mandatory)]
        [string]$GameId
    )

    try {
        if (-not (Test-Path $gameLauncherPath)) {
            Write-Host "Game launcher not found: $gameLauncherPath" -ForegroundColor Red
            return
        }

        # Validate GameId exists in configuration
        if (Test-Path $configPath) {
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            if (-not $config.games.$GameId) {
                Write-Host "Game ID '$GameId' not found in configuration." -ForegroundColor Red
                Write-Host "Use --list to see available games or --config to add new ones." -ForegroundColor Yellow
                return
            }
        }

        Write-Host "Launching game: $GameId" -ForegroundColor Cyan

        # Delegate to existing game launcher
        & powershell.exe -ExecutionPolicy Bypass -File $gameLauncherPath -GameId $GameId

    } catch {
        Write-Host "Failed to launch game '$GameId': $_" -ForegroundColor Red
        exit 1
    }
}

<#
.SYNOPSIS
    Main entry point logic with argument parsing and routing

.DESCRIPTION
    Analyzes command line arguments and routes to appropriate functionality:
    - Help and version information
    - Game listing
    - Configuration editor (GUI)
    - Game launching
#>
function Main {
    try {
        # Debug: Show received parameters
        Write-Host "Main.ps1 Debug: Received parameters:" -ForegroundColor Yellow
        Write-Host "  GameId: '$GameId'" -ForegroundColor Cyan
        Write-Host "  Config: $Config" -ForegroundColor Cyan
        Write-Host "  List: $List" -ForegroundColor Cyan
        Write-Host "  Help: $Help" -ForegroundColor Cyan
        Write-Host "  Version: $Version" -ForegroundColor Cyan

        # Handle help and version first (these don't require config)
        if ($Help) {
            Show-Help
            return
        }

        if ($Version) {
            Show-Version
            return
        }

        if ($List) {
            Show-GameList
            return
        }

        # Handle game launch (GameId provided) - Check this first
        if (-not [string]::IsNullOrWhiteSpace($GameId)) {
            # Check if it's a help request disguised as GameId
            if ($GameId -match "^(help|--help|-h|/?)$") {
                Show-Help
                return
            }

            # Check if it's a version request
            if ($GameId -match "^(version|--version|-v)$") {
                Show-Version
                return
            }

            # Check if it's a list request
            if ($GameId -match "^(list|--list|-l)$") {
                Show-GameList
                return
            }

            Start-Game -GameId $GameId
            return
        }

        # Handle config editor launch (explicit or no arguments)
        if ($Config -or [string]::IsNullOrWhiteSpace($GameId)) {
            Start-ConfigEditor -WithGameLauncher
            return
        }

        # Fallback: show help if nothing matches
        Show-Help

    } catch {
        Write-Host "Unexpected error: $_" -ForegroundColor Red
        Write-Host "Use --help for usage information." -ForegroundColor Yellow
        exit 1
    }
}

# Application entry point
Main
