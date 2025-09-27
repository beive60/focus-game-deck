# Test script to isolate WPF/XAML loading issues
# This script tests each component step by step

$ErrorActionPreference = "Stop"

try {
    Write-Host "1. Testing WPF Assembly Loading..." -ForegroundColor Yellow
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    Write-Host "✓ WPF Assemblies loaded successfully" -ForegroundColor Green
    
    Write-Host "`n2. Testing XAML File Reading..." -ForegroundColor Yellow
    $xamlPath = ".\gui\MainWindow.xaml"
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    Write-Host "✓ XAML content loaded successfully ($($xamlContent.Length) characters)" -ForegroundColor Green
    
    Write-Host "`n3. Testing XAML Parsing..." -ForegroundColor Yellow
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
    $window = [Windows.Markup.XamlReader]::Load($reader)
    Write-Host "✓ XAML parsed successfully" -ForegroundColor Green
    
    Write-Host "`n4. Testing Window Properties..." -ForegroundColor Yellow
    Write-Host "Window Title: $($window.Title)"
    Write-Host "Window Width: $($window.Width)"
    Write-Host "Window Height: $($window.Height)"
    Write-Host "✓ Window properties accessible" -ForegroundColor Green
    
    Write-Host "`n5. Testing Control Access..." -ForegroundColor Yellow
    $versionText = $window.FindName("VersionText")
    if ($versionText) {
        Write-Host "✓ VersionText control found" -ForegroundColor Green
    } else {
        Write-Host "✗ VersionText control not found" -ForegroundColor Red
    }
    
    $checkUpdateButton = $window.FindName("CheckUpdateButton")
    if ($checkUpdateButton) {
        Write-Host "✓ CheckUpdateButton control found" -ForegroundColor Green
    } else {
        Write-Host "✗ CheckUpdateButton control not found" -ForegroundColor Red
    }
    
    Write-Host "`n6. Testing Module Loading..." -ForegroundColor Yellow
    . ".\Version.ps1"
    $versionInfo = Get-ProjectVersionInfo
    Write-Host "✓ Version module loaded: $($versionInfo.FullVersion)" -ForegroundColor Green
    
    . ".\src\modules\UpdateChecker.ps1"
    Write-Host "✓ UpdateChecker module loaded" -ForegroundColor Green
    
    Write-Host "`nAll tests passed! The issue might be in the event handling or ShowDialog() call." -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR in step:" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Location: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Magenta
    
    if ($_.Exception.InnerException) {
        Write-Host "`nInner Exception:" -ForegroundColor Cyan
        Write-Host $_.Exception.InnerException.Message -ForegroundColor Cyan
    }
}

Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")