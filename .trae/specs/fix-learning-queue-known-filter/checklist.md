# Checklist

## 核心功能验证
- [x] 标记单词为"已知"后，该单词不出现在系统词书的学习队列中
- [x] 标记单词为"已知"后，该单词不出现在用户词书的学习队列中
- [x] 标记单词为"已知"后，该单词不出现在复习队列中
- [x] 恢复学习后，单词正常出现在学习队列

## 代码质量验证
- [x] `getReviewQueueBySystemWordBook` 方法同时排除 NEW 和 KNOWN 状态
- [x] `getLearningQueueByUserWordBook` 方法同时排除 NEW 和 KNOWN 状态
- [x] 所有状态比较使用枚举值 `WordStatus.XXX` 而非字符串字面量
- [x] SQL 查询参数正确传递状态枚举值

## 相关方法验证
- [x] `getPendingReviews` 方法正确排除 KNOWN 状态（已有实现，验证正确）
- [x] `getReviewDueCount` 方法正确排除 KNOWN 状态（已有实现，验证正确）
- [x] `getLearningWords` 方法正确排除 KNOWN 状态（已有实现，验证正确）

## 边界情况验证
- [x] 当所有单词都被标记为 KNOWN 时，学习队列为空
- [x] 当部分单词被标记为 KNOWN 时，学习队列只包含非 KNOWN 单词
- [x] KNOWN 状态单词的 due_date 为 0 时，不会影响查询结果
