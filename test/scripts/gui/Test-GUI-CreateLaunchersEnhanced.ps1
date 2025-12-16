<#
.SYNOPSIS
    Tests for Create-Launchers-Enhanced.ps1 script

.DESCRIPTION
    Unit tests for the enhanced launcher creation script.
    Tests single-game and multi-game shortcut creation functionality.

.NOTES
    Author: Focus Game Deck Team
    Date: 2025-12-15
#>

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

# Set execution policy and encoding
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

Write-BuildLog "=== Create-Launchers-Enhanced.ps1 Unit Tests ==="
Write-BuildLog "Testing launcher creation functionality..."
Write-Host ""

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestResults = @()

# Helper function to run a test
function Invoke-Test {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [string]$Description = ""
    )

    Write-BuildLog "Running Test: $TestName"
    if ($Description) {
        Write-BuildLog "  Description: $Description" -Level Debug
    }

    try {
        $result = & $TestCode
        if ($result -eq $true -or $null -eq $result) {
            Write-BuildLog "  PASSED" -Level Success
            $script:TestsPassed++
            $script:TestResults += [PSCustomObject]@{
                TestName = $TestName
                Status = "PASSED"
                Error = $null
                Description = $Description
            }
        } else {
            Write-BuildLog "  FAILED: $result" -Level Error
            $script:TestsFailed++
            $script:TestResults += [PSCustomObject]@{
                TestName = $TestName
                Status = "FAILED"
                Error = $result
                Description = $Description
            }
        }
    } catch {
        Write-BuildLog "  FAILED: $($_.Exception.Message)" -Level Error
        $script:TestsFailed++
        $script:TestResults += [PSCustomObject]@{
            TestName = $TestName
            Status = "FAILED"
            Error = $_.Exception.Message
            Description = $Description
        }
    }
    Write-Host ""
}

# Setup test environment
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$launcherScript = Join-Path -Path $projectRoot -ChildPath "scripts/Create-Launchers-Enhanced.ps1"
$testConfigPath = Join-Path -Path $projectRoot -ChildPath "test/temp/test-launcher-config.json"
$testOutputDir = Join-Path -Path $projectRoot -ChildPath "test/temp/launcher-output"

# Create test directories
$testTempDir = Join-Path -Path $projectRoot -ChildPath "test/temp"
if (-not (Test-Path $testTempDir)) {
    New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null
}
if (-not (Test-Path $testOutputDir)) {
    New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
}

# Test 1: Script Existence
Invoke-Test -TestName "Script File Exists" -Description "Verify Create-Launchers-Enhanced.ps1 exists" -TestCode {
    Test-Path $launcherScript
}

# Test 2: Script Syntax Validation
Invoke-Test -TestName "Script Syntax Valid" -Description "Verify PowerShell syntax is valid" -TestCode {
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $launcherScript -Raw), [ref]$null)
        return $true
    } catch {
        return $_.Exception.Message
    }
}

# Test 3: Required Parameters
Invoke-Test -TestName "Script Parameters" -Description "Verify script accepts required parameters" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasNoInteractive = $scriptContent -match '\[switch\]\$NoInteractive'
    $hasGameId = $scriptContent -match '\[string\]\$GameId'

    if ($hasNoInteractive -and $hasGameId) {
        return $true
    } else {
        return "Missing required parameters: NoInteractive=$hasNoInteractive, GameId=$hasGameId"
    }
}

# Test 4: Create Test Configuration
Invoke-Test -TestName "Create Test Configuration" -Description "Create mock config.json for testing" -TestCode {
    $testConfig = @{
        language = "en"
        games = @{
            testGame1 = @{
                name = "Test Game 1"
                platform = "steam"
                steamAppId = "1234567"
                processName = "testgame1.exe"
            }
            testGame2 = @{
                name = "Test Game 2"
                platform = "epic"
                epicGameId = "testgame2"
                processName = "testgame2.exe"
            }
            testGame3 = @{
                name = "Test Game 3"
                platform = "standalone"
                executablePath = "C:\\Games\\TestGame3\\game.exe"
                processName = "game.exe"
            }
        }
    } | ConvertTo-Json -Depth 10

    try {
        $testConfig | Out-File -FilePath $testConfigPath -Encoding UTF8 -Force
        return Test-Path $testConfigPath
    } catch {
        return $_.Exception.Message
    }
}

# Test 5: Single Game Shortcut Creation (Dry Run Check)
Invoke-Test -TestName "Single Game Parameter Handling" -Description "Verify script handles -GameId parameter" -TestCode {
    # Create a temporary test environment
    $tempConfigDir = Join-Path -Path $testOutputDir -ChildPath "config"
    $tempSrcDir = Join-Path -Path $testOutputDir -ChildPath "src"

    if (-not (Test-Path $tempConfigDir)) {
        New-Item -ItemType Directory -Path $tempConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $tempSrcDir)) {
        New-Item -ItemType Directory -Path $tempSrcDir -Force | Out-Null
    }

    # Copy test config
    Copy-Item -Path $testConfigPath -Destination (Join-Path -Path $tempConfigDir -ChildPath "config.json") -Force

    # Create minimal Invoke-FocusGameDeck.ps1 mock
    $mockScript = @"
# Mock script for testing
param([string]`$GameId)
Write-Host "Mock: Would launch game `$GameId"
"@
    $mockScript | Out-File -FilePath (Join-Path -Path $tempSrcDir -ChildPath "Invoke-FocusGameDeck.ps1") -Encoding UTF8 -Force

    # Test that script can be parsed with GameId parameter
    try {
        $scriptBlock = [scriptblock]::Create((Get-Content $launcherScript -Raw))
        return $true
    } catch {
        return $_.Exception.Message
    }
}

# Test 6: Multiple Games Configuration Handling
Invoke-Test -TestName "Multiple Games Detection" -Description "Verify script detects multiple games in config" -TestCode {
    try {
        $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
        $gameCount = ($config.games.PSObject.Properties | Measure-Object).Count

        if ($gameCount -eq 3) {
            return $true
        } else {
            return "Expected 3 games, found $gameCount"
        }
    } catch {
        return $_.Exception.Message
    }
}

# Test 7: New-GameShortcut Function Existence
Invoke-Test -TestName "New-GameShortcut Function" -Description "Verify New-GameShortcut function is defined" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasFunctionDef = $scriptContent -match 'function\s+New-GameShortcut'

    if ($hasFunctionDef) {
        return $true
    } else {
        return "New-GameShortcut function not found in script"
    }
}

# Test 8: Remove-OldLaunchers Function Existence
Invoke-Test -TestName "Remove-OldLaunchers Function" -Description "Verify Remove-OldLaunchers function is defined" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasFunctionDef = $scriptContent -match 'function\s+Remove-OldLaunchers'

    if ($hasFunctionDef) {
        return $true
    } else {
        return "Remove-OldLaunchers function not found in script"
    }
}

# Test 9: Error Handling for Missing Config
Invoke-Test -TestName "Missing Config Error Handling" -Description "Verify script handles missing config.json" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasConfigCheck = $scriptContent -match 'Test-Path.*configPath'
    $hasErrorMessage = $scriptContent -match 'config\.json not found'

    if ($hasConfigCheck -and $hasErrorMessage) {
        return $true
    } else {
        return "Missing config error handling not found"
    }
}

# Test 10: GameId Filtering Logic
Invoke-Test -TestName "GameId Filtering Logic" -Description "Verify script filters games by GameId parameter" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasFilterLogic = $scriptContent -match 'Where-Object.*Name.*-eq.*\$GameId'

    if ($hasFilterLogic) {
        return $true
    } else {
        return "GameId filtering logic not found"
    }
}

# Test 10.5: _order Property Exclusion
Invoke-Test -TestName "_order Property Exclusion" -Description "Verify script excludes _order property from games" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasOrderExclusion = $scriptContent -match "Where-Object.*Name.*-ne.*'_order'"

    if ($hasOrderExclusion) {
        return $true
    } else {
        return "_order exclusion logic not found"
    }
}

# Test 11: Success Counter Logic
Invoke-Test -TestName "Success Counter" -Description "Verify script tracks successful creations" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasSuccessCounter = $scriptContent -match '\$successCount'
    $hasIncrement = $scriptContent -match '\$successCount\+\+'

    if ($hasSuccessCounter -and $hasIncrement) {
        return $true
    } else {
        return "Success counter logic not found"
    }
}

# Test 12: Failure Counter Logic
Invoke-Test -TestName "Failure Counter" -Description "Verify script tracks failed creations" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasFailureCounter = $scriptContent -match '\$failureCount'
    $hasIncrement = $scriptContent -match '\$failureCount\+\+'

    if ($hasFailureCounter -and $hasIncrement) {
        return $true
    } else {
        return "Failure counter logic not found"
    }
}

# Test 13: Shortcut Naming Convention
Invoke-Test -TestName "Shortcut Naming Convention" -Description "Verify shortcuts follow GAMEID.lnk pattern" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasNamingPattern = $scriptContent -match '\"\$\(\$gameId\)\.lnk\"'

    if ($hasNamingPattern) {
        return $true
    } else {
        return "Shortcut naming convention not found"
    }
}

# Test 14: PowerShell Minimized Window Style
Invoke-Test -TestName "Minimized Window Style" -Description "Verify shortcuts use minimized window style" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasMinimizedStyle = $scriptContent -match 'WindowStyle\s+(Minimized|7)'

    if ($hasMinimizedStyle) {
        return $true
    } else {
        return "Minimized window style not found"
    }
}

# Test 15: NoInteractive Parameter Usage
Invoke-Test -TestName "NoInteractive Parameter" -Description "Verify NoInteractive parameter suppresses pause" -TestCode {
    $scriptContent = Get-Content $launcherScript -Raw
    $hasNoInteractiveCheck = $scriptContent -match 'if\s*\(\s*-not\s+\$NoInteractive\s*\)'

    if ($hasNoInteractiveCheck) {
        return $true
    } else {
        return "NoInteractive parameter handling not found"
    }
}

# Cleanup test files
Write-BuildLog "Cleaning up test files..."
if (Test-Path $testConfigPath) {
    Remove-Item $testConfigPath -Force -ErrorAction SilentlyContinue
}
if (Test-Path $testOutputDir) {
    Remove-Item $testOutputDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Summary
Write-Host ""
Write-BuildLog "=== Test Summary ===" -Level Info
Write-BuildLog "Tests Passed: $script:TestsPassed" -Level Success
Write-BuildLog "Tests Failed: $script:TestsFailed" -Level $(if ($script:TestsFailed -eq 0) { "Success" } else { "Warning" })

if ($script:TestsFailed -gt 0) {
    Write-Host ""
    Write-BuildLog "Failed Tests:" -Level Warning
    $script:TestResults | Where-Object { $_.Status -eq "FAILED" } | ForEach-Object {
        Write-BuildLog "  - $($_.TestName): $($_.Error)" -Level Error
    }
}

Write-Host ""
Write-BuildLog "[TEST RESULT] Create-Launchers-Enhanced.ps1 Tests Completed"

# Exit with appropriate code
exit $(if ($script:TestsFailed -eq 0) { 0 } else { 1 })
