# **Focus Game Deck 🚀**

[日本語](./README.JP.md) | **English**

**A PowerShell script that automates your gaming sessions from start to finish, designed for competitive PC gamers.**

This script handles the tedious environment setup before you start playing (disabling hotkeys, closing background apps, etc.) and automatically restores everything after you're done. This lets you focus solely on your gameplay.

## **✨ Features**

* **🎮 Automated Game-Specific Environments**: Automatically sets up and tears down a custom environment for each game based on your configuration.
* **🔧 Generic Application Management**: Flexibly control any application with configurable startup and shutdown actions.
* **🔄 Easy Extensibility**: Add new applications to manage by simply editing the configuration file - no code changes required.
* **🛡️ Robust Design**: Includes comprehensive configuration validation and a cleanup process that ensures your environment is restored to normal even if the script is interrupted (e.g., with Ctrl+C).
* **⚙️ Special Integrations**: Built-in support for:
  * **Clibor**: Toggles hotkeys on/off.
  * **NoWinKey**: Disables the Windows key to prevent accidental presses.
  * **AutoHotkey**: Stops running scripts and resumes them after the game closes.
  * **OBS Studio**: Launches OBS and automatically starts/stops the replay buffer when your game starts/ends.

## **🛠️ Prerequisites**

To use this script, you will need the following software installed:

* **PowerShell**: Comes standard with Windows.
* **Steam**
* **OBS Studio**: [Official Website](https://obsproject.com/)
  * **obs-websocket plugin**: Included by default in OBS v28 and later. Please ensure it is enabled in the settings.
* **\[Optional\] Clibor**: A clipboard utility.
* **\[Optional\] NoWinKey**: A tool to disable the Windows key.
* **\[Optional\] AutoHotkey**: A scripting language for automation.
* **\[Optional\] Luna**: (Or any other background application you wish to manage).

## **💻 Installation Options**

Focus Game Deck offers flexible installation methods to suit different user preferences:

### **Option 1: Executable Distribution (Recommended)**

Download pre-built, digitally signed executables from [GitHub Releases](https://github.com/beive60/focus-game-deck/releases):

* **Focus-Game-Deck.exe** - Main application (single-file, no PowerShell required)
* **Focus-Game-Deck-Config-Editor.exe** - GUI configuration editor
* **Focus-Game-Deck-MultiPlatform.exe** - Extended platform support version

**Benefits:**

* ✅ No PowerShell execution policy issues
* ✅ Digitally signed for security and trust
* ✅ Single-file distribution
* ✅ Works on systems with restricted PowerShell policies

### **Option 2: PowerShell Script (Development/Advanced Users)**

Clone or download the repository for direct PowerShell execution:

```bash
git clone https://github.com/beive60/focus-game-deck.git
cd focus-game-deck
```

**Benefits:**

* ✅ Full source code visibility
* ✅ Easy customization and modification
* ✅ Access to latest development features

## **🏗️ Architecture & Design**

Focus Game Deck is built with a **lightweight, maintainable, and extensible** design philosophy:

### **Core Principles**

* **🪶 Lightweight**: Uses Windows native PowerShell + WPF, no additional runtime required
* **🔧 Configuration-Driven**: All behavior controlled through `config.json` - no code changes needed for customization
* **🌐 Internationalization-Ready**: JSON external resource pattern for proper Japanese character support
* **📦 Single-File Distribution**: Can be compiled to a single executable using ps2exe

### **Technical Stack**

* **Core Engine**: PowerShell scripts with comprehensive error handling
* **GUI Module**: PowerShell + WPF with JSON-based internationalization
* **Configuration**: JSON-based settings with validation and sample templates
* **Integration**: Native Windows APIs and application-specific protocols

For detailed architectural information, see [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

### **Build System & Distribution**

Focus Game Deck features a comprehensive three-tier build system:

* **📦 Automated Executable Generation**: ps2exe-based compilation to standalone executables
* **🔐 Digital Signature Infrastructure**: Extended Validation certificate support with automated signing
* **🚀 Production-Ready Pipeline**: Complete development and production build workflows
* **📋 Release Package Management**: Automated signed distribution package creation

**Build Scripts:**

* `Master-Build.ps1` - Complete build orchestration (development/production workflows)
* `Build-FocusGameDeck.ps1` - Core executable generation and build management
* `Sign-Executables.ps1` - Digital signature management and certificate operations

For detailed build system documentation, see [docs/BUILD-SYSTEM.md](./docs/BUILD-SYSTEM.md).

## **🚀 Setup & Configuration**

1. **Download the Repository**: Clone or download this repository as a ZIP file.
2. **Create Your Configuration File**:
   * Make a copy of config.json.sample and rename the copy to config.json in the same directory.
3. **Edit config.json**:
   * Open config.json in a text editor and update the paths and settings to match your system.

```json
{
      "obs": {
          "websocket": {
              "host": "localhost",
              "port": 4455,
              "password": "" // Set your OBS WebSocket server password here
          },
          "replayBuffer": true
      },
      "managedApps": {
          "noWinKey": {
              "path": "C:\\\\Apps\\\\NoWinKey\\\\NoWinKey.exe",
              "processName": "NoWinKey",
              "startupAction": "start",
              "shutdownAction": "stop",
              "arguments": ""
          },
          "autoHotkey": {
              "path": "",
              "processName": "AutoHotkeyU64|AutoHotkey|AutoHotkey64",
              "startupAction": "stop",
              "shutdownAction": "start",
              "arguments": ""
          },
          "clibor": {
              "path": "C:\\\\Apps\\\\clibor\\\\Clibor.exe",
              "processName": "Clibor",
              "startupAction": "none",
              "shutdownAction": "none",
              "arguments": "/hs"
          },
          "luna": {
              "path": "",
              "processName": "Luna",
              "startupAction": "stop",
              "shutdownAction": "none",
              "arguments": ""
          }
      },
      "games": {
          "apex": { // ← "apex" is the GameId
              "name": "Apex Legends",
              "steamAppId": "1172470", // Find this in the Steam store page URL
              "processName": "r5apex\*", // Check this in Task Manager (wildcard \* is supported)
              "appsToManage": ["noWinKey", "autoHotkey", "luna", "obs", "clibor"]
          },
          "dbd": {
              "name": "Dead by Daylight",
              "steamAppId": "381210",
              "processName": "DeadByDaylight-Win64-Shipping\*",
              "appsToManage": ["obs", "clibor"]
          }
          // ... Add other games here ...
      },
      "paths": {
          // ↓↓↓ Change these to the correct executable paths on your PC ↓↓↓
          "steam": "C:\\\\Program Files (x86)\\\\Steam\\\\steam.exe",
          "obs": "C:\\\\Program Files\\\\obs-studio\\\\bin\\\\64bit\\\\obs64.exe"
      }
  }
```

* **managedApps**:
* Define all applications you want to manage. Each app has:
  * `path`: Full path to the executable (can be empty if only process management is needed)
  * `processName`: Process name for stopping (supports wildcards with |)
  * `startupAction`: Action when game starts ("start", "stop", or "none")
  * `shutdownAction`: Action when game ends ("start", "stop", or "none")
  * `arguments`: Optional command line arguments
* **games**:
* Add entries for the games you want to manage. The key (e.g., "apex", "dbd") will be used as the \-GameId parameter later.
* Set the `appsToManage` array to specify which applications should be managed for each game.
* **paths**:
* Set paths for Steam and OBS. Other application paths are now defined in `managedApps`.

## **🎬 How to Use**

### **Using Executable Version (Recommended)**

Simply run the executable from command prompt or PowerShell:

```cmd
# Command Prompt
Focus-Game-Deck.exe apex

# PowerShell
.\Focus-Game-Deck.exe apex
```

### **Using PowerShell Script Version**

Open a PowerShell terminal, navigate to the script's directory, and run the following command:

```powershell
# Example: To launch Apex Legends
.\Invoke-FocusGameDeck.ps1 -GameId apex

# Example: To launch Dead by Daylight
.\Invoke-FocusGameDeck.ps1 -GameId dbd
```

### **General Usage Notes**

* Specify the GameId you configured in config.json (e.g., "apex", "dbd") as the parameter.
* The application will automatically apply your configured settings and launch the game via Steam.
* Once you exit the game, the application will detect the process has ended and automatically restore your environment to its original state.
* **GUI Configuration**: Use `Focus-Game-Deck-Config-Editor.exe` for user-friendly configuration editing.

## **➕ Adding New Applications**

The new architecture makes it extremely easy to add new applications to manage. Simply add them to the `managedApps` section:

```json
{
  "managedApps": {
    "discord": {
      "path": "C:\\Users\\Username\\AppData\\Local\\Discord\\app-1.0.9012\\Discord.exe",
      "processName": "Discord",
      "startupAction": "stop",
      "shutdownAction": "start",
      "arguments": ""
    },
    "spotify": {
      "path": "C:\\Users\\Username\\AppData\\Roaming\\Spotify\\Spotify.exe",
      "processName": "Spotify",
      "startupAction": "stop",
      "shutdownAction": "none",
      "arguments": ""
    }
  },
  "games": {
    "apex": {
      "appsToManage": ["noWinKey", "autoHotkey", "discord", "spotify", "obs", "clibor"]
    }
  }
}
```

**That's it!** No PowerShell script changes required. The system automatically handles any application defined in `managedApps`.

## **🔧 Troubleshooting**

1. **If the script fails to execute:**
   * Check PowerShell execution policy
   * Try running with administrator privileges

2. **If processes fail to stop/start:**
   * Verify path settings are correct in `managedApps`
   * Ensure applications are properly installed
   * Check that process names are correct (use Task Manager to verify)

3. **If the game doesn't launch:**
   * Verify the Steam AppID is correct
   * Ensure Steam is running

4. **If OBS replay buffer doesn't start:**
   * Verify OBS WebSocket server is enabled
   * Check WebSocket settings (host, port, password) are correct
   * Ensure replay buffer is configured in OBS

5. **Configuration validation errors:**
   * Check that all referenced applications in `appsToManage` exist in `managedApps`
   * Ensure required properties (path, processName, startupAction, shutdownAction) are present
   * Verify action values are one of: "start", "stop", "none"

## **📜 License**

This project is licensed under the **MIT License**. See the LICENSE file for details.

## ❤️ Show Your Support

My sincere hope is that this tool makes your competitive gaming experience more comfortable and focused.

If you enjoy using it, I would be incredibly grateful if you could share that you're using it on social media like X.com (formerly Twitter). Your voice helps other gamers who might be looking for a similar solution.

When you do, feel free to use the hashtag **`#GameLauncherWatcher`**. It would be a great joy for me to see your post!

Knowing that the tool is helping people is the single biggest motivation to keep improving it.

## **🗺️ Project Roadmap**

Want to see what's coming next? Check out our [detailed roadmap](./docs/ROADMAP.md) to see planned features, timeline, and the strategic vision for Focus Game Deck's future development.

## **📦 Version Management & Releases**

Focus Game Deck follows **[Semantic Versioning](https://semver.org/)** (SemVer) for consistent version management.

### Current Version

**v1.2.0** - Build system and digital signature infrastructure completed

### Release Channels

* **Alpha**: Limited testing releases for core functionality validation
* **Beta**: Public beta testing for broader feedback
* **Stable**: Production-ready releases for all users

### For Developers

If you're contributing to the project, check out our comprehensive documentation:

* **[Architecture & Implementation Guidelines](./docs/ARCHITECTURE.md)** - **Character encoding best practices**, technical architecture, and development standards
* **[Version Management Specification](./docs/VERSION-MANAGEMENT.md)** - SemVer implementation details
* **[GitHub Releases Guide](./docs/GITHUB-RELEASES-GUIDE.md)** - Release operation procedures
* **[Developer Release Guide](./docs/DEVELOPER-RELEASE-GUIDE.md)** - Step-by-step release process

> **⚠️ Important for Contributors**: Character encoding issues have been a recurring challenge in this project. Please review the [Character Encoding Guidelines](./docs/ARCHITECTURE.md#character-encoding-and-console-compatibility-guidelines) before making code contributions.

### Download & Installation

* **Latest Release**: Available from [GitHub Releases](https://github.com/beive60/focus-game-deck/releases/latest)
* **Executable Versions**: Pre-built, signed executables ready for immediate use
* **Source Code**: Complete PowerShell source code for developers and advanced users
* **Security**: All releases are digitally signed with Extended Validation certificates for maximum trust
* **Build System**: Complete automated build and signing infrastructure implemented
