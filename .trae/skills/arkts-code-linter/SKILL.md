---
name: "arkts-code-linter"
description: "检测并修复 ArkTS 代码规范问题。在编写 ArkTS 代码时实时运行，或在代码审查前执行，确保代码符合官方规范。"
---

# ArkTS 代码规范检测与修复工具

## 功能概述

本工具提供全面的 ArkTS 代码规范检测与修复功能，帮助开发者编写符合官方规范的高质量代码。

## 核心功能

### 1. 全面规范扫描
- **语法检查**：检测不符合 ArkTS 语法规范的代码
- **格式检查**：检查代码格式、缩进、换行等
- **最佳实践检查**：验证代码是否遵循 ArkTS 最佳实践
- **性能优化检查**：识别可能影响性能的代码模式

### 2. 详细修复建议
- 针对每个违规问题提供清晰的规范说明
- 提供具体的修复建议和示例代码
- 显示问题的严重程度和影响范围

### 3. 一键自动修复
- 支持自动修复常见的规范问题
- 修复操作可撤销，确保代码安全
- 支持批量修复多个文件

### 4. 自定义规则
- 允许用户配置检查规则的启用/禁用
- 支持添加自定义检查规则
- 允许设置忽略特定文件或代码段

### 5. 清晰错误报告
- 显示问题的精确位置（文件名和行号）
- 分类显示违规类型（语法、格式、最佳实践等）
- 提供严重程度分级（错误、警告、提示）

## 支持的规范

### 语法规范
- 变量和函数类型注解要求
- 禁止使用 any/unknown 类型
- 静态方法调用规范
- 组件语法规则
- 装饰器使用规范

### 格式规范
- 缩进和换行规则
- 空格使用规范
- 命名规范（驼峰式、 PascalCase 等）
- 注释规范

### 最佳实践
- 组件拆分原则
- 状态管理最佳实践
- 性能优化建议
- 错误处理规范

## 使用方法

### 实时检测
工具会在编写代码时实时运行，在 IDE 中显示违规提示。

### 手动运行
```bash
# 检测单个文件
trae arkts-code-linter check <file_path>

# 检测整个目录
trae arkts-code-linter check <directory_path>

# 自动修复问题
trae arkts-code-linter fix <file_path>

trae arkts-code-linter fix <directory_path>
```

### 配置文件
在项目根目录创建 `.arktslintrc.json` 配置文件：

```json
{
  "rules": {
    "no-any": "error",
    "no-unknown": "error",
    "static-method-this": "error",
    "component-syntax": "error",
    "indent": ["error", 2],
    "naming-convention": "error"
  },
  "ignore": [
    "node_modules/**",
    "build/**",
    "*.test.ets"
  ],
  "customRules": [
    "path/to/custom-rule.js"
  ]
}
```

## IDE 集成

### Visual Studio Code
1. 安装 "ArkTS Code Linter" 扩展
2. 在设置中启用实时检测
3. 配置规则和忽略项

### DevEco Studio
1. 安装 "ArkTS Code Linter" 插件
2. 在首选项中配置插件设置
3. 启用实时检测和自动修复

## 示例用法

### 检测代码
```bash
trae arkts-code-linter check src/main/ets/pages/Index.ets
```

### 自动修复
```bash
trae arkts-code-linter fix src/main/ets/model/DesignTokens.ets
```

## 支持的 ArkTS 版本

- ArkTS 4.0+
- HarmonyOS 3.0+

## 常见问题

### Q: 如何忽略特定代码段？
A: 在代码前添加 `// @arktslint-ignore` 注释：

```typescript
// @arktslint-ignore no-any
const data: any = getData();
```

### Q: 如何添加自定义规则？
A: 编写自定义规则脚本并在配置文件中引用：

```javascript
module.exports = {
  name: 'custom-rule',
  severity: 'warning',
  check: (node) => {
    // 检查逻辑
    return {
      message: 'Custom rule violation',
      fix: () => 'fixed code'
    };
  }
};
```

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进本工具。

### 开发流程
1. Fork 本项目
2. 创建功能分支
3. 实现新功能或修复 bug
4. 运行测试
5. 提交 Pull Request

## 许可证

MIT License

## 联系信息

如有问题或建议，请通过以下方式联系：
- GitHub Issues: https://github.com/your-repo/arkts-code-linter/issues
- 邮件: support@example.com

## 更新日志

### v1.0.0
- 初始版本发布
- 支持基本的语法和格式检查
- 支持一键自动修复
- 支持 VS Code 和 DevEco Studio 集成

### v1.1.0
- 增加了最佳实践检查
- 支持自定义规则
- 改进了错误报告格式
- 修复了一些 bug

### v1.2.0
- 支持 ArkTS 5.0 新特性
- 增加了性能优化检查
- 改进了自动修复算法
- 增加了更多配置选项
