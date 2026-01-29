# Test Strategy Guide

This document defines the testing strategy for Focus Game Deck, including test categorization, tagging conventions, and execution environments.

## Test Categories and Tags

### Tag Hierarchy

Tests are organized using a hierarchical tag system:

| Level | Purpose | Examples |
|-------|---------|----------|
| **Primary** | Test category | `Unit`, `Integration`, `E2E` |
| **Domain** | Functional area | `Core`, `GUI`, `Localization` |
| **Feature** | Specific feature | `Validation`, `Encoding`, `Logging` |

### Primary Tags

| Tag | Description | External Dependencies | CI/CD | Local |
|-----|-------------|----------------------|-------|-------|
| `Unit` | Pure logic tests without external dependencies | None | ✅ Run | ✅ Run |
| `Integration` | Tests requiring external services | Discord, OBS, VTube Studio | ⏭️ Skip | ✅ Run (if available) |
| `E2E` | End-to-end workflow tests | Full application stack | ⏭️ Skip | ✅ Run |

### Domain Tags

| Tag | Description | Dependencies |
|-----|-------------|--------------|
| `Core` | Core functionality (validation, encoding, logging) | None |
| `GUI` | GUI/WPF related tests | WPF assemblies |
| `Localization` | Localization system tests | Localization files |

### Feature Tags

| Tag | Description | Associated Domain |
|-----|-------------|-------------------|
| `Validation` | Configuration validation rules | Core |
| `ValidationRules` | Specific validation rule functions | Core |
| `Encoding` | Character encoding tests | Core |
| `Logging` | Log rotation and management | Core |
| `Diagnostic` | Diagnostic analysis tests | GUI, Localization |

## Test File Naming Convention

```
<Domain>.<Feature>.Tests.ps1
```

Examples:
- `Core.CharacterEncoding.Tests.ps1`
- `Core.ConfigValidation.Tests.ps1`
- `GUI.ComboBoxLocalization.Tests.ps1`
- `Integration.Wrapper.Tests.ps1`

## Test Execution Matrix

### CI/CD Environment (GitHub Actions)

```powershell
# Runs all tests except Integration
./test/runners/Invoke-PesterTests.ps1 -ExcludeTag "Integration"
```

| Test File | Tags | Executed in CI |
|-----------|------|----------------|
| Core.CharacterEncoding.Tests.ps1 | `Unit`, `Core`, `Encoding` | ✅ |
| Core.ConfigValidation.Tests.ps1 | `Unit`, `Core`, `Validation` | ✅ |
| Core.LogRotation.Tests.ps1 | `Unit`, `Core`, `Logging` | ✅ |
| Core.ValidationRules.Tests.ps1 | `Unit`, `Core`, `ValidationRules` | ✅ |
| Core.Wrapper.Tests.ps1 | `Unit`, `Core` | ✅ |
| GUI.ComboBoxLocalization.Tests.ps1 | `Unit`, `GUI`, `Localization` | ✅ |
| GUI.LocalizationIntegrity.Tests.ps1 | `Unit`, `GUI`, `Localization`, `Diagnostic` | ✅ |
| GUI.Wrapper.Tests.ps1 | `Unit`, `GUI` | ✅ |
| Localization.Tests.ps1 | `Unit`, `Localization` | ✅ |
| Integration.Wrapper.Tests.ps1 | `Integration` | ⏭️ Skipped |

### Local Development Environment

```powershell
# Run all tests
./test/runners/Invoke-PesterTests.ps1

# Run only Unit tests
./test/runners/Invoke-PesterTests.ps1 -Tag "Unit"

# Run only Integration tests (requires external services)
./test/runners/Invoke-PesterTests.ps1 -Tag "Integration"

# Run specific domain tests
./test/runners/Invoke-PesterTests.ps1 -Tag "Core"
./test/runners/Invoke-PesterTests.ps1 -Tag "GUI"
./test/runners/Invoke-PesterTests.ps1 -Tag "Localization"
```

## Environment Detection

Tests can use the helper module to detect the execution environment:

```powershell
# Load environment helper
. "$PSScriptRoot/../helpers/Test-Environment.ps1"

# Check environment
if (Test-IsCI) {
    # Running in CI/CD
}

if (Test-IsLocal) {
    # Running locally
}

# Check for integration targets
if (Test-HasIntegrationTarget -Target 'Discord') {
    # Discord is available
}
```

See [test/helpers/Test-Environment.ps1](../helpers/Test-Environment.ps1) for full API.

## Integration Test Requirements

Integration tests require specific external services to be running:

| Test | Required Service | Detection Method |
|------|------------------|------------------|
| Discord Integration | Discord Desktop App | Process: `Discord` |
| OBS Integration | OBS Studio | Process: `obs64` or `obs32` |
| VTube Studio Integration | VTube Studio | Process: `VTube Studio` |

### Graceful Degradation

Integration tests should gracefully skip when services are unavailable:

```powershell
It "should connect to Discord" {
    if (-not (Test-HasIntegrationTarget -Target 'Discord')) {
        Set-ItResult -Skipped -Because "Discord is not available in the test environment"
        return
    }
    # Actual test logic here
}
```

## Adding New Tests

### Step 1: Determine Tags

1. **Primary Tag**: Is this a `Unit`, `Integration`, or `E2E` test?
2. **Domain Tag**: Which area does it test? (`Core`, `GUI`, `Localization`)
3. **Feature Tag**: What specific feature? (optional)

### Step 2: Create Test File

```powershell
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.NOTES
    Author: Focus Game Deck Team
    Version: 1.0.0
    Tags: Unit, Core, YourFeature
#>

BeforeAll {
    # Setup code
}

Describe "Your Test Suite" -Tag "Unit", "Core", "YourFeature" {
    Context "Test Context" {
        It "should do something" {
            # Test code
        }
    }
}
```

### Step 3: Verify Execution

```powershell
# Verify test runs with expected tags
Invoke-Pester -Path './test/pester/YourTest.Tests.ps1' -PassThru

# Verify tag filtering works
./test/runners/Invoke-PesterTests.ps1 -Tag "YourFeature"
```

## Best Practices

### Do

- ✅ Use `Unit` tag for tests without external dependencies
- ✅ Use `Integration` tag for tests requiring external services
- ✅ Use `Set-ItResult -Skipped` for conditional skipping with clear reasons
- ✅ Load environment helper for environment-aware tests
- ✅ Document test dependencies in `.NOTES` section

### Don't

- ❌ Use `Integration` tag for tests that can run offline
- ❌ Skip tests without providing a reason
- ❌ Hard-code environment checks without using the helper module
- ❌ Create tests that fail silently in CI/CD

## Related Documentation

- [Architecture Guide](../../docs/developer-guide/architecture.md)
- [Build System](../../docs/developer-guide/build-system.md)
- [Test Environment Helper](../helpers/Test-Environment.ps1)
