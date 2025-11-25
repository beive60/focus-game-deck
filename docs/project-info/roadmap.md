# **Focus Game Deck - Strategic Roadmap (v1.1)**

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
| **Landing Page Creation** | **Critical** | Clear introduction site with tool value, setup instructions, and download links. Serves as base for promotional activities. |
| **GUI for config.json Creation** | **Critical** | Enable users to configure settings intuitively without fear of syntax errors. Without this, widespread adoption among general users is difficult. |
| **Invoke-FocusGameDeck.ps1 Refactoring** | **High** | Transition to config.json data-driven architecture. Resolve technical debt for future feature extensibility. |

### **Phase 1: Foundation Stabilization & v1.0 Official Release**

* **Target Release**: v1.0 (Official Release)
* **Target Timeline**: **~Late November 2025**
* **Goal**: Reflect beta feedback, expand coverage scope. Complete the first official version that can be confidently recommended to anyone.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Non-Steam Platform Support** | **Critical** | Support for Epic Games, EA App, Riot Client, etc. [IN PROGRESS: Standalone platform testing implemented] Essential feature for significantly expanding user base. |
| **Setup Wizard** | **High** | Complete basic configuration (Steam path, etc.) through interactive dialog on first startup. Minimize setup barriers to the extreme. |
| **Chinese/Korean Language Support** | **Medium** | Expand reach to huge Asian gamer markets. Consider translation cooperation from community. |

### **Phase 2: User Experience Enhancement**

* **Target Release**: v1.x Major Updates
* **Target Timeline**: **Q1 2026**
* **Goal**: Maximize core user satisfaction and deepen attachment to the tool by adding advanced features.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Profile Functionality** | **High** | Enable switching settings for the same game between "Ranked" and "Casual" modes. Powerful feature for heavy users. |
| **StreamDeck Configuration Support Tool** | **Medium** | Enable easy generation and export of configurations for launching each profile directly from StreamDeck through GUI. |
| **Theme and Customization Features** | **High** | Modernize GUI, eliminate cheap image, and create an application that many users want to use. |

### **Phase 3: Ecosystem Expansion**

* **Target Release**: v2.0
* **Target Timeline**: **Q2 2026 and beyond**
* **Goal**: Integrate Focus Game Deck with the entire PC environment, evolving from a standalone tool to the "core of gaming environment."

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Discord Integration** | **High** | Automatically change Discord status when games launch. Expected side effect of natural word-of-mouth from tool usage. |
| **Hardware Profile Integration** | **Medium** | Automatically switch profiles for Logicool G Hub, Razer Synapse, etc. Control environment from both software and hardware perspectives. |
| **Expanded Post-Game Actions** | **Medium** | Execute user-defined custom actions like opening replay folder, putting PC to sleep, etc. |

### **Long-term Goals: Leap to the Future**

* **Target Release**: v3.0+
* **Target Timeline**: **Long-term Vision**
* **Goal**: Make the project sustainable and evolve into a platform that can grow infinitely through community power.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Plugin System** | **-** | Separate core and extension features, allowing community to freely create "Spotify plugins" etc. |
| **Community Marketplace** | **-** | Platform where users can share and download custom profiles, themes, and plugins. |
| **Cross-Platform Support** | **-** | Expand to Mac and Linux, making it the standard tool for gamers worldwide. |

### Phase 4: Architectural Unification (v4.0)

* **Target Release**: v4.0 (Future Major Update)
* **Goal**: Achieve the ultimate balance of "Simple Distribution" and "High Performance" by unifying components into a single executable.

This phase addresses the complexity of privilege inheritance in multi-process architectures while maintaining our strict performance standards.

| Major Feature | Priority | Notes |
| :---- | :---- | :---- |
| **Single Executable Architecture** | **High** | Merge Router, GUI, and Launcher into one `Focus-Game-Deck.exe`. This solves privilege inheritance issues (UAC) by keeping the launcher in the same process context as the main application. |
| **Conditional Assembly Loading** | **Critical** | **Performance Optimization**: Dynamically load heavy WPF assemblies *only* when GUI mode is triggered. This ensures the background game launcher remains ultra-lightweight (<50MB) despite being part of the main executable. |
| **Console Window Control** | **High** | **UX Improvement**: Implement native P/Invoke calls to programmatically hide the console window for GUI users, while preserving stdout logging capabilities for command-line usage. |

## **Success Metrics**

### **Phase 0 Success Criteria**

* 100+ downloads within first month
* 5+ community feedback submissions
* Basic functionality validation

### **Phase 1 Success Criteria**

* 1,000+ active users
* Support for 10+ major gaming platforms
* Community-driven translation contributions

### **Phase 2 Success Criteria**

* 10,000+ active users
* 50+ community-created profiles
* Integration with major gaming hardware

### **Long-term Success Vision**

* Industry recognition as standard gaming environment tool
* Active contributor community
* Sustainable development ecosystem

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

---

*This roadmap serves as a living document that will evolve based on user feedback, technical discoveries, and market opportunities while maintaining our core vision of empowering gamers worldwide.*
