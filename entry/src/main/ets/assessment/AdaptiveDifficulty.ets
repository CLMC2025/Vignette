// =====================================================
// AdaptiveDifficulty.ets - 自适应难度系统
// 根据用户表现动态调整学习难度
// =====================================================

import { DifficultyLevel } from '../context/TemplateManager';
import { Rating } from '../model/WordModel';

/**
 * 难度统计数据接口
 */
export interface DifficultyStatistics {
  currentLevel: DifficultyLevel;
  averagePerformance: number;
  performanceTrend: number;
  adjustmentCount: number;
  lastAdjustment: DifficultyAdjustment | null;
}

/**
 * 表现分析数据接口
 */
export interface PerformanceAnalysis {
  totalRecords: number;
  averageScore: number;
  excellentCount: number;
  goodCount: number;
  averageCount: number;
  poorCount: number;
  averageTimeSpent: number;
  averageAttempts: number;
}

/**
 * 表现数据接口（用于导出）
 */
export interface PerformanceData {
  wordId: number;
  rating: Rating;
  timeSpent: number;
  attempts: number;
  timestamp: number;
  difficulty: DifficultyLevel;
  score: number;
  performanceRating: string;
}

/**
 * 导入的表现数据接口
 */
export interface ImportedPerformanceData {
  wordId: number;
  rating: Rating;
  timeSpent: number;
  attempts: number;
  timestamp: number;
  difficulty: DifficultyLevel;
}

/**
 * 难度调整历史记录项接口
 */
export interface AdjustmentHistoryItem {
  timestamp: number;
  fromLevel: DifficultyLevel;
  toLevel: DifficultyLevel;
  reason: string;
}

/**
 * 表现预测结果接口
 */
export interface PerformancePrediction {
  predictedScore: number;
  confidence: number;
  trend: 'improving' | 'stable' | 'declining';
}

/**
 * 用户表现数据
 */
export class UserPerformance {
  wordId: number;
  rating: Rating;
  timeSpent: number;  // 毫秒
  attempts: number;
  timestamp: number;
  difficulty: DifficultyLevel;

  constructor(
    wordId: number,
    rating: Rating,
    timeSpent: number,
    attempts: number = 1,
    difficulty: DifficultyLevel = DifficultyLevel.CET6
  ) {
    this.wordId = wordId;
    this.rating = rating;
    this.timeSpent = timeSpent;
    this.attempts = attempts;
    this.timestamp = Date.now();
    this.difficulty = difficulty;
  }

  /**
   * 计算表现分数
   */
  getScore(): number {
    // 基础分数（评分越高越好）
    let score = this.rating * 25;

    // 时间因素（时间越短越好）
    const idealTime = 30000; // 30秒
    if (this.timeSpent <= idealTime) {
      score += 25;
    } else {
      const timePenalty = Math.min(25, (this.timeSpent - idealTime) / 60000 * 25);
      score -= timePenalty;
    }

    // 尝试次数因素（次数越少越好）
    const attemptPenalty = (this.attempts - 1) * 10;
    score -= attemptPenalty;

    return Math.max(0, Math.min(100, score));
  }

  /**
   * 获取表现评级
   */
  getPerformanceRating(): string {
    const score = this.getScore();
    if (score >= 90) return '优秀';
    if (score >= 75) return '良好';
    if (score >= 60) return '中等';
    if (score >= 40) return '及格';
    return '需改进';
  }
}

/**
 * 难度调整参数
 */
export class DifficultyAdjustment {
  currentLevel: DifficultyLevel;
  targetLevel: DifficultyLevel;
  adjustmentFactor: number;  // -1到1
  confidence: number;  // 0-100
  reason: string;

  constructor(
    currentLevel: DifficultyLevel,
    targetLevel: DifficultyLevel,
    adjustmentFactor: number = 0,
    confidence: number = 0,
    reason: string = ''
  ) {
    this.currentLevel = currentLevel;
    this.targetLevel = targetLevel;
    this.adjustmentFactor = adjustmentFactor;
    this.confidence = confidence;
    this.reason = reason;
  }

  /**
   * 是否需要调整
   */
  needsAdjustment(): boolean {
    return this.adjustmentFactor !== 0;
  }

  /**
   * 获取调整方向
   */
  getDirection(): 'increase' | 'decrease' | 'maintain' {
    if (this.adjustmentFactor > 0) {
      return 'increase';
    } else if (this.adjustmentFactor < 0) {
      return 'decrease';
    }
    return 'maintain';
  }
}

/**
 * 自适应难度系统
 */
export class AdaptiveDifficulty {
  private static instance: AdaptiveDifficulty | null = null;
  private performanceHistory: UserPerformance[];
  private currentDifficulty: DifficultyLevel = DifficultyLevel.CET6;
  private maxHistorySize: number = 100;
  private adjustmentThreshold: number = 0.3; // 调整阈值
  private minConfidence: number = 0.7; // 最小置信度

  private constructor() {
    this.performanceHistory = [];
  }

  /**
   * 获取单例实例
   */
  static getInstance(): AdaptiveDifficulty {
    if (AdaptiveDifficulty.instance === null) {
      AdaptiveDifficulty.instance = new AdaptiveDifficulty();
    }
    return AdaptiveDifficulty.instance;
  }

  /**
   * 记录用户表现
   */
  recordPerformance(performance: UserPerformance): void {
    this.performanceHistory.push(performance);

    // 限制历史记录大小
    if (this.performanceHistory.length > this.maxHistorySize) {
      this.performanceHistory.shift();
    }

    // 计算是否需要调整难度
    const adjustment = this.calculateDifficultyAdjustment();

    if (adjustment.needsAdjustment() && adjustment.confidence >= this.minConfidence) {
      // 应用难度调整
      this.applyDifficultyAdjustment(adjustment);
    }
  }

  /**
   * 计算难度调整
   */
  private calculateDifficultyAdjustment(): DifficultyAdjustment {
    const recentPerformances = this.getRecentPerformances(20);

    if (recentPerformances.length < 5) {
      // 数据不足，不调整
      return new DifficultyAdjustment(
        this.currentDifficulty,
        this.currentDifficulty,
        0,
        0,
        '数据不足，需要更多表现数据'
      );
    }

    // 计算平均表现分数
    const averageScore = recentPerformances.reduce(
      (sum: number, p: UserPerformance) => sum + p.getScore(),
      0
    ) / recentPerformances.length;

    // 计算表现趋势
    const trend = this.calculatePerformanceTrend(recentPerformances);

    // 计算调整因子
    let adjustmentFactor = 0;
    let targetLevel = this.currentDifficulty;
    let confidence = 0;
    let reason = '';

    // 根据平均分数和趋势决定调整
    if (averageScore >= 85 && trend > 0.1) {
      // 表现优秀且持续改善，增加难度
      adjustmentFactor = 1;
      targetLevel = this.increaseDifficulty(this.currentDifficulty);
      confidence = Math.min(100, 80 + trend * 100);
      reason = '表现优秀且持续改善，增加难度';
    } else if (averageScore >= 70) {
      // 表现良好，维持当前难度
      adjustmentFactor = 0;
      targetLevel = this.currentDifficulty;
      confidence = 70;
      reason = '表现良好，维持当前难度';
    } else if (averageScore >= 50) {
      // 表现中等，根据趋势微调
      if (trend > this.adjustmentThreshold) {
        adjustmentFactor = 0.5;
        targetLevel = this.increaseDifficulty(this.currentDifficulty);
        confidence = 60;
        reason = '表现中等且有改善趋势，适度增加难度';
      } else if (trend < -this.adjustmentThreshold) {
        adjustmentFactor = -0.5;
        targetLevel = this.decreaseDifficulty(this.currentDifficulty);
        confidence = 60;
        reason = '表现中等且有下降趋势，适度降低难度';
      } else {
        adjustmentFactor = 0;
        targetLevel = this.currentDifficulty;
        confidence = 60;
        reason = '表现中等且稳定，维持当前难度';
      }
    } else if (averageScore >= 30) {
      // 表现较差，降低难度
      adjustmentFactor = -1;
      targetLevel = this.decreaseDifficulty(this.currentDifficulty);
      confidence = 50;
      reason = '表现较差，降低难度';
    } else {
      // 表现很差，大幅降低难度
      adjustmentFactor = -1;
      targetLevel = this.decreaseDifficulty(this.currentDifficulty);
      confidence = 40;
      reason = '表现很差，大幅降低难度';
    }

    return new DifficultyAdjustment(
      this.currentDifficulty,
      targetLevel,
      adjustmentFactor,
      confidence,
      reason
    );
  }

  /**
   * 计算表现趋势
   */
  private calculatePerformanceTrend(performances: UserPerformance[]): number {
    if (performances.length < 2) {
      return 0;
    }

    // 计算前半部分和后半部分的平均分数
    const midPoint = Math.floor(performances.length / 2);
    const firstHalf = performances.slice(0, midPoint);
    const secondHalf = performances.slice(midPoint);

    const firstAvg = firstHalf.reduce(
      (sum: number, p: UserPerformance) => sum + p.getScore(),
      0
    ) / firstHalf.length;

    const secondAvg = secondHalf.reduce(
      (sum: number, p: UserPerformance) => sum + p.getScore(),
      0
    ) / secondHalf.length;

    // 计算趋势（正数表示改善，负数表示下降）
    const trend = (secondAvg - firstAvg) / 100;

    return trend;
  }

  /**
   * 增加难度
   */
  private increaseDifficulty(current: DifficultyLevel): DifficultyLevel {
    const levels: DifficultyLevel[] = [
      DifficultyLevel.CET4,
      DifficultyLevel.CET6,
      DifficultyLevel.IELTS,
      DifficultyLevel.TOEFL,
      DifficultyLevel.SAT,
      DifficultyLevel.GRE
    ];
    const currentIndex = levels.indexOf(current);

    if (currentIndex < levels.length - 1) {
      return levels[currentIndex + 1];
    }

    return current;
  }

  /**
   * 降低难度
   */
  private decreaseDifficulty(current: DifficultyLevel): DifficultyLevel {
    const levels: DifficultyLevel[] = [
      DifficultyLevel.CET4,
      DifficultyLevel.CET6,
      DifficultyLevel.IELTS,
      DifficultyLevel.TOEFL,
      DifficultyLevel.SAT,
      DifficultyLevel.GRE
    ];
    const currentIndex = levels.indexOf(current);

    if (currentIndex > 0) {
      return levels[currentIndex - 1];
    }

    return current;
  }

  /**
   * 应用难度调整
   */
  private applyDifficultyAdjustment(adjustment: DifficultyAdjustment): void {
    this.currentDifficulty = adjustment.targetLevel;
    console.log(`[AdaptiveDifficulty] ${adjustment.reason}`);
  }

  /**
   * 获取最近的表现记录
   */
  private getRecentPerformances(count: number): UserPerformance[] {
    return this.performanceHistory.slice(-count);
  }

  /**
   * 获取当前难度
   */
  getCurrentDifficulty(): DifficultyLevel {
    return this.currentDifficulty;
  }

  /**
   * 设置当前难度
   */
  setCurrentDifficulty(difficulty: DifficultyLevel): void {
    this.currentDifficulty = difficulty;
  }

  /**
   * 获取推荐难度
   */
  getRecommendedDifficulty(userLevel: number): DifficultyLevel {
    // 根据用户水平推荐难度
    if (userLevel <= 2) {
      return DifficultyLevel.CET4;
    } else if (userLevel <= 4) {
      return DifficultyLevel.CET6;
    } else if (userLevel <= 6) {
      return DifficultyLevel.IELTS;
    } else if (userLevel <= 8) {
      return DifficultyLevel.TOEFL;
    } else if (userLevel <= 10) {
      return DifficultyLevel.SAT;
    } else {
      return DifficultyLevel.GRE;
    }
  }

  /**
   * 获取难度统计
   */
  getDifficultyStatistics(): DifficultyStatistics {
    const recentPerformances = this.getRecentPerformances(20);
    const averagePerformance = recentPerformances.length > 0
      ? recentPerformances.reduce((sum: number, p: UserPerformance) => sum + p.getScore(), 0) / recentPerformances.length
      : 0;

    const trend = this.calculatePerformanceTrend(recentPerformances);

    // 统计难度调整次数
    const adjustments = this.performanceHistory.filter((p: UserPerformance) => {
      const currentLevel = this.performanceHistory.indexOf(p) > 0
        ? this.performanceHistory[this.performanceHistory.indexOf(p) - 1].difficulty
        : this.currentDifficulty;
      return p.difficulty !== currentLevel;
    }).length;

    const result: DifficultyStatistics = {
      currentLevel: this.currentDifficulty,
      averagePerformance,
      performanceTrend: trend,
      adjustmentCount: adjustments,
      lastAdjustment: this.calculateDifficultyAdjustment()
    };
    return result;
  }

  /**
   * 获取表现分析
   */
  analyzePerformance(): PerformanceAnalysis {
    const total = this.performanceHistory.length;

    if (total === 0) {
      const emptyResult: PerformanceAnalysis = {
        totalRecords: 0,
        averageScore: 0,
        excellentCount: 0,
        goodCount: 0,
        averageCount: 0,
        poorCount: 0,
        averageTimeSpent: 0,
        averageAttempts: 0
      };
      return emptyResult;
    }

    const scores = this.performanceHistory.map((p: UserPerformance) => p.getScore());
    const averageScore = scores.reduce((sum: number, score: number) => sum + score, 0) / total;

    const excellentCount = scores.filter((s: number) => s >= 90).length;
    const goodCount = scores.filter((s: number) => s >= 75 && s < 90).length;
    const averageCount = scores.filter((s: number) => s >= 60 && s < 75).length;
    const poorCount = scores.filter((s: number) => s < 60).length;

    const averageTimeSpent = this.performanceHistory.reduce(
      (sum: number, p: UserPerformance) => sum + p.timeSpent,
      0
    ) / total;

    const averageAttempts = this.performanceHistory.reduce(
      (sum: number, p: UserPerformance) => sum + p.attempts,
      0
    ) / total;

    const result: PerformanceAnalysis = {
      totalRecords: total,
      averageScore,
      excellentCount,
      goodCount,
      averageCount,
      poorCount,
      averageTimeSpent,
      averageAttempts
    };
    return result;
  }

  /**
   * 获取学习建议
   */
  getLearningRecommendations(): string[] {
    const stats = this.analyzePerformance();
    const recommendations: string[] = [];

    if (stats.averageScore < 60) {
      recommendations.push('建议：当前难度可能过高，考虑降低难度');
    } else if (stats.averageScore > 85) {
      recommendations.push('建议：表现优秀，可以尝试更高难度');
    }

    if (stats.averageAttempts > 2) {
      recommendations.push('建议：多次尝试同一单词，建议加强复习');
    }

    if (stats.averageTimeSpent > 60000) {
      recommendations.push('建议：学习时间较长，建议优化学习方法');
    }

    if (stats.poorCount > stats.excellentCount * 2) {
      recommendations.push('建议：需要更多练习，建议增加学习频率');
    }

    return recommendations;
  }

  /**
   * 重置难度
   */
  resetDifficulty(): void {
    this.currentDifficulty = DifficultyLevel.CET6;
    this.performanceHistory = [];
  }

  /**
   * 导出表现数据
   */
  exportPerformanceData(): string {
    const data: PerformanceData[] = this.performanceHistory.map((p: UserPerformance): PerformanceData => ({
      wordId: p.wordId,
      rating: p.rating,
      timeSpent: p.timeSpent,
      attempts: p.attempts,
      timestamp: p.timestamp,
      difficulty: p.difficulty,
      score: p.getScore(),
      performanceRating: p.getPerformanceRating()
    }));

    return JSON.stringify(data);
  }

  /**
   * 导入表现数据
   */
  importPerformanceData(json: string): boolean {
    try {
      const data = JSON.parse(json) as ImportedPerformanceData[];

      for (const item of data) {
        const performance = new UserPerformance(
          item.wordId,
          item.rating,
          item.timeSpent,
          item.attempts,
          item.difficulty
        );
        performance.timestamp = item.timestamp;
        this.performanceHistory.push(performance);
      }

      return true;
    } catch (e) {
      console.error('[AdaptiveDifficulty] Import failed:', e);
      return false;
    }
  }

  /**
   * 获取难度调整历史
   */
  getAdjustmentHistory(limit: number = 10): AdjustmentHistoryItem[] {
    const history: AdjustmentHistoryItem[] = [];

    for (let i = 1; i < this.performanceHistory.length; i++) {
      const prev = this.performanceHistory[i - 1];
      const curr = this.performanceHistory[i];

      if (prev.difficulty !== curr.difficulty) {
        history.push({
          timestamp: curr.timestamp,
          fromLevel: prev.difficulty,
          toLevel: curr.difficulty,
          reason: `难度从 ${prev.difficulty} 调整到 ${curr.difficulty}`
        });
      }
    }

    return history.slice(-limit);
  }

  /**
   * 设置调整阈值
   */
  setAdjustmentThreshold(threshold: number): void {
    this.adjustmentThreshold = Math.max(0, Math.min(1, threshold));
  }

  /**
   * 设置最小置信度
   */
  setMinConfidence(confidence: number): void {
    this.minConfidence = Math.max(0, Math.min(100, confidence));
  }

  /**
   * 获取难度名称
   */
  getDifficultyName(level: DifficultyLevel): string {
    const names = new Map<DifficultyLevel, string>();
    names.set(DifficultyLevel.CET4, '四级');
    names.set(DifficultyLevel.CET6, '六级');
    names.set(DifficultyLevel.IELTS, '雅思');
    names.set(DifficultyLevel.TOEFL, '托福');
    names.set(DifficultyLevel.SAT, 'SAT');
    names.set(DifficultyLevel.GRE, 'GRE');
    return names.get(level) ?? String(level);
  }

  /**
   * 预测未来表现
   */
  predictFuturePerformance(days: number = 7): PerformancePrediction {
    const recentPerformances = this.getRecentPerformances(30);

    if (recentPerformances.length < 5) {
      return {
        predictedScore: 0,
        confidence: 0,
        trend: 'stable'
      };
    }

    // 计算趋势
    const trend = this.calculatePerformanceTrend(recentPerformances);

    // 预测未来分数
    const currentScore = recentPerformances.reduce(
      (sum: number, p: UserPerformance) => sum + p.getScore(),
      0
    ) / recentPerformances.length;

    const predictedScore = Math.max(0, Math.min(100, currentScore + trend * days));

    // 计算置信度（基于数据量和趋势稳定性）
    const confidence = Math.min(100, recentPerformances.length * 3);

    let trendLabel: 'improving' | 'stable' | 'declining' = 'stable';
    if (trend > 0.05) {
      trendLabel = 'improving';
    } else if (trend < -0.05) {
      trendLabel = 'declining';
    }

    return {
      predictedScore,
      confidence,
      trend: trendLabel
    };
  }
}
