# ArkTS/HarmonyOS 开发工具配置指南

## 📦 已安装的开发工具

### 1. Skills - ArkTS 开发助手
**位置**: `.qwen/skills/arkts-helper/`

包含：
- **SKILL.md** - ArkTS 开发最佳实践和代码审查指南
- **arkts-snippets.ets** - 常用 ArkTS 代码片段模板

**使用方式**: 直接询问 ArkTS 相关问题，会自动应用这些最佳实践。

### 2. MCP Servers - 模型上下文协议
**位置**: `.qwen/mcp.json`

已配置：
- **filesystem** - 增强文件操作能力
- **memory** - 记录开发笔记和上下文

### 3. 代码生成脚本
**位置**: `scripts/generate.js`

快速生成标准模板代码：

```bash
# 创建页面
node scripts/generate.js page Detail

# 创建组件
node scripts/generate.js component LoadingView

# 创建数据模型
node scripts/generate.js model User

# 创建 API 服务
node scripts/generate.js api Word

# 创建工具类
node scripts/generate.js util Storage
```

### 4. 代码检查脚本
**位置**: `scripts/check-arkts.js`

检查 ArkTS 代码规范和常见问题：

```bash
node scripts/check-arkts.js
```

## 🔧 推荐安装的 VS Code 插件

如果需要使用 VS Code 编辑 ArkTS 文件，推荐安装：

1. **HarmonyOS Preview** - 华为官方预览插件
2. **ArkTS Language** - ArkTS 语言支持
3. **Prettier** - 代码格式化
4. **ESLint** - 代码检查

## 📚 推荐的学习资源

### 官方文档
- [HarmonyOS 开发者官网](https://developer.huawei.com/consumer/cn/doc/harmonyos)
- [ArkTS 语言指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-Guides/arkts-get-started)
- [ArkUI 声明式开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-Guides/arkui-get-started)

### 推荐 MCP Servers (可选安装)

如需更强大的功能，可以安装以下 MCP Servers：

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "D:\\DevEcoStudioProjects\\Vignette"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git"]
    }
  }
}
```

## 🚀 快速开始

1. **创建新页面**: `node scripts/generate.js page MyPage`
2. **创建新组件**: `node scripts/generate.js component MyComponent`
3. **检查代码**: `node scripts/check-arkts.js`

## 📝 代码片段模板

已内置以下模板：
- 基础页面结构
- 状态管理 (@State, @Link, @Prop, @Watch, @Observed)
- 列表组件 (List, Grid, ForEach)
- 动画 (属性动画，显式动画)
- 手势处理 (Pinch, Pan)
- 网络请求封装
- 数据持久化 (Preferences)
- 路由导航
- 常用 UI 组件 (Loading, Empty, SearchBar)

## 💡 使用技巧

1. **询问 ArkTS 问题时** - 我会自动应用 ArkTS 最佳实践
2. **需要创建组件时** - 使用 `node scripts/generate.js component 组件名`
3. **代码审查时** - 使用 `node scripts/check-arkts.js` 检查规范
4. **需要上下文时** - MCP memory 会自动记录重要决策
