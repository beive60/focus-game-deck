# Focus Game Deck

**Unified gaming environment automation for competitive PC gamers.**

Focus Game Deck automates your gaming session from start to finish - handling tedious environment setup before you play and automatically restoring everything when you're done. Let the tool handle the noise, so you can focus solely on winning.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](https://img.shields.io/github/v/release/beive60/focus-game-deck)](https://github.com/beive60/focus-game-deck/releases/latest)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)

<!-- TODO: Add demo -->

## Key Features

- **Automated Game Environments** - Custom environment setup/teardown for each game
- **Smart App Management** - Control any application with configurable startup/shutdown actions
- **Zero-Config Setup** - Intelligent defaults with optional GUI configuration
- **Robust Design** - Comprehensive validation and cleanup even if interrupted
- **Gaming Integrations** - Built-in support for OBS, VTube Studio, Discord (Coming Soon)
- **Secure Architecture** - Three separate, digitally signed executables ensure code integrity
- **Efficient Design** - Multi-executable architecture optimizes memory usage and startup time

## Quick Start

### 1. Launch Focus Game Deck

```bash
# Launch Focus Game Deck (GUI) (default)
Focus-Game-Deck.exe

# Launch configuration editor explicitly
Focus-Game-Deck.exe --config

# Launch a specific game directly
Focus-Game-Deck.exe <game-id>

# List all configured games
Focus-Game-Deck.exe --list

# Show help
Focus-Game-Deck.exe --help
```

### 2. Configure & Launch Games

- **First Launch**: On your first run, an interactive tutorial will guide you through the basic setup
- **Setup**: Configure your games using the GUI configuration editor (ConfigEditor.exe)
- **Launch**: Use command line or desktop shortcuts for one-click game launching
- **Alternative**: The main executable automatically routes to the appropriate component

### 3. Generate Shortcuts (Optional)

Generate `launch_[game-id].lnk` files for desktop shortcuts via the GUI settings panel.

## Architecture (v3.0+)

Focus Game Deck uses a secure multi-executable bundle architecture:

- **Focus-Game-Deck.exe** - Main router that delegates to specialized executables
- **ConfigEditor.exe** - GUI configuration editor (launched when you run Focus-Game-Deck.exe)
- **Invoke-FocusGameDeck.exe** - Game launcher engine (launched for game sessions)

All three executables are digitally signed to ensure code integrity. See [Architecture Documentation](docs/developer-guide/architecture.md) for details.

## Prerequisites

**Required:**

- Windows 10 (1903+) / Windows 11
- PowerShell 5.1+ (included with Windows)
- .NET Framework 4.7.2+ (included with Windows 10/11)

**Integration recommendations:**

- [OBS Studio](https://obsproject.com/) - start/stop replay buffer
- NoWinKey - disable Windows key during gaming

**Integrations you can configure yourself:**

- Discord, Clibor, AutoHotkey, [VTube Studio](https://denchisoft.com/)

## Documentation

| Document | Purpose |
|----------|---------|
| **[Configuration Guide](docs/user-guide/configuration.md)** | Complete setup and configuration instructions |
| **[Build System](docs/developer-guide/build-system.md)** | Development build system and security guidelines |
| **[Release Process](docs/developer-guide/release-process.md)** | Developer release workflow and procedures |
| **[Roadmap](docs/project-info/roadmap.md)** | Project timeline and planned features |
| **[All Documentation](docs/DOCUMENTATION-INDEX.md)** | Complete documentation index |

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for:

- Development environment setup
- Coding standards and guidelines
- Pull request process
- Issue reporting guidelines

## Security

This project follows security best practices with digitally signed releases and comprehensive security policies. See our [Security Policy](SECURITY.md) for details on:

- Supported versions
- Vulnerability reporting
- Security guidelines

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE.md) file for details.

## Show Your Support

If Focus Game Deck helps improve your gaming experience, we'd love to hear about it! Share your experience on social media with **`#FocusGameDeck`** - it motivates us to keep improving the tool.
