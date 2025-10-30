# Mapping Completeness Test

## 目的

`Test-MappingCompleteness.ps1`は、UIマッピングの完全性と一貫性を検証するテストスクリプトです。

## 背景

このテストは、以下の問題を防ぐために作成されました：

### 過去の問題事例

**問題**: ComboBoxItemのローカライゼーションが機能しない
**原因**: `ConfigEditor.ps1`の`$allMappings`ハッシュテーブルに`ComboBoxItem`マッピングが含まれていなかった
**影響**: すべてのComboBoxItem要素（ログ保持期間、ランチャータイプ、プラットフォームなど）がローカライズされず、プレースホルダー（`[LOG_RETENTION_7]`など）がそのまま表示された

このような問題を早期に検出し、再発を防ぐためにこのテストが必要です。

## テスト内容

### 1. マッピングファイルの読み込み
- `ConfigEditor.Mappings.ps1`が正常に読み込めることを確認

### 2. マッピング変数の存在確認
以下のすべてのマッピング変数が存在し、ハッシュテーブルであることを確認：
- `ButtonMappings`
- `LabelMappings`
- `TabMappings`
- `TextMappings`
- `CheckBoxMappings`
- `MenuItemMappings`
- `TooltipMappings`
- `ComboBoxItemMappings`
- `GameActionMessageKeys`

### 3. ConfigEditor.ps1の$allMappings完全性確認
`ConfigEditor.ps1`内の`$allMappings`ハッシュテーブルに、すべての必要なマッピングが含まれていることを確認：
- Button
- Label
- Tab
- Text
- CheckBox
- MenuItem
- Tooltip
- ComboBoxItem

**重要**: ここでマッピングが欠けていると、そのUI要素タイプ全体がローカライズされなくなります。

### 4. XAML要素の存在確認
マッピングで定義されたすべての要素が、実際に`MainWindow.xaml`に存在することを確認。

**検出できる問題**:
- タイプミスによる要素名の不一致
- XAMLから削除された要素への参照
- リファクタリング時の名前変更の反映漏れ

### 5. メッセージキーの存在確認
マッピングで参照されているすべてのメッセージキーが、`messages.json`の全言語（日本語、英語、中国語）に存在することを確認。

**検出できる問題**:
- 未定義のメッセージキーへの参照
- 特定言語での翻訳漏れ
- タイプミスによるキー名の不一致

### 6. 未マッピング要素の検出
`MainWindow.xaml`に`x:Name`属性を持つ要素のうち、どのマッピングにも含まれていない要素を検出（警告として報告）。

**除外される要素**:
- 動的に生成される要素（`GamesList`, `ManagedAppsList`など）
- ローカライゼーション不要な要素（TextBox、ComboBoxなど）
- ツールチップ用のTextBlock要素

## 使用方法

### 基本実行
```powershell
powershell -ExecutionPolicy Bypass -File .\test\Test-MappingCompleteness.ps1
```

### 詳細情報付き実行
```powershell
powershell -ExecutionPolicy Bypass -File .\test\Test-MappingCompleteness.ps1 -ShowDetails
```

## テスト結果の解釈

### 成功（緑色）
すべてのマッピングが正しく設定されています。

### 失敗（赤色）
重大な問題が検出されました。以下を確認してください：
1. `ConfigEditor.ps1`の`$allMappings`にすべてのマッピングタイプが含まれているか
2. マッピングで参照されている要素名がXAMLと一致しているか
3. すべてのメッセージキーが`messages.json`に定義されているか

### 警告（黄色）
潜在的な問題があります。レビューが推奨されます。

## CI/CDへの統合

このテストは、以下のタイミングで実行することを推奨：
- GUI関連ファイルの変更時
- `ConfigEditor.Mappings.ps1`の変更時
- `MainWindow.xaml`の変更時
- `messages.json`の変更時
- プルリクエスト作成時

## メンテナンス

### 新しいUI要素タイプの追加時
1. `ConfigEditor.Mappings.ps1`に新しいマッピング変数を追加
2. `Test-MappingCompleteness.ps1`の`$expectedMappings`配列に追加
3. `ConfigEditor.ps1`の`$allMappings`に追加
4. テストが成功することを確認

### 除外要素の追加
ローカライゼーション不要な新しい要素がある場合、`Test-MappingCompleteness.ps1`の`$excludedElements`配列に追加してください。

## 関連ファイル

- `ConfigEditor.Mappings.ps1` - マッピング定義
- `ConfigEditor.ps1` - メインスクリプト（`$allMappings`定義）
- `ConfigEditor.UI.ps1` - UI更新ロジック
- `MainWindow.xaml` - UI定義
- `messages.json` - ローカライゼーションメッセージ
- `Test-ComboBoxItemLocalization.ps1` - ComboBoxItem特化テスト

## 期待される出力

```
=== Mapping Completeness Test ===

[1/6] Loading mappings from ConfigEditor.Mappings.ps1...
  [PASS] Load ConfigEditor.Mappings.ps1

[2/6] Verifying mapping variables exist...
  [PASS] Mapping variable 'ButtonMappings' exists
  [PASS] Mapping variable 'LabelMappings' exists
  ...

[3/6] Verifying $allMappings completeness in ConfigEditor.ps1...
  [PASS] Button mapping in $allMappings
  [PASS] Label mapping in $allMappings
  ...

[4/6] Verifying mapped elements exist in XAML...
  [PASS] All mapped elements exist in XAML

[5/6] Verifying message keys exist in messages.json...
  [PASS] All message keys exist in messages.json

[6/6] Checking for potentially unmapped elements in XAML...
  [PASS] All XAML elements are mapped or excluded

===================
Test Summary
===================
Total Tests: 21
Passed: 21
Failed: 0
Warnings: 0

All critical tests passed!
```
