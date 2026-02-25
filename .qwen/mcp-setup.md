# MCP Server 配置说明

## 推荐的 MCP Servers

### 1. HarmonyOS 文档 MCP
用于查询 HarmonyOS 官方文档和 API 参考。

**安装方式：**
```bash
npm install -g @harmonyos/mcp-server-docs
```

**配置添加到 `.qwen/mcp.json`：**
```json
{
  "mcpServers": {
    "harmonyos-docs": {
      "command": "npx",
      "args": ["-y", "@harmonyos/mcp-server-docs"],
      "env": {
        "DOCS_BASE_URL": "https://developer.huawei.com/consumer/cn/doc/harmonyos"
      }
    }
  }
}
```

### 2. 文件系统 MCP
用于增强文件操作能力。

**配置：**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "D:\\DevEcoStudioProjects\\Vignette"]
    }
  }
}
```

### 3. 数据库 MCP (用于 RdbStore 调试)
```json
{
  "mcpServers": {
    "sqlite": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sqlite", "./src/main/resources/rawfile/app.db"]
    }
  }
}
```

### 4. 记忆/Memory MCP
用于记录开发笔记和上下文。

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

## 完整配置文件示例

创建 `.qwen/mcp.json` 文件：

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
    }
  }
}
```

## 注意事项

1. 确保已安装 Node.js 和 npm
2. 首次使用会自动下载 MCP Server
3. 路径需要使用双反斜杠或正斜杠
4. 部分 MCP Server 可能需要额外配置 API Key
