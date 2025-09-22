# Focus Game Deck - Architecture & Design Philosophy

## 概要

Focus Game Deck は、ゲーミング環境の自動化とOBS配信管理を行うPowerShellベースのツールです。このドキュメントでは、プロジェクトの設計思想、技術選択の理由、および実装アーキテクチャについて説明します。

## 設計思想

### 1. 軽量性とシンプルさ
- **PowerShell + WPF**: 追加のランタイムや重いフレームワークを避け、Windows標準機能を活用
- **最小限の依存関係**: .NET Framework標準機能のみを使用
- **単一実行ファイル**: ps2exeによる実行ファイル化で配布を簡素化

### 2. 保守性と拡張性
- **設定駆動設計**: すべての動作を`config.json`で制御
- **モジュラー構造**: GUI、コア機能、設定管理を分離
- **国際化対応**: JSON外部リソースによる多言語サポート

### 3. ユーザビリティ
- **直感的なGUI**: 3タブ構造による機能分類（ゲーム設定、管理アプリ設定、グローバル設定）
- **バッチファイル起動**: 技術知識を必要としない簡単起動
- **エラーハンドリング**: 適切な日本語エラーメッセージ表示

## 技術アーキテクチャ

### システム構成

```
Focus Game Deck
├── Core Engine (PowerShell)
│   ├── src/Invoke-FocusGameDeck.ps1     # メインエンジン
│   ├── scripts/Create-Launchers.ps1     # ランチャー生成
│   └── launch_*.bat                     # ゲーム別起動スクリプト
│
├── Configuration Management
│   ├── config/config.json               # メイン設定ファイル
│   ├── config/config.json.sample        # サンプル設定
│   └── config/messages.json             # 国際化リソース（GUI用）
│
├── GUI Module (PowerShell + WPF)
│   ├── gui/MainWindow.xaml              # UIレイアウト定義
│   ├── gui/ConfigEditor.ps1             # GUI制御ロジック
│   ├── gui/messages.json                # GUI用メッセージリソース
│   └── gui/Build-ConfigEditor.ps1       # ビルドスクリプト
│
└── Documentation & Testing
    ├── docs/                            # 設計・仕様書
    ├── test/                            # テストスクリプト
    └── README.md                        # プロジェクト概要
```

### 設計判断の記録

#### 1. GUI技術選択: PowerShell + WPF

**検討した選択肢:**
- Windows Forms
- Electron/Web技術
- .NET WinForms/WPF (C#)
- PowerShell + WPF ✅

**選択理由:**
- **軽量性**: 追加ランタイム不要、Windows標準機能
- **統一性**: メインエンジンと同じPowerShellで実装
- **配布容易性**: ps2exeによる単一実行ファイル化
- **開発効率**: 既存PowerShellスキルを活用

#### 2. 国際化手法: JSON外部リソース

**検討した選択肢:**
- Unicodeコードポイント直接指定
- PowerShell内埋め込み文字列
- JSON外部リソースファイル ✅

**選択理由:**
- **文字化け解決**: PowerShell MessageBox の日本語文字化け問題を回避
- **保守性**: 文字列とコードの分離
- **拡張性**: 将来的な多言語対応への対応
- **標準的手法**: 一般的な国際化パターン

**技術的詳細:**
- Unicodeエスケープシーケンス（`\u30XX`形式）使用
- UTF-8エンコーディング強制設定
- 実行時JSON読み込みによる動的メッセージ取得

#### 3. 設定管理: JSON設定ファイル

**選択理由:**
- **可読性**: 人間が読みやすい形式
- **PowerShell互換性**: ConvertFrom-Json/ConvertTo-Json標準対応
- **階層構造**: 複雑な設定を構造化して管理
- **バージョン管理**: Gitでの差分確認が容易

## 実装ガイドライン

### コーディング規約

1. **エンコーディング**: すべてのファイルはUTF-8で保存
2. **エラーハンドリング**: Try-Catch-Finallyパターンを徹底
3. **関数命名**: PowerShell動詞-名詞パターン（Verb-Noun）
4. **コメント**: 日本語コメント許可（UTF-8保証）

### GUI開発ガイドライン

1. **XAML構造**: 
   - x:Class属性は使用しない（PowerShell互換性のため）
   - Name属性による要素参照
   - TabControl による機能分類

2. **メッセージ表示**:
   ```powershell
   # 推奨: JSON外部リソース使用
   Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"
   
   # 非推奨: 直接文字列指定
   [System.Windows.MessageBox]::Show("設定が保存されました")
   ```

3. **設定管理**:
   ```powershell
   # 設定読み込み
   $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
   
   # 設定保存
   $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
   ```

## パフォーマンス考慮事項

### 起動時間最適化
- JSON読み込みの遅延実行
- WPFアセンブリの事前読み込み
- XAML解析の最適化

### メモリ使用量
- PowerShell ISE vs 通常PowerShell の差異を考慮
- 大きなオブジェクトの適切な解放
- イベントハンドラーのメモリリーク対策

## セキュリティ考慮事項

### 実行ポリシー
- `-ExecutionPolicy Bypass` による制限回避
- スクリプト署名の将来的な検討

### 設定ファイル保護
- パスワード平文保存の制限
- 設定ファイルのアクセス権限制御

## 今後の拡張予定

### 短期（v1.1）
- [ ] 英語メッセージリソースの追加
- [ ] 設定バリデーション強化
- [ ] エラーログ機能

### 中期（v1.2）
- [ ] プラグインアーキテクチャ
- [ ] テーマ機能
- [ ] 設定インポート/エクスポート

### 長期（v2.0）
- [ ] クラウド設定同期
- [ ] Web UI オプション
- [ ] マルチプラットフォーム対応

## 貢献ガイドライン

この設計思想を維持するために、以下の点を重視してください：

1. **軽量性の維持**: 新しい依存関係の追加は慎重に検討
2. **PowerShell First**: 他の言語への移行よりもPowerShellでの解決を優先
3. **設定駆動**: ハードコードではなく設定ファイルでの制御
4. **国際化対応**: 新しいメッセージは必ずJSON外部リソース化

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|----------|
| 1.0.0 | 2025-09-23 | 初期アーキテクチャ設計、GUI実装完了 |
| 1.0.1 | 2025-09-23 | JSON外部リソース国際化対応完了 |

---

*このドキュメントは、Focus Game Deck プロジェクトの設計思想と技術選択を記録し、将来の開発者が一貫した方針で開発を継続できるようにすることを目的としています。*