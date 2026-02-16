import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

export enum ContextDefinitionStatus {
  OK = 'ok',
  FAILED = 'failed'
}

export interface ContextDefinitionRecord {
  status: ContextDefinitionStatus;
  definitionText: string;
  storyTranslation: string;
  createdAt: number;
  formatVersion: number;
}

/**
 * Input record for normalization
 */
export interface ContextDefinitionInputRecord {
  status?: string;
  definitionText?: string;
  storyTranslation?: string;
  createdAt?: number;
  formatVersion?: number;
}

export class ContextDefinitionStore {
  private static readonly PREFERENCES_NAME: string = 'context_definitions';
  private static instance: ContextDefinitionStore | null = null;
  static readonly FORMAT_VERSION: number = 2;

  private preferences: preferences.Preferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;
  private memoryCache: Map<string, ContextDefinitionRecord> = new Map<string, ContextDefinitionRecord>();

  private constructor() {}

  static getInstance(): ContextDefinitionStore {
    if (ContextDefinitionStore.instance === null) {
      ContextDefinitionStore.instance = new ContextDefinitionStore();
    }
    return ContextDefinitionStore.instance;
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
      this.preferences = await preferences.getPreferences(this.abilityContext, ContextDefinitionStore.PREFERENCES_NAME);
      this.isInitialized = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  private buildKey(taskId: string, storyHash: string): string {
    return `ctx_def:${taskId}:${storyHash}`;
  }

  private buildLatestKey(taskId: string): string {
    return `ctx_def_latest:${taskId}`;
  }

  private normalizeRecord(input: ContextDefinitionInputRecord): ContextDefinitionRecord | null {
    return normalizeContextDefinitionRecord(input);
  }

  setCached(taskId: string, storyHash: string, record: ContextDefinitionRecord): void {
    const key = this.buildKey(taskId, storyHash);
    this.memoryCache.set(key, record);
  }

  getCached(taskId: string, storyHash: string): ContextDefinitionRecord | null {
    const key = this.buildKey(taskId, storyHash);
    return this.memoryCache.get(key) ?? null;
  }

  async save(taskId: string, storyHash: string, record: ContextDefinitionRecord): Promise<boolean> {
    if (!await this.initialize()) {
      return false;
    }
    if (this.preferences === null) {
      return false;
    }
    const key = this.buildKey(taskId, storyHash);
    const latestKey = this.buildLatestKey(taskId);
    try {
      await this.preferences.put(key, JSON.stringify(record));
      await this.preferences.put(latestKey, storyHash);
      await this.preferences.flush();
      this.memoryCache.set(key, record);
      return true;
    } catch (e) {
      return false;
    }
  }

  async getLatestHash(taskId: string): Promise<string> {
    if (!await this.initialize()) {
      return '';
    }
    if (this.preferences === null) {
      return '';
    }
    try {
      return await this.preferences.get(this.buildLatestKey(taskId), '') as string;
    } catch (e) {
      return '';
    }
  }

  async load(taskId: string, storyHash: string): Promise<ContextDefinitionRecord | null> {
    const cached = this.getCached(taskId, storyHash);
    if (cached !== null) {
      return cached;
    }
    if (!await this.initialize()) {
      return null;
    }
    if (this.preferences === null) {
      return null;
    }
    const key = this.buildKey(taskId, storyHash);
    try {
      const raw = await this.preferences.get(key, '') as string;
      if (raw.length === 0) {
        return null;
      }
      const parsed = JSON.parse(raw) as ContextDefinitionInputRecord;
      const normalized = this.normalizeRecord(parsed);
      if (normalized === null) {
        return null;
      }
      this.memoryCache.set(key, normalized);
      return normalized;
    } catch (e) {
      return null;
    }
  }
}

export function normalizeContextDefinitionRecord(input: ContextDefinitionInputRecord): ContextDefinitionRecord | null {
  const status = input.status;
  const definitionText = input.definitionText;
  const createdAt = input.createdAt;
  if (typeof status !== 'string' || typeof definitionText !== 'string' || typeof createdAt !== 'number') {
    return null;
  }
  const storyTranslation = typeof input.storyTranslation === 'string' ? input.storyTranslation : '';
  const formatVersion = typeof input.formatVersion === 'number' ? input.formatVersion : 1;
  return {
    status: status as ContextDefinitionStatus,
    definitionText,
    storyTranslation,
    createdAt,
    formatVersion
  };
}

export function hashStoryText(text: string): string {
  let hash = 2166136261;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16);
}
