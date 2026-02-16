// =====================================================
// WordIdentityRepository.ets - Word Identity Management
// Manages global learning state for words (independent of wordbooks)
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { TABLE_WORD_IDENTITIES, WordIdentityColumns, DBError } from '../DBConstants';
import { WordStatus, FSRSState, ReviewHistory } from '../../model/WordModel';

export interface WordIdentity {
  word: string;
  status: WordStatus;
  fsrsState: FSRSState;
  history: ReviewHistory;
  dueDate: number;
  createdAt: number;
  updatedAt: number;
  totalReps: number;
  totalLapses: number;
  firstBookId: string;
}

export class WordIdentityRepository {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  async get(word: string): Promise<WordIdentity | null> {
    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.equalTo(WordIdentityColumns.WORD, word.toLowerCase());

    const resultSet = await this.store.query(predicates);
    
    try {
      if (resultSet.goToFirstRow()) {
        return this.fromResultSet(resultSet);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  async getMany(words: string[]): Promise<Map<string, WordIdentity>> {
    const result = new Map<string, WordIdentity>();
    
    if (words.length === 0) {
      return result;
    }

    const normalizedWords = words.map(w => w.toLowerCase());
    const placeholders = normalizedWords.map(() => '?').join(',');
    const sql = `SELECT * FROM ${TABLE_WORD_IDENTITIES} WHERE ${WordIdentityColumns.WORD} IN (${placeholders})`;
    
    const resultSet = await this.store.querySql(sql, normalizedWords);
    
    try {
      while (resultSet.goToNextRow()) {
        const identity = this.fromResultSet(resultSet);
        result.set(identity.word, identity);
      }
    } finally {
      resultSet.close();
    }

    return result;
  }

  async upsert(identity: WordIdentity): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      [WordIdentityColumns.WORD]: identity.word.toLowerCase(),
      [WordIdentityColumns.STATUS]: identity.status,
      [WordIdentityColumns.FSRS_STATE]: JSON.stringify(identity.fsrsState),
      [WordIdentityColumns.HISTORY]: JSON.stringify(identity.history),
      [WordIdentityColumns.DUE_DATE]: identity.dueDate,
      [WordIdentityColumns.CREATED_AT]: identity.createdAt,
      [WordIdentityColumns.UPDATED_AT]: identity.updatedAt,
      [WordIdentityColumns.TOTAL_REPS]: identity.totalReps,
      [WordIdentityColumns.TOTAL_LAPSES]: identity.totalLapses,
      [WordIdentityColumns.FIRST_BOOK_ID]: identity.firstBookId
    };

    await this.store.insert(TABLE_WORD_IDENTITIES, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async upsertMany(identities: WordIdentity[]): Promise<void> {
    if (identities.length === 0) {
      return;
    }

    for (const identity of identities) {
      await this.upsert(identity);
    }
  }

  async updateStatus(word: string, status: WordStatus): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      [WordIdentityColumns.STATUS]: status,
      [WordIdentityColumns.UPDATED_AT]: Date.now()
    };

    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.equalTo(WordIdentityColumns.WORD, word.toLowerCase());

    await this.store.update(values, predicates);
  }

  async updateFSRSState(word: string, state: FSRSState, dueDate: number, isLapse: boolean): Promise<void> {
    const now = Date.now();
    
    const existing = await this.get(word);
    const totalReps = existing ? existing.totalReps + 1 : 1;
    const totalLapses = existing ? existing.totalLapses + (isLapse ? 1 : 0) : (isLapse ? 1 : 0);

    const values: relationalStore.ValuesBucket = {
      [WordIdentityColumns.FSRS_STATE]: JSON.stringify(state),
      [WordIdentityColumns.DUE_DATE]: dueDate,
      [WordIdentityColumns.UPDATED_AT]: now,
      [WordIdentityColumns.TOTAL_REPS]: totalReps,
      [WordIdentityColumns.TOTAL_LAPSES]: totalLapses
    };

    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.equalTo(WordIdentityColumns.WORD, word.toLowerCase());

    await this.store.update(values, predicates);
  }

  async addHistoryEntry(word: string, entry: string): Promise<void> {
    const existing = await this.get(word);
    if (!existing) {
      return;
    }

    const history = existing.history;
    history.addEntry(entry);

    const values: relationalStore.ValuesBucket = {
      [WordIdentityColumns.HISTORY]: JSON.stringify(history),
      [WordIdentityColumns.UPDATED_AT]: Date.now()
    };

    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.equalTo(WordIdentityColumns.WORD, word.toLowerCase());

    await this.store.update(values, predicates);
  }

  async delete(word: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.equalTo(WordIdentityColumns.WORD, word.toLowerCase());

    await this.store.delete(predicates);
  }

  async deleteAll(): Promise<void> {
    await this.store.executeSql(`DELETE FROM ${TABLE_WORD_IDENTITIES}`);
  }

  async getDueWords(beforeTime: number, limit: number = 100): Promise<WordIdentity[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.lessThanOrEqualTo(WordIdentityColumns.DUE_DATE, beforeTime);
    predicates.in(WordIdentityColumns.STATUS, [WordStatus.LEARNING, WordStatus.REVIEW, WordStatus.RELEARNING]);
    predicates.orderByAsc(WordIdentityColumns.DUE_DATE);
    predicates.limitAs(limit);

    const resultSet = await this.store.query(predicates);
    const results: WordIdentity[] = [];

    try {
      while (resultSet.goToNextRow()) {
        results.push(this.fromResultSet(resultSet));
      }
    } finally {
      resultSet.close();
    }

    return results;
  }

  async getCountByStatus(status: WordStatus): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(TABLE_WORD_IDENTITIES);
    predicates.equalTo(WordIdentityColumns.STATUS, status);

    const resultSet = await this.store.query(predicates, [WordIdentityColumns.WORD]);
    
    try {
      return resultSet.rowCount;
    } finally {
      resultSet.close();
    }
  }

  async getTotalCount(): Promise<number> {
    const sql = `SELECT COUNT(*) as count FROM ${TABLE_WORD_IDENTITIES}`;
    const resultSet = await this.store.querySql(sql);
    
    try {
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('count'));
      }
      return 0;
    } finally {
      resultSet.close();
    }
  }

  async getStats(): Promise<{ total: number; new: number; learning: number; review: number; known: number }> {
    const stats = {
      total: 0,
      new: 0,
      learning: 0,
      review: 0,
      known: 0
    };

    stats.total = await this.getTotalCount();
    stats.new = await this.getCountByStatus(WordStatus.NEW);
    stats.learning = await this.getCountByStatus(WordStatus.LEARNING);
    stats.review = await this.getCountByStatus(WordStatus.REVIEW) + await this.getCountByStatus(WordStatus.RELEARNING);
    stats.known = await this.getCountByStatus(WordStatus.KNOWN);

    return stats;
  }

  private fromResultSet(resultSet: relationalStore.ResultSet): WordIdentity {
    const word = resultSet.getString(resultSet.getColumnIndex(WordIdentityColumns.WORD));
    const status = resultSet.getString(resultSet.getColumnIndex(WordIdentityColumns.STATUS)) as WordStatus;
    const fsrsStateStr = resultSet.getString(resultSet.getColumnIndex(WordIdentityColumns.FSRS_STATE));
    const historyStr = resultSet.getString(resultSet.getColumnIndex(WordIdentityColumns.HISTORY));
    const dueDate = resultSet.getLong(resultSet.getColumnIndex(WordIdentityColumns.DUE_DATE));
    const createdAt = resultSet.getLong(resultSet.getColumnIndex(WordIdentityColumns.CREATED_AT));
    const updatedAt = resultSet.getLong(resultSet.getColumnIndex(WordIdentityColumns.UPDATED_AT));
    const totalReps = resultSet.getLong(resultSet.getColumnIndex(WordIdentityColumns.TOTAL_REPS));
    const totalLapses = resultSet.getLong(resultSet.getColumnIndex(WordIdentityColumns.TOTAL_LAPSES));
    const firstBookId = resultSet.getString(resultSet.getColumnIndex(WordIdentityColumns.FIRST_BOOK_ID));

    let fsrsState: FSRSState;
    try {
      fsrsState = FSRSState.fromJSON(JSON.parse(fsrsStateStr));
    } catch (e) {
      fsrsState = new FSRSState();
    }

    let history: ReviewHistory;
    try {
      history = ReviewHistory.fromJSON(JSON.parse(historyStr));
    } catch (e) {
      history = new ReviewHistory();
    }

    return {
      word,
      status,
      fsrsState,
      history,
      dueDate,
      createdAt,
      updatedAt,
      totalReps,
      totalLapses,
      firstBookId
    };
  }

  static createNewIdentity(word: string, bookId: string): WordIdentity {
    const now = Date.now();
    return {
      word: word.toLowerCase(),
      status: WordStatus.NEW,
      fsrsState: new FSRSState(),
      history: new ReviewHistory(),
      dueDate: now,
      createdAt: now,
      updatedAt: now,
      totalReps: 0,
      totalLapses: 0,
      firstBookId: bookId
    };
  }
}
