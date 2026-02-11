// =====================================================
// CardRepository.ets - Database operations for Cards
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { SRSCard, CardQueue } from '../../model/DeckCardModel';
import { TABLE_CARDS, CardColumns } from '../DBConstants';

export class CardRepository extends BaseRepository {
  constructor(store: relationalStore.RdbStore | null) {
    super(store);
  }

  /**
   * Create a new card
   */
  async createCard(card: SRSCard): Promise<number> {
    this.ensureInitialized();
    
    const bucket: relationalStore.ValuesBucket = {
      [CardColumns.DECK_ID]: card.deckId,
      [CardColumns.WORD_ID]: card.wordId,
      [CardColumns.FRONT]: card.front,
      [CardColumns.BACK]: card.back,
      [CardColumns.CONTEXT]: card.context,
      [CardColumns.CONTEXT_TYPE]: card.contextType,
      [CardColumns.FSRS_STATE]: card.fsrsState.toJSON(),
      [CardColumns.DUE_DATE]: card.dueDate,
      [CardColumns.INTERVAL]: card.interval,
      [CardColumns.REPS]: card.reps,
      [CardColumns.LAPSES]: card.lapses,
      [CardColumns.QUEUE]: card.queue,
      [CardColumns.LEFT]: card.left,
      [CardColumns.SOURCE_TYPE]: card.sourceType,
      [CardColumns.SOURCE_MATERIAL_ID]: card.sourceMaterialId,
      [CardColumns.SOURCE_POSITION]: card.sourcePosition,
      [CardColumns.CREATED_AT]: card.createdAt,
      [CardColumns.UPDATED_AT]: card.updatedAt
    };
    
    const id = await this.store!.insert(TABLE_CARDS, bucket);
    return id;
  }

  /**
   * Update card
   */
  async updateCard(card: SRSCard): Promise<number> {
    this.ensureInitialized();
    
    card.updatedAt = Date.now();
    
    const bucket: relationalStore.ValuesBucket = {
      [CardColumns.FRONT]: card.front,
      [CardColumns.BACK]: card.back,
      [CardColumns.CONTEXT]: card.context,
      [CardColumns.CONTEXT_TYPE]: card.contextType,
      [CardColumns.FSRS_STATE]: card.fsrsState.toJSON(),
      [CardColumns.DUE_DATE]: card.dueDate,
      [CardColumns.INTERVAL]: card.interval,
      [CardColumns.REPS]: card.reps,
      [CardColumns.LAPSES]: card.lapses,
      [CardColumns.QUEUE]: card.queue,
      [CardColumns.LEFT]: card.left,
      [CardColumns.UPDATED_AT]: card.updatedAt
    };
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.ID, card.id);
    
    return await this.store!.update(bucket, predicates);
  }

  /**
   * Get card by ID
   */
  async getCardById(id: number): Promise<SRSCard | null> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.ID, id);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      if (resultSet.goToFirstRow()) {
        return this.resultSetToCard(resultSet);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get all cards for a deck
   */
  async getCardsByDeck(deckId: number): Promise<SRSCard[]> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.DECK_ID, deckId);
    predicates.orderByAsc(CardColumns.DUE_DATE);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      const cards: SRSCard[] = [];
      while (resultSet.goToNextRow()) {
        cards.push(this.resultSetToCard(resultSet));
      }
      return cards;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get due cards for a deck
   */
  async getDueCards(deckId: number, limit: number = 100): Promise<SRSCard[]> {
    this.ensureInitialized();
    
    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.DECK_ID, deckId);
    predicates.lessThanOrEqualTo(CardColumns.DUE_DATE, now);
    predicates.orderByAsc(CardColumns.QUEUE); // NEW, LEARNING, REVIEW, RELEARNING
    predicates.orderByAsc(CardColumns.DUE_DATE);
    predicates.limit(limit);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      const cards: SRSCard[] = [];
      while (resultSet.goToNextRow()) {
        cards.push(this.resultSetToCard(resultSet));
      }
      return cards;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Get cards by queue type
   */
  async getCardsByQueue(deckId: number, queue: CardQueue, limit: number = 100): Promise<SRSCard[]> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.DECK_ID, deckId);
    predicates.equalTo(CardColumns.QUEUE, queue);
    predicates.orderByAsc(CardColumns.DUE_DATE);
    predicates.limit(limit);
    
    const resultSet = await this.store!.query(predicates);
    
    try {
      const cards: SRSCard[] = [];
      while (resultSet.goToNextRow()) {
        cards.push(this.resultSetToCard(resultSet));
      }
      return cards;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Count cards by queue for a deck
   */
  async countCardsByQueue(deckId: number, queue: CardQueue): Promise<number> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.DECK_ID, deckId);
    predicates.equalTo(CardColumns.QUEUE, queue);
    
    const resultSet = await this.store!.query(predicates, [CardColumns.ID]);
    
    try {
      return resultSet.rowCount;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Count due cards by queue for a deck
   */
  async countDueCardsByQueue(deckId: number, queue: CardQueue): Promise<number> {
    this.ensureInitialized();
    
    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.DECK_ID, deckId);
    predicates.equalTo(CardColumns.QUEUE, queue);
    predicates.lessThanOrEqualTo(CardColumns.DUE_DATE, now);
    
    const resultSet = await this.store!.query(predicates, [CardColumns.ID]);
    
    try {
      return resultSet.rowCount;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Delete card by ID
   */
  async deleteCard(id: number): Promise<number> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.ID, id);
    
    return await this.store!.delete(predicates);
  }

  /**
   * Delete all cards for a deck
   */
  async deleteCardsByDeck(deckId: number): Promise<number> {
    this.ensureInitialized();
    
    const predicates = new relationalStore.RdbPredicates(TABLE_CARDS);
    predicates.equalTo(CardColumns.DECK_ID, deckId);
    
    return await this.store!.delete(predicates);
  }

  /**
   * Convert ResultSet row to SRSCard object
   */
  private resultSetToCard(resultSet: relationalStore.ResultSet): SRSCard {
    const obj: Record<string, string | number | null> = {
      'id': resultSet.getLong(resultSet.getColumnIndex(CardColumns.ID)),
      'deck_id': resultSet.getLong(resultSet.getColumnIndex(CardColumns.DECK_ID)),
      'word_id': resultSet.getLong(resultSet.getColumnIndex(CardColumns.WORD_ID)),
      'front': resultSet.getString(resultSet.getColumnIndex(CardColumns.FRONT)),
      'back': resultSet.getString(resultSet.getColumnIndex(CardColumns.BACK)),
      'context': resultSet.getString(resultSet.getColumnIndex(CardColumns.CONTEXT)),
      'context_type': resultSet.getString(resultSet.getColumnIndex(CardColumns.CONTEXT_TYPE)),
      'fsrs_state': resultSet.getString(resultSet.getColumnIndex(CardColumns.FSRS_STATE)),
      'due_date': resultSet.getLong(resultSet.getColumnIndex(CardColumns.DUE_DATE)),
      'interval': resultSet.getDouble(resultSet.getColumnIndex(CardColumns.INTERVAL)),
      'reps': resultSet.getLong(resultSet.getColumnIndex(CardColumns.REPS)),
      'lapses': resultSet.getLong(resultSet.getColumnIndex(CardColumns.LAPSES)),
      'queue': resultSet.getLong(resultSet.getColumnIndex(CardColumns.QUEUE)),
      'left': resultSet.getLong(resultSet.getColumnIndex(CardColumns.LEFT)),
      'source_type': resultSet.getString(resultSet.getColumnIndex(CardColumns.SOURCE_TYPE)),
      'source_material_id': resultSet.getLong(resultSet.getColumnIndex(CardColumns.SOURCE_MATERIAL_ID)),
      'source_position': resultSet.getLong(resultSet.getColumnIndex(CardColumns.SOURCE_POSITION)),
      'created_at': resultSet.getLong(resultSet.getColumnIndex(CardColumns.CREATED_AT)),
      'updated_at': resultSet.getLong(resultSet.getColumnIndex(CardColumns.UPDATED_AT))
    };
    
    return SRSCard.fromDBObject(obj);
  }
}
