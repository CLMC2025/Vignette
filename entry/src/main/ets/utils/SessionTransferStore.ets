import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';
import { QueueItem } from '../model/WordModel';
import { normalizeQueueFromRouterParams, RawQueueItem, RawWordItem } from './RouteParamNormalizer';

interface SessionStringPreferences {
  get(key: string, defValue: string): Promise<string>;
  put(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
  delete(key: string): Promise<void>;
}

class PreferencesStringAdapter implements SessionStringPreferences {
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

  async delete(key: string): Promise<void> {
    await this.raw.delete(key);
  }
}

export class InMemorySessionPreferences implements SessionStringPreferences {
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

  async delete(key: string): Promise<void> {
    this.data.delete(key);
  }
}

interface RawQueueItemForSerialization {
  word: RawWordItem;
  priority: number;
}

export class SessionTransferStore {
  private static readonly PREFERENCES_NAME: string = 'session_transfer_store';
  private static readonly KEY_PREFIX: string = 'session_';
  private static readonly KEY_IDS: string = 'session_ids';
  private static instance: SessionTransferStore | null = null;

  private ids: string[] = [];
  private queues: QueueItem[][] = [];
  private readonly maxSessions: number = 5;

  private prefs: SessionStringPreferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;

  private constructor() {}

  static getInstance(): SessionTransferStore {
    if (SessionTransferStore.instance === null) {
      SessionTransferStore.instance = new SessionTransferStore();
    }
    return SessionTransferStore.instance;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  injectPreferencesForTest(prefs: SessionStringPreferences): void {
    this.prefs = prefs;
    this.isInitialized = true;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      console.warn('[SessionTransferStore] initialize: abilityContext is not available');
      return false;
    }
    try {
      const raw = await preferences.getPreferences(this.abilityContext, SessionTransferStore.PREFERENCES_NAME);
      this.prefs = new PreferencesStringAdapter(raw);
      this.isInitialized = true;
      
      await this.loadFromPreferences();
      
      console.info('[SessionTransferStore] Initialized successfully');
      return true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SessionTransferStore] Failed to initialize: ${errMsg}`);
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

  private async loadFromPreferences(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      const idsJson = await this.prefs.get(SessionTransferStore.KEY_IDS, '[]');
      const savedIds = JSON.parse(idsJson) as string[];
      
      this.ids = [];
      this.queues = [];
      
      for (const id of savedIds) {
        const queueJson = await this.prefs.get(this.keyForSession(id), '');
        if (queueJson.length > 0) {
          try {
            const rawQueue = JSON.parse(queueJson) as RawQueueItemForSerialization[];
            const queue = this.deserializeQueue(rawQueue);
            this.ids.push(id);
            this.queues.push(queue);
          } catch (parseErr) {
            console.warn(`[SessionTransferStore] Failed to parse queue for session ${id}`);
            await this.prefs.delete(this.keyForSession(id));
          }
        }
      }
      
      console.info(`[SessionTransferStore] Loaded ${this.ids.length} sessions from preferences`);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SessionTransferStore] Failed to load from preferences: ${errMsg}`);
    }
  }

  private keyForSession(id: string): string {
    return `${SessionTransferStore.KEY_PREFIX}${id}`;
  }

  private serializeQueue(queue: QueueItem[]): RawQueueItemForSerialization[] {
    const result: RawQueueItemForSerialization[] = [];
    for (const item of queue) {
      const rawWord: RawWordItem = {
        id: item.word.id,
        word: item.word.word,
        status: item.word.status,
        fsrsState: item.word.fsrsState.toJSON(),
        history: item.word.history.toJSON(),
        definition: item.word.definition.toJSON(),
        dueDate: item.word.dueDate,
        createdAt: item.word.createdAt,
        updatedAt: item.word.updatedAt,
        bookId: item.word.bookId,
        tags: item.word.tags,
        lapseCount: item.word.lapseCount,
        leechLevel: item.word.leechLevel,
        errorTags: item.word.errorTags,
        suspendUntil: item.word.suspendUntil
      };
      result.push({
        word: rawWord,
        priority: item.priority
      });
    }
    return result;
  }

  private deserializeQueue(rawQueue: RawQueueItemForSerialization[]): QueueItem[] {
    return normalizeQueueFromRouterParams(rawQueue as RawQueueItem[]);
  }

  private async saveToPreferences(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(SessionTransferStore.KEY_IDS, JSON.stringify(this.ids));
      
      for (let i = 0; i < this.ids.length; i++) {
        const id = this.ids[i];
        const queue = this.queues[i];
        const queueJson = JSON.stringify(this.serializeQueue(queue));
        await this.prefs.put(this.keyForSession(id), queueJson);
      }
      
      await this.prefs.flush();
      console.info(`[SessionTransferStore] Saved ${this.ids.length} sessions to preferences`);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SessionTransferStore] Failed to save to preferences: ${errMsg}`);
    }
  }

  private async deleteSessionFromPreferences(id: string): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.delete(this.keyForSession(id));
      await this.prefs.put(SessionTransferStore.KEY_IDS, JSON.stringify(this.ids));
      await this.prefs.flush();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SessionTransferStore] Failed to delete session ${id}: ${errMsg}`);
    }
  }

  async put(queue: QueueItem[]): Promise<string> {
    const id = `${Date.now()}_${Math.floor(Math.random() * 1_000_000)}`;
    this.ids.push(id);
    this.queues.push(queue);
    
    while (this.ids.length > this.maxSessions) {
      const removedId = this.ids.shift();
      this.queues.shift();
      if (removedId !== undefined) {
        await this.deleteSessionFromPreferences(removedId);
      }
    }
    
    await this.saveToPreferences();
    
    console.info(`[SessionTransferStore] Put session ${id} with ${queue.length} items`);
    return id;
  }

  async take(sessionId: string): Promise<QueueItem[] | null> {
    const idx = this.ids.indexOf(sessionId);
    if (idx < 0) {
      if (await this.ensureInitialized() && this.prefs !== null) {
        const queueJson = await this.prefs.get(this.keyForSession(sessionId), '');
        if (queueJson.length > 0) {
          try {
            const rawQueue = JSON.parse(queueJson) as RawQueueItemForSerialization[];
            const queue = this.deserializeQueue(rawQueue);
            await this.deleteSessionFromPreferences(sessionId);
            console.info(`[SessionTransferStore] Took session ${sessionId} from preferences with ${queue.length} items`);
            return queue;
          } catch (parseErr) {
            console.warn(`[SessionTransferStore] Failed to parse session ${sessionId} from preferences`);
          }
        }
      }
      return null;
    }
    
    const queue = this.queues[idx];
    this.ids.splice(idx, 1);
    this.queues.splice(idx, 1);
    
    await this.deleteSessionFromPreferences(sessionId);
    
    console.info(`[SessionTransferStore] Took session ${sessionId} with ${queue.length} items`);
    return queue;
  }

  async clearAll(): Promise<void> {
    if (this.prefs !== null) {
      try {
        for (const id of this.ids) {
          await this.prefs.delete(this.keyForSession(id));
        }
        await this.prefs.put(SessionTransferStore.KEY_IDS, '[]');
        await this.prefs.flush();
      } catch (e) {
        console.error('[SessionTransferStore] Failed to clear all sessions from preferences');
      }
    }
    
    this.ids = [];
    this.queues = [];
    console.info('[SessionTransferStore] Cleared all sessions');
  }

  getSessionCount(): number {
    return this.ids.length;
  }

  hasSession(sessionId: string): boolean {
    return this.ids.indexOf(sessionId) >= 0;
  }
}
