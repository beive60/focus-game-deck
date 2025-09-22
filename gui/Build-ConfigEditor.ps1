# Focus Game Deck - Config Editor Build Script
# This script creates an executable version of the config editor

param(
    [switch]$Install,
    [switch]$Build
)

# Check if ps2exe is installed
function Test-PS2EXE {
    try {
        $module = Get-Module -ListAvailable -Name ps2exe
        return $module -ne $null
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

# Build executable
if ($Build) {
    Write-Host "Building executable..." -ForegroundColor Yellow
    
    if (-not (Test-PS2EXE)) {
        Write-Host "ps2exe module is not installed. Run with -Install parameter first." -ForegroundColor Red
        exit 1
    }
    
    try {
        Import-Module ps2exe
        
        $scriptPath = Join-Path $PSScriptRoot "ConfigEditor.ps1"
        $outputPath = Join-Path $PSScriptRoot "Focus-Game-Deck-Config-Editor.exe"
        $iconPath = Join-Path $PSScriptRoot "..\docs\icon.ico"  # Optional: add icon if available
        
        $ps2exeParams = @{
            inputFile = $scriptPath
            outputFile = $outputPath
            title = "Focus Game Deck - Configuration Editor"
            description = "GUI configuration editor for Focus Game Deck"
            company = "Focus Game Deck Project"
            version = "1.0.0.0"
            copyright = "MIT License"
            requireAdmin = $false
            STA = $true
            noConsole = $true
        }
        
        # Add icon if it exists
        if (Test-Path $iconPath) {
            $ps2exeParams.iconFile = $iconPath
        }
        
        ps2exe @ps2exeParams
        
        if (Test-Path $outputPath) {
            Write-Host "Executable created successfully: $outputPath" -ForegroundColor Green
            Write-Host "You can now distribute this single .exe file." -ForegroundColor Green
        } else {
            Write-Host "Failed to create executable." -ForegroundColor Red
            exit 1
        }
        
    } catch {
        Write-Host "Failed to build executable: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Show usage if no parameters
if (-not $Install -and -not $Build) {
    Write-Host "Focus Game Deck - Config Editor Build Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\Build-ConfigEditor.ps1 -Install    # Install ps2exe module"
    Write-Host "  .\Build-ConfigEditor.ps1 -Build      # Build executable"
    Write-Host "  .\Build-ConfigEditor.ps1 -Install -Build  # Install and build"
    Write-Host ""
    Write-Host "Example workflow:"
    Write-Host "  1. .\Build-ConfigEditor.ps1 -Install"
    Write-Host "  2. .\Build-ConfigEditor.ps1 -Build"
}