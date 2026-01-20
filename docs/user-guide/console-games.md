# Console Game Configuration Guide

This guide explains how to set up Focus Game Deck for console games (Nintendo Switch, PlayStation 5, Xbox Series X|S, etc.) using capture cards.

## Overview

Console game support allows you to use Focus Game Deck to manage your gaming environment when playing console games through a capture card. Since console games don't have PC processes to monitor, the system uses manual session management instead.

## Requirements

### Hardware
- Console game system (Nintendo Switch, PlayStation 5, Xbox Series X|S, or other)
- Capture card with passthrough capability
- Display(s) configured for console gaming

### Software
- Focus Game Deck v1.1 or later
- **Optional**: DisplayMan.exe for automatic display configuration switching

## DisplayMan.exe Setup

DisplayMan.exe is a tool for managing Windows display configurations. It's used to switch between different display profiles when starting and ending console game sessions.

### Installation

1. Download DisplayMan from the official repository:
   - Repository: https://github.com/mastersign/Mastersign.DisplayManager
   - License: MIT License

2. Place `DisplayMan.exe` in the `tools/` directory of your Focus Game Deck installation:
   ```
   Focus-Game-Deck/
   └── tools/
       └── DisplayMan.exe
   ```

3. Update your `config.json` to include the DisplayMan path:
   ```json
   {
     "paths": {
       "displayManager": "./tools/DisplayMan.exe"
     }
   }
   ```

### Creating Display Profiles

Before using display profiles, you need to save your current display configuration:

1. Configure your displays for console gaming (e.g., set HDMI input to capture card passthrough)

2. Save the current configuration using DisplayMan:
   ```powershell
   .\tools\DisplayMan.exe --save "C:/Users/YourName/DisplayConfigs/console-gaming.xml"
   ```

3. Configure your displays for normal PC use

4. Save this as your default profile:
   ```powershell
   .\tools\DisplayMan.exe --save "C:/Users/YourName/DisplayConfigs/default.xml"
   ```

## Configuring a Console Game

### Using the GUI (Recommended)

1. Open the Configuration Editor (`ConfigEditor.exe`)

2. Navigate to the **Games** tab

3. Click **Add New...** to create a new game entry

4. Fill in the basic information:
   - **Game ID**: Unique identifier (e.g., `switch-zelda`)
   - **Display Name**: Human-readable name (e.g., `The Legend of Zelda (Switch)`)
   - **Platform**: Select **Console Game** from the dropdown

5. Configure Console Settings (panel appears when Console Game is selected):
   - **Console Type**: Select your console (Nintendo Switch, PlayStation 5, Xbox Series X|S, or Other)
   - **Console Game ID**: Identifier for this specific game (e.g., `switch-zelda-001`)
   - **Requires Manual Exit**: Leave checked (recommended for console games)
   - **Display Profile (XML)**: Browse to your console display profile XML file
   - **Restore Display on Exit**: Leave checked to restore default display settings after session

6. Click **Save** to save the configuration

### Manual Configuration (config.json)

You can also manually edit the `config.json` file:

```json
{
  "games": {
    "switch-zelda": {
      "name": "The Legend of Zelda (Switch)",
      "platform": "console",
      "consoleType": "switch",
      "consoleGameId": "switch-zelda-001",
      "requiresManualExit": true,
      "processName": "",
      "display": {
        "profilePath": "C:/Users/YourName/DisplayConfigs/console-gaming.xml",
        "restoreOnExit": true
      },
      "integrations": {
        "useOBS": true,
        "useDiscord": false,
        "useVTubeStudio": false,
        "obsSettings": {
          "replayBufferBehavior": "UseGlobal",
          "targetSceneName": "Console Gaming",
          "enableRollback": true
        }
      }
    }
  }
}
```

### Configuration Options

| Option | Description | Required |
|--------|-------------|----------|
| `name` | Display name for the game | Yes |
| `platform` | Must be set to `"console"` | Yes |
| `consoleType` | Type of console: `switch`, `ps5`, `xbox`, or `other` | Yes |
| `consoleGameId` | Unique identifier for this console game | Yes |
| `requiresManualExit` | Enable manual session control (recommended: `true`) | Yes |
| `processName` | Leave empty for console games | No |
| `display.profilePath` | Path to DisplayMan XML profile | No |
| `display.restoreOnExit` | Restore default display settings on exit | No |
| `integrations` | Standard integration settings (OBS, Discord, VTube Studio) | No |

## Using Console Game Sessions

### Starting a Session

1. Launch the game from Focus Game Deck:
   ```powershell
   .\Focus-Game-Deck.exe switch-zelda
   ```

2. Focus Game Deck will:
   - Start configured managed applications
   - Switch display configuration (if configured)
   - Activate integrations (OBS, VTube Studio, etc.)
   - Display a console banner

3. The session will show:
   ```
   ========================================
   Console Game Session Active
   Game: The Legend of Zelda (Switch)
   ========================================

   Press [Q] then [Enter] to end session...
   ```

4. Start your console game manually on your console

### Ending a Session

1. Type `Q` and press Enter

2. Confirm the exit:
   ```
   Are you sure you want to end the session? (Y/N)
   ```

3. Type `Y` and press Enter to confirm

4. Focus Game Deck will:
   - Stop integrations
   - Restore display configuration (if configured)
   - Stop managed applications

### Session Notes

- The session continues indefinitely until you manually exit
- You can press `N` at the confirmation prompt to keep the session running
- The confirmation prompt prevents accidental exits

## Integrations

Console games support all standard integrations:

### OBS Studio
- Automatic scene switching
- Replay buffer control
- Game-specific OBS settings

### VTube Studio
- Model switching
- Hotkey triggers on game start/end

### Discord
- Status updates (if enabled)

## Troubleshooting

### Display Profile Not Applied

**Symptom**: Display configuration doesn't change when starting a console game session

**Solutions**:
1. Verify DisplayMan.exe is in the `tools/` directory
2. Check the display profile path in your configuration
3. Ensure the XML file exists and is valid
4. Run DisplayMan.exe manually to test the profile:
   ```powershell
   .\tools\DisplayMan.exe --load "path/to/profile.xml" --persistent
   ```

### Session Won't Exit

**Symptom**: Unable to exit the console game session

**Solutions**:
1. Make sure you're typing uppercase `Q` or lowercase `q`
2. Press `Ctrl+C` to force exit (will still run cleanup)
3. Check the console output for error messages

### DisplayMan.exe Requires Administrator

**Symptom**: DisplayMan.exe fails with permission errors

**Solutions**:
1. Run Focus Game Deck as administrator
2. Or, adjust your display profile to only change settings that don't require admin rights

## Best Practices

1. **Test Display Profiles**: Always test your display profiles manually before using them in Focus Game Deck

2. **Save Multiple Profiles**: Create separate profiles for different console setups (e.g., Switch docked vs handheld passthrough)

3. **Use Descriptive Names**: Name your console game configurations clearly (e.g., `switch-zelda-botw` instead of just `zelda`)

4. **Backup Configurations**: Keep backup copies of your display profile XML files

5. **Document Your Setup**: Note which HDMI ports and display settings you're using for each console

## Example Configurations

### Nintendo Switch with OBS Recording

```json
{
  "games": {
    "switch-general": {
      "name": "Nintendo Switch",
      "platform": "console",
      "consoleType": "switch",
      "consoleGameId": "switch-general-001",
      "requiresManualExit": true,
      "display": {
        "profilePath": "C:/DisplayConfigs/switch-passthrough.xml",
        "restoreOnExit": true
      },
      "integrations": {
        "useOBS": true,
        "obsSettings": {
          "replayBufferBehavior": "Enable",
          "targetSceneName": "Switch Capture",
          "enableRollback": true
        }
      }
    }
  }
}
```

### PlayStation 5 with VTube Studio

```json
{
  "games": {
    "ps5-general": {
      "name": "PlayStation 5",
      "platform": "console",
      "consoleType": "ps5",
      "consoleGameId": "ps5-general-001",
      "requiresManualExit": true,
      "display": {
        "profilePath": "C:/DisplayConfigs/ps5-4k-passthrough.xml",
        "restoreOnExit": true
      },
      "integrations": {
        "useOBS": true,
        "useVTubeStudio": true,
        "obsSettings": {
          "targetSceneName": "PS5 Gaming"
        },
        "vtubeStudioSettings": {
          "modelId": "Models/Gaming/console_avatar.vtube.json",
          "onLaunchHotkeys": ["console_mode"],
          "onExitHotkeys": ["idle_mode"]
        }
      }
    }
  }
}
```

## See Also

- [Configuration Guide](configuration.md)
- [DisplayManager Integration (Developer Guide)](../developer-guide/display-manager-integration.md)
- [OBS Integration Guide](../../README.md#obs-integration)
