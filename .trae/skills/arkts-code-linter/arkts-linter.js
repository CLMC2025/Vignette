/**
 * ArkTS Code Linter - Simple Implementation
 * This script checks ArkTS files for common code style issues
 */

const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const readFile = promisify(fs.readFile);
const readdir = promisify(fs.readdir);
const writeFile = promisify(fs.writeFile);

/**
 * Rule definitions
 */
const RULES = {
  'no-any': {
    name: 'no-any',
    description: '禁止使用 any 类型',
    severity: 'error',
    pattern: /:\s*any\b/g,
    fixable: false
  },
  'no-unknown': {
    name: 'no-unknown',
    description: '禁止使用 unknown 类型',
    severity: 'error',
    pattern: /:\s*unknown\b/g,
    fixable: false
  },
  'static-method-this': {
    name: 'static-method-this',
    description: '静态方法中禁止使用 this 关键字',
    severity: 'error',
    pattern: /static\s+\w+\s*\([^)]*\)\s*:\s*[^\n]+\s*\{[^}]*this\./gms,
    fixable: true
  },
  'no-untyped-objects': {
    name: 'no-untyped-objects',
    description: '禁止使用无类型对象字面量',
    severity: 'error',
    pattern: /=\s*\{[^}]*\}\s*;/g,
    fixable: false
  }
};

/**
 * Linter class
 */
class ArkTSLinter {
  constructor(configPath) {
    this.config = this.loadConfig(configPath);
    this.results = [];
  }

  /**
   * Load configuration from file
   */
  loadConfig(configPath) {
    try {
      const configContent = fs.readFileSync(configPath, 'utf8');
      return JSON.parse(configContent);
    } catch (error) {
      console.warn(`Warning: Could not load config file at ${configPath}. Using default configuration.`);
      return {
        rules: {
          'no-any': 'error',
          'static-method-this': 'error'
        },
        ignore: []
      };
    }
  }

  /**
   * Check if file should be ignored
   */
  shouldIgnore(filePath) {
    const relativePath = path.relative(process.cwd(), filePath);
    return this.config.ignore.some(pattern => {
      const regex = new RegExp(`^${pattern.replace(/\*\*/g, '.*').replace(/\*/g, '[^/]*')}$`);
      return regex.test(relativePath);
    });
  }

  /**
   * Check a single file
   */
  async checkFile(filePath) {
    if (this.shouldIgnore(filePath)) {
      return;
    }

    try {
      const content = await readFile(filePath, 'utf8');
      const fileResults = this.lintContent(content, filePath);
      this.results.push(...fileResults);
    } catch (error) {
      console.error(`Error reading file ${filePath}: ${error.message}`);
    }
  }

  /**
   * Check a directory recursively
   */
  async checkDirectory(dirPath) {
    const files = await readdir(dirPath);
    
    for (const file of files) {
      const fullPath = path.join(dirPath, file);
      const stats = fs.statSync(fullPath);
      
      if (stats.isDirectory()) {
        await this.checkDirectory(fullPath);
      } else if (file.endsWith('.ets')) {
        await this.checkFile(fullPath);
      }
    }
  }

  /**
   * Lint content of a file
   */
  lintContent(content, filePath) {
    const results = [];
    
    Object.entries(this.config.rules).forEach(([ruleName, severity]) => {
      if (severity === 'off') return;
      
      const rule = RULES[ruleName];
      if (!rule) {
        console.warn(`Warning: Unknown rule ${ruleName}`);
        return;
      }
      
      let match;
      const pattern = new RegExp(rule.pattern.source, rule.pattern.flags);
      
      while ((match = pattern.exec(content)) !== null) {
        // Calculate line number
        const lines = content.substring(0, match.index).split('\n');
        const line = lines.length;
        
        results.push({
          filePath,
          line,
          column: match.index - lines[lines.length - 1].length - 1,
          ruleName,
          message: rule.description,
          severity,
          match: match[0],
          fixable: rule.fixable
        });
        
        // Prevent infinite loops for zero-length matches
        if (match.index === pattern.lastIndex) {
          pattern.lastIndex++;
        }
      }
    });
    
    return results;
  }

  /**
   * Fix issues in a file
   */
  async fixFile(filePath) {
    if (this.shouldIgnore(filePath)) {
      return;
    }

    try {
      let content = await readFile(filePath, 'utf8');
      let hasChanges = false;
      
      // Apply fixes for each rule
      Object.entries(this.config.rules).forEach(([ruleName, severity]) => {
        if (severity === 'off') return;
        
        const rule = RULES[ruleName];
        if (!rule || !rule.fixable) return;
        
        // Simple fix for static-method-this rule
        if (ruleName === 'static-method-this') {
          // Replace this.method() with ClassName.method() in static methods
          // This is a simplified fix - in real implementation would need more context
          const fixedContent = content.replace(/static\s+(\w+)\s*\([^)]*\)\s*:\s*([^\n]+)\s*\{([^}]*)this\.(\w+)\(/gms, 
            'static $1($2): $3 { $3AnimationConfig.$4(');
          
          if (fixedContent !== content) {
            content = fixedContent;
            hasChanges = true;
          }
        }
      });
      
      if (hasChanges) {
        await writeFile(filePath, content);
        console.log(`Fixed ${filePath}`);
      }
    } catch (error) {
      console.error(`Error fixing file ${filePath}: ${error.message}`);
    }
  }

  /**
   * Fix issues in a directory
   */
  async fixDirectory(dirPath) {
    const files = await readdir(dirPath);
    
    for (const file of files) {
      const fullPath = path.join(dirPath, file);
      const stats = fs.statSync(fullPath);
      
      if (stats.isDirectory()) {
        await this.fixDirectory(fullPath);
      } else if (file.endsWith('.ets')) {
        await this.fixFile(fullPath);
      }
    }
  }

  /**
   * Print results
   */
  printResults() {
    if (this.results.length === 0) {
      console.log('✅ No issues found!');
      return;
    }
    
    console.log('\n❌ ArkTS Linter Results:');
    console.log('='.repeat(60));
    
    // Group results by file
    const resultsByFile = this.results.reduce((acc, result) => {
      if (!acc[result.filePath]) {
        acc[result.filePath] = [];
      }
      acc[result.filePath].push(result);
      return acc;
    }, {});
    
    Object.entries(resultsByFile).forEach(([filePath, fileResults]) => {
      console.log(`\n📁 ${filePath}:`);
      console.log('-'.repeat(40));
      
      fileResults.forEach(result => {
        const severityIcon = result.severity === 'error' ? '❌' : '⚠️';
        console.log(`${severityIcon} Line ${result.line}, Column ${result.column}`);
        console.log(`   Rule: ${result.ruleName}`);
        console.log(`   Message: ${result.message}`);
        console.log(`   Code: ${result.match.trim()}`);
        console.log('   ' + '-'.repeat(30));
      });
    });
    
    console.log('\n📊 Summary:');
    console.log('='.repeat(60));
    console.log(`Total issues: ${this.results.length}`);
    
    const errorCount = this.results.filter(r => r.severity === 'error').length;
    const warningCount = this.results.filter(r => r.severity === 'warning').length;
    
    console.log(`Errors: ${errorCount}`);
    console.log(`Warnings: ${warningCount}`);
  }
}

/**
 * Main function
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.log('Usage: arkts-linter <command> <path>');
    console.log('Commands:');
    console.log('  check   Check files for issues');
    console.log('  fix     Fix issues in files');
    console.log('Example:');
    console.log('  arkts-linter check src/main/ets/pages/Index.ets');
    process.exit(1);
  }
  
  const [command, targetPath] = args;
  const configPath = path.join(process.cwd(), '.arktslintrc.json');
  
  const linter = new ArkTSLinter(configPath);
  
  const fullPath = path.resolve(process.cwd(), targetPath);
  const stats = fs.statSync(fullPath);
  
  if (command === 'check') {
    if (stats.isDirectory()) {
      await linter.checkDirectory(fullPath);
    } else {
      await linter.checkFile(fullPath);
    }
    linter.printResults();
    
    // Exit with error code if there are errors
    const hasErrors = linter.results.some(r => r.severity === 'error');
    process.exit(hasErrors ? 1 : 0);
  } else if (command === 'fix') {
    if (stats.isDirectory()) {
      await linter.fixDirectory(fullPath);
    } else {
      await linter.fixFile(fullPath);
    }
  } else {
    console.error(`Unknown command: ${command}`);
    process.exit(1);
  }
}

// Run the main function
main().catch(error => {
  console.error(`Error: ${error.message}`);
  process.exit(1);
});