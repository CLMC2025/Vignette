# 日志功能独立为二级菜单 Spec

## Why
当前日志功能嵌套在"关于"页面中，不够显眼且功能受限。将日志功能独立为二级菜单项，可以提供更好的用户体验，方便用户快速访问日志查看、搜索、导出和诊断功能。

## What Changes
- 在设置页 `SETTINGS_SECTIONS` 中新增独立的"日志与调试"菜单项
- 将 `LoggerSection` 从 `SettingsAboutSection` 中移除
- 创建新的 `LoggerPage.ets` 页面，提供完整的日志功能

## Impact
- Affected code:
  - `entry/src/main/ets/pages/SettingsPage.ets` - 新增菜单项
  - `entry/src/main/ets/pages/settings/SettingsAboutSection.ets` - 移除 LoggerSection
  - `entry/src/main/ets/pages/settings/LoggerSection.ets` - 重构为独立页面
  - `entry/src/main/resources/base/profile/main_pages.json` - 注册新页面

## ADDED Requirements

### Requirement: 独立日志页面入口
系统应在设置页提供独立的"日志与调试"二级菜单入口，与"关于"菜单平级。

#### Scenario: 用户访问日志功能
- **WHEN** 用户在设置页点击"日志与调试"菜单项
- **THEN** 系统导航到独立的日志页面，展示完整的日志查看、搜索、过滤、导出功能

### Requirement: 日志页面功能完整性
独立的日志页面应包含以下功能：
- 日志统计（总数、错误数、警告数）
- 级别过滤（全部/错误/警告/信息/调试）
- 关键词搜索
- 日志列表预览
- 导出日志文件
- 生成诊断报告
- 清空日志

## MODIFIED Requirements

### Requirement: 关于页面简化
"关于"页面应移除日志相关内容，仅保留：
- 应用版本信息
- 新手引导入口
- 隐私政策入口
- 开源许可
- 开源鸣谢
- 联系方式
