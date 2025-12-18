# Detailed test script for UpdateChecker.ps1

# Load Version.ps1 first
. ./build-tools/Version.ps1

# Load UpdateChecker.ps1
. ./src/modules/UpdateChecker.ps1

Write-Host '============================================' -ForegroundColor Cyan
Write-Host 'UpdateChecker.ps1 Detailed Test Results' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ''

# Test 1: Repository Information
Write-Host '[Test 1] Get-GitHubRepositoryInfo' -ForegroundColor Yellow
$repoInfo = Get-GitHubRepositoryInfo
Write-Host "  Owner: $($repoInfo.Owner)"
Write-Host "  Name: $($repoInfo.Name)"
Write-Host "  API URL: $($repoInfo.ApiUrl)"
Write-Host ''

# Test 2: Current Version
Write-Host '[Test 2] Get-ProjectVersion' -ForegroundColor Yellow
$currentVersion = Get-ProjectVersion -IncludePreRelease
Write-Host "  Current Version: $currentVersion"
Write-Host ''

# Test 3: Version Comparison
Write-Host '[Test 3] Compare-Version' -ForegroundColor Yellow
$testCases = @(
    @{V1="1.0.0"; V2="1.0.1"; Expected=-1},
    @{V1="1.0.1"; V2="1.0.0"; Expected=1},
    @{V1="1.0.0"; V2="1.0.0"; Expected=0},
    @{V1="2.0.0"; V2="1.9.9"; Expected=1},
    @{V1="1.0.0-alpha"; V2="1.0.0-beta"; Expected=-1},
    @{V1="1.0.0-beta"; V2="1.0.0"; Expected=-1},
    @{V1="1.0.0"; V2="1.0.0-alpha"; Expected=1}
)

$passCount = 0
$failCount = 0
foreach ($test in $testCases) {
    $result = Compare-Version $test.V1 $test.V2
    $status = if ($result -eq $test.Expected) {
        $passCount++
        "PASS"
    } else {
        $failCount++
        "FAIL"
    }
    $color = if ($status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "  [$status] $($test.V1) vs $($test.V2): $result (expected: $($test.Expected))" -ForegroundColor $color
}
Write-Host "  Summary: $passCount passed, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) {"Green"} else {"Red"})
Write-Host ''

# Test 4: GitHub API Call
Write-Host '[Test 4] Get-LatestReleaseInfo' -ForegroundColor Yellow
Write-Host "  Attempting to fetch latest release from GitHub API..."
$releaseInfo = Get-LatestReleaseInfo -TimeoutSeconds 10
if ($releaseInfo.Success) {
    Write-Host "  Status: SUCCESS" -ForegroundColor Green
    Write-Host "  Tag: $($releaseInfo.TagName)"
    Write-Host "  Name: $($releaseInfo.Name)"
    Write-Host "  Published: $($releaseInfo.PublishedAt)"
    Write-Host "  Pre-release: $($releaseInfo.PreRelease)"
    Write-Host "  Draft: $($releaseInfo.Draft)"
    Write-Host "  URL: $($releaseInfo.HtmlUrl)"
} else {
    Write-Host "  Status: FAILED" -ForegroundColor Red
    Write-Host "  Error Type: $($releaseInfo.ErrorType)"
    Write-Host "  Error Message: $($releaseInfo.ErrorMessage)"

    # Provide additional information
    if ($releaseInfo.ErrorType -eq "NetworkError") {
        if ($releaseInfo.ErrorMessage -match "404") {
            Write-Host "  Analysis: No releases found in the repository" -ForegroundColor Yellow
            Write-Host "  This is expected if no GitHub releases have been created yet" -ForegroundColor Yellow
        } else {
            Write-Host "  Analysis: Network connectivity issue" -ForegroundColor Yellow
        }
    }
}
Write-Host ''

# Test 5: Update Check
Write-Host '[Test 5] Test-UpdateAvailable' -ForegroundColor Yellow
$updateCheck = Test-UpdateAvailable
if ($updateCheck.ContainsKey("ErrorMessage")) {
    Write-Host "  Status: ERROR" -ForegroundColor Red
    Write-Host "  Error Type: $($updateCheck.ErrorType)"
    Write-Host "  Error Message: $($updateCheck.ErrorMessage)"

    if ($updateCheck.ErrorType -eq "NetworkError" -and $updateCheck.ErrorMessage -match "404") {
        Write-Host "  Expected Behavior: This is normal if no releases exist yet" -ForegroundColor Yellow
    }
} elseif ($updateCheck.UpdateAvailable) {
    Write-Host "  Status: UPDATE AVAILABLE" -ForegroundColor Green
    Write-Host "  Current: $($updateCheck.CurrentVersion)"
    Write-Host "  Latest: $($updateCheck.LatestVersion)"
    Write-Host "  Release URL: $($updateCheck.ReleaseInfo.HtmlUrl)"
} else {
    Write-Host "  Status: UP TO DATE" -ForegroundColor Green
    Write-Host "  Version: $($updateCheck.CurrentVersion)"
}
Write-Host ''

# Test 6: Message Formatting
Write-Host '[Test 6] Get-UpdateCheckMessage' -ForegroundColor Yellow
$messages = @{
    networkError = "Network error occurred"
    timeoutError = "Request timed out"
    unknownError = "Unknown error occurred"
    updateAvailable = "New version available"
    upToDate = "You are running the latest version"
}
$message = Get-UpdateCheckMessage -UpdateCheckResult $updateCheck -Messages $messages
Write-Host "  Message: $message"
Write-Host ''

Write-Host '============================================' -ForegroundColor Cyan
Write-Host 'Test Completed' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan
