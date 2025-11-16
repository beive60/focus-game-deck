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
    [string]$ProjectRoot = ""

    <#
    .SYNOPSIS
        Initializes the localization system with automatic language detection.
    .NOTES
        Sets the MessagesPath, detects language, and loads messages.
    #>
    ConfigEditorLocalization([string]$ProjectRoot) {
        # Store provided project root and build messages path from it.
        $this.ProjectRoot = $ProjectRoot
        $this.MessagesPath = Join-Path -Path $this.ProjectRoot -ChildPath "localization/messages.json"
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
            if ($script:ConfigData -and $script:ConfigData.PSObject.Properties["language"]) {
                $configLang = $script:ConfigData.language
                if ($this.IsLanguageSupported($configLang)) {
                    $this.CurrentLanguage = $configLang
                    return
                }
            }
            $systemLang = (Get-Culture).TwoLetterISOLanguageName
            if ($this.IsLanguageSupported($systemLang)) {
                $this.CurrentLanguage = $systemLang
                return
            }
            $this.CurrentLanguage = "en"
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
        $supportedLanguages = @("en", "ja", "ko", "zh")
        return $Language -in $supportedLanguages
    }

    <#
    .SYNOPSIS
        Loads messages from JSON file for the current language.
    .NOTES
        Falls back to English if the language is not found.
    #>
    [void]LoadMessages() {
        try {
            if (-not (Test-Path $this.MessagesPath)) {
                throw "[ERROR] Messages file not found: $($this.MessagesPath)"
            }
            $messagesContent = Get-Content $this.MessagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($messagesContent.PSObject.Properties[$this.CurrentLanguage]) {
                $this.Messages = $messagesContent.($this.CurrentLanguage)
            } else {
                Write-Verbose "[INFO] Language '$($this.CurrentLanguage)' not found, falling back to English"
                $this.Messages = $messagesContent.en
                $this.CurrentLanguage = "en"
            }
            Write-Verbose "[INFO] Loaded messages for language: $($this.CurrentLanguage)"
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
            if ($this.Messages -and $this.Messages.PSObject.Properties[$Key]) {
                $message = $this.Messages.$Key.ToString()
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
