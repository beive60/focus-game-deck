<#
.SYNOPSIS
    Focus Game Deck master build script (compatibility wrapper)

.DESCRIPTION
    This is a compatibility wrapper for the moved Release-Manager.ps1 script.
    The actual build orchestration functionality has been moved to build-tools/Release-Manager.ps1
    for better organization of build-related scripts.

    This wrapper maintains backward compatibility for existing tasks, documentation,
    and command-line usage that reference the old location.

.PARAMETER Development
    Executes the development build workflow (no code signing).

.PARAMETER Production
    Executes the production build workflow (with code signing).

.PARAMETER Clean
    Removes all build artifacts and cache files.

.PARAMETER SetupOnly
    Only sets up the build environment without building.

.PARAMETER Verbose
    Enables verbose logging throughout the build process.

.NOTES
    DEPRECATED: This wrapper is provided for backward compatibility only.
    Please update your scripts and tasks to reference build-tools/Release-Manager.ps1 directly.

    Migration Path:
    Old: .\Release-Manager.ps1 -Development
    New: .\build-tools\Release-Manager.ps1 -Development

.EXAMPLE
    .\Release-Manager.ps1 -Development
    This will work as before, but internally uses build-tools/Release-Manager.ps1

.EXAMPLE
    .\Release-Manager.ps1 -Production
    This will work as before, but internally uses build-tools/Release-Manager.ps1
#>

param(
    [switch]$Development,
    [switch]$Production,
    [switch]$Clean,
    [switch]$SetupOnly,
    [switch]$Verbose
)

# Compatibility wrapper - forward all calls to the actual implementation
Write-Host "[COMPATIBILITY] Using Release-Manager.ps1 wrapper - please update to use build-tools/Release-Manager.ps1" -ForegroundColor Yellow

# Forward all parameters to the actual implementation
$actualReleaseManager = Join-Path $PSScriptRoot "build-tools/Release-Manager.ps1"

if (Test-Path $actualReleaseManager) {
    $forwardedArgs = @()

    if ($Development) { $forwardedArgs += "-Development" }
    if ($Production) { $forwardedArgs += "-Production" }
    if ($Clean) { $forwardedArgs += "-Clean" }
    if ($SetupOnly) { $forwardedArgs += "-SetupOnly" }
    if ($Verbose) { $forwardedArgs += "-Verbose" }

    # Execute the actual implementation with forwarded arguments
    & $actualReleaseManager @forwardedArgs

    # Forward the exit code
    exit $LASTEXITCODE
} else {
    Write-Error "Release-Manager.ps1 implementation not found at $actualReleaseManager"
    exit 1
}
