// =====================================================
// Algorithm.ets - FSRS (Free Spaced Repetition Scheduler)
// Simplified implementation for Vignette
// =====================================================
import {
  FSRSState,
  Rating,
  HistoryItem,
  WordItem,
  WordStatus
} from '../model/WordModel';
import { LearningStepsPolicy, LearningStepsDecision } from './LearningStepsPolicy';
import { FSRSParameterStore } from './FSRSOptimizer';

/**
 * FSRS Algorithm Parameters
 * These can be tuned for optimal learning
 */
class FSRSParams {
  static readonly DEFAULT_W: number[] = [
    0.4, 0.9, 2.3, 10.9, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94,
    2.18, 0.05, 0.34, 1.26, 0.29, 2.61, 0.96, 0.08, 0.04, 0.15
  ];
  static readonly DEFAULT_REQUEST_RETENTION: number = 0.9;
  static readonly DEFAULT_MAXIMUM_INTERVAL: number = 36500;

  static readonly MIN_DIFFICULTY: number = 1.0;
  static readonly MAX_DIFFICULTY: number = 10.0;
  static readonly MIN_STABILITY: number = 0.1;
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
 * Based on FSRS v6.1.1
 */
export class FSRSAlgorithm {
  private static instance: FSRSAlgorithm | null = null;

  private w: number[];
  private requestRetention: number;
  private maximumInterval: number;
  private decay: number;
  private factor: number;
  private usingOptimizedParams: boolean = false;

  private constructor() {
    this.w = [...FSRSParams.DEFAULT_W];
    this.requestRetention = FSRSParams.DEFAULT_REQUEST_RETENTION;
    this.maximumInterval = FSRSParams.DEFAULT_MAXIMUM_INTERVAL;
    
    // Try to load optimized parameters
    const storedParams = FSRSParameterStore.getInstance().loadParameters();
    if (storedParams !== null && storedParams.length >= 21) {
      this.w = storedParams;
      this.usingOptimizedParams = true;
    }
    
    // FSRS-6: Decay uses w[20]
    this.decay = -this.w[20];
    // Factor ensures R(S) = 0.9.  0.9 = (1 + factor * 1)^decay  =>  factor = 0.9^(1/decay) - 1
    this.factor = Math.pow(0.9, 1 / this.decay) - 1;
  }

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
   * Check if using optimized parameters
   */
  isUsingOptimizedParams(): boolean {
    return this.usingOptimizedParams;
  }

  /**
   * Reload parameters from store (call after optimization)
   */
  reloadParameters(): void {
    const storedParams = FSRSParameterStore.getInstance().loadParameters();
    if (storedParams !== null && storedParams.length >= 21) {
      this.w = storedParams;
      this.usingOptimizedParams = true;
      this.decay = -this.w[20];
      this.factor = Math.pow(0.9, 1 / this.decay) - 1;
    }
  }

  /**
   * Reset to default parameters
   */
  resetToDefault(): void {
    this.w = [...FSRSParams.DEFAULT_W];
    this.usingOptimizedParams = false;
    this.decay = -this.w[20];
    this.factor = Math.pow(0.9, 1 / this.decay) - 1;
    FSRSParameterStore.getInstance().clearParameters();
  }

  /**
   * Calculate new state after review
   * @param currentState Current FSRS state
   * @param rating User's rating
   * @param elapsedDays Days since last review
   * @param shortTerm Whether to use short-term update
   * @returns New review result
   */
  review(
    currentState: FSRSState,
    rating: Rating,
    elapsedDays: number = 0,
    shortTerm: boolean = false
  ): ReviewResult {
    const newState = currentState.clone();
    const now: number = Date.now();

    const needsInit: boolean = newState.stability <= 0 && newState.reps === 0 && newState.lapses === 0;
    if (needsInit) {
      newState.difficulty = this.initDifficulty(rating);
      newState.stability = this.initStability(rating);
      newState.retrievability = 1.0;
      if (rating === Rating.AGAIN) {
        newState.lapses = 1;
      } else {
        newState.reps = 1;
      }
    } else if (shortTerm) {
      newState.difficulty = this.nextDifficulty(newState.difficulty, rating);
      newState.stability = this.nextShortTermStability(newState.stability, rating);
      newState.retrievability = 1.0;
      if (rating === Rating.AGAIN) {
        newState.lapses += 1;
      } else {
        newState.reps += 1;
      }
    } else {
      const retrievability = this.forgettingCurve(elapsedDays, newState.stability);
      newState.retrievability = retrievability;
      newState.difficulty = this.nextDifficulty(newState.difficulty, rating);
      if (rating === Rating.AGAIN) {
        newState.lapses += 1;
        newState.stability = this.nextForgetStability(newState.difficulty, newState.stability, retrievability);
      } else {
        newState.reps += 1;
        newState.stability = this.nextRecallStability(newState.difficulty, newState.stability, retrievability, rating);
      }
      newState.retrievability = 1.0;
    }

    // Calculate next interval
    // FSRS-6: Dynamic interval even for AGAIN
    const intervalDays = this.nextInterval(newState.stability);

    const nextReviewMs = now + this.daysToMs(intervalDays);
    return new ReviewResult(newState, nextReviewMs, intervalDays);
  }

  setParameters(w: number[], requestRetention: number, maximumInterval: number): void {
    if (w.length >= 21) {
      this.w = [...w];
    }
    this.requestRetention = requestRetention;
    this.maximumInterval = maximumInterval;
    this.decay = -this.w[20];
    this.factor = Math.pow(0.9, 1 / this.decay) - 1;
  }

  private round2(value: number): number {
    return Math.round(value * 100) / 100;
  }

  private constrainStability(stability: number): number {
    if (!Number.isFinite(stability)) {
      return FSRSParams.MIN_STABILITY;
    }
    const rounded = this.round2(stability);
    const upperBound = Math.max(this.maximumInterval * 10, FSRSParams.MIN_STABILITY);
    return Math.min(Math.max(rounded, FSRSParams.MIN_STABILITY), upperBound);
  }

  private constrainDifficulty(difficulty: number): number {
    const rounded = this.round2(difficulty);
    return Math.min(Math.max(rounded, FSRSParams.MIN_DIFFICULTY), FSRSParams.MAX_DIFFICULTY);
  }

  private initDifficulty(rating: Rating): number {
    // FSRS-6: Linear D0 = w4 - (G-3) * w5
    const raw = this.w[4] - (rating - 3) * this.w[5];
    return this.constrainDifficulty(raw);
  }

  private initStability(rating: Rating): number {
    // FSRS-6: S0 = w[G-1]
    const raw = Math.max(this.w[rating - 1], FSRSParams.MIN_STABILITY);
    return this.round2(raw);
  }

  private forgettingCurve(elapsedDays: number, stability: number): number {
    if (stability <= 0) {
      return 0;
    }
    if (elapsedDays <= 0) {
      return 1;
    }
    // FSRS-6: Power function with w[20]
    const r = Math.pow(1 + this.factor * elapsedDays / stability, this.decay);
    return Math.max(0, Math.min(1, r));
  }

  private nextInterval(stability: number): number {
    // FSRS-6: Inverse of forgetting curve
    // I = S / factor * (R_req ^ (1/decay) - 1)
    const rawInterval = stability / this.factor * (Math.pow(this.requestRetention, 1 / this.decay) - 1);
    const fuzzedInterval = this.applyFuzz(rawInterval);
    const rounded = Math.round(fuzzedInterval);
    const clamped = Math.min(Math.max(rounded, 1), this.maximumInterval);
    return clamped;
  }

  private applyFuzz(interval: number): number {
    if (interval < 2.5) {
      return interval;
    }
    const fuzzFactor = 0.95 + Math.random() * 0.1; // ±5%
    return interval * fuzzFactor;
  }

  private nextDifficulty(d: number, rating: Rating): number {
    // FSRS-6: Mean Reversion
    // D' = w7 * D0(3) + (1 - w7) * (D - w6 * (G - 3))
    const nextD = d - this.w[6] * (rating - 3);
    const d0_3 = this.w[4] - (3 - 3) * this.w[5]; // D0(3) = w4
    const reverted = this.w[7] * d0_3 + (1 - this.w[7]) * nextD;
    return this.constrainDifficulty(reverted);
  }

  private nextRecallStability(d: number, s: number, r: number, rating: Rating): number {
    // FSRS-6.1.1 Recall Stability
    // S' = S * (1 + exp(w17 * (G - 3 + w18)) * (11 - D) * S^-w19 * (exp((1 - R) * w14) - 1) * HardPenalty * EasyBonus)
    // Keep D/R in the formula and clamp edge cases for numerical stability.
    const safeS = Math.max(s, FSRSParams.MIN_STABILITY);
    const safeD = Math.min(Math.max(d, FSRSParams.MIN_DIFFICULTY), FSRSParams.MAX_DIFFICULTY);
    const safeR = Math.min(Math.max(r, 0), 1);

    const hardPenalty = rating === Rating.HARD ? this.w[15] : 1;
    const easyBonus = rating === Rating.EASY ? this.w[16] : 1;

    const difficultyFactor = 11 - safeD;
    const retrievabilityFactor = Math.exp((1 - safeR) * this.w[14]) - 1;
    const sInc = Math.exp(this.w[17] * (rating - 3 + this.w[18])) *
      difficultyFactor *
      Math.pow(safeS, -this.w[19]) *
      retrievabilityFactor *
      hardPenalty *
      easyBonus;

    const raw = safeS * (1 + sInc);
    return this.constrainStability(raw);
  }

  private nextForgetStability(d: number, s: number, r: number): number {
    // FSRS-6: Forgetting Stability
    // Uses w[11]..w[14]
    const raw = this.w[11] *
      Math.pow(d, -this.w[12]) *
      (Math.pow(s + 1, this.w[13]) - 1) *
      Math.exp((1 - r) * this.w[14]);
    return this.round2(Math.min(raw, s));
  }

  private nextShortTermStability(s: number, rating: Rating): number {
    // FSRS-6: Short Term Stability
    // Uses w[8]..w[10]
    const sInc = Math.exp(this.w[8] * (rating - 3 + this.w[9])) * Math.pow(s, -this.w[10]);
    return this.round2(s * sInc);
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
   * Determine new word status based on state
   */
  determineStatus(state: FSRSState): WordStatus {
    if (state.reps === 0 && state.stability <= 0) {
      return WordStatus.NEW;
    } else if (state.lapses > 0 && state.stability < 1) {
      return WordStatus.RELEARNING;
    } else if (state.reps < 2) {
      return WordStatus.LEARNING;
    } else {
      return WordStatus.REVIEW;
    }
  }

  /**
   * Preview intervals for all ratings
   * Returns map of rating -> interval in days
   */
  previewIntervals(currentState: FSRSState, elapsedDays: number, shortTerm: boolean = false): Map<Rating, number> {
    const intervals = new Map<Rating, number>();

    const ratings:  Rating[] = [Rating.AGAIN, Rating.HARD, Rating.GOOD, Rating.EASY];
    for (const rating of ratings) {
      const result = this.review(currentState.clone(), rating, elapsedDays, shortTerm);
      intervals.set(rating, result.intervalDays);
    }

    return intervals;
  }
}

/**
 * Helper class to process word reviews
 */
export class WordReviewer {
  private algorithm: FSRSAlgorithm;
  private learningStepsPolicy: LearningStepsPolicy;

  constructor(learningStepsPolicy: LearningStepsPolicy | null = null) {
    this.algorithm = FSRSAlgorithm.getInstance();
    this.learningStepsPolicy = learningStepsPolicy ?? new LearningStepsPolicy();
  }

  /**
   * Process a review and return updated word
   * @param word The word being reviewed
   * @param rating User's rating
   * @param lastReviewMs Timestamp of last review (for elapsed calculation)
   * @returns Updated WordItem with new state and history
   */
  processReview(
    word: WordItem,
    rating: Rating,
    lastReviewMs: number = 0,
    useLocalInterval: boolean = false,
    localIntervalDays: number = 0,
    elapsedDays: number = -1
  ): WordItem {
    // Calculate elapsed days
    let finalElapsedDays = 0;
    if (elapsedDays >= 0) {
      finalElapsedDays = elapsedDays;
    } else if (lastReviewMs > 0 && word.history.getReviewCount() > 0) {
      finalElapsedDays = this.algorithm.calculateElapsedDays(lastReviewMs);
    }

    // Clone current state for history
    const stateBefore = word.fsrsState.clone();

    const isLearningWord: boolean = word.status === WordStatus.NEW
      || word.status === WordStatus.LEARNING
      || word.status === WordStatus.RELEARNING;
    // Always use shortTerm logic for learning words (Fix Issue 4)
    const shortTerm: boolean = isLearningWord;

    // Calculate new state
    const result = this.algorithm.review(word.fsrsState, rating, finalElapsedDays, shortTerm);

    const nextStatus: WordStatus = this.algorithm.determineStatus(result.newState);

    let intervalDays: number;
    if (useLocalInterval) {
      intervalDays = localIntervalDays;
    } else {
      intervalDays = result.intervalDays;
    }

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
    word.status = nextStatus;

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

    const shortTerm: boolean = word.status === WordStatus.NEW
      || word.status === WordStatus.LEARNING
      || word.status === WordStatus.RELEARNING;
    const intervals = this.algorithm.previewIntervals(word.fsrsState, elapsedDays, shortTerm);
    const formatted = new Map<Rating, string>();

    intervals.forEach((days: number, rating: Rating) => {
      // Fix Issue 1: Apply LearningStepsPolicy override to preview
      let finalDays = days;
      // Note: We need to simulate the 'nextStatus' for policy check.
      // But determineStatus needs the *new* state which we don't have here easily without re-running logic.
      // However, LearningStepsPolicy mostly cares about 'rating'.
      // For accurate check, we should simulate the review.
      
      // Simulating review to get next status for policy
      const result = this.algorithm.review(word.fsrsState, rating, elapsedDays, shortTerm);
      const nextStatus = this.algorithm.determineStatus(result.newState);
      
      const decision = this.learningStepsPolicy.decide(word, nextStatus, rating);
      if (decision.shouldOverrideInterval) {
        finalDays = decision.intervalDays;
      }
      
      formatted.set(rating, this.formatInterval(finalDays));
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
