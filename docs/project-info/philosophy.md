# Focus Game Deck - Project Philosophy & Manifesto

This document shares what Focus Game Deck aims to achieve and the philosophy behind its development.

## Our Mission

We have only one mission: **"To provide a one-click environment for competitive PC gamers to concentrate 100% on winning."**

We will completely automate the tedious preparations before launching a game (closing unnecessary apps, disabling hotkeys, starting recording software...) and the troublesome cleanup after finishing. We liberate players from this "noise outside of gameplay." What we offer is not just a tool, but a **smooth, stress-free experience to dive into "peak concentration."**

## Guiding Principles

All feature additions and design decisions are made based on the following four principles:

### 2.1 User Experience First

This tool must be intuitive not only for power users but also for **gamers who are not tech-savvy.**

* **Zero-Config:** It should behave intelligently, such as automatically detecting the OS language and responding in the user's native language, without requiring any user setup.
* **Protection from Errors:** Settings should be configurable through a GUI as much as possible, so users don't have to struggle with JSON syntax errors.
* **Clarity:** We will avoid jargon and maintain file names, folder structures, and documentation that anyone can understand.

### 2.2 Uncompromising Performance

Our target users are competitive gamers who are sensitive to a single frame of delay or a 1% increase in CPU usage.

* **Lightweight & Fast:** The tool itself must never impact game performance. Therefore, we prioritize lightweight, Windows-native technologies like WPF over heavyweight ones like Electron.
* **Resource-Efficient:** Resource consumption when running in the background should be kept to an absolute minimum.

### 2.3 Clean and Scalable Architecture

This project is designed with future growth and community improvements in mind.

* **Separation of Concerns:** Files are clearly separated by their roles, such as application core logic (src), utility scripts (scripts), and internationalization files (messages.json).
* **Data-Driven:** The tool's behavior should be determined by the user-editable `config.json`, not by logic within the scripts. This allows for extending the tool's functionality without touching the code.
* **Internationalization (i18n):** All user-facing strings are managed in separate language files, decoupled from the logic, to facilitate multilingual support.

### 2.4 Open and Welcoming Community

This project does not belong to a single author; it should grow with the community that needs it.

* **MIT License:** We permit the free use, modification, and redistribution of the source code to encourage maximum collaboration. However, the author's credit must always be preserved.
* **Contributions Welcome:** We welcome contributions in all forms, including bug reports, feature suggestions, documentation improvements, and translation submissions.

## Branding Philosophy

The project name **Focus Game Deck** embodies our philosophy.

* **Focus**: Symbolizes the greatest value we provide: "concentration."
* **Deck**: Intuitively conveys the nature of the tool—bundling complex actions into a single, one-click execution, much like the "Stream Deck" familiar to gamers.

## Design Values

### Security First

* **Anti-cheat compatibility**: All features are designed to minimize false positive risks
* **Transparency**: Complete open source for security audit
* **Digital signatures**: All releases are signed with Extended Validation certificates

### Performance First

* **Native technologies**: PowerShell + WPF instead of Electron
* **Minimal resource usage**: Background operation should be imperceptible
* **Fast startup**: Quick launch and environment setup

### Configuration-Driven Architecture

* **No code changes required**: All behavior controlled through JSON configuration
* **Extensibility**: Add new applications without modifying source code  
* **Maintainability**: Clear separation between logic and configuration

### Internationalization by Design

* **External JSON resources**: All strings externalized for easy translation
* **Unicode support**: Proper handling of Japanese and Chinese characters
* **Locale-aware**: Automatic language detection and appropriate defaults

## Community Values

We look forward to contributions from you who resonate with this manifesto and share a passion for improving the environment for competitive gamers.

### Inclusivity

* Welcome contributors of all skill levels
* Clear documentation for newcomers
* Patient and constructive code review process

### Collaboration

* Open discussion of design decisions
* Transparent development process
* Recognition of all contributors

### Quality

* Comprehensive testing requirements
* Code review for all changes
* Documentation updates with features

---

*This philosophy guides all decisions in Focus Game Deck development. If you're contributing to the project, please keep these values in mind.*