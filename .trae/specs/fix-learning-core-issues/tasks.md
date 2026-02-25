# Tasks

- [x] Task 1: 修复新词队列排序问题
  - [x] SubTask 1.1: 修改 `getNewWordsQueueBySystemWordBook` 方法，使用 `sw.created_at` 替代 `w.created_at`
  - [x] SubTask 1.2: 修改 `getLearningQueueByUserWordBook` 的新词查询，使用 `sw.created_at` 替代 `w.created_at`
  - [x] SubTask 1.3: 验证修改后的排序逻辑正确

- [x] Task 2: 验证并修复 KNOWN 状态过滤
  - [x] SubTask 2.1: 确认 `getReviewQueueBySystemWordBook` 已正确排除 KNOWN 状态
  - [x] SubTask 2.2: 确认 `getLearningQueueByUserWordBook` 已正确排除 KNOWN 状态
  - [x] SubTask 2.3: 检查 `getNewWordsQueueBySystemWordBook` 是否需要额外过滤（当前只查 NEW，应正确）
  - [x] SubTask 2.4: 检查是否有其他代码路径获取学习队列但未过滤 KNOWN

- [x] Task 3: 验证并修复语境设置同步问题
  - [x] SubTask 3.1: 检查 `AppSettings` 中 `contextStyle` 和 `difficultyLevel` 的类型定义
  - [x] SubTask 3.2: 验证 `SettingsPage` 保存设置时枚举值的转换是否正确
  - [x] SubTask 3.3: 验证 `ReadPage` 加载设置时枚举值的转换是否正确
  - [x] SubTask 3.4: 确保 `StoryController` 正确接收并使用设置
  - [x] SubTask 3.5: 检查 `DictionaryManager.setContextPreferences` 是否正确传递参数

- [x] Task 4: 添加调试日志
  - [x] SubTask 4.1: 在学习队列获取方法中添加状态过滤的日志
  - [x] SubTask 4.2: 在语境设置变更流程中添加日志
  - [x] SubTask 4.3: 在故事生成请求中添加风格和难度的日志

# Task Dependencies
- Task 2 依赖 Task 1（先修复排序，再验证过滤）
- Task 3 独立
- Task 4 可与 Task 1-3 并行
