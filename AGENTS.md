# AGENTS.md (Vignette / 微语单词)

## Project goal (V1)
- A HarmonyOS ArkTS app focused on "micro-context reading" to memorize words.
- V1 scope: refine existing flows, improve usability/robustness, do NOT add extra entrances or unrelated features.

## Key rules (must follow)
- ArkTS规范：命名/模块化/类型安全/错误处理/异步边界清晰；禁止随意 any；避免循环依赖。
- UI：克制、沉浸；核心学习页底部仅 3 个反馈按钮（不认识/有点印象/认识）+ 顶部撤回（仅上一词）。
- 任务加载必须：可观测（log）、可恢复（retry/兜底）、可解释（错误信息明确）。

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
  2) fixes "开始学习 -> 任务加载失败"
  3) adds built-in wordbooks with license attribution
  4) adds tests & updates docs
