# GitHub Copilot Instructions

When generating code for this project, strictly follow the rules below.

## Essential Reference Documents

This project must follow the rules documented in the following files:

- `./docs/DOCUMENTATION-INDEX.md`
- `./docs/developer-guide/architecture.md`
- `./docs/developer-guide/build-system.md`
- `./docs/developer-guide/gui-design.md`
- `./docs/developer-guide/release-process.md`
- `./docs/project-info/philosophy.md`
- `./docs/project-info/roadmap.md`
- `./docs/project-info/version-management.md`

## Writing paths

- When writing file paths or directory paths, always use relative paths from the project root directory whenever possible.
- When writing file paths or directory paths, always use a forward slash (/) regardless of the operating system. Do not use a backslash (\\).
    - This rule is important for cross-platform compatibility and to avoid issues related to escape characters.

Good examples:

```powershell
$projectRoot = Join-Path -Path $PSScriptRoot -ChildPath ".."
$messagesPath = Join-Path -Path $projectRoot -ChildPath "gui/messages.json"
```

Bad examples:

```powershell
$messagesPath = "gui\messages.json"
```

## Attribute Wrapping in XAML

When writing XAML code, if an element has multiple attributes, each attribute should be placed on a new line and indented for better readability.

## Not use emoji

When generating documentation, terminal output, or any other content, do not use emojis. Keep all text plain and professional without any emoji characters or symbols.

## Not use "Column Alignment"

Do not use "Column Alignment" in any code, documentation, or comments. Avoid aligning code or text into columns for better readability and maintainability.

## Rule Summary

- Keep line length within 120 characters.
- Always add JSDoc-style comments to functions.
- Use try-catch blocks for error handling and always include logging.
- Do not use emojis anywhere in the codebase.

Do not suggest code that does not comply with the above rules.
