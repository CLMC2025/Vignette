---
name: arkts-code-linter
description: Detect and fix ArkTS code specification issues. Run in real-time while writing ArkTS code, or execute before code review to ensure code complies with HarmonyOS NEXT official specifications.
author: clmc2025
version: "1.0.0"
license: MIT
tags:
  - arkts
  - harmonyos
  - openharmony
  - linter
  - code-quality
  - static-analysis
---

# ArkTS Code Linter

A comprehensive code linting tool for ArkTS based on Huawei HarmonyOS NEXT official documentation.

## Overview

This tool provides comprehensive ArkTS code specification detection and repair functions to help developers write high-quality code that complies with official specifications.

## Core Features

### 1. Comprehensive Specification Scanning
- **Type Safety**: Detect `any`/`unknown` usage, enforce explicit type declarations
- **ArkUI Standards**: Check decorators, state management, layout specifications
- **Naming Conventions**: Validate PascalCase, camelCase, UPPER_SNAKE_CASE
- **Performance Optimization**: Identify LazyForEach usage, rendering optimization suggestions

### 2. Smart Auto-Fix
- Auto-fix indentation and whitespace issues
- Auto-replace px units with vp
- Auto-convert CommonJS require to ES6 import

### 3. Flexible Configuration
- Support `.arktslintrc.json` configuration file
- Support line-level and file-level ignore comments
- Customizable rule severity levels

## Usage

This skill is automatically invoked by the AI assistant when:
- Writing or reviewing ArkTS code
- Detecting potential specification violations
- Suggesting code improvements

### Configuration

Create `.arktslintrc.json` in project root:

```json
{
  "rules": {
    "no-any": "error",
    "no-unknown": "error",
    "no-px-unit": "error",
    "use-vp-fp": "warning",
    "lazy-for-each": "error",
    "indent": ["error", 2],
    "naming-convention": "error"
  },
  "ignore": [
    "node_modules/**",
    "build/**",
    "oh_modules/**",
    "*.test.ets"
  ]
}
```

## Rules

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

## Rule Details

### Language Specification (Mandatory)

#### Strict Type Safety
- **No `any` type**: All variables and function return values must have explicit types
- **No `unknown` type**: Special cases require comments
- **Null safety**: Must handle `null` and `undefined`
- **ESObject usage**: Only use when interacting with JS libraries

#### Syntax Restrictions
- **Class field initialization**: Must initialize in declaration or constructor
- **Module standards**: Use ES6 `import`/`export`, no CommonJS `require`
- **Type declarations**: No inline object literals, use named `interface`/`type`
- **JSON parsing**: Must convert to explicit struct types after `JSON.parse()`

### ArkUI Development Standards

#### Component Design
- **Decorator checks**: `@Component`, `@Entry` usage standards
- **Builder syntax**: No early return or plain statements in `@Builder`
- **Component splitting**: Single file should not exceed 500 lines

#### State Management
- **Decorator selection**: Correct use of `@State`, `@Prop`, `@Link`, `@Provide`/`@Consume`
- **State updates**: Must update via assignment, no direct object property modification

#### Layout & Styling
- **Unit standards**: Use `vp`/`fp`, no hardcoded `px`
- **Layout performance**: Reduce `Stack`/`Flex` nesting, prefer `RelativeContainer`
- **List rendering**: Must use `LazyForEach` with unique `keyGenerator`

### Performance Optimization

#### Rendering Performance
- **LazyForEach**: Long lists must use lazy loading
- **Conditional rendering**: Use `visibility` instead of `if/else` for frequent toggles
- **Image optimization**: Use `sourceSize` for large images

#### Concurrency & Async
- **Main thread relief**: Move time-consuming operations to `TaskPool` or `Worker`
- **Async standards**: Use Promise or async/await

#### Memory Management
- **Resource release**: Unregister listeners and timers in `aboutToDisappear`
- **Context leaks**: Don't hold `AbilityContext` or UI component references

### Project Architecture

#### Directory Structure
```
entry/src/main/ets/
├── pages/          # Page entries (@Entry)
├── components/     # Shared UI components
├── model/          # Data models
├── utils/          # Utilities
├── service/        # Business logic services
└── resources/      # Static resources
```

#### Naming Conventions
- **Classes/Interfaces/Components**: PascalCase
- **Variables/Functions**: camelCase
- **Constants/Enums**: UPPER_SNAKE_CASE

## References

- [HarmonyOS NEXT Docs](https://developer.huawei.com/consumer/cn/doc/)
- [ArkTS Language Guide](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-basics-V5)
- [ArkUI Development Guide](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkui-overview-V5)
- [Performance Best Practices](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/performance-overview-V5)

## License

MIT License
