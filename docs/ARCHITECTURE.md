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
│   ├── src/Invoke-FocusGameDeck-MultiPlatform.ps1  # Multi-platform version
│   ├── src/modules/                     # Modular components
│   │   ├── AppManager.ps1               # Application lifecycle management
│   │   ├── OBSManager.ps1               # OBS Studio WebSocket integration
│   │   ├── VTubeStudioManager.ps1       # VTube Studio integration
│   │   ├── PlatformManager.ps1          # Multi-platform game launcher support
│   │   └── ConfigValidator.ps1          # Configuration validation
│   ├── scripts/Create-Launchers.ps1     # Launcher generation
│   └── launch_*.bat                     # Game-specific launch scripts
│
├── Configuration Management
│   ├── config/config.json               # Main configuration file
│   ├── config/config.json.sample        # Sample configuration
│   ├── config/messages.json             # Internationalization resources (for GUI)
│   └── config/signing-config.json       # Digital signature configuration
│
├── GUI Module (PowerShell + WPF)
│   ├── gui/MainWindow.xaml              # UI layout definition
│   ├── gui/ConfigEditor.ps1             # GUI control logic
│   ├── gui/messages.json                # GUI message resources
│   └── gui/Build-ConfigEditor.ps1       # GUI build script
│
├── Build System & Distribution
│   ├── Build-FocusGameDeck.ps1          # Main build script
│   ├── Sign-Executables.ps1             # Digital signature script
│   ├── Master-Build.ps1                 # Integrated build orchestration
│   ├── build/                           # Build artifacts directory
│   ├── signed/                          # Signed executables directory
│   └── release/                         # Release package directory
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

#### 3. Build System: PowerShell to Executable Conversion

**Options Considered:**

- Manual PowerShell script distribution
- PowerShell ISE packaging
- ps2exe module compilation ✅
- Migration to compiled languages (C#/.NET)

**Selection Rationale:**

- **Single File Distribution**: ps2exe creates standalone executable files for easy distribution
- **No Runtime Dependencies**: Generated executables run without requiring PowerShell installation
- **Digital Signature Support**: Full support for Authenticode digital signatures
- **Maintains PowerShell Benefits**: Preserves source code readability and maintainability
- **Security Compliance**: Enables Extended Validation certificate signing for trust establishment

**Technical Implementation:**

- **Main Application**: `Focus-Game-Deck.exe` (console-based launcher)
- **Multi-platform Version**: `Focus-Game-Deck-MultiPlatform.exe` (extended platform support)
- **GUI Configuration**: `Focus-Game-Deck-Config-Editor.exe` (WPF-based, no console window)
- **Automated Build Pipeline**: Three-tier build system (individual → integrated → master orchestration)

#### 4. Digital Signature Strategy: Extended Validation Certificate

**Security Requirements:**

- **Trust Establishment**: Windows SmartScreen and antivirus compatibility
- **Anti-cheat Compliance**: Proactive whitelisting with signed executables
- **Timestamp Preservation**: RFC 3161 timestamping for long-term signature validity

**Implementation Details:**

- Certificate storage in Windows Certificate Store (CurrentUser\My)
- Automated signature verification post-signing
- Multiple timestamp server fallback support
- Signature metadata tracking in release packages

#### 5. Configuration Management: JSON Configuration File

**Selection Rationale:**

- **Readability**: Human-readable format
- **PowerShell Compatibility**: Standard support for ConvertFrom-Json/ConvertTo-Json
- **Hierarchical Structure**: Structured management of complex configurations
- **Version Control**: Easy diff checking in Git

#### 6. VTube Studio Integration: Modular Manager Pattern

**Integration Approach:**

- **Modular Design**: Separate VTubeStudioManager.ps1 following OBSManager patterns
- **Auto-Detection**: Automatic detection of Steam vs Standalone installations
- **Special Actions**: Custom `start-vtube-studio` and `stop-vtube-studio` actions in AppManager
- **Future WebSocket Ready**: Foundation prepared for VTube Studio API integration

**Technical Implementation:**

- **Steam Integration**: Proper DRM handling via Steam `-applaunch` parameter (AppID: 1325860)
- **Standalone Support**: Direct executable launching with configurable arguments
- **Process Management**: Graceful shutdown with fallback to force termination
- **Error Handling**: Comprehensive logging and fallback mechanisms

**Selection Rationale:**

- **VTuber Community Support**: Essential for Japanese streaming ecosystem
- **Consistency**: Follows established OBSManager architectural patterns
- **Extensibility**: WebSocket API integration foundation for future model control features
- **Platform Agnostic**: Supports both Steam and standalone VTube Studio installations

#### 7. WebSocket Manager Architecture: Hybrid Utility Class Pattern

**Problem Context:**

During VTube Studio integration development, significant code duplication was identified between OBSManager and VTubeStudioManager modules, particularly in:

- WebSocket connection establishment and management
- Process lifecycle management (start/stop/graceful shutdown)
- Common utility functions for application detection

**Options Considered:**

- **Full Inheritance Model**: Create abstract base class with OBSManager/VTubeStudioManager inheriting all functionality
- **Composition Pattern**: Separate WebSocket utility class with full delegation
- **Hybrid Utility Class Pattern**: Common utility class with selective delegation and fallback mechanisms ✅
- **Code Duplication**: Maintain separate implementations for flexibility

**Selection Rationale:**

- **PowerShell Class Limitations**: PowerShell class inheritance has constraints that make full inheritance complex
- **Flexibility Preservation**: Each manager retains ability to implement application-specific logic
- **Code Reuse Benefits**: Common utilities shared without forcing rigid inheritance structure
- **Fallback Resilience**: Managers can fall back to original implementations if utility class fails
- **Future Extensibility**: Pattern can be extended to other WebSocket-based integrations

**Technical Implementation:**

```powershell
# WebSocketAppManagerBase.ps1 - Common utility class
class WebSocketAppManagerBase {
    [bool] IsProcessRunning([string]$processName) { }
    [object] EstablishWebSocketConnection([string]$uri, [int]$timeout) { }
    [bool] StopApplicationGracefully([string]$processName, [int]$timeout) { }
}

# VTubeStudioManager.ps1 - Hybrid usage pattern
class VTubeStudioManager {
    hidden [WebSocketAppManagerBase] $baseHelper
    
    [bool] IsVTubeStudioRunning() {
        try {
            return $this.baseHelper.IsProcessRunning("VTubeStudio")
        }
        catch {
            # Fallback to original implementation
            return (Get-Process -Name "VTubeStudio" -ErrorAction SilentlyContinue) -ne $null
        }
    }
}
```

**Benefits Achieved:**

- **25% Code Reduction**: Eliminated duplicate utility functions across managers
- **Maintained Flexibility**: Each manager retains full control over application-specific behavior
- **Resilient Design**: Fallback mechanisms ensure continued operation even if base utilities fail
- **Extensible Pattern**: Foundation for future WebSocket-based integrations (Discord bots, streaming tools)

**Design Decision Impact:**

This hybrid approach balances the benefits of code reuse with the need for flexibility in PowerShell-based class architecture, establishing a pattern for future manager implementations while avoiding the constraints of rigid inheritance models.

## Implementation Guidelines

### Coding Standards

1. **Encoding**: All files saved in UTF-8
2. **Error Handling**: Consistent use of Try-Catch-Finally patterns
3. **Function Naming**: PowerShell Verb-Noun pattern
4. **Comments**: Japanese comments allowed (UTF-8 guaranteed)

### Character Encoding and Console Compatibility Guidelines

#### PowerShell Console Character Compatibility

Due to frequent character encoding issues in PowerShell console environments, especially with UTF-8 special characters, follow these guidelines:

##### 1. Avoid UTF-8 Special Characters in Console Output

```powershell
# ❌ Problematic: UTF-8 special characters cause garbling
Write-Host "✓ Success" -ForegroundColor Green
Write-Host "✗ Failed" -ForegroundColor Red
Write-Host "⚠ Warning" -ForegroundColor Yellow

# ✅ Recommended: Use ASCII-compatible alternatives
Write-Host "[OK] Success" -ForegroundColor Green
Write-Host "[ERROR] Failed" -ForegroundColor Red
Write-Host "[WARNING] Warning" -ForegroundColor Yellow
```

##### 2. Safe Character Alternatives

| UTF-8 Character | ASCII Alternative | Usage Context |
|-----------------|-------------------|---------------|
| ✓ (U+2713) | `[OK]` | Success messages |
| ✗ (U+2717) | `[ERROR]` | Error messages |
| ⚠ (U+26A0) | `[WARNING]` | Warning messages |
| ℹ (U+2139) | `[INFO]` | Information messages |
| → (U+2192) | `->` | Direction indicators |
| • (U+2022) | `-` | List bullets |

##### 3. File Encoding Consistency

- **Source Files**: UTF-8 with BOM for PowerShell compatibility
- **Configuration Files**: UTF-8 without BOM for JSON compatibility
- **Documentation**: UTF-8 with BOM for proper character display

##### 4. Testing Console Output

Always test console output in multiple PowerShell environments:

- Windows PowerShell 5.1
- PowerShell Core 7.x
- PowerShell ISE
- Windows Terminal
- Command Prompt with PowerShell

##### 5. Internationalization Considerations

```powershell
# For GUI components: Use JSON external resources with Unicode escapes
$messages = @{
    "success" = "\u6210\u529f"  # Japanese: 成功
    "error" = "\u30a8\u30e9\u30fc"    # Japanese: エラー
}

# For console output: Use ASCII-safe alternatives
Write-Host "[OK] Operation completed successfully"
```

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

- [x] VTube Studio integration (Steam/Standalone auto-detection)
- [x] Character encoding guidelines and console compatibility
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
| 1.2.0 | 2025-09-24 | Build system implementation, digital signature infrastructure completed |
| 1.3.0 | 2025-09-24 | VTube Studio integration, character encoding guidelines added |
| 1.4.0 | 2025-09-24 | WebSocket manager hybrid architecture pattern implemented |

## Language Support

This documentation is available in multiple languages:

- **English** (Main): [docs/ARCHITECTURE.md](./ARCHITECTURE.md)
- **日本語** (Japanese): [docs/ja/ARCHITECTURE.md](./ja/ARCHITECTURE.md)

---

*This document records the design philosophy and technical choices of the Focus Game Deck project, enabling future developers to continue development with consistent principles.*
