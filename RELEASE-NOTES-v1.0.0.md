# Focus Game Deck v1.0.0 - 正式リリース

**リリース日**: 2025年12月18日

Focus Game Deck v1.0.0 の正式リリースをお知らせします。このバージョンは、ゲームプレイ時の集中力を最大化するための環境自動切り替えツールの最初の安定版です。

## 🎉 主要機能

### ゲーム環境の自動最適化
- ゲーム起動時に自動的に不要なアプリケーションを終了
- Discord、Spotify、ブラウザなど、管理対象アプリの柔軟な設定
- Steam、Epic Games Store、EA App、Battle.net、Riot Clientなど主要プラットフォームに対応

### GUI設定エディタ
- 直感的な設定インターフェース
- 日本語、英語、スペイン語、フランス語、ロシア語、中国語（簡体字）の6言語対応
- リアルタイムプレビュー機能

### セキュリティ機能
- デジタル署名による実行ファイルの信頼性保証
- ログ記録による透明性の確保
- アンチチート誤検知ゼロを目指した安全設計

### ビルドシステム
- ps2exe ベースの単一実行ファイル配布
- 開発版・本番版ビルドの自動化
- デジタル署名の自動適用

## 📦 インストール方法

### 方法1: 実行ファイル版（推奨）
1. [Releases](https://github.com/beive60/focus-game-deck/releases/tag/v1.0.0) から `Focus-Game-Deck-v1.0.0.zip` をダウンロード
2. 任意のフォルダに展開
3. `Focus-Game-Deck.exe` を実行

### 方法2: ソースコード版
```powershell
git clone https://github.com/beive60/focus-game-deck.git
cd focus-game-deck
./src/Main.PS1
```

## ⚙️ 初回セットアップ

1. ConfigEditorを起動
2. [ゲーム設定]タブでプレイするゲームを追加
3. [管理対象アプリ設定]タブで終了したいアプリケーションを設定
4. [グローバル設定]タブで言語やログレベルを調整
5. 設定を保存

## 🎮 使い方

### ランチャーの作成
```powershell
# デスクトップにゲーム起動用のショートカットを作成
./scripts/Create-Launchers-Enhanced.ps1
```

### ゲームの起動
- 作成されたデスクトップショートカットから起動
- または、直接 `./src/Main.PS1 -GameName "ゲーム名"` を実行

## 📋 既知の問題と制限事項

### アップデート確認機能
- GUI上の「更新を確認」機能は実装済みですが、初回リリースのため動作未検証です
- 最新バージョンは [GitHub Releases](https://github.com/beive60/focus-game-deck/releases) で確認できます
- 今後のアップデート（v1.0.1など）で動作を検証します

### その他の制限
- 一部のゲームプラットフォームは手動設定が必要な場合があります
- 非Steamゲームの自動検出には制限があります

## 🔄 今後の予定

次のバージョンでは以下の改善を予定しています：

- アップデート確認機能の動作検証と改善
- ユーザーフィードバックに基づくUI/UX改善
- プロファイル機能の追加検討
- 追加言語サポート

## 🙏 謝辞

このプロジェクトは、オープンソースコミュニティの協力により実現しました。
フィードバック、バグレポート、機能提案を歓迎します。

## 📝 ライセンス

MIT License - 詳細は [LICENSE.md](LICENSE.md) を参照してください。

## 🔗 リンク

- [GitHub Repository](https://github.com/beive60/focus-game-deck)
- [ドキュメント](https://github.com/beive60/focus-game-deck/tree/main/docs)
- [Issue Tracker](https://github.com/beive60/focus-game-deck/issues)

---

**注意**: このソフトウェアは「現状のまま」提供され、いかなる保証もありません。
使用に際しては、[セキュリティポリシー](SECURITY.md)と[利用規約](LICENSE.md)を必ずお読みください。
