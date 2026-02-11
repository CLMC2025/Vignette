# Vignette 牌组系统实现总结

## 项目概述

基于 Vignette 现有代码，实现了完整的牌组（Deck）系统、学习交互逻辑和FSRS v5算法集成，支持单词书学习和阅读模式。

## 实现的功能

### 1. 数据模型

#### Card（SRS卡片）
- **队列状态**: NEW=0（新卡片）, LEARNING=1（学习中）, REVIEW=2（复习中）, RELEARNING=3（重新学习）
- **FSRS状态**: difficulty（难度）, stability（稳定性）, retrievability（可回忆性）
- **学习进度**: reps（复习次数）, lapses（遗忘次数）, left（剩余学习步数）
- **内容**: front（正面/单词）, back（背面/释义）, context（语境）
- **来源追踪**: sourceType, sourceMaterialId, sourcePosition

#### Deck（牌组）
- **类型**: BOOK（基于单词书）, READING（基于阅读材料）
- **配置**: DeckConfig
  - newCardsPerDay: 每日新卡片数（默认20）
  - learningSteps: 学习步骤 [15分钟, 1天, 3天]
  - relearningSteps: 重新学习步骤 [10分钟, 1天]
  - reviewsPerDay: 每日复习数（默认200）
- **统计**: DeckStats（new/learning/review/relearning的今日到期数量）

### 2. 数据库设计

#### 表结构
```sql
-- 牌组表
decks (id, name, type, source_id, config, created_at, updated_at)

-- 卡片表  
cards (id, deck_id, word_id, front, back, context, context_type,
       fsrs_state, due_date, interval, reps, lapses, queue, left,
       source_type, source_material_id, source_position,
       created_at, updated_at)
       FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE
```

#### 性能优化索引
- `idx_cards_deck_queue_due` on `(deck_id, queue, due_date)` ← 复合索引，加速学习会话加载
- `idx_cards_deck`, `idx_cards_queue`, `idx_cards_due` ← 单列索引

### 3. 核心管理器

#### DeckManager（牌组管理器）
**功能**:
- `createBookDeck(bookId, name)` - 从单词书创建牌组
  - 导入所有单词
  - 转换 WordItem → SRSCard
  - 保留已有的FSRS状态
- `createReadingDeck(materialId, title)` - 创建阅读牌组
  - 创建空牌组
  - 阅读时动态添加卡片
- `getDecksWithStats()` - 获取所有牌组及统计数据
  - 实时计算今日到期卡片数量
- `addCardToReadingDeck()` - 添加阅读卡片
- `getDeckById()`, `updateDeckConfig()`, `deleteDeck()` - CRUD操作

**示例**:
```typescript
const deckManager = DeckManager.getInstance();
const deck = await deckManager.createBookDeck('cet4', 'CET-4词汇');
// 创建包含~4500张卡片的牌组
```

#### StudyManager（学习管理器）
**功能**:
- `initialize(deckId)` - 初始化学习会话
  - 加载今日到期卡片
  - 优先级排序: LEARNING > RELEARNING > REVIEW > NEW
  - 应用每日限制
- `getCurrentCard()` - 获取当前卡片
- `processRating(rating)` - 处理评分
  - NEW卡片: 根据评分进入LEARNING或直接REVIEW
  - LEARNING卡片: 推进学习步骤或毕业
  - REVIEW卡片: 使用FSRS v5计算间隔
  - 失败: 进入RELEARNING队列
- `previewIntervals(card)` - 预览所有评分的间隔
- `undoLastReview()` - 撤销上次复习
- `getSessionStats()` - 获取会话统计

**队列转换逻辑**:
```
NEW --GOOD--> LEARNING --GOOD--> LEARNING --GOOD--> REVIEW
NEW --EASY--> REVIEW
REVIEW --AGAIN--> RELEARNING --GOOD--> REVIEW
```

### 4. 学习步骤系统

#### 默认学习步骤
```typescript
learningSteps: [15, 1440, 4320]  // 15分钟, 1天, 3天
```

**进度示例**:
1. 新单词，评分GOOD → LEARNING，15分钟后复习，剩余2步
2. 15分钟后，评分GOOD → 1天后复习，剩余1步
3. 1天后，评分GOOD → 3天后复习，剩余0步
4. 3天后，评分GOOD → 毕业到REVIEW，使用FSRS间隔

#### 重新学习步骤（针对失败的复习）
```typescript
relearningSteps: [10, 1440]  // 10分钟, 1天
```

#### 评分效果
- **AGAIN**: 重置到步骤0，增加遗忘次数
- **HARD**: 重复当前步骤（×1.2倍时间）
- **GOOD**: 推进到下一步或毕业
- **EASY**: 直接毕业到REVIEW

### 5. FSRS v5集成

#### 使用场景
**仅**用于REVIEW队列的卡片（已毕业卡片）

**不**用于:
- NEW卡片（使用固定初始间隔）
- LEARNING卡片（使用学习步骤）
- RELEARNING卡片（使用重新学习步骤）

#### 计算逻辑
```typescript
const result = fsrsAlgorithm.review(
  card.fsrsState,
  rating,
  elapsedDays
);

// 更新卡片
card.fsrsState = result.newState;  // 新的D, S, R
card.dueDate = result.nextReviewMs;
card.interval = result.intervalDays;
```

#### 间隔预览
```typescript
const intervals = studyManager.previewIntervals();
// {
//   AGAIN: 2小时,
//   HARD:  1.5天,
//   GOOD:  3.2天,
//   EASY:  8.5天
// }
```

## 使用指南

### 创建和学习牌组

```typescript
import { DeckManager } from './manager/DeckManager';
import { StudyManager } from './manager/StudyManager';
import { Rating } from './model/WordModel';

// 1. 创建单词书牌组
const deckManager = DeckManager.getInstance();
const deck = await deckManager.createBookDeck('cet6', 'CET-6词汇');

// 2. 查看牌组统计
const decks = await deckManager.getDecksWithStats();
console.log(decks[0].stats);
// { newCount: 20, learningCount: 0, reviewCount: 0, relearnCount: 0 }

// 3. 开始学习会话
const studyManager = new StudyManager(deck.id);
await studyManager.initialize();

// 4. 学习循环
while (studyManager.hasMore()) {
  const card = studyManager.getCurrentCard();
  
  // 显示卡片正面
  console.log(`问题: ${card.front}`);
  
  // 显示间隔预览
  const intervals = studyManager.previewIntervals();
  
  // 等待用户输入...
  const rating = Rating.GOOD; // 来自UI
  
  // 处理评分
  await studyManager.processRating(rating);
  
  // 显示进度
  const stats = studyManager.getSessionStats();
  console.log(`进度: ${stats.reviewedCount}/${stats.totalCount}`);
}

console.log('学习会话完成!');
```

### 阅读模式（添加卡片）

```typescript
// 1. 创建阅读牌组
const deck = await deckManager.createReadingDeck(
  456,
  '了不起的盖茨比 - 第一章'
);

// 2. 阅读时添加卡片
await deckManager.addCardToReadingDeck(
  deck.id,
  'elusive',
  'difficult to find, catch, or achieve',
  'The meaning of the green light remained elusive.',
  89  // 在材料中的位置
);

// 3. 学习阅读卡片
const studyManager = new StudyManager(deck.id);
await studyManager.initialize();
// ... 学习循环
```

## 技术亮点

### 1. 性能优化
- **复合索引**: `(deck_id, queue, due_date)` 使会话加载达到O(log n)
- **按需加载**: 仅加载今日到期卡片
- **批量操作**: 创建牌组时批量插入卡片
- **统计计数**: 使用COUNT查询，避免加载完整数据

### 2. 数据完整性
- **外键约束**: cards.deck_id → decks.id ON DELETE CASCADE
- **类型安全**: 严格的TypeScript类型定义
- **状态验证**: 队列转换规则明确

### 3. 可扩展性
- **配置化**: 学习步骤可按牌组定制
- **模块化**: DeckManager、StudyManager职责清晰
- **兼容性**: 保持与现有WordItem系统的兼容

## 架构图

```
┌──────────────┐
│     UI       │
└──────┬───────┘
       │
       v
┌──────────────┐      ┌──────────────┐
│DeckManager   │──────│ StudyManager │
└──────┬───────┘      └──────┬───────┘
       │                     │
       v                     v
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│DeckRepository│      │CardRepository│      │  FSRS v5     │
└──────┬───────┘      └──────┬───────┘      │  Algorithm   │
       │                     │              └──────────────┘
       v                     v
┌─────────────────────────────────┐
│    RelationalStore (SQLite)      │
│  ┌─────────┐    ┌─────────┐    │
│  │  decks  │    │  cards  │    │
│  └─────────┘    └─────────┘    │
└─────────────────────────────────┘
```

## 文件清单

### 新增文件
1. `entry/src/main/ets/model/DeckCardModel.ets` - SRSCard模型
2. `entry/src/main/ets/model/DeckModel.ets` - Deck模型
3. `entry/src/main/ets/database/repositories/DeckRepository.ets` - 牌组仓库
4. `entry/src/main/ets/database/repositories/CardRepository.ets` - 卡片仓库
5. `entry/src/main/ets/manager/DeckManager.ets` - 牌组管理器
6. `entry/src/main/ets/manager/StudyManager.ets` - 学习管理器
7. `docs/DECK_SYSTEM_GUIDE.md` - 详细文档（英文）

### 修改文件
1. `entry/src/main/ets/database/DBConstants.ets` - 添加表常量
2. `entry/src/main/ets/database/SchemaManager.ets` - 添加表定义和索引

## 测试建议

### 手动测试场景
1. **新卡片学习**: 创建牌组 → 学习NEW卡片 → 验证LEARNING转换
2. **学习步骤**: 完成所有学习步骤 → 验证毕业到REVIEW
3. **FSRS间隔**: REVIEW卡片 → 验证间隔符合FSRS计算
4. **失败处理**: REVIEW卡片评AGAIN → 验证进入RELEARNING
5. **撤销功能**: 评分后撤销 → 验证状态恢复
6. **统计准确**: 查看牌组统计 → 验证数量正确

### 性能测试
- 加载1000+到期卡片的会话（应<100ms）
- 验证使用了复合索引（EXPLAIN QUERY PLAN）
- 批量创建牌组（1000+卡片）的时间

## 未来增强

### 近期计划
- [ ] UI界面集成
- [ ] 单元测试
- [ ] 性能基准测试

### 长期计划
- [ ] 牌组模板（预配置设置）
- [ ] 卡片模板（自定义正反面格式）
- [ ] 子牌组（层级组织）
- [ ] 筛选牌组（动态查询）
- [ ] 牌组分享（导出/导入）
- [ ] 统计仪表板
- [ ] 保留曲线
- [ ] 最优调度（最大化保留，最小化复习）

## 向后兼容性

- ✅ 现有WordItem系统保持不变
- ✅ 可以在WordItem和SRSCard之间转换
- ✅ 对现有代码无破坏性更改
- ✅ 数据库迁移由SchemaManager自动处理

## 总结

成功实现了一个完整的、Anki兼容的牌组系统，具有以下特点：

1. **科学的间隔算法**: FSRS v5提供最优复习间隔
2. **灵活的学习步骤**: 支持自定义学习路径
3. **高性能**: 复合索引确保快速查询
4. **可扩展**: 模块化设计便于未来增强
5. **类型安全**: 完整的TypeScript类型定义
6. **文档完善**: 详细的中英文文档

系统已准备好集成到Vignette UI中，为用户提供强大的单词学习体验。

---

**版本**: 1.0  
**日期**: 2026-02-11  
**作者**: Vignette开发团队
