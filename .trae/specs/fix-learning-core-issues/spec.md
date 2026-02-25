# 核心学习流程问题修复规格

## Why
用户报告背单词流程存在多个问题：
1. 标记为"已知"的单词仍然出现在学习队列中
2. 语境风格、难度设置切换后不生效
3. 学习队列排序问题 - 单词未按词书顺序排列

## What Changes
- **修复 KNOWN 状态过滤遗漏** - 检查所有学习队列获取方法
- **修复语境设置同步问题** - 确保设置变更后正确传递到故事生成器
- **修复学习队列排序问题** - 确保新词按词书顺序排列

## Impact
- Affected specs: 学习队列获取、设置同步、故事生成
- Affected code:
  - `entry/src/main/ets/database/repositories/WordBookRepository.ets`
  - `entry/src/main/ets/pages/ReadPage.ets`
  - `entry/src/main/ets/pages/learning/controllers/StoryController.ets`
  - `entry/src/main/ets/pages/index/HomeTabContent.ets`
  - `entry/src/main/ets/model/SettingsModels.ts`

## ADDED Requirements

### Requirement: 所有学习队列查询必须排除 KNOWN 状态

系统在获取学习队列时，必须排除所有状态为 `KNOWN` 的单词。

#### Scenario: 系统词书复习队列排除 KNOWN
- **WHEN** 调用 `getReviewQueueBySystemWordBook` 获取复习队列
- **THEN** 应排除 status = NEW 的单词
- **AND** 应排除 status = KNOWN 的单词

#### Scenario: 系统词书新词队列排除 KNOWN
- **WHEN** 调用 `getNewWordsQueueBySystemWordBook` 获取新词队列
- **THEN** 应只返回 status = NEW 的单词
- **AND** 不应返回 status = KNOWN 的单词（当前实现正确，因为只查 NEW）

#### Scenario: 用户词书学习队列排除 KNOWN
- **WHEN** 调用 `getLearningQueueByUserWordBook` 获取学习队列
- **THEN** 复习单词查询应排除 status = NEW 和 status = KNOWN
- **AND** 新词查询应只返回 status = NEW

---

### Requirement: 语境设置变更必须实时生效

用户在设置页面修改语境风格或难度级别后，变更必须立即传递到故事生成器。

#### Scenario: 设置页面修改语境风格
- **WHEN** 用户在设置页面修改语境风格（如从"随机"改为"正式"）
- **THEN** 设置应保存到持久化存储
- **AND** DictionaryManager 应立即更新语境偏好
- **AND** 后续故事生成应使用新的语境风格

#### Scenario: ReadPage 加载设置
- **WHEN** ReadPage 初始化或设置变更后重新加载
- **THEN** 应从 SettingsStore 加载最新设置
- **AND** 应将设置同步到 StoryController
- **AND** 应调用 dictManager.setContextPreferences() 更新语境偏好

---

### Requirement: 学习队列排序必须遵循用户设置

学习队列的排序应遵循用户在设置中选择的排序策略。

#### Scenario: 默认排序策略（复习优先）
- **WHEN** learningOrderPolicy = 'due_first'
- **THEN** 复习单词按 due_date ASC 排序
- **AND** 新词按 created_at ASC 排序（词书顺序）
- **AND** 复习单词优先于新词

#### Scenario: 新词排序
- **WHEN** 获取新词队列
- **THEN** 新词应按 created_at ASC 排序
- **AND** created_at 应反映单词在词书中的原始顺序

---

## 问题详细分析

### 问题 1: KNOWN 状态过滤遗漏

**已修复的方法**:
- `getReviewQueueBySystemWordBook` - 已添加 `AND w.status != ?` 排除 KNOWN
- `getLearningQueueByUserWordBook` - 已添加 KNOWN 过滤

**需要验证的方法**:
- `getNewWordsQueueBySystemWordBook` - 只查询 NEW 状态，不需要额外过滤
- `getWordsBySystemWordBook` - 列表展示，不需要过滤 KNOWN

**潜在问题**:
如果 KNOWN 单词仍然出现，可能原因：
1. 修复代码未部署
2. 存在其他代码路径获取学习队列
3. 单词状态未正确更新为 KNOWN

---

### 问题 2: 语境设置不生效

**代码流程分析**:

1. **设置保存** (`SettingsPage.ets` 第 300-350 行):
```typescript
const settings = new AppSettings(
  ..., 
  this.selectedContextStyle,  // ContextStyle 枚举值
  this.customContextStyle, 
  this.selectedDifficultyLevel, // DifficultyLevel 枚举值
  ...
);
await settingsStore.saveSettings(settings);
dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel, this.customContextStyle);
```

2. **设置加载** (`ReadPage.ets` 第 1147-1208 行):
```typescript
this.selectedContextStyle = settings.contextStyle as ContextStyle;
this.selectedDifficultyLevel = settings.difficultyLevel as DifficultyLevel;
this.dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel);
if (this.storyController) {
  this.storyController.selectedContextStyle = this.selectedContextStyle;
  this.storyController.selectedDifficultyLevel = this.selectedDifficultyLevel;
}
```

**潜在问题**:
1. `settings.contextStyle` 是 `string` 类型，转换为 `ContextStyle` 枚举时可能不匹配
2. `settings.difficultyLevel` 是 `number` 类型，转换为 `DifficultyLevel` 枚举时可能不匹配
3. ReadPage 可能在设置变更后未重新加载设置

**枚举值对照**:
- `ContextStyle.RANDOM = 'random'` ✓
- `ContextStyle.CONVERSATIONAL = 'conversational'` ✓
- `DifficultyLevel.CET4 = 1` ✓
- `DifficultyLevel.CET6 = 2` ✓

**问题根因**:
在 `PreferencesSection.ets` 中，选项按钮使用枚举值比较：
```typescript
OptionButton({ label: '随机', isSelected: this.selectedContextStyle === ContextStyle.RANDOM, ...})
```

但在 `SettingsPage.ets` 中，`selectedContextStyle` 的类型是 `ContextStyle`，而 `AppSettings.contextStyle` 是 `string`。

当从存储加载时：
```typescript
this.selectedContextStyle = settings.contextStyle as ContextStyle;
```

如果 `settings.contextStyle` 是 `'random'`，转换为 `ContextStyle` 后应该等于 `ContextStyle.RANDOM`。

**需要验证**: 确保枚举值与存储的字符串完全匹配。

---

### 问题 3: 学习队列排序问题

**代码分析**:

`getNewWordsQueueBySystemWordBook` 方法：
```typescript
const sql =
  `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
  `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
  `WHERE sw.book_id = ? AND w.status = ? ` +
  `ORDER BY w.created_at ASC ` +
  `LIMIT ?`;
```

**问题分析**:
1. 新词按 `w.created_at ASC` 排序
2. `created_at` 应该是单词添加到数据库的时间
3. 如果单词批量导入时 `created_at` 相同或接近，排序可能不稳定

**潜在问题**:
1. `TABLE_SYSTEM_WORD_BOOK_WORDS` 表有自己的 `created_at` 字段，但查询使用的是 `w.created_at`（words 表的时间）
2. 应该使用 `sw.created_at` 来保持词书中的原始顺序

**修复方案**:
```typescript
const sql =
  `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
  `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
  `WHERE sw.book_id = ? AND w.status = ? ` +
  `ORDER BY sw.created_at ASC ` +  // 使用 sw.created_at 而非 w.created_at
  `LIMIT ?`;
```

---

## MODIFIED Requirements

### Requirement: 新词队列排序使用词书关联表的时间戳

新词队列应使用 `system_word_book_words.created_at` 而非 `words.created_at` 进行排序，以保持单词在词书中的原始顺序。

---

## REMOVED Requirements

无移除的需求。

---

## 修复优先级

| 优先级 | 问题 | 影响范围 | 修复难度 |
|--------|------|----------|----------|
| P0 | 新词排序使用错误的时间戳字段 | 学习队列顺序 | 低 |
| P1 | 验证 KNOWN 过滤是否生效 | 已知单词过滤 | 低 |
| P2 | 验证语境设置同步流程 | 故事生成风格 | 中 |

---

## 测试验证

修复后需验证：
1. 标记单词为"已知"后，该单词不出现在学习队列
2. 修改语境风格后，新生成的故事使用正确的风格
3. 修改难度级别后，新生成的故事使用正确的难度
4. 新词按词书中的原始顺序排列
5. 复习单词按到期时间排序
