# **Game Launcher & Environment Watcher 🚀**

**日本語** | [English](./README.md)

**競技ゲーマー向けに設計された、ゲームセッションを開始から終了まで自動化するPowerShellスクリプト。**

このスクリプトは、ゲーム開始前の面倒な環境設定（ホットキーの無効化、バックグラウンドアプリの終了など）を処理し、終了後に自動的にすべてを復元します。これにより、ゲームプレイのみに集中できます。

## **✨ 機能**

* **🎮 ゲーム固有の自動環境設定**: 設定に基づいて、各ゲーム用のカスタム環境を自動的にセットアップし、終了時に復元します。
* **🔧 ツール統合**: 以下のツールと機能を自動制御：
  * **Clibor**: ホットキーのオン/オフ切り替え。
  * **NoWinKey**: Windowsキーを無効化して誤操作を防止。
  * **AutoHotkey**: 実行中のスクリプトを一時停止し、ゲーム終了後に再開。
  * **OBS Studio**: OBSを起動し、ゲーム開始/終了時にリプレイバッファを自動開始/停止。
* **⚙️ 簡単な設定**: config.jsonファイルを編集するだけで、新しいゲームの追加や機能のオン/オフが可能。
* **🛡️ 堅牢な設計**: スクリプトが中断された場合（Ctrl+Cなど）でも、環境を正常に復元するクリーンアップ処理を含みます。

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
       "games": {
           "apex": { // ← "apex" が GameId
               "name": "Apex Legends",
               "steamAppId": "1172470", // Steam ストアページのURLで確認
               "processName": "r5apex\\*", // タスクマネージャーで確認（ワイルドカード \\* をサポート）
               "features": {
                   "manageWinKey": true,
                   "manageAutoHotkey": true,
                   "manageLuna": true,
                   "manageObs": true,
                   "manageCliborHotkey": true,
                   "manageObsReplayBuffer": true
               }
           }
           // ... 他のゲームをここに追加 ...
       },
       "paths": {
           // ↓↓↓ これらをPCの正しい実行ファイルパスに変更してください ↓↓↓
           "steam": "C:\\\\Program Files (x86)\\\\Steam\\\\steam.exe",
           "clibor": "C:\\\\Apps\\\\clibor\\\\Clibor.exe",
           "noWinKey": "C:\\\\Apps\\\\NoWinKey\\\\NoWinKey.exe",
           "autoHotkey": "", // ゲーム終了後に実行したいAutoHotkeyスクリプトのパス
           "obs": "C:\\\\Program Files\\\\obs-studio\\\\bin\\\\64bit\\\\obs64.exe"
       }
   }
   ```

   * **games**:
     * 管理したいゲームのエントリを追加します。キー（例："apex"、"dbd"）は後で -GameId パラメータとして使用されます。
     * features の boolean 値を true または false に設定して、各ゲームの特定の自動化を有効または無効にします。
   * **paths**:
     * 各アプリケーションの **実行ファイルへの絶対パス** を正しく設定してください。

## **🎬 使用方法**

PowerShellターミナルを開き、スクリプトのディレクトリに移動して、以下のコマンドを実行します：

\# 例: Apex Legends を起動する場合
.\\GameLauncherAndWatcher.ps1 \-GameId apex

\# 例: Dead by Daylight を起動する場合
.\\GameLauncherAndWatcher.ps1 \-GameId dbd

* config.json で設定した GameId（例："apex"、"dbd"）を -GameId パラメータに指定します。
* スクリプトは自動的に設定を適用し、Steam経由でゲームを起動します。
* ゲームを終了すると、スクリプトはプロセスの終了を検知し、自動的に環境を元の状態に復元します。

## **📜 ライセンス**

このプロジェクトは **MIT ライセンス** の下でライセンスされています。詳細は LICENSE ファイルをご覧ください。

## ❤️ 応援のお願い

このツールが競技ゲーマーの皆さんのゲーム体験をより快適で集中しやすいものにできることを心から願っています。

もしこのツールを気に入っていただけましたら、X.com（旧Twitter）などのSNSで使用していることをシェアしていただけると非常に嬉しく思います。皆さんの声が、似たようなソリューションを探している他のゲーマーの方々の助けになります。

その際は、ハッシュタグ **`#GameLauncherWatcher`** をお使いいただけると幸いです。皆さんの投稿を見るのは私にとって大きな喜びです！

このツールが人々の役に立っていることを知ることが、改善を続けるための最大のモチベーションとなります。
