# Test script for UpdateChecker.ps1

# Load Version.ps1 first
. ./build-tools/Version.ps1

# Load UpdateChecker.ps1
. ./src/modules/UpdateChecker.ps1

Write-Host '=== Testing Get-GitHubRepositoryInfo ===' -ForegroundColor Cyan
try {
    $repoInfo = Get-GitHubRepositoryInfo
    $repoInfo | ConvertTo-Json -Depth 3
    Write-Host 'Success!' -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Write-Host '=== Testing Get-ProjectVersion ===' -ForegroundColor Cyan
try {
    $version = Get-ProjectVersion -IncludePreRelease
    Write-Host "Current Version: $version"
    Write-Host 'Success!' -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Write-Host '=== Testing Get-LatestReleaseInfo ===' -ForegroundColor Cyan
try {
    $releaseInfo = Get-LatestReleaseInfo -TimeoutSeconds 10
    if ($releaseInfo.Success) {
        Write-Host "Latest Release: $($releaseInfo.TagName)"
        Write-Host "Name: $($releaseInfo.Name)"
        Write-Host "Published: $($releaseInfo.PublishedAt)"
        Write-Host "PreRelease: $($releaseInfo.PreRelease)"
        Write-Host "URL: $($releaseInfo.HtmlUrl)"
        Write-Host 'Success!' -ForegroundColor Green
    } else {
        Write-Host "Failed: $($releaseInfo.ErrorType) - $($releaseInfo.ErrorMessage)" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Write-Host '=== Testing Test-UpdateAvailable ===' -ForegroundColor Cyan
try {
    $updateCheck = Test-UpdateAvailable
    $updateCheck | ConvertTo-Json -Depth 3
    Write-Host 'Success!' -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Write-Host '=== Testing Compare-Version ===' -ForegroundColor Cyan
try {
    $result1 = Compare-Version -Version1 "1.0.0" -Version2 "1.0.1"
    Write-Host "Compare 1.0.0 vs 1.0.1: $result1 (should be -1)"

    $result2 = Compare-Version -Version1 "1.0.1" -Version2 "1.0.0"
    Write-Host "Compare 1.0.1 vs 1.0.0: $result2 (should be 1)"

    $result3 = Compare-Version -Version1 "1.0.0" -Version2 "1.0.0"
    Write-Host "Compare 1.0.0 vs 1.0.0: $result3 (should be 0)"

    Write-Host 'Success!' -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
