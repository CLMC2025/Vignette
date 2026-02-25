# ArkTS/HarmonyOS 开发工具推荐指南

## ✅ 已配置的核心工具

### MCP Servers

```json
{
  "mcpServers": {
    "filesystem": {},  // 文件操作
    "memory": {},      // 开发笔记记忆
    "git": {},         // Git 版本控制
    "fetch": {}        // 网页内容获取
  }
}
```

| 工具 | 用途 | 使用场景 |
|------|------|----------|
| **filesystem** | 读取/写入/搜索文件 | 代码分析、批量修改 |
| **memory** | 记录项目上下文 | 记住你的开发偏好、项目决策 |
| **git** | 查看提交历史、diff | 代码审查、变更追踪 |
| **fetch** | 获取网页内容 | 查询 HarmonyOS 官方文档 |

### Skills

- **arkts-helper** - ArkTS 代码生成和最佳实践
- 内置 12 类代码模板（状态管理、列表、动画、网络请求等）

### 本地脚本

```bash
# 代码生成
npm run generate -- page DetailPage
npm run generate -- component LoadingView
npm run generate -- model User
npm run generate -- api Word

# 代码检查
npm run lint
```

---

## ❌ 不推荐的工具（针对 HarmonyOS 开发）

| 工具 | 原因 |
|------|------|
| **Puppeteer/Playwright/Browser Use** | 用于 Web 浏览器自动化，HarmonyOS 是原生应用开发 |
| **Supabase** | HarmonyOS 使用 RdbStore (SQLite) 和本地数据库 |
| **Magic UI** | 这是 React/Vue 的 UI 库，HarmonyOS 使用 ArkUI |
| **FireCrawl** | 功能与 fetch 重叠，无需额外配置 |

---

## 🤔 可选配置（看需求）

### GitHub MCP
如果你经常需要：
- 搜索开源 HarmonyOS 项目
- 查看 Issues 和 PR
- 获取仓库信息

可以添加：
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "your_token"
      }
    }
  }
}
```

### Perplexity
如果你有 Perplexity API 且喜欢用 AI 搜索，可以配置。否则用内置的网络搜索即可。

---

## 📚 Context7 说明

Context7 不是独立工具，而是指**代码上下文理解能力**。

已通过以下方式实现：
- `.qwen/skills/arkts-helper/` - 提供 ArkTS 领域知识
- MCP filesystem - 提供项目文件上下文
- MCP memory - 提供开发记忆上下文

---

## 🎯 最终建议

### 对于你的 HarmonyOS 单词学习应用，当前配置已足够：

```
✅ 文件操作 (filesystem)
✅ 开发记忆 (memory)  
✅ Git 集成 (git)
✅ 文档查询 (fetch)
✅ ArkTS 代码生成 (skills)
✅ 代码检查 (scripts)
```

### 无需额外配置的工具：
- ❌ Browser Tools / Puppeteer / Playwright（Web 自动化，不相关）
- ❌ Supabase（后端服务，HarmonyOS 用本地数据库）
- ❌ Magic UI（React UI 库，HarmonyOS 用 ArkUI）
- ❌ FireCrawl（功能重复）

### 如有特殊需求可添加：
- 🔶 GitHub MCP（需要频繁查开源项目时）
- 🔶 Sequential Thinking（复杂问题推理，已内置）

---

## 💡 使用技巧

1. **查文档**：直接问"HarmonyOS 如何实现 WebDAV 同步"，我会用 fetch 查官方文档
2. **代码生成**：`npm run generate -- page Settings`
3. **代码审查**：`npm run lint`
4. **Git 历史**：让我帮你查看最近的提交记录
5. **上下文记忆**：重要的项目决策会自动记录到 memory
