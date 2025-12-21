# Focus Game Deck - Localization Guide

## Overview

This guide explains how to add support for new languages to Focus Game Deck. The application uses a centralized JSON-based localization system that supports both the GUI configuration editor and the website.

## Localization Architecture

Focus Game Deck uses two separate message files:

1. **`localization/messages.json`** - Application and GUI messages
2. **`website/messages-website.json`** - Website-specific messages

All UI text is externalized to these JSON files, making it easy to add new languages without modifying code.

## Adding a New Language

### Step 1: Add Translations to Message Files

#### 1.1 Application Messages (`localization/messages.json`)

Add a new language section to the JSON file with all required keys. You can copy an existing language section (e.g., `"en"` or `"ja"`) and translate the values:

```json
{
    "en": {
        "windowTitle": "Focus Game Deck - Configuration Editor",
        "saveButton": "Save",
        ...
    },
    "ja": {
        "windowTitle": "Focus Game Deck - 設定エディタ",
        "saveButton": "保存",
        ...
    },
    "your-language-code": {
        "windowTitle": "Your Translation",
        "saveButton": "Your Translation",
        ...
    }
}
```

**Important**: Ensure all keys from the English section are present in your translation. Missing keys will fall back to displaying the key name.

#### 1.2 Website Messages (`website/messages-website.json`)

Add translations for website-specific content:

```json
{
    "en": {
        "site_title": "Focus Game Deck",
        "download_title": "Download",
        ...
    },
    "your-language-code": {
        "site_title": "Your Translation",
        "download_title": "Your Translation",
        ...
    }
}
```

### Step 2: Update Code Files

Add the new language code to the following files:

#### 2.1 Website JavaScript (`website/script.js`)

Add language code to three locations:

**Location 1: `detectLanguage()` method**

```javascript
detectLanguage() {
    const stored = localStorage.getItem('focus-game-deck-language');
    if (stored && ['ja', 'zh-CN', 'en', 'ru', 'fr', 'es', 'pt-BR', 'id-ID', 'your-language-code'].includes(stored)) {
        return stored;
    }

    const browserLang = navigator.language || navigator.userLanguage;
    if (browserLang.startsWith('ja')) return 'ja';
    if (browserLang.startsWith('zh')) return 'zh-CN';
    // ... other language checks
    if (browserLang.startsWith('your-prefix')) return 'your-language-code';
    return 'en';
}
```

**Location 2: `loadMessages()` method**

```javascript
async loadMessages() {
    try {
        const response = await fetch('./messages-website.json');
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        this.messages = await response.json();
    } catch (error) {
        console.error('Error loading translations:', error);
        this.messages = { ja: {}, 'zh-CN': {}, en: {}, 'your-language-code': {} };
    }
}
```

**Location 3: `changeLanguage()` method**

```javascript
changeLanguage(langCode) {
    if (['ja', 'zh-CN', 'en', 'ru', 'fr', 'es', 'your-language-code'].includes(langCode)) {
        this.currentLanguage = langCode;
        localStorage.setItem('focus-game-deck-language', langCode);
        this.translatePage();
    }
}
```

#### 2.2 Language Helper (`scripts/LanguageHelper.ps1`)

Add language code to three functions:

**Location 1: `Get-DetectedLanguage` function**

```powershell
function Get-DetectedLanguage {
    param(
        [PSCustomObject]$ConfigData = $null,
        [string[]]$SupportedLanguages = @("en", "ja", "zh-CN", "ru", "fr", "es", "pt-BR", "id-ID", "your-language-code")
    )
    # ... rest of function
}
```

**Location 2: `Get-OSLanguage` function - Two places**

Add detection logic in both `CurrentUICulture` and `Get-Culture` methods:

```powershell
# Handle language variants
if ($cultureName -eq "zh-cn" -or $cultureName -eq "zh-hans") {
    return "zh-CN"
} elseif ($cultureName.StartsWith("zh-")) {
    return "zh-CN"
} elseif ($cultureName -eq "your-culture-code" -or $cultureName.StartsWith("your-prefix-")) {
    # Your Language
    return "your-language-code"
} else {
    # Return two-letter ISO language name for other languages
    return $uiCulture.TwoLetterISOLanguageName.ToLower()
}
```

**Location 3: `Set-CultureByLanguage` function**

Add a new case to the switch statement:

```powershell
switch ($LanguageCode.ToLower()) {
    "ja" {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("ja-JP")
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("ja-JP")
        Write-Verbose "Culture set to Japanese (ja-JP)"
    }
    # ... other cases
    "your-language-code" {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("your-culture-code")
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("your-culture-code")
        Write-Verbose "Culture set to Your Language (your-culture-code)"
    }
    default {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
        Write-Verbose "Culture set to English (en-US) - default"
    }
}
```

#### 2.3 GUI Localization (`gui/ConfigEditor.Localization.ps1`)

Add language code to the `IsLanguageSupported` method:

```powershell
[bool]IsLanguageSupported([string]$Language) {
    $supportedLanguages = @("en", "ja", "zh-CN", "ru", "fr", "es", "pt-BR", "id-ID", "your-language-code")
    return $Language -in $supportedLanguages
}
```

#### 2.4 GUI UI Manager (`gui/ConfigEditor.UI.ps1`)

Add language to the LanguageCombo initialization in the `CreateLoadGlobalSettingsCallback` method:

```powershell
# Add language options as ComboBoxItems
# Each language is displayed in its native language
$languages = @(
    @{ Code = "en"; Name = "English" }
    @{ Code = "ja"; Name = "日本語" }
    @{ Code = "zh-CN"; Name = "中文（简体）" }
    @{ Code = "ru"; Name = "Русский" }
    @{ Code = "fr"; Name = "Français" }
    @{ Code = "es"; Name = "Español" }
    @{ Code = "pt-BR"; Name = "Português (Brasil)" }
    @{ Code = "id-ID"; Name = "Bahasa Indonesia" }
    @{ Code = "your-language-code"; Name = "Your Native Language Name" }
)
```

### Step 3: Update Website HTML Files

Add the new language option to both website HTML files:

#### 3.1 Main Website (`website/index.html`)

Add to the language selector dropdown:

```html
<div class="language-selector">
    <select id="language-select">
        <option value="en">🇺🇸 English</option>
        <option value="ja">🇯🇵 日本語</option>
        <option value="zh-CN">🇨🇳 中文</option>
        <option value="ru">🇷🇺 Русский</option>
        <option value="fr">🇫🇷 Français</option>
        <option value="es">🇪🇸 Español</option>
        <option value="pt-BR">🇧🇷 Português (BR)</option>
        <option value="id-ID">🇮🇩 Bahasa Indonesia</option>
        <option value="your-language-code">🇫🇱 Your Language Name</option>
    </select>
</div>
```

#### 3.2 Manual Page (`website/gui-manual.html`)

Add the same language option to the manual page's language selector.

## Language Code Format

### Standard Language Codes

Use standard ISO 639-1 two-letter codes for most languages:

- `en` - English
- `ja` - Japanese
- `ru` - Russian
- `fr` - French
- `es` - Spanish

### Regional Variants

For regional variants, use the format `language-REGION`:

- `zh-CN` - Chinese (Simplified)
- `pt-BR` - Portuguese (Brazil)
- `id-ID` - Indonesian (Indonesia)

### Culture Codes in PowerShell

For PowerShell `CultureInfo`, use the appropriate Windows culture code:

- `en-US` - English (United States)
- `ja-JP` - Japanese (Japan)
- `zh-CN` - Chinese (Simplified, China)
- `pt-BR` - Portuguese (Brazil)
- `id-ID` - Indonesian (Indonesia)

Find valid culture codes using PowerShell:

```powershell
[System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures) |
    Select-Object Name, DisplayName |
    Sort-Object Name
```

## Testing Your Translation

### 1. Test GUI Application

1. Open `config/config.json`
2. Set `"language": "your-language-code"`
3. Run the GUI: `gui/ConfigEditor.ps1`
4. Verify all UI elements display your translations

### 2. Test Website

1. Open `website/index.html` in a browser
2. Select your language from the dropdown
3. Verify all text updates to your translations
4. Test the manual page (`website/gui-manual.html`)

### 3. Test Auto-Detection

1. Set your system language to match your new language
2. Remove the `"language"` setting from `config.json` or set it to `""`
3. Run the application
4. It should automatically detect and use your language

## Validation Checklist

Before submitting your translation:

- [ ] All message keys from English version are present
- [ ] All 8 code files have been updated with the language code
- [ ] Both HTML files have the language option added
- [ ] GUI loads and displays correctly in the new language
- [ ] Website displays correctly in the new language
- [ ] Language auto-detection works for your language
- [ ] Native language name is used in the language selector
- [ ] Appropriate flag emoji is used in website dropdowns

## Files Summary

When adding a new language, you must update these **10 files**:

### Message Files (2)

1. `localization/messages.json` - Application messages
2. `website/messages-website.json` - Website messages

### PowerShell Files (3)

3. `scripts/LanguageHelper.ps1` - Language detection and culture settings
2. `gui/ConfigEditor.Localization.ps1` - GUI localization system
3. `gui/ConfigEditor.UI.ps1` - Language selector UI

### JavaScript Files (1)

6. `website/script.js` - Website internationalization

### HTML Files (2)

7. `website/index.html` - Main website page
2. `website/gui-manual.html` - Manual page

## Common Issues

### Issue: Language Not Detected

**Symptom**: Application falls back to English despite setting language in config

**Solution**: Verify the language code is added to `IsLanguageSupported()` in `ConfigEditor.Localization.ps1`

### Issue: Missing Translations

**Symptom**: Some UI elements show key names instead of translated text

**Solution**: Ensure all message keys from English version exist in your translation

### Issue: Website Language Selector Not Working

**Symptom**: Selecting the language doesn't change the website text

**Solution**: Check that the language code is added to all three methods in `script.js`

### Issue: Culture Not Found Error

**Symptom**: PowerShell error when setting culture

**Solution**: Verify you're using a valid Windows culture code in `Set-CultureByLanguage()`

## Best Practices

### 1. Translation Quality

- Use native speakers for translations when possible
- Maintain consistent terminology across all messages
- Keep UI text concise to fit in buttons and labels
- Test with actual users of that language

### 2. Technical Considerations

- Use proper encoding (UTF-8) for all text files
- Test with special characters and diacritics
- Verify text doesn't overflow UI elements
- Consider text direction (LTR vs RTL) for future expansion

### 3. Maintenance

- Document any culture-specific formatting requirements
- Keep translations synchronized when adding new features
- Use version control to track translation changes
- Consider adding translation dates/versions to message files

## Reference: Supported Languages (as of v2.0.0)

| Language | Code | Culture | Native Name |
|----------|------|---------|-------------|
| English | en | en-US | English |
| Japanese | ja | ja-JP | 日本語 |
| Chinese (Simplified) | zh-CN | zh-CN | 中文（简体） |
| Russian | ru | ru-RU | Русский |
| French | fr | fr-FR | Français |
| Spanish | es | es-ES | Español |
| Portuguese (Brazil) | pt-BR | pt-BR | Português (Brasil) |
| Indonesian | id-ID | id-ID | Bahasa Indonesia |

## Contributing Translations

We welcome community translations! To contribute:

1. Fork the repository
2. Add your translation following this guide
3. Test thoroughly using the validation checklist
4. Submit a pull request with:
   - All 10 required file changes
   - A brief description of your translation
   - Note if you are a native speaker

For questions or assistance, please open an issue on GitHub.
