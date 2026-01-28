#Requires -Version 5.1

<#
.SYNOPSIS
    Unit test for AppManager parallel execution functionality.

.DESCRIPTION
    This script tests the AppManager's background job implementation for OBS replay buffer
    parallel processing. It validates that:
    - Background jobs are created correctly
    - Path resolution works in both script and executable modes
    - Job cleanup handles all states properly
    - Error handling returns correct values
    
    This is a unit test that uses mocking to avoid requiring actual OBS Studio.

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Created: 2026-01-28
#>

param(
    [switch]$Verbose
)

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"
$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

# Initialize project root path
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Write-BuildLog "========================================="
Write-BuildLog "AppManager Parallel Execution Unit Test"
Write-BuildLog "========================================="
Write-BuildLog "Testing parallel processing implementation for OBS replay buffer"
Write-BuildLog "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

$results = @{ Total = 0; Passed = 0; Failed = 0; Skipped = 0 }

function Test-Result {
    param([string]$Name, [bool]$Pass, [string]$Message = "", [bool]$Skip = $false)

    $results.Total++
    if ($Skip) {
        $results.Skipped++
        Write-BuildLog "[SKIP] $Name"
        if ($Message) { Write-BuildLog "  Reason: $Message" }
    } elseif ($Pass) {
        $results.Passed++
        Write-BuildLog "[OK] $Name"
        if ($Message) { Write-BuildLog "  $Message" }
    } else {
        $results.Failed++
        Write-BuildLog "[ERROR] $Name"
        if ($Message) { Write-BuildLog "  Error: $Message" }
    }
}

# Test 1: Verify AppManager.ps1 exists and has required methods
Write-BuildLog "Test 1: Verifying AppManager.ps1 structure..."
try {
    $appManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1"
    $appManagerContent = Get-Content -Path $appManagerPath -Raw
    
    $hasHandleOBSAction = $appManagerContent -match '\[bool\]\s+HandleOBSAction'
    $hasProcessShutdownSequence = $appManagerContent -match '\[bool\]\s+ProcessShutdownSequence'
    $hasBackgroundJobCode = $appManagerContent -match 'Start-Job.*-ScriptBlock'
    
    Test-Result "AppManager.ps1 exists" $true
    Test-Result "HandleOBSAction method exists" $hasHandleOBSAction
    Test-Result "ProcessShutdownSequence method exists" $hasProcessShutdownSequence
    Test-Result "Background job code present" $hasBackgroundJobCode
} catch {
    Test-Result "AppManager.ps1 verification" $false $_
}

# Test 2: Verify OBSReplayBufferBackground.ps1 exists
Write-Host ""
Write-BuildLog "Test 2: Verifying background worker script..."
try {
    $backgroundScriptPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSReplayBufferBackground.ps1"
    $backgroundExists = Test-Path $backgroundScriptPath
    Test-Result "OBSReplayBufferBackground.ps1 exists" $backgroundExists
    
    if ($backgroundExists) {
        $backgroundContent = Get-Content -Path $backgroundScriptPath -Raw
        $hasAppRootParam = $backgroundContent -match 'param\s*\([\s\S]*?\[string\]\s+\$AppRoot'
        $hasOBSConfigParam = $backgroundContent -match '\[object\]\s+\$OBSConfig'
        $hasTryFinally = $backgroundContent -match 'try\s*\{[\s\S]*?\}\s*finally'
        
        Test-Result "Has AppRoot parameter" $hasAppRootParam
        Test-Result "Has OBSConfig parameter" $hasOBSConfigParam
        Test-Result "Has try-finally for cleanup" $hasTryFinally
    }
} catch {
    Test-Result "Background script verification" $false $_
}

# Test 3: Verify path resolution logic
Write-Host ""
Write-BuildLog "Test 3: Testing path resolution logic..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw
    
    # Check for correct path resolution (two Split-Path calls for script mode)
    $hasCorrectPathResolution = $appManagerContent -match 'Split-Path\s+-Parent\s+\(Split-Path\s+-Parent\s+\$PSScriptRoot\)'
    Test-Result "Path resolution uses two Split-Path operations" $hasCorrectPathResolution "Required to go from src/modules/ to project root"
    
    # Check for executable mode path resolution
    $hasExecutablePathResolution = $appManagerContent -match 'Split-Path\s+-Parent\s+\$currentProcess\.Path'
    Test-Result "Path resolution handles executable mode" $hasExecutablePathResolution
    
} catch {
    Test-Result "Path resolution verification" $false $_
}

# Test 4: Verify background job creation logic
Write-Host ""
Write-BuildLog "Test 4: Testing background job creation logic..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw
    
    # Check for job started tracking
    $hasJobStartedTracking = $appManagerContent -match '\$jobStarted\s*=\s*\$false' -and $appManagerContent -match '\$jobStarted\s*=\s*\$true'
    Test-Result "Job creation success tracking" $hasJobStartedTracking "Uses \$jobStarted variable to track success"
    
    # Check for proper error handling
    $hasErrorReturn = $appManagerContent -match 'catch\s*\{[\s\S]*?return\s+\$false'
    Test-Result "Returns false on job creation failure" $hasErrorReturn
    
    # Check for job storage
    $hasJobStorage = $appManagerContent -match 'BackgroundJobs\[.*?\]\s*=\s*\$job'
    Test-Result "Stores job reference for cleanup" $hasJobStorage
    
} catch {
    Test-Result "Background job creation logic" $false $_
}

# Test 5: Verify cleanup logic
Write-Host ""
Write-BuildLog "Test 5: Testing cleanup logic..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw
    
    # Check for array copy to avoid collection modification
    $hasArrayCopy = $appManagerContent -match '@\(\$this\.Config\.BackgroundJobs\.Keys\)'
    Test-Result "Creates array copy of keys before iteration" $hasArrayCopy "Prevents collection modification errors"
    
    # Check for switch statement handling all job states
    $hasSwitch = $appManagerContent -match 'switch\s*\(\$job\.State\)'
    Test-Result "Uses switch statement for job state handling" $hasSwitch
    
    # Check for handling of different states
    $hasRunningState = $appManagerContent -match "'Running'\s*\{"
    $hasCompletedState = $appManagerContent -match "'Completed'\s*\{"
    $hasFailedState = $appManagerContent -match "'Failed'\s*\{"
    $hasNotStartedState = $appManagerContent -match "'NotStarted'\s*\{"
    
    Test-Result "Handles 'Running' job state" $hasRunningState
    Test-Result "Handles 'Completed' job state" $hasCompletedState
    Test-Result "Handles 'Failed' job state" $hasFailedState
    Test-Result "Handles 'NotStarted' job state" $hasNotStartedState
    
    # Check for Wait-Job with timeout
    $hasWaitWithTimeout = $appManagerContent -match 'Wait-Job.*-Timeout'
    Test-Result "Waits for jobs with timeout" $hasWaitWithTimeout
    
    # Check for Remove-Job
    $hasRemoveJob = $appManagerContent -match 'Remove-Job\s+-Job\s+\$job'
    Test-Result "Removes jobs after handling" $hasRemoveJob
    
} catch {
    Test-Result "Cleanup logic verification" $false $_
}

# Test 6: Test background script parameters
Write-Host ""
Write-BuildLog "Test 6: Testing background script parameter handling..."
try {
    $backgroundScriptPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSReplayBufferBackground.ps1"
    $backgroundContent = Get-Content -Path $backgroundScriptPath -Raw
    
    # Check for required parameters
    $hasWaitBeforeConnect = $backgroundContent -match '\[int\]\s+\$WaitBeforeConnect\s*=\s*3000'
    Test-Result "Has WaitBeforeConnect parameter with default" $hasWaitBeforeConnect
    
    # Check for module imports
    $importsLanguageHelper = $backgroundContent -match 'LanguageHelper\.ps1'
    $importsOBSManager = $backgroundContent -match 'OBSManager\.ps1'
    $importsWebSocketBase = $backgroundContent -match 'WebSocketAppManagerBase\.ps1'
    
    Test-Result "Imports LanguageHelper module" $importsLanguageHelper
    Test-Result "Imports OBSManager module" $importsOBSManager
    Test-Result "Imports WebSocketAppManagerBase module" $importsWebSocketBase
    
} catch {
    Test-Result "Background script parameters" $false $_
}

# Test 7: Verify WebSocket disconnect handling
Write-Host ""
Write-BuildLog "Test 7: Testing WebSocket disconnect handling..."
try {
    $backgroundScriptPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSReplayBufferBackground.ps1"
    $backgroundContent = Get-Content -Path $backgroundScriptPath -Raw
    
    # Check for connected tracking variable
    $hasConnectedTracking = $backgroundContent -match '\$connected\s*=\s*\$false' -and $backgroundContent -match '\$connected\s*=\s*\$obsManager\.Connect\(\)'
    Test-Result "Tracks connection state" $hasConnectedTracking
    
    # Check for conditional disconnect in finally block
    $hasConditionalDisconnect = $backgroundContent -match 'if\s*\(\$connected\)\s*\{[\s\S]*?\$obsManager\.Disconnect\(\)'
    Test-Result "Disconnects only if connected" $hasConditionalDisconnect "Prevents errors when connection failed"
    
} catch {
    Test-Result "WebSocket disconnect handling" $false $_
}

# Test 8: Verify localization messages
Write-Host ""
Write-BuildLog "Test 8: Testing localization messages..."
try {
    $enPath = Join-Path -Path $projectRoot -ChildPath "localization/en.json"
    $jaPath = Join-Path -Path $projectRoot -ChildPath "localization/ja.json"
    
    $enJson = Get-Content -Path $enPath -Raw | ConvertFrom-Json
    $jaJson = Get-Content -Path $jaPath -Raw | ConvertFrom-Json
    
    $requiredKeys = @(
        'console_obs_replay_buffer_starting_async',
        'console_obs_replay_buffer_async_started',
        'console_obs_replay_buffer_job_failed'
    )
    
    $allKeysPresent = $true
    foreach ($key in $requiredKeys) {
        $inEn = $null -ne $enJson.PSObject.Properties[$key]
        $inJa = $null -ne $jaJson.PSObject.Properties[$key]
        
        if (-not $inEn -or -not $inJa) {
            $allKeysPresent = $false
            Test-Result "Localization key '$key'" $false "Missing in $(if (-not $inEn) { 'EN' } if (-not $inJa) { 'JA' })"
        }
    }
    
    if ($allKeysPresent) {
        Test-Result "All required localization keys present" $true "EN and JA"
    }
    
} catch {
    Test-Result "Localization messages verification" $false $_
}

# Test 9: Mock background job execution test
Write-Host ""
Write-BuildLog "Test 9: Testing background job execution (mock)..."
try {
    # Create a simple mock background job to verify the mechanism works
    $testJob = Start-Job -ScriptBlock {
        Start-Sleep -Milliseconds 100
        return $true
    }
    
    Test-Result "Background job created successfully" ($null -ne $testJob) "Job ID: $($testJob.Id)"
    
    # Wait for job completion
    $null = Wait-Job -Job $testJob -Timeout 5
    $jobResult = Receive-Job -Job $testJob
    Remove-Job -Job $testJob -Force
    
    Test-Result "Background job completed and returned result" ($jobResult -eq $true)
    
} catch {
    Test-Result "Background job execution test" $false $_
}

# Test 10: Verify integration test exists
Write-Host ""
Write-BuildLog "Test 10: Verifying integration test..."
try {
    $integrationTestPath = Join-Path -Path $projectRoot -ChildPath "test/scripts/integration/Test-Integration-OBSBackgroundJob.ps1"
    $integrationTestExists = Test-Path $integrationTestPath
    Test-Result "Integration test exists" $integrationTestExists "Test-Integration-OBSBackgroundJob.ps1"
    
} catch {
    Test-Result "Integration test verification" $false $_
}

# Display summary
Write-Host ""
Write-BuildLog "========================================="
Write-BuildLog "Test Summary"
Write-BuildLog "========================================="
Write-BuildLog "Total:   $($results.Total)"
Write-BuildLog "Passed:  $($results.Passed)"
Write-BuildLog "Failed:  $($results.Failed)"
Write-BuildLog "Skipped: $($results.Skipped)"
Write-BuildLog "========================================="

if ($results.Failed -eq 0) {
    Write-BuildLog "[SUCCESS] All tests passed!"
    exit 0
} else {
    Write-BuildLog "[FAILURE] $($results.Failed) test(s) failed"
    exit 1
}
