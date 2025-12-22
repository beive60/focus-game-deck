# Focus Game Deck - Localization Guide

## Overview

This guide explains how to add support for new languages to Focus Game Deck. The application uses a JSON-based localization system with **individual language files** for optimal performance and maintainability.

## Localization Architecture

### File Structure (v3.1+)

Focus Game Deck uses a **split-file architecture** where each language has its own JSON file:

```
localization/
├── manifest.json      # Language metadata and supported languages list
├── en.json           # English messages (~31KB)
├── ja.json           # Japanese messages (~31KB)
├── zh-CN.json        # Chinese (Simplified)
├── ru.json           # Russian
├── fr.json           # French
├── es.json           # Spanish
├── pt-BR.json        # Portuguese (Brazil)
└── id-ID.json        # Indonesian

website/
└── messages-website.json  # Website-specific messages (all languages)
```

### Performance Benefits

- **88.5% reduction** in startup load time (275KB → ~31KB per language)
- Only the active language is loaded at runtime
- Faster language switching
- Improved maintainability

### Backward Compatibility

The system maintains backward compatibility with the legacy `messages.json` format. If individual files are not found, it falls back to loading from the monolithic file.

## Adding a New Language

### Step 1: Create Individual Language File

Create a new JSON file in the `localization/` directory named `your-language-code.json` (e.g., `de.json` for German).

Copy an existing language file (e.g., `en.json`) as a template:

```json
{
    "windowTitle": "Your Translation",
    "saveButton": "Your Translation",
    "addButton": "Your Translation",
    ...
}
```

**Important**: The file must contain **all keys** from the English version. Missing keys will cause the application to fall back to displaying the key name.

**File Format Requirements**:

- Encoding: UTF-8 without BOM
- Indentation: 4 spaces
- Line endings: LF (Unix style)

### Step 2: Update Manifest File

Add your language to `localization/manifest.json`:

```json
{
    "version": "1.0.0",
    "supportedLanguages": [
        { "code": "en", "name": "English", "nativeName": "English" },
        { "code": "ja", "name": "Japanese", "nativeName": "日本語" },
        ...
        { "code": "your-code", "name": "Your Language", "nativeName": "Native Name" }
    ],
    "defaultLanguage": "en",
    "description": "Focus Game Deck localization manifest",
    "lastUpdated": "2025-12-22"
}
```

### Step 3: Update Website Messages

Add translations for website-specific content in `website/messages-website.json`:

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

### Step 4: Update Code Files

Add the new language code to the following files:

#### 4.1 Language Helper (`scripts/LanguageHelper.ps1`)

The `Get-LocalizedMessages` function automatically loads individual language files. You need to add your language code to the supported languages list:

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

**Location 2: `Get-OSLanguage` function**

Add detection logic for your language:

```powershell
# Handle language variants
if ($cultureName -eq "zh-cn" -or $cultureName -eq "zh-hans") {
    return "zh-CN"
} elseif ($cultureName.StartsWith("zh-")) {
    return "zh-CN"
} elseif ($cultureName -eq "your-culture-code" -or $cultureName.StartsWith("your-prefix-")) {
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

#### 4.2 GUI Localization (`gui/ConfigEditor.Localization.ps1`)

The `LoadMessages()` method automatically loads from individual files. Add your language code to the supported languages check:

```powershell
[bool]IsLanguageSupported([string]$Language) {
    $supportedLanguages = @("en", "ja", "zh-CN", "ru", "fr", "es", "pt-BR", "id-ID", "your-language-code")
    return $Language -in $supportedLanguages
}
```

#### 4.3 GUI UI Manager (`gui/ConfigEditor.UI.ps1`)

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

#### 4.4 Website JavaScript (`website/script.js`)

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

### Step 5: Update Website HTML Files

    @{ Code = "fr"; Name = "Français" }
    @{ Code = "es"; Name = "Español" }
    @{ Code = "pt-BR"; Name = "Português (Brasil)" }
    @{ Code = "id-ID"; Name = "Bahasa Indonesia" }
    @{ Code = "your-language-code"; Name = "Your Native Language Name" }
)

```

### Step 5: Update Website HTML Files

Add the new language option to both website HTML files:

#### 5.1 Main Website (`website/index.html`)

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

#### 5.2 Manual Page (`website/gui-manual.html`)

Add the same language option to the manual page's language selector.

## Build Process

### Automatic Resource Copying

The build system automatically copies all language files to the release directory. The `build-tools/Copy-Resources.ps1` script:

1. Copies all `*.json` files from `localization/` to `release/localization/`
2. Excludes backup files (`*.backup`)
3. Excludes diagnostic files (`localization-diagnostic-*.json`)
4. Includes the `manifest.json` file

No manual intervention is required when adding new language files.

### Build Verification

After building, verify your language file is included:

```powershell
# Check release directory
Get-ChildItem release/localization/*.json

# Expected output includes your-language-code.json
```

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

### 1. Test Individual Language Loading

Verify the language file loads correctly:

```powershell
# Load and verify your language file
$messages = Get-Content "localization/your-language-code.json" -Raw | ConvertFrom-Json
Write-Host "Total keys: $($messages.PSObject.Properties.Count)"
```

### 2. Test GUI Application

1. Open `config/config.json`
2. Set `"language": "your-language-code"`
3. Run the GUI: `src/Main.ps1`
4. Verify all UI elements display your translations

### 3. Test Website

1. Open `website/index.html` in a browser
2. Select your language from the dropdown
3. Verify all text updates to your translations
4. Test the manual page (`website/gui-manual.html`)

### 4. Test Auto-Detection

1. Set your system language to match your new language
2. Remove the `"language"` setting from `config.json` or set it to `""`
3. Run the application
4. It should automatically detect and use your language

### 5. Run Automated Tests

The project includes comprehensive localization tests:

```powershell
# Run all Pester tests
.\test\runners\Invoke-PesterTests.ps1

# Run only localization tests
Invoke-Pester -Path "test/pester/Localization.Tests.ps1" -Output Detailed
```

The localization tests verify:

- Directory structure (manifest.json and individual language files)
- Manifest file validity (version, supported languages list)
- Individual language files existence (all 8 languages)
- Key consistency across languages
- Performance metrics (88.5% reduction verified)
- Backward compatibility with legacy messages.json format

## Validation Checklist

Before submitting your translation:

- [ ] Individual language file created (`your-language-code.json`)
- [ ] All message keys from English version are present
- [ ] Manifest file updated with new language metadata
- [ ] All 7 code files have been updated with the language code
- [ ] Both website HTML files have the language option added
- [ ] Website messages file updated (`messages-website.json`)
- [ ] GUI loads and displays correctly in the new language
- [ ] Website displays correctly in the new language
- [ ] Language auto-detection works for your language
- [ ] Native language name is used in the language selector
- [ ] Appropriate flag emoji is used in website dropdowns
- [ ] Automated tests pass (`Localization.Tests.ps1`)
- [ ] Build process copies the new language file to release directory

## Files Summary

When adding a new language, you must update these **9 files**:

### Message Files (3)

1. `localization/your-language-code.json` - **NEW**: Individual language file
2. `localization/manifest.json` - Add language metadata
3. `website/messages-website.json` - Website messages

### PowerShell Files (3)

1. `scripts/LanguageHelper.ps1` - Language detection and culture settings
2. `gui/ConfigEditor.Localization.ps1` - GUI localization system
3. `gui/ConfigEditor.UI.ps1` - Language selector UI

### JavaScript Files (1)

1. `website/script.js` - Website internationalization

### HTML Files (2)

1. `website/index.html` - Main website page
2. `website/gui-manual.html` - Manual page

## Utilities

### Split Messages Tool

If migrating from legacy format or need to split a combined file:

```powershell
# Split messages.json into individual language files
.\scripts\Split-MessagesJson.ps1 -MessagesPath "localization/messages.json"
```

This creates:

- Individual language files (en.json, ja.json, etc.)
- manifest.json with metadata
- Backup of original file (messages.json.backup)

### Key Consistency Validator

Verify all languages have the same keys:

```powershell
# Run localization tests
Invoke-Pester -Path "test/pester/Localization.Tests.ps1" -Output Detailed
```

## Common Issues

### Issue: Language File Not Found

**Symptom**: Application falls back to English despite individual file existing

**Solution**:

1. Verify file naming matches language code exactly (`en.json`, not `EN.json`)
2. Check file is in `localization/` directory
3. Ensure file encoding is UTF-8 without BOM

### Issue: Language Not Detected

**Symptom**: Application falls back to English despite setting language in config

**Solution**:

1. Verify the language code is added to `IsLanguageSupported()` in `ConfigEditor.Localization.ps1`
2. Check language code in manifest.json
3. Verify case sensitivity (use lowercase for language codes)

### Issue: Missing Translations

**Symptom**: Some UI elements show key names instead of translated text

**Solution**:

1. Run key consistency validator to find missing keys
2. Compare with en.json to ensure all keys present
3. Check JSON syntax is valid (no trailing commas, proper quotes)

### Issue: Website Language Selector Not Working

**Symptom**: Selecting the language doesn't change the website text

**Solution**: Check that the language code is added to all three methods in `script.js`

### Issue: Build Doesn't Include New Language

**Symptom**: Language file missing from release directory

**Solution**:

1. Verify file has `.json` extension
2. Check file is not in `.gitignore`
3. Run `Copy-Resources.ps1` manually to test
4. Rebuild with `Release-Manager.ps1`

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
- Update `lastUpdated` field in manifest.json when modifying translations
- Individual language files make it easier to track changes per language

## Performance Metrics

### Startup Performance Improvement (v3.1+)

The split-file architecture provides significant performance benefits:

| Metric | Legacy (messages.json) | New (individual files) | Improvement |
|--------|------------------------|------------------------|-------------|
| File size loaded | 274.96 KB | ~31 KB average | 88.5% reduction |
| Parse time | All languages | Single language | Proportional speedup |
| Memory usage | All 8 languages | 1 language | 87.5% reduction |

### File Size by Language

| Language | File Size | Keys |
|----------|-----------|------|
| English (en.json) | 36.24 KB | ~335 keys |
| Japanese (ja.json) | 33.57 KB | ~335 keys |
| Chinese (zh-CN.json) | 34.15 KB | ~335 keys |
| Russian (ru.json) | 35.82 KB | ~335 keys |
| French (fr.json) | 34.91 KB | ~335 keys |
| Spanish (es.json) | 34.67 KB | ~335 keys |
| Portuguese (pt-BR.json) | 34.98 KB | ~335 keys |
| Indonesian (id-ID.json) | 34.52 KB | ~335 keys |

## Migration from Legacy Format

If you have an existing `messages.json` file:

1. **Backup your current file**:

   ```powershell
   Copy-Item localization/messages.json localization/messages.json.backup
   ```

2. **Run the split tool**:

   ```powershell
   .\scripts\Split-MessagesJson.ps1 -MessagesPath "localization/messages.json"
   ```

3. **Verify the split**:

   ```powershell
   # Check all language files were created
   Get-ChildItem localization/*.json

   # Run tests to verify integrity
   Invoke-Pester -Path "test/pester/Localization.Tests.ps1"
   ```

4. **Test the application**:

   ```powershell
   # Run GUI to verify all languages load correctly
   .\src\Main.ps1
   ```

5. **Optional: Remove legacy file**:

   ```powershell
   # After confirming everything works
   Remove-Item localization/messages.json
   ```

The system maintains backward compatibility, so you can keep the legacy file as a fallback.

## Reference: Supported Languages (as of v3.1)

| Language | Code | Culture | Native Name | File Size |
|----------|------|---------|-------------|-----------|
| English | en | en-US | English | 36.24 KB |
| Japanese | ja | ja-JP | 日本語 | 33.57 KB |
| Chinese (Simplified) | zh-CN | zh-CN | 中文（简体） | 34.15 KB |
| Russian | ru | ru-RU | Русский | 35.82 KB |
| French | fr | fr-FR | Français | 34.91 KB |
| Spanish | es | es-ES | Español | 34.67 KB |
| Portuguese (Brazil) | pt-BR | pt-BR | Português (Brasil) | 34.98 KB |
| Indonesian | id-ID | id-ID | Bahasa Indonesia | 34.52 KB |

## Contributing Translations

We welcome community translations! To contribute:

1. Fork the repository
2. Create a new branch for your translation
3. Add your translation following this guide
4. Test thoroughly using the validation checklist
5. Submit a pull request with:
   - New individual language file (`your-language-code.json`)
   - Updated manifest.json
   - Updated website messages
   - All 9 required file changes
   - A brief description of your translation
   - Note if you are a native speaker

For questions or assistance, please open an issue on GitHub.

## Technical Implementation Details

### Load Mechanism

The `Get-LocalizedMessages` function in `scripts/LanguageHelper.ps1`:

1. Checks if `MessagesPath` is a directory or file
2. **Directory** (new format): Loads `{LanguageCode}.json`
3. **File** (legacy format): Loads `messages.json` and extracts language section
4. Falls back to English if language file not found
5. Returns PSCustomObject with localized messages

### ps2exe Compatibility

The GUI localization system (`ConfigEditor.Localization.ps1`) is designed for ps2exe compatibility:

- Detects execution context (script vs compiled)
- Uses `$MyInvocation.MyCommand.Path` instead of `$PSScriptRoot`
- Handles both development and production environments
- Gracefully falls back to legacy format if needed

### Test Coverage

The `test/pester/Localization.Tests.ps1` wrapper calls:

- `test/scripts/localization/Test-LocalizationFileStructure.ps1`
  - 34 comprehensive assertions
  - Validates directory structure
  - Checks manifest validity
  - Verifies all language files
  - Tests key consistency
  - Measures performance improvement
  - Confirms backward compatibility

---

**Last Updated**: 2025-12-22 (v3.1 - Split-file architecture)
