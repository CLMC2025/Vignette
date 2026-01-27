/**
 * ArkTS Compliance Skill Main Entry Point
 * Exports all components for use in other systems
 */

export * from './rules';
export * from './code-analyzer';
export * from './report-generator';
export * from './config-manager';

import { CodeAnalyzer } from './code-analyzer';
import { ReportGenerator } from './report-generator';
import { ConfigManager } from './config-manager';

export class ArkTSCompliance {
  private analyzer: CodeAnalyzer;
  private reportGenerator: ReportGenerator;
  private configManager: ConfigManager;

  constructor(configPath?: string) {
    this.configManager = new ConfigManager(configPath);
    const rules = this.configManager.getRules();
    const excludedDirs = this.configManager.getExcludedDirs();
    this.analyzer = new CodeAnalyzer(rules, excludedDirs);
    this.reportGenerator = new ReportGenerator();
  }

  /**
   * Analyze ArkTS/ETS files for compliance violations
   */
  async analyze(directory: string) {
    return this.analyzer.analyze(directory);
  }

  /**
   * Generate compliance report
   */
  generateReport(result: any, format: string = 'markdown') {
    return this.reportGenerator.generateReport(result, format as any);
  }

  /**
   * Get the current configuration
   */
  getConfig() {
    return this.configManager;
  }
}

export default ArkTSCompliance;