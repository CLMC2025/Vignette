import { TaskItem, TaskType, TaskDifficulty, ErrorType } from '../manager/SessionPlanner';
import { RawWordItem, normalizeWordItem } from '../utils/RouteParamNormalizer';
import { WordItem, LearningSession } from '../model/WordModel';

export interface PersistedTaskSnapshot {
  id: string;
  type: TaskType;
  word: RawWordItem;
  difficulty: TaskDifficulty;
  content: string;
  options: string[];
  correctAnswer: string;
  userAnswer: string;
  isCorrect: boolean;
  errorTag: ErrorType | null;
  reflection: string;
  isReinforcement: boolean;
  priority: number;
  estimatedTime: number;
}

export interface NumberMapEntry {
  key: number;
  value: number;
}

export interface ReadPagePersistedState {
  savedAtMs: number;
  taskIndex: number;
  taskQueue: PersistedTaskSnapshot[];
  currentTaskId: string;
  contextSequence: string[];
  contextCursor: number;
  seenContextIds: string[];
  reviewedCount: number;
  newLearnedCount: number;
  todayAttemptEntries: NumberMapEntry[];
  reinforcementEntries: NumberMapEntry[];
}

export class ReadPersistenceController {
  private readonly STORAGE_KEY_SESSION_CONTEXT: string = 'read_page_session_context';
  private readonly SESSION_CONTEXT_MAX_AGE_MS: number = 6 * 60 * 60 * 1000;

  public persistSessionContext(
    taskQueue: TaskItem[],
    taskIndex: number,
    contextSequence: string[],
    contextCursor: number,
    seenContextIds: Set<string>,
    session: LearningSession,
    todayAttempts: Map<number, number>,
    reinforcements: Map<number, number>
  ): void {
    if (taskQueue.length === 0 || taskIndex < 0 || taskIndex >= taskQueue.length) {
      return;
    }

    const persistedQueue: PersistedTaskSnapshot[] = [];
    for (const task of taskQueue) {
      persistedQueue.push(this.buildPersistedTask(task));
    }

    const currentTaskId = taskIndex >= 0 && taskIndex < taskQueue.length ? taskQueue[taskIndex].id : '';

    const state: ReadPagePersistedState = {
      savedAtMs: Date.now(),
      taskIndex: taskIndex,
      taskQueue: persistedQueue,
      currentTaskId: currentTaskId,
      contextSequence: [...contextSequence],
      contextCursor: contextCursor,
      seenContextIds: Array.from(seenContextIds),
      reviewedCount: session.reviewedCount,
      newLearnedCount: session.newLearnedCount,
      todayAttemptEntries: this.mapToEntries(todayAttempts),
      reinforcementEntries: this.mapToEntries(reinforcements)
    };

    AppStorage.setOrCreate(this.STORAGE_KEY_SESSION_CONTEXT, JSON.stringify(state));
  }

  public clearPersistedSessionContext(): void {
    AppStorage.setOrCreate(this.STORAGE_KEY_SESSION_CONTEXT, '');
  }

  public tryRestoreSessionContext(): ReadPagePersistedState | null {
    const raw = AppStorage.get<string>(this.STORAGE_KEY_SESSION_CONTEXT);
    if (raw === undefined || raw.length === 0) {
      return null;
    }

    try {
      const state = JSON.parse(raw) as ReadPagePersistedState;
      const savedAt = Number(state.savedAtMs);
      if (!isFinite(savedAt) || Date.now() - savedAt > this.SESSION_CONTEXT_MAX_AGE_MS) {
        this.clearPersistedSessionContext();
        return null;
      }
      return state;
    } catch (e) {
      this.clearPersistedSessionContext();
      return null;
    }
  }

  public rebuildTaskQueue(persistedQueue: PersistedTaskSnapshot[]): TaskItem[] {
    const rebuiltQueue: TaskItem[] = [];
    for (const item of persistedQueue) {
      rebuiltQueue.push(this.buildTaskFromPersisted(item));
    }
    return rebuiltQueue;
  }

  public applyEntriesToMap(entries: NumberMapEntry[], target: Map<number, number>): void {
    target.clear();
    for (const entry of entries) {
      const key = Number(entry.key);
      const value = Number(entry.value);
      if (isFinite(key) && isFinite(value)) {
        target.set(key, value);
      }
    }
  }

  private buildPersistedTask(task: TaskItem): PersistedTaskSnapshot {
    const options: string[] = task.options ? [...task.options] : [];
    const persisted: PersistedTaskSnapshot = {
      id: task.id,
      type: task.type,
      word: this.buildRawWordItem(task.word),
      difficulty: task.difficulty,
      content: task.content,
      options: options,
      correctAnswer: task.correctAnswer ?? '',
      userAnswer: task.userAnswer ?? '',
      isCorrect: task.isCorrect ?? false,
      errorTag: task.errorTag ?? null,
      reflection: task.reflection ?? '',
      isReinforcement: task.isReinforcement,
      priority: task.priority,
      estimatedTime: task.estimatedTime
    };
    return persisted;
  }

  private buildTaskFromPersisted(persisted: PersistedTaskSnapshot): TaskItem {
    const word = normalizeWordItem(persisted.word);
    const task = new TaskItem(
      persisted.id,
      persisted.type,
      word,
      persisted.difficulty,
      persisted.content,
      persisted.isReinforcement,
      persisted.priority,
      persisted.estimatedTime
    );
    if (persisted.options.length > 0) {
      task.options = [...persisted.options];
    }
    if (persisted.correctAnswer.length > 0) {
      task.correctAnswer = persisted.correctAnswer;
    }
    if (persisted.userAnswer.length > 0) {
      task.userAnswer = persisted.userAnswer;
    }
    if (persisted.isCorrect) {
      task.isCorrect = true;
    }
    if (persisted.errorTag !== null) {
      task.errorTag = persisted.errorTag;
    }
    if (persisted.reflection.length > 0) {
      task.reflection = persisted.reflection;
    }
    return task;
  }

  private buildRawWordItem(word: WordItem): RawWordItem {
    const raw: RawWordItem = {
      id: word.id,
      word: word.word,
      status: word.status,
      fsrsState: word.fsrsState.toJSON(),
      history: word.history.toJSON(),
      definition: word.definition.toJSON(),
      dueDate: word.dueDate,
      createdAt: word.createdAt,
      updatedAt: word.updatedAt,
      bookId: word.bookId,
      tags: word.tags,
      lapseCount: word.lapseCount,
      leechLevel: word.leechLevel,
      errorTags: word.errorTags,
      suspendUntil: word.suspendUntil
    };
    return raw;
  }

  private mapToEntries(map: Map<number, number>): NumberMapEntry[] {
    const entries: NumberMapEntry[] = [];
    map.forEach((value: number, key: number) => {
      entries.push({ key: key, value: value });
    });
    return entries;
  }
}
