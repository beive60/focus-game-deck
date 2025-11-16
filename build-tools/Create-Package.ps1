<#
.SYNOPSIS
    Create final distribution package

.DESCRIPTION
    Assembles all build artifacts into the final distribution package in the release/ directory.
    Collects signed executables, copied resources, and creates package documentation.

    Creates a complete, ready-to-distribute package with:
    - All executables (signed or unsigned)
    - Configuration files
    - Localization resources
    - GUI assets
    - Documentation and version information

.PARAMETER SourceDir
    Source directory containing built artifacts (default: build-tools/dist)

.PARAMETER DestinationDir
    Destination directory for the release package (default: release/)

.PARAMETER IsSigned
    Indicates whether the executables are digitally signed

.PARAMETER Version
    Version string for the package (default: read from Version.ps1)

.PARAMETER Verbose
    Enable verbose output for detailed packaging progress

.EXAMPLE
    .\Create-Package.ps1
    Creates release package from default dist directory

.EXAMPLE
    .\Create-Package.ps1 -IsSigned -Version "3.0.0"
    Creates signed release package with explicit version

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
    Responsibility: Create the final distribution package (SRP)
#>

#Requires -Version 5.1

param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "dist"),
    [string]$DestinationDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "release"),
    [switch]$IsSigned,
    [string]$Version = "",
    [switch]$Verbose
)

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-PackageMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    Write-Host "[$Level] $Message"
}

function Get-ProjectVersion {
    $versionScript = Join-Path $PSScriptRoot "Version.ps1"

    if (Test-Path $versionScript) {
        try {
            . $versionScript
            return Get-ProjectVersion -IncludePreRelease
        } catch {
            Write-Verbose "Failed to get version from Version.ps1: $($_.Exception.Message)"
        }
    }

    return "3.0.0"
}

function New-ReleaseReadme {
    param(
        [string]$Version,
        [bool]$IsSigned,
        [string]$BuildDate
    )

    $readme = @"
# Focus Game Deck - Release Package

**Version:** $Version
**Build Date:** $BuildDate
**Signed:** $(if ($IsSigned) { "Yes" } else { "No" })

## Files Included

- **Focus-Game-Deck.exe**: Main router executable
- **ConfigEditor.exe**: GUI configuration editor (bundled)
- **Invoke-FocusGameDeck.exe**: Game launcher engine (bundled)
- **config/**: Configuration files and templates
- **localization/**: Localization resources
- **gui/**: GUI XAML files

## Installation

1. Extract all files to a directory of your choice
2. Run Focus-Game-Deck.exe (without arguments) to open the configuration editor
3. Use Focus-Game-Deck.exe [GameId] to launch games with optimized settings

## Multi-Executable Bundle Architecture

This release uses a secure multi-executable architecture:
- All executed code is contained within digitally signed executables
- No external unsigned scripts are executed
- Each component is a fully bundled, self-contained executable

## Documentation

For complete documentation, visit:
https://github.com/beive60/focus-game-deck

## License

This software is released under the MIT License.
"@

    return $readme
}

function New-VersionInfo {
    param(
        [string]$Version,
        [bool]$IsSigned,
        [string]$BuildDate,
        [string]$ReleaseDir
    )

    $versionInfo = @{
        version = $Version
        buildDate = $BuildDate
        isSigned = $IsSigned
        architecture = "multi-executable-bundle"
        executables = @()
        resources = @()
    }

    Get-ChildItem $ReleaseDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Replace($ReleaseDir, "").TrimStart('\', '/')
        $fileInfo = @{
            path = $relativePath
            size = $_.Length
            lastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }

        if ($_.Extension -eq ".exe") {
            $signature = Get-AuthenticodeSignature -FilePath $_.FullName
            $fileInfo.Add("signatureStatus", $signature.Status.ToString())
            if ($signature.SignerCertificate) {
                $fileInfo.Add("signerCertificate", $signature.SignerCertificate.Subject)
            }
            $versionInfo.executables += $fileInfo
        } else {
            $versionInfo.resources += $fileInfo
        }
    }

    return $versionInfo
}

try {
    Write-Host "Focus Game Deck - Package Creator"
    Write-Host "=" * 50

    if (-not (Test-Path $SourceDir)) {
        Write-PackageMessage "Source directory not found: $SourceDir" "ERROR"
        Write-PackageMessage "Please run Build-Executables.ps1 and Copy-Resources.ps1 first" "ERROR"
        exit 1
    }

    if ([string]::IsNullOrEmpty($Version)) {
        $Version = Get-ProjectVersion
        Write-Verbose "Using version: $Version"
    }

    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-PackageMessage "Creating release package..." "INFO"
    Write-Verbose "  Source: $SourceDir"
    Write-Verbose "  Destination: $DestinationDir"
    Write-Verbose "  Version: $Version"
    Write-Verbose "  Signed: $IsSigned"

    if (Test-Path $DestinationDir) {
        Write-PackageMessage "Cleaning existing release directory..." "INFO"
        Remove-Item $DestinationDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null

    Write-PackageMessage "Copying files to release directory..." "INFO"
    Copy-Item -Path "$SourceDir/*" -Destination $DestinationDir -Recurse -Force

    $fileCount = (Get-ChildItem $DestinationDir -Recurse -File).Count
    Write-PackageMessage "Copied $fileCount files" "SUCCESS"

    Write-PackageMessage "Creating release documentation..." "INFO"
    $readmeContent = New-ReleaseReadme -Version $Version -IsSigned $IsSigned -BuildDate $buildDate
    $readmePath = Join-Path $DestinationDir "README.txt"
    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
    Write-Verbose "  Created: README.txt"

    $versionInfo = New-VersionInfo -Version $Version -IsSigned $IsSigned -BuildDate $buildDate -ReleaseDir $DestinationDir
    $versionInfoPath = Join-Path $DestinationDir "version-info.json"
    $versionInfo | ConvertTo-Json -Depth 10 | Set-Content -Path $versionInfoPath -Encoding UTF8
    Write-Verbose "  Created: version-info.json"

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "PACKAGE SUMMARY"
    Write-Host "=" * 50

    Write-Host "Version: $Version"
    Write-Host "Build Date: $buildDate"
    Write-Host "Signed: $(if ($IsSigned) { 'Yes' } else { 'No' })"
    Write-Host "Location: $DestinationDir"

    Write-Host ""
    Write-Host "Executables:"
    Get-ChildItem $DestinationDir -Filter "*.exe" -Recurse | ForEach-Object {
        $fileSize = [math]::Round($_.Length / 1KB, 1)
        $signature = Get-AuthenticodeSignature -FilePath $_.FullName
        $signStatus = if ($signature.Status -eq "Valid") { "(signed)" } else { "(unsigned)" }
        Write-Host "  $($_.Name) ($fileSize KB) $signStatus"
    }

    Write-Host ""
    Write-Host "Total package size: $([math]::Round((Get-ChildItem $DestinationDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB"

    Write-Host ""
    Write-PackageMessage "Release package created successfully!" "SUCCESS"
    exit 0

} catch {
    Write-PackageMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    Write-Verbose $_.ScriptStackTrace
    exit 1
}
