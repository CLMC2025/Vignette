# 核心背单词流程问题分析与修复规格

## Why
用户反馈背单词流程存在严重问题：标记为"已知"的单词仍然会出现在学习队列中，影响用户体验和学习效率。经过深入分析代码和日志，发现多个关键问题。

## What Changes
- **修复 `getReviewQueueBySystemWordBook` 方法** - 添加排除 KNOWN 状态单词的逻辑
- **修复 `getLearningQueueByUserWordBook` 方法** - 添加排除 KNOWN 状态单词的逻辑
- **修复 `getLearningQueueByBook` 方法** - 确保正确过滤所有非学习状态单词
- **增强状态一致性检查** - 在多处添加 KNOWN 状态的过滤

## Impact
- Affected specs: 学习队列获取、复习调度、单词状态管理
- Affected code: 
  - `entry/src/main/ets/database/repositories/WordBookRepository.ets`
  - `entry/src/main/ets/database/repositories/WordRepository.ets`

## ADDED Requirements

### Requirement: 学习队列必须排除 KNOWN 状态单词

系统在获取学习队列时，必须排除所有状态为 `KNOWN` 的单词，确保用户标记为"已知"的单词不会再次出现在学习队列中。

#### Scenario: 用户标记单词为已知后不应再出现
- **WHEN** 用户将单词标记为"已知"（status = KNOWN）
- **THEN** 该单词不应出现在后续的学习队列中
- **AND** 该单词不应出现在复习队列中

#### Scenario: 系统词书获取复习队列
- **WHEN** 调用 `getReviewQueueBySystemWordBook` 获取复习队列
- **THEN** 应排除 status = NEW 的单词（当前实现正确）
- **AND** 应排除 status = KNOWN 的单词（**当前缺失**）

#### Scenario: 用户词书获取学习队列
- **WHEN** 调用 `getLearningQueueByUserWordBook` 获取学习队列
- **THEN** 复习单词查询应排除 status = NEW 的单词
- **AND** 复习单词查询应排除 status = KNOWN 的单词（**当前缺失**）

---

## 问题详细分析

### 问题 1: `getReviewQueueBySystemWordBook` 未排除 KNOWN 状态单词

**位置**: `WordBookRepository.ets` 第 496-519 行

**当前代码**:
```typescript
const sql =
  `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
  `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
  `WHERE sw.book_id = ? ` +
  `AND w.status != ? ` +      // 只排除了 NEW
  `AND w.due_date <= ? ` +
  `ORDER BY w.due_date ASC`;
const args: relationalStore.ValueType[] = [normalizedBookId, newStatus, now];
```

**问题**: 
- 只排除了 `NEW` 状态，未排除 `KNOWN` 状态
- 导致标记为"已知"的单词仍会出现在复习队列中

**修复方案**:
```typescript
const knownStatus = WordStatus.KNOWN;
const sql =
  `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
  `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
  `WHERE sw.book_id = ? ` +
  `AND w.status != ? ` +
  `AND w.status != ? ` +      // 添加排除 KNOWN
  `AND w.due_date <= ? ` +
  `ORDER BY w.due_date ASC`;
const args: relationalStore.ValueType[] = [normalizedBookId, newStatus, knownStatus, now];
```

---

### 问题 2: `getLearningQueueByUserWordBook` 复习单词查询未排除 KNOWN 状态

**位置**: `WordBookRepository.ets` 第 641-687 行

**当前代码**:
```typescript
const reviewSql =
  `SELECT w.* FROM ${TABLE_USER_WORD_BOOK_WORDS} sw ` +
  `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
  `WHERE sw.book_id = ? ` +
  `AND w.status != 'NEW' ` +   // 只排除了 NEW
  `AND w.due_date <= ? ` +
  `ORDER BY w.due_date ASC ` +
  `LIMIT ?`;
```

**问题**:
- 使用字符串 `'NEW'` 而非枚举值（不一致）
- 未排除 `KNOWN` 状态

**修复方案**:
```typescript
const reviewSql =
  `SELECT w.* FROM ${TABLE_USER_WORD_BOOK_WORDS} sw ` +
  `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
  `WHERE sw.book_id = ? ` +
  `AND w.status != ? ` +
  `AND w.status != ? ` +       // 添加排除 KNOWN
  `AND w.due_date <= ? ` +
  `ORDER BY w.due_date ASC ` +
  `LIMIT ?`;
const reviewArgs: relationalStore.ValueType[] = [bookId, WordStatus.NEW, WordStatus.KNOWN, now, safeLimit];
```

---

### 问题 3: `getLearningQueueByBook` 方法缺少 KNOWN 过滤

**位置**: `WordBookRepository.ets` 第 632-639 行

**当前代码**:
```typescript
async getLearningQueueByBook(bookId: string, limit: number): Promise<WordItem[]> {
  const reviews = await this.getReviewQueueBySystemWordBook(bookId);
  if (reviews.length >= limit) {
    return reviews.slice(0, limit);
  }
  const newWords = await this.getNewWordsQueueBySystemWordBook(bookId, limit - reviews.length);
  return [...reviews, ...newWords];
}
```

**问题**:
- 依赖 `getReviewQueueBySystemWordBook` 的正确性
- 如果下游方法有问题，这里也会受影响
- 需要在下游方法修复后验证

---

### 问题 4: 潜在的 due_date 问题

**位置**: `WordEntities.ts` 第 394-398 行

**当前代码**:
```typescript
markAsKnown(): void {
  this.status = WordStatus.KNOWN;
  this.dueDate = 0;
  this.updatedAt = Date.now();
}
```

**问题分析**:
- `dueDate = 0` 意味着 `due_date <= now` 永远为真
- 如果查询条件只检查 `status != NEW`，KNOWN 单词会因为 `due_date <= now` 而被选中
- 这解释了为什么 KNOWN 单词会出现在复习队列中

---

## MODIFIED Requirements

### Requirement: 复习队列查询必须同时排除 NEW 和 KNOWN 状态

所有复习队列查询方法必须同时排除：
1. `WordStatus.NEW` - 新单词不应在复习队列
2. `WordStatus.KNOWN` - 已知单词不应出现在任何学习队列

---

## REMOVED Requirements

无移除的需求。

---

## 修复优先级

| 优先级 | 问题 | 影响范围 | 修复难度 |
|--------|------|----------|----------|
| P0 | getReviewQueueBySystemWordBook 未排除 KNOWN | 系统词书复习队列 | 低 |
| P0 | getLearningQueueByUserWordBook 未排除 KNOWN | 用户词书学习队列 | 低 |
| P1 | 代码风格不一致（字符串 vs 枚举） | 可维护性 | 低 |

---

## 测试验证

修复后需验证：
1. 标记单词为"已知"后，该单词不出现在学习队列
2. 标记单词为"已知"后，该单词不出现在复习队列
3. 恢复学习后，单词正常出现在学习队列
4. 进度统计正确反映 KNOWN 状态单词数量
