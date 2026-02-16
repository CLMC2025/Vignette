# WordEcho 功能借鉴对照（仅参考思路，独立实现）

## 许可与合规

- 本项目许可：AGPLv3（见根目录 LICENSE）。
- WordEcho 许可：Attribution-NonCommercial 4.0（非商业）。
- 建议策略：不复制 WordEcho 源码/组件/图标/样式/文案；只参考交互与信息架构，在本项目内独立实现同类功能。
- 若必须复用第三方代码或资源：需逐文件核对许可与署名要求，并确认与本项目发布策略兼容（BY‑NC 会限制商业使用，不建议引入）。

## 功能对照清单

| WordEcho 功能 | 价值 | 本项目现状 | 推荐落地方式（独立实现） | 相关模块线索 |
|---|---|---|---|---|
| Texts（导入/管理阅读文本） | 让阅读材料可积累与复用 | 目前以“语境/会话”驱动，缺少文本库入口 | 新增 Text 实体：新增/编辑/删除/打开阅读；阅读页基于 Text 渲染 | pages/ReadPage.ets、database/* |
| 阅读页点击词侧栏（常驻） | 点词更高效，避免弹窗遮挡 | 目前是弹窗为主 | 增加右侧面板：显示释义、状态、外链、加入词书/单词本 | pages/ReadPage.ets、components/* |
| 词汇页（Vocab）集中管理 | 统一查看已保存词、筛选、批量操作 | 有 WordList/WordBook 管理，但“学习态”视角可加强 | 新增/增强词汇页：按 status/dueDate/tag/filter 展示、批量加入词书/删除 | pages/WordList*.ets、database/WordRepository.ets |
| 学习页（Study）“先回忆→再展示→再评分” | 更贴合 SRS 心智模型 | 已有 FSRS 与学习会话 | 调整 UI 流程与文案，不改 FSRS 算法；增加统计面板 | pages/learning/*、algorithm/*、components/StatisticsPanel.ets |
| 外部词典链接 | 解释不够时跳转外链补充 | 暂无统一入口 | 在侧栏/详情页提供可配置外链（有道/欧路/剑桥等） | pages/WordDetailPage.ets、SettingsPage.ets |
| “Seen/Known” 快捷标记 | 降低操作成本 | 已有 WordStatus（NEW/LEARNING/REVIEW/KNOWN） | 将状态映射为 UI 动作按钮，并同步颜色/过滤规则 | model/WordEntities.ts、pages/ReadPage.ets |

## 与现有能力的复用点

- 释义缓存：DictionaryManager.lookup 具备“内存 + DB definitions 表”缓存链路。
- 语境释义缓存：ContextWordMeaningStore 已支持持久化缓存（word + contextKey）。
- 学习算法：FSRS 模型/事件/间隔已具备，可直接复用做“Study 页面”体验增强。

## 后续实现顺序建议（低风险→高收益）

1) 阅读页侧栏（常驻面板）与快捷动作（不动数据库结构）。
2) Vocab 词汇页增强（主要是列表与筛选/排序）。
3) Texts 文本库（新增表与页面，属于结构性功能）。

## 回归用例清单

### 冷启动与配置

- 冷启动后在任意页面点词：若已保存 API 配置，不应出现 “API not configured”。
- 未配置 API：应给出明确提示，但仍可展示本地/缓存释义与离线能力。

### 缓存与性能（点词）

- 同一词重复点击：基础释义必须秒开（内存/DB 命中不应转圈）。
- 同一句/同一短语重复点击：语境释义应命中缓存并秒显示。
- 不同语境：应生成新的语境释义并缓存；下次同语境命中。

### 开始学习（首语境）

- 进入学习页：首语境应优先显示缓存/离线文本；AI 优化可后台升级替换。
- 退出再进入：若同任务/同词，缓存命中应直接显示。

### 数据一致性

- 标记 Known/加入词书/加入单词本：列表与详情页状态一致、可回退/可撤销时能正确同步。

