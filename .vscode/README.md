# Focus Game Deck - VSCode Development Environment Configuration

This directory contains configuration files for efficient development of the Focus Game Deck project using VSCode.

## 📁 Configuration Files Overview

### `tasks.json` - Task Configuration
Defines frequently used project commands as VSCode tasks.

**Main Tasks:**
- 🔧 **Setup** - Install ps2exe module
- 🏗️ **Build - Development** - Unsigned development build (default)
- 📦 **Build - Production** - Signed production build
- 🧹 **Cleanup** - Delete build artifacts
- 🎮 **Run** - Direct execution of main application
- ⚙️ **GUI Config Editor** - Build and launch configuration editor
- 🧪 **Various Tests** - Config validation, Discord, OBS, VTube Studio integration tests
- 📊 **Project Statistics** - Display file count, line count, and other statistics

### `settings.json` - Workspace Settings
Settings optimized for PowerShell development:
- PowerShell code formatting settings
- 120-character ruler display
- UTF-8 encoding
- JSON configuration file schema validation
- Exclusion of unnecessary files from search

### `keybindings.json` - Keyboard Shortcuts
Keyboard shortcuts for efficient development:
- `Ctrl+Shift+B` - Development build
- `Ctrl+Shift+Alt+B` - Production build
- `Ctrl+Shift+T` - Simple check test
- `F5` - Main application execution
- `Ctrl+F5` - Launch release version executable
- `Ctrl+Shift+Del` - Cleanup
- `Ctrl+Shift+G` - GUI config editor

### `launch.json` - Debug Configuration
Debug execution settings for PowerShell scripts:
- Main application
- Multi-platform version
- Configuration editor
- Currently open file
- Various test scripts

### `extensions.json` - Recommended Extensions
Recommended extensions for PowerShell development:
- PowerShell
- JSON Language Features
- YAML
- Code Spell Checker
- Hex Editor
- Other useful tools

## 🚀 Usage

### Running Tasks
1. **Command Palette**: `Ctrl+Shift+P` → `Tasks: Run Task`
2. **Keyboard Shortcuts**: Use the shortcuts listed above
3. **Terminal Menu**: `Terminal` → `Run Task`

### Starting Debug
1. Press **F5** or run from debug panel
2. Set breakpoints in PowerShell scripts
3. Variable watching, call stack display, etc. are available

### Efficient Development Workflow
1. **Setup**: `🔧 Setup - Install ps2exe Module`
2. **Development**: After code editing, use `Ctrl+Shift+B` for development build
3. **Testing**: Use `Ctrl+Shift+T` for simple check, or run various test tasks
4. **Debugging**: If issues arise, use F5 for debug execution
5. **Cleanup**: Use `Ctrl+Shift+Del` to delete unnecessary files
6. **Release**: Use `Ctrl+Shift+Alt+B` for production build

## 🛠️ Customization

### Adding New Tasks
To add a new task to `tasks.json`:
```json
{
    "label": "New Task Name",
    "type": "shell",
    "command": "powershell",
    "args": ["-ExecutionPolicy", "Bypass", "-File", "script-path"],
    "group": "build|test",
    "detail": "Task description"
}
```

### Changing Keyboard Shortcuts
Modify or add shortcuts in `keybindings.json`:
```json
{
    "key": "ctrl+alt+t",
    "command": "workbench.action.tasks.runTask",
    "args": "Task Name"
}
```

## 📋 Project Statistics

Current project scale (verifiable with statistics task):
- PowerShell Files: 37
- Total Lines: 8,208
- Configuration Files: 4
- Test Files: 10
- Modules: 11

## 🔧 Troubleshooting

### PowerShell Execution Policy Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Missing ps2exe Module
Run the "🔧 Setup" task to install the module

### Task Not Found
- Restart VSCode
- Confirm `.vscode` folder is in workspace root
- Check `tasks.json` for syntax errors

## 📝 Notes

- PowerShell extension installation required
- Must run "🔧 Setup" task on first setup
- Production build requires signing configuration (`config/signing-config.json`)
- PowerShell integrated console is used during debug execution

---

These configurations significantly improve Focus Game Deck development efficiency and provide a consistent development experience.
