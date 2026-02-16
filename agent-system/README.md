# AI 代理开发系统

> 基于 Anthropic 的长期运行代理架构，为 Vignette 项目搭建的无限运行 AI 开发系统。

---

## 系统概述

本系统解决了 AI 代理在跨多个上下文窗口工作时面临的核心挑战：
- **记忆断层**：每个新会话从零开始，没有之前工作的记忆
- **过度尝试**：试图一次性完成太多工作
- **过早完成**：在功能未完全实现时声称完成

### 核心设计

采用双代理架构：

1. **初始化代理 (Initializer Agent)**
   - 首次运行时设置环境
   - 分解需求为细粒度功能点
   - 创建追踪文件和基线

2. **编码代理 (Coding Agent)**
   - 每次会话完成 1-3 个功能点
   - 保持代码处于清洁状态
   - 为下一会话留下清晰上下文

---

## 目录结构

```
agent-system/
├── initializer/
│   └── init-agent.md          # 初始化代理提示模板
├── coder/
│   └── coding-agent.md        # 编码代理提示模板
├── state/
│   ├── feature-list.md        # 功能需求列表（状态追踪）
│   ├── ai-progress.txt        # 工作进度日志
│   └── session-context.md     # 会话上下文摘要
├── config/
│   ├── workflow.yaml          # 工作流配置
│   └── quality-gates.md       # 质量门禁检查清单
└── README.md                  # 本文件
```

---

## 使用方法

### 首次运行（初始化）

将以下内容作为系统提示发送给 AI：

```
请阅读 agent-system/initializer/init-agent.md 并按照其中的指导执行初始化流程。
```

### 日常开发会话

将以下内容作为系统提示发送给 AI：

```
请阅读 agent-system/coder/coding-agent.md 并按照其中的指导执行开发工作。
```

### 检查进度

查看以下文件了解当前状态：
- `state/feature-list.md` - 功能完成情况
- `state/ai-progress.txt` - 工作历史记录
- `state/session-context.md` - 当前焦点和阻塞项

---

## 核心原则

### 1. 增量开发
- 每个会话只完成 1-3 个功能点
- 宁可少做，也要做好
- 避免一次性大规模改动

### 2. 清洁状态
- 会话结束时代码必须可编译
- 所有测试必须通过
- 代码符合项目规范

### 3. 状态持久化
- 进度文件是代理间的"记忆桥梁"
- 每完成一个功能立即更新
- 记录详细，让下一个代理能理解

### 4. 质量保证
- 遵循质量门禁检查清单
- 不跳过测试
- 不忽略警告

---

## 功能状态流转

```
pending → in_progress → completed → verified
    ↓          ↓
 blocked    blocked
```

- **pending**: 待实现
- **in_progress**: 正在实现
- **completed**: 实现完成，待验证
- **verified**: 测试通过，最终状态
- **blocked**: 被阻塞，需要解决依赖问题

---

## 最佳实践

### 对于 AI 代理

1. **会话开始时**
   - 先读取 session-context.md
   - 再读取 feature-list.md
   - 最后读取 ai-progress.txt

2. **选择功能时**
   - 优先处理阻塞项
   - 按优先级 P0 > P1 > P2 > P3
   - 确保依赖已完成

3. **实现功能时**
   - 遵循项目编码规范
   - 编写对应测试
   - 及时更新状态

4. **会话结束时**
   - 验证代码可编译
   - 更新所有追踪文件
   - 明确下一步方向

### 对于人类开发者

1. **监控进度**
   - 定期查看 feature-list.md
   - 关注 blocked 状态的功能

2. **提供指导**
   - 在 session-context.md 中添加注意事项
   - 更新功能优先级

3. **处理阻塞**
   - 解决技术难题
   - 提供资源或决策

---

## 与 Trae IDE 集成

本系统设计用于 Trae IDE 环境：

1. **项目规则**：`.trae/rules/project_rules.md` 定义编码规范
2. **上下文感知**：AI 自动读取项目规则和追踪文件
3. **增量开发**：每次会话自动继承上次进度

---

## 参考资源

- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [HarmonyOS NEXT 开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5)

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2025-02-13 | 初始版本 |

---

> 维护者：AI Agent System | 最后更新：2025-02-13
