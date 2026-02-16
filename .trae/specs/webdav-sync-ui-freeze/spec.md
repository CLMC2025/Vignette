# WebDAV 同步 UI 卡死修复 Spec

## Why
点击"立即同步"或"立即备份"按钮后，应用崩溃。崩溃日志显示 `BCStub_HandleLdobjbyvalueImm8V8StwCopy` - 这是 ArkTS 字节码处理对象属性访问时的内存错误，原因是数据量太大导致内存溢出。

## What Changes
- 为备份操作添加 yield 点和内存保护
- 分批处理大数据导出/导入
- 添加数据量限制和警告
- 优化 JSON 序列化避免内存峰值

## Impact
- Affected code: 
  - `DataSyncManager.ets` - 数据导出/导入
  - `WebDavBackupManager.ets` - 备份逻辑
  - `SettingsSyncSection.ets` - UI 状态管理

## Root Cause Analysis

1. **内存溢出** - `exportData()` 导出所有单词数据，JSON 序列化后可能达到数 MB
2. **加密内存峰值** - 加密大数据时需要额外内存，导致内存不足
3. **缺少分批处理** - 大数据量操作没有分批处理

## ADDED Requirements

### Requirement: 备份操作内存保护
系统 SHALL 在备份操作中添加内存保护机制。

#### Scenario: 大数据量备份
- **WHEN** 用户点击"立即备份"
- **THEN** 系统应分批处理数据
- **AND** 显示进度提示
- **AND** 不应崩溃
