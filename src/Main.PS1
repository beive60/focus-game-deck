<#
.SYNOPSIS
    Focus Game Deck - Unified main entry point for all functionality.

.DESCRIPTION
    This script serves as the single entry point for Focus Game Deck, providing:
    - Game launching with automatic integration management
    - GUI configuration editor
    - Command-line game list and help
    - Version information display

    The script automatically detects its execution environment (bundled executable vs. script)
    and adjusts path resolution accordingly to eliminate code duplication.

.PARAMETER GameId
    The ID of the game to launch (optional, positional parameter)

.PARAMETER Config
    Switch to force launch the GUI configuration editor

.PARAMETER List
    Switch to display a list of all configured games

.PARAMETER Help
    Switch to show help information

.PARAMETER Version
    Switch to display version information

.EXAMPLE
    Focus-Game-Deck.exe
    Launches the GUI configuration editor

.EXAMPLE
    Focus-Game-Deck.exe valorant
    Launches the game with ID "valorant"

.EXAMPLE
    Focus-Game-Deck.exe --list
    Lists all configured games

.EXAMPLE
    Focus-Game-Deck.exe --help
    Displays help information

.NOTES
    File Name  : Main.PS1
    Author     : Focus Game Deck Team
    Version    : 3.0.0 - Multi-Executable Bundle Architecture
    Requires   : PowerShell 5.1 or later

.LINK
    https://github.com/beive60/focus-game-deck
#>

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
# Author: Focus Game Deck Team
# Version: 3.0.0 - Multi-Executable Bundle Architecture
# Date: 2025-11-14

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

# Detect execution environment
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

# Define the application root directory
# This is critical for finding external resources (config, XAML, logs)
if ($isExecutable) {
    # In executable mode, the root is the directory where the .exe file is located
    # ps2exe extracts to temp, but we need the actual exe location
    $appRoot = Split-Path -Parent $currentProcess.Path
    $scriptDir = $PSScriptRoot  # Points to temp extraction dir
} else {
    # In development (script) mode, calculate the project root relative to the current script
    # For Main.PS1 in /src, the root is one level up
    $appRoot = Split-Path -Parent $PSScriptRoot
    $scriptDir = $PSScriptRoot
}

# Path to external resources relative to $appRoot (not $PSScriptRoot)
if ($isExecutable) {
    # In bundled mode, all files are in the same directory as the executable
    $configPath = Join-Path $appRoot "config/config.json"
    $messagesPath = Join-Path $appRoot "localization/messages.json"
    $configEditorExe = Join-Path $appRoot "ConfigEditor.exe"
    $gameLauncherExe = Join-Path $appRoot "Invoke-FocusGameDeck.exe"

    # For version and language helper, check both bundled location and working dir
    $versionScriptPath = Join-Path $scriptDir "Version.ps1"
    $languageHelperPath = Join-Path $scriptDir "LanguageHelper.ps1"
} else {
    # In development (script) mode, use project structure paths
    $configPath = Join-Path $appRoot "config/config.json"
    $messagesPath = Join-Path $appRoot "localization/messages.json"
    $configEditorExe = Join-Path $appRoot "build-tools/dist/ConfigEditor.exe"
    $gameLauncherExe = Join-Path $appRoot "build-tools/dist/Invoke-FocusGameDeck.exe"
    $gameLauncherPath = Join-Path $appRoot "src/Invoke-FocusGameDeck.ps1"
    $configEditorPath = Join-Path $appRoot "gui/ConfigEditor.ps1"
    $versionScriptPath = Join-Path $appRoot "build-tools/Version.ps1"
    $languageHelperPath = Join-Path $appRoot "scripts/LanguageHelper.ps1"
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
if ($versionScriptPath -and (Test-Path $versionScriptPath)) {
    try {
        . $versionScriptPath
    } catch {
        Write-Warning "Failed to load version script: $_"
    }
}

# Provide fallback version function
if (-not (Get-Command "Get-ProjectVersionInfo" -ErrorAction SilentlyContinue)) {
    function Get-ProjectVersionInfo {
        return @{ FullVersion = "3.0.0" }
    }
}

# Import language helper functions
if ($languageHelperPath -and (Test-Path $languageHelperPath)) {
    try {
        . $languageHelperPath
    } catch {
        Write-Warning "Failed to load language helper: $_"
    }
} else {
    # Provide fallback functions for basic operation
    function Get-DetectedLanguage { param($ConfigData) return "en" }
    function Get-LocalizedMessages { param($MessagesPath, $LanguageCode) return $null }
}

<#
.SYNOPSIS
    Displays help information for Focus Game Deck.

.DESCRIPTION
    Shows usage instructions, available commands, and examples in the user's
    preferred language. Includes version information if available.

.OUTPUTS
    None - displays help text to console

.EXAMPLE
    Show-Help

.NOTES
    Automatically detects language from configuration and uses localized messages.
#>
function Show-Help {
    param()

    try {
        # Try to load messages for help display
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        $langCode = if ($config) { Get-DetectedLanguage -ConfigData $config } else { "en" }
        $msg = if (Test-Path $messagesPath) { Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode } else { $null }

        # Get version info
        $versionInfo = Get-ProjectVersionInfo

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
        $versionInfo = Get-ProjectVersionInfo
        Write-Host "Focus Game Deck v$($versionInfo.FullVersion)" -ForegroundColor Cyan
        if ($versionInfo.BuildDate) {
            Write-Host "Build Date: $($versionInfo.BuildDate)" -ForegroundColor Gray
        }
        if ($versionInfo.GitCommit) {
            Write-Host "Git Commit: $($versionInfo.GitCommit)" -ForegroundColor Gray
        }
        Write-Host "Multi-Executable Bundle Architecture" -ForegroundColor Gray
    } catch {
        Write-Host "Focus Game Deck v3.0.0" -ForegroundColor Cyan
        Write-Host "Multi-Executable Bundle Architecture" -ForegroundColor Gray
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

        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

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
        if ($msg -and $msg.mainGameListTitle) {
            Write-Host $msg.mainGameListTitle -ForegroundColor Cyan
        } elseif ($msg -and $msg.availableGames) {
            Write-Host $msg.availableGames -ForegroundColor Cyan
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

            $gameIdLabel = if ($msg -and $msg.mainGameListGameId) { $msg.mainGameListGameId } else { "Game ID: " }
            $nameLabel = if ($msg -and $msg.mainGameListName) { $msg.mainGameListName } else { "  Name: " }
            $platformLabel = if ($msg -and $msg.mainGameListPlatform) { $msg.mainGameListPlatform } else { "  Platform: " }
            $processLabel = if ($msg -and $msg.mainGameListProcess) { $msg.mainGameListProcess } else { "  Process: " }

            Write-Host $gameIdLabel -NoNewline -ForegroundColor White
            Write-Host $gameId -ForegroundColor Green
            Write-Host $nameLabel -NoNewline -ForegroundColor Gray
            Write-Host $gameData.name -ForegroundColor White
            Write-Host $platformLabel -NoNewline -ForegroundColor Gray
            Write-Host $platform -ForegroundColor Cyan
            if ($gameData.processName) {
                Write-Host $processLabel -NoNewline -ForegroundColor Gray
                Write-Host $gameData.processName -ForegroundColor Yellow
            }
            Write-Host ""
        }

        $usageText = if ($msg -and $msg.mainGameListUsage) { $msg.mainGameListUsage } else { "Usage: Focus-Game-Deck.exe <GameId>" }
        Write-Host $usageText -ForegroundColor Gray
        Write-Host ""

    } catch {
        Write-Host "Failed to load game list: $_" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Launches the ConfigEditor with enhanced game launcher functionality

.DESCRIPTION
    Starts the ConfigEditor GUI. In bundled mode, launches the ConfigEditor.exe.
    In development mode, launches the PowerShell script.
#>
function Start-ConfigEditor {
    param(
        [switch]$WithGameLauncher
    )

    try {
        if ($isExecutable) {
            # Running as bundled executable - launch ConfigEditor.exe
            if (Test-Path $configEditorExe) {
                Write-Host "[INFO] Starting Configuration Editor..."
                & $configEditorExe
            } else {
                Write-Host "[ERROR] ConfigEditor.exe not found: $configEditorExe" -ForegroundColor Red
                Write-Host "[INFO] Please ensure all executable files are in the same directory."
                exit 1
            }
        } else {
            # Running as script - launch ConfigEditor.ps1
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
    Validates the game ID and launches the game. In bundled mode, uses Invoke-FocusGameDeck.exe.
    In development mode, uses the PowerShell script.
#>
function Start-Game {
    param(
        [Parameter(Mandatory)]
        [string]$GameId
    )

    try {
        # Validate GameId exists in configuration
        if (Test-Path $configPath) {
            $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $config.games.$GameId) {
                Write-Host "[ERROR] Game ID '$GameId' not found in configuration." -ForegroundColor Red
                Write-Host "[INFO] Use --list to see available games or --config to add new ones." -ForegroundColor Yellow
                return
            }
        }

        if ($isExecutable) {
            # Running as bundled executable - launch Invoke-FocusGameDeck.exe
            if (Test-Path $gameLauncherExe) {
                Write-Host "[INFO] Launching game: $GameId"
                & $gameLauncherExe -GameId $GameId
            } else {
                Write-Host "[ERROR] Invoke-FocusGameDeck.exe not found: $gameLauncherExe" -ForegroundColor Red
                Write-Host "[INFO] Please ensure all executable files are in the same directory."
                exit 1
            }
        } else {
            # Running as script - launch Invoke-FocusGameDeck.ps1
            if (-not (Test-Path $gameLauncherPath)) {
                Write-Host "Game launcher not found: $gameLauncherPath" -ForegroundColor Red
                return
            }

            Write-Host "Launching game: $GameId" -ForegroundColor Cyan

            # Delegate to existing game launcher
            & powershell.exe -ExecutionPolicy Bypass -File $gameLauncherPath -GameId $GameId
        }

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
