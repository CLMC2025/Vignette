import { ReadContextSnapshot, ReadPageHistoryEntry, TaskSnapshot } from '../../../model/ReadContextSnapshot';
import { HistoryStack, HistoryPopResult } from '../../../utils/HistoryStack';
import { WordItem, WordSnapshot, LearningSession } from '../../../model/WordModel';
import { TaskItem } from '../../../manager/SessionPlanner';

export class ReadPageSnapshotManager {
  private historyStack: HistoryStack<ReadPageHistoryEntry>;
  private readonly HISTORY_CAPACITY: number = 5;

  constructor(capacity: number = 5) {
    this.HISTORY_CAPACITY = capacity;
    this.historyStack = new HistoryStack<ReadPageHistoryEntry>(capacity);
  }

  public getHistoryStack(): HistoryStack<ReadPageHistoryEntry> {
    return this.historyStack;
  }
  
  public canUndo(): boolean {
    return !this.historyStack.isEmpty();
  }

  public pushHistory(
    currentWord: WordItem,
    taskQueue: TaskItem[],
    taskIndex: number,
    storyText: string,
    storyError: string,
    supportWords: string[],
    storyTranslation: string,
    showTranslation: boolean,
    lastReviewHint: string,
    pendingReviewReflection: string,
    contextSequence: string[],
    contextCursor: number,
    seenContextIds: Set<string>,
    todayAttemptsByWordId: Map<number, number>,
    reinforcementInsertedCountByWordId: Map<number, number>,
    session: LearningSession
  ): void {
    if (!currentWord) return;

    const taskQueueSnapshots: TaskSnapshot[] = [];
    for (const task of taskQueue) {
      taskQueueSnapshots.push(TaskSnapshot.fromTask(task));
    }
    const currentTaskId =
      taskIndex >= 0 && taskIndex < taskQueue.length ? taskQueue[taskIndex].id : '';
    const seenContextIdsArray: string[] = Array.from(seenContextIds);
    
    const snapshot = new ReadContextSnapshot(
      taskIndex,
      taskQueueSnapshots,
      currentTaskId,
      storyText,
      storyError,
      [...supportWords],
      storyTranslation,
      showTranslation,
      lastReviewHint,
      pendingReviewReflection,
      [...contextSequence],
      contextCursor,
      seenContextIdsArray
    );

    const wordBeforeReview = currentWord.clone();
    const wordId = currentWord.id;
    const prevAttempts = todayAttemptsByWordId.get(wordId) ?? 0;
    const prevReinforcementInserted = reinforcementInsertedCountByWordId.get(wordId) ?? 0;
    const prevReviewedCount = session.reviewedCount;
    const prevNewLearnedCount = session.newLearnedCount;

    const entry = new ReadPageHistoryEntry(
      wordBeforeReview,
      snapshot,
      Date.now(),
      prevAttempts,
      prevReinforcementInserted,
      prevReviewedCount,
      prevNewLearnedCount
    );

    this.historyStack = this.historyStack.push(entry);
  }

  public popHistory(): ReadPageHistoryEntry | null {
    const result: HistoryPopResult<ReadPageHistoryEntry> = this.historyStack.pop();
    this.historyStack = result.stack;
    return result.item;
  }
  
  public clear(): void {
    this.historyStack = new HistoryStack<ReadPageHistoryEntry>(this.HISTORY_CAPACITY);
  }
}
