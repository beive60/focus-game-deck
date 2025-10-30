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
        (Join-Path $PSScriptRoot "../localization/messages.json"),
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
function Import-Configuration {
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
        Import-Configuration

        # Step 3: NOW we can safely dot-source files that contain WPF types
        Write-Host "Loading script modules..." -ForegroundColor Yellow

        $modulePaths = @(
            (Join-Path $PSScriptRoot "ConfigEditor.Mappings.ps1"),      # Load mappings first
            (Join-Path $PSScriptRoot "ConfigEditor.State.ps1"),
            (Join-Path $PSScriptRoot "ConfigEditor.Localization.ps1"),
            (Join-Path $PSScriptRoot "ConfigEditor.UI.ps1"),            # UI depends on mappings
            (Join-Path $PSScriptRoot "ConfigEditor.Events.ps1")
        )

        foreach ($modulePath in $modulePaths) {
            if (Test-Path $modulePath) {
                . $modulePath
                Write-Verbose "Loaded: $(Split-Path $modulePath -Leaf)"
            } else {
                Write-Error "Required module not found: $modulePath"
                throw "Missing required module: $(Split-Path $modulePath -Leaf)"
            }
        }

        Write-Host "Script modules loaded successfully" -ForegroundColor Green

        # Step 3.5: Validate UI mappings
        if (-not (Test-UIMappings)) {
            Write-Warning "UI mappings validation failed - some features may not work properly"
        }

        # Step 3.6: Import additional modules (Version, UpdateChecker, etc.)
        Write-Host "Importing additional modules..." -ForegroundColor Yellow
        Import-AdditionalModules
        Write-Host "Additional modules imported" -ForegroundColor Green

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

        # Store state manager in script scope for access from functions
        $script:StateManager = $stateManager

        # Step 6: Initialize UI manager
        Write-Host "Initializing UI manager..." -ForegroundColor Yellow
        try {
            # Validate mappings are available before creating UI
            if (-not (Get-Variable -Name "ButtonMappings" -Scope Script -ErrorAction SilentlyContinue)) {
                Write-Warning "Button mappings not loaded - UI functionality may be limited"
            }

            Write-Host "DEBUG: Creating ConfigEditorUI instance..." -ForegroundColor Cyan

            $allMappings = @{
                Button = $ButtonMappings
                Label = $LabelMappings
                Tab = $TabMappings
                Text = $TextMappings
                CheckBox = $CheckBoxMappings
                MenuItem = $MenuItemMappings
                Tooltip = $TooltipMappings
                ComboBoxItem = $ComboBoxItemMappings
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

            $script:Window = $uiManager.Window

            # Store UI manager in script scope for access from functions
            $script:UIManager = $uiManager

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

        # Connect event handler to UI manager
        $uiManager.EventHandler = $eventHandler

        # Store UI manager in script scope for access from event handlers
        $script:ConfigEditorForm = $uiManager

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

            # Initialize game launcher list
            Write-Host "Initializing game launcher list..." -ForegroundColor Yellow
            $uiManager.UpdateGameLauncherList($stateManager.ConfigData)

            Write-Host "Data loaded to UI successfully" -ForegroundColor Green
        } catch {
            Write-Host "Failed to load data to UI: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "UIManager exists: $($null -ne $uiManager)" -ForegroundColor Yellow
            Write-Host "ConfigData exists: $($null -ne $stateManager.ConfigData)" -ForegroundColor Yellow
            throw
        }

        # Mark initialization as complete - event handlers can now process user changes
        $script:IsInitializationComplete = $true
        Write-Host "Initialization completed - UI is now ready for user interaction" -ForegroundColor Green

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
            if ($uiManager) {
                try {
                    Write-Host "DEBUG: Final UI manager cleanup" -ForegroundColor Yellow
                    $uiManager.Cleanup()
                } catch {
                    Write-Warning "Error in final UI manager cleanup: $($_.Exception.Message)"
                }
            }
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
        # Get project root directory (parent of gui folder)
        $projectRoot = Split-Path $PSScriptRoot -Parent
        Write-Verbose "Project root: $projectRoot"

        # Define modules to load and their configurations
        $modulesToLoad = @(
            @{
                Path = "scripts/LanguageHelper.ps1"
                GlobalFunctions = @{}
            },
            @{
                Path = "Version.ps1"
                GlobalFunctions = @{ "Get-ProjectVersion" = "GetProjectVersionFunc" }
            },
            @{
                Path = "src/modules/UpdateChecker.ps1"
                GlobalFunctions = @{ "Test-UpdateAvailable" = "TestUpdateAvailableFunc" }
            }
        )

        # Load modules in a loop
        foreach ($moduleInfo in $modulesToLoad) {
            $modulePath = Join-Path $projectRoot $moduleInfo.Path
            $moduleName = Split-Path $modulePath -Leaf

            if (-not (Test-Path $modulePath)) {
                Write-Warning "Module not found: $modulePath"
                continue
            }

            # Load the module with error handling
            try {
                . $modulePath
                Write-Verbose "Loaded: $moduleName"
            } catch {
                Write-Warning "Error loading $($moduleName): $($_.Exception.Message)"
                continue # Skip to next module if loading failed
            }

            # Check for and store global function references if specified
            foreach ($functionName in $moduleInfo.GlobalFunctions.Keys) {
                $globalVarName = $moduleInfo.GlobalFunctions[$functionName]
                if (Test-Path "function:$functionName") {
                    Write-Host "$functionName function loaded successfully" -ForegroundColor Green
                    Set-Variable -Name $globalVarName -Value (Get-Item "function:$functionName") -Scope Global
                } else {
                    Write-Warning "$functionName function not available after loading $moduleName"
                }
            }
        }
    } catch {
        Write-Warning "Failed to import additional modules: $($_.Exception.Message)"
    }
}

# Helper function stubs for backward compatibility with global functions
# These will be properly implemented or removed in a future refactoring

function Update-AppsToManagePanel {
    Write-Verbose "Update-AppsToManagePanel called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Update-PlatformFields {
    param([string]$Platform)
    Write-Verbose "Update-PlatformFields called for platform: $Platform (stub)"
    # TODO: Implement or remove in future refactoring
}

function Update-MoveButtonStates {
    Write-Verbose "Update-MoveButtonStates called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Update-MoveAppButtonStates {
    Write-Verbose "Update-MoveAppButtonStates called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Update-ActionComboBoxes {
    param([string]$AppId, [string]$ExecutablePath)
    Write-Verbose "Update-ActionComboBoxes called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Update-TerminationSettingsVisibility {
    Write-Verbose "Update-TerminationSettingsVisibility called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Save-CurrentGameData {
    Write-Verbose "Save-CurrentGameData called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Save-CurrentAppData {
    Write-Verbose "Save-CurrentAppData called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Save-GlobalSettingsData {
    Write-Verbose "Save-GlobalSettingsData called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Save-OriginalConfig {
    Write-Verbose "Save-OriginalConfig called (stub)"
    # TODO: Implement or remove in future refactoring
}

function Set-ConfigModified {
    param()
    if ($script:StateManager) {
        $script:StateManager.SetModified()
        Write-Verbose "Configuration marked as modified"
    } else {
        Write-Warning "StateManager not available, cannot mark configuration as modified"
    }
}

<#
.SYNOPSIS
    Shows a message prompting the user to restart the application after changing language.

.DESCRIPTION
    Displays a confirmation dialog asking if the user wants to restart the application
    to apply language changes. If the user agrees, saves the configuration and restarts
    the application.

.OUTPUTS
    None
#>
function Show-LanguageChangeRestartMessage {
    try {
        # Check if localization system is available
        if (-not $script:ConfigEditorForm -and -not $script:UIManager) {
            Write-Warning "Localization system not initialized, cannot show language change dialog"
            return
        }

        # Get the localized message
        $message = Get-SafeLocalizedMessage -Key "languageChangeRestart"
        $title = Get-SafeLocalizedMessage -Key "languageChanged"

        # If localization failed, use fallback English messages
        if ($message -eq "languageChangeRestart") {
            $message = "To fully apply the language setting change, please restart the configuration editor.`n`n※ All current configuration changes will be saved when restarting.`n`nWould you like to restart now?"
            $title = "Language Setting Changed"
        }

        # Show confirmation dialog
        $result = [System.Windows.MessageBox]::Show(
            $message,
            $title,
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            # Save configuration before restarting
            try {
                Write-Verbose "Saving configuration before restart"

                if (-not $script:StateManager -or -not $script:StateManager.ConfigData) {
                    throw "StateManager or ConfigData not available"
                }

                $configJson = $script:StateManager.ConfigData | ConvertTo-Json -Depth 10

                if ([string]::IsNullOrWhiteSpace($configJson) -or $configJson -eq "null") {
                    throw "Configuration data is empty or null"
                }

                Set-Content -Path $script:ConfigPath -Value $configJson -Encoding UTF8
                Write-Verbose "Configuration saved successfully"
            } catch {
                Write-Error "Failed to save configuration before restart: $($_.Exception.Message)"

                # Ask if user wants to continue with restart anyway
                $errorMessage = Get-SafeLocalizedMessage -Key "saveBeforeRestartError" -FormatArgs @($_.Exception.Message)
                $errorTitle = Get-SafeLocalizedMessage -Key "saveBeforeRestartErrorTitle"
                $continueMessage = Get-SafeLocalizedMessage -Key "continueRestartConfirm"

                # Fallback messages if localization fails
                if ($errorMessage -eq "saveBeforeRestartError") {
                    $errorMessage = "Failed to save configuration before restart: $($_.Exception.Message)"
                }
                if ($errorTitle -eq "saveBeforeRestartErrorTitle") {
                    $errorTitle = "Save Error"
                }
                if ($continueMessage -eq "continueRestartConfirm") {
                    $continueMessage = "Failed to save configuration before restart. Continue with restart anyway?"
                }

                $continueResult = [System.Windows.MessageBox]::Show(
                    "$errorMessage`n`n$continueMessage",
                    $errorTitle,
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
                )

                if ($continueResult -ne [System.Windows.MessageBoxResult]::Yes) {
                    Write-Verbose "User cancelled restart due to save error"
                    return
                }
            }

            # Restart the application
            Write-Host "Restarting application to apply language changes..." -ForegroundColor Cyan

            # Get the current script path
            $currentScript = $PSCommandPath
            if (-not $currentScript) {
                $currentScript = Join-Path $PSScriptRoot "ConfigEditor.ps1"
            }

            # Start new instance FIRST with proper encoding
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = "powershell.exe"
            $startInfo.Arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"& { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '$currentScript' }`""
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $false
            $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

            try {
                $newProcess = [System.Diagnostics.Process]::Start($startInfo)
                Write-Host "New instance started successfully (PID: $($newProcess.Id))" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to start new instance: $($_.Exception.Message)"
                return
            }

            # Set a flag to bypass the "unsaved changes" dialog during restart
            if ($script:StateManager) {
                # Clear the modified flag to prevent "unsaved changes" dialog
                $script:StateManager.ClearModified()
            }

            # Close the current window gracefully
            if ($script:UIManager -and $script:UIManager.Window) {
                try {
                    # Force close without triggering the closing event dialog
                    $script:UIManager.Window.DialogResult = $false
                    $script:UIManager.Window.Close()
                } catch {
                    Write-Verbose "Window close warning: $($_.Exception.Message)"
                }
            }

            # Exit current process
            try {
                [System.Windows.Application]::Current.Shutdown()
            } catch {
                Write-Verbose "Shutdown warning: $($_.Exception.Message)"
                # Force exit if graceful shutdown fails
                [System.Environment]::Exit(0)
            }
        } else {
            Write-Verbose "User chose to restart later"
        }
    } catch {
        Write-Error "Failed to show language change restart message: $($_.Exception.Message)"
    }
}

function Show-PathSelectionDialog {
    param([array]$Paths, [string]$Platform)
    Write-Verbose "Show-PathSelectionDialog called (stub)"
    # TODO: Implement or remove in future refactoring
    return $Paths[0]
}

<#
.SYNOPSIS
    Gets a localized message for the specified key.

.DESCRIPTION
    Retrieves a localized message from the loaded messages using the current language.
    Supports optional format arguments for string formatting.

.PARAMETER Key
    The message key to retrieve.

.PARAMETER FormatArgs
    Optional array of arguments for string formatting.

.OUTPUTS
    String - The localized message.
#>
function Get-SafeLocalizedMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $false)]
        [array]$FormatArgs = @()
    )

    try {
        if ($script:ConfigEditorForm -and $script:ConfigEditorForm.localization) {
            return $script:ConfigEditorForm.localization.GetMessage($Key, $FormatArgs)
        } elseif ($script:UIManager) {
            $message = $script:UIManager.GetLocalizedMessage($Key)
            if ($FormatArgs -and $FormatArgs.Count -gt 0) {
                return $message -f $FormatArgs
            }
            return $message
        } else {
            Write-Warning "Localization not available, using key as message: $Key"
            return $Key
        }
    } catch {
        Write-Warning "Failed to get localized message for key '$Key': $($_.Exception.Message)"
        return $Key
    }
}

# Shows a localized message dialog
#
# Displays a message box using localized messages from the messages.json file.
# Supports multiple parameter styles for backward compatibility.
#
# @param Key - Message key for localization (new style)
# @param MessageType - Type of message: Information, Warning, Error, Question (new style)
# @param FormatArgs - Arguments for string formatting (new style)
# @param Button - Button type (e.g., "YesNo", "YesNoCancel")
# @param DefaultResult - Default button result
# @param Message - Direct message text (alternative style)
# @param MessageKey - Message key (old style, for compatibility)
# @param TitleKey - Title key (old style, for compatibility)
# @param Arguments - Format arguments (old style, for compatibility)
# @param Icon - Icon type (old style, for compatibility)
# @return MessageBoxResult if button is specified, otherwise void
function Show-SafeMessage {
    param(
        [string]$Key,
        [string]$MessageType = "Information",
        [array]$FormatArgs = @(),
        [string]$Button = "OK",
        [string]$DefaultResult = "OK",
        [string]$Message,
        [string]$MessageKey,
        [string]$TitleKey,
        [array]$Arguments = @(),
        [string]$Icon
    )

    try {
        # Handle old style parameters
        if ($MessageKey) { $Key = $MessageKey }
        if ($TitleKey) { $titleKeyToUse = $TitleKey } else { $titleKeyToUse = $MessageType.ToLower() }
        if ($Arguments -and $Arguments.Count -gt 0) { $FormatArgs = $Arguments }
        if ($Icon) { $MessageType = $Icon }

        # Get localized message
        if ($Message) {
            $messageText = $Message
        } else {
            if ($script:ConfigEditorForm -and $script:ConfigEditorForm.localization) {
                $messageText = $script:ConfigEditorForm.localization.GetMessage($Key, $FormatArgs)
            } else {
                Write-Warning "Localization not available, using key as message: $Key"
                $messageText = $Key
            }
        }

        # Get localized title
        if ($script:ConfigEditorForm -and $script:ConfigEditorForm.localization) {
            $titleText = $script:ConfigEditorForm.localization.GetMessage($titleKeyToUse, @())
        } else {
            $titleText = $titleKeyToUse
        }

        # Map MessageType to icon
        $iconType = switch ($MessageType) {
            "Information" { [System.Windows.MessageBoxImage]::Information }
            "Warning" { [System.Windows.MessageBoxImage]::Warning }
            "Error" { [System.Windows.MessageBoxImage]::Error }
            "Question" { [System.Windows.MessageBoxImage]::Question }
            default { [System.Windows.MessageBoxImage]::Information }
        }

        # Map Button string to MessageBoxButton
        $buttonType = switch ($Button) {
            "OK" { [System.Windows.MessageBoxButton]::OK }
            "OKCancel" { [System.Windows.MessageBoxButton]::OKCancel }
            "YesNo" { [System.Windows.MessageBoxButton]::YesNo }
            "YesNoCancel" { [System.Windows.MessageBoxButton]::YesNoCancel }
            default { [System.Windows.MessageBoxButton]::OK }
        }

        # Map DefaultResult to MessageBoxResult
        $defaultResultType = switch ($DefaultResult) {
            "OK" { [System.Windows.MessageBoxResult]::OK }
            "Cancel" { [System.Windows.MessageBoxResult]::Cancel }
            "Yes" { [System.Windows.MessageBoxResult]::Yes }
            "No" { [System.Windows.MessageBoxResult]::No }
            default { [System.Windows.MessageBoxResult]::OK }
        }

        # Show message box
        return [System.Windows.MessageBox]::Show($messageText, $titleText, $buttonType, $iconType, $defaultResultType)

    } catch {
        Write-Warning "Show-SafeMessage failed: $($_.Exception.Message)"
        # Fallback to simple message box
        return [System.Windows.MessageBox]::Show($Key, "Message", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
}

# Generates a unique ID for configuration items
#
# Creates a unique identifier with the specified prefix, ensuring no collision
# with existing items in the provided collection. Uses random number generation
# with collision detection for uniqueness.
#
# @param Collection - The collection to check for existing IDs
# @param Prefix - The prefix for the new ID (default: "new")
# @param MinRandom - Minimum random number (default: 1000)
# @param MaxRandom - Maximum random number (default: 9999)
# @return string - A unique identifier
function New-UniqueConfigId {
    param(
        [Parameter(Mandatory)]
        [object]$Collection,
        [string]$Prefix = "new",
        [int]$MinRandom = 1000,
        [int]$MaxRandom = 9999
    )

    do {
        $newId = "${Prefix}$(Get-Random -Minimum $MinRandom -Maximum $MaxRandom)"
    } while ($Collection.PSObject.Properties[$newId])

    return $newId
}

# Validates the selected item for duplication operations
#
# Checks if an item is selected and if its source data exists in the configuration.
# Returns validation result and displays appropriate error messages.
#
# @param SelectedItem - The ID of the selected item
# @param SourceData - The source data object
# @param ItemType - The type of item ("Game" or "App")
# @return bool - True if validation passes, false otherwise
function Test-DuplicateSource {
    param(
        [string]$SelectedItem,
        [object]$SourceData,
        [string]$ItemType
    )

    if (-not $SelectedItem) {
        $messageKey = "no${ItemType}Selected"
        Show-SafeMessage -Key $messageKey -MessageType "Warning"
        return $false
    }

    if (-not $SourceData) {
        $messageKey = "${ItemType}DuplicateError"
        Show-SafeMessage -Key $messageKey -MessageType "Error"
        return $false
    }

    return $true
}

# Shows duplication result messages
#
# Displays success or error messages for duplication operations with proper
# localization and error handling.
#
# @param OriginalId - The ID of the original item
# @param NewId - The ID of the new duplicated item
# @param ItemType - The type of item ("Game" or "App")
# @param Success - Whether the duplication was successful
# @param ErrorMessage - Optional error message if duplication failed
function Show-DuplicateResult {
    param(
        [string]$OriginalId,
        [string]$NewId,
        [string]$ItemType,
        [bool]$Success,
        [string]$ErrorMessage = ""
    )

    if ($Success) {
        $messageKey = "${ItemType.ToLower()}Duplicated"
        Show-SafeMessage -Key $messageKey -MessageType "Information" -FormatArgs @($OriginalId, $NewId)
        Write-Verbose "Successfully duplicated ${ItemType.ToLower()} '$OriginalId' to '$NewId'"
    } else {
        Write-Error "Failed to duplicate ${ItemType.ToLower()}: $ErrorMessage"
        $messageKey = "${ItemType.ToLower()}DuplicateError"
        Show-SafeMessage -Key $messageKey -MessageType "Error" -FormatArgs @($ErrorMessage)
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
$script:IsInitializationComplete = $false

# Start the application
if (-not $NoAutoStart) {
    if (Test-Prerequisites) {
        Initialize-ConfigEditor
    } else {
        Write-Host "Cannot start ConfigEditor due to missing prerequisites" -ForegroundColor Red
        exit 1
    }
}
