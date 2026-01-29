# Developer Release Process Guide

This comprehensive guide covers the complete release workflow for Focus Game Deck, from development to GitHub Releases management.

## Overview

This guide provides practical procedures for developers to execute version management and release processes. It covers all steps from daily development work to production release distribution.

## Quick Reference: Release Workflow

For experienced developers, here's the simplified workflow:

```powershell
# 1. Update version in build-tools/Version.ps1 (edit manually)
# 2. Create version tag and release notes
./scripts/Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes

# 3. Build release (choose one)
./build-tools/Release-Manager.ps1 -Development  # For testing
./build-tools/Release-Manager.ps1 -Production   # For official release (with signing)

# 4. Upload to GitHub Releases
```

## Prerequisites

### Required Tools

- **Git**: Version control and tag creation
- **PowerShell 5.1+**: Release management script execution
- **Visual Studio Code**: Recommended editor (optional)
- **Code Signing Certificate**: For digital signatures (production releases only)

### Two Release Manager Scripts

**Important**: This project has two different Release-Manager.ps1 scripts with distinct purposes:

| Script | Location | Purpose |
|--------|----------|---------|
| `scripts/Release-Manager.ps1` | Version management | Updates version, creates git tags, generates release notes |
| `build-tools/Release-Manager.ps1` | Build orchestration | Compiles executables, signs code, creates release packages |

## Daily Development Workflow

### 1. Pre-Development Checks

```powershell
# Update to latest state
git pull origin main

# Check current version
./scripts/Version-Helper.ps1 info

# Create working branch (if needed)
git checkout -b feature/new-feature
```

### 2. Commit Conventions

#### Commit Message Format

```text
<type>: <description>

[optional body]

[optional footer]
```

#### Commit Types

| Type | Description | Version Impact |
|------|-------------|----------------|
| `feat` | New feature addition | MINOR++ |
| `fix` | Bug fix | PATCH++ |
| `docs` | Documentation changes only | None |
| `style` | Code formatting (no functional changes) | None |
| `refactor` | Refactoring | PATCH++ |
| `test` | Test addition/modification | None |
| `chore` | Build/configuration changes | None |
| `BREAKING CHANGE` | Breaking changes | MAJOR++ |

## Release Process

### Phase 1: Release Preparation

#### 1. Pre-Release Checklist

```powershell
# Execute comprehensive validation
./scripts/Version-Helper.ps1 validate

# Verify the following items:
# [OK] Git repository is clean (no uncommitted changes)
# [OK] All tests passing
# [OK] Documentation is up to date
# [OK] build-tools/Version.ps1 contains correct current version
```

#### 2. Determine Next Version

```powershell
# Check next version options
./scripts/Version-Helper.ps1 next

# Sample output:
# Current version: 1.0.0
#
# Release options:
#   Major:  2.0.0
#   Minor:  1.1.0
#   Patch:  1.0.1
#
# Pre-release options:
#   Alpha:  1.0.1-alpha
#   Beta:   1.0.1-beta
#   RC:     1.0.1-rc
```

### Phase 2: Version Update and Tag Creation

#### Using the Version Release Manager (scripts/Release-Manager.ps1)

```powershell
# Check with DRY RUN first (no actual changes)
./scripts/Release-Manager.ps1 -UpdateType patch -DryRun

# Create actual release (updates version, creates tag, generates release notes)
./scripts/Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Patch release with bug fixes"
```

#### Release Type Examples

```powershell
# Alpha pre-release
./scripts/Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -CreateTag -GenerateReleaseNotes

# Beta pre-release
./scripts/Release-Manager.ps1 -UpdateType prerelease -PreReleaseType beta -CreateTag -GenerateReleaseNotes

# Patch release (bug fixes)
./scripts/Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes

# Minor release (new features)
./scripts/Release-Manager.ps1 -UpdateType minor -CreateTag -GenerateReleaseNotes

# Major release (breaking changes)
./scripts/Release-Manager.ps1 -UpdateType major -CreateTag -GenerateReleaseNotes
```

### Phase 3: Build Release Package

#### Using the Build Release Manager (build-tools/Release-Manager.ps1)

The build system uses specialized tool scripts orchestrated by Release-Manager.ps1:

```text
Release-Manager.ps1 (Orchestrator)
├── Install-BuildDependencies.ps1  (Tool: Dependency installation)
├── Embed-XamlResources.ps1        (Tool: XAML embedding)
├── Invoke-PsScriptBundler.ps1     (Tool: Script bundling)
├── Build-Executables.ps1          (Tool: Executable compilation)
├── Copy-Resources.ps1             (Tool: Resource copying)
├── Sign-Executables.ps1           (Tool: Code signing)
└── Create-Package.ps1             (Tool: Package creation)
```

#### Build Commands

```powershell
# Development build (no signing) - For testing
./build-tools/Release-Manager.ps1 -Development

# Production build (with signing) - For official releases
./build-tools/Release-Manager.ps1 -Production

# Setup only (install dependencies)
./build-tools/Release-Manager.ps1 -SetupOnly

# Clean all build artifacts
./build-tools/Release-Manager.ps1 -Clean

# Verbose logging for troubleshooting
./build-tools/Release-Manager.ps1 -Development -Verbose
```

#### Individual Tool Scripts (Advanced)

For fine-grained control, you can use individual tool scripts:

```powershell
# Install build dependencies (ps2exe module)
./build-tools/Install-BuildDependencies.ps1

# Embed XAML resources into PowerShell
./build-tools/Embed-XamlResources.ps1

# Bundle PowerShell scripts
./build-tools/Invoke-PsScriptBundler.ps1 -EntryPoint "gui/ConfigEditor.ps1" -OutputPath "build/ConfigEditor-bundled.ps1"

# Build executables
./build-tools/Build-Executables.ps1

# Copy runtime resources
./build-tools/Copy-Resources.ps1

# Sign executables (requires certificate)
./build-tools/Sign-Executables.ps1 -SignAll

# Create final package
./build-tools/Create-Package.ps1 -IsSigned
```

#### Build Output Structure

After a successful build:

```text
release/
├── Focus-Game-Deck.exe          # Main router executable
├── ConfigEditor.exe             # GUI configuration editor
├── Invoke-FocusGameDeck.exe     # Game launcher engine
├── config/                      # Configuration files
├── localization/                # Language files
├── README.txt                   # Release documentation
└── version-info.json            # Build metadata
```

### Phase 4: GitHub Release Creation

#### 1. Edit Release Notes

```powershell
# Edit the generated release notes file
code release-notes-1.0.1.md
```

#### 2. Create GitHub Release

1. Access GitHub Releases page: <https://github.com/beive60/focus-game-deck/releases>
2. Click "Create a new release"
3. Enter Release Information:

   ```text
   Tag: v1.0.1
   Release title: Focus Game Deck v1.0.1
   Description: [Copy content from generated release notes]
   ```

4. Upload Assets from `release/` directory:
   - `FocusGameDeck-v1.0.1-Portable.zip` (create from release folder)
   - `SHA256SUMS.txt` (generate checksums)

5. Release Settings:
   - Pre-release: Check for alpha/beta/RC versions
   - Set as latest release: Only for stable releases

## Complete Release Workflow Summary

Here's the complete workflow in order:

```powershell
# Step 1: Ensure clean working directory
git status
git pull origin main

# Step 2: Run validation
./scripts/Version-Helper.ps1 validate

# Step 3: Update version and create tag
./scripts/Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Release description"

# Step 4: Build release package
./build-tools/Release-Manager.ps1 -Production

# Step 5: Verify build
Get-AuthenticodeSignature release/*.exe | Format-Table Path, Status

# Step 6: Create GitHub Release and upload assets
```

## Emergency Response

### Hotfix Release

```powershell
# Emergency bug fix release
./scripts/Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Hotfix for critical issue"
./build-tools/Release-Manager.ps1 -Production

# Immediately create GitHub Release and notify users
```

### Release Rollback

1. Change GitHub Release to "Draft"
2. Remove problematic assets
3. Publish downgrade instructions to previous version

## Troubleshooting

### Common Issues and Solutions

#### 1. Version.ps1 Update Fails

```powershell
# Error: 'Access to the path is denied'
# Solution: Run PowerShell with administrator privileges

# Error: Version file validation failed
# Solution: Check syntax errors in Version.ps1
pwsh -File build-tools/Version.ps1  # Syntax check
```

#### 2. Git Tag Creation Fails

```powershell
# Error: 'tag already exists'
# Solution: Delete existing tag
git tag -d v1.0.1        # Delete local tag
git push origin :v1.0.1  # Delete remote tag

# Error: 'not a git repository'
# Solution: Execute in project root directory
```

#### 3. Build Fails

```powershell
# Clean and rebuild
./build-tools/Release-Manager.ps1 -Clean
./build-tools/Release-Manager.ps1 -Development -Verbose
```

## Best Practices

### 1. Pre-Release Quality Assurance

- [ ] Execute and pass all automated tests
- [ ] Execute manual test cases
- [ ] Verify documentation updates
- [ ] Run security scans

### 2. Staged Release Strategy

```text
Development → Alpha → Beta → RC → Official
     ↓         ↓      ↓     ↓      ↓
  Internal  Limited Public Final General
  Testing   Testers Beta  Check Release
```

### 3. Security Focus

- Digital signatures mandatory for production releases
- SHA256 checksums publication mandatory
- Rapid response system for vulnerability reports

## Related Documentation

- [Version Management](../project-info/version-management.md) - Semantic versioning specification
- [Build System](build-system.md) - Build infrastructure details
- [Architecture Guide](architecture.md) - Technical architecture

---

**Last Updated**: January 2026
**Version**: 2.0.0 - Simplified workflow documentation
**Created by**: GitHub Copilot Assistant
