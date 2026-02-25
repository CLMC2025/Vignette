#!/usr/bin/env node
/**
 * ArkTS 代码检查脚本
 * 检查项目中的 ArkTS 代码规范和常见问题
 */

const fs = require('fs');
const path = require('path');

// 项目源目录
const SRC_DIR = path.join(__dirname, '..', 'entry', 'src', 'main', 'ets');

// 检查结果
const results = {
  errors: [],
  warnings: [],
  suggestions: []
};

/**
 * 递归获取所有 .ets 和 .ts 文件
 */
function getAllFiles(dir, fileList = []) {
  if (!fs.existsSync(dir)) {
    return fileList;
  }
  
  const files = fs.readdirSync(dir);
  
  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      getAllFiles(filePath, fileList);
    } else if (/\.(ets|ts)$/.test(file) && !/\.d\.ts$/.test(file)) {
      fileList.push(filePath);
    }
  }
  
  return fileList;
}

/**
 * 检查文件内容
 */
function checkFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const relativePath = path.relative(path.join(__dirname, '..'), filePath);
  const lines = content.split('\n');
  
  // 检查 1: 文件末尾是否有换行
  if (!content.endsWith('\n')) {
    results.warnings.push({
      file: relativePath,
      line: lines.length,
      rule: 'eof-newline',
      message: '文件末尾应有一个空行'
    });
  }
  
  // 检查 2: 检查是否有 TODO 注释
  lines.forEach((line, index) => {
    if (/TODO/i.test(line)) {
      results.suggestions.push({
        file: relativePath,
        line: index + 1,
        rule: 'todo-comment',
        message: `发现 TODO: ${line.trim()}`
      });
    }
  });
  
  // 检查 3: 检查 @Component 装饰的 struct 是否有 build 方法
  if (/@Component\s*\n\s*struct/.test(content)) {
    if (!/build\s*\(\s*\)\s*\{/.test(content)) {
      results.errors.push({
        file: relativePath,
        line: 1,
        rule: 'component-build',
        message: '@Component 装饰的 struct 必须包含 build() 方法'
      });
    }
  }
  
  // 检查 4: 检查是否有 console.log (应该使用 Logger)
  lines.forEach((line, index) => {
    if (/console\.(log|error|warn|info|debug)/.test(line)) {
      results.warnings.push({
        file: relativePath,
        line: index + 1,
        rule: 'no-console',
        message: '建议使用 Logger 工具类代替 console 方法'
      });
    }
  });
  
  // 检查 5: 检查 var 使用 (应使用 let/const)
  lines.forEach((line, index) => {
    if (/\bvar\s+\w+/.test(line)) {
      results.warnings.push({
        file: relativePath,
        line: index + 1,
        rule: 'no-var',
        message: 'ArkTS 中应使用 let 或 const，不要使用 var'
      });
    }
  });
  
  // 检查 6: 检查 @Entry 组件是否有 build 方法
  if (/@Entry\s*\n\s*@Component\s*\n\s*struct/.test(content)) {
    if (!/build\s*\(\s*\)\s*\{/.test(content)) {
      results.errors.push({
        file: relativePath,
        line: 1,
        rule: 'entry-build',
        message: '@Entry 装饰的页面必须包含 build() 方法'
      });
    }
  }
  
  // 检查 7: 检查状态装饰器使用
  const stateDecorators = ['@State', '@Prop', '@Link', '@Watch', '@Observed', '@ObjectLink'];
  lines.forEach((line, index) => {
    for (const decorator of stateDecorators) {
      if (line.includes(decorator) && !/:/.test(line)) {
        results.warnings.push({
          file: relativePath,
          line: index + 1,
          rule: 'decorator-type',
          message: `${decorator} 装饰的属性应该有类型注解`
        });
      }
    }
  });
  
  // 检查 8: 检查 ForEach 是否有唯一的 key 函数
  if (/ForEach\s*\(/.test(content)) {
    if (!/ForEach\s*\([^,]+,\s*[^,]+,\s*[^)]+\)/.test(content)) {
      results.warnings.push({
        file: relativePath,
        line: 1,
        rule: 'foreach-key',
        message: 'ForEach 应该提供唯一的 key 函数以保证列表性能'
      });
    }
  }
}

/**
 * 运行检查
 */
function run() {
  console.log('🔍 开始检查 ArkTS 代码...\n');
  
  const files = getAllFiles(SRC_DIR);
  console.log(`找到 ${files.length} 个源文件\n`);
  
  for (const file of files) {
    checkFile(file);
  }
  
  // 输出结果
  console.log('📊 检查结果:\n');
  
  if (results.errors.length > 0) {
    console.log(`❌ 错误 (${results.errors.length}):`);
    results.errors.forEach(item => {
      console.log(`   ${item.file}:${item.line} - ${item.message}`);
    });
    console.log();
  }
  
  if (results.warnings.length > 0) {
    console.log(`⚠️  警告 (${results.warnings.length}):`);
    results.warnings.forEach(item => {
      console.log(`   ${item.file}:${item.line} - ${item.message}`);
    });
    console.log();
  }
  
  if (results.suggestions.length > 0) {
    console.log(`💡 建议 (${results.suggestions.length}):`);
    results.suggestions.forEach(item => {
      console.log(`   ${item.file}:${item.line} - ${item.message}`);
    });
    console.log();
  }
  
  if (results.errors.length === 0 && results.warnings.length === 0 && results.suggestions.length === 0) {
    console.log('✅ 代码检查通过！\n');
  } else {
    console.log(`总计：${results.errors.length} 错误，${results.warnings.length} 警告，${results.suggestions.length} 建议\n`);
  }
}

run();
