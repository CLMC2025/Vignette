// =====================================================
// DBManager.ets - RelationalStore (SQLite) Wrapper
// Handles all database operations for Vignette
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import type common from '@ohos.app.ability.common';
import {
  WordItem,
  WordStatus,
  FSRSState,
  ReviewHistory,
  WordDefinition,
  QueueItem
} from '../model/WordModel';
import { VersionControl, ChangeType } from '../sync/VersionControl';

/**
 * Database configuration
 */
const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'vignette.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

/**
 * Table names
 */
const TABLE_WORDS = 'words';
const TABLE_DEFINITIONS = 'definitions';
const TABLE_VERSION_CONTROL = 'version_control';
const TABLE_CHANGE_LOG = 'change_log';
const TABLE_REVIEW_EVENTS = 'review_events';
const TABLE_VIGNETTE_CACHE = 'vignette_cache';

/**
 * SQL statements for table creation
 */
const SQL_CREATE_WORDS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_WORDS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'NEW',
    fsrs_state TEXT NOT NULL DEFAULT '{}',
    history TEXT NOT NULL DEFAULT '[]',
    definition TEXT NOT NULL DEFAULT '{}',
    due_date INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    book_id TEXT DEFAULT '',
    tags TEXT DEFAULT '[]'
  )
`;

const SQL_CREATE_DEFINITIONS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_DEFINITIONS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL UNIQUE,
    definition TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'local',
    created_at INTEGER NOT NULL
  )
`;

const SQL_CREATE_VERSION_CONTROL = `
  CREATE TABLE IF NOT EXISTS ${TABLE_VERSION_CONTROL} (
    id INTEGER PRIMARY KEY,
    version INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    description TEXT DEFAULT ''
  )
`;

const SQL_CREATE_CHANGE_LOG = `
  CREATE TABLE IF NOT EXISTS ${TABLE_CHANGE_LOG} (
    id TEXT PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    change_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    previous_value TEXT DEFAULT '',
    new_value TEXT DEFAULT ''
  )
`;

const SQL_CREATE_REVIEW_EVENTS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_REVIEW_EVENTS} (
    id TEXT PRIMARY KEY,
    word_id INTEGER NOT NULL,
    rating INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    prev_state_json TEXT NOT NULL,
    new_state_json TEXT NOT NULL,
    error_tag TEXT DEFAULT '',
    reflection TEXT DEFAULT ''
  )
`;

const SQL_CREATE_VIGNETTE_CACHE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_VIGNETTE_CACHE} (
    word TEXT PRIMARY KEY,
    vignette TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    size_bytes INTEGER NOT NULL
  )
`;

const SQL_CREATE_INDEX_WORD = `
  CREATE INDEX IF NOT EXISTS idx_words_word ON ${TABLE_WORDS}(word)
`;

const SQL_CREATE_INDEX_STATUS = `
  CREATE INDEX IF NOT EXISTS idx_words_status ON ${TABLE_WORDS}(status)
`;

const SQL_CREATE_INDEX_DUE = `
  CREATE INDEX IF NOT EXISTS idx_words_due ON ${TABLE_WORDS}(due_date)
`;

const SQL_CREATE_INDEX_REVIEW_TS = `
  CREATE INDEX IF NOT EXISTS idx_review_events_ts ON ${TABLE_REVIEW_EVENTS}(timestamp)
`;

const SQL_CREATE_INDEX_VIGNETTE_USED = `
  CREATE INDEX IF NOT EXISTS idx_vignette_cache_used ON ${TABLE_VIGNETTE_CACHE}(last_used_at)
`;

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
}

/**
 * Column constants
 */
class WordColumns {
  static readonly ID = 'id';
  static readonly WORD = 'word';
  static readonly STATUS = 'status';
  static readonly FSRS_STATE = 'fsrs_state';
  static readonly HISTORY = 'history';
  static readonly DEFINITION = 'definition';
  static readonly DUE_DATE = 'due_date';
  static readonly CREATED_AT = 'created_at';
  static readonly UPDATED_AT = 'updated_at';
  static readonly BOOK_ID = 'book_id';
  static readonly TAGS = 'tags';
}

/**
 * Custom Error class for database errors
 */
class DBError extends Error {
  constructor(message:  string) {
    super(message);
    this.name = 'DBError';
  }
}

/**
 * Database Manager Singleton
 */
export class DBManager {
  private static instance:  DBManager | null = null;
  private store: relationalStore.RdbStore | null = null;
  private initialized:  boolean = false;

  private constructor() {}

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
      await this.createTables();
      this.initialized = true;
      console.info('[DBManager] Database initialized successfully');
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message :  String(e);
      console.error('[DBManager] Failed to initialize database:', errorMsg);
      throw new DBError(`Failed to initialize database: ${errorMsg}`);
    }
  }

  /**
   * Create tables if not exist
   */
  private async createTables(): Promise<void> {
    if (this.store === null) {
      throw new DBError('Database not initialized');
    }

    await this.store.executeSql(SQL_CREATE_WORDS);
    await this.store.executeSql(SQL_CREATE_DEFINITIONS);
    await this.store.executeSql(SQL_CREATE_VERSION_CONTROL);
    await this.store.executeSql(SQL_CREATE_CHANGE_LOG);
    await this.store.executeSql(SQL_CREATE_REVIEW_EVENTS);
    await this.store.executeSql(SQL_CREATE_VIGNETTE_CACHE);
    await this.store.executeSql(SQL_CREATE_INDEX_WORD);
    await this.store.executeSql(SQL_CREATE_INDEX_STATUS);
    await this.store.executeSql(SQL_CREATE_INDEX_DUE);
    await this.store.executeSql(SQL_CREATE_INDEX_REVIEW_TS);
    await this.store.executeSql(SQL_CREATE_INDEX_VIGNETTE_USED);
  }

  /**
   * Check if database is ready
   */
  private ensureInitialized(): void {
    if (this.store === null) {
      throw new DBError('Database not initialized.Call initialize() first.');
    }
  }

  // ==================== WORD OPERATIONS ====================

  /**
   * Insert a new word
   */
  async insertWord(word: WordItem): Promise<number> {
    this.ensureInitialized();

    const bucket = this.wordToValuesBucket(word);

    try {
      const rowId = await this.store! .insert(TABLE_WORDS, bucket);
      console.info(`[DBManager] Inserted word: ${word.word}, rowId: ${rowId}`);
      return rowId;
    } catch (e) {
      // Check for unique constraint violation
      const errorStr = e instanceof Error ?  e.message : String(e);
      if (errorStr.includes('UNIQUE constraint failed')) {
        console.warn(`[DBManager] Word already exists: ${word.word}`);
        return -1;
      }
      throw new DBError(`Insert failed: ${errorStr}`);
    }
  }

  /**
   * Insert multiple words (batch)
   */
  async insertWords(words: WordItem[]): Promise<number> {
    this.ensureInitialized();

    let insertedCount = 0;
    for (const word of words) {
      const rowId = await this.insertWord(word);
      if (rowId > 0) {
        insertedCount++;
      }
    }

    console.info(`[DBManager] Batch inserted ${insertedCount}/${words.length} words`);
    return insertedCount;
  }

  /**
   * Update an existing word
   */
  async updateWord(word: WordItem): Promise<number> {
    this.ensureInitialized();

    const bucket = this.wordToValuesBucket(word);

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.ID, word.id);

    const affectedRows = await this.store!.update(bucket, predicates);
    console.info(`[DBManager] Updated word id: ${word.id}, affected:  ${affectedRows}`);
    return affectedRows;
  }

  /**
   * Get word by ID
   */
  async getWordById(id:  number): Promise<WordItem | null> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.ID, id);

    const resultSet = await this.store!.query(predicates);

    if (resultSet.goToFirstRow()) {
      const word = this.resultSetToWord(resultSet);
      resultSet.close();
      return word;
    }

    resultSet.close();
    return null;
  }

  /**
   * Get word by word string
   */
  async getWordByWord(wordStr: string): Promise<WordItem | null> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.WORD, wordStr);

    const resultSet = await this.store!.query(predicates);

    if (resultSet.goToFirstRow()) {
      const word = this.resultSetToWord(resultSet);
      resultSet.close();
      return word;
    }

    resultSet.close();
    return null;
  }

  /**
   * Get all words
   */
  async getAllWords(): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.orderByAsc(WordColumns.WORD);

    const resultSet = await this.store!.query(predicates);
    const words:  WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    return words;
  }

  /**
   * Get words by status
   */
  async getWordsByStatus(status:  WordStatus): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.STATUS, status);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    return words;
  }

  /**
   * Get review queue (P0 priority - words due for review)
   */
  async getReviewQueue(): Promise<WordItem[]> {
    this.ensureInitialized();

    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);

    // Words that are due (due_date <= now) and not NEW or SUSPENDED
    predicates.notEqualTo(WordColumns.STATUS, WordStatus.NEW)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.SUSPENDED)
      .and()
      .lessThanOrEqualTo(WordColumns.DUE_DATE, now)
      .orderByAsc(WordColumns.DUE_DATE);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    console.info(`[DBManager] Review queue count: ${words.length}`);
    return words;
  }

  /**
   * Get review queue filtered by book
   */
  async getReviewQueueByBook(bookId: string): Promise<WordItem[]> {
    this.ensureInitialized();

    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);

    predicates.equalTo(WordColumns.BOOK_ID, bookId)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.NEW)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.SUSPENDED)
      .and()
      .lessThanOrEqualTo(WordColumns.DUE_DATE, now)
      .orderByAsc(WordColumns.DUE_DATE);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    console.info(`[DBManager] Review queue count for book ${bookId}: ${words.length}`);
    return words;
  }

  /**
   * Get new words queue (P1 priority)
   * @param limit Maximum number of new words to return
   */
  async getNewWordsQueue(limit:  number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.STATUS, WordStatus.NEW)
      .orderByAsc(WordColumns.CREATED_AT)
      .limitAs(limit);

    const resultSet = await this.store!.query(predicates);
    const words:  WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    console.info(`[DBManager] New words queue count: ${words.length}`);
    return words;
  }

  /**
   * Get new words queue filtered by book
   */
  async getNewWordsQueueByBook(bookId: string, limit: number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.BOOK_ID, bookId)
      .and()
      .equalTo(WordColumns.STATUS, WordStatus.NEW)
      .orderByAsc(WordColumns.CREATED_AT)
      .limitAs(limit);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    console.info(`[DBManager] New words queue count for book ${bookId}: ${words.length}`);
    return words;
  }

  /**
   * Get combined learning queue (Review + New)
   */
  async getLearningQueue(dailyNewLimit: number): Promise<QueueItem[]> {
    const queue: QueueItem[] = [];

    // P0: Review words (due)
    const reviewWords = await this.getReviewQueue();
    for (const word of reviewWords) {
      queue.push(new QueueItem(word, 0));
    }

    // P1: New words
    const newWords = await this.getNewWordsQueue(dailyNewLimit);
    for (const word of newWords) {
      queue.push(new QueueItem(word, 1));
    }

    return queue;
  }

  /**
   * Get combined learning queue (Review + New) filtered by book
   */
  async getLearningQueueByBook(bookId: string, dailyNewLimit: number): Promise<QueueItem[]> {
    if (bookId.trim().length === 0) {
      return this.getLearningQueue(dailyNewLimit);
    }

    const queue: QueueItem[] = [];
    const reviewWords = await this.getReviewQueueByBook(bookId);
    for (const word of reviewWords) {
      queue.push(new QueueItem(word, 0));
    }

    const newWords = await this.getNewWordsQueueByBook(bookId, dailyNewLimit);
    for (const word of newWords) {
      queue.push(new QueueItem(word, 1));
    }

    return queue;
  }

  /**
   * Get support words for story generation (MASTERED or REVIEW)
   */
  async getSupportWords(excludeWord:  string, limit: number = 3): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.WORD, excludeWord)
      .and()
      .beginWrap()
      .equalTo(WordColumns.STATUS, WordStatus.MASTERED)
      .or()
      .equalTo(WordColumns.STATUS, WordStatus.REVIEW)
      .endWrap()
      .orderByDesc(WordColumns.UPDATED_AT)
      .limitAs(limit);

    const resultSet = await this.store!.query(predicates);
    const words:  WordItem[] = [];

    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }

    resultSet.close();
    return words;
  }

  /**
   * Get word counts by status
   */
  async getWordCounts(): Promise<Map<WordStatus, number>> {
    this.ensureInitialized();

    const counts = new Map<WordStatus, number>();
    const statuses:  WordStatus[] = [
      WordStatus.NEW,
      WordStatus.LEARNING,
      WordStatus.REVIEW,
      WordStatus.MASTERED,
      WordStatus.SUSPENDED
    ];

    for (const status of statuses) {
      const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
      predicates.equalTo(WordColumns.STATUS, status);

      const resultSet = await this.store!.query(predicates);
      let count = 0;
      while (resultSet.goToNextRow()) {
        count++;
      }
      resultSet.close();
      counts.set(status, count);
    }

    return counts;
  }

  /**
   * Get review due count
   */
  async getReviewDueCount(): Promise<number> {
    this.ensureInitialized();

    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.STATUS, WordStatus.NEW)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.SUSPENDED)
      .and()
      .lessThanOrEqualTo(WordColumns.DUE_DATE, now);

    const resultSet = await this.store!.query(predicates);
    let count = 0;
    while (resultSet.goToNextRow()) {
      count++;
    }
    resultSet.close();

    return count;
  }

  /**
   * Delete word by ID
   */
  async deleteWord(id: number): Promise<number> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.ID, id);

    const affectedRows = await this.store!.delete(predicates);
    return affectedRows;
  }

  /**
   * Delete all words
   */
  async deleteAllWords(): Promise<number> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    const affectedRows = await this.store! .delete(predicates);
    return affectedRows;
  }

  // ==================== DEFINITION CACHE OPERATIONS ====================

  /**
   * Cache a word definition
   */
  async cacheDefinition(word: string, definition: WordDefinition): Promise<void> {
    this.ensureInitialized();

    const bucket:  relationalStore.ValuesBucket = {
      'word': word,
      'definition': definition.toJSON(),
      'source': definition.source,
      'created_at':  Date.now()
    };

    try {
      await this.store!.insert(TABLE_DEFINITIONS, bucket);
    } catch (e) {
      // Update if exists
      const predicates = new relationalStore.RdbPredicates(TABLE_DEFINITIONS);
      predicates.equalTo('word', word);
      await this.store!.update(bucket, predicates);
    }
  }

  /**
   * Get cached definition
   */
  async getCachedDefinition(word: string): Promise<WordDefinition | null> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_DEFINITIONS);
    predicates.equalTo('word', word);

    const resultSet = await this.store!.query(predicates);

    if (resultSet.goToFirstRow()) {
      const defJson = resultSet.getString(resultSet.getColumnIndex('definition'));
      resultSet.close();
      const definition = WordDefinition.fromJSON(defJson);
      definition.source = 'db';
      return definition;
    }

    resultSet.close();
    return null;
  }

  // ==================== HELPER METHODS ====================

  /**
   * Convert WordItem to ValuesBucket
   */
  private wordToValuesBucket(word: WordItem): relationalStore.ValuesBucket {
    return {
      'word': word.word,
      'status':  word.status,
      'fsrs_state': word.fsrsState.toJSON(),
      'history': word.history.toJSON(),
      'definition': word.definition.toJSON(),
      'due_date': word.dueDate,
      'created_at':  word.createdAt,
      'updated_at': word.updatedAt,
      'book_id': word.bookId,
      'tags': JSON.stringify(word.tags)
    };
  }

  /**
   * Convert ResultSet row to WordItem
   */
  private resultSetToWord(resultSet: relationalStore.ResultSet): WordItem {
    const id = resultSet.getLong(resultSet.getColumnIndex(WordColumns.ID));
    const wordStr = resultSet.getString(resultSet.getColumnIndex(WordColumns.WORD));
    const status = resultSet.getString(resultSet.getColumnIndex(WordColumns.STATUS)) as WordStatus;
    const fsrsJson = resultSet.getString(resultSet.getColumnIndex(WordColumns.FSRS_STATE));
    const historyJson = resultSet.getString(resultSet.getColumnIndex(WordColumns.HISTORY));
    const defJson = resultSet.getString(resultSet.getColumnIndex(WordColumns.DEFINITION));
    const dueDate = resultSet.getLong(resultSet.getColumnIndex(WordColumns.DUE_DATE));
    const createdAt = resultSet.getLong(resultSet.getColumnIndex(WordColumns.CREATED_AT));
    const updatedAt = resultSet.getLong(resultSet.getColumnIndex(WordColumns.UPDATED_AT));
    const bookId = resultSet.getString(resultSet.getColumnIndex(WordColumns.BOOK_ID));
    const tagsJson = resultSet.getString(resultSet.getColumnIndex(WordColumns.TAGS));

    let tags: string[] = [];
    try {
      tags = JSON.parse(tagsJson) as string[];
    } catch (e) {
      tags = [];
    }

    return new WordItem(
      id,
      wordStr,
      status,
      FSRSState.fromJSON(fsrsJson),
      ReviewHistory.fromJSON(historyJson),
      WordDefinition.fromJSON(defJson),
      dueDate,
      createdAt,
      updatedAt,
      bookId,
      tags
    );
  }

  // ==================== VERSION CONTROL OPERATIONS ====================

  /**
   * 获取当前版本控制信息
   */
  async getVersionControl(): Promise<VersionControl> {
    this.ensureInitialized();

    const vc = new VersionControl();

    try {
      // 获取版本信息
      const predicates = new relationalStore.RdbPredicates(TABLE_VERSION_CONTROL);
      predicates.equalTo('id', 1);

      const resultSet = await this.store!.query(predicates);
      if (resultSet.goToFirstRow()) {
        const version = resultSet.getLong(resultSet.getColumnIndex('version'));
        const timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
        const description = resultSet.getString(resultSet.getColumnIndex('description'));

        vc.getCurrentVersion().version = version;
        vc.getCurrentVersion().timestamp = timestamp;
        vc.getCurrentVersion().description = description;
      }
      resultSet.close();

      // 获取变更日志
      const logPredicates = new relationalStore.RdbPredicates(TABLE_CHANGE_LOG);
      logPredicates.orderByDesc('timestamp');
      logPredicates.limitAs(1000);

      const logResultSet = await this.store!.query(logPredicates);
      while (logResultSet.goToNextRow()) {
        const id = logResultSet.getString(logResultSet.getColumnIndex('id'));
        const timestamp = logResultSet.getLong(logResultSet.getColumnIndex('timestamp'));
        const changeType = logResultSet.getString(logResultSet.getColumnIndex('change_type'));
        const entityType = logResultSet.getString(logResultSet.getColumnIndex('entity_type'));
        const entityId = logResultSet.getLong(logResultSet.getColumnIndex('entity_id'));
        const description = logResultSet.getString(logResultSet.getColumnIndex('description'));
        const previousValue = logResultSet.getString(logResultSet.getColumnIndex('previous_value'));
        const newValue = logResultSet.getString(logResultSet.getColumnIndex('new_value'));

        vc.recordChange(
          changeType as ChangeType,
          entityType,
          entityId,
          description,
          previousValue,
          newValue
        );
      }
      logResultSet.close();
    } catch (e) {
      console.warn('[DBManager] Failed to load version control:', e);
    }

    return vc;
  }

  /**
   * 保存版本控制信息
   */
  async saveVersionControl(vc: VersionControl): Promise<void> {
    this.ensureInitialized();

    try {
      // 保存版本信息
      const versionInfo = vc.getCurrentVersion();
      const versionBucket: relationalStore.ValuesBucket = {
        'id': 1,
        'version': versionInfo.version,
        'timestamp': versionInfo.timestamp,
        'description': versionInfo.description
      };

      const versionPredicates = new relationalStore.RdbPredicates(TABLE_VERSION_CONTROL);
      versionPredicates.equalTo('id', 1);

      await this.store!.update(versionBucket, versionPredicates);

      // 保存变更日志
      const changeLog = vc.getChangeLog();
      for (const entry of changeLog) {
        const logBucket: relationalStore.ValuesBucket = {
          'id': entry.id,
          'timestamp': entry.timestamp,
          'change_type': entry.changeType,
          'entity_type': entry.entityType,
          'entity_id': entry.entityId,
          'description': entry.description,
          'previous_value': entry.previousValue,
          'new_value': entry.newValue
        };

        try {
          await this.store!.insert(TABLE_CHANGE_LOG, logBucket);
        } catch (e) {
          // 如果已存在，更新
          const logPredicates = new relationalStore.RdbPredicates(TABLE_CHANGE_LOG);
          logPredicates.equalTo('id', entry.id);
          await this.store!.update(logBucket, logPredicates);
        }
      }
    } catch (e) {
      console.error('[DBManager] Failed to save version control:', e);
    }
  }

  /**
   * Get cached vignette for a word
   */
  async getCachedVignette(word: string): Promise<string> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE);
    predicates.equalTo('word', word);
    const rs = await this.store!.query(predicates, ['word', 'vignette', 'created_at', 'last_used_at', 'size_bytes']);
    let vignette = '';
    if (rs.goToFirstRow()) {
      vignette = rs.getString(rs.getColumnIndex('vignette'));
    }
    rs.close();

    if (vignette.length > 0) {
      // touch
      const bucket: relationalStore.ValuesBucket = {
        'last_used_at': Date.now()
      };
      await this.store!.update(bucket, predicates);
    }
    return vignette;
  }

  /**
   * Upsert vignette cache
   */
  async upsertVignetteCache(word: string, vignette: string): Promise<void> {
    this.ensureInitialized();

    const now = Date.now();
    const sizeBytes = vignette.length;
    const bucket: relationalStore.ValuesBucket = {
      'word': word,
      'vignette': vignette,
      'created_at': now,
      'last_used_at': now,
      'size_bytes': sizeBytes
    };

    try {
      await this.store!.insert(TABLE_VIGNETTE_CACHE, bucket);
    } catch (e) {
      // update if exists
      const pred = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE);
      pred.equalTo('word', word);
      const updateBucket: relationalStore.ValuesBucket = {
        'vignette': vignette,
        'last_used_at': now,
        'size_bytes': sizeBytes
      };
      await this.store!.update(updateBucket, pred);
    }
  }

  /**
   * Prune vignette cache based on size and entry limits
   */
  async pruneVignetteCache(maxBytes: number, maxEntries: number): Promise<void> {
    this.ensureInitialized();
    if (maxBytes <= 0 || maxEntries <= 0) return;

    // 定义VignetteCacheItem接口
    interface VignetteCacheItem {
      word: string;
      size: number;
      used: number;
    }

    // Count total and sum size (fallback approach without aggregate functions)
    const rs = await this.store!.query(new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE), ['word', 'size_bytes', 'last_used_at']);
    const items: VignetteCacheItem[] = [];
    let totalBytes = 0;
    while (rs.goToNextRow()) {
      const w = rs.getString(rs.getColumnIndex('word'));
      const s = rs.getLong(rs.getColumnIndex('size_bytes')) as number;
      const u = rs.getLong(rs.getColumnIndex('last_used_at')) as number;
      items.push({ word: w, size: s, used: u } as VignetteCacheItem);
      totalBytes += s;
    }
    rs.close();

    // Remove least recently used
    items.sort((a, b) => a.used - b.used);
    let idx = 0;
    while ((items.length - idx) > maxEntries || totalBytes > maxBytes) {
      const it = items[idx];
      idx++;
      const pred = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE);
      pred.equalTo('word', it.word);
      await this.store!.delete(pred);
      totalBytes -= it.size;
      if (idx >= items.length) break;
    }
  }

  // ==================== REVIEW EVENT OPERATIONS ====================

  private generateEventId(): string {
    return `rev_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
  }

  async addReviewEvent(
    wordId: number,
    rating: number,
    timestamp: number,
    prevStateJson: string,
    newStateJson: string,
    errorTag: string = '',
    reflection: string = ''
  ): Promise<string> {
    this.ensureInitialized();

    const id = this.generateEventId();
    const bucket: relationalStore.ValuesBucket = {
      'id': id,
      'word_id': wordId,
      'rating': rating,
      'timestamp': timestamp,
      'prev_state_json': prevStateJson,
      'new_state_json': newStateJson,
      'error_tag': errorTag,
      'reflection': reflection
    };

    try {
      await this.store!.insert(TABLE_REVIEW_EVENTS, bucket);
      return id;
    } catch (e) {
      const err = e instanceof Error ? e.message : String(e);
      throw new DBError(`Insert review event failed: ${err}`);
    }
  }

  async insertReviewEvents(events: ReviewEventRow[]): Promise<number> {
    this.ensureInitialized();
    if (events.length === 0) return 0;

    let inserted = 0;
    for (const e of events) {
      const bucket: relationalStore.ValuesBucket = {
        'id': e.id,
        'word_id': e.wordId,
        'rating': e.rating,
        'timestamp': e.timestamp,
        'prev_state_json': e.prevStateJson,
        'new_state_json': e.newStateJson,
        'error_tag': e.errorTag,
        'reflection': e.reflection
      };

      try {
        await this.store!.insert(TABLE_REVIEW_EVENTS, bucket);
        inserted++;
      } catch (err) {
        // Ignore duplicates by primary key
        const msg = err instanceof Error ? err.message : String(err);
        if (msg.includes('UNIQUE constraint failed') || msg.includes('PRIMARY KEY')) {
          continue;
        }
      }
    }
    return inserted;
  }

  async getReviewEventsAfter(timestampMs: number, limit: number = 5000): Promise<ReviewEventRow[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_REVIEW_EVENTS);
    predicates.greaterThan('timestamp', timestampMs);
    predicates.orderByAsc('timestamp');
    predicates.limitAs(limit);

    const columns: string[] = ['id', 'word_id', 'rating', 'timestamp', 'prev_state_json', 'new_state_json', 'error_tag', 'reflection'];

    const resultSet = await this.store!.query(predicates, columns);
    const out: ReviewEventRow[] = [];

    while (resultSet.goToNextRow()) {
      const row: ReviewEventRow = {
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        wordId: resultSet.getLong(resultSet.getColumnIndex('word_id')) as number,
        rating: resultSet.getLong(resultSet.getColumnIndex('rating')) as number,
        timestamp: resultSet.getLong(resultSet.getColumnIndex('timestamp')) as number,
        prevStateJson: resultSet.getString(resultSet.getColumnIndex('prev_state_json')),
        newStateJson: resultSet.getString(resultSet.getColumnIndex('new_state_json')),
        errorTag: resultSet.getString(resultSet.getColumnIndex('error_tag')),
        reflection: resultSet.getString(resultSet.getColumnIndex('reflection'))
      };
      out.push(row);
    }
    resultSet.close();
    return out;
  }

  async getUniqueReviewedWordCountBetween(startMs: number, endMs: number): Promise<number> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_REVIEW_EVENTS);
    predicates.greaterThanOrEqualTo('timestamp', startMs);
    predicates.and();
    predicates.lessThanOrEqualTo('timestamp', endMs);

    const columns: string[] = ['word_id'];
    const resultSet = await this.store!.query(predicates, columns);
    const uniqueWordIds: Set<number> = new Set<number>();

    while (resultSet.goToNextRow()) {
      const wordId = resultSet.getLong(resultSet.getColumnIndex('word_id')) as number;
      uniqueWordIds.add(wordId);
    }

    resultSet.close();
    return uniqueWordIds.size;
  }

  async getRecentReviewEvents(limit: number = 5000): Promise<ReviewEventRow[]> {
    return this.getReviewEventsAfter(0, limit);
  }

  /**
   * Close database connection
   */
  async close(): Promise<void> {
    if (this.store !== null) {
      this.store = null;
      this.initialized = false;
      console.info('[DBManager] Database closed');
    }
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
      const word = new WordItem(
        0, // ID will be assigned by DB
        wordList[i],
        WordStatus.NEW,
        new FSRSState(),
        new ReviewHistory(),
        new WordDefinition(wordList[i], '', '', '', [], 'local'),
        now,
        now,
        now,
        'CET4',
        []
      );
      words.push(word);
    }

    return words;
  }

  /**
   * Generate some pre-learned words for testing support words
   */
  static generateLearnedWords(): WordItem[] {
    const wordList: string[] = ['happy', 'study', 'learn', 'book', 'friend'];
    const words: WordItem[] = [];
    const now = Date.now();

    for (let i = 0; i < wordList.length; i++) {
      const state = new FSRSState(4.5, 7.0, 0.95, 3, 0);
      const word = new WordItem(
        0,
        wordList[i],
        WordStatus.REVIEW,
        state,
        new ReviewHistory(),
        new WordDefinition(wordList[i], '', '', '', [], 'local'),
        now + (i + 1) * 24 * 60 * 60 * 1000, // Due in future
        now - 7 * 24 * 60 * 60 * 1000,
        now,
        'Basic',
        []
      );
      words.push(word);
    }

    return words;
  }
}
