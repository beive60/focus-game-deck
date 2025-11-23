# VTube Studio Integration Test Script
<#
.SYNOPSIS
    Runs integration tests for VTubeStudioManager, ensuring it correctly interacts with the application and configuration.

.DESCRIPTION
    This Pester test script verifies the functionality of the VTubeStudioManager module. It performs the following checks:
    - Loads the VTubeStudioManager and AppManager modules.
    - Loads the application's configuration from 'config/config.json'.
    - Tests the VTubeStudioManager by creating an instance and checking for the VTube Studio installation.
    - Tests AppManager integration by validating the VTube Studio configuration.
    - Tests the ConfigValidator by running a full configuration validation and reporting the results.

.EXAMPLE
    .\Test-Integration-VTubeStudio.ps1
    Runs all integration tests defined in the script.

.NOTES
    This script is intended to be run from the 'test/scripts/integration' directory. It requires the main configuration file ('config/config.json') to be present and correctly formatted.

.OUTPUTS
    Outputs test results to the console, indicating the status of each test (e.g., [OK], [ERROR], [WARNING]).
#>
Write-Host "=== VTube Studio Integration Test ==="

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load required modules
try {
    $vtubeStudioManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/VTubeStudioManager.ps1"
    . $vtubeStudioManagerPath
    Write-Host "[OK] VTubeStudioManager module loaded"
} catch {
    Write-Host "[ERROR] Failed to load VTubeStudioManager: $_"
    exit 1
}

try {
    $appManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1"
    . $appManagerPath
    Write-Host "[OK] AppManager module loaded"
} catch {
    Write-Host "[ERROR] Failed to load AppManager: $_"
    exit 1
}

# Load configuration
try {
    $configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[OK] Configuration loaded"
} catch {
    Write-Host "[ERROR] Failed to load configuration: $_"
    exit 1
}

# Test VTubeStudioManager
Write-Host "=== Testing VTubeStudioManager ==="

# Create DiscordManager instance
$messages = @{}  # Mock messages object for testing
try {
    $vtubeManager = New-VTubeStudioManager -VTubeConfig $config.integrations.vtubeStudio -Messages $messages
    Write-Host "[OK] VTubeStudioManager instance created"

    # Test installation detection
    Write-Host "Testing VTube Studio installation detection..."
    $status = $vtubeManager.GetStatus()

    Write-Host "Current Status:"
    Write-Host "  - Is Running: $($status.IsRunning)"
    Write-Host "  - Installation Available: $($status.Installation.Available)"
    Write-Host "  - Installation Type: $($status.Installation.Type)"
    Write-Host "  - Installation Path: $($status.Installation.Path)"
    Write-Host "  - WebSocket Connected: $($status.WebSocketConnected)"

    if ($status.Installation.Available) {
        Write-Host "[OK] VTube Studio installation detected"
    } else {
        Write-Host "[WARNING] VTube Studio installation not found"
    }

} catch {
    Write-Host "[ERROR] VTubeStudioManager test failed: $_"
}

# Test AppManager integration
Write-Host "=== Testing AppManager Integration ==="

try {
    $appManager = New-AppManager -Config $config -Messages @{}
    Write-Host "[OK] AppManager instance created"

    # Test configuration validation
    Write-Host "Testing VTube Studio configuration validation..."
    if ($appManager.ValidateAppConfig("vtubeStudio")) {
        Write-Host "[OK] VTube Studio configuration valid"
    } else {
        Write-Host "[ERROR] VTube Studio configuration invalid"
    }

} catch {
    Write-Host "[ERROR] AppManager integration test failed: $_"
}

# Test Configuration Validator
Write-Host "=== Testing Configuration Validator ==="

try {
    $configValidatorPath = Join-Path -Path $projectRoot -ChildPath "src/modules/ConfigValidator.ps1"
    . $configValidatorPath
    Write-Host "[OK] ConfigValidator module loaded"

    $validator = New-ConfigValidator -Config $config -Messages @{}
    $validationResult = $validator.ValidateConfiguration($null)

    if ($validationResult) {
        Write-Host "[OK] Configuration validation passed"
    } else {
        Write-Host "[WARNING] Configuration validation has issues"
    }

    $report = $validator.GetValidationReport()
    Write-Host "Validation Report:"
    Write-Host "  - Is Valid: $($report.IsValid)"
    Write-Host "  - Error Count: $($report.ErrorCount)"
    Write-Host "  - Warning Count: $($report.WarningCount)"

    if ($report.ErrorCount -gt 0) {
        Write-Host "Errors:"
        foreach ($errorMsg in $report.Errors) {
            Write-Host "  - $errorMsg"
        }
    }

    if ($report.WarningCount -gt 0) {
        Write-Host "Warnings:"
        foreach ($warningMsg in $report.Warnings) {
            Write-Host "  - $warningMsg"
        }
    }

} catch {
    Write-Host "[ERROR] Configuration validator test failed: $_"
}

Write-Host "=== VTube Studio Integration Test Complete ==="
