<#
.SYNOPSIS
    Install build dependencies for Focus Game Deck

.DESCRIPTION
    This script manages the installation of required PowerShell modules for building
    Focus Game Deck executables. It checks for and installs ps2exe if needed.

.PARAMETER Force
    Force reinstallation of modules even if they are already installed

.PARAMETER Verbose
    Enable verbose output for detailed installation progress

.EXAMPLE
    .\Install-BuildDependencies.ps1
    Checks and installs ps2exe module if not already present

.EXAMPLE
    .\Install-BuildDependencies.ps1 -Force
    Reinstalls ps2exe module regardless of current installation status

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
    Responsibility: Manage build environment setup (SRP)
#>

#Requires -Version 5.1

param(
    [switch]$Force,
    [switch]$Verbose
)

# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Test-PS2EXE {
    try {
        $module = Get-Module -ListAvailable -Name ps2exe
        return $null -ne $module
    } catch {
        return $false
    }
}

function Install-PS2EXE {
    param([bool]$ForceReinstall = $false)

    Write-BuildLog "Checking ps2exe module..."

    $isInstalled = Test-PS2EXE

    if ($isInstalled -and -not $ForceReinstall) {
        Write-BuildLog "ps2exe module is already installed" -Level Success

        $module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
        Write-BuildLog "Version: $($module.Version)" -Level Debug
        Write-BuildLog "Path: $($module.ModuleBase)" -Level Debug

        return $true
    }

    if ($ForceReinstall) {
        Write-BuildLog "Force reinstalling ps2exe module..."
    } else {
        Write-BuildLog "Installing ps2exe module..."
    }

    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
        Write-BuildLog "ps2exe module installed successfully" -Level Success

        $module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
        Write-BuildLog "Installed version: $($module.Version)" -Level Debug

        return $true
    } catch {
        Write-BuildLog "Failed to install ps2exe: $($_.Exception.Message)" -Level Error
        return $false
    }
}

try {
    Write-BuildLog "Focus Game Deck - Build Dependencies Installer"

    $success = Install-PS2EXE -ForceReinstall $Force

    if ($success) {
        Write-BuildLog "Build environment setup completed successfully" -Level Success
        exit 0
    } else {
        Write-BuildLog "Build environment setup failed" -Level Error
        exit 1
    }
} catch {
    Write-BuildLog "Unexpected error: $($_.Exception.Message)" -Level Error
    exit 1
}
