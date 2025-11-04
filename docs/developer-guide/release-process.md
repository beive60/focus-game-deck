# Developer Release Process Guide

This comprehensive guide covers the complete release workflow for Focus Game Deck, from development to GitHub Releases management.

## Overview

This guide provides practical procedures for developers to execute version management and release processes. It covers all steps from daily development work to production release distribution.

## Prerequisites

### Required Tools

- **Git**: Version control and tag creation
- **PowerShell 5.1+**: Release management script execution
- **Visual Studio Code**: Recommended editor (optional)
- **Code Signing Certificate**: For digital signatures (release only)

### Configuration File Security

**SECURITY REMINDER**: Before building releases, ensure:

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

### 2. Commit Conventions During Development

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

#### Commit Examples

```bash
# New feature addition
git commit -m "feat: add Discord integration for game status updates

- Implement Discord Rich Presence API integration
- Add configuration options for Discord features
- Update GUI to include Discord settings tab"

# Bug fix
git commit -m "fix: resolve config file encoding issue on Japanese Windows

- Fix UTF-8 BOM handling in config parser
- Add fallback encoding detection
- Update error messages for better user experience"

# Breaking change
git commit -m "feat: redesign configuration file structure

BREAKING CHANGE: Configuration file format has changed from JSON to YAML.
Users need to migrate their existing config.json files using the provided
migration tool."
```

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
# [OK] Version.ps1 contains correct current version
```

#### 2. Determine Next Version

```powershell
# Check next version options
./scripts/Version-Helper.ps1 next

# Sample output:
# Current version: 1.0.1-alpha
#
# Release options:
#   Major:  2.0.0
#   Minor:  2.1.0
#   Patch:  2.0.2
#
# Pre-release options:
#   Alpha:  2.0.2-alpha
#   Beta:   2.0.2-beta
#   RC:     2.0.2-rc
```

### Phase 2: Version Update and Tag Creation

#### Alpha Release Example

```powershell
# Check with DRY RUN (no actual changes)
./scripts\Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -DryRun

# Create actual release (generate tag and release notes)
./scripts\Release-Manager.ps1 -UpdateType prerelease -PreReleaseType alpha -CreateTag -GenerateReleaseNotes -ReleaseMessage "Alpha release for testing core functionality"
```

#### Patch Release Example

```powershell
# Bug fix release
./scripts\Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Patch release with critical bug fixes"
```

#### Major Release Example

```powershell
# Official release
./scripts\Release-Manager.ps1 -UpdateType minor -CreateTag -GenerateReleaseNotes -ReleaseMessage "Official v1.1.0 release with new platform support"
```

### Phase 3: GitHub Release Creation

#### 1. Edit Release Notes

```powershell
# Edit the generated release notes file
# Example: release-notes-1.0.2-alpha.md
code release-notes-1.0.2-alpha.md
```

#### 2. Build and Asset Preparation

##### Generate Executables and Digital Signing

```powershell
# Development build (unsigned)
./Release-Manager.ps1 -Development

# Production build (signed) *Requires certificate setup
./Release-Manager.ps1 -Production

# Individual build operations
./build-tools/Build-FocusGameDeck.ps1 -Install    # Install ps2exe module
./build-tools/Build-FocusGameDeck.ps1 -Build      # Generate executables
./build-tools/Build-FocusGameDeck.ps1 -Sign       # Apply signatures to existing builds
./build-tools/Build-FocusGameDeck.ps1 -Clean      # Clean up build artifacts

# Individual digital signing operations
./Sign-Executables.ps1 -ListCertificates    # List available certificates
./Sign-Executables.ps1 -TestCertificate     # Test configured certificate
./Sign-Executables.ps1 -SignAll             # Sign all executables
```

**Generated Executables**:

- `Focus-Game-Deck.exe` - Application

**Signing Configuration** (`config/signing-config.json`):

```json
{
  "codeSigningSettings": {
    "enabled": true,
    "certificateThumbprint": "YOUR_CERTIFICATE_THUMBPRINT",
    "timestampServer": "http://timestamp.digicert.com"
  }
}
```

#### 3. GitHub Release Creation Steps

1. Access GitHub Releases page
   - <https://github.com/beive60/focus-game-deck/releases>
2. Click "Create a new release"
3. Enter Release Information

   ```text
   Tag: v1.0.2-alpha.1
   Release title: Focus Game Deck v1.0.2-alpha.1 - Alpha Test Release
   Description: [Copy content from generated release notes]
   ```

4. Upload Assets
   - `FocusGameDeck-v1.0.2-alpha.1-Setup.exe`
   - `FocusGameDeck-v1.0.2-alpha.1-Portable.zip`
   - `SHA256SUMS.txt`
5. Release Settings
   - Pre-release: [OK] (for alpha/beta/RC versions)
   - Set as latest release: (official versions only)

## Emergency Response

### Hotfix Release

```powershell
# Emergency bug fix release
./scripts\Release-Manager.ps1 -UpdateType patch -CreateTag -GenerateReleaseNotes -ReleaseMessage "Hotfix for critical security vulnerability"

# Immediately create GitHub Release and notify users
```

### Release Rollback

```powershell
# Withdraw problematic release
# 1. Change GitHub Release to "Draft"
# 2. Remove problematic assets
# 3. Publish downgrade instructions to previous version
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Version.ps1 Update Fails

```powershell
# Error: 'Access to the path is denied'
# Solution: Run PowerShell with administrator privileges

# Error: Version file validation failed
# Solution: Check syntax errors in Version.ps1
PowerShell -File Version.ps1  # Syntax check
```

#### 2. Git Tag Creation Fails

```powershell
# Error: 'tag already exists'
# Solution: Delete existing tag or use different name
git tag -d v1.0.2-alpha.1        # Delete local tag
git push origin :v1.0.2-alpha.1  # Delete remote tag

# Error: 'not a git repository'
# Solution: Execute in project root directory
cd C:/path\to/focus-game-deck
```

#### 3. Release Notes Generation Fails

```powershell
# Manually create release notes
$template = Get-Content "docs\RELEASE-NOTES-TEMPLATE.md"
$template -replace "{VERSION}", "1.0.2-alpha.1" | Out-File "release-notes-1.0.2-alpha.1.md"
```

## Best Practices

### 1. Pre-Release Quality Assurance

- [ ] Execute and pass all automated tests
- [ ] Execute manual test cases
- [ ] Verify documentation updates
- [ ] Run security scans
- [ ] Execute performance tests

### 2. Staged Release Strategy

```text
Development → Alpha → Beta → RC → Official
     ↓         ↓      ↓     ↓      ↓
   Internal  Limited Public Final General
   Testing   Testers Beta  Check Release
```

### 3. Communication

- **Alpha**: Tester-limited private channels
- **Beta**: GitHub Issues + landing page
- **Official**: Official announcements + social media

### 4. Security Focus

- Digital signatures mandatory for all releases
- SHA256 checksums publication mandatory
- Rapid response system for vulnerability reports

## Future Automation Plans

### GitHub Actions Integration (Future)

```yaml
# .github/workflows/release.yml (example)
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  build-and-release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Assets
        run: ./build/Create-All-Assets.ps1
      - name: Create Release
        uses: actions/create-release@v1
        # ... omitted
```

## References

### Related Documentation

- [VERSION-MANAGEMENT.md](/docs/project-info/version-management.md) - Semantic versioning specification
- [release-process.md)](/docs/developer-guide/release-process.md) - GitHub Releases operation rules
- [architecture.md](/docs/developer-guide/architecture.md) - Technical architecture
- [roadmap.md](/docs/project-info/roadmap.md) - Project roadmap

### External Resources

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

---

**Last Updated**: September 28, 2025
**Version**: 1.1.0
**Created by**: GitHub Copilot Assistant
