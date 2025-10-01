# VTube Studio Integration Test Script
# Test the VTubeStudioManager functionality

Write-Host "=== VTube Studio Integration Test ===" -ForegroundColor Cyan

# Load required modules
try {
    . "$PSScriptRoot/../src/modules/VTubeStudioManager.ps1"
    Write-Host "[OK] VTubeStudioManager module loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load VTubeStudioManager: $_" -ForegroundColor Red
    exit 1
}

try {
    . "$PSScriptRoot/../src/modules/AppManager.ps1"
    Write-Host "[OK] AppManager module loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load AppManager: $_" -ForegroundColor Red
    exit 1
}

# Load configuration
try {
    $config = Get-Content "$PSScriptRoot/../config/config.json" | ConvertFrom-Json
    Write-Host "[OK] Configuration loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load configuration: $_" -ForegroundColor Red
    exit 1
}

# Test VTubeStudioManager
Write-Host "`n=== Testing VTubeStudioManager ===" -ForegroundColor Yellow

try {
    $vtubeManager = New-VTubeStudioManager -VTubeConfig $config.managedApps.vtubeStudio -Messages @{}
    Write-Host "[OK] VTubeStudioManager instance created" -ForegroundColor Green

    # Test installation detection
    Write-Host "`nTesting VTube Studio installation detection..." -ForegroundColor Cyan
    $status = $vtubeManager.GetStatus()

    Write-Host "Current Status:" -ForegroundColor White
    Write-Host "  - Is Running: $($status.IsRunning)" -ForegroundColor White
    Write-Host "  - Installation Available: $($status.Installation.Available)" -ForegroundColor White
    Write-Host "  - Installation Type: $($status.Installation.Type)" -ForegroundColor White
    Write-Host "  - Installation Path: $($status.Installation.Path)" -ForegroundColor White
    Write-Host "  - WebSocket Connected: $($status.WebSocketConnected)" -ForegroundColor White

    if ($status.Installation.Available) {
        Write-Host "[OK] VTube Studio installation detected" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] VTube Studio installation not found" -ForegroundColor Yellow
    }

} catch {
    Write-Host "[ERROR] VTubeStudioManager test failed: $_" -ForegroundColor Red
}

# Test AppManager integration
Write-Host "`n=== Testing AppManager Integration ===" -ForegroundColor Yellow

try {
    $appManager = New-AppManager -Config $config -Messages @{}
    Write-Host "[OK] AppManager instance created" -ForegroundColor Green

    # Test configuration validation
    Write-Host "`nTesting VTube Studio configuration validation..." -ForegroundColor Cyan
    if ($appManager.ValidateAppConfig("vtubeStudio")) {
        Write-Host "[OK] VTube Studio configuration valid" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] VTube Studio configuration invalid" -ForegroundColor Red
    }

} catch {
    Write-Host "[ERROR] AppManager integration test failed: $_" -ForegroundColor Red
}

# Test Configuration Validator
Write-Host "`n=== Testing Configuration Validator ===" -ForegroundColor Yellow

try {
    . "$PSScriptRoot/../src/modules/ConfigValidator.ps1"
    Write-Host "[OK] ConfigValidator module loaded" -ForegroundColor Green

    $validator = New-ConfigValidator -Config $config -Messages @{}
    $validationResult = $validator.ValidateConfiguration($null)

    if ($validationResult) {
        Write-Host "[OK] Configuration validation passed" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Configuration validation has issues" -ForegroundColor Yellow
    }

    $report = $validator.GetValidationReport()
    Write-Host "Validation Report:" -ForegroundColor White
    Write-Host "  - Is Valid: $($report.IsValid)" -ForegroundColor White
    Write-Host "  - Error Count: $($report.ErrorCount)" -ForegroundColor White
    Write-Host "  - Warning Count: $($report.WarningCount)" -ForegroundColor White

    if ($report.ErrorCount -gt 0) {
        Write-Host "Errors:" -ForegroundColor Red
        foreach ($errorMsg in $report.Errors) {
            Write-Host "  - $errorMsg" -ForegroundColor Red
        }
    }

    if ($report.WarningCount -gt 0) {
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($warningMsg in $report.Warnings) {
            Write-Host "  - $warningMsg" -ForegroundColor Yellow
        }
    }

} catch {
    Write-Host "[ERROR] Configuration validator test failed: $_" -ForegroundColor Red
}

Write-Host "`n=== VTube Studio Integration Test Complete ===" -ForegroundColor Cyan
