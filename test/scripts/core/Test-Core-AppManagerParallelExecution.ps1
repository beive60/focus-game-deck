#Requires -Version 5.1

<#
.SYNOPSIS
    Unit test for AppManager background job implementation.

.DESCRIPTION
    This script tests the AppManager's background job implementation for OBS replay buffer
    parallel processing. It validates that:
    - Background jobs use inline ScriptBlock (not external file) for ps2exe compatibility
    - Password decryption is performed in main process before job starts
    - Job cleanup handles all states properly
    - WebSocket operations are properly encapsulated in try-finally blocks
    - Error handling returns correct values

    This is a unit test that validates the implementation structure and patterns.
    Integration tests with actual OBS Studio are separate.

.NOTES
    Author: Focus Game Deck Team
    Version: 2.0.0
    Created: 2026-01-28
    Updated: 2026-02-04 - Updated for inline ScriptBlock implementation
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

# Test 2: Verify background job ScriptBlock exists in AppManager
Write-Host ""
Write-BuildLog "Test 2: Verifying background job ScriptBlock in AppManager..."
try {
    $appManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1"
    $appManagerContent = Get-Content -Path $appManagerPath -Raw

    # Check for inline ScriptBlock (not external file)
    $hasScriptBlock = $appManagerContent -match 'Start-Job\s+-ScriptBlock\s+\{'
    Test-Result "Background job uses inline ScriptBlock" $hasScriptBlock "Embedded in AppManager for ps2exe compatibility"

    # Check for parameters passed to background job
    $hasOBSHostnameParam = $appManagerContent -match 'param\(\$OBSHostname'
    $hasOBSPortParam = $appManagerContent -match '\$OBSPort'
    $hasPlainPasswordParam = $appManagerContent -match '\$PlainPassword'

    Test-Result "Background job receives OBS hostname parameter" $hasOBSHostnameParam
    Test-Result "Background job receives OBS port parameter" $hasOBSPortParam
    Test-Result "Background job receives pre-decrypted password" $hasPlainPasswordParam "Main process decrypts, passes plaintext to job"

    # Check for try-finally cleanup
    $hasTryFinally = $appManagerContent -match 'ScriptBlock\s+\{[\s\S]*?try\s+\{[\s\S]*?\}\s+catch[\s\S]*?\}\s+finally'
    Test-Result "Background job has try-catch-finally structure" $hasTryFinally
} catch {
    Test-Result "Background job ScriptBlock verification" $false $_
}

# Test 3: Verify password decryption in main process
Write-Host ""
Write-BuildLog "Test 3: Testing password decryption in main process..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw

    # Check for password decryption before job starts
    $hasPasswordDecryption = $appManagerContent -match 'ConvertTo-SecureString\s+-String\s+\$config\.websocket\.password'
    Test-Result "Decrypts password in main process" $hasPasswordDecryption "Required for ps2exe background job compatibility"

    # Check for BSTR conversion
    $hasBSTRConversion = $appManagerContent -match 'SecureStringToBSTR'
    Test-Result "Converts SecureString to plaintext via BSTR" $hasBSTRConversion

    # Check for ZeroFreeBSTR cleanup
    $hasZeroFreeBSTR = $appManagerContent -match 'ZeroFreeBSTR'
    Test-Result "Cleans up BSTR memory securely" $hasZeroFreeBSTR

} catch {
    Test-Result "Password decryption verification" $false $_
}

# Test 4: Verify background job creation logic
Write-Host ""
Write-BuildLog "Test 4: Testing background job creation logic..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw

    # Check for BackgroundJobs property
    $hasBackgroundJobsProperty = $appManagerContent -match '\[System\.Collections\.ArrayList\]\s+\$BackgroundJobs'
    Test-Result "Has BackgroundJobs ArrayList property" $hasBackgroundJobsProperty

    # Check for BackgroundJobs initialization in constructor
    $hasBackgroundJobsInit = $appManagerContent -match '\$this\.BackgroundJobs\s*=\s*New-Object\s+System\.Collections\.ArrayList'
    Test-Result "Initializes BackgroundJobs in constructor" $hasBackgroundJobsInit

    # Check for job storage using ArrayList Add method
    $hasJobStorage = $appManagerContent -match '\$this\.BackgroundJobs\.Add\('
    Test-Result "Stores job reference using ArrayList.Add()" $hasJobStorage

    # Check for ArgumentList with decrypted password
    $hasArgumentList = $appManagerContent -match '-ArgumentList.*\$plainPassword'
    Test-Result "Passes decrypted password in ArgumentList" $hasArgumentList

} catch {
    Test-Result "Background job creation logic" $false $_
}

# Test 5: Verify cleanup logic
Write-Host ""
Write-BuildLog "Test 5: Testing cleanup logic..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw

    # Check for BackgroundJobs.Count check
    $hasCountCheck = $appManagerContent -match 'if\s+\(\$this\.BackgroundJobs\.Count\s+-gt\s+0\)'
    Test-Result "Checks BackgroundJobs count before cleanup" $hasCountCheck

    # Check for foreach loop over jobs
    $hasForeachLoop = $appManagerContent -match 'foreach\s+\(\$job\s+in\s+\$this\.BackgroundJobs\)'
    Test-Result "Iterates over BackgroundJobs collection" $hasForeachLoop

    # Check for Wait-Job with timeout
    $hasWaitWithTimeout = $appManagerContent -match 'Wait-Job\s+-Timeout\s+\d+'
    Test-Result "Waits for jobs with timeout" $hasWaitWithTimeout

    # Check for Receive-Job to get results
    $hasReceiveJob = $appManagerContent -match 'Receive-Job\s+-Job'
    Test-Result "Receives job results before cleanup" $hasReceiveJob

    # Check for Remove-Job
    $hasRemoveJob = $appManagerContent -match 'Remove-Job\s+-Job\s+\$job\s+-Force'
    Test-Result "Removes jobs after handling" $hasRemoveJob

    # Check for BackgroundJobs.Clear()
    $hasClear = $appManagerContent -match '\$this\.BackgroundJobs\.Clear\(\)'
    Test-Result "Clears BackgroundJobs collection" $hasClear

} catch {
    Test-Result "Cleanup logic verification" $false $_
}

# Test 6: Test background job ScriptBlock parameters
Write-Host ""
Write-BuildLog "Test 6: Testing background job ScriptBlock parameters..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw

    # Extract ScriptBlock to check parameters
    $scriptBlockMatch = $appManagerContent -match 'Start-Job\s+-ScriptBlock\s+\{[\s\S]*?param\(([^\)]+)\)'
    $hasOBSHostnameParam = $appManagerContent -match 'param\(\$OBSHostname'
    $hasOBSPortParam = $appManagerContent -match '\$OBSPort'
    $hasPlainPasswordParam = $appManagerContent -match '\$PlainPassword'
    $hasMessagesDataParam = $appManagerContent -match '\$MessagesData'
    $hasWaitBeforeConnect = $appManagerContent -match '\$WaitBeforeConnect'

    Test-Result "Has OBSHostname parameter" $hasOBSHostnameParam
    Test-Result "Has OBSPort parameter" $hasOBSPortParam
    Test-Result "Has PlainPassword parameter" $hasPlainPasswordParam
    Test-Result "Has MessagesData parameter" $hasMessagesDataParam
    Test-Result "Has WaitBeforeConnect parameter" $hasWaitBeforeConnect

    # Check for ArgumentList passing these values
    $hasArgumentListValues = $appManagerContent -match '-ArgumentList.*\$config\.websocket\.host.*\$config\.websocket\.port'
    Test-Result "ArgumentList passes all required values" $hasArgumentListValues

} catch {
    Test-Result "Background job ScriptBlock parameters" $false $_
}

# Test 7: Verify WebSocket handling in background job
Write-Host ""
Write-BuildLog "Test 7: Testing WebSocket handling in background job..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw

    # Check for WebSocket creation
    $hasWebSocketCreation = $appManagerContent -match 'New-Object\s+System\.Net\.WebSockets\.ClientWebSocket'
    Test-Result "Creates WebSocket client in background job" $hasWebSocketCreation

    # Check for WebSocket connection
    $hasConnectAsync = $appManagerContent -match '\.ConnectAsync\('
    Test-Result "Connects to WebSocket asynchronously" $hasConnectAsync

    # Check for WebSocket cleanup in finally block
    $hasFinallyCleanup = $appManagerContent -match 'finally\s*\{[\s\S]*?if\s*\(\$webSocket\)'
    Test-Result "Cleans up WebSocket in finally block" $hasFinallyCleanup "Ensures proper resource disposal"

    # Check for CloseAsync
    $hasCloseAsync = $appManagerContent -match '\.CloseAsync\('
    Test-Result "Closes WebSocket gracefully" $hasCloseAsync

} catch {
    Test-Result "WebSocket handling verification" $false $_
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
        'console_obs_replay_buffer_starting_background',
        'console_obs_replay_buffer_job_failed',
        'console_obs_replay_buffer_job_error'
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

# Test 10: Verify OBS authentication in background job
Write-Host ""
Write-BuildLog "Test 10: Testing OBS authentication in background job..."
try {
    $appManagerContent = Get-Content -Path (Join-Path -Path $projectRoot -ChildPath "src/modules/AppManager.ps1") -Raw

    # Check for Hello message handling (Op 0)
    $hasHelloHandling = $appManagerContent -match 'Receive-WebSocketResponse' -and $appManagerContent -match 'hello\.op'
    Test-Result "Handles OBS Hello message" $hasHelloHandling

    # Check for authentication challenge handling
    $hasAuthChallenge = $appManagerContent -match 'hello\.d\.authentication' -and $appManagerContent -match 'challenge'
    Test-Result "Handles authentication challenge" $hasAuthChallenge

    # Check for SHA256 hash computation
    $hasSHA256 = $appManagerContent -match 'System\.Security\.Cryptography\.SHA256'
    Test-Result "Computes SHA256 hashes for authentication" $hasSHA256

    # Check for Identify message (Op 1)
    $hasIdentify = $appManagerContent -match 'op\s*=\s*1'
    Test-Result "Sends Identify message to OBS" $hasIdentify

    # Check for StartReplayBuffer request (Op 6)
    $hasStartReplayBuffer = $appManagerContent -match 'StartReplayBuffer'
    Test-Result "Sends StartReplayBuffer request" $hasStartReplayBuffer

} catch {
    Test-Result "OBS authentication verification" $false $_
}

# Display summary
    Write-Host ""
    Write-BuildLog "========================================="
    Write-BuildLog "Test Summary"
    Write-BuildLog "========================================="
    Write-BuildLog "Total: $($results.Total)"
    Write-BuildLog "Passed: $($results.Passed)"
    Write-BuildLog "Failed: $($results.Failed)"
    Write-BuildLog "Skipped: $($results.Skipped)"
    Write-BuildLog "========================================="

    if ($results.Failed -eq 0) {
        Write-BuildLog "[SUCCESS] All tests passed!"
        exit 0
    } else {
        Write-BuildLog "[FAILURE] $($results.Failed) test(s) failed"
        exit 1
    }
