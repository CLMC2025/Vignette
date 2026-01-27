// =====================================================
// UserAssessment.ets - 用户评估模型
// 管理用户水平评估和动态评估
// =====================================================

import { LevelDetector, LevelDetectionResult, TestResult, TestType } from './LevelDetector';
import { DifficultyLevel } from '../context/TemplateManager';

interface AssessmentRecordData {
  id: string;
  timestamp: number;
  overallLevel: number;
  vocabularyLevel: number;
  readingLevel: number;
  grammarLevel: number;
  estimatedVocabSize: number;
  confidence: number;
}

interface LearningProgressData {
  totalWordsLearned: number;
  wordsMastered: number;
  wordsInReview: number;
  totalStudyTime: number;
  averageSessionLength: number;
  streakDays: number;
  lastStudyDate: number;
}

interface LearningTrendsData {
  levelTrend: 'improving' | 'stable' | 'declining';
  progressRate: number;
  estimatedTimeToNextLevel: number;
}

interface ImportedAssessmentData {
  currentLevel: number;
  learningProgress: string;
  assessmentHistory: string[];
}

interface AssessmentStatisticsData {
  totalAssessments: number;
  averageLevel: number;
  highestLevel: number;
  lowestLevel: number;
  averageConfidence: number;
}

interface LearningGoalsData {
  nextLevel: number;
  wordsToNextLevel: number;
  estimatedDays: number;
}

/**
 * 评估记录
 */
export class AssessmentRecord {
  id: string;
  timestamp: number;
  overallLevel: number;
  vocabularyLevel: number;
  readingLevel: number;
  grammarLevel: number;
  estimatedVocabSize: number;
  confidence: number;

  constructor(
    id: string,
    timestamp: number,
    overallLevel: number,
    vocabularyLevel: number,
    readingLevel: number,
    grammarLevel: number,
    estimatedVocabSize: number,
    confidence: number
  ) {
    this.id = id;
    this.timestamp = timestamp;
    this.overallLevel = overallLevel;
    this.vocabularyLevel = vocabularyLevel;
    this.readingLevel = readingLevel;
    this.grammarLevel = grammarLevel;
    this.estimatedVocabSize = estimatedVocabSize;
    this.confidence = confidence;
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: AssessmentRecordData = {
      id: this.id,
      timestamp: this.timestamp,
      overallLevel: this.overallLevel,
      vocabularyLevel: this.vocabularyLevel,
      readingLevel: this.readingLevel,
      grammarLevel: this.grammarLevel,
      estimatedVocabSize: this.estimatedVocabSize,
      confidence: this.confidence
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): AssessmentRecord {
    try {
      const obj = JSON.parse(json) as AssessmentRecordData;
      return new AssessmentRecord(
        String(obj.id ?? ''),
        Number(obj.timestamp ?? Date.now()),
        Number(obj.overallLevel ?? 0),
        Number(obj.vocabularyLevel ?? 0),
        Number(obj.readingLevel ?? 0),
        Number(obj.grammarLevel ?? 0),
        Number(obj.estimatedVocabSize ?? 0),
        Number(obj.confidence ?? 0)
      );
    } catch (e) {
      return new AssessmentRecord('', Date.now(), 0, 0, 0, 0, 0, 0);
    }
  }
}

/**
 * 学习进度
 */
export class LearningProgress {
  totalWordsLearned: number;
  wordsMastered: number;
  wordsInReview: number;
  totalStudyTime: number;  // 毫秒
  averageSessionLength: number;  // 分钟
  streakDays: number;
  lastStudyDate: number;

  constructor() {
    this.totalWordsLearned = 0;
    this.wordsMastered = 0;
    this.wordsInReview = 0;
    this.totalStudyTime = 0;
    this.averageSessionLength = 0;
    this.streakDays = 0;
    this.lastStudyDate = 0;
  }

  /**
   * 计算掌握率
   */
  getMasteryRate(): number {
    if (this.totalWordsLearned === 0) {
      return 0;
    }
    return (this.wordsMastered / this.totalWordsLearned) * 100;
  }

  /**
   * 计算学习效率
   */
  getEfficiency(): number {
    if (this.totalStudyTime === 0) {
      return 0;
    }
    // 每小时学习的单词数
    return (this.totalWordsLearned / (this.totalStudyTime / 3600000)) * 100;
  }

  /**
   * 更新学习进度
   */
  updateProgress(
    wordsLearned: number,
    wordsMastered: number,
    wordsInReview: number,
    studyTime: number
  ): void {
    this.totalWordsLearned = wordsLearned;
    this.wordsMastered = wordsMastered;
    this.wordsInReview = wordsInReview;
    this.totalStudyTime += studyTime;
    this.lastStudyDate = Date.now();

    // 更新平均学习时长
    const sessionCount = this.getSessionCount();
    this.averageSessionLength = sessionCount > 0 
      ? (this.totalStudyTime / sessionCount) / 60000 // 转换为分钟
      : 0;
  }

  /**
   * 更新连续学习天数
   */
  updateStreak(currentDate: number): void {
    const oneDay = 24 * 60 * 60 * 1000;
    
    if (this.lastStudyDate > 0 && currentDate - this.lastStudyDate < oneDay * 2) {
      // 连续学习
      this.streakDays++;
    } else {
      // 中断或首次
      this.streakDays = 1;
    }
    this.lastStudyDate = currentDate;
  }

  /**
   * 获取学习会话次数
   */
  private getSessionCount(): number {
    // 简化实现：根据总学习时间和平均时长估算
    if (this.averageSessionLength === 0) {
      return 1;
    }
    return Math.floor(this.totalStudyTime / (this.averageSessionLength * 60000));
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: LearningProgressData = {
      totalWordsLearned: this.totalWordsLearned,
      wordsMastered: this.wordsMastered,
      wordsInReview: this.wordsInReview,
      totalStudyTime: this.totalStudyTime,
      averageSessionLength: this.averageSessionLength,
      streakDays: this.streakDays,
      lastStudyDate: this.lastStudyDate
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): LearningProgress {
    try {
      const obj = JSON.parse(json) as LearningProgressData;
      const progress = new LearningProgress();
      progress.totalWordsLearned = obj.totalWordsLearned ?? 0;
      progress.wordsMastered = obj.wordsMastered ?? 0;
      progress.wordsInReview = obj.wordsInReview ?? 0;
      progress.totalStudyTime = obj.totalStudyTime ?? 0;
      progress.averageSessionLength = obj.averageSessionLength ?? 0;
      progress.streakDays = obj.streakDays ?? 0;
      progress.lastStudyDate = obj.lastStudyDate ?? 0;
      return progress;
    } catch (e) {
      return new LearningProgress();
    }
  }
}

/**
 * 用户评估
 */
interface GeneratedObjectLiteralInterface_1 {
  currentLevel: number;
  learningProgress: string;
  assessmentHistory: string[];
}

export class UserAssessment {
  private static instance: UserAssessment | null = null;
  private levelDetector: LevelDetector;
  private assessmentHistory: AssessmentRecord[];
  private learningProgress: LearningProgress;
  private currentLevel: number = 0;
  private maxHistorySize: number = 100;

  private constructor() {
    this.levelDetector = LevelDetector.getInstance();
    this.assessmentHistory = [];
    this.learningProgress = new LearningProgress();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): UserAssessment {
    if (UserAssessment.instance === null) {
      UserAssessment.instance = new UserAssessment();
    }
    return UserAssessment.instance;
  }

  /**
   * 执行初始评估
   */
  async performInitialAssessment(): Promise<LevelDetectionResult> {
    const result = await this.levelDetector.detectLevel();
    
    // 保存评估记录
    const record = new AssessmentRecord(
      this.generateId(),
      Date.now(),
      result.overallLevel,
      result.vocabularyLevel,
      result.readingLevel,
      result.grammarLevel,
      result.estimatedVocabSize,
      result.confidence
    );
    
    this.saveAssessmentRecord(record);
    
    // 更新当前水平
    this.currentLevel = result.overallLevel;
    
    return result;
  }

  /**
   * 执行动态评估
   */
  async performDynamicAssessment(): Promise<LevelDetectionResult> {
    // 基于学习进度和表现进行评估
    const progress = this.learningProgress;
    
    // 根据学习进度调整当前水平
    const adjustedLevel = this.calculateAdjustedLevel(progress);
    
    // 执行快速测试（可选）
    const quickTestResult = await this.levelDetector.detectLevel();
    
    // 结合快速测试结果和进度数据
    const finalLevel = Math.round((adjustedLevel + quickTestResult.overallLevel) / 2);
    
    // 保存评估记录
    const record = new AssessmentRecord(
      this.generateId(),
      Date.now(),
      finalLevel,
      quickTestResult.vocabularyLevel,
      quickTestResult.readingLevel,
      quickTestResult.grammarLevel,
      quickTestResult.estimatedVocabSize,
      quickTestResult.confidence
    );
    
    this.saveAssessmentRecord(record);
    
    // 更新当前水平
    this.currentLevel = finalLevel;
    
    return quickTestResult;
  }

  /**
   * 计算调整后的水平
   */
  private calculateAdjustedLevel(progress: LearningProgress): number {
    const masteryRate = progress.getMasteryRate();
    const efficiency = progress.getEfficiency();
    const streak = progress.streakDays;
    
    // 基础水平
    let adjustedLevel = this.currentLevel;
    
    // 根据掌握率调整
    if (masteryRate > 80) {
      adjustedLevel += 1;
    } else if (masteryRate < 50) {
      adjustedLevel -= 0.5;
    }
    
    // 根据效率调整
    if (efficiency > 100) {
      adjustedLevel += 0.5;
    } else if (efficiency < 50) {
      adjustedLevel -= 0.5;
    }
    
    // 根据连续学习天数调整
    if (streak > 7) {
      adjustedLevel += 0.3;
    } else if (streak < 3) {
      adjustedLevel -= 0.2;
    }
    
    // 限制在0-10范围内
    return Math.max(0, Math.min(10, adjustedLevel));
  }

  /**
   * 获取当前水平
   */
  getCurrentLevel(): number {
    return this.currentLevel;
  }

  /**
   * 设置当前水平
   */
  setCurrentLevel(level: number): void {
    this.currentLevel = Math.max(0, Math.min(10, level));
  }

  /**
   * 更新学习进度
   */
  updateLearningProgress(
    wordsLearned: number,
    wordsMastered: number,
    wordsInReview: number,
    studyTime: number
  ): void {
    this.learningProgress.updateProgress(
      wordsLearned,
      wordsMastered,
      wordsInReview,
      studyTime
    );
    
    // 更新连续学习天数
    this.learningProgress.updateStreak(Date.now());
  }

  /**
   * 获取学习进度
   */
  getLearningProgress(): LearningProgress {
    return this.learningProgress;
  }

  /**
   * 获取推荐难度
   */
  getRecommendedDifficulty(): DifficultyLevel {
    const level = this.currentLevel;
    
    if (level <= 1) {
      return DifficultyLevel.CET4;
    } else if (level <= 2) {
      return DifficultyLevel.CET6;
    } else if (level <= 3) {
      return DifficultyLevel.IELTS;
    } else if (level <= 4) {
      return DifficultyLevel.TOEFL;
    } else if (level <= 5) {
      return DifficultyLevel.SAT;
    } else {
      return DifficultyLevel.GRE;
    }
  }

  /**
   * 获取评估历史
   */
  getAssessmentHistory(limit: number = 10): AssessmentRecord[] {
    return this.assessmentHistory
      .slice(-limit)
      .sort((a, b) => b.timestamp - a.timestamp);
  }

  /**
   * 保存评估记录
   */
  private saveAssessmentRecord(record: AssessmentRecord): void {
    this.assessmentHistory.push(record);
    
    // 限制历史记录大小
    if (this.assessmentHistory.length > this.maxHistorySize) {
      this.assessmentHistory.shift();
    }
  }

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return `assessment_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
  }

  /**
   * 分析学习趋势
   */
  analyzeLearningTrends(): LearningTrendsData {
    const history = this.getAssessmentHistory(10);
    
    if (history.length < 2) {
      return {
        levelTrend: 'stable',
        progressRate: 0,
        estimatedTimeToNextLevel: 0
      };
    }
    
    // 计算水平变化趋势
    const recentLevels = history.map((r: AssessmentRecord) => r.overallLevel);
    const firstHalf = recentLevels.slice(0, Math.floor(history.length / 2));
    const secondHalf = recentLevels.slice(Math.floor(history.length / 2));
    
    const firstAvg = firstHalf.reduce((sum: number, level: number) => sum + level, 0) / firstHalf.length;
    const secondAvg = secondHalf.reduce((sum: number, level: number) => sum + level, 0) / secondHalf.length;
    
    let trend: 'improving' | 'stable' | 'declining' = 'stable';
    if (secondAvg - firstAvg > 0.5) {
      trend = 'improving';
    } else if (firstAvg - secondAvg > 0.5) {
      trend = 'declining';
    }
    
    // 计算进步率
    const progressRate = (secondAvg - firstAvg) / (history.length / 2) * 100;
    
    // 估算到达下一级所需时间
    const progress = this.learningProgress;
    const currentLevel = this.currentLevel;
    const nextLevel = Math.min(10, currentLevel + 1);
    const levelGap = nextLevel - currentLevel;
    
    const estimatedDays = levelGap > 0 
      ? Math.ceil(levelGap / (progressRate / 100)) 
      : 0;
    
    return {
      levelTrend: trend,
      progressRate,
      estimatedTimeToNextLevel: estimatedDays
    };
  }

  /**
   * 获取学习建议
   */
  getLearningRecommendations(): string[] {
    const recommendations: string[] = [];
    const progress = this.learningProgress;
    const trends = this.analyzeLearningTrends();
    
    // 根据趋势给出建议
    if (trends.levelTrend === 'declining') {
      recommendations.push('建议：学习进度有所下降，请检查学习方法');
    } else if (trends.levelTrend === 'improving') {
      recommendations.push('建议：学习进步良好，继续保持！');
    }
    
    // 根据掌握率给出建议
    const masteryRate = progress.getMasteryRate();
    if (masteryRate < 60) {
      recommendations.push('建议：掌握率较低，建议增加复习次数');
    } else if (masteryRate > 90) {
      recommendations.push('建议：掌握率很高，可以尝试更有挑战性的内容');
    }
    
    // 根据连续学习天数给出建议
    if (progress.streakDays < 3) {
      recommendations.push('建议：保持连续学习，建立学习习惯');
    } else if (progress.streakDays > 14) {
      recommendations.push('建议：学习习惯很好，注意适当休息');
    }
    
    // 根据效率给出建议
    const efficiency = progress.getEfficiency();
    if (efficiency < 50) {
      recommendations.push('建议：学习效率偏低，建议优化学习方法');
    }
    
    return recommendations;
  }

  /**
   * 导出评估数据
   */
  exportAssessmentData(): string {
    const data: GeneratedObjectLiteralInterface_1 = {
      currentLevel: this.currentLevel,
      learningProgress: this.learningProgress.toJSON(),
      assessmentHistory: this.assessmentHistory.map((r: AssessmentRecord) => r.toJSON())
    };
    return JSON.stringify(data);
  }

  /**
   * 导入评估数据
   */
  importAssessmentData(json: string): boolean {
    try {
      const data = JSON.parse(json) as ImportedAssessmentData;
      
      this.currentLevel = data.currentLevel ?? 0;
      this.learningProgress = LearningProgress.fromJSON(data.learningProgress);
      
      for (const recordJson of data.assessmentHistory) {
        const record = AssessmentRecord.fromJSON(recordJson);
        this.assessmentHistory.push(record);
      }
      
      return true;
    } catch (e) {
      console.error('[UserAssessment] Import failed:', e);
      return false;
    }
  }

  /**
   * 重置评估
   */
  resetAssessment(): void {
    this.currentLevel = 0;
    this.assessmentHistory = [];
    this.learningProgress = new LearningProgress();
  }

  /**
   * 获取评估统计
   */
  getAssessmentStatistics(): AssessmentStatisticsData {
    const history = this.assessmentHistory;
    
    if (history.length === 0) {
      return {
        totalAssessments: 0,
        averageLevel: 0,
        highestLevel: 0,
        lowestLevel: 0,
        averageConfidence: 0
      };
    }
    
    const levels = history.map((r: AssessmentRecord) => r.overallLevel);
    const confidences = history.map((r: AssessmentRecord) => r.confidence);
    
    return {
      totalAssessments: history.length,
      averageLevel: levels.reduce((sum: number, level: number) => sum + level, 0) / levels.length,
      highestLevel: Math.max(...levels),
      lowestLevel: Math.min(...levels),
      averageConfidence: confidences.reduce((sum: number, conf: number) => sum + conf, 0) / confidences.length
    };
  }

  /**
   * 检查是否需要重新评估
   */
  needsReassessment(): boolean {
    const history = this.getAssessmentHistory(5);
    
    if (history.length === 0) {
      return true;
    }
    
    const lastAssessment = history[0];
    const daysSinceLastAssessment = (Date.now() - lastAssessment.timestamp) / (24 * 60 * 60 * 1000);
    
    // 如果超过30天未评估，或学习进度有显著变化，需要重新评估
    return daysSinceLastAssessment > 30 || this.hasSignificantProgressChange();
  }

  /**
   * 检查是否有显著的进度变化
   */
  private hasSignificantProgressChange(): boolean {
    const progress = this.learningProgress;
    const history = this.getAssessmentHistory(2);
    
    if (history.length < 2) {
      return false;
    }
    
    const lastProgress = history[1].estimatedVocabSize;
    const currentProgress = progress.totalWordsLearned;
    
    // 如果词汇量增长超过20%，认为有显著变化
    return currentProgress > lastProgress * 1.2;
  }

  /**
   * 获取水平描述
   */
  getLevelDescription(level: number): string {
    if (level >= 9) return '专家级';
    if (level >= 7) return '高级';
    if (level >= 5) return '中级';
    if (level >= 3) return '初级';
    return '入门';
  }

  /**
   * 获取学习目标
   */
  getLearningGoals(): LearningGoalsData {
    const currentLevel = this.currentLevel;
    const nextLevel = Math.min(10, currentLevel + 1);
    const progress = this.learningProgress;
    
    // 估算到达下一级所需学习的单词数
    const wordsPerLevel = 500; // 假设每级需要500个单词
    const wordsToNextLevel = (nextLevel - currentLevel) * wordsPerLevel - 
                            (progress.totalWordsLearned % wordsPerLevel);
    
    // 根据学习效率估算所需天数
    const efficiency = progress.getEfficiency();
    const wordsPerDay = efficiency / 100; // 每天学习的单词数
    const estimatedDays = wordsPerDay > 0 ? Math.ceil(wordsToNextLevel / wordsPerDay) : 0;
    
    return {
      nextLevel,
      wordsToNextLevel,
      estimatedDays
    };
  }
}
