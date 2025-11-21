<#
.SYNOPSIS
    Recursively finds all .ps1 files and extracts lines with localization messages
    and the corresponding message key.
#>
param(
    [string]$SearchPath = (Get-Location).Path
)

# Pattern to find the lines containing a message call
$linePattern = 'Write-(Host|Verbose|Warning) \(?\$this\.Messages\.[a-z_].*'
# Pattern to extract the key from the line
$keyPattern = '\$this\.Messages\.([a-z_]+)'

$foundItems = [System.Collections.Generic.List[string]]::new()

try {
    # Find all matching lines across all files.
    $matches = Get-ChildItem -Path $SearchPath -Recurse -Filter *.ps1 | Select-String -Pattern $linePattern -CaseSensitive

    if ($matches) {
        foreach ($match in $matches) {
            # Extract the key from the matched line
            $keyMatch = $match.Line | Select-String -Pattern $keyPattern
            $key = if ($keyMatch) { $keyMatch.Matches[0].Groups[1].Value } else { "N/A" }

            # Format the output string
            $outputString = "{0}:{1}:{2};{3}" -f $match.Filename, $match.LineNumber, $match.Line.Trim(), $key
            $foundItems.Add($outputString)
        }
    }

    # Output the unique, sorted results
    $uniqueResults = $foundItems | Sort-Object -Unique

    if ($uniqueResults) {
        Write-Output "File:Line:Code;MessageKey" # Header
        $uniqueResults | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "No matching strings found in '$SearchPath'."
    }
} catch {
    Write-Error "An error occurred: $_"
}
