# 开发者入门指南

欢迎加入微语单词 (Vignette) 的开发！本指南将帮助你快速上手。

## 📋 目录

1. [环境设置](#环境设置)
2. [构建项目](#构建项目)
3. [代码规范](#代码规范)
4. [提交流程](#提交流程)
5. [常见问题](#常见问题)

---

## 🔧 环境设置

### 必需工具

| 工具 | 版本要求 | 下载链接 |
|------|----------|----------|
| DevEco Studio | 5.0+ | [官网下载](https://developer.huawei.com/consumer/cn/deveco-studio/) |
| Node.js | 18+ | [官网下载](https://nodejs.org/) |
| Git | 2.0+ | [官网下载](https://git-scm.com/) |

### 可选工具

- **VS Code** + ArkTS 插件（代码编辑）
- **Git Lens**（Git 可视化）

### 克隆项目

```bash
git clone https://github.com/CLMC2025/vignette.git
cd vignette
```

### 安装依赖

```bash
# 安装 Node.js 依赖
npm install

# 安装 HarmonyOS 依赖（在 DevEco Studio 中自动完成）
```

---

## 🏗️ 构建项目

### 1. 配置签名证书

**重要**: 项目不包含签名证书，需要自行配置。

```bash
# 复制配置模板
cp build-profile.json5.template build-profile.json5
```

然后编辑 `build-profile.json5`，填写你的签名信息：

```json5
{
  "signingConfigs": {
    "default": {
      "type": "HarmonyOS",
      "storeFile": "/path/to/your/certificate.p12",
      "keyAlias": "your-key-alias",
      "keyPwd": "your-key-password",
      "certpath": "/path/to/your/cert.p7b",
      "profile": "/path/to/your/profile.p7b"
    }
  }
}
```

**获取签名证书**:
1. 打开 DevEco Studio
2. `File > Project Structure > Signing Configs`
3. 按照向导生成签名证书

### 2. 构建命令

```bash
# 调试版本
hvigor buildDebug

# 发布版本
hvigor build

# 清理构建
hvigor clean

# 运行测试
npm test

# 代码检查
npm run lint
```

### 3. 在 DevEco Studio 中运行

1. 打开 DevEco Studio
2. `File > Open`，选择项目目录
3. 等待索引完成
4. 连接设备或启动模拟器
5. 点击运行按钮 (Shift+F10)

---

## 📝 代码规范

### ArkTS 语法规范

#### ✅ 正确做法

```typescript
// 明确的类型注解
const count: number = 0;
const name: string = 'Vignette';

// 接口定义
interface WordItem {
  id: number;
  word: string;
  status: WordStatus;
}

// 组件定义
@Entry
@Component
struct HomePage {
  @State private count: number = 0;
  
  build() {
    Column() {
      Text(`计数：${this.count}`)
    }
  }
}
```

#### ❌ 错误做法

```typescript
// 禁止使用 any/unknown
const data: any = {};  // ❌
const data: unknown = {};  // ❌

// 禁止在 catch 中声明类型
try {
  // ...
} catch (e: unknown) {  // ❌
  // ...
}

// 禁止使用 var
var count = 0;  // ❌
```

### 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 类/接口/组件 | PascalCase | `WordBook`, `LearningPage` |
| 变量/函数 | camelCase | `loadData`, `currentBook` |
| 常量 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 文件 | PascalCase | `WordDetailPage.ets` |

### 日志规范

使用统一的 Logger 工具类：

```typescript
import { Logger } from '../utils/Logger';

const logger = new Logger('MyComponent');

logger.i('组件已加载');
logger.d('调试信息');
logger.e('发生错误', error);
```

### 错误处理

```typescript
// ✅ 推荐做法
try {
  await this.loadData();
} catch (e) {
  const errMsg = e instanceof Error ? e.message : String(e);
  logger.e('加载数据失败', errMsg);
  promptAction.showToast({ message: '加载失败', duration: 2000 });
}

// ❌ 避免空 catch
try {
  await this.loadData();
} catch (e) {
  // 什么都不做
}
```

---

## 🚀 提交流程

### 1. 创建分支

```bash
# 从 main 创建功能分支
git checkout -b feature/your-feature-name

# 或修复 bug
git checkout -b fix/bug-description
```

### 2. 编写代码

- 遵循代码规范
- 添加必要的注释
- 编写单元测试（如适用）

### 3. 提交更改

```bash
# 添加文件
git add .

# 提交（使用约定式提交格式）
git commit -m "feat: 添加单词搜索功能"
# 或
git commit -m "fix: 修复复习队列加载问题"
```

**提交类型**:
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

### 4. 推送分支

```bash
git push origin feature/your-feature-name
```

### 5. 创建 Pull Request

1. 访问 GitHub 项目页面
2. 点击 "Pull requests" → "New pull request"
3. 选择你的分支
4. 填写 PR 描述
5. 提交等待审核

### 6. CI 检查

提交 PR 后，GitHub Actions 会自动运行以下检查：
- ✅ 代码质量检查
- ✅ 代码统计
- ✅ 文档检查
- ✅ 依赖检查

确保所有检查通过后，等待维护者审核合并。

---

## ❓ 常见问题

### Q: 构建时提示签名错误？
**A**: 确保已正确配置 `build-profile.json5`，或参考 [BUILD_CONFIG_GUIDE.md](BUILD_CONFIG_GUIDE.md)

### Q: 如何调试 ArkTS 代码？
**A**: 
1. 在 DevEco Studio 中设置断点
2. 使用调试模式运行 (Shift+F9)
3. 查看控制台输出

### Q: 测试如何编写？
**A**: 
```typescript
// entry/src/test/MyTest.test.ets
import { describe, it, expect } from 'hypium';

describe('MyTest', () => {
  it('should work', () => {
    expect(1 + 1).assertEqual(2);
  });
});
```

### Q: 如何添加新功能？
**A**: 
1. 在 `pages/` 目录创建新页面
2. 在 `module.json5` 注册路由
3. 在相关目录添加组件/服务

### Q: 数据库如何修改？
**A**: 
1. 修改 `SchemaManager.ets` 中的表结构
2. 添加迁移逻辑
3. 更新 `DATABASE_SCHEMA.md` 文档

---

## 📚 相关文档

- [README.md](README.md) - 项目概述
- [CONTRIBUTING.md](CONTRIBUTING.md) - 贡献指南
- [DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md) - 数据库文档
- [BUILD_CONFIG_GUIDE.md](BUILD_CONFIG_GUIDE.md) - 构建配置指南
- [AGENTS.md](AGENTS.md) - 开发规范

---

## 🤝 联系方式

- **邮箱**: 5@941985.xyz
- **QQ 群**: 1077476965
- **GitHub Issues**: [提交问题](https://github.com/CLMC2025/vignette/issues)

---

## 🎯 任务建议

### 新手任务
- 📝 修复文档中的错别字
- 🎨 改进 UI 组件样式
- 🧪 添加单元测试

### 进阶任务
- 🔧 优化数据库查询性能
- 🌐 添加新的 AI 服务提供商
- 📊 实现学习统计图表

### 专家任务
- 🏗️ 重构核心架构
- 🔐 实现新的加密方案
- 🚀 优化启动速度

---

感谢你为微语单词做出贡献！🎉
