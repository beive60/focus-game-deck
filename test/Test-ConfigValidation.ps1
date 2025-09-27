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

# Import updated ConfigValidator module
$scriptDir = $PSScriptRoot
$configValidatorPath = Join-Path $scriptDir "..\src\modules\ConfigValidator.ps1"
if (Test-Path $configValidatorPath) {
    . $configValidatorPath
} else {
    Write-Error "ConfigValidator module not found: $configValidatorPath"
    exit 1
}

# Validate configuration structure using updated validator
function Test-ConfigStructure {
    param(
        [object]$Config,
        [string]$GameId
    )

    $errors = @()
    $gameConfig = $Config.games.$GameId

    Write-Host "Validating configuration structure for game: $GameId" -ForegroundColor Cyan

    # Use the updated ConfigValidator for validation
    $messages = @{
        config_validation_passed = "Configuration validation passed"
        config_validation_failed = "Configuration validation failed"
    }

    $validator = New-ConfigValidator -Config $Config -Messages $messages
    $isValid = $validator.ValidateConfiguration($GameId)
    $report = $validator.GetValidationReport()

    # Show validation details
    if ($report.Errors.Count -gt 0) {
        Write-Host "Game '$GameId' has $($report.Errors.Count) error(s):" -ForegroundColor Red
        foreach ($error in $report.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
    } else {
        Write-Host "  [OK] Game '$GameId' configuration is valid" -ForegroundColor Green
    }

    if ($report.Warnings.Count -gt 0) {
        Write-Host "Game '$GameId' has $($report.Warnings.Count) warning(s):" -ForegroundColor Yellow
        foreach ($warning in $report.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
    }

    # Return the errors from the updated validator
    return $report.Errors
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
    Write-Host "All configurations are valid!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your configuration is ready to use." -ForegroundColor Green
} else {
    Write-Host "Found $($allErrors.Count) validation error(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the errors above before using the script." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor White -BackgroundColor Blue
