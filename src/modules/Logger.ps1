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
                $this.LogFilePath = Join-Path $PSScriptRoot "..\logs\focus-game-deck.log"
            }

            # Initialize Firebase configuration for log notarization
            if ($config.logging.firebase) {
                $this.FirebaseProjectId = $config.logging.firebase.projectId
                $this.FirebaseApiKey = $config.logging.firebase.apiKey
                $this.FirebaseDatabaseURL = $config.logging.firebase.databaseURL
            }
        } else {
            $this.LogFilePath = Join-Path $PSScriptRoot "..\logs\focus-game-deck.log"
        }

        # Ensure log directory exists
        if ($this.EnableFileLogging) {
            $logDir = Split-Path $this.LogFilePath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
        }
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
            }
            catch {
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

    # Rotate log file if it gets too large
    [void] RotateLogFile([int] $maxSizeMB = 10) {
        if (-not $this.EnableFileLogging -or -not (Test-Path $this.LogFilePath)) {
            return
        }

        $logFile = Get-Item $this.LogFilePath
        $fileSizeMB = $logFile.Length / 1MB

        if ($fileSizeMB -gt $maxSizeMB) {
            $backupPath = $this.LogFilePath -replace '\.log$', "-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            Move-Item -Path $this.LogFilePath -Destination $backupPath
            $this.Info("Log file rotated. Backup created: $backupPath", "LOGGER")
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
        }
        catch {
            $this.Error("Failed to calculate log file hash: $_", "NOTARY")
            return $null
        }
    }

    # Send log hash to Firebase for notarization
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
            }
        } | ConvertTo-Json -Depth 5

        $headers = @{
            'Content-Type' = 'application/json'
            'Authorization' = "Bearer $($this.FirebaseApiKey)"
        }

        try {
            $response = Invoke-RestMethod -Uri $firestoreUrl -Method POST -Body $body -Headers $headers -TimeoutSec 30
            return $response
        }
        catch {
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
                $this.Info("Log successfully notarized. Certificate ID: $documentId", "NOTARY")
                return $documentId
            } else {
                throw "Failed to extract document ID from Firebase response"
            }
        }
        catch {
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
