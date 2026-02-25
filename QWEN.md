# Vignette 项目 - AI 助手上下文文档

## 📋 项目概述

**微语单词 Vignette** 是一款基于 HarmonyOS NEXT 的原生单词学习应用，采用情境记忆和 FSRS 间隔重复算法，帮助用户在语境中高效记忆单词。

### 核心技术栈

| 类别 | 技术 |
|------|------|
| **平台** | HarmonyOS NEXT |
| **语言** | ArkTS (TypeScript 扩展) |
| **UI 框架** | ArkUI (声明式 UI) |
| **数据库** | RdbStore (SQLite) |
| **算法** | FSRS-6.1.1 间隔重复 |
| **构建工具** | Hvigor |
| **包管理** | ohpm |

### 主要功能

- 🎯 FSRS 间隔重复算法 - 科学安排复习计划
- 📖 AI 情境故事 - 为单词生成情境语境
- ❄️ 滚雪球语境 - 已学词汇融入新语境
- 📚 多词书支持 - CET4/CET6/考研/雅思/托福/GRE
- 📝 文本库阅读 - 导入文章点击查词
- 🔄 WebDAV 同步 - 多设备数据同步
- 🌙 深色模式 - 护眼夜间主题

---

## 🏗️ 项目结构

```
D:\DevEcoStudioProjects\Vignette\
│
├── AppScope/                           # 应用级配置和资源
│   └── resources/base/element/
│
├── entry/                              # 主模块
│   ├── src/main/
│   │   ├── ets/                        # ArkTS 源代码
│   │   │   ├── pages/                  # 页面入口 (@Entry)
│   │   │   │   ├── Index.ets           # 首页
│   │   │   │   ├── WordDetailPage.ets  # 单词详情页
│   │   │   │   ├── ReadPage.ets        # 阅读页
│   │   │   │   ├── SettingsPage.ets    # 设置页
│   │   │   │   └── ...
│   │   │   ├── components/             # 可复用 UI 组件
│   │   │   ├── model/                  # 数据模型
│   │   │   ├── database/               # 数据库层
│   │   │   │   ├── DBManager.ets       # 数据库管理器
│   │   │   │   ├── SchemaManager.ets   # 数据库版本管理
│   │   │   │   └── repositories/       # 仓储模式
│   │   │   ├── manager/                # 业务逻辑管理器
│   │   │   │   ├── DictionaryManager.ets
│   │   │   │   ├── WordBookManager.ets
│   │   │   │   └── ReviewTimeManager.ets
│   │   │   ├── sync/                   # WebDAV 同步
│   │   │   │   ├── WebDavSyncManager.ets
│   │   │   │   └── webdav/
│   │   │   ├── vocabulary/             # 词汇系统
│   │   │   ├── algorithm/              # FSRS 算法
│   │   │   ├── context/                # AI 语境生成
│   │   │   ├── utils/                  # 工具类
│   │   │   └── entryability/           # Ability 入口
│   │   └── resources/                  # 资源文件
│   └── oh-package.json5
│
├── scripts/                            # 辅助脚本
│   ├── generate.js                     # 代码生成器
│   ├── check-arkts.js                  # ArkTS 代码检查
│   └── run-ohos-tests.js               # 测试运行器
│
├── .qwen/                              # AI 助手配置
│   ├── skills/arkts-helper/            # ArkTS 开发技能
│   ├── mcp.json                        # MCP 服务器配置
│   └── README.md                       # 工具使用指南
│
├── package.json                        # Node.js 配置
├── oh-package.json5                    # HarmonyOS 包配置
├── hvigorfile.ts                       # Hvigor 构建配置
├── code-linter.json5                   # 代码检查规则
└── README.md                           # 项目说明
```

---

## 🛠️ 构建和运行命令

### 环境要求

- **DevEco Studio** 最新版 (API 20+)
- **Node.js** 18+
- **HarmonyOS SDK**

### 构建命令

```bash
# 标准构建
hvigor build

# Debug 构建
hvigor buildDebug

# 指定模块构建
hvigor --mode module -p module=entry debug

# 清理构建
hvigor clean

# 安装依赖
ohpm install
```

### 测试命令

```bash
# 运行测试
npm test

# Hvigor 测试
npx hvigorw --mode module -p module=entry@ohosTest test
```

### 开发脚本

```bash
# 生成页面/组件/模型/API/工具类
npm run generate -- page DetailPage
npm run generate -- component LoadingView
npm run generate -- model User
npm run generate -- api Word
npm run generate -- util Storage

# ArkTS 代码检查
npm run lint
```

---

## 📝 开发规范

### ArkTS 语言规范（强制）

#### 类型安全
- ❌ **禁止使用 `any` 和 `unknown` 类型**
- ✅ 所有变量、函数必须有**明确类型注解**
- ✅ 启用严格 null 检查

```typescript
// ❌ 错误
function loadData(id: any): unknown { }

// ✅ 正确
function loadData(id: string): WordItem { }
```

#### catch 子句限制
```typescript
// ❌ 错误 - catch 子句中不能有类型注解
catch (e: unknown) { }

// ✅ 正确
catch (e) {
  const msg = e instanceof Error ? e.message : String(e);
}
```

#### 展开运算符限制
```typescript
// ❌ 错误 - 复杂展开
const combined = [...new Set([...arr1, ...arr2])];

// ✅ 正确
const set = new Set();
for (const item of arr1) { set.add(item); }
for (const item of arr2) { set.add(item); }
const result = Array.from(set);
```

### 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 类/接口/组件 | PascalCase | `WordBookRepository`, `LearningHeatmap` |
| 变量/函数 | camelCase | `loadData`, `currentBook` |
| 常量 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 文件 | PascalCase | `WordDetailPage.ets` |

### 状态管理装饰器

| 装饰器 | 作用范围 | 数据流向 | 场景 |
|--------|----------|----------|------|
| `@State` | 组件内部 | - | 组件私有状态 |
| `@Prop` | 父子组件 | 父→子 (单向) | 配置参数传递 |
| `@Link` | 父子组件 | 双向同步 | 表单、交互状态 |
| `@Provide/@Consume` | 跨层组件 | 祖先→后代 | 主题、全局配置 |
| `@Observed/@ObjectLink` | 嵌套对象 | - | 复杂数据结构 |
| `@Watch` | 状态监听 | - | 副作用处理 |

### 导入顺序

```typescript
// 1. HarmonyOS 内置模块
import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

// 2. 第三方库

// 3. 内部项目模块
import { DBManager } from '../database/DBManager';

// 4. 本地工具/模型/组件
import { WordItem } from '../model/WordModel';
```

### 日志规范

```typescript
// ✅ 使用类名作为前缀
console.error(`[DBManager] 数据库操作失败：${errMsg}`);

// 区分日志级别
console.info()  // 信息
console.error() // 错误
```

---

## 🧪 测试模式

### 测试框架
使用 **Hypium** 测试框架：

```typescript
describe('测试套件名称', () => {
  beforeEach(() => { /* 每个测试前 setup */ });
  afterEach(() => { /* 每个测试后 cleanup */ });
  
  it('测试用例描述', () => {
    expect(actualValue).assertEqual(expectedValue);
  });
});
```

### 测试目录
- `entry/src/test/` - 本地单元测试
- `entry/src/ohosTest/` - HarmonyOS 仪器测试

---

## 🤖 AI 助手配置

### MCP Servers

已配置以下 MCP 服务（`.qwen/mcp.json`）：

```json
{
  "mcpServers": {
    "filesystem": {},  // 文件操作
    "memory": {},      // 开发记忆
    "git": {},         // Git 版本控制
    "fetch": {}        // 网页内容获取
  }
}
```

### Skills

**位置**: `.qwen/skills/arkts-helper/`

- **SKILL.md** - ArkTS 最佳实践指南
- **arkts-snippets.ets** - 480 行代码模板（12 类常用模式）

### 代码生成器

```bash
# 创建页面
node scripts/generate.js page PageName

# 创建组件
node scripts/generate.js component ComponentName

# 创建数据模型
node scripts/generate.js model ModelName

# 创建 API 服务
node scripts/generate.js api ServiceName

# 创建工具类
node scripts/generate.js util UtilName
```

### 代码检查

```bash
# 运行 ArkTS 代码检查
node scripts/check-arkts.js
```

检查项目：
- console 使用（建议用 Logger）
- 文件末尾换行
- TODO 注释标记
- @Component 必须有 build() 方法
- ForEach 唯一 key 函数

---

## ⚠️ 常见陷阱

### 1. 类型安全错误
```typescript
// ❌ 编译错误
const data: any = JSON.parse(jsonString);

// ✅ 正确
interface WordData { word: string; definition: string; }
const data: WordData = JSON.parse(jsonString) as WordData;
```

### 2. 状态更新
```typescript
// ❌ 直接修改对象属性（不会触发 UI 更新）
this.user.name = 'New Name';

// ✅ 重新赋值（触发 UI 更新）
this.user = { ...this.user, name: 'New Name' };
```

### 3. 内存泄漏
```typescript
// ✅ 在 aboutToDisappear 中清理资源
aboutToDisappear(): void {
  if (this.timer) {
    clearTimeout(this.timer);
  }
}
```

---

## 📚 关键常量

位于 `utils/Constants.ets`：

- **网络超时**: 30s (连接/读取/写入)
- **缓存大小**: 根据配置动态调整
- **动画时长**: 遵循 HarmonyOS 设计规范
- **FSRS 参数**: 基于 FSRS-6.1.1 标准

---

## 🔐 安全注意事项

### 敏感数据存储
- 使用 `SecureStorage` 或系统 `KeyStore` 存储令牌/密码
- 数据库使用 `RdbStore` 加密
- WebDAV 凭证使用 `WebDavCrypto` 加密

### 权限最小化
- 仅在 `module.json5` 申请必要权限
- 敏感权限运行时动态申请

---

## 📖 相关文档

- [CONTRIBUTING.md](CONTRIBUTING.md) - 贡献指南
- [README.md](README.md) - 项目说明
- [PRIVACY.md](PRIVACY.md) - 隐私政策
- [LICENSE](LICENSE) - AGPL v3 许可证

---

## 🎯 快速上手

### 新开发者第一步

1. **阅读 AGENTS.md** - 了解语言和代码规范
2. **查看 entry/src/main/ets/pages/Index.ets** - 了解页面结构
3. **查看 entry/src/main/ets/database/DBManager.ets** - 了解数据层
4. **运行 `npm run generate`** - 熟悉代码生成器

### 添加新功能示例

```bash
# 1. 生成页面
npm run generate -- page MyFeature

# 2. 生成组件
npm run generate -- component MyFeatureCard

# 3. 生成数据模型
npm run generate -- model MyFeatureData

# 4. 运行代码检查
npm run lint
```

---

## 📞 项目联系

- **仓库**: https://github.com/CLMC2025/vignette.git
- **邮箱**: 5@941985.xyz
- **QQ 群**: 1077476965

---

*本文档由 AI 助手生成，用于快速理解项目结构和开发规范。*
