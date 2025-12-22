<#
.SYNOPSIS
    Split monolithic messages.json into individual language files

.DESCRIPTION
    Splits the single messages.json file containing all languages into separate files
    per language (en.json, ja.json, etc.) and creates a manifest.json file with
    supported language metadata.

    This improves application startup performance by loading only the required
    language instead of parsing all languages.

.PARAMETER SourceFile
    Path to the source messages.json file (default: localization/messages.json)

.PARAMETER OutputDir
    Output directory for split files (default: localization)

.PARAMETER CreateManifest
    Whether to create manifest.json (default: true)

.PARAMETER BackupOriginal
    Whether to create a backup of the original file (default: true)

.EXAMPLE
    .\Split-MessagesJson.ps1
    Split messages.json using default paths

.EXAMPLE
    .\Split-MessagesJson.ps1 -SourceFile "custom/messages.json" -OutputDir "custom/output"
    Split with custom paths

.NOTES
    Version: 1.0.0
    This script is part of the localization refactoring in Focus Game Deck v3.1
#>

#Requires -Version 5.1

param(
    [string]$SourceFile = "",
    [string]$OutputDir = "",
    [switch]$CreateManifest = $true,
    [switch]$BackupOriginal = $true
)

# Determine project root and default paths
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrEmpty($SourceFile)) {
    $SourceFile = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
}
if ([string]::IsNullOrEmpty($OutputDir)) {
    $OutputDir = Join-Path -Path $projectRoot -ChildPath "localization"
}

Write-Host "Focus Game Deck - Message File Splitter"
Write-Host "========================================"
Write-Host ""

# Validate source file
if (-not (Test-Path $SourceFile)) {
    Write-Error "Source file not found: $SourceFile"
    exit 1
}

Write-Host "Source file: $SourceFile"
Write-Host "Output directory: $OutputDir"
Write-Host ""

# Create backup if requested
if ($BackupOriginal) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = Join-Path -Path $OutputDir -ChildPath "messages.json.backup-$timestamp"
    Write-Host "Creating backup: $backupFile"
    Copy-Item -Path $SourceFile -Destination $backupFile -Force
    Write-Host "[SUCCESS] Backup created" -ForegroundColor Green
    Write-Host ""
}

# Load the source messages.json
Write-Host "Loading source messages..."
try {
    $messages = Get-Content -Path $SourceFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[SUCCESS] Loaded messages.json" -ForegroundColor Green
} catch {
    Write-Error "Failed to load messages.json: $($_.Exception.Message)"
    exit 1
}

# Language metadata
$languageMetadata = @{
    "en" = @{ name = "English"; nativeName = "English" }
    "ja" = @{ name = "Japanese"; nativeName = "日本語" }
    "zh-CN" = @{ name = "Chinese (Simplified)"; nativeName = "简体中文" }
    "ru" = @{ name = "Russian"; nativeName = "Русский" }
    "fr" = @{ name = "French"; nativeName = "Français" }
    "es" = @{ name = "Spanish"; nativeName = "Español" }
    "pt-BR" = @{ name = "Portuguese (Brazil)"; nativeName = "Português (Brasil)" }
    "id-ID" = @{ name = "Indonesian"; nativeName = "Bahasa Indonesia" }
}

Write-Host ""
Write-Host "Splitting into individual language files..."
Write-Host ""

$languageFiles = @()

# Process each language
foreach ($langProperty in $messages.PSObject.Properties) {
    $langCode = $langProperty.Name
    $langData = $langProperty.Value

    $outputFile = Join-Path -Path $OutputDir -ChildPath "$langCode.json"

    Write-Host "Creating $langCode.json..." -NoNewline

    try {
        # Convert to JSON with proper formatting
        $jsonContent = $langData | ConvertTo-Json -Depth 10

        # Write to file with UTF-8 encoding (no BOM)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($outputFile, $jsonContent, $utf8NoBom)

        Write-Host " [SUCCESS]" -ForegroundColor Green

        # Track created files
        $languageFiles += @{
            code = $langCode
            file = "$langCode.json"
            size = (Get-Item $outputFile).Length
        }
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Error "Failed to create $langCode.json: $($_.Exception.Message)"
    }
}

Write-Host ""

# Create manifest.json
if ($CreateManifest) {
    Write-Host "Creating manifest.json..." -NoNewline

    $supportedLanguages = @()
    foreach ($langFile in $languageFiles) {
        $code = $langFile.code
        $metadata = $languageMetadata[$code]

        if ($metadata) {
            $supportedLanguages += @{
                code = $code
                name = $metadata.name
                nativeName = $metadata.nativeName
            }
        } else {
            # Fallback for unknown languages
            $supportedLanguages += @{
                code = $code
                name = $code
                nativeName = $code
            }
        }
    }

    $manifest = @{
        version = "1.0.0"
        supportedLanguages = $supportedLanguages
        defaultLanguage = "en"
        description = "Focus Game Deck localization manifest"
        lastUpdated = (Get-Date -Format "yyyy-MM-dd")
    }

    try {
        $manifestFile = Join-Path -Path $OutputDir -ChildPath "manifest.json"
        $manifestJson = $manifest | ConvertTo-Json -Depth 10

        # Write with UTF-8 no BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($manifestFile, $manifestJson, $utf8NoBom)

        Write-Host " [SUCCESS]" -ForegroundColor Green
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Error "Failed to create manifest.json: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "Split Summary:"
Write-Host ""
Write-Host "Created $($languageFiles.Count) language files:"
foreach ($langFile in $languageFiles) {
    $sizeKB = [math]::Round($langFile.size / 1KB, 2)
    Write-Host "  $($langFile.file) - $sizeKB KB" -ForegroundColor Cyan
}

if ($CreateManifest) {
    Write-Host "  manifest.json" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Total size reduction per startup:"
$originalSize = (Get-Item $SourceFile).Length
$averageLanguageSize = ($languageFiles | Measure-Object -Property size -Average).Average
$reduction = [math]::Round((1 - ($averageLanguageSize / $originalSize)) * 100, 1)
Write-Host "  Original: $([math]::Round($originalSize / 1KB, 2)) KB (all languages)"
Write-Host "  Per language: $([math]::Round($averageLanguageSize / 1KB, 2)) KB (average)"
Write-Host "  Reduction: $reduction%" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:"
Write-Host "1. Test the application with individual language files"
Write-Host "2. Update ConfigEditor.Localization.ps1 and LanguageHelper.ps1"
Write-Host "3. Update Copy-Resources.ps1 to include new file structure"
Write-Host "4. Run tests to verify backward compatibility"
Write-Host ""
Write-Host "[SUCCESS] Split operation completed!" -ForegroundColor Green
