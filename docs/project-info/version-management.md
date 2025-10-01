# Focus Game Deck - Version Management Specification

## Overview

The Focus Game Deck project adopts **Semantic Versioning (SemVer 2.0.0)** to implement consistent version management.

## Versioning System

### Basic Format

```text
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

### Element Definitions

| Element | Description | Update Condition |
|---------|-------------|------------------|
| **MAJOR** | Major version | When introducing breaking changes |
| **MINOR** | Minor version | When adding features with backward compatibility |
| **PATCH** | Patch version | When fixing bugs with backward compatibility |
| **PRERELEASE** | Pre-release identifier | Identification for alpha/beta/RC versions |
| **BUILD** | Build metadata | Build-specific information (usually omitted) |

### Pre-release Version Naming Conventions

#### Alpha Version

- **Format**: `X.Y.Z-alpha[.N]`
- **Examples**: `1.0.0-alpha`, `1.0.0-alpha.1`, `1.0.0-alpha.2`
- **Purpose**: Internal testing, limited alpha testing period
- **Stability**: Unstable, incomplete features, breaking changes allowed

#### Beta Version

- **Format**: `X.Y.Z-beta[.N]`
- **Examples**: `1.0.0-beta`, `1.0.0-beta.1`, `1.0.0-beta.2`
- **Purpose**: Public beta testing, feedback collection
- **Stability**: Feature freeze, bug fixes only

#### Release Candidate (RC)

- **Format**: `X.Y.Z-rc[.N]`
- **Examples**: `1.0.0-rc.1`, `1.0.0-rc.2`
- **Purpose**: Final confirmation version before release
- **Stability**: Release quality, only critical issues fixed

## Release Cycle

### Alpha Testing Period (October 2025)

```text
1.0.0-alpha.1 → 1.0.0-alpha.2 → ... → 1.0.0-beta.1
```

### Beta Testing Period (Late October - Early November 2025)

```text
1.0.0-beta.1 → 1.0.0-beta.2 → ... → 1.0.0-rc.1
```

### Official Release (Late November - December 2025)

```text
1.0.0-rc.1 → 1.0.0-rc.2 → ... → 1.0.0
```

## Version Update Criteria

### MAJOR Version Update

- Major changes to configuration file format
- Deletion or major changes to existing APIs
- Major changes to system requirements
- Fundamental architectural changes

### MINOR Version Update

- Support for new game platforms
- Addition of new features (profile functionality, Discord integration, etc.)
- New language support
- Addition of configuration options (maintaining existing compatibility)

### PATCH Version Update

- Bug fixes
- Security patches
- Performance improvements
- Minor UI/UX improvements
- Stability improvements for existing features

## Tag Naming Conventions

### Release Tags

```text
v1.0.0          # Official release
v1.0.0-alpha.1  # Alpha version
v1.0.0-beta.1   # Beta version
v1.0.0-rc.1     # Release candidate
```

### Special Tags

```text
release/alpha-test    # Latest in alpha testing period
release/beta-test     # Latest in beta testing period
release/stable        # Latest stable version
```

## GitHub Releases Asset Naming Conventions

### Executable Files

```text
FocusGameDeck-v{VERSION}-Setup.exe
Examples: FocusGameDeck-v1.0.0-alpha.1-Setup.exe
Examples: FocusGameDeck-v1.0.0-Setup.exe
```

### Archive Files

```text
FocusGameDeck-v{VERSION}-Portable.zip
Examples: FocusGameDeck-v1.0.0-alpha.1-Portable.zip
Examples: FocusGameDeck-v1.0.0-Portable.zip
```

### Source Code

```text
focus-game-deck-{VERSION}.zip
focus-game-deck-{VERSION}.tar.gz
Examples: focus-game-deck-1.0.0-alpha.1.zip
Examples: focus-game-deck-1.0.0.tar.gz
```

## Implementation in Version.ps1

### Current Version Settings

```powershell
$script:ProjectVersion = @{
    Major = 1
    Minor = 0
    Patch = 1
    PreRelease = "alpha"  # "", "alpha", "beta", "rc.1", etc.
    Build = ""           # Build metadata (usually empty)
}
```

### Version String Retrieval

```powershell
Get-ProjectVersion                    # "1.0.1"
Get-ProjectVersion -IncludePreRelease # "1.0.1-alpha"
Get-ProjectVersion -IncludePreRelease -IncludeBuild # "1.0.1-alpha+20251024"
```

## Version History

### v1.0.1-alpha (Current)

- GUI configuration editor completed
- Japanese character encoding issues resolved
- Basic version management system implemented

### Planned Releases

#### v1.0.0-alpha.1 (Early October 2025)

- Alpha testing start version
- Digitally signed build
- Basic functionality completed

#### v1.0.0-beta.1 (Late October 2025)

- Public beta start
- Landing page publication
- Alpha testing feedback incorporated

#### v1.0.0 (Late November - December 2025)

- Official release
- Support for platforms other than Steam
- Setup wizard implementation

## Operation Guidelines

### Developer Guidelines

1. **Version Update Timing**
   - Update `Version.ps1` before committing feature additions/changes
   - Include version information in pull request titles

2. **Commit Message Conventions**

   ```text
   feat: When adding new features (MINOR++)
   fix: When fixing bugs (PATCH++)
   BREAKING CHANGE: When introducing breaking changes (MAJOR++)
   ```

3. **Release Creation Process**
   - Version update → Commit → Tag creation → GitHub Release creation
   - Write release notes in Changelog format
   - Publish only digitally signed assets

### Security and Compliance

- Apply digital signatures to all releases
- Include SHA256 hash values in release notes
- Issue emergency patch releases (PATCH++) when vulnerabilities are found
- Prioritize security updates for release

## Related Documentation

- [roadmap.md](/docs/project-info\roadmap.md) - Project roadmap
- [architecture.md](/docs/project-info/architecture.md) - Technical architecture
- [developer-release-guide.md](/docs/developer-guide\release-process.md) - Detailed release procedures

---

Last Updated: October 1, 2025
Version: 1.0.0
Created by: GitHub Copilot Assistant
