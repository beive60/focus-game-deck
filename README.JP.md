# **Focus Game Deck 🚀**

**日本語** | [English](./README.md)

**競技ゲーマー向けに設計された、ゲームセッションを開始から終了まで自動化するPowerShellスクリプト。**

このスクリプトは、ゲーム開始前の面倒な環境設定（ホットキーの無効化、バックグラウンドアプリの終了など）を処理し、終了後に自動的にすべてを復元します。これにより、ゲームプレイのみに集中できます。

## **✨ 機能**

* **🎮 ゲーム固有の自動環境設定**: 設定に基づいて、各ゲーム用のカスタム環境を自動的にセットアップし、終了時に復元します。
* **🔧 汎用アプリケーション管理**: 設定可能な起動・終了アクションで任意のアプリケーションを柔軟に制御。
* **🔄 簡単な拡張性**: 設定ファイルを編集するだけで新しいアプリケーションを管理対象に追加可能 - コード変更は一切不要。
* **🛡️ 堅牢な設計**: 包括的な設定検証機能と、スクリプトが中断された場合（Ctrl+Cなど）でも環境を正常に復元するクリーンアップ処理を含みます。
* **📊 高度なログ管理**: 包括的なログシステムと自動クリーンアップ機能：
  * **自動ログローテーション**: 設定可能な保存期間（30日/90日/180日/無期限）で古いログファイルを自動削除。
  * **ディスク容量保護**: ユーザーが手動管理する必要なく、常に安全な期間のログのみを保持。
  * **統合ログ管理**: デバッグ情報、操作履歴、エラー情報を統一されたログファイルに記録。
* **⚙️ 特別な統合機能**: 以下への組み込みサポート：
  * **Clibor**: ホットキーのオン/オフ切り替え。
  * **NoWinKey**: Windowsキーを無効化して誤操作を防止。
  * **AutoHotkey**: 実行中のスクリプトを停止し、ゲーム終了後に再開。
  * **OBS Studio**: OBSを起動し、ゲーム開始/終了時にリプレイバッファを自動開始/停止。
  * **VTube Studio**: Steam版・スタンドアロン版両対応、ゲーム用モード切り替えと配信復帰の自動化。
  * **Discord**: ゲーミングモード自動切り替え、Rich Presence表示、オーバーレイ制御による集中環境の最適化。

## **🛠️ 必要要件**

このスクリプトを使用するには、以下のソフトウェアがインストールされている必要があります：

* **PowerShell**: Windowsに標準搭載。
* **Steam**
* **OBS Studio**: [公式サイト](https://obsproject.com/)
  * **obs-websocket プラグイン**: OBS v28以降にデフォルトで含まれています。設定で有効になっていることを確認してください。
* **\[オプション\] Clibor**: クリップボードユーティリティ。
* **\[オプション\] NoWinKey**: Windowsキーを無効化するツール。
* **\[オプション\] AutoHotkey**: 自動化のためのスクリプト言語。
* **\[オプション\] VTube Studio**: VTuber向けアバター管理ソフト。
* **\[オプション\] Discord**: ゲーマー向けコミュニケーションプラットフォーム。
* **\[オプション\] Luna**: （または管理したいその他のバックグラウンドアプリケーション）。

## **💻 インストール方法**

Focus Game Deckは、さまざまなユーザーの好みに合わせて柔軟なインストール方法を提供しています：

### **方法1: 実行ファイル配布（推奨）**

[GitHub Releases](https://github.com/beive60/focus-game-deck/releases)から事前ビルドされた、デジタル署名済みの実行ファイルをダウンロード：

* **Focus-Game-Deck.exe** - メインアプリケーション（単一ファイル、PowerShell不要）
* **Focus-Game-Deck-Config-Editor.exe** - GUI設定エディター
* **Focus-Game-Deck-MultiPlatform.exe** - 拡張プラットフォーム対応版

**利点:**

* ✅ PowerShell実行ポリシーの問題なし
* ✅ セキュリティと信頼性のためのデジタル署名
* ✅ 単一ファイル配布
* ✅ PowerShellが制限されたシステムでも動作

### **方法2: PowerShellスクリプト（開発者/上級ユーザー向け）**

直接PowerShell実行のためにリポジトリをクローンまたはダウンロード：

```bash
git clone https://github.com/beive60/focus-game-deck.git
cd focus-game-deck
```

**利点:**

* ✅ 完全なソースコードの可視性
* ✅ 簡単なカスタマイズと変更
* ✅ 最新の開発機能へのアクセス

## **🏗️ アーキテクチャと設計**

Focus Game Deckは**軽量、保守性、拡張性**を重視した設計思想で構築されています：

### **コア原則**

* **🪶 軽量性**: Windows標準のPowerShell + WPFを使用、追加ランタイム不要
* **🔧 設定駆動型**: すべての動作をconfig.jsonで制御 - カスタマイズにコード変更不要
* **🌐 国際化対応**: 適切な日本語文字サポートのためのJSON外部リソースパターン
* **📦 単一ファイル配布**: ps2exeを使用して単一実行ファイルにコンパイル可能

### **技術スタック**

* **コアエンジン**: 包括的なエラーハンドリングを備えたPowerShellスクリプト
* **GUIモジュール**: JSON ベース国際化を備えたPowerShell + WPF
* **設定**: 検証とサンプルテンプレートを備えたJSONベース設定
* **統合**: ネイティブWindows APIとアプリケーション固有プロトコル

詳細なアーキテクチャ情報については、[docs/ja/ARCHITECTURE.md](./docs/ja/ARCHITECTURE.md)をご覧ください。

### **ビルドシステムとディストリビューション**

Focus Game Deckは包括的な3階層ビルドシステムを特徴としています：

* **📦 自動実行ファイル生成**: ps2exeベースでスタンドアロン実行ファイルにコンパイル
* **🔐 デジタル署名インフラ**: 拡張検証証明書対応と自動署名
* **🚀 本番対応パイプライン**: 完全な開発・本番ビルドワークフロー
* **📋 リリースパッケージ管理**: 署名済み配布パッケージの自動作成

**ビルドスクリプト:**

* `Master-Build.ps1` - 完全ビルド統制（開発・本番ワークフロー）
* `Build-FocusGameDeck.ps1` - コア実行ファイル生成とビルド管理
* `Sign-Executables.ps1` - デジタル署名管理と証明書操作

詳細なビルドシステムドキュメントについては、[docs/BUILD-SYSTEM.md](./docs/BUILD-SYSTEM.md)をご覧ください。

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
           },
           "discord": {
               "path": "%LOCALAPPDATA%\\\\Discord\\\\app-*\\\\Discord.exe",
               "processName": "Discord",
               "startupAction": "set-discord-gaming-mode",
               "shutdownAction": "restore-discord-normal",
               "arguments": "",
               "discord": {
                   "statusOnGameStart": "dnd",
                   "statusOnGameEnd": "online",
                   "disableOverlay": true,
                   "customPresence": {
                       "enabled": true,
                       "state": "Focus Gaming Mode"
                   },
                   "rpc": {
                       "enabled": true,
                       "applicationId": ""
                   }
               }
           }
       },
       "games": {
           "apex": { // ← "apex" が GameId
               "name": "Apex Legends",
               "steamAppId": "1172470", // Steam ストアページのURLで確認
               "processName": "r5apex\\*", // タスクマネージャーで確認（ワイルドカード \\* をサポート）
               "appsToManage": ["noWinKey", "autoHotkey", "luna", "obs", "clibor", "discord"]
           },
           "dbd": {
               "name": "Dead by Daylight",
               "steamAppId": "381210",
               "processName": "DeadByDaylight-Win64-Shipping\\*",
               "appsToManage": ["obs", "clibor", "discord"]
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
   * **logging**:
     * ログ機能を設定します。以下のオプションが利用可能です：
       * `level`: ログレベル（"Trace", "Debug", "Info", "Warning", "Error", "Critical"）
       * `enableFileLogging`: ファイルへのログ出力を有効にする（true/false）
       * `logRetentionDays`: ログファイルの自動削除期間（30, 90, 180, または -1 で無期限）
       * `enableNotarization`: ログの暗号化検証を有効にする（true/false）

## **🎬 使用方法**

### **実行ファイル版の使用（推奨）**

コマンドプロンプトまたはPowerShellから実行ファイルを実行するだけです：

```cmd
# コマンドプロンプト
Focus-Game-Deck.exe apex

# PowerShell
.\Focus-Game-Deck.exe apex
```

### **PowerShellスクリプト版の使用**

PowerShellターミナルを開き、スクリプトのディレクトリに移動して、以下のコマンドを実行します：

```powershell
# 例: Apex Legends を起動する場合
.\Invoke-FocusGameDeck.ps1 -GameId apex

# 例: Dead by Daylight を起動する場合
.\Invoke-FocusGameDeck.ps1 -GameId dbd
```

### **一般的な使用上の注意**

* config.json で設定した GameId（例："apex"、"dbd"）をパラメータに指定します。
* アプリケーションは自動的に設定を適用し、Steam経由でゲームを起動します。
* ゲームを終了すると、アプリケーションはプロセスの終了を検知し、自動的に環境を元の状態に復元します。
* **GUI設定**: ユーザーフレンドリーな設定編集には `Focus-Game-Deck-Config-Editor.exe` を使用してください。

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

6. **Discord統合が動作しない場合:**
   * Discordが正常にインストールされ、実行されていることを確認してください
   * Discord RPC機能を使用する場合は、有効なDiscord Application IDが必要です
   * Rich Presence機能には、Discordの設定で「ゲームアクティビティを表示する」が有効になっている必要があります
   * オーバーレイ制御は手動設定が必要な場合があります

## **➕ 新しいアプリケーションの追加**

新しいアーキテクチャにより、管理対象のアプリケーションを非常に簡単に追加できます。`managedApps` セクションに追加するだけです：

```json
{
  "managedApps": {
    "discord": {
      "path": "%LOCALAPPDATA%\\Discord\\app-*\\Discord.exe",
      "processName": "Discord",
      "startupAction": "set-discord-gaming-mode",
      "shutdownAction": "restore-discord-normal",
      "arguments": "",
      "discord": {
        "statusOnGameStart": "dnd",
        "statusOnGameEnd": "online",
        "disableOverlay": true,
        "customPresence": {
          "enabled": true,
          "state": "Gaming with Focus Game Deck"
        },
        "rpc": {
          "enabled": true,
          "applicationId": "YOUR_DISCORD_APP_ID_HERE"
        }
      }
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

## **🗺️ プロジェクト・ロードマップ**

今後の予定を知りたいですか？[詳細なロードマップ](./docs/ja/ROADMAP.md)で、計画されている機能、タイムライン、Focus Game Deckの将来の開発戦略ビジョンをご確認ください。

## **📦 バージョン管理とリリース**

Focus Game Deckは一貫したバージョン管理のために **[セマンティックバージョニング](https://semver.org/)** (SemVer) に従っています。

### 現在のバージョン

**v1.2.0** - ビルドシステムとデジタル署名インフラ完了

### リリースチャンネル

* **アルファ版**: コア機能検証のための限定テストリリース
* **ベータ版**: より広範囲なフィードバックのためのパブリックベータテスト
* **安定版**: すべてのユーザー向けの本番対応リリース

### 開発者向け情報

プロジェクトに貢献される場合は、包括的なドキュメントをご確認ください：

* **[バージョン管理仕様書](./docs/VERSION-MANAGEMENT.md)** - SemVer実装の詳細
* **[GitHub Releases ガイド](./docs/GITHUB-RELEASES-GUIDE.md)** - リリース運用手順
* **[開発者向けリリースガイド](./docs/DEVELOPER-RELEASE-GUIDE.md)** - ステップバイステップのリリースプロセス

### ダウンロードとインストール

* **最新リリース**: [GitHub Releases](https://github.com/beive60/focus-game-deck/releases/latest) から入手可能
* **実行ファイル版**: 事前ビルドされた署名済み実行ファイルですぐに使用可能
* **ソースコード**: 開発者と上級ユーザー向けの完全なPowerShellソースコード
* **セキュリティ**: すべてのリリースは最大限の信頼性のために拡張検証証明書でデジタル署名されています
* **ビルドシステム**: 完全な自動ビルドと署名インフラが実装されています
