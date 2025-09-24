# Focus Game Deck - バージョン管理仕様書

## 概要

Focus Game Deckプロジェクトでは、**セマンティックバージョニング (SemVer 2.0.0)** を採用し、一貫性のあるバージョン管理を実施します。

## バージョニング体系

### 基本形式

```text
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

### 各要素の定義

| 要素 | 説明 | 更新条件 |
|------|------|----------|
| **MAJOR** | メジャーバージョン | 後方互換性のない変更を含む場合 |
| **MINOR** | マイナーバージョン | 後方互換性を保った機能追加 |
| **PATCH** | パッチバージョン | 後方互換性を保ったバグ修正 |
| **PRERELEASE** | プレリリース識別子 | アルファ・ベータ・RC版の識別 |
| **BUILD** | ビルドメタデータ | ビルド固有の情報（通常は省略） |

### プレリリース版命名規則

#### アルファ版（Alpha）

- **形式**: `X.Y.Z-alpha[.N]`
- **例**: `1.0.0-alpha`, `1.0.0-alpha.1`, `1.0.0-alpha.2`
- **用途**: 内部テスト、限定的なアルファテスト期
- **安定性**: 不安定、機能未完成、破壊的変更あり

#### ベータ版（Beta）

- **形式**: `X.Y.Z-beta[.N]`
- **例**: `1.0.0-beta`, `1.0.0-beta.1`, `1.0.0-beta.2`
- **用途**: パブリックベータテスト、フィードバック収集
- **安定性**: 機能凍結、バグ修正のみ

#### リリース候補版（RC: Release Candidate）

- **形式**: `X.Y.Z-rc[.N]`
- **例**: `1.0.0-rc.1`, `1.0.0-rc.2`
- **用途**: 最終リリース前の確認版
- **安定性**: リリース品質、重大な問題のみ修正

## リリースサイクル

### アルファテスト期（2025年10月）

```text
1.0.0-alpha.1 → 1.0.0-alpha.2 → ... → 1.0.0-beta.1
```

### ベータテスト期（2025年10月下旬～11月初旬）

```text
1.0.0-beta.1 → 1.0.0-beta.2 → ... → 1.0.0-rc.1
```

### 公式リリース（2025年11月下旬～12月）

```text
1.0.0-rc.1 → 1.0.0-rc.2 → ... → 1.0.0
```

## バージョン更新基準

### MAJOR バージョン更新

- 設定ファイル形式の大幅変更
- 既存APIの削除・大幅変更
- システム要件の大幅変更
- アーキテクチャの根本的変更

### MINOR バージョン更新

- 新しいゲームプラットフォーム対応
- 新機能の追加（プロファイル機能、Discord連携等）
- 新しい言語サポート
- 設定項目の追加（既存の互換性を保つ）

### PATCH バージョン更新

- バグ修正
- セキュリティパッチ
- パフォーマンス改善
- UI/UXの軽微な改善
- 既存機能の安定性向上

## タグ命名規則

### リリースタグ

```text
v1.0.0          # 正式リリース
v1.0.0-alpha.1  # アルファ版
v1.0.0-beta.1   # ベータ版  
v1.0.0-rc.1     # リリース候補
```

### 特殊タグ

```text
release/alpha-test    # アルファテスト期の最新
release/beta-test     # ベータテスト期の最新
release/stable        # 安定版の最新
```

## GitHub Releases アセット命名規則

### 実行ファイル

```text
FocusGameDeck-v{VERSION}-Setup.exe
例: FocusGameDeck-v1.0.0-alpha.1-Setup.exe
例: FocusGameDeck-v1.0.0-Setup.exe
```

### アーカイブファイル

```text
FocusGameDeck-v{VERSION}-Portable.zip
例: FocusGameDeck-v1.0.0-alpha.1-Portable.zip
例: FocusGameDeck-v1.0.0-Portable.zip
```

### ソースコード

```text
focus-game-deck-{VERSION}.zip
focus-game-deck-{VERSION}.tar.gz
例: focus-game-deck-1.0.0-alpha.1.zip
例: focus-game-deck-1.0.0.tar.gz
```

## Version.ps1 での実装

### 現在のバージョン設定

```powershell
$script:ProjectVersion = @{
    Major = 1
    Minor = 0  
    Patch = 1
    PreRelease = "alpha"  # "", "alpha", "beta", "rc.1", etc.
    Build = ""           # ビルドメタデータ（通常は空）
}
```

### バージョン文字列の取得

```powershell
Get-ProjectVersion                    # "1.0.1"
Get-ProjectVersion -IncludePreRelease # "1.0.1-alpha"
Get-ProjectVersion -IncludePreRelease -IncludeBuild # "1.0.1-alpha+20251024"
```

## バージョン履歴

### v1.0.1-alpha (現在)

- GUI設定エディタ完成
- 日本語文字化け解決
- 基本的なバージョン管理システム実装

### 予定されるリリース

#### v1.0.0-alpha.1 (2025年10月初旬)

- アルファテスト開始版
- デジタル署名付きビルド
- 基本機能の完成

#### v1.0.0-beta.1 (2025年10月下旬)

- パブリックベータ開始
- ランディングページ公開
- アルファテストフィードバック反映

#### v1.0.0 (2025年11月下旬～12月)

- 正式リリース
- Steam以外のプラットフォーム対応
- 導入支援ウィザード

## 運用指針

### 開発者向けガイドライン

1. **バージョン更新のタイミング**
   - 機能追加・変更のコミット前に`Version.ps1`を更新
   - プルリクエストのタイトルにバージョン情報を含める

2. **コミットメッセージ規約**

   ```text
   feat: 新機能追加時 (MINOR++)
   fix: バグ修正時 (PATCH++)
   BREAKING CHANGE: 破壊的変更時 (MAJOR++)
   ```

3. **リリース作成手順**
   - バージョン更新 → コミット → タグ作成 → GitHub Release作成
   - リリースノートはChangelog形式で記述
   - デジタル署名済みアセットのみ公開

### セキュリティとコンプライアンス

- すべてのリリースにデジタル署名を付与
- SHA256ハッシュ値をリリースノートに記載
- 脆弱性発見時は緊急パッチリリース（PATCH++）
- セキュリティアップデートは優先的にリリース

## 関連ドキュメント

- [ROADMAP.md](./ja/ROADMAP.md) - プロジェクトロードマップ
- [ARCHITECTURE.md](./ARCHITECTURE.md) - 技術アーキテクチャ
- リリースプロセスガイド - 詳細なリリース手順（今後作成）

---

**最終更新**: 2025-09-24  
**バージョン**: 1.0.0  
**作成者**: GitHub Copilot Assistant