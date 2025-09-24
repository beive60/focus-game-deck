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
  ## 🚀 Focus Game Deck Alpha Release
  
  ### ⚠️ Alpha Version Notice
  この版本はアルファテスト用です。本番環境での使用は推奨されません。
  This is an alpha version for testing purposes only.
  
  ### 📋 Major Changes
  - ✅ Core game launching functionality
  - ✅ GUI configuration editor
  - ✅ Basic OBS integration
  - ✅ Steam platform support
  
  ### 🐛 Known Issues
  - Performance optimization pending
  - Limited error handling
  - UI polish required
  
  ### 🔧 System Requirements
  - Windows 10/11 (64-bit)
  - .NET Framework 4.8+
  - PowerShell 5.1+
  
  ### 📥 Download & Installation
  1. Download `FocusGameDeck-v1.0.0-alpha.1-Setup.exe`
  2. Verify SHA256: `[HASH_VALUE]`
  3. Run as Administrator
  4. Follow installation wizard
  
  ### 🔒 Security & Trust
  - ✅ Digitally signed executable
  - ✅ Scanned for malware
  - ✅ Open source (MIT License)
  
  ### 🤝 Testing & Feedback
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
## 🚀 Focus Game Deck v{VERSION} - {RELEASE_TYPE} Release

### ⚠️ {RELEASE_TYPE} Version Notice
[適切な注意書きを記載]

### 📋 What's New
- ✅ [新機能1]
- ✅ [新機能2]
- 🔧 [改善点1]
- 🐛 [修正されたバグ1]

### 🐛 Known Issues
- [既知の問題1]
- [既知の問題2]

### 💔 Breaking Changes
- [破壊的変更があれば記載]

### 🔧 System Requirements
- Windows 10/11 (64-bit)
- .NET Framework 4.8+
- PowerShell 5.1+

### 📥 Download & Installation
[ダウンロード・インストール手順]

### 🔒 Security & Trust
- ✅ Digitally signed executable
- ✅ Scanned for malware
- ✅ Open source (MIT License)

### 🤝 Feedback & Support
[フィードバック方法]

---
**Full Changelog**: [v{PREV_VERSION}...v{VERSION}](compare_link)
```

### 正式リリース版テンプレート

```markdown
## 🎉 Focus Game Deck v{VERSION} - Official Release

### 🌟 Highlights
[主要な新機能・改善点を3-5個]

### 📋 Complete Feature List
#### New Features
- ✅ [新機能リスト]

#### Improvements
- 🔧 [改善点リスト]

#### Bug Fixes
- 🐛 [修正されたバグリスト]

### 🔧 System Requirements
[詳細なシステム要件]

### 📥 Download & Installation
[詳細なインストール手順]

### 🔄 Upgrade Guide
[アップグレード手順・注意点]

### 🔒 Security & Trust
[セキュリティ情報]

### 📞 Support & Documentation
[サポート情報・ドキュメントリンク]

### 🙏 Acknowledgments
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
