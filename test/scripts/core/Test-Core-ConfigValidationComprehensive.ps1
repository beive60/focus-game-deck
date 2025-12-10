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
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath "../../.."
$configValidatorPath = Join-Path -Path $projectRoot -ChildPath "src/modules/ConfigValidator.ps1"
if (Test-Path $configValidatorPath) {
    . $configValidatorPath
} else {
    Write-BuildLog "ConfigValidator module not found: $configValidatorPath" -Level Error
    exit 1
}

# Validate configuration structure using updated validator
function Test-ConfigStructure {
    param(
        [object]$Config,
        [string]$GameId
    )


# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
    $errors = @()
    $gameConfig = $Config.games.$GameId

    Write-BuildLog "Validating configuration structure for game: $GameId"

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
        Write-BuildLog "Game '$GameId' has $($report.Errors.Count) error(s):"
        foreach ($error in $report.Errors) {
            Write-BuildLog "  - $error"
        }
    } else {
        Write-BuildLog "  [OK] Game '$GameId' configuration is valid"
    }

    if ($report.Warnings.Count -gt 0) {
        Write-BuildLog "Game '$GameId' has $($report.Warnings.Count) warning(s):"
        foreach ($warning in $report.Warnings) {
            Write-BuildLog "  - $warning"
        }
    }

    # Return the errors from the updated validator
    return $report.Errors
}

# --- End of Functions ---

# --- Main Test Logic ---

Write-BuildLog "=== FocusGameDeck Configuration Validation Test ==="
Write-Host ""

# Load configuration file
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

Write-Host ""
Write-BuildLog "Available games:"
foreach ($gameId in $config.games.PSObject.Properties.Name) {
    $gameName = $config.games.$gameId.name
    Write-BuildLog "  - $gameId ($gameName)"
}

Write-Host ""
Write-BuildLog "--- VALIDATING ALL GAME CONFIGURATIONS ---"
Write-Host ""

$allErrors = @()

foreach ($gameId in $config.games.PSObject.Properties.Name) {
    $gameErrors = Test-ConfigStructure -Config $config -GameId $gameId
    if ($gameErrors.Count -gt 0) {
        $allErrors += $gameErrors
        Write-BuildLog "Game '$gameId' has $($gameErrors.Count) error(s):"
        foreach ($errorMsg in $gameErrors) {
            Write-BuildLog "  - $errorMsg"
        }
    } else {
        Write-BuildLog "Game '$gameId' configuration is valid"
    }
    Write-Host ""
}

Write-BuildLog "--- VALIDATION SUMMARY ---"
if ($allErrors.Count -eq 0) {
    Write-BuildLog "All configurations are valid!"
    Write-Host ""
    Write-BuildLog "Your configuration is ready to use."
} else {
    Write-BuildLog "Found $($allErrors.Count) validation error(s)"
    Write-Host ""
    Write-BuildLog "Please fix the errors above before using the script."
}

Write-Host ""
Write-BuildLog "=== Validation Complete ==="
