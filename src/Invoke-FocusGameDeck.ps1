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

# AssetFile paths variables - use $appRoot for external files
$configPath = Join-Path $appRoot "config/config.json"
$messagesPath = Join-Path $appRoot "localization/messages.json"

# Read Source files using dot-source
if (-not $isExecutable) {
    $filesToSources = @(
        # Modules
        (Join-Path $appRoot "src/modules/AppManager.ps1"),
        (Join-Path $appRoot "src/modules/ConfigValidator.ps1"),
        (Join-Path $appRoot "src/modules/DiscordManager.ps1"),
        (Join-Path $appRoot "src/modules/DiscordRPCClient.ps1"),
        (Join-Path $appRoot "src/modules/Logger.ps1"),
        (Join-Path $appRoot "src/modules/OBSManager.ps1"),
        (Join-Path $appRoot "src/modules/UpdateChecker.ps1"),
        (Join-Path $appRoot "src/modules/PlatformManager.ps1"),
        (Join-Path $appRoot "src/modules/VTubeStudioManager.ps1"),
        (Join-Path $appRoot "src/modules/WebSocketAppManagerBase.ps1"),
        # Scripts
        (Join-Path $appRoot "scripts/LanguageHelper.ps1")
    )

    foreach ($sourcePath in $filesToSources) {
        try {
            . $sourcePath
        } catch {
            Write-Error "Failed to load module '$sourcePath': $_"
            exit 1
        }
    }
}

Write-LocalizedHost -Messages $msg -Key "cli_loading_config" -Default "Loading configuration..." -Color "Cyan"
# Load configuration
try {
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-LocalizedHost -Messages $msg -Key "cli_config_loaded" -Default "Configuration loaded." -Color "Green"
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}
# Load localization messages
try {
    $msg = Get-Content -Path $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Warning "Failed to load localization messages: $_"
    Write-LocalizedHost -Messages $msg -Key "cli_config_loaded" -Default "Continuing with default messages." -Color "Yellow"
    $msg = @{}
}

# Initialize logger
try {
    $logger = Initialize-Logger -Config $config -Messages $msg -AppRoot $appRoot
    $logger.Info("Focus Game Deck started (Multi-Platform)", "MAIN")
    $logger.Info("Game ID: $GameId", "MAIN")

    # Log self-authentication information for audit purposes
    $logger.Debug("Self-authentication initialized for log integrity verification", "AUTH")
} catch {
    Write-Warning "[ERROR] Failed to initialize logger: $_"
    Write-Host "[WARNING] Continue without logging"
    $logger = $null
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
Write-LocalizedHost -Messages $msg -Key "cli_validating_config" -Default "Validating configuration..." -Color "Cyan"
$validator = New-ConfigValidator -Config $config -Messages $msg
if (-not $validator.ValidateConfiguration($GameId)) {
    $validator.DisplayResults()
    Write-LocalizedHost -Messages $msg -Key "cli_validation_failed" -Default "Configuration validation failed." -Color "Red"
    if ($logger) { $logger.Error("Configuration validation failed", "CONFIG") }
    exit 1
}
$validator.DisplayResults()
Write-LocalizedHost -Messages $msg -Key "cli_validation_passed" -Default "Configuration validation passed." -Color "Green"
if ($logger) { $logger.Info("Configuration validation passed", "CONFIG") }

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    $errorMsg = "Error: Game ID '{0}' not found in configuration." -f $GameId
    Write-LocalizedHost -Messages $msg -Key "cli_game_not_found" -Args @($GameId) -Default $errorMsg -Color "Red"

    $availableIds = ($config.games.PSObject.Properties.Name -join ', ')
    Write-LocalizedHost -Messages $msg -Key "cli_available_games" -Args @($availableIds) -Default ("Available game IDs: {0}" -f $availableIds)
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
    Write-LocalizedHost -Messages $msg -Key "cli_platform_not_supported" -Args @($gamePlatform) -Default $errorMsg -Color "Red"
    Write-LocalizedHost -Messages $msg -Key "cli_available_platforms" -Args @($availablePlatforms -join ', ') -Default ("Available platforms: {0}" -f ($availablePlatforms -join ', '))
    if ($logger) { $logger.Error($errorMsg, "PLATFORM") }
    exit 1
}

if ($logger) {
    $logger.Info("Game configuration loaded: $($gameConfig.name) (Platform: $gamePlatform)", "MAIN")
}

# Initialize managers
$appManager = New-AppManager -Config $config -Messages $msg -Logger $logger
[void] $appManager.SetGameContext($gameConfig)

if ($logger) { $logger.Info("Application manager initialized and game context set", "MAIN") }

# Common startup process for game environment
function Invoke-GameStartup {
    if ($logger) { $logger.Info("Starting game environment setup", "SETUP") }

    # Unified application and integration management
    Write-LocalizedHost -Messages $msg -Key "app_management_start" -Default "Starting application management..." -Color "Cyan"
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
        Write-LocalizedHost -Messages $msg -Key "cli_cleanup_interrupted" -Default "Cleanup initiated due to user interruption (Ctrl+C)." -Color "Yellow"
        if ($logger) { $logger.Warning("Cleanup initiated due to interruption", "CLEANUP") }
    } else {
        Write-LocalizedHost -Messages $msg -Key "cli_cleanup_started" -Default "Starting game cleanup..." -Color "Cyan"
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
    Write-LocalizedHost -Messages $msg -Key "cli_launching_game" -Args @($detectedPlatforms[$gamePlatform].Name) -Default ("Launching game via {0}..." -f $detectedPlatforms[$gamePlatform].Name) -Color "Cyan"
    try {
        [void]$platformManager.LaunchGame($gamePlatform, $gameConfig)
        Write-LocalizedHost -Messages $msg -Key "starting_game_name" -Args @($gameConfig.name) -Default ("Starting game: {0}" -f $gameConfig.name)
        if ($logger) { $logger.Info("Game launch command sent to $($detectedPlatforms[$gamePlatform].Name): $($gameConfig.name)", "GAME") }
    } catch {
        $errorMsg = "Failed to launch game via $($detectedPlatforms[$gamePlatform].Name): $_"
        Write-Error $errorMsg
        if ($logger) { $logger.Error($errorMsg, "GAME") }
        throw
    }

    # Wait for actual game process to start (not the launcher)
    Write-LocalizedHost -Messages $msg -Key "cli_waiting_process" -Default "Waiting for game process to start..." -Color "Cyan"
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
        Write-LocalizedHost -Messages $msg -Key "cli_monitoring_process" -Args @($gameProcess.Name, $gameProcess.Id) -Default ("Now monitoring process: {0}." -f $gameConfig.name)
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

        Write-LocalizedHost -Messages $msg -Key "cli_process_exited" -Args @($gameConfig.name) -Default ("Game has exited: {0}" -f $gameConfig.name)
        if ($logger) { $logger.Info("Game process ended: $($gameConfig.name)", "GAME") }
    } else {
        Write-LocalizedHost -Messages $msg -Key "cli_process_timeout" -Args @($gameConfig.processName) -Default ("Game process '{0}' was not detected within timeout period" -f $gameConfig.processName) -Color "Yellow"
        if ($logger) { $logger.Warning("Game process not detected within timeout: $($gameConfig.processName)", "GAME") }
    }

    # Execute cleanup processing when game exits
    Invoke-GameCleanup

    if ($logger) {
        $logger.LogOperationEnd("Multi-Platform Game Launch Sequence", $startTime, "MAIN")
        $logger.Info("Focus Game Deck session completed successfully", "MAIN")
    }

    Write-LocalizedHost -Messages $msg -Key "cli_session_completed" -Default "Focus Game Deck session completed." -Color "Green"
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
