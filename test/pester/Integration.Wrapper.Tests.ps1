<#
.SYNOPSIS
    Pester wrapper for existing Integration test scripts
.DESCRIPTION
    Wraps existing Test-Integration-*.ps1 scripts without modifying them
    These tests may require external services to be running
    This wrapper enables unified test reporting via Pester framework
    without requiring modifications to legacy test scripts
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Write-Information $projectRoot
}

Describe "Integration Tests" -Tag "Integration" {

    Context "Discord Integration" {
        It "should test Discord Rich Presence integration" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/integration/Test-Integration-Discord.ps1"

            if (-not (Test-Path $testScript)) {
                Set-ItResult -Skipped -Because "Discord test script not found"
                return
            }

            $output = & $testScript *>&1 | Out-String
            $outputText = $output

            # These tests may fail if Discord is not running - that's OK
            if ($outputText -match "Discord.*not running|not found") {
                Set-ItResult -Skipped -Because "[INFO] terminate OBS with 'Stop-Process -Name obs64,obs32' if you want to test starting OBS from this script."
            } else {
                $outputText | Should -Match "\[OK\]|\[PASS\]|Success"
            }
        }
    }

    Context "OBS Studio Integration" {
        It "should test OBS WebSocket connection" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/integration/Test-Integration-OBSWebSocket.ps1"

            if (-not (Test-Path $testScript)) {
                Set-ItResult -Skipped -Because "OBS test script not found"
                return
            }

            $output = & $testScript *>&1 | Out-String
            $outputText = $output

            # OBS tests may fail if OBS is not running
            if ($outputText -match "OBS.*not available|not found|connection.*failed") {
                Set-ItResult -Skipped -Because "OBS Studio not available in test environment"
            } else {
                $outputText | Should -Match "\[OK\]|\[PASS\]|Success"
            }
        }
    }

    Context "VTube Studio Integration" {
        It "should test VTube Studio WebSocket integration" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/integration/Test-Integration-VTubeStudio.ps1"

            if (-not (Test-Path $testScript)) {
                Set-ItResult -Skipped -Because "VTube Studio test script not found"
                return
            }

            $output = & $testScript *>&1 | Out-String
            $outputText = $output

            # VTube Studio tests may fail if not running
            if ($outputText -match "VTube Studio.*not running|not found") {
                Set-ItResult -Skipped -Because "VTube Studio not available in test environment"
            } else {
                $outputText | Should -Match "\[OK\]|\[PASS\]|Success"
            }
        }
    }

    Context "Log Notarization" {
        It "should test log authentication and notarization" {
            $testScript = Join-Path -Path $projectRoot -ChildPath "test/scripts/integration/Test-Integration-LogNotarization.ps1"

            if (-not (Test-Path $testScript)) {
                Set-ItResult -Skipped -Because "Log notarization test script not found"
                return
            }

            $output = & $testScript *>&1 | Out-String
            $outputText = $output

            if ($outputText -match "Log notarization.*not running|not found") {
                Set-ItResult -Skipped -Because "Log notarization not available in test environment"
            } else {
                $outputText | Should -Match "\[OK\]|\[PASS\]|Success"
            }
        }
    }
}
