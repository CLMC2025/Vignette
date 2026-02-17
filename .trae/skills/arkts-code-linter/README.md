# ArkTS Code Linter

A code linting skill for ArkTS based on Huawei HarmonyOS NEXT official documentation.

## Features

- ✅ **Strict Type Checking**: Disallow `any`/`unknown`, enforce explicit type declarations
- ✅ **ArkUI Standards**: Check decorators, state management, layout specifications
- ✅ **Performance Suggestions**: LazyForEach, rendering optimization, memory management
- ✅ **Naming Conventions**: PascalCase, camelCase, UPPER_SNAKE_CASE

## Usage

This skill is automatically invoked by the AI assistant when:
- Writing or reviewing ArkTS code
- Detecting potential specification violations
- Suggesting code improvements

## Rules

| Rule | Description | Severity |
|------|-------------|----------|
| no-any | Disallow any type | error |
| no-unknown | Disallow unknown type | error |
| no-px-unit | Disallow px units | error |
| lazy-for-each | Suggest LazyForEach for lists | warning |
| naming-class | Class names use PascalCase | error |
| naming-interface | Interface names use PascalCase | error |

## References

- [Huawei Developer Docs](https://developer.huawei.com/consumer/cn/doc/)
- [ArkTS Language Guide](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-basics-V5)

## License

MIT License
