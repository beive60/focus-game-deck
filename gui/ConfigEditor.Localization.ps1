<#
.SYNOPSIS
    ConfigEditor Localization Module
.DESCRIPTION
    Handles internationalization and message management.
.AUTHOR
    GitHub Copilot Assistant
.VERSION
    1.0.0
#>

class ConfigEditorLocalization {
    [string]$CurrentLanguage = "en"
    [PSCustomObject]$Messages = $null
    [string]$MessagesPath = ""
    [string]$appRoot = ""

    <#
    .SYNOPSIS
        Initializes the localization system with automatic language detection.
    .NOTES
        Sets the MessagesPath, detects language, and loads messages.
    #>
    ConfigEditorLocalization([string]$appRoot) {
        # Store provided project root and build localization directory path from it.
        $this.appRoot = $appRoot
        $this.MessagesPath = Join-Path -Path $this.appRoot -ChildPath "localization"
        $this.DetectLanguage()
        $this.LoadMessages()
    }

    <#
    .SYNOPSIS
        Detects the appropriate language based on config and system settings.
    .NOTES
        Priority: Config file > System UI language > English fallback.
    #>
    [void]DetectLanguage() {
        try {
            Write-Verbose "[DEBUG] ConfigEditorLocalization: DetectLanguage() called"
            Write-Verbose "[DEBUG] ConfigEditorLocalization: script:ConfigData exists = $($null -ne $script:ConfigData)"

            # Priority 1: Config file language setting
            if ($script:ConfigData -and $script:ConfigData.PSObject.Properties["language"]) {
                $configLang = $script:ConfigData.language
                Write-Verbose "[DEBUG] ConfigEditorLocalization: Config language = '$configLang'"

                if ($this.IsLanguageSupported($configLang)) {
                    $this.CurrentLanguage = $configLang
                    Write-Verbose "[INFO] ConfigEditorLocalization: Using config language: $($this.CurrentLanguage)"
                    return
                } else {
                    Write-Verbose "[WARNING] ConfigEditorLocalization: Config language '$configLang' not supported"
                }
            } else {
                Write-Verbose "[DEBUG] ConfigEditorLocalization: No language in config, trying system language"
            }

            # Priority 2: System UI language
            $systemLang = (Get-Culture).TwoLetterISOLanguageName
            Write-Verbose "[DEBUG] ConfigEditorLocalization: System language = '$systemLang'"

            if ($this.IsLanguageSupported($systemLang)) {
                $this.CurrentLanguage = $systemLang
                Write-Verbose "[INFO] ConfigEditorLocalization: Using system language: $($this.CurrentLanguage)"
                return
            }

            # Priority 3: English fallback
            $this.CurrentLanguage = "en"
            Write-Verbose "[INFO] ConfigEditorLocalization: Using fallback language: en"
        } catch {
            Write-Warning "Language detection failed, using English: $($_.Exception.Message)"
            $this.CurrentLanguage = "en"
        }
    }

    <#
    .SYNOPSIS
        Checks if a language is supported.
    .PARAMETER Language
        Language code to check.
    .OUTPUTS
        [bool] True if supported.
    #>
    [bool]IsLanguageSupported([string]$Language) {
        $supportedLanguages = @("en", "ja", "zh-CN", "ru", "fr", "es", "pt-BR", "id-ID")
        return $Language -in $supportedLanguages
    }

    <#
    .SYNOPSIS
        Loads messages from individual language files or legacy messages.json.
    .NOTES
        New format: Loads from individual files (e.g., localization/ja.json)
        Legacy format: Loads from monolithic messages.json (backward compatibility)
        Falls back to English if the requested language is not found.
    #>
    [void]LoadMessages() {
        try {
            Write-Verbose "[DEBUG] LoadMessages: MessagesPath = $($this.MessagesPath)"
            Write-Verbose "[DEBUG] LoadMessages: CurrentLanguage = $($this.CurrentLanguage)"

            # MessagesPath should be the localization directory
            $localizationDir = $this.MessagesPath

            # Try loading individual language file first (new format)
            $languageFile = Join-Path -Path $localizationDir -ChildPath "$($this.CurrentLanguage).json"
            Write-Verbose "[DEBUG] LoadMessages: Checking for language file: $languageFile"

            if (Test-Path $languageFile) {
                # New format: Individual language file exists
                Write-Verbose "[INFO] Loading messages from individual file: $languageFile"
                $this.Messages = Get-Content -Path $languageFile -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-Verbose "[INFO] Loaded messages for language: $($this.CurrentLanguage)"
            } else {
                # Try legacy format as fallback
                $legacyFile = Join-Path -Path $localizationDir -ChildPath "messages.json"
                Write-Verbose "[DEBUG] LoadMessages: Individual file not found, trying legacy: $legacyFile"

                if (Test-Path $legacyFile) {
                    # Legacy format: Load from monolithic messages.json (backward compatibility)
                    Write-Verbose "[INFO] Loading messages from legacy single file: $legacyFile"
                    $messagesContent = Get-Content $legacyFile -Raw -Encoding UTF8 | ConvertFrom-Json
                    $langProperty = $messagesContent.PSObject.Properties | Where-Object { $_.Name -eq $this.CurrentLanguage }

                    if ($langProperty) {
                        $this.Messages = $langProperty.Value
                        Write-Verbose "[INFO] Loaded messages for language: $($this.CurrentLanguage)"
                    } else {
                        # Fallback to English in legacy format
                        Write-Verbose "[INFO] Language '$($this.CurrentLanguage)' not found, falling back to English"
                        $enFile = Join-Path -Path $localizationDir -ChildPath "en.json"

                        if (Test-Path $enFile) {
                            # Try individual English file
                            $this.Messages = Get-Content -Path $enFile -Raw -Encoding UTF8 | ConvertFrom-Json
                        } else {
                            # Use English from legacy file
                            $enProperty = $messagesContent.PSObject.Properties | Where-Object { $_.Name -eq 'en' }
                            $this.Messages = $enProperty.Value
                        }
                        $this.CurrentLanguage = "en"
                        Write-Verbose "[INFO] Loaded English fallback messages"
                    }
                } else {
                    throw "[ERROR] No localization files found. Checked: $languageFile and $legacyFile"
                }
            }

        } catch {
            Write-Error "[ERROR] Failed to load messages: $($_.Exception.Message)"
            $this.Messages = [PSCustomObject]@{}
        }
    }

    <#
    .SYNOPSIS
        Gets a localized message by key with optional arguments.
    .PARAMETER Key
        Message key.
    .PARAMETER Arguments
        Arguments for string formatting.
    .OUTPUTS
        [string] Localized message.
    #>
    [string]GetMessage([string]$Key, [array]$Arguments = @()) {
        try {
            if ($null -eq $this.Messages) {
                Write-Warning "[WARNING] Messages not loaded"
                return $Key
            }
            $messageProperty = $this.Messages.PSObject.Properties | Where-Object { $_.Name -eq $Key }
            if ($messageProperty) {
                $message = $messageProperty.Value.ToString()
                for ($i = 0; $i -lt $Arguments.Length; $i++) {
                    $message = $message -replace "\{$i\}", $Arguments[$i]
                }
                return $message
            } else {
                Write-Warning "[WARNING] Message key '$Key' not found in current language messages"
                return $Key
            }
        } catch {
            Write-Warning "[WARNING] Error getting message for key '$Key': $($_.Exception.Message)"
            return $Key
        }
    }

    <#
    .SYNOPSIS
        Changes the current language and reloads messages.
    .PARAMETER NewLanguage
        New language code.
    .OUTPUTS
        [bool] True if language changed successfully.
    #>
    [bool]ChangeLanguage([string]$NewLanguage) {
        try {
            if ($this.IsLanguageSupported($NewLanguage)) {
                $this.CurrentLanguage = $NewLanguage
                $this.LoadMessages()
                return $true
            } else {
                Write-Warning "Unsupported language: $NewLanguage"
                return $false
            }
        } catch {
            Write-Error "Failed to change language: $($_.Exception.Message)"
            return $false
        }
    }
}
