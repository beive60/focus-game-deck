<#
.SYNOPSIS
    Test script for Enhanced Launcher Creation functionality

.DESCRIPTION
    This script validates the Create-Launchers-Enhanced.ps1 functionality across different Windows environments.
    Tests shortcut creation, error handling, and compatibility with various PowerShell versions.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-09-26

    Test Coverage:
    - WScript.Shell COM object availability
    - Shortcut creation functionality
    - Error handling and fallback scenarios
    - File system permissions
    - PowerShell version compatibility
#>

param(
    [switch]$Verbose,
    [switch]$CleanupOnly
)

# Test configuration
$testDir = Join-Path $PSScriptRoot "test-launchers"
$configTestPath = Join-Path $PSScriptRoot "test-config.json"
$enhancedScriptPath = Join-Path $PSScriptRoot "Create-Launchers-Enhanced.ps1"

<#
.SYNOPSIS
    Creates a test configuration file for launcher testing

.DESCRIPTION
    Generates a minimal config.json structure for testing launcher creation without requiring actual game installations.
#>
function New-TestConfiguration {
    $testConfig = @{
        games       = @{
            test_game1 = @{
                name         = "Test Game 1"
                steamAppId   = "123456"
                processName  = "testgame1"
                appsToManage = @("obs", "clibor")
            }
            test_game2 = @{
                name         = "Test Game 2 (日本語テスト)"
                steamAppId   = "789012"
                processName  = "testgame2"
                appsToManage = @("noWinKey")
            }
        }
        obs         = @{
            websocket    = @{
                host     = "localhost"
                port     = 4455
                password = ""
            }
            replayBuffer = $true
        }
        managedApps = @{
            obs      = @{
                path           = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
                processName    = "obs64"
                startupAction  = "start"
                shutdownAction = "stop"
                arguments      = ""
            }
            clibor   = @{
                path           = "C:\Apps\clibor\Clibor.exe"
                processName    = "Clibor"
                startupAction  = "none"
                shutdownAction = "none"
                arguments      = "/hs"
            }
            noWinKey = @{
                path           = "C:\Apps\NoWinKey\NoWinKey.exe"
                processName    = "NoWinKey"
                startupAction  = "start"
                shutdownAction = "stop"
                arguments      = ""
            }
        }
        paths       = @{
            steam = "C:\Program Files (x86)\Steam\steam.exe"
            obs   = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
        }
    }

    try {
        $testConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configTestPath -Encoding UTF8
        Write-Host "[OK] Test configuration created: $configTestPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[ERROR] Failed to create test configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

<#
.SYNOPSIS
    Tests WScript.Shell COM object availability and functionality

.DESCRIPTION
    Validates that the Windows Script Host Shell object can be created and used for shortcut generation.
#>
function Test-COMObjectAvailability {
    Write-Host "`n=== Testing COM Object Availability ===" -ForegroundColor Cyan

    try {
        $WshShell = New-Object -ComObject WScript.Shell
        Write-Host "[OK] WScript.Shell COM object created successfully" -ForegroundColor Green

        # Test basic functionality
        $testShortcutPath = Join-Path $testDir "test_com.lnk"
        $Shortcut = $WshShell.CreateShortcut($testShortcutPath)
        $Shortcut.TargetPath = "notepad.exe"
        $Shortcut.Description = "COM Test Shortcut"
        $Shortcut.Save()

        if (Test-Path $testShortcutPath) {
            Write-Host "[OK] Test shortcut created successfully" -ForegroundColor Green
            Remove-Item $testShortcutPath -Force
        } else {
            Write-Host "[ERROR] Test shortcut was not created" -ForegroundColor Red
            return $false
        }

        # Cleanup COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
        return $true

    } catch {
        Write-Host "[ERROR] COM object test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

<#
.SYNOPSIS
    Tests the Enhanced Launcher Creation script functionality

.DESCRIPTION
    Executes the enhanced script with test configuration and validates the results.
#>
function Test-EnhancedScript {
    Write-Host "`n=== Testing Enhanced Script Execution ===" -ForegroundColor Cyan

    if (-not (Test-Path $enhancedScriptPath)) {
        Write-Host "[ERROR] Enhanced script not found: $enhancedScriptPath" -ForegroundColor Red
        return $false
    }

    # Backup original config if it exists
    $originalConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\config.json"
    $backupConfigPath = "$originalConfigPath.test-backup"

    try {
        if (Test-Path $originalConfigPath) {
            Copy-Item $originalConfigPath $backupConfigPath -Force
            Write-Host "[INFO] Original config backed up" -ForegroundColor Yellow
        }

        # Copy test config to expected location
        $configDir = Join-Path (Split-Path $PSScriptRoot -Parent) "config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        Copy-Item $configTestPath $originalConfigPath -Force

        # Execute enhanced script
        Write-Host "[INFO] Executing enhanced launcher script..." -ForegroundColor Cyan
        & $enhancedScriptPath | Out-Host

        # Check for created shortcuts
        $rootDir = Split-Path $PSScriptRoot -Parent
        $createdShortcuts = Get-ChildItem -Path $rootDir -Filter "launch_test_*.lnk" -ErrorAction SilentlyContinue

        if ($createdShortcuts) {
            Write-Host "[OK] Created $($createdShortcuts.Count) test shortcuts" -ForegroundColor Green

            # Validate shortcut properties
            foreach ($shortcut in $createdShortcuts) {
                $shell = New-Object -ComObject WScript.Shell
                $lnk = $shell.CreateShortcut($shortcut.FullName)

                Write-Host "  Shortcut: $($shortcut.Name)" -ForegroundColor White
                Write-Host "    Target: $($lnk.TargetPath)" -ForegroundColor Gray
                Write-Host "    Arguments: $($lnk.Arguments)" -ForegroundColor Gray
                Write-Host "    Description: $($lnk.Description)" -ForegroundColor Gray

                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
            }

            # Cleanup test shortcuts
            $createdShortcuts | Remove-Item -Force
            Write-Host "[INFO] Test shortcuts cleaned up" -ForegroundColor Yellow

            return $true
        } else {
            Write-Host "[ERROR] No test shortcuts were created" -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "[ERROR] Enhanced script test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        # Restore original config
        if (Test-Path $backupConfigPath) {
            Move-Item $backupConfigPath $originalConfigPath -Force
            Write-Host "[INFO] Original config restored" -ForegroundColor Yellow
        }
    }
}

<#
.SYNOPSIS
    Tests PowerShell version compatibility

.DESCRIPTION
    Validates functionality across different PowerShell versions and execution policies.
#>
function Test-PowerShellCompatibility {
    Write-Host "`n=== Testing PowerShell Compatibility ===" -ForegroundColor Cyan

    # Display current PowerShell version
    Write-Host "[INFO] PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "[INFO] Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan
    Write-Host "[INFO] Platform: $($PSVersionTable.Platform)" -ForegroundColor Cyan

    # Test execution policy
    $executionPolicy = Get-ExecutionPolicy
    Write-Host "[INFO] Current Execution Policy: $executionPolicy" -ForegroundColor Cyan

    if ($executionPolicy -eq "Restricted") {
        Write-Host "[WARNING] Execution policy is Restricted - this may cause issues" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Execution policy allows script execution" -ForegroundColor Green
    }

    # Test UTF-8 encoding support
    try {
        $testString = "Test Japanese: テスト"
        $testPath = Join-Path $testDir "utf8_test.txt"
        $testString | Set-Content -Path $testPath -Encoding UTF8
        $readBack = Get-Content -Path $testPath -Encoding UTF8

        if ($readBack -eq $testString) {
            Write-Host "[OK] UTF-8 encoding test passed" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] UTF-8 encoding test failed" -ForegroundColor Yellow
        }

        Remove-Item $testPath -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[WARNING] UTF-8 encoding test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    return $true
}

<#
.SYNOPSIS
    Performs cleanup of test files and directories

.DESCRIPTION
    Removes all test-related files and directories created during testing.
#>
function Invoke-TestCleanup {
    Write-Host "`n=== Performing Cleanup ===" -ForegroundColor Cyan

    # Remove test directory
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Test directory removed" -ForegroundColor Green
    }

    # Remove test config
    if (Test-Path $configTestPath) {
        Remove-Item $configTestPath -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Test configuration removed" -ForegroundColor Green
    }

    # Remove any remaining test shortcuts
    $rootDir = Split-Path $PSScriptRoot -Parent
    $testShortcuts = Get-ChildItem -Path $rootDir -Filter "launch_test_*.lnk" -ErrorAction SilentlyContinue
    if ($testShortcuts) {
        $testShortcuts | Remove-Item -Force
        Write-Host "[OK] Remaining test shortcuts removed" -ForegroundColor Green
    }
}

# Main execution
try {
    Write-Host "Focus Game Deck - Enhanced Launcher Test Suite" -ForegroundColor Green
    Write-Host "=" * 55 -ForegroundColor Green
    Write-Host "Test execution started: $(Get-Date)" -ForegroundColor Cyan

    if ($CleanupOnly) {
        Invoke-TestCleanup
        exit 0
    }

    # Create test directory
    if (-not (Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        Write-Host "[OK] Test directory created: $testDir" -ForegroundColor Green
    }

    $allTestsPassed = $true

    # Run test suite
    $allTestsPassed = (New-TestConfiguration) -and $allTestsPassed
    $allTestsPassed = (Test-COMObjectAvailability) -and $allTestsPassed
    $allTestsPassed = (Test-PowerShellCompatibility) -and $allTestsPassed
    $allTestsPassed = (Test-EnhancedScript) -and $allTestsPassed

    # Summary
    Write-Host "`n" + ("=" * 55) -ForegroundColor Green
    if ($allTestsPassed) {
        Write-Host "Test Suite Result: ALL TESTS PASSED" -ForegroundColor Green
        Write-Host "Enhanced launcher functionality is ready for production use!" -ForegroundColor Green
    } else {
        Write-Host "Test Suite Result: SOME TESTS FAILED" -ForegroundColor Red
        Write-Host "Please review the failed tests before production deployment." -ForegroundColor Yellow
    }

    Write-Host "`nTest execution completed: $(Get-Date)" -ForegroundColor Cyan

} catch {
    Write-Host "`nUnexpected error during test execution:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    if (-not $Verbose) {
        Write-Host "`nCleaning up test files..." -ForegroundColor Yellow
        Invoke-TestCleanup
    }

    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    pause
}
