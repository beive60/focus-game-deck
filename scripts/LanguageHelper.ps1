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
    
    Supported languages: ja (Japanese), en (English)

.NOTES
    Used by both GUI ConfigEditor and main Invoke-FocusGameDeck scripts
#>

# Set proper encoding for international characters
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
    Detects the appropriate language code based on configuration and system settings

.PARAMETER ConfigData
    The configuration object (PSCustomObject) containing language settings

.PARAMETER SupportedLanguages
    Array of supported language codes (default: @("en", "ja"))

.RETURNS
    String containing the detected language code ("en" or "ja")

.EXAMPLE
    $langCode = Get-DetectedLanguage -ConfigData $config
    # Returns "ja" if Japanese is configured/detected, "en" otherwise
#>
function Get-DetectedLanguage {
    param(
        [PSCustomObject]$ConfigData = $null,
        [string[]]$SupportedLanguages = @("en", "ja")
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
        if ($osLang -in $SupportedLanguages) {
            Write-Verbose "Language detected from OS: $osLang"
            return $osLang
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
    # Returns "ja" on Japanese Windows, "en" on English Windows, etc.
#>
function Get-OSLanguage {
    try {
        # Method 1: Get current UI culture (most reliable)
        $uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName.ToLower()
        if ($uiCulture) {
            Write-Verbose "OS language detected via CurrentUICulture: $uiCulture"
            return $uiCulture
        }
    } catch {
        Write-Verbose "CurrentUICulture detection failed: $($_.Exception.Message)"
    }
    
    try {
        # Method 2: Get current culture
        $culture = (Get-Culture).TwoLetterISOLanguageName.ToLower()
        if ($culture) {
            Write-Verbose "OS language detected via Get-Culture: $culture"
            return $culture
        }
    } catch {
        Write-Verbose "Get-Culture detection failed: $($_.Exception.Message)"
    }
    
    try {
        # Method 3: Registry-based detection (Windows-specific)
        $regLocale = Get-ItemProperty -Path "HKCU:\Control Panel\International" -Name "LocaleName" -ErrorAction SilentlyContinue
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
    # Sets Japanese culture for proper character display
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
    Language code to load ("en", "ja")

.RETURNS
    PSCustomObject containing localized messages

.EXAMPLE
    $messages = Get-LocalizedMessages -MessagesPath ".\messages.json" -LanguageCode "ja"
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
        if ($messagesData.PSObject.Properties.Name -contains $LanguageCode) {
            Write-Verbose "Loading messages for language: $LanguageCode"
            return $messagesData.$LanguageCode
        } elseif ($messagesData.PSObject.Properties.Name -contains "messages") {
            # Legacy format - assume Japanese
            Write-Verbose "Loading messages from legacy format"
            return $messagesData.messages
        } else {
            Write-Warning "No messages found for language: $LanguageCode"
            return [PSCustomObject]@{}
        }
        
    } catch {
        Write-Error "Failed to load messages: $($_.Exception.Message)"
        return [PSCustomObject]@{}
    }
}

# Export functions for module usage
# Export-ModuleMember -Function Get-DetectedLanguage, Get-OSLanguage, Set-CultureByLanguage, Get-LocalizedMessages