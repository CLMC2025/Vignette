/**
 * UserStateManager - 用户个人单词本状态管理
 * 独立于系统词书，专注于用户个人学习状态管理
 */

import { WordItem } from '../model/WordModel';

/**
 * 用户单词状态枚举
 * 扩展了系统状态，支持更细粒度的用户个人状态
 */
export enum UserWordState {
  UNADDED = 'unadded',      // 未加入任何词书（默认状态）
  ADDED = 'added',          // 已加入词书但未开始学习
  NEW = 'new',              // 新词（开始学习）
  LEARNING = 'learning',    // 学习中
  REVIEW = 'review',        // 复习中
  FAMILIAR = 'familiar',    // 熟悉（用户标记）
  DIFFICULT = 'difficult'  // 困难词（用户标记）
}

const USER_WORD_STATES: UserWordState[] = [
  UserWordState.UNADDED,
  UserWordState.ADDED,
  UserWordState.NEW,
  UserWordState.LEARNING,
  UserWordState.REVIEW,
  UserWordState.FAMILIAR,
  UserWordState.DIFFICULT
];

const USER_WORD_STATE_VALUES: string[] = [
  'unadded',
  'added',
  'new',
  'learning',
  'review',
  'familiar',
  'difficult'
];

/**
 * 用户单词进度数据
 */
export interface UserWordProgress {
  wordId: string;
  state: UserWordState;
  userBookId: string;        // 用户词书ID
  addedAt: number;           // 加入时间
  lastReviewedAt: number;    // 最后复习时间
  reviewCount: number;       // 复习次数
  userTags: string[];        // 用户标签
  notes: string;             // 用户笔记
}

/**
 * 用户级别定义
 */
export enum UserLevel {
  BEGINNER = 'beginner',    // 初级
  INTERMEDIATE = 'intermediate', // 中级
  ADVANCED = 'advanced',   // 高级
  EXPERT = 'expert'         // 专家
}

/**
 * 状态变更监听器
 */
export type StateChangeListener = (wordId: string, oldState: UserWordState, newState: UserWordState) => void;

/**
 * 单词状态更新接口
 */
export interface WordStateUpdate {
  wordId: string;
  state: UserWordState;
  userBookId?: string;
}

/**
 * 用户状态管理器 - 单例模式
 */
export class UserStateManager {
  private static instance: UserStateManager | null = null;
  
  // 用户单词进度缓存
  private userProgress: Map<string, UserWordProgress> = new Map();
  
  // 状态变更监听器
  private stateChangeListeners: StateChangeListener[] = [];
  
  // 当前用户级别
  private currentUserLevel: UserLevel = UserLevel.BEGINNER;
  
  // 高频词库（用于智能初始化）
  private highFrequencyWords: Set<string> = new Set([
    'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i',
    'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at'
  ]);
  
  // 词根映射（用于相似词判断）
  private wordRootMap: Map<string, string[]> = new Map();
  
  private constructor() {
    // 初始化词根映射
    this.initializeWordRoots();
  }
  
  /**
   * 获取单例实例
   */
  static getInstance(): UserStateManager {
    if (UserStateManager.instance === null) {
      UserStateManager.instance = new UserStateManager();
    }
    return UserStateManager.instance;
  }
  
  /**
   * 初始化词根映射
   */
  private initializeWordRoots(): void {
    // 常见的词根映射关系
    this.wordRootMap.set('act', ['act', 'action', 'active', 'actor', 'actress']);
    this.wordRootMap.set('dict', ['dictate', 'dictionary', 'predict', 'contradict']);
    this.wordRootMap.set('port', ['port', 'import', 'export', 'transport', 'portable']);
    this.wordRootMap.set('form', ['form', 'format', 'inform', 'transform', 'formal']);
    this.wordRootMap.set('vis', ['vision', 'visible', 'visit', 'visual', 'supervise']);
  }
  
  /**
   * 设置用户级别
   */
  setUserLevel(level: UserLevel): void {
    this.currentUserLevel = level;
    console.log(`[UserStateManager] User level set to: ${level}`);
  }
  
  /**
   * 获取用户级别
   */
  getUserLevel(): UserLevel {
    return this.currentUserLevel;
  }
  
  /**
   * 智能初始化单词状态
   * 根据用户级别、单词属性等因素智能设置初始状态
   */
  initializeWordState(word: WordItem): UserWordState {
    const wordText = word.word.toLowerCase();
    
    // 1. 高频词默认进入复习
    if (this.isHighFrequencyWord(wordText)) {
      return UserWordState.REVIEW;
    }
    
    // 2. 根据用户级别设置不同策略
    switch (this.currentUserLevel) {
      case UserLevel.BEGINNER:
        // 初级用户：基础词汇设为熟悉
        if (this.isBasicWord(wordText)) {
          return UserWordState.FAMILIAR;
        }
        break;
        
      case UserLevel.INTERMEDIATE:
        // 中级用户：常见词设为熟悉，复杂词标记为困难
        if (this.isCommonWord(wordText)) {
          return UserWordState.FAMILIAR;
        } else if (this.isComplexWord(wordText)) {
          return UserWordState.DIFFICULT;
        }
        break;
        
      case UserLevel.ADVANCED:
      case UserLevel.EXPERT:
        // 高级用户：更多词汇设为熟悉
        if (this.isFrequentWord(wordText)) {
          return UserWordState.FAMILIAR;
        }
        break;
    }
    
    // 3. 相似词判断
    if (this.isSimilarToKnownWord(wordText)) {
      return UserWordState.FAMILIAR;
    }
    
    // 4. 默认状态：未加入
    return UserWordState.UNADDED;
  }
  
  /**
   * 判断是否为高频词
   */
  private isHighFrequencyWord(word: string): boolean {
    return this.highFrequencyWords.has(word);
  }
  
  /**
   * 判断是否为基础词汇
   */
  private isBasicWord(word: string): boolean {
    // 基础词汇列表（长度短、常见）
    const basicWords = ['cat', 'dog', 'run', 'walk', 'big', 'small', 'good', 'bad'];
    return word.length <= 5 && basicWords.includes(word);
  }
  
  /**
   * 判断是否为常见词
   */
  private isCommonWord(word: string): boolean {
    // 常见词汇（CET4级别）
    const commonWords = ['important', 'necessary', 'available', 'different', 'similar'];
    return commonWords.includes(word) || word.length <= 8;
  }
  
  /**
   * 判断是否为复杂词
   */
  private isComplexWord(word: string): boolean {
    // 复杂词汇（长单词、专业词汇）
    return word.length >= 10 || word.includes('-') || word.includes('_');
  }
  
  /**
   * 判断是否为频繁词
   */
  private isFrequentWord(word: string): boolean {
    // 频繁词汇（CET6级别）
    const frequentWords = ['substantial', 'significant', 'comprehensive', 'subsequent'];
    return frequentWords.includes(word);
  }
  
  /**
   * 判断是否与用户已复习词汇相似
   */
  private isSimilarToKnownWord(word: string): boolean {
    // 检查词根相似性
    const entries: Array<[string, string[]]> = Array.from(this.wordRootMap.entries());
    for (let i: number = 0; i < entries.length; i++) {
      const root: string = entries[i][0];
      const words: string[] = entries[i][1];
      if (words.includes(word)) {
        // 检查用户是否已复习该词根的其他词
        for (let j: number = 0; j < words.length; j++) {
          const relatedWord: string = words[j];
          if (relatedWord !== word && this.isWordReviewed(relatedWord)) {
            return true;
          }
        }
      }
    }
    return false;
  }
  
  /**
   * 判断单词是否已复习
   */
  private isWordReviewed(word: string): boolean {
    const progress = this.userProgress.get(word);
    return progress !== undefined && progress.state === UserWordState.REVIEW;
  }
  
  /**
   * 获取用户单词状态
   */
  getWordState(wordId: string): UserWordState | null {
    const progress = this.userProgress.get(wordId);
    return progress?.state ?? null;
  }
  
  /**
   * 获取用户单词进度
   */
  getWordProgress(wordId: string): UserWordProgress | null {
    return this.userProgress.get(wordId) ?? null;
  }
  
  /**
   * 更新用户单词状态
   */
  updateWordState(wordId: string, newState: UserWordState, userBookId: string = ''): void {
    const oldProgress = this.userProgress.get(wordId);
    const oldState = oldProgress?.state ?? UserWordState.UNADDED;
    
    const now = Date.now();
    const progress: UserWordProgress = {
      wordId,
      state: newState,
      userBookId: userBookId || oldProgress?.userBookId || '',
      addedAt: oldProgress?.addedAt || now,
      lastReviewedAt: (newState === UserWordState.REVIEW || newState === UserWordState.LEARNING) ? now : oldProgress?.lastReviewedAt || 0,
      reviewCount: oldProgress?.reviewCount || 0,
      userTags: oldProgress?.userTags || [],
      notes: oldProgress?.notes || ''
    };
    
    // 更新复习次数
    if (newState === UserWordState.REVIEW || newState === UserWordState.LEARNING) {
      progress.reviewCount = (oldProgress?.reviewCount || 0) + 1;
    }
    
    this.userProgress.set(wordId, progress);
    
    // 触发状态变更通知
    this.notifyStateChange(wordId, oldState, newState);
    
    console.log(`[UserStateManager] Word ${wordId} state changed from ${oldState} to ${newState}`);
  }
  
  /**
   * 批量更新单词状态
   */
  batchUpdateWordStates(updates: Array<WordStateUpdate>): void {
    for (let i: number = 0; i < updates.length; i++) {
      const update: WordStateUpdate = updates[i];
      this.updateWordState(update.wordId, update.state, update.userBookId || '');
    }
  }
  
  /**
   * 添加状态变更监听器
   */
  addStateChangeListener(listener: StateChangeListener): void {
    this.stateChangeListeners.push(listener);
  }
  
  /**
   * 移除状态变更监听器
   */
  removeStateChangeListener(listener: StateChangeListener): void {
    const index = this.stateChangeListeners.indexOf(listener);
    if (index !== -1) {
      this.stateChangeListeners.splice(index, 1);
    }
  }
  
  /**
   * 通知状态变更
   */
  private notifyStateChange(wordId: string, oldState: UserWordState, newState: UserWordState): void {
    for (const listener of this.stateChangeListeners) {
      try {
        listener(wordId, oldState, newState);
      } catch (error) {
        console.error(`[UserStateManager] State change listener error:`, error);
      }
    }
  }
  
  /**
   * 获取指定状态的单词列表
   */
  getWordsByState(state: UserWordState): string[] {
    const wordIds: string[] = [];
    const keys: string[] = Array.from(this.userProgress.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const wordId: string = keys[i];
      const progress: UserWordProgress | undefined = this.userProgress.get(wordId);
      if (progress !== undefined && progress.state === state) {
        wordIds.push(wordId);
      }
    }
    return wordIds;
  }
  
  /**
   * 获取用户词书中的单词
   */
  getWordsByUserBook(userBookId: string): string[] {
    const wordIds: string[] = [];
    const keys: string[] = Array.from(this.userProgress.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const wordId: string = keys[i];
      const progress: UserWordProgress | undefined = this.userProgress.get(wordId);
      if (progress !== undefined && progress.userBookId === userBookId) {
        wordIds.push(wordId);
      }
    }
    return wordIds;
  }
  
  /**
   * 获取统计信息
   */
  getStatistics(): Map<UserWordState, number> {
    const stats: Map<UserWordState, number> = new Map<UserWordState, number>();

    // 初始化所有状态为0
    const stateValues: UserWordState[] = USER_WORD_STATES;
    for (let i: number = 0; i < stateValues.length; i++) {
      const state: UserWordState = stateValues[i];
      stats.set(state, 0);
    }

    // 统计各状态单词数量
    const keys: string[] = Array.from(this.userProgress.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const progress: UserWordProgress | undefined = this.userProgress.get(keys[i]);
      if (progress !== undefined) {
        const currentCount: number = stats.get(progress.state) || 0;
        stats.set(progress.state, currentCount + 1);
      }
    }

    return stats;
  }
  
  /**
   * 清空所有用户状态
   */
  clearAllStates(): void {
    this.userProgress.clear();
    this.stateChangeListeners = [];
    console.log('[UserStateManager] All user states cleared');
  }
  
  /**
   * 导出用户状态数据
   */
  exportStates(): Record<string, UserWordProgress> {
    const exportData: Record<string, UserWordProgress> = {};
    const keys: string[] = Array.from(this.userProgress.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const wordId: string = keys[i];
      const progress: UserWordProgress | undefined = this.userProgress.get(wordId);
      if (progress !== undefined) {
        exportData[wordId] = progress;
      }
    }
    return exportData;
  }
  
  /**
   * 导入用户状态数据
   */
  importStates(states: Record<string, UserWordProgress>): void {
    this.clearAllStates();

    const keys: string[] = Object.keys(states);
    for (let i: number = 0; i < keys.length; i++) {
      const wordId: string = keys[i];
      const progress: UserWordProgress = states[wordId];
      if (this.isValidProgress(progress)) {
        this.userProgress.set(wordId, progress);
      }
    }

    console.log('[UserStateManager] Imported ' + this.userProgress.size + ' user states');
  }
  
  /**
   * 验证进度数据有效性
   */
  private isValidProgress(progress: object): boolean {
    const p: Record<string, object | string | number | string[]> = progress as Record<string, object | string | number | string[]>;
    const stateValues: string[] = USER_WORD_STATE_VALUES;
    return (
      p !== null &&
      typeof p.wordId === 'string' &&
      typeof p.state === 'string' &&
      stateValues.includes(p.state) &&
      typeof p.userBookId === 'string' &&
      typeof p.addedAt === 'number' &&
      typeof p.lastReviewedAt === 'number' &&
      typeof p.reviewCount === 'number' &&
      Array.isArray(p.userTags) &&
      typeof p.notes === 'string'
    );
  }
}
