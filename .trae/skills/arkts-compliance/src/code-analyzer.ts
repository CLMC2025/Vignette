/**
 * ArkTS Compliance Code Analyzer
 * Scans ArkTS/ETS files for compliance violations
 */

import { readFileSync } from 'fs';
import { Rule, Severity } from './rules';
import { glob } from 'glob';

export interface Violation {
  ruleId: string;
  ruleName: string;
  file: string;
  line: number;
  column: number;
  content: string;
  severity: Severity;
  category: string;
  fixSuggestion: string;
}

export interface AnalysisResult {
  violations: Violation[];
  totalFiles: number;
  filesWithViolations: number;
  totalViolations: number;
  violationsBySeverity: Record<Severity, number>;
  violationsByCategory: Record<string, number>;
}

export class CodeAnalyzer {
  private rules: Rule[];
  private excludedDirs: string[];

  constructor(rules: Rule[], excludedDirs: string[] = []) {
    this.rules = rules.filter(rule => rule.enabled);
    this.excludedDirs = excludedDirs;
  }

  /**
   * Analyze all ArkTS/ETS files in the given directory
   */
  async analyze(directory: string): Promise<AnalysisResult> {
    const files = await this.getArkTSFiles(directory);
    const violations: Violation[] = [];

    for (const file of files) {
      const fileViolations = this.analyzeFile(file);
      violations.push(...fileViolations);
    }

    return this.generateResult(violations, files.length);
  }

  /**
   * Get all ArkTS/ETS files in the directory
   */
  private async getArkTSFiles(directory: string): Promise<string[]> {
    const patterns = [
      `${directory}/**/*.ets`,
      `${directory}/**/*.ts`
    ];

    let files: string[] = [];
    for (const pattern of patterns) {
      const matches = await glob(pattern, {
        ignore: this.excludedDirs.map(dir => `${directory}/${dir}/**`)
      });
      files = [...files, ...matches];
    }

    return files;
  }

  /**
   * Analyze a single file for violations
   */
  private analyzeFile(filePath: string): Violation[] {
    const content = readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    const violations: Violation[] = [];

    for (const rule of this.rules) {
      // Skip UI rules for non-UI files
      if ((rule.id === 'ui-in-model' || rule.id === 'no-on-finish') && 
          this.isNonUIFile(filePath)) {
        continue;
      }

      for (let lineNum = 0; lineNum < lines.length; lineNum++) {
        const line = lines[lineNum];
        let match;

        // Reset regex lastIndex for multiple matches in the same line
        rule.pattern.lastIndex = 0;

        while ((match = rule.pattern.exec(line)) !== null) {
          violations.push({
            ruleId: rule.id,
            ruleName: rule.name,
            file: filePath,
            line: lineNum + 1,
            column: match.index + 1,
            content: line.trim(),
            severity: rule.severity,
            category: rule.category,
            fixSuggestion: rule.fixSuggestion
          });
        }
      }
    }

    return violations;
  }

  /**
   * Check if a file is a non-UI file
   */
  private isNonUIFile(filePath: string): boolean {
    const nonUIDirs = ['model', 'algorithm', 'database', 'sync', 'manager', 'assessment', 'context', 'vocabulary'];
    return nonUIDirs.some(dir => filePath.includes(`/${dir}/`));
  }

  /**
   * Generate analysis result from violations
   */
  private generateResult(violations: Violation[], totalFiles: number): AnalysisResult {
    const filesWithViolations = new Set(violations.map(v => v.file)).size;
    const violationsBySeverity: Record<Severity, number> = {
      [Severity.ERROR]: 0,
      [Severity.WARNING]: 0,
      [Severity.INFO]: 0
    };

    const violationsByCategory: Record<string, number> = {};

    for (const violation of violations) {
      violationsBySeverity[violation.severity]++;
      violationsByCategory[violation.category] = (violationsByCategory[violation.category] || 0) + 1;
    }

    return {
      violations,
      totalFiles,
      filesWithViolations,
      totalViolations: violations.length,
      violationsBySeverity,
      violationsByCategory
    };
  }
}