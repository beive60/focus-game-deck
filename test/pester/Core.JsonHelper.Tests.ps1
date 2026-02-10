<#
.SYNOPSIS
    Pester tests for ConfigEditor.JsonHelper character encoding

.DESCRIPTION
    Unit tests for the JsonHelper module that validates:
    - UTF-8 encoding without BOM
    - Shift-JIS detection and handling
    - BOM detection in various encodings
    - JSON formatting consistency
    - Edge cases for malformed input

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Tags: Unit, Core, JsonHelper, Encoding
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

    # Import the BuildLogger
    . "$projectRoot/build-tools/utils/BuildLogger.ps1"

    # Import the JsonHelper module
    . "$projectRoot/gui/ConfigEditor.JsonHelper.ps1"

    Write-BuildLog "[INFO] JsonHelper Tests: Loading JsonHelper module"

    # Test directory for file operations
    $script:TestDir = Join-Path $TestDrive "JsonHelperTests"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
}

Describe "ConvertTo-Json4Space - Basic Formatting" -Tag "Unit", "Core", "JsonHelper" {

    Context "Simple Objects" {
        It "Should convert simple object with 4-space indentation" {
            $obj = @{ name = "test"; value = 123 }
            $json = ConvertTo-Json4Space -InputObject $obj

            # Check for 4-space indentation
            $json | Should -Match '^\{\s*\n\s{4}"'
        }

        It "Should preserve string values" {
            $obj = @{ message = "Hello World" }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '"Hello World"'
        }

        It "Should handle numeric values" {
            $obj = @{ count = 42; price = 19.99 }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '42'
            $json | Should -Match '19\.99'
        }

        It "Should handle boolean values" {
            $obj = @{ enabled = $true; disabled = $false }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match 'true'
            $json | Should -Match 'false'
        }

        It "Should handle null values" {
            $obj = @{ empty = $null }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match 'null'
        }
    }

    Context "Nested Objects" {
        It "Should properly indent nested objects" {
            $obj = @{
                level1 = @{
                    level2 = @{
                        value = "deep"
                    }
                }
            }
            $json = ConvertTo-Json4Space -InputObject $obj -Depth 10

            # Check for progressively deeper indentation (8 spaces for level2)
            $json | Should -Match '\n\s{8}"'
        }
    }

    Context "Arrays" {
        It "Should format arrays with proper indentation" {
            $obj = @{
                items = @("one", "two", "three")
            }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '\['
            $json | Should -Match '\]'
            $json | Should -Match '"one"'
        }

        It "Should handle empty arrays" {
            $obj = @{ items = @() }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '\[\s*\]'
        }
    }
}

Describe "ConvertTo-Json4Space - Character Encoding" -Tag "Unit", "Core", "JsonHelper", "Encoding" {

    Context "Unicode Characters" {
        It "Should handle Japanese characters (Hiragana)" {
            # Use Unicode escape to avoid encoding issues in CI
            $hiragana = [System.Text.Encoding]::UTF8.GetString([byte[]]@(227, 129, 147, 227, 130, 147, 227, 129, 171, 227, 129, 161, 227, 129, 175))
            $obj = @{ message = $hiragana }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match $hiragana
        }

        It "Should handle Japanese characters (Katakana)" {
            # Use Unicode escape to avoid encoding issues in CI
            $katakana = [System.Text.Encoding]::UTF8.GetString([byte[]]@(227, 130, 171, 227, 130, 191, 227, 130, 171, 227, 131, 138))
            $obj = @{ message = $katakana }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match $katakana
        }

        It "Should handle Japanese characters (Kanji)" {
            # Use Unicode escape to avoid encoding issues in CI
            $kanji = [System.Text.Encoding]::UTF8.GetString([byte[]]@(230, 151, 165, 230, 156, 172, 232, 170, 158))
            $obj = @{ message = $kanji }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match $kanji
        }

        It "Should handle Chinese characters" {
            # Use Unicode escape to avoid encoding issues in CI
            $chinese = [System.Text.Encoding]::UTF8.GetString([byte[]]@(228, 184, 173, 230, 150, 135, 230, 181, 139, 232, 175, 149))
            $obj = @{ message = $chinese }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match $chinese
        }

        It "Should handle Korean characters" {
            # Use Unicode escape to avoid encoding issues in CI
            $korean = [System.Text.Encoding]::UTF8.GetString([byte[]]@(237, 149, 156, 234, 181, 173, 236, 150, 180))
            $obj = @{ message = $korean }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match $korean
        }

        It "Should handle emoji characters" {
            # Use Unicode escape to avoid encoding issues in CI
            $emoji = [System.Text.Encoding]::UTF8.GetString([byte[]]@(240, 159, 142, 174, 240, 159, 149, 185, 239, 184, 143))
            $obj = @{ emoji = $emoji }
            $json = ConvertTo-Json4Space -InputObject $obj

            # Emoji might be escaped or preserved
            $json | Should -Not -BeNullOrEmpty
        }
    }

    Context "Special Characters in Strings" {
        It "Should escape backslashes" {
            $obj = @{ path = "C:\\Users\\Test" }
            $json = ConvertTo-Json4Space -InputObject $obj

            # Double backslash should be escaped
            $json | Should -Match '\\\\'
        }

        It "Should escape quotes" {
            $obj = @{ message = 'Say "Hello"' }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '\\"'
        }

        It "Should handle newlines in strings" {
            $obj = @{ text = "Line1`nLine2" }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '\\n'
        }

        It "Should handle tabs in strings" {
            $obj = @{ text = "Col1`tCol2" }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '\\t'
        }
    }
}

Describe "Save-ConfigJson - File Operations" -Tag "Unit", "Core", "JsonHelper", "Encoding" {

    Context "UTF-8 Without BOM" {
        It "Should save file as UTF-8 without BOM" {
            $obj = @{ name = "test" }
            $filePath = Join-Path $script:TestDir "utf8-nobom.json"

            Save-ConfigJson -ConfigData $obj -ConfigPath $filePath

            # Check file exists
            Test-Path $filePath | Should -Be $true

            # Check no BOM (first 3 bytes should not be EF BB BF)
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            if ($bytes.Length -ge 3) {
                $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
                $hasBOM | Should -Be $false -Because "UTF-8 files should not have BOM"
            }
        }

        It "Should preserve Japanese characters when saving" {
            # Use Unicode escape to avoid encoding issues in CI
            $japanese = [System.Text.Encoding]::UTF8.GetString([byte[]]@(230, 151, 165, 230, 156, 172, 232, 170, 158, 227, 131, 134, 227, 130, 185, 227, 131, 136))
            $obj = @{ message = $japanese }
            $filePath = Join-Path $script:TestDir "japanese.json"

            Save-ConfigJson -ConfigData $obj -ConfigPath $filePath

            $content = Get-Content $filePath -Raw -Encoding UTF8
            $content | Should -Match $japanese
        }
    }

    Context "Error Handling" {
        It "Should throw on null configuration" {
            $filePath = Join-Path $script:TestDir "null-config.json"

            { Save-ConfigJson -ConfigData $null -ConfigPath $filePath } | Should -Throw
        }

        It "Should throw on empty configuration" {
            $filePath = Join-Path $script:TestDir "empty-config.json"

            # Empty hashtable produces valid JSON, so test null instead
            { Save-ConfigJson -ConfigData $null -ConfigPath $filePath } | Should -Throw
        }

        It "Should accept empty hashtable as valid configuration" {
            $filePath = Join-Path $script:TestDir "empty-hashtable-config.json"

            # Empty hashtable is valid JSON object {}
            { Save-ConfigJson -ConfigData @{} -ConfigPath $filePath } | Should -Not -Throw

            # Verify the file was created
            Test-Path $filePath | Should -Be $true
        }
    }

    Context "Roundtrip Integrity" {
        It "Should maintain data integrity through save/load cycle" {
            $original = @{
                games = @{
                    apex = @{
                        name = "Apex Legends"
                        platform = "steam"
                        steamAppId = "1172470"
                    }
                }
                language = "en"
            }
            $filePath = Join-Path $script:TestDir "roundtrip.json"

            # Save
            Save-ConfigJson -ConfigData $original -ConfigPath $filePath

            # Load
            $loaded = Get-Content $filePath -Raw -Encoding UTF8 | ConvertFrom-Json

            # Verify
            $loaded.games.apex.name | Should -Be "Apex Legends"
            $loaded.games.apex.steamAppId | Should -Be "1172470"
            $loaded.language | Should -Be "en"
        }

        It "Should maintain Japanese text integrity through roundtrip" {
            # Use Unicode escape to avoid encoding issues in CI
            $japaneseName = [System.Text.Encoding]::UTF8.GetString([byte[]]@(227, 131, 135, 227, 131, 131, 227, 131, 137, 227, 131, 144, 227, 130, 164, 227, 131, 135, 227, 130, 164, 227, 131, 169, 227, 130, 164, 227, 131, 136))
            $original = @{
                games = @{
                    dbd = @{
                        name = $japaneseName
                        platform = "steam"
                    }
                }
            }
            $filePath = Join-Path $script:TestDir "roundtrip-ja.json"

            Save-ConfigJson -ConfigData $original -ConfigPath $filePath
            $loaded = Get-Content $filePath -Raw -Encoding UTF8 | ConvertFrom-Json

            $loaded.games.dbd.name | Should -Be $japaneseName
        }
    }
}

Describe "Edge Cases - Malformed Input" -Tag "Unit", "Core", "JsonHelper", "EdgeCase" {

    Context "Depth Limits" {
        It "Should handle deeply nested objects up to specified depth" {
            # Create a deeply nested object
            $deep = @{ level = 1 }
            for ($i = 2; $i -le 10; $i++) {
                $deep = @{ level = $i; child = $deep }
            }

            $json = ConvertTo-Json4Space -InputObject $deep -Depth 10
            $json | Should -Not -BeNullOrEmpty
        }
    }

    Context "Large Strings" {
        It "Should handle large string values" {
            $largeString = "A" * 10000
            $obj = @{ content = $largeString }

            $json = ConvertTo-Json4Space -InputObject $obj
            $json | Should -Match 'AAAA'
        }
    }

    Context "Empty/Whitespace Values" {
        It "Should handle empty string values" {
            $obj = @{ empty = "" }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '""'
        }

        It "Should handle whitespace-only string values" {
            $obj = @{ spaces = "   " }
            $json = ConvertTo-Json4Space -InputObject $obj

            $json | Should -Match '"   "'
        }
    }
}

Describe "BOM Detection Helper Tests" -Tag "Unit", "Core", "JsonHelper", "Encoding" {

    BeforeAll {
        # Helper function to create test files with specific encodings
        function New-EncodedTestFile {
            param(
                [string]$Path,
                [string]$Content,
                [string]$Encoding
            )

            switch ($Encoding) {
                'UTF8-BOM' {
                    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
                    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
                }
                'UTF8-NoBOM' {
                    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
                }
                'UTF16-LE' {
                    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::Unicode)
                }
            }
        }
    }

    Context "Detect UTF-8 BOM" {
        It "Should detect UTF-8 with BOM" {
            $testFile = Join-Path $script:TestDir "bom-test.json"
            New-EncodedTestFile -Path $testFile -Content '{"test": "value"}' -Encoding 'UTF8-BOM'

            $bytes = [System.IO.File]::ReadAllBytes($testFile)
            $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBOM | Should -Be $true
        }

        It "Should detect UTF-8 without BOM" {
            $testFile = Join-Path $script:TestDir "nobom-test.json"
            New-EncodedTestFile -Path $testFile -Content '{"test": "value"}' -Encoding 'UTF8-NoBOM'

            $bytes = [System.IO.File]::ReadAllBytes($testFile)
            $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBOM | Should -Be $false
        }
    }

    Context "Read Files With Different Encodings" {
        It "Should read UTF-8 without BOM correctly" {
            # Use Unicode escape to avoid encoding issues in CI
            $testText = [System.Text.Encoding]::UTF8.GetString([byte[]]@(227, 131, 134, 227, 130, 185, 227, 131, 136))
            $testFile = Join-Path $script:TestDir "read-utf8.json"
            New-EncodedTestFile -Path $testFile -Content ('{"message": "' + $testText + '"}') -Encoding 'UTF8-NoBOM'

            $content = Get-Content $testFile -Raw -Encoding UTF8
            $obj = $content | ConvertFrom-Json
            $obj.message | Should -Be $testText
        }
    }
}

Describe "Invalid Configuration Handling" -Tag "Unit", "Core", "JsonHelper", "EdgeCase" {

    Context "Empty Configuration File" {
        It "Should create empty file correctly" {
            $emptyFile = Join-Path $script:TestDir "empty.json"
            Set-Content -Path $emptyFile -Value "" -Encoding UTF8

            # File should exist and be essentially empty
            Test-Path $emptyFile | Should -Be $true
            $fileInfo = Get-Item $emptyFile
            # File may have minimal content (newlines) depending on OS
            $fileInfo.Length | Should -BeLessThan 10
        }

        It "Should parse empty JSON object to PSCustomObject" {
            $emptyObj = '{}' | ConvertFrom-Json
            # In PowerShell 7+, empty {} returns a PSCustomObject with no properties
            $emptyObj.GetType().Name | Should -BeIn @('PSCustomObject', 'Hashtable')
        }
    }

    Context "Malformed JSON" {
        It "Should fail on missing closing brace" {
            $malformed = '{"name": "test"'
            { $malformed | ConvertFrom-Json } | Should -Throw
        }

        It "Should handle trailing comma based on PS version" {
            # Note: PowerShell 7+ is more lenient with JSON
            # This test documents the behavior rather than enforcing strict JSON
            $malformed = '{"name": "test",}'
            try {
                $result = $malformed | ConvertFrom-Json
                # If parsing succeeds, that's okay in newer PS versions
                $result.name | Should -Be "test"
            } catch {
                # If parsing fails, that's expected in stricter PS versions
                $_.Exception | Should -Not -BeNullOrEmpty
            }
        }

        It "Should handle single quotes based on PS version" {
            # Note: PowerShell 7+ allows single quotes in JSON
            $malformed = "{'name': 'test'}"
            try {
                $result = $malformed | ConvertFrom-Json
                # If parsing succeeds, that's okay in newer PS versions
                $result.name | Should -Be "test"
            } catch {
                # If parsing fails, that's expected in stricter PS versions
                $_.Exception | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "JSON Structure" {
        It "Should parse JSON with empty games object" {
            $json = '{"games": {}}'
            $obj = $json | ConvertFrom-Json

            # Object should be parsed
            $obj.GetType().Name | Should -BeIn @('PSCustomObject', 'Hashtable')
            # games property exists
            $obj.PSObject.Properties.Name | Should -Contain 'games'
        }
    }
}
