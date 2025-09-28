# Developer Release Process Guide

This comprehensive guide covers the complete release workflow for Focus Game Deck, from development to GitHub Releases management.

## Overview

This guide provides practical procedures for developers to execute version management and release processes. It covers all steps from daily development work to production release distribution.

## Prerequisites

### Required Tools

- **Git**: Version control and tag creation
- **PowerShell 5.1+**: Release management script execution
- **Visual Studio Code**: Recommended editor (optional)
- **Code Signing Certificate**: For digital signatures (release only)

### Environment Setup Verification

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Check Git configuration
git config --global user.name
git config --global user.email

# Check repository status
.\scripts\Version-Helper.ps1 check
```

## Daily Development Workflow

### 1. Pre-Development Checks

```powershell
# Update to latest state
git pull origin main

# Check current version
.\scripts\Version-Helper.ps1 info

# Create working branch (if needed)
git checkout -b feature/new-feature
```

### 2. Commit Conventions During Development

#### Commit Message Format

```text
<type>: <description>

[optional body]

[optional footer]
```

#### Commit Types

| Type | Description | Version Impact |
|------|-------------|----------------|
| `feat` | New feature addition | MINOR++ |
| `fix` | Bug fix | PATCH++ |
| `docs` | Documentation changes only | None |
| `style` | Code formatting (no functional changes) | None |
| `refactor` | Refactoring | PATCH++ |
| `test` | Test addition/modification | None |
| `chore` | Build/configuration changes | None |
| `BREAKING CHANGE` | Breaking changes | MAJOR++ |

#### Commit Examples

```bash
# New feature addition
git commit -m "feat: add Discord integration for game status updates

- Implement Discord Rich Presence API integration
- Add configuration options for Discord features
- Update GUI to include Discord settings tab"

# Bug fix
git commit -m "fix: resolve config file encoding issue on Japanese Windows

- Fix UTF-8 BOM handling in config parser
- Add fallback encoding detection
- Update error messages for better user experience"

# Breaking change
git commit -m "feat: redesign configuration file structure

BREAKING CHANGE: Configuration file format has changed from JSON to YAML.
Users need to migrate their existing config.json files using the provided
migration tool."
```

## Release Process

### Phase 1: Release Preparation

#### 1. Pre-Release Checklist

```powershell
# Execute comprehensive validation
.\scripts\Version-Helper.ps1 validate

# Verify the following items:
# ✓ Git repository is clean (no uncommitted changes)
# ✓ All tests passing
# ✓ Documentation is up to date
# ✓ Version.ps1 contains correct current version
```

#### 2. Determine Next Version

```powershell
# Check next version options
.\scripts\Version-Helper.ps1 next

# Sample output:
# Current version: 1.0.1-alpha
#
# Release options:
#   Major:  2.0.0
#   Minor:  1.1.0
#   Patch:  1.0.2
#
# Pre-release options:
#   Alpha:  1.0.2-alpha
#   Beta:   1.0.2-beta
#   RC:     1.0.2-rc
```

### Phase 2: Version Update and Tag Creation

#### Alpha Release Example

```powershell
# Check with DRY RUN (no actual changes)
.\scripts\Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -DryRun

# Create actual release (generate tag and release notes)
.\scripts\Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -CreateTag -GenerateReleaseNotes -ReleaseMessage "Alpha release for testing core functionality"
```

#### Patch Release Example

```powershell
# Bug fix release
.\scripts\Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Patch release with critical bug fixes"
```

#### Major Release Example

```powershell
# Official release
.\scripts\Release-Manager.ps1 -UpdateType minor -CreateTag -GenerateReleaseNotes -ReleaseMessage "Official v1.1.0 release with new platform support"
```

### Phase 3: GitHub Release Creation

#### 1. Edit Release Notes

```powershell
# Edit the generated release notes file
# Example: release-notes-1.0.2-alpha.md
code release-notes-1.0.2-alpha.md
```

#### 2. Build and Asset Preparation

##### Generate Executables and Digital Signing

```powershell
# Development build (unsigned)
.\Master-Build.ps1 -Development

# Production build (signed) *Requires certificate setup
.\Master-Build.ps1 -Production

# Individual build operations
.\build-tools\Build-FocusGameDeck.ps1 -Install    # Install ps2exe module
.\build-tools\Build-FocusGameDeck.ps1 -Build      # Generate executables
.\build-tools\Build-FocusGameDeck.ps1 -Sign       # Apply signatures to existing builds
.\build-tools\Build-FocusGameDeck.ps1 -Clean      # Clean up build artifacts

# Individual digital signing operations
.\Sign-Executables.ps1 -ListCertificates    # List available certificates
.\Sign-Executables.ps1 -TestCertificate     # Test configured certificate
.\Sign-Executables.ps1 -SignAll             # Sign all executables
```

**Generated Executables**:

- `Focus-Game-Deck.exe` - Main application
- `Focus-Game-Deck-MultiPlatform.exe` - Multi-platform version
- `Focus-Game-Deck-Config-Editor.exe` - GUI configuration editor

**Signing Configuration** (`config/signing-config.json`):

```json
{
  "codeSigningSettings": {
    "enabled": true,
    "certificateThumbprint": "YOUR_CERTIFICATE_THUMBPRINT",
    "timestampServer": "http://timestamp.digicert.com"
  }
}
```

#### 3. GitHub Release Creation Steps

1. **Access GitHub Releases page**
   - <https://github.com/beive60/focus-game-deck/releases>

2. **Click "Create a new release"**

3. **Enter Release Information**

   ```text
   Tag: v1.0.2-alpha.1
   Release title: Focus Game Deck v1.0.2-alpha.1 - Alpha Test Release
   Description: [Copy content from generated release notes]
   ```

4. **Upload Assets**
   - `FocusGameDeck-v1.0.2-alpha.1-Setup.exe`
   - `FocusGameDeck-v1.0.2-alpha.1-Portable.zip`
   - `SHA256SUMS.txt`

5. **Release Settings**
   - Pre-release: ✓ (for alpha/beta/RC versions)
   - Set as latest release: (official versions only)

## Emergency Response

### Hotfix Release

```powershell
# Emergency bug fix release
.\scripts\Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Hotfix for critical security vulnerability"

# Immediately create GitHub Release and notify users
```

### Release Rollback

```powershell
# Withdraw problematic release
# 1. Change GitHub Release to "Draft"
# 2. Remove problematic assets
# 3. Publish downgrade instructions to previous version
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Version.ps1 Update Fails

```powershell
# Error: 'Access to the path is denied'
# Solution: Run PowerShell with administrator privileges

# Error: Version file validation failed
# Solution: Check syntax errors in Version.ps1
PowerShell -File Version.ps1  # Syntax check
```

#### 2. Git Tag Creation Fails

```powershell
# Error: 'tag already exists'
# Solution: Delete existing tag or use different name
git tag -d v1.0.2-alpha.1        # Delete local tag
git push origin :v1.0.2-alpha.1  # Delete remote tag

# Error: 'not a git repository'
# Solution: Execute in project root directory
cd C:\path\to\focus-game-deck
```

#### 3. Release Notes Generation Fails

```powershell
# Manually create release notes
$template = Get-Content "docs\RELEASE-NOTES-TEMPLATE.md"
$template -replace "{VERSION}", "1.0.2-alpha.1" | Out-File "release-notes-1.0.2-alpha.1.md"
```

## Best Practices

### 1. Pre-Release Quality Assurance

- [ ] Execute and pass all automated tests
- [ ] Execute manual test cases
- [ ] Verify documentation updates
- [ ] Run security scans
- [ ] Execute performance tests

### 2. Staged Release Strategy

```text
Development → Alpha → Beta → RC → Official
     ↓         ↓      ↓     ↓      ↓
   Internal  Limited Public Final General
   Testing   Testers Beta  Check Release
```

### 3. Communication

- **Alpha**: Tester-limited private channels
- **Beta**: GitHub Issues + landing page
- **Official**: Official announcements + social media

### 4. Security Focus

- Digital signatures mandatory for all releases
- SHA256 checksums publication mandatory
- Rapid response system for vulnerability reports

## Future Automation Plans

### GitHub Actions Integration (Future)

```yaml
# .github/workflows/release.yml (example)
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  build-and-release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Assets
        run: .\build\Create-All-Assets.ps1
      - name: Create Release
        uses: actions/create-release@v1
        # ... omitted
```

## References

### Related Documentation

- [VERSION-MANAGEMENT.md](./VERSION-MANAGEMENT.md) - Semantic versioning specification
- [GITHUB-RELEASES-GUIDE.md](./GITHUB-RELEASES-GUIDE.md) - GitHub Releases operation rules
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Technical architecture
- [ROADMAP.md](./ROADMAP.md) - Project roadmap

### External Resources

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

---

**Last Updated**: September 27, 2025
**Version**: 1.0.0
**Created by**: GitHub Copilot Assistant
# Focus Game Deck - GitHub Releases 運用ルール

## 概要

このドキュメントでは、Focus Game DeckプロジェクトにおけるGitHub Releasesの運用方針、手順、および品質管理基準を定義します。

## リリース分類と目的

### プレリリース版

#### アルファ版（Alpha）

- **対象ユーザー**: 限定されたアルファテスター（5〜10名）
- **目的**: 基本機能の検証、致命的バグの早期発見
- **配布方法**: プライベートアクセス、招待制
- **リリース頻度**: 必要に応じて（週1〜2回程度）
- **セキュリティ要件**: デジタル署名必須
- **サポート**: 限定的、GitHub Issues経由

#### ベータ版（Beta）

- **対象ユーザー**: 一般ユーザー（パブリックベータ）
- **目的**: 実際の使用環境での検証、UIUXフィードバック収集
- **配布方法**: GitHub Releases公開、ランディングページからリンク
- **リリース頻度**: 2週間間隔（安定性重視）
- **セキュリティ要件**: デジタル署名、セキュリティ監査済み
- **サポート**: フル、多言語対応

#### リリース候補版（RC）

- **対象ユーザー**: 正式リリース前の最終確認者
- **目的**: 最終品質検証、リリース可否判断
- **配布方法**: GitHub Releases公開（Pre-releaseタグ付き）
- **リリース頻度**: 正式リリース前のみ（最大3回）
- **セキュリティ要件**: 商用レベルのセキュリティ基準
- **サポート**: 正式版と同等

### 正式リリース版

- **対象ユーザー**: すべてのエンドユーザー
- **目的**: 本番環境での安定稼働
- **配布方法**: GitHub Releases公開、公式Webサイト
- **リリース頻度**: 計画的（四半期またはマイルストーン単位）
- **セキュリティ要件**: 最高レベル、第三者監査完了
- **サポート**: フルサポート、長期保守

## GitHub Releases 作成手順

### 1. 事前準備チェックリスト

- [ ] `Version.ps1`のバージョン番号更新完了
- [ ] 全テストケース実行・合格確認
- [ ] セキュリティスキャン実行・問題なし
- [ ] リリースノート作成完了
- [ ] デジタル署名証明書の有効性確認
- [ ] アセットファイルの命名規則準拠確認

### 2. タグ作成

```bash
# 例: v1.0.0-alpha.1 タグの作成
git tag -a v1.0.0-alpha.1 -m "Alpha release 1.0.0-alpha.1

Major changes:
- Initial alpha release for testing
- Core functionality implementation
- Basic GUI configuration editor

Known issues:
- Performance optimization pending
- Limited platform support

Testing notes:
- Requires Windows 10/11
- Administrator privileges recommended"

git push origin v1.0.0-alpha.1
```

### 3. GitHub Release作成

#### リリース情報設定

```yaml
Tag: v1.0.0-alpha.1
Release Title: "Focus Game Deck v1.0.0-alpha.1 - Alpha Test Release"
Description: |
  ## Focus Game Deck Alpha Release

  ### Alpha Version Notice
  この版本はアルファテスト用です。本番環境での使用は推奨されません。
  This is an alpha version for testing purposes only.

  ### Major Changes
  - Core game launching functionality
  - GUI configuration editor
  - Basic OBS integration
  - Steam platform support

  ### Known Issues
  - Performance optimization pending
  - Limited error handling
  - UI polish required

  ### System Requirements
  - Windows 10/11 (64-bit)
  - .NET Framework 4.8+
  - PowerShell 5.1+

  ### Download & Installation
  1. Download `FocusGameDeck-v1.0.0-alpha.1-Setup.exe`
  2. Verify SHA256: `[HASH_VALUE]`
  3. Run as Administrator
  4. Follow installation wizard

  ### Security & Trust
  - Digitally signed executable
  - Scanned for malware
  - Open source (MIT License)

  ### Testing & Feedback
  Please report issues via [GitHub Issues](https://github.com/beive60/focus-game-deck/issues)
  Include your system info and detailed steps to reproduce.

  ---
  **Release Date**: 2025-10-XX
  **Build**: [BUILD_NUMBER]
  **Commit**: [COMMIT_HASH]

Pre-release: true (for alpha/beta/rc only)
```

### 4. アセットアップロード

#### 必須アセット

1. **インストーラー実行ファイル**
   - ファイル名: `FocusGameDeck-v{VERSION}-Setup.exe`
   - デジタル署名付き
   - SHA256ハッシュ値をリリースノートに記載

2. **ポータブル版ZIP**
   - ファイル名: `FocusGameDeck-v{VERSION}-Portable.zip`
   - インストール不要版
   - 設定ファイルサンプル同梱

3. **チェックサム**
   - ファイル名: `SHA256SUMS.txt`
   - 全アセットのハッシュ値一覧

#### サンプルチェックサムファイル

```text
# SHA256 Checksums for Focus Game Deck v1.0.0-alpha.1
# Generated on: 2025-10-XX XX:XX:XX UTC
#
# Verify integrity with: Get-FileHash -Algorithm SHA256 filename

1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  FocusGameDeck-v1.0.0-alpha.1-Setup.exe
fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321  FocusGameDeck-v1.0.0-alpha.1-Portable.zip
```

## リリースノート テンプレート

### アルファ/ベータ版テンプレート

```markdown
## Focus Game Deck v{VERSION} - {RELEASE_TYPE} Release

### {RELEASE_TYPE} Version Notice
[適切な注意書きを記載]

### What's New
- [新機能1]
- [新機能2]
- [改善点1]
- [修正されたバグ1]

### Known Issues
- [既知の問題1]
- [既知の問題2]

### Breaking Changes
- [破壊的変更があれば記載]

### System Requirements
- Windows 10/11 (64-bit)
- .NET Framework 4.8+
- PowerShell 5.1+

### Download & Installation
[ダウンロード・インストール手順]

### Security & Trust
- Digitally signed executable
- Scanned for malware
- Open source (MIT License)

### Feedback & Support
[フィードバック方法]

---
**Full Changelog**: [v{PREV_VERSION}...v{VERSION}](compare_link)
```

### 正式リリース版テンプレート

```markdown
## Focus Game Deck v{VERSION} - Official Release

### Highlights
[主要な新機能・改善点を3-5個]

### Complete Feature List
#### New Features
- [新機能リスト]

#### Improvements
- [改善点リスト]

#### Bug Fixes
- [修正されたバグリスト]

### System Requirements
[詳細なシステム要件]

### Download & Installation
[詳細なインストール手順]

### Upgrade Guide
[アップグレード手順・注意点]

### Security & Trust
[セキュリティ情報]

### Support & Documentation
[サポート情報・ドキュメントリンク]

### Acknowledgments
[協力者・テスター・貢献者への謝辞]
```

## 品質管理基準

### セキュリティ要件

1. **デジタル署名**
   - 全実行ファイルにデジタル署名必須
   - ExtendedValidation証明書使用
   - タイムスタンプ付与

2. **セキュリティスキャン**
   - VirusTotal全エンジンでクリーン
   - 静的解析ツール（PowerShell Script Analyzer）合格
   - 依存関係脆弱性チェック完了

3. **ハッシュ値検証**
   - SHA256ハッシュ値計算・公開
   - チェックサムファイル提供
   - 検証方法のドキュメント化

### テスト要件

1. **アルファ版**
   - 基本機能動作確認
   - 致命的エラーなし
   - インストール・アンインストール確認

2. **ベータ版**
   - 全機能テスト実施
   - 複数環境での動作確認
   - パフォーマンステスト

3. **正式版**
   - 完全な回帰テスト
   - 長時間動作テスト
   - セキュリティ監査完了

## 運用指針

### リリーススケジュール

```text
アルファ期間（2025年10月）:
├── v1.0.0-alpha.1 ← 初回アルファ
├── v1.0.0-alpha.2 ← フィードバック反映
└── v1.0.0-alpha.3 ← ベータ準備版

ベータ期間（2025年10月下旬-11月初旬）:
├── v1.0.0-beta.1 ← パブリックベータ開始
├── v1.0.0-beta.2 ← 改善版
└── v1.0.0-rc.1   ← リリース候補

正式リリース（2025年11月下旬-12月）:
└── v1.0.0        ← 正式リリース
```

### 緊急時対応

#### 緊急パッチリリース

1. **条件**
   - セキュリティ脆弱性発見
   - データ破損を引き起こすバグ
   - アンチチート誤検知問題

2. **手順**
   - 48時間以内のホットフィックス実装
   - 緊急リリース作成（PATCH番号++）
   - ユーザーへの緊急通知

#### ロールバック手順

1. **判断基準**
   - 致命的問題の報告
   - 大量のユーザーからの苦情
   - セキュリティ問題の発覚

2. **実行手順**
   - GitHub Releaseを「Draft」に変更
   - 問題のあるアセット削除
   - 前バージョンへのダウングレード手順公開

## 継続的改善

### メトリクス収集

- ダウンロード数
- GitHub Starレート
- Issue報告数・解決率
- ユーザーフィードバック満足度

### プロセス改善

- 四半期ごとの運用見直し
- テスター・ユーザーフィードバック反映
- セキュリティ基準の定期更新
- ツール・自動化レベル向上

---

**最終更新**: 2025-09-24
**バージョン**: 1.0.0
**作成者**: GitHub Copilot Assistant
