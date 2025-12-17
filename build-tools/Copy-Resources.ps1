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

# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-CopyMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    Write-Host "[$Level] $Message"
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
        Write-BuildLog "Source not found: $SourcePath" -Level Warning
        return $false
    }

    Write-BuildLog "Copying $Description..."
    Write-BuildLog "  From: $SourcePath" -Level Debug
    Write-BuildLog "  To: $DestPath" -Level Debug

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
                    Write-BuildLog "  Copied: $($file.Name)" -Level Debug
                    $fileCount++
                }
            }
        }

        Write-BuildLog "Copied $fileCount file(s) for $Description" -Level Success
        return $true
    } catch {
        Write-BuildLog "Failed to copy $Description : $($_.Exception.Message)" -Level Error
        return $false
    }
}

try {
    Write-BuildLog "Focus Game Deck - Resource Copier"

    if (-not (Test-Path $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
        Write-BuildLog "Created destination directory: $DestinationDir" -Level Debug
    }

    $copyResults = @()

    # Copy localization files (runtime resources)
    $localizationSource = Join-Path $SourceRoot "localization"
    $localizationDest = Join-Path $DestinationDir "localization"
    $copyResults += Copy-DirectoryContents `
        -SourcePath $localizationSource `
        -DestPath $localizationDest `
        -Include @("*.json") `
        -Exclude @("*.backup", "*diagnostic*") `
        -Description "localization files"

    # NOTE: Script files are no longer copied to release directory
    # Launcher scripts (Create-Launchers-Enhanced.ps1, Create-Launchers.ps1) are bundled
    # into ConfigEditor.exe via Invoke-PsScriptBundler.ps1
    # This eliminates external script file dependencies at runtime
    Write-Host ""
    Write-Verbose "Skipping script files (bundled in executable)"

    # NOTE: GUI XAML files are no longer copied to release directory
    # They are embedded in the executable via Embed-XamlResources.ps1 and XamlResources.ps1
    # This reduces release package size and removes external file dependencies
    Write-Verbose "Skipping GUI XAML files (embedded in executable)"

    Write-BuildLog "COPY SUMMARY"

    $successCount = ($copyResults | Where-Object { $_ -eq $true }).Count
    $totalCount = $copyResults.Count

    Write-BuildLog "Successful operations: $successCount / $totalCount"

    if ($successCount -eq $totalCount) {
        Write-BuildLog "All resources copied successfully!" -Level Success
        exit 0
    } else {
        Write-BuildLog "Some copy operations failed. Check errors above." -Level Warning
        exit 1
    }

} catch {
    Write-BuildLog "Unexpected error: $($_.Exception.Message)" -Level Error
    Write-BuildLog $_.ScriptStackTrace -Level Debug
    exit 1
}
