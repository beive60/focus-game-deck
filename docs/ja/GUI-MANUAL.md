# Focus Game Deck - GUI設定エディタ マニュアル

Focus Game Deck の設定ファイル (`config.json`) を GUI で直感的に編集するためのツールです。

## 概要

このツールは以下の問題を解決します：

- JSON 構文エラーによる設定ファイル破損のリスク
- テキストエディタでの手動編集の複雑さ
- 初心者ユーザーにとっての導入ハードル

## 機能

### 1. ゲーム設定管理

- ゲームの追加・編集・削除
- Steam AppID、プロセス名の設定
- 管理対象アプリの選択

### 2. 管理アプリ設定

- 管理アプリの追加・編集・削除
- 実行ファイルパスの設定（参照ボタン付き）
- ゲーム開始・終了時のアクション設定

### 3. グローバル設定

- OBS 連携設定（ホスト、ポート、パスワード）
- パス設定（Steam、OBS の実行ファイルパス）
- 表示言語設定
- ログ保存期間設定（30日/90日/180日/無期限の選択）

### 4. バリデーション機能

- 入力値の妥当性チェック
- エラー時のフィードバック表示
- 保存前の設定確認

## 使用方法

### 起動方法

#### 方法1: PowerShell スクリプトから起動

```powershell
.\ConfigEditor.ps1
```

#### 方法2: バッチファイルから起動

```cmd
StartConfigEditor.bat
```

#### 方法3: 実行ファイル版の使用

実行ファイル版をビルドした場合：

```bash
Focus-Game-Deck-Config-Editor.exe
```

### 基本操作

1. **設定ファイルの読み込み**
   - 起動時に自動的に `../config/config.json` を読み込みます
   - ファイルが存在しない場合は `../config/config.json.sample` を読み込みます

2. **ゲーム設定の編集**
   - 「ゲーム設定」タブを選択
   - 左のリストからゲームを選択、または「新規追加」ボタンで追加
   - 右側のパネルで詳細を編集

3. **管理アプリ設定の編集**
   - 「管理アプリ設定」タブを選択
   - 左のリストからアプリを選択、または「新規追加」ボタンで追加
   - 「参照」ボタンで実行ファイルを選択可能

4. **グローバル設定の編集**
   - 「グローバル設定」タブを選択
   - 各種設定項目を編集

5. **設定の保存**
   - 「保存」ボタンをクリックして設定を保存
   - バリデーションエラーがある場合は警告が表示されます

## 実行ファイル化

### 前提条件

- PowerShell 5.1 以上
- インターネット接続（ps2exe モジュールのダウンロード用）

### ビルド手順

1. **ps2exe モジュールのインストール**

   ```powershell
   .\Build-ConfigEditor.ps1 -Install
   ```

2. **実行ファイルのビルド**

   ```powershell
   .\Build-ConfigEditor.ps1 -Build
   ```

3. **一括実行**

   ```powershell
   .\Build-ConfigEditor.ps1 -Install -Build
   ```

ビルドが成功すると、`Focus-Game-Deck-Config-Editor.exe` が生成されます。

## トラブルシューティング

### 起動時のエラー

- **「実行ポリシーが制限されています」エラー**

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

- **「設定ファイルが見つかりません」エラー**
  - `config/config.json.sample` が存在することを確認してください
  - ファイルパスが正しいことを確認してください

### バリデーションエラー

- **OBS ポートエラー**: 1-65535 の範囲の数値を入力してください
- **Steam AppID エラー**: 数値のみを入力してください
- **パスエラー**: 存在するファイル・フォルダのパスを指定してください

### 実行ファイル化エラー

- **ps2exe がインストールできない**: 管理者権限で PowerShell を実行してみてください
- **ビルドが失敗する**: ウイルス対策ソフトが干渉していないか確認してください

## 技術仕様

- **言語**: PowerShell + WPF (Windows Presentation Foundation)
- **対応OS**: Windows 10/11
- **.NET Framework**: 4.5 以上
- **アーキテクチャ**: x64

## ファイル構成

```text
gui/
├── ConfigEditor.ps1           # メインロジック
├── MainWindow.xaml            # UI定義
├── StartConfigEditor.bat      # 起動用バッチファイル
└── Build-ConfigEditor.ps1     # ビルドスクリプト
```

## 関連ドキュメント

- **[BD_and_FD_for_GUI.md](../BD_and_FD_for_GUI.md)** - GUI設計の技術仕様書
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - プロジェクト全体のアーキテクチャ設計

## ライセンス

MIT License - 詳細は `../../LICENSE.md` を参照してください。
