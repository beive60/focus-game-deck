# ConfigEditor Debug Mode

## Overview

The ConfigEditor now includes debug mode capabilities for automated testing and troubleshooting without manual GUI interaction.

## Usage

### Basic Debug Mode (Manual Close)

Shows the GUI and allows manual inspection, but includes additional debug output:

```powershell
gui/ConfigEditor.ps1 -DebugMode
```

### Auto-Close Mode

Automatically closes the GUI after a specified number of seconds:

```powershell
# Close after 3 seconds
gui/ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 3

# Close after 10 seconds
gui/ConfigEditor.ps1 -DebugMode -AutoCloseSeconds 10
```

### Automated Testing

Use the dedicated test script to run automated tests with warning/error collection:

```powershell
# Run with default 3-second auto-close
test/Test-ConfigEditorDebug.ps1

# Run with custom timing
test/Test-ConfigEditorDebug.ps1 -AutoCloseSeconds 5

# Run with detailed output of missing localization keys
test/Test-ConfigEditorDebug.ps1 -Verbose
```

## Parameters

### ConfigEditor.ps1

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `-DebugMode` | Switch | Enables debug mode with additional logging | Off |
| `-AutoCloseSeconds` | Int | Seconds before auto-closing (requires -DebugMode) | 0 (manual close) |
| `-NoAutoStart` | Switch | Loads functions without starting the GUI | Off |

### Test-ConfigEditorDebug.ps1

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `-AutoCloseSeconds` | Int | Seconds before auto-closing | 3 |
| `-Verbose` | Switch | Shows detailed list of missing localization keys | Off |

## Features

### Debug Mode Features

1. **Initialization Tracking**: Shows detailed progress of initialization steps
2. **Timer Display**: Visual countdown when using auto-close
3. **Enhanced Logging**: Additional DEBUG messages for troubleshooting
4. **Automatic Cleanup**: Ensures proper resource cleanup on auto-close

### Test Script Features

1. **Warning Collection**: Automatically collects all warnings during execution
2. **Error Detection**: Catches and reports any errors
3. **Categorization**: Groups warnings by type (localization, other)
4. **Missing Keys Analysis**: Identifies unique missing localization keys
5. **Exit Code**: Returns appropriate exit codes for CI/CD integration

## Exit Codes

The test script returns the following exit codes:

- `0`: Success (no errors, warnings are acceptable)
- `1`: Failure (errors detected or script exception)

## Examples

### Quick Smoke Test

```powershell
# Run a quick test to ensure the GUI loads without errors
test/Test-ConfigEditorDebug.ps1 -AutoCloseSeconds 2
```

### Detailed Analysis

```powershell
# Get detailed information about any issues
test/Test-ConfigEditorDebug.ps1 -AutoCloseSeconds 5 -Verbose
```

### Manual Inspection

```powershell
# Open in debug mode but don't auto-close for manual testing
gui/ConfigEditor.ps1 -DebugMode
```

### CI/CD Integration

```powershell
# Example CI/CD script
$result = test/Test-ConfigEditorDebug.ps1 -AutoCloseSeconds 3
if ($LASTEXITCODE -ne 0) {
    Write-Error "ConfigEditor test failed"
    exit 1
}
Write-Host "ConfigEditor test passed"
```

## Troubleshooting

### GUI Doesn't Close Automatically

- Ensure you're using both `-DebugMode` and `-AutoCloseSeconds` parameters
- Check that `AutoCloseSeconds` is greater than 0
- Verify no modal dialogs are blocking the close operation

### Warnings Not Collected

- The test script captures stdout, stderr, and warning streams
- Ensure you're redirecting output properly if running in custom scripts
- Use `-Verbose` to see additional details

### Script Hangs

- If the auto-close timer doesn't work, manually close the GUI
- Check for any error dialogs that might be blocking
- Verify WPF assemblies are properly loaded

## Best Practices

1. **Quick Tests**: Use 2-3 seconds for rapid smoke tests
2. **Visual Verification**: Use 5-10 seconds when you want to see the GUI briefly
3. **Manual Testing**: Use `-DebugMode` without auto-close for detailed inspection
4. **CI/CD**: Always use the test script with appropriate timeout values
5. **Debugging**: Combine `-DebugMode` with manual close for interactive debugging

## Related Files

- gui/ConfigEditor.ps1 - Main GUI application
- test/Test-ConfigEditorDebug.ps1 - Automated test script
- gui/ConfigEditor.*.ps1 - Supporting module files
- localization/*.json - Individual language files for localization resources
