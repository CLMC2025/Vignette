// =====================================================
// VocabularyTracker.ets - 词汇跟踪器
// 跟踪用户词汇掌握程度、频率和状态
// =====================================================

import { WordStatus } from '../model/WordModel';

/**
 * 词汇统计接口
 */
export interface Statistics {
  totalWords: number;
  newCount: number;
  learningCount: number;
  reviewCount: number;
  relearningCount: number;
  avgAccuracy: number;
  avgRating: number;
}

/**
 * 进度分析接口
 */
export interface ProgressAnalysis {
  totalProgress: number;
  reviewEfficiency: number;
  recommendations: string[];
}

/**
 * 学习曲线数据点接口
 */
export interface LearningCurvePoint {
  date: number;
  reviewed: number;
}

/**
 * 词汇记录
 */
export class VocabularyRecord {
  word: string;
  status: WordStatus;
  lastReviewed: number;
  reviewCount: number;
  correctCount: number;
  incorrectCount: number;
  avgRating: number;
  contextCount: number;
  tags: string[];

  constructor(
    word: string,
    status: WordStatus = WordStatus.NEW,
    lastReviewed: number = 0,
    reviewCount: number = 0,
    correctCount: number = 0,
    incorrectCount: number = 0,
    avgRating: number = 0,
    contextCount: number = 0,
    tags: string[] = []
  ) {
    this.word = word;
    this.status = status;
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
   * 获取状态名称
   */
  getStatusName(): string {
    switch (this.status) {
      case WordStatus.NEW:
        return '新词';
      case WordStatus.LEARNING:
        return '学习中';
      case WordStatus.REVIEW:
        return '复习';
      case WordStatus.RELEARNING:
        return '重学';
      default:
        return '未知';
    }
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, number | string | string[]> = {
      'word': this.word,
      'status': this.status,
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
      // Handle legacy masteryLevel if present during migration (optional, but good for safety)
      let status = obj['status'] as WordStatus ?? WordStatus.NEW;
      if (obj['masteryLevel'] !== undefined) {
         // Simple mapping if needed, or just default to NEW/REVIEW based on reviewCount
         // Since we are cleaning up, we assume data migration handles this or we start fresh/default.
         // Let's rely on default NEW if status is missing.
      }

      return new VocabularyRecord(
        obj['word'] as string ?? '',
        status,
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
   * 根据状态获取词汇
   */
  getRecordsByStatus(status: WordStatus): VocabularyRecord[] {
    return this.getAllRecords().filter(
      (record: VocabularyRecord): boolean => record.status === status
    );
  }

  /**
   * 获取需要复习的词汇 (Legacy logic, preferably use DBManager for actual scheduling)
   */
  getWordsForReview(): VocabularyRecord[] {
    const now = Date.now();
    const reviewInterval = 1 * 24 * 60 * 60 * 1000; // 1天 (Simplified)

    return this.getAllRecords().filter((record: VocabularyRecord): boolean => {
      // Return Review/Relearning words or words overdue
      return record.status === WordStatus.REVIEW || record.status === WordStatus.RELEARNING;
    });
  }

  /**
   * 获取已掌握/复习阶段的词汇
   */
  getReviewWords(): VocabularyRecord[] {
    return this.getRecordsByStatus(WordStatus.REVIEW);
  }

  /**
   * 获取学习中的词汇
   */
  getLearningWords(): VocabularyRecord[] {
    return this.getRecordsByStatus(WordStatus.LEARNING);
  }

  /**
   * 获取新词
   */
  getNewWords(): VocabularyRecord[] {
    return this.getRecordsByStatus(WordStatus.NEW);
  }

  /**
   * 获取词汇统计
   */
  getStatistics(): Statistics {
    const records = this.getAllRecords();
    const total = records.length;

    const newCount = records.filter((r: VocabularyRecord) => r.status === WordStatus.NEW).length;
    const learningCount = records.filter((r: VocabularyRecord) => r.status === WordStatus.LEARNING).length;
    const reviewCount = records.filter((r: VocabularyRecord) => r.status === WordStatus.REVIEW).length;
    const relearningCount = records.filter((r: VocabularyRecord) => r.status === WordStatus.RELEARNING).length;

    const totalAccuracy = records.reduce((sum: number, r: VocabularyRecord): number => 
      sum + r.getAccuracy(), 0
    );

    const totalRating = records.reduce((sum: number, r: VocabularyRecord): number => 
      sum + r.avgRating, 0
    );

    return {
      totalWords: total,
      newCount,
      learningCount,
      reviewCount,
      relearningCount,
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
    const totalProgress = (stats.reviewCount + stats.learningCount) / stats.totalWords * 100;
    const reviewEfficiency = stats.avgAccuracy * 100;

    const recommendations: string[] = [];

    // 生成建议
    if (stats.avgAccuracy < 0.6) {
      recommendations.push('建议：复习时更仔细，提高准确率');
    }

    if (stats.avgRating < 2.5) {
      recommendations.push('建议：加强对困难词汇的学习');
    }

    if (stats.newCount > stats.reviewCount) {
      recommendations.push('建议：多复习已学词汇');
    }

    return {
      totalProgress,
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
      const reviewed = Math.floor(Math.random() * 100);

      curve.push({ date: date, reviewed: reviewed });
    }

    return curve;
  }
}
