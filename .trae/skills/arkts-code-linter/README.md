# ArkTS Code Linter

ArkTS 代码规范检测与修复工具，用于在编码过程中实时检测和修复 ArkTS 代码规范问题。

## 功能特性

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

## 安装

### 从源代码安装

1. 克隆仓库到本地：

```bash
git clone https://github.com/your-repo/arkts-code-linter.git
cd arkts-code-linter
```

2. 安装依赖：

```bash
npm install
```

3. 全局安装：

```bash
npm install -g .
```

### 作为 Trae 技能使用

将技能目录复制到 `.trae/skills/` 目录下：

```bash
cp -r arkts-code-linter .trae/skills/
```

## 配置

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

### 规则说明

| 规则名称 | 描述 | 严重程度 | 可修复 |
|---------|------|---------|--------|
| no-any | 禁止使用 any 类型 | error | false |
| no-unknown | 禁止使用 unknown 类型 | error | false |
| static-method-this | 静态方法中禁止使用 this 关键字 | error | true |
| no-untyped-objects | 禁止使用无类型对象字面量 | error | false |
| component-syntax | 组件语法规则检查 | error | false |
| indent | 缩进规则检查 | error | true |
| naming-convention | 命名规范检查 | error | false |
| proper-decorator-use | 装饰器使用规范 | error | false |
| component-root-node | 组件根节点规则 | error | false |
| state-management | 状态管理最佳实践 | warning | false |

## 使用方法

### 命令行使用

```bash
# 检测单个文件
arkts-linter check src/main/ets/pages/Index.ets

# 检测整个目录
arkts-linter check src/main/ets/

# 自动修复单个文件
arkts-linter fix src/main/ets/pages/Index.ets

# 自动修复整个目录
arkts-linter fix src/main/ets/
```

### Trae 技能使用

```bash
# 检测单个文件
trae arkts-code-linter check src/main/ets/pages/Index.ets

# 检测整个目录
trae arkts-code-linter check src/main/ets/

# 自动修复单个文件
trae arkts-code-linter fix src/main/ets/pages/Index.ets

# 自动修复整个目录
trae arkts-code-linter fix src/main/ets/
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

## 自定义规则

### 创建自定义规则

创建一个 JavaScript 文件，定义规则对象：

```javascript
module.exports = {
  name: 'custom-rule',
  description: '自定义规则描述',
  severity: 'warning',
  pattern: /some-pattern/g,
  fixable: true,
  fix: (match) => {
    // 修复逻辑
    return 'fixed-code';
  }
};
```

### 配置自定义规则

在 `.arktslintrc.json` 中添加自定义规则：

```json
{
  "customRules": [
    "path/to/custom-rule.js"
  ]
}
```

## 忽略特定代码

### 忽略整个文件

在文件顶部添加注释：

```typescript
// @arktslint-ignore-file
```

### 忽略特定代码段

在代码前添加注释：

```typescript
// @arktslint-ignore no-any
const data: any = getData();
```

### 忽略多个规则

```typescript
// @arktslint-ignore no-any, no-unknown
const data: any = getData();
```

## 示例

### 检测代码

```bash
arkts-linter check src/main/ets/pages/Index.ets
```

输出示例：

```
❌ ArkTS Linter Results:
============================================================

📁 src/main/ets/pages/Index.ets:
----------------------------------------
❌ Line 210, Column 12
   Rule: static-method-this
   Message: 静态方法中禁止使用 this 关键字
   Code: static springGentle(direction: AnimationDirection = AnimationDirection.CENTER): AnimationConfig {
    return this.spring(direction, 150, 12, 1);
  }
   ------------------------------

📊 Summary:
============================================================
Total issues: 1
Errors: 1
Warnings: 0
```

### 自动修复

```bash
arkts-linter fix src/main/ets/pages/Index.ets
```

输出示例：

```
Fixed src/main/ets/pages/Index.ets
```

## 开发指南

### 目录结构

```
arkts-code-linter/
├── arkts-linter.js        # 主入口文件
├── SKILL.md               # Trae 技能描述
├── README.md              # 项目说明文档
├── package.json           # 项目配置
└── .arktslintrc.json      # 默认配置文件
```

### 运行测试

```bash
npm test
```

### 贡献代码

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
