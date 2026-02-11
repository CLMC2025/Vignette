// =====================================================
// DeckRepository.ets - Database operations for Decks
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { Deck } from '../../model/DeckModel';
import { TABLE_DECKS, DeckColumns } from '../DBConstants';

export class DeckRepository extends BaseRepository {
  constructor(store: relationalStore.RdbStore | null) {
    super(store);
  }

  /**
   * Create a new deck
   */
  async createDeck(deck: Deck): Promise<number> {
    this.ensureInitialized();
    
    const bucket: relationalStore.ValuesBucket = {
      [DeckColumns.NAME]: deck.name,
      [DeckColumns.TYPE]: deck.type,
      [DeckColumns.SOURCE_ID]: deck.sourceId,
      [DeckColumns.CONFIG]: deck.config.toJSON(),
      [DeckColumns.CREATED_AT]: deck.createdAt,
      [DeckColumns.UPDATED_AT]: deck.updatedAt
    };
    
    const id = await this.store!.insert(TABLE_DECKS, bucket);
    return id;
  }

  /**
   * Get deck by ID
   */
  async getDeckById(id: number): Promise<Deck | null> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_DECKS);
    predicates.equalTo(DeckColumns.ID, id);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      if (resultSet.goToFirstRow()) {
        return this.resultSetToDeck(resultSet);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get all decks
   */
  async getAllDecks(): Promise<Deck[]> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_DECKS);
    predicates.orderByAsc(DeckColumns.CREATED_AT);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      const decks: Deck[] = [];
      while (resultSet.goToNextRow()) {
        decks.push(this.resultSetToDeck(resultSet));
      }
      return decks;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Update deck
   */
  async updateDeck(deck: Deck): Promise<number> {
    this.ensureInitialized();
    
    deck.updatedAt = Date.now();
    
    const bucket: relationalStore.ValuesBucket = {
      [DeckColumns.NAME]: deck.name,
      [DeckColumns.TYPE]: deck.type,
      [DeckColumns.SOURCE_ID]: deck.sourceId,
      [DeckColumns.CONFIG]: deck.config.toJSON(),
      [DeckColumns.UPDATED_AT]: deck.updatedAt
    };
    
    const predicates = new relationalStore.RdbPredicates(TABLE_DECKS);
    predicates.equalTo(DeckColumns.ID, deck.id);
    
    return await this.store!.update(bucket, predicates);
  }

  /**
   * Delete deck by ID
   */
  async deleteDeck(id: number): Promise<number> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_DECKS);
    predicates.equalTo(DeckColumns.ID, id);
    
    return await this.store!.delete(predicates);
  }

  /**
   * Get decks by type
   */
  async getDecksByType(type: string): Promise<Deck[]> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_DECKS);
    predicates.equalTo(DeckColumns.TYPE, type);
    predicates.orderByAsc(DeckColumns.CREATED_AT);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      const decks: Deck[] = [];
      while (resultSet.goToNextRow()) {
        decks.push(this.resultSetToDeck(resultSet));
      }
      return decks;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get deck by source ID
   */
  async getDeckBySourceId(sourceId: number): Promise<Deck | null> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_DECKS);
    predicates.equalTo(DeckColumns.SOURCE_ID, sourceId);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      if (resultSet.goToFirstRow()) {
        return this.resultSetToDeck(resultSet);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Convert ResultSet row to Deck object
   */
  private resultSetToDeck(resultSet: relationalStore.ResultSet): Deck {
    const obj: Record<string, string | number | null> = {
      'id': resultSet.getLong(resultSet.getColumnIndex(DeckColumns.ID)),
      'name': resultSet.getString(resultSet.getColumnIndex(DeckColumns.NAME)),
      'type': resultSet.getString(resultSet.getColumnIndex(DeckColumns.TYPE)),
      'source_id': resultSet.getLong(resultSet.getColumnIndex(DeckColumns.SOURCE_ID)),
      'config': resultSet.getString(resultSet.getColumnIndex(DeckColumns.CONFIG)),
      'created_at': resultSet.getLong(resultSet.getColumnIndex(DeckColumns.CREATED_AT)),
      'updated_at': resultSet.getLong(resultSet.getColumnIndex(DeckColumns.UPDATED_AT))
    };
    
    return Deck.fromDBObject(obj);
  }
}
