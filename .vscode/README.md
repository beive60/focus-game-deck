# Focus Game Deck - VSCode開発環境設定

このディレクトリには、Focus Game DeckプロジェクトでのVSCodeを使った効率的な開発のための設定ファイルがまとめられています。

## 📁 設定ファイル一覧

### `tasks.json` - タスク設定
プロジェクトでよく使用するコマンドをVSCodeのタスクとして定義しています。

**主要タスク:**
- 🔧 **セットアップ** - ps2exeモジュールのインストール
- 🏗️ **ビルド - 開発版** - 署名なしの開発用ビルド（デフォルト）
- 📦 **ビルド - プロダクション版** - 署名付きプロダクションビルド
- 🧹 **クリーンアップ** - ビルド成果物の削除
- 🎮 **実行** - メインアプリケーションの直接実行
- ⚙️ **GUI設定エディタ** - 設定エディタのビルドと起動
- 🧪 **各種テスト** - 設定検証、Discord、OBS、VTube Studio連携テスト
- 📊 **プロジェクト統計** - ファイル数、行数などの統計情報表示

### `settings.json` - ワークスペース設定
PowerShell開発に最適化された設定:
- PowerShellコード整形設定
- 120文字ルーラー表示
- UTF-8エンコーディング
- JSON設定ファイルスキーマ検証
- 不要ファイルの検索除外

### `keybindings.json` - キーボードショートカット
効率的な開発のためのキーボードショートカット:
- `Ctrl+Shift+B` - 開発版ビルド
- `Ctrl+Shift+Alt+B` - プロダクション版ビルド
- `Ctrl+Shift+T` - 簡単チェックテスト
- `F5` - メインアプリケーション実行
- `Ctrl+F5` - リリース版実行ファイル起動
- `Ctrl+Shift+Del` - クリーンアップ
- `Ctrl+Shift+G` - GUI設定エディタ

### `launch.json` - デバッグ設定
PowerShellスクリプトのデバッグ実行設定:
- メインアプリケーション
- マルチプラットフォーム版
- 設定エディタ
- 現在開いているファイル
- 各種テストスクリプト

### `extensions.json` - 推奨拡張機能
PowerShell開発に推奨される拡張機能:
- PowerShell
- JSON Language Features
- YAML
- Code Spell Checker
- Hex Editor
- その他便利ツール

## 🚀 使用方法

### タスクの実行
1. **コマンドパレット**: `Ctrl+Shift+P` → `Tasks: Run Task`
2. **キーボードショートカット**: 上記のショートカットキーを使用
3. **ターミナルメニュー**: `Terminal` → `Run Task`

### デバッグの開始
1. **F5キー**またはデバッグパネルから実行
2. PowerShellスクリプトにブレークポイントを設定可能
3. 変数の監視、コールスタック表示等が利用可能

### 効率的な開発フロー
1. **セットアップ**: `🔧 セットアップ - ps2exe モジュールのインストール`
2. **開発**: コード編集後、`Ctrl+Shift+B`で開発版ビルド
3. **テスト**: `Ctrl+Shift+T`で簡単チェック、または各種テストタスク実行
4. **デバッグ**: 問題がある場合はF5でデバッグ実行
5. **クリーンアップ**: `Ctrl+Shift+Del`で不要ファイル削除
6. **リリース**: `Ctrl+Shift+Alt+B`でプロダクション版ビルド

## 🛠️ カスタマイズ

### 新しいタスクの追加
`tasks.json`に新しいタスクを追加する場合:
```json
{
    "label": "新しいタスク名",
    "type": "shell",
    "command": "powershell",
    "args": ["-ExecutionPolicy", "Bypass", "-File", "スクリプトパス"],
    "group": "build|test",
    "detail": "タスクの説明"
}
```

### キーボードショートカットの変更
`keybindings.json`でショートカットキーを変更・追加可能:
```json
{
    "key": "ctrl+alt+t",
    "command": "workbench.action.tasks.runTask",
    "args": "タスク名"
}
```

## 📋 プロジェクト統計

現在のプロジェクト規模（統計タスクで確認可能）:
- PowerShellファイル: 37個
- 総行数: 8,208行
- 設定ファイル: 4個
- テストファイル: 10個
- モジュール数: 11個

## 🔧 トラブルシューティング

### PowerShell実行ポリシーエラー
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ps2exeモジュールがない場合
「🔧 セットアップ」タスクを実行してモジュールをインストール

### タスクが見つからない場合
- VSCodeを再起動
- `.vscode`フォルダーがワークスペースルートにあることを確認
- `tasks.json`の構文エラーをチェック

## 📝 注意事項

- PowerShell拡張機能のインストールが必要
- 初回セットアップ時は「🔧 セットアップ」タスクを必ず実行
- プロダクションビルドには署名設定が必要（`config/signing-config.json`）
- デバッグ実行時はPowerShell統合コンソールが使用される

---

この設定により、Focus GameDeckの開発効率が大幅に向上し、一貫した開発体験が提供されます。
