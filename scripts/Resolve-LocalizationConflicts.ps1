# scripts/Resolve-LocalizationConflicts.ps1

$conflictedFiles = git diff --name-only --diff-filter=U -- 'localization/*.json'

if (-not $conflictedFiles) {
    Write-Host "no conflicted localization files found."
    return
}

foreach ($file in $conflictedFiles) {
    Write-Host "Resolving: $file"

    # Normalize path separators (to handle differences between Windows and Git path formats)
    $gitPath = $file -replace '\\', '/'

    try {
        # 2. Retrieve "Ours" and "Theirs" content from Git index
        # :2: is the current branch (Ours), :3: is the branch being merged (Theirs)
        $oursRaw = git show ":2:$gitPath" | Out-String
        $theirsRaw = git show ":3:$gitPath" | Out-String

        $oursJson = $oursRaw | ConvertFrom-Json
        $theirsJson = $theirsRaw | ConvertFrom-Json
    } catch {
        Write-Warning "  Failed to load JSON. Skipping this file."
        continue
    }

    # 3. Merge process: Start with Ours, add keys only present in Theirs
    # Use an Ordered hashtable to preserve order
    $mergedObj = [Ordered]@{}

    # First, add all keys from Ours
    foreach ($prop in $oursJson.PSObject.Properties) {
        $mergedObj[$prop.Name] = $prop.Value
    }

    # Add keys from Theirs that are not present in Ours (value conflicts favor Ours)
    $addedCount = 0
    foreach ($prop in $theirsJson.PSObject.Properties) {
        if (-not $mergedObj.Contains($prop.Name)) {
            $mergedObj[$prop.Name] = $prop.Value
            $addedCount++
        }
    }
    Write-Host "  + $addedCount keys added"

    # 4. Write back to file
    # Specify UTF8 because it may contain Japanese etc. Adjust Depth according to nesting depth (usually 10 is sufficient)
    $mergedObj | ConvertTo-Json -Depth 10 | Set-Content -Path $file -Encoding UTF8

    # 5. Mark as resolved
    git add $file
}

Write-Host "`nDone. Since formatting (indentation, etc.) may have changed,"
Write-Host "please run the project's formatter if available before committing."
