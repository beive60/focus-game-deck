# Focus Game Deck - Release Manager
# Automated release management tool for Focus Game Deck project
#
# This script automates the version management and release process
# including version updates, tag creation, and release preparation.
#
# Author: GitHub Copilot Assistant
# Version: 1.0.0
# Date: 2025-09-24

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("major", "minor", "patch", "prerelease")]
    [string]$UpdateType,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("alpha", "beta", "rc")]
    [string]$PreReleaseType = "alpha",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateTag,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReleaseNotes,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("ja", "en", "both")]
    [string]$Language = "ja",
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseMessage = ""
)

# Import version module
$VersionModulePath = Join-Path $PSScriptRoot "Version.ps1"
if (Test-Path $VersionModulePath) {
    . $VersionModulePath
} else {
    throw "Version module not found: $VersionModulePath"
}

# Configuration
$script:Config = @{
    VersionFile = $VersionModulePath
    GitRepoPath = $PSScriptRoot
    ReleaseNotesTemplate = Join-Path $PSScriptRoot "docs\RELEASE-NOTES-TEMPLATE.md"
    ChangelogFile = Join-Path $PSScriptRoot "CHANGELOG.md"
}

# Helper Functions
function Write-StatusMessage {
    param([string]$Message, [string]$Status = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Status) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    Write-Host "[$timestamp] [$Status] $Message" -ForegroundColor $color
}

function Get-CurrentGitBranch {
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        return $branch
    }
    catch {
        return $null
    }
}

function Get-GitStatus {
    try {
        $status = git status --porcelain 2>$null
        return $status
    }
    catch {
        return $null
    }
}

function Test-GitRepository {
    $currentDir = Get-Location
    Set-Location $script:Config.GitRepoPath
    
    try {
        # Check if git repository
        $null = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not a git repository"
        }
        
        # Check for uncommitted changes
        $status = Get-GitStatus
        if ($status) {
            Write-StatusMessage "Warning: Uncommitted changes detected:" "WARNING"
            $status | ForEach-Object { Write-StatusMessage "  $_" "WARNING" }
            if (-not $DryRun) {
                $response = Read-Host "Continue anyway? (y/N)"
                if ($response -ne "y" -and $response -ne "Y") {
                    throw "Aborted due to uncommitted changes"
                }
            }
        }
        
        # Check current branch
        $branch = Get-CurrentGitBranch
        Write-StatusMessage "Current branch: $branch" "INFO"
        
        return $true
    }
    finally {
        Set-Location $currentDir
    }
}

function Update-VersionInFile {
    param(
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [string]$PreRelease = ""
    )
    
    if ($DryRun) {
        Write-StatusMessage "DRY RUN: Would update version to $Major.$Minor.$Patch$(if($PreRelease){"-$PreRelease"})" "INFO"
        return
    }
    
    # Read current version file
    $content = Get-Content $script:Config.VersionFile -Raw
    
    # Update version values
    $content = $content -replace 'Major = \d+', "Major = $Major"
    $content = $content -replace 'Minor = \d+', "Minor = $Minor"
    $content = $content -replace 'Patch = \d+', "Patch = $Patch"
    $content = $content -replace 'PreRelease = "[^"]*"', "PreRelease = `"$PreRelease`""
    
    # Write updated content
    Set-Content -Path $script:Config.VersionFile -Value $content -NoNewline
    
    Write-StatusMessage "Updated version in $($script:Config.VersionFile)" "SUCCESS"
}

function Get-NextVersion {
    param([string]$UpdateType, [string]$PreReleaseType)
    
    $currentVersion = Get-ProjectVersionInfo
    $major = $currentVersion.Major
    $minor = $currentVersion.Minor
    $patch = $currentVersion.Patch
    $preRelease = $currentVersion.PreRelease
    
    switch ($UpdateType) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
            $preRelease = ""
        }
        "minor" {
            $minor++
            $patch = 0
            $preRelease = ""
        }
        "patch" {
            $patch++
            $preRelease = ""
        }
        "prerelease" {
            if (-not $preRelease) {
                # If no current prerelease, increment patch and add prerelease
                $patch++
                $preRelease = $PreReleaseType
            } else {
                # Update existing prerelease
                if ($preRelease -match '^(alpha|beta|rc)\.?(\d+)?$') {
                    $type = $matches[1]
                    $number = if ($matches[2]) { [int]$matches[2] } else { 0 }
                    
                    if ($PreReleaseType -eq $type) {
                        $number++
                        $preRelease = "$type.$number"
                    } else {
                        $preRelease = $PreReleaseType
                    }
                } else {
                    $preRelease = $PreReleaseType
                }
            }
        }
    }
    
    return @{
        Major = $major
        Minor = $minor
        Patch = $patch
        PreRelease = $preRelease
        VersionString = "$major.$minor.$patch$(if($preRelease){"-$preRelease"})"
    }
}

function New-GitTag {
    param([string]$TagName, [string]$Message)
    
    $currentDir = Get-Location
    Set-Location $script:Config.GitRepoPath
    
    try {
        if ($DryRun) {
            Write-StatusMessage "DRY RUN: Would create tag '$TagName'" "INFO"
            return
        }
        
        # Create annotated tag
        git tag -a $TagName -m $Message
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create git tag"
        }
        
        Write-StatusMessage "Created git tag: $TagName" "SUCCESS"
        
        # Ask if user wants to push the tag
        $response = Read-Host "Push tag to remote? (Y/n)"
        if ($response -ne "n" -and $response -ne "N") {
            git push origin $TagName
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "Pushed tag to remote: $TagName" "SUCCESS"
            } else {
                Write-StatusMessage "Failed to push tag to remote" "ERROR"
            }
        }
    }
    finally {
        Set-Location $currentDir
    }
}

function New-ReleaseNotes {
    param(
        [string]$Version,
        [string]$TagName,
        [bool]$IsPreRelease,
        [ValidateSet("ja", "en", "both")]
        [string]$Language = "ja"  # Default to Japanese as main target
    )
    
    if ($DryRun) {
        Write-StatusMessage "DRY RUN: Would generate release notes for $Version (Language: $Language)" "INFO"
        return
    }
    
    # Define release types in both languages
    $releaseTypes = @{
        ja = @{
            alpha = "アルファ版"
            beta = "ベータ版"
            rc = "リリース候補版"
            prerelease = "プレリリース版"
            official = "正式リリース版"
        }
        en = @{
            alpha = "Alpha"
            beta = "Beta"
            rc = "Release Candidate"
            prerelease = "Pre-release"
            official = "Official Release"
        }
    }
    
    function Get-ReleaseType($lang, $isPreRelease) {
        if ($isPreRelease) {
            if ($Version -match "alpha") { return $releaseTypes[$lang].alpha }
            elseif ($Version -match "beta") { return $releaseTypes[$lang].beta }
            elseif ($Version -match "rc") { return $releaseTypes[$lang].rc }
            else { return $releaseTypes[$lang].prerelease }
        } else { 
            return $releaseTypes[$lang].official 
        }
    }
    
    # Generate templates based on language selection
    $templates = @{}
    
    # Japanese template (main target)
    $templates.ja = @"
## 🚀 Focus Game Deck $Version - $(Get-ReleaseType "ja" $IsPreRelease)

### ⚠️ $(Get-ReleaseType "ja" $IsPreRelease) について
$(if ($IsPreRelease) {
"これは$(Get-ReleaseType "ja" $IsPreRelease)であり、テスト目的でのみ提供されています。本番環境での使用は推奨されません。"
} else {
"本番環境での使用を推奨する正式リリース版です。"
})

### 📋 新機能・変更点
- ✅ [新機能や改善点を記載してください]
- 🔧 [修正や改善点を記載してください]
- 🐛 [修正されたバグを記載してください]

### 🐛 既知の問題
- [既知の問題があれば記載してください]

### 💔 破壊的変更
- [互換性に影響する変更があれば記載してください]

### 🔧 システム要件
- Windows 10/11 (64-bit)
- .NET Framework 4.8以上
- PowerShell 5.1以上

### 📥 ダウンロード・インストール
1. `FocusGameDeck-$Version-Setup.exe` をダウンロード
2. SHA256ハッシュを確認: `[HASH_VALUE_TO_BE_FILLED]`
3. 管理者権限で実行
4. インストールウィザードに従ってください

### 🔒 セキュリティ・信頼性
- ✅ デジタル署名済み実行ファイル
- ✅ マルウェアスキャン済み
- ✅ オープンソース (MIT ライセンス)

### 🤝 フィードバック・サポート
問題や要望は [GitHub Issues](https://github.com/beive60/focus-game-deck/issues) にてお報告ください

---
**リリース日**: $(Get-Date -Format "yyyy年MM月dd日")  
**ビルド**: [BUILD_NUMBER_TO_BE_FILLED]  
**コミット**: [COMMIT_HASH_TO_BE_FILLED]
"@

    # English template (international support)
    $templates.en = @"
## 🚀 Focus Game Deck $Version - $(Get-ReleaseType "en" $IsPreRelease)

### ⚠️ $(Get-ReleaseType "en" $IsPreRelease) Notice
$(if ($IsPreRelease) {
"This is a $(Get-ReleaseType "en" $IsPreRelease) version for testing purposes only. Not recommended for production use."
} else {
"Official release version recommended for production use."
})

### 📋 What's New
- ✅ [Please describe new features and improvements]
- 🔧 [Please describe fixes and improvements]
- 🐛 [Please describe bugs that were fixed]

### 🐛 Known Issues
- [Please describe any known issues]

### 💔 Breaking Changes
- [Please describe any breaking changes]

### 🔧 System Requirements
- Windows 10/11 (64-bit)
- .NET Framework 4.8+
- PowerShell 5.1+

### 📥 Download & Installation
1. Download `FocusGameDeck-$Version-Setup.exe`
2. Verify SHA256: `[HASH_VALUE_TO_BE_FILLED]`
3. Run as Administrator
4. Follow installation wizard

### 🔒 Security & Trust
- ✅ Digitally signed executable
- ✅ Scanned for malware
- ✅ Open source (MIT License)

### 🤝 Feedback & Support
Please report issues via [GitHub Issues](https://github.com/beive60/focus-game-deck/issues)

---
**Release Date**: $(Get-Date -Format "yyyy-MM-dd")  
**Build**: [BUILD_NUMBER_TO_BE_FILLED]  
**Commit**: [COMMIT_HASH_TO_BE_FILLED]
"@

    # Generate files based on language selection
    $generatedFiles = @()
    
    if ($Language -eq "both") {
        # Generate both Japanese and English versions
        $jaFile = Join-Path $PSScriptRoot "release-notes-$Version-ja.md"
        $enFile = Join-Path $PSScriptRoot "release-notes-$Version-en.md"
        
        Set-Content -Path $jaFile -Value $templates.ja
        Set-Content -Path $enFile -Value $templates.en
        
        $generatedFiles += $jaFile, $enFile
        Write-StatusMessage "Generated Japanese release notes: $jaFile" "SUCCESS"
        Write-StatusMessage "Generated English release notes: $enFile" "SUCCESS"
    } else {
        # Generate single language version
        $suffix = if ($Language -eq "ja") { "" } else { "-$Language" }
        $notesFile = Join-Path $PSScriptRoot "release-notes-$Version$suffix.md"
        
        Set-Content -Path $notesFile -Value $templates[$Language]
        $generatedFiles += $notesFile
        Write-StatusMessage "Generated release notes ($Language): $notesFile" "SUCCESS"
    }
    
    Write-StatusMessage "Please edit the release notes file(s) before creating the release" "INFO"
    
    return $generatedFiles
}

function Invoke-ReleaseProcess {
    Write-StatusMessage "Starting release process..." "INFO"
    Write-StatusMessage "Update type: $UpdateType" "INFO"
    if ($UpdateType -eq "prerelease") {
        Write-StatusMessage "Pre-release type: $PreReleaseType" "INFO"
    }
    
    # Validate git repository
    Write-StatusMessage "Validating git repository..." "INFO"
    Test-GitRepository | Out-Null
    
    # Get current version info
    $currentVersion = Get-ProjectVersionInfo
    Write-StatusMessage "Current version: $($currentVersion.FullVersion)" "INFO"
    
    # Calculate next version
    $nextVersion = Get-NextVersion -UpdateType $UpdateType -PreReleaseType $PreReleaseType
    Write-StatusMessage "Next version: $($nextVersion.VersionString)" "INFO"
    
    # Update version file
    Write-StatusMessage "Updating version file..." "INFO"
    Update-VersionInFile -Major $nextVersion.Major -Minor $nextVersion.Minor -Patch $nextVersion.Patch -PreRelease $nextVersion.PreRelease
    
    # Create git tag if requested
    if ($CreateTag) {
        $tagName = "v$($nextVersion.VersionString)"
        $tagMessage = if ($ReleaseMessage) { $ReleaseMessage } else { "Release $($nextVersion.VersionString)" }
        
        Write-StatusMessage "Creating git tag..." "INFO"
        New-GitTag -TagName $tagName -Message $tagMessage
    }
    
    # Generate release notes if requested
    if ($GenerateReleaseNotes) {
        Write-StatusMessage "Generating release notes (Language: $Language)..." "INFO"
        $isPreRelease = [bool]$nextVersion.PreRelease
        $notesFiles = New-ReleaseNotes -Version $nextVersion.VersionString -TagName "v$($nextVersion.VersionString)" -IsPreRelease $isPreRelease -Language $Language
    }
    
    Write-StatusMessage "Release process completed successfully!" "SUCCESS"
    Write-StatusMessage "New version: $($nextVersion.VersionString)" "SUCCESS"
    
    if ($CreateTag -and -not $DryRun) {
        Write-StatusMessage "Git tag created: v$($nextVersion.VersionString)" "SUCCESS"
    }
    
    if ($GenerateReleaseNotes -and -not $DryRun) {
        if ($notesFiles -is [array]) {
            $notesFiles | ForEach-Object { Write-StatusMessage "Release notes generated: $_" "SUCCESS" }
        } else {
            Write-StatusMessage "Release notes generated: $notesFiles" "SUCCESS"
        }
        Write-StatusMessage "Please edit the release notes before publishing" "INFO"
    }
    
    if ($DryRun) {
        Write-StatusMessage "This was a DRY RUN - no actual changes were made" "WARNING"
    }
}

# Main execution
try {
    Invoke-ReleaseProcess
}
catch {
    Write-StatusMessage "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}