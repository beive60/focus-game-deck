# Focus Game Deck - Developer Release Process Guide

## 概要

このガイドは、Focus Game Deckプロジェクトの開発者がバージョン管理とリリースプロセスを実行するための実践的な手順書です。日常的な開発作業からリリース作成まで、すべての手順を詳細に説明します。

## 事前準備

### 必要なツール

- **Git**: バージョン管理とタグ作成
- **PowerShell 5.1+**: リリース管理スクリプト実行
- **Visual Studio Code**: 推奨エディタ（省略可）
- **コードサイニング証明書**: デジタル署名用（リリース時のみ）

### 環境設定確認

```powershell
# PowerShellバージョン確認
$PSVersionTable.PSVersion

# Git設定確認
git config --global user.name
git config --global user.email

# リポジトリ状態確認
.\scripts\Version-Helper.ps1 check
```

## 日常的な開発ワークフロー

### 1. 開発開始前の確認

```powershell
# 最新の状態に更新
git pull origin main

# 現在のバージョン確認
.\scripts\Version-Helper.ps1 info

# 作業ブランチ作成（必要に応じて）
git checkout -b feature/new-feature
```

### 2. 開発中のコミット規約

#### コミットメッセージ形式

```text
<type>: <description>

[optional body]

[optional footer]
```

#### コミットタイプ

| タイプ | 説明 | バージョン影響 |
|--------|------|----------------|
| `feat` | 新機能追加 | MINOR++ |
| `fix` | バグ修正 | PATCH++ |
| `docs` | ドキュメント変更のみ | なし |
| `style` | コード整形（機能変更なし） | なし |
| `refactor` | リファクタリング | PATCH++ |
| `test` | テスト追加・修正 | なし |
| `chore` | ビルド・設定変更 | なし |
| `BREAKING CHANGE` | 破壊的変更 | MAJOR++ |

#### コミット例

```bash
# 新機能追加
git commit -m "feat: add Discord integration for game status updates

- Implement Discord Rich Presence API integration
- Add configuration options for Discord features
- Update GUI to include Discord settings tab"

# バグ修正
git commit -m "fix: resolve config file encoding issue on Japanese Windows

- Fix UTF-8 BOM handling in config parser
- Add fallback encoding detection
- Update error messages for better user experience"

# 破壊的変更
git commit -m "feat: redesign configuration file structure

BREAKING CHANGE: Configuration file format has changed from JSON to YAML.
Users need to migrate their existing config.json files using the provided
migration tool."
```

## リリースプロセス

### フェーズ1: リリース準備

#### 1. リリース前チェックリスト

```powershell
# 包括的な検証を実行
.\scripts\Version-Helper.ps1 validate

# 以下の項目を確認:
# ✓ Git repository is clean (no uncommitted changes)
# ✓ All tests passing
# ✓ Documentation is up to date
# ✓ Version.ps1 contains correct current version
```

#### 2. 次のバージョン決定

```powershell
# 次のバージョンオプションを確認
.\scripts\Version-Helper.ps1 next

# 出力例:
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

### フェーズ2: バージョン更新とタグ作成

#### アルファ版リリース例

```powershell
# DRY RUNで確認（実際の変更は行わない）
.\scripts\Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -DryRun

# 実際のリリース作成（タグとリリースノート生成）
.\scripts\Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -CreateTag -GenerateReleaseNotes -ReleaseMessage "Alpha release for testing core functionality"
```

#### パッチリリース例

```powershell
# バグ修正版リリース
.\scripts\Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Patch release with critical bug fixes"
```

#### メジャーリリース例

```powershell
# 正式版リリース
.\scripts\Release-Manager.ps1 -UpdateType minor -CreateTag -GenerateReleaseNotes -ReleaseMessage "Official v1.1.0 release with new platform support"
```

### フェーズ3: GitHub Release作成

#### 1. リリースノート編集

```powershell
# 生成されたリリースノートファイルを編集
# 例: release-notes-1.0.2-alpha.md
code release-notes-1.0.2-alpha.md
```

#### 2. ビルドとアセット準備

##### 実行ファイル生成とデジタル署名

```powershell
# 開発版ビルド（署名なし）
.\Master-Build.ps1 -Development

# 本番版ビルド（署名付き）※要証明書設定
.\Master-Build.ps1 -Production

# 個別ビルド操作
.\build-tools\Build-FocusGameDeck.ps1 -Install    # ps2exe モジュールインストール
.\build-tools\Build-FocusGameDeck.ps1 -Build      # 実行ファイル生成
.\build-tools\Build-FocusGameDeck.ps1 -Sign       # 既存ビルドに署名適用
.\build-tools\Build-FocusGameDeck.ps1 -Clean      # ビルド成果物クリーンアップ

# デジタル署名個別操作
.\Sign-Executables.ps1 -ListCertificates    # 利用可能証明書一覧
.\Sign-Executables.ps1 -TestCertificate     # 設定済み証明書テスト
.\Sign-Executables.ps1 -SignAll             # 全実行ファイルに署名
```

**生成される実行ファイル**:

- `Focus-Game-Deck.exe` - メインアプリケーション
- `Focus-Game-Deck-MultiPlatform.exe` - マルチプラットフォーム版
- `Focus-Game-Deck-Config-Editor.exe` - GUI設定エディター

**署名設定** (`config/signing-config.json`):

```json
{
  "codeSigningSettings": {
    "enabled": true,
    "certificateThumbprint": "YOUR_CERTIFICATE_THUMBPRINT",
    "timestampServer": "http://timestamp.digicert.com"
  }
}
```

#### 3. GitHub Release作成手順

1. **GitHub Releasesページにアクセス**
   - <https://github.com/beive60/focus-game-deck/releases>

2. **"Create a new release"をクリック**

3. **リリース情報入力**

   ```text
   Tag: v1.0.2-alpha.1
   Release title: Focus Game Deck v1.0.2-alpha.1 - Alpha Test Release
   Description: [生成されたリリースノートの内容をコピー]
   ```

4. **アセットアップロード**
   - `FocusGameDeck-v1.0.2-alpha.1-Setup.exe`
   - `FocusGameDeck-v1.0.2-alpha.1-Portable.zip`
   - `SHA256SUMS.txt`

5. **リリース設定**
   - Pre-release: ✓ (アルファ・ベータ・RC版の場合)
   - Set as latest release: (正式版のみ)

## 緊急時対応

### ホットフィックスリリース

```powershell
# 緊急バグ修正版
.\scripts\Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Hotfix for critical security vulnerability"

# 即座にGitHub Releaseを作成し、ユーザーに通知
```

### リリースロールバック

```powershell
# 問題のあるリリースを取り下げ
# 1. GitHub Releaseを"Draft"に変更
# 2. 問題のあるアセットを削除
# 3. 前バージョンへのダウングレード手順を公開
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. Version.ps1の更新に失敗する

```powershell
# エラー: 'Access to the path is denied'
# 解決: 管理者権限でPowerShellを実行

# エラー: Version file validation failed
# 解決: Version.ps1の構文エラーを確認
PowerShell -File Version.ps1  # 構文チェック
```

#### 2. Gitタグの作成に失敗する

```powershell
# エラー: 'tag already exists'
# 解決: 既存タグを削除または別名を使用
git tag -d v1.0.2-alpha.1        # ローカルタグ削除
git push origin :v1.0.2-alpha.1  # リモートタグ削除

# エラー: 'not a git repository'
# 解決: プロジェクトルートディレクトリで実行
cd C:\path\to\focus-game-deck
```

#### 3. リリースノート生成に失敗する

```powershell
# 手動でリリースノートを作成
$template = Get-Content "docs\RELEASE-NOTES-TEMPLATE.md"
$template -replace "{VERSION}", "1.0.2-alpha.1" | Out-File "release-notes-1.0.2-alpha.1.md"
```

## ベストプラクティス

### 1. リリース前の品質保証

- [ ] 全自動テストの実行と合格確認
- [ ] 手動テストケースの実行
- [ ] ドキュメントの更新確認
- [ ] セキュリティスキャンの実行
- [ ] パフォーマンステストの実行

### 2. 段階的リリース戦略

```text
開発版 → アルファ版 → ベータ版 → RC版 → 正式版
    ↓      ↓       ↓      ↓      ↓
   内部   限定    パブリック 最終   一般
  テスト テスター  ベータ   確認  リリース
```

### 3. コミュニケーション

- **アルファ版**: テスター限定の非公開チャンネル
- **ベータ版**: GitHub Issues + ランディングページ
- **正式版**: 公式アナウンス + ソーシャルメディア

### 4. セキュリティ重視

- すべてのリリースにデジタル署名必須
- SHA256チェックサム公開必須
- 脆弱性報告の迅速な対応体制

## 自動化の将来計画

### GitHub Actions統合（将来）

```yaml
# .github/workflows/release.yml（例）
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
        # ... 省略
```

## 参考資料

### 関連ドキュメント

- [VERSION-MANAGEMENT.md](./VERSION-MANAGEMENT.md) - セマンティックバージョニング仕様
- [GITHUB-RELEASES-GUIDE.md](./GITHUB-RELEASES-GUIDE.md) - GitHub Releases運用ルール
- [ARCHITECTURE.md](./ARCHITECTURE.md) - 技術アーキテクチャ
- [ROADMAP.md](./ja/ROADMAP.md) - プロジェクトロードマップ

### 外部リソース

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

---

**最終更新**: 2025-09-24
**バージョン**: 1.0.0
**作成者**: GitHub Copilot Assistant
