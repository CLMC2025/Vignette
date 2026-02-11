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

  decide(word: WordItem, nextStatus: WordStatus, rating: Rating): LearningStepsDecision {
    if (rating === Rating.AGAIN) {
      return new LearningStepsDecision(true, this.minutesToDays(5), true, 1, false);
    }

    if (nextStatus !== WordStatus.NEW && nextStatus !== WordStatus.LEARNING) {
      return new LearningStepsDecision(false, 0, false, 0, false);
    }

    if (rating === Rating.HARD) {
      // Fix Issue 2: Increase HARD interval to 120min (2 hours) and do not requeue in short session
      return new LearningStepsDecision(true, this.minutesToDays(120), false, 0, true);
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
}

