<#
.SYNOPSIS
    Pure validation rules module for Focus Game Deck

.DESCRIPTION
    This module contains pure validation logic with no dependencies on UI,
    logging, or other modules. All functions return boolean values or
    simple validation result objects.
    
    This is the single source of truth for all validation rules across
    CLI and GUI components.

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Last Updated: 2026-01-01
    
    Design Principles:
    - No dependencies on UI, logging, or other modules
    - Pure functions that return bool or simple result objects
    - Reusable from CLI, GUI, tests, and build scripts
    - Single source of truth for validation rules

.EXAMPLE
    # Test Game ID format
    $isValid = Test-GameIdFormat -GameId "my-game_123"
    if (-not $isValid) {
        Write-Host "Invalid Game ID format"
    }

.EXAMPLE
    # Test Steam AppID format
    $isValid = Test-SteamAppIdFormat -SteamAppId "1172470"
    if ($isValid) {
        Write-Host "Valid Steam AppID"
    }
#>

<#
.SYNOPSIS
    Tests if a Game ID has valid format.

.DESCRIPTION
    Game IDs must contain only alphanumeric characters, hyphens, and underscores.
    They cannot be empty or contain spaces or special characters.

.PARAMETER GameId
    The Game ID to validate.

.OUTPUTS
    System.Boolean
    True if the Game ID format is valid, False otherwise.

.EXAMPLE
    Test-GameIdFormat -GameId "apex-legends"
    Returns: $true

.EXAMPLE
    Test-GameIdFormat -GameId "apex legends"
    Returns: $false (contains space)
#>
function Test-GameIdFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$GameId
    )

    # Game ID cannot be empty or whitespace
    if ([string]::IsNullOrWhiteSpace($GameId)) {
        return $false
    }

    # Game ID must match pattern: alphanumeric, hyphen, underscore only
    if ($GameId -notmatch '^[A-Za-z0-9_-]+$') {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Tests if a Steam AppID has valid format.

.DESCRIPTION
    Steam AppIDs must be exactly 7 digits (numeric characters only).

.PARAMETER SteamAppId
    The Steam AppID to validate.

.OUTPUTS
    System.Boolean
    True if the Steam AppID format is valid, False otherwise.

.EXAMPLE
    Test-SteamAppIdFormat -SteamAppId "1172470"
    Returns: $true

.EXAMPLE
    Test-SteamAppIdFormat -SteamAppId "123456"
    Returns: $false (only 6 digits)
#>
function Test-SteamAppIdFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$SteamAppId
    )

    # Steam AppID cannot be empty
    if ([string]::IsNullOrWhiteSpace($SteamAppId)) {
        return $false
    }

    # Steam AppID must be exactly 7 digits
    if ($SteamAppId -notmatch '^[0-9]{7}$') {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Tests if an Epic Game ID has valid format.

.DESCRIPTION
    Epic Game IDs must start with 'apps/' or 'com.epicgames.launcher://apps/'.

.PARAMETER EpicGameId
    The Epic Game ID to validate.

.OUTPUTS
    System.Boolean
    True if the Epic Game ID format is valid, False otherwise.

.EXAMPLE
    Test-EpicGameIdFormat -EpicGameId "apps/fortnite"
    Returns: $true

.EXAMPLE
    Test-EpicGameIdFormat -EpicGameId "com.epicgames.launcher://apps/fortnite"
    Returns: $true

.EXAMPLE
    Test-EpicGameIdFormat -EpicGameId "fortnite"
    Returns: $false (missing prefix)
#>
function Test-EpicGameIdFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$EpicGameId
    )

    # Epic Game ID cannot be empty
    if ([string]::IsNullOrWhiteSpace($EpicGameId)) {
        return $false
    }

    # Epic Game ID must start with expected prefix
    if ($EpicGameId -notmatch '^(com\.epicgames\.launcher://)?apps/') {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Tests if a Riot Game ID has valid format.

.DESCRIPTION
    Riot Game IDs must be non-empty strings.
    Examples: "valorant", "bacon", "league_of_legends"

.PARAMETER RiotGameId
    The Riot Game ID to validate.

.OUTPUTS
    System.Boolean
    True if the Riot Game ID format is valid, False otherwise.

.EXAMPLE
    Test-RiotGameIdFormat -RiotGameId "valorant"
    Returns: $true

.EXAMPLE
    Test-RiotGameIdFormat -RiotGameId ""
    Returns: $false
#>
function Test-RiotGameIdFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$RiotGameId
    )

    # Riot Game ID cannot be empty or whitespace
    if ([string]::IsNullOrWhiteSpace($RiotGameId)) {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Tests if a configuration path exists and is valid.

.DESCRIPTION
    Validates that a path is not empty and that the file exists on disk.

.PARAMETER Path
    The file path to validate.

.OUTPUTS
    System.Boolean
    True if the path is not empty and the file exists, False otherwise.

.EXAMPLE
    Test-ConfigPathExists -Path "C:/Program Files/Steam/steam.exe"
    Returns: $true (if file exists)

.EXAMPLE
    Test-ConfigPathExists -Path ""
    Returns: $false (empty path)
#>
function Test-ConfigPathExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Path
    )

    # Path cannot be empty
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    # Path must exist and be a file (not a directory)
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Validates game configuration based on platform type.

.DESCRIPTION
    Performs comprehensive validation of game configuration including
    Game ID format and platform-specific identifier validation.
    
    Returns a hashtable with validation results and error details.

.PARAMETER GameId
    The unique identifier for the game.

.PARAMETER Platform
    The platform type: steam, epic, riot, standalone, or direct.

.PARAMETER SteamAppId
    Steam Application ID (required for steam platform).

.PARAMETER EpicGameId
    Epic Games Launcher Game ID (required for epic platform).

.PARAMETER RiotGameId
    Riot Client game identifier (required for riot platform).

.PARAMETER ExecutablePath
    Full path to the game executable (required for standalone/direct platforms).

.OUTPUTS
    System.Collections.Hashtable
    Returns hashtable with:
    - IsValid (bool): True if all validations pass
    - Errors (array): Array of error objects with Control and Key properties

.EXAMPLE
    $result = Test-GameConfiguration -GameId "valorant" -Platform "riot" -RiotGameId "valorant"
    if (-not $result.IsValid) {
        foreach ($error in $result.Errors) {
            Write-Host "Error on $($error.Control): $($error.Key)"
        }
    }
#>
function Test-GameConfiguration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$GameId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('steam', 'epic', 'riot', 'standalone', 'direct', '')]
        [string]$Platform = '',

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$SteamAppId,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$EpicGameId,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$RiotGameId,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ExecutablePath
    )

    $errors = @()

    # Validate Game ID format
    if (-not (Test-GameIdFormat -GameId $GameId)) {
        if ([string]::IsNullOrWhiteSpace($GameId)) {
            $errors += @{
                Control = 'GameIdTextBox'
                Key = 'gameIdRequired'
            }
        } else {
            $errors += @{
                Control = 'GameIdTextBox'
                Key = 'gameIdInvalidCharacters'
            }
        }
    }

    # Platform-specific validations
    switch ($Platform) {
        'steam' {
            if (-not (Test-SteamAppIdFormat -SteamAppId $SteamAppId)) {
                if ([string]::IsNullOrWhiteSpace($SteamAppId)) {
                    $errors += @{
                        Control = 'SteamAppIdTextBox'
                        Key = 'steamAppIdRequired'
                    }
                } else {
                    $errors += @{
                        Control = 'SteamAppIdTextBox'
                        Key = 'steamAppIdMust7Digits'
                    }
                }
            }
        }
        'epic' {
            if (-not (Test-EpicGameIdFormat -EpicGameId $EpicGameId)) {
                if ([string]::IsNullOrWhiteSpace($EpicGameId)) {
                    $errors += @{
                        Control = 'EpicGameIdTextBox'
                        Key = 'epicGameIdRequired'
                    }
                } else {
                    $errors += @{
                        Control = 'EpicGameIdTextBox'
                        Key = 'epicGameIdInvalidFormat'
                    }
                }
            }
        }
        'riot' {
            if (-not (Test-RiotGameIdFormat -RiotGameId $RiotGameId)) {
                $errors += @{
                    Control = 'RiotGameIdTextBox'
                    Key = 'riotGameIdRequired'
                }
            }
        }
        { $_ -in 'standalone', 'direct' } {
            if (-not (Test-ConfigPathExists -Path $ExecutablePath)) {
                if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
                    $errors += @{
                        Control = 'ExecutablePathTextBox'
                        Key = 'executablePathRequired'
                    }
                } else {
                    $errors += @{
                        Control = 'ExecutablePathTextBox'
                        Key = 'executablePathNotFound'
                    }
                }
            }
        }
    }

    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
    }
}

# Export functions for module use
Export-ModuleMember -Function @(
    'Test-GameIdFormat',
    'Test-SteamAppIdFormat',
    'Test-EpicGameIdFormat',
    'Test-RiotGameIdFormat',
    'Test-ConfigPathExists',
    'Test-GameConfiguration'
)
