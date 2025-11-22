param(
    [Parameter(Mandatory = $true)]
    [string]$GameId
)

#Requires -Version 5.1

# Import required modules if not already loaded
if (-not (Get-Module -Name Microsoft.PowerShell.Security)) {
    try {
        Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to load Microsoft.PowerShell.Security module: $_"
    }
}

# Detect execution environment to determine application root
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

# Define the application root directory
# This is critical for finding external resources (config, logs)
if ($isExecutable) {
    # In executable mode, the root is the directory where the .exe file is located
    # ps2exe extracts to temp, but we need the actual exe location for external files
    $appRoot = Split-Path -Parent $currentProcess.Path
} else {
    # In development (script) mode, calculate the project root relative to the current script
    # For Invoke-FocusGameDeck.ps1 in /src, the root is one level up
    $appRoot = Split-Path -Parent $PSScriptRoot
}
$scriptDir = $PSScriptRoot

# >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
# This section will be replaced by the build script (Build-FocusGameDeck.ps1)
# During build, the script inserts execution mode detection and dynamic path resolution
# to support both development (.ps1) and bundled executable (.exe) modes

# Initialize path variables - use $appRoot for external files
$configPath = Join-Path $appRoot "config/config.json"

# Import modules
$modulePaths = @(
    (Join-Path $scriptDir "modules/Logger.ps1"),
    (Join-Path $scriptDir "modules/ConfigValidator.ps1"),
    (Join-Path $scriptDir "modules/AppManager.ps1"),
    (Join-Path $scriptDir "modules/OBSManager.ps1"),
    (Join-Path $scriptDir "modules/PlatformManager.ps1")
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# Load configuration and messages
try {
    # Load configuration
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Load messages for localization
    $languageHelperPath = Join-Path $appRoot "scripts/LanguageHelper.ps1"
    $messagesPath = Join-Path $appRoot "localization/messages.json"

    if (Test-Path $languageHelperPath) {
        . $languageHelperPath
        $langCode = Get-DetectedLanguage -ConfigData $config
        $msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode
    } else {
        $msg = @{}
    }

    # Display localized loading messages
    if ($msg.mainLoadingConfig) {
        Write-Host $msg.mainLoadingConfig
    } else {
        Write-Host "Loading configuration..."
    }

    if ($msg.mainConfigLoaded) {
        Write-Host $msg.mainConfigLoaded
    } else {
        Write-Host "Configuration loaded successfully."
    }
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}
# <<< BUILD-TIME-PATCH-END <<<

# Initialize logger
try {
    $logger = Initialize-Logger -Config $config -Messages $msg -AppRoot $appRoot
    $logger.Info("Focus Game Deck started (Multi-Platform)", "MAIN")
    $logger.Info("Game ID: $GameId", "MAIN")

    # Log self-authentication information for audit purposes
    $logger.Debug("Self-authentication initialized for log integrity verification", "AUTH")
} catch {
    Write-Warning "Failed to initialize logger: $_"
    # Continue without logging
}

# Initialize platform manager
try {
    $platformManager = New-PlatformManager -Config $config -Messages $msg -Logger $logger
    if ($logger) { $logger.Info("Platform manager initialized", "PLATFORM") }

    # Detect available platforms
    $detectedPlatforms = $platformManager.DetectAllPlatforms()
    $availablePlatforms = $detectedPlatforms.Keys | Where-Object { $detectedPlatforms[$_].Available }
    if ($logger) { $logger.Info("Available platforms: $($availablePlatforms -join ', ')", "PLATFORM") }

    # Auto-detect and update paths if needed
    foreach ($platformKey in $detectedPlatforms.Keys) {
        # Skip direct platform as it doesn't need a global path
        if ($platformKey -eq "direct") {
            continue
        }

        $platform = $detectedPlatforms[$platformKey]
        if ($platform.Available -and $platform.Path) {
            if (-not $config.paths.$platformKey -or $config.paths.$platformKey -ne $platform.Path) {
                $config.paths.$platformKey = $platform.Path
                if ($logger) { $logger.Info("Auto-detected $($platform.Name) path: $($platform.Path)", "PLATFORM") }
            }
        }
    }
} catch {
    Write-Error "Failed to initialize platform manager: $_"
    if ($logger) { $logger.Error("Platform manager initialization failed: $_", "PLATFORM") }
    exit 1
}

# Validate configuration
if ($msg.mainValidatingConfig) {
    Write-Host $msg.mainValidatingConfig
} else {
    Write-Host "Validating configuration..."
}
$validator = New-ConfigValidator -Config $config -Messages $msg
if (-not $validator.ValidateConfiguration($GameId)) {
    $validator.DisplayResults()
    if ($logger) { $logger.Error("Configuration validation failed", "CONFIG") }
    exit 1
}
$validator.DisplayResults()
if ($logger) { $logger.Info("Configuration validation passed", "CONFIG") }

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    if ($msg.mainGameNotFound) {
        $errorMsg = $msg.mainGameNotFound -f $GameId
    } else {
        $errorMsg = "Error: Game ID '{0}' not found in configuration." -f $GameId
    }
    Write-Host $errorMsg

    if ($msg.mainAvailableGameIds) {
        Write-Host ($msg.mainAvailableGameIds -f ($config.games.PSObject.Properties.Name -join ', '))
    } else {
        Write-Host ("Available game IDs: {0}" -f ($config.games.PSObject.Properties.Name -join ', '))
    }
    if ($logger) { $logger.Error($errorMsg, "MAIN") }
    exit 1
}

# Validate platform support
$gamePlatform = $gameConfig.platform
if (-not $gamePlatform) {
    $gamePlatform = "steam"  # Default to Steam for backward compatibility
    $gameConfig | Add-Member -NotePropertyName "platform" -NotePropertyValue "steam" -Force
}

if (-not $platformManager.IsPlatformAvailable($gamePlatform)) {
    $errorMsg = "Platform '$gamePlatform' is not available or supported for game '$($gameConfig.name)'"
    Write-Host $errorMsg
    Write-Host "Available platforms: $($availablePlatforms -join ', ')"
    if ($logger) { $logger.Error($errorMsg, "PLATFORM") }
    exit 1
}

if ($logger) {
    $logger.Info("Game configuration loaded: $($gameConfig.name) (Platform: $gamePlatform)", "MAIN")
}

# Initialize managers
$appManager = New-AppManager -Config $config -Messages $msg -Logger $logger
$appManager.SetGameContext($gameConfig)

if ($logger) { $logger.Info("Application manager initialized and game context set", "MAIN") }

# Common startup process for game environment
function Invoke-GameStartup {
    if ($logger) { $logger.Info("Starting game environment setup", "SETUP") }

    # Unified application and integration management
    Write-Host "[INFO] Starting application management..."
    [void]$appManager.ProcessStartupSequence()
    if ($logger) { $logger.Info("Application startup sequence completed", "APP") }

    if ($logger) { $logger.Info("Game environment setup completed", "SETUP") }

    return
}

# Common cleanup process for game exit
function Invoke-GameCleanup {
    param(
        [bool]$IsInterrupted = $false
    )

    if ($IsInterrupted) {
        Write-Host "Cleanup initiated due to user interruption (Ctrl+C)."
        if ($logger) { $logger.Warning("Cleanup initiated due to interruption", "CLEANUP") }
    } else {
        if ($logger) { $logger.Info("Starting game cleanup", "CLEANUP") }
    }

    # Unified application and integration shutdown
    $appManager.ProcessShutdownSequence()
    if ($logger) { $logger.Info("Application shutdown sequence completed", "CLEANUP") }

    if ($logger) { $logger.Info("Game cleanup completed", "CLEANUP") }

    return
}

# Handle Ctrl+C press
trap [System.Management.Automation.PipelineStoppedException] {
    Invoke-GameCleanup -IsInterrupted $true
    if ($logger) { $logger.Info("Application terminated by user", "MAIN") }
    exit
}

# Main execution flow
try {
    if ($logger) { $logger.LogOperationStart("Multi-Platform Game Launch Sequence", "MAIN") }
    $startTime = Get-Date

    # Execute environment setup
    Invoke-GameStartup

    # Launch game via appropriate platform
    if ($msg.mainLaunchingGame) {
        Write-Host ($msg.mainLaunchingGame -f $detectedPlatforms[$gamePlatform].Name)
    } else {
        Write-Host "Launching game via $($detectedPlatforms[$gamePlatform].Name)..."
    }
    try {
        [void]$platformManager.LaunchGame($gamePlatform, $gameConfig)
        Write-Host ("Starting game: {0}" -f $gameConfig.name)
        if ($logger) { $logger.Info("Game launch command sent to $($detectedPlatforms[$gamePlatform].Name): $($gameConfig.name)", "GAME") }
    } catch {
        $errorMsg = "Failed to launch game via $($detectedPlatforms[$gamePlatform].Name): $_"
        Write-Error $errorMsg
        if ($logger) { $logger.Error($errorMsg, "GAME") }
        throw
    }

    # Wait for actual game process to start (not the launcher)
    if ($msg.mainWaitingForProcess) {
        Write-Host $msg.mainWaitingForProcess
    } else {
        Write-Host "Waiting for game process to start..."
    }
    $gameProcess = $null
    $processStartTimeout = 300  # 5 minutes timeout
    $startTime = Get-Date

    do {
        Start-Sleep -Seconds 3
        $elapsed = (Get-Date) - $startTime
        if ([int]$elapsed.TotalSeconds % 30 -eq 0 -and $elapsed.TotalSeconds -gt 0) {
            Write-Host "." -NoNewline
        }
        $gameProcess = Get-Process $gameConfig.processName -ErrorAction SilentlyContinue
    } while (-not $gameProcess -and $elapsed.TotalSeconds -lt $processStartTimeout)

    if ($gameProcess) {
        Write-Host ("Now monitoring process: {0}. The script will continue after the game exits." -f $gameConfig.name)
        if ($logger) { $logger.Info("Game process detected and monitoring started: $($gameConfig.processName)", "GAME") }

        # Wait for the game process to end.
        # If direct Wait-Process fails (e.g., due to admin privilege issues),
        # fall back to polling the process status.
        try {
            if ($logger) { $logger.Debug("Attempting to wait for process directly: $($gameProcess.Name) (PID: $($gameProcess.Id))", "GAME") }
            Wait-Process -InputObject $gameProcess -ErrorAction Stop
        } catch {
            if ($logger) { $logger.Warning("Direct wait failed. Falling back to polling for process exit: $($gameProcess.Name) (PID: $($gameProcess.Id)). This can happen with admin-level processes.", "GAME") }
            Write-Host "Direct process wait failed. Monitoring process in fallback mode (polling every 3s). This can happen with admin-level processes."

            while ($true) {
                $processCheck = Get-Process -Id $gameProcess.Id -ErrorAction SilentlyContinue
                if (-not $processCheck) {
                    if ($logger) { $logger.Info("Process has exited (detected by polling): $($gameProcess.Name) (PID: $($gameProcess.Id))", "GAME") }
                    break # Exit the loop
                }
                Start-Sleep -Seconds 3
            }
        }

        if ($msg.mainGameExited) {
            Write-Host ($msg.mainGameExited -f $gameConfig.name)
        } else {
            Write-Host ("Game has exited: {0}" -f $gameConfig.name)
        }
        if ($logger) { $logger.Info("Game process ended: $($gameConfig.name)", "GAME") }
    } else {
        Write-Warning "Game process '$($gameConfig.processName)' was not detected within timeout period"
        if ($logger) { $logger.Warning("Game process not detected within timeout: $($gameConfig.processName)", "GAME") }
    }

    # Execute cleanup processing when game exits
    Invoke-GameCleanup

    if ($logger) {
        $logger.LogOperationEnd("Multi-Platform Game Launch Sequence", $startTime, "MAIN")
        $logger.Info("Focus Game Deck session completed successfully", "MAIN")
    }

    if ($msg.mainSessionCompletedMessage) {
        Write-Host $msg.mainSessionCompletedMessage
    } else {
        Write-Host "Focus Game Deck session completed."
    }
} catch {
    $errorMsg = "Unexpected error during execution: $_"
    Write-Error $errorMsg
    if ($logger) {
        $logger.LogException($_, "Main execution flow", "MAIN")
    }

    # Attempt cleanup even on error
    try {
        Invoke-GameCleanup -IsInterrupted $true
    } catch {
        Write-Warning "Error during cleanup: $_"
        if ($logger) { $logger.Error("Error during cleanup: $_", "CLEANUP") }
    }

    exit 1
} finally {
    # Finalize and notarize log file if logging is enabled
    if ($logger) {
        try {
            if ($msg.mainFinalizingLog) {
                Write-Host $msg.mainFinalizingLog
            } else {
                Write-Host "Finalizing session log..."
            }
            $certificateId = $logger.FinalizeAndNotarizeLogAsync()

            if ($certificateId) {
                if ($msg.mainLogNotarizedSuccess) {
                    Write-Host ($msg.mainLogNotarizedSuccess -f $certificateId)
                } else {
                    Write-Host "[OK] " -NoNewline
                    Write-Host "Log successfully notarized. Certificate ID: " -NoNewline
                    Write-Host $certificateId
                }
                if ($msg.mainLogNotarizationInfo) {
                    Write-Host $msg.mainLogNotarizationInfo
                } else {
                    Write-Host "  This certificate can be used to verify log integrity if needed."
                }
            } else {
                if ($msg.mainLogFinalized) {
                    Write-Host $msg.mainLogFinalized
                } else {
                    Write-Host "Log finalized (notarization disabled or failed)"
                }
            }
        } catch {
            Write-Warning "Failed to notarize log: $_"
        }
    }
}
