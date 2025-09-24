# Focus Game Deck - Main Application Build Script
# This script creates an executable version of the main Focus Game Deck application

param(
    [switch]$Install,
    [switch]$Build,
    [switch]$Clean,
    [switch]$Sign,
    [switch]$All
)

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
    Write-Host "Installing ps2exe module..." -ForegroundColor Yellow
    
    if (-not (Test-PS2EXE)) {
        try {
            Install-Module -Name ps2exe -Scope CurrentUser -Force
            Write-Host "ps2exe module installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to install ps2exe: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ps2exe module is already installed." -ForegroundColor Green
    }
}

# Clean build artifacts
if ($Clean) {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    
    $buildDir = Join-Path $PSScriptRoot "build"
    if (Test-Path $buildDir) {
        Remove-Item $buildDir -Recurse -Force
        Write-Host "Build directory cleaned." -ForegroundColor Green
    }
    
    $exeFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.exe" -Recurse
    foreach ($exeFile in $exeFiles) {
        if ($exeFile.Name -like "*Focus-Game-Deck*") {
            Remove-Item $exeFile.FullName -Force
            Write-Host "Removed: $($exeFile.FullName)" -ForegroundColor Green
        }
    }
}

# Build executables
if ($Build) {
    Write-Host "Building executables..." -ForegroundColor Yellow
    
    if (-not (Test-PS2EXE)) {
        Write-Host "ps2exe module is not installed. Run with -Install parameter first." -ForegroundColor Red
        exit 1
    }
    
    try {
        Import-Module ps2exe
        
        # Create build directory
        $buildDir = Join-Path $PSScriptRoot "build"
        if (-not (Test-Path $buildDir)) {
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        }
        
        # Build main application
        $mainScriptPath = Join-Path $PSScriptRoot "src\Invoke-FocusGameDeck.ps1"
        $mainOutputPath = Join-Path $buildDir "Focus-Game-Deck.exe"
        
        if (Test-Path $mainScriptPath) {
            Write-Host "Building main application..." -ForegroundColor Cyan
            
            $ps2exeParams = @{
                inputFile = $mainScriptPath
                outputFile = $mainOutputPath
                title = "Focus Game Deck"
                description = "Gaming environment optimization tool"
                company = "Focus Game Deck Project"
                version = "1.0.0.0"
                copyright = "MIT License"
                requireAdmin = $false
                STA = $false
                noConsole = $false
            }
            
            ps2exe @ps2exeParams
            
            if (Test-Path $mainOutputPath) {
                Write-Host "Main executable created: $mainOutputPath" -ForegroundColor Green
            } else {
                Write-Host "Failed to create main executable." -ForegroundColor Red
            }
        } else {
            Write-Host "Main script not found: $mainScriptPath" -ForegroundColor Red
        }
        
        # Build multiplatform version
        $multiScriptPath = Join-Path $PSScriptRoot "src\Invoke-FocusGameDeck-MultiPlatform.ps1"
        $multiOutputPath = Join-Path $buildDir "Focus-Game-Deck-MultiPlatform.exe"
        
        if (Test-Path $multiScriptPath) {
            Write-Host "Building multiplatform version..." -ForegroundColor Cyan
            
            $ps2exeParams = @{
                inputFile = $multiScriptPath
                outputFile = $multiOutputPath
                title = "Focus Game Deck - MultiPlatform"
                description = "Gaming environment optimization tool (MultiPlatform)"
                company = "Focus Game Deck Project"
                version = "1.0.0.0"
                copyright = "MIT License"
                requireAdmin = $false
                STA = $false
                noConsole = $false
            }
            
            ps2exe @ps2exeParams
            
            if (Test-Path $multiOutputPath) {
                Write-Host "MultiPlatform executable created: $multiOutputPath" -ForegroundColor Green
            } else {
                Write-Host "Failed to create MultiPlatform executable." -ForegroundColor Red
            }
        } else {
            Write-Host "MultiPlatform script not found: $multiScriptPath" -ForegroundColor Yellow
        }
        
        # Build Config Editor if not already built
        $configEditorPath = Join-Path $PSScriptRoot "gui\Focus-Game-Deck-Config-Editor.exe"
        if (-not (Test-Path $configEditorPath)) {
            Write-Host "Building Config Editor..." -ForegroundColor Cyan
            
            $configEditorScript = Join-Path $PSScriptRoot "gui\ConfigEditor.ps1"
            $configEditorOutput = Join-Path $buildDir "Focus-Game-Deck-Config-Editor.exe"
            
            if (Test-Path $configEditorScript) {
                $ps2exeParams = @{
                    inputFile = $configEditorScript
                    outputFile = $configEditorOutput
                    title = "Focus Game Deck - Configuration Editor"
                    description = "GUI configuration editor for Focus Game Deck"
                    company = "Focus Game Deck Project"
                    version = "1.0.0.0"
                    copyright = "MIT License"
                    requireAdmin = $false
                    STA = $true
                    noConsole = $true
                }
                
                ps2exe @ps2exeParams
                
                if (Test-Path $configEditorOutput) {
                    Write-Host "Config Editor executable created: $configEditorOutput" -ForegroundColor Green
                } else {
                    Write-Host "Failed to create Config Editor executable." -ForegroundColor Red
                }
            }
        } else {
            # Copy existing Config Editor to build directory
            $configEditorBuildPath = Join-Path $buildDir "Focus-Game-Deck-Config-Editor.exe"
            Copy-Item $configEditorPath $configEditorBuildPath -Force
            Write-Host "Config Editor copied to build directory: $configEditorBuildPath" -ForegroundColor Green
        }
        
        # Copy necessary files to build directory
        Write-Host "Copying configuration files..." -ForegroundColor Cyan
        
        $configDir = Join-Path $buildDir "config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $sourceConfigDir = Join-Path $PSScriptRoot "config"
        if (Test-Path $sourceConfigDir) {
            Get-ChildItem $sourceConfigDir -Filter "*.json" | ForEach-Object {
                Copy-Item $_.FullName $configDir -Force
            }
        }
        
        # Create launcher scripts in build directory
        $launcherContent = @"
@echo off
echo Focus Game Deck Launcher
echo.
echo Usage: Focus-Game-Deck.exe [GameId]
echo.
echo Available GameIds can be found in config\config.json
echo.
pause
"@
        
        $launcherPath = Join-Path $buildDir "launcher.bat"
        Set-Content -Path $launcherPath -Value $launcherContent -Encoding ASCII
        
        Write-Host "Build completed successfully!" -ForegroundColor Green
        Write-Host "Built files are located in: $buildDir" -ForegroundColor Cyan
        
        # List built files
        Write-Host "`nBuilt files:" -ForegroundColor Yellow
        Get-ChildItem $buildDir -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            $relativePath = $_.FullName.Replace($buildDir, "").TrimStart('\')
            Write-Host "  $relativePath" -ForegroundColor White
        }
        
        # Auto-sign if requested
        if ($Sign -or $All) {
            Write-Host "`nStarting code signing process..." -ForegroundColor Cyan
            $signingScript = Join-Path $PSScriptRoot "Sign-Executables.ps1"
            if (Test-Path $signingScript) {
                & $signingScript -SignAll
            } else {
                Write-Warning "Code signing script not found: $signingScript"
            }
        }
        
    } catch {
        Write-Host "Failed to build executables: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Sign existing build if requested
if ($Sign -and -not $Build) {
    Write-Host "Signing existing build..." -ForegroundColor Yellow
    $signingScript = Join-Path $PSScriptRoot "Sign-Executables.ps1"
    if (Test-Path $signingScript) {
        & $signingScript -SignAll
    } else {
        Write-Error "Code signing script not found: $signingScript"
        exit 1
    }
}

# Show usage if no parameters
if (-not $Install -and -not $Build -and -not $Clean -and -not $Sign -and -not $All) {
    Write-Host "Focus Game Deck - Main Application Build Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\Build-FocusGameDeck.ps1 -Install           # Install ps2exe module"
    Write-Host "  .\Build-FocusGameDeck.ps1 -Build             # Build all executables"
    Write-Host "  .\Build-FocusGameDeck.ps1 -Sign              # Sign existing build"
    Write-Host "  .\Build-FocusGameDeck.ps1 -Clean             # Clean build artifacts"
    Write-Host "  .\Build-FocusGameDeck.ps1 -All               # Install, build, and sign"
    Write-Host "  .\Build-FocusGameDeck.ps1 -Build -Sign       # Build and sign"
    Write-Host ""
    Write-Host "Example workflows:"
    Write-Host "  Development: .\Build-FocusGameDeck.ps1 -Install -Build"
    Write-Host "  Production:  .\Build-FocusGameDeck.ps1 -All"
    Write-Host ""
    Write-Host "This script will create executable versions of:"
    Write-Host "  - Focus-Game-Deck.exe (main application)"
    Write-Host "  - Focus-Game-Deck-MultiPlatform.exe (multiplatform version)"
    Write-Host "  - Focus-Game-Deck-Config-Editor.exe (GUI configuration editor)"
}