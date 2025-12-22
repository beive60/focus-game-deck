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

# Import the BuildLogger at script level
. "$PSScriptRoot/utils/BuildLogger.ps1"

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-PackageMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    Write-BuildLog "[$Level] $Message"
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
        [string]$BuildDate,
        [string]$Language = "en"
    )

    # Load localized content from JSON file
    $readmeStringsPath = Join-Path -Path $PSScriptRoot -ChildPath "resources/readme-strings.json"
    if (-not (Test-Path $readmeStringsPath)) {
        Write-Verbose "README strings file not found: $readmeStringsPath"
        throw "README strings file not found: $readmeStringsPath"
    }

    try {
        $localizedContent = Get-Content $readmeStringsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Verbose "Failed to load README strings: $($_.Exception.Message)"
        throw "Failed to load README strings: $($_.Exception.Message)"
    }

    # Get localized strings, fall back to English if language not found
    # Use PSObject.Properties to access keys with special characters (e.g., zh-CN)
    $langProperty = $localizedContent.PSObject.Properties[$Language]
    $strings = if ($langProperty) { $langProperty.Value } else { $null }

    if (-not $strings) {
        $enProperty = $localizedContent.PSObject.Properties['en']
        $strings = if ($enProperty) { $enProperty.Value } else { $null }

        if (-not $strings) {
            throw "Failed to load strings for language '$Language' and fallback 'en' language not found"
        }
    }

    # Validate that all required keys exist
    $requiredKeys = @(
        "title", "version", "buildDate", "signed", "yes", "no",
        "filesIncluded", "configEditor", "mainApp", "scriptExecutor",
        "localization", "readme", "installation", "step1", "step2",
        "step3", "step4", "architecture", "archIntro", "arch1",
        "arch2", "arch3", "documentation", "docText", "license",
        "licenseText"
    )

    $missingKeys = @()
    foreach ($key in $requiredKeys) {
        # Use PSObject.Properties to ensure consistent access
        $keyProperty = $strings.PSObject.Properties[$key]
        if (-not $keyProperty -or -not $keyProperty.Value) {
            $missingKeys += $key
        }
    }

    if ($missingKeys.Count -gt 0) {
        $missingKeysList = $missingKeys -join ", "
        throw "Required keys missing in README strings for language '$Language': $missingKeysList"
    }

    $readme = @(
        "# $($strings.title)"
        ""
        "**$($strings.version):** $Version"
        "**$($strings.buildDate):** $BuildDate"
        "**$($strings.signed):** $(if ($IsSigned) { $strings.yes } else { $strings.no })"
        ""
        "## $($strings.filesIncluded)"
        ""
        "- **ConfigEditor.exe**: $($strings.configEditor)"
        "- **Focus-Game-Deck.exe**: $($strings.mainApp)"
        "- **Invoke-FocusGameDeck.exe**: $($strings.scriptExecutor)"
        "- **localization/messages.json**: $($strings.localization)"
        "- **README.txt**: $($strings.readme)"
        ""
        "## $($strings.installation)"
        ""
        "1. $($strings.step1)"
        "2. $($strings.step2)"
        "3. $($strings.step3)"
        "4. $($strings.step4)"
        ""
        "## $($strings.architecture)"
        ""
        "$($strings.archIntro)"
        "- $($strings.arch1)"
        "- $($strings.arch2)"
        "- $($strings.arch3)"
        ""
        "## $($strings.documentation)"
        ""
        "$($strings.docText)"
        "https://github.com/beive60/focus-game-deck"
        ""
        "## $($strings.license)"
        ""
        "$($strings.licenseText)"
    ) -join "`n"

    return $readme
}

try {
    Write-BuildLog "Focus Game Deck - Package Creator"
    # Separator removed

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

    # Copy only required executables
    $executablesToCopy = @(
        "ConfigEditor.exe",
        "Focus-Game-Deck.exe",
        "Invoke-FocusGameDeck.exe"
    )

    foreach ($exe in $executablesToCopy) {
        $sourcePath = Join-Path $SourceDir $exe
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $DestinationDir -Force
            Write-Verbose "  Copied: $exe"
        } else {
            Write-PackageMessage "Warning: $exe not found in source directory" "WARN"
        }
    }

    # Copy localization files (individual language files + manifest.json, and legacy messages.json if exists)
    $localizationDir = Join-Path $DestinationDir "localization"
    New-Item -ItemType Directory -Path $localizationDir -Force | Out-Null

    $localizationSourceDir = Join-Path $SourceDir "localization"
    if (Test-Path $localizationSourceDir) {
        # Copy all JSON files (en.json, ja.json, manifest.json, etc.)
        $jsonFiles = Get-ChildItem -Path $localizationSourceDir -Filter "*.json" -File
        if ($jsonFiles) {
            foreach ($file in $jsonFiles) {
                Copy-Item -Path $file.FullName -Destination $localizationDir -Force
                Write-Verbose "  Copied: localization/$($file.Name)"
            }
        } else {
            Write-PackageMessage "Warning: No localization JSON files found in $localizationSourceDir" "WARN"
        }
    } else {
        Write-PackageMessage "Warning: localization directory not found: $localizationSourceDir" "WARN"
    }

    # Copy scripts folder
    $scriptsSourceDir = Join-Path $SourceDir "scripts"
    $scriptsDestDir = Join-Path $DestinationDir "scripts"
    if (Test-Path $scriptsSourceDir) {
        New-Item -ItemType Directory -Path $scriptsDestDir -Force | Out-Null
        Copy-Item -Path "$scriptsSourceDir\*" -Destination $scriptsDestDir -Recurse -Force
        Write-Verbose "  Copied: scripts folder"
    } else {
        Write-PackageMessage "Warning: scripts folder not found" "WARN"
    }

    $fileCount = (Get-ChildItem $DestinationDir -Recurse -File).Count
    Write-PackageMessage "Copied $fileCount files" "SUCCESS"

    Write-PackageMessage "Creating release documentation..." "INFO"

    # Create language-specific versions for all supported languages
    $languages = @("en", "ja", "zh-CN", "ru", "fr", "es", "id-ID", "pt-BR")
    foreach ($lang in $languages) {
        $langReadmeContent = New-ReleaseReadme -Version $Version -IsSigned $IsSigned -BuildDate $buildDate -Language $lang

        # Create in source directory (dist)
        $sourceLangReadmePath = Join-Path $SourceDir "README.$lang.txt"
        [System.IO.File]::WriteAllText($sourceLangReadmePath, $langReadmeContent)
        Write-Verbose "  Created: README.$lang.txt in source directory"

        # Create in destination directory (release)
        $destLangReadmePath = Join-Path $DestinationDir "README.$lang.txt"
        [System.IO.File]::WriteAllText($destLangReadmePath, $langReadmeContent)
        Write-Verbose "  Created: README.$lang.txt in release directory"
    }

    Write-Host ""
    # Separator removed
    Write-BuildLog "PACKAGE SUMMARY"
    # Separator removed

    Write-BuildLog "Version: $Version"
    Write-BuildLog "Build Date: $buildDate"
    Write-BuildLog "Signed: $(if ($IsSigned) { 'Yes' } else { 'No' })"
    Write-BuildLog "Location: $DestinationDir"

    Write-Host ""
    Write-BuildLog "Executables:"
    Get-ChildItem $DestinationDir -Filter "*.exe" -Recurse | ForEach-Object {
        $fileSize = [math]::Round($_.Length / 1KB, 1)
        $signStatus = "(unknown)"
        try {
            $signature = Get-AuthenticodeSignature -FilePath $_.FullName -ErrorAction Stop
            $signStatus = if ($signature.Status -eq "Valid") { "(signed)" } else { "(unsigned)" }
        } catch {
            Write-Verbose "Could not check signature for $($_.Name): $($_.Exception.Message)"
            $signStatus = "(signature check failed)"
        }
        Write-BuildLog "  $($_.Name) ($fileSize KB) $signStatus"
    }

    Write-Host ""
    Write-BuildLog "Total package size: $([math]::Round((Get-ChildItem $DestinationDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB"

    Write-Host ""
    Write-PackageMessage "Release package created successfully!" "SUCCESS"
    exit 0

} catch {
    Write-PackageMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    Write-Verbose $_.ScriptStackTrace
    exit 1
}
