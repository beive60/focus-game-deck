<#
.SYNOPSIS
    Logger Module - Centralized logging functionality with multiple levels and output options.

.DESCRIPTION
    This module provides a comprehensive logging system with support for:
    - Multiple log levels (Trace, Debug, Info, Warning, Error, Critical)
    - Console and file output
    - Log rotation and retention policies
    - Log notarization using Firebase
    - Self-authentication for log integrity verification

.NOTES
    File Name  : Logger.ps1
    Author     : Focus Game Deck Team
    Requires   : PowerShell 5.1 or later
#>

<#
.SYNOPSIS
    Defines log severity levels.

.DESCRIPTION
    Enumeration of available log levels from least to most severe:
    - Trace (0): Detailed diagnostic information
    - Debug (1): Debug-level messages
    - Info (2): Informational messages
    - Warning (3): Warning messages
    - Error (4): Error messages
    - Critical (5): Critical error messages
#>
enum LogLevel {
    Trace = 0
    Debug = 1
    Info = 2
    Warning = 3
    Error = 4
    Critical = 5
}

<#
.SYNOPSIS
    Main logging class for Focus Game Deck.

.DESCRIPTION
    Provides centralized logging functionality with support for multiple output targets,
    log rotation, retention policies, and optional log notarization for integrity verification.

.EXAMPLE
    $logger = [Logger]::new($config, $messages)
    $logger.Info("Application started", "MAIN")

.EXAMPLE
    $logger = [Logger]::new($config, $messages)
    $logger.Error("Failed to connect to service", "NETWORK")
#>
class Logger {
    [string] $LogFilePath
    [LogLevel] $MinimumLevel
    [bool] $EnableFileLogging
    [bool] $EnableConsoleLogging
    [bool] $EnableNotarization
    [object] $Messages

    # Firebase configuration for log notarization
    hidden [string] $FirebaseProjectId
    hidden [string] $FirebaseApiKey
    hidden [string] $FirebaseDatabaseURL

    # Self-authentication properties for log integrity verification
    hidden [string] $AppSignatureHash
    hidden [string] $AppVersion
    hidden [string] $ExecutablePath

    <#
    .SYNOPSIS
        Initializes a new Logger instance.

    .DESCRIPTION
        Creates a new logger with configuration from the provided config object.
        Sets up logging targets, retention policies, and authentication properties.

    .PARAMETER config
        Configuration object containing logging settings (level, file path, retention, etc.)

    .PARAMETER messages
        Localization messages object for internationalized log messages

    .PARAMETER appRoot
        Application root directory for resolving log file paths (optional, defaults to calculating from $PSScriptRoot)

    .EXAMPLE
        $logger = [Logger]::new($config, $messages, $appRoot)
    #>
    Logger([object] $config, [object] $messages) {
        $this.InitializeLogger($config, $messages, $null)
    }
    
    Logger([object] $config, [object] $messages, [string] $appRoot) {
        $this.InitializeLogger($config, $messages, $appRoot)
    }
    
    hidden [void] InitializeLogger([object] $config, [object] $messages, [string] $appRoot) {
        $this.Messages = $messages
        $this.MinimumLevel = [LogLevel]::Info
        $this.EnableConsoleLogging = $true
        $this.EnableFileLogging = $false
        $this.EnableNotarization = $false

        if ($config.logging) {
            if ($config.logging.level) {
                $this.MinimumLevel = [LogLevel]::$($config.logging.level)
            }

            if ($config.logging.enableFileLogging) {
                $this.EnableFileLogging = $config.logging.enableFileLogging
            }

            if ($config.logging.enableConsoleLogging) {
                $this.EnableConsoleLogging = $config.logging.enableConsoleLogging
            }

            if ($config.logging.enableNotarization) {
                $this.EnableNotarization = $config.logging.enableNotarization
            }

            if ($config.logging.filePath) {
                $this.LogFilePath = $config.logging.filePath
            } else {
                # Use $appRoot if provided, otherwise fall back to $PSScriptRoot (development mode)
                if ($appRoot) {
                    $this.LogFilePath = Join-Path $appRoot "logs/focus-game-deck.log"
                } else {
                    # Fallback for development mode - calculate from module location
                    # Logger.ps1 is in src/modules, so go up two levels
                    $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
                    $this.LogFilePath = Join-Path $modulePath "logs/focus-game-deck.log"
                }
            }

            # Initialize Firebase configuration for log notarization
            if ($config.logging.firebase) {
                $this.FirebaseProjectId = $config.logging.firebase.projectId
                $this.FirebaseApiKey = $config.logging.firebase.apiKey
                $this.FirebaseDatabaseURL = $config.logging.firebase.databaseURL
            }
        } else {
            # Use $appRoot if provided, otherwise fall back to $PSScriptRoot (development mode)
            if ($appRoot) {
                $this.LogFilePath = Join-Path $appRoot "logs/focus-game-deck.log"
            } else {
                # Fallback for development mode
                $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
                $this.LogFilePath = Join-Path $modulePath "logs/focus-game-deck.log"
            }
        }

        # Ensure log directory exists
        if ($this.EnableFileLogging) {
            $logDir = Split-Path $this.LogFilePath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
        }

        # Clean up old log files based on retention policy
        if ($this.EnableFileLogging) {
            $this.CleanupOldLogs($config)
        }

        # Initialize self-authentication properties for log integrity verification
        $this.InitializeSelfAuthentication()
    }

    <#
    .SYNOPSIS
        Main logging method for all log levels.

    .DESCRIPTION
        Writes a log entry with the specified level, message, and component.
        Respects the minimum log level and outputs to configured targets.

    .PARAMETER level
        The severity level of the log entry (LogLevel enum)

    .PARAMETER message
        The log message text

    .PARAMETER component
        The component or module name generating the log entry (default: "MAIN")

    .EXAMPLE
        $logger.Log([LogLevel]::Info, "Application started", "MAIN")
    #>
    [void] Log([LogLevel] $level, [string] $message, [string] $component = "MAIN") {
        if ($level -lt $this.MinimumLevel) {
            return
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $levelStr = $level.ToString().ToUpper().PadRight(8)
        $logEntry = "[$timestamp] [$levelStr] [$component] $message"

        # Console logging
        if ($this.EnableConsoleLogging) {
            $this.WriteToConsole($level, $logEntry)
        }

        # File logging
        if ($this.EnableFileLogging) {
            try {
                Add-Content -Path $this.LogFilePath -Value $logEntry -Encoding UTF8
            } catch {
                Write-Warning "Failed to write to log file: $_"
            }
        }
    }

    <#
    .SYNOPSIS
        Writes a log entry to the console with appropriate colors.

    .DESCRIPTION
        Outputs log entries to the console with color coding based on severity level.

    .PARAMETER level
        The severity level (determines output color)

    .PARAMETER logEntry
        The formatted log entry text to display

    .EXAMPLE
        $logger.WriteToConsole([LogLevel]::Warning, "[2024-01-01] [WARNING] Test warning")
    #>
    [void] WriteToConsole([LogLevel] $level, [string] $logEntry) {
        switch ($level) {
            ([LogLevel]::Trace) {
                Write-Host $logEntry
            }
            ([LogLevel]::Debug) {
                Write-Host $logEntry
            }
            ([LogLevel]::Info) {
                Write-Host $logEntry
            }
            ([LogLevel]::Warning) {
                Write-Host $logEntry
            }
            ([LogLevel]::Error) {
                Write-Host $logEntry
            }
            ([LogLevel]::Critical) {
                Write-Host $logEntry
            }
        }
    }

    <#
    .SYNOPSIS
        Logs a trace-level message.

    .DESCRIPTION
        Convenience method for logging detailed diagnostic information.

    .PARAMETER message
        The trace message text

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.Trace("Entering function ProcessData", "DATA")
    #>
    [void] Trace([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Trace, $message, $component)
    }

    <#
    .SYNOPSIS
        Logs a debug-level message.

    .DESCRIPTION
        Convenience method for logging debug information.

    .PARAMETER message
        The debug message text

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.Debug("Processing item 42", "PROCESS")
    #>
    [void] Debug([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Debug, $message, $component)
    }

    <#
    .SYNOPSIS
        Logs an informational message.

    .DESCRIPTION
        Convenience method for logging general informational messages.

    .PARAMETER message
        The information message text

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.Info("Application initialized successfully", "MAIN")
    #>
    [void] Info([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Info, $message, $component)
    }

    <#
    .SYNOPSIS
        Logs a warning message.

    .DESCRIPTION
        Convenience method for logging warning messages.

    .PARAMETER message
        The warning message text

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.Warning("Configuration file not found, using defaults", "CONFIG")
    #>
    [void] Warning([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Warning, $message, $component)
    }

    <#
    .SYNOPSIS
        Logs an error message.

    .DESCRIPTION
        Convenience method for logging error messages.

    .PARAMETER message
        The error message text

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.Error("Failed to connect to database", "DATABASE")
    #>
    [void] Error([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Error, $message, $component)
    }

    <#
    .SYNOPSIS
        Logs a critical error message.

    .DESCRIPTION
        Convenience method for logging critical error messages that may require immediate attention.

    .PARAMETER message
        The critical error message text

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.Critical("System integrity check failed", "SECURITY")
    #>
    [void] Critical([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Critical, $message, $component)
    }

    <#
    .SYNOPSIS
        Logs an exception with full details including stack trace.

    .DESCRIPTION
        Logs exception information including message and stack trace at Error level.

    .PARAMETER exception
        The exception object to log

    .PARAMETER context
        Additional context about where the exception occurred

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        try {
            # Some code
        } catch {
            $logger.LogException($_.Exception, "ProcessData", "DATA")
        }
    #>
    [void] LogException([System.Exception] $exception, [string] $context = "", [string] $component = "MAIN") {
        $message = "Exception in $context : $($exception.Message)"
        if ($exception.StackTrace) {
            $message += "`nStack Trace: $($exception.StackTrace)"
        }
        $this.Error($message, $component)
    }

    <#
    .SYNOPSIS
        Logs the start of an operation.

    .DESCRIPTION
        Records when an operation begins, useful for tracking operation flow.

    .PARAMETER operationName
        The name of the operation being started

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $logger.LogOperationStart("Database Migration", "DATABASE")
    #>
    [void] LogOperationStart([string] $operationName, [string] $component = "MAIN") {
        $this.Info("Starting operation: $operationName", $component)
    }

    <#
    .SYNOPSIS
        Logs the completion of an operation with duration.

    .DESCRIPTION
        Records when an operation completes and calculates its duration.

    .PARAMETER operationName
        The name of the operation that completed

    .PARAMETER startTime
        The DateTime when the operation started

    .PARAMETER component
        The component or module name (default: "MAIN")

    .EXAMPLE
        $startTime = Get-Date
        # ... operation code ...
        $logger.LogOperationEnd("Database Migration", $startTime, "DATABASE")
    #>
    [void] LogOperationEnd([string] $operationName, [datetime] $startTime, [string] $component = "MAIN") {
        $duration = (Get-Date) - $startTime
        $this.Info("Completed operation: $operationName (Duration: $($duration.TotalMilliseconds)ms)", $component)
    }

    <#
    .SYNOPSIS
        Cleans up old log files based on retention policy.

    .DESCRIPTION
        Removes log files older than the configured retention period to manage disk space.
        Supports unlimited retention with -1 value.

    .PARAMETER config
        Configuration object containing log retention settings

    .EXAMPLE
        $logger.CleanupOldLogs($config)

    .NOTES
        Default retention period is 90 days if not specified.
        Use -1 for unlimited retention (no cleanup).
    #>
    hidden [void] CleanupOldLogs([object] $config) {
        try {
            # Get log retention days from config, default to 90 if not specified or invalid
            $retentionDays = 90
            if ($config.logging -and $config.logging.logRetentionDays) {
                $configuredDays = $config.logging.logRetentionDays
                if ($configuredDays -is [int] -and $configuredDays -gt 0) {
                    $retentionDays = $configuredDays
                } elseif ($configuredDays -eq -1) {
                    # Special value -1 means unlimited retention (no cleanup)
                    $this.Debug("Log retention set to unlimited - skipping cleanup", "CLEANUP")
                    return
                }
            }

            $this.Debug("Log retention period: $retentionDays days", "CLEANUP")

            # Get log directory from log file path
            $logDir = Split-Path $this.LogFilePath -Parent
            if (-not (Test-Path $logDir)) {
                $this.Debug("Log directory does not exist - skipping cleanup", "CLEANUP")
                return
            }

            # Get all log files in the directory
            $logFiles = Get-ChildItem -Path $logDir -Filter "*.log" -File -ErrorAction SilentlyContinue

            if (-not $logFiles -or $logFiles.Count -eq 0) {
                $this.Debug("No log files found - skipping cleanup", "CLEANUP")
                return
            }

            # Calculate cutoff date
            $cutoffDate = (Get-Date).AddDays(-$retentionDays)
            $this.Debug("Cutoff date for log cleanup: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))", "CLEANUP")

            # Find and delete old log files
            $deletedCount = 0
            $totalSize = 0

            foreach ($logFile in $logFiles) {
                try {
                    if ($logFile.LastWriteTime -le $cutoffDate) {
                        $fileSize = $logFile.Length
                        $this.Debug("Deleting old log file: $($logFile.Name) (Last modified: $($logFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))", "CLEANUP")

                        Remove-Item -Path $logFile.FullName -Force -ErrorAction Stop
                        $deletedCount++
                        $totalSize += $fileSize
                    }
                } catch {
                    $this.Warning("Failed to delete log file '$($logFile.Name)': $($_.Exception.Message)", "CLEANUP")
                }
            }

            if ($deletedCount -gt 0) {
                $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
                if ($this.Messages -and $this.Messages.loggerCleanupCompleted) {
                    $msg = $this.Messages.loggerCleanupCompleted -f $deletedCount, $totalSizeMB
                    $this.Info($msg, "CLEANUP")
                } else {
                    $this.Info("Cleaned up $deletedCount old log file(s), freed $totalSizeMB MB of disk space", "CLEANUP")
                }
            } else {
                $this.Debug("No old log files found for cleanup", "CLEANUP")
            }

        } catch {
            $this.Warning("Error during log cleanup: $($_.Exception.Message)", "CLEANUP")
        }
    }

    <#
    .SYNOPSIS
        Initializes self-authentication properties using digital signature information.

    .DESCRIPTION
        Retrieves and stores the application's digital signature hash, version, and executable path
        for log integrity verification and authentication purposes.

    .EXAMPLE
        $logger.InitializeSelfAuthentication()

    .NOTES
        Sets AppSignatureHash to special values for unsigned builds or verification errors.
    #>
    hidden [void] InitializeSelfAuthentication() {
        try {
            # Get the path of the currently executing script or executable
            $currentPath = $null

            # Try to get the executable path if running from an .exe
            if ($PSCommandPath) {
                $currentPath = $PSCommandPath
            } else {
                # Fallback: try to find the main executable in common locations
                $possiblePaths = @(
                    (Join-Path $PSScriptRoot "../..\release/Focus-Game-Deck.exe"),
                    (Join-Path $PSScriptRoot "../../build/Focus-Game-Deck.exe"),
                    (Join-Path $PSScriptRoot "../../Focus-Game-Deck.exe")
                )

                foreach ($path in $possiblePaths) {
                    if (Test-Path $path) {
                        $currentPath = $path
                        break
                    }
                }
            }

            $this.ExecutablePath = $currentPath

            if ($currentPath -and (Test-Path $currentPath)) {
                # Get digital signature information
                $signature = Get-AuthenticodeSignature -FilePath $currentPath -ErrorAction SilentlyContinue

                if ($signature -and $signature.Status -eq "Valid" -and $signature.SignerCertificate) {
                    # Extract hash from the signature
                    $this.AppSignatureHash = $signature.SignerCertificate.Thumbprint
                    $this.Debug("Digital signature found - Hash: $($this.AppSignatureHash)", "AUTH")
                } elseif ($signature -and $signature.Status -ne "NotSigned") {
                    # Signature exists but may be invalid or untrusted
                    $this.AppSignatureHash = "INVALID_SIGNATURE_$($signature.Status.ToString().ToUpper())"
                    $this.Warning("Digital signature found but status is: $($signature.Status)", "AUTH")
                } else {
                    # No signature found - likely development build
                    $this.AppSignatureHash = "UNSIGNED_DEVELOPMENT_BUILD"
                    $this.Debug("No digital signature found - using development identifier", "AUTH")
                }
            } else {
                # Could not determine executable path
                $this.AppSignatureHash = "UNKNOWN_EXECUTABLE_PATH"
                $this.Warning("Could not determine executable path for signature verification", "AUTH")
            }

            # Get application version from Version.ps1
            $this.AppVersion = $this.GetApplicationVersion()
            $this.Debug("Application version: $($this.AppVersion)", "AUTH")

        } catch {
            # Error during signature verification
            $this.AppSignatureHash = "SIGNATURE_VERIFICATION_ERROR"
            $this.AppVersion = "VERSION_UNKNOWN"
            $this.Warning("Failed to initialize self-authentication: $($_.Exception.Message)", "AUTH")
        }
    }

    <#
    .SYNOPSIS
        Retrieves the application version from Version.ps1.

    .DESCRIPTION
        Executes the Version.ps1 script to get the current application version string.

    .OUTPUTS
        String containing the version number, or error message if retrieval fails.

    .EXAMPLE
        $version = $logger.GetApplicationVersion()
    #>
    hidden [string] GetApplicationVersion() {
        try {
            $versionScriptPath = Join-Path $PSScriptRoot "../../Version.ps1"

            if (Test-Path $versionScriptPath) {
                # Execute Version.ps1 in isolated scope to get version information
                $versionInfo = & {
                    . $versionScriptPath
                    Get-ProjectVersion -IncludePreRelease
                }

                if ($versionInfo) {
                    return $versionInfo
                } else {
                    return "VERSION_SCRIPT_ERROR"
                }
            } else {
                return "VERSION_SCRIPT_NOT_FOUND"
            }
        } catch {
            return "VERSION_RETRIEVAL_ERROR"
        }
    }

    <#
    .SYNOPSIS
        Rotates the log file if it exceeds the maximum size.

    .DESCRIPTION
        Creates a backup of the current log file and starts a new one if the file size
        exceeds the specified maximum.

    .PARAMETER maxSizeMB
        Maximum log file size in megabytes (default: 10 MB)

    .EXAMPLE
        $logger.RotateLogFile(20)

    .NOTES
        Backup files are named with timestamp: filename-backup-yyyyMMdd-HHmmss.log
    #>
    [void] RotateLogFile([int] $maxSizeMB = 10) {
        if (-not $this.EnableFileLogging -or -not (Test-Path $this.LogFilePath)) {
            return
        }

        $logFile = Get-Item $this.LogFilePath
        $fileSizeMB = $logFile.Length / 1MB

        if ($fileSizeMB -gt $maxSizeMB) {
            $backupPath = $this.LogFilePath -replace '/.log$', "-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            Move-Item -Path $this.LogFilePath -Destination $backupPath
            if ($this.Messages -and $this.Messages.loggerLogRotated) {
                $msg = $this.Messages.loggerLogRotated -f $backupPath
                $this.Info($msg, "LOGGER")
            } else {
                $this.Info("Log file rotated. Backup created: $backupPath", "LOGGER")
            }
        }
    }

    <#
    .SYNOPSIS
        Calculates the SHA256 hash of the log file.

    .DESCRIPTION
        Computes the SHA256 hash of the current log file for integrity verification.

    .OUTPUTS
        String containing the SHA256 hash, or null if calculation fails.

    .EXAMPLE
        $hash = $logger.GetLogFileHash()
    #>
    hidden [string] GetLogFileHash() {
        if (-not (Test-Path $this.LogFilePath)) {
            return $null
        }

        try {
            $hash = Get-FileHash -Path $this.LogFilePath -Algorithm SHA256
            return $hash.Hash
        } catch {
            $this.Error("Failed to calculate log file hash: $_", "NOTARY")
            return $null
        }
    }

    <#
    .SYNOPSIS
        Sends log hash to Firebase for notarization.

    .DESCRIPTION
        Uploads the log file hash along with authentication data to Firebase Firestore
        for tamper-proof timestamping and verification.

    .PARAMETER hash
        The SHA256 hash of the log file

    .PARAMETER clientTimestamp
        ISO 8601 formatted timestamp from the client

    .OUTPUTS
        Firebase response object containing the document ID and metadata

    .EXAMPLE
        $response = $logger.SendHashToFirebase($hash, $timestamp)

    .NOTES
        Requires Firebase configuration (project ID and API key) to be set.
    #>
    hidden [object] SendHashToFirebase([string] $hash, [string] $clientTimestamp) {
        if (-not $this.FirebaseProjectId -or -not $this.FirebaseApiKey) {
            throw "Firebase configuration is not properly set"
        }

        $firestoreUrl = "https://firestore.googleapis.com/v1/projects/$($this.FirebaseProjectId)/databases/(default)/documents/log_hashes"

        $body = @{
            fields = @{
                logHash = @{
                    stringValue = $hash
                }
                clientTimestamp = @{
                    stringValue = $clientTimestamp
                }
                serverTimestamp = @{
                    timestampValue = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                }
                appSignatureHash = @{
                    stringValue = $this.AppSignatureHash
                }
                appVersion = @{
                    stringValue = $this.AppVersion
                }
                executablePath = @{
                    stringValue = if ($this.ExecutablePath) { $this.ExecutablePath } else { "UNKNOWN" }
                }
            }
        } | ConvertTo-Json -Depth 5

        $headers = @{
            'Content-Type' = 'application/json'
            'Authorization' = "Bearer $($this.FirebaseApiKey)"
        }

        try {
            $response = Invoke-RestMethod -Uri $firestoreUrl -Method POST -Body $body -Headers $headers -TimeoutSec 30
            return $response
        } catch {
            # Re-throw with more context
            throw "Failed to send hash to Firebase: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Finalizes and notarizes the log file asynchronously.

    .DESCRIPTION
        Calculates the log file hash and sends it to Firebase for notarization,
        creating a tamper-proof certificate of the log contents.

    .OUTPUTS
        String containing the notarization certificate ID, or null if notarization fails.

    .EXAMPLE
        $certificateId = $logger.FinalizeAndNotarizeLogAsync()

    .NOTES
        Only executes if EnableNotarization is true in configuration.
        Returns immediately if logging or notarization is disabled.
    #>
    [string] FinalizeAndNotarizeLogAsync() {
        if (-not $this.EnableNotarization) {
            $this.Debug("Log notarization is disabled", "NOTARY")
            return $null
        }

        if (-not $this.EnableFileLogging -or -not (Test-Path $this.LogFilePath)) {
            $this.Warning("No log file to notarize", "NOTARY")
            return $null
        }

        try {
            $this.Info("Starting log notarization process...", "NOTARY")

            # Calculate log file hash
            $hash = $this.GetLogFileHash()
            if (-not $hash) {
                throw "Failed to calculate log file hash"
            }

            $this.Debug("Log file hash calculated: $hash", "NOTARY")

            # Generate client timestamp in ISO 8601 format
            $clientTimestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"

            # Send hash to Firebase
            $response = $this.SendHashToFirebase($hash, $clientTimestamp)

            # Extract document ID from response
            $documentId = $null
            if ($response -and $response.name) {
                $documentId = ($response.name -split '/')[-1]
            }

            if ($documentId) {
                if ($this.Messages -and $this.Messages.loggerNotarizationSuccess) {
                    $msg = $this.Messages.loggerNotarizationSuccess -f $documentId
                    $this.Info($msg, "NOTARY")
                } else {
                    $this.Info("Log successfully notarized. Certificate ID: $documentId", "NOTARY")
                }
                return $documentId
            } else {
                throw "Failed to extract document ID from Firebase response"
            }
        } catch {
            $this.Error("Log notarization failed: $($_.Exception.Message)", "NOTARY")
            return $null
        }
    }
}

<#
.SYNOPSIS
    Global logger instance for the entire application.

.DESCRIPTION
    Stores the initialized Logger instance for use throughout the application lifecycle.
#>
$Global:FocusGameDeckLogger = $null

<#
.SYNOPSIS
    Initializes the global logger instance.

.DESCRIPTION
    Creates and configures a new Logger instance with the provided configuration and messages.
    Stores the instance in the global scope for application-wide access.

.PARAMETER Config
    Configuration object containing logging settings

.PARAMETER Messages
    Localization messages object for internationalized log messages

.PARAMETER AppRoot
    Application root directory for resolving log file paths (optional)

.OUTPUTS
    Logger instance that was initialized

.EXAMPLE
    $logger = Initialize-Logger -Config $config -Messages $messages -AppRoot $appRoot

.NOTES
    Should be called once during application startup.
#>
function Initialize-Logger {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,

        [Parameter(Mandatory = $true)]
        [object] $Messages,
        
        [Parameter(Mandatory = $false)]
        [string] $AppRoot = $null
    )

    if ($AppRoot) {
        $Global:FocusGameDeckLogger = [Logger]::new($Config, $Messages, $AppRoot)
    } else {
        $Global:FocusGameDeckLogger = [Logger]::new($Config, $Messages)
    }
    return $Global:FocusGameDeckLogger
}

<#
.SYNOPSIS
    Retrieves the global logger instance.

.DESCRIPTION
    Returns the initialized logger instance from global scope.
    Throws an error if the logger has not been initialized.

.OUTPUTS
    Logger instance

.EXAMPLE
    $logger = Get-Logger
    $logger.Info("Test message")

.NOTES
    Call Initialize-Logger before using this function.
#>
function Get-Logger {
    if (-not $Global:FocusGameDeckLogger) {
        throw "Logger not initialized. Call Initialize-Logger first."
    }
    return $Global:FocusGameDeckLogger
}

<#
.SYNOPSIS
    Convenience function for quick logging at any level.

.DESCRIPTION
    Writes a log entry at the specified level using the global logger instance.

.PARAMETER Level
    The log level (LogLevel enum value)

.PARAMETER Message
    The log message text

.PARAMETER Component
    The component or module name (default: "MAIN")

.EXAMPLE
    Write-FGDLog -Level ([LogLevel]::Info) -Message "Test" -Component "TEST"

.NOTES
    Requires Initialize-Logger to be called first.
#>
function Write-FGDLog {
    param(
        [Parameter(Mandatory = $true)]
        [LogLevel] $Level,

        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    $logger = Get-Logger
    $logger.Log($Level, $Message, $Component)
}

<#
.SYNOPSIS
    Convenience function for logging informational messages.

.DESCRIPTION
    Writes an Info-level log entry using the global logger instance.

.PARAMETER Message
    The information message text

.PARAMETER Component
    The component or module name (default: "MAIN")

.EXAMPLE
    Write-FGDInfo -Message "Application started" -Component "MAIN"

.NOTES
    Requires Initialize-Logger to be called first.
#>
function Write-FGDInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    Write-FGDLog -Level ([LogLevel]::Info) -Message $Message -Component $Component
}

<#
.SYNOPSIS
    Convenience function for logging warning messages.

.DESCRIPTION
    Writes a Warning-level log entry using the global logger instance.

.PARAMETER Message
    The warning message text

.PARAMETER Component
    The component or module name (default: "MAIN")

.EXAMPLE
    Write-FGDWarning -Message "Configuration missing" -Component "CONFIG"

.NOTES
    Requires Initialize-Logger to be called first.
#>
function Write-FGDWarning {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    Write-FGDLog -Level ([LogLevel]::Warning) -Message $Message -Component $Component
}

<#
.SYNOPSIS
    Convenience function for logging error messages.

.DESCRIPTION
    Writes an Error-level log entry using the global logger instance.

.PARAMETER Message
    The error message text

.PARAMETER Component
    The component or module name (default: "MAIN")

.EXAMPLE
    Write-FGDError -Message "Connection failed" -Component "NETWORK"

.NOTES
    Requires Initialize-Logger to be called first.
#>
function Write-FGDError {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    Write-FGDLog -Level ([LogLevel]::Error) -Message $Message -Component $Component
}

<#
.SYNOPSIS
    Functions are available via dot-sourcing.

.DESCRIPTION
    This module exports the Logger class and convenience functions for use in other scripts.
    Import using: . ./modules/Logger.ps1

.NOTES
    All functions and classes are available after dot-sourcing this file.
#>
# Functions are available via dot-sourcing
