<#
.SYNOPSIS
    ConfigEditor Save Functions Module

.DESCRIPTION
    This module contains all save-related functions for the ConfigEditor.
    Handles saving of game configurations, managed applications, and global settings.

    Functions in this module:
    - Set-PropertyValue: Helper to set or add properties to PSCustomObject
    - Protect-Password: Encrypts passwords using DPAPI
    - Unprotect-Password: Decrypts DPAPI-encrypted passwords
    - Save-CurrentGameData: Saves game configuration with validation
    - Save-CurrentAppData: Saves managed application configuration
    - Save-GlobalSettingsData: Saves global settings
    - Save-OBSSettingsData: Saves OBS integration settings
    - Save-DiscordSettingsData: Saves Discord integration settings
    - Save-VTubeStudioSettingsData: Saves VTube Studio integration settings
    - Save-OriginalConfig: Saves original configuration state

.NOTES
    Author: Focus Game Deck Development Team
    Version: 1.0.0
    Last Updated: 2025-12-19

    This module depends on:
    - ValidationRules for validation
    - UIManager for error display
    - StateManager for configuration state
    - Localization for messages
#>

<#
.SYNOPSIS
Helper function to safely set or add a property to a PSCustomObject.

.DESCRIPTION
Checks if a property exists on an object and sets its value, or adds the property if it doesn't exist.
This prevents errors when trying to set non-existent properties on PSCustomObject instances.

.PARAMETER Object
The PSCustomObject to modify.

.PARAMETER PropertyName
The name of the property to set or add.

.PARAMETER Value
The value to assign to the property.
#>
function Set-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Object,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($Object.PSObject.Properties[$PropertyName]) {
        $Object.$PropertyName = $Value
    } else {
        $Object | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $Value -Force
    }
}

<#
.SYNOPSIS
Encrypts a plain text password using Windows Data Protection API (DPAPI).

.DESCRIPTION
Uses ConvertTo-SecureString and ConvertFrom-SecureString to encrypt passwords
with DPAPI. The encrypted string can only be decrypted by the same user on
the same machine.

.PARAMETER PlainTextPassword
The plain text password to encrypt.

.OUTPUTS
String - The encrypted password string.
#>
function Protect-Password {
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Function purpose is to encrypt plain text passwords')]
    # Note: Attribute commented out to avoid ps2exe build issues
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainTextPassword
    )

    try {
        if ([string]::IsNullOrEmpty($PlainTextPassword)) {
            return ""
        }

        # Convert to SecureString, then to encrypted string using DPAPI
        $secureString = ConvertTo-SecureString -String $PlainTextPassword -AsPlainText -Force
        $encryptedString = ConvertFrom-SecureString -SecureString $secureString

        return $encryptedString
    } catch {
        Write-Warning "Failed to encrypt password: $($_.Exception.Message)"
        # Return empty string instead of plain text for security
        return ""
    }
}

<#
.SYNOPSIS
Decrypts a DPAPI-encrypted password string.

.DESCRIPTION
Uses ConvertTo-SecureString to decrypt DPAPI-encrypted passwords.
Supports both encrypted strings and plain text (for backward compatibility).

.PARAMETER EncryptedPassword
The encrypted password string to decrypt.

.OUTPUTS
String - The decrypted plain text password.
#>
function Unprotect-Password {
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Parameter contains encrypted string, not plain text password')]
    # Note: Attribute commented out to avoid ps2exe build issues
    param(
        [Parameter(Mandatory = $false)]
        [string]$EncryptedPassword
    )

    try {
        if ([string]::IsNullOrEmpty($EncryptedPassword)) {
            return ""
        }

        # Try to decrypt as DPAPI-encrypted string
        try {
            $secureString = ConvertTo-SecureString -String $EncryptedPassword
            $marshalType = "System.Runtime.InteropServices.Marshal" -as [type]
            $bstr = $marshalType::SecureStringToBSTR($secureString)
            $plainText = $marshalType::PtrToStringBSTR($bstr)
            $marshalType::ZeroFreeBSTR($bstr)

            return $plainText
        } catch {
            # If decryption fails, assume it's plain text (backward compatibility)
            Write-Verbose "Password is not encrypted, treating as plain text"
            return $EncryptedPassword
        }
    } catch {
        Write-Warning "Failed to decrypt password: $($_.Exception.Message)"
        return ""
    }
}

function Save-CurrentGameData {
    if (-not $script:CurrentGameId) {
        Write-Verbose "No game selected, skipping save"
        return
    }

    if (-not $script:StateManager -or -not $script:StateManager.ConfigData.games) {
        Write-Warning "StateManager or games not available"
        return
    }

    # 1. Read the new game ID from the GameIdTextBox (if present)
    $gameIdTextBox = $script:Window.FindName("GameIdTextBox")
    $newGameId = if ($gameIdTextBox -and $gameIdTextBox.Text) {
        $gameIdTextBox.Text.Trim()
    } else {
        $script:CurrentGameId
    }

    # 2. Validate game inputs (Game ID, Steam AppID, Epic Game ID, Executable Path depending on platform)
    $platformCombo = $script:Window.FindName("PlatformComboBox")
    $platform = if ($platformCombo -and $platformCombo.SelectedItem) { $platformCombo.SelectedItem.Tag } else { "" }

    $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
    $steamAppId = if ($steamAppIdTextBox) { $steamAppIdTextBox.Text.Trim() } else { "" }

    $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
    $epicGameId = if ($epicGameIdTextBox) { $epicGameIdTextBox.Text.Trim() } else { "" }

    $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
    $riotGameId = if ($riotGameIdTextBox) { $riotGameIdTextBox.Text.Trim() } else { "" }

    $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
    $executablePath = if ($executablePathTextBox) { $executablePathTextBox.Text.Trim() } else { "" }

    # Use ValidationRules module for validation
    $validationResult = Test-GameConfiguration -GameId $newGameId -Platform $platform -SteamAppId $steamAppId -EpicGameId $epicGameId -RiotGameId $riotGameId -ExecutablePath $executablePath

    if (-not $validationResult.IsValid) {
        foreach ($err in $validationResult.Errors) {
            $script:UIManager.SetInputError($err.Control, $script:Localization.GetMessage($err.Key))
        }
        Show-SafeMessage -Key $validationResult.Errors[0].Key -MessageType "Warning"
        return
    }

    $idChanged = ($newGameId -ne $script:CurrentGameId)

    # 3. When ID changed, ensure the new ID is not already in use
    if ($idChanged) {
        if ($script:StateManager.ConfigData.games.PSObject.Properties.Name -contains $newGameId) {
            Write-Warning "Game ID '$newGameId' is already in use. Cannot rename."
            # Note: Add key "gameIdAlreadyExists" to localization/messages.json
            Show-SafeMessage -Key "gameIdAlreadyExists" -MessageType "Warning" -FormatArgs @($newGameId)
            return
        }
        Write-Verbose "Game ID changed from '$script:CurrentGameId' to '$newGameId'"
    }

    # Retrieve existing game data using the old ID
    $gameData = $script:StateManager.ConfigData.games.$script:CurrentGameId
    if (-not $gameData) {
        Write-Warning "Game data not found for: $script:CurrentGameId"
        return
    }

    Write-Verbose "Saving game data for: $script:CurrentGameId $(if ($idChanged) { "-> $newGameId" })"

    # Save game name
    $gameNameTextBox = $script:Window.FindName("GameNameTextBox")
    if ($gameNameTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "name" -Value $gameNameTextBox.Text
    }

    # Save process name
    $processNameTextBox = $script:Window.FindName("ProcessNameTextBox")
    if ($processNameTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "processName" -Value $processNameTextBox.Text
    }

    # Save comment
    $gameCommentTextBox = $script:Window.FindName("GameCommentTextBox")
    if ($gameCommentTextBox) {
        $comment = $gameCommentTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($comment)) {
            if ($gameData.PSObject.Properties.Name -contains "_comment") {
                $gameData.PSObject.Properties.Remove("_comment")
            }
        } else {
            Set-PropertyValue -Object $gameData -PropertyName "_comment" -Value $comment
        }
        Write-Verbose "Saved _comment: $comment"
    }

    # Save platform
    $platformCombo = $script:Window.FindName("PlatformComboBox")
    if ($platformCombo -and $platformCombo.SelectedItem) {
        Set-PropertyValue -Object $gameData -PropertyName "platform" -Value $platformCombo.SelectedItem.Tag
    }

    # Save Steam AppID
    $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
    if ($steamAppIdTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "steamAppId" -Value $steamAppIdTextBox.Text
    }

    # Save Epic GameID
    $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
    if ($epicGameIdTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "epicGameId" -Value $epicGameIdTextBox.Text
    }

    # Save Riot GameID
    $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
    if ($riotGameIdTextBox) {
        Set-PropertyValue -Object $gameData -PropertyName "riotGameId" -Value $riotGameIdTextBox.Text
    }

    # Save executable path (normalize backslashes to forward slashes)
    $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
    if ($executablePathTextBox) {
        $normalizedPath = $executablePathTextBox.Text -replace '\\', '/'
        Set-PropertyValue -Object $gameData -PropertyName "executablePath" -Value $normalizedPath
    }

    # Save managed apps list
    $appsToManagePanel = $script:Window.FindName("AppsToManagePanel")
    if ($appsToManagePanel) {
        $appsToManage = @()
        foreach ($child in $appsToManagePanel.Children) {
            if ($child -and
                $child.GetType().FullName -eq 'System.Windows.Controls.CheckBox' -and
                $child.IsChecked) {
                $appsToManage += $child.Tag
            }
        }
        Set-PropertyValue -Object $gameData -PropertyName "appsToManage" -Value $appsToManage
    }

    if (-not $gameData.PSObject.Properties["integrations"]) {
        $gameData | Add-Member -NotePropertyName "integrations" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    # save obs setting
    $useOBSCheck = $script:Window.FindName("UseOBSIntegrationCheckBox")
    if ($useOBSCheck) {
        if (-not $gameData.integrations.PSObject.Properties["useOBS"]) {
            $gameData.integrations | Add-Member -NotePropertyName "useOBS" -NotePropertyValue ([bool]$useOBSCheck.IsChecked) -Force
        } else {
            $gameData.integrations.useOBS = [bool]$useOBSCheck.IsChecked
        }

        # Save OBS game-specific settings if enabled
        if ($useOBSCheck.IsChecked) {
            if (-not $gameData.integrations.PSObject.Properties["obsSettings"]) {
                $gameData.integrations | Add-Member -NotePropertyName "obsSettings" -NotePropertyValue ([PSCustomObject]@{}) -Force
            }

            # Save replay buffer behavior
            $replayBufferBehaviorCombo = $script:Window.FindName("OBSReplayBufferBehaviorCombo")
            if ($replayBufferBehaviorCombo -and $replayBufferBehaviorCombo.SelectedItem) {
                $behavior = $replayBufferBehaviorCombo.SelectedItem.Tag
                Set-PropertyValue -Object $gameData.integrations.obsSettings -PropertyName "replayBufferBehavior" -Value $behavior
            } else {
                # Default to UseGlobal if not set
                Set-PropertyValue -Object $gameData.integrations.obsSettings -PropertyName "replayBufferBehavior" -Value "UseGlobal"
            }

            # Save target scene name
            $targetSceneTextBox = $script:Window.FindName("OBSTargetSceneTextBox")
            if ($targetSceneTextBox) {
                $sceneName = $targetSceneTextBox.Text.Trim()
                Set-PropertyValue -Object $gameData.integrations.obsSettings -PropertyName "targetSceneName" -Value $sceneName
            }

            # Save enable rollback
            $enableRollbackCheckBox = $script:Window.FindName("OBSEnableRollbackCheckBox")
            if ($enableRollbackCheckBox) {
                Set-PropertyValue -Object $gameData.integrations.obsSettings -PropertyName "enableRollback" -Value ([bool]$enableRollbackCheckBox.IsChecked)
            } else {
                Set-PropertyValue -Object $gameData.integrations.obsSettings -PropertyName "enableRollback" -Value $false
            }
        } else {
            # Remove obsSettings if OBS integration is disabled
            if ($gameData.integrations.PSObject.Properties["obsSettings"]) {
                $gameData.integrations.PSObject.Properties.Remove("obsSettings")
            }
        }
    }

    # save discord setting
    $useDiscordCheck = $script:Window.FindName("UseDiscordIntegrationCheckBox")
    if ($useDiscordCheck) {
        if (-not $gameData.integrations.PSObject.Properties["useDiscord"]) {
            $gameData.integrations | Add-Member -NotePropertyName "useDiscord" -NotePropertyValue ([bool]$useDiscordCheck.IsChecked) -Force
        } else {
            $gameData.integrations.useDiscord = [bool]$useDiscordCheck.IsChecked
        }
    }

    # save VTube Studio setting
    $useVTubeCheck = $script:Window.FindName("UseVTubeStudioIntegrationCheckBox")
    if ($useVTubeCheck) {
        if (-not $gameData.integrations.PSObject.Properties["useVTubeStudio"]) {
            $gameData.integrations | Add-Member -NotePropertyName "useVTubeStudio" -NotePropertyValue ([bool]$useVTubeCheck.IsChecked) -Force
        } else {
            $gameData.integrations.useVTubeStudio = [bool]$useVTubeCheck.IsChecked
        }

        # Save VTube Studio game-specific settings if enabled
        if ($useVTubeCheck.IsChecked) {
            if (-not $gameData.integrations.PSObject.Properties["vtubeStudioSettings"]) {
                $gameData.integrations | Add-Member -NotePropertyName "vtubeStudioSettings" -NotePropertyValue ([PSCustomObject]@{}) -Force
            }

            # Save model ID
            $modelIdTextBox = $script:Window.FindName("VTubeModelIdTextBox")
            if ($modelIdTextBox) {
                $modelId = $modelIdTextBox.Text.Trim()
                if ($modelId) {
                    Set-PropertyValue -Object $gameData.integrations.vtubeStudioSettings -PropertyName "modelId" -Value $modelId
                } else {
                    # Remove modelId if empty
                    if ($gameData.integrations.vtubeStudioSettings.PSObject.Properties["modelId"]) {
                        $gameData.integrations.vtubeStudioSettings.PSObject.Properties.Remove("modelId")
                    }
                }
            }

            # Save launch hotkeys
            $launchHotkeysTextBox = $script:Window.FindName("VTubeOnLaunchHotkeysTextBox")
            if ($launchHotkeysTextBox) {
                $hotkeyText = $launchHotkeysTextBox.Text.Trim()
                if ($hotkeyText) {
                    $hotkeys = $hotkeyText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    Set-PropertyValue -Object $gameData.integrations.vtubeStudioSettings -PropertyName "onLaunchHotkeys" -Value @($hotkeys)
                } else {
                    # Remove onLaunchHotkeys if empty
                    if ($gameData.integrations.vtubeStudioSettings.PSObject.Properties["onLaunchHotkeys"]) {
                        $gameData.integrations.vtubeStudioSettings.PSObject.Properties.Remove("onLaunchHotkeys")
                    }
                }
            }

            # Save exit hotkeys
            $exitHotkeysTextBox = $script:Window.FindName("VTubeOnExitHotkeysTextBox")
            if ($exitHotkeysTextBox) {
                $hotkeyText = $exitHotkeysTextBox.Text.Trim()
                if ($hotkeyText) {
                    $hotkeys = $hotkeyText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    Set-PropertyValue -Object $gameData.integrations.vtubeStudioSettings -PropertyName "onExitHotkeys" -Value @($hotkeys)
                } else {
                    # Remove onExitHotkeys if empty
                    if ($gameData.integrations.vtubeStudioSettings.PSObject.Properties["onExitHotkeys"]) {
                        $gameData.integrations.vtubeStudioSettings.PSObject.Properties.Remove("onExitHotkeys")
                    }
                }
            }
        } else {
            # Remove vtubeStudioSettings if VTube Studio integration is disabled
            if ($gameData.integrations.PSObject.Properties["vtubeStudioSettings"]) {
                $gameData.integrations.PSObject.Properties.Remove("vtubeStudioSettings")
            }
        }
    }

    # If the ID changed, perform the rename operation on the games object
    if ($idChanged) {
        Write-Verbose "Performing game ID rename operation"

        # (1) Add the game data under the new ID
        $script:StateManager.ConfigData.games | Add-Member -NotePropertyName $newGameId -NotePropertyValue $gameData -Force

        # (2) Remove the old ID entry
        $script:StateManager.ConfigData.games.PSObject.Properties.Remove($script:CurrentGameId)

        # (3) Update the _order array if present
        if ($script:StateManager.ConfigData.games._order) {
            $orderIndex = $script:StateManager.ConfigData.games._order.IndexOf($script:CurrentGameId)
            if ($orderIndex -ge 0) {
                $script:StateManager.ConfigData.games._order[$orderIndex] = $newGameId
            }
        }

        # (4) Update the current selected game ID to the new one
        $script:CurrentGameId = $newGameId
        Write-Verbose "Game ID renamed successfully to: $newGameId"
    }

    # Mark configuration as modified if StateManager supports it
    try {
        if ($script:StateManager -and $script:StateManager.SetModified) {
            $script:StateManager.SetModified()
        }
    } catch {
        Write-Verbose "SetModified not available or failed: $($_.Exception.Message)"
    }

    Write-Verbose "Game data saved successfully for: $script:CurrentGameId"
}
function Save-CurrentAppData {
    if (-not $script:CurrentAppId) {
        Write-Verbose "No app selected, skipping save"
        return
    }

    if (-not $script:StateManager -or -not $script:StateManager.ConfigData.managedApps) {
        Write-Warning "StateManager or managedApps not available"
        return
    }

    # Get the user-entered app ID from the text box
    # This is the actual config key, not the display name
    $appIdTextBox = $script:Window.FindName("AppIdTextBox")
    $newAppId = if ($appIdTextBox -and $appIdTextBox.Text) {
        $appIdTextBox.Text.Trim()
    } else {
        $script:CurrentAppId
    }

    # Validate the new app ID
    if ([string]::IsNullOrWhiteSpace($newAppId)) {
        Write-Warning "App ID cannot be empty"
        Show-SafeMessage -Key "appIdCannotBeEmpty" -MessageType "Warning"
        return
    }

    # Check if the app ID has changed
    $idChanged = ($newAppId -ne $script:CurrentAppId)

    # If ID changed, validate that the new ID is not already in use
    if ($idChanged) {
        if ($script:StateManager.ConfigData.managedApps.PSObject.Properties.Name -contains $newAppId) {
            Write-Warning "App ID '$newAppId' is already in use. Cannot rename."
            Show-SafeMessage -Key "appIdAlreadyExists" -MessageType "Warning" -FormatArgs @($newAppId)
            return
        }
        Write-Verbose "App ID changed from '$script:CurrentAppId' to '$newAppId'"
    }

    # Get the existing app data
    $appData = $script:StateManager.ConfigData.managedApps.$script:CurrentAppId
    if (-not $appData) {
        Write-Warning "App data not found for: $script:CurrentAppId"
        return
    }

    Write-Verbose "Saving app data for: $script:CurrentAppId $(if ($idChanged) { "-> $newAppId" })"

    # Save display name
    $appDisplayNameTextBox = $script:Window.FindName("AppDisplayNameTextBox")
    if ($appDisplayNameTextBox) {
        $displayName = $appDisplayNameTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            # If displayName is empty, use the app ID as displayName
            $displayName = $newAppId
            Write-Verbose "DisplayName is empty, using app ID as displayName: $displayName"
        }

        Set-PropertyValue -Object $appData -PropertyName "displayName" -Value $displayName
        Write-Verbose "Saved displayName: $displayName"
    }

    # Save comment
    $appCommentTextBox = $script:Window.FindName("AppCommentTextBox")
    if ($appCommentTextBox) {
        $comment = $appCommentTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($comment)) {
            # If comment is empty, remove the property
            if ($appData.PSObject.Properties.Name -contains "_comment") {
                $appData.PSObject.Properties.Remove("_comment")
            }
        } else {
            Set-PropertyValue -Object $appData -PropertyName "_comment" -Value $comment
        }
        Write-Verbose "Saved _comment: $comment"
    }

    # Save process name
    $appProcessNameTextBox = $script:Window.FindName("AppProcessNameTextBox")
    if ($appProcessNameTextBox) {
        $processNameValue = $appProcessNameTextBox.Text.Trim()

        # Remove deprecated processNames property if it exists
        if ($appData.PSObject.Properties.Name -contains "processNames") {
            $appData.PSObject.Properties.Remove("processNames")
            Write-Verbose "Removed deprecated 'processNames' property"
        }

        if ([string]::IsNullOrWhiteSpace($processNameValue)) {
            # If empty, store as empty string
            Set-PropertyValue -Object $appData -PropertyName "processName" -Value ""
        } elseif ($processNameValue -match '\|') {
            # Multiple process names separated by pipe
            Set-PropertyValue -Object $appData -PropertyName "processName" -Value ($processNameValue -split '\|' | ForEach-Object { $_.Trim() })
        } else {
            # Single process name (already trimmed)
            Set-PropertyValue -Object $appData -PropertyName "processName" -Value $processNameValue
        }
        # Remove old 'processNames' key if it exists (backward compatibility cleanup)
        if ($appData.PSObject.Properties.Name -contains "processNames") {
            $appData.PSObject.Properties.Remove("processNames")
        }
        Write-Verbose "Saved processName: $processNameValue"
    }

    # Save path (normalize backslashes to forward slashes)
    $appPathTextBox = $script:Window.FindName("AppPathTextBox")
    if ($appPathTextBox) {
        $normalizedPath = $appPathTextBox.Text -replace '\\', '/'
        Set-PropertyValue -Object $appData -PropertyName "path" -Value $normalizedPath
    }

    # Save working directory (normalize backslashes to forward slashes)
    $workingDirectoryTextBox = $script:Window.FindName("WorkingDirectoryTextBox")
    if ($workingDirectoryTextBox) {
        $workingDirValue = $workingDirectoryTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($workingDirValue)) {
            # If working directory is empty, remove the property
            if ($appData.PSObject.Properties.Name -contains "workingDirectory") {
                $appData.PSObject.Properties.Remove("workingDirectory")
            }
        } else {
            $normalizedWorkingDir = $workingDirValue -replace '\\', '/'
            Set-PropertyValue -Object $appData -PropertyName "workingDirectory" -Value $normalizedWorkingDir
        }
    }

    # Save arguments
    $appArgumentsTextBox = $script:Window.FindName("AppArgumentsTextBox")
    if ($appArgumentsTextBox) {
        Set-PropertyValue -Object $appData -PropertyName "arguments" -Value $appArgumentsTextBox.Text
    }

    # Save start action
    $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
    if ($gameStartActionCombo -and $gameStartActionCombo.SelectedItem) {
        Set-PropertyValue -Object $appData -PropertyName "gameStartAction" -Value $gameStartActionCombo.SelectedItem.Tag
        # Remove old 'startAction' key if it exists (backward compatibility cleanup)
        if ($appData.PSObject.Properties.Name -contains "startAction") {
            $appData.PSObject.Properties.Remove("startAction")
        }
    }

    # Save end action
    $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
    if ($gameEndActionCombo -and $gameEndActionCombo.SelectedItem) {
        Set-PropertyValue -Object $appData -PropertyName "gameEndAction" -Value $gameEndActionCombo.SelectedItem.Tag
        # Remove old 'endAction' key if it exists (backward compatibility cleanup)
        if ($appData.PSObject.Properties.Name -contains "endAction") {
            $appData.PSObject.Properties.Remove("endAction")
        }
    }

    # Save termination method
    $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
    if ($terminationMethodCombo -and $terminationMethodCombo.SelectedItem) {
        Set-PropertyValue -Object $appData -PropertyName "terminationMethod" -Value $terminationMethodCombo.SelectedItem.Tag
    }

    # Save graceful timeout
    $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
    if ($gracefulTimeoutTextBox) {
        $timeoutSeconds = 5
        if ([int]::TryParse($gracefulTimeoutTextBox.Text, [ref]$timeoutSeconds)) {
            Set-PropertyValue -Object $appData -PropertyName "gracefulTimeoutMs" -Value ($timeoutSeconds * 1000)
        } else {
            Set-PropertyValue -Object $appData -PropertyName "gracefulTimeoutMs" -Value 5000
        }
        # Remove old 'gracefulTimeout' key if it exists (backward compatibility cleanup)
        if ($appData.PSObject.Properties.Name -contains "gracefulTimeout") {
            $appData.PSObject.Properties.Remove("gracefulTimeout")
        }
    }

    # If the app ID changed, we need to:
    # 1. Add the data under the new ID
    # 2. Remove the old ID entry
    # 3. Update the _order array
    # 4. Update references in games that use this app
    if ($idChanged) {
        Write-Verbose "Performing app ID rename operation"

        # Add data under new ID
        $script:StateManager.ConfigData.managedApps | Add-Member -NotePropertyName $newAppId -NotePropertyValue $appData -Force

        # Remove old ID entry
        $script:StateManager.ConfigData.managedApps.PSObject.Properties.Remove($script:CurrentAppId)

        # Update the _order array
        if ($script:StateManager.ConfigData.managedApps._order) {
            $orderIndex = $script:StateManager.ConfigData.managedApps._order.IndexOf($script:CurrentAppId)
            if ($orderIndex -ge 0) {
                $script:StateManager.ConfigData.managedApps._order[$orderIndex] = $newAppId
            }
        }

        # Update references in games' appsToManage arrays
        if ($script:StateManager.ConfigData.games) {
            foreach ($gameId in $script:StateManager.ConfigData.games.PSObject.Properties.Name) {
                if ($gameId -eq '_order') { continue }

                $game = $script:StateManager.ConfigData.games.$gameId
                if ($game.appsToManage -and ($game.appsToManage -contains $script:CurrentAppId)) {
                    $appIndex = $game.appsToManage.IndexOf($script:CurrentAppId)
                    if ($appIndex -ge 0) {
                        $game.appsToManage[$appIndex] = $newAppId
                        Write-Verbose "[INFO] Updated app reference in game '$gameId'"
                    }
                }
            }
        }

        # Update the current app ID reference
        $script:CurrentAppId = $newAppId

        Write-Verbose "App ID renamed successfully to: $newAppId"
    }

    # Mark as modified
    $script:StateManager.SetModified()

    Write-Verbose "App data saved for: $script:CurrentAppId"
}


function Save-GlobalSettingsData {
    Write-Verbose "Save-GlobalSettingsData: Starting to save global settings"

    try {
        # Get references to UI controls
        $obsHostTextBox = $script:Window.FindName("OBSHostTextBox")
        $obsPortTextBox = $script:Window.FindName("OBSPortTextBox")
        $obsPasswordBox = $script:Window.FindName("OBSPasswordBox")
        $replayBufferCheckBox = $script:Window.FindName("OBSReplayBufferCheckBox")
        $steamPathTextBox = $script:Window.FindName("SteamPathTextBox")
        $epicPathTextBox = $script:Window.FindName("EpicPathTextBox")
        $riotPathTextBox = $script:Window.FindName("RiotPathTextBox")
        $obsPathTextBox = $script:Window.FindName("OBSPathTextBox")
        $logRetentionCombo = $script:Window.FindName("LogRetentionCombo")
        $enableLogNotarizationCheckBox = $script:Window.FindName("EnableLogNotarizationCheckBox")

        # Ensure integrations section exists
        if (-not $script:StateManager.ConfigData.integrations) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "integrations" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs section exists
        if (-not $script:StateManager.ConfigData.integrations.obs) {
            $script:StateManager.ConfigData.integrations | Add-Member -NotePropertyName "obs" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs.websocket section exists
        if (-not $script:StateManager.ConfigData.integrations.obs.websocket) {
            $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "websocket" -NotePropertyValue @{} -Force
        }

        # Save OBS websocket settings
        if ($obsHostTextBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["host"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "host" -NotePropertyValue $obsHostTextBox.Text -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.host = $obsHostTextBox.Text
            }
            Write-Verbose "Saved OBS host: $($obsHostTextBox.Text)"
        }

        if ($obsPortTextBox) {
            $portValue = if ($obsPortTextBox.Text) { [int]$obsPortTextBox.Text } else { 4455 }
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["port"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "port" -NotePropertyValue $portValue -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.port = $portValue
            }
            Write-Verbose "Saved OBS port: $portValue"
        }

        if ($obsPasswordBox) {
            # Check if user entered a new password or if we should keep the existing one
            if ($obsPasswordBox.Password.Length -gt 0) {
                # User entered a new password - encrypt and save it
                $encryptedPassword = Protect-Password -PlainTextPassword $obsPasswordBox.Password

                if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "password" -NotePropertyValue $encryptedPassword -Force
                } else {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = $encryptedPassword
                }
                Write-Verbose "Saved OBS password (encrypted): $('*' * $obsPasswordBox.Password.Length)"
            } elseif ($obsPasswordBox.Tag -eq "SAVED") {
                # Password field is empty but Tag indicates password exists - keep existing password
                Write-Verbose "OBS password unchanged (keeping existing encrypted password)"
                # No action needed - existing password in config is preserved
            } else {
                # Password field is empty and no saved password - clear password
                if ($script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = ""
                }
                Write-Verbose "OBS password cleared"
            }
        }

        # Save OBS replay buffer setting
        if ($replayBufferCheckBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["replayBuffer"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "replayBuffer" -NotePropertyValue ([bool]$replayBufferCheckBox.IsChecked) -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.replayBuffer = [bool]$replayBufferCheckBox.IsChecked
            }
            Write-Verbose "Saved replay buffer: $($replayBufferCheckBox.IsChecked)"
        }

        # Ensure paths section exists
        if (-not $script:StateManager.ConfigData.paths) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "paths" -NotePropertyValue @{} -Force
        }

        # Save platform paths (normalize backslashes to forward slashes)
        if ($steamPathTextBox) {
            $normalizedPath = $steamPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.paths.PSObject.Properties["steam"]) {
                $script:StateManager.ConfigData.paths | Add-Member -NotePropertyName "steam" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.paths.steam = $normalizedPath
            }
            Write-Verbose "Saved Steam path: $normalizedPath"
        }

        if ($epicPathTextBox) {
            $normalizedPath = $epicPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.paths.PSObject.Properties["epic"]) {
                $script:StateManager.ConfigData.paths | Add-Member -NotePropertyName "epic" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.paths.epic = $normalizedPath
            }
            Write-Verbose "Saved Epic path: $normalizedPath"
        }

        if ($riotPathTextBox) {
            $normalizedPath = $riotPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.paths.PSObject.Properties["riot"]) {
                $script:StateManager.ConfigData.paths | Add-Member -NotePropertyName "riot" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.paths.riot = $normalizedPath
            }
            Write-Verbose "Saved Riot path: $normalizedPath"
        }

        if ($obsPathTextBox) {
            $normalizedPath = $obsPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["path"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "path" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.path = $normalizedPath
            }
            Write-Verbose "Saved OBS path: $normalizedPath"
        }

        # Ensure logging section exists
        if (-not $script:StateManager.ConfigData.logging) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "logging" -NotePropertyValue @{} -Force
        }

        # Save log retention setting
        if ($logRetentionCombo -and $logRetentionCombo.SelectedItem) {
            $retentionDays = switch ($logRetentionCombo.SelectedItem.Tag) {
                "7" { 7 }
                "30" { 30 }
                "180" { 180 }
                "unlimited" { 0 }
                default { 90 }
            }

            if (-not $script:StateManager.ConfigData.logging.PSObject.Properties["logRetentionDays"]) {
                $script:StateManager.ConfigData.logging | Add-Member -NotePropertyName "logRetentionDays" -NotePropertyValue $retentionDays -Force
            } else {
                $script:StateManager.ConfigData.logging.logRetentionDays = $retentionDays
            }
            Write-Verbose "Saved log retention days: $retentionDays"
        }

        # Save log notarization setting
        if ($enableLogNotarizationCheckBox) {
            if (-not $script:StateManager.ConfigData.logging.PSObject.Properties["enableNotarization"]) {
                $script:StateManager.ConfigData.logging | Add-Member -NotePropertyName "enableNotarization" -NotePropertyValue ([bool]$enableLogNotarizationCheckBox.IsChecked) -Force
            } else {
                $script:StateManager.ConfigData.logging.enableNotarization = [bool]$enableLogNotarizationCheckBox.IsChecked
            }
            Write-Verbose "Saved log notarization: $($enableLogNotarizationCheckBox.IsChecked)"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-GlobalSettingsData: Global settings saved successfully"

    } catch {
        Write-Error "Failed to save global settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-OBSSettingsData {
    Write-Verbose "Save-OBSSettingsData: Starting to save OBS settings"

    try {
        # Get references to UI controls from OBS tab
        $obsHostTextBox = $script:Window.FindName("OBSHostTextBox")
        $obsPortTextBox = $script:Window.FindName("OBSPortTextBox")
        $obsPasswordBox = $script:Window.FindName("OBSPasswordBox")
        $replayBufferCheckBox = $script:Window.FindName("OBSReplayBufferCheckBox")
        $obsPathTextBox = $script:Window.FindName("OBSPathTextBox")
        $obsAutoStartCheckBox = $script:Window.FindName("OBSAutoStartCheckBox")
        $obsAutoStopCheckBox = $script:Window.FindName("OBSAutoStopCheckBox")

        # Ensure integrations section exists
        if (-not $script:StateManager.ConfigData.integrations) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "integrations" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs section exists
        if (-not $script:StateManager.ConfigData.integrations.obs) {
            $script:StateManager.ConfigData.integrations | Add-Member -NotePropertyName "obs" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.obs.websocket section exists
        if (-not $script:StateManager.ConfigData.integrations.obs.websocket) {
            $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "websocket" -NotePropertyValue @{} -Force
        }

        # Save OBS websocket settings
        if ($obsHostTextBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["host"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "host" -NotePropertyValue $obsHostTextBox.Text -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.host = $obsHostTextBox.Text
            }
            Write-Verbose "Saved OBS host: $($obsHostTextBox.Text)"
        }

        if ($obsPortTextBox) {
            $portValue = if ($obsPortTextBox.Text) { [int]$obsPortTextBox.Text } else { 4455 }
            if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["port"]) {
                $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "port" -NotePropertyValue $portValue -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.websocket.port = $portValue
            }
            Write-Verbose "Saved OBS port: $portValue"
        }

        if ($obsPasswordBox) {
            if ($obsPasswordBox.Password.Length -gt 0) {
                $encryptedPassword = Protect-Password -PlainTextPassword $obsPasswordBox.Password
                if (-not $script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket | Add-Member -NotePropertyName "password" -NotePropertyValue $encryptedPassword -Force
                } else {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = $encryptedPassword
                }
                Write-Verbose "Saved OBS password (encrypted)"
            } elseif ($obsPasswordBox.Tag -eq "SAVED") {
                Write-Verbose "OBS password unchanged (keeping existing encrypted password)"
            } else {
                if ($script:StateManager.ConfigData.integrations.obs.websocket.PSObject.Properties["password"]) {
                    $script:StateManager.ConfigData.integrations.obs.websocket.password = ""
                }
                Write-Verbose "OBS password cleared"
            }
        }

        # Save OBS replay buffer setting
        if ($replayBufferCheckBox) {
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["replayBuffer"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "replayBuffer" -NotePropertyValue ([bool]$replayBufferCheckBox.IsChecked) -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.replayBuffer = [bool]$replayBufferCheckBox.IsChecked
            }
            Write-Verbose "Saved replay buffer: $($replayBufferCheckBox.IsChecked)"
        }

        # Save OBS executable path
        if ($obsPathTextBox) {
            $normalizedPath = $obsPathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["path"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "path" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.path = $normalizedPath
            }
            Write-Verbose "Saved OBS path: $normalizedPath"
        }

        # Save OBS game start/end actions based on checkboxes
        if ($obsAutoStartCheckBox) {
            $gameStartAction = if ($obsAutoStartCheckBox.IsChecked) { "enter-game-mode" } else { "none" }
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["gameStartAction"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "gameStartAction" -NotePropertyValue $gameStartAction -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.gameStartAction = $gameStartAction
            }
            Write-Verbose "Saved OBS gameStartAction: $gameStartAction"
        }

        if ($obsAutoStopCheckBox) {
            $gameEndAction = if ($obsAutoStopCheckBox.IsChecked) { "exit-game-mode" } else { "none" }
            if (-not $script:StateManager.ConfigData.integrations.obs.PSObject.Properties["gameEndAction"]) {
                $script:StateManager.ConfigData.integrations.obs | Add-Member -NotePropertyName "gameEndAction" -NotePropertyValue $gameEndAction -Force
            } else {
                $script:StateManager.ConfigData.integrations.obs.gameEndAction = $gameEndAction
            }
            Write-Verbose "Saved OBS gameEndAction: $gameEndAction"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-OBSSettingsData: OBS settings saved successfully"

    } catch {
        Write-Error "Failed to save OBS settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-DiscordSettingsData {
    Write-Verbose "Save-DiscordSettingsData: Starting to save Discord settings"

    try {
        # Ensure integrations section exists
        if (-not $script:StateManager.ConfigData.integrations) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "integrations" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.discord section exists
        if (-not $script:StateManager.ConfigData.integrations.discord) {
            $script:StateManager.ConfigData.integrations | Add-Member -NotePropertyName "discord" -NotePropertyValue @{} -Force
        }

        # Get Discord path from UI
        $discordPathTextBox = $script:Window.FindName("DiscordPathTextBox")
        if ($discordPathTextBox -and $discordPathTextBox.Text) {
            if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["path"]) {
                $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "path" -NotePropertyValue $discordPathTextBox.Text -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.path = $discordPathTextBox.Text
            }
            Write-Verbose "Save-DiscordSettingsData: Discord path set to $($discordPathTextBox.Text)"
        }

        # Get game mode checkbox and map to gameStartAction
        $enableGameModeCheckBox = $script:Window.FindName("DiscordEnableGameModeCheckBox")
        if ($enableGameModeCheckBox) {
            $gameStartAction = if ($enableGameModeCheckBox.IsChecked) { "enter-game-mode" } else { "none" }
            if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["gameStartAction"]) {
                $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "gameStartAction" -NotePropertyValue $gameStartAction -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.gameStartAction = $gameStartAction
            }
            Write-Verbose "Save-DiscordSettingsData: gameStartAction set to $gameStartAction"
        }

        # Get status settings and save to discord section (flattened structure)
        $statusOnStartCombo = $script:Window.FindName("DiscordStatusOnStartCombo")
        if ($statusOnStartCombo -and $statusOnStartCombo.SelectedItem) {
            if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["statusOnGameStart"]) {
                $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "statusOnGameStart" -NotePropertyValue $statusOnStartCombo.SelectedItem.Tag -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.statusOnGameStart = $statusOnStartCombo.SelectedItem.Tag
            }
            Write-Verbose "Save-DiscordSettingsData: statusOnGameStart set to $($statusOnStartCombo.SelectedItem.Tag)"
        }

        $statusOnEndCombo = $script:Window.FindName("DiscordStatusOnEndCombo")
        if ($statusOnEndCombo -and $statusOnEndCombo.SelectedItem) {
            if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["statusOnGameEnd"]) {
                $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "statusOnGameEnd" -NotePropertyValue $statusOnEndCombo.SelectedItem.Tag -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.statusOnGameEnd = $statusOnEndCombo.SelectedItem.Tag
            }
            Write-Verbose "Save-DiscordSettingsData: statusOnGameEnd set to $($statusOnEndCombo.SelectedItem.Tag)"
        }

        # Get overlay checkbox
        $disableOverlayCheckBox = $script:Window.FindName("DiscordDisableOverlayCheckBox")
        if ($disableOverlayCheckBox) {
            if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["disableOverlay"]) {
                $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "disableOverlay" -NotePropertyValue $disableOverlayCheckBox.IsChecked -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.disableOverlay = $disableOverlayCheckBox.IsChecked
            }
            Write-Verbose "Save-DiscordSettingsData: disableOverlay set to $($disableOverlayCheckBox.IsChecked)"
        }

        # Ensure customPresence section exists and preserve existing values
        if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["customPresence"]) {
            $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "customPresence" -NotePropertyValue ([PSCustomObject]@{
                    enabled = $false
                    state = "Focus Gaming Mode"
                }) -Force
        }

        # Get Rich Presence settings and save to discord.rpc subsection
        if (-not $script:StateManager.ConfigData.integrations.discord.PSObject.Properties["rpc"]) {
            $script:StateManager.ConfigData.integrations.discord | Add-Member -NotePropertyName "rpc" -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        $rpcEnableCheckBox = $script:Window.FindName("DiscordRPCEnableCheckBox")
        if ($rpcEnableCheckBox) {
            if (-not $script:StateManager.ConfigData.integrations.discord.rpc.PSObject.Properties["enabled"]) {
                $script:StateManager.ConfigData.integrations.discord.rpc | Add-Member -NotePropertyName "enabled" -NotePropertyValue $rpcEnableCheckBox.IsChecked -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.rpc.enabled = $rpcEnableCheckBox.IsChecked
            }
            Write-Verbose "Save-DiscordSettingsData: RPC enabled set to $($rpcEnableCheckBox.IsChecked)"
        }

        $rpcAppIdTextBox = $script:Window.FindName("DiscordRPCAppIdTextBox")
        if ($rpcAppIdTextBox) {
            if (-not $script:StateManager.ConfigData.integrations.discord.rpc.PSObject.Properties["applicationId"]) {
                $script:StateManager.ConfigData.integrations.discord.rpc | Add-Member -NotePropertyName "applicationId" -NotePropertyValue $rpcAppIdTextBox.Text -Force
            } else {
                $script:StateManager.ConfigData.integrations.discord.rpc.applicationId = $rpcAppIdTextBox.Text
            }
            Write-Verbose "Save-DiscordSettingsData: RPC applicationId set to $($rpcAppIdTextBox.Text)"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-DiscordSettingsData: Discord settings saved successfully"

    } catch {
        Write-Error "Failed to save Discord settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-VTubeStudioSettingsData {
    Write-Verbose "Save-VTubeStudioSettingsData: Starting to save VTube Studio settings"

    try {
        # Get references to UI controls from VTube Studio tab
        $vtubePathTextBox = $script:Window.FindName("VTubePathTextBox")
        $vtubeAutoStartCheckBox = $script:Window.FindName("VTubeAutoStartCheckBox")
        $vtubeAutoStopCheckBox = $script:Window.FindName("VTubeAutoStopCheckBox")
        $vtubeWebSocketEnableCheckBox = $script:Window.FindName("VTubeWebSocketEnableCheckBox")
        $vtubeHostTextBox = $script:Window.FindName("VTubeHostTextBox")
        $vtubePortTextBox = $script:Window.FindName("VTubePortTextBox")
        $vtubeAuthTokenPasswordBox = $script:Window.FindName("VTubeAuthTokenPasswordBox")
        $vtubeDefaultModelIdTextBox = $script:Window.FindName("VTubeDefaultModelIdTextBox")

        # Ensure integrations section exists
        if (-not $script:StateManager.ConfigData.integrations) {
            $script:StateManager.ConfigData | Add-Member -NotePropertyName "integrations" -NotePropertyValue @{} -Force
        }

        # Ensure integrations.vtubeStudio section exists
        if (-not $script:StateManager.ConfigData.integrations.vtubeStudio) {
            $script:StateManager.ConfigData.integrations | Add-Member -NotePropertyName "vtubeStudio" -NotePropertyValue @{} -Force
        }

        # Save VTube Studio executable path
        if ($vtubePathTextBox) {
            $normalizedPath = $vtubePathTextBox.Text -replace '\\', '/'
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["path"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio | Add-Member -NotePropertyName "path" -NotePropertyValue $normalizedPath -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.path = $normalizedPath
            }
            Write-Verbose "Saved VTube Studio path: $normalizedPath"
        }

        # Save VTube Studio game start/end actions based on checkboxes
        if ($vtubeAutoStartCheckBox) {
            $gameStartAction = if ($vtubeAutoStartCheckBox.IsChecked) { "enter-game-mode" } else { "none" }
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["gameStartAction"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio | Add-Member -NotePropertyName "gameStartAction" -NotePropertyValue $gameStartAction -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.gameStartAction = $gameStartAction
            }
            Write-Verbose "Saved VTube Studio gameStartAction: $gameStartAction"
        }

        if ($vtubeAutoStopCheckBox) {
            $gameEndAction = if ($vtubeAutoStopCheckBox.IsChecked) { "exit-game-mode" } else { "none" }
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["gameEndAction"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio | Add-Member -NotePropertyName "gameEndAction" -NotePropertyValue $gameEndAction -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.gameEndAction = $gameEndAction
            }
            Write-Verbose "Saved VTube Studio gameEndAction: $gameEndAction"
        }

        # Ensure websocket section exists
        if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["websocket"]) {
            $script:StateManager.ConfigData.integrations.vtubeStudio | Add-Member -NotePropertyName "websocket" -NotePropertyValue @{} -Force
        }

        # Save WebSocket enabled status
        if ($vtubeWebSocketEnableCheckBox) {
            $websocketEnabled = [bool]$vtubeWebSocketEnableCheckBox.IsChecked
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.websocket.PSObject.Properties["enabled"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio.websocket | Add-Member -NotePropertyName "enabled" -NotePropertyValue $websocketEnabled -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.websocket.enabled = $websocketEnabled
            }
            Write-Verbose "Saved VTube Studio WebSocket enabled: $websocketEnabled"
        }

        # Save WebSocket host
        if ($vtubeHostTextBox) {
            $hostValue = $vtubeHostTextBox.Text
            if ([string]::IsNullOrWhiteSpace($hostValue)) {
                $hostValue = "localhost"
            }
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.websocket.PSObject.Properties["host"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio.websocket | Add-Member -NotePropertyName "host" -NotePropertyValue $hostValue -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.websocket.host = $hostValue
            }
            Write-Verbose "Saved VTube Studio WebSocket host: $hostValue"
        }

        # Save WebSocket port
        if ($vtubePortTextBox) {
            $portText = $vtubePortTextBox.Text
            $port = 8001  # Default port
            if (-not [string]::IsNullOrWhiteSpace($portText)) {
                try {
                    $port = [int]$portText
                } catch {
                    Write-Warning "Invalid port number '$portText', using default 8001"
                    $port = 8001
                }
            }
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.websocket.PSObject.Properties["port"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio.websocket | Add-Member -NotePropertyName "port" -NotePropertyValue $port -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.websocket.port = $port
            }
            Write-Verbose "Saved VTube Studio WebSocket port: $port"
        }

        # Save authentication token (encrypt using DPAPI)
        if ($vtubeAuthTokenPasswordBox) {
            if ($vtubeAuthTokenPasswordBox.Password.Length -gt 0) {
                $encryptedToken = Protect-Password -PlainTextPassword $vtubeAuthTokenPasswordBox.Password
                if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["authenticationToken"]) {
                    $script:StateManager.ConfigData.integrations.vtubeStudio | Add-Member -NotePropertyName "authenticationToken" -NotePropertyValue $encryptedToken -Force
                } else {
                    $script:StateManager.ConfigData.integrations.vtubeStudio.authenticationToken = $encryptedToken
                }
                Write-Verbose "Saved VTube Studio authentication token (encrypted)"
            } elseif ($vtubeAuthTokenPasswordBox.Tag -eq "SAVED") {
                Write-Verbose "VTube Studio authentication token unchanged (keeping existing encrypted token)"
            } else {
                if ($script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["authenticationToken"]) {
                    $script:StateManager.ConfigData.integrations.vtubeStudio.authenticationToken = ""
                }
                Write-Verbose "VTube Studio authentication token cleared"
            }
        }

        # Save default model ID
        if ($vtubeDefaultModelIdTextBox) {
            $modelId = $vtubeDefaultModelIdTextBox.Text.Trim()
            if (-not $script:StateManager.ConfigData.integrations.vtubeStudio.PSObject.Properties["defaultModelId"]) {
                $script:StateManager.ConfigData.integrations.vtubeStudio | Add-Member -NotePropertyName "defaultModelId" -NotePropertyValue $modelId -Force
            } else {
                $script:StateManager.ConfigData.integrations.vtubeStudio.defaultModelId = $modelId
            }
            Write-Verbose "Saved VTube Studio default model ID: $modelId"
        }

        # Mark configuration as modified
        $script:StateManager.SetModified()

        Write-Verbose "Save-VTubeStudioSettingsData: VTube Studio settings saved successfully"

    } catch {
        Write-Error "Failed to save VTube Studio settings data: $($_.Exception.Message)"
        throw
    }
}

function Save-OriginalConfig {
    if ($script:StateManager) {
        $script:StateManager.SaveOriginalConfig()
        Write-Verbose "Original configuration saved"
    } else {
        Write-Warning "StateManager not available, cannot save original configuration"
    }
}
