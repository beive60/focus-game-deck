class ConfigEditorEvents {
    $uiManager
    $stateManager
    [string]$appRoot
    [bool]$IsExecutable

    # Drag and drop state
    [object]$dragStartPoint = $null
    [object]$draggedItem = $null
    [object]$currentAdorner = $null
    [object]$adornerLayer = $null

    ConfigEditorEvents($ui, $state, [string]$appRoot, [bool]$IsExecutable) {
        $this.uiManager = $ui
        $this.stateManager = $state
        $this.appRoot = $appRoot
        $this.IsExecutable = $IsExecutable
    }

    # Helper method to set ComboBox selection by matching Tag property
    [void] SetComboBoxSelectionByTag([Object]$ComboBox, [string]$TagValue) {
        if (-not $ComboBox) {
            Write-Warning "ComboBox is null, cannot set selection"
            return
        }

        try {
            # Find the ComboBoxItem with matching Tag
            $matchingItem = $null
            foreach ($item in $ComboBox.Items) {
                if (
                    $item -and
                    $item.GetType().FullName -eq 'System.Windows.Controls.ComboBoxItem' -and
                    $item.Tag -eq $TagValue
                ) {
                    $matchingItem = $item
                    break
                }
            }

            if ($matchingItem) {
                $ComboBox.SelectedItem = $matchingItem
                Write-Verbose "Set ComboBox selection to Tag: $TagValue"
            } else {
                Write-Verbose "No ComboBoxItem found with Tag: $TagValue in ComboBox: $($ComboBox.Name)"
                $ComboBox.SelectedIndex = -1
            }
        } catch {
            Write-Warning "Failed to set ComboBox selection: $($_.Exception.Message)"
        }
    }

    # Helper method to update TerminationMethod ComboBox enabled state
    # Should be enabled only when either start or end action is "stop-process"
    # Also updates AppArgumentsTextBox state (enabled only when either action is "start-process")
    [void] UpdateTerminationMethodState() {
        $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
        $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
        $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
        $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
        $appArgumentsTextBox = $script:Window.FindName("AppArgumentsTextBox")

        if (-not $terminationMethodCombo) {
            Write-Verbose "TerminationMethodCombo not found"
            return
        }

        # Get selected actions
        $startAction = if ($gameStartActionCombo -and $gameStartActionCombo.SelectedItem) {
            $gameStartActionCombo.SelectedItem.Tag
        } else {
            "none"
        }

        $endAction = if ($gameEndActionCombo -and $gameEndActionCombo.SelectedItem) {
            $gameEndActionCombo.SelectedItem.Tag
        } else {
            "none"
        }

        # Enable termination method only if either action is "stop-process"
        $shouldEnableTermination = ($startAction -eq "stop-process") -or ($endAction -eq "stop-process")

        # Store current selection before disabling
        if (-not $shouldEnableTermination -and $terminationMethodCombo.SelectedItem) {
            # Save the current selection
            if (-not $script:SavedTerminationMethod) {
                $script:SavedTerminationMethod = $terminationMethodCombo.SelectedItem.Tag
            }
            # Clear selection when disabled
            $terminationMethodCombo.SelectedIndex = -1
        } elseif ($shouldEnableTermination -and $terminationMethodCombo.SelectedIndex -eq -1) {
            # Restore saved selection when re-enabled, or use default
            $savedValue = if ($script:SavedTerminationMethod) {
                $script:SavedTerminationMethod
            } else {
                "auto"
            }
            $this.SetComboBoxSelectionByTag($terminationMethodCombo, $savedValue)
        }

        $terminationMethodCombo.IsEnabled = $shouldEnableTermination
        if ($gracefulTimeoutTextBox) {
            $gracefulTimeoutTextBox.IsEnabled = $shouldEnableTermination
        }

        # Enable arguments textbox only if either action is "start-process"
        if ($appArgumentsTextBox) {
            $shouldEnableArguments = ($startAction -eq "start-process") -or ($endAction -eq "start-process")
            $appArgumentsTextBox.IsEnabled = $shouldEnableArguments
            Write-Verbose "AppArguments enabled: $shouldEnableArguments (StartAction: $startAction, EndAction: $endAction)"
        }

        Write-Verbose "TerminationMethod enabled: $shouldEnableTermination (StartAction: $startAction, EndAction: $endAction)"
    }

    # Helper method to reorder items in an array
    # Returns the new order array with the item moved from sourceIndex to targetIndex
    [array] ReorderItems([array]$currentOrder, [int]$sourceIndex, [int]$targetIndex) {
        # Validate source index
        if ($sourceIndex -lt 0 -or $sourceIndex -ge $currentOrder.Count) {
            Write-Warning "Invalid source index: $sourceIndex (array size: $($currentOrder.Count))"
            return $currentOrder
        }

        if ($sourceIndex -eq $targetIndex) {
            return $currentOrder
        }

        # Create a new ArrayList for easier manipulation
        $newOrder = [System.Collections.ArrayList]::new($currentOrder)
        $itemToMove = $newOrder[$sourceIndex]

        # Remove the item from source position by index
        $newOrder.RemoveAt($sourceIndex)

        # Adjust target index if removing the item shifted positions
        $adjustedTargetIndex = $targetIndex
        if ($sourceIndex -lt $targetIndex) {
            $adjustedTargetIndex = $targetIndex - 1
        }

        # Clamp adjusted target index to valid range
        $adjustedTargetIndex = [Math]::Max(0, [Math]::Min($adjustedTargetIndex, $newOrder.Count))

        # Insert at new position
        $newOrder.Insert($adjustedTargetIndex, $itemToMove)

        # Convert back to array
        return @($newOrder)
    }

    # Helper method to get the ListBoxItem under the mouse pointer
    [object] GetListBoxItemUnderMouse([object]$listBox, [object]$position) {
        try {
            $visualTreeHelperType = "System.Windows.Media.VisualTreeHelper" -as [type]
            $listBoxItemType = "System.Windows.Controls.ListBoxItem" -as [type]

            $hitTestResult = $visualTreeHelperType::HitTest($listBox, $position)
            if ($hitTestResult) {
                $element = $hitTestResult.VisualHit
                # Walk up the visual tree to find the ListBoxItem
                while ($element -and $element.GetType().FullName -ne 'System.Windows.Controls.ListBoxItem') {
                    $element = $visualTreeHelperType::GetParent($element)
                }
                # Verify the element is actually a ListBoxItem
                if ($element -and $element.GetType().FullName -eq 'System.Windows.Controls.ListBoxItem') {
                    return $element
                }
            }
        } catch {
            Write-Verbose "Failed to get ListBoxItem under mouse: $($_.Exception.Message)"
        }
        return $null
    }

    # Helper method to remove the current insertion indicator adorner
    [void] RemoveInsertionIndicator() {
        if ($this.currentAdorner -and $this.adornerLayer) {
            try {
                $this.adornerLayer.Remove($this.currentAdorner)
                $this.currentAdorner = $null
                $this.adornerLayer = $null
                Write-Verbose "Removed insertion indicator adorner"
            } catch {
                Write-Verbose "Failed to remove adorner: $($_.Exception.Message)"
            }
        }
    }

    # Helper method to show insertion indicator at the specified position
    [void] ShowInsertionIndicator([object]$targetItem, [bool]$insertAbove) {
        # Remove existing adorner first
        $this.RemoveInsertionIndicator()

        try {
            # Get the adorner layer
            $adornerLayerType = "System.Windows.Documents.AdornerLayer" -as [type]
            $layer = $adornerLayerType::GetAdornerLayer($targetItem)
            if (-not $layer) {
                Write-Verbose "Could not get adorner layer for target item"
                return
            }

            # Create new insertion indicator adorner
            $adorner = New-Object InsertionIndicatorAdorner($targetItem, $insertAbove)
            $layer.Add($adorner)

            # Store references for cleanup
            $this.currentAdorner = $adorner
            $this.adornerLayer = $layer

            Write-Verbose "Showing insertion indicator (insertAbove: $insertAbove)"
        } catch {
            Write-Verbose "Failed to show insertion indicator: $($_.Exception.Message)"
        }
    }

    # Handle drag start for ListBox items
    [void] HandleListBoxPreviewMouseLeftButtonDown([object]$sender, [object]$e) {
        $this.dragStartPoint = $e.GetPosition($null)
        $this.draggedItem = $null

        # Find the ListBoxItem that was clicked
        $visualTreeHelperType = "System.Windows.Media.VisualTreeHelper" -as [type]
        $element = $e.OriginalSource
        while ($element -and $element.GetType().FullName -ne 'System.Windows.Controls.ListBoxItem') {
            $element = $visualTreeHelperType::GetParent($element)
        }

        if ($element) {
            $this.draggedItem = $element
        }
    }

    # Handle mouse move to initiate drag operation
    [void] HandleListBoxMouseMove([object]$sender, [object]$e) {
        if ($null -eq $this.dragStartPoint -or $null -eq $this.draggedItem) {
            return
        }

        # Check if mouse moved beyond threshold
        $mousePosition = $e.GetPosition($null)
        $diff = $this.dragStartPoint - $mousePosition

        $dragThreshold = 5
        if ([Math]::Abs($diff.X) -gt $dragThreshold -or [Math]::Abs($diff.Y) -gt $dragThreshold) {
            try {
                # Start drag operation
                $listBox = $sender
                $draggedData = $this.draggedItem.Content

                # Validate dragged data
                if ([string]::IsNullOrEmpty($draggedData)) {
                    Write-Verbose "Dragged item has no content, aborting drag"
                    $this.dragStartPoint = $null
                    $this.draggedItem = $null
                    return
                }

                Write-Verbose "Starting drag operation for item: $draggedData"

                $dragDropType = "System.Windows.DragDrop" -as [type]
                $dragDropEffectsType = "System.Windows.DragDropEffects" -as [type]

                $dragDropType::DoDragDrop(
                    $this.draggedItem,
                    $draggedData,
                    $dragDropEffectsType::Move
                )
            } catch {
                Write-Verbose "Failed to start drag operation: $($_.Exception.Message)"
            } finally {
                $this.dragStartPoint = $null
                $this.draggedItem = $null
            }
        }
    }

    # Handle DragOver event for GamesList
    [void] HandleGamesListDragOver([object]$sender, [object]$e) {
        $dragDropEffectsType = "System.Windows.DragDropEffects" -as [type]

        try {
            # Check if we have valid drag data
            $dragData = $e.Data.GetData([string])
            if (-not $dragData) {
                $e.Effects = $dragDropEffectsType::None
                $this.RemoveInsertionIndicator()
                return
            }

            # Get the target item under mouse
            $mousePosition = $e.GetPosition($sender)
            $targetItem = $this.GetListBoxItemUnderMouse($sender, $mousePosition)

            if ($targetItem) {
                # Determine if we should insert above or below
                $itemPosition = $e.GetPosition($targetItem)
                $itemHeight = $targetItem.ActualHeight
                $insertAbove = $itemPosition.Y -lt ($itemHeight / 2)

                # Show insertion indicator
                $this.ShowInsertionIndicator($targetItem, $insertAbove)

                $e.Effects = $dragDropEffectsType::Move
            } else {
                # No target item, allow drop at the end
                $this.RemoveInsertionIndicator()
                $e.Effects = $dragDropEffectsType::Move
            }

            $e.Handled = $true
        } catch {
            Write-Verbose "Failed to handle DragOver for games list: $($_.Exception.Message)"
            $e.Effects = $dragDropEffectsType::None
        }
    }

    # Handle DragLeave event for GamesList
    [void] HandleGamesListDragLeave([object]$sender, [object]$e) {
        $this.RemoveInsertionIndicator()
    }

    # Handle drop event for GamesList
    [void] HandleGamesListDrop([object]$sender, [object]$e) {
        # Remove insertion indicator
        $this.RemoveInsertionIndicator()

        try {
            $dropData = $e.Data.GetData([string])
            if (-not $dropData) {
                return
            }

            Write-Verbose "Drop event for game: $dropData"

            # Ensure games order exists
            if (-not $this.stateManager.ConfigData.games._order) {
                $this.stateManager.InitializeGameOrder()
            }

            $currentOrder = $this.stateManager.ConfigData.games._order
            $sourceIndex = $currentOrder.IndexOf($dropData)

            if ($sourceIndex -eq -1) {
                Write-Warning "Dropped game not found in order array"
                return
            }

            # Get the target position
            $mousePosition = $e.GetPosition($sender)
            $targetItem = $this.GetListBoxItemUnderMouse($sender, $mousePosition)

            $targetIndex = if ($targetItem) {
                $targetContent = $targetItem.Content
                $baseIndex = $currentOrder.IndexOf($targetContent)

                # Determine if we should insert above or below
                $itemPosition = $e.GetPosition($targetItem)
                $itemHeight = $targetItem.ActualHeight
                $insertAbove = $itemPosition.Y -lt ($itemHeight / 2)

                if ($insertAbove) {
                    $baseIndex
                } else {
                    $baseIndex + 1
                }
            } else {
                # Dropped outside of items, place at end (after last item)
                $currentOrder.Count
            }

            if ($targetIndex -eq -1) {
                # If target item not found in order, place at end
                $targetIndex = $currentOrder.Count
            }

            Write-Verbose "Reordering game from index $sourceIndex to $targetIndex"

            # Reorder the items
            $newOrder = $this.ReorderItems($currentOrder, $sourceIndex, $targetIndex)

            # Update the configuration
            $this.stateManager.ConfigData.games._order = $newOrder

            # Mark as modified
            $this.stateManager.SetModified()

            # Refresh the games list
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

            # Restore selection
            $gamesList = $script:Window.FindName("GamesList")
            for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
                if ($gamesList.Items[$i] -eq $dropData) {
                    $gamesList.SelectedIndex = $i
                    break
                }
            }

            $e.Handled = $true
        } catch {
            Write-Warning "Failed to handle drop for games list: $($_.Exception.Message)"
        }
    }

    # Handle DragOver event for ManagedAppsList
    [void] HandleManagedAppsListDragOver([object]$sender, [object]$e) {
        $dragDropEffectsType = "System.Windows.DragDropEffects" -as [type]

        try {
            # Check if we have valid drag data
            $dragData = $e.Data.GetData([string])
            if (-not $dragData) {
                $e.Effects = $dragDropEffectsType::None
                $this.RemoveInsertionIndicator()
                return
            }

            # Get the target item under mouse
            $mousePosition = $e.GetPosition($sender)
            $targetItem = $this.GetListBoxItemUnderMouse($sender, $mousePosition)

            if ($targetItem) {
                # Determine if we should insert above or below
                $itemPosition = $e.GetPosition($targetItem)
                $itemHeight = $targetItem.ActualHeight
                $insertAbove = $itemPosition.Y -lt ($itemHeight / 2)

                # Show insertion indicator
                $this.ShowInsertionIndicator($targetItem, $insertAbove)

                $e.Effects = $dragDropEffectsType::Move
            } else {
                # No target item, allow drop at the end
                $this.RemoveInsertionIndicator()
                $e.Effects = $dragDropEffectsType::Move
            }

            $e.Handled = $true
        } catch {
            Write-Verbose "Failed to handle DragOver for managed apps list: $($_.Exception.Message)"
            $e.Effects = $dragDropEffectsType::None
        }
    }

    # Handle DragLeave event for ManagedAppsList
    [void] HandleManagedAppsListDragLeave([object]$sender, [object]$e) {
        $this.RemoveInsertionIndicator()
    }

    # Handle drop event for ManagedAppsList
    [void] HandleManagedAppsListDrop([object]$sender, [object]$e) {
        # Remove insertion indicator
        $this.RemoveInsertionIndicator()

        try {
            $dropData = $e.Data.GetData([string])
            if (-not $dropData) {
                return
            }

            Write-Verbose "Drop event for app: $dropData"

            # Ensure apps order exists
            if (-not $this.stateManager.ConfigData.managedApps._order) {
                $this.stateManager.InitializeAppOrder()
            }

            $currentOrder = $this.stateManager.ConfigData.managedApps._order
            $sourceIndex = $currentOrder.IndexOf($dropData)

            if ($sourceIndex -eq -1) {
                Write-Warning "Dropped app not found in order array"
                return
            }

            # Get the target position
            $mousePosition = $e.GetPosition($sender)
            $targetItem = $this.GetListBoxItemUnderMouse($sender, $mousePosition)

            $targetIndex = if ($targetItem) {
                $targetContent = $targetItem.Content
                $baseIndex = $currentOrder.IndexOf($targetContent)

                if ($baseIndex -eq -1) {
                    # If target item not found in order, place at end of list
                    $currentOrder.Count
                } else {
                    # Determine if we should insert above or below
                    $itemPosition = $e.GetPosition($targetItem)
                    $itemHeight = $targetItem.ActualHeight
                    $insertAbove = $itemPosition.Y -lt ($itemHeight / 2)

                    if ($insertAbove) {
                        $baseIndex
                    } else {
                        $baseIndex + 1
                    }
                }
            } else {
                # Dropped outside of items, place at end of list
                $currentOrder.Count
            }

            Write-Verbose "Reordering app from index $sourceIndex to $targetIndex"

            # Reorder the items
            $newOrder = $this.ReorderItems($currentOrder, $sourceIndex, $targetIndex)

            # Update the configuration
            $this.stateManager.ConfigData.managedApps._order = $newOrder

            # Mark as modified
            $this.stateManager.SetModified()

            # Refresh the apps list
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)

            # Restore selection
            $managedAppsList = $script:Window.FindName("ManagedAppsList")
            for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
                if ($managedAppsList.Items[$i] -eq $dropData) {
                    $managedAppsList.SelectedIndex = $i
                    break
                }
            }

            $e.Handled = $true
        } catch {
            Write-Warning "Failed to handle drop for managed apps list: $($_.Exception.Message)"
        }
    }

    # Helper method to get the Border item (game card) under the mouse in ItemsControl
    [object] GetItemsControlBorderUnderMouse([object]$itemsControl, [object]$position) {
        try {
            $visualTreeHelperType = "System.Windows.Media.VisualTreeHelper" -as [type]

            $hitTestResult = $visualTreeHelperType::HitTest($itemsControl, $position)
            if ($hitTestResult) {
                $element = $hitTestResult.VisualHit
                # Walk up the visual tree to find a Border that is a direct child of ItemsControl
                $borderType = "System.Windows.Controls.Border" -as [type]
                while ($element -and $element -ne $itemsControl) {
                    if ($element.GetType().FullName -eq $borderType.FullName) {
                        # Walk up to find if we're inside the ItemsControl
                        $current = $element
                        while ($current -and $current -ne $itemsControl) {
                            $current = $visualTreeHelperType::GetParent($current)
                        }
                        if ($current -eq $itemsControl) {
                            # This border is inside our ItemsControl
                            # Check if it's in the Items collection
                            foreach ($item in $itemsControl.Items) {
                                if ($item -eq $element) {
                                    return $element
                                }
                            }
                        }
                    }
                    $element = $visualTreeHelperType::GetParent($element)
                }
            }
        } catch {
            Write-Verbose "Failed to get Border under mouse: $($_.Exception.Message)"
        }
        return $null
    }

    # Helper method to extract game ID from a Border element
    [string] GetGameIdFromBorder([object]$border) {
        try {
            # The border contains a Grid, which contains an info panel and a launch button
            # The launch button has a Tag with GameId
            if ($border -and $border.Child) {
                $grid = $border.Child
                $buttonType = "System.Windows.Controls.Button" -as [type]
                foreach ($child in $grid.Children) {
                    if ($child.GetType().FullName -eq $buttonType.FullName -and $child.Tag) {
                        if ($child.Tag.GameId) {
                            return $child.Tag.GameId
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "Failed to extract GameId from Border: $($_.Exception.Message)"
        }
        return $null
    }

    # Handle drag start for GameLauncherList items
    [void] HandleGameLauncherPreviewMouseLeftButtonDown([object]$sender, [object]$e) {
        $this.dragStartPoint = $e.GetPosition($null)
        $this.draggedItem = $null

        # Find the Border (game card) that was clicked
        $visualTreeHelperType = "System.Windows.Media.VisualTreeHelper" -as [type]
        $borderType = "System.Windows.Controls.Border" -as [type]
        $element = $e.OriginalSource

        # Walk up to find a Border element
        while ($element -and $element.GetType().FullName -ne $borderType.FullName) {
            $element = $visualTreeHelperType::GetParent($element)
        }

        # Verify this border is a game card in the ItemsControl
        if ($element) {
            $itemsControl = $sender
            foreach ($item in $itemsControl.Items) {
                if ($item -eq $element) {
                    $this.draggedItem = $element
                    Write-Verbose "GameLauncher drag start captured for border"
                    break
                }
            }
        }
    }

    # Handle mouse move to initiate drag operation for GameLauncherList
    [void] HandleGameLauncherMouseMove([object]$sender, [object]$e) {
        if ($null -eq $this.dragStartPoint -or $null -eq $this.draggedItem) {
            return
        }

        # Check if mouse moved beyond threshold
        $mousePosition = $e.GetPosition($null)
        $diff = $this.dragStartPoint - $mousePosition

        $dragThreshold = 5
        if ([Math]::Abs($diff.X) -gt $dragThreshold -or [Math]::Abs($diff.Y) -gt $dragThreshold) {
            try {
                # Extract game ID from the dragged border
                $gameId = $this.GetGameIdFromBorder($this.draggedItem)

                # Validate dragged data
                if ([string]::IsNullOrEmpty($gameId)) {
                    Write-Verbose "Dragged game card has no GameId, aborting drag"
                    $this.dragStartPoint = $null
                    $this.draggedItem = $null
                    return
                }

                Write-Verbose "Starting drag operation for game launcher item: $gameId"

                $dragDropType = "System.Windows.DragDrop" -as [type]
                $dragDropEffectsType = "System.Windows.DragDropEffects" -as [type]

                $dragDropType::DoDragDrop(
                    $this.draggedItem,
                    $gameId,
                    $dragDropEffectsType::Move
                )
            } catch {
                Write-Verbose "Failed to start drag operation for game launcher: $($_.Exception.Message)"
            } finally {
                $this.dragStartPoint = $null
                $this.draggedItem = $null
            }
        }
    }

    # Handle DragOver event for GameLauncherList
    [void] HandleGameLauncherDragOver([object]$sender, [object]$e) {
        $dragDropEffectsType = "System.Windows.DragDropEffects" -as [type]

        try {
            # Check if we have valid drag data
            $dragData = $e.Data.GetData([string])
            if (-not $dragData) {
                $e.Effects = $dragDropEffectsType::None
                $this.RemoveInsertionIndicator()
                return
            }

            # Get the target item under mouse
            $mousePosition = $e.GetPosition($sender)
            $targetBorder = $this.GetItemsControlBorderUnderMouse($sender, $mousePosition)

            if ($targetBorder) {
                # Determine if we should insert above or below
                $itemPosition = $e.GetPosition($targetBorder)
                $itemHeight = $targetBorder.ActualHeight
                $insertAbove = $itemPosition.Y -lt ($itemHeight / 2)

                # Show insertion indicator
                $this.ShowInsertionIndicator($targetBorder, $insertAbove)

                $e.Effects = $dragDropEffectsType::Move
            } else {
                # No target item, allow drop at the end
                $this.RemoveInsertionIndicator()
                $e.Effects = $dragDropEffectsType::Move
            }

            $e.Handled = $true
        } catch {
            Write-Verbose "Failed to handle DragOver for game launcher: $($_.Exception.Message)"
            $e.Effects = $dragDropEffectsType::None
        }
    }

    # Handle DragLeave event for GameLauncherList
    [void] HandleGameLauncherDragLeave([object]$sender, [object]$e) {
        $this.RemoveInsertionIndicator()
    }

    # Handle drop event for GameLauncherList
    [void] HandleGameLauncherDrop([object]$sender, [object]$e) {
        # Remove insertion indicator
        $this.RemoveInsertionIndicator()

        try {
            $dropData = $e.Data.GetData([string])
            if (-not $dropData) {
                return
            }

            Write-Verbose "Drop event for game launcher: $dropData"

            # Ensure games order exists
            if (-not $this.stateManager.ConfigData.games._order) {
                $this.stateManager.InitializeGameOrder()
            }

            $currentOrder = $this.stateManager.ConfigData.games._order
            $sourceIndex = $currentOrder.IndexOf($dropData)

            if ($sourceIndex -eq -1) {
                Write-Warning "Dropped game not found in order array"
                return
            }

            # Get the target position
            $mousePosition = $e.GetPosition($sender)
            $targetBorder = $this.GetItemsControlBorderUnderMouse($sender, $mousePosition)

            $targetIndex = if ($targetBorder) {
                $targetGameId = $this.GetGameIdFromBorder($targetBorder)
                if ($targetGameId) {
                    $baseIndex = $currentOrder.IndexOf($targetGameId)

                    # Determine if we should insert above or below
                    $itemPosition = $e.GetPosition($targetBorder)
                    $itemHeight = $targetBorder.ActualHeight
                    $insertAbove = $itemPosition.Y -lt ($itemHeight / 2)

                    if ($insertAbove) {
                        $baseIndex
                    } else {
                        $baseIndex + 1
                    }
                } else {
                    $currentOrder.Count
                }
            } else {
                # Dropped outside of items, place at end
                $currentOrder.Count
            }

            if ($targetIndex -eq -1) {
                # If target item not found in order, place at end
                $targetIndex = $currentOrder.Count
            }

            Write-Verbose "Reordering game in launcher from index $sourceIndex to $targetIndex"

            # Reorder the items
            $newOrder = $this.ReorderItems($currentOrder, $sourceIndex, $targetIndex)

            # Update the configuration
            $this.stateManager.ConfigData.games._order = $newOrder

            # Mark as modified
            $this.stateManager.SetModified()

            # Refresh the game launcher list to reflect new order
            $this.uiManager.UpdateGameLauncherList($this.stateManager.ConfigData)

            # Also refresh the games list tab to keep it in sync
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

            $e.Handled = $true
        } catch {
            Write-Warning "Failed to handle drop for game launcher: $($_.Exception.Message)"
        }
    }

    # Handle platform selection changed
    [void] HandlePlatformSelectionChanged() {
        $platformCombo = $script:Window.FindName("PlatformComboBox")
        if ($platformCombo.SelectedItem -and $platformCombo.SelectedItem.Tag) {
            $selectedPlatform = $platformCombo.SelectedItem.Tag
            Update-PlatformFields -Platform $selectedPlatform
        }
    }

    # Handle game selection changed
    [void] HandleGameSelectionChanged() {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if ($selectedGame) {
            $script:CurrentGameId = $selectedGame
            $gameData = $this.stateManager.ConfigData.games.$selectedGame

            Write-Verbose "HandleGameSelectionChanged: Selected game = $selectedGame"

            if ($gameData) {
                Write-Verbose "HandleGameSelectionChanged: Game data found for $selectedGame"
                Write-Verbose "  - name: $($gameData.name)"
                Write-Verbose "  - platform: $($gameData.platform)"
                Write-Verbose "  - steamAppId: $($gameData.steamAppId)"
                Write-Verbose "  - executablePath: $($gameData.executablePath)"

                # Load game details into form
                $gameNameTextBox = $script:Window.FindName("GameNameTextBox")
                if ($gameNameTextBox) {
                    # Check for both 'name' and 'displayName' for compatibility
                    $displayName = if ($gameData.name) { $gameData.name } elseif ($gameData.displayName) { $gameData.displayName } else { "" }
                    $gameNameTextBox.Text = $displayName
                    Write-Verbose "  Set GameNameTextBox: $displayName"
                }

                $gameIdTextBox = $script:Window.FindName("GameIdTextBox")
                if ($gameIdTextBox) {
                    # The game ID is the dictionary key, never use appId property (legacy bug)
                    $gameIdTextBox.Text = $selectedGame
                    Write-Verbose "  Set GameIdTextBox: $selectedGame"
                }

                $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
                if ($steamAppIdTextBox) {
                    $steamAppIdTextBox.Text = if ($gameData.steamAppId) { $gameData.steamAppId } else { "" }
                    Write-Verbose "  Set SteamAppIdTextBox: $($gameData.steamAppId)"
                }

                $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
                if ($epicGameIdTextBox) {
                    $epicGameIdTextBox.Text = if ($gameData.epicGameId) { $gameData.epicGameId } else { "" }
                    Write-Verbose "  Set EpicGameIdTextBox: $($gameData.epicGameId)"
                }

                $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
                if ($riotGameIdTextBox) {
                    $riotGameIdTextBox.Text = if ($gameData.riotGameId) { $gameData.riotGameId } else { "" }
                    Write-Verbose "  Set RiotGameIdTextBox: $($gameData.riotGameId)"
                }

                $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
                if ($executablePathTextBox) {
                    $executablePathTextBox.Text = if ($gameData.executablePath) { $gameData.executablePath } else { "" }
                    Write-Verbose "  Set ExecutablePathTextBox: $($gameData.executablePath)"
                }

                # Set process name
                $processNameTextBox = $script:Window.FindName("ProcessNameTextBox")
                if ($processNameTextBox) {
                    $processNameTextBox.Text = if ($gameData.processName) { $gameData.processName } else { "" }
                    Write-Verbose "  Set ProcessNameTextBox: $($gameData.processName)"
                }

                # Load comment
                $gameCommentTextBox = $script:Window.FindName("GameCommentTextBox")
                if ($gameCommentTextBox) {
                    $gameCommentTextBox.Text = if ($gameData._comment) { $gameData._comment } else { "" }
                    Write-Verbose "  Set GameCommentTextBox: $($gameData._comment)"
                }

                # Set platform
                $platformCombo = $script:Window.FindName("PlatformComboBox")
                # Normalize platform value: "direct" is an alias for "standalone"
                $platform = if ($gameData.platform) {
                    if ($gameData.platform -eq "direct") { "standalone" } else { $gameData.platform }
                } else {
                    "standalone"
                }

                Write-Verbose "  Platform: $platform (original: $($gameData.platform))"

                $platformFound = $false
                for ($i = 0; $i -lt $platformCombo.Items.Count; $i++) {
                    if ($platformCombo.Items[$i].Tag -eq $platform) {
                        $platformCombo.SelectedIndex = $i
                        $platformFound = $true
                        Write-Verbose "  Set PlatformComboBox to index $i ($platform)"
                        break
                    }
                }

                if (-not $platformFound) {
                    Write-Warning "Platform '$platform' not found in ComboBox, defaulting to standalone (index 0)"
                    $platformCombo.SelectedIndex = 0
                }

                # Update platform-specific fields
                Update-PlatformFields -Platform $platform

                # Update available actions for this game
                # The game ID is the dictionary key, never use appId property (legacy bug)
                $executablePath = if ($gameData.executablePath) { $gameData.executablePath } else { "" }
                Update-ActionComboBoxes -AppId $selectedGame -ExecutablePath $executablePath

                # Load managed apps settings
                $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
                $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

                $gameStartAction = if ($gameData.managedApps.gameStartAction) { $gameData.managedApps.gameStartAction } else { "none" }
                $gameEndAction = if ($gameData.managedApps.gameEndAction) { $gameData.managedApps.gameEndAction } else { "none" }
                $this.SetComboBoxSelectionByTag($gameStartActionCombo, $gameStartAction)
                $this.SetComboBoxSelectionByTag($gameEndActionCombo, $gameEndAction)

                # Load termination settings
                $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
                $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")

                if ($terminationMethodCombo) {
                    $terminationMethod = if ($gameData.managedApps.terminationMethod) { $gameData.managedApps.terminationMethod } else { "auto" }
                    # Clear saved value and set the actual value from config
                    $script:SavedTerminationMethod = $terminationMethod
                    $this.SetComboBoxSelectionByTag($terminationMethodCombo, $terminationMethod)
                }

                if ($gracefulTimeoutTextBox) {
                    $gracefulTimeoutTextBox.Text = if ($gameData.managedApps.gracefulTimeout) { $gameData.managedApps.gracefulTimeout.ToString() } else { "5" }
                }

                # Update termination settings visibility
                Update-TerminationSettingsVisibility

                # Update termination method enabled state based on selected actions
                $this.UpdateTerminationMethodState()

                # Update apps to manage panel with current game's app list
                Update-AppsToManagePanel

                $useOBSCheck = $script:Window.FindName("UseOBSIntegrationCheckBox")
                if ($useOBSCheck) {
                    $useOBSCheck.IsChecked = ($gameData.integrations -and $gameData.integrations.useOBS) -or ($gameData.appsToManage -contains "obs")
                }

                $useDiscordCheck = $script:Window.FindName("UseDiscordIntegrationCheckBox")
                if ($useDiscordCheck) {
                    $useDiscordCheck.IsChecked = ($gameData.integrations -and $gameData.integrations.useDiscord) -or ($gameData.appsToManage -contains "discord")
                }

                $useVTubeCheck = $script:Window.FindName("UseVTubeStudioIntegrationCheckBox")
                if ($useVTubeCheck) {
                    $useVTubeCheck.IsChecked = ($gameData.integrations -and $gameData.integrations.useVTubeStudio) -or ($gameData.appsToManage -contains "vtubeStudio")
                }

                # Update move button states (removed - using drag and drop)
                # Update-MoveButtonStates

                Write-Verbose "Loaded game data for: $selectedGame"
            }
        } else {
            # No game selected, clear the form
            $script:CurrentGameId = ""

            $gameNameTextBox = $script:Window.FindName("GameNameTextBox")
            if ($gameNameTextBox) { $gameNameTextBox.Text = "" }

            $gameIdTextBox = $script:Window.FindName("GameIdTextBox")
            if ($gameIdTextBox) { $gameIdTextBox.Text = "" }

            $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
            if ($steamAppIdTextBox) { $steamAppIdTextBox.Text = "" }

            $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
            if ($epicGameIdTextBox) { $epicGameIdTextBox.Text = "" }

            $riotGameIdTextBox = $script:Window.FindName("RiotGameIdTextBox")
            if ($riotGameIdTextBox) { $riotGameIdTextBox.Text = "" }

            $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
            if ($executablePathTextBox) { $executablePathTextBox.Text = "" }

            # Reset process name
            $processNameTextBox = $script:Window.FindName("ProcessNameTextBox")
            if ($processNameTextBox) { $processNameTextBox.Text = "" }

            # Reset platform to standalone
            $platformCombo = $script:Window.FindName("PlatformComboBox")
            if ($platformCombo) {
                $platformCombo.SelectedIndex = 0
                Update-PlatformFields -Platform "standalone"
            }

            # Reset action combos
            $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
            $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
            if ($gameStartActionCombo) { $this.SetComboBoxSelectionByTag($gameStartActionCombo, "none") }
            if ($gameEndActionCombo) { $this.SetComboBoxSelectionByTag($gameEndActionCombo, "none") }

            # Reset termination settings
            $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
            $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
            if ($terminationMethodCombo) { $this.SetComboBoxSelectionByTag($terminationMethodCombo, "auto") }
            if ($gracefulTimeoutTextBox) { $gracefulTimeoutTextBox.Text = "5" }

            # Update termination settings visibility
            Update-TerminationSettingsVisibility

            # Buttons removed - using drag and drop and context menus
        }
    }

    # Handle managed app selection changed
    [void] HandleAppSelectionChanged() {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if ($selectedApp) {
            $script:CurrentAppId = $selectedApp
            $appData = $this.stateManager.ConfigData.managedApps.$selectedApp

            Write-Verbose "HandleAppSelectionChanged: Selected app = $selectedApp"

            if ($appData) {
                Write-Verbose "HandleAppSelectionChanged: App data found for $selectedApp"
                Write-Verbose "  - displayName: $($appData.displayName)"
                Write-Verbose "  - processName: $($appData.processName)"
                Write-Verbose "  - path: $($appData.path)"
                Write-Verbose "  - gameStartAction: $($appData.gameStartAction)"
                Write-Verbose "  - gameEndAction: $($appData.gameEndAction)"
                Write-Verbose "  - terminationMethod: $($appData.terminationMethod)"
                Write-Verbose "  - gracefulTimeoutMs: $($appData.gracefulTimeoutMs)"

                # Load app details into form
                $appIdTextBox = $script:Window.FindName("AppIdTextBox")
                if ($appIdTextBox) {
                    # Display the actual app ID (config key), not the display name
                    $appIdTextBox.Text = $selectedApp
                }

                # Load display name
                $appDisplayNameTextBox = $script:Window.FindName("AppDisplayNameTextBox")
                if ($appDisplayNameTextBox) {
                    $appDisplayNameTextBox.Text = if ($appData.displayName) { $appData.displayName } else { "" }
                    Write-Verbose "  Set AppDisplayNameTextBox: $($appData.displayName)"
                }

                # Load comment
                $appCommentTextBox = $script:Window.FindName("AppCommentTextBox")
                if ($appCommentTextBox) {
                    $appCommentTextBox.Text = if ($appData._comment) { $appData._comment } else { "" }
                    Write-Verbose "  Set AppCommentTextBox: $($appData._comment)"
                }

                $appProcessNameTextBox = $script:Window.FindName("AppProcessNameTextBox")
                if ($appProcessNameTextBox) {
                    # Check for both processName (singular) and processNames (plural) for compatibility
                    $processNameValue = if ($appData.processNames) {
                        if ($appData.processNames -is [array]) {
                            $appData.processNames -join "|"
                        } else {
                            $appData.processNames
                        }
                    } elseif ($appData.processName) {
                        $appData.processName
                    } else {
                        ""
                    }
                    $appProcessNameTextBox.Text = $processNameValue
                }

                # Set ComboBox selections using helper function to find matching ComboBoxItem by Tag
                # NOTE: Managed Apps tab uses same ComboBox controls as Game tab
                $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
                $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")

                if ($gameStartActionCombo) {
                    # Check for both startAction and gameStartAction for compatibility
                    $appStartAction = if ($appData.startAction) {
                        $appData.startAction
                    } elseif ($appData.gameStartAction) {
                        $appData.gameStartAction
                    } else {
                        "start-process"
                    }
                    $this.SetComboBoxSelectionByTag($gameStartActionCombo, $appStartAction)
                }

                if ($gameEndActionCombo) {
                    # Check for both endAction and gameEndAction for compatibility
                    $appEndAction = if ($appData.endAction) {
                        $appData.endAction
                    } elseif ($appData.gameEndAction) {
                        $appData.gameEndAction
                    } else {
                        "stop-process"
                    }
                    $this.SetComboBoxSelectionByTag($gameEndActionCombo, $appEndAction)
                }

                $appPathTextBox = $script:Window.FindName("AppPathTextBox")
                if ($appPathTextBox) {
                    # Check for both executablePath and path for compatibility
                    $pathValue = if ($appData.executablePath) {
                        $appData.executablePath
                    } elseif ($appData.path) {
                        $appData.path
                    } else {
                        ""
                    }
                    $appPathTextBox.Text = $pathValue
                }

                # Load working directory
                $workingDirectoryTextBox = $script:Window.FindName("WorkingDirectoryTextBox")
                if ($workingDirectoryTextBox) {
                    $workingDirectoryTextBox.Text = if ($appData.workingDirectory) { $appData.workingDirectory } else { "" }
                }

                # Load arguments
                $appArgumentsTextBox = $script:Window.FindName("AppArgumentsTextBox")
                if ($appArgumentsTextBox) {
                    $appArgumentsTextBox.Text = if ($appData.arguments) { $appData.arguments } else { "" }
                }

                # Load termination settings
                $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
                if ($terminationMethodCombo) {
                    $appTerminationMethod = if ($appData.terminationMethod) { $appData.terminationMethod } else { "auto" }
                    # Clear saved value and set the actual value from config
                    $script:SavedTerminationMethod = $appTerminationMethod
                    $this.SetComboBoxSelectionByTag($terminationMethodCombo, $appTerminationMethod)
                }

                $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
                if ($gracefulTimeoutTextBox) {
                    # Check for both gracefulTimeout and gracefulTimeoutMs for compatibility
                    $timeoutValue = if ($appData.gracefulTimeout) {
                        $appData.gracefulTimeout.ToString()
                    } elseif ($appData.gracefulTimeoutMs) {
                        # Convert milliseconds to seconds for display
                        ([int]($appData.gracefulTimeoutMs / 1000)).ToString()
                    } else {
                        "5"
                    }
                    $gracefulTimeoutTextBox.Text = $timeoutValue
                }

                # Buttons removed - using drag and drop and context menus

                # Update termination method enabled state based on selected actions
                $this.UpdateTerminationMethodState()

                Write-Verbose "Loaded app data for: $selectedApp"
            }
        } else {
            # No app selected, clear the form
            $script:CurrentAppId = ""

            $appIdTextBox = $script:Window.FindName("AppIdTextBox")
            if ($appIdTextBox) { $appIdTextBox.Text = "" }

            $appProcessNameTextBox = $script:Window.FindName("AppProcessNameTextBox")
            if ($appProcessNameTextBox) { $appProcessNameTextBox.Text = "" }

            $gameStartActionCombo = $script:Window.FindName("GameStartActionCombo")
            if ($gameStartActionCombo) { $this.SetComboBoxSelectionByTag($gameStartActionCombo, "start-process") }

            $gameEndActionCombo = $script:Window.FindName("GameEndActionCombo")
            if ($gameEndActionCombo) { $this.SetComboBoxSelectionByTag($gameEndActionCombo, "stop-process") }

            $appPathTextBox = $script:Window.FindName("AppPathTextBox")
            if ($appPathTextBox) { $appPathTextBox.Text = "" }

            $terminationMethodCombo = $script:Window.FindName("TerminationMethodCombo")
            if ($terminationMethodCombo) { $this.SetComboBoxSelectionByTag($terminationMethodCombo, "auto") }

            $gracefulTimeoutTextBox = $script:Window.FindName("GracefulTimeoutTextBox")
            if ($gracefulTimeoutTextBox) { $gracefulTimeoutTextBox.Text = "5" }

            # Buttons removed - using drag and drop and context menus
        }
    }

    # Handle add game
    [void] HandleAddGame() {
        $newGameId = New-UniqueConfigId -Prefix "game-" -Collection $this.stateManager.ConfigData.games

        # Create new game with default values
        $newGame = @{
            displayName = "New Game"
            platform = "standalone"
            managedApps = @{
                gameStartAction = "none"
                gameEndAction = "none"
                terminationMethod = "auto"
                gracefulTimeout = 5
            }
        }

        # Add to configuration
        if (-not $this.stateManager.ConfigData.games) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "games" -NotePropertyValue @{}
        }
        $this.stateManager.ConfigData.games | Add-Member -NotePropertyName $newGameId -NotePropertyValue $newGame

        # Initialize/update games order
        $this.stateManager.InitializeGameOrder()

        # Refresh games list
        $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

        # Select the new game
        $gamesList = $script:Window.FindName("GamesList")
        for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
            if ($gamesList.Items[$i] -eq $newGameId) {
                $gamesList.SelectedIndex = $i
                break
            }
        }

        # Mark as modified
        $this.stateManager.SetModified()

        Write-Verbose "Added new game: $newGameId"
    }    # Handle duplicate game
    [void] HandleDuplicateGame() {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not (Test-DuplicateSource -SelectedItem $selectedGame -SourceData $this.stateManager.ConfigData.games.$selectedGame -ItemType "Game")) {
            return
        }

        try {
            # Generate unique ID for the duplicated game
            $newGameId = New-UniqueConfigId -Prefix "game-" -Collection $this.stateManager.ConfigData.games

            # Deep copy the selected game data
            $originalGameData = $this.stateManager.ConfigData.games.$selectedGame
            $duplicatedGameData = $originalGameData | ConvertTo-Json -Depth 10 | ConvertFrom-Json

            # Remove the appId property if it exists (it should never be on game objects)
            if ($duplicatedGameData.PSObject.Properties.Name -contains "appId") {
                $duplicatedGameData.PSObject.Properties.Remove("appId")
            }

            # Modify the display/name to indicate it's a copy (games historically use 'name')
            $originalDisplayName = if ($duplicatedGameData.displayName) { $duplicatedGameData.displayName } elseif ($duplicatedGameData.name) { $duplicatedGameData.name } else { $selectedGame }
            # Prefer setting the canonical 'name' property for games; use helper to safely add property
            Set-PropertyValue -Object $duplicatedGameData -PropertyName "name" -Value "$originalDisplayName (Copy)"

            # Add to configuration
            $this.stateManager.ConfigData.games | Add-Member -NotePropertyName $newGameId -NotePropertyValue $duplicatedGameData

            # Initialize/update games order
            $this.stateManager.InitializeGameOrder()

            # Refresh games list and apps to manage panel
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)
            Update-AppsToManagePanel

            # Select the new duplicated game
            $gamesList = $script:Window.FindName("GamesList")
            for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
                if ($gamesList.Items[$i] -eq $newGameId) {
                    $gamesList.SelectedIndex = $i
                    break
                }
            }



            Show-DuplicateResult -Success $true -ItemType "Game" -OriginalId $selectedGame -NewId $newGameId

        } catch {
            Write-Error "Failed to duplicate game: $_"
            Show-DuplicateResult -Success $false -ItemType "Game" -OriginalId $selectedGame
        }
    }

    # Handle delete game
    [void] HandleDeleteGame() {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not $selectedGame) {
            Show-SafeMessage -Key "noGameSelected" -MessageType "Warning"
            return
        }

        $gameDisplayName = if ($this.stateManager.ConfigData.games.$selectedGame.displayName) {
            $this.stateManager.ConfigData.games.$selectedGame.displayName
        } else {
            $selectedGame
        }

        $result = Show-SafeMessage -Key "confirmDeleteGame" -MessageType "Question" -Button "YesNo" -DefaultResult "No" -FormatArgs @($gameDisplayName)

        if ($result -eq "Yes") {
            # Remove from configuration
            $this.stateManager.ConfigData.games.PSObject.Properties.Remove($selectedGame)

            # Update games order
            if ($this.stateManager.ConfigData.games._order -and $selectedGame -in $this.stateManager.ConfigData.games._order) {
                $this.stateManager.ConfigData.games._order = $this.stateManager.ConfigData.games._order | Where-Object { $_ -ne $selectedGame }
            }

            # Refresh games list and apps to manage panel
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)
            Update-AppsToManagePanel

            Write-Verbose "Deleted game: $selectedGame"
        }
    }

    # Handle move game
    [void] HandleMoveGame([string]$Direction) {
        $gamesList = $script:Window.FindName("GamesList")
        $selectedGame = $gamesList.SelectedItem

        if (-not $selectedGame) {
            Show-SafeMessage -Key "noGameSelected" -MessageType "Warning"
            return
        }

        # Ensure games order exists
        if (-not $this.stateManager.ConfigData.games._order) {
            $this.stateManager.InitializeGameOrder()
        }

        $currentOrder = $this.stateManager.ConfigData.games._order
        $currentIndex = $currentOrder.IndexOf($selectedGame)

        if ($currentIndex -eq -1) {
            Write-Warning "Selected game not found in order array"
            return
        }

        $newIndex = $currentIndex
        switch ($Direction) {
            "Top" { $newIndex = 0 }
            "Up" { $newIndex = [Math]::Max(0, $currentIndex - 1) }
            "Down" { $newIndex = [Math]::Min($currentOrder.Count - 1, $currentIndex + 1) }
            "Bottom" { $newIndex = $currentOrder.Count - 1 }
        }

        # Only proceed if position actually changes
        if ($newIndex -ne $currentIndex) {
            # Use the shared reorder helper method
            $newOrder = $this.ReorderItems($currentOrder, $currentIndex, $newIndex)

            # Update the configuration
            $this.stateManager.ConfigData.games._order = $newOrder

            # Mark as modified
            $this.stateManager.SetModified()

            # Refresh the games list
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

            # Restore selection
            $gamesList = $script:Window.FindName("GamesList")
            for ($i = 0; $i -lt $gamesList.Items.Count; $i++) {
                if ($gamesList.Items[$i] -eq $selectedGame) {
                    $gamesList.SelectedIndex = $i
                    break
                }
            }

            Write-Verbose "Moved game '$selectedGame' $Direction (from index $currentIndex to $newIndex)"
        }
    }

    # Handle add app
    [void] HandleAddApp() {
        $newAppId = New-UniqueConfigId -Prefix "app-" -Collection $this.stateManager.ConfigData.managedApps

        # Create new app with default values
        $newApp = @{
            displayName = "New App"
            processNames = @("notepad.exe")
            startAction = "start-process"
            endAction = "stop-process"
            terminationMethod = "auto"
            gracefulTimeout = 5
        }

        # Add to configuration
        if (-not $this.stateManager.ConfigData.managedApps) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "managedApps" -NotePropertyValue @{}
        }
        $this.stateManager.ConfigData.managedApps | Add-Member -NotePropertyName $newAppId -NotePropertyValue $newApp

        # Initialize/update apps order
        $this.stateManager.InitializeAppOrder()

        # Refresh managed apps list and apps to manage panel
        $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)
        Update-AppsToManagePanel

        # Select the new app
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
            if ($managedAppsList.Items[$i] -eq $newAppId) {
                $managedAppsList.SelectedIndex = $i
                break
            }
        }

        # Mark as modified
        Set-ConfigModified

        $message = $this.uiManager.GetLocalizedMessage("appAdded")
        $this.uiManager.ShowNotification($message, "Success")
        Write-Verbose "Added new app: $newAppId"
    }

    # Handle duplicate app
    [void] HandleDuplicateApp() {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if (-not (Test-DuplicateSource -SelectedItem $selectedApp -SourceData $this.stateManager.ConfigData.managedApps.$selectedApp -ItemType "App")) {
            return
        }

        try {
            # Generate unique ID for the duplicated app
            $newAppId = New-UniqueConfigId -Prefix "app-" -Collection $this.stateManager.ConfigData.managedApps

            # Deep copy the selected app data
            $originalAppData = $this.stateManager.ConfigData.managedApps.$selectedApp
            $duplicatedAppData = $originalAppData | ConvertTo-Json -Depth 10 | ConvertFrom-Json

            # Modify the display name to indicate it's a copy (managed apps use 'displayName')
            $originalDisplayName = if ($duplicatedAppData.displayName) { $duplicatedAppData.displayName } elseif ($duplicatedAppData.name) { $duplicatedAppData.name } else { $selectedApp }
            Set-PropertyValue -Object $duplicatedAppData -PropertyName "displayName" -Value "$originalDisplayName (Copy)"

            # Add to configuration
            $this.stateManager.ConfigData.managedApps | Add-Member -NotePropertyName $newAppId -NotePropertyValue $duplicatedAppData

            # Initialize/update apps order
            $this.stateManager.InitializeAppOrder()

            # Refresh managed apps list and apps to manage panel
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)
            Update-AppsToManagePanel

            # Select the new duplicated app
            $managedAppsList = $script:Window.FindName("ManagedAppsList")
            for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
                if ($managedAppsList.Items[$i] -eq $newAppId) {
                    $managedAppsList.SelectedIndex = $i
                    break
                }
            }



            Show-DuplicateResult -Success $true -ItemType "App" -OriginalId $selectedApp -NewId $newAppId

        } catch {
            Write-Error "Failed to duplicate app: $_"
            Show-DuplicateResult -Success $false -ItemType "App" -OriginalId $selectedApp
        }
    }

    # Handle delete app
    [void] HandleDeleteApp() {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if (-not $selectedApp) {
            Show-SafeMessage -Key "noAppSelected" -MessageType "Warning"
            return
        }

        $appDisplayName = if ($this.stateManager.ConfigData.managedApps.$selectedApp.displayName) {
            $this.stateManager.ConfigData.managedApps.$selectedApp.displayName
        } else {
            $selectedApp
        }

        $result = Show-SafeMessage -Key "confirmDeleteApp" -MessageType "Question" -Button "YesNo" -DefaultResult "No" -FormatArgs @($appDisplayName)

        if ($result -eq "Yes") {
            # Remove from configuration
            $this.stateManager.ConfigData.managedApps.PSObject.Properties.Remove($selectedApp)

            # Update apps order
            if ($this.stateManager.ConfigData.managedApps._order -and $selectedApp -in $this.stateManager.ConfigData.managedApps._order) {
                $this.stateManager.ConfigData.managedApps._order = $this.stateManager.ConfigData.managedApps._order | Where-Object { $_ -ne $selectedApp }
            }

            # Refresh managed apps list and apps to manage panel
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)
            Update-AppsToManagePanel



            $message = $this.uiManager.GetLocalizedMessage("appDeleted")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "Deleted app: $selectedApp"
        }
    }

    # Handle move app
    [void] HandleMoveApp([string]$Direction) {
        $managedAppsList = $script:Window.FindName("ManagedAppsList")
        $selectedApp = $managedAppsList.SelectedItem

        if (-not $selectedApp) {
            Show-SafeMessage -Key "noAppSelected" -MessageType "Warning"
            return
        }

        # Ensure apps order exists
        if (-not $this.stateManager.ConfigData.managedApps._order) {
            $this.stateManager.InitializeAppOrder()
        }

        $currentOrder = $this.stateManager.ConfigData.managedApps._order
        $currentIndex = $currentOrder.IndexOf($selectedApp)

        if ($currentIndex -eq -1) {
            Write-Warning "Selected app not found in order array"
            return
        }

        $newIndex = $currentIndex
        switch ($Direction) {
            "Top" { $newIndex = 0 }
            "Up" { $newIndex = [Math]::Max(0, $currentIndex - 1) }
            "Down" { $newIndex = [Math]::Min($currentOrder.Count - 1, $currentIndex + 1) }
            "Bottom" { $newIndex = $currentOrder.Count - 1 }
        }

        # Only proceed if position actually changes
        if ($newIndex -ne $currentIndex) {
            # Use the shared reorder helper method
            $newOrder = $this.ReorderItems($currentOrder, $currentIndex, $newIndex)

            # Update the configuration
            $this.stateManager.ConfigData.managedApps._order = $newOrder

            # Mark as modified
            $this.stateManager.SetModified()

            # Refresh the managed apps list
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)

            # Restore selection
            $managedAppsList = $script:Window.FindName("ManagedAppsList")
            for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
                if ($managedAppsList.Items[$i] -eq $selectedApp) {
                    $managedAppsList.SelectedIndex = $i
                    break
                }
            }
            Write-Verbose "Moved app '$selectedApp' $Direction (from index $currentIndex to $newIndex)"
        }
    }

    # Handle save configuration
    [void] HandleSaveConfig() {
        try {
            # Determine which tab is currently active and save accordingly
            $mainTabControl = $script:Window.FindName("MainTabControl")
            $selectedTab = if ($mainTabControl) { $mainTabControl.SelectedItem } else { $null }

            if ($selectedTab) {
                switch ($selectedTab.Name) {
                    "GamesTab" {
                        Write-Verbose "Saving game settings from HandleSaveConfig"
                        Save-CurrentGameData
                    }
                    "ManagedAppsTab" {
                        Write-Verbose "Saving managed apps from HandleSaveConfig"
                        Save-CurrentAppData

                        # Save global apps to manage settings
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

                            # Store in current game's appsToManage if a game is selected
                            if ($script:CurrentGameId) {
                                $gameData = $this.stateManager.ConfigData.games.$script:CurrentGameId
                                if ($gameData) {
                                    if (-not $gameData.PSObject.Properties["appsToManage"]) {
                                        $gameData | Add-Member -NotePropertyName "appsToManage" -NotePropertyValue $appsToManage
                                    } else {
                                        $gameData.appsToManage = $appsToManage
                                    }
                                }
                            }
                        }
                    }
                    "GlobalSettingsTab" {
                        Write-Verbose "Saving global settings from HandleSaveConfig"
                        Save-GlobalSettingsData
                    }
                    default {
                        Write-Verbose "Unknown tab, no specific save action"
                    }
                }
            }

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            $message = $this.uiManager.GetLocalizedMessage("configSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "Configuration saved to: $script:ConfigPath"

        } catch {
            Write-Error "Failed to save configuration: $_"
            Show-SafeMessage -Key "configSaveFailed" -MessageType "Error"
        }
    }

    # Handle browse executable path (for Games tab)
    [void] HandleBrowseExecutablePath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("ExecutablePathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected game executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle browse app path (for Managed Apps tab)
    [void] HandleBrowseAppPath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("AppPathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected app executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle browse working directory (for Managed Apps tab)
    [void] HandleBrowseWorkingDirectory() {
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowserDialog.Description = $this.uiManager.GetLocalizedMessage("browseFolderButton")
        $folderBrowserDialog.ShowNewFolderButton = $true

        if ($folderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:Window.FindName("WorkingDirectoryTextBox").Text = $folderBrowserDialog.SelectedPath
            Write-Verbose "Selected working directory: $($folderBrowserDialog.SelectedPath)"
        }
    }

    # Handle browse OBS path
    [void] HandleBrowseOBSPath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("OBSPathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected OBS executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle browse Discord path
    [void] HandleBrowseDiscordPath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("DiscordPathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected Discord executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle browse VTube Studio path
    [void] HandleBrowseVTubeStudioPath() {
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
        $openFileDialog.Title = $this.uiManager.GetLocalizedMessage("selectExecutable")

        if ($openFileDialog.ShowDialog()) {
            $script:Window.FindName("VTubePathTextBox").Text = $openFileDialog.FileName
            Write-Verbose "Selected VTube Studio executable path: $($openFileDialog.FileName)"
        }
    }

    # Handle check update
    [void] HandleCheckUpdate() {
        try {
            Write-Verbose "[DEBUG] ConfigEditorEvents: Update check started"

            # Get current version - use global function reference
            $currentVersion = if ($global:GetProjectVersionFunc) {
                & $global:GetProjectVersionFunc -IncludePreRelease $true
            } else {
                Write-Verbose "[WARNING] ConfigEditorEvents: Get-ProjectVersion not available"
                "Unknown"
            }
            Write-Verbose "[INFO] ConfigEditorEvents: Current version - $currentVersion"

            # Check for updates - use global function reference
            if (-not $global:TestUpdateAvailableFunc) {
                Write-Verbose "[WARNING] ConfigEditorEvents: Update checker not available"
                $message = $this.uiManager.GetLocalizedMessage("updateCheckFailed")
                $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")
                ("System.Windows.MessageBox" -as [type])::Show($message, $title, "OK", "Warning")
                return
            }

            Write-Verbose "[INFO] ConfigEditorEvents: Checking for updates"
            $updateInfo = & $global:TestUpdateAvailableFunc

            if ($updateInfo) {
                Write-Verbose "[DEBUG] ConfigEditorEvents: Update info received"
                Write-Verbose "[DEBUG] ConfigEditorEvents: Update details - $($updateInfo | ConvertTo-Json -Depth 3)"

                if ($updateInfo.UpdateAvailable) {
                    # Show update available dialog
                    $message = $this.uiManager.GetLocalizedMessage("updateAvailable") -f $updateInfo.LatestVersion, $currentVersion
                    $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

                    $result = ("System.Windows.MessageBox" -as [type])::Show($message, $title, "YesNo", "Question")

                    if ("$result" -eq "Yes") {
                        # Open the release page
                        if ($updateInfo.ReleaseInfo -and $updateInfo.ReleaseInfo.HtmlUrl) {
                            Write-Verbose "[INFO] ConfigEditorEvents: Opening release page - $($updateInfo.ReleaseInfo.HtmlUrl)"
                            Start-Process $updateInfo.ReleaseInfo.HtmlUrl
                        } else {
                            Write-Verbose "[WARNING] ConfigEditorEvents: No release URL provided in update info"
                        }
                    }
                } else {
                    # No update available
                    $message = $this.uiManager.GetLocalizedMessage("noUpdateAvailable") -f $currentVersion
                    $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

                    ("System.Windows.MessageBox" -as [type])::Show($message, $title, "OK", "Information")
                }
            } else {
                Write-Verbose "[WARNING] ConfigEditorEvents: No update info received"
                # Handle case where update check failed
                $message = $this.uiManager.GetLocalizedMessage("updateCheckFailed")
                $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

                ("System.Windows.MessageBox" -as [type])::Show($message, $title, "OK", "Warning")
            }

            Write-Verbose "[OK] ConfigEditorEvents: Update check completed"

        } catch {
            Write-Verbose "[ERROR] ConfigEditorEvents: Update check failed - $($_.Exception.Message)"

            # Show error message
            $message = $this.uiManager.GetLocalizedMessage("updateCheckError") -f $_.Exception.Message
            $title = $this.uiManager.GetLocalizedMessage("updateCheckTitle")

            ("System.Windows.MessageBox" -as [type])::Show($message, $title, "OK", "Error")
        }
    }

    # Handle send feedback
    [void] HandleSendFeedback() {
        try {
            Write-Verbose "[INFO] ConfigEditorEvents: Opening feedback page"
            # Open GitHub issue creation page
            Start-Process "https://github.com/beive60/focus-game-deck/issues/new/choose"
        } catch {
            Write-Verbose "[ERROR] ConfigEditorEvents: Failed to open feedback page - $($_.Exception.Message)"

            # Show error message (reuse existing key 'browserOpenError')
            $message = $this.uiManager.GetLocalizedMessage("browserOpenError")
            Show-SafeMessage -Message $message -MessageType "Error"
        }
    }

    # Handle auto detect path
    [void] HandleAutoDetectPath([string]$Platform) {
        try {
            $detectedPaths = @()

            switch ($Platform) {
                "Steam" {
                    $commonPaths = @(
                        "${env:ProgramFiles(x86)}/Steam/steam.exe",
                        "${env:ProgramFiles}/Steam/steam.exe",
                        "C:/Program Files (x86)/Steam/steam.exe",
                        "C:/Program Files/Steam/steam.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "Epic" {
                    $commonPaths = @(
                        "${env:ProgramFiles(x86)}/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe",
                        "${env:ProgramFiles}/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe",
                        "C:/Program Files (x86)/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe",
                        "C:/Program Files/Epic Games/Launcher/Engine/Binaries/Win64/EpicGamesLauncher.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "Riot" {
                    $commonPaths = @(
                        "${env:ProgramFiles}/Riot Games/Riot Client/RiotClientServices.exe",
                        "${env:ProgramFiles(x86)}/Riot Games/Riot Client/RiotClientServices.exe",
                        "C:/Program Files/Riot Games/Riot Client/RiotClientServices.exe",
                        "C:/Program Files (x86)/Riot Games/Riot Client/RiotClientServices.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "OBS" {
                    $commonPaths = @(
                        "${env:ProgramFiles}/obs-studio/bin/64bit/obs64.exe",
                        "${env:ProgramFiles(x86)}/obs-studio/bin/64bit/obs64.exe",
                        "C:/Program Files/obs-studio/bin/64bit/obs64.exe",
                        "C:/Program Files (x86)/obs-studio/bin/64bit/obs64.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
                "Discord" {
                    # Use version-agnostic path pattern that will be resolved at runtime
                    # The DiscordManager module will automatically find the latest version
                    $discordBase = "${env:LOCALAPPDATA}/Discord"
                    if (Test-Path $discordBase) {
                        # Check if any app-* directories exist
                        $appDirs = Get-ChildItem -Path $discordBase -Directory -Filter "app-*" -ErrorAction SilentlyContinue
                        if ($appDirs.Count -gt 0) {
                            # Return the base pattern path instead of specific version
                            # This allows DiscordManager to resolve the latest version at runtime
                            $detectedPaths += "$discordBase/app-*/Discord.exe"
                        }
                    }
                    # If no app-* directories found, detection fails
                    # This indicates Discord is not properly installed
                }
                "VTubeStudio" {
                    $commonPaths = @(
                        "${env:ProgramFiles(x86)}/Steam/steamapps/common/VTube Studio/VTube Studio.exe",
                        "${env:ProgramFiles}/Steam/steamapps/common/VTube Studio/VTube Studio.exe",
                        "C:/Program Files (x86)/Steam/steamapps/common/VTube Studio/VTube Studio.exe",
                        "C:/Program Files/Steam/steamapps/common/VTube Studio/VTube Studio.exe"
                    )
                    foreach ($path in $commonPaths) {
                        if (Test-Path $path) {
                            $detectedPaths += $path
                        }
                    }
                }
            }

            if ($detectedPaths.Count -eq 0) {
                $message = $this.uiManager.GetLocalizedMessage("noPathDetected") -f $Platform
                Show-SafeMessage -Message $message -MessageType "Information"
                return
            }

            # If only one path detected, use it directly
            $selectedPath = if ($detectedPaths.Count -eq 1) {
                $detectedPaths[0]
            } else {
                # Multiple paths detected, let user choose
                Show-PathSelectionDialog -Paths $detectedPaths -Platform $Platform
            }

            if ($selectedPath) {
                # Set the appropriate text box
                switch ($Platform) {
                    "Steam" { $script:Window.FindName("SteamPathTextBox").Text = $selectedPath }
                    "Epic" { $script:Window.FindName("EpicPathTextBox").Text = $selectedPath }
                    "Riot" { $script:Window.FindName("RiotPathTextBox").Text = $selectedPath }
                    "OBS" { $script:Window.FindName("OBSPathTextBox").Text = $selectedPath }
                    "Discord" { $script:Window.FindName("DiscordPathTextBox").Text = $selectedPath }
                    "VTubeStudio" { $script:Window.FindName("VTubePathTextBox").Text = $selectedPath }
                }

                Write-Verbose "Auto-detected $Platform path: $selectedPath"
            }

        } catch {
            Write-Error "Auto-detection failed for ${Platform}: $_"
            $message = $this.uiManager.GetLocalizedMessage("autoDetectError") -f $Platform, $_.Exception.Message
            Show-SafeMessage -Message $message -MessageType "Error"
        }
    }

    # Handle language selection changed
    [void] HandleLanguageSelectionChanged() {
        # Skip if still initializing to avoid triggering restart during startup
        if (-not $script:IsInitializationComplete) {
            Write-Verbose "Skipping language change handler - initialization not complete"
            Write-Verbose "[DEBUG] ConfigEditorEvents: IsInitializationComplete = $script:IsInitializationComplete"
            return
        }

        $languageCombo = $this.uiManager.Window.FindName("LanguageCombo")
        if (-not $languageCombo.SelectedItem) {
            Write-Verbose "[DEBUG] ConfigEditorEvents: LanguageCombo.SelectedItem is null"
            return
        }

        $selectedLanguageCode = $languageCombo.SelectedItem.Tag
        Write-Verbose "[DEBUG] ConfigEditorEvents: LanguageCombo.SelectedItem.Tag = '$selectedLanguageCode'"
        Write-Verbose "[DEBUG] ConfigEditorEvents: UIManager.CurrentLanguage = '$($this.uiManager.CurrentLanguage)'"
        Write-Verbose "[DEBUG] ConfigEditorEvents: Config.language = '$($this.stateManager.ConfigData.language)'"
        Write-Verbose "[DEBUG] ConfigEditorEvents: Are combo and UIManager equal? $($selectedLanguageCode -eq $this.uiManager.CurrentLanguage)"

        # Check if language actually changed
        if ($selectedLanguageCode -eq $this.uiManager.CurrentLanguage) {
            Write-Verbose "Language not changed, skipping restart prompt"
            Write-Verbose "[INFO] ConfigEditorEvents: Language selection unchanged (both = '$selectedLanguageCode')"
            return
        }

        Write-Verbose "[INFO] ConfigEditorEvents: Language changed from '$($this.uiManager.CurrentLanguage)' to '$selectedLanguageCode'"

        # Save the language setting to configuration
        if (-not $this.stateManager.ConfigData.PSObject.Properties["language"]) {
            $this.stateManager.ConfigData | Add-Member -NotePropertyName "language" -NotePropertyValue $selectedLanguageCode
        } else {
            $this.stateManager.ConfigData.language = $selectedLanguageCode
        }

        # DO NOT mark as modified here - the restart process will save the configuration
        # This prevents the "unsaved changes" dialog from appearing during restart
        # $this.stateManager.SetModified()

        # Show restart message and restart if user agrees
        Show-LanguageChangeRestartMessage

        Write-Verbose "Language changed to: $selectedLanguageCode"
    }

    # Handle window closing
    [void] HandleWindowClosing([Object]$e) {
        try {
            Write-Verbose "[DEBUG] ConfigEditorEvents: HandleWindowClosing called"

            # Check if there are unsaved changes
            if ($this.stateManager.TestHasUnsavedChanges()) {
                Write-Verbose "[DEBUG] ConfigEditorEvents: Unsaved changes detected"

                # Get localized messages
                $message = $this.uiManager.GetLocalizedMessage("saveBeforeClosePrompt")
                $title = $this.uiManager.GetLocalizedMessage("unsavedChangesTitle")
                $saveAndClose = $this.uiManager.GetLocalizedMessage("saveAndClose")
                $discardAndClose = $this.uiManager.GetLocalizedMessage("discardAndClose")
                $cancel = $this.uiManager.GetLocalizedMessage("cancelButton")

                Write-Verbose "[DEBUG] Dialog localization values:"
                Write-Verbose "  title: '$title'"
                Write-Verbose "  message: '$message'"
                Write-Verbose "  saveAndClose: '$saveAndClose'"
                Write-Verbose "  discardAndClose: '$discardAndClose'"
                Write-Verbose "  cancel: '$cancel'"

                # Create custom dialog window
                Add-Type -AssemblyName PresentationFramework

                # Try to load XAML fragment from embedded variable or project GUI files
                $dialogXaml = $null

                # Check if embedded XAML variable exists (production/bundled mode)
                if ($Global:Xaml_ConfirmSaveChangesDialog_fragment) {
                    Write-Verbose "Using embedded dialog XAML from `$Global:Xaml_ConfirmSaveChangesDialog_fragment"
                    $dialogXaml = $Global:Xaml_ConfirmSaveChangesDialog_fragment
                } else {
                    # Fallback to file-based loading (development mode)
                    $dialogXamlPath = Join-Path -Path $this.appRoot -ChildPath "gui/ConfirmSaveChangesDialog.fragment.xaml"
                    if (Test-Path $dialogXamlPath) {
                        try {
                            $dialogXaml = Get-Content -Path $dialogXamlPath -Raw
                            Write-Verbose "Loaded dialog fragment from: $dialogXamlPath"
                        } catch {
                            Write-Warning "Failed to read dialog XAML fragment at {$dialogXamlPath}: $($_.Exception.Message)"
                            $dialogXaml = $null
                        }
                    } else {
                        Write-Verbose "Dialog fragment not found at: $dialogXamlPath"
                    }
                }

                if ([string]::IsNullOrWhiteSpace($dialogXaml)) {
                    Write-Warning "No dialog XAML available (neither embedded nor file-based)"
                    # Continue with fallback logic below
                }

                # Expand placeholders in dialog XAML
                if (-not [string]::IsNullOrWhiteSpace($dialogXaml)) {
                    try {
                        Write-Verbose "[DEBUG] Original XAML length: $($dialogXaml.Length)"
                        Write-Verbose "[DEBUG] First 300 chars of original XAML: $($dialogXaml.Substring(0, [Math]::Min(300, $dialogXaml.Length)))"

                        # Replace literal tokens like $title in the fragment with the runtime values
                        # Use simple string replace instead of regex for better reliability
                        $dialogXaml = $dialogXaml.Replace('$title', $title)
                        $dialogXaml = $dialogXaml.Replace('$message', $message)
                        $dialogXaml = $dialogXaml.Replace('$saveAndClose', $saveAndClose)
                        $dialogXaml = $dialogXaml.Replace('$discardAndClose', $discardAndClose)
                        $dialogXaml = $dialogXaml.Replace('$cancel', $cancel)

                        Write-Verbose "[DEBUG] Replaced XAML length: $($dialogXaml.Length)"
                        Write-Verbose "[DEBUG] First 300 chars of replaced XAML: $($dialogXaml.Substring(0, [Math]::Min(300, $dialogXaml.Length)))"
                    } catch {
                        Write-Warning "Failed to expand placeholders in dialog XAML: $($_.Exception.Message)"
                        $dialogXaml = $null
                    }
                }



                $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dialogXaml))
                $dialogWindow = ("System.Windows.Markup.XamlReader" -as [type])::Load($reader)
                $reader.Close()

                # Set owner for modal behavior
                $dialogWindow.Owner = $this.Window

                # Get buttons
                $saveButton = $dialogWindow.FindName("SaveButton")
                $discardButton = $dialogWindow.FindName("DiscardButton")
                $cancelButton = $dialogWindow.FindName("CancelButton")

                # Add event handlers
                $saveButton.Add_Click({
                        $dialogWindow.Tag = "Save"
                        $dialogWindow.DialogResult = $true
                        $dialogWindow.Close()
                    })

                $discardButton.Add_Click({
                        $dialogWindow.Tag = "Discard"
                        $dialogWindow.DialogResult = $true
                        $dialogWindow.Close()
                    })

                $cancelButton.Add_Click({
                        $dialogWindow.Tag = "Cancel"
                        $dialogWindow.DialogResult = $false
                        $dialogWindow.Close()
                    })

                # Show dialog
                [void]$dialogWindow.ShowDialog()
                $userChoice = $dialogWindow.Tag

                Write-Verbose "[DEBUG] ConfigEditorEvents: User choice - $userChoice"

                switch ($userChoice) {
                    "Save" {
                        # Save and close
                        Write-Verbose "[DEBUG] ConfigEditorEvents: Saving changes before closing"
                        try {
                            $this.HandleSaveConfig()
                            Write-Verbose "[DEBUG] ConfigEditorEvents: Changes saved successfully"
                        } catch {
                            Write-Verbose "[ERROR] ConfigEditorEvents: Failed to save changes - $($_.Exception.Message)"
                            # Show error and cancel closing
                            Show-SafeMessage -Key "configSaveFailed" -MessageType "Error"
                            $e.Cancel = $true
                            return
                        }
                    }
                    "Discard" {
                        # Discard and close
                        Write-Verbose "[DEBUG] ConfigEditorEvents: Discarding changes and closing"
                    }
                    default {
                        # Cancel closing (includes "Cancel" and null)
                        Write-Verbose "[DEBUG] ConfigEditorEvents: User cancelled window closing"
                        $e.Cancel = $true
                        return
                    }
                }
            } else {
                Write-Verbose "[DEBUG] ConfigEditorEvents: No unsaved changes, closing directly"
            }

            Write-Verbose "[DEBUG] ConfigEditorEvents: Window closing approved"
        } catch {
            Write-Verbose "[WARNING] ConfigEditorEvents: Error in HandleWindowClosing - $($_.Exception.Message)"
            # Don't cancel on error - allow window to close
        }
    }

    # Validate Game ID on blur
    [void] ValidateGameIdOnBlur() {
        $gameIdTextBox = $script:Window.FindName("GameIdTextBox")
        $gameId = $gameIdTextBox.Text.Trim()

        # Use centralized validation module
        $errors = Invoke-ConfigurationValidation -GameId $gameId
        $gameIdError = $errors | Where-Object { $_.Control -eq 'GameIdTextBox' }

        if ($gameIdError) {
            $this.uiManager.SetInputError("GameIdTextBox", $this.uiManager.GetLocalizedMessage($gameIdError.Key))
        } else {
            $this.uiManager.SetInputError("GameIdTextBox", "")
        }
    }

    # Validate Steam App ID on blur
    [void] ValidateSteamAppIdOnBlur() {
        $platformCombo = $script:Window.FindName("PlatformComboBox")
        $platform = if ($platformCombo.SelectedItem) { $platformCombo.SelectedItem.Tag } else { "" }

        # Only validate if platform is Steam
        if ($platform -eq "steam") {
            $steamAppIdTextBox = $script:Window.FindName("SteamAppIdTextBox")
            $steamAppId = $steamAppIdTextBox.Text.Trim()

            # Use centralized validation module
            $errors = Invoke-ConfigurationValidation -Platform $platform -SteamAppId $steamAppId
            $steamError = $errors | Where-Object { $_.Control -eq 'SteamAppIdTextBox' }

            if ($steamError) {
                $this.uiManager.SetInputError("SteamAppIdTextBox", $this.uiManager.GetLocalizedMessage($steamError.Key))
            } else {
                $this.uiManager.SetInputError("SteamAppIdTextBox", "")
            }
        } else {
            # Clear error if not Steam platform
            $this.uiManager.SetInputError("SteamAppIdTextBox", "")
        }
    }

    # Clear error on text input (for Game ID)
    [void] ClearGameIdErrorOnInput() {
        $this.uiManager.SetInputError("GameIdTextBox", "")
    }

    # Clear error on text input (for Steam App ID)
    [void] ClearSteamAppIdErrorOnInput() {
        $this.uiManager.SetInputError("SteamAppIdTextBox", "")
    }

    # Validate Epic Game ID on blur
    [void] ValidateEpicGameIdOnBlur() {
        $platformCombo = $script:Window.FindName("PlatformComboBox")
        $platform = if ($platformCombo.SelectedItem) { $platformCombo.SelectedItem.Tag } else { "" }

        # Only validate if platform is Epic
        if ($platform -eq "epic") {
            $epicGameIdTextBox = $script:Window.FindName("EpicGameIdTextBox")
            $epicGameId = $epicGameIdTextBox.Text.Trim()

            # Use centralized validation module
            $errors = Invoke-ConfigurationValidation -Platform $platform -EpicGameId $epicGameId
            $epicError = $errors | Where-Object { $_.Control -eq 'EpicGameIdTextBox' }

            if ($epicError) {
                $this.uiManager.SetInputError("EpicGameIdTextBox", $this.uiManager.GetLocalizedMessage($epicError.Key))
            } else {
                $this.uiManager.SetInputError("EpicGameIdTextBox", "")
            }
        } else {
            # Clear error if not Epic platform
            $this.uiManager.SetInputError("EpicGameIdTextBox", "")
        }
    }

    # Clear error on text input (for Epic Game ID)
    [void] ClearEpicGameIdErrorOnInput() {
        $this.uiManager.SetInputError("EpicGameIdTextBox", "")
    }

    # Validate Executable Path on blur
    [void] ValidateExecutablePathOnBlur() {
        $platformCombo = $script:Window.FindName("PlatformComboBox")
        $platform = if ($platformCombo.SelectedItem) { $platformCombo.SelectedItem.Tag } else { "" }

        # Only validate if platform is standalone or direct
        if ($platform -in 'standalone', 'direct') {
            $executablePathTextBox = $script:Window.FindName("ExecutablePathTextBox")
            $executablePath = $executablePathTextBox.Text.Trim()

            # Use centralized validation module
            $errors = Invoke-ConfigurationValidation -Platform $platform -ExecutablePath $executablePath
            $pathError = $errors | Where-Object { $_.Control -eq 'ExecutablePathTextBox' }

            if ($pathError) {
                $this.uiManager.SetInputError("ExecutablePathTextBox", $this.uiManager.GetLocalizedMessage($pathError.Key))
            } else {
                $this.uiManager.SetInputError("ExecutablePathTextBox", "")
            }
        } else {
            # Clear error if not standalone/direct platform
            $this.uiManager.SetInputError("ExecutablePathTextBox", "")
        }
    }

    # Clear error on text input (for Executable Path)
    [void] ClearExecutablePathErrorOnInput() {
        $this.uiManager.SetInputError("ExecutablePathTextBox", "")
    }

    # Handle save game settings
    [void] HandleSaveGameSettings() {
        try {
            # Save current game data
            Save-CurrentGameData

            # Save apps to manage for current game
            if ($script:CurrentGameId) {
                $gameData = $this.stateManager.ConfigData.games.$script:CurrentGameId
                if ($gameData) {
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

                        # Update game's appsToManage property
                        if (-not $gameData.PSObject.Properties["appsToManage"]) {
                            $gameData | Add-Member -NotePropertyName "appsToManage" -NotePropertyValue $appsToManage
                        } else {
                            $gameData.appsToManage = $appsToManage
                        }
                        Write-Verbose "Saved appsToManage for game $script:CurrentGameId: $($appsToManage -join ', ')"
                    }
                }
            }

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            # Refresh games list to reflect any changes
            $this.uiManager.UpdateGamesList($this.stateManager.ConfigData)

            $message = $this.uiManager.GetLocalizedMessage("gameSettingsSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "Game settings saved"

        } catch {
            Write-Error "Failed to save game settings: $_"
            Show-SafeMessage -Key "gameSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save managed apps
    [void] HandleSaveManagedApps() {
        try {
            # Store the current app ID before saving (it might change during save)
            $currentAppId = $script:CurrentAppId

            # Save current app data
            Save-CurrentAppData

            # Get the potentially updated app ID after save
            $updatedAppId = $script:CurrentAppId

            # Save apps to manage for current game if on Games tab context
            # Note: The AppsToManagePanel is shown on the Games tab, not Managed Apps tab
            # So we save it with the current game's data
            if ($script:CurrentGameId) {
                $gameData = $this.stateManager.ConfigData.games.$script:CurrentGameId
                if ($gameData) {
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

                        # Update game's appsToManage property
                        if (-not $gameData.PSObject.Properties["appsToManage"]) {
                            $gameData | Add-Member -NotePropertyName "appsToManage" -NotePropertyValue $appsToManage
                        } else {
                            $gameData.appsToManage = $appsToManage
                        }
                        Write-Verbose "Saved appsToManage for game $script:CurrentGameId: $($appsToManage -join ', ')"
                    }
                }
            }

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            # Refresh managed apps list to reflect any changes (including ID changes)
            $this.uiManager.UpdateManagedAppsList($this.stateManager.ConfigData)

            # Restore selection to the updated app ID
            if ($updatedAppId) {
                $managedAppsList = $script:Window.FindName("ManagedAppsList")
                if ($managedAppsList) {
                    for ($i = 0; $i -lt $managedAppsList.Items.Count; $i++) {
                        if ($managedAppsList.Items[$i] -eq $updatedAppId) {
                            $managedAppsList.SelectedIndex = $i
                            Write-Verbose "Restored selection to app: $updatedAppId"
                            break
                        }
                    }
                }
            }

            $message = $this.uiManager.GetLocalizedMessage("managedAppsSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "Managed apps settings saved"

        } catch {
            Write-Error "Failed to save managed apps settings: $_"
            Show-SafeMessage -Key "managedAppsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save global settings
    [void] HandleSaveGlobalSettings() {
        try {
            # Save global settings data
            Save-GlobalSettingsData

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            $message = $this.uiManager.GetLocalizedMessage("globalSettingsSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "Global settings saved"

        } catch {
            Write-Error "Failed to save global settings: $_"
            Show-SafeMessage -Key "globalSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save OBS settings
    [void] HandleSaveOBSSettings() {
        try {
            # Save OBS settings data
            Save-OBSSettingsData

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            $message = $this.uiManager.GetLocalizedMessage("obsSettingsSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "OBS settings saved"

        } catch {
            Write-Error "Failed to save OBS settings: $_"
            Show-SafeMessage -Key "obsSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save Discord settings
    [void] HandleSaveDiscordSettings() {
        try {
            # Save Discord settings data
            Save-DiscordSettingsData

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            $message = $this.uiManager.GetLocalizedMessage("discordSettingsSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "Discord settings saved"

        } catch {
            Write-Error "Failed to save Discord settings: $_"
            Show-SafeMessage -Key "discordSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle save VTube Studio settings
    [void] HandleSaveVTubeStudioSettings() {
        try {
            # Save VTube Studio settings data
            Save-VTubeStudioSettingsData

            # Write to file with 4-space indentation
            Save-ConfigJson -ConfigData $this.stateManager.ConfigData -ConfigPath $script:ConfigPath -Depth 10

            # Update original config and clear modified flag
            Save-OriginalConfig
            $this.stateManager.ClearModified()

            $message = $this.uiManager.GetLocalizedMessage("vtubeStudioSettingsSaved")
            $this.uiManager.ShowNotification($message, "Success")
            Write-Verbose "VTube Studio settings saved"

        } catch {
            Write-Error "Failed to save VTube Studio settings: $_"
            Show-SafeMessage -Key "vtubeStudioSettingsSaveFailed" -MessageType "Error"
        }
    }

    # Handle opening integration tab from game settings
    [void] HandleOpenIntegrationTab([string]$TabName) {
        try {
            $tabControl = $script:Window.FindName("MainTabControl")
            if (-not $tabControl) {
                Write-Warning "TabControl not found"
                return
            }

            $targetTab = $null
            switch ($TabName) {
                "OBS" { $targetTab = $script:Window.FindName("OBSTab") }
                "Discord" { $targetTab = $script:Window.FindName("DiscordTab") }
                "VTubeStudio" { $targetTab = $script:Window.FindName("VTubeStudioTab") }
            }

            if ($targetTab) {
                $tabControl.SelectedItem = $targetTab
                Write-Verbose "Switched to $TabName tab"
            } else {
                Write-Warning "$TabName tab not found"
            }

        } catch {
            Write-Error "Failed to open $TabName tab: $_"
        }
    }

    # Handle refresh game list button click
    [void] HandleRefreshGameList() {
        try {
            Write-Verbose "Refreshing game list"
            $this.uiManager.UpdateGameLauncherList($this.stateManager.ConfigData)
        } catch {
            Write-Warning "Failed to refresh game list: $($_.Exception.Message)"
        }
    }

    # Handle launch game from launcher tab
    [void] HandleLaunchGame([string]$GameId) {
        try {
            # Update status immediately for responsive feedback
            $statusText = $this.uiManager.Window.FindName("LauncherStatusText")
            if ($statusText) {
                $launchingMessage = $this.uiManager.GetLocalizedMessage("launchingGame")
                $statusText.Text = $launchingMessage -f $GameId
                $statusText.Foreground = "#0066CC"
            }

            # Validate game exists in configuration
            if (-not $this.stateManager.ConfigData.games -or -not $this.stateManager.ConfigData.games.PSObject.Properties[$GameId]) {
                Show-SafeMessage -Key "gameNotFound" -MessageType "Error" -FormatArgs @($GameId)
                if ($statusText) {
                    $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                    $statusText.Foreground = "#CC0000"
                }
                return
            }

            # Use the direct game launcher to avoid recursive ConfigEditor launches
            $launcherExePath = Join-Path -Path $this.appRoot -ChildPath "Invoke-FocusGameDeck.exe"
            $launcherScriptPath = Join-Path -Path $this.appRoot -ChildPath "src/Invoke-FocusGameDeck.ps1"
            $process = $null

            if ($this.IsExecutable) {
                if (-not (Test-Path $launcherExePath)) {
                    Show-SafeMessage -Key "launcherNotFound" -MessageType "Error"
                    if ($statusText) {
                        $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                        $statusText.Foreground = "#CC0000"
                    }
                    return
                }

                Write-Verbose "[INFO] ConfigEditorEvents: Launching game via bundled executable - $GameId"

                $process = Start-Process -FilePath $launcherExePath -ArgumentList @(
                    "-GameId", $GameId
                ) -WindowStyle Minimized -PassThru
            } else {
                if (-not (Test-Path $launcherScriptPath)) {
                    Show-SafeMessage -Key "launcherNotFound" -MessageType "Error"
                    if ($statusText) {
                        $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                        $statusText.Foreground = "#CC0000"
                    }
                    return
                }

                Write-Verbose "[INFO] ConfigEditorEvents: Launching game from GUI - $GameId"

                # Launch the game using PowerShell - bypass Main.ps1 to prevent recursive ConfigEditor launch
                $process = Start-Process -FilePath "powershell.exe" -ArgumentList @(
                    "-ExecutionPolicy", "Bypass",
                    "-File", $launcherScriptPath,
                    "-GameId", $GameId
                ) -WindowStyle Minimized -PassThru
            }

            # Provide immediate non-intrusive feedback
            if ($process) {
                Write-Verbose "Game launch process started with PID: $($process.Id)"

                # Update status with success message - no modal dialog
                if ($statusText) {
                    $launchedMessage = $this.uiManager.GetLocalizedMessage("gameLaunched")
                    $statusText.Text = $launchedMessage -f $GameId
                    $statusText.Foreground = "#009900"
                }
            }

            # Reset status after delay without interrupting user workflow
            $uiManagerRef = $this.uiManager
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(5)
            $timer.add_Tick({
                    param($eventSender, $e)
                    $statusText = $uiManagerRef.Window.FindName("LauncherStatusText")
                    if ($statusText) {
                        $statusText.Text = $uiManagerRef.GetLocalizedMessage("readyToLaunch")
                        $statusText.Foreground = "#333333"
                    }
                    $eventSender.Stop()
                }.GetNewClosure())
            $timer.Start()

        } catch {
            Write-Warning "Failed to launch game '$GameId': $($_.Exception.Message)"

            # Only show modal dialog for actual errors that need user attention
            Show-SafeMessage -Key "launchFailed" -MessageType "Error" -FormatArgs @($GameId, $_.Exception.Message)

            # Update status for error
            $statusText = $this.uiManager.Window.FindName("LauncherStatusText")
            if ($statusText) {
                $statusText.Text = $this.uiManager.GetLocalizedMessage("launchError")
                $statusText.Foreground = "#CC0000"
            }
        }
    }

    # Handle refresh managed apps list
    [void] HandleRefreshManagedAppsList() {
        try {
            Write-Verbose "Refreshing managed apps list..."
            $configData = $this.stateManager.ConfigData
            $this.uiManager.UpdateManagedAppsList($configData)
            Write-Verbose "Managed apps list refreshed successfully"
        } catch {
            Write-Warning "Failed to refresh managed apps list: $($_.Exception.Message)"
        }
    }

    # Handle refresh all lists
    [void] HandleRefreshAll() {
        try {
            Write-Verbose "Refreshing all lists..."
            $configData = $this.stateManager.ConfigData
            $this.uiManager.UpdateGamesList($configData)
            $this.uiManager.UpdateGameLauncherList($configData)
            $this.uiManager.UpdateManagedAppsList($configData)
            Write-Verbose "All lists refreshed successfully"
        } catch {
            Write-Warning "Failed to refresh all lists: $($_.Exception.Message)"
        }
    }

    # Handle create all shortcuts
    [void] HandleCreateAllShortcuts() {
        try {
            Write-Verbose "Creating shortcuts for all games..."
            $this.uiManager.CreateAllShortcuts()
        } catch {
            Write-Warning "Failed to create all shortcuts: $($_.Exception.Message)"
        }
    }

    # Handle about dialog
    [void] HandleAbout() {
        try {
            Write-Verbose "[DEBUG] ConfigEditorEvents: About dialog started"

            # Get version information - use global function reference
            $version = if ($global:GetProjectVersionFunc) {
                & $global:GetProjectVersionFunc
            } else {
                Write-Verbose "[WARNING] ConfigEditorEvents: Get-ProjectVersion not available"
                "Unknown"
            }
            $buildDate = Get-Date -Format "yyyy-MM-dd"

            Write-Verbose "[INFO] ConfigEditorEvents: Version - $version"
            Write-Verbose "[INFO] ConfigEditorEvents: Build Date - $buildDate"

            # Create about message
            $aboutMessage = $this.uiManager.GetLocalizedMessage("aboutMessage") -f $version, $buildDate
            $aboutTitle = $this.uiManager.GetLocalizedMessage("aboutTitle")

            Write-Verbose "[DEBUG] ConfigEditorEvents: About Message - $aboutMessage"
            Write-Verbose "[DEBUG] ConfigEditorEvents: About Title - $aboutTitle"

            # Show the about dialog
            ("System.Windows.MessageBox" -as [type])::Show($aboutMessage, $aboutTitle, "OK", "Information")

            Write-Verbose "[OK] ConfigEditorEvents: About dialog completed"

        } catch {
            Write-Verbose "[ERROR] ConfigEditorEvents: About dialog error - $($_.Exception.Message)"
        }
    }

    # Handle generate launchers
    [void] HandleGenerateLaunchers() {
        try {
            # Get the selected games from the launcher list
            $gameLauncherList = $script:Window.FindName("GameLauncherList")
            $selectedGames = @()

            foreach ($child in $gameLauncherList.Children) {
                if ($child -and $child.GetType() -eq "System.Windows.Controls.Border") {
                    $grid = $child.Child
                    if ($grid -and $grid.GetType() -eq "System.Windows.Controls.Grid") {
                        $checkBox = $grid.Children |
                        Where-Object { $_.GetType().FullName -eq "System.Windows.Controls.CheckBox" } |
                        Select-Object -First 1
                        if ($checkBox -and $checkBox.IsChecked -and $checkBox.Tag) {
                            $selectedGames += $checkBox.Tag
                        }
                    }
                }
            }

            if ($selectedGames.Count -eq 0) {
                Show-SafeMessage -Key "noGamesSelectedForLaunchers" -MessageType "Warning"
                return
            }

            # Use the internal shortcut creation function from ConfigEditor.UI.ps1
            # This function is already implemented and works correctly in both script and executable modes
            Write-Verbose "[INFO] ConfigEditorEvents: Creating launchers for $($selectedGames.Count) games"

            try {
                # Call the CreateAllShortcuts method from the UI manager
                $this.uiManager.CreateAllShortcuts()
                Write-Verbose "[INFO] ConfigEditorEvents: Successfully initiated shortcut creation for $($selectedGames.Count) games"
            } catch {
                Write-Error "Launcher generation failed: $_"
                Show-SafeMessage -Key "launcherGenerationFailed" -MessageType "Error" -FormatArgs @($_.Exception.Message)
            }

        } catch {
            Write-Error "Failed to generate launchers: $_"
            Show-SafeMessage -Key "launcherGenerationFailed" -MessageType "Error" -FormatArgs @($_.Exception.Message)
        }
    }

    # Register all UI event handlers
    [void] RegisterAll() {
        try {
            Write-Verbose "[INFO] ConfigEditorEvents: Registering all UI event handlers"

            $self = $this

            # --- Window Events ---
            $this.uiManager.Window.add_Closing({
                    param($eventSender, $e)
                    try {
                        Write-Verbose "[DEBUG] ConfigEditorEvents: Window Closing event fired"
                        $self.HandleWindowClosing($e)
                    } catch {
                        Write-Verbose "[WARNING] ConfigEditorEvents: Error in window closing event - $($_.Exception.Message)"
                    }
                }.GetNewClosure())

            # --- Game Launcher Tab ---
            $genLaunchersBtn = $this.uiManager.Window.FindName("GenerateLaunchersButton")
            if ($genLaunchersBtn) { $genLaunchersBtn.add_Click({ $self.HandleGenerateLaunchers() }.GetNewClosure()) } else { Write-Verbose "GenerateLaunchersButton not found" }

            # Register drag and drop handlers for GameLauncherList
            $gameLauncherListCtrl = $this.uiManager.Window.FindName("GameLauncherList")
            if ($gameLauncherListCtrl) {
                $gameLauncherListCtrl.AllowDrop = $true
                $gameLauncherListCtrl.add_PreviewMouseLeftButtonDown({ param($s, $e) $self.HandleGameLauncherPreviewMouseLeftButtonDown($s, $e) }.GetNewClosure())
                $gameLauncherListCtrl.add_MouseMove({ param($s, $e) $self.HandleGameLauncherMouseMove($s, $e) }.GetNewClosure())
                $gameLauncherListCtrl.add_DragOver({ param($s, $e) $self.HandleGameLauncherDragOver($s, $e) }.GetNewClosure())
                $gameLauncherListCtrl.add_DragLeave({ param($s, $e) $self.HandleGameLauncherDragLeave($s, $e) }.GetNewClosure())
                $gameLauncherListCtrl.add_Drop({ param($s, $e) $self.HandleGameLauncherDrop($s, $e) }.GetNewClosure())
                Write-Verbose "GameLauncherList drag and drop handlers registered"
            } else {
                Write-Verbose "GameLauncherList not found"
            }

            # Add tab selection event to update game list when switching to launcher tab
            $mainTabControl = $this.uiManager.Window.FindName("MainTabControl")
            if ($mainTabControl) {
                $mainTabControl.add_SelectionChanged({
                        try {
                            $selectedTab = $this.SelectedItem
                            if ($selectedTab -and $selectedTab.Name -eq "GameLauncherTab") {
                                $self.HandleRefreshGameList()
                            } elseif ($selectedTab -and $selectedTab.Name -eq "GamesTab") {
                                # Ensure first game is selected when switching to Games tab
                                $gamesList = $self.uiManager.Window.FindName("GamesList")
                                if ($gamesList -and $gamesList.Items.Count -gt 0 -and $gamesList.SelectedIndex -lt 0) {
                                    $gamesList.SelectedIndex = 0
                                }
                            } elseif ($selectedTab -and $selectedTab.Name -eq "ManagedAppsTab") {
                                # Ensure first app is selected when switching to Managed Apps tab
                                $managedAppsList = $self.uiManager.Window.FindName("ManagedAppsList")
                                if ($managedAppsList -and $managedAppsList.Items.Count -gt 0 -and $managedAppsList.SelectedIndex -lt 0) {
                                    $managedAppsList.SelectedIndex = 0
                                }
                            }
                        } catch {
                            Write-Warning "Error in tab selection changed: $($_.Exception.Message)"
                        }
                    }.GetNewClosure())
            } else { Write-Verbose "MainTabControl not found" }

            # --- Game Settings Tab ---
            $gamesListCtrl = $this.uiManager.Window.FindName("GamesList")
            if ($gamesListCtrl) {
                $gamesListCtrl.add_SelectionChanged({ $self.HandleGameSelectionChanged() }.GetNewClosure())
                # Register drag and drop handlers for GamesList
                $gamesListCtrl.add_PreviewMouseLeftButtonDown({ param($s, $e) $self.HandleListBoxPreviewMouseLeftButtonDown($s, $e) }.GetNewClosure())
                $gamesListCtrl.add_MouseMove({ param($s, $e) $self.HandleListBoxMouseMove($s, $e) }.GetNewClosure())
                $gamesListCtrl.add_DragOver({ param($s, $e) $self.HandleGamesListDragOver($s, $e) }.GetNewClosure())
                $gamesListCtrl.add_DragLeave({ param($s, $e) $self.HandleGamesListDragLeave($s, $e) }.GetNewClosure())
                $gamesListCtrl.add_Drop({ param($s, $e) $self.HandleGamesListDrop($s, $e) }.GetNewClosure())

                # Create context menu for GamesList
                $gamesContextMenu = New-Object System.Windows.Controls.ContextMenu

                $addGameMenuItem = New-Object System.Windows.Controls.MenuItem
                $addGameMenuItem.Header = $self.uiManager.GetLocalizedMessage("addMenuItem")
                $addGameMenuItem.add_Click({ $self.HandleAddGame() }.GetNewClosure())
                $gamesContextMenu.Items.Add($addGameMenuItem)

                $deleteGameMenuItem = New-Object System.Windows.Controls.MenuItem
                $deleteGameMenuItem.Header = $self.uiManager.GetLocalizedMessage("deleteMenuItem")
                $deleteGameMenuItem.add_Click({ $self.HandleDeleteGame() }.GetNewClosure())
                $gamesContextMenu.Items.Add($deleteGameMenuItem)

                $duplicateGameMenuItem = New-Object System.Windows.Controls.MenuItem
                $duplicateGameMenuItem.Header = $self.uiManager.GetLocalizedMessage("duplicateMenuItem")
                $duplicateGameMenuItem.add_Click({ $self.HandleDuplicateGame() }.GetNewClosure())
                $gamesContextMenu.Items.Add($duplicateGameMenuItem)

                $gamesListCtrl.ContextMenu = $gamesContextMenu
            } else {
                Write-Verbose "GamesList not found"
            }
            $platformCombo = $this.uiManager.Window.FindName("PlatformComboBox"); if ($platformCombo) { $platformCombo.add_SelectionChanged({ $self.HandlePlatformSelectionChanged() }.GetNewClosure()) } else { Write-Verbose "PlatformComboBox not found" }

            # Validation event handlers for Game ID
            $gameIdTextBox = $this.uiManager.Window.FindName("GameIdTextBox")
            if ($gameIdTextBox) {
                $gameIdTextBox.add_LostFocus({ $self.ValidateGameIdOnBlur() }.GetNewClosure())
                $gameIdTextBox.add_TextChanged({ $self.ClearGameIdErrorOnInput() }.GetNewClosure())
            }

            # Validation event handlers for Steam App ID
            $steamAppIdTextBox = $this.uiManager.Window.FindName("SteamAppIdTextBox")
            if ($steamAppIdTextBox) {
                $steamAppIdTextBox.add_LostFocus({ $self.ValidateSteamAppIdOnBlur() }.GetNewClosure())
                $steamAppIdTextBox.add_TextChanged({ $self.ClearSteamAppIdErrorOnInput() }.GetNewClosure())
            }

            # Validation event handlers for Epic Game ID
            $epicGameIdTextBox = $this.uiManager.Window.FindName("EpicGameIdTextBox")
            if ($epicGameIdTextBox) {
                $epicGameIdTextBox.add_LostFocus({ $self.ValidateEpicGameIdOnBlur() }.GetNewClosure())
                $epicGameIdTextBox.add_TextChanged({ $self.ClearEpicGameIdErrorOnInput() }.GetNewClosure())
            }

            # Validation event handlers for Executable Path
            $executablePathTextBox = $this.uiManager.Window.FindName("ExecutablePathTextBox")
            if ($executablePathTextBox) {
                $executablePathTextBox.add_LostFocus({ $self.ValidateExecutablePathOnBlur() }.GetNewClosure())
                $executablePathTextBox.add_TextChanged({ $self.ClearExecutablePathErrorOnInput() }.GetNewClosure())
            }
            $gameStartCombo = $this.uiManager.Window.FindName("GameStartActionCombo"); if ($gameStartCombo) { $gameStartCombo.add_SelectionChanged({ $self.UpdateTerminationMethodState() }.GetNewClosure()) } else { Write-Verbose "GameStartActionCombo not found" }
            $gameEndCombo = $this.uiManager.Window.FindName("GameEndActionCombo"); if ($gameEndCombo) { $gameEndCombo.add_SelectionChanged({ $self.UpdateTerminationMethodState() }.GetNewClosure()) } else { Write-Verbose "GameEndActionCombo not found" }
            $browseExecBtn = $this.uiManager.Window.FindName("BrowseExecutablePathButton"); if ($browseExecBtn) { $browseExecBtn.add_Click({ $self.HandleBrowseExecutablePath() }.GetNewClosure()) } else { Write-Verbose "BrowseExecutablePathButton not found" }
            $saveGameBtn = $this.uiManager.Window.FindName("SaveGameSettingsButton"); if ($saveGameBtn) { $saveGameBtn.add_Click({ $self.HandleSaveGameSettings() }.GetNewClosure()) } else { Write-Verbose "SaveGameSettingsButton not found" }
            $this.uiManager.Window.FindName("OpenOBSTabButton").add_Click({ $self.HandleOpenIntegrationTab("OBS") }.GetNewClosure())
            $this.uiManager.Window.FindName("OpenDiscordTabButton").add_Click({ $self.HandleOpenIntegrationTab("Discord") }.GetNewClosure())
            $this.uiManager.Window.FindName("OpenVTubeStudioTabButton").add_Click({ $self.HandleOpenIntegrationTab("VTubeStudio") }.GetNewClosure())

            # --- Managed Apps Tab ---
            $managedAppsListCtrl = $this.uiManager.Window.FindName("ManagedAppsList")
            if ($managedAppsListCtrl) {
                $managedAppsListCtrl.add_SelectionChanged({ $self.HandleAppSelectionChanged() }.GetNewClosure())
                # Register drag and drop handlers for ManagedAppsList
                $managedAppsListCtrl.add_PreviewMouseLeftButtonDown({ param($s, $e) $self.HandleListBoxPreviewMouseLeftButtonDown($s, $e) }.GetNewClosure())
                $managedAppsListCtrl.add_MouseMove({ param($s, $e) $self.HandleListBoxMouseMove($s, $e) }.GetNewClosure())
                $managedAppsListCtrl.add_DragOver({ param($s, $e) $self.HandleManagedAppsListDragOver($s, $e) }.GetNewClosure())
                $managedAppsListCtrl.add_DragLeave({ param($s, $e) $self.HandleManagedAppsListDragLeave($s, $e) }.GetNewClosure())
                $managedAppsListCtrl.add_Drop({ param($s, $e) $self.HandleManagedAppsListDrop($s, $e) }.GetNewClosure())

                # Create context menu for ManagedAppsList
                $appsContextMenu = New-Object System.Windows.Controls.ContextMenu

                $addAppMenuItem = New-Object System.Windows.Controls.MenuItem
                $addAppMenuItem.Header = $self.uiManager.GetLocalizedMessage("addMenuItem")
                $addAppMenuItem.add_Click({ $self.HandleAddApp() }.GetNewClosure())
                $appsContextMenu.Items.Add($addAppMenuItem)

                $deleteAppMenuItem = New-Object System.Windows.Controls.MenuItem
                $deleteAppMenuItem.Header = $self.uiManager.GetLocalizedMessage("deleteMenuItem")
                $deleteAppMenuItem.add_Click({ $self.HandleDeleteApp() }.GetNewClosure())
                $appsContextMenu.Items.Add($deleteAppMenuItem)

                $duplicateAppMenuItem = New-Object System.Windows.Controls.MenuItem
                $duplicateAppMenuItem.Header = $self.uiManager.GetLocalizedMessage("duplicateMenuItem")
                $duplicateAppMenuItem.add_Click({ $self.HandleDuplicateApp() }.GetNewClosure())
                $appsContextMenu.Items.Add($duplicateAppMenuItem)

                $managedAppsListCtrl.ContextMenu = $appsContextMenu
            } else {
                Write-Verbose "ManagedAppsList not found"
            }
            $this.uiManager.Window.FindName("BrowseAppPathButton").add_Click({ $self.HandleBrowseAppPath() }.GetNewClosure())
            $this.uiManager.Window.FindName("BrowseWorkingDirectoryButton").add_Click({ $self.HandleBrowseWorkingDirectory() }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveManagedAppsButton").add_Click({ $self.HandleSaveManagedApps() }.GetNewClosure())

            # --- OBS Tab ---
            $this.uiManager.Window.FindName("BrowseOBSPathButton").add_Click({ $self.HandleBrowseOBSPath() }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectOBSButton").add_Click({ $self.HandleAutoDetectPath("OBS") }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveOBSSettingsButton").add_Click({ $self.HandleSaveOBSSettings() }.GetNewClosure())

            # --- Discord Tab ---
            $this.uiManager.Window.FindName("BrowseDiscordPathButton").add_Click({ $self.HandleBrowseDiscordPath() }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectDiscordButton").add_Click({ $self.HandleAutoDetectPath("Discord") }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveDiscordSettingsButton").add_Click({ $self.HandleSaveDiscordSettings() }.GetNewClosure())

            # --- VTube Studio Tab ---
            $this.uiManager.Window.FindName("BrowseVTubePathButton").add_Click({ $self.HandleBrowseVTubeStudioPath() }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectVTubeButton").add_Click({ $self.HandleAutoDetectPath("VTubeStudio") }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveVTubeStudioSettingsButton").add_Click({ $self.HandleSaveVTubeStudioSettings() }.GetNewClosure())

            # --- Global Settings Tab ---
            $this.uiManager.Window.FindName("LanguageCombo").add_SelectionChanged({ $self.HandleLanguageSelectionChanged() }.GetNewClosure())
            $this.uiManager.Window.FindName("SaveGlobalSettingsButton").add_Click({ $self.HandleSaveGlobalSettings() }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectSteamButton").add_Click({ $self.HandleAutoDetectPath("Steam") }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectEpicButton").add_Click({ $self.HandleAutoDetectPath("Epic") }.GetNewClosure())
            $this.uiManager.Window.FindName("AutoDetectRiotButton").add_Click({ $self.HandleAutoDetectPath("Riot") }.GetNewClosure())

            # --- Menu Items ---
            $this.uiManager.Window.FindName("RefreshGameListMenuItem").add_Click({ $self.HandleRefreshGameList() }.GetNewClosure())
            $this.uiManager.Window.FindName("RefreshManagedAppsListMenuItem").add_Click({ $self.HandleRefreshManagedAppsList() }.GetNewClosure())
            $this.uiManager.Window.FindName("RefreshAllMenuItem").add_Click({ $self.HandleRefreshAll() }.GetNewClosure())
            $this.uiManager.Window.FindName("CreateAllShortcutsMenuItem").add_Click({ $self.HandleCreateAllShortcuts() }.GetNewClosure())
            $this.uiManager.Window.FindName("CheckUpdateMenuItem").add_Click({ $self.HandleCheckUpdate() }.GetNewClosure())
            $feedbackMenuItem = $this.uiManager.Window.FindName("FeedbackMenuItem")
            if ($feedbackMenuItem) {
                $feedbackMenuItem.add_Click({ $self.HandleSendFeedback() }.GetNewClosure())
            } else {
                Write-Verbose "FeedbackMenuItem not found"
            }
            $this.uiManager.Window.FindName("AboutMenuItem").add_Click({ $self.HandleAbout() }.GetNewClosure())

            Write-Verbose "[OK] ConfigEditorEvents: All UI event handlers registered successfully"
        } catch {
            Write-Verbose "[ERROR] ConfigEditorEvents: Failed to register event handlers - $($_.Exception.Message)"
            throw $_
        }
    }
}
