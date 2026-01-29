# Focus Game Deck - Version Helper
# Helper script for common version management tasks
#
# This script provides convenient functions for version-related operations
# such as checking current version, validating releases, and managing tags.
#
# Author: GitHub Copilot Assistant
# Version: 1.0.0
# Date: 2025-09-24

param(
    [Parameter(Position = 0)]
    [ValidateSet("info", "check", "list-tags", "validate", "next", "help")]
    [string]$Action = "help",

    [Parameter(Position = 1)]
    [string]$Parameter = ""
)

# Import version module
$VersionModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "build-tools/Version.ps1"
if (Test-Path $VersionModulePath) {
    . $VersionModulePath
} else {
    throw "Version module not found: $VersionModulePath"
}

function Show-VersionInfo {
    Write-Host "=== Focus Game Deck Version Information ==="

    $versionInfo = Get-ProjectVersionInfo
    $repoInfo = Get-GitHubRepositoryInfo

    Write-Host "Current Version: " -NoNewline
    Write-Host $versionInfo.FullVersion

    Write-Host "Components:"
    Write-Host "  Major: $($versionInfo.Major)"
    Write-Host "  Minor: $($versionInfo.Minor)"
    Write-Host "  Patch: $($versionInfo.Patch)"
    Write-Host "  Pre-release: $(if ($versionInfo.PreRelease) { $versionInfo.PreRelease } else { 'None' })"
    Write-Host "  Build: $(if ($versionInfo.Build) { $versionInfo.Build } else { 'None' })"

    Write-Host "Release Type: " -NoNewline
    if ($versionInfo.IsPreRelease) {
        Write-Host "Pre-release"
    } else {
        Write-Host "Stable"
    }

    Write-Host "Repository:"
    Write-Host "  Owner: $($repoInfo.Owner)"
    Write-Host "  Name: $($repoInfo.Name)"
    Write-Host "  API URL: $($repoInfo.ApiUrl)"
}

function Test-ReleaseValidation {
    Write-Host "=== Release Validation ==="

    $errors = @()
    $warnings = @()

    # Check git repository status
    try {
        $gitStatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -eq 0) {
            if ($gitStatus) {
                $warnings += "Uncommitted changes detected"
                $gitStatus | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host "[OK] Git repository is clean"
            }

            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            Write-Host "[OK] Current branch: $branch"
        } else {
            $errors += "Not a git repository"
        }
    } catch {
        $errors += "Git validation failed: $($_.Exception.Message)"
    }

    # Check version file integrity
    try {
        $versionInfo = Get-ProjectVersionInfo
        Write-Host "[OK] Version file is valid"
        Write-Host "  Current version: $($versionInfo.FullVersion)"
    } catch {
        $errors += "Version file validation failed: $($_.Exception.Message)"
    }

    # Check for required files
    $requiredFiles = @(
        "build-tools/Version.ps1",
        "README.md",
        "LICENSE.md",
        "CONTRIBUTING.md"
    )

    $rootPath = Split-Path $PSScriptRoot -Parent
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $rootPath $file
        if (Test-Path $filePath) {
            Write-Host "[OK] Required file exists: $file"
        } else {
            $warnings += "Required file missing: $file"
        }
    }

    # Check documentation files
    $docsPath = Join-Path $rootPath "docs"
    $requiredDocs = @(
        "project-info/version-management.md",
        "developer-guide/release-process.md",
        "developer-guide/architecture.md"
    )

    foreach ($doc in $requiredDocs) {
        $docPath = Join-Path $docsPath $doc
        if (Test-Path $docPath) {
            Write-Host "[OK] Documentation exists: $doc"
        } else {
            $warnings += "Documentation missing: $doc"
        }
    }

    # Summary
    Write-Host "=== Validation Summary ==="

    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "[SUCCESS] All validations passed! Ready for release."
        return $true
    } else {
        if ($errors.Count -gt 0) {
            Write-Host "[ERROR] Errors found:"
            $errors | ForEach-Object { Write-Host "  - $_" }
        }

        if ($warnings.Count -gt 0) {
            Write-Host "[WARNING] Warnings:"
            $warnings | ForEach-Object { Write-Host "  - $_" }
        }

        return $false
    }
}

function Get-GitTags {
    Write-Host "=== Git Tags ==="

    try {
        $tags = git tag --sort=-version:refname 2>$null
        if ($LASTEXITCODE -eq 0 -and $tags) {
            Write-Host "Recent tags (sorted by version):"
            $tags | Select-Object -First 10 | ForEach-Object {
                $tagInfo = git show --format="%ai %s" --no-patch $_ 2>$null
                if ($tagInfo) {
                    $date = ($tagInfo -split ' ')[0]
                    $message = ($tagInfo -split ' ', 4)[3]
                    Write-Host "  $_ " -NoNewline
                    Write-Host "($date) " -NoNewline
                    Write-Host $message
                }
            }
        } else {
            Write-Host "No tags found in repository"
        }
    } catch {
        Write-Host "Error retrieving git tags: $($_.Exception.Message)"
    }
}

function Show-NextVersions {
    Write-Host "=== Next Version Options ==="

    $current = Get-ProjectVersionInfo
    Write-Host "Current version: $($current.FullVersion)"

    # Calculate different version bump options
    $major = @{ Major = $current.Major + 1; Minor = 0; Patch = 0; PreRelease = "" }
    $minor = @{ Major = $current.Major; Minor = $current.Minor + 1; Patch = 0; PreRelease = "" }
    $patch = @{ Major = $current.Major; Minor = $current.Minor; Patch = $current.Patch + 1; PreRelease = "" }

    Write-Host "Release options:"
    Write-Host "  Major:  " -NoNewline
    Write-Host "$($major.Major).$($major.Minor).$($major.Patch)"
    Write-Host "  Minor:  " -NoNewline
    Write-Host "$($minor.Major).$($minor.Minor).$($minor.Patch)"
    Write-Host "  Patch:  " -NoNewline
    Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)"

    Write-Host "Pre-release options:"
    if ($current.PreRelease) {
        # Current is pre-release, show next in sequence
        if ($current.PreRelease -match '^(alpha|beta|rc)/.?(/d+)?$') {
            $type = $matches[1]
            $number = if ($matches[2]) { [int]$matches[2] + 1 } else { 1 }
            Write-Host "  Next $type" -NoNewline
            Write-Host ": $($current.Major).$($current.Minor).$($current.Patch)-$type.$number"
        }

        # Show progression options
        Write-Host "  Alpha:  " -NoNewline
        Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)-alpha"
        Write-Host "  Beta:   " -NoNewline
        Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)-beta"
        Write-Host "  RC:     " -NoNewline
        Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)-rc"
    } else {
        # Current is stable, show pre-release for next patch
        Write-Host "  Alpha:  " -NoNewline
        Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)-alpha"
        Write-Host "  Beta:   " -NoNewline
        Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)-beta"
        Write-Host "  RC:     " -NoNewline
        Write-Host "$($patch.Major).$($patch.Minor).$($patch.Patch)-rc"
    }
}

function Show-Help {
    Write-Host "Focus Game Deck - Version Helper"
    Write-Host "Usage: ./Version-Helper.ps1 <action> [parameter]"
    Write-Host ""
    Write-Host "Actions:"
    Write-Host "  info        Show current version information"
    Write-Host "  check       Perform release validation checks"
    Write-Host "  list-tags   List git tags in the repository"
    Write-Host "  validate    Validate release readiness"
    Write-Host "  next        Show next version options"
    Write-Host "  help        Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  ./Version-Helper.ps1 info"
    Write-Host "  ./Version-Helper.ps1 check"
    Write-Host "  ./Version-Helper.ps1 list-tags"
    Write-Host "  ./Version-Helper.ps1 next"
    Write-Host ""
    Write-Host "For release management, use Release-Manager.ps1"
}

# Main execution
switch ($Action) {
    "info" { Show-VersionInfo }
    "check" { Test-ReleaseValidation }
    "validate" { Test-ReleaseValidation }
    "list-tags" { Get-GitTags }
    "next" { Show-NextVersions }
    "help" { Show-Help }
    default { Show-Help }
}
