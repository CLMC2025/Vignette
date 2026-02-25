# 语言配置 / Language Configuration

**【强制要求】所有回复必须使用中文（简体）。**

**CRITICAL REQUIREMENT: You MUST respond in Simplified Chinese at ALL TIMES.**

- 与用户交流时必须使用中文
- 代码注释使用中文（除非用户明确要求英文）
- 错误信息和解释使用中文
- 技术术语可保留英文，但首次出现时需附中文解释
- This instruction has the highest priority and must be followed without exception

---

# Vignette Project - Agency Development Guidelines
Vignette is a HarmonyOS NEXT native language learning app built with ArkTS/ArkUI that uses FSRS (Forgotten Curve Spaced Repetition Scheduler) algorithm combined with AI-generated contextual stories for vocabulary learning.
- Language: ArkTS (TypeScript extension) + JavaScript
- Framework: ArkUI (HarmonyOS native UI)
- Database: RdbStore (SQLite-based)
- Algorithm: FSRS-6.1.1 spaced repetition algorithm 
- Platform: HarmonyOS NEXT
## Build System Commands
### Building the Application
```bash
# Standard build via Hvigor tool
hvigor build                # Default release build
hvigor buildDebug           # Debug build
hvigor --mode module -p module=entry debug # Specific module debug build
hvigorw build              # Use wrapper script if available
```
### Running Tests
```bash
# Run all HarmonyOS instrumented tests (in src/ohosTest/)
npm test                            # Run tests via script
npx hvigorw --mode module -p module=entry@ohosTest test   # Run directly via hvigor
# Due to HarmonyOS testing framework, individual tests are typically run via DevEco Studio
# There's no direct script to run single ArkTS test files outside of the full test suite
```
### Development Commands
```bash
# Preview in DevEco Studio
hvigor preview                    # Preview current module
hvigor previewEntryDebug          # Preview Entry module specifically
hvigor clean                      # Clean compiled outputs
rm -rf ./build ./oh_modules       # Manual cleanup if needed
ohpm install                      # Install project dependencies via HarmonyOS Package Manager
```

## Linting & Code Quality
### Lint Configuration
- Linter: HarmonyOS code linter based on ESLint rules (code-linter.json5)
- Rules: Security-focused + TypeScript recommended + Performance recommended
- Files: Applied to all .ets files by default (except test, mock, build directories)
### ArkTS Code Linter (Specialized Tool)
The project has a specialized ArkTS code linter skill with various rules:
| Rule | Description | Severity | Fixable |
|------|-------------|----------|---------|
| no-any | Disallow any type | error | ❌ |
| no-unknown | Disallow unknown type | error | ❌ |
| no-px-unit | Disallow px units | error | ✅ |
| use-vp-fp | Suggest vp/fp units | warning | ✅ |
| lazy-for-each | Suggest LazyForEach for lists | warning | ❌ |
| no-require | Disallow CommonJS require | error | ✅ |
| indent | Indentation (2 spaces) | error | ✅ |
| naming-class | Class names use PascalCase | error | ❌ |
| naming-interface | Interface names use PascalCase | error | ❌ |
| trailing-whitespace | No trailing whitespace | warning | ✅ |
### Code Linting Commands
```bash
# Run HarmonyOS linter (if available in environment)
# Note: Specific linter command varies depending on DevEco Studio installation
# Manual inspection needed for ArkTS-specific patterns
```
### Linting Rules
- All variables, functions, and parameters must have explicit type annotations
- No use of `any` or `unknown` types allowed
- Security-focused checks (e.g., unsafe encryption algorithms)
- Performance recommendations from HarmonyOS
## Code Style Guidelines
### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Classes/Interfaces/Components | PascalCase | `WordBookRepository`, `LearningHeatmap`, `BookCard` |
| Variables/Functions/Methods | camelCase | `loadData`, `currentBook`, `initializeSession` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `NETWORK_CONNECT_TIMEOUT_MS` |
| Files | PascalCase (Component files) | `SessionTransferStore.ets`, `BookCard.ets` |
### ArkTS Language Specification (Mandatory)

ArkTS is HarmonyOS NEXT's main development language, based on TypeScript extension, with stricter runtime constraints for improved performance.

#### Strict Type Safety
- **Prohibit using `any` and `unknown`**: All variable and function return types must be explicitly declared.
- **Prohibit runtime dynamic features**: No dynamic property addition, deletion, etc.
- **Null safety**: Enable strict null checking (`strictNullChecks`) and explicitly handle `null` and `undefined` in code.
- **ESObject only**: Use ESObject only when interacting with JS libraries or cross-language calls, and convert to specific ArkTS types as soon as possible.

#### Syntax Restrictions
- **Class definitions**: Fields must be initialized at declaration or in constructor.
- **Modularization**: Use ES6 modules standard (`import`/`export`), prohibit CommonJS (`require`).
- **Concurrency model**: ArkTS uses Actor model with memory isolation. Inter-thread communication requires `TaskPool` or `Worker`, with data passing usually deep copying or Transferable objects.
- **Type declaration limitations**: Prohibit using inline object literals as type declarations (e.g. `as { foo?: string }`), must use named `interface`/`type` instead.
- **JSON parsing**: `JSON.parse()` must convert to explicit structure types; prohibit using `any`/`unknown`/`Record<string, unknown>` as intermediate type.
### Import Organization
Imports should follow this general order:
1. HarmonyOS built-in modules (@ohos.*)
2. Third-party libraries 
3. Internal project modules
4. Local utilities/models/components
Example:
```typescript
import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';
import { normalizeQueueFromRouterParams, RawQueueItem, RawWordItem } from './RouteParamNormalizer';
```
### Type Annotations
All functions and variables must have explicit type annotations:
- No `any` or `unknown` types permitted
- Interface definitions recommended over inline object types
- JSON parsing results must be cast to explicit structures
- Use `@Component` decorator for all UI components
- State management with `@State`, `@Prop`, `@Link`, `@Provide`/`@Consume` decorators
- Use `build()` method for UI declaration
- Avoid deeply nested layouts (prefer RelativeContainer and LazyForEach)
- Use Virtual/Prefetch components for large datasets
- Follow ArkUI development constraints:
  - **Componentization Design**:
    - **`@Component`** - UI components must use `@Component` decorator
    - **`@Entry`** - Page entry components use `@Entry` decorator
    - **`@Builder` / `@BuilderParam`** - Lightweight UI reuse, prefer over custom components to reduce component instance overhead
    - **Component Splitting** - Divide complex pages into multiple child components to maintain clear code, each component file not exceeding 500 lines
    - **Builder Syntax** - `@Builder` can only contain UI component syntax inside, disallows `return` early exit or inserting plain statement blocks; conditional rendering uses `if (cond) { ... }`
  - **State Management**:
    - **Principle** - Minimize state sharing scope, avoid excessive global state use
    - **Decorator selection**:
        - `@State` - Component internal private state
        - `@Prop` - Parent-child one-way sync (Parent -> Child)
        - `@Link` - Parent-child two-way sync (Parent <-> Child)
        - `@Provide`/`@Consume` - Cross-component level sync
        - `AppStorage`/`LocalStorage` - Global or page-level state sharing
    - **Update mechanism** - State variables must be updated via assignment, don't directly modify object properties (unless using `@Observed` and `@ObjectLink` to handle nested objects)
  - **Layout and Styling**:
    - **Units** - Unify with `vp` (virtual pixel) and `fp` (font pixel), prohibit hardcoded `px`
    - **Layout performance**:
        - Reduce layout nesting levels (especially for `Stack` and `Flex` deep nesting)
        - Prefer `RelativeContainer` to replace complex nested layouts
        - List rendering must use `LazyForEach`, and provide unique `keyGenerator` to avoid full redraw
    - **Adaptability** - Use breakpoints (`GridRow`/`GridCol`) and media query to adapt for multiple device screens
### Error Handling Patterns
- Use explicit try/catch blocks with meaningful error messages
- Log specific error information using HarmonyOS console API
- Graceful fallback handling where appropriate
- Proper disposal of resources in aboutToAppear/aboutToDisappear lifecycle
Example:
```typescript
async initialize(): Promise<boolean> {
  if (this.isInitialized) {
    return true;
  }
  try {
    // ...
    return true;
  } catch (e) {
    const errMsg = e instanceof Error ? e.message : String(e);
    console.error(`[SessionTransferStore] Failed to initialize: ${errMsg}`);
    return false;
  }
}
```
### Asynchronous Operations
- Use async/await consistently
- Timeout configuration with sensible defaults (network timeouts, story generation timeouts, etc.)
- Error propagation following Promise patterns
- Background processing for heavy operations using HarmonyOS TaskPool/Worker
- HarmonyOS concurrency and async best practices:
  - **Main thread burden reduction** - Time-consuming operations (IO, complex calculations, network requests) must move to background threads
  - **TaskPool** - Prioritize use of `TaskPool` to handle short-term tasks; system automatically manages thread lifecycle
  - **Worker** - Applicable to long-running backend tasks
  - **Promise** - Use Promise and async/await for asynchronous operations, avoid callback hell

### Performance Optimization
- **Rendering Performance**:
  - `LazyForEach`: Long lists must use lazy loading,配合 cachedCount for prefetching.
  - Conditional rendering: Use `visibility` instead of `if/else` for frequent toggles
  - For large images: Use `sourceSize` property of Image component to clip decode size avoiding memory waste
- **Memory Management**:
  - Release resources promptly in component destruction (`aboutToDisappear`): unregister event listeners, timers, and background tasks
  - Context leakage: Don't hold `AbilityContext` or UI component references in long-life objects
### Logging Standards
- Use `[ClassName]` prefix to identify source in logs
- Differentiate between info (`console.info`) and error (`console.error`) logs
- Meaningful messages that help with debugging
- Avoid logging sensitive data
## Testing Patterns

### Test Framework and Structure
Tests follow the Hypium framework:
```typescript
describe('testSuiteName', () => {
  beforeEach(() => { ... });      // Setup before each test
  afterEach(() => { ... });      // Cleanup after each test
    // Test implementation using expect() assertions
    expect(actualValue).assertEqual(expectedValue);
  });
});
```
### Test Categories
Two test directories:
- `entry/src/test/` - Local unit tests using Hypium (src/test/)
- `entry/src/ohosTest/` - Instrumented HarmonyOS tests (src/ohosTest/)
### Assertion Pattern
- Use hypium assertion methods: `expect().assertEqual()`, `expect().assertContain()`, etc.
- Focus on expected behavior validation
- Mock dependencies where necessary for unit isolation
### Test Configuration
- Located in `entry/src/ohosTest/module.json5` for module config
- Located in `entry/src/test/LocalUnit.test.ets` for local test examples
- Located in `entry/src/ohosTest/ets/test/` for specific test files for different functionalities

## Directory Structure

```
D:/DevEcoStudioProjects/Vignette/
│
├── AppScope/
│   └── resources/base/element/string.json  # App-level resources
├── entry/
│   ├── src/
│   │   ├── main/
│   │   │   ├── ets/           # Source code root
│   │   │   │   ├── pages/     # Page entry components (@Entry)
│   │   │   │   ├── components/ # Reusable UI components (@Component)
│   │   │   │   ├── model/     # Data models (Classes and Interfaces)
│   │   │   │   ├── utils/     # Utility functions and helper classes
│   │   │   │   ├── database/  # Database services and repository patterns
│   │   │   │   ├── vocabulary/ # Vocabulary-specific functionality
│   │   │   │   ├── sync/      # WebDAV synchronization logic
│   │   │   │   ├── service/   # Business logic services
│   │   │   │   ├── ui/        # UI animations and reusable elements
│   │   │   │   └── entryability/ # HarmonyOS Ability entry points
│   │   │   ├── resources/    # Resource files and assets
│   │   │   └── module.json5  # Module configuration
│   │   ├── test/            # Local unit tests
│   │   └── ohosTest/        # HarmonyOS instrumented tests
├── scripts/                 # Build and automation scripts
├── hvigor/                  # Hvigor build tools configuration
├── build-profile.json5     # Build configuration
├── hvigorfile.ts           # Hvigor build script
├── package.json            # Node.js scripts and dependencies
├── oh-package.json5        # HarmonyOS package configuration
├── code-linter.json5       # Code quality rules
├── jsconfig.json           # JavaScript/Typescript settings
└── README.md              # Project overview
```

## Contribution Guidelines

### Git Workflow
- Create feature branches: `git checkout -b feature/NewFeatureName`
- Make commits following conventional commit format (see commit message standard below)
- Create pull request against `main` branch

### Commit Message Standard
```
feat: Add new capability 
fix: Correct bugs  
docs: Documentation only changes
style: Formatting, missing semi-colons, etc.
refactor: Code changes that neither fix bugs nor add features
perf: Performance improvements
test: Add missing tests or fix existing tests
chore: Maintainence tasks unrelated to source
```

Use conventional commit format: `category: brief description`.

### File Extensions Reference
- `.ets` - ArkTS files with UI and state capabilities
- `.ts` - Traditional TypeScript files
- `.json5` - JSON5 files (supports comments)
- `.js` - JavaScript files

## Special Considerations
### HarmonyOS-Specific Patterns
- Memory isolation between threads (Actor model) - use TaskPool/Worker for background processing
- Strict compile-time checks on ArkTS compared to regular TypeScript
- UI reactivity relies on decorator-driven state management
- Lifecycle management for Ability and Components
- Minimize requested permissions - apply only mandatory business permissions (`module.json5`) 
- Runtime sensitive permissions must request user approval dynamically
- Data security -:
  - Store sensitive data (tokens, passwords) using WebDavCrypto or system-level `KeyStore`
  - Local database using `RdbStore` or `Preferences`, prefer encryption

## Build Tool Specifications

### Hvigor Build System
- Default build system for HarmonyOS projects
- Supports multiple build types (debug, release)
- Manages dependencies and package structure
- Enables code obfuscation and security options

### Signing Configuration
- Located in 'build-profile.json5' under signingConfigs
- Uses HarmonyOS certificates (p12 format)
- Certificate profile file (p7b format)
- Stores sensitive information in encrypted form

## Environment Setup for Agencies
Before working on this codebase, agencies should:
1. Have access to HarmonyOS development environment and DevEco Studio
2. Understand ArkTS limitations (no dynamic properties, strict typing)
3. Be aware of threading models (no shared memory between threads)
4. Understand ArkUI component lifecycles and state management patterns
## Contributing Information
See CONTRIBUTING.md for detailed contribution guidelines and coding standards.

## Important Constants
Many values come from the `Constants` class in `utils/Constants.ets`:
- Network timeouts (30s connect/read/write)
- Cache sizes and limits  
- Animation durations
- Maximum values for various configurations
## Important ArkTS Coding Rules

When working on this HarmonyOS NEXT ArkTS project, keep in mind the following common pitfalls to avoid compilation errors:

### 1. Type Safety & Syntax Restrictions
- **No `any` or `unknown` types**: Always declare explicit types
- **No type annotations in `catch` clauses** (arkts-no-types-in-catch): Use `catch (e)` not `catch (e: unknown)`
- **Explicit types instead of 'any'/'unknown'** (arkts-no-any-unknown): Use specific interfaces/types
- **Unique names required** (arkts-unique-names): No duplicate type/namespace names

### 2. Spread Operator Limitations
- **Limited spread usage**: Only arrays/classes derived from arrays can be spread
- **Avoid complex spreads** in expressions like `[...new Set([...arr1, ...arr2])]`
- Instead, manually iterate: loop through arrays to populate collections

### 3. Standalone 'this' Usage
- **No 'this' in standalone functions**: Use class instance or static context

### 4. Variable Declaration Restrictions
- **No destructuring in variable declarations** for certain contexts

### 5. Common Safe Patterns
```typescript
// Instead of spread with set
// BAD: const combined = [...new Set([...arr1, ...arr2])]
// GOOD:
const set = new Set();
for (const item of arr1) { set.add(item); }
for (const item of arr2) { set.add(item); }
const result = Array.from(set);

// Catch clauses
// BAD: catch (e: unknown)
// GOOD: catch (e)

// Type checking in catch
// Use: e instanceof Error ? e.message : String(e)
```
