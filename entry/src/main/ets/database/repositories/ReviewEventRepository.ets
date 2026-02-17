// =====================================================
// ReviewEventRepository.ets
// CRUD for review events
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { DBError, TABLE_REVIEW_EVENTS } from '../DBConstants';
import { ReviewEventRow } from '../DBManager';

export interface ReviewDailyAggregateRow {
  dayKey: number;
  againCount: number;
  hardCount: number;
  goodCount: number;
  easyCount: number;
  wordCount: number;
  firstTs: number;
  lastTs: number;
}

export interface ReviewDailyNewWordRow {
  dayKey: number;
  newCount: number;
}

export class ReviewEventRepository extends BaseRepository {

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
    this.ensureInitialized();

    const bucket: relationalStore.ValuesBucket = {
      'id': id,
      'word_id': wordId,
      'rating': rating,
      'timestamp': timestamp,
      'prev_state_json': prevStateJson,
      'new_state_json': newStateJson,
      'error_tag': errorTag,
      'reflection': reflection,
      'scheduled_days': scheduledDays
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
    await this.store!.executeSql('BEGIN TRANSACTION');
    try {
      for (let i = 0; i < events.length; i++) {
        const e = events[i];
        const bucket: relationalStore.ValuesBucket = {
          'id': e.id,
          'word_id': e.wordId,
          'rating': e.rating,
          'timestamp': e.timestamp,
          'prev_state_json': e.prevStateJson,
          'new_state_json': e.newStateJson,
          'error_tag': e.errorTag,
          'reflection': e.reflection,
          'scheduled_days': e.scheduledDays ?? 0
        };

        try {
          await this.store!.insert(TABLE_REVIEW_EVENTS, bucket);
          inserted++;
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          if (msg.includes('UNIQUE constraint failed') || msg.includes('PRIMARY KEY')) {
            continue;
          }
        }

        // 每 50 条记录 yield 一次，避免阻塞 UI
        if (i % 50 === 0 && i > 0) {
          await new Promise<void>((resolve) => setTimeout(resolve, 0));
        }
      }
      await this.store!.executeSql('COMMIT');
      return inserted;
    } catch (e) {
      await this.store!.executeSql('ROLLBACK');
      throw new DBError(`Batch review events insert failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  async getReviewEventsAfter(timestampMs: number, limit: number = 5000): Promise<ReviewEventRow[]> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_REVIEW_EVENTS);
    predicates.greaterThan('timestamp', timestampMs);
    predicates.orderByAsc('timestamp');
    predicates.limitAs(limit);

    const columns: string[] = ['id', 'word_id', 'rating', 'timestamp', 'prev_state_json', 'new_state_json', 'error_tag', 'reflection', 'scheduled_days'];

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
        reflection: resultSet.getString(resultSet.getColumnIndex('reflection')),
        scheduledDays: resultSet.getDouble(resultSet.getColumnIndex('scheduled_days')) as number
      };
      out.push(row);
    }
    resultSet.close();
    return out;
  }

  async getUniqueReviewedWordCountBetween(startMs: number, endMs: number): Promise<number> {
    this.ensureInitialized();

    const sql =
      `SELECT COUNT(DISTINCT word_id) AS cnt ` +
      `FROM ${TABLE_REVIEW_EVENTS} ` +
      `WHERE timestamp >= ? AND timestamp <= ?`;
    const args: relationalStore.ValueType[] = [startMs, endMs];
    const rs = await this.store!.querySql(sql, args);
    let count = 0;
    if (rs.goToFirstRow()) {
      count = Number(rs.getLong(rs.getColumnIndex('cnt')));
    }
    rs.close();
    return count;
  }

  async getRecentReviewEvents(limit: number = 5000): Promise<ReviewEventRow[]> {
    return this.getReviewEventsAfter(0, limit);
  }

  async getReviewDailyAggregates(
    startMs: number,
    endMs: number,
    timezoneOffsetMs: number
  ): Promise<ReviewDailyAggregateRow[]> {
    this.ensureInitialized();
    const dayMs = 24 * 60 * 60 * 1000;
    const sql =
      `SELECT ` +
      `CAST((timestamp + ?) / ? AS INTEGER) AS day_key, ` +
      `SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) AS again_count, ` +
      `SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) AS hard_count, ` +
      `SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) AS good_count, ` +
      `SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) AS easy_count, ` +
      `COUNT(DISTINCT word_id) AS word_count, ` +
      `MIN(timestamp) AS first_ts, ` +
      `MAX(timestamp) AS last_ts ` +
      `FROM ${TABLE_REVIEW_EVENTS} ` +
      `WHERE timestamp >= ? AND timestamp <= ? ` +
      `GROUP BY day_key ` +
      `ORDER BY day_key ASC`;
    const args: relationalStore.ValueType[] = [timezoneOffsetMs, dayMs, startMs, endMs];
    const rs = await this.store!.querySql(sql, args);
    const rows: ReviewDailyAggregateRow[] = [];
    while (rs.goToNextRow()) {
      rows.push({
        dayKey: Number(rs.getLong(rs.getColumnIndex('day_key'))),
        againCount: Number(rs.getLong(rs.getColumnIndex('again_count'))),
        hardCount: Number(rs.getLong(rs.getColumnIndex('hard_count'))),
        goodCount: Number(rs.getLong(rs.getColumnIndex('good_count'))),
        easyCount: Number(rs.getLong(rs.getColumnIndex('easy_count'))),
        wordCount: Number(rs.getLong(rs.getColumnIndex('word_count'))),
        firstTs: Number(rs.getLong(rs.getColumnIndex('first_ts'))),
        lastTs: Number(rs.getLong(rs.getColumnIndex('last_ts')))
      });
    }
    rs.close();
    return rows;
  }

  async getNewWordCountsByDay(
    startMs: number,
    endMs: number,
    timezoneOffsetMs: number
  ): Promise<ReviewDailyNewWordRow[]> {
    this.ensureInitialized();
    const dayMs = 24 * 60 * 60 * 1000;
    const sql =
      `SELECT ` +
      `CAST((first_ts + ?) / ? AS INTEGER) AS day_key, ` +
      `COUNT(1) AS new_count ` +
      `FROM ( ` +
      `SELECT word_id, MIN(timestamp) AS first_ts ` +
      `FROM ${TABLE_REVIEW_EVENTS} ` +
      `GROUP BY word_id ` +
      `) ` +
      `WHERE first_ts >= ? AND first_ts <= ? ` +
      `GROUP BY day_key ` +
      `ORDER BY day_key ASC`;
    const args: relationalStore.ValueType[] = [timezoneOffsetMs, dayMs, startMs, endMs];
    const rs = await this.store!.querySql(sql, args);
    const rows: ReviewDailyNewWordRow[] = [];
    while (rs.goToNextRow()) {
      rows.push({
        dayKey: Number(rs.getLong(rs.getColumnIndex('day_key'))),
        newCount: Number(rs.getLong(rs.getColumnIndex('new_count')))
      });
    }
    rs.close();
    return rows;
  }

  /**
   * Delete a review event by ID
   */
  async deleteReviewEvent(id: string): Promise<void> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_REVIEW_EVENTS);
    predicates.equalTo('id', id);

    try {
      await this.store!.delete(predicates);
    } catch (e) {
      const err = e instanceof Error ? e.message : String(e);
      throw new DBError(`Delete review event failed: ${err}`);
    }
  }

  /**
   * Delete review events older than a timestamp
   */
  async deleteReviewEventsOlderThan(timestampMs: number): Promise<number> {
    this.ensureInitialized();

    const predicates = new relationalStore.RdbPredicates(TABLE_REVIEW_EVENTS);
    predicates.lessThan('timestamp', timestampMs);

    try {
      return await this.store!.delete(predicates);
    } catch (e) {
      const err = e instanceof Error ? e.message : String(e);
      throw new DBError(`Delete old review events failed: ${err}`);
    }
  }

  /**
   * Get total review event count
   */
  async getReviewEventCount(): Promise<number> {
    this.ensureInitialized();

    const sql = `SELECT COUNT(1) AS cnt FROM ${TABLE_REVIEW_EVENTS}`;
    const rs = await this.store!.querySql(sql);
    let count = 0;
    if (rs.goToFirstRow()) {
      count = Number(rs.getLong(rs.getColumnIndex('cnt')));
    }
    rs.close();
    return count;
  }
}
