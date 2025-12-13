# Focus Game Deck - Master Build Script
# This script orchestrates the complete build and signing process for all components

<#
.SYNOPSIS
    Focus Game Deck master build script for complete release management

.DESCRIPTION
    This script orchestrates the complete build and signing process for all Focus Game Deck components.
    It handles environment setup, dependency installation, executable building, code signing,
    and release package creation. Supports both development and production build workflows.

.PARAMETER Development
    Executes the development build workflow (no code signing).
    This workflow includes:
    - Environment setup and dependency installation
    - Building all executable files
    - Creating unsigned release package
    Use this for development, testing, and debugging purposes.

.PARAMETER Production
    Executes the production build workflow (with code signing).
    This workflow includes:
    - Environment setup and dependency installation
    - Building all executable files
    - Code signing with Extended Validation certificate
    - Registering signature hashes for log authentication
    - Creating signed release package
    Use this for official releases and distribution.

.PARAMETER Clean
    Removes all build artifacts and cache files.
    Deletes the following directories and files:
    - build-tools/build/
    - build-tools/dist/
    - release/
    - gui/*.exe
    Use this to clean up the workspace before a fresh build.

.PARAMETER SetupOnly
    Only sets up the build environment without building.
    This includes:
    - Installing required PowerShell modules (ps2exe)
    - Validating build environment
    Use this to prepare the environment before manual builds.

.PARAMETER Verbose
    Enables verbose logging throughout the build process.
    Provides detailed information about each step, including:
    - Detailed progress messages
    - Command execution details
    - File operations
    - Error diagnostics

.EXAMPLE
    .\Release-Manager.ps1 -Development
    Builds all components for development without code signing.

.EXAMPLE
    .\Release-Manager.ps1 -Production
    Builds all components for production with code signing and creates release package.

.EXAMPLE
    .\Release-Manager.ps1 -Clean
    Removes all build artifacts and cleans the workspace.

.EXAMPLE
    .\Release-Manager.ps1 -SetupOnly
    Only installs dependencies and sets up the build environment.

.EXAMPLE
    .\Release-Manager.ps1 -Development -Verbose
    Builds for development with detailed verbose logging.

.NOTES
    Version: 1.0.0
    Author: Focus Game Deck Development Team

    Requirements:
    - Windows PowerShell 5.1 or later
    - Internet connection for module installation
    - For production builds: Extended Validation certificate

    Build Artifacts:
    - Focus-Game-Deck.exe: Unified application executable (includes GUI configuration editor and multi-platform support)

    Output Locations:
    - build-tools/build/: Intermediate build files
    - build-tools/dist/: Distribution files
    - release/: Final release package

    Workflow Overview:
    1. Environment setup (install ps2exe module)
    2. Build all executable files from PowerShell scripts
    3. Apply code signing (production builds only)
    4. Register signature hashes for authentication
    5. Create release package with documentation
#>

param(
    [switch]$Development,  # Build for development (no signing)
    [switch]$Production,   # Build for production (with signing)
    [switch]$Clean,        # Clean all build artifacts
    [switch]$SetupOnly,    # Only setup dependencies
    [switch]$Verbose
)

# Import the BuildLogger
. "$PSScriptRoot/utils/BuildLogger.ps1"

# Set verbose preference if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Script version and build info
$script:Version = "1.0.0"
$script:BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$script:StartTime = Get-Date

Write-BuildLog "Focus Game Deck - Master Build Script v$script:Version"
Write-BuildLog "Build started at: $script:BuildDate"

# Helper function to add timestamp to messages (legacy compatibility)
function Write-BuildLogWithTimestamp {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $levelMapped = switch ($Level) {
        "SUCCESS" { "Success" }
        "ERROR" { "Error" }
        "WARNING" { "Warning" }
        "DEBUG" { "Debug" }
        default { "Info" }
    }
    Write-BuildLog "[$timestamp] $Message" -Level $levelMapped
}

# Function to execute script with error handling
function Invoke-BuildScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$Description
    )

    Write-BuildLogWithTimestamp "Starting: $Description" "INFO"

    if (-not (Test-Path $ScriptPath)) {
        Write-BuildLogWithTimestamp "Script not found: $ScriptPath" "ERROR"
        return $false
    }

    try {
        $argumentString = $Arguments -join " "
        Write-BuildLogWithTimestamp "Executing: $(Split-Path $ScriptPath -Leaf) $argumentString" "DEBUG"

        # Use the current PowerShell host (pwsh or powershell) to maintain session context
        $pwshPath = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh" } else { "powershell" }

        $allArguments = @("-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $Arguments
        $process = Start-Process -FilePath $pwshPath -ArgumentList $allArguments -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-BuildLogWithTimestamp "Completed: $Description" "SUCCESS"
            return $true
        } else {
            Write-BuildLogWithTimestamp "Failed: $Description (Exit Code: $($process.ExitCode))" "ERROR"
            return $false
        }
    } catch {
        Write-BuildLogWithTimestamp "Exception in $Description : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to clean all build artifacts
function Clear-BuildArtifacts {
    Write-BuildLogWithTimestamp "Cleaning build artifacts..." "INFO"

    # Get project root directory (parent of build-tools)
    $projectRoot = Split-Path $PSScriptRoot -Parent

    $pathsToClean = @(
        (Join-Path $PSScriptRoot "build"),
        (Join-Path $PSScriptRoot "dist"),
        (Join-Path $projectRoot "src/generated"),
        (Join-Path $projectRoot "release"),
        (Join-Path $projectRoot "gui/*.exe")
    )

    foreach ($path in $pathsToClean) {
        if (Test-Path $path) {
            try {
                if ((Get-Item $path) -is [System.IO.DirectoryInfo]) {
                    Remove-Item $path -Recurse -Force
                    Write-BuildLogWithTimestamp "Removed directory: $path" "SUCCESS"
                } else {
                    Get-Item $path | Remove-Item -Force
                    Write-BuildLogWithTimestamp "Removed files: $path" "SUCCESS"
                }
            } catch {
                Write-BuildLogWithTimestamp "Failed to remove: $path - $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

# Function to setup development environment
function Initialize-BuildEnvironment {
    Write-BuildLogWithTimestamp "Setting up build environment..." "INFO"

    # Install ps2exe module using specialized tool script
    $installScript = Join-Path $PSScriptRoot "Install-BuildDependencies.ps1"
    return Invoke-BuildScript -ScriptPath $installScript -Arguments @() -Description "Installing build dependencies"
}

# Function to build all executables
function Build-AllExecutables {
    Write-BuildLogWithTimestamp "Building all executables..." "INFO"

    # Path to the specialized build script
    $buildScript = Join-Path $PSScriptRoot "Build-Executables.ps1"

    # Forward the parent's Verbose switch to the child script when set
    $buildArgs = @()
    if ($Verbose) { $buildArgs += "-Verbose" }

    return Invoke-BuildScript -ScriptPath $buildScript -Arguments $buildArgs -Description "Building all executables"
}

# Function to generate embedded XAML resources
function Generate-XamlResources {
    Write-BuildLogWithTimestamp "Generating embedded XAML resources..." "INFO"

    $embedScript = Join-Path $PSScriptRoot "Embed-XamlResources.ps1"
    $outputPath = Join-Path $PSScriptRoot "build/XamlResources.ps1"

    $embedArgs = @("-OutputPath", $outputPath)
    if ($Verbose) { $embedArgs += "-Verbose" }

    return Invoke-BuildScript -ScriptPath $embedScript -Arguments $embedArgs -Description "Embedding XAML resources"
}

# Function to sign all executables
function Add-CodeSignatures {
    Write-BuildLogWithTimestamp "Signing all executables..." "INFO"

    $signingScript = Join-Path $PSScriptRoot "Sign-Executables.ps1"
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $distDir = Join-Path $PSScriptRoot "dist"

    # Check if signing is configured
    $signingConfigPath = Join-Path $projectRoot "config/signing-config.json"
    if (Test-Path $signingConfigPath) {
        try {
            $signingConfig = Get-Content $signingConfigPath -Raw | ConvertFrom-Json
            if (-not $signingConfig.codeSigningSettings.enabled) {
                Write-BuildLogWithTimestamp "Code signing is disabled in configuration" "WARNING"
                Write-BuildLogWithTimestamp "To enable signing, update config/signing-config.json" "INFO"
                return $true  # Not an error, just disabled
            }
        } catch {
            Write-BuildLogWithTimestamp "Failed to read signing configuration" "ERROR"
            return $false
        }
    }

    # Pass the correct build path (dist directory) to the signing script
    $signingResult = Invoke-BuildScript -ScriptPath $signingScript -Arguments @("-SignAll", "-BuildPath", $distDir) -Description "Code signing process"

    # If signing was successful, register signature hashes for log authentication
    if ($signingResult) {
        Register-SignatureHashes
    }

    return $signingResult
}

# Function to register signature hashes in official registry for log authentication
function Register-SignatureHashes {
    Write-BuildLogWithTimestamp "Registering signature hashes for log authentication..." "INFO"

    try {
        # Load version information
        $versionScript = Join-Path $PSScriptRoot "Version.ps1"
        if (-not (Test-Path $versionScript)) {
            Write-BuildLogWithTimestamp "Version.ps1 not found, cannot record signature hashes" "ERROR"
            return $false
        }

        # Get current version
        $currentVersion = & {
            . $versionScript
            Get-ProjectVersion -IncludePreRelease
        }

        if (-not $currentVersion) {
            Write-BuildLogWithTimestamp "Failed to get version information" "ERROR"
            return $false
        }

        # Define paths for signed executables
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $distDir = Join-Path $PSScriptRoot "dist"
        $executables = @{
            "Focus-Game-Deck.exe" = "Unified application executable with integrated GUI configuration editor and multi-platform support"
        }

        # Load existing signature hash registry
        $registryPath = Join-Path $projectRoot "docs/official_signature_hashes.json"
        if (-not (Test-Path $registryPath)) {
            Write-BuildLogWithTimestamp "Signature hash registry not found: $registryPath" "ERROR"
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

        # Register signature hash for each executable
        $allSuccessful = $true
        foreach ($exeName in $executables.Keys) {
            $exePath = Join-Path $distDir $exeName

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
                            fileSize = $fileInfo.Length
                            buildDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                            description = $executables[$exeName]
                        }

                        $registry.releases.$currentVersion.executables | Add-Member -MemberType NoteProperty -Name $exeName -Value $executableInfo -Force

                        Write-BuildLogWithTimestamp "Registered signature for $exeName : $signatureHash" "SUCCESS"
                    } else {
                        Write-BuildLogWithTimestamp "Invalid signature for $exeName (Status: $($signature.Status))" "ERROR"
                        $allSuccessful = $false
                    }
                } catch {
                    Write-BuildLogWithTimestamp "Failed to get signature for $exeName : $($_.Exception.Message)" "ERROR"
                    $allSuccessful = $false
                }
            } else {
                Write-BuildLogWithTimestamp "Executable not found: $exePath" "ERROR"
                $allSuccessful = $false
            }
        }

        if ($allSuccessful) {
            # Update registry metadata
            $registry.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")

            # Save updated registry
            $registry | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath -Encoding UTF8
            Write-BuildLogWithTimestamp "Signature hash registry updated successfully for version $currentVersion" "SUCCESS"
        } else {
            Write-BuildLogWithTimestamp "Some signature registrations failed, registry not updated" "ERROR"
        }

        return $allSuccessful

    } catch {
        Write-BuildLogWithTimestamp "Failed to register signature hashes: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to copy resources
function Copy-BuildResources {
    Write-BuildLogWithTimestamp "Copying build resources..." "INFO"

    # Use specialized resource copier
    $copyScript = Join-Path $PSScriptRoot "Copy-Resources.ps1"
    return Invoke-BuildScript -ScriptPath $copyScript -Arguments @() -Description "Copying runtime resources"
}

# Function to create release package
function New-ReleasePackage {
    param([bool]$IsSigned = $false)

    Write-BuildLogWithTimestamp "Creating release package..." "INFO"

    # Use specialized package creator
    $packageScript = Join-Path $PSScriptRoot "Create-Package.ps1"
    $arguments = @()
    if ($IsSigned) {
        $arguments += "-IsSigned"
    }

    return Invoke-BuildScript -ScriptPath $packageScript -Arguments $arguments -Description "Creating release package"
}

# Function to create legacy release package (deprecated)
function New-LegacyReleasePackage {
    param([bool]$IsSigned = $false)

    Write-BuildLogWithTimestamp "Creating legacy release package..." "INFO"

    $projectRoot = Split-Path $PSScriptRoot -Parent
    $releaseDir = Join-Path $projectRoot "release"
    $sourceDir = Join-Path $PSScriptRoot "dist"

    if (-not (Test-Path $sourceDir)) {
        Write-BuildLogWithTimestamp "Source directory not found: $sourceDir" "ERROR"
        return $false
    }

    try {
        # Clean and create release directory
        if (Test-Path $releaseDir) {
            Remove-Item $releaseDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

        # Copy built files
        Copy-Item -Path "$sourceDir/*" -Destination $releaseDir -Recurse -Force

        # Create README for release
        $releaseReadme = @"
# Focus Game Deck - Release Package

**Version:** $script:Version
**Build Date:** $script:BuildDate
**Signed:** $(if ($IsSigned) { "Yes" } else { "No" })

## Files Included

- **Focus-Game-Deck.exe**: Unified application executable (includes GUI configuration editor and multi-platform support)
- **config/**: Configuration files and templates
- **launcher.bat**: Quick launcher script

## Installation

1. Extract all files to a directory of your choice
2. Run Focus-Game-Deck.exe (without arguments) to open the configuration editor
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
            Version = $script:Version
            BuildDate = $script:BuildDate
            IsSigned = $IsSigned
            Files = @()
        }

        Get-ChildItem $releaseDir -Recurse -File | ForEach-Object {
            $versionInfo.Files += @{
                Path = $_.FullName.Replace($releaseDir, "").TrimStart('\')
                Size = $_.Length
                LastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }

        $versionInfo | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $releaseDir "version-info.json") -Encoding UTF8

        Write-BuildLogWithTimestamp "Release package created: $releaseDir" "SUCCESS"
        return $true

    } catch {
        Write-BuildLogWithTimestamp "Failed to create release package: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to display build summary
function Show-BuildSummary {
    param([bool]$Success, [bool]$IsSigned = $false)

    $endTime = Get-Date
    $duration = $endTime - $script:StartTime

    Write-Host "" + ("=" * 60)
    Write-Host "BUILD SUMMARY"
    Write-Host ("=" * 60)

    Write-Host "Status: " -NoNewline
    if ($Success) {
        Write-Host "SUCCESS"
    } else {
        Write-Host "FAILED"
    }

    Write-Host "Version: $script:Version"
    Write-Host "Build Time: $($duration.ToString('mm\:ss'))"
    Write-Host "Signed: $(if ($IsSigned) { 'Yes' } else { 'No' })"

    if ($Success) {
        Write-Host "Built executables:"
        $distDir = Join-Path $PSScriptRoot "dist"
        if (Test-Path $distDir) {
            Get-ChildItem $distDir -Filter "*.exe" | ForEach-Object {
                Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1KB, 1)) KB)"
            }
        }

        $projectRoot = Split-Path $PSScriptRoot -Parent
        $releaseDir = Join-Path $projectRoot "release"
        if (Test-Path $releaseDir) {
            Write-Host "Release package created: $releaseDir"
        }
    }

    Write-Host ("=" * 60)
}

# Main execution logic
try {
    $success = $true
    $isSigned = $false

    # Clean if requested
    if ($Clean) {
        Clear-BuildArtifacts
        Write-BuildLogWithTimestamp "Clean completed" "SUCCESS"
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
        Write-BuildLogWithTimestamp "Starting DEVELOPMENT build workflow" "INFO"

        # Step 1: Install dependencies
        $success = Initialize-BuildEnvironment

        # Step 2: Generate embedded XAML resources
        if ($success) {
            $success = Generate-XamlResources
        }

        # Step 3: Bundle entry-point scripts
        if ($success) {
            $bundlerScript = Join-Path $PSScriptRoot "Invoke-PsScriptBundler.ps1"
            $projectRoot = Split-Path $PSScriptRoot -Parent
            $buildDir = Join-Path $PSScriptRoot "build"
            $entryPoints = @(
                @{ Entry = Join-Path $projectRoot "gui/ConfigEditor.ps1"; Out = Join-Path $buildDir "ConfigEditor-bundled.ps1" },
                @{ Entry = Join-Path $projectRoot "src/Invoke-FocusGameDeck.ps1"; Out = Join-Path $buildDir "Invoke-FocusGameDeck-bundled.ps1" },
                @{ Entry = Join-Path $projectRoot "src/Main.PS1"; Out = Join-Path $buildDir "Main-bundled.ps1" }
            )
            foreach ($ep in $entryPoints) {
                $bundlerArgs = @("-EntryPoint", $ep.Entry, "-OutputPath", $ep.Out, "-ProjectRoot", $projectRoot)
                # Do NOT add -Verbose argument; rely on $VerbosePreference propagation
                $success = Invoke-BuildScript -ScriptPath $bundlerScript -Arguments $bundlerArgs -Description "Bundling $($ep.Entry)"
                if (-not $success) { break }
            }
        }

        # Step 4: Build executables
        if ($success) {
            $success = Build-AllExecutables
        }

        # Step 5: Copy resources
        if ($success) {
            $success = Copy-BuildResources
        }

        # Step 6: Create release package
        if ($success) {
            $success = New-ReleasePackage -IsSigned $false
        }
    }

    # Production build workflow
    elseif ($Production) {
        Write-BuildLogWithTimestamp "Starting PRODUCTION build workflow" "INFO"

        # Step 1: Install dependencies
        $success = Initialize-BuildEnvironment

        # Step 2: Generate embedded XAML resources
        if ($success) {
            $success = Generate-XamlResources
        }

        # Step 3: Bundle entry-point scripts
        if ($success) {
            $bundlerScript = Join-Path $PSScriptRoot "Invoke-PsScriptBundler.ps1"
            $projectRoot = Split-Path $PSScriptRoot -Parent
            $buildDir = Join-Path $PSScriptRoot "build"
            $entryPoints = @(
                @{ Entry = Join-Path $projectRoot "gui/ConfigEditor.ps1"; Out = Join-Path $buildDir "ConfigEditor-bundled.ps1" },
                @{ Entry = Join-Path $projectRoot "src/Invoke-FocusGameDeck.ps1"; Out = Join-Path $buildDir "Invoke-FocusGameDeck-bundled.ps1" },
                @{ Entry = Join-Path $projectRoot "src/Main.PS1"; Out = Join-Path $buildDir "Main-bundled.ps1" }
            )
            foreach ($ep in $entryPoints) {
                $bundlerArgs = @("-EntryPoint", $ep.Entry, "-OutputPath", $ep.Out, "-ProjectRoot", $projectRoot)
                if ($Verbose) { $bundlerArgs += "-Verbose" }
                $success = Invoke-BuildScript -ScriptPath $bundlerScript -Arguments $bundlerArgs -Description "Bundling $($ep.Entry)"
                if (-not $success) { break }
            }
        }

        # Step 4: Build executables
        if ($success) {
            $success = Build-AllExecutables
        }

        # Step 5: Copy resources
        if ($success) {
            $success = Copy-BuildResources
        }

        # Step 6: Sign executables
        if ($success) {
            $signingSuccess = Add-CodeSignatures
            if ($signingSuccess) {
                $isSigned = $true
                Write-BuildLogWithTimestamp "Code signing completed successfully" "SUCCESS"
            } else {
                Write-BuildLogWithTimestamp "Code signing failed, continuing with unsigned build" "WARNING"
            }
        }

        # Step 7: Create release package
        if ($success) {
            $success = New-ReleasePackage -IsSigned $isSigned
        }
    }

    # Show usage if no workflow specified
    else {
        Write-Host "Usage:"
        Write-Host "  ./Release-Manager.ps1 -Development   # Build for development (no signing)"
        Write-Host "  ./Release-Manager.ps1 -Production    # Build for production (with signing)"
        Write-Host "  ./Release-Manager.ps1 -SetupOnly     # Only setup build environment"
        Write-Host "  ./Release-Manager.ps1 -Clean         # Clean all build artifacts"
        Write-Host "  ./Release-Manager.ps1 -Verbose       # Enable verbose logging"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  ./Release-Manager.ps1 -Development -Verbose"
        Write-Host "  ./Release-Manager.ps1 -Production"
        Write-Host ""
        Write-Host "This script will:"
        Write-Host "  1. Install required modules (ps2exe)"
        Write-Host "  2. Build all executable files"
        Write-Host "  3. Apply code signing (production only)"
        Write-Host "  4. Create release package"
        exit 0
    }

    Show-BuildSummary -Success $success -IsSigned $isSigned
    exit $(if ($success) { 0 } else { 1 })

} catch {
    Write-BuildLogWithTimestamp "Unexpected error: $($_.Exception.Message)" "ERROR"
    Show-BuildSummary -Success $false
    exit 1
}
