<#
.SYNOPSIS
    Centralized configuration validation logic for Focus Game Deck.

.DESCRIPTION
    Provides validation functions for game and application configurations.
    This module is independent and has no dependencies on UI or other modules,
    making it reusable from CLI tools, build scripts, and GUI applications.

    Returns structured error objects with Control and Key properties that can be
    used for displaying localized error messages.

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Last Updated: 2025-12-19
    
    Design Principles:
    - No dependencies on UI or other modules
    - Returns structured error objects for easy integration
    - Single source of truth for all validation rules
    - Platform-specific validation rules

.EXAMPLE
    $errors = Invoke-ConfigurationValidation -GameId "my-game" -Platform "steam" -SteamAppId "1234567"
    if ($errors.Count -gt 0) {
        foreach ($err in $errors) {
            Write-Host "Error on $($err.Control): $($err.Key)"
        }
    }

.EXAMPLE
    # Validate only Game ID
    $errors = Invoke-ConfigurationValidation -GameId "my_game-123"
    if ($errors.Count -eq 0) {
        Write-Host "Game ID is valid"
    }
#>

function Invoke-ConfigurationValidation {
    <#
    .SYNOPSIS
        Validates game configuration parameters.

    .DESCRIPTION
        Main validation entry point for game configurations.
        Validates Game ID, platform-specific identifiers, and executable paths.
        
        Validation Rules:
        - Game ID: Required, alphanumeric with hyphens and underscores only
        - Steam AppID: Required for steam platform, must be 7-digit numeric
        - Epic Game ID: Required for epic platform, must start with 'apps/' or 'com.epicgames.launcher://apps/'
        - Riot Game ID: Required for riot platform
        - Executable Path: Required for standalone/direct platforms, must exist

    .PARAMETER GameId
        The unique identifier for the game. Must be alphanumeric with hyphens and underscores only.

    .PARAMETER Platform
        The platform type: steam, epic, riot, standalone, or direct.

    .PARAMETER SteamAppId
        Steam Application ID. Required when Platform is 'steam'. Must be 7-digit numeric.

    .PARAMETER EpicGameId
        Epic Games Launcher Game ID. Required when Platform is 'epic'.
        Must start with 'apps/' or 'com.epicgames.launcher://apps/'.

    .PARAMETER RiotGameId
        Riot Client game identifier. Required when Platform is 'riot'.

    .PARAMETER ExecutablePath
        Full path to the game executable. Required when Platform is 'standalone' or 'direct'.
        Must point to an existing file.

    .OUTPUTS
        System.Collections.ArrayList
        Array of hashtables with Control and Key properties:
        - Control: The UI control name that has the error
        - Key: The localization key for the error message

    .EXAMPLE
        $errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId "valorant"
        # Validates a Riot game configuration

    .EXAMPLE
        $errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "1172470"
        # Validates a Steam game configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GameId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('steam', 'epic', 'riot', 'standalone', 'direct', '')]
        [string]$Platform = '',

        [Parameter(Mandatory = $false)]
        [string]$SteamAppId,

        [Parameter(Mandatory = $false)]
        [string]$EpicGameId,

        [Parameter(Mandatory = $false)]
        [string]$RiotGameId,

        [Parameter(Mandatory = $false)]
        [string]$ExecutablePath
    )

    $errors = @()

    # Validate Game ID if provided
    if ($PSBoundParameters.ContainsKey('GameId')) {
        # Game ID: required + alphanumeric/hyphen/underscore
        if ([string]::IsNullOrWhiteSpace($GameId)) {
            $errors += @{
                Control = 'GameIdTextBox'
                Key = 'gameIdRequired'
            }
        } elseif ($GameId -notmatch '^[A-Za-z0-9_-]+$') {
            $errors += @{
                Control = 'GameIdTextBox'
                Key = 'gameIdInvalidCharacters'
            }
        }
    }

    # Platform-specific validations
    switch ($Platform) {
        'steam' {
            # Steam AppID: required + 7-digit numeric
            if ([string]::IsNullOrWhiteSpace($SteamAppId)) {
                $errors += @{
                    Control = 'SteamAppIdTextBox'
                    Key = 'steamAppIdRequired'
                }
            } elseif ($SteamAppId -notmatch '^[0-9]{7}$') {
                $errors += @{
                    Control = 'SteamAppIdTextBox'
                    Key = 'steamAppIdMust7Digits'
                }
            }
        }
        'epic' {
            # Epic Game ID: must start with expected prefix
            if ([string]::IsNullOrWhiteSpace($EpicGameId)) {
                $errors += @{
                    Control = 'EpicGameIdTextBox'
                    Key = 'epicGameIdRequired'
                }
            } elseif ($EpicGameId -notmatch '^(com\.epicgames\.launcher://)?apps/') {
                $errors += @{
                    Control = 'EpicGameIdTextBox'
                    Key = 'epicGameIdInvalidFormat'
                }
            }
        }
        'riot' {
            # Riot Game ID: basic validation (non-empty)
            # Note: Riot game IDs are simple identifiers like "valorant", "bacon", "league_of_legends"
            if ([string]::IsNullOrWhiteSpace($RiotGameId)) {
                $errors += @{
                    Control = 'RiotGameIdTextBox'
                    Key = 'riotGameIdRequired'
                }
            }
        }
        { $_ -in 'standalone', 'direct' } {
            # Executable Path: validate file existence
            if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
                $errors += @{
                    Control = 'ExecutablePathTextBox'
                    Key = 'executablePathRequired'
                }
            } elseif (-not (Test-Path -Path $ExecutablePath -PathType Leaf)) {
                $errors += @{
                    Control = 'ExecutablePathTextBox'
                    Key = 'executablePathNotFound'
                }
            }
        }
    }

    return $errors
}
