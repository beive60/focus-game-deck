# Focus Game Deck - GUI Configuration Editor

This directory contains the source code for the GUI configuration editor.

> **Note**: Starting from v2.0.0, the GUI configuration editor is part of the unified architecture.
> The main entry point is `src/Main.PS1`.

## File Structure

- `ConfigEditor.ps1` - Main GUI configuration editor logic (part of unified architecture)
- `MainWindow.xaml` - WPF window UI layout definition (includes Game Launcher tab)
- `messages.json` - Internationalization message resources for GUI

## Quick Start

### Unified GUI Application (Recommended)

```powershell
# Launch main application (integrates configuration editing and game launching)
../src/Main.PS1
```

### Standalone GUI Configuration Editor

```powershell
./ConfigEditor.ps1
```

### Build Executable

```powershell
# Use unified build system
../Release-Manager.ps1 -Development
```

## Detailed Usage

For complete usage instructions, troubleshooting, and technical specifications, refer to the detailed documentation:

**[docs/user-guide/configuration.md](../docs/user-guide/configuration.md)**

## Developer Information

For GUI design technical specifications and architecture details, see:

**[docs/developer-guide/gui-design.md](../docs/developer-guide/gui-design.md)**
