import { WordItem, Rating, WordStatus } from '../../../model/WordModel';
import { WordReviewer } from '../../../algorithm/Algorithm';
import { LearningStepsPolicy, LearningStepsDecision } from '../../../algorithm/LearningStepsPolicy';
import { ReviewTimeManager } from '../../../manager/ReviewTimeManager';
import { DBManager } from '../../../database/DBManager';
import { TaskItem, TaskType, TaskDifficulty } from '../../../manager/SessionPlanner';

export interface ReviewTimeRecordSummary {
  word: string;
  duration: number;
  rating: number;
}

export interface ReviewResult {
  updatedWord: WordItem;
  rating: Rating;
  nextReviewHint: string;
  learningDecision: LearningStepsDecision;
  timeRecord?: ReviewTimeRecordSummary | null;
}

export class ReadPageReviewManager {
  private wordReviewer: WordReviewer;
  private learningStepsPolicy: LearningStepsPolicy;
  private reviewTimeManager: ReviewTimeManager;
  private dbManager: DBManager;

  constructor(
    wordReviewer: WordReviewer,
    learningStepsPolicy: LearningStepsPolicy,
    reviewTimeManager: ReviewTimeManager,
    dbManager: DBManager
  ) {
    this.wordReviewer = wordReviewer;
    this.learningStepsPolicy = learningStepsPolicy;
    this.reviewTimeManager = reviewTimeManager;
    this.dbManager = dbManager;
  }

  public async processReview(
    wordItem: WordItem, 
    rating: Rating, 
    reflection: string,
    todayAttemptsByWordId: Map<number, number>,
    sessionReviewedCount: number,
    sessionNewLearnedCount: number
  ): Promise<ReviewResult | null> {
    const startTime = Date.now();
    
    if (!wordItem) {
      console.warn('[ReadPageReviewManager] processReview called with null wordItem');
      return null;
    }

    if (!this.reviewTimeManager.startReview(wordItem)) {
      console.warn(`[ReadPageReviewManager] Cannot start review for "${wordItem.word}" - too soon or already active`);
      return null;
    }

    const lastReviewMs = wordItem.history.getReviewCount() > 0
      ? wordItem.history.items[wordItem.history.getReviewCount() - 1].timestamp
      : 0;

    const prevAttempts = todayAttemptsByWordId.get(wordItem.id) ?? 0;
    const isFirstAttemptInSession = prevAttempts === 0;
    let elapsedDays = 0;
    if (lastReviewMs > 0 && wordItem.history.getReviewCount() > 0) {
      elapsedDays = (Date.now() - lastReviewMs) / (24 * 60 * 60 * 1000);
    }

    let updatedWord: WordItem = wordItem;
    let prevStateJson: string = '';
    let newStateJson: string = '';
    let learningDecision: LearningStepsDecision = new LearningStepsDecision(false, 0, false, 0, false);

    if (isFirstAttemptInSession) {
      prevStateJson = wordItem.fsrsState.toJSON();
      updatedWord = this.wordReviewer.processReview(wordItem, rating, lastReviewMs, false, 0, elapsedDays);
      learningDecision = this.learningStepsPolicy.decide(updatedWord, updatedWord.status, rating);
      
      if (learningDecision.shouldOverrideInterval) {
        this.applyLearningStepInterval(updatedWord, learningDecision.intervalDays);
        
        const lastIdx = updatedWord.history.getReviewCount() - 1;
        if (lastIdx >= 0) {
          updatedWord.history.items[lastIdx].scheduledDays = learningDecision.intervalDays;
        }
      }
      newStateJson = updatedWord.fsrsState.toJSON();

      if (rating === Rating.AGAIN) {
        updatedWord.incrementLapse();
        updatedWord.updateLeechLevel(updatedWord.history.items.slice(-7).map(h => h.rating));
      }

      await this.dbManager.updateWord(updatedWord);
      
      const reviewCount = updatedWord.history.getReviewCount();
      const eventTs = reviewCount > 0 ? updatedWord.history.items[reviewCount - 1].timestamp : Date.now();
      const scheduledDays = reviewCount > 0 ? updatedWord.history.items[reviewCount - 1].scheduledDays : 0;
      try {
        const eventId = `${updatedWord.id}_${eventTs}`;
        await this.dbManager.insertReviewEvent(
          eventId, 
          updatedWord.id, 
          rating as number, 
          eventTs, 
          prevStateJson, 
          newStateJson, 
          '',
          reflection,
          scheduledDays
        );
      } catch (e) {
        const err = e instanceof Error ? e.message : String(e);
        console.warn('[ReadPageReviewManager] Failed to log review event:', err);
      }
    }

    const timeRecord = this.reviewTimeManager.completeReview(updatedWord, rating as number);
    const summary: ReviewTimeRecordSummary | null = timeRecord && timeRecord.duration !== undefined && timeRecord.rating !== undefined
      ? {
        word: timeRecord.word,
        duration: timeRecord.duration,
        rating: timeRecord.rating
      }
      : null;
    const nextReviewHint = this.formatNextReviewHint(updatedWord.dueDate);

    return {
      updatedWord,
      rating,
      nextReviewHint,
      learningDecision,
      timeRecord: summary
    };
  }

  private formatNextReviewHint(dueDateMs: number): string {
    const diff = dueDateMs - Date.now();
    if (diff <= 0) {
      return '现在可复习';
    }

    const minuteMs = 60 * 1000;
    const hourMs = 60 * minuteMs;
    const dayMs = 24 * hourMs;

    if (diff < hourMs) {
      const minutes = Math.max(1, Math.round(diff / minuteMs));
      return `${minutes}分钟后复习`;
    }

    if (diff < dayMs) {
      const hours = Math.max(1, Math.round(diff / hourMs));
      return `${hours}小时后复习`;
    }

    const days = Math.max(1, Math.round(diff / dayMs));
    return `${days}天后复习`;
  }

  private applyLearningStepInterval(word: WordItem, intervalDays: number): void {
    if (intervalDays <= 0) {
      return;
    }
    word.dueDate = Date.now() + intervalDays * 24 * 60 * 60 * 1000;
    word.updatedAt = Date.now();
    const reviewCount = word.history.getReviewCount();
    if (reviewCount > 0) {
      const last = word.history.items[reviewCount - 1];
      last.scheduledDays = intervalDays;
    }
  }

  public async createReinforcementTasks(
    word: WordItem,
    rating: Rating,
    suggestedOffset: number,
    allowOnPass: boolean,
    reinforcementInsertedCount: number
  ): Promise<TaskItem[]> {
    const tasks: TaskItem[] = [];
    try {
      let maxInsertCount: number = 0;
      if (rating === Rating.AGAIN) {
        maxInsertCount = 3;
      } else if (rating === Rating.HARD) {
        maxInsertCount = 2;
      } else if (allowOnPass) {
        maxInsertCount = 1;
      }

      if (maxInsertCount <= 0 || reinforcementInsertedCount >= maxInsertCount) {
        return tasks;
      }

      // Reinforcement Task 1
      const choiceTask = new TaskItem(
        `re_choice_${word.id}_${Date.now()}`,
        TaskType.STORY,
        word,
        TaskDifficulty.MEDIUM,
        '',
        true,
        100,
        30
      );
      choiceTask.priority = 100;
      // Determine offset
      const offset1 = this.selectRequeueOffset(suggestedOffset, 3);
      choiceTask.preferredOffset = offset1;
      tasks.push(choiceTask);
      
      if (maxInsertCount > 1) {
        // Reinforcement Task 2
        const spellingTask = new TaskItem(
          `re_spell_${word.id}_${Date.now()}`,
          TaskType.STORY,
          word,
          TaskDifficulty.HARD,
          '',
          true,
          90,
          45
        );
        spellingTask.priority = 90;
        const offset2 = this.selectRequeueOffset(suggestedOffset * 2, 8);
        spellingTask.preferredOffset = offset2;
        tasks.push(spellingTask);
      }

      return tasks;
    } catch (e) {
      const err = e instanceof Error ? e.message : String(e);
      console.warn('[ReadPageReviewManager] Failed to create reinforcement tasks:', err);
      return tasks;
    }
  }

  private selectRequeueOffset(primary: number, secondary: number): number {
    if (primary <= 0) return secondary;
    if (secondary <= 0) return primary;
    return Math.min(primary, secondary);
  }
}
