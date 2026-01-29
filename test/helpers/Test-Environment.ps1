<#
.SYNOPSIS
    Test environment detection helper for Pester tests.

.DESCRIPTION
    Provides functions to detect the test execution environment (CI vs Local)
    and determine which tests should be skipped based on available resources.

.EXAMPLE
    . ./test/helpers/Test-Environment.ps1
    if (Test-IsCI) {
        # Skip integration tests
    }
#>

function Test-IsCI {
    <#
    .SYNOPSIS
        Detects if running in a CI/CD environment.
    #>
    return ($env:GITHUB_ACTIONS -eq 'true') -or 
           ($env:CI -eq 'true') -or 
           ($env:TF_BUILD -eq 'true') -or
           ($env:JENKINS_URL -ne $null)
}

function Test-IsLocal {
    <#
    .SYNOPSIS
        Detects if running in a local development environment.
    #>
    return -not (Test-IsCI)
}

function Test-HasIntegrationTarget {
    <#
    .SYNOPSIS
        Checks if a specific integration target is available.
    
    .PARAMETER Target
        The integration target to check (Discord, OBS, VTubeStudio).
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Discord', 'OBS', 'VTubeStudio')]
        [string]$Target
    )

    switch ($Target) {
        'Discord' {
            # Check if Discord process is running
            return $null -ne (Get-Process -Name 'Discord' -ErrorAction SilentlyContinue)
        }
        'OBS' {
            # Check if OBS process is running
            return $null -ne (Get-Process -Name 'obs64', 'obs32' -ErrorAction SilentlyContinue)
        }
        'VTubeStudio' {
            # Check if VTube Studio process is running
            return $null -ne (Get-Process -Name 'VTube Studio' -ErrorAction SilentlyContinue)
        }
        default {
            return $false
        }
    }
}

function Get-TestEnvironmentInfo {
    <#
    .SYNOPSIS
        Returns a summary of the test environment.
    #>
    return @{
        IsCI = Test-IsCI
        IsLocal = Test-IsLocal
        HasDiscord = Test-HasIntegrationTarget -Target 'Discord'
        HasOBS = Test-HasIntegrationTarget -Target 'OBS'
        HasVTubeStudio = Test-HasIntegrationTarget -Target 'VTubeStudio'
        OSVersion = [System.Environment]::OSVersion.VersionString
        PSVersion = $PSVersionTable.PSVersion.ToString()
    }
}

function Skip-TestIfCI {
    <#
    .SYNOPSIS
        Skips the current test if running in CI environment.
    
    .PARAMETER Reason
        The reason for skipping.
    #>
    param(
        [string]$Reason = "Test requires local environment"
    )

    if (Test-IsCI) {
        Set-ItResult -Skipped -Because $Reason
        return $true
    }
    return $false
}

function Skip-TestIfNoIntegration {
    <#
    .SYNOPSIS
        Skips the current test if the integration target is not available.
    
    .PARAMETER Target
        The integration target required.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Discord', 'OBS', 'VTubeStudio')]
        [string]$Target
    )

    if (-not (Test-HasIntegrationTarget -Target $Target)) {
        Set-ItResult -Skipped -Because "$Target is not available in the test environment"
        return $true
    }
    return $false
}

# Export environment info when script is loaded
$script:TestEnvironment = Get-TestEnvironmentInfo
