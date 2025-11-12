<#
.SYNOPSIS
    Focus Game Deck - Configuration Editor GUI application.

.DESCRIPTION
    PowerShell + WPF based GUI application for editing config.json with multi-language support.
    Provides an intuitive 3-tab interface for managing game configurations, managed applications,
    and global settings.

    Design Philosophy:
    1. Lightweight & Simple - Uses Windows native WPF, no additional runtime required
    2. Maintainable & Extensible - Configuration-driven design with modular structure
    3. User-Friendly - Intuitive 3-tab GUI with proper internationalization support

    Technical Architecture:
    - PowerShell + WPF: Windows-native GUI technology for lightweight implementation
    - Dynamic Language Detection: Automatic language detection based on config.json and OS settings
    - Configuration-Driven: All behavior controlled through config.json
    - Event-Driven: UI operations handled through PowerShell event handlers

    Language Support Priority:
    1. config.json language setting (if exists and valid)
    2. OS display language (if supported)
    3. English fallback (default)

.PARAMETER NoAutoStart
    Prevents automatic startup of the configuration editor. Used for loading functions only.

.PARAMETER DebugMode
    Enables debug mode with verbose output for troubleshooting.

.PARAMETER AutoCloseSeconds
    Automatically closes the window after the specified number of seconds (debug mode only).

.EXAMPLE
    .\ConfigEditor.ps1
    Starts the configuration editor in normal mode.

.EXAMPLE
    .\ConfigEditor.ps1 -DebugMode
    Starts the configuration editor in debug mode with verbose output.

.EXAMPLE
    .\ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 10
    Starts the configuration editor in debug mode and auto-closes after 10 seconds.

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.1.0 - Dynamic Language Detection and English Support
    Last Updated: 2025-09-23
    Requires: PowerShell 5.1 or higher, Windows 10/11

.LINK
    https://github.com/beive60/focus-game-deck
#>

param(
    [switch]$NoAutoStart,
    [switch]$DebugMode,
    [int]$AutoCloseSeconds = 0
)

if ($DebugMode) {
    $VerbosePreference = 'Continue'
}

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
        Write-Host "[ERROR] ConfigEditor: Prerequisites check failed"
        $issues | ForEach-Object { Write-Host "  - $_" }
        return $false
    }

    Write-Host "[OK] ConfigEditor: Prerequisites check passed"
    return $true
}

# Load WPF assemblies FIRST before any dot-sourcing
function Initialize-WpfAssemblies {
    try {
        Write-Host "[INFO] ConfigEditor: Loading WPF assemblies"
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        Write-Host "[OK] ConfigEditor: WPF assemblies loaded successfully"
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
                Write-Host "[INFO] ConfigEditor: Created config.json from sample"
            } else {
                throw "Configuration file not found: $configPath"
            }
        }

        $script:ConfigData = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:ConfigPath = $configPath
        Write-Host "[OK] ConfigEditor: Configuration loaded successfully"

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
            Write-Host "[WARNING] ConfigEditor: Missing UI mappings - $($missingMappings -join ', ')"
            return $false
        }

        # Validate mapping structure
        # [修正] ScopeをGlobalからScriptに変更
        if ((Get-Variable -Name 'ButtonMappings' -Scope Script -ErrorAction SilentlyContinue).Value.Count -eq 0) {
            Write-Host "[WARNING] ConfigEditor: ButtonMappings is empty"
            return $false
        }

        Write-Host "[OK] ConfigEditor: UI mappings validated successfully"
        return $true
    } catch {
        Write-Warning "Failed to validate UI mappings: $($_.Exception.Message)"
        return $false
    }
}

# Initialize the application
function Initialize-ConfigEditor {
    try {
        # Debug mode information
        if ($DebugMode) {
            Write-Host "[DEBUG] ConfigEditor: Debug mode enabled"
            if ($AutoCloseSeconds -gt 0) {
                Write-Host "[DEBUG] ConfigEditor: Auto-close timer - $AutoCloseSeconds seconds"
            } else {
                Write-Host "[DEBUG] ConfigEditor: Manual close required"
            }
        }

        Write-Host "[INFO] ConfigEditor: Initialization started"

        # Step 1: Load WPF assemblies FIRST
        if (-not (Initialize-WpfAssemblies)) {
            throw "WPF assemblies loading failed"
        }

        # Step 2: Load configuration
        Import-Configuration

        # Step 3: NOW we can safely dot-source files that contain WPF types
        Write-Host "[INFO] ConfigEditor: Loading script modules"

        $modulePaths = @(
            (Join-Path $PSScriptRoot "ConfigEditor.JsonHelper.ps1"),    # Load JSON helper first
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

        Write-Host "[OK] ConfigEditor: Script modules loaded successfully"

        # Step 3.5: Validate UI mappings
        if (-not (Test-UIMappings)) {
            Write-Host "[WARNING] ConfigEditor: UI mappings validation failed - Some features may not work properly"
        }

        # Step 3.6: Import additional modules (Version, UpdateChecker, etc.)
        Write-Host "[INFO] ConfigEditor: Importing additional modules"
        Import-AdditionalModules
        Write-Host "[OK] ConfigEditor: Additional modules imported"

        # Step 4: Initialize localization
        Write-Host "[INFO] ConfigEditor: Initializing localization"
        try {
            $script:Localization = [ConfigEditorLocalization]::new()
            Write-Host "[OK] ConfigEditor: Localization initialized - Language: $($script:Localization.CurrentLanguage)"
        } catch {
            Write-Error "Failed to initialize localization: $($_.Exception.Message)"
            throw
        }

        # Step 5: Initialize state manager with config path
        Write-Host "[INFO] ConfigEditor: Initializing state manager"
        $stateManager = [ConfigEditorState]::new($script:ConfigPath)
        $stateManager.LoadConfiguration()

        # Validate configuration data
        if ($null -eq $stateManager.ConfigData) {
            throw "Configuration data is null after loading"
        }
        Write-Host "[INFO] ConfigEditor: Configuration data structure - $($stateManager.ConfigData.GetType().Name)"

        $stateManager.SaveOriginalConfig()
        Write-Host "[OK] ConfigEditor: State manager initialized successfully"

        # Store state manager in script scope for access from functions
        $script:StateManager = $stateManager

        # Step 6: Initialize UI manager
        Write-Host "[INFO] ConfigEditor: Initializing UI manager"
        try {
            # Validate mappings are available before creating UI
            if (-not (Get-Variable -Name "ButtonMappings" -Scope Script -ErrorAction SilentlyContinue)) {
                Write-Host "[WARNING] ConfigEditor: Button mappings not loaded - UI functionality may be limited"
            }

            Write-Host "[DEBUG] ConfigEditor: Creating ConfigEditorUI instance"

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
            $uiManager = [ConfigEditorUI]::new($stateManager, $allMappings, $script:Localization)

            Write-Host "[DEBUG] ConfigEditor: ConfigEditorUI instance created - $($null -ne $uiManager)"

            if ($null -eq $uiManager) {
                throw "Failed to create UI manager"
            }

            Write-Host "[DEBUG] ConfigEditor: Checking uiManager.Window"

            if ($null -eq $uiManager.Window) {
                Write-Host "[DEBUG] ConfigEditor: uiManager.Window is null"
                Write-Host "[DEBUG] ConfigEditor: Available uiManager properties:"
                $uiManager | Get-Member -MemberType Property | ForEach-Object {
                    $propName = $_.Name
                    try {
                        $propValue = $uiManager.$propName
                        Write-Host "  - $propName : $propValue"
                    } catch {
                        Write-Host "  - $propName : <Error accessing property>"
                    }
                }
                throw "UI manager Window is null"
            } else {
                Write-Host "[DEBUG] ConfigEditor: uiManager.Window type - $($uiManager.Window.GetType().Name)"
            }

            $script:Window = $uiManager.Window

            # Store UI manager in script scope for access from functions
            $script:UIManager = $uiManager

            Write-Host "[OK] ConfigEditor: UI manager initialized successfully"
        } catch {
            Write-Host "[DEBUG] ConfigEditor: UI Manager initialization error details"
            Write-Host "[DEBUG] ConfigEditor: Error type - $($_.Exception.GetType().Name)"
            Write-Host "[DEBUG] ConfigEditor: Error message - $($_.Exception.Message)"
            if ($_.Exception.InnerException) {
                Write-Host "[DEBUG] ConfigEditor: Inner exception - $($_.Exception.InnerException.Message)"
            }

            # Check if mapping-related error
            if ($_.Exception.Message -match "ButtonMappings|Mappings|mapping") {
                Write-Host "[DEBUG] ConfigEditor: This appears to be a mapping-related error"
                Write-Host "[DEBUG] ConfigEditor: Verify ConfigEditor.Mappings.ps1 is properly loaded"
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
        Write-Host "[INFO] ConfigEditor: Loading data to UI"
        try {
            if ($null -eq $uiManager) {
                throw "UIManager is null"
            }
            if ($null -eq $stateManager.ConfigData) {
                throw "ConfigData is null"
            }
            $uiManager.LoadDataToUI($stateManager.ConfigData)

            # Initialize game launcher list
            Write-Host "[INFO] ConfigEditor: Initializing game launcher list"
            $uiManager.UpdateGameLauncherList($stateManager.ConfigData)

            Write-Host "[OK] ConfigEditor: Data loaded to UI successfully"
        } catch {
            Write-Host "[ERROR] ConfigEditor: Failed to load data to UI - $($_.Exception.Message)"
            Write-Host "[DEBUG] ConfigEditor: UIManager exists - $($null -ne $uiManager)"
            Write-Host "[DEBUG] ConfigEditor: ConfigData exists - $($null -ne $stateManager.ConfigData)"
            throw
        }

        # Mark initialization as complete - event handlers can now process user changes
        $script:IsInitializationComplete = $true
        Write-Host "[OK] ConfigEditor: Initialization completed - UI is ready for user interaction"

        # Step 9: Show window
        Write-Host "[INFO] ConfigEditor: Showing window"
        try {
            # Debug mode: Auto-close after specified seconds
            if ($DebugMode -and $AutoCloseSeconds -gt 0) {
                Write-Host "[DEBUG] ConfigEditor: Window will auto-close in $AutoCloseSeconds seconds"

                # Create a timer to auto-close the window
                $timer = New-Object System.Windows.Threading.DispatcherTimer
                $timer.Interval = [TimeSpan]::FromSeconds($AutoCloseSeconds)
                $timer.Add_Tick({
                        Write-Host "[DEBUG] ConfigEditor: Auto-closing window"
                        $window.Close()
                        $timer.Stop()
                    })
                $timer.Start()

                # Show window and wait
                $dialogResult = $window.ShowDialog()
                Write-Host "[DEBUG] ConfigEditor: Window closed with result - $dialogResult"
            } elseif ($DebugMode) {
                Write-Host "[DEBUG] ConfigEditor: Showing window - Manual close required"
                $dialogResult = $window.ShowDialog()
                Write-Host "[DEBUG] ConfigEditor: Window closed with result - $dialogResult"
            } else {
                # Normal mode: Use ShowDialog() which properly handles the window lifecycle
                $dialogResult = $window.ShowDialog()
                Write-Host "[DEBUG] ConfigEditor: Window closed with result - $dialogResult"
            }
        } catch {
            Write-Host "[DEBUG] ConfigEditor: Window show/close error - $($_.Exception.Message)"
        } finally {
            # Ensure proper cleanup
            if ($uiManager) {
                try {
                    Write-Host "[DEBUG] ConfigEditor: Final UI manager cleanup"
                    $uiManager.Cleanup()
                } catch {
                    Write-Host "[WARNING] ConfigEditor: Error in final UI manager cleanup - $($_.Exception.Message)"
                }
            }
            if ($window) {
                try {
                    Write-Host "[DEBUG] ConfigEditor: Final window cleanup"
                    $window = $null
                } catch {
                    Write-Host "[WARNING] ConfigEditor: Error in final window cleanup - $($_.Exception.Message)"
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

        Write-Host "[OK] ConfigEditor: Initialization completed"

    } catch {
        Write-Host "[ERROR] ConfigEditor: Initialization failed - $($_.Exception.Message)"
        if ($_.InvocationInfo.ScriptName) {
            $projectRoot = Split-Path $PSScriptRoot -Parent
            $relativePath = $_.InvocationInfo.ScriptName -replace [regex]::Escape($projectRoot), "."
            $relativePath = $relativePath -replace "\\", "/"  # Convert to forward slashes
            Write-Host "[ERROR] ConfigEditor: Module - $relativePath"
        } else {
            Write-Host "[ERROR] ConfigEditor: Module - <Main Script>"
        }
        Write-Host "[ERROR] ConfigEditor: Location - Line $($_.InvocationInfo.ScriptLineNumber)"

        try {
            [System.Windows.MessageBox]::Show(
                "初期化エラーが発生しました: $($_.Exception.Message)",
                "エラー",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        } catch {
            Write-Host "[ERROR] ConfigEditor: Failed to show error dialog - $($_.Exception.Message)"
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
                Path = "build-tools/Version.ps1"
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
                Write-Host "[WARNING] ConfigEditor: Error loading $($moduleName) - $($_.Exception.Message)"
                continue # Skip to next module if loading failed
            }

            # Check for and store global function references if specified
            foreach ($functionName in $moduleInfo.GlobalFunctions.Keys) {
                $globalVarName = $moduleInfo.GlobalFunctions[$functionName]
                if (Test-Path "function:$functionName") {
                    Write-Host "[OK] ConfigEditor: $functionName function loaded successfully"
                    Set-Variable -Name $globalVarName -Value (Get-Item "function:$functionName") -Scope Global
                } else {
                    Write-Host "[WARNING] ConfigEditor: $functionName function not available after loading $moduleName"
                }
            }
        }
    } catch {
        Write-Host "[WARNING] ConfigEditor: Failed to import additional modules - $($_.Exception.Message)"
    }
}

# Helper function stubs for backward compatibility with global functions
# These will be properly implemented or removed in a future refactoring

function Update-AppsToManagePanel {
    try {
        $appsToManagePanel = $script:Window.FindName("AppsToManagePanel")
        if (-not $appsToManagePanel) {
            Write-Warning "AppsToManagePanel not found"
            return
        }

        # Set flag to prevent event handling during update
        if (-not $script:UpdatingAppsPanel) {
            $script:UpdatingAppsPanel = $false
        }

        # Prevent recursive updates
        if ($script:UpdatingAppsPanel) {
            Write-Verbose "Already updating AppsToManagePanel, skipping recursive call"
            return
        }

        $script:UpdatingAppsPanel = $true

        try {
            # Clear existing checkboxes
            $appsToManagePanel.Children.Clear()

            # Get current game data
            if (-not $script:CurrentGameId) {
                Write-Verbose "No game selected, clearing AppsToManagePanel"
                return
            }

            $gameData = $script:StateManager.ConfigData.games.$script:CurrentGameId
            if (-not $gameData) {
                Write-Warning "Game data not found for: $script:CurrentGameId"
                return
            }

            # Get list of apps to manage for this game
            $appsToManage = if ($gameData.appsToManage) { $gameData.appsToManage } else { @() }
            Write-Verbose "AppsToManage for $script:CurrentGameId`: $($appsToManage -join ', ')"

            # Get all available managed apps
            $managedApps = $script:StateManager.ConfigData.managedApps
            if (-not $managedApps) {
                Write-Verbose "No managed apps found in configuration"
                return
            }

            # Get order if available
            $appOrder = if ($managedApps._order) { $managedApps._order } else { @() }

            # Create checkboxes for each managed app
            $appsToDisplay = if ($appOrder.Count -gt 0) {
                $appOrder | Where-Object { $_ -ne "_order" -and $managedApps.PSObject.Properties[$_] }
            } else {
                $managedApps.PSObject.Properties.Name | Where-Object { $_ -ne "_order" }
            }

            foreach ($appId in $appsToDisplay) {
                $appData = $managedApps.$appId
                if (-not $appData) { continue }

                $checkbox = New-Object System.Windows.Controls.CheckBox
                $checkbox.Content = if ($appData.displayName) { $appData.displayName } else { $appId }
                $checkbox.Tag = $appId
                $checkbox.IsChecked = $appsToManage -contains $appId
                $checkbox.Margin = "0,2"

                # Capture StateManager in closure for event handlers
                $stateManager = $script:StateManager
                $updatingFlag = { $script:UpdatingAppsPanel }

                # Add event handler for checkbox state changes
                $checkbox.add_Checked({
                        param($sender, $e)
                        # Skip if updating panel
                        if (& $updatingFlag) {
                            return
                        }
                        $stateManager.SetModified()
                    }.GetNewClosure())

                $checkbox.add_Unchecked({
                        param($sender, $e)
                        # Skip if updating panel
                        if (& $updatingFlag) {
                            return
                        }
                        $stateManager.SetModified()
                    }.GetNewClosure())

                $appsToManagePanel.Children.Add($checkbox) | Out-Null
                Write-Verbose "Added checkbox for app: $appId (checked: $($checkbox.IsChecked))"
            }

            Write-Verbose "Updated AppsToManagePanel with $($appsToManagePanel.Children.Count) apps"
        } finally {
            # Always reset the flag
            $script:UpdatingAppsPanel = $false
        }
    } catch {
        Write-Warning "Failed to update AppsToManagePanel: $($_.Exception.Message)"
        $script:UpdatingAppsPanel = $false
    }
}

function Update-PlatformFields {
    param([string]$Platform)

    try {
        Write-Verbose "Update-PlatformFields called for platform: $Platform"

        # Get all platform-specific UI elements
        $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
        $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
        $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
        $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
        $browseExecutablePathButton = $script:Window.FindName("BrowseExecutablePathButton")

        # Disable all platform fields and set gray background
        if ($steamAppIdTextBox) {
            $steamAppIdTextBox.IsEnabled = $false
            $steamAppIdTextBox.Background = [System.Windows.Media.Brushes]::LightGray
        }
        if ($epicGameIdTextBox) {
            $epicGameIdTextBox.IsEnabled = $false
            $epicGameIdTextBox.Background = [System.Windows.Media.Brushes]::LightGray
        }
        if ($riotGameIdTextBox) {
            $riotGameIdTextBox.IsEnabled = $false
            $riotGameIdTextBox.Background = [System.Windows.Media.Brushes]::LightGray
        }
        if ($executablePathTextBox) {
            $executablePathTextBox.IsEnabled = $false
            $executablePathTextBox.Background = [System.Windows.Media.Brushes]::LightGray
        }
        if ($browseExecutablePathButton) {
            $browseExecutablePathButton.IsEnabled = $false
        }

        # Enable the appropriate field based on platform and clear others
        switch ($Platform) {
            "steam" {
                if ($steamAppIdTextBox) {
                    $steamAppIdTextBox.IsEnabled = $true
                    $steamAppIdTextBox.Background = [System.Windows.Media.Brushes]::White
                }
                if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
                if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
                if ($executablePathTextBox) { $executablePathTextBox.Text = "" }
                Write-Verbose "  Enabled Steam AppID field"
            }
            "epic" {
                if ($epicGameIdTextBox) {
                    $epicGameIdTextBox.IsEnabled = $true
                    $epicGameIdTextBox.Background = [System.Windows.Media.Brushes]::White
                }
                if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
                if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
                if ($executablePathTextBox) { $executablePathTextBox.Text = "" }
                Write-Verbose "  Enabled Epic GameID field"
            }
            "riot" {
                if ($riotGameIdTextBox) {
                    $riotGameIdTextBox.IsEnabled = $true
                    $riotGameIdTextBox.Background = [System.Windows.Media.Brushes]::White
                }
                if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
                if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
                if ($executablePathTextBox) { $executablePathTextBox.Text = "" }
                Write-Verbose "  Enabled Riot GameID field"
            }
            "standalone" {
                if ($executablePathTextBox) {
                    $executablePathTextBox.IsEnabled = $true
                    $executablePathTextBox.Background = [System.Windows.Media.Brushes]::White
                }
                if ($browseExecutablePathButton) {
                    $browseExecutablePathButton.IsEnabled = $true
                }
                if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
                if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
                if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
                Write-Verbose "  Enabled Executable Path field"
            }
            default {
                Write-Warning "Unknown platform: $Platform, defaulting to standalone"
                if ($executablePathTextBox) {
                    $executablePathTextBox.IsEnabled = $true
                    $executablePathTextBox.Background = [System.Windows.Media.Brushes]::White
                }
                if ($browseExecutablePathButton) {
                    $browseExecutablePathButton.IsEnabled = $true
                }
                if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
                if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
                if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
            }
        }

        Write-Verbose "Platform fields updated successfully for: $Platform"
    } catch {
        Write-Warning "Failed to update platform fields: $($_.Exception.Message)"
    }
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

<#
.SYNOPSIS
    Helper function to safely set or add a property to a PSCustomObject.

.DESCRIPTION
    Checks if a property exists on an object and sets its value, or adds the property if it doesn't exist.
    This prevents errors when trying to set non-existent properties on PSCustomObject instances.

.PARAMETER Object
    The PSCustomObject to modify.

.PARAMETER PropertyName
    The name of the property to set or add.

.PARAMETER Value
    The value to assign to the property.
#>
function Set-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Object,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($Object.PSObject.Properties[$PropertyName]) {
        $Object.$PropertyName = $Value
    } else {
        $Object | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $Value -Force
    }
}

function Save-CurrentGameData {
    if (-not $script:CurrentGameId) {
        Write-Verbose "No game selected, skipping save"
        return
    }

    if (-not $script:StateManager -or -not $script:StateManager.ConfigData.games) {
        Write-Warning "StateManager or games not available"
        return
    }

    # Get the current game data
    $gameData = $script:StateManager.ConfigData.games.$script:CurrentGameId
    if (-not $gameData) {
        Write-Warning "Game data not found for: $script:CurrentGameId"
        return
    }

    Write-Verbose "Saving game data for: $script:CurrentGameId"

    # Save game name
    $gameNameTextBox = $script:Window.FindName("GameNameTextBox")
    if ($gameNameTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "name" -Value $gameNameTextBox.Text
    }

    # Save process name
    $processNameTextBox = $script:Window.FindName("ProcessNameTextBox")
    if ($processNameTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "processName" -Value $processNameTextBox.Text
    }

    # Save platform
    $platformCombo = $script:Window.FindName("PlatformComboBox")
    if ($platformCombo -and $platformCombo.SelectedItem) {
        Set-PropertyValue -Object $gameData -PropertyName "platform" -Value $platformCombo.SelectedItem.Tag
    }

    # Save Steam AppID
    $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
    if ($steamAppIdTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "steamAppId" -Value $steamAppIdTextBox.Text
    }

    # Save Epic GameID
    $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
    if ($epicGameIdTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "epicGameId" -Value $epicGameIdTextBox.Text
    }

    # Save Riot GameID
    $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
    if ($riotGameIdTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "riotGameId" -Value $riotGameIdTextBox.Text
    }

    # Save executable path (normalize backslashes to forward slashes)
    $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
    if ($executablePathTextBox) {
        $normalizedPath = $executablePathTextBox.Text -replace '\\', '/'
        Set-PropertyValue -Object $gameData -PropertyName "executablePath" -Value $normalizedPath
    }

    # Save managed apps list
    $appsToManagePanel = $script:Window.FindName("AppsToManagePanel")
    if ($appsToManagePanel) {
        $appsToManage = @()
        foreach ($child in $appsToManagePanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $appsToManage += $child.Tag
            }
        }
        Set-PropertyValue -Object $gameData -PropertyName "appsToManage" -Value $appsToManage
    }

    Write-Verbose "Game data saved successfully for: $script:CurrentGameId"
}

function Save-CurrentAppData {
    if (-not $script:CurrentAppId) {
        Write-Verbose "No app selected, skipping save"
        return
    }

    if (-not $script:StateManager -or -not $script:StateManager.ConfigData.managedApps) {
        Write-Warning "StateManager or managedApps not available"
        return
    }

    # Get the user-entered app ID from the text box
    # This is the actual config key, not the display name
    $appIdTextBox = $script:Window.FindName("AppIdTextBox")
    $newAppId = if ($appIdTextBox -and $appIdTextBox.Text) {
        $appIdTextBox.Text.Trim()
    } else {
        $script:CurrentAppId
    }

    # Validate the new app ID
    if ([string]::IsNullOrWhiteSpace($newAppId)) {
        Write-Warning "App ID cannot be empty"
        Show-SafeMessage -Key "appIdCannotBeEmpty" -MessageType "Warning"
        return
    }

    # Check if the app ID has changed
    $idChanged = ($newAppId -ne $script:CurrentAppId)

    # If ID changed, validate that the new ID is not already in use
    if ($idChanged) {
        if ($script:StateManager.ConfigData.managedApps.PSObject.Properties.Name -contains $newAppId) {
            Write-Warning "App ID '$newAppId' is already in use. Cannot rename."
            Show-SafeMessage -Key "appIdAlreadyExists" -MessageType "Warning" -FormatArgs @($newAppId)
            return
        }
        Write-Verbose "App ID changed from '$script:CurrentAppId' to '$newAppId'"
    }

    # Get the existing app data
    $appData = $script:StateManager.ConfigData.managedApps.$script:CurrentAppId
    if (-not $appData) {
        Write-Warning "App data not found for: $script:CurrentAppId"
        return
    }

    Write-Verbose "Saving app data for: $script:CurrentAppId $(if ($idChanged) { "-> $newAppId" })"

    # Save process name
    $appProcessNameTextBox = $script:Window.FindName("AppProcessNameTextBox")
    if ($appProcessNameTextBox) {
        $processNameValue = $appProcessNameTextBox.Text
        if ($processNameValue -match '\|') {
            Set-PropertyValue -Object $appData -PropertyName "processName" -Value ($processNameValue -split '\|' | ForEach-Object { $_.Trim() })
        } else {
            Set-PropertyValue -Object $appData -PropertyName "processName" -Value $processNameValue
        }
    }

    # Save path (normalize backslashes to forward slashes)
    $appPathTextBox = $script:Window.FindName("AppPathTextBox")
    if ($appPathTextBox) {
        $normalizedPath = $appPathTextBox.Text -replace '\\', '/'
        Set-PropertyValue -Object $appData -PropertyName "path" -Value $normalizedPath
    }

    # Save arguments
    $appArgumentsTextBox = $script:Window.FindName("AppArgumentsTextBox")
    if ($appArgumentsTextBox) {
        Set-PropertyValue -Object $appData -PropertyName "arguments" -Value $appArgumentsTextBox.Text
    }

    # Save start action
    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    if ($gameStartActionCombo -and $gameStartActionCombo.SelectedItem) {
        Set-PropertyValue -Object $appData -PropertyName "gameStartAction" -Value $gameStartActionCombo.SelectedItem.Tag
    }

    # Save end action
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
    if ($gameEndActionCombo -and $gameEndActionCombo.SelectedItem) {
        Set-PropertyValue -Object $appData -PropertyName "gameEndAction" -Value $gameEndActionCombo.SelectedItem.Tag
    }

    # Save termination method
    $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
    if ($terminationMethodCombo -and $terminationMethodCombo.SelectedItem) {
        Set-PropertyValue -Object $appData -PropertyName "terminationMethod" -Value $terminationMethodCombo.SelectedItem.Tag
    }

    # Save graceful timeout
    $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
    if ($gracefulTimeoutTextBox) {
        $timeoutSeconds = 5
        if ([int]::TryParse($gracefulTimeoutTextBox.Text, [ref]$timeoutSeconds)) {
            Set-PropertyValue -Object $appData -PropertyName "gracefulTimeoutMs" -Value ($timeoutSeconds * 1000)
        } else {
            Set-PropertyValue -Object $appData -PropertyName "gracefulTimeoutMs" -Value 5000
        }
    }

    # If the app ID changed, we need to:
    # 1. Add the data under the new ID
    # 2. Remove the old ID entry
    # 3. Update the _order array
    # 4. Update references in games that use this app
    if ($idChanged) {
        Write-Verbose "Performing app ID rename operation"

        # Add data under new ID
        $script:StateManager.ConfigData.managedApps | Add-Member -NotePropertyName $newAppId -NotePropertyValue $appData -Force

        # Remove old ID entry
        $script:StateManager.ConfigData.managedApps.PSObject.Properties.Remove($script:CurrentAppId)

        # Update the _order array
        if ($script:StateManager.ConfigData.managedApps._order) {
            $orderIndex = $script:StateManager.ConfigData.managedApps._order.IndexOf($script:CurrentAppId)
            if ($orderIndex -ge 0) {
                $script:StateManager.ConfigData.managedApps._order[$orderIndex] = $newAppId
            }
        }

        # Update references in games' appsToManage arrays
        if ($script:StateManager.ConfigData.games) {
            foreach ($gameId in $script:StateManager.ConfigData.games.PSObject.Properties.Name) {
                if ($gameId -eq '_order') { continue }

                $game = $script:StateManager.ConfigData.games.$gameId
                if ($game.appsToManage -and ($game.appsToManage -contains $script:CurrentAppId)) {
                    $appIndex = $game.appsToManage.IndexOf($script:CurrentAppId)
                    if ($appIndex -ge 0) {
                        $game.appsToManage[$appIndex] = $newAppId
                        Write-Verbose "Updated app reference in game '$gameId'"
                    }
                }
            }
        }

        # Update the current app ID reference
        $script:CurrentAppId = $newAppId

        Write-Verbose "App ID renamed successfully to: $newAppId"
    }

    # Mark as modified
    $script:StateManager.SetModified()

    Write-Verbose "App data saved for: $script:CurrentAppId"
}

<#
.SYNOPSIS
    Encrypts a plain text password using Windows Data Protection API (DPAPI).

.DESCRIPTION
    Uses ConvertTo-SecureString and ConvertFrom-SecureString to encrypt passwords
    with DPAPI. The encrypted string can only be decrypted by the same user on
    the same machine.

.PARAMETER PlainTextPassword
    The plain text password to encrypt.

.OUTPUTS
    String - The encrypted password string.
#>
function Protect-Password {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainTextPassword
    )

    try {
        if ([string]::IsNullOrEmpty($PlainTextPassword)) {
            return ""
        }

        # Convert to SecureString, then to encrypted string using DPAPI
        $secureString = ConvertTo-SecureString -String $PlainTextPassword -AsPlainText -Force
        $encryptedString = ConvertFrom-SecureString -SecureString $secureString

        return $encryptedString
    } catch {
        Write-Warning "Failed to encrypt password: $($_.Exception.Message)"
        return $PlainTextPassword  # Fallback to plain text if encryption fails
    }
}

<#
.SYNOPSIS
    Decrypts a DPAPI-encrypted password string.

.DESCRIPTION
    Uses ConvertTo-SecureString to decrypt DPAPI-encrypted passwords.
    Supports both encrypted strings and plain text (for backward compatibility).

.PARAMETER EncryptedPassword
    The encrypted password string to decrypt.

.OUTPUTS
    String - The decrypted plain text password.
#>
function Unprotect-Password {
    param(
        [Parameter(Mandatory = $false)]
        [string]$EncryptedPassword
    )

    try {
        if ([string]::IsNullOrEmpty($EncryptedPassword)) {
            return ""
        }

        # Try to decrypt as DPAPI-encrypted string
        try {
            $secureString = ConvertTo-SecureString -String $EncryptedPassword
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
            $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

            return $plainText
        } catch {
            # If decryption fails, assume it's plain text (backward compatibility)
            Write-Verbose "Password is not encrypted, treating as plain text"
            return $EncryptedPassword
        }
    } catch {
        Write-Warning "Failed to decrypt password: $($_.Exception.Message)"
        return ""
    }
}

function Save-GlobalSettingsData {
    Write-Verbose "Save-GlobalSettingsData: Starting to save global settings"

    try {
        # Get references to UI controls
        $obsHostTextBox = $script:Window.FindName("OBSHostTextBox")
        $obsPortTextBox = $script:Window.FindName("OBSPortTextBox")
        $obsPasswordBox = $script:Window.FindName("OBSPasswordBox")
        $replayBufferCheckBox = $script:Window.FindName("OBSReplayBufferCheckBox")
        $steamPathTextBox = $script:Window.FindName("SteamPathTextBox")
        $epicPathTextBox = $script:Window.FindName("EpicPathTextBox")
        $riotPathTextBox = $script:Window.FindName("RiotPathTextBox")
        $obsPathTextBox = $script:Window.FindName("OBSPathTextBox")
        $logRetentionCombo = $script:Window.FindName("LogRetentionCombo")
        $enableLogNotarizationCheckBox = $script:Window.FindName("EnableLogNotarizationCheckBox")

        # Ensure integrations section exists
        if (-not $script:StateManager.ConfigData.integrations) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "integrations" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs section exists
        if (-not $script:StateManager.ConfigData.integrations.obs) {
            $script:StateManager.ConfigData.integrations | Add-Member -NotePropertyName "obs" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs.websocket section exists
        if (-not $script:StateManager.ConfigData.integrations.obs.websocket) {
            $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "websocket" -NotePropertyValue @{} -Force
        }

        # Save OBS websocket settings
        if ($obsHostTextBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["host"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "host" -NotePropertyValue $obsHostTextBox.Text -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.host = $obsHostTextBox.Text
            }
            Write-Verbose "Saved OBS host: $($obsHostTextBox.Text)"
        }

        if ($obsPortTextBox) {
            $portValue = if ($obsPortTextBox.Text) { [int]$obsPortTextBox.Text } else { 4455 }
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["port"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "port" -NotePropertyValue $portValue -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.port = $portValue
            }
            Write-Verbose "Saved OBS port: $portValue"
        }

        if ($obsPasswordBox) {
            # Check if user entered a new password or if we should keep the existing one
            if ($obsPasswordBox.Password.Length -gt 0) {
                # User entered a new password - encrypt and save it
                $encryptedPassword = Protect-Password -PlainTextPassword $obsPasswordBox.Password

                if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "password" -NotePropertyValue $encryptedPassword -Force
                } else {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = $encryptedPassword
                }
                Write-Verbose "Saved OBS password (encrypted): $('*' * $obsPasswordBox.Password.Length)"
            } elseif ($obsPasswordBox.Tag -eq "SAVED") {
                # Password field is empty but Tag indicates password exists - keep existing password
                Write-Verbose "OBS password unchanged (keeping existing encrypted password)"
                # No action needed - existing password in config is preserved
            } else {
                # Password field is empty and no saved password - clear password
                if ($script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = ""
                }
                Write-Verbose "OBS password cleared"
            }
        }

        # Save OBS replay buffer setting
        if ($replayBufferCheckBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["replayBuffer"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "replayBuffer" -NotePropertyValue ([bool]$replayBufferCheckBox.IsChecked) -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.replayBuffer = [bool]$replayBufferCheckBox.IsChecked
            }
            Write-Verbose "Saved replay buffer: $($replayBufferCheckBox.IsChecked)"
        }

        # Ensure paths section exists
        if (-not $script:StateManager.ConfigData.paths) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "paths" -NotePropertyValue @{} -Force
        }

        # Save platform paths (normalize backslashes to forward slashes)
        if ($steamPathTextBox) {
            $normalizedPath = $steamPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.paths.PSObject.Properties["steam"]) {
                $script:StateManager.ConfigData.paths | Add-Member -NotePropertyName "steam" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.paths.steam = $normalizedPath
            }
            Write-Verbose "Saved Steam path: $normalizedPath"
        }

        if ($epicPathTextBox) {
            $normalizedPath = $epicPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.paths.PSObject.Properties["epic"]) {
                $script:StateManager.ConfigData.paths | Add-Member -NotePropertyName "epic" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.paths.epic = $normalizedPath
            }
            Write-Verbose "Saved Epic path: $normalizedPath"
        }

        if ($riotPathTextBox) {
            $normalizedPath = $riotPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.paths.PSObject.Properties["riot"]) {
                $script:StateManager.ConfigData.paths | Add-Member -NotePropertyName "riot" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.paths.riot = $normalizedPath
            }
            Write-Verbose "Saved Riot path: $normalizedPath"
        }

        if ($obsPathTextBox) {
            $normalizedPath = $obsPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["path"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "path" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.path = $normalizedPath
            }
            Write-Verbose "Saved OBS path: $normalizedPath"
        }

        # Ensure logging section exists
        if (-not $script:StateManager.ConfigData.logging) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "logging" -NotePropertyValue @{} -Force
        }

        # Save log retention setting
        if ($logRetentionCombo -and $logRetentionCombo.SelectedItem) {
            $retentionDays = switch ($logRetentionCombo.SelectedItem.Tag) {
                "7" { 7 }
                "30" { 30 }
                "180" { 180 }
                "unlimited" { 0 }
                default { 90 }
            }

            if (-not $script:StateManager.ConfigData.logging.PSObject.Properties["logRetentionDays"]) {
                $script:StateManager.ConfigData.logging | Add-Member -NotePropertyName "logRetentionDays" -NotePropertyValue $retentionDays -Force
            } else {
                $script:StateManager.ConfigData.logging.logRetentionDays = $retentionDays
            }
            Write-Verbose "Saved log retention days: $retentionDays"
        }

        # Save log notarization setting
        if ($enableLogNotarizationCheckBox) {
            if (-not $script:StateManager.ConfigData.logging.PSObject.Properties["enableNotarization"]) {
                $script:StateManager.ConfigData.logging | Add-Member -NotePropertyName "enableNotarization" -NotePropertyValue ([bool]$enableLogNotarizationCheckBox.IsChecked) -Force
            } else {
                $script:StateManager.ConfigData.logging.enableNotarization = [bool]$enableLogNotarizationCheckBox.IsChecked
            }
            Write-Verbose "Saved log notarization: $($enableLogNotarizationCheckBox.IsChecked)"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-GlobalSettingsData: Global settings saved successfully"

    } catch {
        Write-Error "Failed to save global settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-OBSSettingsData {
    Write-Verbose "Save-OBSSettingsData: Starting to save OBS settings"

    try {
        # Get references to UI controls from OBS tab
        $obsHostTextBox = $script:Window.FindName("OBSHostTextBox")
        $obsPortTextBox = $script:Window.FindName("OBSPortTextBox")
        $obsPasswordBox = $script:Window.FindName("OBSPasswordBox")
        $replayBufferCheckBox = $script:Window.FindName("OBSReplayBufferCheckBox")
        $obsPathTextBox = $script:Window.FindName("OBSPathTextBox")

        # Ensure integrations section exists
        if (-not $script:StateManager.ConfigData.integrations) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "integrations" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs section exists
        if (-not $script:StateManager.ConfigData.integrations.obs) {
            $script:StateManager.ConfigData.integrations | Add-Member -NotePropertyName "obs" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs.websocket section exists
        if (-not $script:StateManager.ConfigData.integrations.obs.websocket) {
            $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "websocket" -NotePropertyValue @{} -Force
        }

        # Save OBS websocket settings
        if ($obsHostTextBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["host"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "host" -NotePropertyValue $obsHostTextBox.Text -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.host = $obsHostTextBox.Text
            }
            Write-Verbose "Saved OBS host: $($obsHostTextBox.Text)"
        }

        if ($obsPortTextBox) {
            $portValue = if ($obsPortTextBox.Text) { [int]$obsPortTextBox.Text } else { 4455 }
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["port"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "port" -NotePropertyValue $portValue -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.port = $portValue
            }
            Write-Verbose "Saved OBS port: $portValue"
        }

        if ($obsPasswordBox) {
            if ($obsPasswordBox.Password.Length -gt 0) {
                $encryptedPassword = Protect-Password -PlainTextPassword $obsPasswordBox.Password
                if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "password" -NotePropertyValue $encryptedPassword -Force
                } else {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = $encryptedPassword
                }
                Write-Verbose "Saved OBS password (encrypted)"
            } elseif ($obsPasswordBox.Tag -eq "SAVED") {
                Write-Verbose "OBS password unchanged (keeping existing encrypted password)"
            } else {
                if ($script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = ""
                }
                Write-Verbose "OBS password cleared"
            }
        }

        # Save OBS replay buffer setting
        if ($replayBufferCheckBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["replayBuffer"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "replayBuffer" -NotePropertyValue ([bool]$replayBufferCheckBox.IsChecked) -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.replayBuffer = [bool]$replayBufferCheckBox.IsChecked
            }
            Write-Verbose "Saved replay buffer: $($replayBufferCheckBox.IsChecked)"
        }

        # Save OBS executable path
        if ($obsPathTextBox) {
            $normalizedPath = $obsPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["path"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "path" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.path = $normalizedPath
            }
            Write-Verbose "Saved OBS path: $normalizedPath"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-OBSSettingsData: OBS settings saved successfully"

    } catch {
        Write-Error "Failed to save OBS settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-DiscordSettingsData {
    Write-Verbose "Save-DiscordSettingsData: Starting to save Discord settings"

    try {
        # Ensure discord section exists
        if (-not $script:StateManager.ConfigData.discord) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "discord" -NotePropertyValue @{} -Force
        }

        # Get Discord path from UI
        $discordPathTextBox = $script:Window.FindName("DiscordPathTextBox")
        if ($discordPathTextBox -and $discordPathTextBox.Text) {
            $script:StateManager.ConfigData.discord.path = $discordPathTextBox.Text
            Write-Verbose "Save-DiscordSettingsData: Discord path set to $($discordPathTextBox.Text)"
        }

        # Get game mode checkbox
        $enableGameModeCheckBox = $script:Window.FindName("DiscordEnableGameModeCheckBox")
        if ($enableGameModeCheckBox) {
            $script:StateManager.ConfigData.discord.enableGameMode = $enableGameModeCheckBox.IsChecked
            Write-Verbose "Save-DiscordSettingsData: Enable game mode set to $($enableGameModeCheckBox.IsChecked)"
        }

        # Get status settings
        $statusOnStartCombo = $script:Window.FindName("DiscordStatusOnStartCombo")
        if ($statusOnStartCombo -and $statusOnStartCombo.SelectedItem) {
            $script:StateManager.ConfigData.discord.statusOnStart = $statusOnStartCombo.SelectedItem.Tag
            Write-Verbose "Save-DiscordSettingsData: Status on start set to $($statusOnStartCombo.SelectedItem.Tag)"
        }

        $statusOnEndCombo = $script:Window.FindName("DiscordStatusOnEndCombo")
        if ($statusOnEndCombo -and $statusOnEndCombo.SelectedItem) {
            $script:StateManager.ConfigData.discord.statusOnEnd = $statusOnEndCombo.SelectedItem.Tag
            Write-Verbose "Save-DiscordSettingsData: Status on end set to $($statusOnEndCombo.SelectedItem.Tag)"
        }

        # Get overlay checkbox
        $disableOverlayCheckBox = $script:Window.FindName("DiscordDisableOverlayCheckBox")
        if ($disableOverlayCheckBox) {
            $script:StateManager.ConfigData.discord.disableOverlay = $disableOverlayCheckBox.IsChecked
            Write-Verbose "Save-DiscordSettingsData: Disable overlay set to $($disableOverlayCheckBox.IsChecked)"
        }

        # Get Rich Presence settings
        $rpcEnableCheckBox = $script:Window.FindName("DiscordRPCEnableCheckBox")
        if ($rpcEnableCheckBox) {
            if (-not $script:StateManager.ConfigData.discord.rpc) {
                $script:StateManager.ConfigData.discord | Add-Member -NotePropertyName "rpc" -NotePropertyValue @{} -Force
            }
            $script:StateManager.ConfigData.discord.rpc.enabled = $rpcEnableCheckBox.IsChecked
            Write-Verbose "Save-DiscordSettingsData: RPC enabled set to $($rpcEnableCheckBox.IsChecked)"
        }

        $rpcAppIdTextBox = $script:Window.FindName("DiscordRPCAppIdTextBox")
        if ($rpcAppIdTextBox) {
            if (-not $script:StateManager.ConfigData.discord.rpc) {
                $script:StateManager.ConfigData.discord | Add-Member -NotePropertyName "rpc" -NotePropertyValue @{} -Force
            }
            $script:StateManager.ConfigData.discord.rpc.applicationId = $rpcAppIdTextBox.Text
            Write-Verbose "Save-DiscordSettingsData: RPC application ID set to $($rpcAppIdTextBox.Text)"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-DiscordSettingsData: Discord settings saved successfully"

    } catch {
        Write-Error "Failed to save Discord settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-VTubeStudioSettingsData {
    Write-Verbose "Save-VTubeStudioSettingsData: Starting to save VTube Studio settings"

    try {
        # TODO: Implement VTube Studio settings save logic once UI controls are defined
        # Placeholder for VTube Studio-specific settings

        # Ensure vtubeStudio section exists
        if (-not $script:StateManager.ConfigData.vtubeStudio) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "vtubeStudio" -NotePropertyValue @{} -Force
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-VTubeStudioSettingsData: VTube Studio settings saved successfully"

    } catch {
        Write-Error "Failed to save VTube Studio settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-OriginalConfig {
    if ($script:StateManager) {
        $script:StateManager.SaveOriginalConfig()
        Write-Verbose "Original configuration saved"
    } else {
        Write-Warning "StateManager not available, cannot save original configuration"
    }
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

                Save-ConfigJson -ConfigData $script:StateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

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

            Write-Host "[ERROR] ConfigEditor: Restarting application to apply language changes"

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
                Write-Host "[OK] ConfigEditor: New instance started successfully - PID: $($newProcess.Id)"
            } catch {
                Write-Host "[WARNING] ConfigEditor: Failed to start new instance - $($_.Exception.Message)"
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

# Debug helper function to show usage information
function Show-DebugHelp {
    Write-Host ""
    Write-Host "[INFO] ConfigEditor: Debug Mode Usage"
    Write-Host ""
    Write-Host "Start with debug mode (manual close):"
    Write-Host "  gui\ConfigEditor.ps1 -DebugMode"
    Write-Host ""
    Write-Host "Start with auto-close (3 seconds):"
    Write-Host "  gui\ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 3"
    Write-Host ""
    Write-Host "Start with auto-close (10 seconds):"
    Write-Host "  gui\ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 10"
    Write-Host ""
    Write-Host "Normal mode (no debug output):"
    Write-Host "  gui\ConfigEditor.ps1"
    Write-Host ""
    Write-Host "Show this help:"
    Write-Host "  gui\ConfigEditor.ps1 -NoAutoStart"
    Write-Host "  Then call: Show-DebugHelp"
    Write-Host ""
}

# Start the application
if (-not $NoAutoStart) {
    if (Test-Prerequisites) {
        Initialize-ConfigEditor
    } else {
        Write-Host "[ERROR] ConfigEditor: Cannot start due to missing prerequisites"
        exit 1
    }
}
