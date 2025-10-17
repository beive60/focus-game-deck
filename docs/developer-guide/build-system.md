# Focus Game Deck - Build System Documentation

## Overview

This document describes the comprehensive build system implemented for Focus Game Deck, including executable generation, digital signature infrastructure, and automated release packaging.

## Configuration File Security

### Sensitive Data Management

**CRITICAL SECURITY NOTICE**: Configuration files containing sensitive information (passwords, API keys, certificates) are excluded from version control to prevent accidental exposure.

## Build System Architecture

### Three-Tier Build System

The build system consists of three tiers, each with specific responsibilities:

1. **Individual Component Builds** - Single-purpose scripts for specific components
2. **Integrated Build Scripts** - Orchestrate multiple components
3. **Master Build Orchestration** - Complete workflow management

```text
Master-Build.ps1 (Tier 3: Orchestration)
├── build-tools/
│   ├── Build-FocusGameDeck.ps1 (Tier 2: Integration)
│   │   ├── ps2exe compilation for main applications
│   │   ├── Configuration file management
│   │   └── Build artifact organization
│   └── Sign-Executables.ps1 (Tier 2: Security)
│       ├── Certificate validation and management
│       ├── Automated code signing
│       └── Signature verification
└── Release package generation
    ├── Distribution directory creation
    ├── Documentation generation
    └── Version metadata creation
```

## Build Scripts Reference

### Master-Build.ps1

**Purpose**: Complete build workflow orchestration for development and production releases.

**Usage**:

```powershell
# Development build (no signing)
./Master-Build.ps1 -Development

# Production build (with signing)
./Master-Build.ps1 -Production

# Setup dependencies only
./Master-Build.ps1 -SetupOnly

# Clean all build artifacts
./Master-Build.ps1 -Clean

# Enable verbose logging
./Master-Build.ps1 -Development -Verbose
```

**Features**:

- Automated dependency installation (ps2exe module)
- Complete build workflow management
- Error handling and logging
- Build time tracking and reporting
- Release package generation

### Build-FocusGameDeck.ps1

**Purpose**: Core executable generation and build artifact management.

**Usage**:

```powershell
# Install ps2exe module
./build-tools/Build-FocusGameDeck.ps1 -Install

# Build all executables
./build-tools/Build-FocusGameDeck.ps1 -Build

# Sign existing build
./build-tools/Build-FocusGameDeck.ps1 -Sign

# Clean build artifacts
./build-tools/Build-FocusGameDeck.ps1 -Clean

# Complete workflow (install, build, sign)
./build-tools/Build-FocusGameDeck.ps1 -All
```

**Generated Executables**:

- `Focus-Game-Deck.exe` - Main application (console-based, ~36KB)
- `Focus-Game-Deck-MultiPlatform.exe` - Multi-platform version (~37KB)
- `Focus-Game-Deck-Config-Editor.exe` - GUI configuration editor (~75KB)

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

## Build Artifacts Structure

```text
focus-game-deck/
├── build/                           # Build artifacts (unsigned)
│   ├── Focus-Game-Deck.exe
│   ├── Focus-Game-Deck-MultiPlatform.exe
│   ├── Focus-Game-Deck-Config-Editor.exe
│   ├── launcher.bat
│   └── config/
│       ├── config.json
│       ├── messages.json
│       └── config.sample.json
├── signed/                          # Signed executables (production)
│   ├── [same structure as build/]
│   └── signature-info.json         # Signature metadata
└── release/                         # Final distribution package
    ├── [executable files]
    ├── README.txt                   # Release documentation
    └── version-info.json            # Version and build metadata
```

## Development Workflow

### Daily Development Build

```powershell
# Quick development build
./Master-Build.ps1 -Development

# This will:
# 1. Install ps2exe if needed
# 2. Build all executables
# 3. Create release package (unsigned)
# 4. Generate build report
```

### Production Release Build

```powershell
# Complete production build
./Master-Build.ps1 -Production

# This will:
# 1. Install ps2exe if needed
# 2. Build all executables
# 3. Apply digital signatures (if configured)
# 4. Create signed distribution package
# 5. Generate signature verification report
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
./Master-Build.ps1 -Clean
./Master-Build.ps1 -Development
```

### Debug Mode

Enable verbose logging for detailed troubleshooting:

```powershell
./Master-Build.ps1 -Development -Verbose
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

**Last Updated**: September 24, 2025
**Version**: 1.2.0
**Maintainer**: Focus Game Deck Development Team
