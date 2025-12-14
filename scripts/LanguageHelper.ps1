# Language Helper - Common language detection and localization functions
# Focus Game Deck Project
# Author: GitHub Copilot Assistant
# Version: 1.0.0
# Date: 2025-09-23

<#
.SYNOPSIS
    Common language detection and localization functions for Focus Game Deck

.DESCRIPTION
    This module provides unified language detection logic that follows the priority:
    1. config.json language setting (if exists and valid)
    2. OS display language (if supported)
    3. English fallback (default)

    The module supports multiple languages with extensible architecture for future i18n expansion.

.NOTES
    Used by both GUI ConfigEditor and main Invoke-FocusGameDeck scripts
#>

# Set proper encoding for international characters
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Dynamically set console encoding only if a valid console handle exists
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    Write-Verbose "Console encoding successfully set to UTF-8."
} catch [System.IO.IOException] {
    # This is expected for -noConsole executables (e.g., ConfigEditor.exe)
    # The error is "The handle is invalid."
    Write-Verbose "No console handle found. Skipping console encoding setup."
} catch {
    # Catch any other unexpected errors
    Write-Warning "An unexpected error occurred while setting console encoding: $_"
}

<#
.SYNOPSIS
    Detects the appropriate language code based on configuration and system settings

.PARAMETER ConfigData
    The configuration object (PSCustomObject) containing language settings

.PARAMETER SupportedLanguages
    Array of supported language codes (default includes common international languages)

.RETURNS
    String containing the detected language code (falls back to "en" if unsupported)

.EXAMPLE
    $langCode = Get-DetectedLanguage -ConfigData $config
    # Returns the appropriate language code based on config/OS detection, "en" as fallback
#>
function Get-DetectedLanguage {
    param(
        [PSCustomObject]$ConfigData = $null,
        [string[]]$SupportedLanguages = @("en", "ja", "zh-CN", "ru", "fr", "es")
    )

    $defaultLang = "en"  # English as fallback

    try {
        # Priority 1: Check explicit config.json language setting
        if ($ConfigData -and
            $ConfigData.PSObject.Properties.Name -contains "language" -and
            $ConfigData.language -and
            $ConfigData.language.Trim() -ne "") {

            $configLang = $ConfigData.language.Trim().ToLower()
            if ($configLang -in $SupportedLanguages) {
                Write-Verbose "Language detected from config: $configLang"
                return $configLang
            }
        }

        # Priority 2: Auto-detect OS language if config is empty/auto
        $osLang = Get-OSLanguage
        $matchedOSLang = $SupportedLanguages | Where-Object { $_.ToLower() -eq $osLang.ToLower() } | Select-Object -First 1
        if ($matchedOSLang) {
            Write-Verbose "Language detected from OS: $matchedOSLang"
            return $matchedOSLang
        }

        # Priority 3: English fallback
        Write-Verbose "Using default language: $defaultLang"
        return $defaultLang

    } catch {
        Write-Warning "Error in language detection: $($_.Exception.Message). Using default: $defaultLang"
        return $defaultLang
    }
}

<#
.SYNOPSIS
    Gets the OS display language using multiple detection methods

.RETURNS
    String containing the OS language code (e.g., "ja", "en")

.EXAMPLE
    $osLang = Get-OSLanguage
    # Returns the OS language code (e.g., "ja", "en", "zh-CN") based on system locale
#>
function Get-OSLanguage {
    try {
        # Method 1: Get current UI culture (most reliable)
        $uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture
        if ($uiCulture) {
            $cultureName = $uiCulture.Name.ToLower()
            Write-Verbose "OS culture detected via CurrentUICulture: $cultureName"

            # Handle Chinese variants
            if ($cultureName -eq "zh-CN" -or $cultureName -eq "zh-hans") {
                return "zh-CN"
            } elseif ($cultureName.StartsWith("zh-")) {
                # Default other Chinese variants to zh-CN for now
                return "zh-CN"
            } else {
                # Return two-letter ISO language name for other languages
                return $uiCulture.TwoLetterISOLanguageName.ToLower()
            }
        }
    } catch {
        Write-Verbose "CurrentUICulture detection failed: $($_.Exception.Message)"
    }

    try {
        # Method 2: Get current culture
        $culture = Get-Culture
        if ($culture) {
            $cultureName = $culture.Name.ToLower()
            Write-Verbose "OS culture detected via Get-Culture: $cultureName"

            # Handle Chinese variants
            if ($cultureName -eq "zh-CN" -or $cultureName -eq "zh-hans") {
                return "zh-CN"
            } elseif ($cultureName.StartsWith("zh-")) {
                # Default other Chinese variants to zh-CN for now
                return "zh-CN"
            } else {
                # Return two-letter ISO language name for other languages
                return $culture.TwoLetterISOLanguageName.ToLower()
            }
        }
    } catch {
        Write-Verbose "Get-Culture detection failed: $($_.Exception.Message)"
    }

    try {
        # Method 3: Registry-based detection (Windows-specific)
        $regLocale = Get-ItemProperty -Path "HKCU:/Control Panel/International" -Name "LocaleName" -ErrorAction SilentlyContinue
        if ($regLocale -and $regLocale.LocaleName) {
            $regLang = $regLocale.LocaleName.Split('-')[0].ToLower()
            Write-Verbose "OS language detected via registry: $regLang"
            return $regLang
        }
    } catch {
        Write-Verbose "Registry detection failed: $($_.Exception.Message)"
    }

    # All methods failed
    Write-Verbose "All OS language detection methods failed"
    return "en"  # Default fallback
}

<#
.SYNOPSIS
    Sets the appropriate culture based on detected language

.PARAMETER LanguageCode
    The language code to set ("en", "ja", etc.)

.EXAMPLE
    Set-CultureByLanguage -LanguageCode "ja"
    # Sets the appropriate culture for proper character display and formatting
#>
function Set-CultureByLanguage {
    param(
        [string]$LanguageCode
    )

    try {
        switch ($LanguageCode.ToLower()) {
            "ja" {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("ja-JP")
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("ja-JP")
                Write-Verbose "Culture set to Japanese (ja-JP)"
            }
            "zh-CN" {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("zh-CN")
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("zh-CN")
                Write-Verbose "Culture set to Chinese Simplified (zh-CN)"
            }
            "ru" {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("ru-RU")
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("ru-RU")
                Write-Verbose "Culture set to Russian (ru-RU)"
            }
            "fr" {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("fr-FR")
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("fr-FR")
                Write-Verbose "Culture set to French (fr-FR)"
            }
            "es" {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("es-ES")
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("es-ES")
                Write-Verbose "Culture set to Spanish (es-ES)"
            }
            "en" {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
                Write-Verbose "Culture set to English (en-US)"
            }
            default {
                # Keep current culture for unsupported languages
                Write-Verbose "Unsupported language code: $LanguageCode. Keeping current culture."
            }
        }
    } catch {
        Write-Warning "Failed to set culture for language '$LanguageCode': $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Loads localized messages from messages.json file

.PARAMETER MessagesPath
    Path to the messages.json file

.PARAMETER LanguageCode
    Language code to load (supported codes vary based on available localizations)

.RETURNS
    PSCustomObject containing localized messages

.EXAMPLE
    $messages = Get-LocalizedMessages -MessagesPath "./messages.json" -LanguageCode "ja"
#>
function Get-LocalizedMessages {
    param(
        [string]$MessagesPath,
        [string]$LanguageCode = "en"
    )

    try {
        if (-not (Test-Path $MessagesPath)) {
            Write-Warning "Messages file not found: $MessagesPath"
            return [PSCustomObject]@{}
        }

        $messagesData = Get-Content -Path $MessagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Check if the file has language-specific structure
        # Check for exact match first, then case-insensitive match for compatibility
        if ($messagesData.PSObject.Properties.Name -contains $LanguageCode) {
            Write-Verbose "Loading messages for language: $LanguageCode"
            return $messagesData.$LanguageCode
        } else {
            # Try case-insensitive match for backwards compatibility
            $matchingLanguage = $messagesData.PSObject.Properties.Name | Where-Object { $_.ToLower() -eq $LanguageCode.ToLower() } | Select-Object -First 1
            if ($matchingLanguage) {
                Write-Verbose "Loading messages for language (case-insensitive match): $matchingLanguage"
                return $messagesData.$matchingLanguage
            } elseif ($messagesData.PSObject.Properties.Name -contains "messages") {
                # Legacy format - assume Japanese
                Write-Verbose "Loading messages from legacy format"
                return $messagesData.messages
            } else {
                # Fallback to English if the requested language is not found
                if ($messagesData.PSObject.Properties.Name -contains "en") {
                    Write-Warning "No messages found for language: $LanguageCode. Falling back to English."
                    return $messagesData.en
                } else {
                    Write-Warning "No messages found for language: $LanguageCode and no English fallback available"
                    return [PSCustomObject]@{}
                }
            }
        }

    } catch {
        Write-Error "Failed to load messages: $($_.Exception.Message)"
        return [PSCustomObject]@{}
    }
}

<#
.SYNOPSIS
    Writes a localized message to the host console with optional prefix

.PARAMETER Messages
    The messages object (PSCustomObject) containing localized strings

.PARAMETER Key
    The message key to look up in the messages object

.PARAMETER Args
    Optional array of arguments to format into the message

.PARAMETER Default
    Default text to use if the key is not found in the messages object

.PARAMETER Level
    Optional log level prefix (e.g., "OK", "ERROR", "WARNING", "INFO")
    When specified, outputs "[LEVEL] Component: " prefix
    - "OK": Uses Write-Host
    - "ERROR": Uses Write-Error (stops script execution)
    - "WARNING": Uses Write-Warning
    - "INFO": Uses Write-Host
    - Other: Uses Write-Host

.PARAMETER Component
    Optional component name for the prefix (e.g., "AppManager", "OBSManager")
    Only used if Level is specified

.EXAMPLE
    Write-LocalizedHost -Messages $msg -Key "cli_loading_config" -Default "Loading configuration..."

.EXAMPLE
    Write-LocalizedHost -Messages $msg -Key "cli_game_not_found" -Args @($GameId) -Default "Game ID '{0}' not found"

.EXAMPLE
    Write-LocalizedHost -Messages $msg -Key "console_app_started" -Args @("discord") -Default "Application started: {0}" -Level "OK" -Component "AppManager"
    # Outputs: [OK] AppManager: Application started: discord
#>
function Write-LocalizedHost {
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Messages = $null,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $false)]
        [object[]]$Args = @(),

        [Parameter(Mandatory = $false)]
        [string]$Default = "",

        [Parameter(Mandatory = $false)]
        [string]$Level = "",

        [Parameter(Mandatory = $false)]
        [string]$Component = ""
    )

    $message = $Default
    if ($Messages -and $Messages.PSObject.Properties[$Key]) {
        $message = $Messages.$Key
    } elseif ([string]::IsNullOrEmpty($Default)) {
        $message = $Key
    }

    if ($Args.Count -gt 0) {
        try {
            $message = $message -f $Args
        } catch {
            Write-Warning "Format failed for key '$Key': $_"
        }
    }

    # Build the output with prefix if Level is specified
    if ($Level) {
        if ($Component) {
            $output = "[$Level] $Component`: $message"
        } else {
            $output = "[$Level] $message"
        }
    } else {
        $output = $message
    }

    # Output using appropriate cmdlet based on Level
    switch ($Level.ToUpper()) {
        "ERROR" {
            Write-Error $output
        }
        "WARNING" {
            Write-Warning $output
        }
        "OK" {
            Write-Host $output
        }
        "INFO" {
            Write-Host $output
        }
        default {
            if ($Level) {
                Write-Host $output
            } else {
                Write-Host $message
            }
        }
    }
}

# Export functions for module usage
# Export-ModuleMember -Function Get-DetectedLanguage, Get-OSLanguage, Set-CultureByLanguage, Get-LocalizedMessages, Write-LocalizedHost
