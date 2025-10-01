# Focus Game Deck - Version Information
# Centralized version management for the project
#
# This file serves as the single source of truth for version information
# across all components of Focus Game Deck.
#
# Author: GitHub Copilot Assistant
# Version: 1.0.0
# Date: 2025-09-24

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
