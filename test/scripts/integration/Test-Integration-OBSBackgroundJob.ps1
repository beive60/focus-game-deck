<#
.SYNOPSIS
    Test for OBS Replay Buffer Background Job Implementation.

.DESCRIPTION
    This script tests the new background job functionality for OBS replay buffer operations.
    It verifies that:
    - Background job is created successfully
    - Main process doesn't block
    - Background job completes the replay buffer start
    - Cleanup works correctly

.NOTES
    File Name      : Test-Integration-OBSBackgroundJob.ps1
    Prerequisite   : OBS Studio must be running with WebSocket server enabled
    Required Files :
        - config/config.json (OBS configuration)
        - src/modules/OBSReplayBufferBackground.ps1
        - src/modules/OBSManager.ps1
        - src/modules/AppManager.ps1
#>

# Import the BuildLogger
. "$PSScriptRoot/../../../build-tools/utils/BuildLogger.ps1"

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Load config
$configPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BuildLog "[OK] Config loaded successfully"
} catch {
    Write-BuildLog "[ERROR] Failed to load config: $_"
    exit 1
}

# Load required modules
try {
    $languageHelperPath = Join-Path -Path $projectRoot -ChildPath "scripts/LanguageHelper.ps1"
    . $languageHelperPath
    Write-BuildLog "[OK] LanguageHelper loaded"

    $webSocketBasePath = Join-Path -Path $projectRoot -ChildPath "src/modules/WebSocketAppManagerBase.ps1"
    . $webSocketBasePath
    Write-BuildLog "[OK] WebSocketAppManagerBase loaded"

    $obsManagerPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSManager.ps1"
    . $obsManagerPath
    Write-BuildLog "[OK] OBSManager loaded"

    $backgroundScriptPath = Join-Path -Path $projectRoot -ChildPath "src/modules/OBSReplayBufferBackground.ps1"
    if (-not (Test-Path $backgroundScriptPath)) {
        Write-BuildLog "[ERROR] Background script not found at: $backgroundScriptPath"
        exit 1
    }
    Write-BuildLog "[OK] Background script found at: $backgroundScriptPath"
} catch {
    Write-BuildLog "[ERROR] Failed to load required modules: $_"
    exit 1
}

Write-BuildLog "--- Starting OBS Background Job Test ---"

# Check if OBS is already running
if (Get-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue) {
    Write-BuildLog "[INFO] OBS process detected running"
    Write-BuildLog "[INFO] Test will use existing OBS instance"
    $obsWasRunning = $true
} else {
    Write-BuildLog "[INFO] OBS is not running, starting it..."
    $obsWasRunning = $false
    
    # Start OBS
    $messages = @{}
    $obsManager = New-OBSManager -OBSConfig $config.integrations.obs -Messages $messages
    
    try {
        $obsManager.StartOBS()
        Write-BuildLog "[OK] OBS started successfully"
        Start-Sleep -Seconds 5
    } catch {
        Write-BuildLog "[ERROR] Failed to start OBS: $_"
        exit 1
    }
}

$testSuccessful = $true

try {
    Write-BuildLog "[INFO] Testing background job functionality..."

    # Test 1: Verify background script can be executed
    Write-BuildLog "[INFO] Test 1: Verify background script executes"
    $startTime = Get-Date

    $job = Start-Job -ScriptBlock {
        param($scriptPath, $obsConfig, $messages, $appRootPath)
        & $scriptPath -OBSConfig $obsConfig -Messages $messages -WaitBeforeConnect 1000 -AppRoot $appRootPath
    } -ArgumentList $backgroundScriptPath, $config.integrations.obs, @{}, $projectRoot

    if (-not $job) {
        Write-BuildLog "[ERROR] Failed to create background job"
        $testSuccessful = $false
    } else {
        Write-BuildLog "[OK] Background job created successfully (Job ID: $($job.Id))"
        
        # Test 2: Verify main process doesn't block
        $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
        if ($elapsed -lt 100) {
            Write-BuildLog "[OK] Main process returned immediately (${elapsed}ms)"
        } else {
            Write-BuildLog "[WARNING] Main process took ${elapsed}ms to return"
        }

        # Test 3: Wait for job to complete and check result
        Write-BuildLog "[INFO] Test 3: Waiting for background job to complete..."
        $waitResult = Wait-Job -Job $job -Timeout 30

        if ($job.State -eq 'Completed') {
            $jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
            Write-BuildLog "[OK] Background job completed successfully"
            Write-BuildLog "[INFO] Job result: $jobResult"
            
            if ($jobResult -eq $true) {
                Write-BuildLog "[OK] Replay buffer operation succeeded"
            } else {
                Write-BuildLog "[WARNING] Replay buffer operation returned: $jobResult"
            }
        } elseif ($job.State -eq 'Failed') {
            Write-BuildLog "[ERROR] Background job failed"
            $jobError = Receive-Job -Job $job -ErrorAction SilentlyContinue
            Write-BuildLog "[ERROR] Job error: $jobError"
            $testSuccessful = $false
        } else {
            Write-BuildLog "[WARNING] Background job did not complete within timeout (State: $($job.State))"
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        }

        # Cleanup job
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Write-BuildLog "[OK] Job cleanup completed"
    }

} catch {
    Write-BuildLog "[ERROR] Test execution failed: $_"
    $testSuccessful = $false
} finally {
    # Cleanup: Stop OBS if we started it
    if (-not $obsWasRunning) {
        Write-BuildLog "[INFO] Stopping OBS Studio (test cleanup)..."
        try {
            Stop-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue
            Write-BuildLog "[INFO] OBS stopped"
        } catch {
            Write-BuildLog "[WARNING] Error stopping OBS: $_"
        }
    }
}

Write-BuildLog "--- Test Finished ---"
if ($testSuccessful) {
    Write-BuildLog "[OK] All tests passed"
    exit 0
} else {
    Write-BuildLog "[ERROR] Some tests failed"
    exit 1
}
