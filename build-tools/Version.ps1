<#
.SYNOPSIS
    Focus Game Deck centralized version management system

.DESCRIPTION
    This script serves as the single source of truth for version information
    across all components of Focus Game Deck. It provides functions for version
    retrieval, comparison, and GitHub repository information management.

    The script follows semantic versioning (SemVer) principles and supports
    pre-release and build metadata for comprehensive version tracking.

.FUNCTIONALITY
    Version Management:
    - Get-ProjectVersion: Retrieves formatted version strings
    - Get-ProjectVersionInfo: Returns complete version information object
    - Compare-Version: Compares two semantic version strings

    Repository Information:
    - Get-GitHubRepositoryInfo: Returns GitHub repository details

    Version Format:
    - Standard: MAJOR.MINOR.PATCH (e.g., "1.0.1")
    - Pre-release: MAJOR.MINOR.PATCH-PRERELEASE (e.g., "1.0.1-alpha")
    - Build: MAJOR.MINOR.PATCH-PRERELEASE+BUILD (e.g., "1.0.1-alpha+20241104")

.EXAMPLE
    . .\Version.ps1
    $version = Get-ProjectVersion
    Write-Host "Current version: $version"

    Dot-sources the script and gets the current project version.

.EXAMPLE
    . .\Version.ps1
    $fullVersion = Get-ProjectVersion -IncludePreRelease -IncludeBuild
    Write-Host "Full version: $fullVersion"

    Gets the complete version string including pre-release and build information.

.EXAMPLE
    . .\Version.ps1
    $versionInfo = Get-ProjectVersionInfo
    Write-Host "Is pre-release: $($versionInfo.IsPreRelease)"

    Gets detailed version information including pre-release status.

.EXAMPLE
    . .\Version.ps1
    $comparison = Compare-Version "1.0.0" "1.0.1"
    # Returns -1 (first version is lower)

    Compares two version strings using semantic versioning rules.

.EXAMPLE
    . .\Version.ps1
    $repoInfo = Get-GitHubRepositoryInfo
    Write-Host "Repository: $($repoInfo.Owner)/$($repoInfo.Name)"

    Gets GitHub repository information for API calls and integrations.

.NOTES
    Version: 1.0.0
    Author: Focus Game Deck Development Team
    Date: 2025-09-24

    Usage Pattern:
    This script is designed to be dot-sourced by other scripts that need
    version information. All functions become available in the calling scope.

    Semantic Versioning Rules:
    - MAJOR: Incompatible API changes
    - MINOR: Backwards-compatible functionality additions
    - PATCH: Backwards-compatible bug fixes
    - PRERELEASE: Optional pre-release identifier (alpha, beta, rc1, etc.)
    - BUILD: Optional build metadata

    Version Comparison:
    - Returns -1 if Version1 < Version2
    - Returns 0 if Version1 = Version2
    - Returns 1 if Version1 > Version2
    - Pre-release versions are considered lower than release versions

    Integration:
    This script integrates with build systems, release management,
    and GitHub API interactions throughout the project.
#>

# Project version information
$script:ProjectVersion = @{
    Major = 1
    Minor = 0
    Patch = 1
    PreRelease = "alpha"  # Can be "", "alpha", "beta", "rc1", etc.
    Build = ""
}

# GitHub repository information
$script:GitHubRepository = @{
    Owner = "beive60"
    Name = "focus-game-deck"
    ApiUrl = "https://api.github.com/repos/beive60/focus-game-deck"
}

# Get formatted version string
function Get-ProjectVersion {
    param(
        [switch]$IncludePreRelease,
        [switch]$IncludeBuild
    )

    $version = "$($script:ProjectVersion.Major).$($script:ProjectVersion.Minor).$($script:ProjectVersion.Patch)"

    if ($IncludePreRelease -and $script:ProjectVersion.PreRelease) {
        $version += "-$($script:ProjectVersion.PreRelease)"
    }

    if ($IncludeBuild -and $script:ProjectVersion.Build) {
        $version += "+$($script:ProjectVersion.Build)"
    }

    return $version
}

# Get full version information object
function Get-ProjectVersionInfo {
    return @{
        Version = Get-ProjectVersion
        FullVersion = Get-ProjectVersion -IncludePreRelease -IncludeBuild
        Major = $script:ProjectVersion.Major
        Minor = $script:ProjectVersion.Minor
        Patch = $script:ProjectVersion.Patch
        PreRelease = $script:ProjectVersion.PreRelease
        Build = $script:ProjectVersion.Build
        IsPreRelease = [bool]$script:ProjectVersion.PreRelease
    }
}

# Get GitHub repository information
function Get-GitHubRepositoryInfo {
    return $script:GitHubRepository
}

# Compare two version strings (semantic versioning)
function Compare-Version {
    param(
        [string]$Version1,
        [string]$Version2
    )

    try {
        # Parse versions (remove pre-release and build info for basic comparison)
        $v1Parts = ($Version1 -split '-')[0] -split '/.'
        $v2Parts = ($Version2 -split '-')[0] -split '/.'

        # Ensure we have at least 3 parts (major.minor.patch)
        while ($v1Parts.Count -lt 3) { $v1Parts += "0" }
        while ($v2Parts.Count -lt 3) { $v2Parts += "0" }

        # Compare each part
        for ($i = 0; $i -lt 3; $i++) {
            $v1Num = [int]$v1Parts[$i]
            $v2Num = [int]$v2Parts[$i]

            if ($v1Num -lt $v2Num) { return -1 }
            if ($v1Num -gt $v2Num) { return 1 }
        }

        # If base versions are equal, check pre-release
        $v1Pre = ($Version1 -split '-', 2)[1]
        $v2Pre = ($Version2 -split '-', 2)[1]

        # No pre-release is higher than pre-release
        if (-not $v1Pre -and $v2Pre) { return 1 }
        if ($v1Pre -and -not $v2Pre) { return -1 }
        if (-not $v1Pre -and -not $v2Pre) { return 0 }

        # Both have pre-release, compare alphabetically
        return [string]::Compare($v1Pre, $v2Pre)

    } catch {
        Write-Warning "Error comparing versions '$Version1' and '$Version2': $($_.Exception.Message)"
        return 0
    }
}

# Note: Export-ModuleMember is not needed when dot-sourcing the script
# These functions are automatically available when the script is dot-sourced
