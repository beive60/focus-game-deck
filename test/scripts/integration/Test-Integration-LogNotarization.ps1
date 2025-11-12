#Requires -Version 5.1

<#
.SYNOPSIS
    Tests the log notarization functionality with Firebase integration.

.DESCRIPTION
    This script creates a dummy log file, initializes the Logger with Firebase
    configuration, and tests the FinalizeAndNotarizeLogAsync method to ensure
    proper integration with Firebase Firestore.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-09-26

    Prerequisites:
    - Firebase project must be set up with Firestore enabled
    - Firebase API key and project ID must be configured in config.json
    - Internet connection required for Firebase API calls
#>

param(
    [switch]$Verbose,
    [switch]$NoCleanup
)

# Set up error handling and verbose preference
$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

# Initialize script variables
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
$messagesPath = Join-Path -Path $projectRoot -ChildPath "localization/messages.json"
$loggerModulePath = Join-Path -Path $projectRoot -ChildPath "src/modules/Logger.ps1"
$testLogDir = Join-Path -Path $PSScriptRoot -ChildPath "temp-logs"
$testLogFile = Join-Path $testLogDir "test-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Test results tracking
$testResults = @{
    Total   = 0
    Passed  = 0
    Failed  = 0
    Skipped = 0
}

function Write-TestHeader {
    param([string]$Title)

    Write-Host ""
    Write-Host "=" * 60
    Write-Host " $Title"
    Write-Host "=" * 60
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    $testResults.Total++

    if ($Passed) {
        $testResults.Passed++
        Write-Host "[OK] " -NoNewline
        Write-Host "$TestName"
        if ($Message) {
            Write-Host "  $Message"
        }
    } else {
        $testResults.Failed++
        Write-Host "[ERROR] " -NoNewline
        Write-Host "$TestName"
        if ($Message) {
            Write-Host "  Error: $Message"
        }
    }
}

function Write-TestSkipped {
    param(
        [string]$TestName,
        [string]$Reason
    )

    $testResults.Total++
    $testResults.Skipped++
    Write-Host "- " -NoNewline
    Write-Host "$TestName"
    Write-Host "  Skipped: $Reason"
}

function Test-Prerequisites {
    Write-TestHeader "Testing Prerequisites"

    # Test if Logger module exists
    try {
        if (Test-Path $loggerModulePath) {
            Write-TestResult "Logger module file exists" $true
        } else {
            Write-TestResult "Logger module file exists" $false "File not found: $loggerModulePath"
            return $false
        }
    } catch {
        Write-TestResult "Logger module file exists" $false $_.Exception.Message
        return $false
    }

    # Test if configuration file exists
    try {
        if (Test-Path $configPath) {
            Write-TestResult "Configuration file exists" $true
        } else {
            Write-TestResult "Configuration file exists" $false "File not found: $configPath"
            return $false
        }
    } catch {
        Write-TestResult "Configuration file exists" $false $_.Exception.Message
        return $false
    }

    # Test if messages file exists
    try {
        if (Test-Path $messagesPath) {
            Write-TestResult "Messages file exists" $true
        } else {
            Write-TestResult "Messages file exists" $false "File not found: $messagesPath"
            return $false
        }
    } catch {
        Write-TestResult "Messages file exists" $false $_.Exception.Message
        return $false
    }

    return $true
}

function Test-ConfigurationLoading {
    Write-TestHeader "Testing Configuration Loading"

    try {
        # Load configuration
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-TestResult "Configuration JSON parsing" $true

        # Check if logging section exists
        if ($config.logging) {
            Write-TestResult "Logging section exists" $true

            # Check Firebase configuration
            if ($config.logging.firebase) {
                Write-TestResult "Firebase configuration section exists" $true

                $hasRequiredFields = $true
                $missingFields = @()

                if (-not $config.logging.firebase.projectId -or $config.logging.firebase.projectId -eq "") {
                    $hasRequiredFields = $false
                    $missingFields += "projectId"
                }

                if (-not $config.logging.firebase.apiKey -or $config.logging.firebase.apiKey -eq "") {
                    $hasRequiredFields = $false
                    $missingFields += "apiKey"
                }

                if ($hasRequiredFields) {
                    Write-TestResult "Firebase required fields present" $true
                } else {
                    Write-TestSkipped "Firebase required fields present" "Missing fields: $($missingFields -join ', '). Configure Firebase settings in config.json"
                    return $false
                }
            } else {
                Write-TestSkipped "Firebase configuration section exists" "Firebase section missing in config.json"
                return $false
            }
        } else {
            Write-TestSkipped "Logging section exists" "Logging section missing in config.json"
            return $false
        }

        return $config
    } catch {
        Write-TestResult "Configuration loading" $false $_.Exception.Message
        return $false
    }
}

function Test-LoggerInitialization {
    param([object]$Config)

    Write-TestHeader "Testing Logger Initialization"

    try {
        # Load Logger module
        . $loggerModulePath
        Write-TestResult "Logger module import" $true

        # Load messages
        $messagesJson = Get-Content -Path $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-TestResult "Messages loading" $true

        # Initialize Logger using the Initialize-Logger function with English messages
        $logger = Initialize-Logger -Config $Config -Messages $messagesJson.en
        Write-TestResult "Logger initialization" $true

        # Test Logger properties
        if ($logger.EnableNotarization) {
            Write-TestResult "Log notarization enabled in Logger" $true
        } else {
            Write-TestSkipped "Log notarization enabled in Logger" "Notarization disabled in configuration"
        }

        return $logger
    } catch {
        Write-TestResult "Logger initialization" $false $_.Exception.Message
        return $null
    }
}

function Test-LogFileCreation {
    param($Logger)

    Write-TestHeader "Testing Log File Creation"

    try {
        # Create test log directory
        if (-not (Test-Path $testLogDir)) {
            New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null
        }
        Write-TestResult "Test log directory creation" $true

        # Update logger to use test log file
        $Logger.LogFilePath = $testLogFile
        $Logger.EnableFileLogging = $true

        # Write some test log entries
        $Logger.Info("Test log entry 1 - Starting notarization test", "TEST")
        $Logger.Info("Test log entry 2 - Simulating game session", "TEST")
        $Logger.Warning("Test log entry 3 - Sample warning message", "TEST")
        $Logger.Info("Test log entry 4 - Ending notarization test", "TEST")

        # Verify log file was created and has content
        if (Test-Path $testLogFile) {
            $logContent = Get-Content $testLogFile
            if ($logContent.Count -gt 0) {
                Write-TestResult "Log file creation and content" $true "Created log with $($logContent.Count) lines"
            } else {
                Write-TestResult "Log file creation and content" $false "Log file is empty"
                return $false
            }
        } else {
            Write-TestResult "Log file creation and content" $false "Log file was not created"
            return $false
        }

        return $true
    } catch {
        Write-TestResult "Log file creation" $false $_.Exception.Message
        return $false
    }
}

function Test-HashCalculation {
    param($Logger)

    Write-TestHeader "Testing Hash Calculation"

    try {
        # Test hash calculation using reflection to access private method
        $hashMethod = $Logger.GetType().GetMethod("GetLogFileHash", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)

        if ($hashMethod) {
            $hash = $hashMethod.Invoke($Logger, $null)

            if ($hash -and $hash.Length -eq 64) {
                Write-TestResult "SHA256 hash calculation" $true "Hash: $($hash.Substring(0, 16))..."
            } else {
                Write-TestResult "SHA256 hash calculation" $false "Invalid hash format or null result"
                return $false
            }
        } else {
            Write-TestResult "SHA256 hash calculation method access" $false "Could not access GetLogFileHash method"
            return $false
        }

        return $hash
    } catch {
        Write-TestResult "Hash calculation" $false $_.Exception.Message
        return $null
    }
}

function Test-SelfAuthentication {
    param($Logger)

    Write-TestHeader "Testing Self-Authentication Features"

    try {
        # Use reflection to access private properties for testing
        $loggerType = $Logger.GetType()

        # Test AppSignatureHash property
        $appSignatureHashField = $loggerType.GetField("AppSignatureHash", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
        if ($appSignatureHashField) {
            $appSignatureHash = $appSignatureHashField.GetValue($Logger)
            if ($appSignatureHash) {
                Write-TestResult "Application signature hash acquisition" $true "Hash: $($appSignatureHash.Substring(0, [Math]::Min(16, $appSignatureHash.Length)))..."
            } else {
                Write-TestResult "Application signature hash acquisition" $false "Hash is null or empty"
            }
        } else {
            Write-TestResult "Application signature hash field access" $false "Cannot access AppSignatureHash field"
        }

        # Test AppVersion property
        $appVersionField = $loggerType.GetField("AppVersion", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
        if ($appVersionField) {
            $appVersion = $appVersionField.GetValue($Logger)
            if ($appVersion) {
                Write-TestResult "Application version acquisition" $true "Version: $appVersion"
            } else {
                Write-TestResult "Application version acquisition" $false "Version is null or empty"
            }
        } else {
            Write-TestResult "Application version field access" $false "Cannot access AppVersion field"
        }

        # Test ExecutablePath property
        $executablePathField = $loggerType.GetField("ExecutablePath", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
        if ($executablePathField) {
            $executablePath = $executablePathField.GetValue($Logger)
            if ($executablePath) {
                Write-TestResult "Executable path detection" $true "Path: $executablePath"
            } else {
                Write-TestResult "Executable path detection" $false "Path is null or empty"
            }
        } else {
            Write-TestResult "Executable path field access" $false "Cannot access ExecutablePath field"
        }

        return $true
    } catch {
        Write-TestResult "Self-authentication testing" $false $_.Exception.Message
        return $false
    }
}

function Test-FirebaseIntegration {
    param($Logger)

    Write-TestHeader "Testing Firebase Integration with Enhanced Data"

    try {
        # Test the full notarization process
        Write-Host "Attempting to notarize log file with self-authentication data..."

        $certificateId = $Logger.FinalizeAndNotarizeLogAsync()

        if ($certificateId) {
            Write-TestResult "Firebase log notarization with authentication data" $true "Certificate ID: $certificateId"
            Write-Host "  You can verify this record in your Firebase Console"
            Write-Host "  The record should include:"
            Write-Host "    - logHash: SHA256 hash of the log file"
            Write-Host "    - appSignatureHash: Digital signature hash of the executable"
            Write-Host "    - appVersion: Application version from Version.ps1"
            Write-Host "    - executablePath: Path to the running executable"
            Write-Host "    - clientTimestamp: Client-side timestamp"
            Write-Host "    - serverTimestamp: Server-side timestamp"
            return $certificateId
        } else {
            Write-TestResult "Firebase log notarization with authentication data" $false "No certificate ID returned"
            return $null
        }
    } catch {
        Write-TestResult "Firebase integration with authentication" $false $_.Exception.Message
        return $null
    }
}

function Test-Cleanup {
    Write-TestHeader "Cleanup"

    if (-not $NoCleanup) {
        try {
            if (Test-Path $testLogDir) {
                Remove-Item -Path $testLogDir -Recurse -Force
                Write-TestResult "Test files cleanup" $true
            }
        } catch {
            Write-TestResult "Test files cleanup" $false $_.Exception.Message
        }
    } else {
        Write-Host "Cleanup skipped due to -NoCleanup flag"
        Write-Host "Test files location: $testLogDir"
    }
}

function Show-TestSummary {
    Write-TestHeader "Test Summary"

    Write-Host "Total Tests: " -NoNewline
    Write-Host $testResults.Total

    Write-Host "Passed: " -NoNewline
    Write-Host $testResults.Passed

    Write-Host "Failed: " -NoNewline
    Write-Host $testResults.Failed

    Write-Host "Skipped: " -NoNewline
    Write-Host $testResults.Skipped

    $successRate = if ($testResults.Total -gt 0) {
        [math]::Round(($testResults.Passed / $testResults.Total) * 100, 1)
    } else {
        0
    }

    Write-Host "Success Rate: " -NoNewline
    if ($successRate -ge 80) {
        Write-Host "[OK] $successRate%"
    } elseif ($successRate -ge 60) {
        Write-Host "[WARNING] $successRate%"
    } else {
        Write-Host "[ERROR] $successRate%"
    }

    if ($testResults.Failed -eq 0 -and $testResults.Passed -gt 0) {
        Write-Host ""
        Write-Host "[OK] All tests passed! Log notarization system is working correctly."
    } elseif ($testResults.Failed -gt 0) {
        Write-Host ""
        Write-Host "[WARNING] Some tests failed. Please check the configuration and Firebase setup."
    }
}

# Main test execution
try {
    Write-Host "Focus Game Deck - Log Notarization Test"
    Write-Host "Testing Firebase integration and log integrity verification"
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # Run test sequence
    $prerequisitesOk = Test-Prerequisites
    if (-not $prerequisitesOk) {
        Write-Host "Prerequisites test failed. Aborting remaining tests."
        Show-TestSummary
        exit 1
    }

    $config = Test-ConfigurationLoading
    if (-not $config) {
        Write-Host "Configuration test failed. Aborting remaining tests."
        Show-TestSummary
        exit 1
    }

    $logger = Test-LoggerInitialization -Config $config
    if (-not $logger) {
        Write-Host "Logger initialization failed. Aborting remaining tests."
        Show-TestSummary
        exit 1
    }

    $logFileOk = Test-LogFileCreation -Logger $logger
    if (-not $logFileOk) {
        Write-Host "Log file creation failed. Aborting remaining tests."
        Show-TestSummary
        exit 1
    }

    $hash = Test-HashCalculation -Logger $logger

    # Test self-authentication features
    $selfAuthOk = Test-SelfAuthentication -Logger $logger

    # Only test Firebase if notarization is enabled and configured
    if ($logger.EnableNotarization) {
        $certificateId = Test-FirebaseIntegration -Logger $logger
    } else {
        Write-TestSkipped "Firebase Integration Test with Enhanced Data" "Log notarization is disabled"
    }

    Test-Cleanup
    Show-TestSummary

    # Exit with appropriate code
    exit $(if ($testResults.Failed -eq 0) { 0 } else { 1 })

} catch {
    Write-Host ""
    Write-Host "Unexpected error during test execution:"
    Write-Host $_.Exception.Message
    Write-Host $_.ScriptStackTrace

    Test-Cleanup
    Show-TestSummary
    exit 1
}
