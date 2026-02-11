
import { WordItem, WordStatus, Rating, LearningSession } from '../model/WordModel';
import { ReadPageSessionManager } from './learning/controllers/SessionManager';
import { ReadPageReviewManager } from './learning/controllers/ReviewManager';
import { TopBannerType } from '../ui/TopBanner';
import { TaskItem } from '../manager/SessionPlanner';

export interface ReviewProcessResult {
  updatedWord: WordItem;
  nextReviewHint: string;
  tasksInserted: boolean;
  newQueue?: TaskItem[];
}

export interface ReviewProcessCallbacks {
  onShowBanner: (type: TopBannerType, message: string, duration: number) => void;
  onMoveToNext: () => void;
}

export class ReadPageReviewHandler {
  static async processReview(
    rating: Rating,
    reflection: string,
    currentWord: WordItem,
    currentTask: TaskItem | null,
    sessionManager: ReadPageSessionManager,
    reviewManager: ReadPageReviewManager,
    callbacks: ReviewProcessCallbacks
  ): Promise<ReviewProcessResult | null> {
    
    const prevAttempts = sessionManager.getTodayAttemptsMap().get(currentWord.id) ?? 0;
    const isFirstAttempt = prevAttempts === 0;
    
    const result = await reviewManager.processReview(
        currentWord,
        rating,
        reflection,
        sessionManager.getTodayAttemptsMap(),
        sessionManager.getSession()?.reviewedCount ?? 0,
        sessionManager.getSession()?.newLearnedCount ?? 0
    );

    if (!result) return null;

    sessionManager.incrementAttempt(result.updatedWord.id);
    
    if (isFirstAttempt && sessionManager.getSession()) {
         if (result.updatedWord.status === WordStatus.LEARNING || result.updatedWord.status === WordStatus.NEW) {
              sessionManager.getSession()!.newLearnedCount++;
         } else {
              sessionManager.getSession()!.reviewedCount++;
         }
         
         if (currentTask) {
             sessionManager.markTaskAsSeen(currentTask);
         }
    }
    
    let tasksInserted = false;
    let newQueue: TaskItem[] | undefined = undefined;

    if (result.learningDecision.shouldRequeueInSession) {
         const allowOnPass = result.learningDecision.allowReinforcementOnPass || rating === Rating.GOOD || rating === Rating.EASY;
         const tasks = await reviewManager.createReinforcementTasks(
             result.updatedWord,
             rating,
             result.learningDecision.requeueOffset,
             allowOnPass,
             sessionManager.getReinforcementInsertedCount(result.updatedWord.id)
         );
         if (tasks.length > 0) {
             sessionManager.insertTasks(tasks, result.learningDecision.requeueOffset);
             sessionManager.incrementReinforcementInserted(result.updatedWord.id);
             newQueue = [...sessionManager.getTaskQueue()];
             tasksInserted = true;
         }
    }
    
    let message = `下次复习：${result.nextReviewHint}`;
    if (rating === Rating.GOOD) message = `会了 · ${result.nextReviewHint}`;
    else if (rating === Rating.EASY) message = `轻松 · ${result.nextReviewHint}`;
    else if (rating === Rating.HARD) message = `更近复习 · ${result.nextReviewHint}`;
    else if (rating === Rating.AGAIN) message = `更快复习 · ${result.nextReviewHint}`;
    
    callbacks.onShowBanner(TopBannerType.INFO, message, 1000);
    callbacks.onMoveToNext();

    return {
      updatedWord: result.updatedWord,
      nextReviewHint: result.nextReviewHint,
      tasksInserted,
      newQueue
    };
  }
}
