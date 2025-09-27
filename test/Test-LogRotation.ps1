# Test-LogRotation.ps1
# ログファイル自動削除機能のテストスクリプト
#
# このスクリプトは、Logger.ps1 のログ自動削除機能をテストします。
# - 様々な更新日時のダミーログファイルを作成
# - 異なる logRetentionDays 設定での削除動作をテスト
# - 無期限設定時の動作確認
#
# Author: GitHub Copilot Assistant
# Date: 2025-09-27

param(
    [switch]$Verbose
)

# Set execution policy and encoding
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Import required modules
$LoggerModulePath = Join-Path $PSScriptRoot "..\src\modules\Logger.ps1"
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

# Utility function to write test results
function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    if ($Passed) {
        Write-Host "PASS: $TestName" -ForegroundColor Green
        if ($Message) { Write-Host "   $Message" -ForegroundColor Gray }
        $script:TestsPassed++
    } else {
        Write-Host "FAIL: $TestName" -ForegroundColor Red
        if ($Message) { Write-Host "   $Message" -ForegroundColor Yellow }
        $script:TestsFailed++
    }
}

# Cleanup function
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

# Create test log files with specific dates
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
            Write-Host "Created test file: $($file.Name) (Age: $($file.DaysOld) days)" -ForegroundColor Cyan
        }
    }

    return $testFiles.Count
}

# Create test configuration
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

# Test function for specific retention period
function Test-LogRetention {
    param(
        [int]$RetentionDays,
        [string]$TestDescription
    )

    try {
        Write-Host "`Testing: $TestDescription" -ForegroundColor Cyan

        # Create fresh test environment
        Clear-TestEnvironment
        $null = New-TestLogFiles -LogDirectory $TestLogDir
        New-TestConfig -ConfigPath $TestConfigPath -RetentionDays $RetentionDays

        # Load test config
        $config = Get-Content -Path $TestConfigPath -Raw | ConvertFrom-Json
        $messages = @{} # Empty messages for test

        # Get file count before cleanup
        $filesBefore = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count

        # Initialize logger (this triggers cleanup)
        $null = [Logger]::new($config, $messages)

        # Get file count after cleanup
        $filesAfter = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count
        $filesDeleted = $filesBefore - $filesAfter

        if ($Verbose) {
            Write-Host "Files before: $filesBefore, Files after: $filesAfter, Deleted: $filesDeleted" -ForegroundColor Gray
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

# Main test execution
function Invoke-LogRotationTests {
    param()

    Write-Host "Starting Log Rotation Tests" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow

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
        Write-Host "`Testing: Invalid configuration handling" -ForegroundColor Cyan

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
        $config = Get-Content -Path $TestConfigPath -Raw | ConvertFrom-Json

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
        Write-Host "`Testing: Missing logging configuration" -ForegroundColor Cyan

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
        $config = Get-Content -Path $TestConfigPath -Raw | ConvertFrom-Json

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
    Write-Host "`n" + "=" * 50 -ForegroundColor Yellow
    Write-Host "Test Summary:" -ForegroundColor Yellow
    Write-Host "Passed: $TestsPassed" -ForegroundColor Green
    Write-Host "Failed: $TestsFailed" -ForegroundColor Red
    Write-Host "Success Rate: $([math]::Round(($TestsPassed / ($TestsPassed + $TestsFailed)) * 100, 1))%" -ForegroundColor $(if ($TestsFailed -eq 0) { "Green" } else { "Yellow" })

    if ($TestsFailed -eq 0) {
        Write-Host "`All tests passed! Log rotation feature is working correctly." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "` Some tests failed. Please review the implementation." -ForegroundColor Yellow
        exit 1
    }

} catch {
    Write-Host "`Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Clear-TestEnvironment
    exit 1
}
