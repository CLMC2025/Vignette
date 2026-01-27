# V1 Acceptance Criteria

## Core navigation
- Home -> Wordbook -> Word List -> Word Detail 可达
- Home -> Start Learning -> Session 可达
- Word List 点击任意单词：进入/弹出 Word Detail（必须能看见详细信息）

## Start Learning reliability
- 点击“开始学习”：
  - 必须出现 loading 状态（spinner 或 skeleton）
  - 成功：渲染第一张语境卡
  - 失败：提示明确原因（网络/解析/无数据/权限等）+ 提供可操作按钮（重试/返回/使用离线兜底）
- 不允许只弹“任务加载失败”且无恢复路径

## Session UX (pure micro-context)
- 语境区：目标词下划线/高亮；每个单词可点击查看释义/详情
- 底部：三个按钮（不认识/有点印象/认识），点击进入下一词
- 撤回：仅撤回上一词（按钮置灰逻辑正确）
- 长语境可滚动，并能自动滚到高亮附近

## Wordbooks
- 内置 CET4/CET6/考研 等词书至少可用（可只内置词+基础释义，具体以数据源为准）
- 必须包含第三方数据源的 LICENSE/NOTICE

## Tests
- 任务加载：至少覆盖
  - 正常返回 -> 任务列表生成成功
  - 网络失败 -> 进入离线兜底路径
  - 数据格式异常 -> 明确错误提示且不崩溃
