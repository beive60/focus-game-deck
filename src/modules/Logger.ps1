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
    [object] $Messages

    # Constructor
    Logger([object] $config, [object] $messages) {
        $this.Messages = $messages
        $this.MinimumLevel = [LogLevel]::Info
        $this.EnableConsoleLogging = $true
        $this.EnableFileLogging = $false

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
            
            if ($config.logging.filePath) {
                $this.LogFilePath = $config.logging.filePath
            } else {
                $this.LogFilePath = Join-Path $PSScriptRoot "..\logs\focus-game-deck.log"
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