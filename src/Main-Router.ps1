<#
.SYNOPSIS
    Focus Game Deck - Lightweight Router (Main Entry Point)

.DESCRIPTION
    This is a lightweight router that launches the correct sub-process based on user arguments.
    It serves as the main entry point for Focus Game Deck and delegates to specialized executables:
    - ConfigEditor.exe for GUI configuration
    - Invoke-FocusGameDeck.exe for game launching
    
    This architecture ensures all executed code is contained within digitally signed executables.

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

.NOTES
    File Name  : Main-Router.ps1
    Author     : Focus Game Deck Team
    Version    : 3.0.0 - Multi-Executable Bundle Architecture
    Requires   : PowerShell 5.1 or later

.LINK
    https://github.com/beive60/focus-game-deck
#>

param(
    [Parameter(Position = 0)]
    [string]$GameId = "",

    [switch]$Config,
    [switch]$List,
    [switch]$Help,
    [switch]$Version
)

#Requires -Version 5.1

$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

if ($isExecutable) {
    $workingDir = Split-Path -Parent $currentProcess.Path
    $scriptDir = $workingDir
} else {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $workingDir = (Get-Location).Path
}

if ($isExecutable) {
    $configPath = Join-Path $workingDir "config/config.json"
    $languageHelperPath = Join-Path $workingDir "scripts/LanguageHelper.ps1"
    $messagesPath = Join-Path $workingDir "localization/messages.json"
    $versionScriptPath = Join-Path $workingDir "build-tools/Version.ps1"
    $configEditorExe = Join-Path $workingDir "ConfigEditor.exe"
    $gameLauncherExe = Join-Path $workingDir "Invoke-FocusGameDeck.exe"
} else {
    $projectRoot = if ($scriptDir -like "*\src") { Split-Path $scriptDir -Parent } else { $workingDir }
    $configPath = Join-Path $projectRoot "config/config.json"
    $languageHelperPath = Join-Path $projectRoot "scripts/LanguageHelper.ps1"
    $messagesPath = Join-Path $projectRoot "localization/messages.json"
    $versionScriptPath = Join-Path $projectRoot "build-tools/Version.ps1"
    $configEditorExe = Join-Path $projectRoot "build-tools/dist/ConfigEditor.exe"
    $gameLauncherExe = Join-Path $projectRoot "build-tools/dist/Invoke-FocusGameDeck.exe"
}

if ($versionScriptPath -and (Test-Path $versionScriptPath)) {
    try {
        . $versionScriptPath
    } catch {
        Write-Warning "Failed to load version script: $_"
    }
}

if ($languageHelperPath -and (Test-Path $languageHelperPath)) {
    try {
        . $languageHelperPath
    } catch {
        Write-Warning "Failed to load language helper: $_"
    }
} else {
    function Get-DetectedLanguage { param($ConfigData) return "en" }
    function Get-LocalizedMessages { param($MessagesPath, $LanguageCode) return $null }
}

function Show-Help {
    param()

    try {
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        $langCode = if ($config) { Get-DetectedLanguage -ConfigData $config } else { "en" }
        $msg = if (Test-Path $messagesPath) { Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode } else { $null }

        $versionInfo = if (Get-Command "Get-ProjectVersionInfo" -ErrorAction SilentlyContinue) {
            Get-ProjectVersionInfo
        } else {
            @{ FullVersion = "3.0.0" }
        }

        Write-Host ""
        Write-Host "Focus Game Deck v$($versionInfo.FullVersion)"
        Write-Host "=================================="
        Write-Host ""

        if ($msg -and $msg.help_description) {
            Write-Host $msg.help_description
        } else {
            Write-Host "A multi-platform game launcher with application management capabilities."
        }

        Write-Host ""
        Write-Host "Usage:"
        Write-Host "  Focus-Game-Deck.exe                    # Launch GUI configuration editor"
        Write-Host "  Focus-Game-Deck.exe --config          # Launch GUI configuration editor (explicit)"
        Write-Host "  Focus-Game-Deck.exe <GameId>          # Launch specific game"
        Write-Host "  Focus-Game-Deck.exe --list           # List available games"
        Write-Host "  Focus-Game-Deck.exe --help           # Show this help information"
        Write-Host "  Focus-Game-Deck.exe --version        # Show version information"
        Write-Host ""

        Write-Host "Examples:"
        Write-Host "  Focus-Game-Deck.exe apex              # Launch Apex Legends"
        Write-Host "  Focus-Game-Deck.exe valorant          # Launch Valorant"
        Write-Host "  Focus-Game-Deck.exe dbd               # Launch Dead by Daylight"
        Write-Host ""

    } catch {
        Write-Host "Focus Game Deck - Multi-Platform Game Launcher"
        Write-Host "Usage: Focus-Game-Deck.exe [GameId|--config|--list|--help|--version]"
    }
}

function Show-Version {
    param()

    try {
        if (Get-Command "Get-ProjectVersionInfo" -ErrorAction SilentlyContinue) {
            $versionInfo = Get-ProjectVersionInfo
            Write-Host "Focus Game Deck v$($versionInfo.FullVersion)"
            if ($versionInfo.BuildDate) {
                Write-Host "Build Date: $($versionInfo.BuildDate)"
            }
            if ($versionInfo.GitCommit) {
                Write-Host "Git Commit: $($versionInfo.GitCommit)"
            }
        } else {
            Write-Host "Focus Game Deck v3.0.0"
        }
    } catch {
        Write-Host "Focus Game Deck v3.0.0"
    }
}

function Show-GameList {
    param()

    try {
        if (-not (Test-Path $configPath)) {
            Write-Host "[ERROR] Configuration file not found: $configPath"
            Write-Host "[INFO] Please run the configuration editor to set up your games."
            return
        }

        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $langCode = Get-DetectedLanguage -ConfigData $config
        $msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode

        if (-not $config.games -or $config.games.PSObject.Properties.Count -eq 0) {
            if ($msg -and $msg.no_games_configured) {
                Write-Host $msg.no_games_configured
            } else {
                Write-Host "[WARNING] No games are configured. Use --config to set up your games."
            }
            return
        }

        Write-Host ""
        if ($msg -and $msg.mainGameListTitle) {
            Write-Host $msg.mainGameListTitle
        } else {
            Write-Host "Available Games:"
        }
        Write-Host ("=" * 50)
        Write-Host ""

        $config.games.PSObject.Properties | ForEach-Object {
            $gameId = $_.Name
            $gameData = $_.Value
            $platform = if ($gameData.platform) { $gameData.platform } else { "steam" }

            $gameIdLabel = if ($msg -and $msg.mainGameListGameId) { $msg.mainGameListGameId } else { "Game ID: " }
            $nameLabel = if ($msg -and $msg.mainGameListName) { $msg.mainGameListName } else { "  Name: " }
            $platformLabel = if ($msg -and $msg.mainGameListPlatform) { $msg.mainGameListPlatform } else { "  Platform: " }

            Write-Host "$gameIdLabel$gameId"
            Write-Host "$nameLabel$($gameData.name)"
            Write-Host "$platformLabel$platform"
            Write-Host ""
        }

        $usageText = if ($msg -and $msg.mainGameListUsage) { $msg.mainGameListUsage } else { "Usage: Focus-Game-Deck.exe <GameId>" }
        Write-Host $usageText
        Write-Host ""

    } catch {
        Write-Host "[ERROR] Failed to load game list: $_"
    }
}

function Start-ConfigEditor {
    param()

    try {
        if (Test-Path $configEditorExe) {
            Write-Host "[INFO] Starting Configuration Editor..."
            & $configEditorExe
        } else {
            Write-Host "[ERROR] ConfigEditor.exe not found: $configEditorExe"
            Write-Host "[INFO] Please ensure all executable files are in the same directory."
            exit 1
        }
    } catch {
        Write-Host "[ERROR] Failed to start configuration editor: $_"
        exit 1
    }
}

function Start-Game {
    param(
        [Parameter(Mandatory)]
        [string]$GameId
    )

    try {
        if (Test-Path $configPath) {
            $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $config.games.$GameId) {
                Write-Host "[ERROR] Game ID '$GameId' not found in configuration."
                Write-Host "[INFO] Use --list to see available games or --config to add new ones."
                return
            }
        }

        if (Test-Path $gameLauncherExe) {
            Write-Host "[INFO] Launching game: $GameId"
            & $gameLauncherExe -GameId $GameId
        } else {
            Write-Host "[ERROR] Invoke-FocusGameDeck.exe not found: $gameLauncherExe"
            Write-Host "[INFO] Please ensure all executable files are in the same directory."
            exit 1
        }
    } catch {
        Write-Host "[ERROR] Failed to launch game '$GameId': $_"
        exit 1
    }
}

function Main {
    try {
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

        if (-not [string]::IsNullOrWhiteSpace($GameId)) {
            if ($GameId -match "^(help|--help|-h|/?)$") {
                Show-Help
                return
            }

            if ($GameId -match "^(version|--version|-v)$") {
                Show-Version
                return
            }

            if ($GameId -match "^(list|--list|-l)$") {
                Show-GameList
                return
            }

            Start-Game -GameId $GameId
            return
        }

        if ($Config -or [string]::IsNullOrWhiteSpace($GameId)) {
            Start-ConfigEditor
            return
        }

        Show-Help

    } catch {
        Write-Host "[ERROR] Unexpected error: $_"
        Write-Host "[INFO] Use --help for usage information."
        exit 1
    }
}

Main
