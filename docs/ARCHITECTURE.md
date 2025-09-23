# Focus Game Deck - Architecture & Design Philosophy

## Overview

Focus Game Deck is a PowerShell-based tool for gaming environment automation and OBS streaming management. This document explains th## Contribution Guidelines

To maintain this design philosophy, please prioritize the following:

1. **Security First**: Always consider anti-cheat false positive risks with non-invasive design
2. **Maintain Lightweight Nature**: Carefully consider adding new dependencies
3. **PowerShell First**: Prioritize PowerShell solutions over migration to other languages
4. **Configuration-Driven**: Control through configuration files rather than hard-coding
5. **Internationalization Support**: All new messages must be externalized to JSON resourcest's design philosophy, rationale for technical choices, and implementation architecture.

## Design Philosophy

### 1. Lightweight and Simple

- **PowerShell + WPF**: Utilizes Windows standard features while avoiding additional runtimes or heavy frameworks
- **Minimal Dependencies**: Uses only .NET Framework standard features
- **Single Executable**: Simplified distribution through ps2exe compilation

### 2. Maintainability and Extensibility

- **Configuration-Driven Design**: All behavior controlled through `config.json`
- **Modular Structure**: Separation of GUI, core functionality, and configuration management
- **Internationalization Support**: Multi-language support through JSON external resources

### 3. Usability

- **Intuitive GUI**: Three-tab structure for feature categorization (Game Settings, Managed Apps Settings, Global Settings)
- **Batch File Launch**: Simple startup without requiring technical knowledge
- **Error Handling**: Appropriate error message display

## Technical Architecture

### System Structure

```text
Focus Game Deck
├── Core Engine (PowerShell)
│   ├── src/Invoke-FocusGameDeck.ps1     # Main engine
│   ├── scripts/Create-Launchers.ps1     # Launcher generation
│   └── launch_*.bat                     # Game-specific launch scripts
│
├── Configuration Management
│   ├── config/config.json               # Main configuration file
│   ├── config/config.json.sample        # Sample configuration
│   └── config/messages.json             # Internationalization resources (for GUI)
│
├── GUI Module (PowerShell + WPF)
│   ├── gui/MainWindow.xaml              # UI layout definition
│   ├── gui/ConfigEditor.ps1             # GUI control logic
│   ├── gui/messages.json                # GUI message resources
│   └── gui/Build-ConfigEditor.ps1       # Build script
│
└── Documentation & Testing
    ├── docs/                            # Design and specification documents
    ├── test/                            # Test scripts
    └── DOCUMENTATION-INDEX.md           # Documentation index
```

### Design Decision Records

#### 1. GUI Technology Choice: PowerShell + WPF

**Options Considered:**

- Windows Forms
- Electron/Web Technologies
- .NET WinForms/WPF (C#)
- PowerShell + WPF ✅

**Selection Rationale:**

- **Lightweight**: No additional runtime required, uses Windows standard features
- **Consistency**: Implementation using the same PowerShell as the main engine
- **Distribution Ease**: Single executable file creation through ps2exe
- **Development Efficiency**: Leverages existing PowerShell skills

#### 2. Internationalization Method: JSON External Resources

**Options Considered:**

- Direct Unicode code point specification
- PowerShell embedded strings
- JSON external resource files ✅

**Selection Rationale:**

- **Character Encoding Solution**: Avoids Japanese character garbling issues in PowerShell MessageBox
- **Maintainability**: Separation of strings and code
- **Extensibility**: Foundation for future multi-language support
- **Standard Approach**: Follows common internationalization patterns

**Technical Details:**

- Uses Unicode escape sequences (`\u30XX` format)
- UTF-8 encoding enforcement
- Dynamic message retrieval through runtime JSON loading

#### 3. Configuration Management: JSON Configuration File

**Selection Rationale:**

- **Readability**: Human-readable format
- **PowerShell Compatibility**: Standard support for ConvertFrom-Json/ConvertTo-Json
- **Hierarchical Structure**: Structured management of complex configurations
- **Version Control**: Easy diff checking in Git

## Implementation Guidelines

### Coding Standards

1. **Encoding**: All files saved in UTF-8
2. **Error Handling**: Consistent use of Try-Catch-Finally patterns
3. **Function Naming**: PowerShell Verb-Noun pattern
4. **Comments**: Japanese comments allowed (UTF-8 guaranteed)

### GUI Development Guidelines

1. **XAML Structure**:
   - Do not use x:Class attribute (for PowerShell compatibility)
   - Element reference through Name attribute
   - Feature categorization through TabControl

2. **Message Display**:

   ```powershell
   # Recommended: Use JSON external resources
   Show-SafeMessage -MessageKey "configSaved" -TitleKey "info"
   
   # Not recommended: Direct string specification
   [System.Windows.MessageBox]::Show("設定が保存されました")
   ```

3. **Configuration Management**:

   ```powershell
   # Configuration loading
   $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
   
   # Configuration saving
   $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
   ```

## Performance Considerations

### Startup Time Optimization

- Lazy loading of JSON
- Pre-loading of WPF assemblies
- XAML parsing optimization

### Memory Usage

- Account for differences between PowerShell ISE vs standard PowerShell
- Proper disposal of large objects
- Memory leak prevention in event handlers

## Security Considerations and Risk Management

### Highest Priority Risk: Anti-Cheat System False Positive Prevention

**Technical Approach (Thorough Non-Invasive Design)**:

- Completely avoid invasive operations such as game process memory reading/writing and code injection
- Use only official OS standard features (Get-Process, Stop-Process, etc.) for process operations
- Ensure transparency: Maintain all source code publicly on GitHub for anyone to audit code safety

**Proactive Communication**:

- Notify major anti-cheat developers (Epic Games, BattlEye, etc.) in advance of this project's purpose and technical specifications, requesting whitelist registration

### Execution Policy and Distribution Strategy

- **Development**: Restriction bypass through `-ExecutionPolicy Bypass`
- **Distribution**: **Digital signature with code signing certificate is mandatory**, distributing only officially signed executable files (.exe) by trusted Certificate Authority (CA)
- Signed files ensure trust from Windows SmartScreen and security software

### Configuration File Protection and Privacy

- **Sensitive Information Encryption**: OBS WebSocket passwords etc. are encrypted using Windows Data Protection API (DPAPI) via SecureString, tied to user account
- **Configuration File Access Control**: Appropriate file permission settings

## Future Extension Plans

### Highest Priority (Alpha Test Period)

- [ ] Implementation of alpha test plan (recruiting 5-10 testers)
- [ ] Establishment of official distribution system with digital signatures
- [ ] Security audit and advance notification to anti-cheat developers

### Short-term (v1.1)

- [ ] Addition of English message resources
- [ ] Enhanced configuration validation
- [ ] Error logging functionality

### Medium-term (v1.2)

- [ ] Plugin architecture
- [ ] Theme functionality
- [ ] Configuration import/export

### Long-term (v2.0)

- [ ] Cloud configuration synchronization
- [ ] Web UI option
- [ ] Multi-platform support

## Contribution Guidelines

To maintain this design philosophy, please prioritize the following:

1. **Maintain Lightweight Nature**: Carefully consider adding new dependencies
2. **PowerShell First**: Prioritize PowerShell solutions over migration to other languages
3. **Configuration-Driven**: Control through configuration files rather than hardcoding
4. **Internationalization Support**: Always externalize new messages to JSON resources

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-09-23 | Initial architecture design, GUI implementation completed |
| 1.0.1 | 2025-09-23 | JSON external resource internationalization support completed |
| 1.1.0 | 2025-09-23 | Integration of risk management policy and security design |

## Language Support

This documentation is available in multiple languages:

- **English** (Main): [docs/ARCHITECTURE.md](./ARCHITECTURE.md)
- **日本語** (Japanese): [docs/ja/ARCHITECTURE.md](./ja/ARCHITECTURE.md)

---

*This document records the design philosophy and technical choices of the Focus Game Deck project, enabling future developers to continue development with consistent principles.*
