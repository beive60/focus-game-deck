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
$configValidatorPath = Join-Path $scriptDir "../src/modules/ConfigValidator.ps1"
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

    Write-Host "Validating configuration structure for game: $GameId"

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
        Write-Host "Game '$GameId' has $($report.Errors.Count) error(s):"
        foreach ($error in $report.Errors) {
            Write-Host "  - $error"
        }
    } else {
        Write-Host "  [OK] Game '$GameId' configuration is valid"
    }

    if ($report.Warnings.Count -gt 0) {
        Write-Host "Game '$GameId' has $($report.Warnings.Count) warning(s):"
        foreach ($warning in $report.Warnings) {
            Write-Host "  - $warning"
        }
    }

    # Return the errors from the updated validator
    return $report.Errors
}

# --- End of Functions ---

# --- Main Test Logic ---

Write-Host "=== FocusGameDeck Configuration Validation Test ==="
Write-Host ""

# Load configuration file
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "../config/config.json"

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

Write-Host ""
Write-Host "Available games:"
foreach ($gameId in $config.games.PSObject.Properties.Name) {
    $gameName = $config.games.$gameId.name
    Write-Host "  - $gameId ($gameName)"
}

Write-Host ""
Write-Host "--- VALIDATING ALL GAME CONFIGURATIONS ---"
Write-Host ""

$allErrors = @()

foreach ($gameId in $config.games.PSObject.Properties.Name) {
    $gameErrors = Test-ConfigStructure -Config $config -GameId $gameId
    if ($gameErrors.Count -gt 0) {
        $allErrors += $gameErrors
        Write-Host "Game '$gameId' has $($gameErrors.Count) error(s):"
        foreach ($errorMsg in $gameErrors) {
            Write-Host "  - $errorMsg"
        }
    } else {
        Write-Host "Game '$gameId' configuration is valid"
    }
    Write-Host ""
}

Write-Host "--- VALIDATION SUMMARY ---"
if ($allErrors.Count -eq 0) {
    Write-Host "All configurations are valid!"
    Write-Host ""
    Write-Host "Your configuration is ready to use."
} else {
    Write-Host "Found $($allErrors.Count) validation error(s)"
    Write-Host ""
    Write-Host "Please fix the errors above before using the script."
}

Write-Host ""
Write-Host "=== Validation Complete ==="
