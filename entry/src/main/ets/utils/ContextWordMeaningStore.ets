import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

export interface ContextWordMeaningRecord {
  formatVersion: number;
  key: string;
  contextMeaning: string;
  createdAt: number;
}

export class ContextWordMeaningStore {
  static readonly FORMAT_VERSION: number = 1;
  private static readonly PREFERENCES_NAME: string = 'context_word_meaning_store';
  private static readonly INDEX_KEY: string = '__keys_v1';
  private static instance: ContextWordMeaningStore | null = null;

  private prefs: preferences.Preferences | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  private isInitialized: boolean = false;

  private readonly maxEntries: number = 2000;
  private keys: string[] = [];
  private values: string[] = [];

  private constructor() {}

  static getInstance(): ContextWordMeaningStore {
    if (ContextWordMeaningStore.instance === null) {
      ContextWordMeaningStore.instance = new ContextWordMeaningStore();
    }
    return ContextWordMeaningStore.instance;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      return false;
    }
    try {
      this.prefs = await preferences.getPreferences(this.abilityContext, ContextWordMeaningStore.PREFERENCES_NAME);
      this.isInitialized = true;
      await this.loadIndexToMemory();
      return true;
    } catch (e) {
      return false;
    }
  }

  private async loadIndexToMemory(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    const raw = await this.prefs.get(ContextWordMeaningStore.INDEX_KEY, '') as string;
    if (raw.length === 0) {
      return;
    }
    try {
      const arr = JSON.parse(raw) as string[];
      for (const k of arr) {
        if (typeof k === 'string' && k.length > 0) {
          this.keys.push(k);
          this.values.push('');
        }
      }
    } catch (e) {
      this.keys = [];
      this.values = [];
    }
  }

  buildKey(wordLower: string, storyHash: string): string {
    return `${wordLower}|${storyHash}`;
  }

  async getContextMeaning(key: string): Promise<string> {
    const idx = this.keys.indexOf(key);
    if (idx >= 0) {
      const inMem = this.values[idx];
      if (inMem.length > 0) {
        this.touch(idx);
        return inMem;
      }
    }
    if (!await this.ensureInitialized()) {
      return '';
    }
    if (this.prefs === null) {
      return '';
    }
    const raw = await this.prefs.get(key, '') as string;
    if (raw.length === 0) {
      return '';
    }
    const parsed = this.parseRecord(raw);
    if (parsed === null) {
      return '';
    }
    const meaning = parsed.contextMeaning;
    this.putMemory(key, meaning);
    return meaning;
  }

  async setContextMeaning(key: string, contextMeaning: string): Promise<void> {
    if (contextMeaning.trim().length === 0) {
      return;
    }
    if (!await this.ensureInitialized()) {
      return;
    }
    if (this.prefs === null) {
      return;
    }
    const record: ContextWordMeaningRecord = {
      formatVersion: ContextWordMeaningStore.FORMAT_VERSION,
      key: key,
      contextMeaning: contextMeaning,
      createdAt: Date.now()
    };
    await this.prefs.put(key, JSON.stringify(record));
    this.putMemory(key, contextMeaning);
    await this.persistIndex();
    await this.prefs.flush();
  }

  private parseRecord(raw: string): ContextWordMeaningRecord | null {
    try {
      const obj = JSON.parse(raw) as Record<string, string | number>;
      const version = (obj['formatVersion'] as number) ?? 0;
      if (version !== ContextWordMeaningStore.FORMAT_VERSION) {
        return null;
      }
      const key = (obj['key'] as string) ?? '';
      const contextMeaning = (obj['contextMeaning'] as string) ?? '';
      const createdAt = (obj['createdAt'] as number) ?? 0;
      const record: ContextWordMeaningRecord = {
        formatVersion: version,
        key: key,
        contextMeaning: contextMeaning,
        createdAt: createdAt
      };
      return record;
    } catch (e) {
      return null;
    }
  }

  private putMemory(key: string, meaning: string): void {
    const idx = this.keys.indexOf(key);
    if (idx >= 0) {
      this.values[idx] = meaning;
      this.touch(idx);
      return;
    }
    this.keys.push(key);
    this.values.push(meaning);
    if (this.keys.length > this.maxEntries) {
      this.keys.shift();
      this.values.shift();
    }
  }

  private touch(idx: number): void {
    const k = this.keys[idx];
    const v = this.values[idx];
    this.keys.splice(idx, 1);
    this.values.splice(idx, 1);
    this.keys.push(k);
    this.values.push(v);
  }

  private async persistIndex(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    const arr: string[] = [];
    for (const k of this.keys) {
      arr.push(k);
    }
    while (arr.length > this.maxEntries) {
      arr.shift();
    }
    await this.prefs.put(ContextWordMeaningStore.INDEX_KEY, JSON.stringify(arr));
  }

  private async ensureInitialized(): Promise<boolean> {
    if (!this.isInitialized) {
      return await this.initialize();
    }
    return true;
  }
}

