# GitHub Copilot Instructions

When generating code for this project, strictly follow the rules below.

## Essential Reference Documents

- This project must follow the rules documented in the following files:
    - `.\docs\DOCUMENTATION-INDEX.md`
    - `.\docs\developer-guide\architecture.md`
    - `.\docs\developer-guide\build-system.md`
    - `.\docs\developer-guide\gui-design.md`
    - `.\docs\developer-guide\release-process.md`
    - `.\docs\project-info\philosophy.md`
    - `.\docs\project-info\roadmap.md`
    - `.\docs\project-info\version-management.md`

## Writing paths

When writing file paths or directory paths, always use a forward slash (/) regardless of the operating system. Do not use a backslash (\\).

Good examples:

```path
src/components/button.js
/api/data
C:/Users/YourName/Documents/project (Even when dealing with Windows paths in PowerShell scripts, use forward slashes)
```

Bad examples:

```path
src\components\button.js
C:\Users\YourName\Documents\project
```

This rule is important for cross-platform compatibility and to avoid issues related to escape characters.

## Attribute Wrapping in XAML

When writing XAML code, if an element has multiple attributes, each attribute should be placed on a new line and indented for better readability.

## Rule Summary

- Keep line length within 120 characters.
- Always add JSDoc-style comments to functions.
- Use try-catch blocks for error handling and always include logging.
- Do not use emojis anywhere in the codebase.

Do not suggest code that does not comply with the above rules.
