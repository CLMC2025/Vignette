# Vignette 功能需求列表

> 本文档追踪所有功能需求的状态。每个功能都有唯一ID、优先级和验收标准。
> 状态：pending → in_progress → completed → verified

---

## 功能统计

| 状态 | 数量 |
|------|------|
| pending | 14 |
| in_progress | 0 |
| completed | 1 |
| verified | 5 |
| blocked | 0 |

---

## P0 - 核心功能（必须完成）

### F-001: AI语境背单词核心流程
- **描述**：基于AI生成的语境学习单词，支持单词标记和状态管理，参考WordEcho的阅读模式，符合鸿蒙原生UI风格
- **优先级**：P0
- **状态**：pending
- **依赖**：无
- **验收标准**：
  - [ ] 用户可以从首页进入学习页面
  - [ ] 用户可以选择词书
  - [ ] 用户可以查看单词详情和AI生成的语境
  - [ ] 用户可以标记单词状态（新单词/已见过/已知）
  - [ ] 用户可以进行复习操作
  - [ ] 界面符合鸿蒙设计规范
  - [ ] 支持流畅的动画效果
- **相关文件**：
  - entry/src/main/ets/pages/Index.ets
  - entry/src/main/ets/pages/ReadPage.ets
  - entry/src/main/ets/pages/WordListPage.ets
  - entry/src/main/ets/context/StoryGenerationPipeline.ets

### F-002: 最新版FSRS算法 ✅
- **描述**：集成最新版本FSRS算法，支持算法参数优化，与学习数据完美结合
- **优先级**：P0
- **状态**：verified
- **依赖**：无
- **完成时间**：2026-02-13
- **实现说明**：已实现FSRS v6.1.1算法，支持参数优化和持久化存储
- **验收标准**：
  - [x] 集成最新版本FSRS算法
  - [x] 根据用户评分计算下次复习时间
  - [x] 支持算法参数优化
  - [x] 复习间隔符合预期
  - [x] 与学习数据完美结合
  - [x] 性能优化，计算速度快
- **相关文件**：
  - entry/src/main/ets/algorithm/Algorithm.ets
  - entry/src/main/ets/algorithm/FSRSOptimizer.ets
  - entry/src/main/ets/algorithm/LearningStepsPolicy.ets

### F-003: Anki风格学习交互 ✅
- **描述**：实现四档评分系统(Again/Hard/Good/Easy)，间隔重复复习逻辑，学习进度跟踪
- **优先级**：P0
- **状态**：completed
- **依赖**：F-002
- **完成时间**：2026-02-13
- **实现说明**：已实现四档评分系统和复习逻辑
- **验收标准**：
  - [x] 实现四档评分系统 (Again/Hard/Good/Easy)
  - [x] 间隔重复复习逻辑
  - [x] 学习进度跟踪
  - [x] 符合Anki的学习交互模式
- **相关文件**：
  - entry/src/main/ets/pages/ReadPage.ets
  - entry/src/main/ets/pages/learning/controllers/ReviewManager.ets
  - entry/src/main/ets/algorithm/Algorithm.ets

### F-004: 词书管理系统
- **描述**：支持导入预设词书，支持创建自定义词书，参考Anki的词书组织方式
- **优先级**：P0
- **状态**：pending
- **依赖**：无
- **验收标准**：
  - [ ] 用户可以导入预设词书
  - [ ] 用户可以创建自定义词书
  - [ ] 用户可以添加/删除单词到词书
  - [ ] 用户可以删除词书
  - [ ] 参考Anki的词书组织方式
  - [ ] 支持词书分类和标签
- **相关文件**：
  - entry/src/main/ets/pages/WordBookManagerPage.ets
  - entry/src/main/ets/manager/WordBookManager.ets
  - entry/src/main/ets/database/repositories/WordBookRepository.ets

### F-005: 数据持久化 ✅
- **描述**：本地数据库存储，支持数据备份恢复
- **优先级**：P0
- **状态**：verified
- **依赖**：无
- **完成时间**：2026-02-13
- **实现说明**：已实现完整的数据库管理和设置存储
- **验收标准**：
  - [x] 单词学习进度正确保存
  - [x] 用户设置正确保存
  - [x] 应用重启后数据不丢失
  - [x] 支持数据备份和恢复
  - [x] 数据库性能优化
- **相关文件**：
  - entry/src/main/ets/database/DBManager.ets
  - entry/src/main/ets/database/SchemaManager.ets
  - entry/src/main/ets/database/repositories/*.ets
  - entry/src/main/ets/utils/SettingsStore.ets

### F-006: 语境故事生成
- **描述**：为单词生成语境故事帮助记忆，基于AI的智能语境生成
- **优先级**：P0
- **状态**：pending
- **依赖**：F-001
- **已实现基础**：
  - ContextStyle枚举（随机/对话/正式/幽默/叙述/技术/自定义）
  - DifficultyLevel枚举（入门/四级/六级/考研/雅思/托福/SAT/GRE/高级）
  - 模板系统基础架构
- **验收标准**：
  - [x] 可以调用AI生成故事（基础实现）
  - [x] 故事包含目标单词
  - [ ] 故事内容相关且有教育意义（需增强）
  - [x] 支持多种语境类型
  - [ ] 语境质量评估（待完善）
  - [ ] 用户自定义语境模板UI
- **相关文件**：
  - entry/src/main/ets/context/StoryGenerationPipeline.ets
  - entry/src/main/ets/context/TemplateManager.ets
  - entry/src/main/ets/context/TemplateTypes.ets
  - entry/src/main/ets/manager/dictionary/*.ets

---

## P1 - 重要功能

### F-007: 鸿蒙原生UI动效
- **描述**：符合鸿蒙设计规范，流畅的页面过渡动画，响应式交互反馈
- **优先级**：P1
- **状态**：pending
- **依赖**：无
- **已实现基础**：
  - Animations.ets 动画组件
  - CelebrationParticles.ets 庆祝粒子效果
  - LoadingAnimations.ets 加载动画
- **验收标准**：
  - [x] 符合鸿蒙设计规范
  - [x] 流畅的页面过渡动画
  - [x] 响应式交互反馈
  - [x] 适配不同屏幕尺寸
  - [x] 性能优化，动画流畅
  - [ ] 手势操作支持（滑动翻卡等）
  - [ ] 震动反馈
- **相关文件**：
  - entry/src/main/ets/ui/Animations.ets
  - entry/src/main/ets/ui/CelebrationParticles.ets
  - entry/src/main/ets/ui/LoadingAnimations.ets
  - entry/src/main/ets/components/*.ets
  - entry/src/main/ets/pages/*.ets

### F-008: 学习统计系统
- **描述**：详细的学习数据统计，学习热力图，进度追踪
- **优先级**：P1
- **状态**：pending
- **依赖**：F-001, F-005
- **验收标准**：
  - [ ] 显示每日学习单词数
  - [ ] 显示学习热力图
  - [ ] 显示复习统计
  - [ ] 显示学习进度
  - [ ] 数据可视化美观
- **相关文件**：
  - entry/src/main/ets/components/LearningHeatmap.ets
  - entry/src/main/ets/components/StatisticsPanel.ets
  - entry/src/main/ets/model/HeatmapData.ets

### F-009: TTS语音播放 ✅
- **描述**：支持单词和句子的语音播放
- **优先级**：P1
- **状态**：verified
- **依赖**：F-001
- **完成时间**：2026-02-13
- **实现说明**：已实现TTS播放器和音频获取功能
- **验收标准**：
  - [x] 支持单词发音
  - [x] 支持句子朗读
  - [x] 支持语速调节
  - [x] 支持后台播放
- **相关文件**：
  - entry/src/main/ets/manager/TTSPlayer.ets
  - entry/src/main/ets/utils/TtsAudioFetcher.ets
  - entry/src/main/ets/pages/learning/controllers/AudioManager.ets

### F-010: 设置页面
- **描述**：完整的设置页面，包含FSRS算法参数配置，学习设置，界面设置
- **优先级**：P1
- **状态**：pending
- **依赖**：无
- **已实现基础**：
  - PreferencesSection.ets（每日新词、复习词、学习流程、TTS设置）
  - APIConfigSection.ets（API配置）
  - FSRSOptimizationSection.ets（FSRS参数优化）
  - SettingsBackupSection.ets（备份恢复）
  - SettingsSyncSection.ets（同步设置）
- **验收标准**：
  - [x] API配置功能
  - [x] FSRS参数优化
  - [x] 数据备份恢复
  - [x] 隐私设置
  - [x] 关于页面
  - [x] 学习设置
  - [ ] 界面设置（主题自定义等）
  - [ ] 语境风格自定义UI
- **相关文件**：
  - entry/src/main/ets/pages/SettingsPage.ets
  - entry/src/main/ets/pages/settings/*.ets

### F-011: WebDAV同步 ✅
- **描述**：支持通过WebDAV同步学习数据
- **优先级**：P1
- **状态**：verified
- **依赖**：F-005
- **完成时间**：2026-02-13
- **实现说明**：已实现完整的WebDAV同步功能，包括加密、冲突解决等
- **验收标准**：
  - [x] 用户可以配置WebDAV服务器
  - [x] 支持数据上传和下载
  - [x] 支持冲突解决
  - [x] 支持自动同步
- **相关文件**：
  - entry/src/main/ets/sync/WebDavSyncManager.ets
  - entry/src/main/ets/sync/webdav/*.ets

### F-012: 主题与外观自定义
- **描述**：多套预设主题，自定义主题色，字体大小调节
- **优先级**：P1
- **状态**：pending
- **依赖**：无
- **已实现基础**：
  - ThemeManager.ets（浅色/深色主题切换）
  - Theme.ets, ThemeColors.ets（主题模型）
- **验收标准**：
  - [x] 支持浅色/深色主题切换
  - [ ] 多套预设主题
  - [ ] 自定义主题色
  - [ ] 字体大小调节
  - [ ] 卡片样式选择
- **相关文件**：
  - entry/src/main/ets/manager/ThemeManager.ets
  - entry/src/main/ets/model/Theme.ets
  - entry/src/main/ets/model/ThemeColors.ets

---

## P2 - 增强功能

### F-013: 生词本功能
- **描述**：用户可以标记和管理生词
- **优先级**：P2
- **状态**：pending
- **依赖**：F-001
- **验收标准**：
  - [ ] 用户可以添加单词到生词本
  - [ ] 用户可以从生词本移除单词
  - [ ] 生词本支持分类
- **相关文件**：
  - entry/src/main/ets/vocabulary/VocabularyTracker.ets
  - entry/src/main/ets/vocabulary/UnknownWordHandler.ets

### F-014: 学习会话管理
- **描述**：支持学习会话的保存和恢复
- **优先级**：P2
- **状态**：pending
- **依赖**：F-001
- **验收标准**：
  - [ ] 支持保存当前学习进度
  - [ ] 支持恢复上次学习状态
  - [ ] 支持多设备同步会话
- **相关文件**：
  - entry/src/main/ets/pages/learning/controllers/SessionManager.ets
  - entry/src/main/ets/utils/SessionTransferStore.ets

### F-015: 成就系统
- **描述**：学习成就和里程碑展示
- **优先级**：P2
- **状态**：pending
- **依赖**：F-008
- **验收标准**：
  - [ ] 定义学习成就
  - [ ] 成就达成通知
  - [ ] 成就展示页面
- **相关文件**：
  - entry/src/main/ets/components/AchievementBanner.ets

### F-016: 快捷操作
- **描述**：首页快捷操作入口
- **优先级**：P2
- **状态**：pending
- **依赖**：F-001
- **验收标准**：
  - [ ] 快速开始学习
  - [ ] 快速复习
  - [ ] 快速查看生词
- **相关文件**：
  - entry/src/main/ets/components/QuickActions.ets

### F-017: 学习偏好设置增强
- **描述**：学习时段提醒、学习模式选择、个性化学习设置
- **优先级**：P2
- **状态**：pending
- **依赖**：F-010
- **验收标准**：
  - [ ] 学习时段提醒
  - [ ] 学习模式选择（新词/复习/混合）
  - [ ] 每日学习目标设置
  - [ ] Timebox时间盒管理
- **相关文件**：
  - entry/src/main/ets/pages/settings/PreferencesSection.ets
  - entry/src/main/ets/manager/TimeboxManager.ets

### F-018: 手势与反馈优化
- **描述**：手势操作支持，滑动翻卡，长按快捷操作，震动反馈
- **优先级**：P2
- **状态**：pending
- **依赖**：F-007
- **验收标准**：
  - [ ] 滑动翻卡
  - [ ] 长按快捷操作
  - [ ] 震动反馈
  - [ ] 手势导航
- **相关文件**：
  - entry/src/main/ets/ui/Animations.ets
  - entry/src/main/ets/components/*.ets

### F-019: 个性化推荐
- **描述**：智能推荐待学单词，根据学习曲线调整，薄弱单词重点提示
- **优先级**：P2
- **状态**：pending
- **依赖**：F-008
- **验收标准**：
  - [ ] 智能推荐待学单词
  - [ ] 根据学习曲线调整
  - [ ] 薄弱单词重点提示
- **相关文件**：
  - entry/src/main/ets/vocabulary/SnowballSystem.ets
  - entry/src/main/ets/manager/SessionPlanner.ets

### F-020: 学习计划管理
- **描述**：创建学习计划，计划进度追踪，计划提醒通知
- **优先级**：P2
- **状态**：pending
- **依赖**：F-008
- **验收标准**：
  - [ ] 创建学习计划
  - [ ] 计划进度追踪
  - [ ] 计划提醒通知
- **相关文件**：
  - 待创建

---

## P3 - 优化功能

### F-021: 性能优化
- **描述**：优化应用启动速度和运行性能
- **优先级**：P3
- **状态**：pending
- **依赖**：所有P0功能
- **验收标准**：
  - [ ] 应用启动时间 < 2秒
  - [ ] 页面切换流畅
  - [ ] 内存占用合理
- **相关文件**：全部

### F-022: 无障碍支持
- **描述**：支持无障碍功能
- **优先级**：P3
- **状态**：pending
- **依赖**：无
- **验收标准**：
  - [ ] 支持屏幕阅读器
  - [ ] 支持大字体
  - [ ] 支持高对比度
- **相关文件**：UI组件

### F-023: 多语言支持
- **描述**：支持多语言界面
- **优先级**：P3
- **状态**：pending
- **依赖**：无
- **验收标准**：
  - [ ] 支持中文
  - [ ] 支持英文
  - [ ] 支持语言切换
- **相关文件**：
  - entry/src/main/resources/base/element/string.json

### F-024: 新手引导系统
- **描述**：新手引导流程，功能提示气泡，帮助文档中心
- **优先级**：P3
- **状态**：pending
- **依赖**：无
- **验收标准**：
  - [ ] 新手引导流程
  - [ ] 功能提示气泡
  - [ ] 帮助文档中心
- **相关文件**：
  - 待创建

### F-025: 社交分享功能
- **描述**：学习成果分享，学习打卡，成就分享
- **优先级**：P3
- **状态**：pending
- **依赖**：F-015
- **验收标准**：
  - [ ] 学习成果分享
  - [ ] 学习打卡
  - [ ] 成就分享
- **相关文件**：
  - 待创建

---

## 更新日志

| 日期 | 功能ID | 变更 | 备注 |
|------|--------|------|------|
| 2025-02-13 | - | 创建功能列表 | 初始化 |
| 2026-02-13 | - | 更新功能需求 | 根据新需求更新 |
| 2026-02-13 | F-002, F-003, F-005, F-009, F-011 | 标记已实现功能 | verified/completed |
| 2026-02-13 | F-006, F-007, F-010, F-012 | 更新已实现基础 | 需继续增强 |
| 2026-02-13 | F-017~F-025 | 新增功能 | 用户体验增强 |

---

> 注意：本文件由AI代理自动维护，请勿手动修改状态字段
