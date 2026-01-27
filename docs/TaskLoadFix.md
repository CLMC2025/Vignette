# “开始学习”任务加载失败修复说明（最终版）

## 1. 现象
- 用户点击首页 **“开始学习”** 后进入 `ReadPage`，提示 **“任务加载失败”**，学习内容未加载。
- 工程能编译通过，属于 **运行时逻辑/异常处理不足**。

## 2. P0 根因
### 2.1 Router 传参后实例对象变成普通对象（Prototype 丢失）
`Index -> ReadPage` 使用 `router.pushUrl({ params: { queue } })` 传递 `QueueItem[]`。

ArkUI 路由参数会被序列化/反序列化，导致：
- `QueueItem` / `WordItem` 变成 plain object
- `WordItem.clone()`、`FSRSState.clone()` 等实例方法丢失

`ReadPage.loadCurrentTask()` 中会执行：
- `new WordSnapshot(task.word)` 或 `session.createSnapshot(task.word)`

这两个路径都会调用 `WordItem.clone()`，当对象变成 plain object 时会触发异常 → 被捕获后统一弹出 **“任务加载失败”**。

### 2.2 故事生成校验过严导致“无故事文本”进而影响 CLOZE
旧逻辑中：故事生成若被 `ContextValidator` 判为不合格，就不会写入 `storyText`。
而 `CLOZE` 任务依赖 `storyText` 做挖空，导致再次异常/空内容。

### 2.3 CHOICE 任务依赖释义，但 definition 可能不存在
在 API 未配置/网络异常/缓存缺失时，`WordItem.definition` 可能缺少可用释义。
旧逻辑直接抛错，导致任务加载失败。

## 3. 修复点（已落地）
### 3.1 ReadPage 增加“反序列化重建”
文件：`entry/src/main/ets/pages/ReadPage.ets`
- 新增 `rebuildQueueFromParams / rebuildWordItem / rebuildFsrsState / rebuildReviewHistory / rebuildDefinition`
- 在 `initializeSession()` 内把 router params 的 `queue` 重建成真正的 `QueueItem/WordItem` 实例，再交给 `SessionPlanner`。

效果：从根上修复 Snapshot/Review 等依赖类方法的崩溃。

### 3.2 故事生成改为 best-effort，不再“因为校验失败就不展示”
- `generateStory()`：校验失败只作为 **warning**（`storyError`），仍展示 `storyText`
- 若 API 失败/返回空文本：写入 **离线兜底故事**，保证任务可继续

### 3.3 CLOZE 更稳：没有故事也能挖空
- 若 `storyText` 为空则生成离线兜底文本
- 修复正则边界：使用 `\\b` 防止 `\b` 在模板字符串中被解释为 backspace

### 3.4 CHOICE 无释义时降级为“拼写选择”
- 若无法得到释义，生成 `word + 相似干扰项` 的拼写选择题，避免整条任务链报错。

### 3.5 错误提示更清晰 + 引导动作
- 引入 `utils/ErrorClassifier.ets`
- `loadCurrentTask()` catch 中把异常归类为：网络/API/权限/格式/未知等
- 弹窗提供 **重试 / 去设置 / 跳过 / 返回**（最多 3 个按钮，保证兼容性）

### 3.6 加载状态反馈
- 新增 `isTaskLoading` + `buildTaskLoadingOverlay()`，任务准备期间显示遮罩与加载动画。

## 4. 测试方法
### 4.1 手动回归
1. 不配置 API Key：点击开始学习
   - 任务应能加载（故事走离线兜底）
   - CHOICE 若无释义会降级为拼写题
2. 配置正确 API Key：点击开始学习
   - 应正常加载任务、生成故事、可点击查词
3. 模拟网络断开：
   - 弹窗应提示网络问题，并提供“重试/跳过”等操作

### 4.2 单元测试（Hypium）
新增：`entry/src/test/TaskLoadFix.test.ets`
- 覆盖 `classifyError / buildUserFacingError`
- 覆盖 `DictionaryManager.generateStory()` 在未配置 API 时仍返回可用文本

运行：DevEco Studio → `entry` → Test → Local Unit Test。

## 5. 相关文件清单
- ✅ `entry/src/main/ets/pages/ReadPage.ets`（核心修复：重建 queue + 任务加载稳定性）
- ✅ `entry/src/main/ets/utils/ErrorClassifier.ets`（错误分类 & 用户提示）
- ✅ `entry/src/test/TaskLoadFix.test.ets`（新增单元测试）
- ✅ `entry/src/test/List.test.ets`（注册新增测试）
- ✅ `docs/TaskLoadFix.md`（本说明文档）
