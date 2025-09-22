# =============================================================================
# Test-ConfigValidation.ps1
#
# This script tests the configuration validation logic from the FocusGameDeck
# project. It verifies that the configuration structure is correct and all
# required properties are present.
#
# Usage:
# 1. Ensure config.json exists with proper configuration.
# 2. Run this script from the project's root directory:
#    .\test\Test-ConfigValidation.ps1
# =============================================================================

# --- Start of Functions from Invoke-FocusGameDeck.ps1 ---

# Validate configuration structure
function Test-ConfigStructure {
    param(
        [object]$Config,
        [string]$GameId
    )
    
    $errors = @()
    $gameConfig = $Config.games.$GameId
    
    Write-Host "Validating configuration structure for game: $GameId" -ForegroundColor Cyan
    
    # Check if managedApps section exists
    if (-not $Config.managedApps) {
        $errors += "Missing 'managedApps' section in configuration"
    }
    
    # Check if appsToManage exists for this game
    if (-not $gameConfig.appsToManage) {
        $errors += "Missing 'appsToManage' array for game '$GameId'"
    } else {
        # Validate each app in appsToManage
        foreach ($appId in $gameConfig.appsToManage) {
            Write-Host "  Checking app: $appId" -ForegroundColor Gray
            
            if ($appId -eq "obs") {
                # Special case for OBS - skip validation
                Write-Host "    [INFO] OBS is a special app - skipping managedApps validation" -ForegroundColor Gray
                continue
            }
            
            if (-not $Config.managedApps.$appId) {
                $errors += "Application '$appId' is referenced in game '$GameId' but not defined in managedApps"
            } else {
                $appConfig = $Config.managedApps.$appId
                
                # Validate required properties
                if (-not $appConfig.PSObject.Properties.Name -contains "processName") {
                    $errors += "Application '$appId' is missing 'processName' property"
                }
                if (-not $appConfig.PSObject.Properties.Name -contains "gameStartAction") {
                    $errors += "Application '$appId' is missing 'gameStartAction' property"
                }
                if (-not $appConfig.PSObject.Properties.Name -contains "gameEndAction") {
                    $errors += "Application '$appId' is missing 'gameEndAction' property"
                }
                
                # Validate action values
                $validActions = @("start-process", "stop-process", "toggle-hotkeys", "none")
                if ($appConfig.gameStartAction -and $appConfig.gameStartAction -notin $validActions) {
                    $errors += "Application '$appId' has invalid gameStartAction: '$($appConfig.gameStartAction)'. Valid values: $($validActions -join ', ')"
                }
                if ($appConfig.gameEndAction -and $appConfig.gameEndAction -notin $validActions) {
                    $errors += "Application '$appId' has invalid gameEndAction: '$($appConfig.gameEndAction)'. Valid values: $($validActions -join ', ')"
                }
                
                # Check logical consistency
                if ($appConfig.gameStartAction -eq "start-process" -and (-not $appConfig.path -or $appConfig.path -eq "")) {
                    $errors += "Application '$appId' has gameStartAction 'start-process' but no path specified"
                }
                if ($appConfig.gameEndAction -eq "start-process" -and (-not $appConfig.path -or $appConfig.path -eq "")) {
                    $errors += "Application '$appId' has gameEndAction 'start-process' but no path specified"
                }
                if (($appConfig.gameStartAction -eq "stop-process" -or $appConfig.gameEndAction -eq "stop-process") -and (-not $appConfig.processName -or $appConfig.processName -eq "")) {
                    $errors += "Application '$appId' has stop-process action but no processName specified"
                }
                if (($appConfig.gameStartAction -eq "toggle-hotkeys" -or $appConfig.gameEndAction -eq "toggle-hotkeys") -and (-not $appConfig.path -or $appConfig.path -eq "")) {
                    $errors += "Application '$appId' has toggle-hotkeys action but no path specified"
                }
                
                Write-Host "    [OK] App '$appId' configuration is valid" -ForegroundColor Green
            }
        }
    }
    
    # Check required paths
    if (-not $Config.paths.steam) {
        $errors += "Missing 'paths.steam' in configuration"
    }
    
    # Check OBS-specific configuration if OBS is managed
    if ("obs" -in $gameConfig.appsToManage) {
        if (-not $Config.paths.obs) {
            $errors += "OBS is managed but 'paths.obs' is not defined"
        }
        if (-not $Config.obs) {
            $errors += "OBS is managed but 'obs' configuration section is missing"
        }
    }
    
    return $errors
}

# --- End of Functions ---

# --- Main Test Logic ---

Write-Host "=== FocusGameDeck Configuration Validation Test ===" -ForegroundColor White -BackgroundColor Blue
Write-Host ""

# Load configuration file
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "..\config\config.json"

if (-not (Test-Path $configPath)) {
    Write-Host "Error: config.json not found at $configPath" -ForegroundColor Red
    Write-Host "Please create it from config.json.sample." -ForegroundColor Red
    exit 1
}

try {
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "Error loading configuration: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Available games:" -ForegroundColor Yellow
foreach ($gameId in $config.games.PSObject.Properties.Name) {
    $gameName = $config.games.$gameId.name
    Write-Host "  - $gameId ($gameName)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "--- VALIDATING ALL GAME CONFIGURATIONS ---" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host ""

$allErrors = @()

foreach ($gameId in $config.games.PSObject.Properties.Name) {
    $gameErrors = Test-ConfigStructure -Config $config -GameId $gameId
    if ($gameErrors.Count -gt 0) {
        $allErrors += $gameErrors
        Write-Host "Game '$gameId' has $($gameErrors.Count) error(s):" -ForegroundColor Red
        foreach ($errorMsg in $gameErrors) {
            Write-Host "  - $errorMsg" -ForegroundColor Red
        }
    } else {
        Write-Host "Game '$gameId' configuration is valid" -ForegroundColor Green
    }
    Write-Host ""
}

Write-Host "--- VALIDATION SUMMARY ---" -ForegroundColor White -BackgroundColor DarkBlue
if ($allErrors.Count -eq 0) {
    Write-Host "✅ All configurations are valid!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your configuration is ready to use." -ForegroundColor Green
} else {
    Write-Host "❌ Found $($allErrors.Count) validation error(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the errors above before using the script." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor White -BackgroundColor Blue