# Simple test script for Enhanced Launcher Creation
# Test execution for Create-Launchers-Enhanced.ps1

param(
    [switch]$CleanupOnly
)

$scriptDir = $PSScriptRoot
$enhancedScriptPath = Join-Path (Split-Path $scriptDir -Parent) "scripts\Create-Launchers-Enhanced.ps1"
$configPath = Join-Path (Split-Path $scriptDir -Parent) "config\config.json"

Write-Host "Focus Game Deck - Enhanced Launcher Simple Test" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

# Test 1: Check if enhanced script exists
Write-Host "`nTest 1: Enhanced Script Availability" -ForegroundColor Cyan
if (Test-Path $enhancedScriptPath) {
    Write-Host "[OK] Enhanced script found: $enhancedScriptPath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Enhanced script not found: $enhancedScriptPath" -ForegroundColor Red
    exit 1
}

# Test 2: Check COM object availability
Write-Host "`nTest 2: COM Object Availability" -ForegroundColor Cyan
try {
    $WshShell = New-Object -ComObject WScript.Shell
    Write-Host "[OK] WScript.Shell COM object created successfully" -ForegroundColor Green
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
} catch {
    Write-Host "[ERROR] Failed to create WScript.Shell COM object: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Check if config.json exists
Write-Host "`nTest 3: Configuration File" -ForegroundColor Cyan
if (Test-Path $configPath) {
    Write-Host "[OK] Configuration file found: $configPath" -ForegroundColor Green

    try {
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $gameCount = ($config.games.PSObject.Properties).Count
        Write-Host "[OK] Configuration loaded successfully - $gameCount games found" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to parse configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[WARNING] Configuration file not found - enhanced script will show error" -ForegroundColor Yellow
}

# Test 4: PowerShell version check
Write-Host "`nTest 4: PowerShell Environment" -ForegroundColor Cyan
Write-Host "[INFO] PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "[INFO] Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan

# Test 5: Manual execution (if config exists)
if ((Test-Path $configPath) -and -not $CleanupOnly) {
    Write-Host "`nTest 5: Manual Script Execution" -ForegroundColor Cyan
    Write-Host "[INFO] You can now manually test the enhanced script by running:" -ForegroundColor Yellow
    Write-Host "  & '$enhancedScriptPath'" -ForegroundColor White

    $response = Read-Host "`nDo you want to execute the enhanced script now? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "`nExecuting enhanced script..." -ForegroundColor Cyan
        & $enhancedScriptPath
    }
}

Write-Host "`n" + ("=" * 50) -ForegroundColor Green
Write-Host "Simple test completed!" -ForegroundColor Green
Write-Host "Manual testing is recommended to verify shortcut creation." -ForegroundColor Yellow
