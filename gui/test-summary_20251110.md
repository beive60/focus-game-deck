# テスト実行結果サマリー

Date: 2025-11-10
Branch: refactor/gui-functions

refactor/gui-functions ブランチのプルリクエスト前テストを実行しました。以下が結果のまとめです。

✅ 合格したテスト
基本設定ファイル検証 (Test-Core-ConfigFileValidation.ps1)

設定ファイルの読み込み、OBS設定、言語設定、ゲーム設定が正常に動作
ComboBoxローカライゼーション (Test-GUI-ComboBoxLocalization.ps1)

12個のComboBoxアイテムすべてが正しくローカライズされている
日本語表示が正常に機能
文字エンコーディング (Test-Core-CharacterEncoding.ps1)

UTF-8エンコーディングが全ファイルで正しく実装されている
BOMなしUTF-8の使用が確認された
日本語文字の整合性が保たれている
10/10テスト合格
ログローテーション (Test-Core-LogRotation.ps1)

30日、90日、180日、無期限の保持ポリシーがすべて正常に動作
無効な設定のハンドリングも正常
12/12テスト合格

⚠️ 問題が検出されたテスト
ConfigEditor整合性テスト (Test-GUI-ConfigEditorConsistency.ps1)

68個の未マッピング要素が検出されました
これらは主にツールチップ、新しいUI要素（Discord、VTube Studio、OBSの統合設定など）
既存の機能は動作していますが、これらの要素のローカライゼーションが未完了
要素マッピング完全性 (Test-GUI-ElementMappingCompleteness.ps1)

gui/messages.jsonがパスに存在しない（messages.jsonに移動済み）
テストスクリプトのパス修正が必要
マルチプラットフォームサポート (Test-Core-MultiPlatformSupport.ps1)

32/34テスト合格
2つの失敗：プラットフォーム数の期待値不一致（standaloneプラットフォームの追加により4になった）
機能的には問題なし、テストの期待値更新が必要
ローカライズメッセージ関数 (Test-Core-LocalizedMessageFunction.ps1)

Get-ProjectVersionInfo関数が見つからないエラー
テストスクリプトの依存関係の問題
ゲームランチャータブ (Test-GUI-GameLauncherTab.ps1)

4/7テスト合格
3つの失敗：メッセージの引数置換が未実装（{0}プレースホルダーが残っている）
📋 推奨事項
プルリクエスト前に修正すべき項目:

高優先度: ゲームランチャータブのメッセージ引数置換の実装
中優先度: 68個の未マッピング要素のローカライゼーション追加
低優先度: テストスクリプトのパス修正とプラットフォーム数期待値の更新
現状の判断:

コア機能は正常に動作しています
既に人間によるGUI操作テストで動作確認済み
検出された問題は主にローカライゼーションの未完了部分です
致命的なバグは検出されていません

## Mapping Issues Details

```pwsh
powershell -ExecutionPolicy Bypass -File ./test/Test-GUI-ConfigEditorConsistency.ps1
PS focus-game-deck> powershell -ExecutionPolicy Bypass -File ./test/Test-GUI-ConfigEditorConsistency.ps1
=== Focus Game Deck - ConfigEditor Consistency Test ===
Checking files:
- MainWindow.xaml: C:\Users\mnaoy\dev\focus-game-deck\gui\MainWindow.xaml
- Mappings file:   C:\Users\mnaoy\dev\focus-game-deck\gui\ConfigEditor.Mappings.ps1
Loading ConfigEditor mappings
[OK] Mappings loaded successfully
Analyzing MainWindow.xaml
[OK] Extracted 153 UI elements with placeholders

Checking mapping completeness
Mapping Analysis Results:
- Total UI elements: 153
- Mapped elements:   85
[ERROR] - Missing mappings:  68

[ERROR] TEST FAILED: Missing mappings detected!
[ERROR] Elements requiring mappings:
   - AppArgumentsLabelPanel [Placeholder: [TOOLTIP_LAUNCH_ARGUMENTS]]
   - AppArgumentsTooltip [Placeholder: ?]
   - AppIdLabelPanel [Placeholder: [TOOLTIP_APP_ID]]
   - AppIdTooltip [Placeholder: ?]
   - AppProcessNameLabelPanel [Placeholder: [TOOLTIP_PROCESS_NAME]]
   - AppProcessNameTooltip [Placeholder: ?]
   - AutoDetectDiscordButton [Placeholder: 自動検出]
   - AutoDetectEpicTooltip [Placeholder: ?]
   - AutoDetectRiotTooltip [Placeholder: ?]
   - AutoDetectSteamTooltip [Placeholder: ?]
   - AutoDetectVTubeButton [Placeholder: 自動検出]
   - BrowseDiscordPathButton [Placeholder: 参照]
   - BrowseVTubePathButton [Placeholder: 参照]
   - DiscordDisableOverlayCheckBox [Placeholder: ゲーム中はオーバーレイを無効化]
   - DiscordEnableGameModeCheckBox [Placeholder: ゲーム開始時に自動制御を有効化]
   - DiscordRPCEnableCheckBox [Placeholder: Rich Presenceを有効化]
   - EpicGameIdLabelPanel [Placeholder: [TOOLTIP_EPIC_GAME_ID]]
   - EpicGameIdTooltip [Placeholder: ?]
   - ExecutablePathLabelPanel [Placeholder: [TOOLTIP_EXECUTABLE_PATH]]
   - ExecutablePathTooltip [Placeholder: ?]
   - GameEndActionLabelPanel [Placeholder: [TOOLTIP_GAME_ACTIONS]]
   - GameEndActionTooltip [Placeholder: ?]
   - GameIdLabelPanel [Placeholder: [TOOLTIP_GAME_ID]]
   - GameIdTooltip [Placeholder: ?]
   - GameLauncherTypeEnhancedItem [Placeholder: [ENHANCED_SHORTCUTS]]
   - GameLauncherTypeTraditionalItem [Placeholder: [TRADITIONAL_BATCH]]
   - GameNameLabelPanel [Placeholder: [TOOLTIP_DISPLAY_NAME]]
   - GameNameTooltip [Placeholder: ?]
   - GameStartActionLabelPanel [Placeholder: [TOOLTIP_GAME_ACTIONS]]
   - GameStartActionTooltip [Placeholder: ?]
   - GracefulTimeoutLabelPanel [Placeholder: [TOOLTIP_GRACEFUL_TIMEOUT]]
   - GracefulTimeoutTooltip [Placeholder: ?]
   - LauncherTypeEnhancedItem [Placeholder: [ENHANCED_SHORTCUTS]]
   - LauncherTypeTraditionalItem [Placeholder: [TRADITIONAL_BATCH]]
   - LogRetention180Item [Placeholder: [LOG_RETENTION_180]]
   - LogRetention30Item [Placeholder: [LOG_RETENTION_30]]
   - LogRetention7Item [Placeholder: [LOG_RETENTION_7]]
   - LogRetentionUnlimitedItem [Placeholder: [LOG_RETENTION_UNLIMITED]]
   - OBSAutoStartCheckBox [Placeholder: ゲーム開始時にOBSを自動起動]
   - OBSAutoStopCheckBox [Placeholder: ゲーム終了時にOBSを停止]
   - OBSReplayBufferCheckBox [Placeholder: ゲーム中にリプレイバッファを有効化]
   - OpenDiscordTabButton [Placeholder: → 設定を開く]
   - OpenOBSTabButton [Placeholder: → 設定を開く]
   - OpenVTubeStudioTabButton [Placeholder: → 設定を開く]
   - PlatformEpicItem [Placeholder: [EPIC_PLATFORM]]
   - PlatformRiotItem [Placeholder: [RIOT_PLATFORM]]
   - PlatformStandaloneItem [Placeholder: [STANDALONE_PLATFORM]]
   - PlatformSteamItem [Placeholder: [STEAM_PLATFORM]]
   - ProcessNameLabelPanel [Placeholder: [TOOLTIP_PROCESS_NAME]]
   - ProcessNameTooltip [Placeholder: ?]
   - RiotGameIdLabelPanel [Placeholder: [TOOLTIP_RIOT_GAME_ID]]
   - RiotGameIdTooltip [Placeholder: ?]
   - SteamAppIdLabelPanel [Placeholder: [TOOLTIP_STEAM_APP_ID]]
   - SteamAppIdTooltip [Placeholder: ?]
   - TerminationMethodLabelPanel [Placeholder: [TOOLTIP_TERMINATION_METHOD]]
   - TerminationMethodTooltip [Placeholder: ?]
   - UseDiscordIntegrationCheckBox [Placeholder: Discord]
   - UseOBSIntegrationCheckBox [Placeholder: OBS Studio]
   - UseVTubeStudioIntegrationCheckBox [Placeholder: VTube Studio]
   - VersionText [Placeholder: 1.0.1-alpha]
   - VTubeAutoStartCheckBox [Placeholder: ゲーム開始時にVTube Studioを自動起動]
   - VTubeAutoStopCheckBox [Placeholder: ゲーム終了時にVTube Studioを停止]
   - VTubeHostTextBox [Placeholder: localhost]
   - VTubeLaunchDirectRadio [Placeholder: 実行ファイルから直接起動]
   - VTubeLaunchViaSteamRadio [Placeholder: Steamから起動]
   - VTubePortTextBox [Placeholder: 8001]
   - VTubeSteamAppIdTextBox [Placeholder: 1325860]
   - VTubeWebSocketEnableCheckBox [Placeholder: WebSocket連携を有効化]
Please add the missing mappings to ConfigEditor.Mappings.ps1
```
