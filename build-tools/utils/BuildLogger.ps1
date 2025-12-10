<#
.SYNOPSIS
    Standardized logging utility for Focus Game Deck build and test scripts

.DESCRIPTION
    Provides a common logging function (Write-BuildLog) for consistent output
    formatting across all development scripts. Uses text-based prefixes without
    colors or emojis for maximum accessibility and maintainability.

.NOTES
    Version: 1.0.0
    This script is part of the Focus Game Deck build system
#>

function Write-BuildLog {
    <#
    .SYNOPSIS
        Write a formatted log message to the appropriate output stream

    .DESCRIPTION
        Formats log messages with text-based prefixes and routes them to the
        appropriate PowerShell output stream based on the level.

    .PARAMETER Message
        The message to log (mandatory)

    .PARAMETER Level
        The log level: Info, Success, Warning, Error, or Debug (default: Info)

    .EXAMPLE
        Write-BuildLog "Starting build process"

    .EXAMPLE
        Write-BuildLog "Build completed successfully" -Level Success

    .EXAMPLE
        Write-BuildLog "Missing configuration file" -Level Warning

    .EXAMPLE
        Write-BuildLog "Build failed with errors" -Level Error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline
    )

    switch ($Level) {
        "Info" {
            Write-Host "[INFO] $Message" -NoNewline:$NoNewline
        }
        "Success" {
            Write-Host "[DONE] $Message" -NoNewline:$NoNewline
        }
        "Warning" {
            Write-Warning "[WARN] $Message"
        }
        "Error" {
            Write-Error "[FAIL] $Message"
        }
        "Debug" {
            Write-Verbose "[DBUG] $Message"
        }
    }
}
