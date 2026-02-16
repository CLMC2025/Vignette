// =====================================================
// ContextValidator.ets - 语境验证系统
// 多维度验证语境的准确性、语法正确性和难度适配性
// =====================================================

import { DifficultyLevel } from './TemplateManager';
import { TextSanitizer } from '../utils/TextSanitizer';

/**
 * 验证问题
 */
export class ValidationIssue {
  type: ValidationIssueType;
  severity: IssueSeverity;
  message: string;
  suggestion: string;

  constructor(
    type: ValidationIssueType,
    severity: IssueSeverity,
    message: string,
    suggestion: string = ''
  ) {
    this.type = type;
    this.severity = severity;
    this.message = message;
    this.suggestion = suggestion;
  }
}

/**
 * 验证问题类型
 */
export enum ValidationIssueType {
  WORD_MISSING = 'WORD_MISSING',           // 目标词汇缺失
  GRAMMAR_ERROR = 'GRAMMAR_ERROR',         // 语法错误
  SEMANTIC_ERROR = 'SEMANTIC_ERROR',       // 语义错误
  DIFFICULTY_MISMATCH = 'DIFFICULTY_MISMATCH', // 难度不匹配
  LENGTH_INVALID = 'LENGTH_INVALID',         // 长度无效
  PUNCTUATION_ERROR = 'PUNCTUATION_ERROR'   // 标点错误
}

/**
 * 问题严重程度
 */
export enum IssueSeverity {
  ERROR = 'ERROR',       // 错误，必须修复
  WARNING = 'WARNING',   // 警告，建议修复
  INFO = 'INFO'          // 信息，可选修复
}

/**
 * 验证结果
 */
export class ValidationResult {
  isValid: boolean;
  issues: ValidationIssue[];
  score: number;  // 0-100分

  constructor() {
    this.isValid = true;
    this.issues = [];
    this.score = 100;
  }

  /**
   * 添加问题
   */
  addIssue(issue: ValidationIssue): void {
    this.issues.push(issue);
    
    // 根据严重程度调整分数
    switch (issue.severity) {
      case IssueSeverity.ERROR:
        this.score -= 30;
        break;
      case IssueSeverity.WARNING:
        this.score -= 10;
        break;
      case IssueSeverity.INFO:
        this.score -= 5;
        break;
    }

    // 更新有效性
    this.isValid = this.score >= 60;
  }

  /**
   * 获取错误问题
   */
  getErrors(): ValidationIssue[] {
    return this.issues.filter((issue: ValidationIssue): boolean => 
      issue.severity === IssueSeverity.ERROR
    );
  }

  /**
   * 获取警告问题
   */
  getWarnings(): ValidationIssue[] {
    return this.issues.filter((issue: ValidationIssue): boolean => 
      issue.severity === IssueSeverity.WARNING
    );
  }

  /**
   * 获取信息问题
   */
  getInfoIssues(): ValidationIssue[] {
    return this.issues.filter((issue: ValidationIssue): boolean => 
      issue.severity === IssueSeverity.INFO
    );
  }

  /**
   * 获取摘要
   */
  getSummary(): string {
    const errorCount = this.getErrors().length;
    const warningCount = this.getWarnings().length;
    const infoCount = this.getInfoIssues().length;

    if (errorCount === 0 && warningCount === 0 && infoCount === 0) {
      return '验证通过，语境质量良好';
    }

    const parts: string[] = [];
    if (errorCount > 0) {
      parts.push(`${errorCount} 个错误`);
    }
    if (warningCount > 0) {
      parts.push(`${warningCount} 个警告`);
    }
    if (infoCount > 0) {
      parts.push(`${infoCount} 个提示`);
    }

    return `发现 ${parts.join(', ')}，评分: ${this.score}/100`;
  }
}

/**
 * 语境验证器
 */
export class ContextValidator {
  private static instance: ContextValidator | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): ContextValidator {
    if (ContextValidator.instance === null) {
      ContextValidator.instance = new ContextValidator();
    }
    return ContextValidator.instance;
  }

  /**
   * 验证语境
   */
  validate(
    context: string,
    targetWord: string,
    userLevel: DifficultyLevel = DifficultyLevel.CET6,
    minWords: number = 0,
    maxWords: number = 9999,
    minTargetOccurrences: number = 1,
    maxTargetOccurrences: number = 9999
  ): ValidationResult {
    const result = new ValidationResult();

    // 1. 检查目标词汇出现次数
    this.validateTargetWordOccurrences(context, targetWord, minTargetOccurrences, maxTargetOccurrences, result);

    // 2. 检查语法正确性
    this.validateGrammar(context, result);

    // 3. 检查语义相关性
    this.validateSemantics(context, targetWord, result);

    // 4. 检查难度适配性
    this.validateDifficulty(context, userLevel, result);

    // 5. 检查长度有效性
    this.validateLength(context, minWords, maxWords, result);

    // 6. 检查标点符号
    this.validatePunctuation(context, result);

    return result;
  }

  /**
   * 验证目标词汇出现次数
   */
  private validateTargetWordOccurrences(
    context: string,
    targetWord: string,
    minTargetOccurrences: number,
    maxTargetOccurrences: number,
    result: ValidationResult
  ): void {
    const count = this.countTargetWordOccurrences(context, targetWord);

    if (count <= 0) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.WORD_MISSING,
        IssueSeverity.ERROR,
        `目标词汇 "${targetWord}" 不在语境中`,
        `请确保目标词汇 "${targetWord}" 出现在语境中`
      ));
      return;
    }

    if (count < minTargetOccurrences) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.SEMANTIC_ERROR,
        IssueSeverity.WARNING,
        `目标词汇 "${targetWord}" 出现次数偏少（${count}次）`,
        `建议让 "${targetWord}" 自然出现 ${minTargetOccurrences}-${maxTargetOccurrences} 次`
      ));
    } else if (count > maxTargetOccurrences) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.SEMANTIC_ERROR,
        IssueSeverity.WARNING,
        `目标词汇 "${targetWord}" 出现次数偏多（${count}次）`,
        `建议让 "${targetWord}" 自然出现 ${minTargetOccurrences}-${maxTargetOccurrences} 次`
      ));
    }
  }

  /**
   * 验证语法正确性
   */
  private validateGrammar(context: string, result: ValidationResult): void {
    // 检查句子结构
    if (!context.trim().endsWith('.')) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.GRAMMAR_ERROR,
        IssueSeverity.WARNING,
        '句子应以句号结尾',
        '在句子末尾添加句号'
      ));
    }

    // 检查连续空格
    if (context.includes('  ')) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.GRAMMAR_ERROR,
        IssueSeverity.WARNING,
        '存在连续空格',
        '移除多余的空格'
      ));
    }

    // 检查大小写一致性（首字母大写）
    const sentences = context.split('. ');
    for (const sentence of sentences) {
      if (sentence.length > 0) {
        const firstChar = sentence.charAt(0);
        if (firstChar !== firstChar.toUpperCase()) {
          result.addIssue(new ValidationIssue(
            ValidationIssueType.GRAMMAR_ERROR,
            IssueSeverity.INFO,
            '句子首字母应大写',
            '将句子首字母改为大写'
          ));
        }
      }
    }

    // 检查括号匹配
    const openParens = (context.match(/\(/g) || []).length;
    const closeParens = (context.match(/\)/g) || []).length;
    if (openParens !== closeParens) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.GRAMMAR_ERROR,
        IssueSeverity.ERROR,
        '括号不匹配',
        '检查并修复括号'
      ));
    }
  }

  /**
   * 验证语义相关性
   */
  private validateSemantics(
    context: string,
    targetWord: string,
    result: ValidationResult
  ): void {
    // 检查语境长度是否足够包含语义
    if (context.length < 20) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.SEMANTIC_ERROR,
        IssueSeverity.WARNING,
        '语境过短，语义不完整',
        '增加语境长度以提供更完整的语义'
      ));
    }

    // 检查是否有重复的单词
    const words = context.toLowerCase().split(/\s+/);
    const uniqueWords = new Set<string>(words);
    const duplicateRatio = (words.length - uniqueWords.size) / words.length;

    if (duplicateRatio > 0.3) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.SEMANTIC_ERROR,
        IssueSeverity.INFO,
        '存在较多重复词汇',
        '考虑使用更多样化的词汇'
      ));
    }
  }

  /**
   * 验证难度适配性
   */
  private validateDifficulty(
    context: string,
    userLevel: DifficultyLevel,
    result: ValidationResult
  ): void {
    const wordCount = context.split(/\s+/).length;
    const avgWordLength = context.replace(/\s+/g, '').length / wordCount;

    // 根据用户级别检查词汇复杂度
    const expectedMaxWordLength = this.getMaxWordLength(userLevel);
    
    if (avgWordLength > expectedMaxWordLength) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.DIFFICULTY_MISMATCH,
        IssueSeverity.WARNING,
        `平均词长 ${avgWordLength.toFixed(1)} 超过用户级别 ${userLevel} 的建议值 ${expectedMaxWordLength}`,
        '简化词汇以适应用户水平'
      ));
    }

    // 检查句子长度
    const sentenceCount = context.split(/[.!?]+/).length;
    const avgSentenceLength = wordCount / sentenceCount;

    const expectedMaxSentenceLength = this.getMaxSentenceLength(userLevel);

    if (avgSentenceLength > expectedMaxSentenceLength) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.DIFFICULTY_MISMATCH,
        IssueSeverity.INFO,
        `平均句长 ${avgSentenceLength.toFixed(1)} 超过建议值 ${expectedMaxSentenceLength}`,
        '考虑拆分长句子'
      ));
    }
  }

  /**
   * 验证长度有效性
   */
  private validateLength(context: string, minWords: number, maxWords: number, result: ValidationResult): void {
    const wordCount = this.countWords(context);
    if (minWords > 0 && wordCount < minWords) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.LENGTH_INVALID,
        IssueSeverity.ERROR,
        '语境过短',
        `语境应至少包含 ${minWords} 个单词（当前 ${wordCount}）`
      ));
    }

    if (maxWords > 0 && wordCount > maxWords) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.LENGTH_INVALID,
        IssueSeverity.WARNING,
        '语境过长',
        `建议将语境长度控制在 ${maxWords} 个单词以内（当前 ${wordCount}）`
      ));
    }
  }

  private countWords(context: string): number {
    const matches = context.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g);
    if (matches === null) {
      const trimmed = context.trim();
      if (trimmed.length === 0) return 0;
      const parts = trimmed.split(/\s+/).filter((s: string): boolean => s.length > 0);
      return parts.length;
    }
    return matches.length;
  }

  private countTargetWordOccurrences(context: string, targetWord: string): number {
    const escaped = this.escapeRegExp(targetWord.trim());
    if (escaped.length === 0) return 0;
    const re = new RegExp(`\\b${escaped}\\b`, 'gi');
    const matches = context.match(re);
    return matches === null ? 0 : matches.length;
  }

  private escapeRegExp(text: string): string {
    return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 验证标点符号
   */
  private validatePunctuation(context: string, result: ValidationResult): void {
    // 检查连续标点
    if (/[.!?]{2,}/.test(context)) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.PUNCTUATION_ERROR,
        IssueSeverity.WARNING,
        '存在连续标点符号',
        '移除多余的标点符号'
      ));
    }

    // 检查标点后空格
    if (/[.!?][a-zA-Z]/.test(context)) {
      result.addIssue(new ValidationIssue(
        ValidationIssueType.PUNCTUATION_ERROR,
        IssueSeverity.INFO,
        '标点后应有空格',
        '在标点符号后添加空格'
      ));
    }
  }

  /**
   * 获取最大词长（根据用户级别）
   */
  private getMaxWordLength(userLevel: DifficultyLevel): number {
    switch (userLevel) {
      case DifficultyLevel.CET4:
        return 5;
      case DifficultyLevel.CET6:
        return 6;
      case DifficultyLevel.IELTS:
        return 7;
      case DifficultyLevel.TOEFL:
        return 8;
      case DifficultyLevel.SAT:
        return 9;
      case DifficultyLevel.GRE:
        return 10;
      default:
        return 6;
    }
  }

  /**
   * 获取最大句长（根据用户级别）
   */
  private getMaxSentenceLength(userLevel: DifficultyLevel): number {
    switch (userLevel) {
      case DifficultyLevel.CET4:
        return 10;
      case DifficultyLevel.CET6:
        return 15;
      case DifficultyLevel.IELTS:
        return 20;
      case DifficultyLevel.TOEFL:
        return 25;
      case DifficultyLevel.SAT:
        return 30;
      case DifficultyLevel.GRE:
        return 35;
      default:
        return 15;
    }
  }

  /**
   * 批量验证
   */
  validateBatch(
    contexts: string[],
    targetWord: string,
    userLevel: DifficultyLevel = DifficultyLevel.CET6
  ): ValidationResult[] {
    return contexts.map((context: string): ValidationResult => 
      this.validate(context, targetWord, userLevel)
    );
  }

  /**
   * 获取最佳语境
   */
  getBestContext(
    contexts: string[],
    targetWord: string,
    userLevel: DifficultyLevel = DifficultyLevel.CET6
  ): BestContextResult | null {
    if (contexts.length === 0) {
      return null;
    }

    const results = this.validateBatch(contexts, targetWord, userLevel);
    
    // 按分数排序
    results.sort((a: ValidationResult, b: ValidationResult): number => b.score - a.score);

    const bestResult: BestContextResult = {
      context: contexts[results.indexOf(results[0])],
      result: results[0]
    };
    return bestResult;
  }

  /**
   * 生成改进建议
   */
  generateImprovements(result: ValidationResult): string[] {
    const improvements: string[] = [];

    for (const issue of result.issues) {
      if (issue.suggestion.length > 0) {
        improvements.push(issue.suggestion);
      }
    }

    return improvements;
  }

  /**
   * 获取验证统计
   */
  getValidationStats(results: ValidationResult[]): ValidationStats {
    const total = results.length;
    const valid = results.filter((r: ValidationResult): boolean => r.isValid).length;
    const invalid = total - valid;
    const averageScore = results.reduce((sum: number, r: ValidationResult): number => 
      sum + r.score, 0
    ) / total;

    const stats: ValidationStats = {
      total,
      valid,
      invalid,
      averageScore
    };
    return stats;
  }

  /**
   * 检查语境是否适合AI生成
   */
  isSuitableForAI(context: string): boolean {
    // 检查是否包含敏感词
    const sensitiveWords = ['test', 'example', 'demo', 'sample'];
    const lowerContext = context.toLowerCase();

    for (const word of sensitiveWords) {
      if (lowerContext.includes(word)) {
        return false;
      }
    }

    return true;
  }

  /**
   * 检查语境是否适合离线生成
   */
  isSuitableForOffline(context: string): boolean {
    // 检查词汇复杂度
    const words = context.split(/\s+/);
    const avgWordLength = context.replace(/\s+/g, '').length / words.length;

    // 如果平均词长超过12，可能不适合离线模板
    if (avgWordLength > 12) {
      return false;
    }

    return true;
  }

  /**
   * 清理语境（修复常见问题）
   */
  cleanContext(context: string): string {
    let cleaned = TextSanitizer.sanitizeContext(context);
    cleaned = cleaned.trim();

    // 修复标点后空格
    cleaned = cleaned.replace(/([.!?])([a-zA-Z])/g, '$1 $2');

    // 确保句子以句号结尾
    if (!cleaned.endsWith('.')) {
      cleaned += '.';
    }

    // 首字母大写
    cleaned = cleaned.charAt(0).toUpperCase() + cleaned.slice(1);

    return cleaned;
  }
}

export interface BestContextResult {
  context: string;
  result: ValidationResult;
}

export interface ValidationStats {
  total: number;
  valid: number;
  invalid: number;
  averageScore: number;
}
