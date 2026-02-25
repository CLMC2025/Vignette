# Tasks

- [x] Task 1: 修复 `getReviewQueueBySystemWordBook` 方法
  - [x] SubTask 1.1: 在 SQL 查询中添加 `AND w.status != ?` 条件排除 KNOWN 状态
  - [x] SubTask 1.2: 更新 SQL 参数数组，添加 `knownStatus` 参数
  - [x] SubTask 1.3: 验证修改后的查询逻辑正确

- [x] Task 2: 修复 `getLearningQueueByUserWordBook` 方法
  - [x] SubTask 2.1: 修改复习单词查询 SQL，添加排除 KNOWN 状态条件
  - [x] SubTask 2.2: 将字符串字面量 `'NEW'` 替换为枚举值 `WordStatus.NEW`
  - [x] SubTask 2.3: 更新 SQL 参数数组，正确传递状态枚举值
  - [x] SubTask 2.4: 验证修改后的查询逻辑正确

- [x] Task 3: 代码质量改进
  - [x] SubTask 3.1: 确保所有状态比较使用枚举值而非字符串
  - [x] SubTask 3.2: 添加必要的代码注释说明排除逻辑

- [x] Task 4: 验证修复效果
  - [x] SubTask 4.1: 检查是否有其他类似遗漏 KNOWN 过滤的查询
  - [x] SubTask 4.2: 确认所有学习队列相关方法都正确过滤 KNOWN 状态

# Task Dependencies
- Task 2 依赖 Task 1（先修复系统词书方法，再修复用户词书方法，保持一致性）
- Task 3 依赖 Task 1 和 Task 2
- Task 4 依赖 Task 1、Task 2、Task 3
