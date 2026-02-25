import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';
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
  storyText: string;
  storyTranslation: string;
}

interface PersistenceStringPreferences {
  get(key: string, defValue: string): Promise<string>;
  put(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
}

class PreferencesStringAdapter implements PersistenceStringPreferences {
  private raw: preferences.Preferences;

  constructor(raw: preferences.Preferences) {
    this.raw = raw;
  }

  async get(key: string, defValue: string): Promise<string> {
    const v = await this.raw.get(key, defValue);
    if (typeof v === 'string') {
      return v;
    }
    return String(v);
  }

  async put(key: string, value: string): Promise<void> {
    await this.raw.put(key, value);
  }

  async flush(): Promise<void> {
    await this.raw.flush();
  }
}

export class InMemoryPersistencePreferences implements PersistenceStringPreferences {
  private data: Map<string, string> = new Map<string, string>();

  async get(key: string, defValue: string): Promise<string> {
    return this.data.get(key) ?? defValue;
  }

  async put(key: string, value: string): Promise<void> {
    this.data.set(key, value);
  }

  async flush(): Promise<void> {
    return;
  }
}

export class ReadPersistenceController {
  private static readonly PREFERENCES_NAME: string = 'read_persistence_store';
  private static readonly STORAGE_KEY_SESSION_CONTEXT: string = 'read_page_session_context';
  private static instance: ReadPersistenceController | null = null;

  private readonly SESSION_CONTEXT_MAX_AGE_MS: number = 24 * 60 * 60 * 1000;

  private prefs: PersistenceStringPreferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;

  private memoryCache: ReadPagePersistedState | null = null;

  private constructor() {}

  static getInstance(): ReadPersistenceController {
    if (ReadPersistenceController.instance === null) {
      ReadPersistenceController.instance = new ReadPersistenceController();
    }
    return ReadPersistenceController.instance;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  injectPreferencesForTest(prefs: PersistenceStringPreferences): void {
    this.prefs = prefs;
    this.isInitialized = true;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      console.warn('[ReadPersistenceController] initialize: abilityContext is not available');
      return false;
    }
    try {
      const raw = await preferences.getPreferences(this.abilityContext, ReadPersistenceController.PREFERENCES_NAME);
      this.prefs = new PreferencesStringAdapter(raw);
      this.isInitialized = true;
      console.info('[ReadPersistenceController] Initialized successfully');
      return true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[ReadPersistenceController] Failed to initialize: ${errMsg}`);
      this.prefs = null;
      this.isInitialized = false;
      return false;
    }
  }

  private async ensureInitialized(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    return this.initialize();
  }

  public async persistSessionContext(
    taskQueue: TaskItem[],
    taskIndex: number,
    contextSequence: string[],
    contextCursor: number,
    seenContextIds: Set<string>,
    session: LearningSession,
    todayAttempts: Map<number, number>,
    reinforcements: Map<number, number>,
    storyText: string = '',
    storyTranslation: string = ''
  ): Promise<boolean> {
    if (taskQueue.length === 0 || taskIndex < 0 || taskIndex >= taskQueue.length) {
      return false;
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
      reinforcementEntries: this.mapToEntries(reinforcements),
      storyText: storyText,
      storyTranslation: storyTranslation
    };

    this.memoryCache = state;

    if (!await this.ensureInitialized()) {
      console.warn('[ReadPersistenceController] persistSessionContext: not initialized, using memory cache only');
      return false;
    }

    if (this.prefs === null) {
      return false;
    }

    try {
      await this.prefs.put(ReadPersistenceController.STORAGE_KEY_SESSION_CONTEXT, JSON.stringify(state));
      await this.prefs.flush();
      console.info(`[ReadPersistenceController] Session context persisted with ${persistedQueue.length} tasks`);
      return true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[ReadPersistenceController] Failed to persist session context: ${errMsg}`);
      return false;
    }
  }

  public async clearPersistedSessionContext(): Promise<void> {
    this.memoryCache = null;

    if (!await this.ensureInitialized()) {
      return;
    }

    if (this.prefs === null) {
      return;
    }

    try {
      await this.prefs.put(ReadPersistenceController.STORAGE_KEY_SESSION_CONTEXT, '');
      await this.prefs.flush();
      console.info('[ReadPersistenceController] Session context cleared');
    } catch (e) {
      console.error('[ReadPersistenceController] Failed to clear session context');
    }
  }

  public async tryRestoreSessionContext(): Promise<ReadPagePersistedState | null> {
    if (this.memoryCache !== null) {
      const savedAt = Number(this.memoryCache.savedAtMs);
      if (isFinite(savedAt) && Date.now() - savedAt <= this.SESSION_CONTEXT_MAX_AGE_MS) {
        console.info('[ReadPersistenceController] Restored session context from memory cache');
        return this.memoryCache;
      }
      this.memoryCache = null;
    }

    if (!await this.ensureInitialized()) {
      console.warn('[ReadPersistenceController] tryRestoreSessionContext: not initialized');
      return null;
    }

    if (this.prefs === null) {
      return null;
    }

    try {
      const raw = await this.prefs.get(ReadPersistenceController.STORAGE_KEY_SESSION_CONTEXT, '');
      if (raw.length === 0) {
        return null;
      }

      const state = JSON.parse(raw) as ReadPagePersistedState;
      const savedAt = Number(state.savedAtMs);
      if (!isFinite(savedAt) || Date.now() - savedAt > this.SESSION_CONTEXT_MAX_AGE_MS) {
        await this.clearPersistedSessionContext();
        console.info('[ReadPersistenceController] Session context expired, cleared');
        return null;
      }

      this.memoryCache = state;
      console.info(`[ReadPersistenceController] Restored session context with ${state.taskQueue.length} tasks, age: ${Math.round((Date.now() - savedAt) / 60000)} minutes`);
      return state;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[ReadPersistenceController] Failed to restore session context: ${errMsg}`);
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
