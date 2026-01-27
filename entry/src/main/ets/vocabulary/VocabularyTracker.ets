// =====================================================
// VocabularyTracker.ets - 词汇跟踪器
// 跟踪用户词汇掌握程度、频率和状态
// =====================================================

import { WordStatus } from '../model/WordModel';

/**
 * 词汇掌握等级
 */
export enum MasteryLevel {
  UNKNOWN = 0,    // 未知
  FAMILIAR = 1,   // 熟悉
  LEARNING = 2,   // 学习中
  MASTERED = 3,    // 已掌握
  EXPERT = 4       // 专家
}

/**
 * 词汇统计接口
 */
export interface Statistics {
  totalWords: number;
  masteredCount: number;
  learningCount: number;
  familiarCount: number;
  unknownCount: number;
  avgAccuracy: number;
  avgRating: number;
}

/**
 * 进度分析接口
 */
export interface ProgressAnalysis {
  totalProgress: number;
  masteryProgress: number;
  reviewEfficiency: number;
  recommendations: string[];
}

/**
 * 学习曲线数据点接口
 */
export interface LearningCurvePoint {
  date: number;
  mastered: number;
  reviewed: number;
}

/**
 * 词汇记录
 */
export class VocabularyRecord {
  word: string;
  masteryLevel: MasteryLevel;
  lastReviewed: number;
  reviewCount: number;
  correctCount: number;
  incorrectCount: number;
  avgRating: number;
  contextCount: number;
  tags: string[];

  constructor(
    word: string,
    masteryLevel: MasteryLevel = MasteryLevel.UNKNOWN,
    lastReviewed: number = 0,
    reviewCount: number = 0,
    correctCount: number = 0,
    incorrectCount: number = 0,
    avgRating: number = 0,
    contextCount: number = 0,
    tags: string[] = []
  ) {
    this.word = word;
    this.masteryLevel = masteryLevel;
    this.lastReviewed = lastReviewed;
    this.reviewCount = reviewCount;
    this.correctCount = correctCount;
    this.incorrectCount = incorrectCount;
    this.avgRating = avgRating;
    this.contextCount = contextCount;
    this.tags = tags;
  }

  /**
   * 计算准确率
   */
  getAccuracy(): number {
    if (this.correctCount + this.incorrectCount === 0) {
      return 0;
    }
    return this.correctCount / (this.correctCount + this.incorrectCount);
  }

  /**
   * 更新复习记录
   */
  updateReview(rating: number, isCorrect: boolean): void {
    this.lastReviewed = Date.now();
    this.reviewCount++;
    
    if (isCorrect) {
      this.correctCount++;
    } else {
      this.incorrectCount++;
    }

    // 更新平均评分
    this.avgRating = (this.avgRating * (this.reviewCount - 1) + rating) / this.reviewCount;

    // 更新掌握等级
    this.updateMasteryLevel();
  }

  /**
   * 更新掌握等级
   */
  private updateMasteryLevel(): void {
    const accuracy = this.getAccuracy();
    const avgRating = this.avgRating;

    // 根据准确率和平均评分判断掌握等级
    if (this.reviewCount < 3) {
      // 复习次数少于3次，根据评分判断
      if (avgRating >= 3.5) {
        this.masteryLevel = MasteryLevel.FAMILIAR;
      } else if (avgRating >= 2.5) {
        this.masteryLevel = MasteryLevel.LEARNING;
      } else {
        this.masteryLevel = MasteryLevel.UNKNOWN;
      }
    } else {
      // 复习次数>=3次，综合考虑准确率和评分
      if (accuracy >= 0.9 && avgRating >= 3.5) {
        this.masteryLevel = MasteryLevel.EXPERT;
      } else if (accuracy >= 0.8 && avgRating >= 3.0) {
        this.masteryLevel = MasteryLevel.MASTERED;
      } else if (accuracy >= 0.6 && avgRating >= 2.5) {
        this.masteryLevel = MasteryLevel.LEARNING;
      } else if (accuracy >= 0.4 && avgRating >= 2.0) {
        this.masteryLevel = MasteryLevel.FAMILIAR;
      } else {
        this.masteryLevel = MasteryLevel.UNKNOWN;
      }
    }
  }

  /**
   * 添加标签
   */
  addTag(tag: string): void {
    if (!this.tags.includes(tag)) {
      this.tags.push(tag);
    }
  }

  /**
   * 移除标签
   */
  removeTag(tag: string): void {
    const index = this.tags.indexOf(tag);
    if (index >= 0) {
      this.tags.splice(index, 1);
    }
  }

  /**
   * 获取掌握等级名称
   */
  getMasteryLevelName(): string {
    if (this.masteryLevel === MasteryLevel.UNKNOWN) {
      return '未知';
    } else if (this.masteryLevel === MasteryLevel.FAMILIAR) {
      return '熟悉';
    } else if (this.masteryLevel === MasteryLevel.LEARNING) {
      return '学习中';
    } else if (this.masteryLevel === MasteryLevel.MASTERED) {
      return '已掌握';
    } else if (this.masteryLevel === MasteryLevel.EXPERT) {
      return '专家';
    }
    return '未知';
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, number | string | string[]> = {
      'word': this.word,
      'masteryLevel': this.masteryLevel,
      'lastReviewed': this.lastReviewed,
      'reviewCount': this.reviewCount,
      'correctCount': this.correctCount,
      'incorrectCount': this.incorrectCount,
      'avgRating': this.avgRating,
      'contextCount': this.contextCount,
      'tags': this.tags
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): VocabularyRecord {
    try {
      const obj = JSON.parse(json) as Record<string, number | string | string[]>;
      return new VocabularyRecord(
        obj['word'] as string ?? '',
        obj['masteryLevel'] as MasteryLevel ?? MasteryLevel.UNKNOWN,
        obj['lastReviewed'] as number ?? 0,
        obj['reviewCount'] as number ?? 0,
        obj['correctCount'] as number ?? 0,
        obj['incorrectCount'] as number ?? 0,
        obj['avgRating'] as number ?? 0,
        obj['contextCount'] as number ?? 0,
        obj['tags'] as string[] ?? []
      );
    } catch (e) {
      return new VocabularyRecord('');
    }
  }
}

/**
 * 词汇跟踪器
 */
export class VocabularyTracker {
  private static instance: VocabularyTracker | null = null;
  private vocabulary: Map<string, VocabularyRecord>;

  private constructor() {
    this.vocabulary = new Map();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): VocabularyTracker {
    if (VocabularyTracker.instance === null) {
      VocabularyTracker.instance = new VocabularyTracker();
    }
    return VocabularyTracker.instance;
  }

  /**
   * 获取词汇记录
   */
  getRecord(word: string): VocabularyRecord | null {
    const lowerWord = word.toLowerCase();
    return this.vocabulary.get(lowerWord) ?? null;
  }

  /**
   * 添加或更新词汇记录
   */
  addOrUpdateRecord(record: VocabularyRecord): void {
    const lowerWord = record.word.toLowerCase();
    this.vocabulary.set(lowerWord, record);
  }

  /**
   * 记录复习
   */
  recordReview(word: string, rating: number, isCorrect: boolean): void {
    const record = this.getRecord(word);
    if (record === null) {
      // 创建新记录
      const newRecord = new VocabularyRecord(word);
      newRecord.updateReview(rating, isCorrect);
      this.addOrUpdateRecord(newRecord);
    } else {
      // 更新现有记录
      record.updateReview(rating, isCorrect);
    }
  }

  /**
   * 增加上下文计数
   */
  incrementContextCount(word: string): void {
    const record = this.getRecord(word);
    if (record !== null) {
      record.contextCount++;
    }
  }

  /**
   * 获取所有词汇记录
   */
  getAllRecords(): VocabularyRecord[] {
    return Array.from(this.vocabulary.values());
  }

  /**
   * 根据掌握等级获取词汇
   */
  getRecordsByMastery(level: MasteryLevel): VocabularyRecord[] {
    return this.getAllRecords().filter(
      (record: VocabularyRecord): boolean => record.masteryLevel === level
    );
  }

  /**
   * 获取需要复习的词汇
   */
  getWordsForReview(): VocabularyRecord[] {
    const now = Date.now();
    const reviewInterval = 7 * 24 * 60 * 60 * 1000; // 7天

    return this.getAllRecords().filter((record: VocabularyRecord): boolean => {
      // 掌握等级低于已掌握
      if (record.masteryLevel < MasteryLevel.MASTERED) {
        return true;
      }

      // 或者超过复习间隔
      return (now - record.lastReviewed) > reviewInterval;
    });
  }

  /**
   * 获取已掌握的词汇
   */
  getMasteredWords(): VocabularyRecord[] {
    return this.getRecordsByMastery(MasteryLevel.MASTERED);
  }

  /**
   * 获取学习中的词汇
   */
  getLearningWords(): VocabularyRecord[] {
    return this.getRecordsByMastery(MasteryLevel.LEARNING);
  }

  /**
   * 获取熟悉但未掌握的词汇
   */
  getFamiliarWords(): VocabularyRecord[] {
    return this.getRecordsByMastery(MasteryLevel.FAMILIAR);
  }

  /**
   * 获取未知的词汇
   */
  getUnknownWords(): VocabularyRecord[] {
    return this.getRecordsByMastery(MasteryLevel.UNKNOWN);
  }

  /**
   * 获取词汇统计
   */
  getStatistics(): Statistics {
    const records = this.getAllRecords();
    const total = records.length;

    const mastered = records.filter((r: VocabularyRecord): boolean => 
      r.masteryLevel === MasteryLevel.MASTERED || r.masteryLevel === MasteryLevel.EXPERT
    ).length;

    const learning = records.filter((r: VocabularyRecord): boolean => 
      r.masteryLevel === MasteryLevel.LEARNING
    ).length;

    const familiar = records.filter((r: VocabularyRecord): boolean => 
      r.masteryLevel === MasteryLevel.FAMILIAR
    ).length;

    const unknown = records.filter((r: VocabularyRecord): boolean => 
      r.masteryLevel === MasteryLevel.UNKNOWN
    ).length;

    const totalAccuracy = records.reduce((sum: number, r: VocabularyRecord): number => 
      sum + r.getAccuracy(), 0
    );

    const totalRating = records.reduce((sum: number, r: VocabularyRecord): number => 
      sum + r.avgRating, 0
    );

    return {
      totalWords: total,
      masteredCount: mastered,
      learningCount: learning,
      familiarCount: familiar,
      unknownCount: unknown,
      avgAccuracy: total > 0 ? totalAccuracy / total : 0,
      avgRating: total > 0 ? totalRating / total : 0
    };
  }

  /**
   * 获取词汇频率统计
   */
  getFrequencyStats(): Map<string, number> {
    const frequency = new Map<string, number>();

    this.vocabulary.forEach((record: VocabularyRecord) => {
      const count = record.contextCount;
      frequency.set(record.word, count);
    });

    return frequency;
  }

  /**
   * 获取高频词汇
   */
  getHighFrequencyWords(threshold: number = 5): string[] {
    const stats = this.getFrequencyStats();
    const highFreq: string[] = [];

    stats.forEach((count: number, word: string) => {
      if (count >= threshold) {
        highFreq.push(word);
      }
    });

    return highFreq.sort((a: string, b: string): number => {
      const countA = stats.get(a) ?? 0;
      const countB = stats.get(b) ?? 0;
      return countB - countA;
    });
  }

  /**
   * 搜索词汇
   */
  searchWords(prefix: string): VocabularyRecord[] {
    const lowerPrefix = prefix.toLowerCase();
    const results: VocabularyRecord[] = [];

    this.vocabulary.forEach((record: VocabularyRecord, word: string) => {
      if (word.startsWith(lowerPrefix)) {
        results.push(record);
      }
    });

    return results;
  }

  /**
   * 根据标签获取词汇
   */
  getWordsByTag(tag: string): VocabularyRecord[] {
    return this.getAllRecords().filter((record: VocabularyRecord): boolean => 
      record.tags.includes(tag)
    );
  }

  /**
   * 导出词汇数据
   */
  exportData(): string {
    const records = this.getAllRecords();
    const data = records.map((record: VocabularyRecord) => record.toJSON());
    return JSON.stringify(data);
  }

  /**
   * 导入词汇数据
   */
  importData(json: string): boolean {
    try {
      const data = JSON.parse(json) as string[];
      const records = data.map((item: string): VocabularyRecord => 
        VocabularyRecord.fromJSON(item)
      );

      for (const record of records) {
        this.addOrUpdateRecord(record);
      }

      return true;
    } catch (e) {
      console.error('[VocabularyTracker] Import failed:', e);
      return false;
    }
  }

  /**
   * 清空词汇数据
   */
  clearAll(): void {
    this.vocabulary.clear();
  }

  /**
   * 获取数据库大小
   */
  getDatabaseSize(): number {
    return this.vocabulary.size;
  }

  /**
   * 分析学习进度
   */
  analyzeProgress(): ProgressAnalysis {
    const stats = this.getStatistics();
    const totalProgress = (stats.masteredCount + stats.learningCount) / stats.totalWords * 100;
    const masteryProgress = stats.masteredCount / stats.totalWords * 100;
    const reviewEfficiency = stats.avgAccuracy * 100;

    const recommendations: string[] = [];

    // 生成建议
    if (stats.avgAccuracy < 0.6) {
      recommendations.push('建议：复习时更仔细，提高准确率');
    }

    if (stats.avgRating < 2.5) {
      recommendations.push('建议：加强对困难词汇的学习');
    }

    if (stats.unknownCount > stats.masteredCount) {
      recommendations.push('建议：多复习未知词汇');
    }

    return {
      totalProgress,
      masteryProgress,
      reviewEfficiency,
      recommendations
    };
  }

  /**
   * 获取学习曲线数据
   */
  getLearningCurve(days: number = 30): LearningCurvePoint[] {
    const curve: LearningCurvePoint[] = [];
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;

    for (let i = 0; i < days; i++) {
      const date = now - (days - i - 1) * dayMs;
      
      // 模拟数据（实际应从历史记录获取）
      const mastered = Math.floor(Math.random() * 50);
      const reviewed = Math.floor(Math.random() * 100);

      curve.push({ date: date, mastered: mastered, reviewed: reviewed });
    }

    return curve;
  }

  /**
   * 获取词汇分布
   */
  getMasteryDistribution(): Map<MasteryLevel, number> {
    const distribution = new Map<MasteryLevel, number>();
    
    const levels: MasteryLevel[] = [
      MasteryLevel.UNKNOWN,
      MasteryLevel.FAMILIAR,
      MasteryLevel.LEARNING,
      MasteryLevel.MASTERED,
      MasteryLevel.EXPERT
    ];

    for (const level of levels) {
      distribution.set(level, 0);
    }

    this.vocabulary.forEach((record: VocabularyRecord) => {
      const current = distribution.get(record.masteryLevel) ?? 0;
      distribution.set(record.masteryLevel, current + 1);
    });

    return distribution;
  }
}
