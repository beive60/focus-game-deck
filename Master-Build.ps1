# Focus Game Deck - Master Build Script
# This script orchestrates the complete build and signing process for all components

param(
    [switch]$Development,  # Build for development (no signing)
    [switch]$Production,   # Build for production (with signing)
    [switch]$Clean,        # Clean all build artifacts
    [switch]$SetupOnly,    # Only setup dependencies
    [switch]$Verbose
)

# Set verbose preference if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Script version and build info
$script:Version = "1.0.0"
$script:BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$script:StartTime = Get-Date

Write-Host "Focus Game Deck - Master Build Script v$script:Version" -ForegroundColor Cyan
Write-Host "Build started at: $script:BuildDate" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Function to log messages with timestamps
function Write-BuildLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )

    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $prefix = "[$timestamp] [$Level]"
    Write-Host "$prefix $Message" -ForegroundColor $Color
}

# Function to execute script with error handling
function Invoke-BuildScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$Description
    )

    Write-BuildLog "Starting: $Description" "INFO" "Yellow"

    if (-not (Test-Path $ScriptPath)) {
        Write-BuildLog "Script not found: $ScriptPath" "ERROR" "Red"
        return $false
    }

    try {
        $argumentString = $Arguments -join " "
        Write-BuildLog "Executing: $(Split-Path $ScriptPath -Leaf) $argumentString" "DEBUG" "Gray"

        $allArguments = @("-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $Arguments
        $process = Start-Process -FilePath "powershell" -ArgumentList $allArguments -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-BuildLog "Completed: $Description" "SUCCESS" "Green"
            return $true
        } else {
            Write-BuildLog "Failed: $Description (Exit Code: $($process.ExitCode))" "ERROR" "Red"
            return $false
        }
    } catch {
        Write-BuildLog "Exception in $Description : $($_.Exception.Message)" "ERROR" "Red"
        return $false
    }
}

# Function to clean all build artifacts
function Clear-BuildArtifacts {
    Write-BuildLog "Cleaning build artifacts..." "INFO" "Yellow"

    $pathsToClean = @(
        (Join-Path $PSScriptRoot "build"),
        (Join-Path $PSScriptRoot "signed"),
        (Join-Path $PSScriptRoot "gui\*.exe")
    )

    foreach ($path in $pathsToClean) {
        if (Test-Path $path) {
            try {
                if ((Get-Item $path) -is [System.IO.DirectoryInfo]) {
                    Remove-Item $path -Recurse -Force
                    Write-BuildLog "Removed directory: $path" "SUCCESS" "Green"
                } else {
                    Get-Item $path | Remove-Item -Force
                    Write-BuildLog "Removed files: $path" "SUCCESS" "Green"
                }
            } catch {
                Write-BuildLog "Failed to remove: $path - $($_.Exception.Message)" "ERROR" "Red"
            }
        }
    }
}

# Function to setup development environment
function Initialize-BuildEnvironment {
    Write-BuildLog "Setting up build environment..." "INFO" "Yellow"

    # Install ps2exe module
    $buildScript = Join-Path $PSScriptRoot "build-tools\Build-FocusGameDeck.ps1"
    return Invoke-BuildScript -ScriptPath $buildScript -Arguments @("-Install") -Description "Installing ps2exe module"
}

# Function to build all executables
function Build-AllExecutables {
    Write-BuildLog "Building all executables..." "INFO" "Yellow"

    $buildScript = Join-Path $PSScriptRoot "build-tools\Build-FocusGameDeck.ps1"
    return Invoke-BuildScript -ScriptPath $buildScript -Arguments @("-Build") -Description "Building all executables"
}

# Function to sign all executables
function Add-CodeSignatures {
    Write-BuildLog "Signing all executables..." "INFO" "Yellow"

    $signingScript = Join-Path $PSScriptRoot "build-tools\Sign-Executables.ps1"

    # Check if signing is configured
    $signingConfigPath = Join-Path $PSScriptRoot "config\signing-config.json"
    if (Test-Path $signingConfigPath) {
        try {
            $signingConfig = Get-Content $signingConfigPath -Raw | ConvertFrom-Json
            if (-not $signingConfig.codeSigningSettings.enabled) {
                Write-BuildLog "Code signing is disabled in configuration" "WARNING" "Yellow"
                Write-BuildLog "To enable signing, update config\signing-config.json" "INFO" "Cyan"
                return $true  # Not an error, just disabled
            }
        } catch {
            Write-BuildLog "Failed to read signing configuration" "ERROR" "Red"
            return $false
        }
    }

    $signingResult = Invoke-BuildScript -ScriptPath $signingScript -Arguments @("-SignAll") -Description "Code signing process"

    # If signing was successful, record signature hashes for log authentication
    if ($signingResult) {
        Record-SignatureHashes
    }

    return $signingResult
}

# Function to record signature hashes in official registry for log authentication
function Record-SignatureHashes {
    Write-BuildLog "Recording signature hashes for log authentication..." "INFO" "Yellow"

    try {
        # Load version information
        $versionScript = Join-Path $PSScriptRoot "Version.ps1"
        if (-not (Test-Path $versionScript)) {
            Write-BuildLog "Version.ps1 not found, cannot record signature hashes" "ERROR" "Red"
            return $false
        }

        # Get current version
        $currentVersion = & {
            . $versionScript
            Get-ProjectVersion -IncludePreRelease
        }

        if (-not $currentVersion) {
            Write-BuildLog "Failed to get version information" "ERROR" "Red"
            return $false
        }

        # Define paths for signed executables
        $releaseDir = Join-Path $PSScriptRoot "release"
        $executables = @{
            "Focus-Game-Deck.exe"               = "Main application executable"
            "Focus-Game-Deck-MultiPlatform.exe" = "Multi-platform version with extended game support"
            "Focus-Game-Deck-Config-Editor.exe" = "GUI configuration editor"
        }

        # Load existing signature hash registry
        $registryPath = Join-Path $PSScriptRoot "docs\official_signature_hashes.json"
        if (-not (Test-Path $registryPath)) {
            Write-BuildLog "Signature hash registry not found: $registryPath" "ERROR" "Red"
            return $false
        }

        $registry = Get-Content $registryPath -Raw | ConvertFrom-Json

        # Create new release entry if it doesn't exist
        if (-not $registry.releases.$currentVersion) {
            $registry.releases | Add-Member -MemberType NoteProperty -Name $currentVersion -Value @{
                releaseDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                description = "Production release with log authentication capabilities"
                executables = @{}
            }
        }

        # Record signature hash for each executable
        $allSuccessful = $true
        foreach ($exeName in $executables.Keys) {
            $exePath = Join-Path $releaseDir $exeName

            if (Test-Path $exePath) {
                try {
                    # Get digital signature
                    $signature = Get-AuthenticodeSignature -FilePath $exePath -ErrorAction Stop

                    if ($signature.Status -eq "Valid" -and $signature.SignerCertificate) {
                        $signatureHash = $signature.SignerCertificate.Thumbprint
                        $fileInfo = Get-Item $exePath

                        # Update registry entry
                        $executableInfo = @{
                            signatureHash = $signatureHash
                            fileSize      = $fileInfo.Length
                            buildDate     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                            description   = $executables[$exeName]
                        }

                        $registry.releases.$currentVersion.executables | Add-Member -MemberType NoteProperty -Name $exeName -Value $executableInfo -Force

                        Write-BuildLog "Recorded signature for $exeName : $signatureHash" "SUCCESS" "Green"
                    } else {
                        Write-BuildLog "Invalid signature for $exeName (Status: $($signature.Status))" "ERROR" "Red"
                        $allSuccessful = $false
                    }
                } catch {
                    Write-BuildLog "Failed to get signature for $exeName : $($_.Exception.Message)" "ERROR" "Red"
                    $allSuccessful = $false
                }
            } else {
                Write-BuildLog "Executable not found: $exePath" "ERROR" "Red"
                $allSuccessful = $false
            }
        }

        if ($allSuccessful) {
            # Update registry metadata
            $registry.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")

            # Save updated registry
            $registry | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath -Encoding UTF8
            Write-BuildLog "Signature hash registry updated successfully for version $currentVersion" "SUCCESS" "Green"
        } else {
            Write-BuildLog "Some signature recordings failed, registry not updated" "ERROR" "Red"
        }

        return $allSuccessful

    } catch {
        Write-BuildLog "Failed to record signature hashes: $($_.Exception.Message)" "ERROR" "Red"
        return $false
    }
}

# Function to create release package
function New-ReleasePackage {
    param([bool]$IsSigned = $false)

    Write-BuildLog "Creating release package..." "INFO" "Yellow"

    $releaseDir = Join-Path $PSScriptRoot "release"
    $sourceDir = if ($IsSigned) { Join-Path $PSScriptRoot "signed" } else { Join-Path $PSScriptRoot "build" }

    if (-not (Test-Path $sourceDir)) {
        Write-BuildLog "Source directory not found: $sourceDir" "ERROR" "Red"
        return $false
    }

    try {
        # Clean and create release directory
        if (Test-Path $releaseDir) {
            Remove-Item $releaseDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

        # Copy built files
        Copy-Item -Path "$sourceDir\*" -Destination $releaseDir -Recurse -Force

        # Create README for release
        $releaseReadme = @"
# Focus Game Deck - Release Package

**Version:** $script:Version
**Build Date:** $script:BuildDate
**Signed:** $(if ($IsSigned) { "Yes" } else { "No" })

## Files Included

- **Focus-Game-Deck.exe**: Main application (Multi-platform support included)
- **Focus-Game-Deck-Config-Editor.exe**: GUI configuration editor
- **config/**: Configuration files and templates
- **launcher.bat**: Quick launcher script

## Installation

1. Extract all files to a directory of your choice
2. Run Focus-Game-Deck-Config-Editor.exe to configure your settings
3. Use Focus-Game-Deck.exe [GameId] to launch games with optimized settings

## Documentation

For complete documentation, visit:
https://github.com/beive60/focus-game-deck

## License

This software is released under the MIT License.
"@

        Set-Content -Path (Join-Path $releaseDir "README.txt") -Value $releaseReadme -Encoding UTF8

        # Create version info
        $versionInfo = @{
            Version   = $script:Version
            BuildDate = $script:BuildDate
            IsSigned  = $IsSigned
            Files     = @()
        }

        Get-ChildItem $releaseDir -Recurse -File | ForEach-Object {
            $versionInfo.Files += @{
                Path         = $_.FullName.Replace($releaseDir, "").TrimStart('\')
                Size         = $_.Length
                LastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }

        $versionInfo | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $releaseDir "version-info.json") -Encoding UTF8

        Write-BuildLog "Release package created: $releaseDir" "SUCCESS" "Green"
        return $true

    } catch {
        Write-BuildLog "Failed to create release package: $($_.Exception.Message)" "ERROR" "Red"
        return $false
    }
}

# Function to display build summary
function Show-BuildSummary {
    param([bool]$Success, [bool]$IsSigned = $false)

    $endTime = Get-Date
    $duration = $endTime - $script:StartTime

    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Host "BUILD SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan

    Write-Host "Status: " -NoNewline
    if ($Success) {
        Write-Host "SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
    }

    Write-Host "Version: $script:Version" -ForegroundColor White
    Write-Host "Build Time: $($duration.ToString('mm\:ss'))" -ForegroundColor White
    Write-Host "Signed: $(if ($IsSigned) { 'Yes' } else { 'No' })" -ForegroundColor White

    if ($Success) {
        Write-Host "`nBuilt executables:" -ForegroundColor Yellow
        $buildDir = Join-Path $PSScriptRoot "build"
        if (Test-Path $buildDir) {
            Get-ChildItem $buildDir -Filter "*.exe" | ForEach-Object {
                Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1KB, 1)) KB)" -ForegroundColor White
            }
        }

        $releaseDir = Join-Path $PSScriptRoot "release"
        if (Test-Path $releaseDir) {
            Write-Host "`nRelease package created: $releaseDir" -ForegroundColor Green
        }
    }

    Write-Host ("=" * 60) -ForegroundColor Cyan
}

# Main execution logic
try {
    $success = $true
    $isSigned = $false

    # Clean if requested
    if ($Clean) {
        Clear-BuildArtifacts
        Write-BuildLog "Clean completed" "SUCCESS" "Green"
        exit 0
    }

    # Setup environment
    if ($SetupOnly) {
        $success = Initialize-BuildEnvironment
        Show-BuildSummary -Success $success
        exit $(if ($success) { 0 } else { 1 })
    }

    # Development build workflow
    if ($Development) {
        Write-BuildLog "Starting DEVELOPMENT build workflow" "INFO" "Cyan"

        $success = Initialize-BuildEnvironment
        if ($success) {
            $success = Build-AllExecutables
        }

        if ($success) {
            $success = New-ReleasePackage -IsSigned $false
        }
    }

    # Production build workflow
    elseif ($Production) {
        Write-BuildLog "Starting PRODUCTION build workflow" "INFO" "Cyan"

        $success = Initialize-BuildEnvironment
        if ($success) {
            $success = Build-AllExecutables
        }

        if ($success) {
            $signingSuccess = Add-CodeSignatures
            if ($signingSuccess) {
                $isSigned = $true
                Write-BuildLog "Code signing completed successfully" "SUCCESS" "Green"
            } else {
                Write-BuildLog "Code signing failed, continuing with unsigned build" "WARNING" "Yellow"
            }
        }

        if ($success) {
            $success = New-ReleasePackage -IsSigned $isSigned
        }
    }

    # Show usage if no workflow specified
    else {
        Write-Host "`nUsage:" -ForegroundColor Yellow
        Write-Host "  .\Master-Build.ps1 -Development   # Build for development (no signing)"
        Write-Host "  .\Master-Build.ps1 -Production    # Build for production (with signing)"
        Write-Host "  .\Master-Build.ps1 -SetupOnly     # Only setup build environment"
        Write-Host "  .\Master-Build.ps1 -Clean         # Clean all build artifacts"
        Write-Host "  .\Master-Build.ps1 -Verbose       # Enable verbose logging"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  .\Master-Build.ps1 -Development -Verbose"
        Write-Host "  .\Master-Build.ps1 -Production"
        Write-Host ""
        Write-Host "This script will:" -ForegroundColor White
        Write-Host "  1. Install required modules (ps2exe)"
        Write-Host "  2. Build all executable files"
        Write-Host "  3. Apply code signing (production only)"
        Write-Host "  4. Create release package"
        exit 0
    }

    Show-BuildSummary -Success $success -IsSigned $isSigned
    exit $(if ($success) { 0 } else { 1 })

} catch {
    Write-BuildLog "Unexpected error: $($_.Exception.Message)" "ERROR" "Red"
    Show-BuildSummary -Success $false
    exit 1
}
