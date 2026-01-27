#!/usr/bin/env node
/**
 * ArkTS Compliance Verification Script
 * Strictly validates project against ArkTS/ETS coding rules
 */

import { readFileSync, readdirSync, writeFileSync } from 'fs';
import { join } from 'path';

// Project root directory
const PROJECT_ROOT = 'd:/DevEcoStudioProjects/Vignette/entry/src/main/ets';

// Compliance rules
const RULES = {
  NO_ANY_UNKNOWN: /:\s*(any|unknown)(?=\s|>|\[|\))/g,
  NO_DESTRUCTURING: /\{[^}]+\}\s*=|\[[^\]]+\]\s*=/g,
  NO_INLINE_OBJECT_TYPES: /:\s*\{[^}]+\}/g,
  NO_UI_IN_MODEL: /(Column|Row|Text|Stack|ForEach)\(/g,
  NO_ON_FINISH: /\.onFinish\(/g,
  NO_EASE_OUT_BACK: /Curve\.EaseOutBack/g,
  NO_SPRING_CURVE: /Curve\.Spring/g,
  NO_PARAM_DESTRUCTURING: /\([^)]*\{[^)]*\}\)/g
};

// File types to check
const CHECK_FILES = /\.ets$/;

// Directories to exclude from UI checks
const UI_EXCLUDED_DIRS = ['model', 'algorithm', 'database', 'sync', 'manager', 'assessment', 'context', 'vocabulary'];

/**
 * Check file for compliance issues
 */
function checkFile(filePath) {
  const issues = [];
  const content = readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  
  // Check each rule
  for (const [ruleName, regex] of Object.entries(RULES)) {
    // Skip UI checks for non-UI directories
    if ((ruleName === 'NO_UI_IN_MODEL' || ruleName === 'NO_ON_FINISH') && 
        UI_EXCLUDED_DIRS.some(dir => filePath.includes(`/${dir}/`))) {
      continue;
    }
    
    // Check each line
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      let match;
      while ((match = regex.exec(line)) !== null) {
        issues.push({
          rule: ruleName,
          line: i + 1,
          content: line.trim()
        });
      }
    }
  }
  
  return issues;
}

/**
 * Recursively check all files
 */
function checkAllFiles(dir) {
  let results = [];
  
  const files = readdirSync(dir, { withFileTypes: true });
  
  for (const file of files) {
    const fullPath = join(dir, file.name);
    
    if (file.isDirectory()) {
      results = results.concat(checkAllFiles(fullPath));
    } else if (CHECK_FILES.test(file.name)) {
      const issues = checkFile(fullPath);
      if (issues.length > 0) {
        results.push({
          file: fullPath.replace(PROJECT_ROOT, ''),
          issues
        });
      }
    }
  }
  
  return results;
}

/**
 * Generate compliance report
 */
function generateReport(results) {
  let report = `# ArkTS Compliance Report\n\n`;
  report += `## Summary\n`;
  report += `Total files checked: ${readdirSync(PROJECT_ROOT, { withFileTypes: true })
    .filter(f => f.isFile() && CHECK_FILES.test(f.name)).length}\n`;
  report += `Files with issues: ${results.length}\n`;
  report += `Total issues: ${results.reduce((sum, r) => sum + r.issues.length, 0)}\n\n`;
  
  if (results.length > 0) {
    report += `## Issues Found\n\n`;
    for (const result of results) {
      report += `### ${result.file}\n`;
      for (const issue of result.issues) {
        report += `- Line ${issue.line}: ${issue.rule} - ${issue.content}\n`;
      }
      report += `\n`;
    }
  } else {
    report += `## Status: ✅ FULLY COMPLIANT\n\n`;
    report += `All files pass strict ArkTS compliance checks!\n`;
  }
  
  return report;
}

// Run the check
const results = checkAllFiles(PROJECT_ROOT);
const report = generateReport(results);

console.log(report);

// Write report to file
writeFileSync('./compliance-report.md', report);
console.log('Compliance report written to compliance-report.md');