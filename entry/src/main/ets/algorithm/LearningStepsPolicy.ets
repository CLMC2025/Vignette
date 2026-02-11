import { Rating, WordItem, WordStatus } from '../model/WordModel';

export class LearningStepsDecision {
  shouldOverrideInterval: boolean;
  intervalDays: number;
  shouldRequeueInSession: boolean;
  requeueOffset: number;
  allowReinforcementOnPass: boolean;

  constructor(
    shouldOverrideInterval: boolean,
    intervalDays: number,
    shouldRequeueInSession: boolean,
    requeueOffset: number,
    allowReinforcementOnPass: boolean
  ) {
    this.shouldOverrideInterval = shouldOverrideInterval;
    this.intervalDays = intervalDays;
    this.shouldRequeueInSession = shouldRequeueInSession;
    this.requeueOffset = requeueOffset;
    this.allowReinforcementOnPass = allowReinforcementOnPass;
  }
}

/**
 * Learning Steps Policy (FSRS v5 Compatible)
 * 
 * Key principle: Learning steps apply ONLY for the first 2-3 reviews of a new word.
 * After that, we trust FSRS v5's scientific intervals.
 * 
 * Learning state criteria:
 * - NEW: reps = 0 (never reviewed)
 * - LEARNING: reps < 3 AND stability < 7 days (still in initial learning phase)
 * - REVIEW/MASTERED: reps >= 3 OR stability >= 7 days (graduated to FSRS scheduling)
 */
export class LearningStepsPolicy {
  private static readonly MINUTES_PER_DAY: number = 24 * 60;
  private static readonly LEARNING_PHASE_MAX_REPS: number = 2; // First 2 reviews use learning steps
  private static readonly LEARNING_PHASE_MAX_STABILITY: number = 7.0; // < 7 days = still learning

  /**
   * Decide whether to apply learning steps or trust FSRS
   * 
   * @param word The word being reviewed
   * @param nextStatus Status after review
   * @param rating User's rating
   * @returns Decision object
   */
  decide(word: WordItem, nextStatus: WordStatus, rating: Rating): LearningStepsDecision {
    const reps = word.fsrsState.reps;
    const stability = word.fsrsState.stability;

    // ALWAYS use short interval for AGAIN (immediate reinforcement)
    if (rating === Rating.AGAIN) {
      // Use 5-minute interval for immediate re-learning
      return new LearningStepsDecision(true, this.minutesToDays(5), true, 1, false);
    }

    // Check if word has graduated from learning phase
    const hasGraduated = (reps >= LearningStepsPolicy.LEARNING_PHASE_MAX_REPS) ||
                        (stability >= LearningStepsPolicy.LEARNING_PHASE_MAX_STABILITY);

    if (hasGraduated) {
      // Word has graduated: trust FSRS completely
      return new LearningStepsDecision(false, 0, false, 0, false);
    }

    // Still in learning phase (first 2 reviews, stability < 7 days)
    if (nextStatus === WordStatus.NEW || nextStatus === WordStatus.LEARNING) {
      if (rating === Rating.HARD) {
        // HARD during learning: 2-hour interval, allow reinforcement
        return new LearningStepsDecision(true, this.minutesToDays(120), false, 0, true);
      }

      if (rating === Rating.GOOD) {
        // GOOD during early learning: trust FSRS but cap at 1-2 days if needed
        // Actually, let FSRS decide - it already gives appropriate intervals for new words
        return new LearningStepsDecision(false, 0, false, 0, false);
      }

      if (rating === Rating.EASY) {
        // EASY during learning: trust FSRS (it gives longer intervals for EASY)
        return new LearningStepsDecision(false, 0, false, 0, false);
      }
    }

    // Default: trust FSRS
    return new LearningStepsDecision(false, 0, false, 0, false);
  }

  private minutesToDays(minutes: number): number {
    return minutes / LearningStepsPolicy.MINUTES_PER_DAY;
  }

  /**
   * Check if a word is still in the learning phase
   * Useful for UI indicators
   */
  static isInLearningPhase(word: WordItem): boolean {
    return (word.fsrsState.reps < LearningStepsPolicy.LEARNING_PHASE_MAX_REPS) &&
           (word.fsrsState.stability < LearningStepsPolicy.LEARNING_PHASE_MAX_STABILITY);
  }
}

