# Focus Game Deck - Build System Documentation

## Overview

The Focus Game Deck build system follows the **Single Responsibility Principle (SRP)** by separating build tasks into specialized tool scripts coordinated by a single orchestrator.

## Architecture

### Orchestrator

**`Release-Manager.ps1`** - The main orchestrator that manages the complete build workflow.

**Responsibility:** Coordinate the entire build pipeline by executing tool scripts in the correct sequence.

**Workflows:**

- **Development:** `Install Dependencies` → `Build Executables` → `Copy Resources` → `Create Package`
- **Production:** `Install Dependencies` → `Build Executables` → `Copy Resources` → `Sign Executables` → `Create Package`
- **Setup Only:** `Install Dependencies` (stop)
- **Clean:** Remove all build artifacts

**Usage:**

```powershell
# Development build (unsigned)
.\Release-Manager.ps1 -Development

# Production build (signed)
.\Release-Manager.ps1 -Production

# Setup environment only
.\Release-Manager.ps1 -SetupOnly

# Clean all artifacts
.\Release-Manager.ps1 -Clean

# Enable verbose logging
.\Release-Manager.ps1 -Development -Verbose
```

### Tool Scripts (Workers)

#### 1. Install-BuildDependencies.ps1

**Responsibility:** Manage build environment setup.

**Task:** Checks for and installs required PowerShell modules (primarily `ps2exe`).

**Usage:**

```powershell
# Install dependencies
.\Install-BuildDependencies.ps1

# Force reinstall
.\Install-BuildDependencies.ps1 -Force

# Verbose output
.\Install-BuildDependencies.ps1 -Verbose
```

#### 2. Invoke-PsScriptBundler.ps1

**Responsibility:** Handle PowerShell script preprocessing and bundling.

**Task:** Reads entry-point scripts, recursively resolves all dot-sourced dependencies, and concatenates them into a single flat `.ps1` file.

**Usage:**

```powershell
# Bundle a script
.\Invoke-PsScriptBundler.ps1 -EntryPoint "gui/ConfigEditor.ps1" -OutputPath "build/ConfigEditor-bundled.ps1"

# With explicit project root
.\Invoke-PsScriptBundler.ps1 -EntryPoint "src/Invoke-FocusGameDeck.ps1" -OutputPath "build/Invoke-FocusGameDeck-bundled.ps1" -ProjectRoot "C:/project"
```

**Why bundling?**

- Eliminates the need for `ps2exe`'s `-embedFiles` parameter
- Ensures all executable code is compiled into the final binary
- Simplifies dependency management

#### 3. Build-Executables.ps1

**Responsibility:** Compile executables using `ps2exe`.

**Task:** Takes bundled scripts as input and manages ps2exe compilation parameters for each target executable:

- `Focus-Game-Deck.exe`: Main router (console, no STA)
- `ConfigEditor.exe`: GUI editor (no console, STA)
- `Invoke-FocusGameDeck.exe`: Game launcher (console, no STA)

**Usage:**

```powershell
# Build all executables
.\Build-Executables.ps1

# Custom directories
.\Build-Executables.ps1 -BuildDir "custom/build" -OutputDir "custom/dist"

# Verbose output
.\Build-Executables.ps1 -Verbose
```

#### 4. Copy-Resources.ps1

**Responsibility:** Copy all non-executable assets.

**Task:** Copies runtime files that are not compiled into executables:

- Configuration files (`config.json`, `config.json.sample`)
- Localization files (`messages.json`)
- XAML UI files (`MainWindow.xaml`)
- Asset files (icons, images)
- Documentation (`README.md`, `LICENSE.md`)

**Usage:**

```powershell
# Copy all resources
.\Copy-Resources.ps1

# Custom destination
.\Copy-Resources.ps1 -DestinationDir "custom/output"

# Verbose output
.\Copy-Resources.ps1 -Verbose
```

#### 5. Sign-Executables.ps1

**Responsibility:** Apply digital signatures.

**Task:** Finds and signs all `.exe` files based on `signing-config.json`. Supports:

- Certificate listing and testing
- Individual file signing
- Batch signing of all executables
- Signature verification

**Usage:**

```powershell
# List available certificates
.\Sign-Executables.ps1 -ListCertificates

# Test certificate configuration
.\Sign-Executables.ps1 -TestCertificate

# Sign all executables
.\Sign-Executables.ps1 -SignAll

# Sign specific file
.\Sign-Executables.ps1 -SignFile "path/to/file.exe"
```

#### 6. Create-Package.ps1

**Responsibility:** Create the final distribution package.

**Task:** Assembles all build artifacts into the `release/` directory:

- Collects signed/unsigned executables
- Includes copied resources
- Generates package documentation (`README.txt`)
- Creates version information (`version-info.json`)

**Usage:**

```powershell
# Create release package
.\Create-Package.ps1

# Create signed package
.\Create-Package.ps1 -IsSigned

# With explicit version
.\Create-Package.ps1 -Version "3.0.0" -IsSigned

# Verbose output
.\Create-Package.ps1 -Verbose
```

## Build Workflow

### Development Build (Unsigned)

```architecture
Install-BuildDependencies.ps1
    ↓
Build-Executables.ps1
    ↓
Copy-Resources.ps1
    ↓
Create-Package.ps1
```

**Output:** Unsigned executables in `release/` directory

### Production Build (Signed)

```architecture
Install-BuildDependencies.ps1
    ↓
Build-Executables.ps1
    ↓
Copy-Resources.ps1
    ↓
Sign-Executables.ps1
    ↓
Create-Package.ps1
```

**Output:** Digitally signed executables in `release/` directory

## Directory Structure

```architecture
build-tools/
├── Release-Manager.ps1           # Orchestrator
├── Install-BuildDependencies.ps1 # Tool: Dependency installation
├── Invoke-PsScriptBundler.ps1   # Tool: Script bundling
├── Build-Executables.ps1         # Tool: Executable compilation
├── Copy-Resources.ps1            # Tool: Resource copying
├── Sign-Executables.ps1          # Tool: Code signing
├── Create-Package.ps1            # Tool: Package creation
├── Version.ps1                   # Helper: Version management
├── build/                        # Intermediate build files
├── dist/                         # Distribution staging
└── signing-config/               # Code signing configuration
```

## VS Code Integration

The build system integrates with VS Code tasks:

- `[SETUP] Install ps2exe Module`: Run `Install-BuildDependencies.ps1`
- `[SETUP] Build Environment Only`: Run `Release-Manager.ps1 -SetupOnly`
- `[BUILD] Development Build (unsigned)`: Run `Release-Manager.ps1 -Development`
- `[BUILD] Production Build (signed)`: Run `Release-Manager.ps1 -Production`
- `[BUILD] Executable Only`: Run `Build-Executables.ps1`
- `[CLEAN] Delete All Build Artifacts`: Run `Release-Manager.ps1 -Clean`
- `[SIGN] Sign Existing Build`: Run `Sign-Executables.ps1 -SignAll`

## Benefits of SRP Architecture

1. **Maintainability:** Each script has a single, well-defined responsibility
2. **Testability:** Individual components can be tested in isolation
3. **Reusability:** Tool scripts can be used independently or composed
4. **Clarity:** Clear separation of concerns makes the system easier to understand
5. **Flexibility:** Easy to modify individual components without affecting others
6. **Debugging:** Issues can be isolated to specific tool scripts

## Migration from Legacy Build Script

The monolithic `Build-FocusGameDeck.ps1` script has been deprecated. It contained multiple responsibilities:

- Installing dependencies
- Cleaning artifacts
- Building executables
- Copying resources
- Signing executables
- Creating packages

These have been separated into specialized tool scripts (see above).

### Migration Guide

| Legacy Command | New Command |
|----------------|-------------|
| `.\Build-FocusGameDeck.ps1 -Install` | `.\Install-BuildDependencies.ps1` |
| `.\Build-FocusGameDeck.ps1 -Build` | `.\Build-Executables.ps1` |
| `.\Build-FocusGameDeck.ps1 -Clean` | `.\Release-Manager.ps1 -Clean` |
| `.\Build-FocusGameDeck.ps1 -Sign` | `.\Sign-Executables.ps1 -SignAll` |
| `.\Build-FocusGameDeck.ps1 -All` | `.\Release-Manager.ps1 -Production` |

**Note:** `Build-FocusGameDeck.ps1` is maintained for backward compatibility but displays a deprecation warning and will be removed in a future version.

## Troubleshooting

### ps2exe Module Not Found

```powershell
.\Install-BuildDependencies.ps1
```

### Build Fails

1. Check verbose output: `.\Release-Manager.ps1 -Development -Verbose`
2. Verify environment: Run `[DEBUG] Check Build Environment` task
3. Clean and rebuild: `.\Release-Manager.ps1 -Clean` then `.\Release-Manager.ps1 -Development`

### Signing Fails

1. List certificates: `.\Sign-Executables.ps1 -ListCertificates`
2. Test certificate: `.\Sign-Executables.ps1 -TestCertificate`
3. Verify `signing-config.json` configuration

## Version History

- **v3.0.0** - Refactored to SRP architecture with specialized tool scripts
- **v2.x.x** - Multi-executable bundle architecture
- **v1.x.x** - Original monolithic build script

## Contributing

When contributing to the build system:

1. Follow SRP: Each script should have one responsibility
2. Use forward slashes (`/`) in paths for cross-platform compatibility
3. Include comprehensive help documentation (`.SYNOPSIS`, `.DESCRIPTION`, etc.)
4. Add verbose output for debugging
5. Handle errors gracefully with meaningful messages
6. Update this README when adding new tools or workflows

## References

- [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single-responsibility_principle)
- [ps2exe Documentation](https://github.com/MScholtes/PS2EXE)
- [PowerShell Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
