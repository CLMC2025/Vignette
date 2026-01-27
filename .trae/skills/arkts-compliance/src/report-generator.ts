/**
 * ArkTS Compliance Report Generator
 * Creates comprehensive compliance reports from analysis results
 */

import { writeFileSync } from 'fs';
import { AnalysisResult, Violation } from './code-analyzer';
import { Severity } from './rules';

export enum ReportFormat {
  MARKDOWN = 'markdown',
  HTML = 'html',
  JSON = 'json'
}

export class ReportGenerator {
  /**
   * Generate report in specified format
   */
  generateReport(result: AnalysisResult, format: ReportFormat = ReportFormat.MARKDOWN): string {
    switch (format) {
      case ReportFormat.MARKDOWN:
        return this.generateMarkdownReport(result);
      case ReportFormat.HTML:
        return this.generateHtmlReport(result);
      case ReportFormat.JSON:
        return this.generateJsonReport(result);
      default:
        return this.generateMarkdownReport(result);
    }
  }

  /**
   * Write report to file
   */
  writeReport(result: AnalysisResult, format: ReportFormat, outputPath: string): void {
    const report = this.generateReport(result, format);
    writeFileSync(outputPath, report);
  }

  /**
   * Generate Markdown report
   */
  private generateMarkdownReport(result: AnalysisResult): string {
    let report = '# ArkTS Compliance Report\n\n';
    report += `**Generated:** ${new Date().toISOString()}\n\n`;

    // Summary
    report += '## Summary\n\n';
    report += `| Metric | Value |\n`;
    report += `|--------|-------|\n`;
    report += `| Total Files Checked | ${result.totalFiles} |\n`;
    report += `| Files With Violations | ${result.filesWithViolations} |\n`;
    report += `| Total Violations | ${result.totalViolations} |\n`;
    report += `| Errors | ${result.violationsBySeverity[Severity.ERROR]} |\n`;
    report += `| Warnings | ${result.violationsBySeverity[Severity.WARNING]} |\n`;
    report += `| Info | ${result.violationsBySeverity[Severity.INFO]} |\n\n`;

    // Violations by Category
    report += '## Violations by Category\n\n';
    for (const [category, count] of Object.entries(result.violationsByCategory)) {
      report += `- **${category}**: ${count} violations\n`;
    }
    report += '\n';

    // Detailed Violations
    if (result.violations.length > 0) {
      report += '## Detailed Violations\n\n';

      // Group violations by file
      const violationsByFile = this.groupViolationsByFile(result.violations);

      for (const [file, violations] of Object.entries(violationsByFile)) {
        report += `### ${file}\n\n`;
        report += `| Line | Rule | Severity | Description | Fix Suggestion |\n`;
        report += `|------|------|----------|-------------|----------------|\n`;

        for (const violation of violations) {
          report += `| ${violation.line} | ${violation.ruleName} | ${violation.severity} | ${violation.content} | ${violation.fixSuggestion} |\n`;
        }
        report += '\n';
      }
    } else {
      report += '## Status: ✅ FULLY COMPLIANT\n\n';
      report += 'All files pass strict ArkTS compliance checks!\n';
    }

    return report;
  }

  /**
   * Generate HTML report
   */
  private generateHtmlReport(result: AnalysisResult): string {
    // Basic HTML report implementation
    let report = `<!DOCTYPE html>\n<html>\n<head>\n`;
    report += `<title>ArkTS Compliance Report</title>\n`;
    report += `<style>\n`;
    report += `body { font-family: Arial, sans-serif; margin: 20px; }\n`;
    report += `h1 { color: #2c3e50; }\n`;
    report += `.summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }\n`;
    report += `.compliant { color: #27ae60; font-weight: bold; }\n`;
    report += `.error { color: #e74c3c; }\n`;
    report += `.warning { color: #f39c12; }\n`;
    report += `.info { color: #3498db; }\n`;
    report += `table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }\n`;
    report += `th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n`;
    report += `th { background-color: #f2f2f2; }\n`;
    report += `.file-section { margin-bottom: 30px; }\n`;
    report += `</style>\n`;
    report += `</head>\n<body>\n`;

    report += `<h1>ArkTS Compliance Report</h1>\n`;
    report += `<p>Generated: ${new Date().toISOString()}</p>\n`;

    // Summary
    report += `<div class="summary">\n`;
    report += `<h2>Summary</h2>\n`;
    report += `<table>\n`;
    report += `<tr><td>Total Files Checked</td><td>${result.totalFiles}</td></tr>\n`;
    report += `<tr><td>Files With Violations</td><td>${result.filesWithViolations}</td></tr>\n`;
    report += `<tr><td>Total Violations</td><td>${result.totalViolations}</td></tr>\n`;
    report += `<tr><td>Errors</td><td class="error">${result.violationsBySeverity[Severity.ERROR]}</td></tr>\n`;
    report += `<tr><td>Warnings</td><td class="warning">${result.violationsBySeverity[Severity.WARNING]}</td></tr>\n`;
    report += `<tr><td>Info</td><td class="info">${result.violationsBySeverity[Severity.INFO]}</td></tr>\n`;
    report += `</table>\n`;
    report += `</div>\n`;

    // Detailed Violations
    if (result.violations.length > 0) {
      report += `<h2>Detailed Violations</h2>\n`;
      const violationsByFile = this.groupViolationsByFile(result.violations);

      for (const [file, violations] of Object.entries(violationsByFile)) {
        report += `<div class="file-section">\n`;
        report += `<h3>${file}</h3>\n`;
        report += `<table>\n`;
        report += `<tr><th>Line</th><th>Rule</th><th>Severity</th><th>Description</th><th>Fix Suggestion</th></tr>\n`;

        for (const violation of violations) {
          const severityClass = violation.severity.toLowerCase();
          report += `<tr>\n`;
          report += `<td>${violation.line}</td>\n`;
          report += `<td>${violation.ruleName}</td>\n`;
          report += `<td class="${severityClass}">${violation.severity}</td>\n`;
          report += `<td>${violation.content}</td>\n`;
          report += `<td>${violation.fixSuggestion}</td>\n`;
          report += `</tr>\n`;
        }
        report += `</table>\n`;
        report += `</div>\n`;
      }
    } else {
      report += `<h2 class="compliant">Status: FULLY COMPLIANT</h2>\n`;
      report += `<p>All files pass strict ArkTS compliance checks!</p>\n`;
    }

    report += `</body>\n</html>`;
    return report;
  }

  /**
   * Generate JSON report
   */
  private generateJsonReport(result: AnalysisResult): string {
    return JSON.stringify(result, null, 2);
  }

  /**
   * Group violations by file
   */
  private groupViolationsByFile(violations: Violation[]): Record<string, Violation[]> {
    const grouped: Record<string, Violation[]> = {};

    for (const violation of violations) {
      if (!grouped[violation.file]) {
        grouped[violation.file] = [];
      }
      grouped[violation.file].push(violation);
    }

    return grouped;
  }
}