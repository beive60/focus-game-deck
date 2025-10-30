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

# Initialize script variables
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "../config/config.json"

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

# Load and validate configuration
try {
    Write-Host "Loading configuration..." -ForegroundColor Cyan
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    Write-Host "Configuration loaded successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}

# Initialize logger
# Note: Passing an empty messages object as i18n is disabled for this debug script.
$msg = @{}
try {
    $logger = Initialize-Logger -Config $config -Messages $msg
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
Write-Host "Validating configuration..." -ForegroundColor Cyan
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
    $errorMsg = "Error: Game ID '{0}' not found in configuration." -f $GameId
    Write-Host $errorMsg -ForegroundColor Red
    Write-Host ("Available game IDs: {0}" -f ($config.games.PSObject.Properties.Name -join ', '))
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
    Write-Host $errorMsg -ForegroundColor Red
    Write-Host "Available platforms: $($availablePlatforms -join ', ')" -ForegroundColor Yellow
    if ($logger) { $logger.Error($errorMsg, "PLATFORM") }
    exit 1
}

if ($logger) {
    $logger.Info("Game configuration loaded: $($gameConfig.name) (Platform: $gamePlatform)", "MAIN")
}

# Initialize managers
$appManager = New-AppManager -Config $config -Messages $msg
$obsManager = $null

if ("obs" -in $gameConfig.appsToManage) {
    if ($config.obs) {
        $obsManager = New-OBSManager -OBSConfig $config.obs -Messages $msg
        if ($logger) { $logger.Info("OBS manager initialized", "OBS") }
    } else {
        Write-Warning "OBS is in appsToManage but OBS configuration is missing"
        if ($logger) { $logger.Warning("OBS configuration missing", "OBS") }
    }
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

    # Filter out special apps for normal app manager processing
    $normalApps = $gameConfig.appsToManage | Where-Object { $_ -notin @("obs", "clibor") }

    # Handle Clibor hotkey toggle (special case)
    if ("clibor" -in $gameConfig.appsToManage) {
        $appManager.InvokeAction("clibor", "toggle-hotkeys")
        if ($logger) { $logger.Info("Clibor hotkeys toggled", "CLEANUP") }
    }

    # Process normal applications shutdown
    if ($normalApps.Count -gt 0) {
        $appManager.ProcessShutdownSequence($normalApps)
        if ($logger) { $logger.Info("Application shutdown sequence completed", "CLEANUP") }
    }

    # Handle OBS replay buffer shutdown
    if ($obsManager -and $config.obs.replayBuffer) {
        if ($obsManager.Connect()) {
            $obsManager.StopReplayBuffer()
            $obsManager.Disconnect()
            if ($logger) { $logger.Info("OBS replay buffer stopped", "CLEANUP") }
        }
    }

    if ($logger) { $logger.Info("Game cleanup completed", "CLEANUP") }
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

    # Filter out special apps for normal app manager processing
    $normalApps = $gameConfig.appsToManage | Where-Object { $_ -notin @("obs", "clibor") }

    # Handle OBS startup (special case)
    if ("obs" -in $gameConfig.appsToManage -and $obsManager) {
        Write-Host "Starting OBS..." -ForegroundColor Cyan
        if ($obsManager.StartOBS($config.paths.obs)) {
            if ($logger) { $logger.Info("OBS started successfully", "OBS") }

            # Handle replay buffer if configured
            if ($config.obs.replayBuffer) {
                if ($obsManager.Connect()) {
                    $obsManager.StartReplayBuffer()
                    $obsManager.Disconnect()
                    if ($logger) { $logger.Info("OBS replay buffer started", "OBS") }
                }
            }
        } else {
            Write-Warning "Failed to start OBS"
            if ($logger) { $logger.Warning("Failed to start OBS", "OBS") }
        }
    }

    # Handle Clibor hotkey toggle (special case)
    if ("clibor" -in $gameConfig.appsToManage) {
        $appManager.InvokeAction("clibor", "toggle-hotkeys")
        if ($logger) { $logger.Info("Clibor hotkeys toggled for game start", "APP") }
    }

    # Process normal applications startup
    if ($normalApps.Count -gt 0) {
        Write-Host "Starting managed applications..." -ForegroundColor Cyan
        $appManager.ProcessStartupSequence($normalApps)
        if ($logger) { $logger.Info("Application startup sequence completed", "APP") }
    }

    # Launch game via appropriate platform
    Write-Host "Launching game via $($detectedPlatforms[$gamePlatform].Name)..." -ForegroundColor Cyan
    try {
        $launcherProcess = $platformManager.LaunchGame($gamePlatform, $gameConfig)
        Write-Host ("Starting game: {0}" -f $gameConfig.name) -ForegroundColor Green
        if ($logger) { $logger.Info("Game launch command sent to $($detectedPlatforms[$gamePlatform].Name): $($gameConfig.name)", "GAME") }
    } catch {
        $errorMsg = "Failed to launch game via $($detectedPlatforms[$gamePlatform].Name): $_"
        Write-Error $errorMsg
        if ($logger) { $logger.Error($errorMsg, "GAME") }
        throw
    }

    # Wait for actual game process to start (not the launcher)
    Write-Host "Waiting for game process to start..." -ForegroundColor Yellow
    $gameProcess = $null
    $processStartTimeout = 300  # 5 minutes timeout
    $startTime = Get-Date

    do {
        Start-Sleep -Seconds 3
        $elapsed = (Get-Date) - $startTime
        if ([int]$elapsed.TotalSeconds % 30 -eq 0 -and $elapsed.TotalSeconds -gt 0) {
            Write-Host "." -NoNewline -ForegroundColor Yellow
        }
        $gameProcess = Get-Process $gameConfig.processName -ErrorAction SilentlyContinue
    } while (-not $gameProcess -and $elapsed.TotalSeconds -lt $processStartTimeout)

    if ($gameProcess) {
        Write-Host ("`nNow monitoring process: {0}. The script will continue after the game exits." -f $gameConfig.name) -ForegroundColor Green
        if ($logger) { $logger.Info("Game process detected and monitoring started: $($gameConfig.processName)", "GAME") }

        # Wait for the game process to end.
        # If direct Wait-Process fails (e.g., due to admin privilege issues),
        # fall back to polling the process status.
        try {
            if ($logger) { $logger.Debug("Attempting to wait for process directly: $($gameProcess.Name) (PID: $($gameProcess.Id))", "GAME") }
            Wait-Process -InputObject $gameProcess -ErrorAction Stop
        }
        catch {
            if ($logger) { $logger.Warning("Direct wait failed. Falling back to polling for process exit: $($gameProcess.Name) (PID: $($gameProcess.Id)). This can happen with admin-level processes.", "GAME") }
            Write-Host "`nDirect process wait failed. Monitoring process in fallback mode (polling every 3s). This can happen with admin-level processes." -ForegroundColor Yellow

            while ($true) {
                $processCheck = Get-Process -Id $gameProcess.Id -ErrorAction SilentlyContinue
                if (-not $processCheck) {
                    if ($logger) { $logger.Info("Process has exited (detected by polling): $($gameProcess.Name) (PID: $($gameProcess.Id))", "GAME") }
                    break # Exit the loop
                }
                Start-Sleep -Seconds 3
            }
        }

        Write-Host ("Game has exited: {0}" -f $gameConfig.name) -ForegroundColor Yellow
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

    Write-Host "Focus Game Deck session completed." -ForegroundColor Green
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
            Write-Host "Finalizing session log..." -ForegroundColor Cyan
            $certificateId = $logger.FinalizeAndNotarizeLogAsync()

            if ($certificateId) {
                Write-Host "[OK] " -NoNewline -ForegroundColor Green
                Write-Host "Log successfully notarized. Certificate ID: " -NoNewline -ForegroundColor White
                Write-Host $certificateId -ForegroundColor Yellow
                Write-Host "  This certificate can be used to verify log integrity if needed." -ForegroundColor Gray
            } else {
                Write-Host "Log finalized (notarization disabled or failed)" -ForegroundColor Gray
            }
        } catch {
            Write-Warning "Failed to notarize log: $_"
        }
    }
}