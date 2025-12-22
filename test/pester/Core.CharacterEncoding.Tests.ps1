<#
.SYNOPSIS
    Pester tests for character encoding validation
.DESCRIPTION
    Validates UTF-8 encoding compliance across configuration files
    and ensures proper character handling per architecture guidelines
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

    # Import the BuildLogger
    . "$projectRoot/build-tools/utils/BuildLogger.ps1"

    $ConfigPath = Join-Path -Path $projectRoot -ChildPath "config/config.json"
    $LocalizationDir = Join-Path -Path $projectRoot -ChildPath "localization"
    $MessagesPath = Join-Path -Path $LocalizationDir -ChildPath "en.json"
}

Describe "Character Encoding Tests" -Tag "Core", "Encoding" {

    Context "JSON File Encoding" {
        It "config.json should be UTF-8 without BOM" {
            if (-not (Test-Path $ConfigPath)) {
                Set-ItResult -Skipped -Because "config.json not found at $ConfigPath"
                return
            }
            $bytes = [System.IO.File]::ReadAllBytes($ConfigPath)
            # UTF-8 BOM is EF BB BF
            $hasBOM = (
                $bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF)
            $hasBOM | Should -Be $false
        }

        It "config.json should be valid UTF-8" {
            if (-not (Test-Path $ConfigPath)) {
                Set-ItResult -Skipped -Because "config.json not found at $ConfigPath"
                return
            }
            {
                $content = Get-Content $ConfigPath -Raw -Encoding UTF8
                $content | ConvertFrom-Json
            } | Should -Not -Throw
        }

        It "en.json should be UTF-8 without BOM" {
            $bytes = [System.IO.File]::ReadAllBytes($MessagesPath)
            $hasBOM = (
                $bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF)
            $hasBOM | Should -Be $false
        }

        It "en.json should be valid UTF-8" {
            {
                $content = Get-Content $MessagesPath -Raw -Encoding UTF8
                $content | ConvertFrom-Json
            } | Should -Not -Throw
        }
    }

    Context "Japanese Character Integrity" {
        It "should correctly read Japanese characters from ja.json" {
            $jaPath = Join-Path -Path $LocalizationDir -ChildPath "ja.json"
            $messages = Get-Content $jaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $messages | Should -Not -BeNullOrEmpty

            # Check for common Japanese characters
            $jaText = $messages | ConvertTo-Json
            $jaText | Should -Match '[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]+'
        }
    }

    Context "Console Output Safety" {
        It "should use ASCII-safe markers instead of UTF-8 symbols" {
            $scriptFiles = Get-ChildItem -Path $projectRoot -Filter "*.ps1" -Recurse
            $failedFiles = @()
            $skippedFiles = @()
            $checkedCount = 0

            foreach ($file in $scriptFiles) {
                $relativePath = $file.FullName.Replace($projectRoot, "").TrimStart("\", "/")

                # Skip self-check
                if ($relativePath -eq "test/pester/Core.CharacterEncoding.Tests.ps1") {
                    $skippedFiles += $relativePath
                    continue
                }

                $content = Get-Content $file.FullName -Raw -Encoding UTF8
                $checkedCount++

                # Check that we're not using problematic UTF-8 symbols in console output
                # Allow them in comments and strings, but not in Write-Host for [OK]/[ERROR]
                if ($content -match 'Write-Host.*[\p{So}\uFE0F]') {
                    $failedFiles += @{
                        Name = $file.Name
                        Path = $relativePath
                    }
                }
            }

            # Output summary only after all checks are complete
            Write-BuildLog "Checked $checkedCount files, skipped $($skippedFiles.Count) file(s)"

            if ($failedFiles.Count -gt 0) {
                Write-BuildLog "Files with UTF-8 symbols in console output:" -Level Warning
                $failedFiles | ForEach-Object {
                    Write-BuildLog "  - $($_.Path)" -Level Warning
                }
            }

            $failedFiles | Should -BeNullOrEmpty -Because "These files use UTF-8 symbols in console output: $($failedFiles.Name -join ', ')"
        }
    }
}
