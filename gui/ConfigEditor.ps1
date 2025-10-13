# Focus Game Deck - Configuration Editor
# PowerShell + WPF GUI for editing config.json
#
# Design Philosophy:
# 1. Lightweight & Simple - Uses Windows native WPF, no additional runtime required
# 2. Maintainable & Extensible - Configuration-driven design with modular structure
# 3. User-Friendly - Intuitive 3-tab GUI with proper internationalization support
#
# Technical Architecture:
# - PowerShell + WPF: Windows-native GUI technology for lightweight implementation
# - Dynamic Language Detection: Automatic language detection based on config.json and OS settings
# - Configuration-Driven: All behavior controlled through config.json
# - Event-Driven: UI operations handled through PowerShell event handlers
#
# Language Support:
# This implementation uses dynamic language detection following the priority:
# 1. config.json language setting (if exists and valid)
# 2. OS display language (if supported)
# 3. English fallback (default)
#
# Author: GitHub Copilot Assistant
# Version: 1.1.0 - Dynamic Language Detection and English Support
# Date: 2025-09-23

param(
    [switch]$NoAutoStart
)

# Set system-level encoding settings for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Prerequisites check function
function Test-Prerequisites {
    param()

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell version 5.0 or higher required. Current: $($PSVersionTable.PSVersion)"
    }

    # Check essential files
    $requiredFiles = @(
        (Join-Path $PSScriptRoot "MainWindow.xaml"),
        (Join-Path $PSScriptRoot "messages.json"),
        (Join-Path $PSScriptRoot "ConfigEditor.Mappings.ps1"),
        (Join-Path (Split-Path $PSScriptRoot) "config/config.json")
    )

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            $issues += "Required file missing: $file"
        }
    }

    if ($issues.Count -gt 0) {
        Write-Host "=== PREREQUISITES CHECK FAILED ===" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        return $false
    }

    Write-Host "Prerequisites check passed" -ForegroundColor Green
    return $true
}

# Load WPF assemblies FIRST before any dot-sourcing
function Initialize-WpfAssemblies {
    try {
        Write-Host "Loading WPF assemblies..." -ForegroundColor Yellow
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        Write-Host "WPF assemblies loaded successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Failed to load WPF assemblies: $($_.Exception.Message)"
        return $false
    }
}

# Load configuration function
function Load-Configuration {
    try {
        $configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config/config.json"

        if (-not (Test-Path $configPath)) {
            # Try sample config
            $samplePath = "$configPath.sample"
            if (Test-Path $samplePath) {
                Copy-Item $samplePath $configPath
                Write-Host "Created config.json from sample" -ForegroundColor Yellow
            } else {
                throw "Configuration file not found: $configPath"
            }
        }

        $script:ConfigData = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:ConfigPath = $configPath
        Write-Host "Configuration loaded successfully" -ForegroundColor Green

    } catch {
        Write-Error "Failed to load configuration: $($_.Exception.Message)"
        throw
    }
}

# Validate UI mappings function
function Test-UIMappings {
    param()

    try {
        $mappingVariables = @(
            'ButtonMappings',
            'CrudButtonMappings',
            'BrowserButtonMappings',
            'AutoDetectButtonMappings',
            'ActionButtonMappings',
            'MovementButtonMappings'
        )

        $missingMappings = @()
        foreach ($varName in $mappingVariables) {
            # [修正] ScopeをGlobalからScriptに変更
            if (-not (Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue)) {
                $missingMappings += $varName
            }
        }

        if ($missingMappings.Count -gt 0) {
            Write-Warning "Missing UI mappings: $($missingMappings -join ', ')"
            return $false
        }

        # Validate mapping structure
        # [修正] ScopeをGlobalからScriptに変更
        if ((Get-Variable -Name 'ButtonMappings' -Scope Script -ErrorAction SilentlyContinue).Value.Count -eq 0) {
            Write-Warning "ButtonMappings is empty"
            return $false
        }

        Write-Host "UI mappings validated successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Failed to validate UI mappings: $($_.Exception.Message)"
        return $false
    }
}

# Initialize the application
function Initialize-ConfigEditor {
    try {
        Write-Host "=== ConfigEditor initialization started ===" -ForegroundColor Green

        # Step 1: Load WPF assemblies FIRST
        if (-not (Initialize-WpfAssemblies)) {
            throw "WPF assemblies loading failed"
        }

        # Step 2: Load configuration
        Load-Configuration

        # Step 3: NOW we can safely dot-source files that contain WPF types
        Write-Host "Loading script modules..." -ForegroundColor Yellow
        . "$PSScriptRoot/ConfigEditor.Mappings.ps1"      # Load mappings first
        . "$PSScriptRoot/ConfigEditor.State.ps1"
        . "$PSScriptRoot/ConfigEditor.Localization.ps1"
        . "$PSScriptRoot/ConfigEditor.UI.ps1"            # UI depends on mappings
        . "$PSScriptRoot/ConfigEditor.Events.ps1"
        Write-Host "Script modules loaded successfully" -ForegroundColor Green

        # Step 3.5: Validate UI mappings
        if (-not (Test-UIMappings)) {
            Write-Warning "UI mappings validation failed - some features may not work properly"
        }

        # Step 4: Initialize localization
        $localization = [ConfigEditorLocalization]::new()

        # Step 5: Initialize state manager with config path
        Write-Host "Initializing state manager..." -ForegroundColor Yellow
        $stateManager = [ConfigEditorState]::new($script:ConfigPath)
        $stateManager.LoadConfiguration()

        # Validate configuration data
        if ($null -eq $stateManager.ConfigData) {
            throw "Configuration data is null after loading"
        }
        Write-Host "Configuration data structure: $($stateManager.ConfigData.GetType().Name)" -ForegroundColor Yellow

        $stateManager.SaveOriginalConfig()
        Write-Host "State manager initialized successfully" -ForegroundColor Green

        # Step 6: Initialize UI manager
        Write-Host "Initializing UI manager..." -ForegroundColor Yellow
        try {
            # Validate mappings are available before creating UI
            if (-not (Get-Variable -Name "ButtonMappings" -Scope Script -ErrorAction SilentlyContinue)) {
                Write-Warning "Button mappings not loaded - UI functionality may be limited"
            }

            Write-Host "DEBUG: Creating ConfigEditorUI instance..." -ForegroundColor Cyan

            $allMappings = @{
                Button   = $ButtonMappings
                Label    = $LabelMappings
                Tab      = $TabMappings
                Text     = $TextMappings
                CheckBox = $CheckBoxMappings
                MenuItem = $MenuItemMappings
                Tooltip  = $TooltipMappings
            }
            $uiManager = [ConfigEditorUI]::new($stateManager, $allMappings, $localization)

            Write-Host "DEBUG: ConfigEditorUI instance created: $($null -ne $uiManager)" -ForegroundColor Cyan

            if ($null -eq $uiManager) {
                throw "Failed to create UI manager"
            }

            Write-Host "DEBUG: Checking uiManager.Window..." -ForegroundColor Cyan

            if ($null -eq $uiManager.Window) {
                Write-Host "DEBUG: uiManager.Window is null" -ForegroundColor Red
                Write-Host "DEBUG: Available uiManager properties:" -ForegroundColor Cyan
                $uiManager | Get-Member -MemberType Property | ForEach-Object {
                    $propName = $_.Name
                    try {
                        $propValue = $uiManager.$propName
                        Write-Host "  - $propName : $propValue" -ForegroundColor Cyan
                    } catch {
                        Write-Host "  - $propName : <Error accessing property>" -ForegroundColor Yellow
                    }
                }
                throw "UI manager Window is null"
            } else {
                Write-Host "DEBUG: uiManager.Window type: $($uiManager.Window.GetType().Name)" -ForegroundColor Cyan
            }

            $window = $uiManager.Window
            Write-Host "UI manager initialized successfully" -ForegroundColor Green
        } catch {
            Write-Host "DEBUG: UI Manager initialization error details:" -ForegroundColor Red
            Write-Host "DEBUG: Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
            Write-Host "DEBUG: Error message: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.Exception.InnerException) {
                Write-Host "DEBUG: Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }

            # Check if mapping-related error
            if ($_.Exception.Message -match "ButtonMappings|Mappings|mapping") {
                Write-Host "DEBUG: This appears to be a mapping-related error" -ForegroundColor Yellow
                Write-Host "DEBUG: Verify ConfigEditor.Mappings.ps1 is properly loaded" -ForegroundColor Yellow
            }

            throw
        }

        # Step 7: Initialize event handler
        $eventHandler = [ConfigEditorEvents]::new($uiManager, $stateManager)
        $eventHandler.RegisterAll()

        # Step 8: Load data to UI
        Write-Host "Loading data to UI..." -ForegroundColor Yellow
        try {
            if ($null -eq $uiManager) {
                throw "UIManager is null"
            }
            if ($null -eq $stateManager.ConfigData) {
                throw "ConfigData is null"
            }
            $uiManager.LoadDataToUI($stateManager.ConfigData)
            Write-Host "Data loaded to UI successfully" -ForegroundColor Green
        } catch {
            Write-Host "Failed to load data to UI: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "UIManager exists: $($null -ne $uiManager)" -ForegroundColor Yellow
            Write-Host "ConfigData exists: $($null -ne $stateManager.ConfigData)" -ForegroundColor Yellow
            throw
        }

        # Step 9: Show window
        Write-Host "Showing window..." -ForegroundColor Yellow
        try {
            # Use ShowDialog() which properly handles the window lifecycle
            $dialogResult = $window.ShowDialog()
            Write-Host "DEBUG: Window closed with result: $dialogResult" -ForegroundColor Cyan
        } catch {
            Write-Host "DEBUG: Window show/close error: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            # Ensure proper cleanup
            if ($window) {
                try {
                    Write-Host "DEBUG: Final window cleanup" -ForegroundColor Yellow
                    $window = $null
                } catch {
                    Write-Warning "Error in final window cleanup: $($_.Exception.Message)"
                }
            }

            # Force cleanup of global variables
            $script:Window = $null
            $script:ConfigData = $null

            # Force garbage collection to clean up WPF resources
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
        }

        Write-Host "=== ConfigEditor initialization completed ===" -ForegroundColor Green

    } catch {
        Write-Host "=== INITIALIZATION FAILED ===" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.InvocationInfo.ScriptName) {
            $projectRoot = Split-Path $PSScriptRoot -Parent
            $relativePath = $_.InvocationInfo.ScriptName -replace [regex]::Escape($projectRoot), "."
            $relativePath = $relativePath -replace "\\", "/"  # Convert to forward slashes
            Write-Host "Module: $relativePath" -ForegroundColor Red
        } else {
            Write-Host "Module: <Main Script>" -ForegroundColor Red
        }
        Write-Host "Location: Line $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red

        try {
            [System.Windows.MessageBox]::Show(
                "初期化エラーが発生しました: $($_.Exception.Message)",
                "エラー",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        } catch {
            Write-Host "Failed to show error dialog: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Import additional modules after WPF assemblies are loaded
function Import-AdditionalModules {
    try {
        # Import language helper functions
        $LanguageHelperPath = Join-Path (Split-Path $PSScriptRoot) "scripts/LanguageHelper.ps1"
        if (Test-Path $LanguageHelperPath) {
            . $LanguageHelperPath
        } else {
            Write-Warning "Language helper not found: $LanguageHelperPath"
        }

        # Import version and update checker modules
        $VersionModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Version.ps1"
        if (Test-Path $VersionModulePath) {
            . $VersionModulePath
        } else {
            Write-Warning "Version module not found: $VersionModulePath"
        }

        $UpdateCheckerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "src/modules/UpdateChecker.ps1"
        if (Test-Path $UpdateCheckerPath) {
            . $UpdateCheckerPath
        } else {
            Write-Warning "Update checker module not found: $UpdateCheckerPath"
        }
    } catch {
        Write-Warning "Failed to import additional modules: $($_.Exception.Message)"
    }
}

# Global variables
$script:ConfigData = $null
$script:ConfigPath = ""
$script:Window = $null
$script:CurrentGameId = ""
$script:CurrentAppId = ""
$script:Messages = $null
$script:CurrentLanguage = "en"
$script:HasUnsavedChanges = $false
$script:OriginalConfigData = $null

# Start the application
if (-not $NoAutoStart) {
    if (Test-Prerequisites) {
        Initialize-ConfigEditor
    } else {
        Write-Host "Cannot start ConfigEditor due to missing prerequisites" -ForegroundColor Red
        exit 1
    }
}
