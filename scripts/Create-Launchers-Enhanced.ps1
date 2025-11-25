<#
.SYNOPSIS
    Enhanced Launcher Creation Script for Focus Game Deck

.DESCRIPTION
    This script generates Windows shortcut (.lnk) files instead of .bat files for better user experience and visual appeal.
    Creates user-friendly shortcut launchers for each game defined in config.json, with minimized PowerShell window execution.

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

# Get the directory where the script is located
$scriptDir = $PSScriptRoot
$rootDir = Split-Path $scriptDir -Parent
$configPath = Join-Path $rootDir "config/config.json"
$coreScriptPath = Join-Path $rootDir "src/Invoke-FocusGameDeck.ps1"

# Check if running from GUI (parameter to suppress pause)
param(
    [switch]$NoInteractive
)

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

    # Clean up old launchers
    Remove-OldLaunchers -RootDirectory $rootDir

    # Get all game entries
    $games = $config.games.PSObject.Properties

    if ($games.Count -eq 0) {
        Write-Host "Warning: No games found in configuration."
        if (-not $NoInteractive) {
            pause
        }
        exit 0
    }

    Write-Host "Found $($games.Count) games. Generating shortcut launchers..."

    $successCount = 0
    $failureCount = 0

    # Loop through each game and create a shortcut launcher
    foreach ($game in $games) {
        $gameId = $game.Name
        $gameDisplayName = $game.Value.name
        $shortcutPath = Join-Path $rootDir "launch_$($gameId).lnk"

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
            Write-Host "    [OK] Successfully created: launch_$($gameId).lnk"
            $successCount++
        } else {
            Write-Host "    [ERROR] Failed to create launcher for: $gameDisplayName"
            $failureCount++
        }
    }

    # Summary
    Write-Host "" + ("=" * 50)
    Write-Host "Launcher creation completed!"
    Write-Host "Successfully created: $successCount shortcuts"

    if ($failureCount -gt 0) {
        Write-Host "Failed to create: $failureCount shortcuts"
    }

    Write-Host "You can now double-click the 'launch_GAMEID.lnk' files to start your games."
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
