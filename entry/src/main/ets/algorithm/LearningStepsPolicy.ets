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

export class LearningStepsPolicy {
  private static readonly MINUTES_PER_DAY: number = 24 * 60;
  private static readonly DEFAULT_STEP_MINUTES: number[] = [5, 120];
  private stepMinutes: number[] = LearningStepsPolicy.DEFAULT_STEP_MINUTES.slice();

  constructor(stepMinutes: number[] = LearningStepsPolicy.DEFAULT_STEP_MINUTES) {
    this.setStepMinutes(stepMinutes);
  }

  setStepMinutes(stepMinutes: number[]): void {
    this.stepMinutes = LearningStepsPolicy.normalizeStepMinutes(stepMinutes);
  }

  decide(word: WordItem, nextStatus: WordStatus, rating: Rating): LearningStepsDecision {
    if (rating === Rating.AGAIN) {
      const minutes = this.getStepMinutesAt(0);
      return new LearningStepsDecision(true, this.minutesToDays(minutes), true, 1, false);
    }

    if (nextStatus !== WordStatus.NEW && nextStatus !== WordStatus.LEARNING && nextStatus !== WordStatus.RELEARNING) {
      return new LearningStepsDecision(false, 0, false, 0, false);
    }

    if (rating === Rating.HARD) {
      const minutes = this.getStepMinutesAt(1);
      return new LearningStepsDecision(true, this.minutesToDays(minutes), false, 0, true);
    }

    // Fix Issue 6: Allow graduation for GOOD/EASY (let FSRS decide interval >= 1 day)
    if (rating === Rating.GOOD) {
      return new LearningStepsDecision(false, 0, false, 0, false);
    }

    if (rating === Rating.EASY) {
      return new LearningStepsDecision(false, 0, false, 0, false);
    }

    return new LearningStepsDecision(false, 0, false, 0, false);
  }

  private minutesToDays(minutes: number): number {
    return minutes / LearningStepsPolicy.MINUTES_PER_DAY;
  }

  private getStepMinutesAt(index: number): number {
    if (index >= 0 && index < this.stepMinutes.length) {
      return this.stepMinutes[index];
    }
    if (index > 0 && this.stepMinutes.length > 0) {
      return this.stepMinutes[0];
    }
    return LearningStepsPolicy.DEFAULT_STEP_MINUTES[index] ?? LearningStepsPolicy.DEFAULT_STEP_MINUTES[0];
  }

  private static normalizeStepMinutes(stepMinutes: number[]): number[] {
    const normalized: number[] = [];
    for (const value of stepMinutes) {
      if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
        normalized.push(Math.round(value));
      }
    }
    if (normalized.length === 0) {
      return LearningStepsPolicy.DEFAULT_STEP_MINUTES.slice();
    }
    return normalized;
  }
}
