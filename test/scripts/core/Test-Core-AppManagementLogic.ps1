# =============================================================================
# Test-AppActions.ps1
#
# This script tests the application management logic from the FocusGameDeck
# project without actually launching a game. It simulates game start and
# game end scenarios to verify that managed applications are controlled
# correctly according to the configuration.
#
# Usage:
# 1. Ensure config.json exists with proper managedApps configuration.
# 2. Run this script from the project's root directory:
#    .\test\Test-AppActions.ps1 -GameId apex
#    .\test\Test-AppActions.ps1 -GameId dbd
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$GameId
)

# --- Start of Functions from Invoke-FocusGameDeck.ps1 ---

# Helper function for secure string conversion
function ConvertTo-SecureStringSafe {
    param(
        [string]$PlainText
    )


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
    try {
        return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    } catch {
        Write-BuildLog "ConvertTo-SecureString failed, attempting alternative method: $_" -Level Warning
        # Alternative: create SecureString manually
        $secureString = New-Object System.Security.SecureString
        foreach ($char in $PlainText.ToCharArray()) {
            $secureString.AppendChar($char)
        }
        $secureString.MakeReadOnly()
        return $secureString
    }
}

# Function to manage generic applications
function Invoke-AppAction {
    param(
        [string]$AppId,
        [string]$Action,  # "start-process", "stop-process" and "none"
        [string]$SpecialMode = $null  # For backward compatibility
    )


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
    # Validate app exists in managedApps
    if (-not $config.managedApps.$AppId) {
        Write-BuildLog "WARNING: Application '$AppId' is not defined in managedApps"
        return
    }

    $appConfig = $config.managedApps.$AppId

    Write-BuildLog "  Testing action '$Action' for app '$AppId'..."

    # Handle different action types
    switch ($Action) {
        "start-process" {
            if ($appConfig.path -and $appConfig.path -ne "") {
                $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") { $appConfig.arguments } else { "no arguments" }
                Write-BuildLog "    [SIMULATE] Would start process: $($appConfig.path) $arguments"
            } else {
                Write-BuildLog "    [WARNING] No path specified for app '$AppId'"
            }
        }
        "stop-process" {
            if ($appConfig.processName -and $appConfig.processName -ne "") {
                # Handle multiple process names separated by |
                $processNames = $appConfig.processName -split '\|'

                foreach ($processName in $processNames) {
                    $processName = $processName.Trim()
                    try {
                        $processes = Get-Process -Name $processName -ErrorAction Stop
                        if ($processes) {
                            Write-BuildLog "    [SIMULATE] Would stop process: $processName (Currently running with PID: $($processes[0].Id))"
                        }
                    } catch {
                        Write-BuildLog "    [INFO] Process '$processName' is not currently running"
                    }
                }
            } else {
                Write-BuildLog "    [WARNING] No process name specified for app '$AppId'"
            }
        }
        "start-vtube-studio" {
            Write-BuildLog "    [SIMULATE] Would start VTube Studio integration"
        }
        "stop-vtube-studio" {
            Write-BuildLog "    [SIMULATE] Would stop VTube Studio integration"
        }
        "set-discord-gaming-mode" {
            Write-BuildLog "    [SIMULATE] Would set Discord to gaming mode"
        }
        "restore-discord-normal" {
            Write-BuildLog "    [SIMULATE] Would restore Discord to normal mode"
        }
        "none" {
            Write-BuildLog "    [INFO] No action specified - skipping"
        }
        default {
            Write-BuildLog "    [ERROR] Unknown action: $Action for app: $AppId"
        }
    }
}

# Simulate OBS actions
function Test-OBSActions {
    param(
        [string]$Action  # "start" or "stop"
    )


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
    Write-BuildLog "  Testing OBS $Action..."

    if ($Action -eq "start") {
        $obsProcessName = "obs64"
        $obsProcess = Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue
        if ($obsProcess) {
            Write-BuildLog "    [INFO] OBS is already running (PID: $($obsProcess[0].Id))"
        } else {
            Write-BuildLog "    [SIMULATE] Would start OBS: $($config.integrations.obs.path)"
        }

        if ($config.integrations.obs.replayBuffer) {
            Write-BuildLog "    [SIMULATE] Would start OBS replay buffer via WebSocket"
        }
    } elseif ($Action -eq "stop") {
        if ($config.integrations.obs.replayBuffer) {
            Write-BuildLog "    [SIMULATE] Would stop OBS replay buffer via WebSocket"
        }
    }
}

# --- End of Functions ---

# --- Main Test Logic ---

Write-BuildLog "=== FocusGameDeck App Actions Test ==="
Write-Host ""

# Load configuration file
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"

if (-not (Test-Path $configPath)) {
    Write-BuildLog "Error: config.json not found at $configPath"
    Write-BuildLog "Please create it from config.json.sample."
    exit 1
}

try {
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "Configuration loaded successfully"
} catch {
    Write-BuildLog "Error loading configuration: $_"
    exit 1
}

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    Write-BuildLog "Error: Game ID '$GameId' not found in configuration"
    Write-BuildLog "Available game IDs: $($config.games.PSObject.Properties.Name -join ', ')"
    exit 1
}

Write-BuildLog "Testing game: $($gameConfig.name)"
Write-BuildLog "Apps to manage: $($gameConfig.appsToManage -join ', ')"
Write-Host ""

# Test game start scenario
Write-BuildLog "--- SIMULATING GAME START ---"
Write-Host ""

foreach ($appId in $gameConfig.appsToManage) {
    if ($appId -eq "obs") {
        Test-OBSActions -Action "start"
        continue
    }

    if ($appId -eq "clibor") {
        Invoke-AppAction -AppId "clibor" -Action "toggle-hotkeys"
        continue
    }

    # Get app configuration
    if ($config.managedApps.$appId) {
        $appConfig = $config.managedApps.$appId
        $action = $appConfig.gameStartAction

        Invoke-AppAction -AppId $appId -Action $action
    } else {
        Write-BuildLog "  WARNING: App '$appId' not defined in managedApps"
    }
}

Write-Host ""
Write-BuildLog "--- SIMULATING GAME END ---"
Write-Host ""

# Test Clibor first (special handling)
if ("clibor" -in $gameConfig.appsToManage) {
    Invoke-AppAction -AppId "clibor" -Action "toggle-hotkeys"
}

# Test game end scenario
foreach ($appId in $gameConfig.appsToManage) {
    if ($appId -eq "obs") {
        Test-OBSActions -Action "stop"
        continue
    }

    if ($appId -eq "clibor") {
        # Already handled above
        continue
    }

    # Get app configuration
    if ($config.managedApps.$appId) {
        $appConfig = $config.managedApps.$appId
        $action = $appConfig.gameEndAction

        Invoke-AppAction -AppId $appId -Action $action
    }
}

Write-Host ""
Write-BuildLog "=== Test Complete ==="
Write-Host ""
Write-BuildLog "This test simulated the app management actions without actually executing them."
Write-BuildLog "Review the output above to verify the expected behavior matches your configuration."
