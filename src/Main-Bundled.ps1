<#
.SYNOPSIS
    Focus Game Deck - Main Router (Bundled Version for ps2exe)

.DESCRIPTION
    Lightweight router compiled into Main.exe. This script is designed to be
    bundled with ps2exe and launches specialized executables for GUI or game launching.
    
    When compiled with ps2exe, this script extracts to a temporary flat directory.
    All paths are resolved relative to $PSScriptRoot (the extraction directory).

.NOTES
    This is the bundled version for ps2exe compilation.
    All dependencies are bundled into the executable.
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

# Detect execution environment
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

# When running as executable, ps2exe extracts files to a flat temporary directory
# $PSScriptRoot points to this extraction directory
if ($isExecutable) {
    # Running as compiled executable
    $workingDir = Split-Path -Parent $currentProcess.Path
    $scriptDir = $PSScriptRoot
    
    # In bundled mode, all files are in the same directory as the executable
    $configPath = Join-Path $workingDir "config.json"
    $messagesPath = Join-Path $workingDir "messages.json"
    $configEditorExe = Join-Path $workingDir "ConfigEditor.exe"
    $gameLauncherExe = Join-Path $workingDir "Invoke-FocusGameDeck.exe"
} else {
    # Running as script (development mode)
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $workingDir = (Get-Location).Path
    $projectRoot = if ($scriptDir -like "*\src") { Split-Path $scriptDir -Parent } else { $workingDir }
    
    $configPath = Join-Path $projectRoot "config/config.json"
    $messagesPath = Join-Path $projectRoot "localization/messages.json"
    $configEditorExe = Join-Path $projectRoot "build-tools/dist/ConfigEditor.exe"
    $gameLauncherExe = Join-Path $projectRoot "build-tools/dist/Invoke-FocusGameDeck.exe"
}

# Simple language detection (fallback if LanguageHelper is not available)
function Get-SimpleLanguage {
    param($ConfigPath)
    
    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($config.globalSettings -and $config.globalSettings.language) {
                return $config.globalSettings.language
            }
        } catch {
            # Ignore errors
        }
    }
    return "en"
}

function Show-Help {
    Write-Host ""
    Write-Host "Focus Game Deck v3.0.0"
    Write-Host "=================================="
    Write-Host ""
    Write-Host "A multi-platform game launcher with application management capabilities."
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
    Write-Host ""
}

function Show-Version {
    Write-Host "Focus Game Deck v3.0.0"
    Write-Host "Multi-Executable Bundle Architecture"
}

function Show-GameList {
    if (-not (Test-Path $configPath)) {
        Write-Host "[ERROR] Configuration file not found: $configPath"
        Write-Host "[INFO] Please run the configuration editor to set up your games."
        return
    }

    try {
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        if (-not $config.games -or $config.games.PSObject.Properties.Count -eq 0) {
            Write-Host "[WARNING] No games are configured. Use --config to set up your games."
            return
        }

        Write-Host ""
        Write-Host "Available Games:"
        Write-Host ("=" * 50)
        Write-Host ""

        $config.games.PSObject.Properties | ForEach-Object {
            $gameId = $_.Name
            $gameData = $_.Value
            $platform = if ($gameData.platform) { $gameData.platform } else { "steam" }

            Write-Host "Game ID: $gameId"
            Write-Host "  Name: $($gameData.name)"
            Write-Host "  Platform: $platform"
            Write-Host ""
        }

        Write-Host "Usage: Focus-Game-Deck.exe <GameId>"
        Write-Host ""

    } catch {
        Write-Host "[ERROR] Failed to load game list: $_"
    }
}

function Start-ConfigEditor {
    if (Test-Path $configEditorExe) {
        Write-Host "[INFO] Starting Configuration Editor..."
        & $configEditorExe
    } else {
        Write-Host "[ERROR] ConfigEditor.exe not found: $configEditorExe"
        Write-Host "[INFO] Please ensure all executable files are in the same directory."
        exit 1
    }
}

function Start-Game {
    param([Parameter(Mandatory)][string]$GameId)

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
}

# Main routing logic
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
