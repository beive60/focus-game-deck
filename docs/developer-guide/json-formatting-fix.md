# JSON Formatting Fix - Technical Documentation

> **DEPRECATED**: This document has been consolidated into [architecture.md](architecture.md) as of 2025-12-07 to reduce documentation fragmentation and centralize technical implementation details.
>
> Please refer to:
> - [Architecture Guide - JSON Formatting Standards](architecture.md#json-formatting-standards) - For current JSON formatting guidelines and usage

## Issue Description

When using the ConfigEditor GUI to update `config.json`, the file's indentation was being corrupted. Specifically, the indentation was not using a consistent multiple of 4 spaces as required by the project's coding standards.

### Root Cause

PowerShell's built-in `ConvertTo-Json` cmdlet has inconsistent indentation behavior for nested objects. While it claims to use 2-space indentation, the actual output uses a complex alignment pattern that doesn't follow a consistent rule, especially for deeply nested objects.

#### Expected Format (Project Standard)

```json
{
    "level1": "value1",
    "nested": {
        "level2": "value2",
        "level3": "value3"
    }
}
```

- Single space after colon
- Each nesting level increases indentation by exactly 4 spaces
- Consistent indentation at each level

#### Actual PowerShell Output (Problem)

```json
{
    "level1":  "value1",
    "nested":  {
                   "level2":  "value2",
                   "level3":  "value3"
               }
}
```

Notice the problems:

- Double space after colon
- `level2` and `level3` have 19 spaces of indentation (not 8 as expected)
- Closing brace has 15 spaces (not 4 as expected)
- Indentation is not a multiple of 4

## Solution

Created a custom JSON formatter (`ConfigEditor.JsonHelper.ps1`) that:

1. **Compresses JSON first**: Uses `ConvertTo-Json -Compress` to remove all whitespace
2. **Manual formatting**: Parses the compressed JSON character by character and applies proper 4-space indentation
3. **String awareness**: Correctly handles strings containing special characters like `{`, `}`, `[`, `]`, etc.
4. **Consistent indentation**: Ensures all indentation levels are exact multiples of 4 spaces

### Implementation Details

#### New Functions

##### ConvertTo-Json4Space

```powershell
function ConvertTo-Json4Space {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,
        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )
    # Returns JSON with consistent 4-space indentation
}
```

##### Save-ConfigJson

```powershell
function Save-ConfigJson {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ConfigData,
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )
    # Saves JSON file with proper formatting and UTF-8 encoding
}
```

#### Modified Files

1. **gui/ConfigEditor.JsonHelper.ps1** (NEW)
   - Contains the custom JSON formatting functions

2. **gui/ConfigEditor.ps1**
   - Added loading of JsonHelper module
   - Updated language change restart save to use `Save-ConfigJson`

3. **gui/ConfigEditor.Events.ps1**
   - Updated `HandleSaveConfiguration` to use `Save-ConfigJson`
   - Updated `HandleSaveGameSettings` to use `Save-ConfigJson`
   - Updated `HandleSaveManagedApps` to use `Save-ConfigJson`
   - Updated `HandleSaveGlobalSettings` to use `Save-ConfigJson`

4. **gui/ConfigEditor.State.ps1**
   - Updated `SaveOriginalConfig` to use `ConvertTo-Json4Space`

## Testing

### Unit Tests

#### Test-JsonFormatting.ps1

- Tests `ConvertTo-Json4Space` function with nested objects
- Tests `Save-ConfigJson` function
- Verifies all indentation is multiples of 4 spaces

#### Test-ConfigEditorJsonFormatting.ps1

- Integration test that saves config.json and verifies formatting
- Creates backup, modifies config, saves, verifies indentation, and restores

### Test Results

All tests pass successfully:

```text
[PASS] All JSON formatting tests passed!
  - ConvertTo-Json4Space produces 4-space indentation
  - Save-ConfigJson saves files with 4-space indentation
```

## Usage

### For Developers

When saving configuration data, always use the helper functions:

```powershell
# Instead of:
$configJson = $config | ConvertTo-Json -Depth 10
Set-Content -Path $configPath -Value $configJson -Encoding UTF8

# Use:
Save-ConfigJson -ConfigData $config -ConfigPath $configPath -Depth 10
```

### For Users

No action required. The fix is transparent - the GUI will now maintain proper JSON formatting automatically when saving configuration files.

## Benefits

1. **Consistent formatting**: All saved JSON files use 4-space indentation
2. **Better version control**: Consistent formatting reduces unnecessary diffs
3. **Improved readability**: Properly formatted JSON is easier to read and edit manually
4. **Standards compliance**: Matches project coding standards

## Technical Notes

### Character-by-Character Parsing

The formatter processes compressed JSON character by character while tracking:

- Current indentation level
- Whether inside a string literal
- Escape sequences within strings

This ensures proper handling of edge cases like JSON strings containing braces or brackets.

### Performance

The custom formatter is slightly slower than native `ConvertTo-Json` due to character-by-character processing, but the difference is negligible for configuration files (typically < 100KB). The benefit of consistent formatting far outweighs the minimal performance impact.

## Future Improvements

1. Consider caching formatted JSON if the same config is saved multiple times
2. Add option to preserve comment fields in specific order
3. Implement custom property ordering to maintain semantic grouping

## Related Files

- `gui/ConfigEditor.JsonHelper.ps1` - JSON formatting functions
- `test/Test-JsonFormatting.ps1` - Unit tests
- `test/Test-ConfigEditorJsonFormatting.ps1` - Integration tests
- `docs/developer-guide/gui-design.md` - GUI architecture documentation

## References

- [PowerShell ConvertTo-Json documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json)
- [JSON specification](https://www.json.org/)
- Project coding standards: See `.github/copilot-instructions.md`
