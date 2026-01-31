<#
.SYNOPSIS
    Pester tests for Main Router (Main.PS1) argument parsing and routing

.DESCRIPTION
    Unit tests for the Main Router component that validates:
    - Command-line argument parsing (--help, --version, --list, --config)
    - GameId routing to appropriate executable
    - Fallback behavior when no arguments provided
    - Error handling for invalid arguments

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Tags: Unit, Core, MainRouter
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

    # Import the BuildLogger
    . "$projectRoot/build-tools/utils/BuildLogger.ps1"

    # Path to Main.PS1
    $script:MainRouterPath = Join-Path $projectRoot "src/Main.PS1"

    Write-BuildLog "[INFO] MainRouter Tests: Starting Main Router validation"
}

Describe "Main Router - File Existence" -Tag "Unit", "Core", "MainRouter" {

    Context "Entry Point Scripts" {
        It "Should have Main.PS1 entry point" {
            Test-Path $script:MainRouterPath | Should -Be $true
        }

        It "Should have valid PowerShell syntax in Main.PS1" {
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($script:MainRouterPath, [ref]$null, [ref]$parseErrors)
            $parseErrors.Count | Should -Be 0 -Because "Main.PS1 should have no parse errors"
        }
    }
}

Describe "Main Router - Argument Parsing" -Tag "Unit", "Core", "MainRouter" {

    BeforeAll {
        # Parse Main.PS1 to extract param block
        $content = Get-Content $script:MainRouterPath -Raw -Encoding UTF8
    }

    Context "Parameter Definition" {
        It "Should define GameId parameter" {
            $content | Should -Match '\$GameId'
        }

        It "Should define Config switch" {
            $content | Should -Match '\[switch\].*\$Config'
        }

        It "Should define List switch" {
            $content | Should -Match '\[switch\].*\$List'
        }

        It "Should define Help switch" {
            $content | Should -Match '\[switch\].*\$Help'
        }

        It "Should define Version switch" {
            $content | Should -Match '\[switch\].*\$Version'
        }
    }

    Context "Routing Functions" {
        It "Should define Show-Help function" {
            $content | Should -Match 'function\s+Show-Help'
        }

        It "Should define Show-Version function" {
            $content | Should -Match 'function\s+Show-Version'
        }

        It "Should define Show-GameList function" {
            $content | Should -Match 'function\s+Show-GameList'
        }

        It "Should define Start-ConfigEditor function" {
            $content | Should -Match 'function\s+Start-ConfigEditor'
        }

        It "Should define Start-Game function" {
            $content | Should -Match 'function\s+Start-Game'
        }

        It "Should define Main function" {
            $content | Should -Match 'function\s+Main'
        }
    }

    Context "Executable Mode Detection" {
        It "Should detect executable vs script mode" {
            $content | Should -Match '\$isExecutable\s*='
        }

        It "Should define path to ConfigEditor executable" {
            $content | Should -Match '\$configEditorExe\s*='
        }

        It "Should define path to GameLauncher executable" {
            $content | Should -Match '\$gameLauncherExe\s*='
        }
    }
}

Describe "Main Router - Help Pattern Matching" -Tag "Unit", "Core", "MainRouter" {

    BeforeAll {
        $content = Get-Content $script:MainRouterPath -Raw -Encoding UTF8
    }

    Context "Help Argument Variations" {
        It "Should handle help as GameId argument" {
            # The Main function checks for help patterns in GameId
            $content | Should -Match '\$GameId\s*-match.*help'
        }

        It "Should handle version as GameId argument" {
            $content | Should -Match '\$GameId\s*-match.*version'
        }

        It "Should handle list as GameId argument" {
            $content | Should -Match '\$GameId\s*-match.*list'
        }
    }
}

Describe "Main Router - Exit Codes" -Tag "Unit", "Core", "MainRouter" {

    BeforeAll {
        $content = Get-Content $script:MainRouterPath -Raw -Encoding UTF8
    }

    Context "Success Exit Codes" {
        It "Should exit with 0 for help command" {
            # Show-Help should exit 0
            $content | Should -Match 'function\s+Show-Help[\s\S]*?exit\s+0'
        }

        It "Should exit with 0 for version command" {
            # Show-Version should exit 0
            $content | Should -Match 'function\s+Show-Version[\s\S]*?exit\s+0'
        }

        It "Should exit with 0 for successful list command" {
            # Show-GameList should exit 0 on success
            $content | Should -Match 'function\s+Show-GameList[\s\S]*?exit\s+0'
        }
    }

    Context "Error Exit Codes" {
        It "Should exit with 1 for game not found" {
            $content | Should -Match 'exit\s+1'
        }
    }
}

Describe "Main Router - Localization Support" -Tag "Unit", "Core", "MainRouter" {

    BeforeAll {
        $content = Get-Content $script:MainRouterPath -Raw -Encoding UTF8
    }

    Context "Language Detection" {
        It "Should use Get-DetectedLanguage function" {
            $content | Should -Match 'Get-DetectedLanguage'
        }

        It "Should use Get-LocalizedMessages function" {
            $content | Should -Match 'Get-LocalizedMessages'
        }

        It "Should have fallback for missing localization" {
            # Should have fallback function definitions with default "en" return
            # The pattern: function Get-DetectedLanguage { ... return "en" }
            $content | Should -Match 'function\s+Get-DetectedLanguage'
            # Verify there's a fallback to English in the code
            $content | Should -Match '"en"'
        }
    }
}

Describe "Main Router - Security" -Tag "Unit", "Core", "MainRouter" {

    BeforeAll {
        $content = Get-Content $script:MainRouterPath -Raw -Encoding UTF8
    }

    Context "Input Validation" {
        It "Should validate GameId before processing" {
            # Check that GameId is validated before use
            $content | Should -Match 'if.*config\.games\.\$GameId'
        }

        It "Should not execute arbitrary code from GameId" {
            # Ensure GameId is not directly executed
            $content | Should -Not -Match 'Invoke-Expression.*\$GameId'
        }
    }
}
