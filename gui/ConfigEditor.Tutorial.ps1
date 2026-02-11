# ConfigEditor.Tutorial.ps1
# Tutorial system for first-run experience

<#
.SYNOPSIS
    Tutorial module for Focus Game Deck configuration editor.

.DESCRIPTION
    Provides a tutorial window with carousel navigation for first-time users.
    Shows screenshots and descriptions of key features with Next, Back, and Skip options.
#>

class TutorialManager {
    [Object]$Window
    [Object]$Localization
    [string]$AppRoot
    [int]$CurrentPage = 0
    [array]$TutorialPages
    [hashtable]$Controls = @{}

    TutorialManager([Object]$localization, [string]$appRoot) {
        $this.Localization = $localization
        $this.AppRoot = $appRoot
        $this.InitializeTutorialPages()
    }

    [void]InitializeTutorialPages() {
        # Define tutorial pages with title, description, and image
        $this.TutorialPages = @(
            @{
                TitleKey = "tutorialPage1Title"
                DescriptionKey = "tutorialPage1Description"
                ImageName = "tutorial-welcome.png"
            },
            @{
                TitleKey = "tutorialPage2Title"
                DescriptionKey = "tutorialPage2Description"
                ImageName = "tutorial-game-registration.png"
            },
            @{
                TitleKey = "tutorialPage3Title"
                DescriptionKey = "tutorialPage3Description"
                ImageName = "tutorial-app-registration.png"
            },
            @{
                TitleKey = "tutorialPage4Title"
                DescriptionKey = "tutorialPage4Description"
                ImageName = "tutorial-obs-integration.png"
            },
            @{
                TitleKey = "tutorialPage5Title"
                DescriptionKey = "tutorialPage5Description"
                ImageName = "tutorial-game-launching.png"
            }
        )
    }

    [void]LoadWindow() {
        try {
            # Load XAML content
            $xamlContent = $null
            
            # Check if embedded XAML variable exists (production/bundled mode)
            if ($Global:Xaml_TutorialWindow) {
                Write-Verbose "Loading tutorial XAML from embedded resource"
                $xamlContent = $Global:Xaml_TutorialWindow
            } else {
                # Fallback to file-based loading (development mode)
                Write-Verbose "Loading tutorial XAML from file (development mode)"
                $xamlPath = Join-Path -Path $this.AppRoot -ChildPath "gui/TutorialWindow.xaml"
                
                if (-not (Test-Path $xamlPath)) {
                    throw "Tutorial XAML file not found: $xamlPath"
                }
                
                $xamlContent = Get-Content -Path $xamlPath -Raw -Encoding UTF8
            }
            
            if ([string]::IsNullOrWhiteSpace($xamlContent)) {
                throw "Tutorial XAML content is empty or null"
            }

            # Replace localization placeholders
            $xamlContent = $this.ReplaceLocalizationPlaceholders($xamlContent)

            # Load XAML using string-based type resolution for ps2exe compatibility
            $xmlReaderType = "System.Xml.XmlReader" -as [type]
            $stringReaderType = "System.IO.StringReader" -as [type]
            $xamlReaderType = "System.Windows.Markup.XamlReader" -as [type]
            
            $stringReader = $stringReaderType::new($xamlContent)
            $reader = $xmlReaderType::Create($stringReader)
            $this.Window = $xamlReaderType::Load($reader)
            $reader.Close()

            # Get control references
            $this.Controls.TutorialTitle = $this.Window.FindName("TutorialTitle")
            $this.Controls.TutorialSubtitle = $this.Window.FindName("TutorialSubtitle")
            $this.Controls.TutorialDescription = $this.Window.FindName("TutorialDescription")
            $this.Controls.TutorialImage = $this.Window.FindName("TutorialImage")
            $this.Controls.PageIndicator = $this.Window.FindName("PageIndicator")
            $this.Controls.BackButton = $this.Window.FindName("BackButton")
            $this.Controls.NextButton = $this.Window.FindName("NextButton")
            $this.Controls.SkipButton = $this.Window.FindName("SkipButton")
            $this.Controls.DocumentationLink = $this.Window.FindName("DocumentationLink")

            Write-Verbose "Tutorial window loaded successfully"
        }
        catch {
            Write-Error "Failed to load tutorial window: $_"
            throw
        }
    }

    [string]ReplaceLocalizationPlaceholders([string]$xaml) {
        # Replace all [KEY] patterns with localized strings
        # Pattern matches camelCase keys inside square brackets
        $pattern = '\[([a-zA-Z][a-zA-Z0-9_]*)\]'
        $xaml = [regex]::Replace($xaml, $pattern, {
                param($match)
                $key = $match.Groups[1].Value
                $localizedText = $this.GetLocalizedMessage($key)
                return $localizedText
            })
        return $xaml
    }

    [string]GetLocalizedMessage([string]$key) {
        try {
            # ConfigEditorLocalization has a Messages property
            $messages = $null
            if ($this.Localization -is [ConfigEditorLocalization]) {
                $messages = $this.Localization.Messages
            } elseif ($this.Localization.PSObject.Properties['Messages']) {
                $messages = $this.Localization.Messages
            } else {
                # Assume it's the messages object directly
                $messages = $this.Localization
            }

            if ($messages -and $messages.PSObject.Properties[$key]) {
                return $messages.$key
            }
            return "[$key]"
        }
        catch {
            return "[$key]"
        }
    }

    [void]RegisterEventHandlers() {
        $self = $this

        # Back button
        $this.Controls.BackButton.add_Click({
            $self.NavigateBack()
        }.GetNewClosure())

        # Next button
        $this.Controls.NextButton.add_Click({
            $self.NavigateNext()
        }.GetNewClosure())

        # Skip button
        $this.Controls.SkipButton.add_Click({
            $self.SkipTutorial()
        }.GetNewClosure())

        # Documentation link
        if ($this.Controls.DocumentationLink) {
            $this.Controls.DocumentationLink.add_MouseLeftButtonUp({
                $self.OpenDocumentation()
            }.GetNewClosure())
        }
    }

    [void]NavigateBack() {
        if ($this.CurrentPage -gt 0) {
            $this.CurrentPage--
            $this.UpdatePage()
        }
    }

    [void]NavigateNext() {
        if ($this.CurrentPage -lt ($this.TutorialPages.Count - 1)) {
            $this.CurrentPage++
            $this.UpdatePage()
        }
        else {
            # Last page - close tutorial
            $this.CompleteTutorial()
        }
    }

    [void]SkipTutorial() {
        # Mark as skipped (DialogResult = false means not completed)
        $this.Window.DialogResult = $false
        $this.Window.Close()
    }

    [void]CompleteTutorial() {
        # Mark as completed (DialogResult = true means completed successfully)
        $this.Window.DialogResult = $true
        $this.Window.Close()
    }

    [void]UpdatePage() {
        $currentPageData = $this.TutorialPages[$this.CurrentPage]

        # Update title
        $this.Controls.TutorialTitle.Text = $this.GetLocalizedMessage($currentPageData.TitleKey)

        # Update description
        $this.Controls.TutorialDescription.Text = $this.GetLocalizedMessage($currentPageData.DescriptionKey)

        # Update page indicator
        $pageNumber = $this.CurrentPage + 1
        $totalPages = $this.TutorialPages.Count
        $this.Controls.PageIndicator.Text = "$pageNumber / $totalPages"

        # Update image
        $this.LoadTutorialImage($currentPageData.ImageName)

        # Update button states
        $this.Controls.BackButton.IsEnabled = ($this.CurrentPage -gt 0)

        # Update Next button text for last page
        if ($this.CurrentPage -eq ($this.TutorialPages.Count - 1)) {
            $this.Controls.NextButton.Content = $this.GetLocalizedMessage("tutorialFinishButton")
        }
        else {
            $this.Controls.NextButton.Content = $this.GetLocalizedMessage("tutorialNextButton")
        }
    }

    [void]LoadTutorialImage([string]$imageName) {
        try {
            # Use string-based type resolution for ps2exe compatibility
            $bitmapImageType = "System.Windows.Media.Imaging.BitmapImage" -as [type]
            $uriType = "System.Uri" -as [type]
            $uriKindType = "System.UriKind" -as [type]
            $bitmapCacheOptionType = "System.Windows.Media.Imaging.BitmapCacheOption" -as [type]
            $visibilityType = "System.Windows.Visibility" -as [type]
            
            # Try to load image from assets/tutorial directory
            $imagePath = Join-Path -Path $this.AppRoot -ChildPath "assets/tutorial/$imageName"
            
            if (Test-Path $imagePath) {
                $bitmap = $bitmapImageType::new()
                $bitmap.BeginInit()
                $bitmap.UriSource = $uriType::new($imagePath, $uriKindType::Absolute)
                $bitmap.CacheOption = $bitmapCacheOptionType::OnLoad
                $bitmap.EndInit()
                $bitmap.Freeze()
                
                $this.Controls.TutorialImage.Source = $bitmap
                $this.Controls.TutorialImage.Visibility = $visibilityType::Visible
                Write-Verbose "Loaded tutorial image: $imagePath"
            }
            else {
                # Hide image if not found
                $this.Controls.TutorialImage.Visibility = $visibilityType::Collapsed
                Write-Verbose "Tutorial image not found: $imagePath"
            }
        }
        catch {
            Write-Warning "Failed to load tutorial image: $_"
            # Use string-based type resolution for error handling
            $visibilityType = "System.Windows.Visibility" -as [type]
            $this.Controls.TutorialImage.Visibility = $visibilityType::Collapsed
        }
    }

    [void]OpenDocumentation() {
        try {
            $url = "https://github.com/beive60/focus-game-deck/blob/main/README.md"
            Start-Process $url
        }
        catch {
            Write-Warning "Failed to open documentation: $_"
        }
    }

    [bool]Show() {
        try {
            $this.LoadWindow()
            $this.RegisterEventHandlers()
            $this.CurrentPage = 0
            $this.UpdatePage()
            
            $result = $this.Window.ShowDialog()
            return [bool]$result
        }
        catch {
            Write-Error "Failed to show tutorial: $_"
            return $false
        }
    }
}

# Helper function to check if tutorial has been completed
function Test-TutorialCompleted {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$ConfigData
    )

    try {
        # Check if globalSettings exists and has hasCompletedTutorial flag
        if ($ConfigData.PSObject.Properties['globalSettings'] -and 
            $ConfigData.globalSettings.PSObject.Properties['hasCompletedTutorial']) {
            return [bool]$ConfigData.globalSettings.hasCompletedTutorial
        }
        return $false
    }
    catch {
        Write-Verbose "Error checking tutorial completion status: $_"
        return $false
    }
}

# Helper function to mark tutorial as completed
function Set-TutorialCompleted {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$ConfigData
    )

    try {
        # Ensure globalSettings exists
        if (-not $ConfigData.PSObject.Properties['globalSettings']) {
            $ConfigData | Add-Member -MemberType NoteProperty -Name 'globalSettings' -Value ([PSCustomObject]@{})
        }

        # Add or update hasCompletedTutorial flag
        if ($ConfigData.globalSettings.PSObject.Properties['hasCompletedTutorial']) {
            $ConfigData.globalSettings.hasCompletedTutorial = $true
        }
        else {
            $ConfigData.globalSettings | Add-Member -MemberType NoteProperty -Name 'hasCompletedTutorial' -Value $true
        }

        Write-Verbose "Marked tutorial as completed in configuration"
        return $true
    }
    catch {
        Write-Warning "Failed to mark tutorial as completed: $_"
        return $false
    }
}

# Helper function to show tutorial
function Show-Tutorial {
    param(
        [Parameter(Mandatory = $true)]
        [Object]$Localization,
        
        [Parameter(Mandatory = $true)]
        [string]$AppRoot
    )

    try {
        Write-Verbose "Showing tutorial window"
        $tutorialManager = [TutorialManager]::new($Localization, $AppRoot)
        $result = $tutorialManager.Show()
        Write-Verbose "Tutorial completed: $result"
        return $result
    }
    catch {
        Write-Error "Failed to show tutorial: $_"
        return $false
    }
}
