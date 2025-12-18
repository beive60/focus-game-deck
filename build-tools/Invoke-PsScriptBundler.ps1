<#
.SYNOPSIS
    PowerShell script bundler for dependency resolution

.DESCRIPTION
    Reads entry-point scripts (like ConfigEditor.ps1, Main.ps1, Invoke-FocusGameDeck.ps1),
    recursively resolves all dot-sourced dependencies (e.g., . $path references to Logger.ps1,
    AppManager.ps1, etc.), and generates a single flat .ps1 file with all dependencies included.

    This eliminates the need for ps2exe's -embedFiles parameter and ensures all code is
    compiled into the final executable.

.PARAMETER EntryPoint
    Path to the entry-point PowerShell script to bundle

.PARAMETER OutputPath
    Path where the bundled script will be written

.PARAMETER ProjectRoot
    Root directory of the project (used to resolve relative paths)

.PARAMETER Verbose
    Enable verbose output for detailed bundling progress

.EXAMPLE
    .\Invoke-PsScriptBundler.ps1 -EntryPoint "gui/ConfigEditor.ps1" -OutputPath "build/ConfigEditor-bundled.ps1"
    Bundles ConfigEditor.ps1 and all its dependencies into a single file

.EXAMPLE
    .\Invoke-PsScriptBundler.ps1 -EntryPoint "src/Invoke-FocusGameDeck.ps1" -OutputPath "build/Invoke-FocusGameDeck-bundled.ps1" -ProjectRoot "C:/project"
    Bundles the game launcher with explicit project root

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
    Responsibility: Handle PowerShell script preprocessing and bundling (SRP)
#>

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$EntryPoint,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

# Import the BuildLogger at script level
. "$PSScriptRoot/utils/BuildLogger.ps1"

function Write-BundlerMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    Write-BuildLog "[$Level] $Message"
}

function Resolve-DotSourcedPath {
    param(
        [string]$Line,
        [string]$CurrentScriptDir,
        [string]$ProjectRoot
    )

    if ($Line -notmatch '^\s*\.\s+(.+)') {
        return $null
    }

    $pathExpression = $Matches[1].Trim()
    $resolvedPath = $null

    # Attempt to resolve using original logic first
    try {
        $tempPath = $pathExpression -replace '["'']', ''
        if ($tempPath -match '\$PSScriptRoot') {
            $resolvedPath = $tempPath -replace '\$PSScriptRoot', $CurrentScriptDir
        } elseif ($tempPath -match '\$projectRoot') {
            $resolvedPath = $tempPath -replace '\$projectRoot', $ProjectRoot
        } else {
            $resolvedPath = Join-Path $CurrentScriptDir $tempPath
        }
        $resolvedPath = [System.IO.Path]::GetFullPath(($resolvedPath -replace '[\\/]+', '/'))
    } catch {
        # This can fail on complex expressions, so we nullify and proceed
        $resolvedPath = $null
    }


    # 1. Test-Path で $resolvedPath が存在するかをチェックし、存在したら return $resolvedPath
    if ($resolvedPath -and (Test-Path $resolvedPath)) {
        return $resolvedPath
    }

    # 2. 存在しない場合、`. (Join-Path ...)` のようなパスを正しくパースする
    if ($pathExpression -match '^\(Join-Path') {
        # Try positional parameters first: (Join-Path $var "path")
        $match = [regex]::Match($pathExpression, '^\(Join-Path\s+\$(\w+)\s+"([^"]+)"\)$')
        if ($match.Success) {
            $baseVarName = $match.Groups[1].Value
            $childPath = $match.Groups[2].Value

            $basePath = ""
            if ($baseVarName -eq 'appRoot' -or $baseVarName -eq 'projectRoot') {
                $basePath = $ProjectRoot
            } elseif ($baseVarName -eq 'PSScriptRoot') {
                $basePath = $CurrentScriptDir
            }

            if ($basePath) {
                $resolvedPath = Join-Path -Path $basePath -ChildPath $childPath
                $resolvedPath = [System.IO.Path]::GetFullPath(($resolvedPath -replace '[\\/]+', '/'))
                return $resolvedPath
            }
        }

        # Try named parameters: (Join-Path -Path $var -ChildPath "path")
        $match = [regex]::Match($pathExpression, '^\(Join-Path\s+-Path\s+\$(\w+)\s+-ChildPath\s+"([^"]+)"\)$')
        if ($match.Success) {
            $baseVarName = $match.Groups[1].Value
            # 2.2. -ChildPathに続く引数を抽出する。
            # 2.3. ダブルクォーテーションを除去する。
            $childPath = $match.Groups[2].Value

            $basePath = ""
            if ($baseVarName -eq 'appRoot' -or $baseVarName -eq 'ProjectRoot') {
                $basePath = $ProjectRoot
            } elseif ($baseVarName -eq 'PSScriptRoot') {
                $basePath = $CurrentScriptDir
            }

            if ($basePath) {
                $resolvedPath = Join-Path -Path $basePath -ChildPath $childPath
                $resolvedPath = [System.IO.Path]::GetFullPath(($resolvedPath -replace '[\\/]+', '/'))
                return $resolvedPath
            }
        }
    }

    # If all else fails, return the original (non-existent) path, which was the original behavior.
    return $resolvedPath
}

function Get-ScriptDependencies {
    param(
        [string]$ScriptPath,
        [string]$ProjectRoot,
        [hashtable]$ProcessedFiles = @{}
    )

    if ($ProcessedFiles.ContainsKey($ScriptPath)) {
        Write-Verbose "Already processed: $ScriptPath"
        return @()
    }

    $ProcessedFiles[$ScriptPath] = $true

    if (-not (Test-Path $ScriptPath)) {
        Write-BundlerMessage "Script not found: $ScriptPath" "WARNING"
        return @()
    }

    Write-Verbose "Processing: $ScriptPath"

    $scriptDir = Split-Path $ScriptPath -Parent
    $content = Get-Content $ScriptPath -Raw -Encoding UTF8

    $dependencies = @()

    $lines = $content -split "`r?`n"
    foreach ($line in $lines) {
        $resolvedPath = Resolve-DotSourcedPath -Line $line -CurrentScriptDir $scriptDir -ProjectRoot $ProjectRoot

        if ($resolvedPath) {
            Write-Verbose "Found dependency: $resolvedPath"
            $dependencies += $resolvedPath

            $nestedDeps = Get-ScriptDependencies -ScriptPath $resolvedPath -ProjectRoot $ProjectRoot -ProcessedFiles $ProcessedFiles
            $dependencies += $nestedDeps
        }
    }

    return $dependencies
}

function New-BundledScript {
    param(
        [string]$EntryPointPath,
        [string]$OutputPath,
        [string]$ProjectRoot
    )

    if (-not (Test-Path $EntryPointPath)) {
        Write-BundlerMessage "Entry point not found: $EntryPointPath" "ERROR"
        return $false
    }

    $processedFiles = @{}

    Write-BundlerMessage "Resolving dependencies for: $(Split-Path $EntryPointPath -Leaf)" "INFO"
    $dependencies = Get-ScriptDependencies -ScriptPath $EntryPointPath -ProjectRoot $ProjectRoot -ProcessedFiles $processedFiles

    # Auto-include XamlResources.ps1 for GUI applications (ConfigEditor, Main.PS1)
    $entryFileName = [System.IO.Path]::GetFileName($EntryPointPath)
    if ($entryFileName -match '^(ConfigEditor|Main)\.ps1$') {
        $xamlResourcesCandidates = @(
            (Join-Path $ProjectRoot "build-tools/build/XamlResources.ps1"),
            (Join-Path $ProjectRoot "src/generated/XamlResources.ps1")  # Backward compatibility
        )

        $xamlResourcesPath = $xamlResourcesCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($xamlResourcesPath -and -not ($dependencies -contains $xamlResourcesPath)) {
            $relativePath = $xamlResourcesPath.Replace($ProjectRoot + [IO.Path]::DirectorySeparatorChar, "") -replace "\\", "/"
            Write-BundlerMessage "Auto-including XamlResources.ps1 for GUI application from $relativePath" "INFO"
            # Add at the beginning so XAML variables are available before UI initialization
            $dependencies = @($xamlResourcesPath) + $dependencies
        }
    }

    # Note: Launcher scripts are NOT auto-included for ConfigEditor
    # ConfigEditor has its own internal shortcut creation functionality
    # External launcher scripts (Create-Launchers-Enhanced.ps1, Create-Launchers.ps1)
    # are standalone scripts and should not be bundled into the executable

    Write-BundlerMessage "Found $($dependencies.Count) dependencies" "INFO"

    $entryContent = Get-Content $EntryPointPath -Raw -Encoding UTF8

    # --- FIX: Extract param block to ensure it remains at the top ---
    $paramBlock = ""
    $mainScriptContent = $entryContent

    # Extract param block to ensure it remains at the top
    # Use a more robust approach: find the param block by matching balanced parentheses
    $paramBlock = ""
    $mainScriptContent = $entryContent

    # Look for param block at the start (may have comments/whitespace before it)
    if ($entryContent -match '(?s)^(.*?)\s*param\s*\(') {
        $beforeParam = $Matches[1]  # Comments/whitespace before param
        $startPos = $Matches[0].Length

        # Count parentheses to find the end of the param block
        $depth = 1
        $endPos = $startPos
        $chars = $entryContent.ToCharArray()

        for ($i = $startPos; $i -lt $chars.Length; $i++) {
            if ($chars[$i] -eq '(') { $depth++ }
            elseif ($chars[$i] -eq ')') {
                $depth--
                if ($depth -eq 0) {
                    $endPos = $i + 1
                    break
                }
            }
        }

        if ($depth -eq 0) {
            $paramBlock = $entryContent.Substring(0, $endPos).Trim() + "`n"
            $mainScriptContent = $entryContent.Substring($endPos).TrimStart()
        }
    }
    # ---------------------------------------------------------------

    # Build bundled content: Header -> Param -> Dependencies -> Main Script
    $bundledContent = @"
# ============================================================================
# BUNDLED SCRIPT - Generated by Invoke-PsScriptBundler.ps1
# Entry Point: $EntryPointPath
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# ============================================================================

$paramBlock

"@

    foreach ($depPath in $dependencies) {
        if (Test-Path $depPath) {
            Write-Verbose "Bundling: $depPath"
            $depContent = Get-Content $depPath -Raw -Encoding UTF8
            # Remove dot-sources from dependencies (line-by-line to handle multiline properly)
            $depContent = ($depContent -split "`r?`n" | Where-Object { $_ -notmatch '^\s*\.\s+' }) -join "`n"

            $bundledContent += @"

# ----------------------------------------------------------------------------
# Source: $depPath
# ----------------------------------------------------------------------------
$depContent

"@
        }
    }

    # Remove dot-sources from main script content (line-by-line to handle multiline properly)
    $mainScriptContent = ($mainScriptContent -split "`r?`n" | Where-Object { $_ -notmatch '^\s*\.\s+' }) -join "`n"

    $bundledContent += @"

# ----------------------------------------------------------------------------
# ENTRY POINT: $EntryPointPath
# ----------------------------------------------------------------------------
$mainScriptContent
"@

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $bundledContent | Set-Content -Path $OutputPath -Encoding UTF8 -Force

    Write-BundlerMessage "Bundled script created: $OutputPath" "SUCCESS"

    $fileSize = [math]::Round((Get-Item $OutputPath).Length / 1KB, 2)
    Write-Verbose "Bundled file size: $fileSize KB"

    return $true
}

try {
    Write-BuildLog "Focus Game Deck - Script Bundler"
    # Separator removed

    $entryPointFull = Join-Path $ProjectRoot $EntryPoint
    if (-not (Test-Path $entryPointFull)) {
        $entryPointFull = $EntryPoint
    }

    $success = New-BundledScript -EntryPointPath $entryPointFull -OutputPath $OutputPath -ProjectRoot $ProjectRoot

    Write-Host ""
    if ($success) {
        Write-BundlerMessage "Script bundling completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-BundlerMessage "Script bundling failed" "ERROR"
        exit 1
    }
} catch {
    Write-BundlerMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    Write-Verbose $_.ScriptStackTrace
    exit 1
}

