<#
.SYNOPSIS
Converts the source SVG icon to a multi-resolution ICO file using ImageMagick.

.DESCRIPTION
This script automates the conversion of the master icon file (assets/icon.svg)
into the .ico format required for the application executable.

It requires ImageMagick to be installed and available in the system's PATH.

The script generates an ICO file containing multiple resolutions (256x256, 128x128, 64x64, 32x32, 16x16)
to ensure proper display across different areas of the Windows OS.

.NOTES
Author: Gemini
Date: 2025-10-22
#>
param()

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Configuration ---
$projectRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
$SvgIconPath = Join-Path -Path $projectRoot -ChildPath 'assets/icon.svg'
$IcoOutputPath = Join-Path -Path $projectRoot -ChildPath 'assets/icon.ico'
$Resolutions = @(256, 128, 64, 32, 16)

# --- Pre-flight Checks ---
Write-Host "Checking for ImageMagick..."
try {
    $magickVersion = magick -version
    Write-Host "ImageMagick found."
    # Write-Host $magickVersion # Uncomment for debugging
} catch {
    Write-Error "ImageMagick not found. Please install it and ensure 'magick.exe' is in your system's PATH."
    exit 1
}

if (-not (Test-Path -Path $SvgIconPath)) {
    Write-Error "Source icon not found at: $SvgIconPath"
    exit 1
}

# --- Conversion Logic ---
Write-Host "Starting icon conversion..."
$tempDir = Join-Path -Path $env:TEMP -ChildPath "icon-temp-$($PID)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$tempPngFiles = @()
foreach ($res in $Resolutions) {
    $tempPngPath = Join-Path -Path $tempDir -ChildPath "icon_${res}x${res}.png"
    $tempPngFiles += $tempPngPath
    Write-Host "Generating ${res}x${res} PNG..."
    magick -background none -size "${res}x${res}" "$SvgIconPath" "$tempPngPath"
}

Write-Host "Assembling ICO file from PNGs..."
magick $tempPngFiles "$IcoOutputPath"

# --- Cleanup ---
Write-Host "Cleaning up temporary files..."
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "--------------------------------------------------"
Write-Host "Successfully created '$IcoOutputPath' with resolutions: $($Resolutions -join ', ')."
Write-Host "Please review the new icon and commit both 'icon.svg' and 'icon.ico' if the changes are correct."
