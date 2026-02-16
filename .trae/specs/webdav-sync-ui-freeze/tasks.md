# Tasks

- [x] Task 1: 修复加密操作阻塞 UI 问题
  - [x] SubTask 1.1: 在 `encryptUtf8Async` 和 `decryptUtf8Async` 中添加 yield 点
  - [x] SubTask 1.2: 确保 taskpool 失败时使用正确的异步回退
  - [x] SubTask 1.3: 在 PBKDF2 迭代过程中添加 yield 点

- [x] Task 2: 添加同步操作超时机制
  - [x] SubTask 2.1: 为 `syncIncremental` 添加整体超时（30秒）
  - [x] SubTask 2.2: 为单个网络请求添加超时检查

- [x] Task 3: 优化 UI 状态管理
  - [x] SubTask 3.1: 确保所有错误路径都正确重置 `webdavBusy`
  - [x] SubTask 3.2: 添加同步进度提示

- [x] Task 4: 修复备份操作内存溢出问题
  - [x] SubTask 4.1: 为备份操作添加 yield 点
  - [x] SubTask 4.2: 分批处理大数据导出
  - [x] SubTask 4.3: 添加内存保护机制

- [x] Task 5: 使用 taskpool 执行 JSON 序列化
  - [x] SubTask 5.1: 创建 stringifyJson taskpool 任务
  - [x] SubTask 5.2: 更新 DataSyncManager 使用异步导出

- [x] Task 6: 智能同步释义数据
  - [x] SubTask 6.1: 在 ExportedWord 中添加 definitionSource 字段
  - [x] SubTask 6.2: 只同步非 builtin 来源的释义
  - [x] SubTask 6.3: 导入时根据 source 决定是否覆盖

- [x] Task 7: 添加用户词书同步
  - [x] SubTask 7.1: 在 ExportData 中添加 userBooks 字段
  - [x] SubTask 7.2: 导出用户词书列表
  - [x] SubTask 7.3: 导入时合并用户词书

- [ ] Task 8: 验证修复效果
  - [ ] SubTask 8.1: 测试点击同步后 UI 是否响应
  - [ ] SubTask 8.2: 测试备份操作是否正常
  - [ ] SubTask 8.3: 测试应用不再崩溃
  - [ ] SubTask 8.4: 测试用户词书同步正常

# Task Dependencies
- Task 4 depends on Task 1, Task 2, Task 3
- Task 5 depends on Task 4
- Task 6 depends on Task 5
- Task 7 depends on Task 6
- Task 8 depends on Task 7
