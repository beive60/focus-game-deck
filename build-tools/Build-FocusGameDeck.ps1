<#
.SYNOPSIS
    [DEPRECATED] Focus Game Deck application build script - Multi-Executable Bundle Architecture

.DESCRIPTION
    ================================================================================================
    ⚠️  DEPRECATION NOTICE - This script is deprecated in favor of specialized tool scripts  ⚠️
    ================================================================================================

    This monolithic build script has been refactored following the Single Responsibility Principle (SRP).
    Its functionality has been separated into specialized tool scripts:

    - Install-BuildDependencies.ps1  : Manages ps2exe module installation
    - Invoke-PsScriptBundler.ps1     : Handles PowerShell script bundling
    - Build-Executables.ps1          : Compiles executables using ps2exe
    - Copy-Resources.ps1             : Copies non-executable runtime assets
    - Sign-Executables.ps1           : Applies digital signatures
    - Create-Package.ps1             : Creates final distribution package
    - Release-Manager.ps1            : Orchestrates the complete build workflow

    RECOMMENDED USAGE:
    - For complete builds: Use Release-Manager.ps1 -Development or -Production
    - For individual tasks: Use the appropriate specialized tool script

    This script is maintained for backward compatibility but will be removed in a future version.
    Please update your build processes to use the new tool scripts.

    ================================================================================================

    LEGACY DESCRIPTION:
    This script creates three separate, fully bundled, digitally signed executables:
    1. Focus-Game-Deck.exe - Lightweight router that launches sub-processes
    2. ConfigEditor.exe - Fully bundled GUI configuration editor
    3. Invoke-FocusGameDeck.exe - Fully bundled game launcher

    This architecture ensures all executed code is contained within digitally signed
    executables, eliminating the security vulnerability of external unsigned scripts.

.PARAMETER Install
    [DEPRECATED] Installs the ps2exe module.
    Use Install-BuildDependencies.ps1 instead.

.PARAMETER Build
    [DEPRECATED] Builds all three application executables.
    Use Build-Executables.ps1 instead.

.PARAMETER Clean
    [DEPRECATED] Removes build artifacts and cache files.
    Use Release-Manager.ps1 -Clean instead.

.PARAMETER Sign
    [DEPRECATED] Applies digital signature to the created executable files.
    Use Sign-Executables.ps1 -SignAll instead.

.PARAMETER All
    [DEPRECATED] Executes all operations (Install, Clean, Build, Sign) sequentially.
    Use Release-Manager.ps1 -Production instead.

.EXAMPLE
    .\Build-FocusGameDeck.ps1 -Install
    [DEPRECATED] Use: .\Install-BuildDependencies.ps1

.EXAMPLE
    .\Build-FocusGameDeck.ps1 -Build
    [DEPRECATED] Use: .\Build-Executables.ps1

.EXAMPLE
    .\Build-FocusGameDeck.ps1 -All
    Executes all operations (install, cleanup, build, sign).

.NOTES
    Version: 3.0.0 - Multi-Executable Bundle Architecture
    Author: Focus Game Deck Development Team
    This script requires Windows PowerShell 5.1 or later.

    STATUS: DEPRECATED - Use specialized tool scripts instead
    See DEPRECATION NOTICE in DESCRIPTION for replacement scripts.
#>

param(
    [switch]$Install,
    [switch]$Build,
    [switch]$Clean,
    [switch]$Sign,
    [switch]$All
)

# Display deprecation warning
function Show-DeprecationWarning {
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Yellow
    Write-Host "⚠️  DEPRECATION WARNING" -ForegroundColor Yellow
    Write-Host "================================================================================================" -ForegroundColor Yellow
    Write-Host "This script (Build-FocusGameDeck.ps1) is DEPRECATED and will be removed in a future version." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The build system has been refactored following the Single Responsibility Principle." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please use the new specialized tool scripts:" -ForegroundColor White
    Write-Host "  - Install-BuildDependencies.ps1  : Install ps2exe module" -ForegroundColor White
    Write-Host "  - Build-Executables.ps1          : Build executables" -ForegroundColor White
    Write-Host "  - Copy-Resources.ps1             : Copy runtime resources" -ForegroundColor White
    Write-Host "  - Sign-Executables.ps1           : Sign executables" -ForegroundColor White
    Write-Host "  - Create-Package.ps1             : Create release package" -ForegroundColor White
    Write-Host "  - Release-Manager.ps1            : Orchestrate complete workflow" -ForegroundColor White
    Write-Host ""
    Write-Host "Recommended commands:" -ForegroundColor Cyan
    Write-Host "  Development build: .\Release-Manager.ps1 -Development" -ForegroundColor Green
    Write-Host "  Production build:  .\Release-Manager.ps1 -Production" -ForegroundColor Green
    Write-Host ""
    Write-Host "This script will continue to work but is no longer maintained." -ForegroundColor Yellow
    Write-Host "================================================================================================" -ForegroundColor Yellow
    Write-Host ""

    Start-Sleep -Seconds 3
}

# Show deprecation warning whenever this script is executed
Show-DeprecationWarning

# Check if ps2exe is installed
function Test-PS2EXE {
    try {
        $module = Get-Module -ListAvailable -Name ps2exe
        return $null -ne $module
    } catch {
        return $false
    }
}

# Install ps2exe if needed
if ($Install) {
    Write-Host "Installing ps2exe module..."

    if (-not (Test-PS2EXE)) {
        try {
            Install-Module -Name ps2exe -Scope CurrentUser -Force
            Write-Host "ps2exe module installed successfully."
        } catch {
            Write-Host "Failed to install ps2exe: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Host "ps2exe module is already installed."
    }
}

# Clean build artifacts
if ($Clean) {
    Write-Host "Cleaning build artifacts..."

    $buildDir = Join-Path $PSScriptRoot "build"
    $distDir = Join-Path $PSScriptRoot "dist"

    if (Test-Path $buildDir) {
        Remove-Item $buildDir -Recurse -Force
        Write-Host "Build directory cleaned."
    }

    if (Test-Path $distDir) {
        Remove-Item $distDir -Recurse -Force
        Write-Host "Distribution directory cleaned."
    }    $exeFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.exe" -Recurse
    foreach ($exeFile in $exeFiles) {
        if ($exeFile.Name -like "*Focus-Game-Deck*") {
            Remove-Item $exeFile.FullName -Force
            Write-Host "Removed: $($exeFile.FullName)"
        }
    }
}

# Build executables
if ($Build) {
    Write-Host "Building executables..."

    if (-not (Test-PS2EXE)) {
        Write-Host "ps2exe module is not installed. Run with -Install parameter first."
        exit 1
    }

    try {
        Import-Module ps2exe

        # Create build directory
        $buildDir = Join-Path $PSScriptRoot "build"
        if (-not (Test-Path $buildDir)) {
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        }

        # Get project root and icon
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $iconFile = Join-Path $projectRoot "assets/icon.ico"

        # Build 1: Main Router (Focus-Game-Deck.exe)
        # This is a lightweight router that only launches other executables
        Write-Host "Building Main Router (Focus-Game-Deck.exe)..."
        $mainScriptPath = Join-Path $projectRoot "src/Main.PS1"
        $mainOutputPath = Join-Path $buildDir "Focus-Game-Deck.exe"

        if (Test-Path $mainScriptPath) {
            $ps2exeParams = @{
                inputFile = $mainScriptPath
                outputFile = $mainOutputPath
                title = "Focus Game Deck"
                description = "Gaming environment optimization tool - Main Router"
                company = "Focus Game Deck Project"
                version = "3.0.0.0"
                copyright = "MIT License"
                requireAdmin = $false
                STA = $false
                noConsole = $false
            }

            if (Test-Path $iconFile) {
                $ps2exeParams.Add("iconFile", $iconFile)
            } else {
                Write-Warning "Icon file not found: $iconFile. Building without an icon."
            }

            ps2exe @ps2exeParams

            if (Test-Path $mainOutputPath) {
                Write-Host "[OK] Main Router executable created: $mainOutputPath"
            } else {
                Write-Host "[ERROR] Failed to create Main Router executable."
            }
        } else {
            Write-Host "[ERROR] Main script not found: $mainScriptPath"
        }

        # Build 2: Config Editor (ConfigEditor.exe)
        # Bundle all GUI dependencies into the executable
        Write-Host ""
        Write-Host "Building Config Editor (ConfigEditor.exe) with bundled dependencies..."

        # Define ConfigEditor paths
        $configEditorPath = Join-Path -Path $projectRoot "gui/ConfigEditor.ps1"
        if (Test-Path $configEditorPath) {
            $configEditorOutput = Join-Path $buildDir "ConfigEditor.exe"

            # Collect all helper scripts to embed
            $guiHelpers = @(
                "ConfigEditor.JsonHelper.ps1",
                "ConfigEditor.Mappings.ps1",
                "ConfigEditor.State.ps1",
                "ConfigEditor.Localization.ps1",
                "ConfigEditor.UI.ps1",
                "ConfigEditor.Events.ps1"
            )

            $embedFilesHash = @{}
            foreach ($helper in $guiHelpers) {
                $helperPath = Join-Path $projectRoot "gui/$helper"
                if (Test-Path $helperPath) {
                    $embedFilesHash[(Join-Path -Path "./" -ChildPath $helper)] = $helperPath
                    Write-Host "[INFO] Will embed: $helper"
                }
            }

            # Add other helper scripts
            $additionalEmbedScripts = @(
                "scripts/LanguageHelper.ps1",
                "Version.ps1",
                "src/modules/UpdateChecker.ps1"
            )
            foreach ($relPath in $additionalEmbedScripts) {
                $fullPath = Join-Path -Path $projectRoot -ChildPath $relPath
                if (Test-Path $fullPath) {
                    $embedFilesHash[$relPath] = $fullPath
                    Write-Host "[INFO] Will embed: $relPath"
                }
            }

            # Build ps2exe parameters with embedFiles
            $ps2exeParams = @{
                inputFile = $configEditorPath
                outputFile = $configEditorOutput
                title = "Focus Game Deck - Configuration Editor"
                description = "Focus Game Deck GUI Configuration Editor"
                company = "Focus Game Deck Project"
                version = "3.0.0.0"
                copyright = "MIT License"
                requireAdmin = $false
                STA = $true
                noConsole = $true
            }

            if (Test-Path $iconFile) {
                $ps2exeParams.Add("iconFile", $iconFile)
            }

            if ($embedFilesHash.Count -gt 0) {
                $ps2exeParams.Add("embedFiles", $embedFilesHash)
                Write-Host "[INFO] Embedding $($embedFilesHash.Count) helper files into ConfigEditor.exe"
            }

            ps2exe @ps2exeParams

            if (Test-Path $configEditorOutput) {
                Write-Host "[OK] Config Editor executable created: $configEditorOutput"
            } else {
                Write-Host "[ERROR] Failed to create Config Editor executable."
            }
        } else {
            Write-Host "[ERROR] Config Editor script not found: $configEditorPath"
        }

        # Build 3: Game Launcher (Invoke-FocusGameDeck.exe)
        # Bundle all game launcher modules into the executable
        Write-Host ""
        Write-Host "Building Game Launcher (Invoke-FocusGameDeck.exe) with bundled dependencies..."

        # Create staging directory for game launcher
        $gameLauncherStaging = Join-Path $buildDir "staging-gameLauncher"
        if (Test-Path $gameLauncherStaging) {
            Remove-Item $gameLauncherStaging -Recurse -Force
        }
        New-Item -ItemType Directory -Path $gameLauncherStaging -Force | Out-Null

        # Copy game launcher main script and apply build-time patching
        $gameLauncherPath = Join-Path $projectRoot "src/Invoke-FocusGameDeck.ps1"
        if (Test-Path $gameLauncherPath) {
            # Read game launcher script and patch for bundled execution
            $gameLauncherContent = Get-Content $gameLauncherPath -Raw -Encoding UTF8

            # Define the patch content that will be inserted between markers
            # This patch detects execution mode and adjusts paths accordingly
            $pathResolutionPatch = @'
# >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
# Detect execution mode for ps2exe bundling
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

# Define the application root directory
# This is critical for finding external resources (config, logs)
if ($isExecutable) {
    # In executable mode, the root is the directory where the .exe file is located
    # ps2exe extracts to temp, but we need the actual exe location for external files
    $appRoot = Split-Path -Parent $currentProcess.Path
    $scriptDir = $PSScriptRoot  # Points to temp extraction dir for bundled scripts
} else {
    # In development (script) mode, calculate the project root relative to the current script
    # For Invoke-FocusGameDeck.ps1 in /src, the root is one level up
    $appRoot = Split-Path -Parent $PSScriptRoot
    $scriptDir = $PSScriptRoot
}

# Initialize path variables - use $appRoot for external files
$configPath = Join-Path $appRoot "config/config.json"
$messagesPath = Join-Path $appRoot "localization/messages.json"

# Module scripts are bundled and extracted to $PSScriptRoot (flat in bundled mode)
$modulePaths = @(
    (Join-Path $scriptDir "Logger.ps1"),
    (Join-Path $scriptDir "ConfigValidator.ps1"),
    (Join-Path $scriptDir "AppManager.ps1"),
    (Join-Path $scriptDir "OBSManager.ps1"),
    (Join-Path $scriptDir "PlatformManager.ps1")
)

$languageHelperPath = Join-Path $scriptDir "LanguageHelper.ps1"

# Import modules
foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# Load configuration and messages
try {
    # Load configuration
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Load messages for localization
    if (Test-Path $languageHelperPath) {
        . $languageHelperPath
        $langCode = Get-DetectedLanguage -ConfigData $config
        $msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode
    } else {
        $msg = @{}
    }

    # Display localized loading messages
    if ($msg.mainLoadingConfig) {
        Write-Host $msg.mainLoadingConfig
    } else {
        Write-Host "Loading configuration..."
    }

    if ($msg.mainConfigLoaded) {
        Write-Host $msg.mainConfigLoaded
    } else {
        Write-Host "Configuration loaded successfully."
    }
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}
# <<< BUILD-TIME-PATCH-END <<<
'@

            # Replace the section between markers with the patch
            $patchPattern = '(?s)# >>> BUILD-TIME-PATCH-START:.*?# <<< BUILD-TIME-PATCH-END <<<'
            $gameLauncherContent = $gameLauncherContent -replace $patchPattern, $pathResolutionPatch

            # Save patched version
            $gameLauncherContent | Set-Content (Join-Path $gameLauncherStaging "Invoke-FocusGameDeck.ps1") -Encoding UTF8 -Force
            Write-Host "[INFO] Patched Invoke-FocusGameDeck.ps1 for bundled execution"

            # Copy all module scripts to flat structure (ps2exe will bundle these)
            $modules = @(
                "Logger.ps1",
                "ConfigValidator.ps1",
                "AppManager.ps1",
                "OBSManager.ps1",
                "PlatformManager.ps1",
                "VTubeStudioManager.ps1",
                "DiscordManager.ps1",
                "DiscordRPCClient.ps1",
                "WebSocketAppManagerBase.ps1",
                "UpdateChecker.ps1"
            )

            foreach ($module in $modules) {
                $modulePath = Join-Path $projectRoot "src/modules/$module"
                if (Test-Path $modulePath) {
                    Copy-Item $modulePath $gameLauncherStaging -Force
                    Write-Host "[INFO] Bundled: $module"
                }
            }

            # Copy helper scripts
            Copy-Item (Join-Path $projectRoot "scripts/LanguageHelper.ps1") $gameLauncherStaging -Force -ErrorAction SilentlyContinue
            Copy-Item (Join-Path $PSScriptRoot "Version.ps1") $gameLauncherStaging -Force -ErrorAction SilentlyContinue

            # Now build from staging directory
            $gameLauncherInput = Join-Path $gameLauncherStaging "Invoke-FocusGameDeck.ps1"
            $gameLauncherOutput = Join-Path $buildDir "Invoke-FocusGameDeck.exe"

            $ps2exeParams = @{
                inputFile = $gameLauncherInput
                outputFile = $gameLauncherOutput
                title = "Focus Game Deck - Game Launcher"
                description = "Focus Game Deck Game Launcher Engine"
                company = "Focus Game Deck Project"
                version = "3.0.0.0"
                copyright = "MIT License"
                requireAdmin = $false
                STA = $false
                noConsole = $false
            }

            if (Test-Path $iconFile) {
                $ps2exeParams.Add("iconFile", $iconFile)
            }

            ps2exe @ps2exeParams

            if (Test-Path $gameLauncherOutput) {
                Write-Host "[OK] Game Launcher executable created: $gameLauncherOutput"
            } else {
                Write-Host "[ERROR] Failed to create Game Launcher executable."
            }

            # Clean up staging directory
            Remove-Item $gameLauncherStaging -Recurse -Force
        } else {
            Write-Host "[ERROR] Game Launcher script not found: $gameLauncherPath"
        }

        Write-Host ""
        Write-Host "Multi-Executable Bundle Architecture:"
        Write-Host "  1. Focus-Game-Deck.exe - Main router (launches sub-processes)"
        Write-Host "  2. ConfigEditor.exe - GUI configuration editor (fully bundled)"
        Write-Host "  3. Invoke-FocusGameDeck.exe - Game launcher (fully bundled)"

        # Copy necessary supporting files to build directory
        Write-Host ""
        Write-Host "Copying supporting files to build directory..."

        # Copy config directory
        $configDir = Join-Path $buildDir "config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $sourceConfigDir = Join-Path $projectRoot "config"
        if (Test-Path $sourceConfigDir) {
            # Copy *.json.sample files and rename to *.json
            Get-ChildItem $sourceConfigDir -Filter "*.json.sample" | ForEach-Object {
                $destName = $_.Name -replace '\.sample$', ''
                $destPath = Join-Path $configDir $destName
                Copy-Item $_.FullName $destPath -Force
                Write-Host "[OK] Copied $($_.Name) as $destName"
            }

            # Copy other JSON files (excluding *.json.sample files)
            Get-ChildItem $sourceConfigDir -Filter "*.json" | Where-Object { $_.Name -notlike "*.json.sample" } | ForEach-Object {
                Copy-Item $_.FullName $configDir -Force
                Write-Host "[OK] Copied $($_.Name)"
            }
        }

        # Copy localization directory
        $localizationDir = Join-Path $buildDir "localization"
        if (-not (Test-Path $localizationDir)) {
            New-Item -ItemType Directory -Path $localizationDir -Force | Out-Null
        }
        $sourceLocalizationDir = Join-Path $projectRoot "localization"
        if (Test-Path $sourceLocalizationDir) {
            Copy-Item "$sourceLocalizationDir/*.json" $localizationDir -Force
            Write-Host "[OK] Copied localization files"
        }

        # Copy gui directory (for XAML and helper scripts that ConfigEditor.exe references at runtime)
        $guiDir = Join-Path $buildDir "gui"
        if (-not (Test-Path $guiDir)) {
            New-Item -ItemType Directory -Path $guiDir -Force | Out-Null
        }
        $sourceGuiDir = Join-Path $projectRoot "gui"
        if (Test-Path $sourceGuiDir) {
            Get-ChildItem $sourceGuiDir -Include "*.xaml" -Recurse | ForEach-Object {
                Copy-Item $_.FullName $guiDir -Force
            }
            Write-Host "[OK] Copied GUI files (XAML only)"
        }

        Write-Host ""
        Write-Host "Build completed successfully!"
        Write-Host "Built files are located in: $buildDir"

        # List built executables
        Write-Host ""
        Write-Host "Built executables:"
        Get-ChildItem $buildDir -Filter "*.exe" | ForEach-Object {
            $fileSize = [math]::Round($_.Length / 1KB, 2)
            Write-Host "  $($_.Name) ($fileSize KB)"
        }

        # Auto-sign if requested
        if ($Sign -or $All) {
            Write-Host "`nStarting code signing process..."
            $signingScript = Join-Path $PSScriptRoot "Sign-Executables.ps1"
            if (Test-Path $signingScript) {
                & $signingScript -SignAll
            } else {
                Write-Warning "Code signing script not found: $signingScript"
            }
        }

        # Create distribution directory and move final files
        $distDir = Join-Path $PSScriptRoot "dist"
        if (-not (Test-Path $distDir)) {
            New-Item -ItemType Directory -Path $distDir -Force | Out-Null
        }

        Write-Host "Creating distribution package..."

        # Move executables to dist directory
        Get-ChildItem $buildDir -Filter "*.exe" | ForEach-Object {
            $destinationPath = Join-Path $distDir $_.Name
            Move-Item $_.FullName $destinationPath -Force

            # Check if executable is signed
            $isSigned = $false
            try {
                $signature = Get-AuthenticodeSignature $destinationPath
                $isSigned = $signature.Status -ne "NotSigned"
            } catch {
                $isSigned = $false
            }

            $signStatus = if ($isSigned) { "(signed)" } else { "(unsigned)" }
            Write-Host "Moved: $($_.Name) to distribution directory $signStatus"
        }

        # Copy configuration files and other assets to dist directory
        if (Test-Path $configDir) {
            $distConfigDir = Join-Path $distDir "config"
            if (-not (Test-Path $distConfigDir)) {
                New-Item -ItemType Directory -Path $distConfigDir -Force | Out-Null
            }
            Copy-Item "$configDir/*" $distConfigDir -Recurse -Force
        }

        # Copy other support directories that bundled executables may require at runtime
        # Only XAML files and localization data are needed - all scripts are bundled

        # Copy directly from project source to dist

        # Ensure GUI (XAML only) is present
        $sourceGuiProject = Join-Path $projectRoot "gui"
        $distGuiDir = Join-Path $distDir "gui"
        if (Test-Path $sourceGuiProject) {
            if (-not (Test-Path $distGuiDir)) { New-Item -ItemType Directory -Path $distGuiDir -Force | Out-Null }
            Get-ChildItem $sourceGuiProject -Include "*.xaml" -Recurse | ForEach-Object {
                Copy-Item $_.FullName $distGuiDir -Force
            }
            Write-Host "[OK] Copied GUI XAML files to distribution directory"
        }

        # Ensure localization directory is present
        $sourceLocalizationProject = Join-Path $projectRoot "localization"
        $distLocalizationDir = Join-Path $distDir "localization"
        if (Test-Path $sourceLocalizationProject) {
            if (-not (Test-Path $distLocalizationDir)) { New-Item -ItemType Directory -Path $distLocalizationDir -Force | Out-Null }
            Copy-Item "$sourceLocalizationProject/*.json" $distLocalizationDir -Force
            Write-Host "[OK] Copied localization files to distribution directory"
        }

        # Verification: All scripts should be bundled in executables
        Write-Host ""
        Write-Host "Verifying distribution package (all scripts should be bundled)..."
        $checkPaths = @(
            @{ Path = (Join-Path $distDir "config"); Type = "Configuration files" },
            @{ Path = (Join-Path $distGuiDir "MainWindow.xaml"); Type = "GUI XAML resources" },
            @{ Path = (Join-Path $distDir "localization"); Type = "Localization resources" },
            @{ Path = (Join-Path $distDir "Focus-Game-Deck.exe"); Type = "Main router executable" },
            @{ Path = (Join-Path $distDir "ConfigEditor.exe"); Type = "Config editor executable" },
            @{ Path = (Join-Path $distDir "Invoke-FocusGameDeck.exe"); Type = "Game launcher executable" }
        )

        foreach ($item in $checkPaths) {
            if (Test-Path $item.Path) {
                Write-Host "  [OK] $($item.Type): $($item.Path)"
            } else {
                Write-Warning "  [MISSING] $($item.Type): $($item.Path)"
            }
        }

        # Clean up intermediate build directory
        Write-Host "Cleaning up intermediate build directory..."
        Remove-Item $buildDir -Recurse -Force
        Write-Host "Build directory cleaned up."

        Write-Host "Distribution package completed! Files are located in: $distDir"
    } catch {
        Write-Host "Failed to build executables: $($_.Exception.Message)"
        exit 1
    }
}

# Sign existing build if requested
if ($Sign -and -not $Build) {
    Write-Host "Signing existing build..."
    $buildDir = Join-Path $PSScriptRoot "build"
    $distDir = Join-Path $PSScriptRoot "dist"

    if (-not (Test-Path $buildDir)) {
        Write-Error "Build directory not found. Please run with -Build first."
        exit 1
    }

    $signingScript = Join-Path $PSScriptRoot "Sign-Executables.ps1"
    if (Test-Path $signingScript) {
        & $signingScript -SignAll

        # Create distribution directory
        if (-not (Test-Path $distDir)) {
            New-Item -ItemType Directory -Path $distDir -Force | Out-Null
        }

        Write-Host "Creating distribution package..."

        # Move executables to dist directory
        Get-ChildItem $buildDir -Filter "*.exe" | ForEach-Object {
            $destinationPath = Join-Path $distDir $_.Name
            Move-Item $_.FullName $destinationPath -Force

            # Check if executable is signed
            $isSigned = $false
            try {
                $signature = Get-AuthenticodeSignature $destinationPath
                $isSigned = $signature.Status -ne "NotSigned"
            } catch {
                $isSigned = $false
            }

            $signStatus = if ($isSigned) { "(signed)" } else { "(unsigned)" }
            Write-Host "Moved: $($_.Name) to distribution directory $signStatus"
        }

        # Copy other files to dist directory
        Get-ChildItem $buildDir -Recurse | Where-Object { -not $_.PSIsContainer -and $_.Extension -ne ".exe" } | ForEach-Object {
            $relativePath = $_.FullName.Replace($buildDir, "").TrimStart('\')
            $destinationPath = Join-Path $distDir $relativePath
            $destinationDir = Split-Path $destinationPath -Parent

            if (-not (Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }

            Copy-Item $_.FullName $destinationPath -Force
        }

        # Clean up intermediate build directory
        Write-Host "Cleaning up intermediate build directory..."
        Remove-Item $buildDir -Recurse -Force
        Write-Host "Build directory cleaned up."

        Write-Host "Distribution package completed! Files are located in: $distDir"
    } else {
        Write-Error "Code signing script not found: $signingScript"
        exit 1
    }
}# Show usage if no parameters
if (-not $Install -and -not $Build -and -not $Clean -and -not $Sign -and -not $All) {
    Write-Host "Focus Game Deck - Main Application Build Script"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  ./Build-FocusGameDeck.ps1 -Install           # Install ps2exe module"
    Write-Host "  ./Build-FocusGameDeck.ps1 -Build             # Build all executables"
    Write-Host "  ./Build-FocusGameDeck.ps1 -Sign              # Sign existing build"
    Write-Host "  ./Build-FocusGameDeck.ps1 -Clean             # Clean build artifacts"
    Write-Host "  ./Build-FocusGameDeck.ps1 -All               # Install, build, and sign"
    Write-Host "  ./Build-FocusGameDeck.ps1 -Build -Sign       # Build and sign"
    Write-Host ""
    Write-Host "Example workflows:"
    Write-Host "  Development: ./Build-FocusGameDeck.ps1 -Install -Build"
    Write-Host "  Production:  ./Build-FocusGameDeck.ps1 -All"
    Write-Host ""
    Write-Host "This script will create executable versions of:"
    Write-Host "  - Focus-Game-Deck.exe (unified application with integrated GUI configuration editor)"
    Write-Host ""
    Write-Host "Final distribution files will be placed in the 'dist' directory."
    Write-Host "Digital signature status can be verified via Windows Properties."
}
