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

    try {
        return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    } catch {
        Write-Warning "ConvertTo-SecureString failed, attempting alternative method: $_"
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
        [string]$Action,  # "start-process", "stop-process", "toggle-hotkeys", "none"
        [string]$SpecialMode = $null  # For backward compatibility
    )

    # Validate app exists in managedApps
    if (-not $config.managedApps.$AppId) {
        Write-Host "WARNING: Application '$AppId' is not defined in managedApps"
        return
    }

    $appConfig = $config.managedApps.$AppId

    Write-Host "  Testing action '$Action' for app '$AppId'..."

    # Handle different action types
    switch ($Action) {
        "start-process" {
            if ($appConfig.path -and $appConfig.path -ne "") {
                $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") { $appConfig.arguments } else { "no arguments" }
                Write-Host "    [SIMULATE] Would start process: $($appConfig.path) $arguments"
            } else {
                Write-Host "    [WARNING] No path specified for app '$AppId'"
            }
        }
        "stop-process" {
            if ($appConfig.processName -and $appConfig.processName -ne "") {
                # Handle multiple process names separated by |
                $processNames = $appConfig.processName -split '/|'

                foreach ($processName in $processNames) {
                    $processName = $processName.Trim()
                    try {
                        $processes = Get-Process -Name $processName -ErrorAction Stop
                        if ($processes) {
                            Write-Host "    [SIMULATE] Would stop process: $processName (Currently running with PID: $($processes[0].Id))"
                        }
                    } catch {
                        Write-Host "    [INFO] Process '$processName' is not currently running"
                    }
                }
            } else {
                Write-Host "    [WARNING] No process name specified for app '$AppId'"
            }
        }
        "toggle-hotkeys" {
            # Special handling for applications that need hotkey toggling (like Clibor)
            if ($appConfig.path -and $appConfig.path -ne "") {
                $arguments = if ($appConfig.arguments -and $appConfig.arguments -ne "") { $appConfig.arguments } else { "/hs" }
                Write-Host "    [SIMULATE] Would toggle hotkeys: $($appConfig.path) $arguments"
            } else {
                Write-Host "    [WARNING] No path specified for app '$AppId'"
            }
        }
        "pause-wallpaper" {
            # Wallpaper Engine pause functionality
            if ($appConfig.path -and $appConfig.path -ne "") {
                # Determine correct executable (32-bit vs 64-bit)
                $executablePath = $appConfig.path
                $is64Bit = [Environment]::Is64BitOperatingSystem
                $executableName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)

                if ($executableName -eq "wallpaper32" -and $is64Bit) {
                    $wallpaper64Path = Join-Path ([System.IO.Path]::GetDirectoryName($executablePath)) "wallpaper64.exe"
                    if (Test-Path $wallpaper64Path) {
                        $executablePath = $wallpaper64Path
                        Write-Host "    [INFO] Auto-selected 64-bit version: $executablePath"
                    }
                }

                Write-Host "    [SIMULATE] Would pause Wallpaper Engine: $executablePath -control pause"
            } else {
                Write-Host "    [WARNING] No path specified for Wallpaper Engine app '$AppId'"
            }
        }
        "play-wallpaper" {
            # Wallpaper Engine resume functionality
            if ($appConfig.path -and $appConfig.path -ne "") {
                # Determine correct executable (32-bit vs 64-bit)
                $executablePath = $appConfig.path
                $is64Bit = [Environment]::Is64BitOperatingSystem
                $executableName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)

                if ($executableName -eq "wallpaper32" -and $is64Bit) {
                    $wallpaper64Path = Join-Path ([System.IO.Path]::GetDirectoryName($executablePath)) "wallpaper64.exe"
                    if (Test-Path $wallpaper64Path) {
                        $executablePath = $wallpaper64Path
                        Write-Host "    [INFO] Auto-selected 64-bit version: $executablePath"
                    }
                }

                Write-Host "    [SIMULATE] Would resume Wallpaper Engine: $executablePath -control play"
            } else {
                Write-Host "    [WARNING] No path specified for Wallpaper Engine app '$AppId'"
            }
        }
        "start-vtube-studio" {
            Write-Host "    [SIMULATE] Would start VTube Studio integration"
        }
        "stop-vtube-studio" {
            Write-Host "    [SIMULATE] Would stop VTube Studio integration"
        }
        "set-discord-gaming-mode" {
            Write-Host "    [SIMULATE] Would set Discord to gaming mode"
        }
        "restore-discord-normal" {
            Write-Host "    [SIMULATE] Would restore Discord to normal mode"
        }
        "none" {
            Write-Host "    [INFO] No action specified - skipping"
        }
        default {
            Write-Host "    [ERROR] Unknown action: $Action for app: $AppId"
        }
    }
}

# Simulate OBS actions
function Test-OBSActions {
    param(
        [string]$Action  # "start" or "stop"
    )

    Write-Host "  Testing OBS $Action..."

    if ($Action -eq "start") {
        $obsProcessName = "obs64"
        $obsProcess = Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue
        if ($obsProcess) {
            Write-Host "    [INFO] OBS is already running (PID: $($obsProcess[0].Id))"
        } else {
            Write-Host "    [SIMULATE] Would start OBS: $($config.integrations.obs.path)"
        }

        if ($config.integrations.obs.replayBuffer) {
            Write-Host "    [SIMULATE] Would start OBS replay buffer via WebSocket"
        }
    } elseif ($Action -eq "stop") {
        if ($config.integrations.obs.replayBuffer) {
            Write-Host "    [SIMULATE] Would stop OBS replay buffer via WebSocket"
        }
    }
}

# --- End of Functions ---

# --- Main Test Logic ---

Write-Host "=== FocusGameDeck App Actions Test ==="
Write-Host ""

# Load configuration file
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"

if (-not (Test-Path $configPath)) {
    Write-Host "Error: config.json not found at $configPath"
    Write-Host "Please create it from config.json.sample."
    exit 1
}

try {
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Configuration loaded successfully"
} catch {
    Write-Host "Error loading configuration: $_"
    exit 1
}

# Get game configuration
$gameConfig = $config.games.$GameId
if (-not $gameConfig) {
    Write-Host "Error: Game ID '$GameId' not found in configuration"
    Write-Host "Available game IDs: $($config.games.PSObject.Properties.Name -join ', ')"
    exit 1
}

Write-Host "Testing game: $($gameConfig.name)"
Write-Host "Apps to manage: $($gameConfig.appsToManage -join ', ')"
Write-Host ""

# Test game start scenario
Write-Host "--- SIMULATING GAME START ---"
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
        Write-Host "  WARNING: App '$appId' not defined in managedApps"
    }
}

Write-Host ""
Write-Host "--- SIMULATING GAME END ---"
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
Write-Host "=== Test Complete ==="
Write-Host ""
Write-Host "This test simulated the app management actions without actually executing them."
Write-Host "Review the output above to verify the expected behavior matches your configuration."
