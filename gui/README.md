# Focus Game Deck - GUI Configuration Editor

This directory contains the source code for the GUI configuration editor.

> **Note**: Starting from v2.0.0, the GUI configuration editor is part of the unified architecture.
> The main entry point is `src/Main.PS1`.

## File Structure

- `ConfigEditor.ps1` - Main GUI configuration editor logic (part of unified architecture)
- `ConfigEditor.Events.ps1` - Event handling logic for UI interactions
- `ConfigEditor.JsonHelper.ps1` - JSON formatting utilities (ensures 4-space indentation)
- `ConfigEditor.Localization.ps1` - Internationalization and localization support
- `ConfigEditor.Mappings.ps1` - UI element to message key mappings
- `ConfigEditor.State.ps1` - Configuration state management
- `ConfigEditor.UI.ps1` - UI construction and management
- `MainWindow.xaml` - WPF window UI layout definition (includes Game Launcher tab)

**Note**: Localization message files have been moved to `../localization/` directory (individual language files).

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
../build-tools/Release-Manager.ps1 -Development
```

## Detailed Usage

For complete usage instructions, troubleshooting, and technical specifications, refer to the detailed documentation:

**[docs/user-guide/configuration.md](../docs/user-guide/configuration.md)**

## Developer Information

For GUI design technical specifications and architecture details, see:

**[docs/developer-guide/gui-design.md](../docs/developer-guide/gui-design.md)**
