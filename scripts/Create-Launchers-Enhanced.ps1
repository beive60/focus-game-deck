<#
.SYNOPSIS
    Enhanced Launcher Creation Script for Focus Game Deck

.DESCRIPTION
    This script generates Windows shortcut (.lnk) files instead of .bat files for better user experience and visual appeal.
    Creates user-friendly shortcut launchers for each game defined in config.json, with minimized PowerShell window execution.

.PARAMETER NoInteractive
    Suppresses pause prompts for automated execution

.PARAMETER GameId
    Optional. If specified, creates a shortcut only for the specified game ID

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-09-26

    Requirements:
    - Windows 10/11
    - PowerShell 5.1 or later
    - config.json file in project config directory

    Design Philosophy:
    - User-friendly alternative to .bat files for non-technical users
    - Minimized window execution to reduce visual disruption
    - Automatic cleanup of old launcher files
    - Robust error handling with appropriate fallbacks
#>

param(
    [switch]$NoInteractive,
    [string]$GameId = $null
)

# Get the directory where the script is located
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
    # When run from executable, use current directory
    $scriptDir = Get-Location
}

Write-Verbose "Script directory: $scriptDir"

# Determine root directory - if scriptDir is 'scripts', go up one level
if ((Split-Path -Leaf $scriptDir) -eq "scripts") {
    $rootDir = Split-Path $scriptDir -Parent
} else {
    # When run from executable, assume current directory is root
    $rootDir = $scriptDir
}

Write-Verbose "Root directory: $rootDir"

$configPath = Join-Path $rootDir "config/config.json"
$coreScriptPath = Join-Path $rootDir "src/Invoke-FocusGameDeck.ps1"
$messagesPath = Join-Path $rootDir "localization/messages.json"

Write-Verbose "Config path: $configPath"
Write-Verbose "Core script path: $coreScriptPath"
Write-Verbose "Messages path: $messagesPath"

# Check if config.json exists
if (-not (Test-Path $configPath)) {
    Write-Host "Error: config/config.json not found."
    Write-Host "Please copy config/config.json.sample to config/config.json and configure it."
    if (-not $NoInteractive) {
        pause
    }
    exit 1
}

<#
.SYNOPSIS
    Creates a Windows shortcut (.lnk) file for game launcher

.DESCRIPTION
    Generates a Windows shortcut file using WScript.Shell COM object with proper error handling and memory cleanup.
    Supports custom icons, working directories, and window styles for optimal user experience.

.PARAMETER ShortcutPath
    Full path where the shortcut file will be created

.PARAMETER TargetPath
    Path to the target executable (typically powershell.exe)

.PARAMETER Arguments
    Command line arguments to pass to the target executable

.PARAMETER Description
    Description text for the shortcut (visible in tooltip)

.PARAMETER WorkingDirectory
    Working directory for the shortcut execution

.PARAMETER IconLocation
    Path to custom icon file (.ico) for the shortcut

.PARAMETER WindowStyle
    Window display style (7 = Minimized for reduced visual disruption)

.OUTPUTS
    [bool] Returns $true if shortcut creation succeeded, $false otherwise

.EXAMPLE
    New-GameShortcut -ShortcutPath "C:/Games/launch_apex.lnk" -TargetPath "powershell.exe" -Arguments "-File script.ps1"
#>
function New-GameShortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShortcutPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [string]$WorkingDirectory = "",

        [string]$IconLocation = "",

        [int]$WindowStyle = 7  # 7 = Minimized (reduces visual disruption)
    )

    try {
        # Create WScript.Shell COM object for shortcut creation
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

        # Configure shortcut properties
        $Shortcut.TargetPath = $TargetPath
        $Shortcut.Arguments = $Arguments
        $Shortcut.Description = $Description
        $Shortcut.WindowStyle = $WindowStyle

        # Set working directory if provided
        if ($WorkingDirectory) {
            $Shortcut.WorkingDirectory = $WorkingDirectory
        }

        # Set custom icon if provided
        if ($IconLocation -and (Test-Path $IconLocation)) {
            $Shortcut.IconLocation = $IconLocation
        }

        # Save the shortcut
        $Shortcut.Save()

        # Release COM object to prevent memory leaks
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null

        return $true
    } catch {
        Write-Host "Warning: Failed to create shortcut '$ShortcutPath': $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Cleans up old launcher files from previous executions

.DESCRIPTION
    Removes existing .bat and .lnk launcher files to prevent accumulation of outdated launchers.
    Provides user feedback about cleanup operations and gracefully handles file access errors.

.PARAMETER RootDirectory
    Root directory path where launcher files are located

.EXAMPLE
    Remove-OldLaunchers -RootDirectory "C:/FocusGameDeck"
#>
function Remove-OldLaunchers {
    param([string]$RootDirectory)

    # Remove old .bat files
    $oldBatFiles = Get-ChildItem -Path $RootDirectory -Filter "launch_*.bat" -ErrorAction SilentlyContinue
    if ($oldBatFiles) {
        Write-Host "Cleaning up old .bat launchers..."
        foreach ($file in $oldBatFiles) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "  Removed: $($file.Name)"
            } catch {
                Write-Host "  Warning: Could not remove $($file.Name): $($_.Exception.Message)"
            }
        }
    }

    # Remove old .lnk files
    $oldLnkFiles = Get-ChildItem -Path $RootDirectory -Filter "launch_*.lnk" -ErrorAction SilentlyContinue
    if ($oldLnkFiles) {
        Write-Host "Cleaning up old shortcut launchers..."
        foreach ($file in $oldLnkFiles) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "  Removed: $($file.Name)"
            } catch {
                Write-Host "  Warning: Could not remove $($file.Name): $($_.Exception.Message)"
            }
        }
    }
}

# Main execution
try {
    Write-Host "Focus Game Deck - Enhanced Launcher Creator"
    Write-Host ("=" * 60)

    # Load the configuration file
    Write-Host "Loading configuration from: $configPath"
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Load localization messages
    if (-not (Test-Path $messagesPath)) {
        Write-Host "Warning: Localization file not found at: $messagesPath"
        Write-Host "Using default English messages"
        $localizedMessages = @{
            readmeTitle = "Focus Game Deck - Game Launcher Shortcuts"
            readmeDescription = "This folder contains shortcuts for games configured in Focus Game Deck."
            readmeUsageTitle = "Usage"
            readmeUsageStep1 = "1. Double-click a shortcut to launch the game"
            readmeUsageStep2 = "2. Focus Game Deck will automatically launch the game and control associated integration apps (OBS, Discord, VTube Studio, etc.)"
            readmeUsageStep3 = "3. Configured integration apps will automatically stop when you exit the game"
            readmeNotesTitle = "Notes"
            readmeNote1 = "- You can freely delete or move shortcuts"
            readmeNote2 = "- If you change settings, recreate shortcuts from the Tools menu"
            readmeNote3 = "- If you encounter any issues, please report them in the GitHub repository Issues section"
            readmeFooter = "More info: https://github.com/beive60/focus-game-deck"
        }
    } else {
        $messages = Get-Content -Path $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $currentLanguage = $config.globalSettings.language
        if (-not $currentLanguage) {
            $currentLanguage = "en"
        }
        $localizedMessages = $messages.$currentLanguage
    }

    # Determine output directory (Desktop/Focus-Game-Deck/)
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $outputDir = Join-Path $desktopPath "Focus-Game-Deck"

    # Create output directory if it doesn't exist
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        Write-Host "Created directory: $outputDir"
    }

    # Create README.txt in the output directory
    $readmeContent = @"
$($localizedMessages.readmeTitle)
$('=' * 80)

$($localizedMessages.readmeDescription)

$($localizedMessages.readmeUsageTitle)
$('-' * 80)
$($localizedMessages.readmeUsageStep1)
$($localizedMessages.readmeUsageStep2)
$($localizedMessages.readmeUsageStep3)

$($localizedMessages.readmeNotesTitle)
$('-' * 80)
$($localizedMessages.readmeNote1)
$($localizedMessages.readmeNote2)
$($localizedMessages.readmeNote3)

$($localizedMessages.readmeFooter)
"@
    $readmePath = Join-Path $outputDir "README.txt"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8 -Force
    Write-Host "Created README.txt in output directory"

    # Clean up old launchers
    Remove-OldLaunchers -TargetDirectory $outputDir

    # Get all game entries, excluding _order property
    $allProperties = $config.games.PSObject.Properties
    $games = @($allProperties | Where-Object { $_.Name -ne '_order' })

    if ($games.Count -eq 0) {
        Write-Host "Warning: No games found in configuration."
        if (-not $NoInteractive) {
            pause
        }
        exit 0
    }

    # If a specific GameId is provided, filter to only that game
    if ($GameId) {
        $targetGame = $games | Where-Object { $_.Name -eq $GameId }
        if (-not $targetGame) {
            Write-Host "Error: Game ID '$GameId' not found in configuration."
            if (-not $NoInteractive) {
                pause
            }
            exit 1
        }
        $games = @($targetGame)
        Write-Host "Creating shortcut launcher for game: $GameId"
    } else {
        $count = $games.Count
        Write-Host "Found $count games. Generating shortcut launchers..."
    }

    $successCount = 0
    $failureCount = 0

    # Loop through each game and create a shortcut launcher
    foreach ($game in $games) {
        $gameId = $game.Name
        $gameDisplayName = $game.Value.name
        $shortcutPath = Join-Path $outputDir "$($gameId).lnk"

        # Create description for the shortcut
        $description = "Launch $gameDisplayName with Focus Game Deck automation"

        # PowerShell arguments for executing the core script
        $psArguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$coreScriptPath`" -GameId $gameId"

        Write-Host "  Creating launcher for: $gameDisplayName"

        # Create the shortcut
        $success = New-GameShortcut -ShortcutPath $shortcutPath `
            -TargetPath "powershell.exe" `
            -Arguments $psArguments `
            -Description $description `
            -WorkingDirectory $rootDir `
            -WindowStyle 7

        if ($success) {
            Write-Host "    [OK] Successfully created: $($gameId).lnk"
            $successCount++
        } else {
            Write-Host "    [ERROR] Failed to create launcher for: $gameDisplayName"
            $failureCount++
        }
    }

    # Summary
    Write-Host "" + ("=" * 50)
    if ($GameId) {
        if ($successCount -eq 1) {
            Write-Host "Shortcut created successfully for game: $GameId"
            Write-Host "You can now double-click 'launch_$($GameId).lnk' to start the game."
        } else {
            Write-Host "Failed to create shortcut for game: $GameId"
        }
    } else {
        Write-Host "Launcher creation completed!"
        Write-Host "Successfully created: $successCount shortcuts"

        if ($failureCount -gt 0) {
            Write-Host "Failed to create: $failureCount shortcuts"
        }

        Write-Host "You can now double-click the 'launch_GAMEID.lnk' files to start your games."
    }
    Write-Host "The PowerShell window will be minimized automatically for better user experience."

} catch {
    Write-Host "Error: Failed to process configuration file."
    Write-Host "Details: $($_.Exception.Message)"
    Write-Host "Please check your config.json file for syntax errors."
} finally {
    if (-not $NoInteractive) {
        Write-Host "Press any key to continue..."
        pause
    }
}
