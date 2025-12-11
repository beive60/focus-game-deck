<#
.SYNOPSIS
    Create final distribution package

.DESCRIPTION
    Assembles all build artifacts into the final distribution package in the release/ directory.
    Collects signed executables, copied resources, and creates package documentation.

    Creates a complete, ready-to-distribute package with:
    - All executables (signed or unsigned)
    - Configuration files
    - Localization resources
    - GUI assets
    - Documentation and version information

.PARAMETER SourceDir
    Source directory containing built artifacts (default: build-tools/dist)

.PARAMETER DestinationDir
    Destination directory for the release package (default: release/)

.PARAMETER IsSigned
    Indicates whether the executables are digitally signed

.PARAMETER Version
    Version string for the package (default: read from Version.ps1)

.PARAMETER Verbose
    Enable verbose output for detailed packaging progress

.EXAMPLE
    .\Create-Package.ps1
    Creates release package from default dist directory

.EXAMPLE
    .\Create-Package.ps1 -IsSigned -Version "3.0.0"
    Creates signed release package with explicit version

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
    Responsibility: Create the final distribution package (SRP)
#>

#Requires -Version 5.1

param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "dist"),
    [string]$DestinationDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "release"),
    [switch]$IsSigned,
    [string]$Version = "",
    [switch]$Verbose
)

# Import the BuildLogger at script level
. "$PSScriptRoot/utils/BuildLogger.ps1"

if ($Verbose) {
    $VerbosePreference = "Continue"
}

function Write-PackageMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    Write-BuildLog "[$Level] $Message"
}

function Get-ProjectVersion {
    $versionScript = Join-Path $PSScriptRoot "Version.ps1"

    if (Test-Path $versionScript) {
        try {
            . $versionScript
            return Get-ProjectVersion -IncludePreRelease
        } catch {
            Write-Verbose "Failed to get version from Version.ps1: $($_.Exception.Message)"
        }
    }

    return "3.0.0"
}

function New-ReleaseReadme {
    param(
        [string]$Version,
        [bool]$IsSigned,
        [string]$BuildDate,
        [string]$Language = "en"
    )

    # Define localized content
    $localizedContent = @{
        "en" = @{
            "title" = "Focus Game Deck - Release Package"
            "version" = "Version"
            "buildDate" = "Build Date"
            "signed" = "Signed"
            "yes" = "Yes"
            "no" = "No"
            "filesIncluded" = "Files Included"
            "configEditor" = "GUI configuration editor for managing game profiles and settings"
            "mainApp" = "Main application executable (unified launcher and game runner)"
            "scriptExecutor" = "PowerShell script executor for running games with optimizations"
            "localization" = "Localization resources for multi-language support"
            "readme" = "This file"
            "installation" = "Installation"
            "step1" = "Extract all files to a directory of your choice"
            "step2" = "Run ConfigEditor.exe to open the configuration editor"
            "step3" = "Configure your games and settings"
            "step4" = "Run Focus-Game-Deck.exe [GameId] to launch games with optimized settings"
            "architecture" = "Architecture"
            "arch1" = "All PowerShell scripts are bundled into the executables"
            "arch2" = "Configuration files are automatically generated when needed"
            "arch3" = "Self-contained with minimal external dependencies"
            "documentation" = "Documentation"
            "docText" = "For complete documentation, visit:"
            "license" = "License"
            "licenseText" = "This software is released under the MIT License."
        }
        "ja" = @{
            "title" = "Focus Game Deck - リリースパッケージ"
            "version" = "バージョン"
            "buildDate" = "ビルド日時"
            "signed" = "署名済み"
            "yes" = "はい"
            "no" = "いいえ"
            "filesIncluded" = "含まれるファイル"
            "configEditor" = "ゲームプロファイルと設定を管理するGUI設定エディタ"
            "mainApp" = "メインアプリケーション実行可能ファイル（統合ランチャーとゲームランナー）"
            "scriptExecutor" = "ゲーム実行用の最適化を行うPowerScriptスクリプト実行機"
            "localization" = "多言語対応のローカライゼーションリソース"
            "readme" = "このファイル"
            "installation" = "インストール方法"
            "step1" = "すべてのファイルを任意のディレクトリに抽出します"
            "step2" = "ConfigEditor.exe を実行して設定エディタを開きます"
            "step3" = "ゲームと設定を構成します"
            "step4" = "Focus-Game-Deck.exe [GameId] を実行して、ゲームを最適化された設定で起動します"
            "architecture" = "アーキテクチャ"
            "arch1" = "すべてのPowerShellスクリプトは実行可能ファイルにバンドルされています"
            "arch2" = "設定ファイルは必要に応じて自動的に生成されます"
            "arch3" = "自己完結型で、外部依存関係は最小限です"
            "documentation" = "ドキュメント"
            "docText" = "完全なドキュメントについては、以下をご覧ください："
            "license" = "ライセンス"
            "licenseText" = "このソフトウェアはMITライセンスの下でリリースされています。"
        }
    }

    # Get localized strings, fall back to English if language not found
    $strings = $localizedContent[$Language]
    if (-not $strings) {
        $strings = $localizedContent["en"]
    }

    $readme = @(
        "# $($strings["title"])"
        ""
        "**$($strings["version"]):** $Version"
        "**$($strings["buildDate"]):** $BuildDate"
        "**$($strings["signed"]):** $(if ($IsSigned) { $strings["yes"] } else { $strings["no"] })"
        ""
        "## $($strings["filesIncluded"])"
        ""
        "- **ConfigEditor.exe**: $($strings["configEditor"])"
        "- **Focus-Game-Deck.exe**: $($strings["mainApp"])"
        "- **Invoke-FocusGameDeck.exe**: $($strings["scriptExecutor"])"
        "- **localization/messages.json**: $($strings["localization"])"
        "- **README.txt**: $($strings["readme"])"
        ""
        "## $($strings["installation"])"
        ""
        "1. $($strings["step1"])"
        "2. $($strings["step2"])"
        "3. $($strings["step3"])"
        "4. $($strings["step4"])"
        ""
        "## $($strings["architecture"])"
        ""
        "This release uses a bundled executable architecture:"
        "- $($strings["arch1"])"
        "- $($strings["arch2"])"
        "- $($strings["arch3"])"
        ""
        "## $($strings["documentation"])"
        ""
        "$($strings["docText"])"
        "https://github.com/beive60/focus-game-deck"
        ""
        "## $($strings["license"])"
        ""
        "$($strings["licenseText"])"
    ) -join "`n"

    return $readme
}

try {
    Write-BuildLog "Focus Game Deck - Package Creator"
    # Separator removed

    if (-not (Test-Path $SourceDir)) {
        Write-PackageMessage "Source directory not found: $SourceDir" "ERROR"
        Write-PackageMessage "Please run Build-Executables.ps1 and Copy-Resources.ps1 first" "ERROR"
        exit 1
    }

    if ([string]::IsNullOrEmpty($Version)) {
        $Version = Get-ProjectVersion
        Write-Verbose "Using version: $Version"
    }

    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-PackageMessage "Creating release package..." "INFO"
    Write-Verbose "  Source: $SourceDir"
    Write-Verbose "  Destination: $DestinationDir"
    Write-Verbose "  Version: $Version"
    Write-Verbose "  Signed: $IsSigned"

    if (Test-Path $DestinationDir) {
        Write-PackageMessage "Cleaning existing release directory..." "INFO"
        Remove-Item $DestinationDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null

    Write-PackageMessage "Copying files to release directory..." "INFO"

    # Copy only required executables
    $executablesToCopy = @(
        "ConfigEditor.exe",
        "Focus-Game-Deck.exe",
        "Invoke-FocusGameDeck.exe"
    )

    foreach ($exe in $executablesToCopy) {
        $sourcePath = Join-Path $SourceDir $exe
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $DestinationDir -Force
            Write-Verbose "  Copied: $exe"
        } else {
            Write-PackageMessage "Warning: $exe not found in source directory" "WARN"
        }
    }

    # Copy localization/messages.json
    $localizationDir = Join-Path $DestinationDir "localization"
    New-Item -ItemType Directory -Path $localizationDir -Force | Out-Null

    $messagesSource = Join-Path $SourceDir "localization/messages.json"
    if (Test-Path $messagesSource) {
        Copy-Item -Path $messagesSource -Destination (Join-Path $localizationDir "messages.json") -Force
        Write-Verbose "  Copied: localization/messages.json"
    } else {
        Write-PackageMessage "Warning: localization/messages.json not found" "WARN"
    }

    $fileCount = (Get-ChildItem $DestinationDir -Recurse -File).Count
    Write-PackageMessage "Copied $fileCount files" "SUCCESS"

    Write-PackageMessage "Creating release documentation..." "INFO"

    # Create default README (using localized content based on system settings or first available language)
    $defaultLanguage = "en"
    $readmeContent = New-ReleaseReadme -Version $Version -IsSigned $IsSigned -BuildDate $buildDate -Language $defaultLanguage

    # Create README.txt in source directory (dist) - default language, no language suffix
    $sourceReadmePath = Join-Path $SourceDir "README.txt"
    Set-Content -Path $sourceReadmePath -Value $readmeContent -Encoding UTF8
    Write-Verbose "  Created: README.txt in source directory"

    # Create README.txt in destination directory (release) - default language, no language suffix
    $readmePath = Join-Path $DestinationDir "README.txt"
    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
    Write-Verbose "  Created: README.txt in release directory"

    # Create language-specific versions
    $languages = @("en", "ja")
    foreach ($lang in $languages) {
        $langReadmeContent = New-ReleaseReadme -Version $Version -IsSigned $IsSigned -BuildDate $buildDate -Language $lang

        # Create in source directory (dist)
        $sourceLangReadmePath = Join-Path $SourceDir "README.$lang.txt"
        Set-Content -Path $sourceLangReadmePath -Value $langReadmeContent -Encoding UTF8
        Write-Verbose "  Created: README.$lang.txt in source directory"

        # Create in destination directory (release)
        $destLangReadmePath = Join-Path $DestinationDir "README.$lang.txt"
        Set-Content -Path $destLangReadmePath -Value $langReadmeContent -Encoding UTF8
        Write-Verbose "  Created: README.$lang.txt in release directory"
    }

    Write-Host ""
    # Separator removed
    Write-BuildLog "PACKAGE SUMMARY"
    # Separator removed

    Write-BuildLog "Version: $Version"
    Write-BuildLog "Build Date: $buildDate"
    Write-BuildLog "Signed: $(if ($IsSigned) { 'Yes' } else { 'No' })"
    Write-BuildLog "Location: $DestinationDir"

    Write-Host ""
    Write-BuildLog "Executables:"
    Get-ChildItem $DestinationDir -Filter "*.exe" -Recurse | ForEach-Object {
        $fileSize = [math]::Round($_.Length / 1KB, 1)
        $signStatus = "(unknown)"
        try {
            $signature = Get-AuthenticodeSignature -FilePath $_.FullName -ErrorAction Stop
            $signStatus = if ($signature.Status -eq "Valid") { "(signed)" } else { "(unsigned)" }
        } catch {
            Write-Verbose "Could not check signature for $($_.Name): $($_.Exception.Message)"
            $signStatus = "(signature check failed)"
        }
        Write-BuildLog "  $($_.Name) ($fileSize KB) $signStatus"
    }

    Write-Host ""
    Write-BuildLog "Total package size: $([math]::Round((Get-ChildItem $DestinationDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB"

    Write-Host ""
    Write-PackageMessage "Release package created successfully!" "SUCCESS"
    exit 0

} catch {
    Write-PackageMessage "Unexpected error: $($_.Exception.Message)" "ERROR"
    Write-Verbose $_.ScriptStackTrace
    exit 1
}
