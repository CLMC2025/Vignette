import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { DBError, TABLE_TEXTS } from '../DBConstants';

export interface TextRow {
  id: number;
  title: string;
  content: string;
  sourceType: string;
  sourceRef: string;
  createdAt: number;
  updatedAt: number;
}

export class TextRepository extends BaseRepository {
  async createText(
    title: string,
    content: string,
    sourceType: string = 'paste',
    sourceRef: string = ''
  ): Promise<number> {
    this.ensureInitialized();
    const now = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      'title': title,
      'content': content,
      'source_type': sourceType,
      'source_ref': sourceRef,
      'created_at': now,
      'updated_at': now
    };
    try {
      const id = await this.store!.insert(TABLE_TEXTS, bucket);
      return Number(id);
    } catch (e) {
      throw new DBError(`Create text failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  async updateText(
    id: number,
    title: string,
    content: string,
    sourceType: string,
    sourceRef: string
  ): Promise<void> {
    this.ensureInitialized();
    const bucket: relationalStore.ValuesBucket = {
      'title': title,
      'content': content,
      'source_type': sourceType,
      'source_ref': sourceRef,
      'updated_at': Date.now()
    };
    const predicates = new relationalStore.RdbPredicates(TABLE_TEXTS);
    predicates.equalTo('id', id);
    await this.store!.update(bucket, predicates);
  }

  async deleteText(id: number): Promise<void> {
    this.ensureInitialized();
    const predicates = new relationalStore.RdbPredicates(TABLE_TEXTS);
    predicates.equalTo('id', id);
    await this.store!.delete(predicates);
  }

  async getTextById(id: number): Promise<TextRow | null> {
    this.ensureInitialized();
    const predicates = new relationalStore.RdbPredicates(TABLE_TEXTS);
    predicates.equalTo('id', id);
    predicates.limitAs(1);
    const resultSet = await this.store!.query(predicates);
    let out: TextRow | null = null;
    if (resultSet.goToFirstRow()) {
      out = {
        id: Number(resultSet.getLong(resultSet.getColumnIndex('id'))),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        content: resultSet.getString(resultSet.getColumnIndex('content')),
        sourceType: resultSet.getString(resultSet.getColumnIndex('source_type')),
        sourceRef: resultSet.getString(resultSet.getColumnIndex('source_ref')),
        createdAt: Number(resultSet.getLong(resultSet.getColumnIndex('created_at'))),
        updatedAt: Number(resultSet.getLong(resultSet.getColumnIndex('updated_at')))
      };
    }
    resultSet.close();
    return out;
  }

  async listTexts(limit: number = 100): Promise<TextRow[]> {
    this.ensureInitialized();
    const predicates = new relationalStore.RdbPredicates(TABLE_TEXTS);
    predicates.orderByDesc('updated_at');
    predicates.limitAs(Math.max(1, Math.min(500, Math.round(limit))));
    const resultSet = await this.store!.query(predicates);
    const out: TextRow[] = [];
    while (resultSet.goToNextRow()) {
      out.push({
        id: Number(resultSet.getLong(resultSet.getColumnIndex('id'))),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        content: resultSet.getString(resultSet.getColumnIndex('content')),
        sourceType: resultSet.getString(resultSet.getColumnIndex('source_type')),
        sourceRef: resultSet.getString(resultSet.getColumnIndex('source_ref')),
        createdAt: Number(resultSet.getLong(resultSet.getColumnIndex('created_at'))),
        updatedAt: Number(resultSet.getLong(resultSet.getColumnIndex('updated_at')))
      });
    }
    resultSet.close();
    return out;
  }
}

