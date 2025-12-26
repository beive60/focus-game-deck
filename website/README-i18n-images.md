# 多言語対応画像の使用方法

## 概要

言語に応じて異なる画像を表示する機能が実装されています。`data-i18n-img`属性を使用することで、画像のsrcを自動的に切り替えることができます。

## 使用方法

### 基本的な使い方

HTMLで画像要素に`data-i18n-img`属性を追加します：

```html
<img src="assets/launcher_en.png"
     alt="Screenshot"
     data-i18n-img="assets/launcher_{lang}.png"
     data-i18n-img-alt="hero_image_alt">
```

- `data-i18n-img`: 画像パスのパターンを指定（`{lang}`が言語コードに置き換えられます）
- `data-i18n-img-alt`: alt属性の翻訳キー（messages-website.jsonから取得）

### 言語コードのマッピング

以下の言語コードがファイル名にマッピングされます：

#### 標準画像（launcher, games, app, settingなど）

| 言語 | コード | ファイル名 |
|------|--------|------------|
| 日本語 | ja | `jp` |
| 中国語（簡体字） | zh-CN | `zh-cn` |
| ポルトガル語（ブラジル） | pt-BR | `pt-br` |
| インドネシア語 | id-ID | `id` |
| 英語 | en | `en` |
| ロシア語 | ru | `ru` |
| フランス語 | fr | `fr` |
| スペイン語 | es | `es` |

#### コンソール画像（特別な命名規則）

コンソール画像は異なる命名規則を使用します：

| 言語 | コード | ファイル名 |
|------|--------|------------|
| 日本語 | ja | `ja` |
| 中国語（簡体字） | zh-CN | `zn-CN` |
| ポルトガル語（ブラジル） | pt-BR | `pt-BR` |
| インドネシア語 | id-ID | `id-ID` |
| 英語 | en | `en` |
| ロシア語 | ru | `ru` |
| フランス語 | fr | `fr` |
| スペイン語 | es | `es` |

### ファイル命名規則

画像ファイルは以下の命名規則に従ってください：

#### 標準画像

```
assets/launcher_en.png
assets/launcher_jp.png
assets/launcher_zh-cn.png
assets/launcher_ru.png
assets/launcher_fr.png
assets/launcher_es.png
assets/launcher_pt-br.png
assets/launcher_id.png
```

#### コンソール画像（特別な命名規則）

```
assets/console_en.png
assets/console_ja.png
assets/console_zn-CN.png
assets/console_ru.png
assets/console_fr.png
assets/console_es.png
assets/console_pt-BR.png
assets/console_id-ID.png
```

## 拡張性

この機能は拡張可能です。gui-manual.htmlなど、他のページでも同様に使用できます：

```html
<!-- スクリーンショットプレースホルダーの代わりに -->
<img src="assets/game_settings_en.png"
     alt="Game Settings Screenshot"
     data-i18n-img="assets/game_settings_{lang}.png"
     data-i18n-img-alt="game_settings_screenshot">
```

## 実装詳細

`script.js`の`I18n`クラスに`updateLanguageImages()`メソッドが実装されています。このメソッドは：

1. `data-i18n-img`属性を持つすべての画像を検索
2. 現在の言語コードをファイル名形式にマッピング
3. `{lang}`プレースホルダーを実際の言語コードに置き換え
4. 画像のsrcを更新
5. `data-i18n-img-alt`が指定されていれば、alt属性も更新

言語が変更されると、`translatePage()`メソッドから自動的に呼び出されます。
