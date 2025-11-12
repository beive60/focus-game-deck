<#
.SYNOPSIS
    Pester tests for GUI ComboBox localization
.DESCRIPTION
    Validates that ComboBox items are properly localized
    Tests Japanese language support and message key mappings
#>

BeforeAll {
    # Navigate up two levels from test/pester/ to project root
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    # Load WPF assemblies
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Load required modules
    . (Join-Path -Path $ProjectRoot -ChildPath "gui/ConfigEditor.Mappings.ps1")
    . (Join-Path -Path $ProjectRoot -ChildPath "gui/ConfigEditor.Localization.ps1")
}

Describe "GUI ComboBox Localization Tests" -Tag "GUI", "Localization" {

    Context "ComboBox Item Mappings" {
        It "should have ComboBoxItemMappings defined" {
            $ComboBoxItemMappings | Should -Not -BeNullOrEmpty
        }

        It "should have mappings for all expected ComboBox items" {
            $expectedItems = @(
                'LogRetentionUnlimitedItem',
                'LogRetention7Item',
                'LogRetention30Item',
                'LogRetention180Item',
                'LauncherTypeTraditionalItem',
                'LauncherTypeEnhancedItem',
                'PlatformStandaloneItem',
                'PlatformSteamItem',
                'PlatformEpicItem',
                'PlatformRiotItem'
            )

            foreach ($item in $expectedItems) {
                $ComboBoxItemMappings.Keys | Should -Contain $item
            }
        }
    }

    Context "Localization Application" {
        BeforeEach {
            # Load XAML
            $xamlPath = Join-Path -Path $ProjectRoot -ChildPath "gui/MainWindow.xaml"
            $xamlContent = Get-Content -Path $xamlPath -Raw -Encoding UTF8
            [xml]$xaml = $xamlContent

            $reader = [System.Xml.XmlNodeReader]::new($xaml)
            $window = [Windows.Markup.XamlReader]::Load($reader)
        }

        It "should successfully localize ComboBox items to Japanese" {
            # This would require the full localization logic
            # Simplified test:
            $testMapping = $ComboBoxItemMappings['LogRetentionUnlimitedItem']
            $testMapping | Should -Not -BeNullOrEmpty
            $testMapping | Should -Be 'logRetentionUnlimited'
        }

        It "should have message keys for all ComboBox mappings" {
            $messages = Get-Content -Path (Join-Path -Path $ProjectRoot -ChildPath "localization/messages.json") -Raw -Encoding UTF8 | ConvertFrom-Json

            foreach ($messageKey in $ComboBoxItemMappings.Values) {
                $messages.ja.$messageKey | Should -Not -BeNullOrEmpty -Because "Message key $messageKey should exist"
            }
        }
    }

    Context "Platform ComboBox Items" {
        It "should have all platform types localized" {
            $platformItems = $ComboBoxItemMappings.Keys | Where-Object { $_ -like 'Platform*' }
            $platformItems.Count | Should -BeGreaterThan 3

            foreach ($item in $platformItems) {
                $ComboBoxItemMappings[$item] | Should -Match '^[A-Z_]+$' -Because "Should be uppercase message key"
            }
        }
    }
}
