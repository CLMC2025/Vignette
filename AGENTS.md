# AGENTS.md (Vignette / 微语境)

## Project goal (V1)
- A HarmonyOS ArkTS app focused on "micro-context reading" to memorize words.
- V1 scope: refine existing flows, improve usability/robustness, do NOT add extra entrances or unrelated features.

## Key rules (must follow)
- ArkTS类型: 避免使用any和unknown，使用明确的类型注解。函数参数和返回值必须有类型声明。使用interface定义复杂类型。
- ArkTSCheck: 使用Promise<{...}> 替代 {...} 作为异步返回类型。避免使用as unknown as ...，如需类型断言请使用as。
- UI: 使用ArkTS装饰器语法，避免使用字符串拼接构建UI。使用@State、@Prop、@Link等装饰器管理状态。
- 错误处理: 使用try-catch捕获异常，记录日志，提供用户友好的错误提示。

## Build / test
- Build HAP: use the repo's existing hvigor command (search existing scripts/README). If missing, run:
  - hvigorw assembleHap (or the equivalent in this repo)
- Tests:
  - run existing ohosTest/hypium tests if present
  - add unit tests for task loading / parsing / offline fallback

## Where to work
- Implement UI per docs/spec/V1_UI_SPEC.md
- Acceptance criteria per docs/spec/V1_ACCEPTANCE.md
- Built-in wordbooks per docs/spec/V1_WORDLISTS.md
- Follow existing folder conventions; do not reorganize the whole repo in V1.

## Deliverables
- A PR that:
  1) implements V1 UI + navigation
  2) fixes "类型错误 -> 运行时异常"
  3) adds built-in wordbooks with license attribution
  4) adds tests & updates docs
