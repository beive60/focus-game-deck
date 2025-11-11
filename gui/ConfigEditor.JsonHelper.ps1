<#
.SYNOPSIS
    JSON helper functions for ConfigEditor to maintain consistent formatting.

.DESCRIPTION
    Provides utility functions for JSON serialization with consistent indentation
    and formatting to match the project's coding standards (4-space indentation).

.NOTES
    Author: Focus Game Deck Development Team
    Last Updated: 2025-11-09
#>

<#
.SYNOPSIS
    Converts an object to JSON with 4-space indentation.

.DESCRIPTION
    Serializes a PowerShell object to JSON format with 4-space indentation
    to match the project's formatting standards. This ensures consistency
    when saving configuration files.
    
    PowerShell's ConvertTo-Json has inconsistent indentation for nested objects,
    so this function manually formats the JSON with proper 4-space indentation.

.PARAMETER InputObject
    The object to convert to JSON.

.PARAMETER Depth
    The depth of nested objects to serialize. Default is 10.

.OUTPUTS
    String - JSON representation with 4-space indentation.

.EXAMPLE
    $json = ConvertTo-Json4Space -InputObject $config -Depth 10
#>
function ConvertTo-Json4Space {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )

    try {
        # Convert to JSON in compressed format first
        $compressedJson = $InputObject | ConvertTo-Json -Depth $Depth -Compress

        # Format the JSON with proper 4-space indentation
        $indent = 0
        $result = New-Object System.Text.StringBuilder
        $inString = $false
        $escapeNext = $false

        for ($i = 0; $i -lt $compressedJson.Length; $i++) {
            $char = $compressedJson[$i]

            # Track if we're inside a string
            if ($escapeNext) {
                $escapeNext = $false
                [void]$result.Append($char)
                continue
            }

            if ($char -eq '\') {
                $escapeNext = $true
                [void]$result.Append($char)
                continue
            }

            if ($char -eq '"') {
                $inString = -not $inString
                [void]$result.Append($char)
                continue
            }

            # If inside a string, just append the character
            if ($inString) {
                [void]$result.Append($char)
                continue
            }

            # Handle formatting characters
            switch ($char) {
                '{' {
                    [void]$result.Append($char)
                    $indent++
                    [void]$result.AppendLine()
                    [void]$result.Append(' ' * ($indent * 4))
                }
                '}' {
                    $indent--
                    [void]$result.AppendLine()
                    [void]$result.Append(' ' * ($indent * 4))
                    [void]$result.Append($char)
                }
                '[' {
                    [void]$result.Append($char)
                    $indent++
                    [void]$result.AppendLine()
                    [void]$result.Append(' ' * ($indent * 4))
                }
                ']' {
                    $indent--
                    [void]$result.AppendLine()
                    [void]$result.Append(' ' * ($indent * 4))
                    [void]$result.Append($char)
                }
                ',' {
                    [void]$result.Append($char)
                    [void]$result.AppendLine()
                    [void]$result.Append(' ' * ($indent * 4))
                }
                ':' {
                    [void]$result.Append($char)
                    [void]$result.Append(' ')
                }
                default {
                    # Skip whitespace in compressed JSON
                    if ($char -ne ' ' -and $char -ne "`t" -and $char -ne "`r" -and $char -ne "`n") {
                        [void]$result.Append($char)
                    }
                }
            }
        }

        return $result.ToString()

    } catch {
        Write-Error "Failed to convert object to JSON with 4-space indentation: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Saves configuration data to a JSON file with proper formatting.

.DESCRIPTION
    Serializes configuration data to JSON with 4-space indentation and
    saves it to the specified file path with UTF-8 encoding.

.PARAMETER ConfigData
    The configuration data object to save.

.PARAMETER ConfigPath
    The path to the configuration file.

.PARAMETER Depth
    The depth of nested objects to serialize. Default is 10.

.OUTPUTS
    None

.EXAMPLE
    Save-ConfigJson -ConfigData $config -ConfigPath "config/config.json"
#>
function Save-ConfigJson {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ConfigData,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )

    try {
        # Convert to JSON with 4-space indentation
        $configJson = ConvertTo-Json4Space -InputObject $ConfigData -Depth $Depth

        # Verify JSON is not empty
        if ([string]::IsNullOrWhiteSpace($configJson) -or $configJson -eq "null") {
            throw "Configuration data is empty or null"
        }

        # Save to file with UTF-8 encoding
        Set-Content -Path $ConfigPath -Value $configJson -Encoding UTF8

        Write-Verbose "Configuration saved to: $ConfigPath with 4-space indentation"

    } catch {
        Write-Error "Failed to save configuration JSON: $($_.Exception.Message)"
        throw
    }
}
