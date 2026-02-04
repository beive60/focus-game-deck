<#
.SYNOPSIS
    Pester tests for ValidationRules module

.DESCRIPTION
    Unit tests for pure validation rules module.
    Tests validation functions for Game ID, platform-specific identifiers,
    and executable paths across all supported platforms.

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Tags: Core, Validation, ValidationRules
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

    # Import the BuildLogger
    . "$projectRoot/build-tools/utils/BuildLogger.ps1"

    # Import the validation rules module
    . "$projectRoot/src/modules/ValidationRules.ps1"

    Write-BuildLog "[INFO] ValidationRules Tests: Loaded validation module"
}

Describe "Test-GameIdFormat" -Tag "Unit", "Core", "ValidationRules" {

    Context "Valid Game IDs" {
        It "Should accept alphanumeric characters" {
            Test-GameIdFormat -GameId "apex2024" | Should -BeTrue
        }

        It "Should accept underscores" {
            Test-GameIdFormat -GameId "league_of_legends" | Should -BeTrue
        }

        It "Should accept hyphens" {
            Test-GameIdFormat -GameId "counter-strike-2" | Should -BeTrue
        }

        It "Should accept mixed format" {
            Test-GameIdFormat -GameId "apex-legends_2024" | Should -BeTrue
        }

        It "Should accept single character" {
            Test-GameIdFormat -GameId "a" | Should -BeTrue
        }

        It "Should accept very long Game ID" {
            $longId = "a" * 100
            Test-GameIdFormat -GameId $longId | Should -BeTrue
        }
    }

    Context "Invalid Game IDs" {
        It "Should reject empty string" {
            Test-GameIdFormat -GameId "" | Should -BeFalse
        }

        It "Should reject whitespace" {
            Test-GameIdFormat -GameId "   " | Should -BeFalse
        }

        It "Should reject spaces" {
            Test-GameIdFormat -GameId "apex legends" | Should -BeFalse
        }

        It "Should reject special characters" {
            Test-GameIdFormat -GameId "apex@legends!" | Should -BeFalse
        }

        It "Should reject Japanese characters" {
            # Use Unicode escape to avoid encoding issues in CI
            $japaneseText = [System.Text.Encoding]::UTF8.GetString([byte[]]@(227, 130, 168, 227, 131, 188, 227, 131, 154, 227, 131, 131, 227, 130, 175, 227, 130, 185))
            Test-GameIdFormat -GameId $japaneseText | Should -BeFalse
        }

        It "Should reject symbols" {
            Test-GameIdFormat -GameId "game#1" | Should -BeFalse
        }
    }
}

Describe "Test-SteamAppIdFormat" -Tag "Unit", "Core", "ValidationRules" {

    Context "Valid Steam AppIDs" {
        It "Should accept valid 7-digit Steam AppID" {
            Test-SteamAppIdFormat -SteamAppId "1172470" | Should -BeTrue
        }

        It "Should accept another valid 7-digit Steam AppID" {
            Test-SteamAppIdFormat -SteamAppId "0000000" | Should -BeTrue
        }
        It "Should accept 6-digit number" {
            Test-SteamAppIdFormat -SteamAppId "123456" | Should -BeTrue
        }
    }

    Context "Invalid Steam AppIDs" {
        It "Should reject empty string" {
            Test-SteamAppIdFormat -SteamAppId "" | Should -BeFalse
        }

        It "Should reject mixed alphanumeric" {
            Test-SteamAppIdFormat -SteamAppId "abc1234" | Should -BeFalse
        }
    }
}

Describe "Test-EpicGameIdFormat" -Tag "Unit", "Core", "ValidationRules" {

    Context "Valid Epic Game IDs" {
        It "Should accept 'apps/' prefix" {
            Test-EpicGameIdFormat -EpicGameId "apps/fortnite" | Should -BeTrue
        }

        It "Should accept full launcher URL" {
            Test-EpicGameIdFormat -EpicGameId "com.epicgames.launcher://apps/fortnite" | Should -BeTrue
        }

        It "Should accept 'apps/' with complex game ID" {
            Test-EpicGameIdFormat -EpicGameId "apps/my-game-123" | Should -BeTrue
        }
    }

    Context "Invalid Epic Game IDs" {
        It "Should reject empty string" {
            Test-EpicGameIdFormat -EpicGameId "" | Should -BeFalse
        }

        It "Should reject without proper prefix" {
            Test-EpicGameIdFormat -EpicGameId "fortnite" | Should -BeFalse
        }

        It "Should reject invalid prefix" {
            Test-EpicGameIdFormat -EpicGameId "game/fortnite" | Should -BeFalse
        }

        It "Should reject partial URL" {
            Test-EpicGameIdFormat -EpicGameId "epicgames.launcher://fortnite" | Should -BeFalse
        }
    }
}

Describe "Test-RiotGameIdFormat" -Tag "Unit", "Core", "ValidationRules" {

    Context "Valid Riot Game IDs" {
        It "Should accept 'valorant'" {
            Test-RiotGameIdFormat -RiotGameId "valorant" | Should -BeTrue
        }

        It "Should accept 'bacon'" {
            Test-RiotGameIdFormat -RiotGameId "bacon" | Should -BeTrue
        }

        It "Should accept 'league_of_legends'" {
            Test-RiotGameIdFormat -RiotGameId "league_of_legends" | Should -BeTrue
        }

        It "Should accept any non-empty string" {
            Test-RiotGameIdFormat -RiotGameId "any-game-id-123" | Should -BeTrue
        }
    }

    Context "Invalid Riot Game IDs" {
        It "Should reject empty string" {
            Test-RiotGameIdFormat -RiotGameId "" | Should -BeFalse
        }

        It "Should reject whitespace" {
            Test-RiotGameIdFormat -RiotGameId "   " | Should -BeFalse
        }
    }
}

Describe "Test-ConfigPathExists" -Tag "Unit", "Core", "ValidationRules" {

    BeforeAll {
        # Create a temporary file for testing
        $script:testFilePath = Join-Path -Path $TestDrive -ChildPath "test-file.exe"
        New-Item -Path $script:testFilePath -ItemType File -Force | Out-Null

        # Create a temporary directory
        $script:testDirPath = Join-Path -Path $TestDrive -ChildPath "test-directory"
        New-Item -Path $script:testDirPath -ItemType Directory -Force | Out-Null
    }

    Context "Valid Paths" {
        It "Should accept existing file path" {
            Test-ConfigPathExists -Path $script:testFilePath | Should -BeTrue
        }
    }

    Context "Invalid Paths" {
        It "Should reject empty path" {
            Test-ConfigPathExists -Path "" | Should -BeFalse
        }

        It "Should reject whitespace path" {
            Test-ConfigPathExists -Path "   " | Should -BeFalse
        }

        It "Should reject non-existent file" {
            Test-ConfigPathExists -Path "C:/NonExistent/file.exe" | Should -BeFalse
        }

        It "Should reject directory path (not a file)" {
            Test-ConfigPathExists -Path $script:testDirPath | Should -BeFalse
        }
    }
}

Describe "Test-GameConfiguration" -Tag "Unit", "Core", "ValidationRules" {

    BeforeAll {
        # Create a temporary executable file for testing
        $script:testExePath = Join-Path -Path $TestDrive -ChildPath "test-game.exe"
        New-Item -Path $script:testExePath -ItemType File -Force | Out-Null
    }

    Context "Steam Platform" {
        It "Should return valid for correct Steam configuration" {
            $result = Test-GameConfiguration -GameId "apex" -Platform "steam" -SteamAppId "1172470"
            $result.IsValid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It "Should return error for empty Steam AppID" {
            $result = Test-GameConfiguration -GameId "apex" -Platform "steam" -SteamAppId ""
            $result.IsValid | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterThan 0
            $result.Errors[0].Key | Should -Be "steamAppIdRequired"
        }

        It "Should return error for invalid Steam AppID format" {
            $result = Test-GameConfiguration -GameId "apex" -Platform "steam" -SteamAppId "123456abc"
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "steamAppIdMustBeNumeric"
        }
    }

    Context "Epic Platform" {
        It "Should return valid for correct Epic configuration" {
            $result = Test-GameConfiguration -GameId "fortnite" -Platform "epic" -EpicGameId "apps/fortnite"
            $result.IsValid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It "Should return error for empty Epic Game ID" {
            $result = Test-GameConfiguration -GameId "fortnite" -Platform "epic" -EpicGameId ""
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "epicGameIdRequired"
        }

        It "Should return error for invalid Epic Game ID format" {
            $result = Test-GameConfiguration -GameId "fortnite" -Platform "epic" -EpicGameId "fortnite"
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "epicGameIdInvalidFormat"
        }
    }

    Context "Riot Platform" {
        It "Should return valid for correct Riot configuration" {
            $result = Test-GameConfiguration -GameId "valorant" -Platform "riot" -RiotGameId "valorant"
            $result.IsValid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It "Should return error for empty Riot Game ID" {
            $result = Test-GameConfiguration -GameId "valorant" -Platform "riot" -RiotGameId ""
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "riotGameIdRequired"
        }
    }

    Context "Standalone Platform" {
        It "Should return valid for correct standalone configuration" {
            $result = Test-GameConfiguration -GameId "test-game" -Platform "standalone" -ExecutablePath $script:testExePath
            $result.IsValid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It "Should return error for empty executable path" {
            $result = Test-GameConfiguration -GameId "test-game" -Platform "standalone" -ExecutablePath ""
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "executablePathRequired"
        }

        It "Should return error for non-existent executable path" {
            $result = Test-GameConfiguration -GameId "test-game" -Platform "standalone" -ExecutablePath "C:/NonExistent/game.exe"
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "executablePathNotFound"
        }
    }

    Context "Direct Platform" {
        It "Should return valid for correct direct configuration" {
            $result = Test-GameConfiguration -GameId "direct-game" -Platform "direct" -ExecutablePath $script:testExePath
            $result.IsValid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It "Should return error for empty executable path" {
            $result = Test-GameConfiguration -GameId "direct-game" -Platform "direct" -ExecutablePath ""
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "executablePathRequired"
        }
    }

    Context "Multiple Validation Errors" {
        It "Should return multiple errors for multiple invalid fields" {
            $result = Test-GameConfiguration -GameId "" -Platform "steam" -SteamAppId "invalid"
            $result.IsValid | Should -BeFalse
            $result.Errors.Count | Should -Be 2
        }
    }

    Context "Game ID Validation" {
        It "Should return error for invalid Game ID" {
            $result = Test-GameConfiguration -GameId "invalid game" -Platform "steam" -SteamAppId "1172470"
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "gameIdInvalidCharacters"
        }

        It "Should return error for empty Game ID" {
            $result = Test-GameConfiguration -GameId "" -Platform "steam" -SteamAppId "1172470"
            $result.IsValid | Should -BeFalse
            $result.Errors[0].Key | Should -Be "gameIdRequired"
        }
    }
}
