# Test-GUI-Tutorial.ps1
# Tests tutorial functionality and first-run detection

param(
    [switch]$Verbose
)

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

# Set encoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-BuildLog "=== Tutorial Functionality Test ==="
Write-Host ""

# Test 1: Tutorial module loading
Write-BuildLog "Test 1: Loading tutorial module"
try {
    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $tutorialModulePath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.Tutorial.ps1"
    
    if (-not (Test-Path $tutorialModulePath)) {
        throw "Tutorial module not found at: $tutorialModulePath"
    }
    
    Write-BuildLog "✓ Tutorial module file exists"
} catch {
    Write-BuildLog "✗ FAILED: $_"
    exit 1
}

# Test 2: Tutorial XAML file
Write-BuildLog "Test 2: Validating tutorial XAML"
try {
    $xamlPath = Join-Path -Path $projectRoot -ChildPath "gui/TutorialWindow.xaml"
    
    if (-not (Test-Path $xamlPath)) {
        throw "Tutorial XAML not found at: $xamlPath"
    }
    
    # Validate XAML is well-formed
    $xaml = Get-Content -Path $xamlPath -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
    while ($reader.Read()) { }
    $reader.Close()
    
    Write-BuildLog "✓ Tutorial XAML is well-formed"
} catch {
    Write-BuildLog "✗ FAILED: $_"
    exit 1
}

# Test 3: Tutorial localization keys
Write-BuildLog "Test 3: Checking tutorial localization keys"
try {
    $requiredKeys = @(
        "tutorialWindowTitle",
        "tutorialWelcomeTitle",
        "tutorialWelcomeSubtitle",
        "tutorialSkipButton",
        "tutorialBackButton",
        "tutorialNextButton",
        "tutorialFinishButton",
        "tutorialPage1Title",
        "tutorialPage1Description",
        "tutorialPage2Title",
        "tutorialPage2Description",
        "tutorialPage3Title",
        "tutorialPage3Description",
        "tutorialPage4Title",
        "tutorialPage4Description",
        "tutorialPage5Title",
        "tutorialPage5Description"
    )
    
    $languages = @("en", "ja", "zh-CN", "fr", "es", "pt-BR", "ru", "id-ID")
    $missingKeys = @()
    
    foreach ($lang in $languages) {
        $localizationPath = Join-Path -Path $projectRoot -ChildPath "localization/$lang.json"
        
        if (-not (Test-Path $localizationPath)) {
            $missingKeys += "Language file not found: $lang"
            continue
        }
        
        $localization = Get-Content -Path $localizationPath -Raw | ConvertFrom-Json
        
        foreach ($key in $requiredKeys) {
            if (-not $localization.PSObject.Properties[$key]) {
                $missingKeys += "${lang}: $key"
            }
        }
    }
    
    if ($missingKeys.Count -gt 0) {
        Write-BuildLog "✗ FAILED: Missing localization keys:"
        $missingKeys | ForEach-Object { Write-BuildLog "  - $_" }
        exit 1
    }
    
    Write-BuildLog "✓ All tutorial localization keys present in all languages"
} catch {
    Write-BuildLog "✗ FAILED: $_"
    exit 1
}

# Test 4: Tutorial assets directory
Write-BuildLog "Test 4: Checking tutorial assets directory"
try {
    $assetsPath = Join-Path -Path $projectRoot -ChildPath "assets/tutorial"
    
    if (-not (Test-Path $assetsPath)) {
        throw "Tutorial assets directory not found at: $assetsPath"
    }
    
    $readmePath = Join-Path -Path $assetsPath -ChildPath "README.md"
    if (-not (Test-Path $readmePath)) {
        Write-BuildLog "⚠ Warning: Tutorial assets README.md not found"
    }
    
    Write-BuildLog "✓ Tutorial assets directory exists"
} catch {
    Write-BuildLog "✗ FAILED: $_"
    exit 1
}

# Test 5: First-run detection functions
Write-BuildLog "Test 5: Testing first-run detection functions"
try {
    # Create a test config object
    $testConfig = [PSCustomObject]@{
        language = "en"
        managedApps = @{}
        games = @{}
    }
    
    # Load only the helper functions, not the class (which requires WPF)
    $tutorialModuleContent = Get-Content $tutorialModulePath -Raw
    
    # Extract just the helper functions
    $helperFunctionsStart = $tutorialModuleContent.IndexOf("# Helper function to check if tutorial has been completed")
    $helperFunctions = $tutorialModuleContent.Substring($helperFunctionsStart)
    
    # Execute the helper functions
    Invoke-Expression $helperFunctions
    
    # Test without globalSettings
    $result = Test-TutorialCompleted -ConfigData $testConfig
    
    if ($result -ne $false) {
        throw "Expected Test-TutorialCompleted to return false for config without globalSettings"
    }
    
    # Add globalSettings without tutorial flag
    $testConfig | Add-Member -MemberType NoteProperty -Name 'globalSettings' -Value ([PSCustomObject]@{})
    $result = Test-TutorialCompleted -ConfigData $testConfig
    
    if ($result -ne $false) {
        throw "Expected Test-TutorialCompleted to return false for config without hasCompletedTutorial flag"
    }
    
    # Mark tutorial as completed
    Set-TutorialCompleted -ConfigData $testConfig
    $result = Test-TutorialCompleted -ConfigData $testConfig
    
    if ($result -ne $true) {
        throw "Expected Test-TutorialCompleted to return true after marking as completed"
    }
    
    Write-BuildLog "✓ First-run detection functions work correctly"
} catch {
    Write-BuildLog "✗ FAILED: $_"
    exit 1
}

# Test 6: ConfigEditor integration
Write-BuildLog "Test 6: Checking ConfigEditor integration"
try {
    $configEditorPath = Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.ps1"
    $configEditorContent = Get-Content -Path $configEditorPath -Raw
    
    # Check if tutorial module is loaded
    if ($configEditorContent -notmatch "ConfigEditor\.Tutorial\.ps1") {
        throw "Tutorial module not loaded in ConfigEditor.ps1"
    }
    
    # Check if tutorial functions are called
    if ($configEditorContent -notmatch "Test-TutorialCompleted") {
        throw "Test-TutorialCompleted function not called in ConfigEditor.ps1"
    }
    
    if ($configEditorContent -notmatch "Show-Tutorial") {
        throw "Show-Tutorial function not called in ConfigEditor.ps1"
    }
    
    Write-BuildLog "✓ Tutorial properly integrated into ConfigEditor"
} catch {
    Write-BuildLog "✗ FAILED: $_"
    exit 1
}

Write-Host ""
Write-BuildLog "=== All Tests Passed ==="
Write-BuildLog "Tutorial functionality is properly implemented"
Write-Host ""

exit 0
