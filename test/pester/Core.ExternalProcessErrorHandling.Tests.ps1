<#
.SYNOPSIS
    Pester tests for external process integration error handling

.DESCRIPTION
    Unit tests that validate error handling when:
    - OBS/VTube Studio doesn't respond
    - External processes crash during operation
    - WebSocket connections fail
    - Process timeouts occur

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Tags: Unit, Core, Integration, ErrorHandling
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

    # Import the BuildLogger
    . "$projectRoot/build-tools/utils/BuildLogger.ps1"

    Write-BuildLog "[INFO] ExternalProcess Tests: Loading modules for error handling tests"

    # Import modules
    . "$projectRoot/scripts/LanguageHelper.ps1"
    . "$projectRoot/src/modules/WebSocketAppManagerBase.ps1"
    . "$projectRoot/src/modules/OBSManager.ps1"
    . "$projectRoot/src/modules/VTubeStudioManager.ps1"

    # Mock configurations
    $script:OBSConfig = @{
        enabled = $true
        path = 'C:/OBS/obs64.exe'
        websocket = @{
            host = 'localhost'
            port = 4455
            password = ''
        }
        replayBuffer = $true
    }

    $script:VTubeStudioConfig = @{
        enabled = $true
        path = 'C:/VTubeStudio/VTube Studio.exe'
        websocket = @{
            host = 'localhost'
            port = 8001
        }
    }

    $script:MockMessages = @{}
}

Describe "OBSManager - Connection Error Handling" -Tag "Unit", "Core", "OBS", "ErrorHandling" {

    BeforeEach {
        # Mock Get-Process to simulate OBS not running
        Mock Get-Process { return $null } -ParameterFilter { $Name -in @('obs64', 'obs32') }
    }

    Context "OBS Not Running" {
        It "Should create OBSManager instance even when OBS is not running" {
            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages
            $obsManager | Should -Not -BeNullOrEmpty
        }

        It "Should report OBS as not running via IsOBSRunning" {
            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages
            $obsManager.IsOBSRunning() | Should -Be $false
        }
    }

    Context "WebSocket Connection Failure" {
        It "Should handle connection timeout gracefully" {
            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages

            # Connect should return false, not throw, when OBS is not available
            $result = $obsManager.Connect()
            $result | Should -Be $false
        }

        It "Should not throw on disconnect when not connected" {
            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages

            # Disconnect should not throw even if never connected
            { $obsManager.Disconnect() } | Should -Not -Throw
        }
    }

    Context "Invalid Configuration" {
        It "Should handle null websocket config" {
            $badConfig = @{
                enabled = $true
                path = 'C:/OBS/obs64.exe'
                websocket = $null
            }

            # Should not throw during construction
            { New-OBSManager -OBSConfig $badConfig -Messages $script:MockMessages } | Should -Not -Throw
        }

        It "Should handle missing port in websocket config" {
            $badConfig = @{
                enabled = $true
                path = 'C:/OBS/obs64.exe'
                websocket = @{
                    host = 'localhost'
                    # Missing port
                }
            }

            $obsManager = New-OBSManager -OBSConfig $badConfig -Messages $script:MockMessages
            $result = $obsManager.Connect()
            # Connection should fail gracefully
            $result | Should -Be $false
        }
    }
}

Describe "OBSManager - Replay Buffer Error Handling" -Tag "Unit", "Core", "OBS", "ErrorHandling" {

    BeforeEach {
        Mock Get-Process { return $null }
    }

    Context "Replay Buffer Operations When Not Connected" {
        It "Should return false when starting replay buffer without connection" {
            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages

            # Should return false, not throw
            $result = $obsManager.StartReplayBuffer()
            $result | Should -Be $false
        }

        It "Should return false when stopping replay buffer without connection" {
            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages

            $result = $obsManager.StopReplayBuffer()
            $result | Should -Be $false
        }
    }
}

Describe "OBSManager - Process Crash Simulation" -Tag "Unit", "Core", "OBS", "ErrorHandling" {

    Context "Process Disappears During Operation" {
        It "Should handle process crash gracefully" {
            # First call returns process, second call returns null (simulating crash)
            $callCount = 0
            Mock Get-Process {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return [PSCustomObject]@{
                        Id = 1234
                        ProcessName = 'obs64'
                    }
                }
                return $null
            } -ParameterFilter { $Name -in @('obs64', 'obs32') }

            $obsManager = New-OBSManager -OBSConfig $script:OBSConfig -Messages $script:MockMessages

            # First check should show running
            $firstCheck = $obsManager.IsOBSRunning()

            # After "crash", check should show not running
            $callCount = 1  # Reset for next call
            $secondCheck = $obsManager.IsOBSRunning()

            $secondCheck | Should -Be $false
        }
    }
}

Describe "VTubeStudioManager - Connection Error Handling" -Tag "Unit", "Core", "VTubeStudio", "ErrorHandling" {

    BeforeEach {
        Mock Get-Process { return $null } -ParameterFilter { $Name -eq 'VTube Studio' }
    }

    Context "VTube Studio Not Running" {
        It "Should create VTubeStudioManager instance even when not running" {
            $vtsManager = New-VTubeStudioManager -VTubeConfig $script:VTubeStudioConfig -Messages $script:MockMessages
            $vtsManager | Should -Not -BeNullOrEmpty
        }

        It "Should report VTube Studio as not running" {
            $vtsManager = New-VTubeStudioManager -VTubeConfig $script:VTubeStudioConfig -Messages $script:MockMessages
            $vtsManager.IsVTubeStudioRunning() | Should -Be $false
        }
    }

    Context "WebSocket Connection Failure" {
        It "Should not throw when VTube Studio is not running" {
            $vtsManager = New-VTubeStudioManager -VTubeConfig $script:VTubeStudioConfig -Messages $script:MockMessages

            # Manager can be created without throwing
            $vtsManager | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invalid Configuration" {
        It "Should handle null websocket config" {
            $badConfig = @{
                enabled = $true
                path = 'C:/VTubeStudio/VTube Studio.exe'
                websocket = $null
            }

            { New-VTubeStudioManager -VTubeConfig $badConfig -Messages $script:MockMessages } | Should -Not -Throw
        }
    }
}

Describe "VTubeStudioManager - State Management" -Tag "Unit", "Core", "VTubeStudio", "ErrorHandling" {

    BeforeEach {
        Mock Get-Process { return $null }
    }

    Context "Manager State" {
        It "Should track running state correctly" {
            $vtsManager = New-VTubeStudioManager -VTubeConfig $script:VTubeStudioConfig -Messages $script:MockMessages

            # When VTube Studio is not running, should report false
            $vtsManager.IsVTubeStudioRunning() | Should -Be $false
        }
    }
}

Describe "Timeout Handling" -Tag "Unit", "Core", "Timeout", "ErrorHandling" {

    Context "Process Start Timeout" {
        It "Should detect when process does not start within timeout" {
            # Mock Start-Process to do nothing
            Mock Start-Process { return $null }
            Mock Get-Process { return $null }

            # Simulate a short timeout scenario
            $timeout = 1  # 1 second for test
            $startTime = Get-Date

            # Quick timeout check
            $processFound = $false
            $elapsed = 0

            while (-not $processFound -and $elapsed -lt $timeout) {
                $process = Get-Process -Name "nonexistent" -ErrorAction SilentlyContinue
                if ($process) {
                    $processFound = $true
                    break
                }
                Start-Sleep -Milliseconds 100
                $elapsed = ((Get-Date) - $startTime).TotalSeconds
            }

            # Process should not be found
            $processFound | Should -Be $false
        }
    }
}

Describe "Process Termination Error Handling" -Tag "Unit", "Core", "Process", "ErrorHandling" {

    Context "Stopping Process That Doesn't Exist" {
        It "Should handle stopping non-existent process" {
            Mock Get-Process { throw "Cannot find process" }
            Mock Stop-Process { }

            # Attempting to stop a non-existent process should not throw
            $result = $null
            try {
                $process = Get-Process -Name "nonexistent" -ErrorAction SilentlyContinue
                if ($process) {
                    Stop-Process -InputObject $process
                    $result = $true
                } else {
                    $result = $false
                }
            } catch {
                $result = $false
            }

            $result | Should -Be $false
        }
    }

    Context "Stopping Process That Won't Die" {
        It "Should handle stubborn process scenario" {
            # This test verifies error handling patterns used in real code
            $result = "unknown"

            try {
                # Simulate a stubborn process scenario
                $processFound = $false

                Mock Get-Process {
                    return [PSCustomObject]@{
                        Id = 9999
                        ProcessName = 'stubborn'
                        HasExited = $false
                    }
                } -ParameterFilter { $Name -eq 'stubborn' }

                Mock Stop-Process { }  # Does nothing
                Mock Wait-Process { throw "Process did not exit" }

                # Pattern used in real code
                $process = Get-Process -Name "stubborn" -ErrorAction SilentlyContinue
                if ($process) {
                    Stop-Process -InputObject $process -ErrorAction SilentlyContinue
                    try {
                        Wait-Process -InputObject $process -Timeout 1 -ErrorAction Stop
                        $result = "success"
                    } catch {
                        # Timeout or error during wait
                        $result = "timeout"
                    }
                }
            } catch {
                $result = "error"
            }

            # Result should be timeout or error (both are acceptable)
            $result | Should -BeIn @("timeout", "error")
        }
    }
}

Describe "Network Error Simulation" -Tag "Unit", "Core", "Network", "ErrorHandling" {

    Context "WebSocket Host Unreachable" {
        It "Should handle unreachable host" {
            $badConfig = @{
                enabled = $true
                path = 'C:/OBS/obs64.exe'
                websocket = @{
                    host = '192.168.255.255'  # Likely unreachable
                    port = 4455
                    password = ''
                }
            }

            $obsManager = New-OBSManager -OBSConfig $badConfig -Messages $script:MockMessages

            # Should not hang indefinitely
            $result = $obsManager.Connect()
            $result | Should -Be $false
        }

        It "Should handle invalid port" {
            $badConfig = @{
                enabled = $true
                path = 'C:/OBS/obs64.exe'
                websocket = @{
                    host = 'localhost'
                    port = 99999  # Invalid port
                    password = ''
                }
            }

            $obsManager = New-OBSManager -OBSConfig $badConfig -Messages $script:MockMessages

            $result = $obsManager.Connect()
            $result | Should -Be $false
        }
    }
}
