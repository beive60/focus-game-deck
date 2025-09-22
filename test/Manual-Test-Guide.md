# Config Editor 手動テストガイド

## 現在の設定値（テスト前）
- OBSホスト: localhost
- OBSポート: 4455 
- 言語設定: (空)

## テスト手順

### 1. GUI起動確認
✓ Config Editorが正常に起動している
✓ 3つのタブ（ゲーム設定、管理アプリ設定、グローバル設定）が表示されている
✓ 日本語UIが正しく表示されている

### 2. グローバル設定タブのテスト
以下の変更を行ってください：
- OBSホストを "localhost" から "testhost" に変更
- OBSポートを "4455" から "4456" に変更  
- 言語設定を "Auto (System Language)" から "Japanese (ja)" に変更

### 3. ゲーム設定タブのテスト
- 既存のゲーム（apex、dbd）が正しく表示されているか確認
- "新しいゲームを追加" ボタンをクリック
- 新しいゲームの詳細を入力：
  - ゲーム名: "Test Game"
  - Steam App ID: "999999"
  - プロセス名: "testgame.exe"

### 4. 管理アプリ設定タブのテスト
- 既存のアプリ（noWinKey、autoHotkey、clibor、luna）が正しく表示されているか確認
- 任意のアプリを選択して詳細を確認

### 5. 保存機能のテスト
- "設定を保存" ボタンをクリック
- 保存完了のメッセージが日本語で表示されるか確認

### 6. アプリケーション終了
- "閉じる" ボタンをクリックしてアプリケーションを終了

## テスト完了後の確認

このファイルを保存した後、以下のPowerShellコマンドを実行してconfig.jsonの変更を確認してください：

```powershell
# 設定ファイルの変更時刻を確認
Get-Item config\config.json | Select-Object Name, Length, LastWriteTime

# 変更された設定値を確認
$config = Get-Content config\config.json -Raw | ConvertFrom-Json
Write-Host "更新後のOBSホスト: $($config.obs.websocket.host)"
Write-Host "更新後のOBSポート: $($config.obs.websocket.port)" 
Write-Host "更新後の言語設定: '$($config.language)'"

# 新しく追加されたゲームを確認
if ($config.games.PSObject.Properties | Where-Object { $_.Value.name -eq "Test Game" }) {
    Write-Host "✓ テストゲームが正常に追加されました" -ForegroundColor Green
} else {
    Write-Host "✗ テストゲームが見つかりません" -ForegroundColor Red
}
```

## 期待される結果

- config.jsonファイルの最終更新時刻が現在時刻に近い
- OBSホストが "testhost" に変更されている
- OBSポートが "4456" に変更されている  
- 言語設定が "ja" に変更されている
- 新しいテストゲームが games セクションに追加されている
- すべての日本語メッセージが正しく表示されている

このテストにより、Config Editorの基本的な編集・保存機能と日本語の文字エンコーディング対応が正しく動作することを確認できます。