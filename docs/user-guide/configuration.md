# Focus Game Deck - Configuration Guide

**Complete setup and configuration guide for Focus Game Deck**

This document provides detailed instructions for configuring Focus Game Deck to work with your specific gaming environment and applications.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration File Structure](#configuration-file-structure)
- [Managed Applications](#managed-applications)
- [Game Configuration](#game-configuration)
- [Path Settings](#path-settings)
- [Logging Configuration](#logging-configuration)
- [Advanced Configuration](#advanced-configuration)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Choose Configuration Method

**Option A: GUI Configuration Editor (Recommended)**

- Run `Focus-Game-Deck-Config-Editor.exe`
- Use the intuitive interface to configure all settings
- Automatically generates valid `config.json`

**Option B: Manual Configuration**

- Copy `config/config.json.sample` to `config/config.json`
- Edit the file following this guide

### 2. Essential Configuration Steps

1. **Set up your games** (Steam AppIDs, process names)
2. **Configure managed applications** (paths, actions)
3. **Set platform launcher paths** (Steam, Epic, etc.)
4. **Test with a simple game** before full setup

## Configuration File Structure

The `config.json` file has the following main sections:

```json
{
    "language": "",              // UI language (optional)
    "obs": { ... },             // OBS Studio integration
    "managedApps": { ... },     // Applications to manage
    "games": { ... },           // Game definitions
    "paths": { ... },           // Platform launcher paths
    "logging": { ... }          // Logging configuration
}
```

## Managed Applications

Define all applications you want Focus Game Deck to control during gaming sessions.

### Basic Structure

```json
"managedApps": {
    "appName": {
        "path": "C:/Path/To/Application.exe",
        "processName": "ProcessName",
        "gameStartAction": "action-when-game-starts",
        "gameEndAction": "action-when-game-ends",
        "arguments": "optional-arguments",
        "terminationMethod": "graceful|force|auto",
        "gracefulTimeoutMs": 5000
    }
}
```

### Configuration Properties

| Property | Required | Description | Valid Values |
|----------|----------|-------------|--------------|
| `path` | No* | Full path to executable | File path or empty string |
| `processName` | Yes | Process name for identification | Process name (supports `|` for multiple) |
| `gameStartAction` | Yes | Action when game starts | See [Actions](#available-actions) below |
| `gameEndAction` | Yes | Action when game ends | See [Actions](#available-actions) below |
| `arguments` | No | Command line arguments | Any string |
| `terminationMethod` | No | How to terminate process | `graceful`, `force`, `auto` |
| `gracefulTimeoutMs` | No | Timeout for graceful shutdown | Milliseconds (default: 3000) |

*Path is required only for `start-process` actions

### Available Actions

| Action | Description | Requires Path |
|--------|-------------|---------------|
| `start-process` | Launch the application | Yes |
| `stop-process` | Stop the application process | No |
| `toggle-hotkeys` | Toggle Clibor hotkeys on/off | No |
| `set-discord-gaming-mode` | Set Discord to gaming mode | No |
| `restore-discord-normal` | Restore Discord normal mode | No |
| `start-vtube-studio` | Start VTube Studio gaming mode | No |
| `stop-vtube-studio` | Stop VTube Studio gaming mode | No |
| `none` | Do nothing | No |

### Termination Methods

| Method | Behavior | Use Case |
|--------|----------|----------|
| `graceful` | Only attempt graceful shutdown | Apps that may have unsaved data |
| `force` | Immediately force terminate | Simple utilities |
| `auto` | Try graceful first, then force | Most applications (default) |

### Application-Specific Examples

#### NoWinKey (Disable Windows Key)

```json
"noWinKey": {
    "path": "C:/Apps/NoWinKey/NoWinKey.exe",
    "processName": "NoWinKey",
    "gameStartAction": "start-process",
    "gameEndAction": "stop-process",
    "terminationMethod": "force",
    "gracefulTimeoutMs": 1000
}
```

#### Clibor (Clipboard Manager)

```json
"clibor": {
    "path": "C:/Apps/clibor/Clibor.exe",
    "processName": "Clibor",
    "gameStartAction": "toggle-hotkeys",
    "gameEndAction": "toggle-hotkeys",
    "arguments": "/hs",
    "terminationMethod": "graceful",
    "gracefulTimeoutMs": 5000
}
```

#### Discord (Communication)

```json
"discord": {
    "path": "%LOCALAPPDATA%/Discord/app-*/Discord.exe",
    "processName": "Discord",
    "gameStartAction": "set-discord-gaming-mode",
    "gameEndAction": "restore-discord-normal",
    "terminationMethod": "graceful",
    "gracefulTimeoutMs": 8000,
    "discord": {
        "statusOnGameStart": "dnd",
        "statusOnGameEnd": "online",
        "disableOverlay": true
    }
}
```

#### AutoHotkey (Script Manager)

```json
"autoHotkey": {
    "path": "",
    "processName": "AutoHotkeyU64|AutoHotkey|AutoHotkey64",
    "gameStartAction": "stop-process",
    "gameEndAction": "none",
    "terminationMethod": "auto",
    "gracefulTimeoutMs": 2000
}
```

#### VTube Studio Integration

```json
"vtubeStudio": {
    "path": "",
    "processName": "VTube Studio",
    "gameStartAction": "start-vtube-studio",
    "gameEndAction": "stop-vtube-studio",
    "websocket": {
        "host": "localhost",
        "port": 8001,
        "enabled": false
    }
}
```

## Game Configuration

Define the games you want to manage and which applications should be controlled for each game.

### Game Structure

```json
"games": {
    "gameId": {
        "name": "Display Name",
        "platform": "steam|epic|riot|standalone",
        "steamAppId": "123456",          // For Steam games
        "epicGameId": "epic-game-id",    // For Epic games
        "riotGameId": "game-name",       // For Riot games
        "executablePath": "path",        // For standalone games
        "processName": "ProcessName*",   // Process name pattern
        "arguments": "launch-args",      // Optional launch arguments
        "appsToManage": ["app1", "app2"] // List of managed apps
    }
}
```

### Platform-Specific Configuration

#### Steam Games

```json
"apex": {
    "name": "Apex Legends",
    "platform": "steam",
    "steamAppId": "1172470",
    "processName": "r5apex*",
    "appsToManage": ["noWinKey", "discord", "obs"]
}
```

#### Epic Games

```json
"genshin": {
    "name": "Genshin Impact",
    "platform": "epic",
    "epicGameId": "ac2c3d6632504c6b9b0503d8b6c41227",
    "processName": "YuanShen*",
    "appsToManage": ["obs", "clibor"]
}
```

#### Riot Games

```json
"valorant": {
    "name": "VALORANT",
    "platform": "riot",
    "riotGameId": "valorant",
    "processName": "VALORANT-Win64-Shipping*",
    "appsToManage": ["discord", "obs"]
}
```

#### Standalone Applications

For games not available through major platforms (Steam, Epic, etc.):

```json
"custom-game": {
    "name": "Custom Game",
    "platform": "standalone",
    "executablePath": "C:/Games/MyGame/game.exe",
    "processName": "game*",
    "arguments": "-fullscreen",
    "appsToManage": ["noWinKey", "obs"]
}
```

| Property | Description | Required |
|----------|-------------|----------|
| `platform` | Must be set to "standalone" | Yes |
| `executablePath` | Full path to game executable | Yes |
| `processName` | Process name for monitoring | Yes |
| `arguments` | Command line arguments | No |
| `appsToManage` | List of managed applications | No |

### Finding Game Information

#### Steam App IDs

1. Visit the game's Steam store page
2. Look at the URL: `store.steampowered.com/app/[APPID]/`
3. Use the number as `steamAppId`

#### Process Names

1. Launch the game
2. Open Task Manager (Ctrl+Shift+Esc)
3. Find the game process in the "Processes" tab
4. Use the process name (supports wildcards with `*`)

#### Epic Game IDs

1. Check Epic Games Launcher
2. Or use third-party tools to find the game's internal ID

## Path Settings

Configure paths to platform launchers and essential applications.

```json
"paths": {
    "steam": "C:/Program Files (x86)/Steam/steam.exe",
    "epic": "C:/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe",
    "riot": "C:/Riot Games/Riot Client/RiotClientServices.exe",
    "obs": "C:/Program Files/obs-studio/bin/64bit/obs64.exe"
}
```

### Common Installation Paths

#### Steam

- **Default**: `C:/Program Files (x86)/Steam/steam.exe`
- **Alternative**: `C:/Steam/steam.exe`

#### Epic Games Launcher

- **Default**: `C:/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe`

#### Riot Client

- **Default**: `C:/Riot Games/Riot Client/RiotClientServices.exe`

#### OBS Studio

- **Default**: `C:/Program Files/obs-studio/bin/64bit/obs64.exe`
- **32-bit**: `C:/Program Files (x86)/obs-studio/bin/32bit/obs32.exe`

## Logging Configuration

Configure how Focus Game Deck logs its activities.

```json
"logging": {
    "level": "Info",                    // Logging level
    "enableFileLogging": true,          // Save logs to file
    "enableConsoleLogging": true,       // Show logs in console
    "logRetentionDays": 90,            // Keep logs for 90 days
    "filePath": "",                    // Custom log file path (optional)
    "enableNotarization": false,       // Enable log integrity verification
    "firebase": {                      // Firebase configuration for notarization
        "projectId": "",
        "apiKey": ""
    }
}
```

### Logging Levels

- `Trace`: Very detailed information
- `Debug`: Debugging information
- `Info`: General information (recommended)
- `Warn`: Warnings only
- `Error`: Errors only
- `Fatal`: Fatal errors only

### Log Notarization

Enable cryptographic proof of log integrity for competitive gaming or dispute resolution:

```json
"logging": {
    "enableNotarization": true,
    "firebase": {
        "projectId": "your-firebase-project-id",
        "apiKey": "your-firebase-api-key"
    }
}
```

See [SECURITY.md](../SECURITY.md) for detailed information about log notarization.

## Advanced Configuration

### Environment Variables

You can use environment variables in paths:

- `%LOCALAPPDATA%`: User's local app data
- `%PROGRAMFILES%`: Program Files directory
- `%SYSTEMROOT%`: Windows system directory

Example:

```json
"path": "%LOCALAPPDATA%/Discord/app-*/Discord.exe"
```

### Multiple Process Names

Use the pipe `|` character to match multiple process names:

```json
"processName": "AutoHotkeyU64|AutoHotkey|AutoHotkey64"
```

### Wildcard Patterns

Use `*` for wildcard matching:

```json
"processName": "r5apex*"  // Matches r5apex.exe, r5apex_dx12.exe, etc.
```

## Examples

### Example 1: Basic Gaming Setup

```json
{
    "managedApps": {
        "discord": {
            "processName": "Discord",
            "gameStartAction": "set-discord-gaming-mode",
            "gameEndAction": "restore-discord-normal"
        },
        "chrome": {
            "processName": "chrome",
            "gameStartAction": "stop-process",
            "gameEndAction": "none",
            "terminationMethod": "graceful"
        }
    },
    "games": {
        "apex": {
            "name": "Apex Legends",
            "platform": "steam",
            "steamAppId": "1172470",
            "processName": "r5apex*",
            "appsToManage": ["discord", "chrome"]
        }
    },
    "paths": {
        "steam": "C:/Program Files (x86)/Steam/steam.exe"
    }
}
```

### Example 2: Streaming Setup

```json
{
    "obs": {
        "websocket": {
            "host": "localhost",
            "port": 4455,
            "password": "your-obs-password"
        },
        "replayBuffer": true
    },
    "managedApps": {
        "obs": {
            "processName": "obs64",
            "gameStartAction": "start-process",
            "gameEndAction": "none"
        },
        "vtubeStudio": {
            "processName": "VTube Studio",
            "gameStartAction": "start-vtube-studio",
            "gameEndAction": "stop-vtube-studio"
        }
    },
    "games": {
        "valorant": {
            "name": "VALORANT",
            "platform": "riot",
            "riotGameId": "valorant",
            "processName": "VALORANT-Win64-Shipping*",
            "appsToManage": ["obs", "vtubeStudio"]
        }
    }
}
```

## Troubleshooting

### Common Issues

#### 1. Application Not Starting/Stopping

Problem: Managed application doesn't respond to start/stop commands.

**Solutions**:

- Verify the `path` is correct and file exists
- Check `processName` matches exactly (use Task Manager)
- Try different `terminationMethod` values
- Increase `gracefulTimeoutMs` for slow applications

#### 2. Game Not Launching

**Problem**: Game doesn't start when running Focus Game Deck.

**Solutions**:

- Verify platform launcher path in `paths` section
- Check game ID (Steam AppID, Epic Game ID, etc.)
- Ensure the platform launcher is running
- Test launching the game manually first

#### 3. Process Name Issues

**Problem**: Can't find correct process name for application.

**Solutions**:

- Use Task Manager to find exact process name
- Try using wildcards: `processname*`
- For multiple possible names: `name1|name2|name3`

#### 4. Permission Errors

**Problem**: "Access denied" or permission errors.

**Solutions**:

- Run Focus Game Deck as Administrator
- Check if antivirus is blocking the application
- Verify file permissions on target applications

#### 5. Configuration Validation Errors

**Problem**: Config file has syntax errors or invalid values.

**Solutions**:

- Use the GUI Config Editor for validation
- Check JSON syntax with online validators
- Ensure all referenced apps in `appsToManage` exist in `managedApps`
- Verify action values are valid (see [Actions](#available-actions))

### Debug Mode

Enable detailed logging to troubleshoot issues:

```json
"logging": {
    "level": "Debug",
    "enableConsoleLogging": true,
    "enableFileLogging": true
}
```

Then check the log files in the `src/logs/` directory.

### Testing Configuration

Use the mock games for testing:

```json
"mock-notepad": {
    "name": "Test Game (Notepad)",
    "platform": "standalone",
    "executablePath": "C:/Windows/System32/notepad.exe",
    "processName": "notepad",
    "appsToManage": ["your-test-apps"]
}
```

Run: `Focus-Game-Deck.exe mock-notepad`

## Related Documentation

- [README.md](/README.md): Project overview and quick start
- [SECURITY.md](/SECURITY.md): Security features and log notarization
- [GUI Manual](/GUI-MANUAL.md): GUI configuration editor manual
- [Architecture](docs/developer-guide/architecture.md): Technical architecture details

---

Last Updated: September 28, 2025
Version: 1.0.0
For: Focus Game Deck v1.0.1+
