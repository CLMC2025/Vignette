import router from '@ohos.router';
import { LearningSession, QueueItem, WordItem, WordStatus } from '../../../model/WordModel';
import { TaskItem, SessionPlanner, TaskType } from '../../../manager/SessionPlanner';
import { SessionTransferStore } from '../../../utils/SessionTransferStore';
import { normalizeQueueFromRouterParams, RawQueueItem } from '../../../utils/RouteParamNormalizer';
import { DBManager } from '../../../database/DBManager';
import { SessionErrorAction } from '../../ReadPageModels';

export interface ReadPageParams {
  queue?: QueueItem[];
  sessionId?: string;
}

export interface SessionInitResult {
  success: boolean;
  errorTitle?: string;
  errorMessage?: string;
  primaryAction?: SessionErrorAction;
  secondaryAction?: SessionErrorAction;
  tasks?: TaskItem[];
}

export class ReadPageSessionManager {
  private session: LearningSession | null = null;
  private taskQueue: TaskItem[] = [];
  private taskIndex: number = 0;
  
  private sessionPlanner: SessionPlanner;
  private dbManager: DBManager;
  
  // Session State
  private todayAttemptsByWordId: Map<number, number> = new Map<number, number>();
  private reinforcementInsertedCountByWordId: Map<number, number> = new Map<number, number>();
  private seenContextIds: Set<string> = new Set<string>();
  
  private taskErrorCount: number = 0;
  private readonly MAX_TASK_ERRORS: number = 3;

  constructor(sessionPlanner: SessionPlanner, dbManager: DBManager) {
    this.sessionPlanner = sessionPlanner;
    this.dbManager = dbManager;
  }

  public getSession(): LearningSession | null {
    return this.session;
  }

  public setSession(session: LearningSession): void {
    this.session = session;
  }

  public getTaskQueue(): TaskItem[] {
    return this.taskQueue;
  }

  public setTaskQueue(queue: TaskItem[]): void {
    this.taskQueue = queue;
  }

  public getTaskIndex(): number {
    return this.taskIndex;
  }

  public setTaskIndex(index: number): void {
    this.taskIndex = index;
  }

  public getCurrentTask(): TaskItem | null {
    if (this.taskIndex >= 0 && this.taskIndex < this.taskQueue.length) {
      return this.taskQueue[this.taskIndex];
    }
    return null;
  }
  
  public getTodayAttemptsMap(): Map<number, number> {
    return this.todayAttemptsByWordId;
  }

  public getReinforcementInsertedMap(): Map<number, number> {
    return this.reinforcementInsertedCountByWordId;
  }
  
  public getReinforcementInsertedCount(wordId: number): number {
    return this.reinforcementInsertedCountByWordId.get(wordId) ?? 0;
  }

  public setSessionState(
    attempts: Map<number, number>,
    reinforcements: Map<number, number>
  ): void {
    this.todayAttemptsByWordId = attempts;
    this.reinforcementInsertedCountByWordId = reinforcements;
  }
  
  public setSeenContextIds(ids: Set<string>): void {
    this.seenContextIds = ids;
  }
  
  public incrementAttempt(wordId: number): void {
    const prev = this.todayAttemptsByWordId.get(wordId) ?? 0;
    this.todayAttemptsByWordId.set(wordId, prev + 1);
  }
  
  public incrementReinforcementInserted(wordId: number): void {
    const prev = this.reinforcementInsertedCountByWordId.get(wordId) ?? 0;
    this.reinforcementInsertedCountByWordId.set(wordId, prev + 1);
  }
  
  public markTaskAsSeen(task: TaskItem): boolean {
    if (task.isReinforcement) {
      return false;
    }
    const id = String(task.word.id);
    if (!this.seenContextIds.has(id)) {
      this.seenContextIds.add(id);
      return true;
    }
    return false;
  }

  public restoreWordState(wordId: number, attempts: number, reinforcementCount: number): void {
      if (attempts <= 0) {
          this.todayAttemptsByWordId.delete(wordId);
      } else {
          this.todayAttemptsByWordId.set(wordId, attempts);
      }
      if (reinforcementCount <= 0) {
          this.reinforcementInsertedCountByWordId.delete(wordId);
      } else {
          this.reinforcementInsertedCountByWordId.set(wordId, reinforcementCount);
      }
  }
  
  public updateSessionCounts(reviewed: number, learned: number): void {
      if (this.session) {
          this.session.reviewedCount = reviewed;
          this.session.newLearnedCount = learned;
      }
  }

  public async initializeSession(
    filterOutSeenTasks: (tasks: TaskItem[]) => TaskItem[],
    params?: ReadPageParams
  ): Promise<SessionInitResult> {
    const startTime = Date.now();
    console.log('[ReadPageSessionManager] initializeSession started');

    this.taskErrorCount = 0;
    
    // Reset session state
    this.todayAttemptsByWordId.clear();
    this.reinforcementInsertedCountByWordId.clear();

    try {
      // params handling
      const routerParams = params || router.getParams() as ReadPageParams;
      let rawQueue: QueueItem[] | null = null;
      let usedStore: boolean = false;
      const sessionId = String(routerParams?.sessionId ?? '');
      if (sessionId.trim().length > 0) {
        const taken = SessionTransferStore.getInstance().take(sessionId);
        if (taken !== null) {
          rawQueue = taken;
          usedStore = true;
        }
      }
      if (rawQueue === null) {
        rawQueue = (routerParams?.queue && Array.isArray(routerParams.queue)) ? (routerParams.queue as QueueItem[]) : null;
      }

      if (!routerParams) {
        return {
          success: false,
          errorTitle: '学习任务参数错误',
          errorMessage: '未收到学习队列参数，请返回重新进入。',
          primaryAction: SessionErrorAction.BACK,
          secondaryAction: SessionErrorAction.RETRY
        };
      }

      if (rawQueue === null || !Array.isArray(rawQueue)) {
        return {
          success: false,
          errorTitle: '学习队列格式错误',
          errorMessage: '学习队列格式不正确，请返回重新进入。',
          primaryAction: SessionErrorAction.BACK,
          secondaryAction: SessionErrorAction.RETRY
        };
      }

      if (rawQueue.length === 0) {
        return {
          success: false,
          errorTitle: '没有可学习的单词',
          errorMessage: '当前词书中没有可学习的单词，请先导入或切换词书。',
          primaryAction: SessionErrorAction.WORD_BOOKS,
          secondaryAction: SessionErrorAction.BACK
        };
      }

      const normalizedQueue = usedStore
        ? rawQueue
        : normalizeQueueFromRouterParams(rawQueue as Array<RawQueueItem>);

      if (normalizedQueue.length === 0) {
        return {
          success: false,
          errorTitle: '学习队列解析失败',
          errorMessage: '队列解析失败，请重试或返回重新进入。',
          primaryAction: SessionErrorAction.RETRY,
          secondaryAction: SessionErrorAction.BACK
        };
      }

      this.session = new LearningSession();
      this.session.addToQueue(normalizedQueue);

      const words = normalizedQueue.map((item: QueueItem): WordItem => item.word);
      console.log('[ReadPageSessionManager] Generating task queue for', words.length, 'words...');

      const taskGenStart = Date.now();
      const plannedTasks = this.sessionPlanner.planMicroContextSession(words);
      this.taskQueue = filterOutSeenTasks(plannedTasks);
      this.taskIndex = 0;
      
      console.log(`[Perf] Task queue generation took ${Date.now() - taskGenStart}ms`);
      console.log('[ReadPageSessionManager] Task queue generated with', this.taskQueue.length, 'tasks');

      if (plannedTasks.length > 0 && this.taskQueue.length === 0) {
        return {
          success: false,
          errorTitle: '没有新的可学习单词',
          errorMessage: '已过滤掉历史已学习内容，请切换词书或稍后再试。',
          primaryAction: SessionErrorAction.WORD_BOOKS,
          secondaryAction: SessionErrorAction.BACK
        };
      }

      if (!this.taskQueue || this.taskQueue.length === 0) {
        return {
          success: false,
          errorTitle: '生成学习任务失败',
          errorMessage: '无法生成学习任务，请重试或切换词书。',
          primaryAction: SessionErrorAction.RETRY,
          secondaryAction: SessionErrorAction.WORD_BOOKS
        };
      }

      return {
        success: true,
        tasks: this.taskQueue
      };

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPageSessionManager] Failed to initialize session:', errorMsg);
      return {
        success: false,
        errorTitle: '学习任务初始化失败',
        errorMessage: `初始化失败：${errorMsg}`,
        primaryAction: SessionErrorAction.RETRY,
        secondaryAction: SessionErrorAction.BACK
      };
    }
  }

  public insertTasks(tasks: TaskItem[], offset: number): void {
    if (tasks.length === 0) return;
    
    const safeOffset = Math.max(0, offset);
    const safeTaskIndex = Math.max(0, Math.min(this.taskIndex, this.taskQueue.length));
    
    for (let i = 0; i < tasks.length; i++) {
      const task = tasks[i];
      const taskOffset = Math.max(0, task.preferredOffset ?? safeOffset);
      const idx = Math.min(this.taskQueue.length, safeTaskIndex + taskOffset + 1 + i);
      this.taskQueue.splice(idx, 0, task);
    }
  }
  
  public checkSessionComplete(): boolean {
    return this.taskIndex >= this.taskQueue.length;
  }
  
  public incrementTaskErrorCount(): number {
    this.taskErrorCount++;
    return this.taskErrorCount;
  }
  
  public resetTaskErrorCount(): void {
    this.taskErrorCount = 0;
  }
  
  public getMaxTaskErrors(): number {
    return this.MAX_TASK_ERRORS;
  }
}
