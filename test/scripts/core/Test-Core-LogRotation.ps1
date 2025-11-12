<#
.SYNOPSIS
    Test script for log file automatic deletion functionality.

.DESCRIPTION
    This script tests the automatic log rotation and cleanup feature in Logger.ps1.
    It validates that old log files are deleted according to the configured retention
    policy (logRetentionDays setting) while preserving recent logs.

    Test Coverage:
    - Creates dummy log files with various ages (10, 30, 45, 90, 95, 180, 200 days old)
    - Tests different logRetentionDays configurations (30, 90, 180 days)
    - Validates unlimited retention policy (logRetentionDays = -1)
    - Tests invalid configuration handling (defaults to 90 days)
    - Tests missing logging configuration handling

    The test creates a temporary test environment with controlled log file ages
    and verifies that the Logger class correctly removes files based on the
    retention policy while preserving the current log file and recent logs.

.PARAMETER Verbose
    Enables verbose output showing detailed information about test file creation,
    deletion counts, and intermediate test results.

.EXAMPLE
    .\Test-LogRotation.ps1
    Runs the log rotation tests with standard output.

.EXAMPLE
    .\Test-LogRotation.ps1 -Verbose
    Runs the tests with detailed verbose output showing file operations.

.NOTES
    Author: GitHub Copilot Assistant
    Version: 1.0.0
    Date: 2025-09-27

    Test Scenarios:
    1. 30-day retention: Expects deletion of 6 files (30, 45, 90, 95, 180, 200 days old)
    2. 90-day retention: Expects deletion of 4 files (90, 95, 180, 200 days old)
    3. 180-day retention: Expects deletion of 2 files (180, 200 days old)
    4. Unlimited retention (-1): Expects no deletions
    5. Invalid configuration (0): Should default to 90-day behavior
    6. Missing configuration: Should handle gracefully without errors

    Test Files Created:
    - recent.log (10 days old)
    - 30days.log (30 days old)
    - 45days.log (45 days old)
    - 90days.log (90 days old)
    - 95days.log (95 days old)
    - 180days.log (180 days old)
    - 200days.log (200 days old)
    - focus-game-deck.log (5 days old - current log)

    Exit Codes:
    - 0: All tests passed successfully
    - 1: One or more tests failed

    Dependencies:
    - src/modules/Logger.ps1 (Logger class implementation)

    Temporary Files:
    - Creates temp_log_test/ directory with test log files
    - Creates temp_config_test.json configuration file
    - All temporary files are cleaned up after test completion
#>

param(
    [switch]$Verbose
)

# Set execution policy and encoding
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Import required modules
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$LoggerModulePath = Join-Path -Path $projectRoot -ChildPath "src/modules/Logger.ps1"
if (Test-Path $LoggerModulePath) {
    . $LoggerModulePath
} else {
    throw "Logger module not found: $LoggerModulePath"
}

# Test variables
$TestLogDir = Join-Path $PSScriptRoot "temp_log_test"
$TestConfigPath = Join-Path $PSScriptRoot "temp_config_test.json"

# Test results counter
$TestsPassed = 0
$TestsFailed = 0

<#
.SYNOPSIS
    Writes a formatted test result to the console.

.DESCRIPTION
    Utility function to record and display test results in a consistent format.
    Increments the global test counters based on pass/fail status.

.PARAMETER TestName
    The name or description of the test being reported.

.PARAMETER Passed
    Boolean indicating whether the test passed (true) or failed (false).

.PARAMETER Message
    Optional additional message providing details about the test result.

.EXAMPLE
    Write-TestResult -TestName "30-day retention" -Passed $true
    Write-TestResult -TestName "File cleanup" -Passed $false -Message "Expected 4 deletions, got 2"

.NOTES
    Updates the script-scoped $TestsPassed and $TestsFailed counters.
#>
function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    if ($Passed) {
        Write-Host "PASS: $TestName"
        if ($Message) { Write-Host "   $Message" }
        $script:TestsPassed++
    } else {
        Write-Host "FAIL: $TestName"
        if ($Message) { Write-Host "   $Message" }
        $script:TestsFailed++
    }
}

<#
.SYNOPSIS
    Cleans up temporary test files and directories.

.DESCRIPTION
    Removes all temporary files and directories created during the test execution,
    including the test log directory and test configuration file. Handles errors
    gracefully if cleanup fails.

.EXAMPLE
    Clear-TestEnvironment

.NOTES
    Called at the end of each test scenario and final cleanup.
    Suppresses errors if files don't exist or cannot be deleted.
#>
function Clear-TestEnvironment {
    param()

    try {
        if (Test-Path $TestLogDir) {
            Remove-Item -Path $TestLogDir -Recurse -Force
        }
        if (Test-Path $TestConfigPath) {
            Remove-Item -Path $TestConfigPath -Force
        }
    } catch {
        Write-Warning "Failed to cleanup test environment: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Creates test log files with specific ages for testing.

.DESCRIPTION
    Generates a set of dummy log files with various ages (in days) by manipulating
    the LastWriteTime property. This allows testing of the log retention policy
    without waiting for files to age naturally.

    Creates 8 test files ranging from 5 to 200 days old, including the current
    log file (focus-game-deck.log).

.PARAMETER LogDirectory
    The directory path where test log files should be created.

.EXAMPLE
    New-TestLogFiles -LogDirectory "C:\temp\test_logs"

.NOTES
    Returns the count of files created.
    Uses UTF-8 encoding for file content.
    If -Verbose is enabled, outputs creation details for each file.
#>
function New-TestLogFiles {
    param(
        [string]$LogDirectory
    )

    # Ensure directory exists
    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    # Create log files with different ages
    $testFiles = @(
        @{ Name = "recent.log"; DaysOld = 10; Content = "Recent log file" },
        @{ Name = "30days.log"; DaysOld = 30; Content = "30 days old log file" },
        @{ Name = "45days.log"; DaysOld = 45; Content = "45 days old log file" },
        @{ Name = "90days.log"; DaysOld = 90; Content = "90 days old log file" },
        @{ Name = "95days.log"; DaysOld = 95; Content = "95 days old log file" },
        @{ Name = "180days.log"; DaysOld = 180; Content = "180 days old log file" },
        @{ Name = "200days.log"; DaysOld = 200; Content = "200 days old log file" },
        @{ Name = "focus-game-deck.log"; DaysOld = 5; Content = "Current log file" }
    )

    foreach ($file in $testFiles) {
        $filePath = Join-Path $LogDirectory $file.Name
        Set-Content -Path $filePath -Value $file.Content -Encoding UTF8

        # Set the file's last write time to simulate age
        $oldDate = (Get-Date).AddDays(-$file.DaysOld)
        (Get-Item $filePath).LastWriteTime = $oldDate

        if ($Verbose) {
            Write-Host "Created test file: $($file.Name) (Age: $($file.DaysOld) days)"
        }
    }

    return $testFiles.Count
}

<#
.SYNOPSIS
    Creates a test configuration file with specified retention settings.

.DESCRIPTION
    Generates a temporary configuration JSON file for testing Logger initialization
    with different logRetentionDays values.

.PARAMETER ConfigPath
    The file path where the configuration JSON should be saved.

.PARAMETER RetentionDays
    The number of days to retain log files. Use -1 for unlimited retention.

.EXAMPLE
    New-TestConfig -ConfigPath "test_config.json" -RetentionDays 30
    New-TestConfig -ConfigPath "test_config.json" -RetentionDays -1

.NOTES
    Configuration includes minimal logging settings required for Logger class initialization.
    Saves the configuration as UTF-8 encoded JSON.
#>
function New-TestConfig {
    param(
        [string]$ConfigPath,
        [int]$RetentionDays
    )

    $config = @{
        logging = @{
            level                = "Debug"
            enableFileLogging    = $true
            enableConsoleLogging = $false
            filePath             = Join-Path $TestLogDir "focus-game-deck.log"
            logRetentionDays     = $RetentionDays
            enableNotarization   = $false
        }
    }

    $config | ConvertTo-Json -Depth 3 | Set-Content -Path $ConfigPath -Encoding UTF8
}

<#
.SYNOPSIS
    Tests log retention behavior for a specific retention period.

.DESCRIPTION
    Executes a complete test scenario for a given logRetentionDays configuration.
    Creates test files, initializes the Logger (which triggers cleanup), and
    validates that the correct number of old files were deleted.

    Also verifies that recent files are preserved and not incorrectly deleted.

.PARAMETER RetentionDays
    The number of days for the retention policy being tested. Use -1 for unlimited.

.PARAMETER TestDescription
    Human-readable description of the test scenario for output display.

.EXAMPLE
    Test-LogRetention -RetentionDays 30 -TestDescription "30-day retention policy"
    Test-LogRetention -RetentionDays -1 -TestDescription "Unlimited retention"

.NOTES
    Expected deletions by retention period:
    - 30 days: 6 files deleted (30, 45, 90, 95, 180, 200 days old)
    - 90 days: 4 files deleted (90, 95, 180, 200 days old)
    - 180 days: 2 files deleted (180, 200 days old)
    - -1 (unlimited): 0 files deleted
#>
function Test-LogRetention {
    param(
        [int]$RetentionDays,
        [string]$TestDescription
    )

    try {
        Write-Host "`Testing: $TestDescription"

        # Create fresh test environment
        Clear-TestEnvironment
        $null = New-TestLogFiles -LogDirectory $TestLogDir
        New-TestConfig -ConfigPath $TestConfigPath -RetentionDays $RetentionDays

        # Load test config
        $config = Get-Content -Path $TestConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $messages = @{} # Empty messages for test

        # Get file count before cleanup
        $filesBefore = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count

        # Initialize logger (this triggers cleanup)
        $null = [Logger]::new($config, $messages)

        # Get file count after cleanup
        $filesAfter = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count
        $filesDeleted = $filesBefore - $filesAfter

        if ($Verbose) {
            Write-Host "Files before: $filesBefore, Files after: $filesAfter, Deleted: $filesDeleted"
        }

        # Calculate expected deletions based on retention period
        $expectedDeletions = 0
        if ($RetentionDays -eq 30) {
            $expectedDeletions = 6  # Files older than or equal to 30 days: 30, 45, 90, 95, 180, 200
        } elseif ($RetentionDays -eq 90) {
            $expectedDeletions = 4  # Files older than or equal to 90 days: 90, 95, 180, 200
        } elseif ($RetentionDays -eq 180) {
            $expectedDeletions = 2  # Files older than or equal to 180 days: 180, 200
        } elseif ($RetentionDays -eq -1) {
            $expectedDeletions = 0  # No deletions for unlimited retention
        }

        # Verify results
        $testPassed = ($filesDeleted -eq $expectedDeletions)
        Write-TestResult -TestName "$TestDescription (Expected: $expectedDeletions, Actual: $filesDeleted)" -Passed $testPassed

        # Additional verification: Check specific files
        if ($testPassed) {
            $remainingFiles = Get-ChildItem -Path $TestLogDir -Filter "*.log" | Select-Object -ExpandProperty Name

            if ($RetentionDays -ne -1) {
                # Verify that recent files still exist
                $shouldExist = @("recent.log", "focus-game-deck.log")
                foreach ($file in $shouldExist) {
                    if ($file -in $remainingFiles) {
                        Write-TestResult -TestName "Recent file '$file' preserved" -Passed $true
                    } else {
                        Write-TestResult -TestName "Recent file '$file' preserved" -Passed $false -Message "File was incorrectly deleted"
                    }
                }
            }
        }

    } catch {
        Write-TestResult -TestName $TestDescription -Passed $false -Message "Exception: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Main test execution function that runs all log rotation test scenarios.

.DESCRIPTION
    Orchestrates the execution of all test cases for log rotation functionality:
    - Tests standard retention periods (30, 90, 180 days)
    - Tests unlimited retention (-1)
    - Tests invalid configuration handling
    - Tests missing configuration handling

    Each test creates a fresh environment, executes the scenario, and validates results.

.EXAMPLE
    Invoke-LogRotationTests

.NOTES
    This function is called by the main test script execution block.
    Results are tracked globally via $TestsPassed and $TestsFailed counters.
#>
function Invoke-LogRotationTests {
    param()

    Write-Host "Starting Log Rotation Tests"
    Write-Host "=" * 50

    # Test 1: 30-day retention
    Test-LogRetention -RetentionDays 30 -TestDescription "30-day retention policy"

    # Test 2: 90-day retention (default)
    Test-LogRetention -RetentionDays 90 -TestDescription "90-day retention policy (default)"

    # Test 3: 180-day retention
    Test-LogRetention -RetentionDays 180 -TestDescription "180-day retention policy"

    # Test 4: Unlimited retention
    Test-LogRetention -RetentionDays -1 -TestDescription "Unlimited retention policy"

    # Test 5: Invalid configuration (should default to 90 days)
    try {
        Write-Host "`Testing: Invalid configuration handling"

        Clear-TestEnvironment
        New-TestLogFiles -LogDirectory $TestLogDir

        # Create config with invalid retention value
        $invalidConfig = @{
            logging = @{
                level                = "Debug"
                enableFileLogging    = $true
                enableConsoleLogging = $false
                filePath             = Join-Path $TestLogDir "focus-game-deck.log"
                logRetentionDays     = 0  # Invalid value
                enableNotarization   = $false
            }
        }

        $invalidConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $TestConfigPath -Encoding UTF8
        $config = Get-Content -Path $TestConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

        $filesBefore = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count
        $null = [Logger]::new($config, @{})
        $filesAfter = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count
        $filesDeleted = $filesBefore - $filesAfter

        # Should behave like 90-day retention (default)
        $expectedDeletions = 4
        $testPassed = ($filesDeleted -eq $expectedDeletions)
        Write-TestResult -TestName "Invalid config defaults to 90 days (Expected: $expectedDeletions, Actual: $filesDeleted)" -Passed $testPassed

    } catch {
        Write-TestResult -TestName "Invalid configuration handling" -Passed $false -Message "Exception: $($_.Exception.Message)"
    }

    # Test 6: Missing logging configuration
    try {
        Write-Host "`Testing: Missing logging configuration"

        Clear-TestEnvironment
        New-TestLogFiles -LogDirectory $TestLogDir

        # Create minimal config without logging section
        $minimalConfig = @{
            obs = @{
                websocket = @{
                    host = "localhost"
                    port = 4455
                }
            }
        }

        $minimalConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $TestConfigPath -Encoding UTF8
        $config = Get-Content -Path $TestConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # This should not crash and should use default behavior
        $null = [Logger]::new($config, @{})
        Write-TestResult -TestName "Missing logging configuration handled gracefully" -Passed $true

    } catch {
        Write-TestResult -TestName "Missing logging configuration handling" -Passed $false -Message "Exception: $($_.Exception.Message)"
    }
}

# Execute tests
try {
    Invoke-LogRotationTests

    # Final cleanup
    Clear-TestEnvironment

    # Summary
    Write-Host "`n" + "=" * 50
    Write-Host "Test Summary:"
    Write-Host "Passed: $TestsPassed"
    Write-Host "Failed: $TestsFailed"
    $successRate = [math]::Round(($TestsPassed / ($TestsPassed + $TestsFailed)) * 100, 1)
    if ($TestsFailed -eq 0) {
        Write-Host "[OK] Success Rate: $successRate%"
    } else {
        Write-Host "[WARNING] Success Rate: $successRate%"
    }

    if ($TestsFailed -eq 0) {
        Write-Host "[OK] All tests passed! Log rotation feature is working correctly."
        exit 0
    } else {
        Write-Host "[WARNING] Some tests failed. Please review the implementation."
        exit 1
    }

} catch {
    Write-Host "[ERROR] Test execution failed: $($_.Exception.Message)"
    Clear-TestEnvironment
    exit 1
}
