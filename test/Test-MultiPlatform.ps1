# Focus Game Deck - Multi-Platform Support Unit Tests
# v1.0 Epic Games & Riot Client Support Testing

param(
    [switch]$Verbose
)

#Requires -Version 5.1

# Test Configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent $scriptDir
$srcDir = Join-Path $projectRoot "src"

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

function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message = ""
    )

    if ($Condition) {
        $global:TestResults.Passed++
        $status = "PASS"
        $color = "Green"
    } else {
        $global:TestResults.Failed++
        $status = "FAIL"
        $color = "Red"
    }

    $result = "$status - $TestName"
    if ($Message) {
        $result += " ($Message)"
    }

    $global:TestResults.Details += $result
    Write-Host $result -ForegroundColor $color
}

function Test-PlatformManager {
    Write-Host "`n=== PlatformManager Tests ==="

    # Create test configuration
    $testConfig = @{
        paths = @{
            steam = "C:/Program Files (x86)/Steam/steam.exe"
            epic = "C:/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
            riot = "C:\Riot Games\Riot Client\RiotClientServices.exe"
        }
    }

    # Test PlatformManager creation
    try {
        $platformManager = New-PlatformManager -Config $testConfig -Messages @{}
        Test-Assert "PlatformManager Creation" ($null -ne $platformManager) "Successfully created PlatformManager instance"
    }
    catch {
        Test-Assert "PlatformManager Creation" $false "Failed to create PlatformManager: $_"
        return
    }

    # Test supported platforms
    $supportedPlatforms = $platformManager.GetSupportedPlatforms()
    Test-Assert "Supported Platforms Count" ($supportedPlatforms.Count -eq 3) "Expected 3 platforms (steam, epic, riot), got $($supportedPlatforms.Count)"
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
    Test-Assert "Platform Detection Results" ($detectedPlatforms.Count -eq 3) "Should detect 3 platforms"

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
        }
        catch {
            Test-Assert "$platform Game Config Validation" $false "Validation failed: $_"
        }
    }
}

function Test-ConfigValidator {
    Write-Host "`n=== ConfigValidator Multi-Platform Tests ==="

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
    }
    catch {
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

function Test-ConfigurationLoading {
    Write-Host "`n=== Configuration Loading Tests ==="

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
    }
    catch {
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
Write-Host "`n======================================================"
Write-Host "Test Results Summary"
Write-Host "======================================================"
Write-Host "Tests Passed: $($global:TestResults.Passed)"
Write-Host "Tests Failed: $($global:TestResults.Failed)"
Write-Host "Total Tests: $($global:TestResults.Passed + $global:TestResults.Failed)"

if ($global:TestResults.Failed -gt 0) {
    Write-Host "`nFailed Tests:"
    $global:TestResults.Details | Where-Object { $_ -like "FAIL*" } | ForEach-Object {
        Write-Host "  $_"
    }
    exit 1
} else {
    Write-Host "`nAll tests passed!"
    exit 0
}
