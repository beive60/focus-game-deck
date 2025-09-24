# Debug version of ConfigEditor launcher
# This script provides detailed error information for troubleshooting

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

try {
    Write-Host "Starting ConfigEditor debug session..." -ForegroundColor Green
    
    # Check if required files exist
    $requiredFiles = @(
        ".\gui\ConfigEditor.ps1",
        ".\Version.ps1",
        ".\src\modules\UpdateChecker.ps1",
        ".\gui\MainWindow.xaml",
        ".\gui\messages.json"
    )
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "✓ Found: $file" -ForegroundColor Green
        } else {
            Write-Host "✗ Missing: $file" -ForegroundColor Red
        }
    }
    
    Write-Host "Attempting to load ConfigEditor..." -ForegroundColor Yellow
    . ".\gui\ConfigEditor.ps1"
    
} catch {
    Write-Host "`nERROR DETAILS:" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Location: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "Line: $($_.InvocationInfo.Line)" -ForegroundColor Yellow
    Write-Host "`nFull Exception:" -ForegroundColor Magenta
    Write-Host $_.Exception -ForegroundColor Magenta
    Write-Host "`nStack Trace:" -ForegroundColor Cyan
    Write-Host $_.ScriptStackTrace -ForegroundColor Cyan
}

Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")