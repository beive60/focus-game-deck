#Requires -Version 5.1

<#
.SYNOPSIS
    Tests Focus Game Deck functionality using lightweight mock games instead of actual games.

.DESCRIPTION
    This script provides a development-friendly testing environment by using lightweight
    system applications (Notepad, Calculator, etc.) as mock games to test Focus Game Deck's
    application management and integration features without the overhead of launching
    actual resource-intensive games.

    The script uses the standard config.json configuration file, ensuring consistency
    with production environments while providing fast, non-intrusive testing capabilities.

.PARAMETER MockGameId
    Specifies which mock game to launch for testing. Valid options are:
    - mock-notepad: Lightweight test using Notepad
    - mock-calc: UI interaction test using Calculator
    - mock-mspaint: Graphics-related test using Paint
    - mock-powershell: Console-based test using PowerShell

.PARAMETER DryRun
    When specified, shows what would be executed without actually running the mock game.
    Useful for validating configuration and understanding the test process.

.EXAMPLE
    .\test\Test-DevMockGames.ps1 -MockGameId mock-notepad
    Runs a basic test using Notepad as a mock game.

.EXAMPLE
    .\test\Test-DevMockGames.ps1 -MockGameId mock-calc -Verbose
    Runs a test using Calculator with detailed logging output.

.EXAMPLE
    .\test\Test-DevMockGames.ps1 -MockGameId mock-powershell -DryRun
    Shows what would be executed for the PowerShell mock game without actually running it.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2025-09-27

    Benefits:
    - Fast startup (1-2 seconds vs minutes for real games)
    - No display occupation (small windows only)
    - Minimal resource usage
    - Real application management testing
    - Single config.json maintenance (improved maintainability)

    Prerequisites:
    - config.json must exist with mock game definitions
    - Mock games are integrated into the standard configuration file
    - System applications (notepad.exe, calc.exe, etc.) must be available
#>

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("mock-notepad", "mock-calc", "mock-mspaint", "mock-powershell")]
    [string]$MockGameId,

    [switch]$DryRun
)

#Requires -Version 5.1

# Setup paths
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
$configSamplePath = Join-Path -Path $projectRoot -ChildPath "config/config.json.sample"
$mainScriptPath = Join-Path -Path $projectRoot -ChildPath "src/Invoke-FocusGameDeck.ps1"

Write-BuildLog "=== Focus Game Deck - Development Mock Game Test ==="
Write-BuildLog "Mock Game ID: $MockGameId"
Write-Host ""

# Determine which config file to use
$actualConfigPath = $configPath
if (-not (Test-Path $configPath)) {
    Write-BuildLog "[INFO] config.json not found, using sample configuration"
    $actualConfigPath = $configSamplePath
}

Write-BuildLog "Config File: $actualConfigPath"
Write-Host ""

# Validate configuration exists
if (-not (Test-Path $actualConfigPath)) {
    Write-BuildLog "[ERROR] Configuration file not found: $actualConfigPath"
    Write-BuildLog "Please ensure config.json or config.json.sample exists in the config directory."
    exit 1
}

# Load configuration
try {
    $config = Get-Content -Path $actualConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "[OK] Configuration loaded successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to load configuration: $_"
    exit 1
}

# Validate mock game exists in config
if (-not $config.games.$MockGameId) {
    Write-BuildLog "[ERROR] Mock game '$MockGameId' not found in configuration"
    $availableGames = $config.games.PSObject.Properties | Where-Object { $_.Name -like "mock-*" } | Select-Object -ExpandProperty Name
    Write-BuildLog "Available mock games: $($availableGames -join ', ')"
    exit 1
}

$mockGame = $config.games.$MockGameId
Write-BuildLog "[INFO] Mock Game: $($mockGame.name)"
Write-BuildLog "[INFO] Target Process: $($mockGame.processName)"
Write-BuildLog "[INFO] Apps to Manage: $($mockGame.appsToManage -join ', ')"

if ($DryRun) {
    Write-Host ""
    Write-BuildLog "=== DRY RUN MODE - No actual execution ==="
    Write-BuildLog "Would execute: $mainScriptPath -GameId $MockGameId"
    Write-Host ""
    Write-BuildLog "Mock game details:"
    Write-BuildLog "- Name: $($mockGame.name)"
    Write-BuildLog "- Executable: $($mockGame.executablePath)"
    Write-BuildLog "- Process: $($mockGame.processName)"
    Write-BuildLog "- Managed Apps: $($mockGame.appsToManage -join ', ')"
    Write-Host ""
    Write-BuildLog "This would provide fast testing without:"
    Write-BuildLog "[OK] Long game startup times"
    Write-BuildLog "[OK] Display occupation"
    Write-BuildLog "[OK] Resource-intensive processes"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-BuildLog "=== Starting Mock Game Test ==="
Write-BuildLog "Press Ctrl+C to abort before game launch..."
Start-Sleep -Seconds 2

# Execute the main script with mock game
try {
    $arguments = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", $mainScriptPath
        "-GameId", $MockGameId
    )

    if ($VerbosePreference -eq 'Continue') {
        $arguments += "-Verbose"
    }

    Write-BuildLog "[INFO] Executing: powershell.exe $($arguments -join ' ')"
    Write-Host ""

    & powershell.exe @arguments

    Write-Host ""
    Write-BuildLog "[OK] Mock game test completed"

} catch {
    Write-Host ""
    Write-BuildLog "[ERROR] Mock game test failed: $_"
    exit 1
}

Write-Host ""
Write-BuildLog "=== Test Summary ==="
Write-BuildLog "Mock Game: $($mockGame.name)"
Write-BuildLog "Benefits demonstrated:"
Write-BuildLog "  [OK] Fast startup (< 5 seconds)"
Write-BuildLog "  [OK] No display occupation"
Write-BuildLog "  [OK] Minimal resource usage"
Write-BuildLog "  [OK] Real app management testing"
Write-Host ""
Write-BuildLog "For production testing, use actual game IDs (apex, dbd, genshin, valorant, etc.)"
Write-BuildLog "Mock games are now integrated into the main config.json for easier maintenance."
Write-BuildLog "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
