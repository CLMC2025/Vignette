// =====================================================
// SnowballSystem.ets - 滚雪球式记忆系统
// 将之前学习过的词汇有机融入新的微语境中
// =====================================================

import { VocabularyTracker, VocabularyRecord } from './VocabularyTracker';
import { WordStatus } from '../model/WordModel';
import { TemplateManager, ContextStyle, DifficultyLevel, TemplateParams } from '../context/TemplateManager';
import { OfflineContextGenerator, GenerationResult } from '../context/OfflineContext';

/**
 * 词汇关联类型
 */
export enum AssociationType {
  SEMANTIC = 'semantic',       // 语义关联
  SYNONYM = 'synonym',         // 同义词
  ANTONYM = 'antonym',         // 反义词
  CONTEXTUAL = 'contextual',     // 语境关联
  THEMATIC = 'thematic'         // 主题关联
}

/**
 * 词汇关联
 */
export class WordAssociation {
  word: string;
  associatedWord: string;
  associationType: AssociationType;
  strength: number;  // 关联强度 0-1
  timestamp: number;

  constructor(
    word: string,
    associatedWord: string,
    associationType: AssociationType,
    strength: number = 0.5,
    timestamp: number = Date.now()
  ) {
    this.word = word;
    this.associatedWord = associatedWord;
    this.associationType = associationType;
    this.strength = strength;
    this.timestamp = timestamp;
  }
}

/**
 * 滚雪球语境生成参数
 */
export class SnowballParams {
  targetWord: string;
  supportWords: string[];
  style: ContextStyle;
  difficulty: DifficultyLevel;
  associationStrength: number;  // 关联强度 0-1
  maxSupportWords: number;

  constructor(
    targetWord: string,
    supportWords: string[] = [],
    style: ContextStyle = ContextStyle.CONVERSATIONAL,
    difficulty: DifficultyLevel = DifficultyLevel.CET6,
    associationStrength: number = 0.7,
    maxSupportWords: number = 3
  ) {
    this.targetWord = targetWord;
    this.supportWords = supportWords;
    this.style = style;
    this.difficulty = difficulty;
    this.associationStrength = associationStrength;
    this.maxSupportWords = maxSupportWords;
  }
}

/**
 * 滚雪球生成结果
 */
export class SnowballResult {
  success: boolean;
  context: string;
  supportWords: string[];
  associations: WordAssociation[];
  error: string;

  constructor(
    success: boolean = false,
    context: string = '',
    supportWords: string[] = [],
    associations: WordAssociation[] = [],
    error: string = ''
  ) {
    this.success = success;
    this.context = context;
    this.supportWords = supportWords;
    this.associations = associations;
    this.error = error;
  }
}

/**
 * 评分结果接口
 */
export interface ScoredResult {
  result: SnowballResult;
  score: number;
}

/**
 * 滚雪球统计接口
 */
export interface SnowballStats {
  totalAssociations: number;
  averageStrength: number;
  associationTypes: Map<AssociationType, number>;
  topAssociatedWords: string[];
}

/**
 * 导出关联数据接口
 */
export interface ExportedAssociation {
  word: string;
  associatedWord: string;
  associationType: AssociationType;
  strength: number;
  timestamp: number;
}

/**
 * 导入关联数据接口
 */
export interface ImportedAssociation {
  word: string;
  associatedWord: string;
  associationType: AssociationType;
  strength: number;
  timestamp: number;
}

/**
 * 学习网络分析接口
 */
export interface LearningNetworkAnalysis {
  networkSize: number;
  averageConnections: number;
  strongConnections: number;
  weakConnections: number;
  isolatedWords: string[];
}

/**
 * 滚雪球进度接口
 */
export interface SnowballProgress {
  totalWords: number;
  connectedWords: number;
  averageConnections: number;
  progress: number;
}

/**
 * 滚雪球系统
 */
export class SnowballSystem {
  private static instance: SnowballSystem | null = null;
  private vocabularyTracker: VocabularyTracker;
  private templateManager: TemplateManager;
  private offlineGenerator: OfflineContextGenerator;
  private associations: Map<string, WordAssociation[]>;

  private constructor() {
    this.vocabularyTracker = VocabularyTracker.getInstance();
    this.templateManager = TemplateManager.getInstance();
    this.offlineGenerator = OfflineContextGenerator.getInstance();
    this.associations = new Map();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): SnowballSystem {
    if (SnowballSystem.instance === null) {
      SnowballSystem.instance = new SnowballSystem();
    }
    return SnowballSystem.instance;
  }

  /**
   * 生成滚雪球语境
   */
  async generateSnowballContext(params: SnowballParams): Promise<SnowballResult> {
    try {
      // 1. 选择支持词汇
      const supportWords = await this.selectSupportWords(
        params.targetWord,
        params.associationStrength,
        params.maxSupportWords
      );

      if (supportWords.length === 0) {
        return new SnowballResult(false, '', [], [], '没有可用的支持词汇');
      }

      // 2. 生成语境
      const generationResult = this.offlineGenerator.generateContext(
        params.targetWord,
        supportWords,
        params.style,
        params.difficulty
      );

      if (!generationResult.success) {
        return new SnowballResult(false, '', [], [], generationResult.error);
      }

      // 3. 创建词汇关联
      const associations = this.createAssociations(
        params.targetWord,
        supportWords,
        params.associationStrength
      );

      return new SnowballResult(
        true,
        generationResult.context,
        supportWords,
        associations,
        ''
      );
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[SnowballSystem] Generation failed:', errMsg);
      return new SnowballResult(false, '', [], [], `生成失败: ${errMsg}`);
    }
  }

  /**
   * 选择支持词汇
   */
  private async selectSupportWords(
    targetWord: string,
    associationStrength: number,
    maxCount: number
  ): Promise<string[]> {
    // 获取已掌握的词汇 (Review/Relearning)
    const reviewWords = this.vocabularyTracker.getReviewWords();
    const learningWords = this.vocabularyTracker.getLearningWords();

    // 合并所有可用词汇
    const availableWords = [...reviewWords, ...learningWords];
    
    // 过滤掉目标词汇
    const filteredWords = availableWords.filter((record: VocabularyRecord): boolean => 
      record.word.toLowerCase() !== targetWord.toLowerCase()
    );

    // 根据状态优先级排序（复习阶段优先）
    filteredWords.sort((a: VocabularyRecord, b: VocabularyRecord): number => {
      const levelA = this.getStatusPriority(a.status);
      const levelB = this.getStatusPriority(b.status);
      return levelB - levelA;
    });

    // 根据关联强度选择词汇数量
    const count = Math.min(maxCount, Math.floor(filteredWords.length * associationStrength));

    // 提取词汇
    const selectedWords: string[] = [];
    for (let i = 0; i < count && i < filteredWords.length; i++) {
      selectedWords.push(filteredWords[i].word);
    }

    return selectedWords;
  }

  /**
   * 获取状态优先级
   */
  private getStatusPriority(status: WordStatus): number {
    switch (status) {
      case WordStatus.NEW:
        return 0;
      case WordStatus.LEARNING:
        return 1;
      case WordStatus.RELEARNING:
        return 2;
      case WordStatus.REVIEW:
        return 3;
      case WordStatus.KNOWN:
        return 4;
      default:
        return 0;
    }
  }

  /**
   * 创建词汇关联
   */
  private createAssociations(
    targetWord: string,
    supportWords: string[],
    strength: number
  ): WordAssociation[] {
    const associations: WordAssociation[] = [];

    for (const supportWord of supportWords) {
      // 根据词汇关系确定关联类型
      const associationType = this.determineAssociationType(targetWord, supportWord);
      
      const association = new WordAssociation(
        targetWord,
        supportWord,
        associationType,
        strength
      );

      associations.push(association);

      // 保存关联
      this.saveAssociation(association);
    }

    return associations;
  }

  /**
   * 确定关联类型
   */
  private determineAssociationType(word1: string, word2: string): AssociationType {
    // 简化实现：基于词首字母和长度
    const w1 = word1.toLowerCase();
    const w2 = word2.toLowerCase();

    // 相同词性关联
    if (w1.length === w2.length && Math.abs(w1.charCodeAt(0) - w2.charCodeAt(0)) < 5) {
      return AssociationType.SEMANTIC;
    }

    // 长度差异关联
    if (Math.abs(w1.length - w2.length) <= 2) {
      return AssociationType.CONTEXTUAL;
    }

    // 默认语义关联
    return AssociationType.SEMANTIC;
  }

  /**
   * 保存词汇关联
   */
  private saveAssociation(association: WordAssociation): void {
    const key = `${association.word}_${association.associatedWord}`;
    
    if (!this.associations.has(key)) {
      this.associations.set(key, []);
    }

    const existing = this.associations.get(key);
    if (existing !== undefined) {
      existing.push(association);
    }
  }

  /**
   * 获取词汇关联
   */
  getAssociations(word: string): WordAssociation[] {
    const associations: WordAssociation[] = [];

    this.associations.forEach((assocList: WordAssociation[], key: string) => {
      if (key.startsWith(word.toLowerCase())) {
        associations.push(...assocList);
      }
    });

    return associations;
  }

  /**
   * 生成多个滚雪球语境
   */
  async generateMultipleSnowballContexts(
    targetWord: string,
    count: number = 3,
    style: ContextStyle = ContextStyle.CONVERSATIONAL,
    difficulty: DifficultyLevel = DifficultyLevel.CET6
  ): Promise<SnowballResult[]> {
    const results: SnowballResult[] = [];

    for (let i = 0; i < count; i++) {
      const params = new SnowballParams(
        targetWord,
        [],
        style,
        difficulty,
        0.5 + (i * 0.1), // 逐渐增加关联强度
        2 + i // 逐渐增加支持词汇数量
      );

      const result = await this.generateSnowballContext(params);
      results.push(result);
    }

    return results;
  }

  /**
   * 获取最佳滚雪球语境
   */
  getBestSnowballContext(results: SnowballResult[]): SnowballResult | null {
    if (results.length === 0) {
      return null;
    }

    // 根据支持词汇数量和关联强度评分
    const scored: ScoredResult[] = results.map((result: SnowballResult): ScoredResult => {
      const score: number = result.supportWords.length * 10 + 
               result.associations.reduce((sum: number, assoc: WordAssociation) => 
                 sum + assoc.strength, 0);
      return {
        result: result,
        score: score
      };
    });

    scored.sort((a, b) => b.score - a.score);

    return scored[0].result;
  }

  /**
   * 获取滚雪球统计
   */
  getSnowballStats(): SnowballStats {
    const allAssociations: WordAssociation[] = [];

    this.associations.forEach((assocList: WordAssociation[]) => {
      allAssociations.push(...assocList);
    });

    const total = allAssociations.length;
    const averageStrength = total > 0 
      ? allAssociations.reduce((sum: number, assoc: WordAssociation) => sum + assoc.strength, 0) / total 
      : 0;

    const typeCounts = new Map<AssociationType, number>();
    const wordCounts = new Map<string, number>();

    for (const assoc of allAssociations) {
      // 统计关联类型
      const currentCount = typeCounts.get(assoc.associationType) ?? 0;
      typeCounts.set(assoc.associationType, currentCount + 1);

      // 统计被关联词汇频率
      const currentWordCount = wordCounts.get(assoc.associatedWord) ?? 0;
      wordCounts.set(assoc.associatedWord, currentWordCount + 1);
    }

    // 获取高频被关联词汇
    const topWords = Array.from(wordCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map((entry) => entry[0]);

    return {
      totalAssociations: total,
      averageStrength,
      associationTypes: typeCounts,
      topAssociatedWords: topWords
    };
  }

  /**
   * 清空所有关联
   */
  clearAllAssociations(): void {
    this.associations.clear();
  }

  /**
   * 导出关联数据
   */
  exportAssociations(): string {
    const allAssociations: WordAssociation[] = [];

    this.associations.forEach((assocList: WordAssociation[]) => {
      allAssociations.push(...assocList);
    });

    const data: ExportedAssociation[] = allAssociations.map((assoc: WordAssociation): ExportedAssociation => {
      return {
        word: assoc.word,
        associatedWord: assoc.associatedWord,
        associationType: assoc.associationType,
        strength: assoc.strength,
        timestamp: assoc.timestamp
      };
    });

    return JSON.stringify(data);
  }

  /**
   * 导入关联数据
   */
  importAssociations(json: string): boolean {
    try {
      const data = JSON.parse(json) as ImportedAssociation[];

      for (const item of data) {
        const association = new WordAssociation(
          item.word,
          item.associatedWord,
          item.associationType,
          item.strength,
          item.timestamp
        );

        const key = `${association.word}_${association.associatedWord}`;
        
        if (!this.associations.has(key)) {
          this.associations.set(key, []);
        }

        const existing = this.associations.get(key);
        if (existing !== undefined) {
          existing.push(association);
        }
      }

      return true;
    } catch (e) {
      console.error('[SnowballSystem] Import failed:', e);
      return false;
    }
  }

  /**
   * 获取推荐的支持词汇
   */
  getRecommendedSupportWords(
    targetWord: string,
    count: number = 3,
    minStatus: WordStatus = WordStatus.LEARNING
  ): string[] {
    const reviewWords = this.vocabularyTracker.getReviewWords();
    const learningWords = this.vocabularyTracker.getLearningWords();

    // 过滤满足最低状态优先级的词汇
    const qualifiedWords = [
      ...reviewWords,
      ...learningWords
    ].filter((record: VocabularyRecord): boolean => {
      const levelValue = this.getStatusPriority(record.status);
      const minValue = this.getStatusPriority(minStatus);
      return levelValue >= minValue;
    });

    // 排序并选择
    qualifiedWords.sort((a: VocabularyRecord, b: VocabularyRecord): number => {
      const levelA = this.getStatusPriority(a.status);
      const levelB = this.getStatusPriority(b.status);
      return levelB - levelA;
    });

    return qualifiedWords.slice(0, Math.min(count, qualifiedWords.length))
      .map((record: VocabularyRecord) => record.word);
  }

  /**
   * 分析学习网络
   */
  analyzeLearningNetwork(): LearningNetworkAnalysis {
    const allAssociations: WordAssociation[] = [];
    const wordConnections = new Map<string, number>();

    this.associations.forEach((assocList: WordAssociation[]) => {
      allAssociations.push(...assocList);
    });

    // 统计每个词汇的连接数
    for (const assoc of allAssociations) {
      const count = wordConnections.get(assoc.word) ?? 0;
      wordConnections.set(assoc.word, count + 1);
    }

    // 计算统计信息
    const networkSize = wordConnections.size;
    const totalConnections = Array.from(wordConnections.values())
      .reduce((sum: number, count: number) => sum + count, 0);
    const averageConnections = networkSize > 0 ? totalConnections / networkSize : 0;

    const strongConnections = allAssociations.filter((assoc: WordAssociation): boolean => 
      assoc.strength >= 0.7
    ).length;

    const weakConnections = allAssociations.filter((assoc: WordAssociation): boolean => 
      assoc.strength < 0.3
    ).length;

    // 找出孤立词汇（连接数<=1）
    const isolatedWords: string[] = [];
    wordConnections.forEach((count: number, word: string) => {
      if (count <= 1) {
        isolatedWords.push(word);
      }
    });

    return {
      networkSize,
      averageConnections,
      strongConnections,
      weakConnections,
      isolatedWords
    };
  }

  /**
   * 获取学习建议
   */
  getLearningRecommendations(): string[] {
    const networkStats = this.analyzeLearningNetwork();
    const recommendations: string[] = [];

    if (networkStats.weakConnections > networkStats.strongConnections) {
      recommendations.push('建议：加强已学词汇的复习，建立更强的关联');
    }

    if (networkStats.isolatedWords.length > networkStats.networkSize * 0.2) {
      recommendations.push('建议：关注孤立词汇，通过滚雪球系统建立连接');
    }

    if (networkStats.averageConnections < 2) {
      recommendations.push('建议：增加支持词汇数量，丰富学习网络');
    }

    if (recommendations.length === 0) {
      recommendations.push('学习网络状况良好，继续保持');
    }

    return recommendations;
  }

  /**
   * 获取滚雪球进度
   */
  getSnowballProgress(): SnowballProgress {
    const stats = this.analyzeLearningNetwork();
    const connectedWords = stats.networkSize - stats.isolatedWords.length;
    const progress = stats.networkSize > 0 
      ? (connectedWords / stats.networkSize) * 100 
      : 0;

    return {
      totalWords: stats.networkSize,
      connectedWords,
      averageConnections: stats.averageConnections,
      progress
    };
  }
}
