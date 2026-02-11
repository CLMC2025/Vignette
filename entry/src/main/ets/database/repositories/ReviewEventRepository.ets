// =====================================================
// ReviewEventRepository.ets
// CRUD for review events
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { DBError, TABLE_REVIEW_EVENTS } from '../DBConstants';
import { ReviewEventRow } from '../DBManager';

export class ReviewEventRepository extends BaseRepository {

  async insertReviewEvent(
    id: string,
    wordId: number,
    rating: number,
    timestamp: number,
    prevStateJson: string,
    newStateJson: string,
    errorTag: string = '',
    reflection: string = ''
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
    await this.store!.executeSql('BEGIN TRANSACTION');
    try {
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
          const msg = err instanceof Error ? err.message : String(err);
          if (msg.includes('UNIQUE constraint failed') || msg.includes('PRIMARY KEY')) {
            continue;
          }
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
}
