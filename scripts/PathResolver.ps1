# Path Resolution Helper - Common path resolution functions for Focus Game Deck
# Focus Game Deck Project
# Author: Focus Game Deck Team
# Version: 1.0.0
# Date: 2026-01-30

<#
.SYNOPSIS
    Common path resolution functions for Focus Game Deck

.DESCRIPTION
    This module provides unified path resolution logic that handles both:
    - Script execution mode (development)
    - Compiled executable mode (production)

    The module detects the execution environment and resolves paths accordingly,
    eliminating code duplication across entry points.

.NOTES
    Used by Main.PS1, ConfigEditor.ps1, Invoke-FocusGameDeck.ps1, and modules
#>

<#
.SYNOPSIS
    Detects if the script is running as a compiled ps2exe executable

.RETURNS
    Boolean - $true if running as executable, $false if running as script

.EXAMPLE
    $isExe = Test-IsExecutable
    if ($isExe) {
        Write-Host "Running as compiled executable"
    }
#>
function Test-IsExecutable {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $currentProcess = Get-Process -Id $PID
        $processName = $currentProcess.ProcessName.ToLower()
        return ($processName -ne 'pwsh' -and $processName -ne 'powershell')
    } catch {
        Write-Verbose "Failed to detect execution mode: $_. Assuming script mode."
        return $false
    }
}

<#
.SYNOPSIS
    Gets the application root directory based on execution environment

.DESCRIPTION
    Resolves the application root directory:
    - In executable mode: Directory where the .exe file is located
    - In script mode: Calculated relative to PSScriptRoot

.PARAMETER CallerScriptRoot
    The $PSScriptRoot value from the calling script

.PARAMETER RelativeDepth
    Number of directory levels up from CallerScriptRoot to reach app root (default: 1)
    - Use 1 for scripts in /src, /gui, /scripts
    - Use 2 for scripts in /src/modules

.RETURNS
    String - The absolute path to the application root directory

.EXAMPLE
    # From gui/ConfigEditor.ps1 (one level up to reach app root)
    $appRoot = Get-AppRoot -CallerScriptRoot $PSScriptRoot

.EXAMPLE
    # From src/modules/AppManager.ps1 (two levels up to reach app root)
    $appRoot = Get-AppRoot -CallerScriptRoot $PSScriptRoot -RelativeDepth 2
#>
function Get-AppRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CallerScriptRoot,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 5)]
        [int]$RelativeDepth = 1
    )

    $isExecutable = Test-IsExecutable

    if ($isExecutable) {
        # In executable mode, the root is the directory where the .exe file is located
        $currentProcess = Get-Process -Id $PID
        $appRoot = Split-Path -Parent $currentProcess.Path
    } else {
        # In script mode, calculate relative to caller's location
        $appRoot = $CallerScriptRoot
        for ($i = 0; $i -lt $RelativeDepth; $i++) {
            $appRoot = Split-Path -Parent $appRoot
        }
    }

    Write-Verbose "Resolved appRoot: $appRoot (isExecutable: $isExecutable)"
    return $appRoot
}

<#
.SYNOPSIS
    Gets common resource paths based on application root

.DESCRIPTION
    Returns a hashtable containing paths to commonly used resources:
    - ConfigPath: config/config.json
    - LocalizationDir: localization/
    - MessagesPath: localization/messages.json (legacy)
    - GuiPath: gui/
    - ModulesPath: src/modules/

.PARAMETER AppRoot
    The application root directory

.RETURNS
    Hashtable containing resolved paths

.EXAMPLE
    $appRoot = Get-AppRoot -CallerScriptRoot $PSScriptRoot
    $paths = Get-ResourcePaths -AppRoot $appRoot
    $config = Get-Content $paths.ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
#>
function Get-ResourcePaths {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppRoot
    )

    return @{
        ConfigPath = Join-Path -Path $AppRoot -ChildPath "config/config.json"
        LocalizationDir = Join-Path -Path $AppRoot -ChildPath "localization"
        MessagesPath = Join-Path -Path $AppRoot -ChildPath "localization/messages.json"
        GuiPath = Join-Path -Path $AppRoot -ChildPath "gui"
        ModulesPath = Join-Path -Path $AppRoot -ChildPath "src/modules"
        ScriptsPath = Join-Path -Path $AppRoot -ChildPath "scripts"
        BuildToolsPath = Join-Path -Path $AppRoot -ChildPath "build-tools"
    }
}

<#
.SYNOPSIS
    Initializes path resolution context for the application

.DESCRIPTION
    Convenience function that combines Test-IsExecutable, Get-AppRoot,
    and Get-ResourcePaths into a single call.

.PARAMETER CallerScriptRoot
    The $PSScriptRoot value from the calling script

.PARAMETER RelativeDepth
    Number of directory levels up from CallerScriptRoot to reach app root

.RETURNS
    PSCustomObject containing:
    - IsExecutable: Boolean indicating execution mode
    - AppRoot: Application root directory
    - Paths: Hashtable of resource paths

.EXAMPLE
    $context = Initialize-PathContext -CallerScriptRoot $PSScriptRoot
    $config = Get-Content $context.Paths.ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
#>
function Initialize-PathContext {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CallerScriptRoot,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 5)]
        [int]$RelativeDepth = 1
    )

    $isExecutable = Test-IsExecutable
    $appRoot = Get-AppRoot -CallerScriptRoot $CallerScriptRoot -RelativeDepth $RelativeDepth
    $paths = Get-ResourcePaths -AppRoot $appRoot

    return [PSCustomObject]@{
        IsExecutable = $isExecutable
        AppRoot = $appRoot
        Paths = $paths
    }
}

# Export functions for module usage
# Export-ModuleMember -Function Test-IsExecutable, Get-AppRoot, Get-ResourcePaths, Initialize-PathContext
