# Test Directory Structure

This directory contains all test scripts and test infrastructure for Focus Game Deck.

## Directory Organization

```text
test/
├── scripts/              # Actual test scripts (legacy Test-*.ps1 files)
│   ├── core/            # Core functionality tests
│   ├── gui/             # GUI component tests
│   ├── integration/     # Integration tests (external services)
│   └── development/     # Development/debug tests
│
├── pester/              # Pester wrapper tests
│   ├── Core.Wrapper.Tests.ps1
│   ├── GUI.Wrapper.Tests.ps1
│   └── Integration.Wrapper.Tests.ps1
│
├── runners/             # Test execution scripts
│   ├── Invoke-PesterTests.ps1           # Run tests via Pester framework
│   └── Invoke-AllTests.ps1              # Legacy runner (direct execution)
│
├── docs/                # Test documentation
│   ├── Manual-Test-Guide.md
│   └── DEBUG-MODE.md
│
├── pester.config.psd1   # Pester configuration
├── test-results.xml     # NUnit XML test results
├── test-results.html    # HTML test report (auto-generated)
├── Convert-TestResultsToHtml.ps1  # XML to HTML converter
└── README.md           # This file
```

## Running Tests

### Option 1: Pester Framework (Recommended)

Unified test reporting with categorization and filtering:

```powershell
# Run all tests via Pester wrappers
./test/runners/Invoke-PesterTests.ps1 -OnlyWrappers

# Run only Core tests
./test/runners/Invoke-PesterTests.ps1 -Tag "Core" -OnlyWrappers

# Run GUI tests only
./test/runners/Invoke-PesterTests.ps1 -Tag "GUI" -OnlyWrappers

# Exclude integration tests (requires external services)
./test/runners/Invoke-PesterTests.ps1 -ExcludeTag "Integration" -OnlyWrappers
```

### Option 2: Direct Execution (Legacy)

Run tests directly without Pester framework:

```powershell
# Run all tests sequentially
./test/runners/Invoke-AllTests.ps1

# Skip integration tests
./test/runners/Invoke-AllTests.ps1 -SkipIntegrationTests

# Run individual test
./test/scripts/core/Test-Core-CharacterEncoding.ps1
```

### Option 3: VS Code Tasks

Use VS Code's task runner (`Ctrl+Shift+P` → "Tasks: Run Task"):

- `[TEST] Run All Tests (Sequential)` - Execute all tests
- Individual test tasks available for each test script

## Test Categories

### Core Tests (`scripts/core/`)

- Character encoding validation
- Log rotation functionality
- Configuration file validation
- Multi-platform support

### GUI Tests (`scripts/gui/`)

- ConfigEditor consistency
- UI element mapping completeness
- ComboBox localization
- Game launcher tab functionality

### Integration Tests (`scripts/integration/`)

- Discord Rich Presence
- OBS Studio WebSocket
- VTube Studio integration
- Wallpaper Engine

**Note:** Integration tests may be skipped if external services are not running.

## Output Formats

### Pester Output

```text
========================================
Test Summary
========================================
Total:   12
Passed:  10
Failed:  0
Skipped: 2
Duration: 15.3s
========================================
```

### XML Results

- Test results: `test/test-results.xml` (NUnit format)
- Compatible with CI/CD systems

### HTML Report

Generate visual HTML reports with dark mode support:

```powershell
test/Convert-TestResultsToHtml.ps1
```

**Features:**

- Visual test summary with color-coded metrics
- Automatic dark mode support (follows system preference)
- Responsive design for all screen sizes
- Detailed test results with error messages and stack traces
- Test execution time for each test
- Bilingual support (English/Japanese)
- Print-optimized layout

**Output:** `test/test-results.html` or timestamped reports in `test-results/` directory

## Adding New Tests

### 1. Create test script in appropriate directory

```powershell
# test/scripts/core/Test-Core-NewFeature.ps1
```

### 2. Add to Pester wrapper

```powershell
# test/pester/Core.Wrapper.Tests.ps1
Context "New Feature" {
    It "should test new feature" {
        $testScript = Join-Path $projectRoot "test/scripts/core/Test-Core-NewFeature.ps1"
        $output = & $testScript 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
```

### 3. Update VS Code tasks if needed

Edit `.vscode/tasks.json` to add task for manual execution.

## Migration Notes

This structure was introduced to improve organization:

- **Before**: All tests in flat `test/` directory (confusing)
- **After**: Categorized into subdirectories (clear separation)

Existing test scripts were **not modified** - only relocatedThis maintains backward compatibility while improving maintainability.

## Best Practices

1. **Use Pester for PR checks** - Provides unified reporting
2. **Run individual scripts during development** - Faster feedback
3. **Tag integration tests appropriately** - Can be skipped in CI
4. **Keep test scripts independent** - No cross-dependencies
5. **Document known issues** - Use `Set-ItResult -Skipped` in Pester wrappers
