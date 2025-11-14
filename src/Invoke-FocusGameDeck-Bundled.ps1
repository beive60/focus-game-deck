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

# Detect execution mode
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

# Initialize script variables with path resolution for ps2exe bundling
# When ps2exe bundles files, they are extracted to a flat temporary directory
# $PSScriptRoot points to this flat extraction directory
$scriptDir = $PSScriptRoot

if ($isExecutable) {
    # Running as bundled executable - all files are in flat structure at $PSScriptRoot
    $configPath = Join-Path (Split-Path $scriptDir -Parent) "config/config.json"
    
    # Module paths in flat structure (ps2exe extracts all bundled files here)
    $modulePaths = @(
        (Join-Path $scriptDir "Logger.ps1"),
        (Join-Path $scriptDir "ConfigValidator.ps1"),
        (Join-Path $scriptDir "AppManager.ps1"),
        (Join-Path $scriptDir "OBSManager.ps1"),
        (Join-Path $scriptDir "PlatformManager.ps1")
    )
    
    $languageHelperPath = Join-Path $scriptDir "LanguageHelper.ps1"
    $messagesPath = Join-Path (Split-Path $scriptDir -Parent) "localization/messages.json"
} else {
    # Running as script (development mode) - use relative paths
    $configPath = Join-Path $scriptDir "../config/config.json"
    
    $modulePaths = @(
        (Join-Path $scriptDir "modules/Logger.ps1"),
        (Join-Path $scriptDir "modules/ConfigValidator.ps1"),
        (Join-Path $scriptDir "modules/AppManager.ps1"),
        (Join-Path $scriptDir "modules/OBSManager.ps1"),
        (Join-Path $scriptDir "modules/PlatformManager.ps1")
    )
    
    $languageHelperPath = Join-Path $scriptDir "../scripts/LanguageHelper.ps1"
    $messagesPath = Join-Path $scriptDir "../localization/messages.json"
}

# Import modules
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

# Initialize logger
try {
    $logger = Initialize-Logger -Config $config -Messages $msg
    $logger.Info("Focus Game Deck started (Multi-Platform)", "MAIN")
    $logger.Info("Game ID: $GameId", "MAIN")
    $logger.Debug("Self-authentication initialized for log integrity verification", "AUTH")
} catch {
    Write-Warning "Failed to initialize logger: $_"
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
        if ($platformKey -eq "direct") {
            continue
        }
        
        $platformInfo = $detectedPlatforms[$platformKey]
        if ($platformInfo.Available -and $platformInfo.AutoDetectedPath) {
            $currentPath = $config.platformPaths.$platformKey
            
            if ([string]::IsNullOrWhiteSpace($currentPath) -or $currentPath -eq "path/to/platform") {
                $config.platformPaths.$platformKey = $platformInfo.AutoDetectedPath
                if ($logger) {
                    $logger.Info("Auto-detected $platformKey path: $($platformInfo.AutoDetectedPath)", "PLATFORM")
                }
            }
        }
    }
} catch {
    Write-Error "Failed to initialize platform manager: $_"
    if ($logger) { $logger.Error("Platform manager initialization failed: $_", "PLATFORM") }
    exit 1
}

# Validate game configuration
if (-not $config.games.$GameId) {
    Write-Error "Game '$GameId' not found in configuration"
    if ($logger) { $logger.Error("Game '$GameId' not found in configuration", "MAIN") }
    exit 1
}

$gameConfig = $config.games.$GameId
if ($logger) { $logger.Info("Game configuration loaded: $($gameConfig.name)", "MAIN") }

# Validate game configuration
try {
    $validator = New-ConfigValidator -Config $config -Messages $msg -Logger $logger
    $validationResult = $validator.ValidateGameConfig($GameId)
    
    if (-not $validationResult.IsValid) {
        Write-Error "Game configuration validation failed"
        foreach ($error in $validationResult.Errors) {
            Write-Error "  - $error"
            if ($logger) { $logger.Error("Validation error: $error", "VALIDATION") }
        }
        exit 1
    }
    
    if ($logger) { $logger.Info("Game configuration validated successfully", "VALIDATION") }
} catch {
    Write-Error "Configuration validation error: $_"
    if ($logger) { $logger.Error("Configuration validation error: $_", "VALIDATION") }
    exit 1
}

# Initialize app manager
try {
    $appManager = New-AppManager -Config $config -Messages $msg -Logger $logger -PlatformManager $platformManager
    if ($logger) { $logger.Info("App manager initialized", "APPMGR") }
} catch {
    Write-Error "Failed to initialize app manager: $_"
    if ($logger) { $logger.Error("App manager initialization failed: $_", "APPMGR") }
    exit 1
}

# Execute pre-game actions
try {
    if ($logger) { $logger.Info("Executing pre-game actions", "MAIN") }
    
    if ($gameConfig.beforeLaunch -and $gameConfig.beforeLaunch.Count -gt 0) {
        foreach ($action in $gameConfig.beforeLaunch) {
            $appManager.ExecuteAction($action)
        }
    }
    
    if ($logger) { $logger.Info("Pre-game actions completed", "MAIN") }
} catch {
    Write-Error "Failed to execute pre-game actions: $_"
    if ($logger) { $logger.Error("Pre-game actions failed: $_", "MAIN") }
    exit 1
}

# Launch the game
try {
    if ($logger) { $logger.Info("Launching game: $($gameConfig.name)", "MAIN") }
    
    $launchResult = $platformManager.LaunchGame($GameId, $gameConfig)
    
    if (-not $launchResult.Success) {
        Write-Error "Failed to launch game: $($launchResult.Error)"
        if ($logger) { $logger.Error("Game launch failed: $($launchResult.Error)", "MAIN") }
        exit 1
    }
    
    if ($logger) { $logger.Info("Game launched successfully", "MAIN") }
} catch {
    Write-Error "Game launch error: $_"
    if ($logger) { $logger.Error("Game launch error: $_", "MAIN") }
    exit 1
}

# Monitor game process
try {
    if ($logger) { $logger.Info("Monitoring game process: $($gameConfig.processName)", "MAIN") }
    
    $processName = $gameConfig.processName
    if ([string]::IsNullOrWhiteSpace($processName)) {
        $processName = Split-Path -Leaf $gameConfig.executable
        $processName = $processName -replace '\.exe$', ''
    }
    
    # Wait for process to start
    $maxWaitTime = 30
    $waitedTime = 0
    $gameProcess = $null
    
    while ($waitedTime -lt $maxWaitTime -and $null -eq $gameProcess) {
        Start-Sleep -Seconds 1
        $waitedTime++
        $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
    }
    
    if ($null -eq $gameProcess) {
        Write-Warning "Game process '$processName' not found after $maxWaitTime seconds"
        if ($logger) { $logger.Warning("Game process not found: $processName", "MAIN") }
    } else {
        if ($logger) { $logger.Info("Game process detected: $processName (PID: $($gameProcess.Id))", "MAIN") }
        
        # Wait for process to exit
        $gameProcess.WaitForExit()
        
        if ($logger) { $logger.Info("Game process exited", "MAIN") }
    }
} catch {
    Write-Warning "Error monitoring game process: $_"
    if ($logger) { $logger.Warning("Process monitoring error: $_", "MAIN") }
}

# Execute post-game actions
try {
    if ($logger) { $logger.Info("Executing post-game actions", "MAIN") }
    
    if ($gameConfig.afterExit -and $gameConfig.afterExit.Count -gt 0) {
        foreach ($action in $gameConfig.afterExit) {
            $appManager.ExecuteAction($action)
        }
    }
    
    if ($logger) { $logger.Info("Post-game actions completed", "MAIN") }
} catch {
    Write-Error "Failed to execute post-game actions: $_"
    if ($logger) { $logger.Error("Post-game actions failed: $_", "MAIN") }
}

# Cleanup and exit
if ($logger) {
    $logger.Info("Focus Game Deck session completed", "MAIN")
}

Write-Host "Game session completed successfully"
exit 0
