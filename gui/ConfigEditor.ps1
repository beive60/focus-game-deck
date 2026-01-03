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
    Version: 2.0.0 - Multi-Executable Architecture Migration
    Last Updated: 2025-09-23
    Requires: PowerShell 5.1 or higher, Windows 10/11

.LINK
    https://github.com/beive60/focus-game-deck
#>

param(
    [switch]$NoAutoStart,
    [switch]$DebugMode,
    [int]$AutoCloseSeconds = 0,
    [switch]$Headless  # Headless mode: suppress UI dialogs and window display
)

if ($DebugMode) {
    $VerbosePreference = 'Continue'
}

# Check for duplicate class definitions (occurs when script is run multiple times in same session)
# Note: This check is only relevant in script mode, not when running as compiled executable
$isCompiledExecutable = $false
try {
    # Detect if running as ps2exe compiled executable
    $processName = (Get-Process -Id $PID).ProcessName
    $isCompiledExecutable = ($processName -ne 'pwsh' -and $processName -ne 'powershell')
} catch {
    $isCompiledExecutable = $false
}

if (-not $isCompiledExecutable) {
    # Only check for duplicate classes in script mode
    $classAlreadyDefined = $false
    try {
        # Try to check if ConfigEditorState class is already defined
        $existingType = [ConfigEditorState] -as [type]
        if ($null -ne $existingType) {
            $classAlreadyDefined = $true
            Write-Warning "================================================================"
            Write-Warning "IMPORTANT: Classes are already defined in this PowerShell session."
            Write-Warning "Running this script multiple times in the same session causes type conflicts."
            Write-Warning "================================================================"
            Write-Warning ""
            Write-Warning "SOLUTION: Please start a NEW PowerShell session and run the script again."
            Write-Warning ""
            Write-Warning "Quick commands:"
            Write-Warning "  1. Close this terminal (type 'exit')"
            Write-Warning "  2. Open a new PowerShell terminal"
            Write-Warning "  3. Run: gui/ConfigEditor.ps1 -DebugMode"
            Write-Warning ""
            Write-Warning "================================================================"

            # Exit with error if classes are already defined
            if (-not $NoAutoStart) {
                Write-Error "Cannot continue with duplicate class definitions. Please use a new PowerShell session."
                exit 1
            }
        }
    } catch {
        # Class not defined yet - this is expected on first run
        $classAlreadyDefined = $false
    }
}

# Expose headless flag to script scope for functions to read
$script:Headless = [bool]$Headless

# Set system-level encoding settings for proper character display
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.Encoding]::UTF8

# Dynamically set console encoding only if a valid console handle exists
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    Write-Verbose "Console encoding successfully set to UTF-8."
} catch [System.IO.IOException] {
    # This is expected for -noConsole executables (e.g., ConfigEditor.exe)
    # The error is "The handle is invalid."
    Write-Verbose "No console handle found. Skipping console encoding setup."
} catch {
    # Catch any other unexpected errors
    Write-Warning "An unexpected error occurred while setting console encoding: $_"
}

# Detect execution environment to determine application root
$currentProcess = Get-Process -Id $PID
# Make isExecutable script-scoped so functions can access it
$script:isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

Write-Verbose "--- DEBUG: Path Resolution Info ---"
Write-Verbose "isExecutable: $script:isExecutable"
Write-Verbose "PID: $PID"
Write-Verbose "ProcessName: $($currentProcess.ProcessName)"
Write-Verbose "ProcessPath (Get-Process): '$($currentProcess.Path)'"
try {
    # Alternative method to get path, often more reliable in some contexts
    Write-Verbose "MainModule.FileName: '$([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)'"
} catch {
    Write-Verbose "MainModule.FileName: [Failed to get - $($_.Exception.Message)]"
}
Write-Verbose "PSScriptRoot: '$PSScriptRoot'"

# Define the application root directory
# This is critical for finding external resources (config, XAML, logs)
if ($script:isExecutable) {
    # In executable mode, the root is the directory where the .exe file is located
    # ps2exe extracts to temp, but we need the actual exe location for external files
    $script:appRoot = Split-Path -Parent $currentProcess.Path
} else {
    # In development (script) mode, calculate the project root relative to the current script
    # For ConfigEditor.ps1 in /gui, the root is one level up
    $script:appRoot = Split-Path -Parent $PSScriptRoot
}

Write-Verbose "Calculated appRoot: '$script:appRoot'"
if ([string]::IsNullOrEmpty($script:appRoot)) {
    Write-Verbose "ERROR: appRoot is NULL or EMPTY! Join-Path will fail."
}

# Prerequisites check function
function Test-Prerequisites {
    param()

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell version 5.0 or higher required. Current: $($PSVersionTable.PSVersion)"
    }

    # Define required external files based on execution mode
    $mainWindowPath = Join-Path -Path $script:appRoot -ChildPath "gui/MainWindow.xaml"
    # Check MainWindow.xaml - only fatal if missing AND embedded XAML not available
    if (-not (Test-Path $mainWindowPath) -and -not $Global:Xaml_MainWindow) {
        throw "Fatal error: Required file not found and no embedded XAML available: $mainWindowPath"
    }

    $requiredFiles = @(
        (Join-Path -Path $script:appRoot -ChildPath "localization"),
        (Join-Path -Path $script:appRoot -ChildPath "config/config.json")
    )

    # Add MainWindow.xaml to required files list only if it exists (optional in bundled mode)
    if (Test-Path $mainWindowPath) {
        $requiredFiles += $mainWindowPath
    }

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            Write-Verbose "[WARNING] Required file missing: $file"
        }
    }
    return $true
}

# Load WPF assemblies FIRST before any dot-sourcing
function Initialize-WpfAssemblies {
    try {
        Write-Verbose "[INFO] ConfigEditor: Loading WPF assemblies"

        # Load required assemblies with guard to prevent duplicate loading
        $requiredAssemblies = @(
            'PresentationFramework',
            'PresentationCore',
            'WindowsBase',
            'System.Windows.Forms',
            'System.Xaml'
        )
        foreach ($assemblyName in $requiredAssemblies) {
            $isLoaded = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $assemblyName }
            if (-not $isLoaded) {
                try {
                    Add-Type -AssemblyName $assemblyName
                    Write-Verbose "[INFO] Loaded assembly: $assemblyName"
                } catch {
                    Write-Warning "[WARNING] Failed to load assembly: $assemblyName - $($_.Exception.Message)"
                }
            } else {
                Write-Verbose "[INFO] Assembly already loaded: $assemblyName"
            }
        }
        Write-Verbose "[OK] ConfigEditor: WPF assemblies loaded successfully"

        # Define the InsertionIndicatorAdorner class for drag and drop visual feedback
        try {
            $adornerCode = @"
using System;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;

public class InsertionIndicatorAdorner : Adorner
{
    private bool insertAbove;
    private Pen pen;

    public InsertionIndicatorAdorner(UIElement adornedElement, bool insertAbove) : base(adornedElement)
    {
        this.insertAbove = insertAbove;
        this.IsHitTestVisible = false;

        // Create a pen for drawing the insertion line
        // Using a bright blue color with 2px thickness for visibility
        this.pen = new Pen(new SolidColorBrush(Color.FromRgb(0, 120, 215)), 2.0);
        this.pen.Freeze();
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        if (this.AdornedElement == null) return;

        Rect adornedElementRect = new Rect(this.AdornedElement.RenderSize);

        // Draw a horizontal line at the top or bottom of the adorned element
        double yPosition = this.insertAbove ? adornedElementRect.Top : adornedElementRect.Bottom;

        // Draw the line across the full width of the element
        Point startPoint = new Point(adornedElementRect.Left, yPosition);
        Point endPoint = new Point(adornedElementRect.Right, yPosition);

        drawingContext.DrawLine(this.pen, startPoint, endPoint);

        // Draw small triangles at both ends to make it more visible
        double triangleSize = 4.0;

        // Left triangle
        var leftTriangle = new StreamGeometry();
        using (StreamGeometryContext ctx = leftTriangle.Open())
        {
            ctx.BeginFigure(new Point(startPoint.X, yPosition), true, true);
            ctx.LineTo(new Point(startPoint.X + triangleSize, yPosition - triangleSize), true, false);
            ctx.LineTo(new Point(startPoint.X + triangleSize, yPosition + triangleSize), true, false);
        }
        leftTriangle.Freeze();
        drawingContext.DrawGeometry(this.pen.Brush, null, leftTriangle);

        // Right triangle
        var rightTriangle = new StreamGeometry();
        using (StreamGeometryContext ctx = rightTriangle.Open())
        {
            ctx.BeginFigure(new Point(endPoint.X, yPosition), true, true);
            ctx.LineTo(new Point(endPoint.X - triangleSize, yPosition - triangleSize), true, false);
            ctx.LineTo(new Point(endPoint.X - triangleSize, yPosition + triangleSize), true, false);
        }
        rightTriangle.Freeze();
        drawingContext.DrawGeometry(this.pen.Brush, null, rightTriangle);
    }
}
"@

            # Get the already loaded WPF assemblies to avoid version conflicts
            $loadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies()
            $requiredAssemblyNames = @('PresentationCore', 'PresentationFramework', 'WindowsBase', 'System.Xaml')
            $assemblyPaths = @()

            foreach ($name in $requiredAssemblyNames) {
                $assembly = $loadedAssemblies | Where-Object { $_.GetName().Name -eq $name } | Select-Object -First 1
                if ($assembly) {
                    # Use Location for file-based assemblies
                    if ($assembly.Location -and (Test-Path $assembly.Location)) {
                        $assemblyPaths += $assembly.Location
                        Write-Verbose "[DEBUG] ConfigEditor: Found assembly $name at $($assembly.Location)"
                    } else {
                        # For GAC assemblies without Location, try to find them
                        Write-Verbose "[DEBUG] ConfigEditor: Assembly $name has no location, skipping"
                    }
                }
            }

            # If we don't have all required assemblies, fall back to just loading without custom references
            if ($assemblyPaths.Count -lt 4) {
                Write-Verbose "[WARNING] ConfigEditor: Not all assembly paths found ($($assemblyPaths.Count)/4), attempting without explicit references"
                try {
                    # Try without ReferencedAssemblies - let .NET resolve them
                    Add-Type -TypeDefinition $adornerCode -Language CSharp -IgnoreWarnings -ErrorAction Stop
                    Write-Verbose "[OK] ConfigEditor: InsertionIndicatorAdorner class loaded successfully (auto-resolved)"
                } catch {
                    Write-Warning "[WARNING] Failed to load InsertionIndicatorAdorner class: $($_.Exception.Message)"
                    Write-Verbose "[INFO] ConfigEditor: Drag and drop insertion indicator will not be available"
                }
            } else {
                # Load the adorner type using the already loaded assembly references
                Add-Type -TypeDefinition $adornerCode -ReferencedAssemblies $assemblyPaths -Language CSharp -ErrorAction Stop
                Write-Verbose "[OK] ConfigEditor: InsertionIndicatorAdorner class loaded successfully"
            }
        } catch {
            Write-Warning "[WARNING] Failed to load InsertionIndicatorAdorner class (outer catch): $($_.Exception.Message)"
            Write-Verbose "[INFO] ConfigEditor: Drag and drop insertion indicator will not be available"
        }

        return $true
    } catch {
        Write-Error "Failed to load WPF assemblies: $($_.Exception.Message)"
        return $false
    }
}

# Cleanup function to reset application state before initialization
function Invoke-StartupCleanup {
    try {
        Write-Verbose "[INFO] Startup cleanup: Checking for existing instances"

        # Close any existing window
        if (Get-Variable -Name "Window" -Scope Script -ErrorAction SilentlyContinue) {
            $existingWindow = $script:Window
            if ($null -ne $existingWindow) {
                Write-Verbose "[INFO] Startup cleanup: Closing existing window"
                try {
                    $existingWindow.Close()
                } catch {
                    Write-Verbose "[WARN] Startup cleanup: Failed to close window - $($_.Exception.Message)"
                }
            }
            Remove-Variable -Name "Window" -Scope Script -Force -ErrorAction SilentlyContinue
        }

        # Clear UI manager reference
        if (Get-Variable -Name "UIManager" -Scope Script -ErrorAction SilentlyContinue) {
            Write-Verbose "[INFO] Startup cleanup: Clearing UIManager reference"
            $script:UIManager = $null
            Remove-Variable -Name "UIManager" -Scope Script -Force -ErrorAction SilentlyContinue
        }

        # Clear state manager reference
        if (Get-Variable -Name "StateManager" -Scope Script -ErrorAction SilentlyContinue) {
            Write-Verbose "[INFO] Startup cleanup: Clearing StateManager reference"
            $script:StateManager = $null
            Remove-Variable -Name "StateManager" -Scope Script -Force -ErrorAction SilentlyContinue
        }

        # Clear localization reference
        if (Get-Variable -Name "Localization" -Scope Script -ErrorAction SilentlyContinue) {
            Write-Verbose "[INFO] Startup cleanup: Clearing Localization reference"
            $script:Localization = $null
            Remove-Variable -Name "Localization" -Scope Script -Force -ErrorAction SilentlyContinue
        }

        # Reset initialization flag
        $script:IsInitializationComplete = $false

        Write-Verbose "[OK] Startup cleanup: Completed successfully"
    } catch {
        Write-Verbose "[WARN] Startup cleanup: Error during cleanup - $($_.Exception.Message)"
        # Continue anyway - cleanup is best-effort
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
            # [fix] Change Scope to Script from Global
            if (-not (Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue)) {
                $missingMappings += $varName
            }
        }

        if ($missingMappings.Count -gt 0) {
            Write-Verbose "[WARNING] ConfigEditor: Missing UI mappings - $($missingMappings -join ', ')"
            return $false
        }

        # Validate mapping structure
        # [fix] Change Scope to Script from Global
        if ((Get-Variable -Name 'ButtonMappings' -Scope Script -ErrorAction SilentlyContinue).Value.Count -eq 0) {
            Write-Verbose "[WARNING] ConfigEditor: ButtonMappings is empty"
            return $false
        }

        Write-Verbose "[OK] ConfigEditor: UI mappings validated successfully"
        return $true
    } catch {
        Write-Warning "Failed to validate UI mappings: $($_.Exception.Message)"
        return $false
    }
}

# Initialize the application
function Initialize-ConfigEditor {
    Write-Verbose "[TRACE] Initialize-ConfigEditor: FUNCTION STARTED"
    try {
        # Step 0: Cleanup existing instances (if any)
        Write-Verbose "[INFO] ConfigEditor: Performing pre-initialization cleanup"
        Invoke-StartupCleanup

        # Debug mode information
        Write-Verbose "[DEBUG] ConfigEditor: Debug mode enabled"
        if ($AutoCloseSeconds -gt 0) {
            Write-Verbose "[DEBUG] ConfigEditor: Auto-close timer - $AutoCloseSeconds seconds"
        } else {
            Write-Verbose "[DEBUG] ConfigEditor: Manual close required"
        }

        Write-Verbose "[INFO] ConfigEditor: Initialization started"

        # Step 1: Load WPF assemblies FIRST
        if (-not (Initialize-WpfAssemblies)) {
            throw "WPF assemblies loading failed"
        }

        # Step 2: Load script modules (must be done before using PowerShell classes)
        Write-Verbose "[INFO] ConfigEditor: Loading script modules"

        # Define module list (order matters - dependencies must be loaded first)
        if (-not $script:isExecutable) {
            # In script mode, load modules from file system relative to project root
            Write-Verbose "[INFO] ConfigEditor: Running in script mode - loading modules from filesystem"

            try {
                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.JsonHelper.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.JsonHelper.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.JsonHelper.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.Mappings.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.Mappings.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.Mappings.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.State.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.State.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.State.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.Localization.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.Localization.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.Localization.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.UI.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.UI.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.UI.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.Events.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.Events.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.Events.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - src/modules/ValidationRules.ps1"
                . (Join-Path -Path $appRoot -ChildPath "src/modules/ValidationRules.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ValidationRules.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - scripts/Invoke-ConfigurationValidation.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "scripts/Invoke-ConfigurationValidation.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: Invoke-ConfigurationValidation.ps1"

                Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing module - gui/ConfigEditor.Save.ps1"
                . (Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.Save.ps1")
                Write-Verbose "[OK] ConfigEditor: Module Loaded: ConfigEditor.Save.ps1"
            } catch {
                # The error record ($_) from a dot-sourcing failure contains details
                # about the file that could not be loaded.
                Write-Error "[ERROR] ConfigEditor: A required GUI module could not be loaded."
                Write-Error "Error Details: $($_.Exception.Message)"
                # Re-throw the exception to halt execution, as the GUI cannot function.
                throw "Module loading failed. The application cannot continue."
            }
        }

        Write-Verbose "[OK] ConfigEditor: Script modules loaded successfully"
        Write-Verbose "[TRACE] Initialize-ConfigEditor: Reached Step 3"

        # Step 3: Prepare configuration path
        # Note: Actual config loading and generation happens in ConfigEditorState.LoadConfiguration()
        Write-Verbose "[INFO] ConfigEditor: Preparing configuration path"
        $script:ConfigPath = Join-Path -Path $script:appRoot -ChildPath "config/config.json"
        Write-Verbose "[INFO] ConfigEditor: Config path set to: $($script:ConfigPath)"

        # Step 4: Validate UI mappings
        Write-Verbose "[TRACE] Initialize-ConfigEditor: Reached Step 4"
        if (-not (Test-UIMappings)) {
            Write-Verbose "[WARNING] ConfigEditor: UI mappings validation failed - Some features may not work properly"
        }

        # Step 5: Initialize state manager with config path
        # This will load existing config.json or generate a new one with defaults
        Write-Verbose "[TRACE] Initialize-ConfigEditor: Reached Step 5"
        Write-Verbose "[INFO] ConfigEditor: Initializing state manager"
        try {
            $stateManager = [ConfigEditorState]::new($script:ConfigPath)
            $stateManager.LoadConfiguration()

            # Validate configuration data
            if ($null -eq $stateManager.ConfigData) {
                throw "Configuration data is null after loading"
            }
            Write-Verbose "[INFO] ConfigEditor: Configuration data structure - $($stateManager.ConfigData.GetType().Name)"

            $stateManager.SaveOriginalConfig()
            Write-Verbose "[OK] ConfigEditor: State manager initialized successfully"

            # Store state manager in script scope for access from functions
            $script:StateManager = $stateManager
            Write-Verbose "[TRACE] Initialize-ConfigEditor: StateManager stored in script scope"
        } catch {
            Write-Error "[ERROR] ConfigEditor: Failed to initialize state manager: $($_.Exception.Message)"
            Write-Verbose "[TRACE] Initialize-ConfigEditor: ERROR in Step 5 - throwing exception"
            throw
        }

        # Step 6: Import additional modules (Version, UpdateChecker, etc.)
        Write-Verbose "[TRACE] Initialize-ConfigEditor: Reached Step 6 (CRITICAL POINT)"
        Write-Verbose "[INFO] ConfigEditor: Importing additional modules"
        Write-Verbose "[TRACE] === ABOUT TO CALL Import-AdditionalModules ==="
        Import-AdditionalModules
        Write-Verbose "[TRACE] === RETURNED FROM Import-AdditionalModules ==="

        # Step 6.5: Verify global function references are set
        Write-Verbose "[INFO] ConfigEditor: Verifying global function references"
        if ($global:GetProjectVersionFunc) {
            Write-Verbose "[OK] ConfigEditor: GetProjectVersionFunc is set"
        } else {
            Write-Verbose "[WARN] ConfigEditor: GetProjectVersionFunc is NOT set"
        }
        if ($global:TestUpdateAvailableFunc) {
            Write-Verbose "[OK] ConfigEditor: TestUpdateAvailableFunc is set"
        } else {
            Write-Verbose "[WARN] ConfigEditor: TestUpdateAvailableFunc is NOT set"
        }

        # Step 7: Initialize localization
        Write-Verbose "[TRACE] Initialize-ConfigEditor: Reached Step 7"
        Write-Verbose "[INFO] ConfigEditor: Initializing localization"
        try {
            # Set script:ConfigData for localization to access
            # This must be done BEFORE creating the Localization instance
            $script:ConfigData = $stateManager.ConfigData
            Write-Verbose "[DEBUG] ConfigEditor: script:ConfigData.language = '$($script:ConfigData.language)'"

            # Pass shared project root into localization class (PowerShell classes cannot access script-scoped variables)
            $script:Localization = [ConfigEditorLocalization]::new($script:appRoot)

            # Re-detect language with ConfigData now available
            $script:Localization.DetectLanguage()

            Write-Verbose "[OK] ConfigEditor: Localization initialized - Language: $($script:Localization.CurrentLanguage)"
            Write-Verbose "[DEBUG] ConfigEditor: Localization.CurrentLanguage = '$($script:Localization.CurrentLanguage)'"
            Write-Verbose "[DEBUG] ConfigEditor: Localization type = '$($script:Localization.GetType().FullName)'"
        } catch {
            Write-Error "[ERROR] ConfigEditor: Failed to initialize localization: $($_.Exception.Message)"
        }

        # Step 8: Initialize UI manager
        Write-Verbose "[INFO] ConfigEditor: Initializing UI manager"
        try {
            # Validate mappings are available before creating UI
            if (-not (Get-Variable -Name "ButtonMappings" -Scope Script -ErrorAction SilentlyContinue)) {
                Write-Verbose "[WARNING] ConfigEditor: Button mappings not loaded - UI functionality may be limited"
            }

            Write-Verbose "[DEBUG] ConfigEditor: Creating ConfigEditorUI instance"
            Write-Verbose "[DEBUG] ConfigEditor: Localization instance type = '$($script:Localization.GetType().FullName)'"
            Write-Verbose "[DEBUG] ConfigEditor: StateManager instance type = '$($stateManager.GetType().FullName)'"

            $allMappings = @{
                Button = $ButtonMappings
                Label = $LabelMappings
                Tab = $TabMappings
                Text = $TextMappings
                CheckBox = $CheckBoxMappings
                RadioButton = $RadioButtonMappings
                MenuItem = $MenuItemMappings
                Tooltip = $TooltipMappings
                ComboBoxItem = $ComboBoxItemMappings
            }
            # Pass project root into UI class so it can construct file paths without referencing script-scoped variables
            $uiManager = [ConfigEditorUI]::new($stateManager, $allMappings, $script:Localization, $script:appRoot)

            Write-Verbose "[DEBUG] ConfigEditor: ConfigEditorUI instance created - $($null -ne $uiManager)"

            if ($null -eq $uiManager) {
                throw "Failed to create UI manager"
            }

            Write-Verbose "[DEBUG] ConfigEditor: Checking uiManager.Window"

            if ($null -eq $uiManager.Window) {
                Write-Verbose "[DEBUG] ConfigEditor: uiManager.Window is null"
                throw "UI manager Window is null"
            } else {
                Write-Verbose "[OK] ConfigEditor: uiManager.Window type - $($uiManager.Window.GetType().Name)"
            }

            $script:Window = $uiManager.Window

            # Store UI manager in script scope for access from functions
            $script:UIManager = $uiManager

            Write-Verbose "[OK] ConfigEditor: UI manager initialized successfully"
        } catch {
            Write-Verbose "[DEBUG] ConfigEditor: UI Manager initialization error details"
            Write-Verbose "[DEBUG] ConfigEditor: Error type - $($_.Exception.GetType().Name)"
            Write-Verbose "[DEBUG] ConfigEditor: Error message - $($_.Exception.Message)"
            if ($_.Exception.InnerException) {
                Write-Verbose "[DEBUG] ConfigEditor: Inner exception - $($_.Exception.InnerException.Message)"
            }

            # Check if mapping-related error
            if ($_.Exception.Message -match "ButtonMappings|Mappings|mapping") {
                Write-Verbose "[DEBUG] ConfigEditor: This appears to be a mapping-related error"
                Write-Verbose "[DEBUG] ConfigEditor: Verify ConfigEditor.Mappings.ps1 is properly loaded"
            }

            throw
        }

        # Step 9: Initialize event handler
        # Pass project root into events handler so it can construct file paths without referencing script-scoped variables
        $eventHandler = [ConfigEditorEvents]::new($uiManager, $stateManager, $script:appRoot, $script:isExecutable)

        # Connect event handler to UI manager
        $uiManager.EventHandler = $eventHandler

        # Store UI manager in script scope for access from event handlers
        $script:ConfigEditorForm = $uiManager

        # Register event handlers BEFORE loading data to UI
        # This ensures that events are captured when UI elements are populated
        $eventHandler.RegisterAll()

        # Step 10: Load data to UI
        Write-Verbose "[INFO] ConfigEditor: Loading data to UI"
        try {
            if ($null -eq $uiManager) {
                throw "UIManager is null"
            }
            if ($null -eq $stateManager.ConfigData) {
                throw "ConfigData is null"
            }
            $uiManager.LoadDataToUI($stateManager.ConfigData)

            # Initialize game launcher list
            Write-Verbose "[INFO] ConfigEditor: Initializing game launcher list"
            $uiManager.UpdateGameLauncherList($stateManager.ConfigData)

            Write-Verbose "[OK] ConfigEditor: Data loaded to UI successfully"
        } catch {
            Write-Verbose "[ERROR] ConfigEditor: Failed to load data to UI - $($_.Exception.Message)"
            Write-Verbose "[DEBUG] ConfigEditor: UIManager exists - $($null -ne $uiManager)"
            Write-Verbose "[DEBUG] ConfigEditor: ConfigData exists - $($null -ne $stateManager.ConfigData)"
            throw
        }

        # Mark initialization as complete - event handlers can now process user changes
        $script:IsInitializationComplete = $true
        Write-Verbose "[OK] ConfigEditor: Initialization completed - UI is ready for user interaction"

        # Step 11: Show window
        # Create a local reference to the window object
        $window = $script:Window
        Write-Verbose "[INFO] ConfigEditor: Showing window"
        try {
            if ($Headless) {
                Write-Verbose "[INFO] ConfigEditor: Headless mode enabled - skipping window display"
                # In headless mode, do not show the UI. Initialization verification only.
            } elseif ($DebugMode -and $AutoCloseSeconds -gt 0) {
                Write-Verbose "[DEBUG] ConfigEditor: Window will auto-close in $AutoCloseSeconds seconds"

                # Create a timer to auto-close the window
                $timer = New-Object System.Windows.Threading.DispatcherTimer
                $timer.Interval = [TimeSpan]::FromSeconds($AutoCloseSeconds)
                $timer.Add_Tick({
                        Write-Verbose "[DEBUG] ConfigEditor: Auto-closing window"
                        $window.Close()
                        $timer.Stop()
                    })
                $timer.Start()

                # Show window and wait
                $dialogResult = $window.ShowDialog()
                Write-Verbose "[DEBUG] ConfigEditor: Window closed with result - $dialogResult"
            } elseif ($DebugMode) {
                Write-Verbose "[DEBUG] ConfigEditor: Showing window - Manual close required"
                $dialogResult = $window.ShowDialog()
                Write-Verbose "[DEBUG] ConfigEditor: Window closed with result - $dialogResult"
            } else {
                # Normal mode: Use ShowDialog() which properly handles the window lifecycle
                $dialogResult = $window.ShowDialog()
                Write-Verbose "[DEBUG] ConfigEditor: Window closed with result - $dialogResult"
            }
        } catch {
            Write-Verbose "[DEBUG] ConfigEditor: Window show/close error - $($_.Exception.Message)"
        } finally {
            # Ensure proper cleanup
            if ($uiManager) {
                try {
                    Write-Verbose "[DEBUG] ConfigEditor: Final UI manager cleanup"
                    $uiManager.Cleanup()
                } catch {
                    Write-Verbose "[WARNING] ConfigEditor: Error in final UI manager cleanup - $($_.Exception.Message)"
                }
            }
            if ($window) {
                try {
                    Write-Verbose "[DEBUG] ConfigEditor: Final window cleanup"
                    $window = $null
                } catch {
                    Write-Verbose "[WARNING] ConfigEditor: Error in final window cleanup - $($_.Exception.Message)"
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

        Write-Verbose "[OK] ConfigEditor: Initialization completed"

    } catch {
        Write-Verbose "[ERROR] ConfigEditor: Initialization failed - $($_.Exception.Message)"
        if ($_.InvocationInfo.ScriptName) {
            $relativePath = $_.InvocationInfo.ScriptName -replace [regex]::Escape($script:appRoot), "."
            $relativePath = $relativePath -replace "\\", "/"  # Convert to forward slashes
            Write-Verbose "[ERROR] ConfigEditor: Module - $relativePath"
        } else {
            Write-Verbose "[ERROR] ConfigEditor: Module - <Main Script>"
        }
        Write-Verbose "[ERROR] ConfigEditor: Location - Line $($_.InvocationInfo.ScriptLineNumber)"

        if (-not $Headless) {
            try {
                ("System.Windows.MessageBox" -as [type])::Show(
                    "An initialization error occurred: $($_.Exception.Message)",
                    "Error",
                    "OK",
                    "Error"
                )
            } catch {
                Write-Verbose "[ERROR] ConfigEditor: Failed to show error dialog - $($_.Exception.Message)"
            }
        }
    }
}

# Import additional modules after WPF assemblies are loaded
function Import-AdditionalModules {
    Write-Verbose "[DEBUG] Import-AdditionalModules: FUNCTION ENTERED - appRoot=$script:appRoot"
    try {
        Write-Verbose "[DEBUG] Import-AdditionalModules: Inside try block"
        # Load modules individually with dedicated error handling for each.
        # This makes the loading process more robust, as a failure in one optional
        # module will not prevent others from being loaded.

        # --- Load LanguageHelper.ps1 - Load to GLOBAL scope ---
        try {
            Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing additional module - scripts/LanguageHelper.ps1"
            $languageHelperPath = Join-Path -Path $script:appRoot -ChildPath "scripts/LanguageHelper.ps1"
            Write-Verbose "[DEBUG] ConfigEditor: LanguageHelper.ps1 path: $languageHelperPath"
            Write-Verbose "[DEBUG] ConfigEditor: LanguageHelper.ps1 exists: $(Test-Path $languageHelperPath)"

            if (Test-Path $languageHelperPath) {
                # Load the script content and execute it in the global scope
                $languageHelperScript = Get-Content -Path $languageHelperPath -Raw
                # Replace 'function' with 'function global:' to make functions globally available
                $languageHelperScript = $languageHelperScript -replace '(?m)^(\s*)function\s+([A-Za-z-]+)', '$1function global:$2'
                # Replace '$script:' with '$global:' for variables
                $languageHelperScript = $languageHelperScript -replace '\$script:', '$global:'

                . ([ScriptBlock]::Create($languageHelperScript))
                Write-Verbose "[OK] ConfigEditor: Loaded: LanguageHelper.ps1 with global scope"

                # Verify Write-LocalizedHost function is available and register it
                if (Test-Path function:\Write-LocalizedHost) {
                    Write-Verbose "[OK] ConfigEditor: Write-LocalizedHost function is available globally"
                    $global:WriteLocalizedHostFunc = Get-Command Write-LocalizedHost
                    Write-Verbose "[OK] ConfigEditor: Write-LocalizedHost global reference set"
                } else {
                    Write-Verbose "[WARN] ConfigEditor: Write-LocalizedHost function not found after loading LanguageHelper.ps1"
                }
            } else {
                Write-Warning "[WARN] ConfigEditor: 'scripts/LanguageHelper.ps1' not found at expected path"
            }
        } catch {
            Write-Warning "[WARN] ConfigEditor: Could not load 'scripts/LanguageHelper.ps1'. Some functionality may be affected. Details: $($_.Exception.Message)"
        }

        # --- Load Version.ps1 (for version info) - Load to GLOBAL scope ---
        try {
            Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing additional module - build-tools/Version.ps1"
            $versionPath = Join-Path -Path $script:appRoot -ChildPath "build-tools/Version.ps1"
            Write-Verbose "[DEBUG] ConfigEditor: Version.ps1 path: $versionPath"
            Write-Verbose "[DEBUG] ConfigEditor: Version.ps1 exists: $(Test-Path $versionPath)"

            if (Test-Path $versionPath) {
                # Load the script content and execute it in the global scope
                $versionScript = Get-Content -Path $versionPath -Raw
                # Replace 'function' with 'function global:' to make functions globally available
                $versionScript = $versionScript -replace '(?m)^(\s*)function\s+([A-Za-z-]+)', '$1function global:$2'
                # Replace '$script:' with '$global:' for variables
                $versionScript = $versionScript -replace '\$script:', '$global:'

                . ([ScriptBlock]::Create($versionScript))
                Write-Verbose "[OK] ConfigEditor: Loaded: Version.ps1 with global scope"

                # Verify functions are available
                if (Test-Path function:\Get-ProjectVersion) {
                    Write-Verbose "[OK] ConfigEditor: Get-ProjectVersion function is available globally"
                    $global:GetProjectVersionFunc = { param($IncludePreRelease)
                        if ($IncludePreRelease) {
                            Get-ProjectVersion -IncludePreRelease
                        } else {
                            Get-ProjectVersion
                        }
                    }
                    Write-Verbose "[OK] ConfigEditor: Get-ProjectVersion global reference set"
                } else {
                    Write-Verbose "[WARN] ConfigEditor: Get-ProjectVersion function not found after loading Version.ps1"
                }
            } else {
                Write-Verbose "[WARN] ConfigEditor: Version.ps1 not found at: $versionPath"
            }
        } catch {
            Write-Verbose "[WARN] ConfigEditor: Could not load 'build-tools/Version.ps1'. Version info will be unavailable. Details: $($_.Exception.Message)"
        }

        # --- Load UpdateChecker.ps1 (for update checks) - Load to GLOBAL scope ---
        try {
            Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing additional module - src/modules/UpdateChecker.ps1"
            $updateCheckerPath = Join-Path -Path $script:appRoot -ChildPath "src/modules/UpdateChecker.ps1"
            Write-Verbose "[DEBUG] ConfigEditor: UpdateChecker.ps1 path: $updateCheckerPath"
            Write-Verbose "[DEBUG] ConfigEditor: UpdateChecker.ps1 exists: $(Test-Path $updateCheckerPath)"

            if (Test-Path $updateCheckerPath) {
                # Load the script content and execute it in the global scope
                $updateCheckerScript = Get-Content -Path $updateCheckerPath -Raw
                # Replace 'function' with 'function global:' to make functions globally available
                $updateCheckerScript = $updateCheckerScript -replace '(?m)^(\s*)function\s+([A-Za-z-]+)', '$1function global:$2'
                # Replace '$script:' with '$global:' for variables
                $updateCheckerScript = $updateCheckerScript -replace '\$script:', '$global:'

                . ([ScriptBlock]::Create($updateCheckerScript))
                Write-Verbose "[OK] ConfigEditor: Loaded: UpdateChecker.ps1 with global scope"

                # Verify functions are available
                if (Test-Path function:\Test-UpdateAvailable) {
                    Write-Verbose "[OK] ConfigEditor: Test-UpdateAvailable function is available globally"
                    $global:TestUpdateAvailableFunc = {
                        Test-UpdateAvailable
                    }
                    Write-Verbose "[OK] ConfigEditor: Test-UpdateAvailable global reference set"
                } else {
                    Write-Verbose "[WARN] ConfigEditor: Test-UpdateAvailable function not found after loading UpdateChecker.ps1"
                }
            } else {
                Write-Verbose "[WARN] ConfigEditor: UpdateChecker.ps1 not found at: $updateCheckerPath"
            }
        } catch {
            Write-Verbose "[WARN] ConfigEditor: Could not load 'src/modules/UpdateChecker.ps1'. Update checks will be disabled. Details: $($_.Exception.Message)"
        }

        # --- Load WebSocketAppManagerBase.ps1 (for VTube Studio integration) ---
        try {
            Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing additional module - src/modules/WebSocketAppManagerBase.ps1"
            $websocketBasePath = Join-Path -Path $script:appRoot -ChildPath "src/modules/WebSocketAppManagerBase.ps1"
            Write-Verbose "[DEBUG] ConfigEditor: WebSocketAppManagerBase.ps1 path: $websocketBasePath"
            Write-Verbose "[DEBUG] ConfigEditor: WebSocketAppManagerBase.ps1 exists: $(Test-Path $websocketBasePath)"

            if (Test-Path $websocketBasePath) {
                # Load the module normally (classes and functions)
                . $websocketBasePath
                Write-Verbose "[OK] ConfigEditor: Loaded: WebSocketAppManagerBase.ps1"

                # Explicitly register the function in global scope
                if (Test-Path function:\New-WebSocketAppManagerBase) {
                    $global:NewWebSocketAppManagerBaseFunc = Get-Command New-WebSocketAppManagerBase
                    Write-Verbose "[OK] ConfigEditor: New-WebSocketAppManagerBase function registered globally"
                } else {
                    Write-Verbose "[WARN] ConfigEditor: New-WebSocketAppManagerBase function not found after loading WebSocketAppManagerBase.ps1"
                }
            } else {
                Write-Verbose "[WARN] ConfigEditor: WebSocketAppManagerBase.ps1 not found at: $websocketBasePath"
            }
        } catch {
            Write-Warning "[WARN] ConfigEditor: Could not load 'src/modules/WebSocketAppManagerBase.ps1'. VTube Studio integration may be affected. Details: $($_.Exception.Message)"
        }

        # --- Load VTubeStudioManager.ps1 (for VTube Studio integration) ---
        try {
            Write-Verbose "[DEBUG] ConfigEditor: Dot-sourcing additional module - src/modules/VTubeStudioManager.ps1"
            $vtubeManagerPath = Join-Path -Path $script:appRoot -ChildPath "src/modules/VTubeStudioManager.ps1"
            Write-Verbose "[DEBUG] ConfigEditor: VTubeStudioManager.ps1 path: $vtubeManagerPath"
            Write-Verbose "[DEBUG] ConfigEditor: VTubeStudioManager.ps1 exists: $(Test-Path $vtubeManagerPath)"

            if (Test-Path $vtubeManagerPath) {
                # Load the module normally (classes and functions)
                . $vtubeManagerPath
                Write-Verbose "[OK] ConfigEditor: Loaded: VTubeStudioManager.ps1"

                # Explicitly register the function in global scope
                if (Test-Path function:\New-VTubeStudioManager) {
                    $global:NewVTubeStudioManagerFunc = Get-Command New-VTubeStudioManager
                    Write-Verbose "[OK] ConfigEditor: New-VTubeStudioManager function registered globally"
                } else {
                    Write-Verbose "[WARN] ConfigEditor: New-VTubeStudioManager function not found after loading VTubeStudioManager.ps1"
                }
            } else {
                Write-Verbose "[WARN] ConfigEditor: VTubeStudioManager.ps1 not found at: $vtubeManagerPath"
            }
        } catch {
            Write-Warning "[WARN] ConfigEditor: Could not load 'src/modules/VTubeStudioManager.ps1'. VTube Studio integration will be disabled. Details: $($_.Exception.Message)"
        }
    } catch {
        Write-Verbose "[WARNING] ConfigEditor: Failed to import additional modules - $($_.Exception.Message)"
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
                        param($s, $e)
                        # Skip if updating panel
                        if (& $updatingFlag) {
                            return
                        }
                        $stateManager.SetModified()
                    }.GetNewClosure())

                $checkbox.add_Unchecked({
                        param($s, $e)
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
            $steamAppIdTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::LightGray
        }
        if ($epicGameIdTextBox) {
            $epicGameIdTextBox.IsEnabled = $false
            $epicGameIdTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::LightGray
        }
        if ($riotGameIdTextBox) {
            $riotGameIdTextBox.IsEnabled = $false
            $riotGameIdTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::LightGray
        }
        if ($executablePathTextBox) {
            $executablePathTextBox.IsEnabled = $false
            $executablePathTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::LightGray
        }
        if ($browseExecutablePathButton) {
            $browseExecutablePathButton.IsEnabled = $false
        }

        # Enable the appropriate field based on platform and clear others
        switch ($Platform) {
            "steam" {
                if ($steamAppIdTextBox) {
                    $steamAppIdTextBox.IsEnabled = $true
                    $steamAppIdTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::White
                }
                if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
                if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
                if ($executablePathTextBox) { $executablePathTextBox.Text = "" }
                Write-Verbose "  Enabled Steam AppID field"
            }
            "epic" {
                if ($epicGameIdTextBox) {
                    $epicGameIdTextBox.IsEnabled = $true
                    $epicGameIdTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::White
                }
                if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
                if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }
                if ($executablePathTextBox) { $executablePathTextBox.Text = "" }
                Write-Verbose "  Enabled Epic GameID field"
            }
            "riot" {
                if ($riotGameIdTextBox) {
                    $riotGameIdTextBox.IsEnabled = $true
                    $riotGameIdTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::White
                }
                if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }
                if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }
                if ($executablePathTextBox) { $executablePathTextBox.Text = "" }
                Write-Verbose "  Enabled Riot GameID field"
            }
            "standalone" {
                if ($executablePathTextBox) {
                    $executablePathTextBox.IsEnabled = $true
                    $executablePathTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::White
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
                    $executablePathTextBox.Background = ("System.Windows.Media.Brushes" -as [type])::White
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
        $result = ("System.Windows.MessageBox" -as [type])::Show(
            $message,
            $title,
            "YesNo",
            "Question"
        )

        if ("$result" -eq "Yes") {
            # Update UIManager.CurrentLanguage to the new language code
            # This ensures the language change is properly tracked
            if ($script:ConfigEditorForm) {
                $newLanguageCode = $script:Window.FindName("LanguageCombo").SelectedItem.Tag
                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Updating UIManager.CurrentLanguage from '$($script:ConfigEditorForm.CurrentLanguage)' to '$newLanguageCode'"
                $script:ConfigEditorForm.CurrentLanguage = $newLanguageCode
            }

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

                $continueResult = ("System.Windows.MessageBox" -as [type])::Show(
                    "$errorMessage`n`n$continueMessage",
                    $errorTitle,
                    "YesNo",
                    "Warning"
                )

                if ($continueResult -ne ("System.Windows.MessageBoxResult" -as [type])::Yes) {
                    Write-Verbose "User cancelled restart due to save error"
                    return
                }
            }

            Write-Verbose "[ERROR] ConfigEditor: Restarting application to apply language changes"

            # Determine execution context and prepare restart command
            if ($script:isExecutable) {
                # In executable mode: restart the .exe directly
                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Executable mode detected"

                $currentProcess = Get-Process -Id $PID
                $executablePath = $currentProcess.Path

                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Executable path: $executablePath"

                # Start new instance with proper process configuration
                $startInfo = New-Object System.Diagnostics.ProcessStartInfo
                $startInfo.FileName = $executablePath
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $false

                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Starting new ConfigEditor instance (executable mode)"
                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Command: $($startInfo.FileName)"

                try {
                    $newProcess = [System.Diagnostics.Process]::Start($startInfo)
                    if ($newProcess) {
                        Write-Verbose "[OK] ConfigEditor: New instance started successfully - PID: $($newProcess.Id)"
                        Write-Verbose "[OK] ConfigEditor: New instance started successfully - PID: $($newProcess.Id)"
                    } else {
                        Write-Verbose "[ERROR] ConfigEditor: Process.Start returned null"
                        throw "Process.Start returned null"
                    }
                } catch {
                    Write-Verbose "[ERROR] ConfigEditor: Failed to start new instance (executable mode) - $($_.Exception.Message)"
                    Write-Verbose "[DEBUG] ConfigEditor: Exception Type - $($_.Exception.GetType().Name)"

                    # Try alternative method: Use Start-Process cmdlet
                    Write-Verbose "[INFO] ConfigEditor: Attempting alternative restart method using Start-Process"
                    try {
                        Start-Process -FilePath $executablePath -WindowStyle Normal -ErrorAction Stop
                        Write-Verbose "[OK] ConfigEditor: Alternative restart method succeeded"
                    } catch {
                        Write-Verbose "[ERROR] ConfigEditor: Alternative restart method also failed - $($_.Exception.Message)"
                        Write-Verbose "[ERROR] ConfigEditor: Unable to restart application. User must restart manually."

                        # Show error dialog to user
                        $errorMsg = "Failed to restart the configuration editor automatically. Please restart the application manually to apply language changes."
                        $errorTitle = "Restart Failed"
                        ("System.Windows.MessageBox" -as [type])::Show($errorMsg, $errorTitle, "OK", "Error") | Out-Null

                        return
                    }
                }
            } else {
                # In script mode: restart via PowerShell
                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Script mode detected"

                # Get the current script path
                $currentScript = $PSCommandPath
                if (-not $currentScript) {
                    $currentScript = Join-Path -Path $script:appRoot -ChildPath "gui/ConfigEditor.ps1"
                }

                # Start new instance with proper process configuration
                $startInfo = New-Object System.Diagnostics.ProcessStartInfo
                $startInfo.FileName = "powershell.exe"
                $startInfo.Arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"& { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '$currentScript' }`""
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $false
                # Note: StandardOutputEncoding is only valid when UseShellExecute = $true or RedirectStandardOutput = $true
                # For UI applications, we don't need it since we're not capturing output

                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Starting new ConfigEditor instance (script mode)"
                Write-Verbose "[DEBUG] Show-LanguageChangeRestartMessage: Command: $($startInfo.FileName) $($startInfo.Arguments)"

                try {
                    $newProcess = [System.Diagnostics.Process]::Start($startInfo)
                    if ($newProcess) {
                        Write-Verbose "[OK] ConfigEditor: New instance started successfully - PID: $($newProcess.Id)"
                        Write-Verbose "[OK] ConfigEditor: New instance started successfully - PID: $($newProcess.Id)"
                    } else {
                        Write-Verbose "[ERROR] ConfigEditor: Process.Start returned null"
                        throw "Process.Start returned null"
                    }
                } catch {
                    Write-Verbose "[ERROR] ConfigEditor: Failed to start new instance (script mode) with ProcessStartInfo"
                    Write-Verbose "[DEBUG] ConfigEditor: Exception - $($_.Exception.Message)"
                    Write-Verbose "[DEBUG] ConfigEditor: Exception Type - $($_.Exception.GetType().Name)"

                    # Try alternative method: Use Start-Process cmdlet instead
                    Write-Verbose "[INFO] ConfigEditor: Attempting alternative restart method using Start-Process"
                    try {
                        Start-Process -FilePath "powershell.exe" `
                            -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"& { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '$currentScript' }`"" `
                            -WindowStyle Normal `
                            -ErrorAction Stop
                        Write-Verbose "[OK] ConfigEditor: Alternative restart method succeeded"
                    } catch {
                        Write-Verbose "[ERROR] ConfigEditor: Alternative restart method also failed - $($_.Exception.Message)"
                        Write-Verbose "[ERROR] ConfigEditor: Unable to restart application. User must restart manually."

                        # Show error dialog to user
                        $errorMsg = "Failed to restart the configuration editor automatically. Please restart the application manually to apply language changes."
                        $errorTitle = "Restart Failed"
                        ("System.Windows.MessageBox" -as [type])::Show($errorMsg, $errorTitle, "OK", "Error") | Out-Null

                        return
                    }
                }
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
                $applicationType = "System.Windows.Application" -as [type]
                $applicationType::Current.Shutdown()
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
        # Prefer ConfigEditorForm.localization when available (older codepath)
        if ($script:ConfigEditorForm -and $script:ConfigEditorForm.localization) {
            return $script:ConfigEditorForm.localization.GetMessage($Key, $FormatArgs)
        }

        # If the ConfigEditorForm exposes a Messages hashtable, use it (ConfigEditorUI stores Messages)
        if ($script:ConfigEditorForm -and $script:ConfigEditorForm.Messages) {
            try {
                $msgs = $script:ConfigEditorForm.Messages
                if ($msgs.PSObject.Properties[$Key]) {
                    $msg = $msgs.$Key
                    if ($FormatArgs -and $FormatArgs.Count -gt 0) { return $msg -f $FormatArgs }
                    return $msg
                }
            } catch {
                # fallthrough to other sources
            }
        }

        # Localization singleton created during initialization
        if ($script:Localization) {
            return $script:Localization.GetMessage($Key, $FormatArgs)
        }

        # Fallback to UIManager helper method
        if ($script:UIManager) {
            $message = $script:UIManager.GetLocalizedMessage($Key)
            if ($FormatArgs -and $FormatArgs.Count -gt 0) {
                return $message -f $FormatArgs
            }
            return $message
        }

        Write-Warning "Localization not available, using key as message: $Key"
        return $Key
    } catch {
        Write-Warning "Failed to get localized message for key '$Key': $($_.Exception.Message)"
        return $Key
    }
}

<#
.SYNOPSIS
Shows a localized message dialog.

.DESCRIPTION
Displays a message box using localized messages from the messages.json file.
Supports multiple parameter styles for backward compatibility.

.PARAMETER Key
Message key for localization (new style).

.PARAMETER MessageType
Type of message: Information, Warning, Error, Question (new style).

.PARAMETER FormatArgs
Arguments for string formatting (new style).

.PARAMETER Button
Button type (e.g., "YesNo", "YesNoCancel").

.PARAMETER DefaultResult
Default button result.

.PARAMETER Message
Direct message text (alternative style).

.PARAMETER MessageKey
Message key (old style, for compatibility).

.PARAMETER TitleKey
Title key (old style, for compatibility).

.PARAMETER Arguments
Format arguments (old style, for compatibility).

.PARAMETER Icon
Icon type (old style, for compatibility).

.OUTPUTS
System.Windows.MessageBoxResult
Returns MessageBoxResult if button is specified, otherwise void.
#>
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
            # Try multiple sources in order of preference
            if ($script:ConfigEditorForm -and $script:ConfigEditorForm.localization) {
                $messageText = $script:ConfigEditorForm.localization.GetMessage($Key, $FormatArgs)
            } elseif ($script:ConfigEditorForm -and $script:ConfigEditorForm.Messages) {
                try {
                    $msgs = $script:ConfigEditorForm.Messages
                    if ($msgs.PSObject.Properties[$Key]) {
                        $messageText = $msgs.$Key
                        if ($FormatArgs -and $FormatArgs.Count -gt 0) { $messageText = $messageText -f $FormatArgs }
                    } else {
                        $messageText = $Key
                    }
                } catch {
                    $messageText = $Key
                }
            } elseif ($script:Localization) {
                $messageText = $script:Localization.GetMessage($Key, $FormatArgs)
            } elseif ($script:UIManager -and $script:UIManager.localization) {
                $messageText = $script:UIManager.localization.GetMessage($Key, $FormatArgs)
            } else {
                Write-Warning "Localization not available, using key as message: $Key"
                $messageText = $Key
            }
        }

        # Get localized title (same lookup order)
        if ($script:ConfigEditorForm -and $script:ConfigEditorForm.localization) {
            $titleText = $script:ConfigEditorForm.localization.GetMessage($titleKeyToUse, @())
        } elseif ($script:ConfigEditorForm -and $script:ConfigEditorForm.Messages -and $script:ConfigEditorForm.Messages.PSObject.Properties[$titleKeyToUse]) {
            $titleText = $script:ConfigEditorForm.Messages.$titleKeyToUse
        } elseif ($script:Localization) {
            $titleText = $script:Localization.GetMessage($titleKeyToUse, @())
        } elseif ($script:UIManager -and $script:UIManager.localization) {
            $titleText = $script:UIManager.localization.GetMessage($titleKeyToUse, @())
        } else {
            $titleText = $titleKeyToUse
        }

        # Map MessageType to icon
        $iconType = switch ($MessageType) {
            "Information" { ("System.Windows.MessageBoxImage" -as [type])::Information }
            "Warning" { ("System.Windows.MessageBoxImage" -as [type])::Warning }
            "Error" { ("System.Windows.MessageBoxImage" -as [type])::Error }
            "Question" { ("System.Windows.MessageBoxImage" -as [type])::Question }
            default { ("System.Windows.MessageBoxImage" -as [type])::Information }
        }

        # Map Button string to MessageBoxButton
        $buttonType = switch ($Button) {
            "OK" { ("System.Windows.MessageBoxButton" -as [type])::OK }
            "OKCancel" { ("System.Windows.MessageBoxButton" -as [type])::OKCancel }
            "YesNo" { ("System.Windows.MessageBoxButton" -as [type])::YesNo }
            "YesNoCancel" { ("System.Windows.MessageBoxButton" -as [type])::YesNoCancel }
            default { ("System.Windows.MessageBoxButton" -as [type])::OK }
        }

        # Map DefaultResult to MessageBoxResult
        $defaultResultType = switch ($DefaultResult) {
            "OK" { ("System.Windows.MessageBoxResult" -as [type])::OK }
            "Cancel" { ("System.Windows.MessageBoxResult" -as [type])::Cancel }
            "Yes" { ("System.Windows.MessageBoxResult" -as [type])::Yes }
            "No" { ("System.Windows.MessageBoxResult" -as [type])::No }
            default { ("System.Windows.MessageBoxResult" -as [type])::OK }
        }

        # If running in headless mode, print to console and return the default result
        if ($script:Headless) {
            Write-Verbose "[$MessageType] $titleText : $messageText"
            return $defaultResultType
        }

        # Show message box
        return ("System.Windows.MessageBox" -as [type])::Show($messageText, $titleText, $buttonType, $iconType, $defaultResultType)

    } catch {
        Write-Warning "Show-SafeMessage failed: $($_.Exception.Message)"
        # Fallback to simple message box
        return ("System.Windows.MessageBox" -as [type])::Show($Key, "Message", "OK", "Information")
    }
}

<#
.SYNOPSIS
Generates a unique ID for configuration items.

.DESCRIPTION
Creates a unique identifier with the specified prefix, ensuring no collision
with existing items in the provided collection. Uses random number generation
with collision detection for uniqueness.

.PARAMETER Collection
The collection to check for existing IDs.

.PARAMETER Prefix
The prefix for the new ID (default: "new").

.PARAMETER MinRandom
Minimum random number (default: 1000).

.PARAMETER MaxRandom
Maximum random number (default: 9999).

.OUTPUTS
String
Returns a unique identifier.
#>
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

<#
.SYNOPSIS
Validates the selected item for duplication operations.

.DESCRIPTION
Checks if an item is selected and if its source data exists in the configuration.
Returns validation result and displays appropriate error messages.

.PARAMETER SelectedItem
The ID of the selected item.

.PARAMETER SourceData
The source data object.

.PARAMETER ItemType
The type of item ("Game" or "App").

.OUTPUTS
Boolean
Returns true if validation passes, false otherwise.
#>
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

<#
.SYNOPSIS
Shows duplication result messages.

.DESCRIPTION
Displays success or error messages for duplication operations with proper
localization and error handling.

.PARAMETER OriginalId
The ID of the original item.

.PARAMETER NewId
The ID of the new duplicated item.

.PARAMETER ItemType
The type of item ("Game" or "App").

.PARAMETER Success
Whether the duplication was successful.

.PARAMETER ErrorMessage
Optional error message if duplication failed.
#>
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
    Write-Verbose ""
    Write-Verbose "[INFO] ConfigEditor: Debug Mode Usage"
    Write-Verbose ""
    Write-Verbose "Start with debug mode (manual close):"
    Write-Verbose "  gui\ConfigEditor.ps1 -DebugMode"
    Write-Verbose ""
    Write-Verbose "Start with auto-close (3 seconds):"
    Write-Verbose "  gui\ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 3"
    Write-Verbose ""
    Write-Verbose "Start with auto-close (10 seconds):"
    Write-Verbose "  gui\ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 10"
    Write-Verbose ""
    Write-Verbose "Normal mode (no debug output):"
    Write-Verbose "  gui\ConfigEditor.ps1"
    Write-Verbose ""
    Write-Verbose "Show this help:"
    Write-Verbose "  gui\ConfigEditor.ps1 -NoAutoStart"
    Write-Verbose "  Then call: Show-DebugHelp"
    Write-Verbose ""
}

# Start the application
if (-not $NoAutoStart) {
    if (Test-Prerequisites) {
        Initialize-ConfigEditor
    } else {
        Write-Verbose "[ERROR] ConfigEditor: Cannot start due to missing prerequisites"
        exit 1
    }
}
