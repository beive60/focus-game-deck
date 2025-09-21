# **Focus Game Deck 🚀**

**日本語** | [English](./README.md)

**競技ゲーマー向けに設計された、ゲームセッションを開始から終了まで自動化するPowerShellスクリプト。**

このスクリプトは、ゲーム開始前の面倒な環境設定（ホットキーの無効化、バックグラウンドアプリの終了など）を処理し、終了後に自動的にすべてを復元します。これにより、ゲームプレイのみに集中できます。

## **✨ 機能**

* **🎮 ゲーム固有の自動環境設定**: 設定に基づいて、各ゲーム用のカスタム環境を自動的にセットアップし、終了時に復元します。
* **🔧 汎用アプリケーション管理**: 設定可能な起動・終了アクションで任意のアプリケーションを柔軟に制御。
* **🔄 簡単な拡張性**: 設定ファイルを編集するだけで新しいアプリケーションを管理対象に追加可能 - コード変更は一切不要。
* **🛡️ 堅牢な設計**: 包括的な設定検証機能と、スクリプトが中断された場合（Ctrl+Cなど）でも環境を正常に復元するクリーンアップ処理を含みます。
* **⚙️ 特別な統合機能**: 以下への組み込みサポート：
  * **Clibor**: ホットキーのオン/オフ切り替え。
  * **NoWinKey**: Windowsキーを無効化して誤操作を防止。
  * **AutoHotkey**: 実行中のスクリプトを停止し、ゲーム終了後に再開。
  * **OBS Studio**: OBSを起動し、ゲーム開始/終了時にリプレイバッファを自動開始/停止。

## **🛠️ 必要要件**

このスクリプトを使用するには、以下のソフトウェアがインストールされている必要があります：

* **PowerShell**: Windowsに標準搭載。
* **Steam**
* **OBS Studio**: [公式サイト](https://obsproject.com/)
  * **obs-websocket プラグイン**: OBS v28以降にデフォルトで含まれています。設定で有効になっていることを確認してください。
* **\[オプション\] Clibor**: クリップボードユーティリティ。
* **\[オプション\] NoWinKey**: Windowsキーを無効化するツール。
* **\[オプション\] AutoHotkey**: 自動化のためのスクリプト言語。
* **\[オプション\] Luna**: （または管理したいその他のバックグラウンドアプリケーション）。

## **🚀 セットアップと設定**

1. **リポジトリのダウンロード**: このリポジトリをクローンするか、ZIPファイルとしてダウンロードします。
2. **設定ファイルの作成**:
   * config.json.sample をコピーして、同じディレクトリに config.json という名前で保存します。
3. **config.json の編集**:
   * config.json をテキストエディタで開き、お使いのシステムに合わせてパスと設定を更新します。

   ```json
   {
       "obs": {
           "websocket": {
               "host": "localhost",
               "port": 4455,
               "password": "" // OBS WebSocketサーバーのパスワードをここに設定
           },
           "replayBuffer": true
       },
       "managedApps": {
           "noWinKey": {
               "path": "C:\\\\Apps\\\\NoWinKey\\\\NoWinKey.exe",
               "processName": "NoWinKey",
               "startupAction": "start",
               "shutdownAction": "stop",
               "arguments": ""
           },
           "autoHotkey": {
               "path": "",
               "processName": "AutoHotkeyU64|AutoHotkey|AutoHotkey64",
               "startupAction": "stop",
               "shutdownAction": "start",
               "arguments": ""
           },
           "clibor": {
               "path": "C:\\\\Apps\\\\clibor\\\\Clibor.exe",
               "processName": "Clibor",
               "startupAction": "none",
               "shutdownAction": "none",
               "arguments": "/hs"
           },
           "luna": {
               "path": "",
               "processName": "Luna",
               "startupAction": "stop",
               "shutdownAction": "none",
               "arguments": ""
           }
       },
       "games": {
           "apex": { // ← "apex" が GameId
               "name": "Apex Legends",
               "steamAppId": "1172470", // Steam ストアページのURLで確認
               "processName": "r5apex\\*", // タスクマネージャーで確認（ワイルドカード \\* をサポート）
               "appsToManage": ["noWinKey", "autoHotkey", "luna", "obs", "clibor"]
           },
           "dbd": {
               "name": "Dead by Daylight",
               "steamAppId": "381210",
               "processName": "DeadByDaylight-Win64-Shipping\\*",
               "appsToManage": ["obs", "clibor"]
           }
           // ... 他のゲームをここに追加 ...
       },
       "paths": {
           // ↓↓↓ これらをPCの正しい実行ファイルパスに変更してください ↓↓↓
           "steam": "C:\\\\Program Files (x86)\\\\Steam\\\\steam.exe",
           "obs": "C:\\\\Program Files\\\\obs-studio\\\\bin\\\\64bit\\\\obs64.exe"
       }
   }
   ```

   * **managedApps**:  
     * 管理したいすべてのアプリケーションを定義します。各アプリには以下が含まれます：
       * `path`: 実行ファイルのフルパス（プロセス管理のみの場合は空でも可）
       * `processName`: 停止用のプロセス名（|でワイルドカードをサポート）
       * `startupAction`: ゲーム開始時のアクション（"start", "stop", "none"）
       * `shutdownAction`: ゲーム終了時のアクション（"start", "stop", "none"）
       * `arguments`: オプションのコマンドライン引数
   * **games**:  
     * 管理したいゲームのエントリを追加します。キー（例："apex"、"dbd"）は後で -GameId パラメータとして使用されます。  
     * `appsToManage` 配列で、各ゲームで管理するアプリケーションを指定します。  
   * **paths**:  
     * SteamとOBSのパスを設定します。その他のアプリケーションパスは `managedApps` で定義されます。

## **🎬 使用方法**

PowerShellターミナルを開き、スクリプトのディレクトリに移動して、以下のコマンドを実行します：

\# 例: Apex Legends を起動する場合
.\\Invoke-FocusGameDeck.ps1 \-GameId apex

\# 例: Dead by Daylight を起動する場合
.\\Invoke-FocusGameDeck.ps1 \-GameId dbd

* config.json で設定した GameId（例："apex"、"dbd"）を -GameId パラメータに指定します。
* スクリプトは自動的に設定を適用し、Steam経由でゲームを起動します。
* ゲームを終了すると、スクリプトはプロセスの終了を検知し、自動的に環境を元の状態に復元します。

## **🔧 トラブルシューティング**

1. **スクリプトの実行が失敗する場合:**
   * PowerShellの実行ポリシーを確認してください
   * 管理者権限で実行してみてください

2. **プロセスの停止/開始が失敗する場合:**
   * `managedApps` のパス設定が正しいことを確認してください
   * アプリケーションが正しくインストールされていることを確認してください
   * プロセス名が正しいことを確認してください（タスクマネージャーで確認）

3. **ゲームが起動しない場合:**
   * Steam AppIDが正しいことを確認してください
   * Steamが実行されていることを確認してください

4. **OBSリプレイバッファが開始しない場合:**
   * OBS WebSocketサーバーが有効になっていることを確認してください
   * WebSocket設定（ホスト、ポート、パスワード）が正しいことを確認してください
   * OBSでリプレイバッファが設定されていることを確認してください

5. **設定検証エラーが発生する場合:**
   * `appsToManage` で参照されているすべてのアプリケーションが `managedApps` に存在することを確認してください
   * 必要なプロパティ（path, processName, startupAction, shutdownAction）が存在することを確認してください
   * アクション値が次のいずれかであることを確認してください: "start", "stop", "none"

## **➕ 新しいアプリケーションの追加**

新しいアーキテクチャにより、管理対象のアプリケーションを非常に簡単に追加できます。`managedApps` セクションに追加するだけです：

```json
{
  "managedApps": {
    "discord": {
      "path": "C:\\Users\\Username\\AppData\\Local\\Discord\\app-1.0.9012\\Discord.exe",
      "processName": "Discord",
      "startupAction": "stop",
      "shutdownAction": "start",
      "arguments": ""
    },
    "spotify": {
      "path": "C:\\Users\\Username\\AppData\\Roaming\\Spotify\\Spotify.exe",
      "processName": "Spotify",
      "startupAction": "stop",
      "shutdownAction": "none",
      "arguments": ""
    }
  },
  "games": {
    "apex": {
      "appsToManage": ["noWinKey", "autoHotkey", "discord", "spotify", "obs", "clibor"]
    }
  }
}
```

**以上です！** PowerShellスクリプトの変更は一切不要です。システムは `managedApps` で定義された任意のアプリケーションを自動的に処理します。

## **📜 ライセンス**

このプロジェクトは **MIT ライセンス** の下でライセンスされています。詳細は LICENSE ファイルをご覧ください。

## ❤️ 応援のお願い

このツールが競技ゲーマーの皆さんのゲーム体験をより快適で集中しやすいものにできることを心から願っています。

もしこのツールを気に入っていただけましたら、X.com（旧Twitter）などのSNSで使用していることをシェアしていただけると非常に嬉しく思います。皆さんの声が、似たようなソリューションを探している他のゲーマーの方々の助けになります。

その際は、ハッシュタグ **`#GameLauncherWatcher`** をお使いいただけると幸いです。皆さんの投稿を見るのは私にとって大きな喜びです！

このツールが人々の役に立っていることを知ることが、改善を続けるための最大のモチベーションとなります。
