# 数据库 Schema 文档

本文档描述了微语单词 (Vignette) 应用使用的数据库结构和表关系。

## 数据库概述

- **数据库类型**: SQLite (通过 HarmonyOS RdbStore)
- **数据库名称**: `vignette.db`
- **安全级别**: S1 (系统级加密)
- **位置**: 应用沙盒目录

---

## ER 图概览

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   words         │     │  word_book_map   │     │ user_word_books │
├─────────────────┤     ├──────────────────┤     ├─────────────────┤
│ id (PK)         │◄────│ word_id (FK)     │     │ id (PK)         │
│ word            │     │ book_id (FK)     │────►│ name            │
│ definition_hash │     │ is_learned       │     │ description     │
│ status          │     │ learned_at       │     │ word_count      │
│ fsrs_state      │     │ created_at       │     │ is_system       │
│ due_date        │     └──────────────────┘     │ created_at      │
│ history         │                              │ updated_at      │
│ created_at      │                              └─────────────────┘
│ updated_at      │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌─────────────────┐     ┌─────────────────┐
│ review_events   │     │  texts          │
├─────────────────┤     ├─────────────────┤
│ id (PK)         │     │ id (PK)         │
│ word_id (FK)    │     │ title           │
│ rating          │     │ content         │
│ timestamp       │     │ source_type     │
│ prev_state_json │     │ source_ref      │
│ new_state_json  │     │ created_at      │
│ error_tag       │     │ updated_at      │
│ reflection      │     └─────────────────┘
│ scheduled_days  │
└─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│ definitions     │     │ vignette_cache  │
├─────────────────┤     ├─────────────────┤
│ word (PK)       │     │ id (PK)         │
│ definition_json │     │ word            │
│ cached_at       │     │ vignette        │
└─────────────────┘     │ vignette_hash   │
                        │ created_at      │
                        │ last_used_at    │
                        │ size_bytes      │
                        └─────────────────┘

┌─────────────────┐
│ notebook_words  │
├─────────────────┤
│ word (PK)       │
│ created_at      │
└─────────────────┘
```

---

## 表结构详情

### 1. words (单词表)

存储所有学习单词及其 FSRS 状态。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | 单词 ID |
| word | TEXT | NOT NULL UNIQUE | 单词原文（标准化为小写） |
| definition_hash | TEXT | | 定义哈希（用于去重） |
| status | INTEGER | NOT NULL DEFAULT 0 | 单词状态：0-NEW, 1-LEARNING, 2-REVIEW, 3-RELEARNING, 4-KNOWN, 5-FORGOTTEN |
| fsrs_state_json | TEXT | NOT NULL | FSRS 状态 JSON（稳定性、难度、复习次数等） |
| due_date | INTEGER | NOT NULL DEFAULT 0 | 下次复习时间戳（毫秒） |
| history_json | TEXT | NOT NULL DEFAULT '[]' | 复习历史 JSON 数组 |
| created_at | INTEGER | NOT NULL | 创建时间戳 |
| updated_at | INTEGER | NOT NULL | 更新时间戳 |

**索引**:
- `idx_words_status`: 按状态查询
- `idx_words_due_date`: 按到期时间查询
- `idx_words_updated_at`: 按更新时间查询

---

### 2. word_book_map (词书映射表)

单词与词书的多对多关系表。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| word_id | INTEGER | NOT NULL | 单词 ID（外键） |
| book_id | TEXT | NOT NULL | 词书 ID |
| is_learned | INTEGER | NOT NULL DEFAULT 0 | 是否已学 |
| learned_at | INTEGER | DEFAULT NULL | 学习完成时间戳 |
| created_at | INTEGER | NOT NULL | 创建时间戳 |

**主键**: (word_id, book_id)

**索引**:
- `idx_word_book_book_id`: 按词书 ID 查询
- `idx_word_book_learned`: 按学习状态查询

---

### 3. user_word_books (用户词书表)

用户自定义词书和系统词书。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | TEXT | PRIMARY KEY | 词书 ID（UUID） |
| name | TEXT | NOT NULL | 词书名称 |
| description | TEXT | DEFAULT '' | 词书描述 |
| word_count | INTEGER | NOT NULL DEFAULT 0 | 单词数量 |
| is_system | INTEGER | NOT NULL DEFAULT 0 | 是否系统词书 |
| category | TEXT | DEFAULT '其他' | 词书分类 |
| difficulty | TEXT | DEFAULT '初级' | 难度级别 |
| cover_color | TEXT | DEFAULT '' | 封面颜色 |
| icon | TEXT | DEFAULT '📓' | 图标 emoji |
| created_at | INTEGER | NOT NULL | 创建时间戳 |
| updated_at | INTEGER | NOT NULL | 更新时间戳 |

**索引**:
- `idx_user_word_books_is_system`: 按系统/用户分类查询

---

### 4. review_events (复习事件表)

存储所有复习操作记录，用于同步和分析。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | TEXT | PRIMARY KEY | 事件 ID（UUID） |
| word_id | INTEGER | NOT NULL | 单词 ID（外键） |
| rating | INTEGER | NOT NULL | 评分：1-Again, 2-Hard, 3-Good, 4-Easy |
| timestamp | INTEGER | NOT NULL | 复习时间戳 |
| prev_state_json | TEXT | NOT NULL | 复习前 FSRS 状态 JSON |
| new_state_json | TEXT | NOT NULL | 复习后 FSRS 状态 JSON |
| error_tag | TEXT | DEFAULT '' | 错误标签（如有） |
| reflection | TEXT | DEFAULT '' | 用户反思笔记 |
| scheduled_days | INTEGER | NOT NULL DEFAULT 0 | 安排的间隔天数 |

**索引**:
- `idx_review_events_word_id`: 按单词 ID 查询
- `idx_review_events_timestamp`: 按时间查询
- `idx_review_events_word_timestamp`: 复合索引 (word_id, timestamp)

---

### 5. texts (文本库表)

用户导入的阅读文本。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | 文本 ID |
| title | TEXT | NOT NULL | 文本标题 |
| content | TEXT | NOT NULL | 文本内容 |
| source_type | TEXT | NOT NULL DEFAULT 'paste' | 来源类型：paste/import/url |
| source_ref | TEXT | DEFAULT '' | 来源引用（URL 或文件路径） |
| created_at | INTEGER | NOT NULL | 创建时间戳 |
| updated_at | INTEGER | NOT NULL | 更新时间戳 |

**索引**:
- `idx_texts_created_at`: 按创建时间排序

---

### 6. definitions (定义缓存表)

AI 生成的单词定义缓存。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| word | TEXT | PRIMARY KEY | 单词（标准化为小写） |
| definition_json | TEXT | NOT NULL | 定义 JSON（包含释义、例句等） |
| cached_at | INTEGER | NOT NULL | 缓存时间戳 |

---

### 7. vignette_cache (情境故事缓存表)

AI 生成的单词情境故事缓存。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | 缓存 ID |
| word | TEXT | NOT NULL | 单词 |
| vignette | TEXT | NOT NULL | 情境故事文本 |
| vignette_hash | INTEGER | NOT NULL | 故事哈希（用于去重） |
| created_at | INTEGER | NOT NULL | 创建时间戳 |
| last_used_at | INTEGER | NOT NULL | 最后使用时间戳 |
| size_bytes | INTEGER | NOT NULL | 存储大小（字节） |

**索引**:
- `idx_vignette_cache_word`: 按单词查询
- `idx_vignette_cache_hash`: 按哈希查询（去重）

---

### 8. notebook_words (生词本表)

用户手动添加的生词。

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| word | TEXT | PRIMARY KEY | 单词（标准化为小写） |
| created_at | INTEGER | NOT NULL | 添加时间戳 |

---

## 数据类型说明

### FSRS 状态结构 (fsrs_state_json)

```json
{
  "stability": 2.5,      // 稳定性（天数）
  "difficulty": 5.2,     // 难度 (1-10)
  "retrievability": 0.9, // 可检索性 (0-1)
  "reps": 3,             // 复习次数
  "lapses": 0,           // 遗忘次数
  "state": "REVIEW"      // 状态：NEW/LEARNING/REVIEW/RELEARNING
}
```

### 复习历史结构 (history_json)

```json
[
  {
    "timestamp": 1708876543210,
    "rating": 3,
    "prevState": { /* FSRS 状态 */ },
    "newState": { /* FSRS 状态 */ },
    "intervalDays": 2
  }
]
```

### 单词定义结构 (definition_json)

```json
{
  "word": "example",
  "phonetic": "/ɪɡˈzæmpəl/",
  "definitions": [
    {
      "partOfSpeech": "n.",
      "meaning": "例子",
      "examples": ["This is an example."]
    }
  ],
  "cachedAt": 1708876543210
}
```

---

## 数据库版本历史

### v1.0 (当前版本)

初始版本，包含所有核心表：
- words
- word_book_map
- user_word_books
- review_events
- texts
- definitions
- vignette_cache
- notebook_words

---

## 性能优化建议

1. **定期清理复习事件**: 保留最近 6 个月的事件记录
2. **清理过期缓存**: 定期清理 30 天未使用的定义和情境缓存
3. **批量操作使用事务**: 所有批量插入/更新操作应使用事务包装
4. **避免 N+1 查询**: 使用 JOIN 或批量查询

---

## 备份与恢复

### 备份策略
- 使用 `DataExportImport.ets` 导出完整数据库
- WebDAV 云端备份加密数据
- 本地系统备份（通过 HarmonyOS BackupAbility）

### 恢复流程
1. 从 WebDAV 下载加密备份
2. 解密并验证备份完整性
3. 清空当前数据库
4. 导入备份数据
5. 重建索引

---

## 联系与维护

如有数据库相关问题，请联系：
- 邮箱：5@941985.xyz
- QQ 群：1077476965
