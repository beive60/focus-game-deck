# **Focus Game Deck GUI Configuration Editor - Design Document**

| Document ID | FGD-GUI-001 |
| :---- | :---- |
| **Creation Date** | September 23, 2025 |
| **Author** | Gemini |
| **Version** | 1.0 |

---

## **Part 1: Basic Design Document (BD / System Specification)**

### **1. Overview**

This document defines the basic design of an application (hereinafter referred to as "this app") that enables intuitive editing of the configuration file (`config.json`) for the PowerShell script "Focus Game Deck" through a Graphical User Interface (GUI).

### **2. Development Background and Purpose**

The configuration of `Focus Game Deck` currently relies on manual editing of a JSON-formatted text file. While this approach offers high flexibility, it presents the following challenges:

* **Syntax Error Risk**: Users without JSON knowledge may cause the entire script to malfunction due to missing commas or bracket mismatches.
* **Adoption Barriers**: The configuration process becomes a psychological barrier for users unfamiliar with text editing.

This application aims to solve these issues and realize the project's guiding principle of being "intuitively usable even for gamers who aren't tech-savvy" [/doc/CONTRIBUTING.md]. This functionality is also positioned as the highest priority issue in `ROADMAP.md`.

### **3. System Configuration**

* **Runtime Environment**: Windows 10 / 11
* **Technologies Used**:
  * **Language/Framework**: PowerShell + WPF (Windows Presentation Foundation)
  * **Rationale**: High technical affinity with the main project, enabling the construction of lightweight native applications aligned with the philosophy in `CONTRIBUTING.md`.

**File Structure**:
focus-game-deck/
└─ gui/
   ├─ ConfigEditor.ps1   (Main logic of this app)
   └─ MainWindow.xaml    (UI definition of this app)

* **Distribution Format**: Distributed as a single executable file (`.exe`) using tools like `PS2EXE`.

### **4. Functional Requirements**

| ID | Function Name | Overview |
| :---- | :---- | :---- |
| FR-01 | **Configuration File Loading** | Load `../config/config.json` at startup and display contents on screen. If not found, load `../config/config.json.sample`. |
| FR-02 | **Game Settings Management** | Add, edit, and delete managed games. |
| FR-03 | **Managed Apps Settings Management** | Add, edit, and delete controlled applications. |
| FR-04 | **Global Settings Management** | Edit overall settings such as main paths and display language. |
| FR-06 | **Integration Apps Settings Management** | Configure integration apps (OBS, Discord, VTube Studio) including connection settings and behavior options. |
| FR-05 | **Configuration File Saving** | Save all changes made on screen as syntactically correct JSON to `../config/config.json`. |
| FR-08 | **Validation** | Check input value validity, prevent saving if errors exist, and provide user feedback. |

### **5. Non-Functional Requirements**

| ID | Type | Content |
| :---- | :---- | :---- |
| NFR-01 | **Performance** | Application should be lightweight, start quickly, and minimize resource consumption. |
| NFR-02 | **Usability** | Provide intuitive UI and prevent user input errors by utilizing file selection dialogs and dropdown lists. |
| NFR-03 | **Extensibility** | Design with separated UI and logic to facilitate future additions of configuration items (other platform support, profile functionality, etc.). |
| NFR-04 | **Multi-language Support** | Consider design where UI strings can be loaded from external files in the future. |
| NFR-05 | **Responsive Design** | UI layout should adjust appropriately to window size changes. |

---

## **Part 2: Functional Design Document (FD / Functional Design)**

### **1. Screen Design**

This application consists of a single window, with main functions switched through three tabs.

* **Window Title**: `Focus Game Deck - Configuration Editor`
* **UI Structure**:
  * **Tab Control**:
    * `Game Settings` tab
    * `Managed Apps Settings` tab
    * `Global Settings` tab
    * `OBS Integration Settings` tab
    * `Discord Integration Settings` tab
    * `VTube Studio Integration Settings` tab
  * **Footer**:
    * `Save` button
    * `Close` button

**(See wireframes for details)**

### **2. Functional Details**

#### **2.1. Common Processing**

* **Startup Process**:
  1. `ConfigEditor.ps1` is executed.
  2. Load WPF assemblies.
  3. Read `MainWindow.xaml` and create UI objects.
  4. Load configuration file according to `FR-01` and set values to UI controls (data binding).
  5. Register event handlers for each UI control.
  6. Display window.

#### **2.2. "Game Settings" Tab**

* **Screen Layout**: Game list box on the left, detailed settings panel for selected game on the right.
* **Data Flow**:
  * At startup, display keys from `games` object in `config.json` in the left list box.
  * When user selects a list box item, `SelectionChanged` event fires.
  * Retrieve configuration values (name, steamAppId, etc.) corresponding to the selected game ID from `config.json` data and display in right panel controls.
  * `appsToManage` checkbox list is dynamically generated based on all app names registered in the "Managed Apps Settings" tab.
* **Events**:
  * `Add New` button: Add "New Game" to list and clear right panel.
  * `Delete` button: Delete the currently selected game from the list.

#### **2.3. "Managed Apps Settings" Tab**

* **Screen Layout**: App list box on the left, detailed settings panel for selected app on the right.
* **Data Flow**:
  * At startup, display keys from `managedApps` object in `config.json` in the left list box.
  * When list box is selected, display corresponding app details in right panel.
  * `gameStartAction`/`gameEndAction` are dropdown lists with fixed values ("start-process", "stop-process", "toggle-hotkeys", "none").
* **Events**:
  * `Browse` button: Open executable file selection dialog and set selected path to `Executable Path` text box.

#### **2.4. "Global Settings" Tab**

* **Screen Layout**: Composed of two groups: `Path Settings` and `Overall Settings`.
* **Data Flow**:
  1. At startup, display values from `paths` and `language` in `config.json` to corresponding controls.

#### **2.5. "OBS Integration Settings" Tab**

* **Screen Layout**: Single group for OBS connection and replay buffer settings.
* **Data Flow**:
  1. At startup, display values from `integrations.obs` in `config.json` to corresponding controls.
  2. `Password` text box masks input values using SecureString encryption.
  3. Executable path is loaded from `integrations.obs.path`.

#### **2.6. "Discord Integration Settings" Tab**

* **Screen Layout**: Single group for Discord Rich Presence configuration.
* **Data Flow**:
  1. At startup, display values from `integrations.discord` in `config.json` to corresponding controls.

#### **2.7. "VTube Studio Integration Settings" Tab**

* **Screen Layout**: Single group for VTube Studio WebSocket connection settings.
* **Data Flow**:
  1. At startup, display values from `integrations.vtubeStudio` in `config.json` to corresponding controls.

#### **2.8. Footer and Save Behavior**

##### **Auto-save + Manual Save Hybrid Model (Phase 1 - Implemented)**

The configuration editor implements a hybrid save model that combines immediate in-memory updates with automatic file persistence:

* **Immediate ConfigData Updates**:
  * Game display name and managed app display name changes are immediately reflected in the in-memory ConfigData object
  * TextChanged event handlers update ConfigData synchronously without file I/O
  * UI synchronization occurs on tab switches (e.g., AppsToManagePanel updates with latest display names)
  * Technical implementation uses PowerShell closures with explicit variable capture (`GetNewClosure()`)

* **Automatic Save on Window Close**:
  * When the window is closed, any pending changes are automatically saved to `config.json`
  * No confirmation dialog is displayed during auto-save
  * Validation is performed before saving; errors prevent window close and display user feedback

* **Delete Operations**:
  * Game and managed app deletion no longer requires confirmation dialogs
  * Changes are immediately marked as modified in ConfigData
  * Actual file persistence occurs on window close

* **Event Handler Pattern**:
  * TextChanged handlers are temporarily removed during programmatic data loading
  * Re-registered in finally blocks to prevent null reference errors
  * Captured window and state manager references before creating closures to ensure proper scope access

* **`Save` Button (Manual Save)**:
  1. `Click` event fires.
  2. Retrieve current values from UI controls of all tabs.
  3. Create new PowerShell object with same hierarchical structure as `config.json` and store retrieved values.
  4. Convert created object to JSON string using `ConvertTo-Json`.
  5. According to `FR-05`, overwrite save to `../config/config.json` as a file.
  6. Display "Saved" confirmation message.
  7. Clear modified flag in state manager.

* **Future Enhancements (Phase 2-3)**:
  * Phase 2: Auto-backup timer (1-minute interval to `.autosave` file)
  * Phase 2: Startup recovery from `.autosave` with user prompt
  * Phase 3: Title bar indicator for unsaved changes
  * Phase 3: Ctrl+S keyboard shortcut for manual save

#### **2.9. Security and Risk Management Requirements**

Security requirements specific to the GUI configuration editor are defined as follows:

* **Configuration File Security**:
  * Password Encryption: Sensitive information such as OBS/VTube Studio WebSocket passwords is encrypted using Windows DPAPI (SecureString)
  * Configuration Validation: Detect and prevent invalid values and dangerous path specifications
  * File Path Verification: Validate the legitimacy of executable file paths and directory paths

* **Input Validation**:
  * File Path Existence Check: Verify that specified file paths actually exist
  * Numeric Range Check: Validate that numeric items like port numbers are within appropriate ranges
  * JSON Structure Integrity Check: Ensure configuration file structure is correct
  * Required Field Check: Verify that necessary configuration items are entered

* **Application Security**:
  * Digital Signature: Official distribution versions must be signed with code signing certificates
  * Transparency Assurance: Ensure code safety through open source

#### **2.7. Alpha Test Support Features**

To support alpha test implementation requirements, the following features are planned:

* **Feedback Collection Support**: Features to easily export error information and configuration status
* **Tester Support**: Introduction support through automatic generation of configuration examples and preset features
* **Version Management**: Configuration file versioning and migration features

### **3. Data Structure (Mapping with `config.json`)**

The data structure of `config.json` that this application edits conforms to `config.json.sample`. Each UI control corresponds one-to-one with each key in this JSON file. (See `./config/config.json.sample` for details).

## Screen Design (Wireframes)

We propose a simple design that separates main configuration items into tabs for intuitive user operation.

### Main Window

Overall structure of the application. Configuration items are clearly separated into three main tabs with operation buttons at the bottom.

```txt
+-----------------------------------------------------------------+
| Focus Game Deck - Configuration Editor                         |
+-----------------------------------------------------------------+
| | Game Settings | | Managed Apps | | Global Settings | | OBS | | Discord | | VTube Studio |        |
+-----------------------------------------------------------------+
|                                                                 |
|                                                                 |
|         (Selected tab content displayed here)                  |
|                                                                 |
|                                                                 |
|                                                                 |
|                                                                 |
|                                                                 |
+-----------------------------------------------------------------+
|                                               [ Save ] [ Close ] |
+-----------------------------------------------------------------+
```

* Tab 1: Game Settings
  * Screen for adding, editing, and deleting games the user wants to manage. Select a game from the left list and configure details in the right panel.

appsToManage items are automatically displayed as a checkbox list of app names registered in the "Managed Apps Settings" tab.

```txt
+-----------------------------------------------------------------+
| Game List                | Selected Game Details               |
| +-----------------------+ | ----------------------------------- |
| | Apex Legends          | | GameID:     [apex____________]      |
| | Dead by Daylight      | | Display Name:[Apex Legends____]     |
| |                       | | Steam AppID:[1172470_________]      |
| +-----------------------+ | Process Name:[r5apex*_________]     |
| [ Add New... ] [ Delete ] |                                     |
|                           | Managed Apps:                       |
|                           | [x] noWinKey                        |
|                           | [x] autoHotkey                      |
|                           | [x] luna                            |
|                           | [x] obs                             |
|                           | [x] clibor                          |
+-----------------------------------------------------------------+
```

* Tab 2: Managed Apps Settings
  * Screen for registering applications to control when games start/end. Basic structure is similar to "Game Settings" tab.

Action items use dropdown lists to prevent configuration errors.

```txt
+-----------------------------------------------------------------+
| App List                 | Selected App Details                |
| +-----------------------+ | ----------------------------------- |
| | noWinKey              | | App ID:       [noWinKey________]    |
| | autoHotkey            | | Executable Path:[C:/Apps\NWK..][Browse] |
| | clibor                | | Process Name: [NoWinKey________]    |
| | luna                  | |                                     |
| +-----------------------+ | Game Start Action:                  |
| [ Add New... ] [ Delete ] |   [start-process          ^]       |
|                           | Game End Action:                    |
|                           |   [stop-process           ^]       |
|                           | Launch Args:    [________________] |
+-----------------------------------------------------------------+
```

* Tab 3: Global Settings
  * Screen for managing overall configuration items not dependent on specific games or apps.

Password input field displays with * masking.

Language dropdown is automatically generated based on language keys present in messages.json.

```txt
+-----------------------------------------------------------------+
| Path Settings                                                  |
|   Steam.exe Path:   [C:/Program Files..] [Browse]              |
| --------------------------------------------------------------- |
| Overall Settings                                               |
|   Display Language: [English (en)         ^]                   |
|                                                                 |
+-----------------------------------------------------------------+
```

* Tab 4: OBS Integration Settings
  * Screen for configuring OBS Studio WebSocket connection and replay buffer behavior.

```txt
+-----------------------------------------------------------------+
| OBS Integration Settings                                        |
|   Executable Path: [C:/Program Files/obs-studio/bin/64bit/obs64.exe] [Browse] |
|   Host:       [localhost_______]  Port: [4455__]               |
|   Password:   [****************]                               |
|   [x] Enable replay buffer during games                        |
+-----------------------------------------------------------------+
```

* Tab 5: Discord Integration Settings
  * Screen for configuring Discord Rich Presence integration.

```txt
+-----------------------------------------------------------------+
| Discord Integration Settings                                    |
|   [x] Enable Discord Rich Presence                             |
|   Application ID: [1234567890123456789_]                       |
+-----------------------------------------------------------------+
```

* Tab 6: VTube Studio Integration Settings
  * Screen for configuring VTube Studio WebSocket connection.

```txt
+-----------------------------------------------------------------+
| VTube Studio Integration Settings                              |
|   Host:       [localhost_______]  Port: [8001__]               |
+-----------------------------------------------------------------+
```

---

## **Supplement: Implementation Design Philosophy**

### **Technical Choice Records**

The following design decisions were made for implementing this GUI configuration editor. These decisions consider future maintainability and extensibility.

#### **1. GUI Technology: PowerShell + WPF**

**Selection Rationale:**

* **Consistency**: Implementation in the same PowerShell environment as the main engine
* **Lightweight**: No additional runtime required, utilizes Windows standard features
* **Distribution Ease**: Single executable file creation possible through ps2exe

#### **2. Internationalization Method: JSON External Resources**

**Technical Background:**

Regarding Japanese character garbling issues in PowerShell's `[System.Windows.MessageBox]`, the following methods were verified:

1. **Direct Unicode Code Point Specification** [VERIFIED]
2. **JSON External Resource Files** (Adopted)
3. **PowerShell Embedded Strings** [NOT VIABLE]

**Adoption Decision:**

* **Maintainability**: Easy translation and message changes through separation of strings and code
* **Standard Approach**: Implementation following common internationalization patterns
* **Extensibility**: Foundation for future multi-language support

**Technical Details:**

```json
{
    "messages": {
        "configSaved": "/u8a2d/u5b9a/u304c/u4fdd/u5b58/u3055/u308c/u307e/u3057/u305f/u3002"
    }
}
```

#### **3. Architecture Pattern**

**File Structure:**

```text
gui/
├── MainWindow.xaml          # UI Layout (no x:Class attribute)
├── ConfigEditor.ps1         # Main Logic
├── messages.json           # Internationalization Resources
└── Build-ConfigEditor.ps1  # Build Script
```

**Design Patterns:**

* **MVVM-like**: Separation of XAML and PowerShell
* **Event-Driven**: Handle UI operations like button clicks with handlers
* **Configuration-Driven**: All behavior controlled by config.json

#### **4. Error Handling Strategy**

**Message Display Patterns:**

```powershell
# Recommended Pattern: Use JSON External Resources
Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"

# Traditional Pattern: Direct Specification (Not Recommended)
[System.Windows.MessageBox]::Show("設定が保存されました")
```

### **Performance Optimization**

1. **Startup Time Reduction**: Lazy loading of JSON
2. **Memory Efficiency**: Consider differences between PowerShell ISE vs standard PowerShell
3. **UI Responsiveness**: Consider asynchronous execution for heavy processing

### **Future Extension Plans**

* **Theme Functionality**: UI color setting customization
* **Plugin Support**: Integration with external scripts
* **Cloud Sync**: External storage and sharing of configurations

---

*This design philosophy is recorded to ensure the technical continuity of the Focus Game Deck project and enable new developers to continue development with consistent policies.*
