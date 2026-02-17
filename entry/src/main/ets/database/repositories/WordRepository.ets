// =====================================================
// WordRepository.ets
// CRUD for words and definitions
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { DBError, TABLE_WORDS, TABLE_DEFINITIONS, WordColumns } from '../DBConstants';
import { WordItem, WordStatus, WordDefinition, FSRSState, ReviewHistory, normalizeWordStatus } from '../../model/WordModel';
import { isUniqueConstraintErrorMessage } from '../../utils/DatabaseErrorUtil';

export class WordRepository extends BaseRepository {

  /**
   * Insert a new word
   */
  async insertWord(word: WordItem): Promise<number> {
    this.ensureInitialized();

    if (word.word.trim().length === 0) {
      throw new DBError('Insert failed: invalid word');
    }

    const bucket = this.wordToValuesBucket(word);

    try {
      const rowId = await this.store!.insert(TABLE_WORDS, bucket);
      console.info(`[WordRepository] Inserted word: ${word.word}, rowId: ${rowId}`);
      return rowId;
    } catch (e) {
      const errorStr = e instanceof Error ? e.message : String(e);
      if (isUniqueConstraintErrorMessage(errorStr)) {
        console.warn(`[WordRepository] Word already exists: ${word.word}`);
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
    if (words.length === 0) {
      return insertedCount;
    }

    await this.store!.executeSql('BEGIN TRANSACTION');
    try {
      for (const word of words) {
        const rowId = await this.insertWord(word);
        if (rowId > 0) {
          insertedCount++;
        }
      }
      await this.store!.executeSql('COMMIT');
      console.info(`[WordRepository] Batch inserted ${insertedCount}/${words.length} words`);
      return insertedCount;
    } catch (e) {
      await this.store!.executeSql('ROLLBACK');
      throw new DBError(`Batch insert failed: ${e instanceof Error ? e.message : String(e)}`);
    }
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
    console.info(`[WordRepository] Updated word id: ${word.id}, affected: ${affectedRows}`);
    return affectedRows;
  }

  /**
   * Get word by ID
   */
  async getWordById(id: number): Promise<WordItem | null> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.ID, id);

    const resultSet = await this.store!.query(predicates);

    try {
      if (resultSet.goToFirstRow()) {
        const word = this.resultSetToWord(resultSet);
        return word;
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get word by word string
   */
  async getWordByWord(wordStr: string): Promise<WordItem | null> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.WORD, wordStr);

    const resultSet = await this.store!.query(predicates);

    try {
      if (resultSet.goToFirstRow()) {
        const word = this.resultSetToWord(resultSet);
        return word;
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get all words
   */
  async getAllWords(): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.orderByAsc(WordColumns.WORD);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  /**
   * Get words by status
   */
  async getWordsByStatus(status: WordStatus): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.equalTo(WordColumns.STATUS, status);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  /**
   * Get word counts by status
   */
  async getWordCounts(): Promise<Map<WordStatus, number>> {
    this.ensureInitialized();

    const counts = new Map<WordStatus, number>();
    const statuses: WordStatus[] = [
      WordStatus.NEW,
      WordStatus.LEARNING,
      WordStatus.REVIEW,
      WordStatus.RELEARNING,
      WordStatus.KNOWN
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
      .notEqualTo(WordColumns.STATUS, WordStatus.KNOWN)
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
    const affectedRows = await this.store!.delete(predicates);
    return affectedRows;
  }

  /**
   * Get pending reviews
   */
  async getPendingReviews(limit: number, excludeWord: string): Promise<WordItem[]> {
    this.ensureInitialized();

    const now = Date.now();
    // 5 minutes cooldown to prevent same word appearing immediately if skipped
    const cooldownMs = 5 * 60 * 1000;
    const cutoffUpdatedAt = now - cooldownMs;

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.WORD, excludeWord)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.NEW)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.KNOWN)
      .and()
      .lessThanOrEqualTo(WordColumns.DUE_DATE, now)
      .and()
      .lessThanOrEqualTo(WordColumns.UPDATED_AT, cutoffUpdatedAt)
      .orderByAsc(WordColumns.DUE_DATE)
      .limitAs(limit);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  /**
   * Get new words
   */
  async getNewWords(limit: number, excludeWord: string): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.WORD, excludeWord)
      .and()
      .equalTo(WordColumns.STATUS, WordStatus.NEW)
      .orderByAsc(WordColumns.ID) // FIFO
      .limitAs(limit);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  /**
   * Get learning/relearning words
   */
  async getLearningWords(limit: number, excludeWord: string): Promise<WordItem[]> {
    this.ensureInitialized();

    const now = Date.now();
    // 1 minute cooldown for learning steps
    const cooldownMs = 60 * 1000;
    
    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.WORD, excludeWord)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.KNOWN)
      .and()
      .beginWrap()
      .equalTo(WordColumns.STATUS, WordStatus.LEARNING)
      .or()
      .equalTo(WordColumns.STATUS, WordStatus.RELEARNING)
      .endWrap()
      .orderByAsc(WordColumns.DUE_DATE)
      .limitAs(limit);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  /**
   * Get support words (words that are not the target word, preferably learned)
   */
  async getSupportWords(targetWord: string, limit: number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.WORD, targetWord)
      .and()
      .notEqualTo(WordColumns.STATUS, WordStatus.NEW) // Prefer learned words
      .limitAs(limit * 2); // Fetch more and shuffle in memory if needed, or just take first few

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }

    // Shuffle and pick limit
    for (let i = words.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = words[i];
      words[i] = words[j];
      words[j] = tmp;
    }
    return words.slice(0, limit);
  }

  // ==================== DEFINITION CACHE OPERATIONS ====================

  /**
   * Cache a word definition
   */
  async cacheDefinition(word: string, definition: WordDefinition): Promise<void> {
    this.ensureInitialized();

    const normalizedWord = word.toLowerCase().trim();
    const bucket: relationalStore.ValuesBucket = {
      'word': normalizedWord,
      'definition': definition.toJSON(),
      'source': definition.source,
      'created_at': Date.now()
    };

    try {
      await this.store!.insert(TABLE_DEFINITIONS, bucket);
    } catch (e) {
      // Update if exists
      const predicates = new relationalStore.RdbPredicates(TABLE_DEFINITIONS);
      predicates.equalTo('word', normalizedWord);
      await this.store!.update(bucket, predicates);
    }
  }

  /**
   * Get cached definition
   */
  async getCachedDefinition(word: string): Promise<WordDefinition | null> {
    this.ensureInitialized();

    const normalizedWord = word.toLowerCase().trim();
    const predicates = new relationalStore.RdbPredicates(TABLE_DEFINITIONS);
    predicates.equalTo('word', normalizedWord);

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

  /**
   * Clear cached definition
   */
  async clearCachedDefinition(word: string): Promise<void> {
    this.ensureInitialized();

    const normalizedWord = word.toLowerCase().trim();
    const predicates = new relationalStore.RdbPredicates(TABLE_DEFINITIONS);
    predicates.equalTo('word', normalizedWord);

    await this.store!.delete(predicates);
    console.info(`[WordRepository] Cleared cached definition for: ${normalizedWord}`);
  }

  /**
   * Convert WordItem to ValuesBucket
   */
  private wordToValuesBucket(word: WordItem): relationalStore.ValuesBucket {
    return {
      'word': word.word,
      'status': word.status,
      'fsrs_state': word.fsrsState.toJSON(),
      'history': word.history.toJSON(),
      'definition': word.definition.toJSON(),
      'due_date': word.dueDate,
      'created_at': word.createdAt,
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
    const statusRaw = resultSet.getString(resultSet.getColumnIndex(WordColumns.STATUS));
    const status = normalizeWordStatus(statusRaw);
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

    const fsrsState = FSRSState.fromJSON(fsrsJson);
    const history = ReviewHistory.fromJSON(historyJson);
    const definition = WordDefinition.fromJSON(defJson);

    return new WordItem(
      id,
      wordStr,
      status,
      fsrsState,
      history,
      definition,
      dueDate,
      createdAt,
      updatedAt,
      bookId,
      tags
    );
  }

  /**
   * Prune history for all words
   * Returns the total number of history entries removed
   */
  async pruneAllHistory(): Promise<number> {
    this.ensureInitialized();

    const words = await this.getAllWords();
    let totalRemoved = 0;
    const wordsToUpdate: WordItem[] = [];

    for (const word of words) {
      const removed = word.history.pruneOldEntries();
      if (removed > 0) {
        totalRemoved += removed;
        wordsToUpdate.push(word);
      }
    }

    // Batch update words with pruned history
    for (const word of wordsToUpdate) {
      await this.updateWord(word);
    }

    return totalRemoved;
  }

  /**
   * Get total history entry count across all words
   */
  async getTotalHistoryCount(): Promise<number> {
    this.ensureInitialized();

    const words = await this.getAllWords();
    let total = 0;
    for (const word of words) {
      total += word.history.getReviewCount();
    }
    return total;
  }

  async getWordsUpdatedAfter(sinceMs: number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.greaterThan(WordColumns.UPDATED_AT, sinceMs);
    predicates.orderByAsc(WordColumns.UPDATED_AT);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  /**
   * 获取有学习记录的单词（用于同步，排除仅导入未学习的单词）
   */
  async getLearnedWordsUpdatedAfter(sinceMs: number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.greaterThan(WordColumns.UPDATED_AT, sinceMs);
    predicates.notEqualTo(WordColumns.STATUS, WordStatus.NEW);
    predicates.orderByAsc(WordColumns.UPDATED_AT);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  async getAllDefinitions(): Promise<DefinitionCacheRow[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_DEFINITIONS);
    const resultSet = await this.store!.query(predicates);
    const definitions: DefinitionCacheRow[] = [];

    try {
      while (resultSet.goToNextRow()) {
        const word = resultSet.getString(resultSet.getColumnIndex('word'));
        const definition = resultSet.getString(resultSet.getColumnIndex('definition'));
        const source = resultSet.getString(resultSet.getColumnIndex('source'));
        const createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        definitions.push({ word, definition, source, createdAt });
      }
    } finally {
      resultSet.close();
    }
    return definitions;
  }

  async getWordCount(): Promise<number> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    const resultSet = await this.store!.query(predicates, ['COUNT(*) AS cnt']);

    try {
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('cnt'));
      }
      return 0;
    } finally {
      resultSet.close();
    }
  }

  async getWordsPaged(limit: number, offset: number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.orderByAsc(WordColumns.ID);
    predicates.limitAs(limit);
    predicates.offsetAs(offset);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }

  async getLearnedWordsPaged(limit: number, offset: number): Promise<WordItem[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    predicates.notEqualTo(WordColumns.STATUS, WordStatus.NEW);
    predicates.orderByAsc(WordColumns.ID);
    predicates.limitAs(limit);
    predicates.offsetAs(offset);

    const resultSet = await this.store!.query(predicates);
    const words: WordItem[] = [];

    try {
      while (resultSet.goToNextRow()) {
        words.push(this.resultSetToWord(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return words;
  }
}

export interface DefinitionCacheRow {
  word: string;
  definition: string;
  source: string;
  createdAt: number;
}
