# Installation Guide

This guide provides step-by-step instructions for installing and setting up Focus Game Deck.

## System Requirements

### Minimum Requirements

- **Operating System**: Windows 10 (version 1903 or later) or Windows 11
- **PowerShell**: Version 5.1 or later (included with Windows)
- **Memory**: 2GB RAM available
- **Storage**: 50MB free disk space

### Recommended Requirements

- **Operating System**: Windows 11
- **PowerShell**: Version 7.x (for enhanced performance)
- **Memory**: 4GB RAM available
- **Storage**: 100MB free disk space for logs and configuration

## Installation Methods

Focus Game Deck offers two installation methods to suit different user preferences:

### Method 1: Executable Distribution (Recommended)

This is the easiest method for most users.

1. **Download the Latest Release**
   - Visit [GitHub Releases](https://github.com/beive60/focus-game-deck/releases/latest)
   - Download the appropriate executable:
     - `Focus-Game-Deck.exe` - Main application
     - `Focus-Game-Deck-Config-Editor.exe` - GUI configuration editor
     - `Focus-Game-Deck-MultiPlatform.exe` - Extended platform support

2. **Verify Digital Signature**
   - Right-click the downloaded executable
   - Select "Properties" → "Digital Signatures"
   - Verify the signature is from the official publisher

3. **First Run Setup**

   ```cmd
   # Run from Command Prompt or PowerShell
   Focus-Game-Deck.exe --setup
   ```

4. **Test Installation**

   ```cmd
   # Verify the application works
   Focus-Game-Deck.exe --version
   ```

### Method 2: PowerShell Script (Advanced Users)

This method is for developers and advanced users who want full source code access.

1. **Clone Repository**

   ```powershell
   git clone https://github.com/beive60/focus-game-deck.git
   cd focus-game-deck
   ```

2. **Set Execution Policy** (if needed)

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Install Dependencies**

   ```powershell
   ./build-tools/Build-FocusGameDeck.ps1 -Install
   ```

4. **Test Installation**

   ```powershell
   ./src/Invoke-FocusGameDeck.ps1 --version
   ```

## Initial Configuration

### Quick Setup with GUI (Recommended)

1. **Launch Configuration Editor**

   ```cmd
   Focus-Game-Deck-Config-Editor.exe
   ```

2. **Basic Settings**
   - Set your preferred language
   - Configure game detection paths
   - Enable desired integrations (OBS, Discord, etc.)

3. **Test Configuration**
   - Use the "Test Configuration" button in the GUI
   - Verify all paths and applications are detected correctly

### Manual Configuration

If you prefer to edit configuration files directly:

1. **Locate Configuration File**
   - Executable version: Same directory as the .exe file
   - Script version: `config/config.json`

2. **Edit Configuration**

   ```json
   {
     "language": "en-US",
     "games": {
       "apex": {
         "name": "Apex Legends",
         "platform": "steam",
         "appId": "1172470"
       }
     }
   }
   ```

3. **Validate Configuration**

   ```powershell
   .\test\Test-ConfigValidation.ps1
   ```

## Administrator Privileges (Optional)

Depending on the applications you manage, Focus Game Deck may require Administrator privileges to function correctly.

### Why is this needed?

Certain tools (e.g., **NoWinKey** for disabling the Windows key) and some competitive games with anti-cheat systems run with high system privileges.

- **The Issue:** If Focus Game Deck runs as a standard user, Windows security will prevent it from stopping these high-privilege tools (Access Denied error) when you finish playing.
- **The Benefit:** Running as Administrator ensures that your gaming environment is **cleanly and automatically restored** every time.

### How to set up

If you use such tools, please configure the application to run as administrator:

1. Right-click `Focus-Game-Deck.exe` and select **Properties**.
2. Go to the **Compatibility** tab.
3. Check **Run this program as an administrator**.
4. Click **Apply** and **OK**.

## Integration Setup

### Steam Integration

1. **Locate Steam Installation**
   - Default: `C:/Program Files (x86)/Steam/`
   - Steam will be automatically detected in most cases

2. **Game Library Detection**
   - Games are detected automatically from Steam library
   - Custom game paths can be configured if needed

### OBS Studio Integration

1. **Install OBS Studio**
   - Download from [OBS Project](https://obsproject.com/)
   - Ensure version 28.0 or later for WebSocket support

2. **Configure WebSocket**
   - In OBS: Tools → WebSocket Server Settings
   - Enable WebSocket server
   - Set password (recommended)
   - Default port: 4455

3. **Update Focus Game Deck Configuration**

   ```json
   "integrations": {
     "obs": {
       "path": "C:/Program Files/obs-studio/bin/64bit/obs64.exe",
       "processName": "obs64",
       "websocket": {
         "host": "localhost",
         "port": 4455,
         "password": "your-password"
       },
       "replayBuffer": true
     }
   }
   ```

### Discord Integration

1. **Enable Developer Mode**
   - Discord Settings → Advanced → Developer Mode: ON

2. **Configure Rich Presence**

   ```json
   "integrations": {
     "discord": {
       "enabled": true,
       "clientId": "your-app-id",
       "showGameStatus": true
     }
   }
   ```

## Troubleshooting Installation

### Common Issues

#### PowerShell Execution Policy Error

**Problem**: "Execution of scripts is disabled on this system"

**Solution**:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Antivirus False Positive

**Problem**: Antivirus software blocks the executable

**Solution**:

1. Add Focus Game Deck folder to antivirus exclusions
2. Verify digital signature to confirm authenticity
3. Download from official GitHub releases only

#### Configuration File Not Found

**Problem**: Application cannot find config.json

**Solution**:

1. Ensure config.json is in the same directory as the executable
2. Run the configuration editor to generate a new config file
3. Check file permissions

#### Steam Games Not Detected

**Problem**: Steam games are not automatically detected

**Solution**:

1. Verify Steam is installed and running
2. Check Steam library paths in configuration
3. Ensure games are installed and visible in Steam library

### Getting Additional Help

- **Configuration Issues**: See [Configuration Guide](configuration.md)
- **Bug Reports**: [GitHub Issues](https://github.com/beive60/focus-game-deck/issues)
- **Community Support**: [GitHub Discussions](https://github.com/beive60/focus-game-deck/discussions)

## Next Steps

After successful installation:

1. **Configure Your Games**: Follow the [Configuration Guide](configuration.md)
2. **Test Your Setup**: Run a quick test with one of your games
3. **Customize Settings**: Explore advanced configuration options
4. **Join the Community**: Share your experience and get help from other users

## Security Notes

- **Digital Signatures**: All official releases are digitally signed with Extended Validation certificates
- **Source Code**: Complete source code is available for security audit
- **Permissions**: The application requires minimal system permissions
- **Data Privacy**: No personal data is collected or transmitted

---

**Installation Complete!** You're now ready to enjoy automated gaming environment management with Focus Game Deck.
