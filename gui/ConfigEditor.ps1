# Focus Game Deck - Configuration Editor
# PowerShell + WPF GUI for editing config.json
#
# Design Philosophy:
# 1. Lightweight & Simple - Uses Windows native WPF, no additional runtime required
# 2. Maintainable & Extensible - Configuration-driven design with modular structure  
# 3. User-Friendly - Intuitive 3-tab GUI with proper Japanese character support
#
# Technical Architecture:
# - PowerShell + WPF: Windows-native GUI technology for lightweight implementation
# - JSON External Resources: Internationalization approach to solve Japanese character encoding issues
# - Configuration-Driven: All behavior controlled through config.json
# - Event-Driven: UI operations handled through PowerShell event handlers
#
# Character Encoding Solution:
# This implementation uses JSON external resource files to solve PowerShell MessageBox 
# Japanese character corruption issues. Messages are stored in messages.json using 
# Unicode escape sequences (\u30XX format) and loaded at runtime.
#
# Author: GitHub Copilot Assistant
# Version: 1.0.1 - JSON External Resource Internationalization
# Date: 2025-09-23

# Set system-level encoding settings for proper Japanese character display
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("ja-JP")

# Force all encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Add WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Global variables
$script:ConfigData = $null
$script:ConfigPath = ""
$script:Window = $null
$script:CurrentGameId = ""
$script:CurrentAppId = ""
$script:Messages = $null

# Load messages from JSON file
function Load-Messages {
    param()
    
    try {
        $messagesPath = Join-Path $PSScriptRoot "messages.json"
        if (Test-Path $messagesPath) {
            $jsonContent = Get-Content $messagesPath -Raw -Encoding UTF8
            $messagesData = $jsonContent | ConvertFrom-Json
            $script:Messages = $messagesData.messages
            Write-Host "Loaded messages from: $messagesPath"
        } else {
            Write-Warning "Messages file not found: $messagesPath"
            # Create default empty messages object
            $script:Messages = [PSCustomObject]@{}
        }
    } catch {
        Write-Error "Failed to load messages: $($_.Exception.Message)"
        $script:Messages = [PSCustomObject]@{}
    }
}

# Get localized message
function Get-LocalizedMessage {
    param(
        [string]$Key,
        [string[]]$Args = @()
    )
    
    if ($script:Messages -and $script:Messages.PSObject.Properties[$Key]) {
        $message = $script:Messages.$Key
        
        # Replace placeholders if args provided
        for ($i = 0; $i -lt $Args.Length; $i++) {
            $message = $message -replace "\{$i\}", $Args[$i]
        }
        
        return $message
    } else {
        # Fallback to English if message not found
        return $Key
    }
}

# Helper function for safe message display using JSON resources
function Show-SafeMessage {
    param(
        [string]$MessageKey,
        [string]$TitleKey = "info",
        [string[]]$Args = @(),
        [System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )
    
    try {
        # Get localized strings from JSON resources
        $message = Get-LocalizedMessage -Key $MessageKey -Args $Args
        $title = Get-LocalizedMessage -Key $TitleKey
        
        return [System.Windows.MessageBox]::Show($message, $title, $Button, $Icon)
    } catch {
        # Fallback to key names if JSON loading fails
        return [System.Windows.MessageBox]::Show($MessageKey, $TitleKey, $Button, $Icon)
    }
}

# Initialize the application
function Initialize-ConfigEditor {
    param()
    
    try {
        # Load messages first
        Load-Messages
        
        # Load XAML
        $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
        $script:Window = [Windows.Markup.XamlReader]::Load($reader)
        
        # Initialize config path
        $script:ConfigPath = Join-Path (Split-Path $PSScriptRoot) "config\config.json"
        
        # Load configuration
        Load-Configuration
        
        # Setup UI controls
        Setup-UIControls
        
        # Setup event handlers
        Setup-EventHandlers
        
        # Load data into UI
        Load-DataToUI
        
        # Show window
        $script:Window.ShowDialog() | Out-Null
        
    } catch {
        Show-SafeMessage -MessageKey "initError" -TitleKey "error" -Icon Error
    }
}

# Load configuration from file
function Load-Configuration {
    param()
    
    try {
        if (Test-Path $script:ConfigPath) {
            $jsonContent = Get-Content $script:ConfigPath -Raw -Encoding UTF8
            $script:ConfigData = $jsonContent | ConvertFrom-Json
            Write-Host "Loaded config from: $script:ConfigPath"
        } else {
            # Load from sample if config doesn't exist
            $configSamplePath = Join-Path (Split-Path $PSScriptRoot) "config\config.json.sample"
            if (Test-Path $configSamplePath) {
                $jsonContent = Get-Content $configSamplePath -Raw -Encoding UTF8
                $script:ConfigData = $jsonContent | ConvertFrom-Json
                Write-Host "Loaded config from sample: $configSamplePath"
            } else {
                throw "configNotFound"
            }
        }
    } catch {
        Show-SafeMessage -MessageKey "configLoadError" -TitleKey "error" -Args @($_.Exception.Message) -Icon Error
        # Create default config
        $script:ConfigData = [PSCustomObject]@{
            language = ""
            obs = [PSCustomObject]@{
                websocket = [PSCustomObject]@{
                    host = "localhost"
                    port = 4455
                    password = ""
                }
                replayBuffer = $true
            }
            managedApps = [PSCustomObject]@{}
            games = [PSCustomObject]@{}
            paths = [PSCustomObject]@{
                steam = ""
                obs = ""
            }
        }
    }
}

# Setup UI controls (dropdown lists, etc.)
function Setup-UIControls {
    param()
    
    # Setup Action combo boxes
    $actions = @("start-process", "stop-process", "toggle-hotkeys", "none")
    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
    
    foreach ($action in $actions) {
        $gameStartActionCombo.Items.Add($action)
        $gameEndActionCombo.Items.Add($action)
    }
    
    # Setup Language combo box
    $languageCombo = $script:Window.FindName("LanguageCombo")
    $languages = @(
        "Auto (System Language)",
        "Japanese (ja)",
        "English (en)"
    )
    
    foreach ($lang in $languages) {
        $languageCombo.Items.Add($lang)
    }
}

# Setup event handlers
function Setup-EventHandlers {
    param()
    
    # Footer buttons
    $saveButton = $script:Window.FindName("SaveButton")
    $saveButton.add_Click({ Handle-SaveConfig })
    
    $closeButton = $script:Window.FindName("CloseButton")
    $closeButton.add_Click({ Handle-CloseWindow })
    
    # Games tab events
    $gamesList = $script:Window.FindName("GamesList")
    $gamesList.add_SelectionChanged({ Handle-GameSelectionChanged })
    
    $addGameButton = $script:Window.FindName("AddGameButton")
    $addGameButton.add_Click({ Handle-AddGame })
    
    $deleteGameButton = $script:Window.FindName("DeleteGameButton")
    $deleteGameButton.add_Click({ Handle-DeleteGame })
    
    # Managed Apps tab events
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $managedAppsList.add_SelectionChanged({ Handle-AppSelectionChanged })
    
    $addAppButton = $script:Window.FindName("AddAppButton")
    $addAppButton.add_Click({ Handle-AddApp })
    
    $deleteAppButton = $script:Window.FindName("DeleteAppButton")
    $deleteAppButton.add_Click({ Handle-DeleteApp })
}

# Load data into UI controls
function Load-DataToUI {
    param()
    
    # Load games list
    Update-GamesList
    
    # Load managed apps list
    Update-ManagedAppsList
    
    # Load global settings
    Load-GlobalSettings
}

# Update games list
function Update-GamesList {
    param()
    
    $gamesList = $script:Window.FindName("GamesList")
    $gamesList.Items.Clear()
    
    if ($script:ConfigData.games) {
        $script:ConfigData.games.PSObject.Properties | ForEach-Object {
            $gamesList.Items.Add($_.Name)
        }
    }
}

# Update managed apps list
function Update-ManagedAppsList {
    param()
    
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $managedAppsList.Items.Clear()
    
    if ($script:ConfigData.managedApps) {
        $script:ConfigData.managedApps.PSObject.Properties | ForEach-Object {
            $managedAppsList.Items.Add($_.Name)
        }
    }
    
    # Update apps to manage checkboxes
    Update-AppsToManagePanel
}

# Update apps to manage panel with checkboxes
function Update-AppsToManagePanel {
    param()
    
    $panel = $script:Window.FindName("AppsToManagePanel")
    $panel.Children.Clear()
    
    if ($script:ConfigData.managedApps) {
        $script:ConfigData.managedApps.PSObject.Properties | ForEach-Object {
            $checkBox = New-Object System.Windows.Controls.CheckBox
            $checkBox.Content = $_.Name
            $checkBox.Name = "App_$($_.Name)"
            $checkBox.Margin = "0,2"
            $panel.Children.Add($checkBox)
        }
    }
}

# Load global settings
function Load-GlobalSettings {
    param()
    
    # OBS Settings
    $script:Window.FindName("ObsHostTextBox").Text = $script:ConfigData.obs.websocket.host
    $script:Window.FindName("ObsPortTextBox").Text = $script:ConfigData.obs.websocket.port.ToString()
    $script:Window.FindName("ObsPasswordBox").Password = $script:ConfigData.obs.websocket.password
    $script:Window.FindName("ReplayBufferCheckBox").IsChecked = $script:ConfigData.obs.replayBuffer
    
    # Path Settings
    $script:Window.FindName("SteamPathTextBox").Text = $script:ConfigData.paths.steam
    $script:Window.FindName("ObsPathTextBox").Text = $script:ConfigData.paths.obs
    
    # Language Setting
    $languageCombo = $script:Window.FindName("LanguageCombo")
    $currentLang = $script:ConfigData.language
    if ($currentLang -eq "" -or $currentLang -eq $null) {
        $languageCombo.SelectedIndex = 0  # Auto
    } elseif ($currentLang -eq "ja") {
        $languageCombo.SelectedIndex = 1  # Japanese
    } elseif ($currentLang -eq "en") {
        $languageCombo.SelectedIndex = 2  # English
    }
}

# Handle game selection changed
function Handle-GameSelectionChanged {
    param()
    
    $gamesList = $script:Window.FindName("GamesList")
    $selectedGame = $gamesList.SelectedItem
    
    if ($selectedGame) {
        $script:CurrentGameId = $selectedGame
        $gameData = $script:ConfigData.games.$selectedGame
        
        # Load game details
        $script:Window.FindName("GameIdTextBox").Text = $selectedGame
        $script:Window.FindName("GameNameTextBox").Text = $gameData.name
        $script:Window.FindName("SteamAppIdTextBox").Text = $gameData.steamAppId
        $script:Window.FindName("ProcessNameTextBox").Text = $gameData.processName
        
        # Update apps to manage checkboxes
        $panel = $script:Window.FindName("AppsToManagePanel")
        foreach ($child in $panel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $appName = $child.Content
                $child.IsChecked = $gameData.appsToManage -contains $appName
            }
        }
    }
}

# Handle managed app selection changed
function Handle-AppSelectionChanged {
    param()
    
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $selectedApp = $managedAppsList.SelectedItem
    
    if ($selectedApp) {
        $script:CurrentAppId = $selectedApp
        $appData = $script:ConfigData.managedApps.$selectedApp
        
        # Load app details
        $script:Window.FindName("AppIdTextBox").Text = $selectedApp
        $script:Window.FindName("AppPathTextBox").Text = $appData.path
        $script:Window.FindName("AppProcessNameTextBox").Text = $appData.processName
        $script:Window.FindName("AppArgumentsTextBox").Text = $appData.arguments
        
        # Set combo box selections
        $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
        $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
        
        $gameStartActionCombo.SelectedItem = $appData.gameStartAction
        $gameEndActionCombo.SelectedItem = $appData.gameEndAction
    }
}

# Handle add game
function Handle-AddGame {
    param()
    
    $newGameId = "newGame$(Get-Random -Minimum 1000 -Maximum 9999)"
    
    # Add to config data
    if (-not $script:ConfigData.games) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "games" -Value ([PSCustomObject]@{})
    }
    
    $script:ConfigData.games | Add-Member -MemberType NoteProperty -Name $newGameId -Value ([PSCustomObject]@{
        name = "New Game"
        steamAppId = ""
        processName = ""
        appsToManage = @()
    })
    
    Update-GamesList
    
    # Select the new game
    $gamesList = $script:Window.FindName("GamesList")
    $gamesList.SelectedItem = $newGameId
    
    Show-SafeMessage -MessageKey "gameAdded" -TitleKey "info"
}

# Handle delete game
function Handle-DeleteGame {
    param()
    
    $gamesList = $script:Window.FindName("GamesList")
    $selectedGame = $gamesList.SelectedItem
    
    if ($selectedGame) {
        $result = Show-SafeMessage -MessageKey "deleteGameConfirm" -TitleKey "confirmation" -Args @($selectedGame) -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:ConfigData.games.PSObject.Properties.Remove($selectedGame)
            Update-GamesList
            
            # Clear details
            $script:Window.FindName("GameIdTextBox").Text = ""
            $script:Window.FindName("GameNameTextBox").Text = ""
            $script:Window.FindName("SteamAppIdTextBox").Text = ""
            $script:Window.FindName("ProcessNameTextBox").Text = ""
            
            Show-SafeMessage -MessageKey "gameRemoved" -TitleKey "info"
        }
    }
}

# Handle add app
function Handle-AddApp {
    param()
    
    $newAppId = "newApp$(Get-Random -Minimum 1000 -Maximum 9999)"
    
    # Add to config data
    if (-not $script:ConfigData.managedApps) {
        $script:ConfigData | Add-Member -MemberType NoteProperty -Name "managedApps" -Value ([PSCustomObject]@{})
    }
    
    $script:ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name $newAppId -Value ([PSCustomObject]@{
        path = ""
        processName = ""
        gameStartAction = "none"
        gameEndAction = "none"
        arguments = ""
    })
    
    Update-ManagedAppsList
    
    # Select the new app
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $managedAppsList.SelectedItem = $newAppId
    
    Show-SafeMessage -MessageKey "appAdded" -TitleKey "info"
}

# Handle delete app
function Handle-DeleteApp {
    param()
    
    $managedAppsList = $script:Window.FindName("ManagedAppsList")
    $selectedApp = $managedAppsList.SelectedItem
    
    if ($selectedApp) {
        $result = Show-SafeMessage -MessageKey "deleteAppConfirm" -TitleKey "confirmation" -Args @($selectedApp) -Button YesNo -Icon Question
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:ConfigData.managedApps.PSObject.Properties.Remove($selectedApp)
            Update-ManagedAppsList
            
            # Clear details
            $script:Window.FindName("AppIdTextBox").Text = ""
            $script:Window.FindName("AppPathTextBox").Text = ""
            $script:Window.FindName("AppProcessNameTextBox").Text = ""
            $script:Window.FindName("AppArgumentsTextBox").Text = ""
            
            Show-SafeMessage -MessageKey "appRemoved" -TitleKey "info"
        }
    }
}

# Handle save configuration
function Handle-SaveConfig {
    param()
    
    try {
        # Save current UI data back to config object
        Save-UIDataToConfig
        
        # Convert to JSON and save
        $jsonString = $script:ConfigData | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $jsonString -Encoding UTF8
        
        Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"
        
    } catch {
        Show-SafeMessage -MessageKey "configSaveError" -TitleKey "error" -Args @($_.Exception.Message) -Icon Error
    }
}

# Save UI data back to config object
function Save-UIDataToConfig {
    param()
    
    # Save current game if selected
    if ($script:CurrentGameId -and $script:CurrentGameId -ne "") {
        Save-CurrentGameData
    }
    
    # Save current app if selected
    if ($script:CurrentAppId -and $script:CurrentAppId -ne "") {
        Save-CurrentAppData
    }
    
    # Save global settings
    Save-GlobalSettingsData
}

# Save current game data
function Save-CurrentGameData {
    param()
    
    $gameId = $script:Window.FindName("GameIdTextBox").Text
    $gameName = $script:Window.FindName("GameNameTextBox").Text
    $steamAppId = $script:Window.FindName("SteamAppIdTextBox").Text
    $processName = $script:Window.FindName("ProcessNameTextBox").Text
    
    # Get selected apps to manage
    $appsToManage = @()
    $panel = $script:Window.FindName("AppsToManagePanel")
    foreach ($child in $panel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
            $appsToManage += $child.Content
        }
    }
    
    # Update config data
    if ($gameId -ne $script:CurrentGameId) {
        # Game ID changed, remove old and add new
        $oldGameData = $script:ConfigData.games.$script:CurrentGameId
        $script:ConfigData.games.PSObject.Properties.Remove($script:CurrentGameId)
        $script:ConfigData.games | Add-Member -MemberType NoteProperty -Name $gameId -Value $oldGameData
    }
    
    $script:ConfigData.games.$gameId.name = $gameName
    $script:ConfigData.games.$gameId.steamAppId = $steamAppId
    $script:ConfigData.games.$gameId.processName = $processName
    $script:ConfigData.games.$gameId.appsToManage = $appsToManage
}

# Save current app data
function Save-CurrentAppData {
    param()
    
    $appId = $script:Window.FindName("AppIdTextBox").Text
    $appPath = $script:Window.FindName("AppPathTextBox").Text
    $processName = $script:Window.FindName("AppProcessNameTextBox").Text
    $arguments = $script:Window.FindName("AppArgumentsTextBox").Text
    $gameStartAction = $script:Window.FindName("GameStartActionCombo").SelectedItem
    $gameEndAction = $script:Window.FindName("GameEndActionCombo").SelectedItem
    
    # Update config data
    if ($appId -ne $script:CurrentAppId) {
        # App ID changed, remove old and add new
        $oldAppData = $script:ConfigData.managedApps.$script:CurrentAppId
        $script:ConfigData.managedApps.PSObject.Properties.Remove($script:CurrentAppId)
        $script:ConfigData.managedApps | Add-Member -MemberType NoteProperty -Name $appId -Value $oldAppData
    }
    
    $script:ConfigData.managedApps.$appId.path = $appPath
    $script:ConfigData.managedApps.$appId.processName = $processName
    $script:ConfigData.managedApps.$appId.arguments = $arguments
    $script:ConfigData.managedApps.$appId.gameStartAction = $gameStartAction
    $script:ConfigData.managedApps.$appId.gameEndAction = $gameEndAction
}

# Save global settings data
function Save-GlobalSettingsData {
    param()
    
    # OBS Settings
    $script:ConfigData.obs.websocket.host = $script:Window.FindName("ObsHostTextBox").Text
    $script:ConfigData.obs.websocket.port = [int]$script:Window.FindName("ObsPortTextBox").Text
    $script:ConfigData.obs.websocket.password = $script:Window.FindName("ObsPasswordBox").Password
    $script:ConfigData.obs.replayBuffer = $script:Window.FindName("ReplayBufferCheckBox").IsChecked
    
    # Path Settings
    $script:ConfigData.paths.steam = $script:Window.FindName("SteamPathTextBox").Text
    $script:ConfigData.paths.obs = $script:Window.FindName("ObsPathTextBox").Text
    
    # Language Setting
    $languageCombo = $script:Window.FindName("LanguageCombo")
    $selectedIndex = $languageCombo.SelectedIndex
    switch ($selectedIndex) {
        0 { $script:ConfigData.language = "" }      # Auto
        1 { $script:ConfigData.language = "ja" }    # Japanese
        2 { $script:ConfigData.language = "en" }    # English
        default { $script:ConfigData.language = "" }
    }
}

# Handle close window
function Handle-CloseWindow {
    param()
    
    $script:Window.Close()
}

# Start the application
Initialize-ConfigEditor