
import { WordItem, WordStatus, Rating, LearningSession } from '../model/WordModel';
import { ReadPageSessionManager } from './learning/controllers/SessionManager';
import { ReadPageReviewManager } from './learning/controllers/ReviewManager';
import { TopBannerType } from '../ui/TopBanner';
import { TaskItem } from '../manager/SessionPlanner';

export interface ReviewProcessResult {
  updatedWord: WordItem;
  nextReviewHint: string;
  intervalLabel: string;
  statusLabel: string;
  stability: number;
  tasksInserted: boolean;
  newQueue?: TaskItem[];
}

export interface ReviewProcessCallbacks {
  onShowBanner: (type: TopBannerType, message: string, duration: number) => void;
  onMoveToNext: () => void;
}

export class ReadPageReviewHandler {
  private static getStatusLabel(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW:
        return '新词';
      case WordStatus.LEARNING:
        return '学习中';
      case WordStatus.RELEARNING:
        return '再学习';
      case WordStatus.REVIEW:
      default:
        return '复习';
    }
  }

  private static formatIntervalDays(intervalDays: number): string {
    if (!Number.isFinite(intervalDays) || intervalDays <= 0) {
      return '';
    }
    const minutes = Math.max(1, Math.round(intervalDays * 24 * 60));
    if (minutes < 60) {
      return `${minutes}分钟`;
    }
    if (minutes < 24 * 60) {
      return `${Math.max(1, Math.round(minutes / 60))}小时`;
    }
    return `${Math.max(1, Math.round(intervalDays))}天`;
  }

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

    const historyCount = result.updatedWord.history.getReviewCount();
    const intervalDays = historyCount > 0
      ? result.updatedWord.history.items[historyCount - 1].scheduledDays
      : 0;
    const intervalLabel = ReadPageReviewHandler.formatIntervalDays(intervalDays);
    const prevStatus = currentWord.status;
    const nextStatus = result.updatedWord.status;
    const statusLabel = prevStatus === nextStatus
      ? ReadPageReviewHandler.getStatusLabel(nextStatus)
      : `${ReadPageReviewHandler.getStatusLabel(prevStatus)}→${ReadPageReviewHandler.getStatusLabel(nextStatus)}`;
    const stability = result.updatedWord.fsrsState.stability;
    const stabilityLabel = Number.isFinite(stability) ? stability.toFixed(2) : '';
    const detailParts: string[] = [];
    if (intervalLabel.length > 0) detailParts.push(`间隔 ${intervalLabel}`);
    if (statusLabel.length > 0) detailParts.push(`状态 ${statusLabel}`);
    if (stabilityLabel.length > 0) detailParts.push(`稳定度 ${stabilityLabel}`);
    if (detailParts.length > 0) {
      message = `${message} · ${detailParts.join(' · ')}`;
    }
    
    callbacks.onShowBanner(TopBannerType.INFO, message, 1000);
    callbacks.onMoveToNext();

    return {
      updatedWord: result.updatedWord,
      nextReviewHint: result.nextReviewHint,
      intervalLabel,
      statusLabel,
      stability,
      tasksInserted,
      newQueue
    };
  }
}
