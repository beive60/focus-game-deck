<#
.SYNOPSIS
    Multi-platform support unit tests for Focus Game Deck.

.DESCRIPTION
    This test suite validates the multi-platform game launcher functionality,
    specifically testing Epic Games Store and Riot Client integration alongside
    the existing Steam platform support.

    The test suite performs comprehensive validation of:
    - PlatformManager class functionality and platform detection
    - Configuration validation for multi-platform game entries
    - Platform-specific game ID properties (steamAppId, epicGameId, riotGameId)
    - Platform availability detection logic
    - Game launch configuration validation (without actual launch)
    - Configuration file structure for multi-platform games

    Test Categories:
    1. Configuration Loading Tests
        - Main config.json structure validation
        - Multi-platform game entries verification
        - Platform paths configuration check

    2. PlatformManager Tests
        - Instance creation and initialization
        - Supported platforms enumeration
        - Platform availability detection (Steam, Epic, Riot)
        - Platform detection methods and results structure
        - Game configuration validation for each platform

    3. ConfigValidator Multi-Platform Tests
        - Steam game configuration validation
        - Epic Games game configuration validation
        - Riot Client game configuration validation
        - Invalid platform handling
        - Missing platform property handling (defaults)
        - Error and warning reporting

.PARAMETER Verbose
    Enables verbose output showing detailed validation errors, warnings,
    and intermediate test results for debugging purposes.

.EXAMPLE
    .\Test-MultiPlatform.ps1
    Runs all multi-platform support tests with standard output.

.EXAMPLE
    .\Test-MultiPlatform.ps1 -Verbose
    Runs tests with detailed verbose output including validation errors and warnings.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Purpose: Epic Games & Riot Client Support Testing

    Supported Platforms:
    - Steam (steamAppId property)
    - Epic Games Store (epicGameId property)
    - Riot Client (riotGameId property)

    Test Configuration:
    The test creates synthetic game configurations for each platform to validate
    the ConfigValidator and PlatformManager without requiring actual game installations.

    Expected Test Cases:
    - steamGame: Should pass (all required properties present)
    - epicGame: May warn (Epic path might not be configured)
    - riotGame: May warn (Riot path might not be configured)
    - invalidGame: Should fail (unsupported platform)
    - missingPlatform: Should pass (defaults to Steam)

    Exit Codes:
    - 0: All tests passed successfully
    - 1: One or more tests failed

    Dependencies:
    - src/modules/Logger.ps1 (logging functionality)
    - src/modules/ConfigValidator.ps1 (configuration validation)
    - src/modules/PlatformManager.ps1 (platform detection and management)
    - config/config.json (main configuration file)

    Requirements:
    - PowerShell 5.1 or higher
#>

param(
    [switch]$Verbose
)

#Requires -Version 5.1

# Test Configuration
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$srcDir = Join-Path -Path $projectRoot -ChildPath "src"

# Import modules for testing
$modulePaths = @(
    (Join-Path $srcDir "modules/Logger.ps1"),
    (Join-Path $srcDir "modules/ConfigValidator.ps1"),
    (Join-Path $srcDir "modules/PlatformManager.ps1")
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# Test Results
$global:TestResults = @{
    Passed = 0
    Failed = 0
    Details = @()
}

<#
.SYNOPSIS
    Asserts a test condition and records the result.

.DESCRIPTION
    Evaluates a test condition and records the result in the global test results
    structure. Displays formatted output with PASS or FAIL status and optional
    detailed message.

.PARAMETER TestName
    The name or description of the test being asserted.

.PARAMETER Condition
    Boolean condition to evaluate. True indicates test passed, false indicates failure.

.PARAMETER Message
    Optional detailed message providing context about the test result or failure reason.

.EXAMPLE
    Test-Assert "Platform Creation" ($platformManager -ne $null) "PlatformManager created successfully"
    Test-Assert "Steam Support" ("steam" -in $platforms) "Steam should be in supported platforms"

.NOTES
    Updates the global $TestResults hashtable with passed/failed counters and details.
    Output format: [OK] PASS or [ERROR] FAIL with test name and optional message.
#>
function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message = ""
    )

    if ($Condition) {
        $global:TestResults.Passed++
        $status = "[OK] PASS"
    } else {
        $global:TestResults.Failed++
        $status = "[ERROR] FAIL"
    }

    $result = "$status - $TestName"
    if ($Message) {
        $result += " ($Message)"
    }

    $global:TestResults.Details += $result
    Write-Host $result
}

<#
.SYNOPSIS
    Tests PlatformManager functionality for multi-platform support.

.DESCRIPTION
    Comprehensive test function that validates the PlatformManager class implementation.
    Tests platform detection, availability checking, game configuration validation,
    and platform-specific properties for Steam, Epic Games, and Riot Client.

    Test Scenarios:
    - PlatformManager instance creation
    - Supported platforms enumeration (expects 3: steam, epic, riot)
    - Platform availability detection logic
    - Platform detection results structure
    - Game configuration validation for each platform

.EXAMPLE
    Test-PlatformManager

.NOTES
    Creates a test configuration with paths for all three platforms.
    Does not actually launch games, only validates configuration structure.
    Updates global $TestResults with all test outcomes.
#>
function Test-PlatformManager {
    Write-Host "=== PlatformManager Tests ==="

    # Create test configuration
    $testConfig = @{
        paths = @{
            steam = "C:/Program Files (x86)/Steam/steam.exe"
            epic = "C:/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
            riot = "C:/Riot Games/Riot Client/RiotClientServices.exe"
        }
    }

    # Test PlatformManager creation
    try {
        $platformManager = New-PlatformManager -Config $testConfig -Messages @{}
        Test-Assert "PlatformManager Creation" ($null -ne $platformManager) "Successfully created PlatformManager instance"
    } catch {
        Test-Assert "PlatformManager Creation" $false "Failed to create PlatformManager: $_"
        return
    }

    # Test supported platforms
    $supportedPlatforms = $platformManager.GetSupportedPlatforms()
    Test-Assert "Supported Platforms Count" ($supportedPlatforms.Count -eq 4) "Expected 4 platforms (steam, epic, riot and direct), got $($supportedPlatforms.Count)"
    Test-Assert "Steam Platform Support" ("steam" -in $supportedPlatforms) "Steam platform should be supported"
    Test-Assert "Epic Platform Support" ("epic" -in $supportedPlatforms) "Epic platform should be supported"
    Test-Assert "Riot Platform Support" ("riot" -in $supportedPlatforms) "Riot platform should be supported"

    # Test platform availability detection
    $steamAvailable = $platformManager.IsPlatformAvailable("steam")
    $epicAvailable = $platformManager.IsPlatformAvailable("epic")
    $riotAvailable = $platformManager.IsPlatformAvailable("riot")

    Test-Assert "Steam Detection Logic" ($steamAvailable -is [bool]) "Steam detection should return boolean"
    Test-Assert "Epic Detection Logic" ($epicAvailable -is [bool]) "Epic detection should return boolean"
    Test-Assert "Riot Detection Logic" ($riotAvailable -is [bool]) "Riot detection should return boolean"

    # Test platform detection methods
    $detectedPlatforms = $platformManager.DetectAllPlatforms()
    Test-Assert "Platform Detection Results" ($detectedPlatforms.Count -eq 4) "Should detect 4 platforms"

    foreach ($platform in @("steam", "epic", "riot")) {
        $platformInfo = $detectedPlatforms[$platform]
        Test-Assert "$platform Detection Structure" ($null -ne $platformInfo) "$platform should have detection info"
        Test-Assert "$platform Available Property" ($platformInfo.ContainsKey("Available")) "$platform should have Available property"
        Test-Assert "$platform Name Property" ($platformInfo.ContainsKey("Name")) "$platform should have Name property"
    }

    # Test game launch validation (without actual launch)
    $testGameConfigs = @{
        steam = @{
            steamAppId = "123456"
            name = "Test Steam Game"
        }
        epic = @{
            epicGameId = "TestEpicGame"
            name = "Test Epic Game"
        }
        riot = @{
            riotGameId = "testgame"
            name = "Test Riot Game"
        }
    }

    foreach ($platform in $testGameConfigs.Keys) {
        $gameConfig = $testGameConfigs[$platform]
        try {
            # We can't actually launch games in tests, but we can validate the structure
            $platformObj = $platformManager.Platforms[$platform]
            $gameIdProperty = $platformObj.GameIdProperty
            $hasRequiredProperty = $gameConfig.ContainsKey($gameIdProperty)
            Test-Assert "$platform Game Config Validation" $hasRequiredProperty "Game config should have $gameIdProperty property"
        } catch {
            Test-Assert "$platform Game Config Validation" $false "Validation failed: $_"
        }
    }
}

<#
.SYNOPSIS
    Tests ConfigValidator with multi-platform game configurations.

.DESCRIPTION
    Validates the ConfigValidator class's ability to properly validate game
    configurations for different platforms (Steam, Epic Games, Riot Client).

    Tests multiple scenarios:
    - Valid Steam game configuration
    - Epic Games game configuration (may have path warnings)
    - Riot Client game configuration (may have path warnings)
    - Invalid platform handling
    - Missing platform property (defaults to Steam)

    Each test case validates error and warning reporting, ensuring that the
    ConfigValidator correctly identifies configuration issues and provides
    appropriate feedback.

.EXAMPLE
    Test-ConfigValidator

.NOTES
    Creates synthetic test configurations to validate all scenarios.
    Checks both error and warning counts in validation results.
    If -Verbose is enabled, displays detailed error and warning messages.
    Updates global $TestResults with all test outcomes.
#>
function Test-ConfigValidator {
    Write-Host "=== ConfigValidator Multi-Platform Tests ==="

    # Test configuration with multi-platform games
    $testConfig = @{
        managedApps = @{
            testApp = @{
                path = "C:\Test/app.exe"
                processName = "testapp"
                gameStartAction = "start-process"
                gameEndAction = "stop-process"
                arguments = ""
            }
        }
        games = @{
            steamGame = @{
                name = "Test Steam Game"
                platform = "steam"
                steamAppId = "123456"
                processName = "steamgame*"
                appsToManage = @("testApp")
            }
            epicGame = @{
                name = "Test Epic Game"
                platform = "epic"
                epicGameId = "TestEpicGame"
                processName = "epicgame*"
                appsToManage = @("testApp")
            }
            riotGame = @{
                name = "Test Riot Game"
                platform = "riot"
                riotGameId = "testgame"
                processName = "riotgame*"
                appsToManage = @("testApp")
            }
            invalidGame = @{
                name = "Invalid Game"
                platform = "unsupported"
                processName = "invalid*"
                appsToManage = @()
            }
            missingPlatform = @{
                name = "Missing Platform Game"
                steamAppId = "654321"
                processName = "missing*"
                appsToManage = @()
            }
        }
        paths = @{
            steam = "C:/Steam/steam.exe"
        }
    }

    try {
        $validator = New-ConfigValidator -Config $testConfig -Messages @{}
        Test-Assert "ConfigValidator Creation" ($null -ne $validator) "Successfully created ConfigValidator"
    } catch {
        Test-Assert "ConfigValidator Creation" $false "Failed to create ConfigValidator: $_"
        return
    }

    # Test individual game validations
    $testCases = @{
        "steamGame" = $true
        "epicGame" = $false  # Should have warnings about missing epic path
        "riotGame" = $false  # Should have warnings about missing riot path
        "invalidGame" = $false  # Should fail due to unsupported platform
        "missingPlatform" = $true  # Should pass (defaults to steam)
    }

    foreach ($gameId in $testCases.Keys) {
        $shouldPass = $testCases[$gameId]

        # Clear previous validation results
        $validator.Errors = @()
        $validator.Warnings = @()

        $validator.ValidateGameConfiguration($gameId)

        $hasErrors = $validator.Errors.Count -gt 0
        $actualResult = -not $hasErrors

        if ($shouldPass) {
            Test-Assert "Game '$gameId' Validation (Should Pass)" $actualResult "Expected no errors, got $($validator.Errors.Count) errors"
        } else {
            Test-Assert "Game '$gameId' Validation (Should Fail/Warn)" (-not $actualResult -or $validator.Warnings.Count -gt 0) "Expected errors or warnings"
        }

        if ($Verbose -and ($validator.Errors.Count -gt 0 -or $validator.Warnings.Count -gt 0)) {
            Write-Host "  Errors: $($validator.Errors -join '; ')"
            Write-Host "  Warnings: $($validator.Warnings -join '; ')"
        }
    }
}

<#
.SYNOPSIS
    Tests loading and validation of the main configuration file.

.DESCRIPTION
    Validates the actual config.json file in the project, ensuring it contains
    proper multi-platform game configurations and platform paths.

    Test Validations:
    - Main configuration file loads successfully
    - Configuration has required sections (games, paths)
    - At least one multi-platform (non-Steam) game is configured
    - All three platform paths are configured (steam, epic, riot)

    This test ensures that the project's actual configuration file supports
    multi-platform functionality and has the necessary structure for all
    supported game launchers.

.EXAMPLE
    Test-ConfigurationLoading

.NOTES
    Reads the actual config/config.json file from the project.
    Uses UTF-8 encoding for proper character support.
    Updates global $TestResults with all test outcomes.
#>
function Test-ConfigurationLoading {
    Write-Host "=== Configuration Loading Tests ==="

    $configPath = Join-Path $projectRoot "config/config.json"

    # Test main config.json loading
    try {
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Test-Assert "Main Config Loading" ($null -ne $config) "Successfully loaded main configuration"
        Test-Assert "Config Has Games" ($null -ne $config.games) "Configuration should have games section"
        Test-Assert "Config Has Paths" ($null -ne $config.paths) "Configuration should have paths section"

        # Test multi-platform game entries
        $gameIds = $config.games.PSObject.Properties.Name
        $multiPlatformGames = 0

        foreach ($gameId in $gameIds) {
            $game = $config.games.$gameId
            if ($game.platform -and $game.platform -ne "steam") {
                $multiPlatformGames++
            }
        }

        Test-Assert "Multi-Platform Games Present" ($multiPlatformGames -gt 0) "Should have at least one non-Steam game configured"

        # Test platform paths
        $expectedPlatforms = @("steam", "epic", "riot")
        foreach ($platform in $expectedPlatforms) {
            $hasPath = $config.paths.PSObject.Properties.Name -contains $platform
            Test-Assert "$platform Path Configuration" $hasPath "$platform should have a configured path"
        }
    } catch {
        Test-Assert "Main Config Loading" $false "Failed to load configuration: $_"
    }
}

# Execute Tests
Write-Host "Focus Game Deck - Multi-Platform Support Unit Tests"
Write-Host "Testing Epic Games & Riot Client Integration (v1.0)"
Write-Host "======================================================"

Test-ConfigurationLoading
Test-PlatformManager
Test-ConfigValidator

# Display Results
Write-Host "======================================================"
Write-Host "Test Results Summary"
Write-Host "======================================================"
Write-Host "Tests Passed: $($global:TestResults.Passed)"
Write-Host "Tests Failed: $($global:TestResults.Failed)"
Write-Host "Total Tests: $($global:TestResults.Passed + $global:TestResults.Failed)"

if ($global:TestResults.Failed -gt 0) {
    Write-Host "Failed Tests:"
    $global:TestResults.Details | Where-Object { $_ -like "FAIL*" } | ForEach-Object {
        Write-Host "  $_"
    }
    exit 1
} else {
    Write-Host "All tests passed!"
    exit 0
}
