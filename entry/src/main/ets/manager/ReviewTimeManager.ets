/**
 * ReviewTimeManager - 复习时间状态管理器
 * 用于精确跟踪和管理复习时间，防止时间叠加和重复计算
 */

import { WordItem } from '../model/WordModel';

/**
 * 复习时间记录
 */
interface ReviewTimeRecord {
  wordId: number;
  word: string;
  startTime: number;
  endTime?: number;
  duration?: number;
  rating?: number;
  status: 'active' | 'completed' | 'cancelled';
}

/**
 * 复习时间统计
 */
interface ReviewTimeStats {
  totalWordsReviewed: number;
  totalTimeSpent: number; // 毫秒
  averageTimePerWord: number; // 毫秒
  currentSessionStartTime: number;
  currentSessionDuration: number;
}

/**
 * 复习时间管理器 - 单例模式
 */
export class ReviewTimeManager {
  private static instance: ReviewTimeManager | null = null;
  
  // 当前活动的复习记录
  private activeReviews: Map<string, ReviewTimeRecord> = new Map();
  
  // 历史复习记录（用于统计）
  private reviewHistory: ReviewTimeRecord[] = [];
  
  // 会话统计
  private sessionStats: ReviewTimeStats;
  
  // 时间阈值配置
  private readonly MIN_REVIEW_INTERVAL_MS = 2000; // 最小复习间隔：2秒
  private readonly MAX_REVIEW_TIME_MS = 300000; // 最大复习时间：5分钟
  private readonly SESSION_TIMEOUT_MS = 1800000; // 会话超时：30分钟
  
  private constructor() {
    this.sessionStats = {
      totalWordsReviewed: 0,
      totalTimeSpent: 0,
      averageTimePerWord: 0,
      currentSessionStartTime: Date.now(),
      currentSessionDuration: 0
    };
  }
  
  /**
   * 获取单例实例
   */
  static getInstance(): ReviewTimeManager {
    if (ReviewTimeManager.instance === null) {
      ReviewTimeManager.instance = new ReviewTimeManager();
    }
    return ReviewTimeManager.instance;
  }
  
  /**
   * 开始复习计时
   */
  startReview(word: WordItem): ReviewTimeRecord | null {
    const wordKey = `${word.id}_${word.word}`;
    const now = Date.now();
    
    // 检查是否已有活动的复习记录
    if (this.activeReviews.has(wordKey)) {
      const existingRecord = this.activeReviews.get(wordKey)!;
      if (existingRecord.status === 'active') {
        console.warn(`[ReviewTimeManager] Word "${word.word}" already has active review, cancelling previous`);
        this.cancelReview(word);
      }
    }
    
    // 检查与上次复习的时间间隔
    const lastReview = this.getLastReviewForWord(word.word);
    if (lastReview && lastReview.endTime) {
      const timeSinceLastReview = now - lastReview.endTime;
      if (timeSinceLastReview < this.MIN_REVIEW_INTERVAL_MS) {
        console.warn(`[ReviewTimeManager] Word "${word.word}" reviewed too recently (${timeSinceLastReview}ms ago)`);
        return null;
      }
    }
    
    // 创建新的复习记录
    const record: ReviewTimeRecord = {
      wordId: word.id,
      word: word.word,
      startTime: now,
      status: 'active'
    };
    
    this.activeReviews.set(wordKey, record);
    console.log(`[ReviewTimeManager] Started review for "${word.word}" at ${now}`);
    
    return record;
  }
  
  /**
   * 完成复习计时
   */
  completeReview(word: WordItem, rating: number): ReviewTimeRecord | null {
    const wordKey = `${word.id}_${word.word}`;
    const now = Date.now();
    
    const record = this.activeReviews.get(wordKey);
    if (!record || record.status !== 'active') {
      console.warn(`[ReviewTimeManager] No active review found for "${word.word}"`);
      return null;
    }
    
    // 计算复习时长
    const duration = now - record.startTime;
    
    // 验证复习时长是否合理
    if (duration > this.MAX_REVIEW_TIME_MS) {
      console.warn(`[ReviewTimeManager] Review duration too long for "${word.word}": ${duration}ms`);
      return null;
    }
    
    // 更新记录状态
    record.endTime = now;
    record.duration = duration;
    record.rating = rating;
    record.status = 'completed';
    
    // 添加到历史记录
    const historyRecord: ReviewTimeRecord = {
      wordId: record.wordId,
      word: record.word,
      startTime: record.startTime,
      endTime: record.endTime,
      duration: record.duration,
      rating: record.rating,
      status: record.status
    };
    this.reviewHistory.push(historyRecord);
    
    // 更新统计
    this.updateStats(record);
    
    // 从活动记录中移除
    this.activeReviews.delete(wordKey);
    
    console.log(`[ReviewTimeManager] Completed review for "${word.word}": ${duration}ms, rating: ${rating}`);
    
    return record;
  }
  
  /**
   * 取消复习计时
   */
  cancelReview(word: WordItem): void {
    const wordKey = `${word.id}_${word.word}`;
    const record = this.activeReviews.get(wordKey);
    
    if (!record || record.status !== 'active') {
      return;
    }
    
    record.status = 'cancelled';
    record.endTime = Date.now();
    
    // 从活动记录中移除
    this.activeReviews.delete(wordKey);
    
    console.log(`[ReviewTimeManager] Cancelled review for "${word.word}"`);
  }
  
  /**
   * 检查是否可以开始复习
   */
  canStartReview(word: WordItem): boolean {
    const wordKey = `${word.id}_${word.word}`;
    const now = Date.now();
    
    // 检查是否有活动的复习记录
    if (this.activeReviews.has(wordKey)) {
      const existingRecord = this.activeReviews.get(wordKey)!;
      if (existingRecord.status === 'active') {
        return false;
      }
    }
    
    // 检查与上次复习的时间间隔
    const lastReview = this.getLastReviewForWord(word.word);
    if (lastReview && lastReview.endTime) {
      const timeSinceLastReview = now - lastReview.endTime;
      if (timeSinceLastReview < this.MIN_REVIEW_INTERVAL_MS) {
        return false;
      }
    }
    
    return true;
  }
  
  /**
   * 获取单词的最后一次复习记录
   */
  private getLastReviewForWord(word: string): ReviewTimeRecord | null {
    // 从历史记录中倒序查找
    for (let i = this.reviewHistory.length - 1; i >= 0; i--) {
      const record = this.reviewHistory[i];
      if (record.word === word && record.status === 'completed') {
        return record;
      }
    }
    return null;
  }
  
  /**
   * 更新统计信息
   */
  private updateStats(record: ReviewTimeRecord): void {
    if (record.duration && record.status === 'completed') {
      this.sessionStats.totalWordsReviewed++;
      this.sessionStats.totalTimeSpent += record.duration;
      
      // 计算平均时间
      if (this.sessionStats.totalWordsReviewed > 0) {
        this.sessionStats.averageTimePerWord = 
          this.sessionStats.totalTimeSpent / this.sessionStats.totalWordsReviewed;
      }
      
      // 更新当前会话时长
      this.sessionStats.currentSessionDuration = Date.now() - this.sessionStats.currentSessionStartTime;
    }
  }
  
  /**
   * 获取当前会话统计
   */
  getSessionStats(): ReviewTimeStats {
    // 更新当前会话时长
    this.sessionStats.currentSessionDuration = Date.now() - this.sessionStats.currentSessionStartTime;
    const stats: ReviewTimeStats = {
      totalWordsReviewed: this.sessionStats.totalWordsReviewed,
      totalTimeSpent: this.sessionStats.totalTimeSpent,
      averageTimePerWord: this.sessionStats.averageTimePerWord,
      currentSessionStartTime: this.sessionStats.currentSessionStartTime,
      currentSessionDuration: this.sessionStats.currentSessionDuration
    };
    return stats;
  }
  
  /**
   * 获取活动的复习记录
   */
  getActiveReview(word: WordItem): ReviewTimeRecord | null {
    const wordKey = `${word.id}_${word.word}`;
    return this.activeReviews.get(wordKey) || null;
  }
  
  /**
   * 获取单词的复习历史
   */
  getReviewHistory(word: WordItem): ReviewTimeRecord[] {
    return this.reviewHistory.filter(record => 
      record.word === word.word && record.status === 'completed'
    );
  }
  
  /**
   * 获取当前活动的复习数量
   */
  getActiveReviewCount(): number {
    return this.activeReviews.size;
  }
  
  /**
   * 重置会话统计
   */
  resetSessionStats(): void {
    this.sessionStats = {
      totalWordsReviewed: 0,
      totalTimeSpent: 0,
      averageTimePerWord: 0,
      currentSessionStartTime: Date.now(),
      currentSessionDuration: 0
    };
    
    // 清理活动复习记录
    this.activeReviews.clear();
    
    console.log('[ReviewTimeManager] Session stats reset');
  }
  
  /**
   * 检查会话是否超时
   */
  isSessionTimeout(): boolean {
    const now = Date.now();
    const sessionDuration = now - this.sessionStats.currentSessionStartTime;
    return sessionDuration > this.SESSION_TIMEOUT_MS;
  }
  
  /**
   * 清理过期数据
   */
  cleanup(): void {
    const now = Date.now();
    const MAX_HISTORY_AGE = 24 * 60 * 60 * 1000; // 24小时
    
    // 清理过期的历史记录
    this.reviewHistory = this.reviewHistory.filter(record => {
      const recordAge = now - (record.endTime || record.startTime);
      return recordAge < MAX_HISTORY_AGE;
    });
    
    // 清理超时的活动复习
    const entries: Array<[string, ReviewTimeRecord]> = Array.from(this.activeReviews.entries());
    for (let i: number = 0; i < entries.length; i++) {
      const wordKey: string = entries[i][0];
      const record: ReviewTimeRecord = entries[i][1];
      if (record.status === 'active') {
        const activeDuration: number = now - record.startTime;
        if (activeDuration > this.MAX_REVIEW_TIME_MS) {
          console.warn('[ReviewTimeManager] Cleaning up stale active review for "' + record.word + '"');
          const wordItem: WordItem = new WordItem(record.wordId, record.word);
          this.cancelReview(wordItem);
        }
      }
    }
    
    console.log(`[ReviewTimeManager] Cleanup completed. Active reviews: ${this.activeReviews.size}, History: ${this.reviewHistory.length}`);
  }
}