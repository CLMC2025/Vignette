/**
 * ArkTS Compliance CLI
 * Command-line interface for ArkTS coding compliance checking
 */

import { Command } from 'commander';
import { CodeAnalyzer } from './code-analyzer';
import { ReportGenerator, ReportFormat } from './report-generator';
import { ConfigManager } from './config-manager';
import { writeFileSync } from 'fs';

const program = new Command();

program
  .name('arkts-compliance')
  .description('ArkTS Coding Compliance Checker - Enforces strict ArkTS/ETS coding rules')
  .version('1.0.0');

// Analyze command
program
  .command('analyze')
  .description('Analyze ArkTS/ETS files for compliance violations')
  .argument('<directory>', 'Directory to analyze')
  .option('-c, --config <path>', 'Path to configuration file')
  .option('-f, --format <format>', 'Report format (markdown, html, json)', 'markdown')
  .option('-o, --output <path>', 'Output file path for the report')
  .action(async (directory: string, options: { config?: string, format?: string, output?: string }) => {
    console.log('🔍 Starting ArkTS compliance analysis...');
    console.log(`📁 Directory: ${directory}`);
    
    const configManager = new ConfigManager(options.config);
    const rules = configManager.getRules();
    const excludedDirs = configManager.getExcludedDirs();
    
    const analyzer = new CodeAnalyzer(rules, excludedDirs);
    const result = await analyzer.analyze(directory);
    
    const reportGenerator = new ReportGenerator();
    const format = (options.format as ReportFormat) || ReportFormat.MARKDOWN;
    const report = reportGenerator.generateReport(result, format);
    
    if (options.output) {
      reportGenerator.writeReport(result, format, options.output);
      console.log(`📄 Report written to: ${options.output}`);
    } else {
      console.log(report);
    }
    
    if (result.totalViolations > 0) {
      console.log(`\n❌ Found ${result.totalViolations} violations in ${result.filesWithViolations} files`);
      process.exit(1);
    } else {
      console.log(`\n✅ No violations found! All files are compliant.`);
      process.exit(0);
    }
  });

// Init command - create default config file
program
  .command('init')
  .description('Create default configuration file')
  .option('-o, --output <path>', 'Output path for config file', 'arkts-compliance.yaml')
  .action((options: { output: string }) => {
    const configManager = new ConfigManager();
    const defaultConfig = configManager.getDefaultConfigContent();
    writeFileSync(options.output, defaultConfig);
    console.log(`📋 Default config file created at: ${options.output}`);
  });

// Check command - check single file
program
  .command('check')
  .description('Check single ArkTS/ETS file for compliance violations')
  .argument('<file>', 'File to check')
  .option('-c, --config <path>', 'Path to configuration file')
  .option('-f, --format <format>', 'Report format (markdown, html, json)', 'markdown')
  .action(async (file: string, options: { config?: string, format?: string }) => {
    console.log(`🔍 Checking file: ${file}`);
    
    const configManager = new ConfigManager(options.config);
    const rules = configManager.getRules();
    
    const analyzer = new CodeAnalyzer(rules);
    const result = await analyzer.analyze(file);
    
    const reportGenerator = new ReportGenerator();
    const format = (options.format as ReportFormat) || ReportFormat.MARKDOWN;
    const report = reportGenerator.generateReport(result, format);
    
    console.log(report);
    
    if (result.totalViolations > 0) {
      console.log(`\n❌ Found ${result.totalViolations} violations`);
      process.exit(1);
    } else {
      console.log(`\n✅ No violations found! File is compliant.`);
      process.exit(0);
    }
  });

// Parse arguments
program.parse(process.argv);
