// =====================================================
// DeckManager.ets - Deck Management
// Handles deck creation, updates, and statistics
// =====================================================

import { DBManager } from '../database/DBManager';
import { DeckRepository } from '../database/repositories/DeckRepository';
import { CardRepository } from '../database/repositories/CardRepository';
import { WordRepository } from '../database/repositories/WordRepository';
import { Deck, DeckType, DeckConfig, DeckStats } from '../model/DeckModel';
import { SRSCard, CardQueue, SourceType } from '../model/DeckCardModel';
import { WordItem } from '../model/WordModel';

/**
 * DeckManager - Singleton manager for deck operations
 * 
 * Provides high-level deck management including:
 * - Creating decks from word books
 * - Creating decks for reading materials
 * - Getting deck statistics
 */
export class DeckManager {
  private static instance: DeckManager | null = null;
  
  private deckRepository: DeckRepository | null = null;
  private cardRepository: CardRepository | null = null;
  private wordRepository: WordRepository | null = null;
  
  private constructor() {
    this.initialize();
  }
  
  /**
   * Get singleton instance
   */
  static getInstance(): DeckManager {
    if (DeckManager.instance === null) {
      DeckManager.instance = new DeckManager();
    }
    return DeckManager.instance;
  }
  
  /**
   * Initialize repositories
   */
  private async initialize(): Promise<void> {
    const store = await DBManager.getInstance().getStore();
    this.deckRepository = new DeckRepository(store);
    this.cardRepository = new CardRepository(store);
    this.wordRepository = new WordRepository(store);
  }
  
  /**
   * Ensure repositories are initialized
   */
  private ensureInitialized(): void {
    if (this.deckRepository === null || this.cardRepository === null || this.wordRepository === null) {
      throw new Error('DeckManager not initialized. Call initialize() first.');
    }
  }
  
  /**
   * Create a deck from a word book
   * 
   * @param bookId - Word book ID (e.g., 'cet4', 'cet6')
   * @param name - Deck name
   * @param config - Optional deck configuration
   * @returns Created deck with generated cards
   */
  async createBookDeck(
    bookId: string,
    name: string,
    config?: DeckConfig
  ): Promise<Deck> {
    this.ensureInitialized();
    
    // Create deck
    const deck = new Deck(
      0, // Will be set by database
      name,
      DeckType.BOOK,
      null, // Will store bookId in a different way if needed
      config ?? new DeckConfig()
    );
    
    const deckId = await this.deckRepository!.createDeck(deck);
    deck.id = deckId;
    
    // Get words from book
    const words = await this.wordRepository!.getWordsByBookId(bookId);
    
    // Create cards for each word
    let createdCount = 0;
    for (const word of words) {
      try {
        const card = this.createCardFromWord(deckId, word, bookId);
        await this.cardRepository!.createCard(card);
        createdCount++;
      } catch (e) {
        console.error(`[DeckManager] Failed to create card for word ${word.word}:`, e);
      }
    }
    
    console.info(`[DeckManager] Created deck ${name} with ${createdCount} cards from book ${bookId}`);
    
    return deck;
  }
  
  /**
   * Create a deck for reading material
   * 
   * @param materialId - Reading material ID
   * @param title - Deck title
   * @param config - Optional deck configuration
   * @returns Created empty deck
   */
  async createReadingDeck(
    materialId: number,
    title: string,
    config?: DeckConfig
  ): Promise<Deck> {
    this.ensureInitialized();
    
    const deck = new Deck(
      0,
      title,
      DeckType.READING,
      materialId,
      config ?? new DeckConfig()
    );
    
    const deckId = await this.deckRepository!.createDeck(deck);
    deck.id = deckId;
    
    console.info(`[DeckManager] Created reading deck ${title} for material ${materialId}`);
    
    return deck;
  }
  
  /**
   * Get all decks with their statistics
   * 
   * @returns Array of decks with computed stats
   */
  async getDecksWithStats(): Promise<Deck[]> {
    this.ensureInitialized();
    
    const decks = await this.deckRepository!.getAllDecks();
    
    // Compute stats for each deck
    for (const deck of decks) {
      deck.stats = await this.getDeckStats(deck.id);
    }
    
    return decks;
  }
  
  /**
   * Get deck by ID
   */
  async getDeckById(deckId: number): Promise<Deck | null> {
    this.ensureInitialized();
    return await this.deckRepository!.getDeckById(deckId);
  }
  
  /**
   * Update deck configuration
   */
  async updateDeckConfig(deckId: number, config: DeckConfig): Promise<void> {
    this.ensureInitialized();
    
    const deck = await this.deckRepository!.getDeckById(deckId);
    if (deck === null) {
      throw new Error(`Deck ${deckId} not found`);
    }
    
    deck.config = config;
    await this.deckRepository!.updateDeck(deck);
  }
  
  /**
   * Delete deck and all its cards
   */
  async deleteDeck(deckId: number): Promise<void> {
    this.ensureInitialized();
    
    // Cards will be cascade deleted by foreign key constraint
    await this.deckRepository!.deleteDeck(deckId);
    
    console.info(`[DeckManager] Deleted deck ${deckId}`);
  }
  
  /**
   * Get statistics for a deck
   */
  async getDeckStats(deckId: number): Promise<DeckStats> {
    this.ensureInitialized();
    
    // Count cards by queue type (only due cards)
    const newCount = await this.cardRepository!.countDueCardsByQueue(deckId, CardQueue.NEW);
    const learningCount = await this.cardRepository!.countDueCardsByQueue(deckId, CardQueue.LEARNING);
    const reviewCount = await this.cardRepository!.countDueCardsByQueue(deckId, CardQueue.REVIEW);
    const relearnCount = await this.cardRepository!.countDueCardsByQueue(deckId, CardQueue.RELEARNING);
    
    return new DeckStats(newCount, learningCount, reviewCount, relearnCount);
  }
  
  /**
   * Add a card to a reading deck
   * 
   * @param deckId - Deck ID
   * @param front - Card front (question)
   * @param back - Card back (answer)
   * @param context - Optional context text
   * @param position - Position in reading material
   * @returns Created card
   */
  async addCardToReadingDeck(
    deckId: number,
    front: string,
    back: string,
    context?: string,
    position?: number
  ): Promise<SRSCard> {
    this.ensureInitialized();
    
    const deck = await this.deckRepository!.getDeckById(deckId);
    if (deck === null) {
      throw new Error(`Deck ${deckId} not found`);
    }
    
    if (deck.type !== DeckType.READING) {
      throw new Error(`Deck ${deckId} is not a reading deck`);
    }
    
    const card = new SRSCard(
      0,
      deckId,
      front,
      back,
      null, // No word ID for reading cards
      context ?? null,
      context ? 'READING' as any : 'NONE' as any,
      SourceType.READING,
      deck.sourceId,
      position ?? null
    );
    
    const cardId = await this.cardRepository!.createCard(card);
    card.id = cardId;
    
    return card;
  }
  
  /**
   * Create a card from a WordItem
   * @private
   */
  private createCardFromWord(deckId: number, word: WordItem, bookId: string): SRSCard {
    const front = word.word;
    const back = word.definition.contextualMeaning || 
                 (word.definition.commonMeanings.length > 0 ? word.definition.commonMeanings[0] : '');
    
    const card = new SRSCard(
      0,
      deckId,
      front,
      back,
      word.id,
      null, // No context initially
      'NONE' as any,
      SourceType.BOOK,
      null, // We could store bookId as number if needed
      null
    );
    
    // Copy FSRS state from word if it exists
    if (word.fsrsState) {
      card.fsrsState = word.fsrsState.clone();
      card.reps = word.fsrsState.reps;
      card.lapses = word.fsrsState.lapses;
      
      // Set queue based on word status
      if (word.isNew()) {
        card.queue = CardQueue.NEW;
      } else if (word.status === 'LEARNING') {
        card.queue = CardQueue.LEARNING;
      } else {
        card.queue = CardQueue.REVIEW;
      }
    }
    
    card.dueDate = word.dueDate;
    
    return card;
  }
}
