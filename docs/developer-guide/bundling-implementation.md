# Implementation Summary: Secure Multi-Executable Bundle Architecture

> **DEPRECATED**: This document has been consolidated into [architecture.md](architecture.md) and [build-system.md](build-system.md) as of 2025-12-07 to reduce documentation duplication, as the content was already comprehensively covered in the architecture and build system documentation.
>
> Please refer to:
> - [Architecture Guide](architecture.md) - For multi-executable architecture design and rationale
> - [Build System Guide](build-system.md) - For build process, tool scripts, and SRP refactoring details
> - [v3 Migration Guide](v3-migration-guide.md) - For migration instructions and testing procedures

## Overview

This document summarizes the complete implementation of the secure multi-executable bundle architecture as specified in issue #44 and the detailed architecture specification.

**v3.0 Update**: The build system has been refactored following the Single Responsibility Principle (SRP), separating build tasks into specialized tool scripts. See the "Build System Refactoring (v3.0)" section for details.

## What Was Implemented

### Three Fully Bundled Executables

#### 1. Main.exe (Focus-Game-Deck.exe)

- **Source**: `src/Main-Bundled.ps1`
- **Size**: ~30-40KB
- **Dependencies**: None (standalone router)
- **Purpose**: Lightweight router that launches ConfigEditor.exe or Invoke-FocusGameDeck.exe based on command-line arguments
- **Bundling**: No external PS1 dependencies to bundle

#### 2. ConfigEditor.exe

- **Source**: `gui/ConfigEditor.ps1` (patched during build)
- **Size**: ~75-100KB
- **Bundled Dependencies**:
  - ConfigEditor.JsonHelper.ps1
  - ConfigEditor.Mappings.ps1
  - ConfigEditor.State.ps1
  - ConfigEditor.Localization.ps1
  - ConfigEditor.UI.ps1
  - ConfigEditor.Events.ps1
  - LanguageHelper.ps1
  - Version.ps1
- **External Resources** (data files, not executable code):
  - MainWindow.xaml
  - ConfirmSaveChangesDialog.xaml
  - messages.json
  - config.json
- **Path Resolution**: Automatically patched during build to detect execution mode

#### 3. Invoke-FocusGameDeck.exe

- **Source**: `src/Invoke-FocusGameDeck-Bundled.ps1`
- **Size**: ~60-80KB
- **Bundled Dependencies**:
  - Logger.ps1
  - ConfigValidator.ps1
  - AppManager.ps1
  - OBSManager.ps1
  - PlatformManager.ps1
  - VTubeStudioManager.ps1
  - DiscordManager.ps1
  - DiscordRPCClient.ps1
  - WebSocketAppManagerBase.ps1
  - UpdateChecker.ps1
  - LanguageHelper.ps1
- **External Resources**: JSON configuration files
- **Path Resolution**: Built-in detection for bundled vs. development mode

## Build Process Implementation

### Modern SRP-Based Build System (v3.0+)

The build process is now managed by specialized tool scripts:

1. **Install-BuildDependencies.ps1**: Installs ps2exe module
2. **Invoke-PsScriptBundler.ps1**: Resolves dependencies and creates bundled scripts
3. **Build-Executables.ps1**: Compiles bundled scripts into executables
4. **Copy-Resources.ps1**: Copies runtime assets (JSON, XAML)
5. **Sign-Executables.ps1**: Applies digital signatures
6. **Create-Package.ps1**: Creates final distribution package
7. **Release-Manager.ps1**: Orchestrates the complete workflow

### Staging Directory Approach

The build script creates staging directories with flat structure for ps2exe bundling:

```architecture
For Invoke-FocusGameDeck.exe:
staging-gameLauncher/
├── Invoke-FocusGameDeck.ps1  (main script)
├── Logger.ps1                 (bundled)
├── ConfigValidator.ps1        (bundled)
├── AppManager.ps1             (bundled)
├── OBSManager.ps1             (bundled)
├── PlatformManager.ps1        (bundled)
└── ... (all other modules)

ps2exe compiles from this staging directory, bundling all files into a single .exe
```

### Path Resolution Implementation

#### Approach 1: Built-in Detection (Invoke-FocusGameDeck)

Created `Invoke-FocusGameDeck-Bundled.ps1` with built-in path resolution:

```powershell
$isExecutable = (Get-Process -Id $PID).ProcessName -ne 'pwsh' -and ...

if ($isExecutable) {
    # ps2exe flat extraction - all files at $PSScriptRoot
    $modulePaths = @(
        (Join-Path $scriptDir "Logger.ps1"),
        (Join-Path $scriptDir "ConfigValidator.ps1"),
        ...
    )
} else {
    # Development mode - relative paths
    $modulePaths = @(
        (Join-Path $scriptDir "modules/Logger.ps1"),
        (Join-Path $scriptDir "modules/ConfigValidator.ps1"),
        ...
    )
}
```

#### Approach 2: Build-Time Patching (ConfigEditor)

The build script patches ConfigEditor.ps1 during staging:

1. Injects execution mode detection at the top
2. Replaces path construction to use conditional logic:

   ```powershell
   # Original:
   Join-Path -Path $projectRoot -ChildPath "gui/ConfigEditor.Mappings.ps1"

   # Patched to:
   Join-Path -Path $(if ($isExecutable) { $guiScriptRoot } else { $projectRoot }) -ChildPath $(if ($isExecutable) { "ConfigEditor.Mappings.ps1" } else { "gui/ConfigEditor.Mappings.ps1" })
   ```

3. Works seamlessly in both bundled and development modes

## Security Improvement

### Problem Eliminated

**Before v3.0:**

- Single signed Focus-Game-Deck.exe
- Executed external, unsigned .ps1 scripts
- Attack vector: Malicious actors could modify Logger.ps1, AppManager.ps1, ConfigEditor.ps1, etc.
- Code signature on the .exe provided no protection for external scripts

**After v3.0:**

- Three signed executables with bundled code
- All PowerShell code (.ps1) is inside signed executables
- Only data files (JSON, XAML) are external
- Attack surface dramatically reduced

### Attack Surface Analysis

| File Type | Before v3.0 | After v3.0 | Security Status |
|-----------|-------------|------------|-----------------|
| .ps1 (PowerShell code) | External, unsigned | Bundled in signed .exe | Secured |
| .json (Configuration) | External | External | Data only, no code execution |
| .xaml (UI layout) | External | External | Data only, no code execution |

**Key Point**: While JSON and XAML files remain external, they cannot directly execute code. The PowerShell code that processes these files is now protected within signed executables.

## How ps2exe Bundling Works

### ps2exe Behavior

When ps2exe creates an executable:

1. **Compilation**: Converts PowerShell script to C# code
2. **Compilation**: Compiles C# to .exe
3. **Resource Embedding**: Embeds PowerShell runtime and script
4. **Dependency Bundling**: If other .ps1 files are in the same directory, they can be referenced
5. **Runtime Extraction**: When executed, extracts files to a flat temporary directory

### Flat Directory Extraction

Example of ps2exe extraction at runtime:

```architecture
Original staging structure:
staging-gameLauncher/
├── Invoke-FocusGameDeck.ps1
├── Logger.ps1
├── AppManager.ps1
└── OBSManager.ps1

After bundling and extraction (runtime):
C:/Users/username/AppData/Local/Temp/ps2exe_xxxxx/
├── Invoke-FocusGameDeck.ps1
├── Logger.ps1
├── AppManager.ps1
└── OBSManager.ps1

All files are at the same level (flat structure)
$PSScriptRoot points to this temp directory
```

### Why Path Resolution Matters

In development:

```powershell
# $PSScriptRoot = C:/Projects/focus-game-deck/src
. (Join-Path $PSScriptRoot "modules/Logger.ps1")  # Works
```

In bundled executable:

```powershell
# $PSScriptRoot = C:/Users/.../Temp/ps2exe_xxxxx/
. (Join-Path $PSScriptRoot "modules/Logger.ps1")  # Fails - no subdirectory
. (Join-Path $PSScriptRoot "Logger.ps1")          # Works - flat structure
```

## Build Script Changes

### Build-FocusGameDeck.ps1

**Key Changes:**

1. **Staging Directories**: Creates flat staging directories for each executable
2. **Dependency Copying**: Copies all PS1 dependencies to staging
3. **Path Patching**: Automatically patches ConfigEditor.ps1 for path resolution
4. **ps2exe Compilation**: Compiles from staging directories
5. **Cleanup**: Removes staging directories after compilation

**Build Flow:**

```architecture
1. Install ps2exe (if needed)
   ↓
2. Create build directory
   ↓
3. For each executable:
   a. Create staging directory
   b. Copy main script
   c. Copy all dependencies (flat structure)
   d. Apply path patches (if needed)
   e. Compile with ps2exe
   f. Clean staging directory
   ↓
4. Copy supporting files (config, localization, etc.)
   ↓
5. Move to dist directory (optional: sign)
```

## Testing Requirements

### Windows Environment Required

ps2exe only works on Windows as it creates Windows .exe files.

### Build Testing

```powershell
# Navigate to project root
cd path/to/focus-game-deck

# Install dependencies (new SRP approach)
./build-tools/Install-BuildDependencies.ps1

# Build all three executables (new SRP approach)
./build-tools/Build-Executables.ps1

# Or use the orchestrator for complete workflow
./build-tools/Release-Manager.ps1 -Development

# Check output
dir ./build-tools/dist/*.exe

# Expected output:
# Focus-Game-Deck.exe
# ConfigEditor.exe
# Invoke-FocusGameDeck.exe
```

### Functional Testing

```powershell
cd ./build-tools/dist

# Test Main Router
./Focus-Game-Deck.exe --help
./Focus-Game-Deck.exe --list
./Focus-Game-Deck.exe --version

# Test ConfigEditor (should load all bundled helpers)
./ConfigEditor.exe
# Verify: GUI loads, no "module not found" errors

# Test Game Launcher (should load all bundled modules)
./Invoke-FocusGameDeck.exe -GameId <your-game-id>
# Verify: Game launches, no module errors
```

### Bundling Verification

```powershell
# Extract and inspect the executables (advanced)
# ps2exe executables can be decompiled to verify bundling
# Tools like ILSpy or dotPeek can show embedded resources

# Simpler verification: File size check
Get-Item ./build-tools/dist/*.exe | Select-Object Name, Length

# Expected approximate sizes:
# Focus-Game-Deck.exe: 30-40 KB
# ConfigEditor.exe: 75-100 KB (larger due to WPF and bundled helpers)
# Invoke-FocusGameDeck.exe: 60-80 KB (due to bundled modules)
```

## Build System Refactoring (v3.0)

### From Monolithic to SRP Architecture

The original `Build-FocusGameDeck.ps1` was a monolithic script with multiple responsibilities:

- Installing dependencies
- Bundling scripts
- Building executables
- Copying resources
- Signing executables
- Creating packages

This has been refactored into specialized tool scripts, each with a single responsibility:

#### Tool Scripts

**Install-BuildDependencies.ps1:**

- **Responsibility**: Manage ps2exe module installation
- **Usage**: `./build-tools/Install-BuildDependencies.ps1 [-Force] [-Verbose]`

**Invoke-PsScriptBundler.ps1:**

- **Responsibility**: Resolve dot-sourced dependencies and create bundled scripts
- **Usage**: `./build-tools/Invoke-PsScriptBundler.ps1 -EntryPoint "src/Main.ps1" -OutputPath "build/Main-bundled.ps1"`
- **Features**:
  - Recursively resolves `. $path` references
  - Handles `$PSScriptRoot` and `$projectRoot` variables
  - Creates single flat .ps1 files for ps2exe
  - Eliminates need for ps2exe's `-embedFiles` parameter

**Build-Executables.ps1:**

- **Responsibility**: Compile executables using ps2exe
- **Usage**: `./build-tools/Build-Executables.ps1 [-BuildDir <path>] [-OutputDir <path>] [-Verbose]`
- **Features**:
  - Compiles three executables with specific configurations
  - Manages console visibility, STA mode, icons
  - Falls back to non-bundled scripts if bundled versions not found

**Copy-Resources.ps1:**

- **Responsibility**: Copy non-executable runtime assets
- **Usage**: `./build-tools/Copy-Resources.ps1 [-DestinationDir <path>] [-Verbose]`
- **Features**:
  - Copies configuration files (JSON)
  - Copies localization files
  - Copies XAML UI files
  - Copies assets and documentation

**Sign-Executables.ps1:**

- **Responsibility**: Apply digital signatures (unchanged)
- **Usage**: `./build-tools/Sign-Executables.ps1 -SignAll`

**Create-Package.ps1:**

- **Responsibility**: Create final distribution package
- **Usage**: `./build-tools/Create-Package.ps1 [-IsSigned] [-Version <version>] [-Verbose]`
- **Features**:
  - Assembles all artifacts into release/ directory
  - Generates README.txt
  - Creates version-info.json

**Release-Manager.ps1:**

- **Responsibility**: Orchestrate complete build workflow
- **Usage**: `./build-tools/Release-Manager.ps1 -Development|-Production [-Verbose]`
- **Workflows**:
  - Development: Install → Build → Copy → Package
  - Production: Install → Build → Copy → Sign → Package

### Benefits of SRP Refactoring

1. **Maintainability**: Each script has clear, focused responsibility
2. **Testability**: Individual components can be tested in isolation
3. **Reusability**: Tool scripts can be used independently
4. **Debugging**: Issues isolated to specific tool scripts
5. **Flexibility**: Easy to modify individual components

### Migration from Legacy Build Script

The monolithic `Build-FocusGameDeck.ps1` is deprecated but maintained for backward compatibility:

| Legacy Command | New Command |
|----------------|-------------|
| `Build-FocusGameDeck.ps1 -Install` | `Install-BuildDependencies.ps1` |
| `Build-FocusGameDeck.ps1 -Build` | `Build-Executables.ps1` |
| `Build-FocusGameDeck.ps1 -All` | `Release-Manager.ps1 -Production` |

## Migration from Previous Implementation

### For Users

No changes required. Command-line interface remains identical:

```powershell
# v2.x and v3.0 use the same commands
Focus-Game-Deck.exe
Focus-Game-Deck.exe <game-id>
Focus-Game-Deck.exe --config
```

### For Developers

**Changes:**

1. **New Files**:
   - `src/Main-Bundled.ps1` - Used for Main.exe compilation
   - `src/Invoke-FocusGameDeck-Bundled.ps1` - Used for game launcher compilation

2. **Build Process**:
   - Build script now uses staging directories
   - Automatic path patching for ConfigEditor
   - Must run on Windows with ps2exe

3. **Development**:
   - Original scripts (Main-Router.ps1, Invoke-FocusGameDeck.ps1, ConfigEditor.ps1) still work for development
   - Bundled versions only used for compilation

## Compliance with Architecture Specification

### Requirements from Issue #44 Comment

**Build Process Overhaul**: Implemented with staging directories and dependency copying

**Path Resolution Logic**: Implemented with dual-mode detection

**Main.exe**: Lightweight router with no external PS1 dependencies

**ConfigEditor.exe**: Bundles all gui/*.ps1 scripts with path resolution

**Invoke-FocusGameDeck.exe**: Bundles all src/modules/*.ps1 with path resolution

**Flat Directory Structure**: All bundled scripts work with ps2exe's flat extraction

**Security Improvement**: All PowerShell code protected by digital signatures

## Limitations and Future Work

### Current Limitations

1. **External Data Files**: JSON and XAML files remain external
   - **Rationale**: These are data files, not executable code
   - **Risk**: Low - cannot directly execute code
   - **Mitigation**: File integrity can be verified at runtime

2. **Build Environment**: Requires Windows + ps2exe
   - **Rationale**: ps2exe creates Windows .exe files
   - **Workaround**: Use CI/CD pipeline on Windows

3. **ConfigEditor Patching**: Uses regex-based patching during build
   - **Rationale**: Avoids maintaining separate ConfigEditor version
   - **Risk**: Patching could break with major ConfigEditor changes
   - **Mitigation**: Well-tested regex patterns, documented

### Future Enhancements

1. **Resource Embedding**: Explore embedding JSON/XAML as resources
2. **Build Verification**: Add automated tests to verify bundling
3. **Cross-Platform**: Investigate PowerShell Core compilation alternatives
4. **Performance**: Profile bundled executables vs. script execution

## Conclusion

The secure multi-executable bundle architecture has been fully implemented as specified:

- Three separate signed executables
- All PowerShell code bundled into executables
- Path resolution handles ps2exe flat extraction
- Build process uses staging directories
- Security vulnerability eliminated
- Backward compatible command-line interface

The implementation addresses the critical security issue where external unsigned .ps1 scripts could be modified, undermining the code signature. Now all PowerShell code is protected within digitally signed executables.

---

**Last Updated**: November 16, 2025
**Implementation Version**: 3.0.0 - SRP Architecture Refactoring
**Status**: Complete and Production-Ready
