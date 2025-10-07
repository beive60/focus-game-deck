# Contributing to Focus Game Deck

Thank you for your interest in contributing to Focus Game Deck! This guide will help you get started with the development process.

## Table of Contents

- [Project Philosophy](#project-philosophy)
- [Development Environment Setup](#development-environment-setup)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Documentation](#documentation)

## Project Philosophy

Focus Game Deck has one mission: **"To provide a one-click environment for competitive PC gamers to concentrate 100% on winning."**

Our guiding principles:

1. **User Experience First** - Intuitive for both power users and non-technical gamers
2. **Uncompromising Performance** - Never impact game performance
3. **Clean and Scalable Architecture** - Configuration-driven, data-driven design
4. **Open and Welcoming Community** - MIT License, contributions welcome

For the complete project manifesto, see [Project Philosophy](docs/project-info/philosophy.md).

## Development Environment Setup

### Prerequisites

- **Windows 10/11** (Primary development platform)
- **PowerShell 5.1+** (included with Windows)
- **Git** for version control
- **VS Code** (recommended) with PowerShell extension

### Initial Setup

1. **Fork and Clone**

   ```bash
   git clone https://github.com/YOUR-USERNAME/focus-game-deck.git
   cd focus-game-deck
   ```

2. **Install Required Modules**

   ```powershell
   # Install ps2exe for building executables
   ./build-tools/Build-FocusGameDeck.ps1 -Install
   ```

3. **Verify Setup**

   ```powershell
   # Run basic configuration validation
   .\test/Simple-Check.ps1
   ```

### Development Tools

- **Build System**: PowerShell scripts with ps2exe
- **Testing**: PowerShell-based test suite
- **GUI Development**: PowerShell + WPF with JSON internationalization
- **Code Signing**: Extended Validation certificate support

## Development Workflow

### Branch Strategy

- `main` - Stable release branch
- `develop` - Integration branch for new features
- `feature/feature-name` - Feature development branches
- `bugfix/bug-description` - Bug fix branches

### Typical Development Flow

1. **Create Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Follow coding standards (see below)
   - Add/update tests as needed
   - Update documentation

3. **Test Changes**

   ```powershell
   # Run specific tests
   .\test\Test-ConfigValidation.ps1

   # Run all tests
   .\test\Test-*.ps1
   ```

4. **Build and Verify**

   ```powershell
   # Development build
   ./Master-Build.ps1 -Development -Verbose
   ```

5. **Submit Pull Request**

## Coding Standards

### PowerShell Guidelines

Based on [copilot-instructions.md](.github/copilot-instructions.md):

1. **Line Length**: Maximum 120 characters per line
2. **Function Documentation**: All functions must have JSDoc-style comments
3. **Error Handling**: Use try-catch blocks with proper logging
4. **Character Encoding**: Follow [Character Encoding Guidelines](docs/developer-guide/architecture.md#character-encoding-and-console-compatibility-guidelines)

### Code Style

```powershell
<#
.SYNOPSIS
    Brief description of the function.

.DESCRIPTION
    Detailed description of what the function does.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    Example of how to use the function.

.NOTES
    Additional notes if needed.
#>
function Get-ExampleFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequiredParameter,

        [Parameter(Mandatory = $false)]
        [string]$OptionalParameter = "DefaultValue"
    )

    try {
        # Function implementation
        Write-Log "Performing action with parameter: $RequiredParameter"

        # Your code here

        return $result
    }
    catch {
        Write-Log "Error in Get-ExampleFunction: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}
```

### Configuration Management

- All behavior must be configurable through `config.json`
- No hardcoded paths or application-specific logic in core scripts
- Use the configuration-driven architecture pattern

### Internationalization

- All user-facing strings must be externalized to `messages.json`
- Use Unicode escape sequences for non-ASCII characters
- Support English, Japanese, and Chinese Simplified

## Testing Guidelines

### Test Structure

Tests are located in the `test/` directory:

- `Simple-Check.ps1` - Basic configuration validation
- `Test-*.ps1` - Specific feature tests
- `Manual-Test-Guide.md` - Manual testing procedures

### Writing Tests

```powershell
# test/Test-YourFeature.ps1
try {
    Write-Host "Testing Your Feature..." -ForegroundColor Cyan

    # Test setup
    $testConfig = @{
        "testProperty" = "testValue"
    }

    # Execute test
    $result = Test-YourFunction -Config $testConfig

    # Validate result
    if ($result -eq "expected") {
        Write-Host "[OK] Test passed" -ForegroundColor Green
    } else {
        throw "Test failed: Expected 'expected', got '$result'"
    }
}
catch {
    Write-Host "[ERROR] Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### Running Tests

```powershell
# Run individual tests
.\test\Test-ConfigValidation.ps1

# Run standalone platform GUI tests
.\test\Test-standalone-gui-functionality.ps1

# Run all tests
Get-ChildItem -Path ".\test\Test-*.ps1" | ForEach-Object { & $_.FullName }

# Use the debug task (runs all tests with formatting)
# VS Code: Ctrl+Shift+P -> "Tasks: Run Task" -> "[DEBUG] Run All Tests"
```

## Pull Request Process

### Before Submitting

1. **Ensure tests pass**
2. **Update documentation** if needed
3. **Follow coding standards**
4. **Test on clean environment** if possible

### PR Requirements

- **Clear title and description**
- **Link to related issues** (if applicable)
- **Screenshots/demos** for UI changes
- **Test results** for significant changes

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (please describe)

## Testing
- [ ] Tests pass locally
- [ ] Added new tests (if applicable)
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project standards
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

## Issue Guidelines

### Bug Reports

Use this template:

```markdown
**Describe the Bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1.
2.
3.

**Expected Behavior**
What you expected to happen

**Environment:**
- OS Version: [e.g., Windows 11]
- PowerShell Version: [e.g., 5.1.19041.1682]
- Focus Game Deck Version: [e.g., v1.2.0]

**Configuration**
Relevant parts of your config.json (remove sensitive data)

**Logs**
Error messages or log output
```

### Feature Requests

Use this template:

```markdown
**Feature Description**
Clear description of the feature

**Problem/Use Case**
What problem does this solve?

**Proposed Solution**
How you envision this working

**Alternatives Considered**
Other approaches you've thought about

**Additional Context**
Screenshots, mockups, etc.
```

## Documentation

### Documentation Structure

Follow our [Documentation Index](docs/DOCUMENTATION-INDEX.md):

- **User Documentation**: `docs/user-guide/configuration.md`, `docs/user-guide/installation.md`
- **Developer Documentation**: `docs/developer-guide/architecture.md`, `docs/developer-guide/build-system.md`
- **Project Documentation**: `docs/project-info/roadmap.md`, this file

### Documentation Standards

- Use clear, concise language
- Include code examples where applicable
- Update relevant documentation with code changes
- Follow Markdown best practices

### Key Files to Update

- **Architecture changes**: Update `docs/developer-guide/architecture.md`
- **GUI changes**: Update `docs/developer-guide/gui-design.md`
- **New features**: Update `docs/user-guide/configuration.md`
- **Build changes**: Update `docs/developer-guide/build-system.md`

## Getting Help

- **Documentation**: Start with [Documentation Index](docs/DOCUMENTATION-INDEX.md)
- **Issues**: Search existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions
- **Architecture**: Review [Architecture Documentation](docs/developer-guide/architecture.md)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

---

Thank you for contributing to Focus Game Deck! Together, we're building a tool that helps competitive gamers achieve peak focus and performance.
