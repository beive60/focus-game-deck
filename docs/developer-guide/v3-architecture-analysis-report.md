# Focus Game Deck v3.0 Architecture Analysis Report

## 整合性分析レポート (Consistency Analysis Report)

このレポートは、v3.0 Multi-Executable Bundle Architectureのドキュメントと実装の整合性を分析し、リファクタリング提案を行います。

> **注意:** このレポートで特定された問題点は、本リファクタリング作業で修正済みです。修正箇所は ✅ マークで示されています。

---

## 1. アーキテクチャと実装の整合性チェック

### 1.1 ファイル命名の乖離 ✅ (修正済み)

| ドキュメント記載（修正前） | 実際のファイル | 重大度 | 状態 |
|--------------------------|---------------|--------|------|
| `src/Main-Router.ps1` | `src/Main.PS1` | **HIGH** | ✅ 修正済み |
| Component Reference Table の記述 | 実際の構成 | **MEDIUM** | ✅ 修正済み |

**修正されたファイル:**
- `docs/developer-guide/architecture.md` - Main.PS1 への参照に更新
- `docs/developer-guide/build-system.md` - Main.PS1 への参照に更新
- `docs/developer-guide/bundling-implementation.md` - Main.PS1 への参照に更新

### 1.2 Build-Time Patchingの実装状況

**ドキュメント定義 (architecture.md lines 175-228):**
```powershell
# >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
# Development code: simple relative paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot "config/config.json"
# <<< BUILD-TIME-PATCH-END <<<
```

**実際の実装 (Main.PS1, ConfigEditor.ps1, Invoke-FocusGameDeck.ps1):**

実装はドキュメントの「Path Resolution Strategy」(lines 207-220) に準拠しています。環境検出ロジック (`$isExecutable`) は正しく実装されています：

```powershell
# Main.PS1 (lines 86-98)
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

if ($isExecutable) {
    $appRoot = Split-Path -Parent $currentProcess.Path
} else {
    $appRoot = Split-Path -Parent $PSScriptRoot
}
```

**評価:** ✅ Build-Time Patching戦略と実装は整合しています。

### 1.3 Multi-Executable Bundle Architecture構成

**ドキュメント定義:**
1. `Focus-Game-Deck.exe` (Main Router) ← `src/Main-Router.ps1`
2. `ConfigEditor.exe` (GUI) ← `gui/ConfigEditor.ps1`
3. `Invoke-FocusGameDeck.exe` (Game Launcher) ← `src/Invoke-FocusGameDeck.ps1`

**実際の構成:**
1. `Focus-Game-Deck.exe` ← `src/Main.PS1` (**名前不一致**)
2. `ConfigEditor.exe` ← `gui/ConfigEditor.ps1` (✅ 一致)
3. `Invoke-FocusGameDeck.exe` ← `src/Invoke-FocusGameDeck.ps1` (✅ 一致)

---

## 2. コード品質とメンテナンス性の向上

### 2.1 AppManager.ps1 のSwitch文分析

**現状分析:**

`AppManager.ps1` 内の `InvokeIntegrationAction` メソッド (lines 267-296) では、integration typeごとにswitch文でハンドラーを呼び出しています：

```powershell
switch ($integrationId) {
    "obs" { return $this.HandleOBSAction($manager, $integrationConfig, $action) }
    "discord" { return $this.HandleDiscordAction($manager, $integrationConfig, $action) }
    "vtubeStudio" { return $this.HandleVTubeStudioAction($manager, $integrationConfig, $action) }
    "voiceMeeter" { return $this.HandleVoiceMeeterAction($manager, $integrationConfig, $action) }
    default { ... }
}
```

**評価:** 
現在のswitch文は、4つの統合のみを管理しており、許容範囲内です。PowerShellクラスの継承制約を考慮すると、現在のパターンは適切です。ドキュメントの「Hybrid Utility Class Pattern」(lines 358-417) もこのアプローチを支持しています。

**推奨事項:** 将来的に統合が増加した場合（7+）は、Strategyパターンへの移行を検討してください。

### 2.2 冗長コードの削除対象

#### 2.2.1 `$classAlreadyDefined` チェック (ConfigEditor.ps1 lines 68-111)

```powershell
if (-not $isCompiledExecutable) {
    $classAlreadyDefined = $false
    try {
        $existingType = [ConfigEditorState] -as [type]
        if ($null -ne $existingType) {
            $classAlreadyDefined = $true
            # Warning messages...
        }
    } catch {
        $classAlreadyDefined = $false
    }
}
```

**評価:** 
このチェックは開発時のスクリプトモードでの重複実行防止に必要です。EXE化後は不要ですが、開発ワークフローを考慮すると削除は推奨しません。ただし、より簡潔な実装が可能です：

```powershell
# 改善案: よりシンプルな実装
if (-not $isCompiledExecutable -and [type]::GetType('ConfigEditorState')) {
    Write-Warning "Classes already defined. Please restart PowerShell session."
    if (-not $NoAutoStart) { exit 1 }
}
```

### 2.3 エラーハンドリングとWrite-Hostガイドライン違反

**「Character Encoding and Console Compatibility Guidelines」(architecture.md lines 608-798) に基づく分析:**

#### 2.3.1 Write-Host使用箇所の違反

**ガイドライン違反の検出箇所:**

| ファイル | 行番号 | 問題点 |
|---------|--------|--------|
| `VTubeStudioManager.ps1` | 345, 353 | `-ForegroundColor` パラメータの使用 |
| `DiscordRPCClient.ps1` | 41, 63, 67, etc. | コンポーネントプレフィックスなしのWrite-Host |
| `AppManager.ps1` | 1023, 1036, 1046, etc. | 標準フォーマット未準拠のWrite-Host |

**ガイドライン準拠の例:**
```powershell
# 非準拠
Write-Host "Failed to start VTube Studio: $_"
Write-Host "[DEBUG] VTubeStudioManager: Token response received" -ForegroundColor Cyan

# 準拠形式
Write-Host "[ERROR] VTubeStudioManager: Failed to start VTube Studio - $_"
Write-Host "[DEBUG] VTubeStudioManager: Token response received"
```

---

## 3. 機能の整合性と廃止予定コード

### 3.1 Discord統合の現状

**コード内のコメント (AppManager.ps1):**
```powershell
# TODO: Re-enable in future release
# Disabled for v1.0 - Discord integration has known bugs
if ($false) { # Disabled for v1.0
    # Discord integration code...
}
```

**検出箇所:**
- `AppManager.ps1` lines 114-127 (InitializeIntegrationManagers)
- `AppManager.ps1` lines 543-584 (HandleDiscordAction)
- `AppManager.ps1` lines 1052-1107 (SetDiscordGamingMode, RestoreDiscordNormal)
- `Invoke-FocusGameDeck.ps1` lines 54-57 (module loading)

**技術的推奨事項:**

| オプション | 推奨度 | 理由 |
|-----------|--------|------|
| 削除 | ⚠️ 非推奨 | 将来的な再有効化が困難になる |
| 現状維持 | ✅ 推奨 | コードは無害であり、将来の再有効化が容易 |
| 機能フラグ化 | ✅✅ 最推奨 | config.jsonでの有効化制御を実装 |

**推奨アクション:** 
1. Discord統合コードは削除せず維持
2. `config.json` に `"discordEnabled": false` フラグを追加
3. 将来のリリースでバグ修正後に有効化

### 3.2 パス解決ロジックの重複

**重複箇所の特定:**

1. `src/Main.PS1` (lines 86-98)
2. `gui/ConfigEditor.ps1` (lines 134-162)
3. `src/Invoke-FocusGameDeck.ps1` (lines 27-40)
4. `src/modules/AppManager.ps1` (lines 398-405)
5. `build-tools/Build-FocusGameDeck.ps1` (lines 356-361)

**共通化案:**

`scripts/PathResolver.ps1` として共通モジュール化を提案します。

---

## 4. ドキュメント修正案

### 4.1 architecture.md の修正箇所

#### 修正箇所1: Main-Router.ps1 → Main.PS1

**現行 (line 53):**
```markdown
   - **Source**: `src/Main-Router.ps1`
```

**修正案:**
```markdown
   - **Source**: `src/Main.PS1`
```

#### 修正箇所2: Component Reference Table (line 152)

**現行:**
```markdown
| **Main Router** | `src/Main-Router.ps1` → `Focus-Game-Deck.exe` | Entry point routing and process delegation | ConfigEditor.exe, Invoke-FocusGameDeck.exe |
```

**修正案:**
```markdown
| **Main Router** | `src/Main.PS1` → `Focus-Game-Deck.exe` | Entry point routing and process delegation | ConfigEditor.exe, Invoke-FocusGameDeck.exe |
```

#### 修正箇所3: System Architecture Components (line 111)

**現行:**
```markdown
- **`src/Main-Router.ps1`** - Lightweight router compiled to Focus-Game-Deck.exe
```

**修正案:**
```markdown
- **`src/Main.PS1`** - Lightweight router compiled to Focus-Game-Deck.exe
```

#### 修正箇所4: Build Process Changes (lines 559-561)

**現行:**
```markdown
1. **New Entry Point**: Created `src/Main-Router.ps1` - lightweight router (replaces Main.PS1 as main executable)
2. **Updated Build Script**: Modified `Build-FocusGameDeck.ps1` to build three executables:
   - `Focus-Game-Deck.exe` from `Main-Router.ps1`
```

**修正案:**
```markdown
1. **Entry Point**: `src/Main.PS1` - lightweight router serving as main entry point
2. **Updated Build Script**: Modified `Build-FocusGameDeck.ps1` to build three executables:
   - `Focus-Game-Deck.exe` from `Main.PS1`
```

### 4.2 build-system.md の修正箇所

**現行 (line 401):**
```markdown
  - Sources from `src/Main-Router.ps1`
```

**修正案:**
```markdown
  - Sources from `src/Main.PS1`
```

---

## 5. 次のステップ (優先順位付きタスクリスト)

### 優先度: 高 (High Priority) ✅ 完了

1. **ドキュメント整合性の修正**
   - [x] `architecture.md` の Main-Router.ps1 参照を Main.PS1 に修正
   - [x] `build-system.md` の参照を修正
   - [x] `bundling-implementation.md` の参照を修正

### 優先度: 中 (Medium Priority) ✅ 完了

2. **パス解決ロジックの共通化**
   - [x] `scripts/PathResolver.ps1` を作成
   - [ ] 全エントリーポイントで共通モジュールを使用（任意：将来的なリファクタリング）

3. **Write-Hostガイドライン準拠**
   - [x] `VTubeStudioManager.ps1` の `-ForegroundColor` 削除
   - [x] `AppManager.ps1` のWrite-Host呼び出しを標準フォーマットに修正

### 優先度: 低 (Low Priority) - 将来のリリース向け

4. **Discord統合の機能フラグ化**
   - [ ] config.jsonにdiscordEnabledフラグを追加
   - [ ] 条件分岐をフラグベースに変更

5. **コード品質向上**
   - [ ] `$classAlreadyDefined` チェックの簡素化（オプション）

---

## 6. 結論

v3.0 Multi-Executable Bundle Architectureの実装は、セキュリティ強化とモジュール分離の観点から適切に設計されています。

**本リファクタリングで対応した課題:**
- ✅ ドキュメントとコードの命名不一致（Main-Router.ps1 vs Main.PS1）を修正
- ✅ パス解決ロジック用の共通モジュール `scripts/PathResolver.ps1` を作成
- ✅ Write-Hostガイドライン違反を修正（VTubeStudioManager.ps1, AppManager.ps1）

**将来の改善提案:**
- パス解決ロジックの重複は、共通モジュール化により解決可能（PathResolver.ps1を既に作成済み）
- Discord統合は将来の再有効化を考慮して維持することを推奨

---

*Report generated: 2026-01-30*
*Author: Focus Game Deck Architecture Analysis*
