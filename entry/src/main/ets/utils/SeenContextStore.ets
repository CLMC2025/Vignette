import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

interface SeenContextPreferences {
  get(key: string, defValue: string): Promise<string>;
  put(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
}

class PreferencesStringAdapter implements SeenContextPreferences {
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

export class InMemorySeenContextPreferences implements SeenContextPreferences {
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

export class SeenContextStore {
  private static readonly PREFERENCES_NAME: string = 'seen_context_store';
  private static instances: Map<string, SeenContextStore> = new Map<string, SeenContextStore>();

  private readonly storageKey: string;
  private readonly maxSize: number;
  private prefs: SeenContextPreferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;
  private memoryCache: Set<string> | null = null;

  private constructor(storageKey: string, maxSize: number) {
    this.storageKey = storageKey;
    this.maxSize = Math.max(1, maxSize);
  }

  static getInstance(storageKey: string, maxSize: number): SeenContextStore {
    if (!SeenContextStore.instances.has(storageKey)) {
      SeenContextStore.instances.set(storageKey, new SeenContextStore(storageKey, maxSize));
    }
    return SeenContextStore.instances.get(storageKey)!;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  injectPreferencesForTest(prefs: SeenContextPreferences): void {
    this.prefs = prefs;
    this.isInitialized = true;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      console.warn('[SeenContextStore] initialize: abilityContext is not available');
      return false;
    }
    try {
      const raw = await preferences.getPreferences(this.abilityContext, SeenContextStore.PREFERENCES_NAME);
      this.prefs = new PreferencesStringAdapter(raw);
      this.isInitialized = true;
      console.info(`[SeenContextStore] Initialized successfully for key ${this.storageKey}`);
      return true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SeenContextStore] Failed to initialize: ${errMsg}`);
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

  async load(): Promise<Set<string>> {
    if (this.memoryCache !== null) {
      return new Set<string>(this.memoryCache);
    }

    if (!await this.ensureInitialized() || this.prefs === null) {
      return new Set<string>();
    }

    try {
      const raw = await this.prefs.get(this.storageKey, '');
      if (raw.length === 0) {
        return new Set<string>();
      }
      const arr = JSON.parse(raw) as string[];
      const set = new Set<string>();
      for (const id of arr) {
        if (typeof id === 'string' && id.length > 0) {
          set.add(id);
        }
      }
      this.memoryCache = set;
      return new Set<string>(set);
    } catch (e) {
      return new Set<string>();
    }
  }

  async save(ids: Set<string>): Promise<void> {
    const arr: string[] = [];
    for (const id of ids) {
      arr.push(id);
    }
    while (arr.length > this.maxSize) {
      arr.shift();
    }

    this.memoryCache = new Set<string>(arr);

    if (!await this.ensureInitialized() || this.prefs === null) {
      return;
    }

    try {
      await this.prefs.put(this.storageKey, JSON.stringify(arr));
      await this.prefs.flush();
    } catch (e) {
      console.error(`[SeenContextStore] Failed to save: ${e}`);
    }
  }

  async add(id: string): Promise<void> {
    if (id.length === 0) {
      return;
    }
    const set = await this.load();
    set.add(id);
    await this.save(set);
  }

  async has(id: string): Promise<boolean> {
    if (id.length === 0) {
      return false;
    }
    const set = await this.load();
    return set.has(id);
  }

  async clear(): Promise<void> {
    this.memoryCache = new Set<string>();

    if (!await this.ensureInitialized() || this.prefs === null) {
      return;
    }

    try {
      await this.prefs.put(this.storageKey, '[]');
      await this.prefs.flush();
    } catch (e) {
      console.error(`[SeenContextStore] Failed to clear: ${e}`);
    }
  }

  loadSync(): Set<string> {
    if (this.memoryCache !== null) {
      return new Set<string>(this.memoryCache);
    }
    return new Set<string>();
  }

  saveSync(ids: Set<string>): void {
    const arr: string[] = [];
    for (const id of ids) {
      arr.push(id);
    }
    while (arr.length > this.maxSize) {
      arr.shift();
    }
    this.memoryCache = new Set<string>(arr);
    void this.save(ids);
  }

  addSync(id: string): void {
    if (id.length === 0) {
      return;
    }
    const set = this.loadSync();
    set.add(id);
    this.saveSync(set);
  }

  hasSync(id: string): boolean {
    if (id.length === 0) {
      return false;
    }
    const set = this.loadSync();
    return set.has(id);
  }
}
