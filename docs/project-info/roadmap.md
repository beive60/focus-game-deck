# **Focus Game Deck - Strategic Roadmap (v1.2)**

## **Immediate Priorities (Q1-Q2 2026)**

Based on comprehensive analysis of user feedback, code quality, and market opportunities, the following items have been identified as immediate priorities:

### **Critical Bug Fixes**

| Issue | Priority | Status | Notes |
| :---- | :---- | :---- | :---- |
| **Configuration Data Handling (#90)** | **Critical** | Open | Data integrity issues in Load/Save/Default configuration flows need resolution |
| **Technical Debt Resolution** | **High** | In Progress | Multiple TODO items throughout codebase requiring attention |

### **User Experience Improvements**

| Feature | Priority | Status | Notes |
| :---- | :---- | :---- | :---- |
| **Dark Mode Theme (#41)** | **High** | Open | Most requested UI feature; essential for modern application appearance |
| **Demo/Tutorial Content** | **Medium** | Pending | README demo section is empty; video tutorials would significantly improve onboarding |
| **Internationalization Specification (#20)** | **Medium** | Open | Formalize i18n guidelines for consistent translation quality |

### **Language Support Expansion**

| Language | Priority | Status | Notes |
| :---- | :---- | :---- | :---- |
| **Korean** | **Low** | Deferred | Korean gamers generally have high English proficiency. Will implement on community request or contribution. |
| **German** | **Medium** | Pending | Significant European gaming market |
| **Italian** | **Low** | Pending | Growing gaming community |

### **Technical Improvements**

| Item | Priority | Status | Notes |
| :---- | :---- | :---- | :---- |
| **Update Checker Re-enablement** | **High** | Pending | Currently disabled; needs proper implementation for user convenience |
| **Logger Improvements** | **Medium** | Pending | Multiple TODO items for re-enabling features |
| **Permission Logic Implementation** | **Medium** | Pending | TODO in ConfigEditor.UI.ps1 for actual permission handling |

---

## **Implementation Completion Record**

### **[COMPLETED] v1.0.1 Completed (September 23, 2025)**

| Feature | Status | Design Decision |
| :---- | :---- | :---- |
| **GUI Configuration Editor** | [COMPLETED] **Completed** | Lightweight implementation using PowerShell + WPF |
| **Japanese Character Encoding Resolution** | [COMPLETED] **Completed** | Adopted JSON external resource method |
| **Architecture Design** | [COMPLETED] **Completed** | Configuration-driven, modular structure |
| **Risk Management Policy Establishment** | [COMPLETED] **Completed** | Anti-cheat false positive prevention, security-first design |
| **Alpha Test Plan** | [COMPLETED] **Completed** | 5-10 tester recruitment, multi-perspective feedback collection system |
| **Distribution Strategy Establishment** | [COMPLETED] **Completed** | Digital signature reliability assurance, centralized official distribution channels |

### **[COMPLETED] v1.2.0 Completed (September 24, 2025)**

| Feature | Status | Design Decision |
| :---- | :---- | :---- |
| **Executable Build System** | [COMPLETED] **Completed** | ps2exe-based single-file distribution system |
| **Digital Signature Infrastructure** | [COMPLETED] **Completed** | Extended Validation certificate support with automated signing |
| **Build Pipeline Automation** | [COMPLETED] **Completed** | Three-tier build system (individual → integrated → master orchestration) |
| **Release Package Generation** | [COMPLETED] **Completed** | Automated signed distribution package creation |

**Technical Milestones (v1.0.1):**

* Established GUI framework using PowerShell + WPF
* Implemented internationalization pattern using JSON external resources
* Completed 3-tab structure (Game Settings/Managed Apps Settings/Global Settings)
* Fundamental resolution of character encoding issues
* **Systematization of security risk management**
* **Establishment of official distribution and reliability assurance strategy**

**Technical Milestones (v1.2.0):**

* **Complete Build System Implementation**: ps2exe-based executable generation for all components
* **Digital Signature Ready**: Extended Validation certificate infrastructure with automated signing workflow
* **Production Distribution Pipeline**: Release-Manager.ps1 orchestrating development and production builds
* **Security-First Packaging**: Signed executable distribution with integrity verification

**Strategic Milestones:**

* Clarification of MIT License strategic value
* Transparency assurance through open source
* Advance dialogue strategy with anti-cheat developers
* **Ready for Official Release Distribution**: Complete build and signature infrastructure established

## **Release Strategy and License Selection**

### **MIT License Strategic Value**

#### **Contribution to Community Formation**

MIT License provides strategic value beyond just a legal framework for this project:

* **Minimizing Participation Barriers**: Low restrictions allow other developers to easily propose bug fixes and feature additions
* **Reliability Assurance**: Complete transparency through open source builds social trust, especially for tools affecting gaming environments
* **Future Option Security**: Preserves developer's future freedom for commercial expansion or code reuse in other projects

#### **Alignment with Project Philosophy**

The guiding principle of "open and welcoming community" perfectly aligns with MIT License's high degree of freedom, forming the foundation for long-term project growth.

### **Official Distribution and Reliability Assurance Strategy**

Focus Game Deck, as a tool that particularly affects gaming environments, requires thorough reliability assurance.

#### **Integrity Assurance through Digital Signatures** [COMPLETED] **Infrastructure Completed**

* **Implementation Strategy**: [COMPLETED] Comprehensive code signing infrastructure for executable files implemented
* **Technical Requirements**: [COMPLETED] Extended Validation certificate support with RFC 3161 timestamped signatures
* **Distribution Chain**: [COMPLETED] GitHub Releases → Automated Build → Signed Binaries → End User Execution
* **Build System**: [COMPLETED] Release-Manager.ps1 provides complete development and production build workflows
* **Certificate Management**: [COMPLETED] Automated certificate discovery, validation, and signing process

#### **Transparency Assurance Mechanisms**

* **Complete Source Code Disclosure**: All functionality implemented as open source
* **Build Reproducibility**: Users can independently build and verify results
* **Design Philosophy Documentation**: Complete documentation of risk management policies and design decisions

#### **Security Verification Process**

* **Static Analysis**: Comprehensive inspection using PowerShellScriptAnalyzer
* **Anti-cheat Testing**: Demonstrating 0% false positive rate in major games
* **Third-party Review**: Rigorous quality verification during alpha test period

**Design Philosophy Documents:**

* [docs/ARCHITECTURE.md](./ARCHITECTURE.md) - Detailed technical architecture + Risk management policy
* [docs/BD_and_FD_for_GUI.md](./BD_and_FD_for_GUI.md) - GUI specifications and design decisions + Security requirements

---

## **Project Vision**

"Provide an environment where all competitive PC gamers can focus 100% on victory with a single click"

Based on this vision, this roadmap defines the path to evolve Focus Game Deck from a simple tool into a complete application beloved by many users.

### **Phase 0: Preparation & Beta Launch**

* **Target Release**: v0.5 (Public Beta)
* **Target Timeline**: **~Mid-October 2025**
* **Goal**: Establish the project's "face" and "core" and release a practical version that can receive feedback from initial users.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Landing Page Creation** | [COMPLETED] | Clear introduction site with tool value, setup instructions, and download links. Serves as base for promotional activities. |
| **GUI for config.json Creation** | [COMPLETED] | Enable users to configure settings intuitively without fear of syntax errors. Without this, widespread adoption among general users is difficult. |
| **Invoke-FocusGameDeck.ps1 Refactoring** | [COMPLETED] | Transition to config.json data-driven architecture. Resolve technical debt for future feature extensibility. |

### **Phase 1: Foundation Stabilization & v1.0 Official Release**

* **Target Release**: v1.0 (Official Release)
* **Target Timeline**: **Q2 2026** (Updated)
* **Goal**: Reflect beta feedback, expand coverage scope. Complete the first official version that can be confidently recommended to anyone.

| Major Feature | Priority | Status | Notes |
| :---- | :---- | :---- | :---- |
| **Non-Steam Platform Support** | **Critical** | [COMPLETED] | Steam, Epic Games, Riot Client, Standalone/Direct platforms fully supported. EA App games can use standalone mode. |
| **Setup Wizard** | **High** | [COMPLETED] | Complete basic configuration (Steam path, etc.) through interactive dialog on first startup. Minimize setup barriers to the extreme. |
| **Korean Language Support** | **Low** | [DEFERRED] | Deferred due to high English proficiency in Korean gaming community. Will implement on community request or contribution. |
| **Chinese Language Enhancement** | **Medium** | [COMPLETED] | Chinese Simplified (zh-CN) already supported in localization. |
| **Demo Video/GIF Creation** | **Medium** | [PENDING] | Visual demonstration of tool value proposition. README currently lacks demo content. |
| **Documentation Completion** | **Medium** | [IN PROGRESS] | Ensure all user-facing documentation is accurate and comprehensive. |

### **Phase 2: User Experience Enhancement**

* **Target Release**: v1.x Major Updates
* **Target Timeline**: **Q1-Q2 2026**
* **Goal**: Maximize core user satisfaction and deepen attachment to the tool by adding advanced features and modern UI.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Dark Mode Theme** | **Critical** | Most requested feature (#41). Essential for modern application appearance and reduced eye strain during gaming sessions. Implementation should support both system-following and manual toggle options. |
| **Profile Functionality** | **High** | Enable switching settings for the same game between "Ranked" and "Casual" modes. Powerful feature for heavy users. |
| **Theme and Customization Features** | **High** | Beyond dark mode, enable custom color schemes and font preferences. Modernize GUI, eliminate cheap image, and create an application that many users want to use. |
| **StreamDeck Configuration Support Tool** | **Medium** | Enable easy generation and export of configurations for launching each profile directly from StreamDeck through GUI. |
| **Improved Error Handling** | **Medium** | User-friendly error messages with actionable suggestions. Replace technical jargon with plain language explanations. |

### **Phase 3: Ecosystem Expansion**

* **Target Release**: v2.0
* **Target Timeline**: **Q3-Q4 2026**
* **Goal**: Integrate Focus Game Deck with the entire PC environment, evolving from a standalone tool to the "core of gaming environment."

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Discord Integration Enhancement** | **High** | Automatically change Discord status when games launch. Rich Presence support with game-specific details. Expected side effect of natural word-of-mouth from tool usage. |
| **VTube Studio Deep Integration** | **High** | Enhanced WebSocket control for automatic model/expression switching based on game state. Valuable for content creators. |
| **Hardware Profile Integration** | **Medium** | Automatically switch profiles for Logitech G Hub, Razer Synapse, SteelSeries GG, etc. Control environment from both software and hardware perspectives. |
| **Expanded Post-Game Actions** | **Medium** | Execute user-defined custom actions like opening replay folder, putting PC to sleep, sending notifications, etc. |
| **Cloud Configuration Sync** | **Medium** | Optional cloud backup and sync of configurations across multiple PCs. Consider privacy-first implementation. |
| **Performance Analytics** | **Low** | Optional anonymous telemetry for understanding user patterns and improving the tool. Must be opt-in with clear privacy policy. |

### **Long-term Goals: Leap to the Future**

* **Target Release**: v3.0+
* **Target Timeline**: **2027 and beyond**
* **Goal**: Make the project sustainable and evolve into a platform that can grow infinitely through community power.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Plugin System** | **High** | Separate core and extension features, allowing community to freely create custom integrations (Spotify, Twitch, custom hardware, etc.). Standardized API for third-party extensions. |
| **Community Marketplace** | **Medium** | Platform where users can share and download custom profiles, themes, and plugins. Include rating system and verification process. |
| **Cross-Platform Support** | **Medium** | Expand to Mac and Linux, making it the standard tool for gamers worldwide. Consider .NET MAUI or Avalonia UI for cross-platform GUI. |
| **Game Database Integration** | **Low** | Automatic game detection and recommended configurations using community-curated database. Reduce manual setup time for new users. |
| **Mobile Companion App** | **Low** | Remote configuration and monitoring from mobile devices. Start/stop games remotely. |

### Phase 4: Architectural Unification (v4.0)

* **Target Release**: v4.0 (Future Major Update)
* **Goal**: Achieve the ultimate balance of "Simple Distribution" and "High Performance" by unifying components into a single executable.

This phase addresses the complexity of privilege inheritance in multi-process architectures while maintaining our strict performance standards.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Single Executable Architecture** | **High** | Merge Router, GUI, and Launcher into one `Focus-Game-Deck.exe`. This solves privilege inheritance issues (UAC) by keeping the launcher in the same process context as the main application. |
| **Conditional Assembly Loading** | **Critical** | **Performance Optimization**: Dynamically load heavy WPF assemblies *only* when GUI mode is triggered. This ensures the background game launcher remains ultra-lightweight (<50MB) despite being part of the main executable. |
| **Console Window Control** | **High** | **UX Improvement**: Implement native P/Invoke calls to programmatically hide the console window for GUI users, while preserving stdout logging capabilities for command-line usage. |

---

## **Continuous Improvement Initiatives**

The following improvements should be addressed continuously throughout all phases:

### **Code Quality**

| Initiative | Priority | Notes |
| :---- | :---- | :---- |
| **Technical Debt Resolution** | **Ongoing** | Address TODO/FIXME items systematically. Current count: 15+ items across codebase. |
| **Test Coverage Expansion** | **Ongoing** | Increase unit test coverage, especially for core modules (AppManager, ConfigValidator, PlatformManager). |
| **Code Documentation** | **Ongoing** | Improve inline documentation and function-level comments. |
| **Static Analysis** | **Ongoing** | Maintain zero PSScriptAnalyzer warnings in CI/CD pipeline. |

### **User Experience Quality**

| Initiative | Priority | Notes |
| :---- | :---- | :---- |
| **Accessibility Compliance** | **High** | Ensure GUI meets WCAG 2.1 guidelines. Support keyboard navigation and screen readers. |
| **Error Message Clarity** | **Medium** | Replace technical error messages with user-friendly explanations and actionable solutions. |
| **Performance Monitoring** | **Medium** | Track and optimize startup time, memory usage, and CPU impact during gaming sessions. |
| **Localization Quality** | **Medium** | Regular review of translations for accuracy and natural language flow. |

### **Security & Reliability**

| Initiative | Priority | Notes |
| :---- | :---- | :---- |
| **Dependency Updates** | **Ongoing** | Keep all dependencies current to address security vulnerabilities. |
| **Anti-Cheat Compatibility Testing** | **High** | Regular testing with major anti-cheat systems (EasyAntiCheat, BattlEye, Vanguard). |
| **Configuration Backup** | **Medium** | Automatic backup of user configurations before updates. |

---

## **Success Metrics**

### **Immediate Priorities Success Criteria (Q1-Q2 2026)**

* Zero critical bugs in configuration data handling
* Technical debt reduction: resolve 50%+ of TODO items
* Dark mode implementation with positive user feedback
* Korean language support live with community validation

### **Phase 1 Success Criteria**

* 1,000+ active users
* Support for 10+ major gaming platforms (Steam, Epic, EA App, Riot, etc.)
* Community-driven translation contributions for at least 2 new languages
* Setup wizard reducing first-time configuration time by 75%
* Demo video achieving 1,000+ views

### **Phase 2 Success Criteria**

* 10,000+ active users
* 50+ community-created profiles shared
* Profile functionality adoption rate: 30%+ of active users
* StreamDeck integration downloads: 500+
* User satisfaction rating: 4.5/5 or higher

### **Phase 3 Success Criteria**

* 50,000+ active users
* Discord integration adoption: 40%+ of users
* Hardware profile integration with 5+ major brands
* Cloud sync feature adoption: 20%+ of users
* Zero anti-cheat false positive reports

### **Long-term Success Vision**

* Industry recognition as standard gaming environment tool
* Active contributor community (50+ contributors)
* Sustainable development ecosystem with plugin marketplace
* Cross-platform availability (Windows, Mac, Linux)
* 100,000+ total users

## **Development Principles**

Throughout all phases, maintain these core principles:

1. **User-First Design**: Every feature must solve real user problems
2. **Lightweight Philosophy**: Avoid bloat, maintain fast startup and low resource usage
3. **Community-Driven**: Listen to user feedback and enable community contributions
4. **Technical Excellence**: Maintain high code quality and comprehensive documentation
5. **Accessibility**: Ensure the tool remains approachable for non-technical users

## **Risk Management**

### **Technical Risks**

* **PowerShell Compatibility**: Monitor Windows PowerShell evolution and .NET Core migration
* **Third-party Dependencies**: Maintain compatibility with gaming platforms and hardware APIs
* **Performance Scaling**: Ensure tool remains responsive as feature set grows

### **Market Risks**

* **Competition**: Stay ahead of similar tools through unique features and superior UX
* **Platform Changes**: Adapt to changes in gaming platforms and launcher ecosystems
* **User Adoption**: Maintain focus on ease of use and clear value proposition

## **Community Building Strategy**

* **Documentation**: Maintain comprehensive, multi-language documentation
* **Tutorials**: Create video and written guides for common use cases
* **Support Channels**: Establish Discord, Reddit, and GitHub issue support
* **Contributor Recognition**: Acknowledge and reward community contributions

## **Competitive Positioning**

Focus Game Deck differentiates itself through:

| Aspect | Focus Game Deck | Typical Alternatives |
| :---- | :---- | :---- |
| **Technology** | Lightweight PowerShell + WPF | Heavy Electron-based apps |
| **Resource Usage** | Minimal background impact | Often resource-intensive |
| **Customization** | Configuration-driven, highly flexible | Limited preset options |
| **Open Source** | Fully open, MIT licensed | Often proprietary |
| **Anti-Cheat Risk** | Security-first design, transparent | Often opaque implementation |
| **Gaming Focus** | Purpose-built for competitive gaming | General automation tools |

### **Key Differentiators**

1. **Zero Performance Impact**: Unlike Electron-based alternatives, Focus Game Deck is designed specifically for competitive gaming where every frame matters
2. **Transparency**: Complete open-source codebase allows users and anti-cheat developers to verify safety
3. **Community-Driven**: Development priorities based on real user feedback
4. **Professional Security**: Digital signatures and security-first architecture

---

## **Revision History**

| Version | Date | Changes |
| :---- | :---- | :---- |
| v1.2 | January 29, 2026 | Added Immediate Priorities section, expanded Phase 2-3 features, added Continuous Improvement initiatives, updated success metrics, added competitive positioning |
| v1.1 | September 2025 | Added Phase 4 architectural unification plans |
| v1.0 | September 2025 | Initial roadmap release |

---

*This roadmap serves as a living document that will evolve based on user feedback, technical discoveries, and market opportunities while maintaining our core vision of empowering gamers worldwide.*
