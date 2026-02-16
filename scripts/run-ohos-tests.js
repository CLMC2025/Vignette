#!/usr/bin/env node

const { existsSync } = require('node:fs');
const { spawnSync } = require('node:child_process');

const localHvigorw = './hvigorw';
const hvigorwBin = existsSync(localHvigorw) ? localHvigorw : 'hvigorw';
const hvigorArgs = ['--mode', 'module', '-p', 'module=entry@ohosTest', 'test'];

const result = spawnSync(hvigorwBin, hvigorArgs, {
  stdio: 'inherit',
  shell: process.platform === 'win32'
});

if (result.error) {
  if (result.error.code === 'ENOENT') {
    console.error('[npm test] 未找到 hvigorw。请在 DevEco Studio/HarmonyOS 构建环境中运行，或将 hvigorw 放到仓库根目录。');
    process.exit(1);
  }
  console.error(`[npm test] 执行失败: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status === null ? 1 : result.status);
