# **Focus Game Deck - Strategic Roadmap (v1.0)**

## **Implementation Completion Record**

### **✅ v1.0.1 Completed (September 23, 2025)**

| Feature | Status | Design Decision |
| :---- | :---- | :---- |
| **GUI Configuration Editor** | ✅ **Completed** | Lightweight implementation using PowerShell + WPF |
| **Japanese Character Encoding Resolution** | ✅ **Completed** | Adopted JSON external resource method |
| **Architecture Design** | ✅ **Completed** | Configuration-driven, modular structure |

**Technical Milestones:**

* Established GUI framework using PowerShell + WPF
* Implemented internationalization pattern using JSON external resources
* Completed 3-tab structure (Game Settings/Managed Apps Settings/Global Settings)
* Fundamental resolution of character encoding issues

**Design Philosophy Documents:**

* [docs/ARCHITECTURE.md](./ARCHITECTURE.md) - Detailed technical architecture
* [docs/BD_and_FD_for_GUI.md](./BD_and_FD_for_GUI.md) - GUI specifications and design decisions

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
| **Non-Steam Platform Support** | **Critical** | Support for Epic Games, EA App, Riot Client, etc. Essential feature for significantly expanding user base. |
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

## Language Support

This documentation is available in multiple languages:

* **English** (Main): [docs/ROADMAP.md](./ROADMAP.md)
* **日本語** (Japanese): [docs/ja/ROADMAP.md](./ja/ROADMAP.md)

---

*This roadmap serves as a living document that will evolve based on user feedback, technical discoveries, and market opportunities while maintaining our core vision of empowering gamers worldwide.*
