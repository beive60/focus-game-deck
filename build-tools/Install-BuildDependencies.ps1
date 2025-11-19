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

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-BuildMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    Write-Host "[$Level] $Message"
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

    Write-BuildMessage "Checking ps2exe module..." "INFO"

    $isInstalled = Test-PS2EXE

    if ($isInstalled -and -not $ForceReinstall) {
        Write-BuildMessage "ps2exe module is already installed" "SUCCESS"

        $module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
        Write-Verbose "Version: $($module.Version)"
        Write-Verbose "Path: $($module.ModuleBase)"

        return $true
    }

    if ($ForceReinstall) {
        Write-BuildMessage "Force reinstalling ps2exe module..." "INFO"
    } else {
        Write-BuildMessage "Installing ps2exe module..." "INFO"
    }

    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
        Write-BuildMessage "ps2exe module installed successfully" "SUCCESS"

        $module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
        Write-Verbose "Installed version: $($module.Version)"

        return $true
    } catch {
        Write-BuildMessage "Failed to install ps2exe: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

try {
    Write-Host "Focus Game Deck - Build Dependencies Installer"
    Write-Host ("=" * 60)

    $success = Install-PS2EXE -ForceReinstall $Force

    Write-Host ""
    if ($success) {
        Write-BuildMessage "Build environment setup completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-BuildMessage "Build environment setup failed" "ERROR"
        exit 1
    }
} catch {
    Write-BuildMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    exit 1
}
