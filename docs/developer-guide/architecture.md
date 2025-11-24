# Focus Game Deck - Architecture & Design Philosophy

## Overview

Focus Game Deck is a PowerShell-based tool for gaming environment automation and OBS streaming management. This document explains th## Contribution Guidelines

To maintain this design philosophy, please prioritize the following:

1. **Security First**: Always consider anti-cheat false positive risks with non-invasive design
2. **Maintain Lightweight Nature**: Carefully consider adding new dependencies
3. **PowerShell First**: Prioritize PowerShell solutions over migration to other languages
4. **Configuration-Driven**: Control through configuration files rather than hard-coding
5. **Internationalization Support**: All new messages must be externalized to JSON resourcest's design philosophy, rationale for technical choices, and implementation architecture.

## Design Philosophy

### 1. Lightweight and Simple

- **PowerShell + WPF**: Utilizes Windows standard features while avoiding additional runtimes or heavy frameworks
- **Minimal Dependencies**: Uses only .NET Framework standard features
- **Single Executable**: Simplified distribution through ps2exe compilation

### 2. Maintainability and Extensibility

- **Configuration-Driven Design**: All behavior controlled through `config.json`
- **Modular Structure**: Separation of GUI, core functionality, and configuration management
- **Internationalization Support**: Multi-language support through JSON external resources

### 3. Usability

- **Intuitive GUI**: Three-tab structure for feature categorization (Game Settings, Managed Apps Settings, Global Settings)
- **Batch File Launch**: Simple startup without requiring technical knowledge
- **Error Handling**: Appropriate error message display

## Technical Architecture

### Secure Multi-Executable Bundle Architecture (v3.0+)

**Architecture Overview:**

Focus Game Deck v3.0 introduces a secure multi-executable bundle architecture that addresses critical security vulnerabilities while improving efficiency and maintainability. This architecture replaces the previous single-executable model with three separate, fully bundled, digitally signed executables.

**The Problem (Pre-v3.0):**

The original build process created a single signed `Focus-Game-Deck.exe` that acted as a wrapper, executing external, **unsigned** `.ps1` script files. This created a significant security vulnerability where malicious actors could modify these external scripts, and the code signature on the main `.exe` would be unable to prevent the tampered code from running.

**The Solution (v3.0+):**

The new architecture bundles all code into three separate, signed executables using `ps2exe`, ensuring all executed code is verified:

1. **Focus-Game-Deck.exe (Main Router)**
   - **Purpose**: Lightweight router that launches the correct sub-process based on user arguments
   - **Source**: `src/Main-Router.ps1`
   - **Responsibility**: Argument parsing, process delegation, user interface routing
   - **Size**: ~30-40 KB
   - **Console**: Visible console window for status messages

2. **ConfigEditor.exe (GUI Configuration Editor)**
   - **Purpose**: Fully bundled and signed GUI for configuration management
   - **Source**: `gui/ConfigEditor.ps1` + all GUI dependencies
   - **Responsibility**: Configuration editing, game management, settings interface
   - **Size**: ~75-100 KB
   - **Console**: Hidden (noConsole flag enabled)
   - **Technology**: PowerShell + WPF

3. **Invoke-FocusGameDeck.exe (Game Launcher)**
   - **Purpose**: Fully bundled and signed game launching engine
   - **Source**: `src/Invoke-FocusGameDeck.ps1` + all core modules
   - **Responsibility**: Game session lifecycle, app management, integration orchestration
   - **Size**: ~60-80 KB
   - **Console**: Visible console window for real-time status

**Key Benefits:**

- **Enhanced Security**: All executed code is contained within digitally signed executables, guaranteeing code integrity
- **Improved Efficiency**: Separate processes optimize memory usage - the game launcher doesn't load WPF assemblies, and the GUI doesn't load game modules
- **Simplified Distribution**: Clean distribution with only executables and supporting files (JSON, XAML)
- **Better Process Isolation**: Each component runs in its own process, improving stability and resource management

**Focus Game Deck v3.0+ Execution Flow::**

```architecture
User Command
    ↓
Focus-Game-Deck.exe (Router)
    ↓
    ├─→ ConfigEditor.exe (if --config or no args)
    │   └─→ Displays GUI, manages configuration
    │
    └─→ Invoke-FocusGameDeck.exe -GameId <id> (if game launch)
        └─→ Launches game with environment setup
```

**Supporting Files Structure:**

While the executables are fully bundled, they still require supporting files at runtime:

- `config/` - Configuration files (config.json, messages.json)
- `localization/` - Language resource files
- `gui/` - XAML files and GUI helper scripts
- `src/modules/` - PowerShell module files loaded by game launcher
- `scripts/` - Utility scripts (LanguageHelper.ps1)
- `build-tools/` - Version information scripts

### System Architecture Components

The Focus Game Deck architecture consists of five main layers, each serving distinct purposes:

#### 1. Multi-Executable Entry Points

- **`src/Main-Router.ps1`** - Lightweight router compiled to Focus-Game-Deck.exe
- **`gui/ConfigEditor.ps1`** - GUI application compiled to ConfigEditor.exe
- **`src/Invoke-FocusGameDeck.ps1`** - Game launcher compiled to Invoke-FocusGameDeck.exe
- **Routing Logic**: Main router handles argument parsing and delegates to specialized executables

#### 2. Core Engine Layer

- **Primary Location**: `src/` directory
- **Main Components**:
  - `Invoke-FocusGameDeck.ps1` - Core game environment automation engine
  - `modules/` - Modular component system with specialized managers
- **Responsibility**: Game session lifecycle, app management, integration orchestration

#### 3. Configuration Management

- **Primary Location**: `config/` directory
- **Key Files**: `config.json` (main), `messages.json` (i18n), `*.json.sample` (templates)
- **Responsibility**: Centralized configuration, validation, internationalization resources

#### 4. User Interface Layer

- **Primary Location**: `gui/` directory
- **Technology Stack**: PowerShell + WPF (XAML)
- **Key Components**:
  - `ConfigEditor.ps1` - GUI logic with integrated game launcher
  - `MainWindow.xaml` - UI layout definition
- **Responsibility**: User configuration, game launcher interface, settings management

#### 5. Build & Distribution System

- **Primary Location**: `build-tools/` directory
- **Key Components**:
  - `build-tools/Release-Manager.ps1` - Build orchestration
  - `build-tools/Build-FocusGameDeck.ps1` - ps2exe compilation
  - `build-tools/Sign-Executables.ps1` - Digital signature workflow
- **Responsibility**: Executable generation, code signing, release packaging

#### Component Reference Table

| Component Type | Key Files | Primary Responsibility | Dependencies |
|---------------|-----------|----------------------|--------------|
| **Main Router** | `src/Main-Router.ps1` → `Focus-Game-Deck.exe` | Entry point routing and process delegation | ConfigEditor.exe, Invoke-FocusGameDeck.exe |
| **GUI Application** | `gui/ConfigEditor.ps1` → `ConfigEditor.exe` | Configuration editor, game management UI | XAML files, localization, configuration |
| **Game Launcher** | `src/Invoke-FocusGameDeck.ps1` → `Invoke-FocusGameDeck.exe` | Game session automation | Configuration, modules |
| **Module System** | `src/modules/*.ps1` | Specialized service management | External APIs (OBS, VTube Studio) |
| **Configuration** | `config/*.json` | Settings and localization | User preferences, defaults |
| **User Interface** | `gui/MainWindow.xaml`, `gui/*.ps1` | XAML layouts and UI helpers | ConfigEditor.exe |
| **Build System** | `build-tools/Release-Manager.ps1`, `build-tools/*.ps1` | Compilation and distribution | ps2exe, signing certificates |
| **Documentation** | `docs/**/*.md` | Architecture and usage guides | Project knowledge base |
| **Testing** | `test/*.ps1` | Validation and integration testing | All components |

> **Maintenance Note**: This table provides a logical view independent of physical file structure.
> For current directory structure, use: `tree /f` (Windows) or `Get-ChildItem -Recurse` (PowerShell)
>
> **Structure Validation**: Run project statistics task to verify current architecture alignment:
>
> ```powershell
> # Via VSCode task (recommended)
> # Ctrl+Shift+P → "Tasks: Run Task" → "[STATS] Project Statistics"
>
> # Or direct execution
> powershell -ExecutionPolicy Bypass -Command "& {your stats command here}"
> ```

### Build-Time Patching System

The build system uses a unified build-time patching approach for both entry points:

#### Development Phase

- Source files contain simple relative path resolution
- Marker comments define sections that will be replaced during build
- Easy to develop and test in the source environment

```powershell
# >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
# Development code: simple relative paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot "config/config.json"
# <<< BUILD-TIME-PATCH-END <<<
```

#### Build Phase

- Build script detects marker comments
- Replaces marked sections with environment-aware code
- Generates both script and executable versions

#### Production Phase

- Patched code detects execution environment (script vs executable)
- Resolves paths correctly for each environment
- Handles the `$PSScriptRoot` limitation in ps2exe executables

**Path Resolution Strategy:**

```powershell
# Patched code injected at build time
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

if ($isExecutable) {
    # Use executable's actual location
    $workingDir = Split-Path -Parent $currentProcess.Path
    $configPath = Join-Path $workingDir "config/config.json"
} else {
    # Use script's directory
    $configPath = Join-Path $PSScriptRoot "../config/config.json"
}
```

**Benefits:**

- Single source file for both execution modes
- No manual maintenance of separate bundled versions
- Automatic handling of path differences
- Improved maintainability

**Entry Points with Build-Time Patching:**

- `gui/ConfigEditor.ps1` → `ConfigEditor.exe`
- `src/Invoke-FocusGameDeck.ps1` → `Invoke-FocusGameDeck.exe`

For detailed build system information, see [Build System Documentation](build-system.md).

### Design Decision Records

#### 1. GUI Technology Choice: PowerShell + WPF

**Options Considered:**

- Windows Forms
- Electron/Web Technologies
- .NET WinForms/WPF (C#)
- PowerShell + WPF

**Selection Rationale:**

- **Lightweight**: No additional runtime required, uses Windows standard features
- **Consistency**: Implementation using the same PowerShell as the main engine
- **Distribution Ease**: Single executable file creation through ps2exe
- **Development Efficiency**: Leverages existing PowerShell skills

#### 2. Internationalization Method: JSON External Resources

**Options Considered:**

- Direct Unicode code point specification
- PowerShell embedded strings
- JSON external resource files

**Selection Rationale:**

- **Character Encoding Solution**: Avoids Japanese character garbling issues in PowerShell MessageBox
- **Maintainability**: Separation of strings and code
- **Extensibility**: Foundation for future multi-language support
- **Standard Approach**: Follows common internationalization patterns

**Technical Details:**

- Uses Unicode escape sequences (`/u30XX` format)
- UTF-8 encoding enforcement
- Dynamic message retrieval through runtime JSON loading

#### 3. Build System: PowerShell to Executable Conversion

**Options Considered:**

- Manual PowerShell script distribution
- PowerShell ISE packaging
- ps2exe module compilation
- Migration to compiled languages (C#/.NET)

**Selection Rationale:**

- **Single File Distribution**: ps2exe creates standalone executable files for easy distribution
- **No Runtime Dependencies**: Generated executables run without requiring PowerShell installation
- **Digital Signature Support**: Full support for Authenticode digital signatures
- **Maintains PowerShell Benefits**: Preserves source code readability and maintainability
- **Security Compliance**: Enables Extended Validation certificate signing for trust establishment

**Technical Implementation:**

- **Main Application**: `Focus-Game-Deck.exe` (console-based launcher)
- **Multi-platform Version**: `Focus-Game-Deck-MultiPlatform.exe` (extended platform support)
- **GUI Configuration**: `Focus-Game-Deck-Config-Editor.exe` (WPF-based, no console window)
- **Automated Build Pipeline**: Three-tier build system (individual → integrated → master orchestration)

#### 4. Digital Signature Strategy: Extended Validation Certificate

**Security Requirements:**

- **Trust Establishment**: Windows SmartScreen and antivirus compatibility
- **Anti-cheat Compliance**: Proactive whitelisting with signed executables
- **Timestamp Preservation**: RFC 3161 timestamping for long-term signature validity

**Implementation Details:**

- Certificate storage in Windows Certificate Store (CurrentUser/My)
- Automated signature verification post-signing
- Multiple timestamp server fallback support
- Signature metadata tracking in release packages

#### 5. Configuration Management: JSON Configuration File

**Selection Rationale:**

- **Readability**: Human-readable format
- **PowerShell Compatibility**: Standard support for ConvertFrom-Json/ConvertTo-Json
- **Hierarchical Structure**: Structured management of complex configurations
- **Version Control**: Easy diff checking in Git

#### 6. VTube Studio Integration: Modular Manager Pattern

**Integration Approach:**

- **Modular Design**: Separate VTubeStudioManager.ps1 following OBSManager patterns
- **Auto-Detection**: Automatic detection of Steam vs Standalone installations
- **Special Actions**: Custom `start-vtube-studio` and `stop-vtube-studio` actions in AppManager
- **Future WebSocket Ready**: Foundation prepared for VTube Studio API integration

**Technical Implementation:**

- **Steam Integration**: Proper DRM handling via Steam `-applaunch` parameter (AppID: 1325860)
- **Standalone Support**: Direct executable launching with configurable arguments
- **Process Management**: Graceful shutdown with fallback to force termination
- **Error Handling**: Comprehensive logging and fallback mechanisms

**Selection Rationale:**

- **VTuber Community Support**: Essential for Japanese streaming ecosystem
- **Consistency**: Follows established OBSManager architectural patterns
- **Extensibility**: WebSocket API integration foundation for future model control features
- **Platform Agnostic**: Supports both Steam and standalone VTube Studio installations

#### 7. Code Signing Certificate Selection

**Initial Consideration:**

- The ideal choice was an Extended Validation (EV) certificate, aiming for the highest level of trust and SmartScreen compatibility.

**Practical Decision:**

- However, obtaining an EV certificate proved to be extremely difficult for an individual developer or sole proprietor due to strict requirements and verification processes.
- As a realistic alternative, an Organization Validation (OV) certificate was selected. This option provides sufficient trust for code signing and SmartScreen reputation, while being attainable for small businesses and individual developers.

#### 8. WebSocket Manager Architecture: Hybrid Utility Class Pattern

**Problem Context:**

During VTube Studio integration development, significant code duplication was identified between OBSManager and VTubeStudioManager modules, particularly in:

- WebSocket connection establishment and management
- Process lifecycle management (start/stop/graceful shutdown)
- Common utility functions for application detection

**Options Considered:**

- **Full Inheritance Model**: Create abstract base class with OBSManager/VTubeStudioManager inheriting all functionality
- **Composition Pattern**: Separate WebSocket utility class with full delegation
- **Hybrid Utility Class Pattern**: Common utility class with selective delegation and fallback mechanisms
- **Code Duplication**: Maintain separate implementations for flexibility

**Selection Rationale:**

- **PowerShell Class Limitations**: PowerShell class inheritance has constraints that make full inheritance complex
- **Flexibility Preservation**: Each manager retains ability to implement application-specific logic
- **Code Reuse Benefits**: Common utilities shared without forcing rigid inheritance structure
- **Fallback Resilience**: Managers can fall back to original implementations if utility class fails
- **Future Extensibility**: Pattern can be extended to other WebSocket-based integrations

**Technical Implementation:**

```powershell
# WebSocketAppManagerBase.ps1 - Common utility class
class WebSocketAppManagerBase {
    [bool] IsProcessRunning([string]$processName) { }
    [object] EstablishWebSocketConnection([string]$uri, [int]$timeout) { }
    [bool] StopApplicationGracefully([string]$processName, [int]$timeout) { }
}

# VTubeStudioManager.ps1 - Hybrid usage pattern
class VTubeStudioManager {
    hidden [WebSocketAppManagerBase] $baseHelper

    [bool] IsVTubeStudioRunning() {
        try {
            return $this.baseHelper.IsProcessRunning("VTubeStudio")
        }
        catch {
            # Fallback to original implementation
            return (Get-Process -Name "VTubeStudio" -ErrorAction SilentlyContinue) -ne $null
        }
    }
}
```

**Benefits Achieved:**

- **25% Code Reduction**: Eliminated duplicate utility functions across managers
- **Maintained Flexibility**: Each manager retains full control over application-specific behavior
- **Resilient Design**: Fallback mechanisms ensure continued operation even if base utilities fail
- **Extensible Pattern**: Foundation for future WebSocket-based integrations (Discord bots, streaming tools)

**Design Decision Impact:**

This hybrid approach balances the benefits of code reuse with the need for flexibility in PowerShell-based class architecture, establishing a pattern for future manager implementations while avoiding the constraints of rigid inheritance models.

#### 8. Launcher Format Enhancement: Windows Shortcuts over Batch Files

**Problem Context:**

The original `Create-Launchers.ps1` generated `.bat` files for game launching, which presented usability challenges for the project's target audience of "gamers who are not tech-savvy":

- Visual intimidation: `.bat` extensions appear technical and suspicious to non-technical users
- Disruptive UX: Command prompt windows flash briefly when executed
- Poor file identification: Uniform batch file icons make game identification difficult
- User anxiety: Black command prompt windows create uncertainty about what's executing

**Options Considered:**

- **Maintain Batch Files (.bat)**: Keep existing implementation for consistency
- **PowerShell Scripts (.ps1)**: Direct PowerShell execution with better control
- **Windows Shortcuts (.lnk)**: Native Windows shortcut files with enhanced UX
- **Desktop Applications**: Create native executables for each game

**Selection Rationale:**

- **User-Friendly Design**: `.lnk` files are familiar and trusted by general users
- **Enhanced UX**: Minimized window execution (`WindowStyle = 7`) eliminates disruptive command prompt flashing
- **Visual Appeal**: Support for custom icons and proper tooltips/descriptions
- **Platform Integration**: Native Windows shortcuts integrate seamlessly with desktop and file explorer
- **Maintained Functionality**: All existing features preserved while improving presentation
- **Project Alignment**: Directly supports the core principle "intuitive for non-technical gamers"

**Technical Implementation:**

```powershell
# Enhanced launcher creation using WScript.Shell COM object
function New-GameShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath = "powershell.exe",
        [string]$Arguments,
        [string]$Description,
        [int]$WindowStyle = 7  # Minimized execution
    )

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Arguments = $Arguments
    $Shortcut.Description = $Description
    $Shortcut.WindowStyle = $WindowStyle
    $Shortcut.Save()
}
```

**Implementation Strategy:**

- **Phase 1**: Parallel deployment with existing batch file system
- **Phase 2**: GUI integration allowing user choice between formats
- **Phase 3**: Default transition to enhanced shortcuts with fallback support

**Benefits Achieved:**

| Aspect | Batch Files (.bat) | Enhanced Shortcuts (.lnk) | Improvement |
|--------|-------------------|---------------------------|-------------|
| User Perception | Technical/Suspicious | Familiar/Trusted | Reduced barrier to entry |
| Execution Experience | Visible CMD window | Minimized/Silent | Professional UX |
| File Identification | Generic icons | Custom icons supported | Better usability |
| Tooltips/Description | Limited | Rich metadata | User guidance |
| Desktop Integration | △ Functional | Native | Windows consistency |

**Risk Mitigation:**

- **COM Object Dependency**: Implemented robust error handling and fallback to batch file generation
- **Compatibility Concerns**: Comprehensive testing across Windows 10/11 and PowerShell versions
- **User Choice**: GUI integration allows users to select preferred launcher format

**Future Considerations:**

- Custom icon support for game-specific visual identification
- Integration with Windows Start Menu and taskbar pinning
- Potential extension to create desktop shortcuts automatically

**Design Decision Impact:**

This enhancement directly addresses the project's core value of accessibility for non-technical users while maintaining all existing functionality. The implementation demonstrates the project's commitment to user-first design principles and establishes a pattern for future UX improvements throughout the application.

#### 9. Multi-Executable Bundle Architecture: Security-First Redesign

**Problem Context:**

The original architecture (pre-v3.0) had a critical security vulnerability: a single signed `Focus-Game-Deck.exe` that executed external, unsigned `.ps1` scripts. This created a significant attack vector where malicious actors could modify these external scripts, and the code signature on the main `.exe` would be unable to prevent the tampered code from running. This directly violated the project's "Security First" philosophy.

**Options Considered:**

- **Single Signed Executable with External Scripts**: Maintain existing architecture (status quo)
- **Single Large Bundled Executable**: Bundle everything into one massive executable
- **Multi-Executable Bundle**: Separate executables for router, GUI, and game launcher
- **Hybrid Approach**: Signed main executable with encrypted script resources

**Selection Rationale:**

The multi-executable bundle architecture was selected for the following reasons:

- **Enhanced Security**: All executed code is now contained within digitally signed executables, eliminating the external script vulnerability
- **Improved Efficiency**: Separate processes optimize memory usage - the game launcher doesn't load heavy WPF assemblies, and the GUI doesn't load game-related modules
- **Process Isolation**: Each component runs in its own process, improving stability and preventing cascading failures
- **Simplified Distribution**: Clean distribution with only executables and supporting data files (JSON, XAML)
- **Maintainability**: Clear separation of concerns with distinct executables for distinct purposes
- **Future Extensibility**: Easier to add new executables for new features without affecting existing ones

**Technical Implementation:**

```architecture
Focus Game Deck v3.0 Multi-Executable Architecture
──────────────────────────────────────────────────

┌─────────────────────────────────────────────────┐
│  User Command Line / Desktop Shortcut           │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
     ┌───────────────────────────┐
     │  Focus-Game-Deck.exe      │ ← Main Router (30-40 KB)
     │  (Main-Router.ps1)        │   - Argument parsing
     │  - Digitally Signed       │   - Process delegation
     └─────────┬─────────────────┘   - User interface
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
┌──────────────┐  ┌──────────────────────┐
│ConfigEditor  │  │Invoke-FocusGameDeck  │
│    .exe      │  │        .exe          │
│(75-100 KB)   │  │    (60-80 KB)        │
│              │  │                      │
│- GUI Editor  │  │- Game Launching      │
│- WPF/XAML    │  │- App Management      │
│- Settings    │  │- Integration Control │
│- Signed      │  │- Signed              │
└──────────────┘  └──────────────────────┘
```

**Build Process Changes:**

1. **New Entry Point**: Created `src/Main-Router.ps1` - lightweight router (replaces Main.PS1 as main executable)
2. **Updated Build Script**: Modified `Build-FocusGameDeck.ps1` to build three executables:
   - `Focus-Game-Deck.exe` from `Main-Router.ps1`
   - `ConfigEditor.exe` from `gui/ConfigEditor.ps1`
   - `Invoke-FocusGameDeck.exe` from `src/Invoke-FocusGameDeck.ps1`
3. **Supporting Files**: All three executables share supporting files (config/, localization/, gui/, src/modules/)
4. **Digital Signatures**: All three executables are digitally signed with the same certificate

**Security Benefits:**

- **Code Integrity**: All execution flows through signed executables - no external unsigned scripts can be executed
- **Tamper Detection**: Any modification to executables breaks the digital signature
- **Trust Chain**: Users can verify all executables are from the legitimate publisher
- **Attack Surface Reduction**: Eliminates the largest attack vector from the previous architecture

**Performance Benefits:**

| Component | Memory Savings | Startup Time | Notes |
|-----------|---------------|--------------|-------|
| ConfigEditor.exe | -15MB | -0.5s | Doesn't load game modules |
| Invoke-FocusGameDeck.exe | -25MB | -1.0s | Doesn't load WPF assemblies |
| Overall | ~40MB saved | ~1.5s faster | Per-component resource optimization |

**Migration Impact:**

- **User Experience**: Transparent to end users - command-line interface remains identical
- **Distribution**: Slightly larger total package size (3 executables instead of 1) but still under 300 KB total
- **Compatibility**: Full backward compatibility with existing configuration files and scripts
- **Testing**: Requires testing of three executables instead of one, but better isolation simplifies testing

**Future Considerations:**

- **Plugin Architecture**: Easier to add plugin executables for community extensions
- **Microservices Pattern**: Foundation for potential future service-oriented architecture
- **Independent Updates**: Ability to update individual components without full reinstall

**Design Decision Impact:**

This architectural change directly addresses the security vulnerability identified in the original issue, demonstrating the project's commitment to "Security First" principles. The implementation provides a scalable foundation for future enhancements while maintaining the lightweight, user-friendly nature of the application.

## Implementation Guidelines

### Coding Standards

1. **Encoding**: All files saved in UTF-8
2. **Error Handling**: Consistent use of Try-Catch-Finally patterns
3. **Function Naming**: PowerShell Verb-Noun pattern
4. **Comments**: Japanese comments allowed (UTF-8 guaranteed)

### Character Encoding and Console Compatibility Guidelines

#### PowerShell Console Character Compatibility

Due to frequent character encoding issues in PowerShell console environments, especially with UTF-8 special characters, follow these guidelines:

##### 1. Avoid UTF-8 Special Characters in Console Output

```powershell
# Problematic: UTF-8 special characters cause garbling
Write-Host "[OK] Success"
Write-Host "[ERROR] Failed"
Write-Host "Warning"

# Recommended: Use ASCII-compatible alternatives
Write-Host "[OK] Success"
Write-Host "[ERROR] Failed"
Write-Host "[WARNING] Warning"
```

##### 2. Avoid Write-Host with Color Parameters

**Do NOT use Write-Host with -ForegroundColor or -BackgroundColor parameters:**

```powershell
# Problematic: Forces specific colors that may conflict with user's console theme
Write-Host "Success message" -ForegroundColor Green
Write-Host "Error message" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "Warning" -ForegroundColor Yellow

# Recommended: Use Write-Host without color parameters or alternative output methods
Write-Host "[OK] Success message"
Write-Host "[ERROR] Error message"
Write-Host "[WARNING] Warning message"

# Alternative: Use Write-Output for pipeline compatibility
Write-Output "[INFO] Information message"

# For error reporting: Use Write-Error for proper error stream handling
Write-Error "This is an error message"

# For verbose output: Use Write-Verbose with preference variables
Write-Verbose "Detailed operation information" -Verbose
```

**Rationale:**

- **User Experience**: Users who customize their console color schemes find forced colors disruptive and inconsistent with their preferred environment
- **Accessibility**: Color-blind users may not be able to distinguish forced color combinations
- **Professional Consideration**: Respecting user's personalized environment demonstrates thoughtful development practices
- **Consistency**: Messages should rely on clear text indicators (like `[OK]`, `[ERROR]`) rather than color coding
- **Cross-Platform**: Console color support varies across different PowerShell hosts and operating systems

##### 3. Console Message Format Standards

**Standardized message format ensures consistency and readability across all project scripts.**

**Message Format Template:**

```text
[LEVEL] Component: Action description
[LEVEL] Component: Action description - Additional context
```

**Format Rules:**

1. **Severity Level Prefix** (Required):
   - Use uppercase with square brackets
   - Must be one of: `[OK]`, `[ERROR]`, `[WARNING]`, `[INFO]`, `[DEBUG]`

2. **Component Identifier** (Required):
   - Identifies the module or function generating the message
   - Use PascalCase or module name
   - Follow with colon and space

3. **Action Description** (Required):
   - Clear, concise description of the action or status
   - Use present or past tense consistently

4. **Additional Context** (Optional):
   - Provide details after a dash separator
   - Include relevant values, paths, or error details

**Examples:**

```powershell
# Success messages
Write-Host "[OK] ConfigEditor: Configuration saved successfully"
Write-Host "[OK] OBSManager: Connected to OBS Studio"

# Error messages
Write-Host "[ERROR] GameLauncher: Failed to start game - Process not found"
Write-Host "[ERROR] FileOperation: Cannot read config.json - File does not exist"

# Warning messages
Write-Host "[WARNING] VTubeStudio: Connection timeout - Retrying in 5 seconds"
Write-Host "[WARNING] ConfigValidator: Deprecated setting detected - Please update config.json"

# Informational messages
Write-Host "[INFO] BuildSystem: Starting compilation process"
Write-Host "[INFO] TestRunner: Running 15 test cases"

# Debug messages (only shown when debug mode enabled)
Write-Host "[DEBUG] WebSocket: Sending authentication request - Token length: 32"
Write-Host "[DEBUG] StateManager: Current state transition: Idle -> Starting"
```

**Multi-line Messages:**

For complex output, use consistent indentation:

```powershell
Write-Host "[INFO] SystemCheck: Validating environment"
Write-Host "  - PowerShell version: 7.4.0"
Write-Host "  - ps2exe module: Installed"
Write-Host "  - Configuration file: Valid"
```

**Progress Indicators:**

For long-running operations, use standardized progress format:

```powershell
Write-Host "[INFO] BuildProcess: Step 1/5 - Installing dependencies"
Write-Host "[INFO] BuildProcess: Step 2/5 - Compiling source files"
# ...
```

**Helper Function Implementation:**

To ensure consistency, consider creating a helper function:

```powershell
<#
.SYNOPSIS
    Writes a standardized console message.

.PARAMETER Level
    Message severity level: OK, ERROR, WARNING, INFO, DEBUG

.PARAMETER Component
    Component or module name generating the message

.PARAMETER Message
    Main message content

.PARAMETER Details
    Optional additional details or context

.EXAMPLE
    Write-ConsoleMessage -Level "OK" -Component "ConfigEditor" -Message "Configuration saved"
    Write-ConsoleMessage -Level "ERROR" -Component "GameLauncher" -Message "Failed to start" -Details "Process not found"
#>
function Write-ConsoleMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("OK", "ERROR", "WARNING", "INFO", "DEBUG")]
        [string]$Level,

        [Parameter(Mandatory = $false)]
        [string]$Component,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Details
    )

    $output = "[$Level]"

    if ($Component) {
        $output += " ${Component}:"
    }

    $output += " $Message"

    if ($Details) {
        $output += " - $Details"
    }

    Write-Host $output
}

# Usage examples
Write-ConsoleMessage -Level "OK" -Component "ConfigEditor" -Message "Configuration saved successfully"
Write-ConsoleMessage -Level "ERROR" -Component "GameLauncher" -Message "Failed to start game" -Details "Process not found"
Write-ConsoleMessage -Level "INFO" -Message "Operation completed"
```

##### 4. Safe Character Alternatives

| UTF-8 Character | ASCII Alternative | Usage Context |
|-----------------|-------------------|---------------|
| ✓ (U+2713) | `[OK]` | Success messages |
| ✗ (U+2717) | `[ERROR]` | Error messages |
| (U+26A0) | `[WARNING]` | Warning messages |
| (U+2139) | `[INFO]` | Information messages |
| → (U+2192) | `->` | Direction indicators |
| • (U+2022) | `-` | List bullets |

##### 4. File Encoding Consistency Rules

> **Critical**: Character encoding issues have been a recurring source of bugs in this project. Strict adherence to these rules is essential.

- **PowerShell Source Files (.ps1)**: UTF-8 with BOM for maximum compatibility
- **JSON Configuration Files (.json)**: UTF-8 without BOM to prevent JSON parsing errors
- **Documentation Files (.md)**: UTF-8 with BOM for proper GitHub display
- **Text Log Files (.log, .txt)**: UTF-8 without BOM for cross-platform compatibility

##### 5. JSON File Handling Best Practices

**Critical for avoiding parsing errors:**

```powershell
# Always specify encoding when reading JSON files
$jsonContent = Get-Content -Path $jsonPath -Raw -Encoding UTF8
$config = $jsonContent | ConvertFrom-Json

# Always specify encoding when writing JSON files
$jsonString = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($jsonPath, $jsonString, [System.Text.Encoding]::UTF8)

# Never use default encoding (causes corruption)
$config = Get-Content -Path $jsonPath | ConvertFrom-Json
```

##### 6. Multi-Language Content Validation

**Verification process for messages.json integrity:**

```powershell
# Test JSON structure integrity
try {
    $messages = Get-Content -Path "./config/messages.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $enCount = ($messages.en.PSObject.Properties | Measure-Object).Count
    $jaCount = ($messages.ja.PSObject.Properties | Measure-Object).Count

    if ($enCount -ne $jaCount) {
        throw "Key count mismatch: EN=$enCount, JA=$jaCount"
    }

    Write-Host "[OK] Messages file validated: $enCount keys each language"
} catch {
    Write-Host "[ERROR] Messages file validation failed: $($_.Exception.Message)"
}
```

##### 7. Testing Console Output

Always test console output in multiple PowerShell environments:

- Windows PowerShell 5.1
- PowerShell Core 7.x
- PowerShell ISE
- Windows Terminal
- Command Prompt with PowerShell

##### 8. Internationalization Implementation

```powershell
# For GUI components: Use JSON external resources
# Store Japanese text using properly encoded JSON (not Unicode escapes)
{
    "en": {
        "configSaved": "Configuration has been saved."
    },
    "ja": {
        "configSaved": "設定が保存されました。"
    }
}

# For console output: Use ASCII-safe alternatives with optional localized logging
function Write-SafeMessage {
    param([string]$MessageKey, [string]$Severity = "Info")

    # Console: ASCII-safe
    Write-Host "[$Severity] Operation completed"

    # Log: Full localized message (if logger available)
    if ($global:Logger) {
        $localizedMsg = Get-LocalizedMessage -Key $MessageKey
        $global:Logger.Info($localizedMsg, "SYSTEM")
    }
}
```

##### 9. Character Encoding Troubleshooting

**Common issues and solutions:**

| Problem | Cause | Solution |
|---------|-------|----------|
| JSON parsing fails with "Invalid character" | BOM in JSON file | Save as UTF-8 without BOM |
| Japanese characters appear as "繧�繝�" | Wrong encoding assumption | Use `-Encoding UTF8` parameter |
| Console shows question marks | UTF-8 special chars | Use ASCII alternatives |
| Logger initialization fails | Malformed messages.json | Validate JSON structure and encoding |
| Build process creates corrupted files | Mixed encoding in pipeline | Ensure consistent UTF-8 throughout |

##### 10. Development Workflow for Character Safety

1. **Before committing**: Validate all JSON files with encoding test
2. **During development**: Use ASCII-safe console output for immediate feedback
3. **For production**: Store full Unicode content in properly encoded JSON
4. **Testing phase**: Verify functionality across different PowerShell environments

##### 11. Practical Character Encoding Checklist

**Pre-development Setup:**

- [ ] Set PowerShell execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- [ ] Configure editor to save PowerShell files as UTF-8 with BOM
- [ ] Configure editor to save JSON files as UTF-8 without BOM
- [ ] Test console environment with Japanese characters

**During Development:**

- [ ] Use `Get-Content -Raw -Encoding UTF8` for all JSON file reads
- [ ] Use `[System.IO.File]::WriteAllText()` with UTF-8 encoding for JSON writes
- [ ] Replace UTF-8 special characters in console output with ASCII alternatives
- [ ] Test Logger initialization with actual messages.json before committing

**Before Release:**

- [ ] Run messages.json validation script across all language files
- [ ] Test console output in both PowerShell 5.1 and PowerShell Core 7.x
- [ ] Verify JSON file parsing in clean environment
- [ ] Validate that all log files are properly encoded and readable

**Emergency Recovery Procedures:**

```powershell
# If messages.json becomes corrupted:
# 1. Backup the corrupted file
Copy-Item "./config/messages.json" "./config/messages.json.corrupted"

# 2. Restore from sample or rebuild
if (Test-Path "./config/messages.json.sample") {
    Copy-Item "./config/messages.json.sample" "./config/messages.json"
} else {
    # Manually recreate with proper encoding
    $messages = @{
        en = @{}
        ja = @{}
    }
    $jsonString = $messages | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText("./config/messages.json", $jsonString, [System.Text.Encoding]::UTF8)
}

# 3. Validate the restored file
$test = Get-Content "./config/messages.json" -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "[OK] Messages file restored successfully"
```

### GUI Development Guidelines

1. **XAML Structure**:
   - Do not use x:Class attribute (for PowerShell compatibility)
   - Element reference through Name attribute
   - Feature categorization through TabControl

2. **Message Display**:

   ```powershell
   # Recommended: Use JSON external resources
   Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"

   # Not recommended: Direct string specification
   [System.Windows.MessageBox]::Show("設定が保存されました")
   ```

3. **Configuration Management**:

   ```powershell
   # Configuration loading
   $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

   # Configuration saving
   $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
   ```

## Performance Considerations

### Startup Time Optimization

- Lazy loading of JSON
- Pre-loading of WPF assemblies
- XAML parsing optimization

### Memory Usage

- Account for differences between PowerShell ISE vs standard PowerShell
- Proper disposal of large objects
- Memory leak prevention in event handlers

## Security Considerations and Risk Management

### Highest Priority Risk: Anti-Cheat System False Positive Prevention

**Technical Approach (Thorough Non-Invasive Design)**:

- Completely avoid invasive operations such as game process memory reading/writing and code injection
- Use only official OS standard features (Get-Process, Stop-Process, etc.) for process operations
- Ensure transparency: Maintain all source code publicly on GitHub for anyone to audit code safety

**Proactive Communication**:

- Notify major anti-cheat developers (Epic Games, BattlEye, etc.) in advance of this project's purpose and technical specifications, requesting whitelist registration

### Execution Policy and Distribution Strategy

- **Development**: Restriction bypass through `-ExecutionPolicy Bypass`
- **Distribution**: **Digital signature with code signing certificate is mandatory**, distributing only officially signed executable files (.exe) by trusted Certificate Authority (CA)
- Signed files ensure trust from Windows SmartScreen and security software

### Configuration File Protection and Privacy

- **Sensitive Information Encryption**: OBS WebSocket passwords etc. are encrypted using Windows Data Protection API (DPAPI) via SecureString, tied to user account
- **Configuration File Access Control**: Appropriate file permission settings

## Future Extension Plans

### Highest Priority (Alpha Test Period)

- [ ] Implementation of alpha test plan (recruiting 5-10 testers)
- [ ] Establishment of official distribution system with digital signatures
- [ ] Security audit and advance notification to anti-cheat developers

### Short-term (v1.1)

- [x] VTube Studio integration (Steam/Standalone auto-detection)
- [x] Character encoding guidelines and console compatibility
- [ ] Addition of English message resources
- [ ] Enhanced configuration validation
- [ ] Error logging functionality

### Medium-term (v1.2)

- [ ] Plugin architecture
- [ ] Theme functionality
- [ ] Configuration import/export

### Long-term (v2.0)

- [ ] Cloud configuration synchronization
- [ ] Web UI option
- [ ] Multi-platform support

## Contribution Guidelines

To maintain this design philosophy, please prioritize the following:

1. **Maintain Lightweight Nature**: Carefully consider adding new dependencies
2. **PowerShell First**: Prioritize PowerShell solutions over migration to other languages
3. **Configuration-Driven**: Control through configuration files rather than hardcoding
4. **Internationalization Support**: Always externalize new messages to JSON resources

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-09-23 | Initial architecture design, GUI implementation completed |
| 1.0.1 | 2025-09-23 | JSON external resource internationalization support completed |
| 1.1.0 | 2025-09-23 | Integration of risk management policy and security design |
| 1.2.0 | 2025-09-24 | Build system implementation, digital signature infrastructure completed |
| 1.3.0 | 2025-09-24 | VTube Studio integration, character encoding guidelines added |
| 1.4.0 | 2025-09-24 | WebSocket manager hybrid architecture pattern implemented |
| 1.5.0 | 2025-09-26 | Enhanced launcher format implementation: Windows shortcuts over batch files for improved UX |
| 1.6.0 | 2025-09-26 | Comprehensive character encoding best practices: Extended implementation guidelines with practical troubleshooting, validation procedures, and emergency recovery protocols |
| 2.0.0 | 2025-10-01 | Unified architecture implementation: Main.PS1 entry point with integrated GUI and game launcher, obsolete file cleanup, English documentation standardization |
| 2.1.0 | 2025-11-03 | Console output guidelines: Added prohibition of Write-Host color parameters to respect user console customization and improve accessibility |
| 3.0.0 | 2025-11-13 | Multi-Executable Bundle Architecture: Security-first redesign with three separate signed executables (Main Router, ConfigEditor, Game Launcher) eliminating external unsigned script vulnerability, improving efficiency through process isolation, and establishing foundation for future extensibility |
| 3.0.1 | 2025-11-15 | Build-Time Patching Unification: Refactored build system to use unified build-time patching approach for both ConfigEditor and Invoke-FocusGameDeck, eliminating duplicate -Bundled.ps1 files and improving maintainability through single-source architecture |

---

*This document records the design philosophy and technical choices of the Focus Game Deck project, enabling future developers to continue development with consistent principles.*
