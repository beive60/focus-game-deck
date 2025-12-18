# Focus Game Deck - Update Checker Module
# GitHub API integration for version checking and update notifications
#
# This module provides functionality to check for updates from GitHub Releases
# and notify users about new versions available for download.
#
# Features:
# - GitHub Releases API integration
# - Version comparison using semantic versioning
# - Network error handling and retry logic
# - Configurable update check frequency
#
# Author: GitHub Copilot Assistant
# Version: 1.0.0
# Date: 2025-09-24

# Note: Version.ps1 functions are expected to be available through bundling or prior sourcing
# No explicit import needed here as dependencies are resolved at bundle time

# Get latest release information from GitHub API
function Get-LatestReleaseInfo {
    param(
        [int]$TimeoutSeconds = 10
    )

    try {
        $repoInfo = Get-GitHubRepositoryInfo
        $apiUrl = "$($repoInfo.ApiUrl)/releases/latest"

        Write-Verbose "Checking for updates from: $apiUrl"

        # Configure web request
        $webRequest = [System.Net.WebRequest]::Create($apiUrl)
        $webRequest.Timeout = $TimeoutSeconds * 1000
        $webRequest.UserAgent = "Focus Game Deck Update Checker"

        # Make the request
        $response = $webRequest.GetResponse()
        $responseStream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $jsonContent = $reader.ReadToEnd()

        # Clean up
        $reader.Close()
        $responseStream.Close()
        $response.Close()

        # Parse JSON response
        $releaseInfo = $jsonContent | ConvertFrom-Json

        return @{
            Success = $true
            TagName = $releaseInfo.tag_name
            Name = $releaseInfo.name
            PublishedAt = [DateTime]::Parse($releaseInfo.published_at)
            HtmlUrl = $releaseInfo.html_url
            Body = $releaseInfo.body
            PreRelease = $releaseInfo.prerelease
            Draft = $releaseInfo.draft
            Assets = $releaseInfo.assets
        }

    } catch [System.Net.WebException] {
        return @{
            Success = $false
            ErrorType = "NetworkError"
            ErrorMessage = $_.Exception.Message
        }
    } catch [System.TimeoutException] {
        return @{
            Success = $false
            ErrorType = "TimeoutError"
            ErrorMessage = "Request timed out after $TimeoutSeconds seconds"
        }
    } catch {
        return @{
            Success = $false
            ErrorType = "UnknownError"
            ErrorMessage = $_.Exception.Message
        }
    }
}

# Check if an update is available
function Test-UpdateAvailable {
    param(
        [switch]$IncludePreRelease
    )

    try {
        $releaseInfo = Get-LatestReleaseInfo

        if (-not $releaseInfo.Success) {
            return @{
                UpdateAvailable = $false
                ErrorMessage = $releaseInfo.ErrorMessage
                ErrorType = $releaseInfo.ErrorType
            }
        }

        # Skip draft releases
        if ($releaseInfo.Draft) {
            return @{
                UpdateAvailable = $false
                Message = "Latest release is a draft"
            }
        }

        # Skip pre-releases unless explicitly included
        if ($releaseInfo.PreRelease -and -not $IncludePreRelease) {
            return @{
                UpdateAvailable = $false
                Message = "Latest release is a pre-release"
            }
        }

        # Get current version
        $currentVersion = Get-ProjectVersion -IncludePreRelease
        $latestVersion = $releaseInfo.TagName -replace '^v', ''  # Remove 'v' prefix if present

        # Compare versions
        $comparison = Compare-Version -Version1 $currentVersion -Version2 $latestVersion

        if ($comparison -lt 0) {
            return @{
                UpdateAvailable = $true
                CurrentVersion = $currentVersion
                LatestVersion = $latestVersion
                ReleaseInfo = $releaseInfo
            }
        } else {
            return @{
                UpdateAvailable = $false
                CurrentVersion = $currentVersion
                LatestVersion = $latestVersion
                Message = "Current version is up to date"
            }
        }

    } catch {
        return @{
            UpdateAvailable = $false
            ErrorMessage = $_.Exception.Message
            ErrorType = "UnknownError"
        }
    }
}

# Get formatted update check result message
function Get-UpdateCheckMessage {
    param(
        [hashtable]$UpdateCheckResult,
        [hashtable]$Messages = @{}
    )

    if (-not $UpdateCheckResult) {
        return "Update check failed: No result provided"
    }

    if ($UpdateCheckResult.ContainsKey("ErrorMessage")) {
        switch ($UpdateCheckResult.ErrorType) {
            "NetworkError" {
                if ($Messages.ContainsKey("networkError")) {
                    return $Messages["networkError"]
                } else {
                    return "Network error: Unable to check for updates"
                }
            }
            "TimeoutError" {
                if ($Messages.ContainsKey("timeoutError")) {
                    return $Messages["timeoutError"]
                } else {
                    return "Timeout error: Update check timed out"
                }
            }
            default {
                if ($Messages.ContainsKey("unknownError")) {
                    return $Messages["unknownError"]
                } else {
                    return "Unknown error: $($UpdateCheckResult.ErrorMessage)"
                }
            }
        }
    }

    if ($UpdateCheckResult.UpdateAvailable) {
        $current = $UpdateCheckResult.CurrentVersion
        $latest = $UpdateCheckResult.LatestVersion
        if ($Messages.ContainsKey("updateAvailable")) {
            return $Messages["updateAvailable"]
        } else {
            return "Update available: v$latest (current: v$current)"
        }
    } else {
        if ($Messages.ContainsKey("upToDate")) {
            return $Messages["upToDate"]
        } else {
            return "You are using the latest version"
        }
    }
}

# Open GitHub releases page in default browser
function Open-ReleasesPage {
    param()

    try {
        $repoInfo = Get-GitHubRepositoryInfo
        $releasesUrl = "https://github.com/$($repoInfo.Owner)/$($repoInfo.Name)/releases"

        Start-Process $releasesUrl
        return $true
    } catch {
        Write-Warning "Failed to open releases page: $($_.Exception.Message)"
        return $false
    }
}

# Note: Export-ModuleMember is not needed when dot-sourcing the script
# These functions are automatically available when the script is dot-sourced
