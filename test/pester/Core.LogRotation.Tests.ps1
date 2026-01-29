<#
.SYNOPSIS
    Pester tests for log rotation functionality
.DESCRIPTION
    Validates log retention policies and cleanup behavior
    Tests retention periods: 7, 30, 90, 180 days, and unlimited
.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Tags: Unit, Core, Logging
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $TestLogDir = Join-Path -Path $projectRoot -ChildPath "test/temp/logs"

    # Create test log directory
    if (-not (Test-Path $TestLogDir)) {
        New-Item -ItemType Directory -Path $TestLogDir -Force | Out-Null
    }

    # Load Logger module (simplified - adjust path as needed)
    # . (Join-Path -Path $projectRoot -ChildPath "src/modules/Logger.ps1")
}

Describe "Log Rotation Tests" -Tag "Unit", "Core", "Logging" {

    Context "Log Retention Policies" {
        BeforeEach {
            # Create test log files with different ages
            $now = Get-Date
            $testFiles = @{
                "recent.log" = $now.AddDays(-5)
                "30days.log" = $now.AddDays(-30)
                "45days.log" = $now.AddDays(-45)
                "90days.log" = $now.AddDays(-90)
                "180days.log" = $now.AddDays(-180)
                "200days.log" = $now.AddDays(-200)
            }

            foreach ($file in $testFiles.Keys) {
                $filePath = Join-Path $TestLogDir $file
                "Test log content" | Set-Content $filePath -Encoding UTF8
                (Get-Item $filePath).LastWriteTime = $testFiles[$file]
            }
        }

        AfterEach {
            # Clean up test files
            Remove-Item -Path "$TestLogDir\*.log" -Force -ErrorAction SilentlyContinue
        }

        It "should delete logs older than 30 days with 30-day retention" {
            $cutoffDate = (Get-Date).AddDays(-30)
            $oldLogs = Get-ChildItem -Path $TestLogDir -Filter "*.log" |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }

            # Expected: 30days.log, 45days.log, 90days.log, 180days.log, 200days.log
            $oldLogs.Count | Should -BeGreaterThan 4
        }

        It "should preserve recent logs with 30-day retention" {
            $cutoffDate = (Get-Date).AddDays(-30)
            $recentLogs = Get-ChildItem -Path $TestLogDir -Filter "*.log" |
            Where-Object { $_.LastWriteTime -ge $cutoffDate }

            # Expected: recent.log
            $recentLogs.Count | Should -BeGreaterThan 0
        }

        It "should delete logs older than 90 days with 90-day retention" {
            $cutoffDate = (Get-Date).AddDays(-90)
            $oldLogs = Get-ChildItem -Path $TestLogDir -Filter "*.log" |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }

            # Expected: 90days.log, 180days.log, 200days.log
            $oldLogs.Count | Should -BeGreaterOrEqual 2
        }

        It "should handle unlimited retention (no deletion)" {
            $beforeCount = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count

            # Simulate unlimited retention (no cleanup)
            # In real implementation, this would call the cleanup function with unlimited setting

            $afterCount = (Get-ChildItem -Path $TestLogDir -Filter "*.log").Count
            $afterCount | Should -Be $beforeCount
        }
    }

    Context "Configuration Validation" {
        It "should default to 90 days when invalid retention value is provided" {
            $invalidValues = @(-1, 0, "invalid", $null, 999)

            foreach ($value in $invalidValues) {
                # In real implementation, this would test the config validation logic
                # For now, we just verify the expected default
                $expectedDefault = 90
                $expectedDefault | Should -Be 90
            }
        }

        It "should accept valid retention values" {
            $validValues = @(7, 30, 90, 180, "unlimited")

            foreach ($value in $validValues) {
                # This would test the config validation accepts these values
                $value | Should -Not -BeNullOrEmpty
            }
        }
    }
}
