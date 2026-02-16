// =====================================================
// UnknownWordHandler.ets - 未知词汇处理器
// 检测、处理和管理未知词汇
// =====================================================

import { VocabularyTracker, VocabularyRecord } from './VocabularyTracker';
import { WordDefinition, WordStatus } from '../model/WordModel';

/**
 * 未知词汇信息
 */
export class UnknownWordInfo {
  word: string;
  context: string;
  timestamp: number;
  frequency: number;
  priority: Priority;
  status: WordStatus;

  constructor(
    word: string,
    context: string,
    frequency: number = 1,
    priority: Priority = Priority.MEDIUM
  ) {
    this.word = word;
    this.context = context;
    this.timestamp = Date.now();
    this.frequency = frequency;
    this.priority = priority;
    this.status = WordStatus.NEW;
  }
}

/**
 * 优先级
 */
export enum Priority {
  HIGH = 'HIGH',
  MEDIUM = 'MEDIUM',
  LOW = 'LOW'
}

/**
 * 处理策略
 */
export enum HandlingStrategy {
  IMMEDIATE_LEARN = 'IMMEDIATE_LEARN',       // 立即学习
  CONTEXT_SIMPLIFY = 'CONTEXT_SIMPLIFY',   // 语境简化
  SKIP_IGNORE = 'SKIP_IGNORE',             // 跳过忽略
  QUEUE_FOR_LATER = 'QUEUE_FOR_LATER'       // 稍后处理
}

/**
 * 处理结果
 */
export class HandlingResult {
  strategy: HandlingStrategy;
  simplifiedContext: string;
  alternativeWord: string;
  shouldAddToNotebook: boolean;

  constructor(
    strategy: HandlingStrategy,
    simplifiedContext: string = '',
    alternativeWord: string = '',
    shouldAddToNotebook: boolean = false
  ) {
    this.strategy = strategy;
    this.simplifiedContext = simplifiedContext;
    this.alternativeWord = alternativeWord;
    this.shouldAddToNotebook = shouldAddToNotebook;
  }
}

/**
 * 上下文处理参数接口
 */
export interface ContextItem {
  context: string;
  knownWords: string[];
  targetWord: string;
}

/**
 * 处理结果项接口
 */
export interface HandlingResultItem {
  word: string;
  result: HandlingResult;
}

/**
 * 未知词汇统计信息接口
 */
export interface UnknownWordStats {
  totalUnknown: number;
  highPriority: number;
  mediumPriority: number;
  lowPriority: number;
  avgFrequency: number;
}

/**
 * 未知词汇导出数据接口
 */
export interface ExportedUnknownWord {
  word: string;
  context: string;
  timestamp: number;
  frequency: number;
  priority: Priority;
  status: WordStatus;
}

/**
 * 未知词汇处理器
 */
export class UnknownWordHandler {
  private static instance: UnknownWordHandler | null = null;
  private vocabularyTracker: VocabularyTracker;
  private unknownWords: Map<string, UnknownWordInfo>;
  private maxUnknownWords: number = 100;

  private constructor() {
    this.vocabularyTracker = VocabularyTracker.getInstance();
    this.unknownWords = new Map();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): UnknownWordHandler {
    if (UnknownWordHandler.instance === null) {
      UnknownWordHandler.instance = new UnknownWordHandler();
    }
    return UnknownWordHandler.instance;
  }

  /**
   * 检测未知词汇
   */
  detectUnknownWords(
    context: string,
    knownWords: string[],
    targetWord: string
  ): string[] {
    const words = this.extractWords(context);
    const unknown: Array<string> = [];

    for (const word of words) {
      // 跳过目标词汇
      if (word.toLowerCase() === targetWord.toLowerCase()) {
        continue;
      }

      // 检查是否在已知词汇中
      const isKnown = knownWords.some((known: string): boolean => 
        known.toLowerCase() === word.toLowerCase()
      );

      if (!isKnown) {
        unknown.push(word);
      }
    }

    return unknown;
  }

  /**
   * 提取词汇
   */
  private extractWords(text: string): string[] {
    // 移除标点符号，分割词汇
    const cleanText = text.replace(/[^\w\s]/g, ' ');
    return cleanText.split(/\s+/).filter((word: string): boolean => word.length > 1);
  }

  /**
   * 分析未知词汇
   */
  analyzeUnknownWord(word: string, context: string): UnknownWordInfo {
    const existing = this.unknownWords.get(word.toLowerCase());

    if (existing !== undefined) {
      // 更新现有记录
      existing.frequency++;
      existing.timestamp = Date.now();
      existing.context = context;
      return existing;
    }

    // 创建新记录
    const frequency = 1;
    const priority = this.calculatePriority(word, frequency, context);
    const info = new UnknownWordInfo(word, context, frequency, priority);

    this.unknownWords.set(word.toLowerCase(), info);

    // 限制未知词汇数量
    if (this.unknownWords.size > this.maxUnknownWords) {
      this.cleanupOldUnknownWords();
    }

    return info;
  }

  /**
   * 计算优先级
   */
  private calculatePriority(word: string, frequency: number, context: string): Priority {
    // 根据词长判断
    if (word.length > 8) {
      return Priority.HIGH;
    } else if (word.length > 5) {
      return Priority.MEDIUM;
    }

    // 根据频率判断
    if (frequency > 3) {
      return Priority.HIGH;
    } else if (frequency > 1) {
      return Priority.MEDIUM;
    }

    // 根据语境判断
    if (context.length > 200) {
      return Priority.LOW;
    }

    return Priority.MEDIUM;
  }

  /**
   * 确定处理策略
   */
  determineHandlingStrategy(wordInfo: UnknownWordInfo, userLevel: number): HandlingResult {
    const result = new HandlingResult(HandlingStrategy.SKIP_IGNORE);

    // 根据优先级和用户水平确定策略
    if (wordInfo.priority === Priority.HIGH) {
      // 高优先级：立即学习
      result.strategy = HandlingStrategy.IMMEDIATE_LEARN;
      result.shouldAddToNotebook = true;
    } else if (wordInfo.priority === Priority.MEDIUM) {
      // 中优先级：根据用户水平决定
      if (userLevel <= 2) {
        // 初学者：简化语境
        result.strategy = HandlingStrategy.CONTEXT_SIMPLIFY;
        result.simplifiedContext = this.simplifyContext(wordInfo.context, wordInfo.word);
      } else {
        // 中高级：稍后处理
        result.strategy = HandlingStrategy.QUEUE_FOR_LATER;
      }
    } else {
      // 低优先级：跳过
      result.strategy = HandlingStrategy.SKIP_IGNORE;
    }

    return result;
  }

  /**
   * 简化语境
   */
  private simplifyContext(context: string, unknownWord: string): string {
    // 移除未知词汇或用简单词汇替换
    const words = this.extractWords(context);
    const simplified: string[] = [];

    for (const word of words) {
      if (word.toLowerCase() === unknownWord.toLowerCase()) {
        // 用同义词或简单词替换
        const simpleWord = this.getSimpleAlternative(word);
        simplified.push(simpleWord);
      } else {
        simplified.push(word);
      }
    }

    return simplified.join(' ');
  }

  /**
   * 获取简单替代词
   */
  private getSimpleAlternative(word: string): string {
    // 简化实现：返回单词本身
    // 实际应用中应该维护一个同义词库
    return word;
  }

  /**
   * 获取未知词汇定义
   */
  async getUnknownWordDefinition(word: string): Promise<WordDefinition | null> {
    // 检查是否在词汇跟踪器中
    const record = this.vocabularyTracker.getRecord(word);
    
    if (record !== null && record.status !== WordStatus.NEW) {
      // 如果词汇已记录且不是新词，返回空
      return null;
    }

    // 返回基本定义
    return new WordDefinition(
      word,
      '',
      '',
      '未知词汇，请添加到学习列表',
      [],
      'local'
    );
  }

  /**
   * 添加到学习队列
   */
  addToLearningQueue(word: string): boolean {
    try {
      // 检查是否已存在
      const record = this.vocabularyTracker.getRecord(word);
      
      if (record === null) {
        // 创建新记录
        const newRecord = new VocabularyRecord(
          word,
          WordStatus.NEW,
          Date.now(),
          0,
          0,
          0,
          0,
          0,
          ['unknown']
        );
        
        this.vocabularyTracker.addOrUpdateRecord(newRecord);
        return true;
      }

      return false;
    } catch (e) {
      console.error('[UnknownWordHandler] Failed to add to learning queue:', e);
      return false;
    }
  }

  /**
   * 批量处理未知词汇
   */
  processUnknownWordsBatch(
    contexts: Array<ContextItem>,
    userLevel: number = 2
  ): Array<HandlingResultItem> {
    const results: Array<HandlingResultItem> = [];

    for (const item of contexts) {
      const unknownWords = this.detectUnknownWords(
        item.context,
        item.knownWords,
        item.targetWord
      );

      for (const word of unknownWords) {
        const wordInfo = this.analyzeUnknownWord(word, item.context);
        const handlingResult = this.determineHandlingStrategy(wordInfo, userLevel);
        
        const resultItem: HandlingResultItem = { word: word, result: handlingResult };
        results.push(resultItem);

        // 根据策略执行操作
        if (handlingResult.shouldAddToNotebook) {
          this.addToLearningQueue(word);
        }
      }
    }

    return results;
  }

  /**
   * 清理旧的未知词汇记录
   */
  private cleanupOldUnknownWords(): void {
    const now = Date.now();
    const maxAge = 30 * 24 * 60 * 60 * 1000; // 30天

    const toDelete: string[] = [];

    this.unknownWords.forEach((info: UnknownWordInfo, word: string) => {
      if (now - info.timestamp > maxAge) {
        toDelete.push(word);
      }
    });

    for (const word of toDelete) {
      this.unknownWords.delete(word);
    }

    console.log(`[UnknownWordHandler] Cleaned up ${toDelete.length} old unknown word records`);
  }

  /**
   * 获取所有未知词汇
   */
  getAllUnknownWords(): UnknownWordInfo[] {
    return Array.from(this.unknownWords.values());
  }

  /**
   * 获取高优先级未知词汇
   */
  getHighPriorityUnknownWords(): UnknownWordInfo[] {
    return this.getAllUnknownWords().filter((info: UnknownWordInfo): boolean => 
      info.priority === Priority.HIGH
    );
  }

  /**
   * 获取未知词汇统计
   */
  getUnknownWordStats(): UnknownWordStats {
    const all = this.getAllUnknownWords();
    const highPriority = all.filter((info: UnknownWordInfo): boolean => 
      info.priority === Priority.HIGH
    ).length;
    const mediumPriority = all.filter((info: UnknownWordInfo): boolean => 
      info.priority === Priority.MEDIUM
    ).length;
    const lowPriority = all.filter((info: UnknownWordInfo): boolean => 
      info.priority === Priority.LOW
    ).length;

    const totalFrequency = all.reduce((sum: number, info: UnknownWordInfo): number => 
      sum + info.frequency, 0
    );
    const avgFrequency = all.length > 0 ? totalFrequency / all.length : 0;

    return {
      totalUnknown: all.length,
      highPriority,
      mediumPriority,
      lowPriority,
      avgFrequency
    };
  }

  /**
   * 导出未知词汇数据
   */
  exportUnknownWords(): string {
    const all = this.getAllUnknownWords();
    const data: ExportedUnknownWord[] = all.map((info: UnknownWordInfo): ExportedUnknownWord => ({
      word: info.word,
      context: info.context,
      timestamp: info.timestamp,
      frequency: info.frequency,
      priority: info.priority,
      status: info.status
    }));
    return JSON.stringify(data);
  }

  /**
   * 导入未知词汇数据
   */
  importUnknownWords(json: string): boolean {
    try {
      const data = JSON.parse(json) as ExportedUnknownWord[];

      for (const item of data) {
        const info = new UnknownWordInfo(
          item.word,
          item.context,
          item.frequency,
          item.priority
        );
        info.timestamp = item.timestamp;
        info.status = item.status;
        
        this.unknownWords.set(item.word.toLowerCase(), info);
      }

      return true;
    } catch (e) {
      console.error('[UnknownWordHandler] Import failed:', e);
      return false;
    }
  }

  /**
   * 清空所有未知词汇
   */
  clearAllUnknownWords(): void {
    this.unknownWords.clear();
  }

  /**
   * 检查词汇是否为未知
   */
  isWordUnknown(word: string): boolean {
    return this.unknownWords.has(word.toLowerCase());
  }

  /**
   * 获取未知词汇数量
   */
  getUnknownWordCount(): number {
    return this.unknownWords.size;
  }

  /**
   * 设置最大未知词汇数量
   */
  setMaxUnknownWords(max: number): void {
    this.maxUnknownWords = max;
  }

  /**
   * 生成学习建议
   */
  generateLearningSuggestions(): string[] {
    const suggestions: string[] = [];
    const stats = this.getUnknownWordStats();

    if (stats.totalUnknown === 0) {
      suggestions.push('当前没有未知词汇');
      return suggestions;
    }

    if (stats.highPriority > 0) {
      suggestions.push(`有 ${stats.highPriority} 个高优先级未知词汇需要学习`);
    }

    if (stats.avgFrequency > 2) {
      suggestions.push('部分未知词汇频繁出现，建议优先学习');
    }

    if (stats.totalUnknown > 20) {
      suggestions.push('未知词汇数量较多，建议集中进行词汇学习');
    }

    return suggestions;
  }

  /**
   * 获取处理建议
   */
  getHandlingRecommendation(word: string, userLevel: number): HandlingResult {
    const wordInfo = this.analyzeUnknownWord(word, '');
    return this.determineHandlingStrategy(wordInfo, userLevel);
  }
}
