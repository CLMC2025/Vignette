// =====================================================
// StudyManager.ets - Study Session Management
// Handles learning sessions, reviews, and FSRS integration
// =====================================================

import { DBManager } from '../database/DBManager';
import { CardRepository } from '../database/repositories/CardRepository';
import { DeckRepository } from '../database/repositories/DeckRepository';
import { SRSCard, CardQueue } from '../model/DeckCardModel';
import { Deck, DeckConfig } from '../model/DeckModel';
import { Rating, FSRSState } from '../model/WordModel';
import { FSRSAlgorithm, ReviewResult } from '../algorithm/Algorithm';

/**
 * Study session statistics
 */
export class SessionStats {
  newCount: number;
  learningCount: number;
  reviewCount: number;
  relearnCount: number;
  reviewedCount: number;
  
  constructor() {
    this.newCount = 0;
    this.learningCount = 0;
    this.reviewCount = 0;
    this.relearnCount = 0;
    this.reviewedCount = 0;
  }
}

/**
 * StudyManager - Manages study sessions for a deck
 * 
 * Handles:
 * - Loading and prioritizing cards
 * - Processing ratings with FSRS algorithm
 * - Managing learning steps
 * - Queue transitions
 */
export class StudyManager {
  private deckId: number;
  private deck: Deck | null = null;
  private cards: SRSCard[] = [];
  private currentIndex: number = 0;
  private stats: SessionStats = new SessionStats();
  
  private cardRepository: CardRepository | null = null;
  private deckRepository: DeckRepository | null = null;
  private fsrsAlgorithm: FSRSAlgorithm;
  
  // Review history for undo
  private reviewHistory: Array<{card: SRSCard, prevState: SRSCard}> = [];
  
  constructor(deckId: number) {
    this.deckId = deckId;
    this.fsrsAlgorithm = FSRSAlgorithm.getInstance();
  }
  
  /**
   * Initialize the study session
   * Loads deck configuration and due cards
   */
  async initialize(): Promise<void> {
    const store = await DBManager.getInstance().getStore();
    this.cardRepository = new CardRepository(store);
    this.deckRepository = new DeckRepository(store);
    
    // Load deck
    this.deck = await this.deckRepository.getDeckById(this.deckId);
    if (this.deck === null) {
      throw new Error(`Deck ${this.deckId} not found`);
    }
    
    // Load cards and prioritize
    await this.loadAndPrioritizeCards();
    
    // Calculate stats
    this.calculateStats();
    
    console.info(`[StudyManager] Initialized session for deck ${this.deckId} with ${this.cards.length} due cards`);
  }
  
  /**
   * Get current card
   */
  getCurrentCard(): SRSCard | null {
    if (this.currentIndex >= this.cards.length) {
      return null;
    }
    return this.cards[this.currentIndex];
  }
  
  /**
   * Get session statistics
   */
  getSessionStats(): SessionStats {
    return this.stats;
  }
  
  /**
   * Check if session has more cards
   */
  hasMore(): boolean {
    return this.currentIndex < this.cards.length;
  }
  
  /**
   * Process a rating for the current card
   * 
   * @param rating - User's rating (AGAIN, HARD, GOOD, EASY)
   * @returns Updated card
   */
  async processRating(rating: Rating): Promise<SRSCard> {
    const card = this.getCurrentCard();
    if (card === null) {
      throw new Error('No current card to review');
    }
    
    // Save state for undo
    const prevCard = card.clone();
    this.reviewHistory.push({ card: card, prevState: prevCard });
    
    // Process based on queue
    if (card.queue === CardQueue.NEW) {
      await this.processNewCard(card, rating);
    } else if (card.queue === CardQueue.LEARNING || card.queue === CardQueue.RELEARNING) {
      await this.processLearningCard(card, rating);
    } else if (card.queue === CardQueue.REVIEW) {
      await this.processReviewCard(card, rating);
    }
    
    // Update card in database
    await this.cardRepository!.updateCard(card);
    
    // Update stats
    this.stats.reviewedCount++;
    
    // Move to next card
    this.currentIndex++;
    
    return card;
  }
  
  /**
   * Preview intervals for all ratings
   * 
   * @param card - Card to preview (defaults to current card)
   * @returns Map of rating to interval in days
   */
  previewIntervals(card?: SRSCard): Map<Rating, number> {
    const targetCard = card ?? this.getCurrentCard();
    if (targetCard === null) {
      return new Map<Rating, number>();
    }
    
    // Calculate elapsed days
    const elapsedDays = this.calculateElapsedDays(targetCard);
    
    // Use FSRS algorithm to preview
    return this.fsrsAlgorithm.previewIntervals(targetCard.fsrsState, elapsedDays);
  }
  
  /**
   * Move to next card without processing current
   */
  moveToNextCard(): void {
    this.currentIndex++;
  }
  
  /**
   * Undo last review
   */
  async undoLastReview(): Promise<boolean> {
    if (this.reviewHistory.length === 0) {
      return false;
    }
    
    const { card, prevState } = this.reviewHistory.pop()!;
    
    // Restore previous state
    Object.assign(card, prevState);
    
    // Update in database
    await this.cardRepository!.updateCard(card);
    
    // Move back
    this.currentIndex = Math.max(0, this.currentIndex - 1);
    this.stats.reviewedCount = Math.max(0, this.stats.reviewedCount - 1);
    
    return true;
  }
  
  /**
   * Load and prioritize cards for the session
   * @private
   */
  private async loadAndPrioritizeCards(): Promise<void> {
    if (this.deck === null) {
      throw new Error('Deck not loaded');
    }
    
    const config = this.deck.config;
    
    // Load cards by priority
    const newCards = await this.cardRepository!.getCardsByQueue(
      this.deckId,
      CardQueue.NEW,
      config.newCardsPerDay
    );
    
    const learningCards = await this.cardRepository!.getDueCards(this.deckId, 1000)
      .then(cards => cards.filter(c => c.queue === CardQueue.LEARNING));
    
    const reviewCards = await this.cardRepository!.getDueCards(this.deckId, config.reviewsPerDay)
      .then(cards => cards.filter(c => c.queue === CardQueue.REVIEW));
    
    const relearnCards = await this.cardRepository!.getDueCards(this.deckId, 1000)
      .then(cards => cards.filter(c => c.queue === CardQueue.RELEARNING));
    
    // Priority: LEARNING > RELEARNING > REVIEW > NEW
    this.cards = [
      ...learningCards,
      ...relearnCards,
      ...reviewCards,
      ...newCards
    ];
  }
  
  /**
   * Calculate session statistics
   * @private
   */
  private calculateStats(): void {
    this.stats.newCount = this.cards.filter(c => c.queue === CardQueue.NEW).length;
    this.stats.learningCount = this.cards.filter(c => c.queue === CardQueue.LEARNING).length;
    this.stats.reviewCount = this.cards.filter(c => c.queue === CardQueue.REVIEW).length;
    this.stats.relearnCount = this.cards.filter(c => c.queue === CardQueue.RELEARNING).length;
  }
  
  /**
   * Process a NEW card
   * @private
   */
  private async processNewCard(card: SRSCard, rating: Rating): Promise<void> {
    if (this.deck === null) {
      throw new Error('Deck not loaded');
    }
    
    const steps = this.deck.config.learningSteps;
    
    if (rating === Rating.AGAIN) {
      // Stay NEW, reschedule for soon
      card.queue = CardQueue.NEW;
      card.dueDate = Date.now() + this.minutesToMs(1); // 1 minute
    } else if (rating === Rating.EASY) {
      // Graduate immediately to REVIEW
      card.queue = CardQueue.REVIEW;
      card.left = 0;
      this.applyFSRS(card, rating);
    } else {
      // Enter LEARNING queue
      card.queue = CardQueue.LEARNING;
      card.left = steps.length - 1; // Remaining steps
      
      // Schedule for first learning step
      const stepInterval = steps[0];
      card.dueDate = Date.now() + this.minutesToMs(stepInterval);
      card.interval = stepInterval / 1440; // Convert to days
    }
    
    card.reps = 0;
    card.updatedAt = Date.now();
  }
  
  /**
   * Process a LEARNING or RELEARNING card
   * @private
   */
  private async processLearningCard(card: SRSCard, rating: Rating): Promise<void> {
    if (this.deck === null) {
      throw new Error('Deck not loaded');
    }
    
    const steps = card.queue === CardQueue.LEARNING 
      ? this.deck.config.learningSteps
      : this.deck.config.relearningSteps;
    
    if (rating === Rating.AGAIN) {
      // Reset to first step
      card.left = steps.length - 1;
      const stepInterval = steps[0];
      card.dueDate = Date.now() + this.minutesToMs(stepInterval);
      card.interval = stepInterval / 1440;
      card.lapses++;
    } else if (rating === Rating.GOOD || rating === Rating.EASY) {
      // Move to next step or graduate
      if (card.left > 0) {
        card.left--;
        const stepIndex = steps.length - card.left - 1;
        const stepInterval = steps[stepIndex];
        card.dueDate = Date.now() + this.minutesToMs(stepInterval);
        card.interval = stepInterval / 1440;
      } else {
        // Graduate to REVIEW
        card.queue = CardQueue.REVIEW;
        card.left = 0;
        this.applyFSRS(card, rating);
      }
    } else if (rating === Rating.HARD) {
      // Repeat current step or move forward slowly
      const currentStepIndex = steps.length - card.left - 1;
      const stepInterval = steps[currentStepIndex];
      card.dueDate = Date.now() + this.minutesToMs(stepInterval * 1.2); // 20% longer
      card.interval = stepInterval * 1.2 / 1440;
    }
    
    card.updatedAt = Date.now();
  }
  
  /**
   * Process a REVIEW card
   * @private
   */
  private async processReviewCard(card: SRSCard, rating: Rating): Promise<void> {
    if (this.deck === null) {
      throw new Error('Deck not loaded');
    }
    
    if (rating === Rating.AGAIN) {
      // Move to RELEARNING
      card.queue = CardQueue.RELEARNING;
      card.left = this.deck.config.relearningSteps.length - 1;
      const stepInterval = this.deck.config.relearningSteps[0];
      card.dueDate = Date.now() + this.minutesToMs(stepInterval);
      card.interval = stepInterval / 1440;
      card.lapses++;
    } else {
      // Apply FSRS algorithm
      this.applyFSRS(card, rating);
    }
    
    card.updatedAt = Date.now();
  }
  
  /**
   * Apply FSRS algorithm to update card state
   * @private
   */
  private applyFSRS(card: SRSCard, rating: Rating): void {
    const elapsedDays = this.calculateElapsedDays(card);
    
    // Use FSRS algorithm
    const result: ReviewResult = this.fsrsAlgorithm.review(
      card.fsrsState,
      rating,
      elapsedDays
    );
    
    // Update card
    card.fsrsState = result.newState;
    card.dueDate = result.nextReviewMs;
    card.interval = result.intervalDays;
    card.reps = result.newState.reps;
    card.lapses = result.newState.lapses;
  }
  
  /**
   * Calculate elapsed days since last review
   * @private
   */
  private calculateElapsedDays(card: SRSCard): number {
    if (card.reps === 0) {
      return 0;
    }
    
    const now = Date.now();
    const elapsed = now - (card.dueDate - this.daysToMs(card.interval));
    return elapsed / (24 * 60 * 60 * 1000);
  }
  
  /**
   * Convert minutes to milliseconds
   * @private
   */
  private minutesToMs(minutes: number): number {
    return minutes * 60 * 1000;
  }
  
  /**
   * Convert days to milliseconds
   * @private
   */
  private daysToMs(days: number): number {
    return days * 24 * 60 * 60 * 1000;
  }
}
