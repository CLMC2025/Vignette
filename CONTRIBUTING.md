# 贡献指南

感谢您考虑为微语单词做出贡献！

## 🤔 如何贡献

### 报告 Bug

如果您发现了 bug，请通过 [GitHub Issues](https://github.com/CLMC2025/vignette/issues) 提交，包含以下信息：

- 问题描述
- 复现步骤
- 预期行为
- 实际行为
- 设备信息（型号、系统版本）
- 截图（如有）

### 提出新功能

如果您有新功能的想法，欢迎在 Issues 中讨论：

- 功能描述
- 使用场景
- 可能的实现方式

### 提交代码

1. Fork 本仓库
2. 创建特性分支
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. 编写代码，确保遵循以下规范
4. 提交更改
   ```bash
   git commit -m 'feat: 添加 AmazingFeature 功能'
   ```
5. 推送到分支
   ```bash
   git push origin feature/AmazingFeature
   ```
6. 提交 Pull Request

## 📝 代码规范

### ArkTS 规范

- 遵循 TypeScript 语法规范
- 禁止使用 `any` 和 `unknown` 类型
- 变量、函数必须有明确的类型注解
- 组件使用 `@Component` 装饰器
- 状态变量使用 `@State`/`@Link`/`@Prop` 装饰器

### 命名规范

| 类型 | 规范 | 示例 |
| :--- | :--- | :--- |
| 类/接口/组件 | PascalCase | `WordItem`, `DBManager` |
| 变量/函数 | camelCase | `loadData`, `currentBook` |
| 常量 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 文件 | PascalCase | `WordDetailPage.ets` |

### 目录结构

```
entry/src/main/ets/
├── pages/          # 页面入口 (@Entry)
├── components/     # 公共 UI 组件
├── model/          # 数据模型 (Class/Interface)
├── utils/          # 工具类
├── manager/        # 业务逻辑管理器
├── database/       # 数据库相关
├── context/        # 语境生成相关
├── sync/           # WebDAV 同步相关
├── service/        # API、数据库服务
├── vocabulary/     # 词汇系统
└── entryability/   # Ability 相关
```

### 提交信息规范

使用清晰的提交信息：

- `feat: 添加新功能`
- `fix: 修复 bug`
- `docs: 文档更新`
- `style: 代码格式调整`
- `refactor: 重构代码`
- `perf: 性能优化`
- `test: 测试相关`
- `chore: 构建/工具相关`

## 🔧 开发环境

- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 最新版
- HarmonyOS SDK (API 20+)
- Node.js 18+

## 📄 许可证

提交代码即表示您同意您的贡献将按照 [GNU AGPL v3](LICENSE) 许可证授权。
