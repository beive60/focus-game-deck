# Logger Module
# Centralized logging functionality with multiple levels and output options

enum LogLevel {
    Trace = 0
    Debug = 1
    Info = 2
    Warning = 3
    Error = 4
    Critical = 5
}

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

    # Constructor
    Logger([object] $config, [object] $messages) {
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
                $this.LogFilePath = Join-Path $PSScriptRoot "../logs/focus-game-deck.log"
            }

            # Initialize Firebase configuration for log notarization
            if ($config.logging.firebase) {
                $this.FirebaseProjectId = $config.logging.firebase.projectId
                $this.FirebaseApiKey = $config.logging.firebase.apiKey
                $this.FirebaseDatabaseURL = $config.logging.firebase.databaseURL
            }
        } else {
            $this.LogFilePath = Join-Path $PSScriptRoot "../logs/focus-game-deck.log"
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

    # Main logging method
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

    # Write to console with appropriate colors
    [void] WriteToConsole([LogLevel] $level, [string] $logEntry) {
        switch ($level) {
            ([LogLevel]::Trace) {
                Write-Host $logEntry -ForegroundColor DarkGray
            }
            ([LogLevel]::Debug) {
                Write-Host $logEntry -ForegroundColor Gray
            }
            ([LogLevel]::Info) {
                Write-Host $logEntry -ForegroundColor White
            }
            ([LogLevel]::Warning) {
                Write-Host $logEntry -ForegroundColor Yellow
            }
            ([LogLevel]::Error) {
                Write-Host $logEntry -ForegroundColor Red
            }
            ([LogLevel]::Critical) {
                Write-Host $logEntry -ForegroundColor Magenta
            }
        }
    }

    # Convenience methods for different log levels
    [void] Trace([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Trace, $message, $component)
    }

    [void] Debug([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Debug, $message, $component)
    }

    [void] Info([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Info, $message, $component)
    }

    [void] Warning([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Warning, $message, $component)
    }

    [void] Error([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Error, $message, $component)
    }

    [void] Critical([string] $message, [string] $component = "MAIN") {
        $this.Log([LogLevel]::Critical, $message, $component)
    }

    # Log exception with stack trace
    [void] LogException([System.Exception] $exception, [string] $context = "", [string] $component = "MAIN") {
        $message = "Exception in $context : $($exception.Message)"
        if ($exception.StackTrace) {
            $message += "`nStack Trace: $($exception.StackTrace)"
        }
        $this.Error($message, $component)
    }

    # Log start of operation
    [void] LogOperationStart([string] $operationName, [string] $component = "MAIN") {
        $this.Info("Starting operation: $operationName", $component)
    }

    # Log end of operation with duration
    [void] LogOperationEnd([string] $operationName, [datetime] $startTime, [string] $component = "MAIN") {
        $duration = (Get-Date) - $startTime
        $this.Info("Completed operation: $operationName (Duration: $($duration.TotalMilliseconds)ms)", $component)
    }

    # Clean up old log files based on retention policy
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
                    if ($logFile.LastWriteTime -lt $cutoffDate) {
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

    # Initialize self-authentication properties by retrieving digital signature information
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

    # Get application version from Version.ps1
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

    # Rotate log file if it gets too large
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

    # Calculate SHA256 hash of log file
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

    # Send log hash to Firebase for notarization with self-authentication data
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

    # Finalize and notarize log file
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

# Global logger instance
$Global:FocusGameDeckLogger = $null

# Public function to initialize logger
function Initialize-Logger {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Config,

        [Parameter(Mandatory = $true)]
        [object] $Messages
    )

    $Global:FocusGameDeckLogger = [Logger]::new($Config, $Messages)
    return $Global:FocusGameDeckLogger
}

# Public function to get logger instance
function Get-Logger {
    if (-not $Global:FocusGameDeckLogger) {
        throw "Logger not initialized. Call Initialize-Logger first."
    }
    return $Global:FocusGameDeckLogger
}

# Convenience functions for quick logging
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

function Write-FGDInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    Write-FGDLog -Level ([LogLevel]::Info) -Message $Message -Component $Component
}

function Write-FGDWarning {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    Write-FGDLog -Level ([LogLevel]::Warning) -Message $Message -Component $Component
}

function Write-FGDError {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Component = "MAIN"
    )

    Write-FGDLog -Level ([LogLevel]::Error) -Message $Message -Component $Component
}

# Functions are available via dot-sourcing
