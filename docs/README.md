# Focus Game Deck - Documentation Index

## 📚 Design Philosophy Record

The design philosophy and technical choices of this project are systematically documented in the following documents:

### 🏗️ Main Design Documents

| Document | Purpose | Target Audience |
|----------|---------|-----------------|
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | Technical architecture and detailed design philosophy | Developers and maintainers |
| **[BD_and_FD_for_GUI.md](./BD_and_FD_for_GUI.md)** | GUI design specifications and implementation decisions | UI developers and designers |
| **[ROADMAP.md](./ROADMAP.md)** | Project strategy and completion record | Project managers |

### 📋 Overview Documents

| Document | Purpose | Target Audience |
|----------|---------|-----------------|
| **[README.md](../README.md)** | Project overview and design principles summary | General users and new developers |
| **[README.JP.md](../README.JP.md)** | Japanese version of project overview | Japanese users |

### 💻 Implementation Documents

| File | Purpose | Recorded Content |
|------|---------|------------------|
| **[gui/ConfigEditor.ps1](../gui/ConfigEditor.ps1)** | GUI main code | Design philosophy recorded in header comments |
| **[gui/messages.json](../gui/messages.json)** | Internationalization resources | JSON external resource implementation example |

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

- **English** (Main): [docs/README.md](./README.md)
- **日本語** (Japanese): [docs/ja/DOCUMENTATION-INDEX.md](./ja/DOCUMENTATION-INDEX.md)

For Japanese-speaking contributors and users, please refer to the Japanese documentation in the `docs/ja/` directory.

---

*This design philosophy documentation aims to make the technical decisions of the Focus Game Deck project transparent and ensure long-term development consistency.*
