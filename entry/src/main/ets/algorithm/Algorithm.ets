// =====================================================
// Algorithm.ets - FSRS (Free Spaced Repetition Scheduler)
// FSRS v5 Implementation with 19-parameter model
// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
// =====================================================

import {
  FSRSState,
  Rating,
  HistoryItem,
  WordItem,
  WordStatus
} from '../model/WordModel';
import { EvolveScheduler, SchedulerMode } from '../evolve/EvolveScheduler';

/**
 * FSRS v5 Algorithm Parameters (19 weights)
 * Default parameters from FSRS v5 research
 * Can be customized for optimal learning
 */
class FSRSParams {
  /**
   * FSRS v5 default weights (19 parameters)
   * [w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15, w16, w17, w18]
   */
  static readonly DEFAULT_WEIGHTS: number[] = [
    0.40255,  // w[0]: Initial stability for AGAIN (G=1)
    1.18385,  // w[1]: Initial stability for HARD (G=2)
    3.173,    // w[2]: Initial stability for GOOD (G=3)
    15.69105, // w[3]: Initial stability for EASY (G=4)
    7.1949,   // w[4]: Initial difficulty (base)
    0.5345,   // w[5]: Difficulty decay factor
    1.4604,   // w[6]: Difficulty delta multiplier
    0.0046,   // w[7]: Mean reversion weight
    1.54575,  // w[8]: Stability success factor (base)
    0.1192,   // w[9]: Stability power for success
    1.01925,  // w[10]: Retrievability bonus for success
    1.9395,   // w[11]: Stability failure factor (base)
    0.11,     // w[12]: Difficulty power for failure
    0.29605,  // w[13]: Stability power for failure
    2.2698,   // w[14]: Retrievability penalty for failure
    0.2315,   // w[15]: Hard rating multiplier (G=2)
    2.9898,   // w[16]: Easy rating multiplier (G=4)
    0.51655,  // w[17]: Same-day review factor
    0.6621    // w[18]: Same-day review offset
  ];

  // Minimum/Maximum bounds
  static readonly MIN_DIFFICULTY: number = 1.0;
  static readonly MAX_DIFFICULTY: number = 10.0;
  static readonly MIN_STABILITY: number = 0.1;
  static readonly MAX_STABILITY: number = 365.0;

  // Retrievability decay (FSRS v5 formula)
  static readonly DECAY: number = -0.5;
  static readonly FACTOR: number = 19 / 81;

  // Request retention (default 0.9 = 90%)
  static readonly REQUEST_RETENTION: number = 0.9;
}

/**
 * Result of a review calculation
 */
export class ReviewResult {
  newState: FSRSState;
  nextReviewMs: number;      // Timestamp for next review
  intervalDays: number;      // Days until next review

  constructor(
    newState: FSRSState,
    nextReviewMs: number,
    intervalDays: number
  ) {
    this.newState = newState;
    this.nextReviewMs = nextReviewMs;
    this.intervalDays = intervalDays;
  }
}

/**
 * FSRS Algorithm Implementation
 * Implements FSRS v5 with 19-parameter model
 */
export class FSRSAlgorithm {
  private static instance: FSRSAlgorithm | null = null;
  
  // Configurable weights (can be evolved/optimized)
  private weights: number[] = FSRSParams.DEFAULT_WEIGHTS;
  
  // Performance optimization: cache preview intervals
  private intervalCache: Map<string, Map<Rating, number>> = new Map<string, Map<Rating, number>>();
  private readonly MAX_CACHE_SIZE: number = 200;

  private constructor() {}

  /**
   * Singleton accessor
   */
  static getInstance(): FSRSAlgorithm {
    if (FSRSAlgorithm.instance === null) {
      FSRSAlgorithm.instance = new FSRSAlgorithm();
    }
    return FSRSAlgorithm.instance;
  }

  /**
   * Set custom weights for optimization
   */
  setWeights(customWeights: number[]): void {
    if (customWeights.length === 19) {
      this.weights = [...customWeights];
      this.clearCache(); // Clear cache when weights change
    }
  }

  /**
   * Get current weights
   */
  getWeights(): number[] {
    return [...this.weights];
  }

  /**
   * Calculate new state after review (Main entry point)
   * @param currentState Current FSRS state
   * @param rating User's rating
   * @param elapsedDays Days since last review
   * @returns New review result
   */
  review(
    currentState: FSRSState,
    rating: Rating,
    elapsedDays: number = 0
  ): ReviewResult {
    // Clone state to avoid mutation
    const newState = currentState.clone();

    // First review (new word)
    if (currentState.reps === 0) {
      return this.handleFirstReview(newState, rating);
    }

    // Subsequent reviews
    return this.handleSubsequentReview(newState, rating, elapsedDays);
  }

  /**
   * Handle first review of a new word
   * FSRS v5: S0(G) = w[G-1]
   */
  private handleFirstReview(state: FSRSState, rating: Rating): ReviewResult {
    // Initial stability: S0(G) = w[G-1]
    const stability = this.weights[rating - 1];
    state.stability = this.clampStability(stability);
    
    // Initial difficulty: D0(G) = w4 - e^(w5 * (G-1)) + 1
    state.difficulty = this.calculateInitialDifficulty(rating);
    state.retrievability = 1.0;

    // Calculate interval based on new stability
    let intervalDays: number;
    if (rating === Rating.AGAIN) {
      intervalDays = this.minutesToDays(10); // 10 minutes for lapse
      state.lapses = 1;
    } else {
      state.reps = 1;
      intervalDays = this.calculateInterval(state.stability);
    }

    const nextReviewMs = Date.now() + this.daysToMs(intervalDays);
    return new ReviewResult(state, nextReviewMs, intervalDays);
  }

  /**
   * Handle subsequent reviews
   */
  private handleSubsequentReview(
    state: FSRSState,
    rating: Rating,
    elapsedDays: number
  ): ReviewResult {
    // Calculate current retrievability based on elapsed time
    const retrievability = this.calculateRetrievabilityInternal(state.stability, elapsedDays);
    state.retrievability = retrievability;

    // Update difficulty with linear damping and mean reversion
    state.difficulty = this.updateDifficulty(state.difficulty, rating);

    let newStability: number;
    let intervalDays: number;

    // Check if same-day review (elapsed < 1 day)
    const isSameDayReview = elapsedDays < 1.0;

    if (rating === Rating.AGAIN) {
      // Failed recall - lapse
      state.lapses += 1;
      newStability = this.calculateFailStability(
        state.stability,
        state.difficulty,
        retrievability
      );
      intervalDays = this.minutesToDays(10); // 10 minutes for lapse
    } else {
      // Successful recall
      state.reps += 1;
      
      if (isSameDayReview) {
        // Same-day review formula: S' = S * e^(w17 * (G-3+w18))
        newStability = this.calculateSameDayStability(state.stability, rating);
      } else {
        // Normal success formula
        newStability = this.calculateSuccessStability(
          state.stability,
          state.difficulty,
          retrievability,
          rating
        );
      }
      
      intervalDays = this.calculateInterval(newStability);
    }

    state.stability = this.clampStability(newStability);
    state.retrievability = 1.0; // Reset after review

    const nextReviewMs = Date.now() + this.daysToMs(intervalDays);
    return new ReviewResult(state, nextReviewMs, intervalDays);
  }

  /**
   * Calculate initial difficulty based on first rating
   * FSRS v5: D0(G) = w4 - e^(w5 * (G-1)) + 1
   */
  private calculateInitialDifficulty(rating: Rating): number {
    const w4 = this.weights[4];
    const w5 = this.weights[5];
    const G = rating;
    
    const d0 = w4 - Math.exp(w5 * (G - 1)) + 1;
    return this.clampDifficulty(d0);
  }

  /**
   * Update difficulty after review with linear damping and mean reversion
   * FSRS v5: 
   * 1. ΔD = -w6 * (G-3)
   * 2. D' = D + ΔD * (10-D)/9 (linear damping)
   * 3. D'' = w7 * D0(4) + (1-w7) * D' (mean reversion)
   */
  private updateDifficulty(currentD: number, rating: Rating): number {
    const w6 = this.weights[6];
    const w7 = this.weights[7];
    const G = rating;
    
    // Step 1: Calculate difficulty delta
    const deltaD = -w6 * (G - 3);
    
    // Step 2: Apply linear damping
    const dPrime = currentD + deltaD * (10 - currentD) / 9;
    
    // Step 3: Apply mean reversion toward D0(4)
    const d0_4 = this.calculateInitialDifficulty(Rating.EASY);
    const dDoublePrime = w7 * d0_4 + (1 - w7) * dPrime;
    
    return this.clampDifficulty(dDoublePrime);
  }

  /**
   * Calculate stability after successful recall
   * FSRS v5: S'_r = S * (e^w8 * (11-D) * S^(-w9) * (e^(w10*(1-R)) - 1) * w15(if G=2) * w16(if G=4) + 1)
   */
  private calculateSuccessStability(
    s: number,
    d: number,
    r: number,
    rating: Rating
  ): number {
    const w8 = this.weights[8];
    const w9 = this.weights[9];
    const w10 = this.weights[10];
    const w15 = this.weights[15];
    const w16 = this.weights[16];
    
    // Base formula components
    const difficultyFactor = 11 - d;
    const stabilityPower = Math.pow(s, -w9);
    const retrievabilityBonus = Math.exp(w10 * (1 - r)) - 1;
    
    // Rating-specific multiplier
    let ratingMultiplier = 1.0;
    if (rating === Rating.HARD) {
      ratingMultiplier = w15;
    } else if (rating === Rating.EASY) {
      ratingMultiplier = w16;
    }
    
    // Complete formula
    const sInc = Math.exp(w8) * difficultyFactor * stabilityPower * retrievabilityBonus * ratingMultiplier + 1;
    const newS = s * sInc;
    
    return newS;
  }

  /**
   * Calculate stability after failed recall (lapse)
   * FSRS v5: S'_f = w11 * D^(-w12) * ((S+1)^w13 - 1) * e^(w14*(1-R))
   */
  private calculateFailStability(s: number, d: number, r: number): number {
    const w11 = this.weights[11];
    const w12 = this.weights[12];
    const w13 = this.weights[13];
    const w14 = this.weights[14];
    
    const difficultyPower = Math.pow(d, -w12);
    const stabilityComponent = Math.pow(s + 1, w13) - 1;
    const retrievabilityPenalty = Math.exp(w14 * (1 - r));
    
    const newS = w11 * difficultyPower * stabilityComponent * retrievabilityPenalty;
    
    return Math.max(FSRSParams.MIN_STABILITY, newS);
  }

  /**
   * Calculate stability for same-day review
   * FSRS v5: S' = S * e^(w17 * (G-3+w18))
   */
  private calculateSameDayStability(s: number, rating: Rating): number {
    const w17 = this.weights[17];
    const w18 = this.weights[18];
    const G = rating;
    
    const exponent = w17 * (G - 3 + w18);
    const newS = s * Math.exp(exponent);
    
    return newS;
  }

  /**
   * Calculate retrievability based on elapsed time (internal)
   * FSRS v5: R(t,S) = (1 + FACTOR * t/S)^DECAY where FACTOR=19/81, DECAY=-0.5
   */
  private calculateRetrievabilityInternal(stability: number, elapsedDays: number): number {
    if (stability <= 0) return 0;
    if (elapsedDays <= 0) return 1;

    const r = Math.pow(1 + FSRSParams.FACTOR * elapsedDays / stability, FSRSParams.DECAY);

    return Math.max(0, Math.min(1, r));
  }

  /**
   * Calculate interval from stability
   * FSRS v5: I = (S/FACTOR) * (r^(1/DECAY) - 1) for request retention r=0.9
   */
  private calculateInterval(stability: number): number {
    const r = FSRSParams.REQUEST_RETENTION;
    const factor = FSRSParams.FACTOR;
    const decay = FSRSParams.DECAY;
    
    const interval = (stability / factor) * (Math.pow(r, 1 / decay) - 1);
    
    return Math.max(1, Math.round(interval));
  }

  /**
   * Clamp difficulty to valid range
   */
  private clampDifficulty(d: number): number {
    return Math.max(
      FSRSParams.MIN_DIFFICULTY,
      Math.min(FSRSParams.MAX_DIFFICULTY, d)
    );
  }

  /**
   * Clamp stability to valid range
   */
  private clampStability(s: number): number {
    return Math.max(
      FSRSParams.MIN_STABILITY,
      Math.min(FSRSParams.MAX_STABILITY, s)
    );
  }

  /**
   * Convert days to milliseconds
   */
  private daysToMs(days: number): number {
    return days * 24 * 60 * 60 * 1000;
  }

  /**
   * Convert minutes to days (fraction)
   */
  private minutesToDays(minutes: number): number {
    return minutes / (24 * 60);
  }

  /**
   * Calculate elapsed days since last review
   */
  calculateElapsedDays(lastReviewMs: number): number {
    const now = Date.now();
    const elapsedMs = now - lastReviewMs;
    return elapsedMs / (24 * 60 * 60 * 1000);
  }

  /**
   * Calculate retrievability (public method for testing)
   * FSRS v5: R(t,S) = (1 + FACTOR * t/S)^DECAY
   */
  calculateRetrievability(stability: number, elapsedDays: number): number {
    return this.calculateRetrievabilityInternal(stability, elapsedDays);
  }

  /**
   * Determine new word status based on state
   */
  determineStatus(state: FSRSState): WordStatus {
    if (state.reps === 0) {
      return WordStatus.NEW;
    } else if (state.reps < 2 || state.stability < 1) {
      return WordStatus.LEARNING;
    } else if (state.stability >= 21) {
      return WordStatus.MASTERED;
    } else {
      return WordStatus.REVIEW;
    }
  }

  /**
   * Preview intervals for all ratings
   * Returns map of rating -> interval in days
   * Performance optimized with caching
   */
  previewIntervals(currentState: FSRSState, elapsedDays:  number): Map<Rating, number> {
    // Generate cache key from state parameters
    const cacheKey = `${currentState.stability.toFixed(2)}_${currentState.difficulty.toFixed(2)}_${currentState.reps}_${elapsedDays}`;
    
    // Check cache first
    const cached = this.intervalCache.get(cacheKey);
    if (cached !== undefined) {
      return cached;
    }
    
    // Calculate intervals
    const intervals = new Map<Rating, number>();
    const ratings:  Rating[] = [Rating.AGAIN, Rating.HARD, Rating.GOOD, Rating.EASY];
    for (const rating of ratings) {
      const result = this.review(currentState.clone(), rating, elapsedDays);
      intervals.set(rating, result.intervalDays);
    }
    
    // Store in cache with size limit
    if (this.intervalCache.size >= this.MAX_CACHE_SIZE) {
      // Remove oldest entry (first key)
      const firstKey = this.intervalCache.keys().next().value;
      this.intervalCache.delete(firstKey);
    }
    this.intervalCache.set(cacheKey, intervals);

    return intervals;
  }
  
  /**
   * Clear the interval cache (useful for testing or memory management)
   */
  clearCache(): void {
    this.intervalCache.clear();
  }
}

/**
 * Helper class to process word reviews
 */
export class WordReviewer {
  private algorithm: FSRSAlgorithm;

  constructor() {
    this.algorithm = FSRSAlgorithm.getInstance();
  }

  /**
   * Process a review and return updated word
   * @param word The word being reviewed
   * @param rating User's rating
   * @param lastReviewMs Timestamp of last review (for elapsed calculation)
   * @returns Updated WordItem with new state and history
   */
  processReview(word: WordItem, rating: Rating, lastReviewMs: number = 0): WordItem {
    // Calculate elapsed days
    let elapsedDays = 0;
    if (lastReviewMs > 0 && word.history.getReviewCount() > 0) {
      elapsedDays = this.algorithm.calculateElapsedDays(lastReviewMs);
    }

    // Clone current state for history
    const stateBefore = word.fsrsState.clone();

    const isFirstReview = (word.fsrsState.reps === 0);

    // Calculate new state
    const result = this.algorithm.review(word.fsrsState, rating, elapsedDays);

    // Optionally adjust next interval using evolved policy
    const mode: SchedulerMode = EvolveScheduler.getMode();
    const intervalDays: number = EvolveScheduler.decideIntervalDays(
      mode,
      rating,
      isFirstReview,
      result.intervalDays,
      result.newState
    );

    const nextReviewMs: number = Date.now() + intervalDays * 24 * 60 * 60 * 1000;

    // Create history item
    const historyItem = new HistoryItem(
      Date.now(),
      rating,
      stateBefore,
      result.newState.clone(),
      intervalDays
    );

    // Update word
    word.fsrsState = result.newState;
    word.dueDate = nextReviewMs;
    word.history.addEntry(historyItem);
    word.updatedAt = Date.now();

    // Update status
    word.status = this.algorithm.determineStatus(word.fsrsState);

    return word;
  }

  /**
   * Get preview of next intervals for UI display
   */
  getIntervalPreviews(word: WordItem): Map<Rating, string> {
    const lastReviewMs = this.getLastReviewTime(word);
    const elapsedDays = lastReviewMs > 0
      ? this.algorithm.calculateElapsedDays(lastReviewMs)
      : 0;

    const intervals = this.algorithm.previewIntervals(word.fsrsState, elapsedDays);
    const formatted = new Map<Rating, string>();

    intervals.forEach((days:  number, rating: Rating) => {
      formatted.set(rating, this.formatInterval(days));
    });

    return formatted;
  }

  /**
   * Format interval for display
   */
  private formatInterval(days: number): string {
    if (days < 1 / 24) {
      // Less than 1 hour
      const minutes = Math.round(days * 24 * 60);
      return `${minutes}m`;
    } else if (days < 1) {
      // Less than 1 day
      const hours = Math.round(days * 24);
      return `${hours}h`;
    } else if (days < 30) {
      return `${Math.round(days)}d`;
    } else if (days < 365) {
      const months = Math.round(days / 30);
      return `${months}mo`;
    } else {
      const years = Math.round(days / 365 * 10) / 10;
      return `${years}y`;
    }
  }

  /**
   * Get last review timestamp
   */
  private getLastReviewTime(word: WordItem): number {
    const count = word.history.getReviewCount();
    if (count > 0) {
      return word.history.items[count - 1].timestamp;
    }
    return 0;
  }
}