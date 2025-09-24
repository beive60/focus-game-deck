# GUI Configuration Editor Extension for Multi-Platform Support
# Add these elements to MainWindow.xaml for platform selection

# Additional XAML elements to add to the Game Settings tab:

<ComboBox Grid.Row="X" Grid.Column="1" Name="PlatformComboBox" Margin="5">
    <ComboBoxItem Content="Steam" Tag="steam"/>
    <ComboBoxItem Content="Epic Games" Tag="epic"/>
    <ComboBoxItem Content="EA App" Tag="ea"/>
    <ComboBoxItem Content="Riot Client" Tag="riot"/>
    <ComboBoxItem Content="Direct Launch" Tag="direct"/>
</ComboBox>

# Platform-specific fields that should show/hide based on selection:
<Label Grid.Row="Y" Grid.Column="0" Name="SteamAppIdLabel" Content="Steam AppID:" VerticalAlignment="Center"/>
<TextBox Grid.Row="Y" Grid.Column="1" Name="SteamAppIdTextBox" Margin="5"/>

<Label Grid.Row="Z" Grid.Column="0" Name="EpicGameIdLabel" Content="Epic Game ID:" VerticalAlignment="Center" Visibility="Collapsed"/>
<TextBox Grid.Row="Z" Grid.Column="1" Name="EpicGameIdTextBox" Margin="5" Visibility="Collapsed"/>

<Label Grid.Row="A" Grid.Column="0" Name="EAGameIdLabel" Content="EA Game ID:" VerticalAlignment="Center" Visibility="Collapsed"/>
<TextBox Grid.Row="A" Grid.Column="1" Name="EAGameIdTextBox" Margin="5" Visibility="Collapsed"/>

<Label Grid.Row="B" Grid.Column="0" Name="RiotGameIdLabel" Content="Riot Game ID:" VerticalAlignment="Center" Visibility="Collapsed"/>
<TextBox Grid.Row="B" Grid.Column="1" Name="RiotGameIdTextBox" Margin="5" Visibility="Collapsed"/>

<Label Grid.Row="C" Grid.Column="0" Name="ExecutablePathLabel" Content="Executable Path:" VerticalAlignment="Center" Visibility="Collapsed"/>
<Grid Grid.Row="C" Grid.Column="1" Margin="5" Visibility="Collapsed" Name="ExecutablePathGrid">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBox Grid.Column="0" Name="ExecutablePathTextBox"/>
    <Button Grid.Column="1" Name="BrowseExecutableButton" Content="Browse" Width="50" Margin="5,0,0,0"/>
</Grid>

# PowerShell event handlers to add:

# Platform selection change handler
$PlatformComboBox.Add_SelectionChanged({
    $selectedPlatform = $PlatformComboBox.SelectedItem.Tag
    
    # Hide all platform-specific fields
    $SteamAppIdLabel.Visibility = "Collapsed"
    $SteamAppIdTextBox.Visibility = "Collapsed"
    $EpicGameIdLabel.Visibility = "Collapsed"
    $EpicGameIdTextBox.Visibility = "Collapsed"
    $EAGameIdLabel.Visibility = "Collapsed"
    $EAGameIdTextBox.Visibility = "Collapsed"
    $RiotGameIdLabel.Visibility = "Collapsed"
    $RiotGameIdTextBox.Visibility = "Collapsed"
    $ExecutablePathLabel.Visibility = "Collapsed"
    $ExecutablePathGrid.Visibility = "Collapsed"
    
    # Show relevant fields based on platform
    switch ($selectedPlatform) {
        "steam" {
            $SteamAppIdLabel.Visibility = "Visible"
            $SteamAppIdTextBox.Visibility = "Visible"
        }
        "epic" {
            $EpicGameIdLabel.Visibility = "Visible"
            $EpicGameIdTextBox.Visibility = "Visible"
        }
        "ea" {
            $EAGameIdLabel.Visibility = "Visible"
            $EAGameIdTextBox.Visibility = "Visible"
        }
        "riot" {
            $RiotGameIdLabel.Visibility = "Visible"
            $RiotGameIdTextBox.Visibility = "Visible"
        }
        "direct" {
            $ExecutablePathLabel.Visibility = "Visible"
            $ExecutablePathGrid.Visibility = "Visible"
        }
    }
})

# Browse button for executable path
$BrowseExecutableButton.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
    $openFileDialog.Title = "Select Game Executable"
    
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $ExecutablePathTextBox.Text = $openFileDialog.FileName
    }
})

# Updated game loading function
function Load-GameToForm {
    param($gameId, $gameData)
    
    $GameIdTextBox.Text = $gameId
    $GameNameTextBox.Text = $gameData.name
    $ProcessNameTextBox.Text = $gameData.processName
    
    # Set platform
    $platform = if ($gameData.platform) { $gameData.platform } else { "steam" }
    for ($i = 0; $i -lt $PlatformComboBox.Items.Count; $i++) {
        if ($PlatformComboBox.Items[$i].Tag -eq $platform) {
            $PlatformComboBox.SelectedIndex = $i
            break
        }
    }
    
    # Set platform-specific values
    $SteamAppIdTextBox.Text = if ($gameData.steamAppId) { $gameData.steamAppId } else { "" }
    $EpicGameIdTextBox.Text = if ($gameData.epicGameId) { $gameData.epicGameId } else { "" }
    $EAGameIdTextBox.Text = if ($gameData.eaGameId) { $gameData.eaGameId } else { "" }
    $RiotGameIdTextBox.Text = if ($gameData.riotGameId) { $gameData.riotGameId } else { "" }
    $ExecutablePathTextBox.Text = if ($gameData.executablePath) { $gameData.executablePath } else { "" }
    
    # ... existing appsToManage loading code ...
}

# Updated game saving function
function Save-GameFromForm {
    param($gameId)
    
    $selectedPlatform = $PlatformComboBox.SelectedItem.Tag
    
    $gameData = @{
        name = $GameNameTextBox.Text
        platform = $selectedPlatform
        processName = $ProcessNameTextBox.Text
        appsToManage = @($AppsToManageListBox.SelectedItems | ForEach-Object { $_ })
    }
    
    # Add platform-specific properties
    switch ($selectedPlatform) {
        "steam" {
            if ($SteamAppIdTextBox.Text -ne "") {
                $gameData.steamAppId = $SteamAppIdTextBox.Text
            }
        }
        "epic" {
            if ($EpicGameIdTextBox.Text -ne "") {
                $gameData.epicGameId = $EpicGameIdTextBox.Text
            }
        }
        "ea" {
            if ($EAGameIdTextBox.Text -ne "") {
                $gameData.eaGameId = $EAGameIdTextBox.Text
            }
        }
        "riot" {
            if ($RiotGameIdTextBox.Text -ne "") {
                $gameData.riotGameId = $RiotGameIdTextBox.Text
            }
        }
        "direct" {
            if ($ExecutablePathTextBox.Text -ne "") {
                $gameData.executablePath = $ExecutablePathTextBox.Text
            }
        }
    }
    
    $script:config.games.$gameId = $gameData
}