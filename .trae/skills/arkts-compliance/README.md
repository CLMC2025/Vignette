# ArkTS Compliance Skill

A comprehensive ArkTS/ETS coding compliance system that enforces strict coding rules following the latest ArkTS language specifications. This tool provides both real-time code formatting during development and post-development code analysis.

## Features

### 🔍 **Code Analysis**
- Scans ArkTS/ETS files for compliance violations
- Supports large codebases with parallel processing
- Recursive directory scanning
- False positive filtering

### 📋 **Rule System**
- **Syntax Rules**: No `any`/`unknown` types, no destructuring, explicit types
- **Naming Conventions**: Component, function, constant, and type naming rules
- **UI Component Rules**: Proper UI syntax usage, animation API compliance
- **Performance Rules**: ForEach key requirements, lazy loading
- **Security Rules**: Input validation, no hardcoded secrets

### 📄 **Comprehensive Reports**
- Multiple formats: Markdown, HTML, JSON
- Detailed violation information with line numbers and code snippets
- Violation severity levels (error, warning, info)
- Fix suggestions for each violation

### ⚙️ **Configurable**
- Project-specific rule enable/disable
- Customizable severity levels
- Exclude specific files/directories
- Project-specific naming conventions

## Installation

```bash
# Install globally
npm install -g arkts-compliance

# Install locally for project
npm install --save-dev arkts-compliance
```

## Usage

### Basic Analysis

```bash
# Analyze directory with default config
arkts-compliance analyze ./src

# Analyze with custom config
arkts-compliance analyze ./src --config ./arkts-compliance.yaml

# Save report to file
arkts-compliance analyze ./src --output compliance-report.md

# Generate HTML report
arkts-compliance analyze ./src --format html --output compliance-report.html
```

### Check Single File

```bash
arkts-compliance check ./src/pages/Index.ets
```

### Create Default Config

```bash
arkts-compliance init
```

## Configuration

### Default Configuration

```yaml
# ArkTS Compliance Configuration
rules:
  # Syntax rules
  no-any-unknown:
    severity: error
    enabled: true
  no-destructuring:
    severity: error
    enabled: true
  no-param-destructuring:
    severity: error
    enabled: true
  no-inline-object-types:
    severity: error
    enabled: true
  valid-property-names:
    severity: error
    enabled: true

  # Naming conventions
  component-names:
    severity: error
    enabled: true
  function-names:
    severity: error
    enabled: true
  constant-names:
    severity: error
    enabled: true

  # UI component rules
  ui-in-model:
    severity: error
    enabled: true
  no-on-finish:
    severity: error
    enabled: true
  no-ease-out-back:
    severity: warning
    enabled: true
  no-spring-curve:
    severity: warning
    enabled: true

  # Performance rules
  foreach-key:
    severity: error
    enabled: true

  # Type safety rules
  explicit-return-types:
    severity: error
    enabled: true

exclude:
  - node_modules
  - build
  - .preview
  - oh_modules

namingConventions:
  componentNames: PascalCase
  functionNames: camelCase
  constantNames: UPPER_SNAKE_CASE
  typeNames: PascalCase
```

## Available Rules

| Rule ID | Name | Category | Severity | Description |
|---------|------|----------|----------|-------------|
| `no-any-unknown` | No any/unknown types | syntax | error | Avoid using any or unknown types |
| `no-destructuring` | No destructuring | syntax | error | Destructuring is not supported in strict ArkTS |
| `no-param-destructuring` | No parameter destructuring | syntax | error | Parameter destructuring is not supported |
| `no-inline-object-types` | No inline object types | syntax | error | Use explicit interfaces instead of inline object types |
| `valid-property-names` | Valid property names | syntax | error | Object property names must be valid identifiers |
| `component-names` | Component names | naming | error | Component names must be PascalCase |
| `function-names` | Function names | naming | error | Function names must be camelCase |
| `constant-names` | Constant names | naming | error | Constant names must be UPPER_SNAKE_CASE |
| `ui-in-model` | No UI in model files | ui | error | UI syntax should only be in UI files |
| `no-on-finish` | No onFinish property | ui | error | The onFinish property is not supported |
| `no-ease-out-back` | No Curve.EaseOutBack | ui | warning | Curve.EaseOutBack is not supported in all versions |
| `no-spring-curve` | No Curve.Spring | ui | warning | Curve.Spring is not supported in all versions |
| `foreach-key` | ForEach must have key | performance | error | ForEach loops must include a key attribute |
| `explicit-return-types` | Explicit return types | type-safety | error | Functions must have explicit return types |

## Integration

### IDE Integration

#### VS Code
1. Install the "ArkTS Compliance" extension
2. Configure the extension in VS Code settings
3. Enjoy real-time linting and auto-formatting

#### DevEco Studio
1. Install the "ArkTS Compliance" plugin
2. Configure plugin settings
3. Get inline violation indicators and quick fixes

### CI/CD Integration

```yaml
# GitHub Actions example
name: ArkTS Compliance

on: [push, pull_request]

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm install
      - name: Install ArkTS Compliance
        run: npm install -g arkts-compliance
      - name: Run compliance check
        run: arkts-compliance analyze ./src --output compliance-report.md
      - name: Upload report
        uses: actions/upload-artifact@v3
        with:
          name: compliance-report
          path: compliance-report.md
```

## Real-time Formatting

The ArkTS Compliance Skill provides real-time code formatting through IDE plugins:

1. **Auto-formatting on save**: Automatically formats code to follow rules when saving
2. **Inline linting**: Shows violation indicators in the editor gutter
3. **Quick fixes**: One-click fixes for common issues
4. **Hover information**: Shows rule description and fix suggestions when hovering over violations

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                      ArkTS Compliance                   │
├───────────┬──────────────┬────────────────┬─────────────┤
│ Rule      │ Code         │ Report         │ Config      │
│ Engine    │ Analyzer     │ Generator      │ Manager     │
├───────────┼──────────────┼────────────────┼─────────────┤
│ Defines   │ Scans files  │ Creates        │ Handles     │
│ all coding│ for          │ comprehensive  │ project-    │
│ rules     │ violations   │ compliance     │ specific    │
│           │              │ reports        │ configs     │
└───────────┴──────────────┴────────────────┴─────────────┘
```

## Development

### Build from Source

```bash
git clone https://github.com/your-org/arkts-compliance.git
cd arkts-compliance
npm install
npm run build
npm link
```

### Run Tests

```bash
npm test
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.