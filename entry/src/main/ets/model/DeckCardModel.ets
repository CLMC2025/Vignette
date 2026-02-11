// =====================================================
// DeckCardModel.ets - SRS Card Data Model for Deck System
// Implements Anki-compatible SRS card structure
// =====================================================

import { FSRSState } from './WordModel';

/**
 * Card queue types (Anki-compatible)
 */
export enum CardQueue {
  NEW = 0,         // New card, never studied
  LEARNING = 1,    // In learning phase, progressing through steps
  REVIEW = 2,      // In review phase, using FSRS intervals
  RELEARNING = 3   // Failed review, relearning with shorter steps
}

/**
 * Card context type
 */
export enum ContextType {
  NONE = 'NONE',       // No context
  STORY = 'STORY',     // AI-generated story
  SENTENCE = 'SENTENCE', // Example sentence
  READING = 'READING'  // From reading material
}

/**
 * Card source type
 */
export enum SourceType {
  BOOK = 'BOOK',           // From word book
  READING = 'READING',     // From reading material
  MANUAL = 'MANUAL'        // Manually created
}

/**
 * SRS Card - Basic unit for spaced repetition learning
 * 
 * Represents a flashcard with front/back content, FSRS state,
 * and learning progress tracking.
 */
export class SRSCard {
  id: number;
  deckId: number;
  wordId: number | null;
  
  // Card content
  front: string;        // Question/word
  back: string;         // Answer/definition
  context: string | null;      // Optional context for the card
  contextType: ContextType;
  
  // FSRS algorithm state
  fsrsState: FSRSState;
  dueDate: number;      // Unix timestamp
  interval: number;     // Days until next review
  reps: number;         // Successful review count
  lapses: number;       // Failure count
  
  // Queue management
  queue: CardQueue;
  left: number;         // Remaining learning steps (for LEARNING/RELEARNING)
  
  // Source tracking
  sourceType: SourceType;
  sourceMaterialId: number | null;
  sourcePosition: number | null;
  
  // Metadata
  createdAt: number;
  updatedAt: number;
  
  constructor(
    id: number,
    deckId: number,
    front: string,
    back: string,
    wordId: number | null = null,
    context: string | null = null,
    contextType: ContextType = ContextType.NONE,
    sourceType: SourceType = SourceType.MANUAL,
    sourceMaterialId: number | null = null,
    sourcePosition: number | null = null
  ) {
    this.id = id;
    this.deckId = deckId;
    this.wordId = wordId;
    this.front = front;
    this.back = back;
    this.context = context;
    this.contextType = contextType;
    
    // Initialize FSRS state
    this.fsrsState = new FSRSState();
    this.dueDate = Date.now();
    this.interval = 0;
    this.reps = 0;
    this.lapses = 0;
    
    // Initialize as NEW card
    this.queue = CardQueue.NEW;
    this.left = 0;
    
    // Source tracking
    this.sourceType = sourceType;
    this.sourceMaterialId = sourceMaterialId;
    this.sourcePosition = sourcePosition;
    
    // Timestamps
    this.createdAt = Date.now();
    this.updatedAt = Date.now();
  }
  
  /**
   * Check if card is due for review
   */
  isDue(): boolean {
    return this.dueDate <= Date.now();
  }
  
  /**
   * Check if card is new
   */
  isNew(): boolean {
    return this.queue === CardQueue.NEW;
  }
  
  /**
   * Check if card is in learning phase
   */
  isLearning(): boolean {
    return this.queue === CardQueue.LEARNING || this.queue === CardQueue.RELEARNING;
  }
  
  /**
   * Check if card is in review phase
   */
  isReview(): boolean {
    return this.queue === CardQueue.REVIEW;
  }
  
  /**
   * Update queue based on FSRS state
   */
  updateQueueFromState(): void {
    if (this.queue === CardQueue.NEW) {
      // Don't auto-update NEW cards
      return;
    }
    
    if (this.queue === CardQueue.LEARNING || this.queue === CardQueue.RELEARNING) {
      // Learning cards stay in learning until graduated
      return;
    }
    
    // Review cards stay in review
    this.queue = CardQueue.REVIEW;
  }
  
  /**
   * Clone this card
   */
  clone(): SRSCard {
    const cloned = new SRSCard(
      this.id,
      this.deckId,
      this.front,
      this.back,
      this.wordId,
      this.context,
      this.contextType,
      this.sourceType,
      this.sourceMaterialId,
      this.sourcePosition
    );
    
    cloned.fsrsState = this.fsrsState.clone();
    cloned.dueDate = this.dueDate;
    cloned.interval = this.interval;
    cloned.reps = this.reps;
    cloned.lapses = this.lapses;
    cloned.queue = this.queue;
    cloned.left = this.left;
    cloned.createdAt = this.createdAt;
    cloned.updatedAt = this.updatedAt;
    
    return cloned;
  }
  
  /**
   * Serialize to JSON object for database storage
   */
  toDBObject(): Record<string, string | number | null> {
    return {
      'id': this.id,
      'deck_id': this.deckId,
      'word_id': this.wordId,
      'front': this.front,
      'back': this.back,
      'context': this.context,
      'context_type': this.contextType,
      'fsrs_state': this.fsrsState.toJSON(),
      'due_date': this.dueDate,
      'interval': this.interval,
      'reps': this.reps,
      'lapses': this.lapses,
      'queue': this.queue,
      'left': this.left,
      'source_type': this.sourceType,
      'source_material_id': this.sourceMaterialId,
      'source_position': this.sourcePosition,
      'created_at': this.createdAt,
      'updated_at': this.updatedAt
    };
  }
  
  /**
   * Deserialize from database object
   */
  static fromDBObject(obj: Record<string, string | number | null>): SRSCard {
    const card = new SRSCard(
      obj['id'] as number,
      obj['deck_id'] as number,
      obj['front'] as string,
      obj['back'] as string,
      obj['word_id'] as number | null,
      obj['context'] as string | null,
      (obj['context_type'] as ContextType) ?? ContextType.NONE,
      (obj['source_type'] as SourceType) ?? SourceType.MANUAL,
      obj['source_material_id'] as number | null,
      obj['source_position'] as number | null
    );
    
    card.fsrsState = FSRSState.fromJSON(obj['fsrs_state'] as string);
    card.dueDate = obj['due_date'] as number;
    card.interval = obj['interval'] as number;
    card.reps = obj['reps'] as number;
    card.lapses = obj['lapses'] as number;
    card.queue = obj['queue'] as CardQueue;
    card.left = obj['left'] as number;
    card.createdAt = obj['created_at'] as number;
    card.updatedAt = obj['updated_at'] as number;
    
    return card;
  }
}
