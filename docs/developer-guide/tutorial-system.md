# Tutorial System

The tutorial system provides an interactive first-run experience for new users of Focus Game Deck.

## Overview

When a user launches the Configuration Editor for the first time, they are presented with an interactive tutorial that walks them through the key features and setup steps. The tutorial:

- Shows screenshots and descriptions of 5 key areas
- Provides Next, Back, and Skip navigation
- Links to detailed documentation
- Automatically marks itself as completed after viewing
- Never shows again after completion

## Architecture

The tutorial system consists of the following components:

### Files

- **`gui/TutorialWindow.xaml`** - XAML definition for the tutorial window UI
- **`gui/ConfigEditor.Tutorial.ps1`** - PowerShell module with tutorial logic
- **`assets/tutorial/`** - Directory for tutorial screenshot images
- **`localization/*.json`** - Localized tutorial text in all supported languages

### Key Classes and Functions

#### `TutorialManager` Class

The main class that manages the tutorial window and navigation.

**Constructor:**
```powershell
TutorialManager([Object]$localization, [string]$appRoot)
```

**Key Methods:**
- `Show()` - Display the tutorial window and return completion status
- `NavigateNext()` - Move to the next tutorial page
- `NavigateBack()` - Move to the previous tutorial page
- `SkipTutorial()` - Close tutorial without completing
- `UpdatePage()` - Refresh the current page content

#### Helper Functions

**`Test-TutorialCompleted`**
```powershell
Test-TutorialCompleted -ConfigData $configData
```
Checks if the tutorial has been completed by looking for the `hasCompletedTutorial` flag in `config.json`.

**`Set-TutorialCompleted`**
```powershell
Set-TutorialCompleted -ConfigData $configData
```
Marks the tutorial as completed in the configuration data.

**`Show-Tutorial`**
```powershell
Show-Tutorial -Localization $localization -AppRoot $appRoot
```
Shows the tutorial window and returns whether it was completed.

## Tutorial Pages

The tutorial consists of 5 pages:

1. **Welcome** - Introduction to Focus Game Deck and its key features
2. **Game Registration** - How to add and configure games
3. **Application Management** - Setting up managed applications
4. **Integration Apps** - OBS, Discord, and VTube Studio setup
5. **Game Launching** - Creating shortcuts and launching games

## Configuration Storage

The tutorial completion status is stored in `config.json`:

```json
{
  "globalSettings": {
    "hasCompletedTutorial": true
  }
}
```

## Localization

All tutorial text is localized and stored in the localization JSON files. Required keys:

- `tutorialWindowTitle` - Window title
- `tutorialWelcomeTitle` - Welcome screen title
- `tutorialWelcomeSubtitle` - Welcome screen subtitle
- `tutorialSkipButton` - Skip button text
- `tutorialBackButton` - Back button text
- `tutorialNextButton` - Next button text
- `tutorialFinishButton` - Finish button text (on last page)
- `tutorialPage1Title` through `tutorialPage5Title` - Page titles
- `tutorialPage1Description` through `tutorialPage5Description` - Page descriptions

## Screenshot Images

Tutorial screenshots should be placed in `assets/tutorial/` with the following names:

- `tutorial-welcome.png` - Welcome/overview
- `tutorial-game-registration.png` - Game registration interface
- `tutorial-app-registration.png` - Managed apps configuration
- `tutorial-obs-integration.png` - OBS integration setup
- `tutorial-game-launching.png` - Game launching demonstration

**Image Requirements:**
- Format: PNG
- Recommended size: 1200x800 pixels or similar aspect ratio
- File size: Keep under 500KB per image

If images are not present, the tutorial will still function but won't display screenshots.

## Integration Flow

The tutorial is integrated into ConfigEditor.ps1 startup flow:

1. ConfigEditor initializes normally
2. After UI is ready but before main window is shown, check `Test-TutorialCompleted`
3. If first run (returns `false`), show tutorial via `Show-Tutorial`
4. If tutorial is completed (not skipped), mark as completed via `Set-TutorialCompleted`
5. Save the updated configuration
6. Continue to show main ConfigEditor window

## Testing

Run the test suite to verify tutorial functionality:

```powershell
.\test\scripts\gui\Test-GUI-Tutorial.ps1
```

This tests:
- Tutorial module loading
- XAML validation
- Localization key presence
- First-run detection functions
- ConfigEditor integration

## Build System Integration

The tutorial XAML is automatically included in the build process:

- `Embed-XamlResources.ps1` automatically embeds `TutorialWindow.xaml` as `$Global:Xaml_TutorialWindow`
- `Invoke-PsScriptBundler.ps1` bundles the tutorial module with ConfigEditor
- Tutorial assets directory is included in distribution packages

## Future Enhancements

Potential improvements for the tutorial system:

- Add animated GIFs or video demonstrations
- Interactive elements (clickable areas)
- Progress tracking for partial completion
- Ability to re-launch tutorial from Help menu
- Context-sensitive help linked to tutorial pages
- Customizable tutorial content via configuration

## Troubleshooting

### Tutorial Doesn't Show

- Check if `hasCompletedTutorial` is set to `true` in `config.json`
- Manually set it to `false` or remove it to show tutorial again
- Ensure ConfigEditor is not running in headless mode

### Missing Localization

- Run `Test-GUI-Tutorial.ps1` to check for missing keys
- Ensure all required tutorial keys are present in language files
- Check for JSON syntax errors in localization files

### Images Not Displaying

- Verify images exist in `assets/tutorial/` directory
- Check image file names match exactly (case-sensitive)
- Ensure images are valid PNG format
- Tutorial will continue to work without images

## See Also

- [GUI Design Specifications](gui-design.md)
- [Localization Guide](localization-guide.md)
- [Architecture Guide](architecture.md)
