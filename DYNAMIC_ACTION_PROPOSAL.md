# Dynamic Action Selection Proposal
# GUI設定エディタの動的アクション選択機能設計案

## 現在の問題点

### 1. UX問題
- 全てのアクションが全てのアプリに表示される
- ユーザーが不適切な選択を行いやすい
- 設定エラーの原因となる

### 2. スケーラビリティ問題
- 新アプリ追加時の広範囲な修正が必要
- アクション数 × アプリ数の複雑性増加
- 保守性の悪化

## 提案する解決策

### 1. 動的アクション選択機能

```powershell
# 現在の実装 (静的)
$actions = @("start-process", "stop-process", "toggle-hotkeys",
             "start-vtube-studio", "stop-vtube-studio",
             "set-discord-gaming-mode", "restore-discord-normal",
             "pause-wallpaper", "play-wallpaper", "none")

# 提案する実装 (動的)
function Get-AvailableActionsForApp {
    param([string]$AppId, [string]$ExecutablePath)

    # 基本アクション（全アプリ共通）
    $baseActions = @("start-process", "stop-process", "toggle-hotkeys", "pause-wallpaper", "play-wallpaper", "none")

    # アプリ固有アクション判定
    $specificActions = @()

    # AppIdベースの判定
    switch ($AppId) {
        "discord" { $specificActions += @("set-discord-gaming-mode", "restore-discord-normal") }
        "vtubeStudio" { $specificActions += @("start-vtube-studio", "stop-vtube-studio") }
    }

    # ExecutablePathベースの判定（将来の拡張性）
    if ($ExecutablePath -like "*Discord*") {
        $specificActions += @("set-discord-gaming-mode", "restore-discord-normal")
    }

    return $baseActions + $specificActions
}
```

### 2. GUI動的更新機能

```powershell
function Update-ActionComboBoxes {
    param([string]$SelectedAppId)

    $availableActions = Get-AvailableActionsForApp -AppId $SelectedAppId

    # コンボボックス更新
    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

    # 現在の選択を保存
    $currentStartAction = $gameStartActionCombo.SelectedItem
    $currentEndAction = $gameEndActionCombo.SelectedItem

    # アイテムをクリアして再構築
    $gameStartActionCombo.Items.Clear()
    $gameEndActionCombo.Items.Clear()

    foreach ($action in $availableActions) {
        $gameStartActionCombo.Items.Add($action)
        $gameEndActionCombo.Items.Add($action)
    }

    # 選択を復元（可能な場合）
    if ($currentStartAction -in $availableActions) {
        $gameStartActionCombo.SelectedItem = $currentStartAction
    }
    if ($currentEndAction -in $availableActions) {
        $gameEndActionCombo.SelectedItem = $currentEndAction
    }
}
```

### 3. 設定ベース拡張システム

```json
// config.json に追加する拡張設定
{
  "actionMappings": {
    "discord": {
      "availableActions": ["set-discord-gaming-mode", "restore-discord-normal"],
      "description": "Discord-specific actions"
    },
    "vtubeStudio": {
      "availableActions": ["start-vtube-studio", "stop-vtube-studio"],
      "description": "VTube Studio-specific actions"
    }
  }
}
```

## 期待される効果

### UX改善
- ✅ 適切なアクションのみ表示
- ✅ 設定エラーの防止
- ✅ 直感的な操作性

### 保守性向上
- ✅ 新アプリ追加が設定ファイルベース
- ✅ コード修正範囲の限定
- ✅ テストケースの簡素化

### 将来の拡張性
- ✅ ExecutablePathベースの自動判定
- ✅ プラグインシステムへの発展可能
- ✅ 多言語対応の容易化

## 実装優先度

1. **High**: 動的アクション選択機能の基本実装
2. **Medium**: ExecutablePathベースの自動判定機能
3. **Low**: 設定ベース拡張システム（将来の大規模拡張時）

## リスク評価

### 低リスク
- 既存設定との互換性維持
- 段階的実装が可能

### 中リスク
- UI応答性の考慮が必要
- テストケースの再設計

この提案により、スケーラブルで保守しやすいアクション選択システムが実現できます。
