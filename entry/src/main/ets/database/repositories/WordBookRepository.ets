// =====================================================
// WordBookRepository.ets
// CRUD for word books
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import {
  DBError,
  TABLE_USER_WORD_BOOKS,
  TABLE_USER_WORD_BOOK_WORDS,
  TABLE_SYSTEM_WORD_BOOK_WORDS,
  TABLE_WORDS,
  WordColumns,
  SYSTEM_WORD_BOOK_IDS
} from '../DBConstants';
import {
  UserWordBook,
  DailyActivity,
  UserWordBookBrief,
  EnsureBookIdOutcome,
  AddToUserWordBookOutcome
} from '../DBManager';
import { WordDefinition, WordItem, WordStatus, FSRSState, ReviewHistory, normalizeWordStatus } from '../../model/WordModel';
import { BookProgress } from '../../model/WordBookCatalog';
import { isUniqueConstraintErrorMessage } from '../../utils/DatabaseErrorUtil';

export class WordBookRepository extends BaseRepository {

  /**
   * Get user word books
   */
  async getUserWordBooks(): Promise<UserWordBook[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOKS);
    predicates.orderByDesc('updated_at');

    const resultSet = await this.store!.query(predicates);
    const books: UserWordBook[] = [];

    while (resultSet.goToNextRow()) {
      const bookId = resultSet.getString(resultSet.getColumnIndex('id'));
      const name = resultSet.getString(resultSet.getColumnIndex('name'));
      const createdAt = Number(resultSet.getLong(resultSet.getColumnIndex('created_at')));
      const updatedAt = Number(resultSet.getLong(resultSet.getColumnIndex('updated_at')));
      // New columns check
      let description = '';
      let category = '其他';
      let difficulty = '初级';
      let coverColor = '["#a8edea", "#fed6e3"]';
      let icon = '📓';

      try { description = resultSet.getString(resultSet.getColumnIndex('description')); } catch (e) { }
      try { category = resultSet.getString(resultSet.getColumnIndex('category')); } catch (e) { }
      try { difficulty = resultSet.getString(resultSet.getColumnIndex('difficulty')); } catch (e) { }
      try { coverColor = resultSet.getString(resultSet.getColumnIndex('cover_color')); } catch (e) { }
      try { icon = resultSet.getString(resultSet.getColumnIndex('icon')); } catch (e) { }

      const count = await this.getUserWordBookWordCount(bookId);
      const book: UserWordBook = {
        id: bookId,
        name: name,
        description: description || '用户自定义词书',
        wordCount: count,
        isUserCreated: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
        category,
        difficulty,
        coverColor,
        icon
      };
      books.push(book);
    }
    resultSet.close();
    return books;
  }

  async getUserWordBookById(bookId: string): Promise<UserWordBook | null> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOKS);
    predicates.equalTo('id', bookId);
    const resultSet = await this.store!.query(predicates);

    try {
      if (!resultSet.goToFirstRow()) {
        return null;
      }

      const name = resultSet.getString(resultSet.getColumnIndex('name'));
      const createdAt = Number(resultSet.getLong(resultSet.getColumnIndex('created_at')));
      const updatedAt = Number(resultSet.getLong(resultSet.getColumnIndex('updated_at')));
      let description = '';
      let category = '其他';
      let difficulty = '初级';
      let coverColor = '["#a8edea", "#fed6e3"]';
      let icon = '📓';

      try { description = resultSet.getString(resultSet.getColumnIndex('description')); } catch (e) { }
      try { category = resultSet.getString(resultSet.getColumnIndex('category')); } catch (e) { }
      try { difficulty = resultSet.getString(resultSet.getColumnIndex('difficulty')); } catch (e) { }
      try { coverColor = resultSet.getString(resultSet.getColumnIndex('cover_color')); } catch (e) { }
      try { icon = resultSet.getString(resultSet.getColumnIndex('icon')); } catch (e) { }

      const count = await this.getUserWordBookWordCount(bookId);
      const book: UserWordBook = {
        id: bookId,
        name,
        description: description || '用户自定义词书',
        wordCount: count,
        isUserCreated: true,
        createdAt,
        updatedAt,
        category,
        difficulty,
        coverColor,
        icon
      };
      return book;
    } finally {
      resultSet.close();
    }
  }

  async getUserWordBookWordCount(bookId: string): Promise<number> {
    this.ensureInitialized();
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOK_WORDS);
    predicates.equalTo('book_id', bookId);
    const resultSet = await this.store!.query(predicates);
    let count = 0;
    while (resultSet.goToNextRow()) {
      count++;
    }
    resultSet.close();
    return count;
  }

  async createUserWordBook(name: string, description: string = '', category: string = '其他', difficulty: string = '初级', coverColor: string = '', icon: string = '📓'): Promise<string> {
    this.ensureInitialized();
    const now = Date.now();
    const id = this.generateUserWordBookId(now);
    const bucket: relationalStore.ValuesBucket = {
      'id': id,
      'name': name,
      'created_at': now,
      'updated_at': now,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'cover_color': coverColor || '["#a8edea", "#fed6e3"]',
      'icon': icon
    };
    try {
      await this.store!.insert(TABLE_USER_WORD_BOOKS, bucket);
      return id;
    } catch (e) {
      throw new DBError(`Create user word book failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  async deleteUserWordBook(bookId: string): Promise<void> {
    this.ensureInitialized();
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOKS);
    predicates.equalTo('id', bookId);
    await this.store!.delete(predicates);

    // Also delete words relationship
    const wordPredicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOK_WORDS);
    wordPredicates.equalTo('book_id', bookId);
    await this.store!.delete(wordPredicates);
  }

  async updateUserWordBook(book: UserWordBook): Promise<void> {
    this.ensureInitialized();
    const bucket: relationalStore.ValuesBucket = {
      'name': book.name,
      'description': book.description,
      'category': book.category ?? '其他',
      'difficulty': book.difficulty ?? '初级',
      'cover_color': book.coverColor ?? '',
      'icon': book.icon ?? '📓',
      'updated_at': Date.now()
    };
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOKS);
    predicates.equalTo('id', book.id);
    await this.store!.update(bucket, predicates);
  }

  async addWordToUserWordBook(bookId: string, wordStr: string): Promise<AddToUserWordBookOutcome> {
    this.ensureInitialized();
    const normalizedWord = wordStr.trim().toLowerCase();
    const bucket: relationalStore.ValuesBucket = {
      'book_id': bookId,
      'word': normalizedWord,
      'created_at': Date.now()
    };
    try {
      await this.store!.insert(TABLE_USER_WORD_BOOK_WORDS, bucket);
      return AddToUserWordBookOutcome.Added;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (isUniqueConstraintErrorMessage(msg)) {
        return AddToUserWordBookOutcome.Already;
      }
      throw new DBError(`Add word to user book failed: ${msg}`);
    }
  }

  async removeWordFromUserWordBook(bookId: string, wordStr: string): Promise<void> {
    this.ensureInitialized();
    const normalizedWord = wordStr.trim().toLowerCase();
    const predicates = new relationalStore.RdbPredicates(TABLE_USER_WORD_BOOK_WORDS);
    predicates.equalTo('book_id', bookId);
    predicates.equalTo('word', normalizedWord);
    await this.store!.delete(predicates);
  }

  async getDailyActivity(limit: number): Promise<DailyActivity[]> {
    this.ensureInitialized();

    const cutoff = Date.now() - (limit * 24 * 60 * 60 * 1000);
    const sql = `SELECT timestamp FROM ${'review_events'} WHERE timestamp >= ?`; // Hardcoded table name for circular dependency avoidance if any
    // Actually we can import TABLE_REVIEW_EVENTS
    // const sql = `SELECT timestamp FROM ${TABLE_REVIEW_EVENTS} WHERE timestamp >= ?`;

    const args: relationalStore.ValueType[] = [cutoff];
    // Need to access review_events table. It's in DBConstants.
    const resultSet = await this.store!.querySql(`SELECT timestamp FROM review_events WHERE timestamp >= ?`, args);

    const activityMap = new Map<string, number>();

    while (resultSet.goToNextRow()) {
      const ts = Number(resultSet.getLong(resultSet.getColumnIndex('timestamp')));
      const date = new Date(ts);
      const dateStr = `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
      activityMap.set(dateStr, (activityMap.get(dateStr) || 0) + 1);
    }
    resultSet.close();

    const result: DailyActivity[] = [];
    activityMap.forEach((count, dateStr) => {
      const parts = dateStr.split('-');
      const d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
      result.push({
        date: d.getTime(),
        count: count
      });
    });

    return result.sort((a, b) => a.date - b.date);
  }

  async ensureBookIdForWord(wordStr: string, bookId: string): Promise<EnsureBookIdOutcome> {
    this.ensureInitialized();

    const queryPredicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    queryPredicates.equalTo(WordColumns.WORD, wordStr);
    const resultSet = await this.store!.query(queryPredicates);

    let existingBookId = '';
    try {
      if (!resultSet.goToFirstRow()) {
        return EnsureBookIdOutcome.NotFound;
      }
      existingBookId = resultSet.getString(resultSet.getColumnIndex(WordColumns.BOOK_ID));
    } finally {
      resultSet.close();
    }

    if (existingBookId === bookId) {
      return EnsureBookIdOutcome.Already;
    }

    if (existingBookId.trim().length > 0) {
      return EnsureBookIdOutcome.Conflict;
    }

    const updatePredicates = new relationalStore.RdbPredicates(TABLE_WORDS);
    updatePredicates.equalTo(WordColumns.WORD, wordStr);
    const bucket: relationalStore.ValuesBucket = {
      'book_id': bookId,
      'updated_at': Date.now()
    };
    const affectedRows = await this.store!.update(bucket, updatePredicates);
    if (affectedRows > 0) {
      return EnsureBookIdOutcome.Assigned;
    }
    return EnsureBookIdOutcome.NotFound;
  }

  async addWordToSystemWordBook(bookId: string, wordStr: string): Promise<void> {
    this.ensureInitialized();
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      throw new DBError('Book id is empty.');
    }
    const normalizedWord = wordStr.trim().toLowerCase();
    if (normalizedWord.length === 0) {
      throw new DBError('Word is empty.');
    }
    const now = Date.now();
    const bucket: relationalStore.ValuesBucket = {};
    bucket['book_id'] = normalizedBookId;
    bucket['word'] = normalizedWord;
    bucket['created_at'] = now;
    try {
      await this.store!.insert(TABLE_SYSTEM_WORD_BOOK_WORDS, bucket);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (!isUniqueConstraintErrorMessage(msg)) {
        throw new DBError(`Add word to system book failed: ${msg}`);
      }
    }
  }

  async migrateSystemWordBookMembership(): Promise<void> {
    if (this.store === null) return;

    try {
      // Check if table is empty
      const sqlCheck = `SELECT count(*) as cnt FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS}`;
      const rs = await this.store.querySql(sqlCheck, []);
      let cnt = 0;
      if (rs.goToFirstRow()) {
        cnt = Number(rs.getLong(rs.getColumnIndex('cnt')));
      }
      rs.close();

      if (cnt > 0) {
        return; // Already migrated or populated
      }

      console.info('[WordBookRepository] Migrating system word book membership from words table...');
      // Select words with system book ids
      const placeholders = SYSTEM_WORD_BOOK_IDS.map(id => `'${id}'`).join(',');
      const sqlMigrate = `
        INSERT OR IGNORE INTO ${TABLE_SYSTEM_WORD_BOOK_WORDS} (book_id, word, created_at)
        SELECT book_id, word, created_at FROM ${TABLE_WORDS}
        WHERE book_id IN (${placeholders})
      `;
      await this.store.executeSql(sqlMigrate);
      console.info('[WordBookRepository] System book migration done.');
    } catch (e) {
      console.warn('[WordBookRepository] System book migration warning:', e);
    }
  }

  private getWordsOrderBy(sortType: string, sortDirection: string): string {
    const dir = sortDirection === 'desc' ? 'DESC' : 'ASC';
    if (sortType === 'time') {
      return `w.created_at ${dir}, w.word ASC`;
    }
    if (sortType === 'status') {
      const statusOrder =
        `CASE w.status ` +
        `WHEN 'NEW' THEN 0 ` +
        `WHEN 'LEARNING' THEN 1 ` +
        `WHEN 'RELEARNING' THEN 2 ` +
        `WHEN 'REVIEW' THEN 3 ` +
        `WHEN 'KNOWN' THEN 4 ` +
        `ELSE 99 END`;
      return `${statusOrder} ${dir}, w.word ASC`;
    }
    if (sortType === 'alphabet') {
      return `w.word ${dir}`;
    }
    return `w.word ASC`;
  }

  async getSystemWordBookWordsPaged(
    bookId: string,
    limit: number,
    offset: number,
    sortType: string = 'default',
    sortDirection: string = 'asc'
  ): Promise<WordItem[]> {
    this.ensureInitialized();
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return [];
    }
    const safeLimit = Math.max(1, Math.min(200, limit));
    const safeOffset = Math.max(0, offset);
    const orderBy = this.getWordsOrderBy(sortType, sortDirection);
    const sql =
      `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
      `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
      `WHERE sw.book_id = ? ` +
      `ORDER BY ${orderBy} ` +
      `LIMIT ? OFFSET ?`;
    const args: relationalStore.ValueType[] = [normalizedBookId, safeLimit, safeOffset];
    const resultSet = await this.store!.querySql(sql, args);
    const words: WordItem[] = [];
    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }
    resultSet.close();
    return words;
  }

  async getUserWordBookWordsPaged(
    bookId: string,
    limit: number,
    offset: number,
    sortType: string = 'default',
    sortDirection: string = 'asc'
  ): Promise<WordItem[]> {
    this.ensureInitialized();
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return [];
    }
    const safeLimit = Math.max(1, Math.min(200, limit));
    const safeOffset = Math.max(0, offset);
    const orderBy = this.getWordsOrderBy(sortType, sortDirection);
    const sql =
      `SELECT w.* FROM ${TABLE_USER_WORD_BOOK_WORDS} uw ` +
      `INNER JOIN ${TABLE_WORDS} w ON uw.word = w.word ` +
      `WHERE uw.book_id = ? ` +
      `ORDER BY ${orderBy} ` +
      `LIMIT ? OFFSET ?`;
    const args: relationalStore.ValueType[] = [normalizedBookId, safeLimit, safeOffset];
    const resultSet = await this.store!.querySql(sql, args);
    const words: WordItem[] = [];
    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }
    resultSet.close();
    return words;
  }

  async getReviewQueueBySystemWordBook(bookId: string): Promise<WordItem[]> {
    this.ensureInitialized();
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return [];
    }
    const now = Date.now();
    const newStatus = WordStatus.NEW;
    const sql =
      `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
      `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
      `WHERE sw.book_id = ? ` +
      `AND w.status != ? ` +
      `AND w.due_date <= ? ` +
      `ORDER BY w.due_date ASC`;
    const args: relationalStore.ValueType[] = [normalizedBookId, newStatus, now];
    const resultSet = await this.store!.querySql(sql, args);
    const words: WordItem[] = [];
    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }
    resultSet.close();
    return words;
  }

  async getNewWordsQueueBySystemWordBook(bookId: string, limit: number): Promise<WordItem[]> {
    this.ensureInitialized();
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return [];
    }
    const safeLimit = Math.max(1, Math.min(200, limit));
    const newStatus = WordStatus.NEW;
    const sql =
      `SELECT w.* FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} sw ` +
      `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
      `WHERE sw.book_id = ? AND w.status = ? ` +
      `ORDER BY w.created_at ASC ` +
      `LIMIT ?`;
    const args: relationalStore.ValueType[] = [normalizedBookId, newStatus, safeLimit];
    const resultSet = await this.store!.querySql(sql, args);
    const words: WordItem[] = [];
    while (resultSet.goToNextRow()) {
      words.push(this.resultSetToWord(resultSet));
    }
    resultSet.close();
    return words;
  }

  async getAllBookCounts(): Promise<Map<string, number>> {
    this.ensureInitialized();
    const sql = `SELECT book_id AS id, COUNT(1) AS cnt FROM ${TABLE_WORDS} WHERE book_id != '' GROUP BY book_id`;
    const args: relationalStore.ValueType[] = [];
    const resultSet = await this.store!.querySql(sql, args);
    const map = new Map<string, number>();
    while (resultSet.goToNextRow()) {
      const id = resultSet.getString(resultSet.getColumnIndex('id'));
      const cnt = Number(resultSet.getLong(resultSet.getColumnIndex('cnt')));
      if (id.length > 0) {
        map.set(id, cnt);
      }
    }
    resultSet.close();
    return map;
  }

  async getBookProgress(bookId: string, isSystem: boolean): Promise<BookProgress> {
    this.ensureInitialized();
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return new BookProgress();
    }

    const tableMap = isSystem ? TABLE_SYSTEM_WORD_BOOK_WORDS : TABLE_USER_WORD_BOOK_WORDS;
    const sql =
      `SELECT w.status, COUNT(1) as cnt ` +
      `FROM ${tableMap} b ` +
      `INNER JOIN ${TABLE_WORDS} w ON b.word = w.word ` +
      `WHERE b.book_id = ? ` +
      `GROUP BY w.status`;

    const args: relationalStore.ValueType[] = [normalizedBookId];
    const resultSet: relationalStore.ResultSet = await this.store!.querySql(sql, args);

    let newWords = 0;
    let learning = 0;
    let mastered = 0;

    while (resultSet.goToNextRow()) {
      const status = Number(resultSet.getLong(resultSet.getColumnIndex('status')));
      const count = Number(resultSet.getLong(resultSet.getColumnIndex('cnt')));

      if (status === 0) {
        newWords += count;
      } else if (status === 1 || status === 3) {
        learning += count;
      } else if (status === 2) {
        mastered += count;
      }
    }
    resultSet.close();
    return new BookProgress(mastered, learning, newWords);
  }

  async getUserWordBooksContainingWord(word: string): Promise<UserWordBookBrief[]> {
    this.ensureInitialized();
    const normalizedWord = word.trim().toLowerCase();
    const sql = `SELECT b.id, b.name FROM ${TABLE_USER_WORD_BOOKS} b ` +
                `INNER JOIN ${TABLE_USER_WORD_BOOK_WORDS} w ON b.id = w.book_id ` +
                `WHERE w.word = ?`;
    const args: relationalStore.ValueType[] = [normalizedWord];
    const resultSet = await this.store!.querySql(sql, args);
    const books: UserWordBookBrief[] = [];
    while (resultSet.goToNextRow()) {
      books.push({
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        name: resultSet.getString(resultSet.getColumnIndex('name'))
      });
    }
    resultSet.close();
    return books;
  }

  async getSystemWordBookWordCount(bookId: string): Promise<number> {
    this.ensureInitialized();
    const sql = `SELECT COUNT(1) as cnt FROM ${TABLE_SYSTEM_WORD_BOOK_WORDS} WHERE book_id = ?`;
    const args: relationalStore.ValueType[] = [bookId];
    const rs = await this.store!.querySql(sql, args);
    let count = 0;
    if (rs.goToFirstRow()) {
      count = Number(rs.getLong(rs.getColumnIndex('cnt')));
    }
    rs.close();
    return count;
  }

  async getLearningQueueByBook(bookId: string, limit: number): Promise<WordItem[]> {
    const reviews = await this.getReviewQueueBySystemWordBook(bookId);
    if (reviews.length >= limit) {
      return reviews.slice(0, limit);
    }
    const newWords = await this.getNewWordsQueueBySystemWordBook(bookId, limit - reviews.length);
    return [...reviews, ...newWords];
  }

  async getLearningQueueByUserWordBook(bookId: string, limit: number): Promise<WordItem[]> {
    this.ensureInitialized();
    const now = Date.now();
    const safeLimit = Math.max(1, limit);

    // Review words
    const reviewSql =
      `SELECT w.* FROM ${TABLE_USER_WORD_BOOK_WORDS} sw ` +
      `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
      `WHERE sw.book_id = ? ` +
      `AND w.status != 'NEW' ` +
      `AND w.due_date <= ? ` +
      `ORDER BY w.due_date ASC ` +
      `LIMIT ?`;
    
    const reviewArgs: relationalStore.ValueType[] = [bookId, now, safeLimit];
    const reviewRs = await this.store!.querySql(reviewSql, reviewArgs);
    const reviews: WordItem[] = [];
    while (reviewRs.goToNextRow()) {
      reviews.push(this.resultSetToWord(reviewRs));
    }
    reviewRs.close();

    if (reviews.length >= limit) {
      return reviews;
    }

    // New words
    const newLimit = limit - reviews.length;
    const newSql =
      `SELECT w.* FROM ${TABLE_USER_WORD_BOOK_WORDS} sw ` +
      `INNER JOIN ${TABLE_WORDS} w ON sw.word = w.word ` +
      `WHERE sw.book_id = ? ` +
      `AND w.status = 'NEW' ` +
      `ORDER BY w.created_at ASC ` +
      `LIMIT ?`;
    
    const newArgs: relationalStore.ValueType[] = [bookId, newLimit];
    const newRs = await this.store!.querySql(newSql, newArgs);
    const newWords: WordItem[] = [];
    while (newRs.goToNextRow()) {
      newWords.push(this.resultSetToWord(newRs));
    }
    newRs.close();

    return [...reviews, ...newWords];
  }

  private generateUserWordBookId(now: number): string {
    const suffix = Math.floor(Math.random() * 1000000);
    return `user_${now}_${suffix}`;
  }

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

  async resetBookProgress(bookId: string): Promise<void> {
    this.ensureInitialized();

    const isSystemBook = SYSTEM_WORD_BOOK_IDS.includes(bookId);
    const tableName = isSystemBook ? TABLE_SYSTEM_WORD_BOOK_WORDS : TABLE_USER_WORD_BOOK_WORDS;

    const sql = `
      UPDATE ${TABLE_WORDS}
      SET 
        ${WordColumns.STATUS} = 'NEW',
        ${WordColumns.FSRS_STATE} = '{}',
        ${WordColumns.HISTORY} = '[]',
        ${WordColumns.DUE_DATE} = ?,
        ${WordColumns.UPDATED_AT} = ?
      WHERE ${WordColumns.WORD} IN (
        SELECT word FROM ${tableName} WHERE book_id = ?
      )
    `;

    const now = Date.now();
    await this.store!.executeSql(sql, [now, now, bookId]);
  }
}
