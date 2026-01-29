<#
.SYNOPSIS
    Pester tests for Invoke-ConfigurationValidation module

.DESCRIPTION
    Unit tests for centralized configuration validation logic.
    Tests validation rules for Game ID, platform-specific identifiers,
    and executable paths across all supported platforms.

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Tags: Core, Validation
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

    # Import the BuildLogger
    . "$projectRoot/build-tools/utils/BuildLogger.ps1"

    # Import the validation module
    . "$projectRoot/scripts/Invoke-ConfigurationValidation.ps1"

    Write-BuildLog "[INFO] ConfigValidation Tests: Loaded validation module"
}

Describe "Invoke-ConfigurationValidation" -Tag "Unit", "Core", "Validation" {

    Context "Game ID Validation" {
        It "Should accept valid Game ID with alphanumeric characters" {
            $errors = Invoke-ConfigurationValidation -GameId "apex-legends-2024"
            $errors | Should -HaveCount 0
        }

        It "Should accept Game ID with underscores" {
            $errors = Invoke-ConfigurationValidation -GameId "league_of_legends"
            $errors | Should -HaveCount 0
        }

        It "Should accept Game ID with hyphens" {
            $errors = Invoke-ConfigurationValidation -GameId "counter-strike-2"
            $errors | Should -HaveCount 0
        }

        It "Should reject empty Game ID" {
            $errors = Invoke-ConfigurationValidation -GameId ""
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdRequired"
        }

        It "Should reject Game ID with spaces" {
            $errors = Invoke-ConfigurationValidation -GameId "apex legends"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdInvalidCharacters"
        }

        It "Should reject Game ID with special characters" {
            $errors = Invoke-ConfigurationValidation -GameId "apex@legends!"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdInvalidCharacters"
        }

        It "Should reject Game ID with Japanese characters" {
            $errors = Invoke-ConfigurationValidation -GameId "エーペックス"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdInvalidCharacters"
        }
    }

    Context "Steam Platform Validation" {
        It "Should accept valid 7-digit Steam AppID" {
            $errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "1172470"
            $errors | Should -HaveCount 0
        }

        It "Should reject empty Steam AppID" {
            $errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId ""
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "SteamAppIdTextBox"
            $errors[0].Key | Should -Be "steamAppIdRequired"
        }

        It "Should accept Steam AppID with less than 7 digits" {
            $errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "123456"
            $errors | Should -HaveCount 0
        }

        It "Should accept Steam AppID with more than 7 digits" {
            $errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "12345678"
            $errors | Should -HaveCount 0
        }

        It "Should reject Steam AppID with non-numeric characters" {
            $errors = Invoke-ConfigurationValidation -GameId "apex" -Platform "steam" -SteamAppId "117247a"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "SteamAppIdTextBox"
            $errors[0].Key | Should -Be "steamAppIdMust7Digits"
        }
    }

    Context "Epic Platform Validation" {
        It "Should accept valid Epic Game ID with 'apps/' prefix" {
            $errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "apps/fortnite"
            $errors | Should -HaveCount 0
        }

        It "Should accept valid Epic Game ID with full launcher URL" {
            $errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "com.epicgames.launcher://apps/fortnite"
            $errors | Should -HaveCount 0
        }

        It "Should reject empty Epic Game ID" {
            $errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId ""
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "EpicGameIdTextBox"
            $errors[0].Key | Should -Be "epicGameIdRequired"
        }

        It "Should reject Epic Game ID without proper prefix" {
            $errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "fortnite"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "EpicGameIdTextBox"
            $errors[0].Key | Should -Be "epicGameIdInvalidFormat"
        }

        It "Should reject Epic Game ID with invalid prefix" {
            $errors = Invoke-ConfigurationValidation -GameId "fortnite" -Platform "epic" -EpicGameId "game/fortnite"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "EpicGameIdTextBox"
            $errors[0].Key | Should -Be "epicGameIdInvalidFormat"
        }
    }

    Context "Riot Platform Validation" {
        It "Should accept valid Riot Game ID" {
            $errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId "valorant"
            $errors | Should -HaveCount 0
        }

        It "Should accept Riot Game ID 'bacon' (LoR)" {
            $errors = Invoke-ConfigurationValidation -GameId "lor" -Platform "riot" -RiotGameId "bacon"
            $errors | Should -HaveCount 0
        }

        It "Should accept Riot Game ID 'league_of_legends'" {
            $errors = Invoke-ConfigurationValidation -GameId "lol" -Platform "riot" -RiotGameId "league_of_legends"
            $errors | Should -HaveCount 0
        }

        It "Should reject empty Riot Game ID" {
            $errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId ""
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "RiotGameIdTextBox"
            $errors[0].Key | Should -Be "riotGameIdRequired"
        }

        It "Should reject whitespace-only Riot Game ID" {
            $errors = Invoke-ConfigurationValidation -GameId "valorant" -Platform "riot" -RiotGameId "   "
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "RiotGameIdTextBox"
            $errors[0].Key | Should -Be "riotGameIdRequired"
        }
    }

    Context "Standalone Platform Validation" {
        BeforeAll {
            # Create a temporary executable file for testing
            $script:testExePath = Join-Path -Path $TestDrive -ChildPath "test-game.exe"
            New-Item -Path $script:testExePath -ItemType File -Force | Out-Null
        }

        It "Should accept valid executable path for standalone platform" {
            $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "standalone" -ExecutablePath $script:testExePath
            $errors | Should -HaveCount 0
        }

        It "Should reject empty executable path for standalone platform" {
            $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "standalone" -ExecutablePath ""
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "ExecutablePathTextBox"
            $errors[0].Key | Should -Be "executablePathRequired"
        }

        It "Should reject non-existent executable path for standalone platform" {
            $errors = Invoke-ConfigurationValidation -GameId "test-game" -Platform "standalone" -ExecutablePath "C:/NonExistent/game.exe"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "ExecutablePathTextBox"
            $errors[0].Key | Should -Be "executablePathNotFound"
        }
    }

    Context "Direct Platform Validation" {
        BeforeAll {
            # Create a temporary executable file for testing
            $script:testExePath = Join-Path -Path $TestDrive -ChildPath "direct-game.exe"
            New-Item -Path $script:testExePath -ItemType File -Force | Out-Null
        }

        It "Should accept valid executable path for direct platform" {
            $errors = Invoke-ConfigurationValidation -GameId "direct-game" -Platform "direct" -ExecutablePath $script:testExePath
            $errors | Should -HaveCount 0
        }

        It "Should reject empty executable path for direct platform" {
            $errors = Invoke-ConfigurationValidation -GameId "direct-game" -Platform "direct" -ExecutablePath ""
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "ExecutablePathTextBox"
            $errors[0].Key | Should -Be "executablePathRequired"
        }

        It "Should reject non-existent executable path for direct platform" {
            $errors = Invoke-ConfigurationValidation -GameId "direct-game" -Platform "direct" -ExecutablePath "C:/NonExistent/game.exe"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "ExecutablePathTextBox"
            $errors[0].Key | Should -Be "executablePathNotFound"
        }
    }

    Context "Multiple Validation Errors" {
        It "Should return multiple errors when both Game ID and Steam AppID are invalid" {
            $errors = Invoke-ConfigurationValidation -GameId "" -Platform "steam" -SteamAppId "invalid"
            $errors | Should -HaveCount 2
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdRequired"
            $errors[1].Control | Should -Be "SteamAppIdTextBox"
            $errors[1].Key | Should -Be "steamAppIdMust7Digits"
        }

        It "Should return multiple errors for invalid Game ID and empty Epic Game ID" {
            $errors = Invoke-ConfigurationValidation -GameId "game with spaces" -Platform "epic" -EpicGameId ""
            $errors | Should -HaveCount 2
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdInvalidCharacters"
            $errors[1].Control | Should -Be "EpicGameIdTextBox"
            $errors[1].Key | Should -Be "epicGameIdRequired"
        }
    }

    Context "No Platform Specified" {
        It "Should only validate Game ID when no platform is specified" {
            $errors = Invoke-ConfigurationValidation -GameId "valid-game"
            $errors | Should -HaveCount 0
        }

        It "Should return error for invalid Game ID when no platform is specified" {
            $errors = Invoke-ConfigurationValidation -GameId "invalid game"
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdInvalidCharacters"
        }
    }

    Context "Edge Cases" {
        It "Should handle null Game ID parameter" {
            $errors = Invoke-ConfigurationValidation -GameId $null
            $errors | Should -HaveCount 1
            $errors[0].Control | Should -Be "GameIdTextBox"
            $errors[0].Key | Should -Be "gameIdRequired"
        }

        It "Should accept minimum valid Game ID (single character)" {
            $errors = Invoke-ConfigurationValidation -GameId "a"
            $errors | Should -HaveCount 0
        }

        It "Should accept very long valid Game ID" {
            $longId = "a" * 100
            $errors = Invoke-ConfigurationValidation -GameId $longId
            $errors | Should -HaveCount 0
        }

        It "Should handle Steam platform with empty string" {
            $errors = Invoke-ConfigurationValidation -GameId "game" -Platform "" -SteamAppId "1234567"
            $errors | Should -HaveCount 0
        }
    }

    Context "Return Value Structure" {
        It "Should return array type for valid input" {
            $errors = Invoke-ConfigurationValidation -GameId "test"
            $errors.GetType().BaseType.Name | Should -Be "Array"
            $errors.Count | Should -Be 0
        }

        It "Should return array type for error input" {
            $errors = Invoke-ConfigurationValidation -GameId ""
            $errors.GetType().BaseType.Name | Should -Be "Array"
            $errors.Count | Should -BeGreaterThan 0
        }

        It "Should return hashtable objects with Control and Key properties" {
            $errors = Invoke-ConfigurationValidation -GameId "" -Platform "steam" -SteamAppId ""
            $errors | Should -HaveCount 2
            foreach ($error in $errors) {
                $error.Keys | Should -Contain "Control"
                $error.Keys | Should -Contain "Key"
                $error.Control | Should -Not -BeNullOrEmpty
                $error.Key | Should -Not -BeNullOrEmpty
            }
        }
    }
}
