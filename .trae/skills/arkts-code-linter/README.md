# ArkTS Code Linter

基于华为 HarmonyOS NEXT 官方文档的 ArkTS 代码规范检查工具。

## 功能特性

- ✅ **严格类型检查**：禁止 `any`/`unknown`，强制显式类型声明
- ✅ **ArkUI 规范检查**：装饰器、状态管理、布局规范
- ✅ **性能优化建议**：LazyForEach、渲染优化、内存管理
- ✅ **命名规范检查**：PascalCase、camelCase、UPPER_SNAKE_CASE
- ✅ **自动修复支持**：可自动修复缩进、单位等问题

## 快速开始

### 安装

将本目录复制到项目的 `.trae/skills/` 目录下：

```bash
cp -r arkts-code-linter .trae/skills/
```

### 使用

```bash
# 检查文件
arkts-linter check src/main/ets/pages/Index.ets

# 检查目录
arkts-linter check src/main/ets/

# 自动修复
arkts-linter fix src/main/ets/pages/Index.ets
```

## 配置

创建 `.arktslintrc.json`：

```json
{
  "rules": {
    "no-any": "error",
    "no-unknown": "error",
    "lazy-for-each": "error",
    "no-px-unit": "error"
  }
}
```

## 参考

- [华为开发者文档](https://developer.huawei.com/consumer/cn/doc/)
- [ArkTS 语言指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-basics-V5)
