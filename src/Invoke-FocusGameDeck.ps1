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
$configPath = Join-Path $scriptDir "..\config\config.json"
$languageHelperPath = Join-Path $scriptDir "..\scripts\LanguageHelper.ps1"
$messagesPath = Join-Path $scriptDir "..\config\messages.json"

# Import modules
$modulePaths = @(
    (Join-Path $scriptDir "modules\Logger.ps1"),
    (Join-Path $scriptDir "modules\ConfigValidator.ps1"),
    (Join-Path $scriptDir "modules\AppManager.ps1"),
    (Join-Path $scriptDir "modules\OBSManager.ps1"),
    (Join-Path $scriptDir "modules\PlatformManager.ps1")
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# Import language helper functions
if (Test-Path $languageHelperPath) {
    . $languageHelperPath
} else {
    Write-Warning "Language helper not found: $languageHelperPath"
}

# Load and validate configuration
try {
    Write-Host "Loading configuration..." -ForegroundColor Cyan
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Detect language and load messages
    $langCode = Get-DetectedLanguage -ConfigData $config
    Set-CultureByLanguage -LanguageCode $langCode
    $msg = Get-LocalizedMessages -MessagesPath $messagesPath -LanguageCode $langCode

    Write-Host "Configuration loaded successfully. Language: $langCode" -ForegroundColor Green
} catch {
    Write-Error "Failed to load configuration: $_"
    exit 1
}

# Initialize logger
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
    $errorMsg = $msg.error_game_id_not_found -f $GameId
    Write-Host $errorMsg -ForegroundColor Red
    Write-Host ($msg.available_game_ids -f ($config.games.PSObject.Properties.Name -join ', '))
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
        Write-Host $msg.cleanup_initiated_interrupted
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
        $platformManager.LaunchGame($gamePlatform, $gameConfig)
        Write-Host ($msg.starting_game -f $gameConfig.name) -ForegroundColor Green
        if ($logger) { $logger.Info("Game launch command sent to $($detectedPlatforms[$gamePlatform].Name): $($gameConfig.name)", "GAME") }
    } catch {
        $errorMsg = "Failed to launch game via $($detectedPlatforms[$gamePlatform].Name): $_"
        Write-Error $errorMsg
        if ($logger) { $logger.Error($errorMsg, "GAME") }
        throw
    }

    # Wait for game process to start
    Write-Host "Waiting for game process to start..." -ForegroundColor Yellow
    $processStartTimeout = 300  # 5 minutes timeout
    $processStartElapsed = 0

    while (!(Get-Process $gameConfig.processName -ErrorAction SilentlyContinue) -and $processStartElapsed -lt $processStartTimeout) {
        Start-Sleep -Seconds 30
        $processStartElapsed += 30
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }

    if (Get-Process $gameConfig.processName -ErrorAction SilentlyContinue) {
        Write-Host "`n$($msg.monitoring_process -f $gameConfig.name)" -ForegroundColor Green
        if ($logger) { $logger.Info("Game process detected and monitoring started: $($gameConfig.processName)", "GAME") }

        # Wait for game process to end
        while (Get-Process $gameConfig.processName -ErrorAction SilentlyContinue) {
            Start-Sleep -Seconds 10
        }

        Write-Host ($msg.game_exited -f $gameConfig.name) -ForegroundColor Yellow
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
                Write-Host "✓ " -NoNewline -ForegroundColor Green
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
