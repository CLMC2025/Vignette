# =====================================================
# 构建配置说明
# =====================================================

## 签名配置步骤

1. **复制模板文件**
   ```bash
   cp build-profile.json5.template build-profile.json5
   ```

2. **获取签名证书**
   - 访问 [HarmonyOS 开发者官网](https://developer.huawei.com/consumer/cn/deveco-studio/)
   - 下载并安装 DevEco Studio
   - 按照 [应用签名指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-signing-V5) 获取证书

3. **配置签名信息**
   编辑 `build-profile.json5`，填写以下信息：
   - `storeFile`: .p12 证书文件路径
   - `keyAlias`: 密钥别名
   - `keyPwd`: 密钥密码
   - `certpath`: .p7b 证书文件路径
   - `profile`: 配置文件路径

4. **验证配置**
   在 DevEco Studio 中打开项目，运行 `Build > Make Project`

## 注意事项

- ⚠️ `build-profile.json5` 已加入 `.gitignore`，不会被提交到仓库
- ⚠️ 不要将签名证书文件提交到版本控制系统
- ✅ 每个开发者应使用自己的签名配置

## 无签名调试

如果仅需调试，可以在 DevEco Studio 中：
1. `File > Project Structure > Signing Configs`
2. 选择 "Automatically generate signature"
3. 使用自动生成的签名进行调试

## 构建命令

```bash
# 调试版本
hvigor buildDebug

# 发布版本（需要签名配置）
hvigor build

# 清理构建
hvigor clean
```

## 常见问题

### Q: 找不到签名证书文件？
A: 确保证书文件路径正确，可以使用绝对路径。

### Q: 签名密码错误？
A: 检查 `keyPwd` 是否正确，注意大小写。

### Q: 如何在团队间共享项目？
A: 每个团队成员需要生成自己的签名证书，不要共享证书文件。
