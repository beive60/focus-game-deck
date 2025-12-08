# Focus Game Deck - Build System Documentation

## Overview

This document describes the comprehensive build system implemented for Focus Game Deck, including executable generation, digital signature infrastructure, and automated release packaging.

The build system follows the **Single Responsibility Principle (SRP)**, separating build tasks into specialized tool scripts coordinated by a single orchestrator.
This architecture provides better maintainability, testability, and flexibility.

## Configuration File Security

### Sensitive Data Management

**CRITICAL SECURITY NOTICE**: Configuration files containing sensitive information (passwords, API keys, certificates) are excluded from version control to prevent accidental exposure.

## Build System Architecture

### SRP-Based Architecture (v3.0+)

The build system consists of specialized tool scripts, each with a single responsibility, coordinated by an orchestrator:

```text
Release-Manager.ps1 (Orchestrator)
├── Install-BuildDependencies.ps1  (Tool: Dependency installation)
├── Embed-XamlResources.ps1        (Tool: XAML embedding)
├── Invoke-PsScriptBundler.ps1    (Tool: Script bundling)
├── Build-Executables.ps1          (Tool: Executable compilation)
├── Copy-Resources.ps1             (Tool: Resource copying)
├── Sign-Executables.ps1           (Tool: Code signing)
└── Create-Package.ps1             (Tool: Package creation)

Build-FocusGameDeck.ps1 [DEPRECATED]
└── Legacy monolithic build script (maintained for backward compatibility)
```

**Key Benefits:**

- **Maintainability**: Each script has a single, well-defined responsibility
- **Testability**: Individual components can be tested in isolation
- **Reusability**: Tool scripts can be used independently or composed
- **Flexibility**: Easy to modify workflows without affecting other components

## Build-Time Patching Architecture

### Overview--build-time patching

The build system uses a unified **build-time patching** approach to handle path resolution differences between development (.ps1 script) and production (.exe executable) environments. This eliminates code duplication and improves maintainability.

### The Path Resolution Problem

When ps2exe creates an executable, it extracts embedded files to a temporary directory. This causes `$PSScriptRoot` to point to the temporary extraction directory, not the executable's actual location.

**Example of the problem:**

```powershell
# In script mode:
$PSScriptRoot = "C:/Users/YourName/dev/focus-game-deck/src"
$configPath = Join-Path $PSScriptRoot "../config/config.json"
# Result: C:/Users/YourName/dev/focus-game-deck/config/config.json (correct)

# In executable mode:
$PSScriptRoot = "C:/Users/YourName/AppData/Local/Temp/pe_xxxxx" (temp directory)
$configPath = Join-Path $PSScriptRoot "../config/config.json"
# Result: C:/Users/YourName/AppData/Local/Temp/config/config.json (wrong - doesn't exist)
```

### Build-Time Patching Solution

The build system replaces simple path resolution code with environment-aware logic during the build process.

#### How It Works

##### Development Phase

Source files contain marker comments defining sections to be replaced:

```powershell
# >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
# Simple development code with relative paths
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "../config/config.json"
# <<< BUILD-TIME-PATCH-END <<<
```

##### Build Phase

The build script detects markers and replaces the section with patched code:

```powershell
# Detect execution environment
$currentProcess = Get-Process -Id $PID
$isExecutable = $currentProcess.ProcessName -ne 'pwsh' -and $currentProcess.ProcessName -ne 'powershell'

if ($isExecutable) {
    # Get actual executable location
    $workingDir = Split-Path -Parent $currentProcess.Path
    $configPath = Join-Path $workingDir "config/config.json"
} else {
    # Use script location
    $configPath = Join-Path $PSScriptRoot "../config/config.json"
}
```

##### Production Phase

The patched code automatically detects the execution environment and resolves paths correctly:

### Entry Points Using Build-Time Patching

1. **`gui/ConfigEditor.ps1`** → `ConfigEditor.exe`
   - GUI configuration editor
   - Patches module loading and XAML file paths

2. **`src/Invoke-FocusGameDeck.ps1`** → `Invoke-FocusGameDeck.exe`
   - Game launcher engine
   - Patches module loading and configuration paths

### Patch Markers Reference

**Marker Format:**

```powershell
# >>> BUILD-TIME-PATCH-START: Description >>>
# Code to be replaced
# <<< BUILD-TIME-PATCH-END <<<
```

**Rules:**

- Markers must start at the beginning of a line
- Opening marker includes a description of what's being patched
- Closing marker must match exactly
- Everything between markers is replaced during build

### Build Script Patching Logic

The `Build-FocusGameDeck.ps1` script applies patches as follows:

1. Read source file content
2. Define patch code with environment detection
3. Use regex to replace content between markers
4. Save patched version to staging directory
5. Compile patched file with ps2exe

**Example from Build-FocusGameDeck.ps1:**

```powershell
# Read source file
$sourceContent = Get-Content $sourcePath -Raw -Encoding UTF8

# Define patch
$patchCode = @'
# >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
# Environment-aware path resolution code here
# <<< BUILD-TIME-PATCH-END <<<
'@

# Apply patch
$patchPattern = '(?s)# >>> BUILD-TIME-PATCH-START:.*?# <<< BUILD-TIME-PATCH-END <<<'
$patchedContent = $sourceContent -replace $patchPattern, $patchCode

# Save to staging
$patchedContent | Set-Content $stagingPath -Encoding UTF8
```

### Benefits of Build-Time Patching

1. **Single Source File**: No need to maintain separate `-Bundled.ps1` versions
2. **Development Simplicity**: Source files use simple relative paths
3. **Automatic Handling**: Build system handles environment differences
4. **Maintainability**: Changes only needed in one place
5. **No Runtime Overhead**: Path resolution logic embedded at compile time

### Adding New Entry Points with Patching

To add a new entry point that requires build-time patching:

1. **Add markers to source file:**

   ```powershell
   # >>> BUILD-TIME-PATCH-START: Path resolution for ps2exe bundling >>>
   $scriptDir = $PSScriptRoot
   $configPath = Join-Path $scriptDir "../config/config.json"
   # <<< BUILD-TIME-PATCH-END <<<
   ```

2. **Update Build-FocusGameDeck.ps1:**
   - Add patching logic for the new file
   - Define the patch code template
   - Include in the build workflow

3. **Test both modes:**

   ```powershell
   # Test script mode
   ./src/YourNewScript.ps1

   # Build and test executable mode
   ./build-tools/Build-FocusGameDeck.ps1 -Build
   ./build-tools/dist/YourNewScript.exe
   ```

### Troubleshooting Patching Issues

**Issue: Patch not applied:**

- Verify marker comments match exactly (including spaces and colons)
- Check regex pattern in build script
- Ensure file encoding is UTF-8

**Issue: Executable can't find resources:**

- Verify patch code uses `$currentProcess.Path` for executable location
- Check that resources are copied to distribution directory
- Test with explicit path logging to debug resolution

**Issue: Script mode broken after adding patches:**

- Ensure development code within markers still works
- Test script mode before and after build
- Verify module paths are correct for both modes

## Build Scripts Reference

### build-tools/Release-Manager.ps1

**Purpose**: Complete release workflow orchestration including build, signing, and distribution packaging for development and production releases.

**Note**: Despite the name suggesting only build functionality, this script orchestrates the entire release pipeline from compilation to distribution-ready packages.

**Location**: Moved to `build-tools/` directory for better organization of build-related scripts.

**Usage**:

```powershell
# Development build (no signing)
./build-tools/Release-Manager.ps1 -Development

# Production build (with signing)
./build-tools/Release-Manager.ps1 -Production

# Setup dependencies only
./build-tools/Release-Manager.ps1 -SetupOnly

# Clean all build artifacts
./build-tools/Release-Manager.ps1 -Clean

# Enable verbose logging
./build-tools/Release-Manager.ps1 -Development -Verbose
```

**Features**:

- Automated dependency installation (ps2exe module)
- Complete build workflow management
- Error handling and logging
- Build time tracking and reporting
- Release package generation

### Tool Scripts (Specialized Workers)

#### Install-BuildDependencies.ps1

**Purpose**: Manage build environment setup.

**Responsibility**: Checks for and installs required PowerShell modules (primarily ps2exe).

**Usage**:

```powershell
# Install dependencies
./build-tools/Install-BuildDependencies.ps1

# Force reinstall
./build-tools/Install-BuildDependencies.ps1 -Force

# Verbose output
./build-tools/Install-BuildDependencies.ps1 -Verbose
```

#### Embed-XamlResources.ps1

**Purpose**: Convert XAML UI files to embedded PowerShell string variables.

**Responsibility**: Reads all .xaml files from the gui/ directory and converts them into PowerShell Here-String format variables in src/generated/XamlResources.ps1. This eliminates external XAML file dependencies in production builds.

**Usage**:

```powershell
# Embed all XAML files
./build-tools/Embed-XamlResources.ps1

# Verbose output
./build-tools/Embed-XamlResources.ps1 -Verbose

# Custom output path
./build-tools/Embed-XamlResources.ps1 -OutputPath "custom/path/XamlResources.ps1"
```

**Features**:

- Converts XAML files to `$Global:Xaml_<FileName>` variables
- Automatically creates src/generated/ directory if needed
- Sanitizes variable names (replaces special characters with underscores)
- Generates UTF-8 encoded output with descriptive headers

**Note**: The generated XamlResources.ps1 file must be dot-sourced before loading ConfigEditor classes to enable embedded XAML mode. The ConfigEditor automatically falls back to file-based XAML loading in development mode when embedded variables are not available.

#### Invoke-PsScriptBundler.ps1

**Purpose**: Handle PowerShell script preprocessing and bundling.

**Responsibility**: Reads entry-point scripts, recursively resolves dot-sourced dependencies, and concatenates them into single flat .ps1 files.

**Usage**:

```powershell
# Bundle a script
./build-tools/Invoke-PsScriptBundler.ps1 -EntryPoint "gui/ConfigEditor.ps1" -OutputPath "build/ConfigEditor-bundled.ps1"

# With explicit project root
./build-tools/Invoke-PsScriptBundler.ps1 -EntryPoint "src/Invoke-FocusGameDeck.ps1" -OutputPath "build/Invoke-bundled.ps1" -ProjectRoot "C:/project"
```

#### Build-Executables.ps1

**Purpose**: Compile executables using ps2exe.

**Responsibility**: Takes bundled scripts as input and manages ps2exe compilation parameters for each target executable.

**Usage**:

```powershell
# Build all executables
./build-tools/Build-Executables.ps1

# Custom directories
./build-tools/Build-Executables.ps1 -BuildDir "custom/build" -OutputDir "custom/dist"

# Verbose output
./build-tools/Build-Executables.ps1 -Verbose
```

#### Copy-Resources.ps1

**Purpose**: Copy all non-executable assets.

**Responsibility**: Copies runtime files not compiled into executables (JSON files, documentation). Note that XAML files are no longer copied as they are embedded via Embed-XamlResources.ps1.

**Usage**:

```powershell
# Copy all resources
./build-tools/Copy-Resources.ps1

# Custom destination
./build-tools/Copy-Resources.ps1 -DestinationDir "custom/output"

# Verbose output
./build-tools/Copy-Resources.ps1 -Verbose
```

#### Create-Package.ps1

**Purpose**: Create the final distribution package.

**Responsibility**: Assembles all build artifacts into the release/ directory with documentation.

**Usage**:

```powershell
# Create release package
./build-tools/Create-Package.ps1

# Create signed package
./build-tools/Create-Package.ps1 -IsSigned

# With explicit version
./build-tools/Create-Package.ps1 -Version "3.0.0" -IsSigned
```

#### Build-FocusGameDeck.ps1 [DEPRECATED]

**Status**: Deprecated in favor of specialized tool scripts.

**Purpose**: Legacy monolithic build script (maintained for backward compatibility).

**Migration**:

- Use `Install-BuildDependencies.ps1` instead of `-Install`
- Use `Build-Executables.ps1` instead of `-Build`
- Use `Release-Manager.ps1 -Production` instead of `-All`

**Note**: This script displays a deprecation warning and will be removed in a future version.

**Generated Executables (v3.0+ Multi-Executable Bundle Architecture)**:

- `Focus-Game-Deck.exe` - Main router executable (console-based, ~30-40KB)
  - Lightweight entry point that delegates to specialized executables
  - Handles argument parsing and process routing
  - Sources from `src/Main-Router.ps1`

- `ConfigEditor.exe` - GUI configuration editor (no console, ~75-100KB)
  - Fully bundled WPF application for configuration management
  - Includes all GUI dependencies and XAML layouts
  - Sources from `gui/ConfigEditor.ps1`

- `Invoke-FocusGameDeck.exe` - Game launcher engine (console-based, ~60-80KB)
  - Core game launching and environment automation
  - Includes all game modules and integration managers
  - Sources from `src/Invoke-FocusGameDeck.ps1`

**Supporting Files** (required at runtime):

- `config/` - Configuration and messages files
- `localization/` - Language resource files
- `gui/` - XAML layouts and GUI helper scripts
- `src/modules/` - PowerShell modules for game launcher
- `scripts/` - Utility scripts (LanguageHelper.ps1)
- `build-tools/` - Version information

### Sign-Executables.ps1

**Purpose**: Digital signature management and certificate operations.

**Usage**:

```powershell
# List available code signing certificates
./Sign-Executables.ps1 -ListCertificates

# Test configured certificate
./Sign-Executables.ps1 -TestCertificate

# Sign all executables in build directory
./Sign-Executables.ps1 -SignAll

# Sign specific file
./Sign-Executables.ps1 -SignFile "path\to/executable.exe"
```

**Configuration** (`config/signing-config.json`):

```json
{
  "codeSigningSettings": {
    "enabled": true,
    "certificateThumbprint": "YOUR_CERTIFICATE_THUMBPRINT",
    "certificateStorePath": "Cert:/CurrentUser/My",
    "timestampServer": "http://timestamp.digicert.com",
    "hashAlgorithm": "SHA256",
    "description": "Focus Game Deck - Gaming Environment Optimization Tool"
  }
}
```

## Digital Signature Infrastructure

### Certificate Requirements

- **Type**: Code Signing Certificate (EV or OV)
- **Recommended Providers**: DigiCert, Sectigo, GlobalSign, Entrust
- **Key Usage**: Digital Signature, Key Encipherment
- **Extended Key Usage**: Code Signing

### Certificate Setup Process

1. **Obtain EV or OV Certificate**: Purchase from a trusted Certificate Authority
2. **Install Certificate**: Import into Windows Certificate Store (CurrentUser/My)
3. **Configure Thumbprint**: Update `certificateThumbprint` in signing-config.json
4. **Enable Signing**: Set `enabled: true` in configuration
5. **Test Setup**: Run `./Sign-Executables.ps1 -TestCertificate`

### Timestamp Servers

**Primary**: `http://timestamp.digicert.com`

**Fallback Options**:

- `http://timestamp.sectigo.com`
- `http://timestamp.globalsign.com/?signature=sha2`
- `http://timestamp.entrust.net/TSS/RFC3161sha2TS`

## Build Artifacts Structure (v3.0+)

```text
focus-game-deck/
├── build-tools/
│   ├── build/                       # Temporary build artifacts (auto-deleted after packaging)
│   │   ├── Focus-Game-Deck.exe     # Main router (30-40KB)
│   │   ├── ConfigEditor.exe        # GUI editor (75-100KB)
│   │   ├── Invoke-FocusGameDeck.exe # Game launcher (60-80KB)
│   │   ├── config/
│   │   │   ├── config.json
│   │   │   ├── messages.json
│   │   │   └── config.sample.json
│   │   ├── localization/
│   │   │   └── messages.json
│   │   ├── gui/                    # GUI support files for ConfigEditor.exe
│   │   │   ├── *.ps1 (helper scripts)
│   │   │   └── *.xaml (UI layouts)
│   │   ├── src/
│   │   │   └── modules/            # Game modules for Invoke-FocusGameDeck.exe
│   │   │       └── *.ps1
│   │   ├── scripts/
│   │   │   └── LanguageHelper.ps1
│   │   └── build-tools/
│   │       └── Version.ps1
│   └── dist/                        # Distribution-ready package (signed/unsigned)
│       ├── Focus-Game-Deck.exe     # Signed main router
│       ├── ConfigEditor.exe        # Signed GUI editor
│       ├── Invoke-FocusGameDeck.exe # Signed game launcher
│       ├── config/
│       ├── localization/
│       ├── gui/
│       ├── src/modules/
│       ├── scripts/
│       ├── build-tools/
│       └── signature-info.json     # Signature metadata (if signed)
└── release/                         # Final distribution package
    ├── Focus-Game-Deck.exe         # Main executable
    ├── ConfigEditor.exe            # GUI executable
    ├── Invoke-FocusGameDeck.exe    # Launcher executable
    ├── config/                     # Configuration files
    ├── localization/               # Language files
    ├── gui/                        # GUI support files
    ├── src/modules/                # Game modules
    ├── scripts/                    # Utility scripts
    ├── README.txt                  # Release documentation
    └── version-info.json           # Version and build metadata
```

**Key Changes in v3.0:**

- Three separate executables instead of one monolithic executable
- All executables are digitally signed
- Supporting files (config, gui, modules) are shared by all executables
- Smaller individual executable sizes, better memory efficiency
- Each executable only loads what it needs at runtime

## Development Workflow

### Quick Start

```powershell
# Complete development build (recommended)
./build-tools/Release-Manager.ps1 -Development

# This orchestrates:
# 1. Install-BuildDependencies.ps1  - Install ps2exe if needed
# 2. Build-Executables.ps1          - Build all executables
# 3. Copy-Resources.ps1             - Copy runtime resources
# 4. Create-Package.ps1             - Create release package (unsigned)
```

### Daily Development Build

```powershell
# Quick development build with verbose output
./build-tools/Release-Manager.ps1 -Development -Verbose

# Individual steps (for debugging):
./build-tools/Install-BuildDependencies.ps1  # Setup only
./build-tools/Build-Executables.ps1          # Build only
./build-tools/Copy-Resources.ps1             # Copy only
./build-tools/Create-Package.ps1             # Package only
```

### Production Release Build

```powershell
# Complete production build
./build-tools/Release-Manager.ps1 -Production

# This orchestrates:
# 1. Install-BuildDependencies.ps1  - Install ps2exe if needed
# 2. Build-Executables.ps1          - Build all executables
# 3. Copy-Resources.ps1             - Copy runtime resources
# 4. Sign-Executables.ps1           - Apply digital signatures (if configured)
# 5. Create-Package.ps1             - Create signed distribution package
```

### Workflow Visualization

```text
Development Build:
  Install → Build → Copy → Package

Production Build:
  Install → Build → Copy → Sign → Package

Setup Only:
  Install (stop)

Clean:
  Remove all artifacts
```

### Build Verification

After each build, verify the generated executables:

```powershell
# Check executable signatures
Get-AuthenticodeSignature "release/*.exe" | Format-Table Path, Status

# Test executable functionality
.\release/Focus-Game-Deck.exe --help
.\release/Focus-Game-Deck-Config-Editor.exe
```

## Troubleshooting

### Common Issues

#### ps2exe Module Installation Fails

**Error**: "Access denied" or "Module not found"

**Solution**:

```powershell
# Run PowerShell as Administrator
# Install manually:
Install-Module -Name ps2exe -Scope CurrentUser -Force
```

#### Certificate Not Found

**Error**: "Certificate not found with thumbprint"

**Solution**:

1. Run `./Sign-Executables.ps1 -ListCertificates`
2. Copy correct thumbprint to signing-config.json
3. Verify certificate has private key access

#### Build Artifacts Missing

**Error**: "Source directory not found" during release packaging

**Solution**:

```powershell
# Clean and rebuild:
./build-tools/Release-Manager.ps1 -Clean
./build-tools/Release-Manager.ps1 -Development
```

### Debug Mode

Enable verbose logging for detailed troubleshooting:

```powershell
./build-tools/Release-Manager.ps1 -Development -Verbose
```

This provides:

- Detailed step-by-step execution logging
- Error stack traces
- Build timing information
- File operation details

## Performance Considerations

### Build Time Optimization

- **Incremental Builds**: Only rebuild changed components
- **Parallel Processing**: Future enhancement for multi-component builds
- **Cache Management**: ps2exe compilation caching

### Resource Usage

- **Memory**: ~100MB peak during compilation
- **Disk Space**: ~5MB for build artifacts, ~2MB for release package
- **CPU**: Single-threaded ps2exe compilation

## Security Considerations

### Build Environment Security

- **Clean Build Environment**: Isolated from development tools
- **Certificate Protection**: Secure storage of signing certificates
- **Build Verification**: Automated signature and hash verification

### Supply Chain Security

- **Reproducible Builds**: Deterministic build process
- **Source Integrity**: Git commit hash tracking in build metadata
- **Distribution Integrity**: SHA256 checksums for all release artifacts

## Future Enhancements

### Planned Improvements

- **GitHub Actions Integration**: Automated CI/CD pipeline
- **Multi-Platform Builds**: Linux and macOS support
- **Build Caching**: Faster incremental builds
- **Automated Testing**: Pre-release functionality verification

### Configuration Extensions

- **Build Profiles**: Development, staging, production configurations
- **Plugin Architecture**: Extensible build steps
- **Custom Packaging**: Alternative distribution formats

## Related Documentation

- [DEVELOPER-RELEASE-GUIDE.md](./DEVELOPER-RELEASE-GUIDE.md) - Complete release process
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture overview
- [GITHUB-RELEASES-GUIDE.md](./GITHUB-RELEASES-GUIDE.md) - GitHub release management

---

**Last Updated**: November 16, 2025
**Version**: 3.0.0 - SRP Architecture Refactoring
**Maintainer**: Focus Game Deck Development Team
