<#
.SYNOPSIS
    Copy non-executable runtime resources

.DESCRIPTION
    Copies all necessary runtime files that are not compiled into executables.
    This includes:
    - Configuration files (config.json, config.json.sample)
    - Localization files (messages.json)
    - XAML UI files (MainWindow.xaml, etc.)
    - Other supporting assets

.PARAMETER SourceRoot
    Root directory of the project (default: parent of build-tools)

.PARAMETER DestinationDir
    Destination directory for copied resources (default: build-tools/dist)

.PARAMETER Verbose
    Enable verbose output for detailed copy progress

.EXAMPLE
    .\Copy-Resources.ps1
    Copies all resources to default destination directory

.EXAMPLE
    .\Copy-Resources.ps1 -DestinationDir "custom/output"
    Copies resources to a custom destination directory

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
    Responsibility: Copy all non-executable assets (SRP)
#>

#Requires -Version 5.1

param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$DestinationDir = (Join-Path $PSScriptRoot "dist"),
    [switch]$Verbose
)

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-CopyMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }

    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Copy-DirectoryContents {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string[]]$Include = @("*"),
        [string[]]$Exclude = @(),
        [string]$Description
    )

    if (-not (Test-Path $SourcePath)) {
        Write-CopyMessage "Source not found: $SourcePath" "WARNING"
        return $false
    }

    Write-CopyMessage "Copying $Description..." "INFO"
    Write-Verbose "  From: $SourcePath"
    Write-Verbose "  To: $DestPath"

    if (-not (Test-Path $DestPath)) {
        New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
    }

    try {
        $fileCount = 0

        foreach ($pattern in $Include) {
            $files = Get-ChildItem -Path $SourcePath -Filter $pattern -File -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                $shouldExclude = $false
                foreach ($excludePattern in $Exclude) {
                    if ($file.Name -like $excludePattern) {
                        $shouldExclude = $true
                        break
                    }
                }

                if (-not $shouldExclude) {
                    Copy-Item -Path $file.FullName -Destination $DestPath -Force
                    Write-Verbose "  Copied: $($file.Name)"
                    $fileCount++
                }
            }
        }

        Write-CopyMessage "Copied $fileCount file(s) for $Description" "SUCCESS"
        return $true
    } catch {
        Write-CopyMessage "Failed to copy $Description : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

try {
    Write-Host "Focus Game Deck - Resource Copier"
    Write-Host "=" * 50

    if (-not (Test-Path $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
        Write-Verbose "Created destination directory: $DestinationDir"
    }

    $copyResults = @()

    Write-Host ""
    $configSource = Join-Path $SourceRoot "config"
    $configDest = Join-Path $DestinationDir "config"
    $copyResults += Copy-DirectoryContents `
        -SourcePath $configSource `
        -DestPath $configDest `
        -Include @("*.json", "*.json.sample") `
        -Description "configuration files"

    if (Test-Path (Join-Path $configSource "config.json.sample")) {
        $samplePath = Join-Path $configSource "config.json.sample"
        $destPath = Join-Path $configDest "config.json"
        Copy-Item -Path $samplePath -Destination $destPath -Force
        Write-Verbose "  Copied config.json.sample as config.json"
    }

    Write-Host ""
    $localizationSource = Join-Path $SourceRoot "localization"
    $localizationDest = Join-Path $DestinationDir "localization"
    $copyResults += Copy-DirectoryContents `
        -SourcePath $localizationSource `
        -DestPath $localizationDest `
        -Include @("*.json") `
        -Exclude @("*.backup", "*diagnostic*") `
        -Description "localization files"

    Write-Host ""
    $guiSource = Join-Path $SourceRoot "gui"
    $guiDest = Join-Path $DestinationDir "gui"
    $copyResults += Copy-DirectoryContents `
        -SourcePath $guiSource `
        -DestPath $guiDest `
        -Include @("*.xaml") `
        -Description "GUI XAML files"

    Write-Host ""
    $assetsSource = Join-Path $SourceRoot "assets"
    if (Test-Path $assetsSource) {
        $assetsDest = Join-Path $DestinationDir "assets"
        $copyResults += Copy-DirectoryContents `
            -SourcePath $assetsSource `
            -DestPath $assetsDest `
            -Include @("*.ico", "*.png", "*.jpg") `
            -Description "asset files"
    }

    Write-Host ""
    $docsFiles = @("README.md", "LICENSE.md")
    foreach ($docFile in $docsFiles) {
        $sourcePath = Join-Path $SourceRoot $docFile
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $DestinationDir -Force
            Write-CopyMessage "Copied: $docFile" "SUCCESS"
        }
    }

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "COPY SUMMARY"
    Write-Host "=" * 50

    $successCount = ($copyResults | Where-Object { $_ -eq $true }).Count
    $totalCount = $copyResults.Count

    Write-Host "Successful operations: $successCount / $totalCount"

    if ($successCount -eq $totalCount) {
        Write-CopyMessage "All resources copied successfully!" "SUCCESS"
        exit 0
    } else {
        Write-CopyMessage "Some copy operations failed. Check errors above." "WARNING"
        exit 1
    }

} catch {
    Write-CopyMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    Write-Verbose $_.ScriptStackTrace
    exit 1
}
