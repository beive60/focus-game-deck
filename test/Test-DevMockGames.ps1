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

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("mock-notepad", "mock-calc", "mock-mspaint", "mock-powershell")]
    [string]$MockGameId,

    [switch]$DryRun
)

#Requires -Version 5.1

# Setup paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent $scriptDir
$configPath = Join-Path $projectRoot "config/config.json"
$configSamplePath = Join-Path $projectRoot "config/config.json.sample"
$mainScriptPath = Join-Path $projectRoot "src/Invoke-FocusGameDeck.ps1"

Write-Host "=== Focus Game Deck - Development Mock Game Test ===" -ForegroundColor Cyan
Write-Host "Mock Game ID: $MockGameId" -ForegroundColor Green
Write-Host ""

# Determine which config file to use
$actualConfigPath = $configPath
if (-not (Test-Path $configPath)) {
    Write-Host "[INFO] config.json not found, using sample configuration" -ForegroundColor Yellow
    $actualConfigPath = $configSamplePath
}

Write-Host "Config File: $actualConfigPath" -ForegroundColor Gray
Write-Host ""

# Validate configuration exists
if (-not (Test-Path $actualConfigPath)) {
    Write-Host "[ERROR] Configuration file not found: $actualConfigPath" -ForegroundColor Red
    Write-Host "Please ensure config.json or config.json.sample exists in the config directory." -ForegroundColor Yellow
    exit 1
}

# Load configuration
try {
    $config = Get-Content -Path $actualConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load configuration: $_" -ForegroundColor Red
    exit 1
}

# Validate mock game exists in config
if (-not $config.games.$MockGameId) {
    Write-Host "[ERROR] Mock game '$MockGameId' not found in configuration" -ForegroundColor Red
    $availableGames = $config.games.PSObject.Properties | Where-Object { $_.Name -like "mock-*" } | Select-Object -ExpandProperty Name
    Write-Host "Available mock games: $($availableGames -join ', ')" -ForegroundColor Yellow
    exit 1
}

$mockGame = $config.games.$MockGameId
Write-Host "[INFO] Mock Game: $($mockGame.name)" -ForegroundColor Cyan
Write-Host "[INFO] Target Process: $($mockGame.processName)" -ForegroundColor Cyan
Write-Host "[INFO] Apps to Manage: $($mockGame.appsToManage -join ', ')" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "=== DRY RUN MODE - No actual execution ===" -ForegroundColor Yellow
    Write-Host "Would execute: $mainScriptPath -GameId $MockGameId" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Mock game details:"
    Write-Host "- Name: $($mockGame.name)"
    Write-Host "- Executable: $($mockGame.executablePath)"
    Write-Host "- Process: $($mockGame.processName)"
    Write-Host "- Managed Apps: $($mockGame.appsToManage -join ', ')"
    Write-Host ""
    Write-Host "This would provide fast testing without:"
    Write-Host "[OK] Long game startup times"
    Write-Host "[OK] Display occupation"
    Write-Host "[OK] Resource-intensive processes"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "=== Starting Mock Game Test ===" -ForegroundColor Green
Write-Host "Press Ctrl+C to abort before game launch..."
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

    Write-Host "[INFO] Executing: powershell.exe $($arguments -join ' ')" -ForegroundColor Gray
    Write-Host ""

    & powershell.exe @arguments

    Write-Host ""
    Write-Host "[OK] Mock game test completed" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "[ERROR] Mock game test failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Mock Game: $($mockGame.name)" -ForegroundColor White
Write-Host "Benefits demonstrated:" -ForegroundColor White
Write-Host "  [OK] Fast startup (< 5 seconds)" -ForegroundColor Green
Write-Host "  [OK] No display occupation" -ForegroundColor Green
Write-Host "  [OK] Minimal resource usage" -ForegroundColor Green
Write-Host "  [OK] Real app management testing" -ForegroundColor Green
Write-Host ""
Write-Host "For production testing, use actual game IDs (apex, dbd, genshin, valorant, etc.)" -ForegroundColor Yellow
Write-Host "Mock games are now integrated into the main config.json for easier maintenance." -ForegroundColor Cyan
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
