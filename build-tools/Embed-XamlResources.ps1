<#
.SYNOPSIS
    Embed XAML resources as PowerShell string variables

.DESCRIPTION
    Reads all .xaml files from the gui/ directory and converts them into PowerShell
    Here-String format variables. The output is written to build-tools/build/XamlResources.ps1
    which can be dot-sourced by the main application to access embedded XAML content.

    This allows the application to run without external XAML file dependencies in
    production builds while maintaining the ability to load from files during development.

.PARAMETER ProjectRoot
    Root directory of the project (default: parent of build-tools)

.PARAMETER OutputPath
    Path where the generated XamlResources.ps1 file will be written
    (default: build-tools/build/XamlResources.ps1)

.PARAMETER Verbose
    Enable verbose output for detailed processing information

.EXAMPLE
    .\Embed-XamlResources.ps1
    Embeds all XAML files using default paths

.EXAMPLE
    .\Embed-XamlResources.ps1 -Verbose
    Embeds XAML files with detailed progress output

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
    Responsibility: Convert XAML files to embedded PowerShell variables (SRP)
#>

#Requires -Version 5.1

param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputPath = "",
    [switch]$Verbose
)

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-EmbedMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    Write-Host "[$Level] $Message"
}

function Convert-XamlFileToVariable {
    param(
        [string]$FilePath,
        [string]$FileName
    )

    try {
        Write-Verbose "Processing XAML file: $FileName"

        $xamlContent = Get-Content -Path $FilePath -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($xamlContent)) {
            Write-EmbedMessage "XAML file is empty: $FileName" "WARNING"
            return $null
        }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $baseName = $baseName -replace '[^a-zA-Z0-9_]', '_'

        # Ensure variable name doesn't start with a number
        if ($baseName -match '^[0-9]') {
            $baseName = '_' + $baseName
        }

        $variableName = "Global:Xaml_$baseName"

        # Check if XAML content contains the Here-String terminator sequence
        if ($xamlContent -match '\"@') {
            Write-Verbose "  XAML contains Here-String terminator, using alternative string construction"
            # Use single-quoted here-string which doesn't interpret escape sequences
            $escapedContent = $xamlContent -replace "'", "''"
            $variableDefinition = "`$$variableName = @'`n$escapedContent`n'@"
        } else {
            # Always use single-quoted here-string to preserve $ symbols for runtime replacement
            # Double-quoted here-strings would expand $variables at build time, causing placeholders to become empty
            $escapedContent = $xamlContent -replace "'", "''"
            $variableDefinition = "`$$variableName = @'`n$escapedContent`n'@"
        }

        Write-Verbose "  Variable name: $variableName"
        Write-Verbose "  Content length: $($xamlContent.Length) characters"

        return $variableDefinition

    } catch {
        Write-EmbedMessage "Failed to process $FileName : $($_.Exception.Message)" "ERROR"
        return $null
    }
}

try {
    Write-Host "Focus Game Deck - XAML Resource Embedder"
    Write-Host ("=" * 60)
    Write-Host ""

    $guiPath = Join-Path -Path $ProjectRoot -ChildPath "gui"

    if (-not (Test-Path $guiPath)) {
        Write-EmbedMessage "GUI directory not found: $guiPath" "ERROR"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path -Path $PSScriptRoot -ChildPath "build/XamlResources.ps1"
    }

    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        Write-EmbedMessage "Creating output directory: $outputDir" "INFO"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # Get all XAML and XAML-related files (*.xaml, *.xaml.fragment, etc.)
    $xamlFiles = Get-ChildItem -Path $guiPath -File | Where-Object {
        $_.Name -match '\.xaml($|\.)'
    } | Sort-Object Name

    if ($xamlFiles.Count -eq 0) {
        Write-EmbedMessage "No XAML files found in: $guiPath" "WARNING"
        exit 0
    }

    Write-EmbedMessage "Found $($xamlFiles.Count) XAML file(s) in gui/" "INFO"
    Write-Host ""

    $variableDefinitions = @()
    $processedCount = 0

    foreach ($xamlFile in $xamlFiles) {
        $variableDef = Convert-XamlFileToVariable -FilePath $xamlFile.FullName -FileName $xamlFile.Name

        if ($null -ne $variableDef) {
            $variableDefinitions += $variableDef
            $processedCount++
            Write-EmbedMessage "Converted: $($xamlFile.Name)" "SUCCESS"
        }
    }

    Write-Host ""
    Write-EmbedMessage "Generating output file: $OutputPath" "INFO"

    $header = @"
# Auto-generated by Embed-XamlResources.ps1
# DO NOT EDIT THIS FILE MANUALLY
# Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
#
# This file contains embedded XAML resources as PowerShell Here-String variables.
# Each XAML file from gui/ directory is converted to a global variable.
# Variable naming convention: `$Global:Xaml_<FileName>
#
# Example: gui/MainWindow.xaml -> `$Global:Xaml_MainWindow

"@

    $outputContent = $header + ($variableDefinitions -join "`n`n")

    Set-Content -Path $OutputPath -Value $outputContent -Encoding UTF8 -Force

    $readmePath = Join-Path -Path $outputDir -ChildPath "README.md"
    $readmeContent = @"
# Generated Files Directory

This directory contains auto-generated PowerShell files created during the build process.

## XamlResources.ps1

**Generated by**: build-tools/Embed-XamlResources.ps1

**Purpose**: Contains embedded XAML UI resources as PowerShell Here-String variables.

**Usage**: This file is dot-sourced automatically during bundling for GUI entry points. To load manually in a development session:

```
. ./build-tools/build/XamlResources.ps1
. ./gui/ConfigEditor.ps1
```

**Variables**:
- All XAML files from gui/ directory are embedded as $Global:Xaml_<FileName> variables
- Examples:
    - $Global:Xaml_MainWindow - Main application window XAML
    - $Global:Xaml_ConfirmSaveChangesDialog_fragment - Dialog fragment XAML
    - $Global:Xaml_NewTabs_xaml - New tabs fragment XAML
- Variable names are derived from file names with special characters replaced by underscores

**Note**:
- This directory and its contents are excluded from version control (see .gitignore)
- The files are regenerated during each build process
- ConfigEditor automatically falls back to file-based XAML loading when these variables are not available (development mode)

## Why Embed XAML?

Embedding XAML as PowerShell variables provides several benefits:

1. Single Executable Distribution: No need to distribute separate XAML files
2. Reduced Package Size: Eliminates redundant file copies in release packages
3. Simpler Deployment: Users only need to download one .exe file
4. Development Flexibility: Source XAML files remain editable during development

## Build Integration

The Embed-XamlResources.ps1 script runs early in the build process, before bundling and compilation:

1. Run Embed-XamlResources.ps1 to generate this file (Release-Manager.ps1 calls it automatically)
2. Bundle scripts (which include this generated file via dot-sourcing)
3. Compile bundled scripts to executables
4. Copy other resources (XAML files are skipped)
5. Sign and package the release
"@

    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8 -Force
    Write-EmbedMessage "Generated README: $readmePath" "INFO"

    Write-Host ""
    Write-Host ("=" * 60)
    Write-Host "EMBEDDING SUMMARY"
    Write-Host ("=" * 60)
    Write-EmbedMessage "Total XAML files found: $($xamlFiles.Count)" "INFO"
    Write-EmbedMessage "Successfully converted: $processedCount" "SUCCESS"
    Write-EmbedMessage "Output file: $OutputPath" "INFO"
    Write-Host ""

    if ($processedCount -eq $xamlFiles.Count) {
        Write-EmbedMessage "All XAML files embedded successfully!" "SUCCESS"
        exit 0
    } else {
        Write-EmbedMessage "Some XAML files failed to embed. Check errors above." "WARNING"
        exit 1
    }

} catch {
    Write-EmbedMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    Write-Verbose $_.ScriptStackTrace
    exit 1
}
