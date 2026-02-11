// =====================================================
// DeckModel.ets - Deck Data Model for SRS System
// =====================================================

/**
 * Deck type enum
 */
export enum DeckType {
  BOOK = 'BOOK',       // Based on word book
  READING = 'READING'  // Based on reading material
}

/**
 * Deck configuration
 */
export class DeckConfig {
  newCardsPerDay: number;
  learningSteps: number[];  // In minutes
  relearningSteps: number[]; // In minutes
  reviewsPerDay: number;
  
  constructor(
    newCardsPerDay: number = 20,
    learningSteps: number[] = [15, 1440, 4320], // 15min, 1day, 3days
    relearningSteps: number[] = [10, 1440],     // 10min, 1day
    reviewsPerDay: number = 200
  ) {
    this.newCardsPerDay = newCardsPerDay;
    this.learningSteps = learningSteps;
    this.relearningSteps = relearningSteps;
    this.reviewsPerDay = reviewsPerDay;
  }
  
  /**
   * Serialize to JSON string
   */
  toJSON(): string {
    const obj = {
      'newCardsPerDay': this.newCardsPerDay,
      'learningSteps': this.learningSteps,
      'relearningSteps': this.relearningSteps,
      'reviewsPerDay': this.reviewsPerDay
    };
    return JSON.stringify(obj);
  }
  
  /**
   * Deserialize from JSON string
   */
  static fromJSON(json: string): DeckConfig {
    try {
      const obj = JSON.parse(json) as Record<string, number | number[]>;
      return new DeckConfig(
        obj['newCardsPerDay'] as number ?? 20,
        obj['learningSteps'] as number[] ?? [15, 1440, 4320],
        obj['relearningSteps'] as number[] ?? [10, 1440],
        obj['reviewsPerDay'] as number ?? 200
      );
    } catch (e) {
      return new DeckConfig();
    }
  }
}

/**
 * Deck statistics
 */
export class DeckStats {
  newCount: number;
  learningCount: number;
  reviewCount: number;
  relearnCount: number;
  totalCount: number;
  
  constructor(
    newCount: number = 0,
    learningCount: number = 0,
    reviewCount: number = 0,
    relearnCount: number = 0
  ) {
    this.newCount = newCount;
    this.learningCount = learningCount;
    this.reviewCount = reviewCount;
    this.relearnCount = relearnCount;
    this.totalCount = newCount + learningCount + reviewCount + relearnCount;
  }
  
  /**
   * Check if deck has any due cards
   */
  hasDue(): boolean {
    return this.totalCount > 0;
  }
}

/**
 * Deck - Container for SRS cards
 * 
 * Represents a collection of flashcards with shared configuration
 * and learning progress tracking.
 */
export class Deck {
  id: number;
  name: string;
  type: DeckType;
  sourceId: number | null;  // Word book ID or reading material ID
  config: DeckConfig;
  
  // Statistics (computed, not stored)
  stats: DeckStats | null;
  
  // Metadata
  createdAt: number;
  updatedAt: number;
  
  constructor(
    id: number,
    name: string,
    type: DeckType = DeckType.MANUAL,
    sourceId: number | null = null,
    config: DeckConfig = new DeckConfig()
  ) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.sourceId = sourceId;
    this.config = config;
    this.stats = null;
    
    this.createdAt = Date.now();
    this.updatedAt = Date.now();
  }
  
  /**
   * Check if deck is based on a book
   */
  isBookDeck(): boolean {
    return this.type === DeckType.BOOK;
  }
  
  /**
   * Check if deck is based on reading material
   */
  isReadingDeck(): boolean {
    return this.type === DeckType.READING;
  }
  
  /**
   * Serialize to JSON object for database storage
   */
  toDBObject(): Record<string, string | number | null> {
    return {
      'id': this.id,
      'name': this.name,
      'type': this.type,
      'source_id': this.sourceId,
      'config': this.config.toJSON(),
      'created_at': this.createdAt,
      'updated_at': this.updatedAt
    };
  }
  
  /**
   * Deserialize from database object
   */
  static fromDBObject(obj: Record<string, string | number | null>): Deck {
    const deck = new Deck(
      obj['id'] as number,
      obj['name'] as string,
      (obj['type'] as DeckType) ?? DeckType.BOOK,
      obj['source_id'] as number | null,
      DeckConfig.fromJSON(obj['config'] as string)
    );
    
    deck.createdAt = obj['created_at'] as number;
    deck.updatedAt = obj['updated_at'] as number;
    
    return deck;
  }
}

/**
 * Deck type for manual creation (backward compatibility)
 */
const MANUAL = 'MANUAL';
export { MANUAL as DeckTypeManual };
