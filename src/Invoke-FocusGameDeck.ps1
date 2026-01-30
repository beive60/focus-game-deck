param(
    [Parameter(Mandatory = $true)]
    [string]$GameId
)

#Requires -Version 5.1

# Import required modules if not already loaded
# Check both module (PowerShell Core) and snap-in (Windows PowerShell)
if (-not (Get-Module -Name Microsoft.PowerShell.Security)) {
    try {
        # Try Get-PSSnapin only for Windows PowerShell (version < 6)
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $snapin = Get-PSSnapin -Name Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
            if (-not $snapin) {
                Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
            }
        } else {
            Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
        }
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
$localizationDir = Join-Path $appRoot "localization"

# Explicit dot-source declarations for bundler dependency resolution
# These are processed by Invoke-PsScriptBundler.ps1 and removed during bundling
# Order is critical: LanguageHelper must be first!
. (Join-Path -Path $appRoot -ChildPath "scripts/LanguageHelper.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/WebSocketAppManagerBase.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/AppManager.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/ValidationRules.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/ConfigValidator.ps1")
# TODO: Re-enable in future release
# Disabled for v1.0 - Discord integration has known bugs
. (Join-Path -Path $appRoot -ChildPath "src/modules/DiscordManager.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/DiscordRPCClient.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/Logger.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/OBSManager.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/UpdateChecker.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/PlatformManager.ps1")
. (Join-Path -Path $appRoot -ChildPath "src/modules/VTubeStudioManager.ps1")

# Load configuration
try {
    Write-Host "[INFO] ConfigLoader: Loading configuration..."
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] ConfigLoader: Configuration loaded."
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}

# Load localization messages from individual language files
try {
    $langCode = Get-DetectedLanguage -ConfigData $config
    Write-Verbose "Detected language code: $langCode"

    # Use Get-LocalizedMessages function to load individual language file (e.g., fr.json, en.json)
    # This follows the v3.1+ split-file architecture for 88.5% performance improvement
    $msg = Get-LocalizedMessages -MessagesPath $localizationDir -LanguageCode $langCode

    if (-not $msg -or $msg.PSObject.Properties.Count -eq 0) {
        Write-Warning "Failed to load messages for language '$langCode'. Using English fallback."
        $msg = Get-LocalizedMessages -MessagesPath $localizationDir -LanguageCode "en"
    }

    Write-Verbose "Loaded localization messages for language: $langCode"
} catch {
    Write-Warning "Failed to load localization messages: $_"
    Write-Host "Continuing with default messages."
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
Write-LocalizedHost -Messages $msg -Key "cli_validating_config" -Default "Validating configuration..." -Level "INFO" -Component "ConfigValidator"
$validator = New-ConfigValidator -Config $config -Messages $msg
if (-not $validator.ValidateConfiguration($GameId)) {
    $validator.DisplayResults()
    $errorMsg = "Configuration validation failed."
    Write-LocalizedHost -Messages $msg -Key "cli_validation_failed" -Default $errorMsg -Level "WARNING" -Component "ConfigValidator"
    if ($logger) { $logger.Error($errorMsg, "CONFIG") }
    throw $errorMsg
}
$validator.DisplayResults()
Write-LocalizedHost -Messages $msg -Key "console_config_validation_passed" -Default "Configuration validation passed" -Level "OK" -Component "ConfigValidator"
if ($logger) { $logger.Info("Configuration validation passed", "CONFIG") }

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    $errorMsg = "Error: Game ID '{0}' not found in configuration." -f $GameId
    Write-LocalizedHost -Messages $msg -Key "cli_game_not_found" -Args @($GameId) -Default $errorMsg -Level "WARNING" -Component "GameLauncher"

    $availableIds = ($config.games.PSObject.Properties.Name -join ', ')
    Write-LocalizedHost -Messages $msg -Key "cli_available_games" -Args @($availableIds) -Default ("Available game IDs: {0}" -f $availableIds) -Level "INFO" -Component "GameLauncher"
    if ($logger) { $logger.Error($errorMsg, "MAIN") }
    throw $errorMsg
}

# Validate platform support
$gamePlatform = $gameConfig.platform
if (-not $gamePlatform) {
    $gamePlatform = "steam"  # Default to Steam for backward compatibility
    $gameConfig | Add-Member -NotePropertyName "platform" -NotePropertyValue "steam" -Force
}

if (-not $platformManager.IsPlatformAvailable($gamePlatform)) {
    $errorMsg = "Platform '$gamePlatform' is not available or supported for game '$($gameConfig.name)'"
    Write-LocalizedHost -Messages $msg -Key "cli_platform_not_supported" -Args @($gamePlatform) -Default $errorMsg -Level "WARNING" -Component "PlatformManager"
    Write-LocalizedHost -Messages $msg -Key "cli_available_platforms" -Args @($availablePlatforms -join ', ') -Default ("Available platforms: {0}" -f ($availablePlatforms -join ', ')) -Level "INFO" -Component "PlatformManager"
    if ($logger) { $logger.Error($errorMsg, "PLATFORM") }
    throw $errorMsg
}

if ($logger) {
    $logger.Info("Game configuration loaded: $($gameConfig.name) (Platform: $gamePlatform)", "MAIN")
}
Write-LocalizedHost -Messages $msg -Key "console_game_config_loaded" -Args @($gameConfig.name, $gamePlatform) -Default ("Game configuration loaded: {0} (Platform: {1})" -f $gameConfig.name, $gamePlatform) -Level "INFO" -Component "GameLauncher"

# Initialize managers
$appManager = New-AppManager -Config $config -Messages $msg -Logger $logger
[void] $appManager.SetGameContext($gameConfig)

Write-LocalizedHost -Messages $msg -Key "console_app_manager_initialized" -Default "Application manager initialized" -Level "INFO" -Component "GameLauncher"
if ($logger) { $logger.Info("Application manager initialized and game context set", "MAIN") }

# Common startup process for game environment
function Invoke-GameStartup {
    Write-LocalizedHost -Messages $msg -Key "console_game_environment_setup" -Default "Starting game environment setup" -Level "INFO" -Component "GameLauncher"
    if ($logger) { $logger.Info("Starting game environment setup", "SETUP") }

    # Unified application and integration management
    Write-LocalizedHost -Messages $msg -Key "app_management_start" -Default "Starting application management..." -Level "INFO" -Component "AppManager"
    [void]$appManager.ProcessStartupSequence()
    Write-LocalizedHost -Messages $msg -Key "console_startup_sequence_complete" -Default "Startup sequence completed" -Level "OK" -Component "AppManager"
    if ($logger) { $logger.Info("Application startup sequence completed", "APP") }

    Write-LocalizedHost -Messages $msg -Key "console_game_environment_ready" -Default "Game environment ready" -Level "OK" -Component "GameLauncher"
    if ($logger) { $logger.Info("Game environment setup completed", "SETUP") }

    return
}

# Common cleanup process for game exit
function Invoke-GameCleanup {
    param(
        [bool]$IsInterrupted = $false
    )

    if ($IsInterrupted) {
        Write-LocalizedHost -Messages $msg -Key "cli_cleanup_interrupted" -Default "Cleanup initiated due to user interruption (Ctrl+C)." -Level "WARNING" -Component "GameLauncher"
        if ($logger) { $logger.Warning("Cleanup initiated due to interruption", "CLEANUP") }
    } else {
        Write-LocalizedHost -Messages $msg -Key "console_cleanup_starting" -Default "Starting cleanup..." -Level "INFO" -Component "GameLauncher"
        if ($logger) { $logger.Info("Starting game cleanup", "CLEANUP") }
    }

    # Unified application and integration shutdown
    [void]$appManager.ProcessShutdownSequence()
    Write-LocalizedHost -Messages $msg -Key "console_cleanup_complete" -Default "Cleanup completed" -Level "OK" -Component "GameLauncher"
    if ($logger) { $logger.Info("Application shutdown sequence completed", "CLEANUP") }

    if ($logger) { $logger.Info("Game cleanup completed", "CLEANUP") }

    return
}

# Handle Ctrl+C press
# Note: 'trap [PipelineStoppedException]' does not work reliably in ps2exe-compiled executables.
# Use .NET Console.CancelKeyPress event handler which works in both script and executable modes.
$script:ctrlCPressed = $false

$script:ctrlCHandler = [System.ConsoleCancelEventHandler] {
    param($sender, $eventArgs)

    # Prevent immediate process termination
    $eventArgs.Cancel = $true

    # Avoid duplicate cleanup calls
    if ($script:ctrlCPressed) {
        return
    }
    $script:ctrlCPressed = $true

    # Perform cleanup with error handling to ensure graceful exit
    try {
        Invoke-GameCleanup -IsInterrupted $true
        if ($logger) { $logger.Info("Application terminated by user", "MAIN") }
    } catch {
        Write-Warning "Error during Ctrl+C cleanup: $_"
    }

    # Exit the application
    [Environment]::Exit(0)
}

# Register the Ctrl+C handler using .NET event subscription
[Console]::TreatControlCAsInput = $false
[Console]::add_CancelKeyPress($script:ctrlCHandler)

# Main execution flow
try {
    if ($logger) { $logger.LogOperationStart("Multi-Platform Game Launch Sequence", "MAIN") }
    $startTime = Get-Date

    # Execute environment setup
    Invoke-GameStartup

    # Launch game via appropriate platform
    Write-LocalizedHost -Messages $msg -Key "console_launching_via_platform" -Args @($detectedPlatforms[$gamePlatform].Name) -Default ("Launching game via {0}..." -f $detectedPlatforms[$gamePlatform].Name) -Level "INFO" -Component "GameLauncher"
    try {
        [void]$platformManager.LaunchGame($gamePlatform, $gameConfig)
        Write-LocalizedHost -Messages $msg -Key "starting_game_name" -Args @($gameConfig.name) -Default ("Starting game: {0}" -f $gameConfig.name) -Level "INFO" -Component "GameLauncher"
        if ($logger) { $logger.Info("Game launch command sent to $($detectedPlatforms[$gamePlatform].Name): $($gameConfig.name)", "GAME") }
    } catch {
        $errorMsg = "Failed to launch game via $($detectedPlatforms[$gamePlatform].Name): $_"
        Write-Error $errorMsg
        if ($logger) { $logger.Error($errorMsg, "GAME") }
        throw
    }

    # Wait for actual game process to start (not the launcher)
    Write-LocalizedHost -Messages $msg -Key "cli_waiting_process" -Default "Waiting for game process to start..." -Level "INFO" -Component "GameMonitor"
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
        Write-LocalizedHost -Messages $msg -Key "console_game_process_detected" -Args @($gameConfig.name) -Default ("Game process detected: {0}" -f $gameConfig.name) -Level "OK" -Component "GameMonitor"
        if ($logger) { $logger.Info("Game process detected and monitoring started: $($gameConfig.processName)", "GAME") }

        # Wait for the game process to end.
        # If direct Wait-Process fails (e.g., due to admin privilege issues),
        # fall back to polling the process status.
        try {
            if ($logger) { $logger.Debug("Attempting to wait for process directly: $($gameProcess.Name) (PID: $($gameProcess.Id))", "GAME") }
            Wait-Process -InputObject $gameProcess -ErrorAction Stop
        } catch {
            if ($logger) { $logger.Warning("Direct wait failed. Falling back to polling for process exit: $($gameProcess.Name) (PID: $($gameProcess.Id)). This can happen with admin-level processes.", "GAME") }
            Write-LocalizedHost -Messages $msg -Key "console_process_wait_fallback" -Default "Direct process wait failed - Monitoring in fallback mode (polling every 3s)" -Level "WARNING" -Component "GameMonitor"

            while ($true) {
                $processCheck = Get-Process -Id $gameProcess.Id -ErrorAction SilentlyContinue
                if (-not $processCheck) {
                    if ($logger) { $logger.Info("Process has exited (detected by polling): $($gameProcess.Name) (PID: $($gameProcess.Id))", "GAME") }
                    break # Exit the loop
                }
                Start-Sleep -Seconds 3
            }
        }

        Write-LocalizedHost -Messages $msg -Key "console_game_process_ended" -Args @($gameConfig.name) -Default ("Game process ended: {0}" -f $gameConfig.name) -Level "INFO" -Component "GameMonitor"
        if ($logger) { $logger.Info("Game process ended: $($gameConfig.name)", "GAME") }
    } else {
        Write-LocalizedHost -Messages $msg -Key "cli_process_timeout" -Args @($gameConfig.processName) -Default ("Game process '{0}' was not detected within timeout period" -f $gameConfig.processName) -Level "WARNING" -Component "GameMonitor"
        if ($logger) { $logger.Warning("Game process not detected within timeout: $($gameConfig.processName)", "GAME") }
    }

    # Execute cleanup processing when game exits
    Invoke-GameCleanup

    if ($logger) {
        $logger.LogOperationEnd("Multi-Platform Game Launch Sequence", $startTime, "MAIN")
        $logger.Info("Focus Game Deck session completed successfully", "MAIN")
    }

    Write-LocalizedHost -Messages $msg -Key "console_session_complete" -Default "Focus Game Deck session completed" -Level "OK" -Component "GameLauncher"
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
    # Unregister the Ctrl+C handler to follow resource cleanup best practices
    if ($script:ctrlCHandler) {
        try {
            [Console]::remove_CancelKeyPress($script:ctrlCHandler)
        } catch {
            # Silently ignore errors during handler cleanup
        }
    }

    # Finalize and notarize log file if logging is enabled
    if ($logger) {
        Write-Host "[INFO] Logger: " -NoNewline
        Write-LocalizedHost -Messages $msg -Key "console_finalizing_log" -Default "Finalizing session log..."

        try {
            # TODO: Re-enable in future release
            # Disabled for v1.0 - Firebase log integrity verification is temporarily disabled
            if ($false) { # Disabled for v1.0
                $certificateId = $logger.FinalizeAndNotarizeLogAsync()

                if ($certificateId) {
                    Write-Host "[OK] Logger: " -NoNewline
                    Write-LocalizedHost -Messages $msg -Key "mainLogNotarizedSuccess" -Args @($certificateId) -Default ("[OK] Log notarized successfully. Certificate ID: {0}" -f $certificateId)
                } else {
                    Write-Host "[INFO] Logger: " -NoNewline
                    Write-LocalizedHost -Messages $msg -Key "console_log_finalized" -Default "Log finalization completed"
                }
            } else {
                Write-Host "[INFO] Logger: " -NoNewline
                Write-LocalizedHost -Messages $msg -Key "console_log_finalized" -Default "Log finalization completed"
            }
        } catch {
            Write-Host "[WARNING] Logger: Failed to notarize log - $_"
        }
    }
}
