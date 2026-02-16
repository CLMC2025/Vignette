// =====================================================
// DBManager.ets - RelationalStore (SQLite) Wrapper
// Handles all database operations for Vignette
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import type common from '@ohos.app.ability.common';
import {
  WordItem,
  WordStatus,
  WordDefinition,
  FSRSState,
  ReviewHistory
} from '../model/WordModel';
import { BookProgress } from '../model/WordBookCatalog';
import { HeatmapDailyStats } from '../model/HeatmapData';
import { isUniqueConstraintErrorMessage } from '../utils/DatabaseErrorUtil';

// Repositories
import { WordRepository, DefinitionCacheRow } from './repositories/WordRepository';
import { ReviewEventRepository, ReviewDailyAggregateRow, ReviewDailyNewWordRow } from './repositories/ReviewEventRepository';
import { VignetteCacheRepository } from './repositories/VignetteCacheRepository';
import { WordBookRepository } from './repositories/WordBookRepository';
import { TextRepository, TextRow } from './repositories/TextRepository';
import { SchemaManager } from './SchemaManager';

// Constants and Shared Types
import {
  DBError,
  TABLE_USER_NOTEBOOK_WORDS
} from './DBConstants';

/**
 * 用户词书数据
 */
export interface UserWordBook {
  id: string;
  name: string;
  description: string;
  wordCount: number;
  isUserCreated: boolean;
  createdAt: number;
  updatedAt: number;
  category?: string;
  difficulty?: string;
  coverColor?: string;
  icon?: string;
}

/**
 * 单词本条目
 */
export interface NotebookWordEntry {
  word: string;
  createdAt: number;
}

export interface DailyActivity {
  date: number;
  count: number;
}

export interface UserWordBookBrief {
  id: string;
  name: string;
}

export enum EnsureBookIdOutcome {
  NotFound = 0,
  Already = 1,
  Assigned = 2,
  Conflict = 3
}

export enum AddToUserWordBookOutcome {
  Added = 0,
  Already = 1
}

/**
 * Database configuration
 */
const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'vignette.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

function hashToUint32(input: string): number {
  let hash = 2166136261;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

/**
 * Review event row for sync/optimizer
 */
export interface ReviewEventRow {
  id: string;
  wordId: number;
  rating: number;
  timestamp: number;
  prevStateJson: string;
  newStateJson: string;
  errorTag: string;
  reflection: string;
  scheduledDays: number;
}

export interface VignetteCacheItemRow {
  id: number;
  word: string;
  vignette: string;
  vignetteHash: number;
  createdAt: number;
  lastUsedAt: number;
  sizeBytes: number;
}

export { DefinitionCacheRow };

export interface VignetteCacheStats {
  count: number;
  sizeBytes: number;
}

/**
 * Database Manager Singleton
 */
export class DBManager {
  private static instance: DBManager | null = null;
  private store: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;

  // Repositories
  private wordRepo: WordRepository;
  private reviewEventRepo: ReviewEventRepository;
  private vignetteCacheRepo: VignetteCacheRepository;
  private wordBookRepo: WordBookRepository;
  private textRepo: TextRepository;
  private schemaManager: SchemaManager | null = null;

  private constructor() {
    this.wordRepo = new WordRepository(null);
    this.reviewEventRepo = new ReviewEventRepository(null);
    this.vignetteCacheRepo = new VignetteCacheRepository(null);
    this.wordBookRepo = new WordBookRepository(null);
    this.textRepo = new TextRepository(null);
  }

  /**
   * Get singleton instance
   */
  static getInstance(): DBManager {
    if (DBManager.instance === null) {
      DBManager.instance = new DBManager();
    }
    return DBManager.instance;
  }

  /**
   * Initialize database
   */
  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      this.store = await relationalStore.getRdbStore(context, DB_CONFIG);
      
      this.wordRepo.setStore(this.store);
      this.reviewEventRepo.setStore(this.store);
      this.vignetteCacheRepo.setStore(this.store);
      this.wordBookRepo.setStore(this.store);
      this.textRepo.setStore(this.store);

      this.schemaManager = new SchemaManager(this.store);
      await this.schemaManager.createTables();
      await this.schemaManager.upgradeTables();

      await Promise.all([
        this.vignetteCacheRepo.migrateVignetteCacheToItems(),
        this.wordBookRepo.migrateSystemWordBookMembership()
      ]);
      this.initialized = true;
      console.info('[DBManager] Database initialized successfully');
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      console.error('[DBManager] Failed to initialize database:', errorMsg);
      throw new DBError(`Failed to initialize database: ${errorMsg}`);
    }
  }

  /**
   * Check if database is ready
   */
  private ensureInitialized(): void {
    if (this.store === null) {
      throw new DBError('Database not initialized. Call initialize() first.');
    }
  }

  /**
   * Close database connection
   */
  async close(): Promise<void> {
    if (this.store !== null) {
      this.store = null;
      this.initialized = false;
      this.wordRepo.setStore(null);
      this.reviewEventRepo.setStore(null);
      this.vignetteCacheRepo.setStore(null);
      this.wordBookRepo.setStore(null);
      this.textRepo.setStore(null);
      this.schemaManager = null;
      console.info('[DBManager] Database closed');
    }
  }

  // ==================== TEXT OPERATIONS ====================

  async createText(
    title: string,
    content: string,
    sourceType: string = 'paste',
    sourceRef: string = ''
  ): Promise<number> {
    return this.textRepo.createText(title, content, sourceType, sourceRef);
  }

  async updateText(
    id: number,
    title: string,
    content: string,
    sourceType: string,
    sourceRef: string
  ): Promise<void> {
    await this.textRepo.updateText(id, title, content, sourceType, sourceRef);
  }

  async deleteText(id: number): Promise<void> {
    await this.textRepo.deleteText(id);
  }

  async getTextById(id: number): Promise<TextRow | null> {
    return this.textRepo.getTextById(id);
  }

  async listTexts(limit: number = 100): Promise<TextRow[]> {
    return this.textRepo.listTexts(limit);
  }

  // ==================== WORD OPERATIONS ====================

  async insertWord(word: WordItem): Promise<number> {
    return this.wordRepo.insertWord(word);
  }

  async insertWords(words: WordItem[]): Promise<number> {
    return this.wordRepo.insertWords(words);
  }

  async ensureBookIdForWord(wordStr: string, bookId: string): Promise<EnsureBookIdOutcome> {
    return this.wordBookRepo.ensureBookIdForWord(wordStr, bookId);
  }

  async updateWord(word: WordItem): Promise<number> {
    return this.wordRepo.updateWord(word);
  }

  async getWordById(id: number): Promise<WordItem | null> {
    return this.wordRepo.getWordById(id);
  }

  async getWordByWord(wordStr: string): Promise<WordItem | null> {
    return this.wordRepo.getWordByWord(wordStr);
  }

  async getAllWords(): Promise<WordItem[]> {
    return this.wordRepo.getAllWords();
  }

  async getWordsUpdatedAfter(sinceMs: number): Promise<WordItem[]> {
    return this.wordRepo.getWordsUpdatedAfter(sinceMs);
  }

  async getLearnedWordsUpdatedAfter(sinceMs: number): Promise<WordItem[]> {
    return this.wordRepo.getLearnedWordsUpdatedAfter(sinceMs);
  }

  async getWordsByStatus(status: WordStatus): Promise<WordItem[]> {
    return this.wordRepo.getWordsByStatus(status);
  }

  async getWordCounts(): Promise<Map<WordStatus, number>> {
    return this.wordRepo.getWordCounts();
  }

  async getReviewDueCount(): Promise<number> {
    return this.wordRepo.getReviewDueCount();
  }

  async deleteWord(id: number): Promise<number> {
    return this.wordRepo.deleteWord(id);
  }

  async deleteAllWords(): Promise<number> {
    return this.wordRepo.deleteAllWords();
  }

  async getReviewQueue(limit: number, excludeWord: string): Promise<WordItem[]> {
    return this.wordRepo.getPendingReviews(limit, excludeWord);
  }

  async getNewWordsQueue(limit: number, excludeWord: string): Promise<WordItem[]> {
    return this.wordRepo.getNewWords(limit, excludeWord);
  }

  async getLearningQueue(limit: number, excludeWord: string): Promise<WordItem[]> {
    return this.wordRepo.getLearningWords(limit, excludeWord);
  }

  // ==================== DEFINITION CACHE OPERATIONS ====================

  async cacheDefinition(word: string, definition: WordDefinition): Promise<void> {
    return this.wordRepo.cacheDefinition(word, definition);
  }

  async getCachedDefinition(word: string): Promise<WordDefinition | null> {
    return this.wordRepo.getCachedDefinition(word);
  }

  async clearCachedDefinition(word: string): Promise<void> {
    return this.wordRepo.clearCachedDefinition(word);
  }

  async getAllDefinitions(): Promise<DefinitionCacheRow[]> {
    return this.wordRepo.getAllDefinitions();
  }

  // ==================== VIGNETTE CACHE OPERATIONS ====================

  private async migrateVignetteCacheToItems(): Promise<void> {
    return this.vignetteCacheRepo.migrateVignetteCacheToItems();
  }

  async upsertVignetteCache(word: string, vignette: string): Promise<void> {
    const vignetteHash = hashToUint32(vignette);
    return this.vignetteCacheRepo.cacheVignetteItem(word, vignette, vignetteHash);
  }

  async cacheVignetteItem(word: string, vignette: string, vignetteHash: number): Promise<void> {
    return this.vignetteCacheRepo.cacheVignetteItem(word, vignette, vignetteHash);
  }

  async getCachedVignette(word: string): Promise<string> {
    return this.vignetteCacheRepo.getCachedVignette(word);
  }

  async getCachedVignetteItems(word: string): Promise<VignetteCacheItemRow[]> {
    return this.vignetteCacheRepo.getCachedVignetteItems(word);
  }

  async getVignetteVariantCount(word: string): Promise<number> {
    return this.vignetteCacheRepo.getVignetteVariantCount(word);
  }

  async getVignetteCacheStats(): Promise<VignetteCacheStats> {
    return this.vignetteCacheRepo.getVignetteCacheStats();
  }

  async pruneVignetteCache(maxBytes: number, maxEntries: number): Promise<number> {
    return this.vignetteCacheRepo.pruneVignetteCache(maxBytes, maxEntries);
  }

  async clearVignetteCache(): Promise<void> {
    return this.vignetteCacheRepo.clearVignetteCache();
  }

  // ==================== REVIEW EVENT OPERATIONS ====================

  async insertReviewEvent(
    id: string,
    wordId: number,
    rating: number,
    timestamp: number,
    prevStateJson: string,
    newStateJson: string,
    errorTag: string = '',
    reflection: string = '',
    scheduledDays: number = 0
  ): Promise<string> {
    return this.reviewEventRepo.insertReviewEvent(id, wordId, rating, timestamp, prevStateJson, newStateJson, errorTag, reflection, scheduledDays);
  }

  async insertReviewEvents(events: ReviewEventRow[]): Promise<number> {
    return this.reviewEventRepo.insertReviewEvents(events);
  }

  async getReviewEventsAfter(timestampMs: number, limit: number = 5000): Promise<ReviewEventRow[]> {
    return this.reviewEventRepo.getReviewEventsAfter(timestampMs, limit);
  }

  async getUniqueReviewedWordCountBetween(startMs: number, endMs: number): Promise<number> {
    return this.reviewEventRepo.getUniqueReviewedWordCountBetween(startMs, endMs);
  }

  async getRecentReviewEvents(limit: number = 5000): Promise<ReviewEventRow[]> {
    return this.reviewEventRepo.getRecentReviewEvents(limit);
  }

  async deleteReviewEvent(id: string): Promise<void> {
    return this.reviewEventRepo.deleteReviewEvent(id);
  }

  async deleteReviewEventsOlderThan(timestampMs: number): Promise<number> {
    return this.reviewEventRepo.deleteReviewEventsOlderThan(timestampMs);
  }

  async getReviewEventCount(): Promise<number> {
    return this.reviewEventRepo.getReviewEventCount();
  }

  async pruneAllWordHistory(): Promise<number> {
    return this.wordRepo.pruneAllHistory();
  }

  async getTotalHistoryCount(): Promise<number> {
    return this.wordRepo.getTotalHistoryCount();
  }

  async getHeatmapDailyStats(startMs: number, endMs: number): Promise<HeatmapDailyStats[]> {
    const timezoneOffsetMs = -new Date().getTimezoneOffset() * 60 * 1000;
    const aggregates: ReviewDailyAggregateRow[] = await this.reviewEventRepo.getReviewDailyAggregates(
      startMs,
      endMs,
      timezoneOffsetMs
    );
    const newRows: ReviewDailyNewWordRow[] = await this.reviewEventRepo.getNewWordCountsByDay(
      startMs,
      endMs,
      timezoneOffsetMs
    );
    const newMap: Map<number, number> = new Map();
    for (const row of newRows) {
      newMap.set(row.dayKey, row.newCount);
    }
    const dayMs = 24 * 60 * 60 * 1000;
    const stats: HeatmapDailyStats[] = [];
    for (const row of aggregates) {
      const newCount = newMap.get(row.dayKey) ?? 0;
      const reviewCount = Math.max(0, row.wordCount - newCount);
      const totalReviews = row.againCount + row.hardCount + row.goodCount + row.easyCount;
      const durationMs = row.lastTs >= row.firstTs ? row.lastTs - row.firstTs : 0;
      stats.push({
        dateMs: row.dayKey * dayMs - timezoneOffsetMs,
        knownCount: row.goodCount + row.easyCount,
        fuzzyCount: row.hardCount,
        forgottenCount: row.againCount,
        newCount: newCount,
        reviewCount: reviewCount,
        durationMs: durationMs,
        totalReviews: totalReviews
      });
    }
    return stats;
  }

  // ==================== NOTEBOOK OPERATIONS ====================
  // Keeping this here for now as requested, but should be moved to WordBookRepo in future.
  
  async getNotebookWords(): Promise<string[]> {
    this.ensureInitialized();
    const columns: string[] = ['word'];
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_NOTEBOOK_WORDS);
    const resultSet = await this.store!.query(predicates, columns);
    const out: string[] = [];
    while (resultSet.goToNextRow()) {
      const word = resultSet.getString(resultSet.getColumnIndex('word'));
      if (word.length > 0) {
        out.push(word);
      }
    }
    resultSet.close();
    return out;
  }

  async getNotebookWordsWithTime(): Promise<NotebookWordEntry[]> {
    this.ensureInitialized();
    const columns: string[] = ['word', 'created_at'];
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_NOTEBOOK_WORDS);
    const resultSet = await this.store!.query(predicates, columns);
    const out: NotebookWordEntry[] = [];
    while (resultSet.goToNextRow()) {
      const word = resultSet.getString(resultSet.getColumnIndex('word'));
      const createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
      if (word.length > 0) {
        const entry: NotebookWordEntry = { word: word, createdAt: createdAt };
        out.push(entry);
      }
    }
    resultSet.close();
    return out;
  }

  async isWordInNotebook(word: string): Promise<boolean> {
    this.ensureInitialized();
    const normalized = word.trim().toLowerCase();
    if (normalized.length === 0) {
      return false;
    }
    const columns: string[] = ['word'];
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_NOTEBOOK_WORDS);
    predicates.equalTo('word', normalized);
    predicates.limitAs(1);
    const resultSet = await this.store!.query(predicates, columns);
    const exists = resultSet.goToNextRow();
    resultSet.close();
    return exists;
  }

  async addWordToNotebook(word: string): Promise<void> {
    this.ensureInitialized();
    const normalized = word.trim().toLowerCase();
    if (normalized.length === 0) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = {
      'word': normalized,
      'created_at': Date.now()
    };
    try {
      await this.store!.insert(TABLE_USER_NOTEBOOK_WORDS, bucket);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.includes('UNIQUE constraint failed')) {
        return;
      }
      if (e instanceof Error) {
        throw e;
      } else {
        throw new Error(String(e));
      }
    }
  }

  async removeWordFromNotebook(word: string): Promise<void> {
    this.ensureInitialized();
    const normalized = word.trim().toLowerCase();
    if (normalized.length === 0) {
      return;
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_NOTEBOOK_WORDS);
    predicates.equalTo('word', normalized);
    await this.store!.delete(predicates);
  }

  // ==================== WORD BOOK OPERATIONS ====================

  async getUserWordBooks(): Promise<UserWordBook[]> {
    return this.wordBookRepo.getUserWordBooks();
  }

  async getUserWordBookById(bookId: string): Promise<UserWordBook | null> {
    return this.wordBookRepo.getUserWordBookById(bookId);
  }

  async getUserWordBookWordCount(bookId: string): Promise<number> {
    return this.wordBookRepo.getUserWordBookWordCount(bookId);
  }

  async createUserWordBook(name: string, description: string = '', category: string = '其他', difficulty: string = '初级', coverColor: string = '', icon: string = '📓'): Promise<string> {
    return this.wordBookRepo.createUserWordBook(name, description, category, difficulty, coverColor, icon);
  }

  async deleteUserWordBook(bookId: string): Promise<void> {
    return this.wordBookRepo.deleteUserWordBook(bookId);
  }

  async updateUserWordBook(book: UserWordBook): Promise<void> {
    return this.wordBookRepo.updateUserWordBook(book);
  }

  async addWordToUserWordBook(bookId: string, wordStr: string): Promise<AddToUserWordBookOutcome> {
    return this.wordBookRepo.addWordToUserWordBook(bookId, wordStr);
  }

  async removeWordFromUserWordBook(bookId: string, wordStr: string): Promise<void> {
    return this.wordBookRepo.removeWordFromUserWordBook(bookId, wordStr);
  }

  async getDailyActivity(limit: number): Promise<DailyActivity[]> {
    return this.wordBookRepo.getDailyActivity(limit);
  }

  private async migrateSystemWordBookMembership(): Promise<void> {
    return this.wordBookRepo.migrateSystemWordBookMembership();
  }

  async addWordToSystemWordBook(bookId: string, wordStr: string): Promise<void> {
    return this.wordBookRepo.addWordToSystemWordBook(bookId, wordStr);
  }

  async getSystemWordBookWordsPaged(
    bookId: string,
    limit: number,
    offset: number,
    sortType: string = 'default',
    sortDirection: string = 'asc'
  ): Promise<WordItem[]> {
    return this.wordBookRepo.getSystemWordBookWordsPaged(bookId, limit, offset, sortType, sortDirection);
  }

  async getUserWordBookWordsPaged(
    bookId: string,
    limit: number,
    offset: number,
    sortType: string = 'default',
    sortDirection: string = 'asc'
  ): Promise<WordItem[]> {
    return this.wordBookRepo.getUserWordBookWordsPaged(bookId, limit, offset, sortType, sortDirection);
  }

  async getReviewQueueBySystemWordBook(bookId: string): Promise<WordItem[]> {
    return this.wordBookRepo.getReviewQueueBySystemWordBook(bookId);
  }

  async getNewWordsQueueBySystemWordBook(bookId: string, limit: number): Promise<WordItem[]> {
    return this.wordBookRepo.getNewWordsQueueBySystemWordBook(bookId, limit);
  }

  async getAllBookCounts(): Promise<Map<string, number>> {
    return this.wordBookRepo.getAllBookCounts();
  }

  async getBookProgress(bookId: string, isSystem: boolean): Promise<BookProgress> {
    return this.wordBookRepo.getBookProgress(bookId, isSystem);
  }

  async getSupportWords(targetWord: string, limit: number): Promise<WordItem[]> {
    return this.wordRepo.getSupportWords(targetWord, limit);
  }

  async getUserWordBooksContainingWord(word: string): Promise<UserWordBookBrief[]> {
    return this.wordBookRepo.getUserWordBooksContainingWord(word);
  }

  async getSystemWordBookWordCount(bookId: string): Promise<number> {
    return this.wordBookRepo.getSystemWordBookWordCount(bookId);
  }

  async getLearningQueueByBook(bookId: string, limit: number): Promise<WordItem[]> {
    return this.wordBookRepo.getLearningQueueByBook(bookId, limit);
  }

  async getLearningQueueByUserWordBook(bookId: string, limit: number): Promise<WordItem[]> {
    return this.wordBookRepo.getLearningQueueByUserWordBook(bookId, limit);
  }

  async resetBookProgress(bookId: string): Promise<void> {
    this.ensureInitialized();
    await this.wordBookRepo.resetBookProgress(bookId);
  }
}

/**
 * Mock data generator for testing
 */
export class MockDataGenerator {
  /**
   * Generate CET-4 mock words
   */
  static generateCET4Words(): WordItem[] {
    const wordList: string[] = [
      'abandon', 'ability', 'abnormal', 'aboard', 'abolish',
      'absorb', 'abstract', 'abundant', 'abuse', 'academic',
      'accelerate', 'accent', 'accept', 'access', 'accident',
      'accommodate', 'accompany', 'accomplish', 'accord', 'account',
      'accumulate', 'accurate', 'accuse', 'achieve', 'acknowledge',
      'acquire', 'adapt', 'addition', 'adequate', 'adjust',
      'administration', 'admire', 'admit', 'adopt', 'advance',
      'advantage', 'adventure', 'advertise', 'advocate', 'affect'
    ];

    const words: WordItem[] = [];
    const now = Date.now();

    for (let i = 0; i < wordList.length; i++) {
      const wordStr = wordList[i];
      const item = new WordItem(
        0,
        wordStr,
        WordStatus.NEW,
        new FSRSState(),
        new ReviewHistory(),
        new WordDefinition(),
        now,
        now,
        now,
        'cet4',
        []
      );
      words.push(item);
    }
    return words;
  }

  static generateLearnedWords(): WordItem[] {
    const wordList: string[] = [
      'benefit', 'concern', 'deliver', 'discover', 'encourage',
      'focus', 'hesitate', 'invest', 'maintain', 'obtain',
      'promote', 'recover', 'reflect', 'select', 'succeed'
    ];
    const words: WordItem[] = [];
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;

    for (let i = 0; i < wordList.length; i++) {
      const wordStr = wordList[i];
      const item = new WordItem(
        0,
        wordStr,
        WordStatus.REVIEW,
        new FSRSState(4, 7, 0.9, 3, 0),
        new ReviewHistory(),
        new WordDefinition(),
        now - dayMs,
        now - dayMs * 7,
        now,
        'cet4',
        []
      );
      words.push(item);
    }
    return words;
  }
}
