# Tasks

- [x] Task 1: 在设置页新增"日志与调试"菜单项
  - [x] SubTask 1.1: 在 `SETTINGS_SECTIONS` 数组中添加 `{ id: 'logger', title: '日志与调试', subtitle: '查看、搜索与导出日志' }`
  - [x] SubTask 1.2: 在 `buildSectionContent()` 中添加 logger section 的条件渲染

- [x] Task 2: 从"关于"页面移除日志组件
  - [x] SubTask 2.1: 从 `SettingsAboutSection.ets` 中移除 `LoggerSection` 导入和使用
  - [x] SubTask 2.2: 移除 `logStats` 相关的状态和传递

- [x] Task 3: 重构 LoggerSection 为独立页面组件
  - [x] SubTask 3.1: 将 `LoggerSection.ets` 重构为 `LoggerPage.ets`，添加 `@Entry` 装饰器
  - [x] SubTask 3.2: 添加页面标题栏和返回按钮
  - [x] SubTask 3.3: 在 `main_pages.json` 中注册新页面

- [x] Task 4: 更新 SettingsPage 路由逻辑
  - [x] SubTask 4.1: 修改 logger section 点击行为，使用 `router.pushUrl` 导航到独立页面
  - [x] SubTask 4.2: 移除 SettingsPage 中不再需要的 logStats 相关状态

# Task Dependencies
- Task 2 依赖 Task 1 完成
- Task 3 和 Task 4 可并行执行
