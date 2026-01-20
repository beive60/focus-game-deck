# DisplayManager Integration Specification

## Overview

The DisplayManager integration provides automatic display configuration switching for console game sessions. It wraps the DisplayMan.exe tool from the [Mastersign.DisplayManager](https://github.com/mastersign/Mastersign.DisplayManager) project.

## Architecture

### Module Location

- **Path**: `src/modules/DisplayManager.ps1`
- **Dependencies**: None (external dependency on DisplayMan.exe)
- **Loaded by**: `src/Invoke-FocusGameDeck.ps1`

### Class: DisplayProfileManager

The `DisplayProfileManager` class encapsulates all display profile operations.

```powershell
class DisplayProfileManager {
    [string] $DisplayManPath
    [object] $Logger
    [hashtable] $SavedProfile
}
```

#### Constructor

```powershell
DisplayProfileManager([object] $Config, [object] $Logger)
```

**Parameters**:
- `$Config`: Configuration object containing `paths.displayManager`
- `$Logger`: Logger instance for operation logging

**Behavior**:
1. Reads DisplayMan.exe path from config or defaults to `./tools/DisplayMan.exe`
2. Resolves relative paths to absolute paths
3. Detects if running in executable or development mode
4. Logs warning if DisplayMan.exe not found (graceful degradation)

#### Methods

##### IsAvailable()

```powershell
[bool] IsAvailable()
```

**Returns**: `$true` if DisplayMan.exe exists at the configured path, `$false` otherwise

**Usage**:
```powershell
$displayManager = New-DisplayProfileManager -Config $config -Logger $logger
if ($displayManager.IsAvailable()) {
    # Proceed with display operations
}
```

##### SetProfile()

```powershell
[bool] SetProfile([string] $ProfilePath)
```

**Parameters**:
- `$ProfilePath`: Absolute path to DisplayMan XML profile file

**Returns**: `$true` if profile applied successfully, `$false` on error

**Behavior**:
1. Validates DisplayMan.exe availability
2. Validates profile XML file exists
3. Executes: `DisplayMan.exe --load "$ProfilePath" --persistent`
4. Waits for completion (`-Wait -PassThru`)
5. Logs success or failure
6. Returns exit code status

**Error Handling**:
- Returns `$false` if DisplayMan.exe not available
- Returns `$false` if profile file not found
- Catches and logs exceptions
- Returns `$false` on non-zero exit code

**Example**:
```powershell
$result = $displayManager.SetProfile("C:/DisplayConfigs/console.xml")
if ($result) {
    Write-Host "Display profile applied successfully"
}
```

##### SaveCurrentProfile()

```powershell
[bool] SaveCurrentProfile([string] $OutputPath)
```

**Parameters**:
- `$OutputPath`: Absolute path where to save the current display configuration

**Returns**: `$true` if saved successfully, `$false` on error

**Behavior**:
1. Validates DisplayMan.exe availability
2. Executes: `DisplayMan.exe --save "$OutputPath"`
3. Waits for completion
4. Logs success or failure
5. Returns exit code status

**Example**:
```powershell
$result = $displayManager.SaveCurrentProfile("C:/DisplayConfigs/backup.xml")
```

##### RestoreDefault()

```powershell
[bool] RestoreDefault()
```

**Returns**: `$true` if reset successful, `$false` on error

**Behavior**:
1. Validates DisplayMan.exe availability
2. Executes: `DisplayMan.exe --reset`
3. Waits for completion
4. Logs success or failure
5. Returns exit code status

**Notes**:
- `--reset` restores Windows default display configuration
- Use this when no specific profile path is configured
- Alternative to storing a "default" profile

**Example**:
```powershell
$result = $displayManager.RestoreDefault()
```

### Factory Function

```powershell
function New-DisplayProfileManager {
    param(
        [object] $Config,
        [object] $Logger
    )
    return [DisplayProfileManager]::new($Config, $Logger)
}
```

PowerShell-style factory function for module compatibility.

## Integration Points

### Invoke-FocusGameDeck.ps1

DisplayManager is integrated into the main game launch flow:

```powershell
# Load module
. (Join-Path -Path $appRoot -ChildPath "src/modules/DisplayManager.ps1")

# In console game flow
if ($gamePlatform -eq "console" -and $gameConfig.requiresManualExit) {
    # Initialize display manager
    $displayManager = $null
    if ($gameConfig.display -and $gameConfig.display.profilePath) {
        $displayManager = New-DisplayProfileManager -Config $config -Logger $logger
        if ($displayManager.IsAvailable()) {
            $displayManager.SetProfile($gameConfig.display.profilePath)
        }
    }
    
    # ... manual session control ...
    
    # Restore on exit
    if ($displayManager -and $gameConfig.display.restoreOnExit) {
        $displayManager.RestoreDefault()
    }
}
```

### Configuration Schema

Display settings are stored in the game configuration:

```json
{
  "games": {
    "game-id": {
      "platform": "console",
      "display": {
        "profilePath": "C:/Path/To/Profile.xml",
        "restoreOnExit": true
      }
    }
  },
  "paths": {
    "displayManager": "./tools/DisplayMan.exe"
  }
}
```

**Schema Details**:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `display` | object | No | Display configuration settings |
| `display.profilePath` | string | No | Path to DisplayMan XML profile |
| `display.restoreOnExit` | boolean | No | Whether to restore default on exit |
| `paths.displayManager` | string | No | Path to DisplayMan.exe |

## DisplayMan.exe

### About

- **Project**: Mastersign.DisplayManager
- **Repository**: https://github.com/mastersign/Mastersign.DisplayManager
- **License**: MIT License
- **Purpose**: Windows display configuration management tool

### Command Reference

#### Save Configuration

```powershell
DisplayMan.exe --save "path/to/output.xml"
```

Saves the current display configuration to an XML file.

#### Load Configuration

```powershell
DisplayMan.exe --load "path/to/profile.xml" --persistent
```

Loads a display configuration from an XML file. The `--persistent` flag makes the change permanent.

#### Reset to Default

```powershell
DisplayMan.exe --reset
```

Resets display configuration to Windows defaults.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| Non-zero | Error occurred |

The DisplayProfileManager checks exit codes to determine operation success.

### XML Profile Format

DisplayMan uses an XML format to store display configurations. Example structure:

```xml
<?xml version="1.0" encoding="utf-8"?>
<DisplayConfiguration>
  <Monitor>
    <DevicePath>\\?\DISPLAY#...</DevicePath>
    <Width>1920</Width>
    <Height>1080</Height>
    <RefreshRate>60</RefreshRate>
    <Scaling>100</Scaling>
    <Position>
      <X>0</X>
      <Y>0</Y>
    </Position>
    <Primary>true</Primary>
  </Monitor>
  <!-- Additional monitors -->
</DisplayConfiguration>
```

**Note**: Users should generate these files using DisplayMan's `--save` command rather than manually creating them.

## Error Handling

### Graceful Degradation

The DisplayManager module is designed for graceful degradation:

1. **DisplayMan.exe Not Found**
   - Logs warning message
   - `IsAvailable()` returns `$false`
   - Operations return `$false` without throwing exceptions
   - Game session continues without display management

2. **Profile File Not Found**
   - Logs error message
   - Returns `$false`
   - Does not prevent game session from starting

3. **DisplayMan.exe Execution Failure**
   - Logs error with exit code
   - Returns `$false`
   - Continues with session

### Logging

All operations are logged with appropriate log levels:

- **Debug**: Execution commands with arguments
- **Info**: Successful operations
- **Warning**: DisplayMan.exe not found, optional feature unavailable
- **Error**: Failed operations with error details

## Administrator Privileges

### Requirement

DisplayMan.exe may require administrator privileges depending on the display operations being performed:

- **Likely Required**: Multi-monitor configuration changes
- **Likely Required**: HDR/color profile changes
- **May Not Require**: Single monitor resolution changes

### Detection

The current implementation does not automatically detect or request administrator privileges. Users must:

1. Run Focus Game Deck as administrator if DisplayMan requires it
2. Configure display profiles that don't require admin privileges

### Future Consideration

A future enhancement could detect when DisplayMan.exe requires admin privileges and:
- Provide a clear error message
- Offer to relaunch with elevated privileges
- Document which operations require admin access

## Testing

### Unit Testing

To test the DisplayManager module in isolation:

```powershell
# Test with mock config
$mockConfig = @{
    paths = @{
        displayManager = "C:/Path/To/DisplayMan.exe"
    }
}

$mockLogger = @{
    Info = { param($msg, $component) Write-Host "[INFO] $msg" }
    Error = { param($msg, $component) Write-Host "[ERROR] $msg" }
    Warning = { param($msg, $component) Write-Host "[WARN] $msg" }
    Debug = { param($msg, $component) Write-Verbose "[DEBUG] $msg" }
}

. ./src/modules/DisplayManager.ps1
$dm = New-DisplayProfileManager -Config $mockConfig -Logger $mockLogger

# Test availability
$dm.IsAvailable()

# Test save (requires DisplayMan.exe)
$dm.SaveCurrentProfile("test-profile.xml")

# Test load
$dm.SetProfile("test-profile.xml")

# Test reset
$dm.RestoreDefault()
```

### Integration Testing

Test within Focus Game Deck:

```powershell
# Create test console game config
{
  "games": {
    "test-console": {
      "name": "Test Console Game",
      "platform": "console",
      "consoleType": "other",
      "consoleGameId": "test-001",
      "requiresManualExit": true,
      "display": {
        "profilePath": "C:/DisplayConfigs/test.xml",
        "restoreOnExit": true
      }
    }
  }
}

# Run game session
.\Focus-Game-Deck.exe test-console

# Verify:
# 1. Display configuration changes on start
# 2. Session control works
# 3. Display restores on exit
```

## Best Practices

### For Users

1. **Test Profiles First**: Always test display profiles with DisplayMan.exe directly before using in Focus Game Deck
2. **Use Absolute Paths**: Specify full paths to display profile XML files
3. **Create Backups**: Keep backup copies of working profiles
4. **Document Settings**: Note which displays and settings each profile uses

### For Developers

1. **Validate Availability**: Always check `IsAvailable()` before calling operations
2. **Check Return Values**: All operations return boolean success/failure
3. **Log Errors**: Use the logger for all error conditions
4. **Don't Throw**: Return `$false` instead of throwing exceptions for expected failures
5. **Path Normalization**: Normalize backslashes to forward slashes in configuration

### For Integrators

1. **Optional Feature**: Treat display management as an optional feature
2. **Graceful Degradation**: Continue session even if display operations fail
3. **User Control**: Always provide `restoreOnExit` option
4. **Clear Errors**: Provide clear error messages when operations fail

## Future Enhancements

### Planned Features

1. **Profile Validation**: Validate XML profiles before applying
2. **Profile Preview**: Show profile details before applying
3. **Multiple Profiles**: Support profile chains (e.g., primary + secondary)
4. **Profile Editor**: GUI editor for creating/modifying profiles
5. **Auto-Detection**: Detect optimal profile for connected displays

### Considerations

1. **Cross-Platform**: DisplayMan.exe is Windows-only; consider alternatives for Linux/macOS
2. **Performance**: Profile switching adds 1-3 seconds to session start/end
3. **Reliability**: Display switching may fail on some hardware configurations
4. **HDR Support**: Test and document HDR profile switching behavior

## See Also

- [Console Games User Guide](../user-guide/console-games.md)
- [Architecture Guide](architecture.md)
- [DisplayMan Repository](https://github.com/mastersign/Mastersign.DisplayManager)
