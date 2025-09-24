# Focus Game Deck - Documentation Index

## 📚 Project Overview

Focus Game Deck is a **gaming environment automation tool** for competitive PC gamers. It automatically controls related applications when games start, instantly creating an environment for focused gameplay.

### 🎯 Core Philosophy

- Building an **open and welcoming community**
- Maximum freedom through **MIT License**
- **Security First**: Minimizing anti-cheat false positive risks
- **Transparency Assurance**: Complete open source

## 📖 Documentation Structure

Each document has a clear role and complements each other:

### 🏗️ Technical Documents

| Document | Purpose | Content |
|----------|---------|---------|
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | **Detailed Technical Architecture Design** | System structure, design decisions, implementation guidelines, security design |
| **[BD_and_FD_for_GUI.md](./BD_and_FD_for_GUI.md)** | **GUI Configuration Editor Specifications** | Screen design, functional specifications, wireframes, UI implementation details |
| **[BUILD-SYSTEM.md](./BUILD-SYSTEM.md)** | **Build System and Distribution Infrastructure** | Executable generation, digital signatures, automated build workflows |

### 📋 Strategic Documents

| Document | Purpose | Content |
|----------|---------|---------|
| **[ROADMAP.md](./ROADMAP.md)** | **Project Strategy and Milestones** | Development phases, release plans, alpha test strategy |

### � Reference Documents

| Document | Purpose | Target Audience |
|----------|---------|-----------------|
| **[README.md](../README.md)** | Project overview (English) | International users and developers |
| **[README.JP.md](../README.JP.md)** | Project overview (Japanese) | Japanese users |
| **[GUI-MANUAL.md](./ja/GUI-MANUAL.md)** | GUI configuration editor user manual | End users and GUI users |

### 💻 Implementation Documents

| File | Purpose | Recorded Content |
|------|---------|------------------|
| **[gui/ConfigEditor.ps1](../gui/ConfigEditor.ps1)** | GUI main code | Design philosophy recorded in header comments |
| **[gui/messages.json](../gui/messages.json)** | Internationalization resources | JSON external resource implementation example |
| **[DEVELOPER-RELEASE-GUIDE.md](./DEVELOPER-RELEASE-GUIDE.md)** | Developer release workflow | Complete build and release process documentation |

## 🎯 Key Design Decisions

### 1. **GUI Technology Choice: PowerShell + WPF**

- **Location**: [ARCHITECTURE.md](./ARCHITECTURE.md#gui-technology-choice-powershell--wpf)
- **Rationale**: Lightweight, consistency, ease of distribution
- **Alternatives considered**: Windows Forms, Electron, C# WPF

### 2. **Internationalization Method: JSON External Resources**

- **Location**: [BD_and_FD_for_GUI.md](./BD_and_FD_for_GUI.md#internationalization-method-json-external-resources)
- **Rationale**: Solves Japanese character encoding issues, maintainability, standard approach
- **Technical details**: Uses Unicode escape sequences

### 3. **Architecture Pattern: Configuration-Driven**

- **Location**: [ARCHITECTURE.md](./ARCHITECTURE.md#configuration-management-json-configuration-file)
- **Rationale**: Flexibility, extensibility, customization without code changes
- **Implementation**: Behavior control through config.json

## � Quick Start

### For Users

1. Check release status in **[ROADMAP.md](./ROADMAP.md)**
2. Download official release version from GitHub Releases
3. Run digitally signed .exe file

### For Developers

1. Understand system design in **[ARCHITECTURE.md](./ARCHITECTURE.md)**
2. Check GUI specifications in **[BD_and_FD_for_GUI.md](./BD_and_FD_for_GUI.md)**
3. Develop following coding standards

## 🔄 Documentation Update Policy

- **Technical Changes**: Update ARCHITECTURE.md
- **UI Changes**: Update BD_and_FD_for_GUI.md
- **Strategic Changes**: Update ROADMAP.md
- **Overview Changes**: Update this documentation index

## 🔄 Design Philosophy Continuity

This documentation ensures:

1. **Technical Continuity**: New developers can understand the design intent
2. **Decision Transparency**: Why specific technology choices were made is clear
3. **Future Extensibility**: Feature additions can follow the design philosophy
4. **Quality Maintenance**: Consistent coding standards and implementation patterns

## 📅 Update History

| Date | Version | Changes |
|------|---------|---------|
| 2025-09-23 | v1.0.0 | Initial design philosophy documentation, GUI implementation completed |
| 2025-09-23 | v1.0.1 | JSON external resource internationalization support completed |

## 🌐 Language Support

This documentation is available in multiple languages:

- **English** (Main): [docs/DOCUMENTATION-INDEX.md](./DOCUMENTATION-INDEX.md)
- **日本語** (Japanese): [docs/ja/DOCUMENTATION-INDEX.md](./ja/DOCUMENTATION-INDEX.md)

For Japanese-speaking contributors and users, please refer to the Japanese documentation in the `docs/ja/` directory.

---

*This design philosophy documentation aims to make the technical decisions of the Focus Game Deck project transparent and ensure long-term development consistency.*
