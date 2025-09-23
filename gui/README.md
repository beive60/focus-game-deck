# Focus Game Deck - GUI設定エディタ

GUI設定エディタのソースコードディレクトリです。

## 📁 ファイル構成

- `ConfigEditor.ps1` - GUI設定エディタのメインロジック
- `MainWindow.xaml` - WPFウィンドウのUIレイアウト定義
- `StartConfigEditor.bat` - 設定エディタの起動用バッチファイル
- `Build-ConfigEditor.ps1` - 実行ファイル(.exe)生成用ビルドスクリプト
- `messages.json` - GUI用の国際化対応メッセージリソース

## 🚀 クイックスタート

### GUI設定エディタの起動

```cmd
StartConfigEditor.bat
```

または

```powershell
.\ConfigEditor.ps1
```

### 実行ファイル生成

```powershell
.\Build-ConfigEditor.ps1 -Install -Build
```

## 📖 詳細な使用方法

完全な使用方法、トラブルシューティング、技術仕様については、以下の詳細マニュアルを参照してください：

**[docs/ja/GUI-MANUAL.md](../docs/ja/GUI-MANUAL.md)**

## 🔧 開発者向け情報

GUI設計の技術仕様、アーキテクチャ設計については：

**[docs/ja/BD_and_FD_for_GUI.md](../docs/ja/BD_and_FD_for_GUI.md)**
