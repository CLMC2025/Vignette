import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

import { AppSettings } from '../model/WordModel';
import { FsrsParamsPack } from '../model/FsrsParamsPack';
import { StorageError, StorageErrorType } from './StorageError';

export interface SettingsStringPreferences {
  get(key: string, defValue: string): Promise<string>;
  put(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
}

class PreferencesStringAdapter implements SettingsStringPreferences {
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

export class InMemorySettingsPreferences implements SettingsStringPreferences {
  private data: Map<string, string> = new Map<string, string>();
  flushCount: number = 0;

  async get(key: string, defValue: string): Promise<string> {
    return this.data.get(key) ?? defValue;
  }

  async put(key: string, value: string): Promise<void> {
    this.data.set(key, value);
  }

  async flush(): Promise<void> {
    this.flushCount += 1;
  }
}

export interface SettingsLoadResult {
  settings: AppSettings | null;
  error?: StorageError;
}

export interface InitializationStateResult {
  initialized: boolean;
  error: StorageError | null;
}

export class SettingsStore {
  private static readonly PREFERENCES_NAME: string = 'settings_store';
  private static readonly SETTINGS_JSON_KEY: string = 'app_settings_json';
  private static readonly FSRS_PARAMS_JSON_KEY: string = 'fsrs_params_json';
  private static readonly PRIVACY_CONSENT_KEY: string = 'privacy_consent_v1';
  private static readonly ONBOARDING_SEEN_KEY: string = 'onboarding_seen_v1';
  private static instance: SettingsStore | null = null;

  private prefs: SettingsStringPreferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;
  private lastInitError: StorageError | null = null;

  private constructor() {}

  static getInstance(): SettingsStore {
    if (SettingsStore.instance === null) {
      SettingsStore.instance = new SettingsStore();
    }
    return SettingsStore.instance;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  injectPreferencesForTest(prefs: SettingsStringPreferences): void {
    this.prefs = prefs;
    this.isInitialized = true;
    this.lastInitError = null;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      this.lastInitError = StorageError.contextNotInjected();
      console.error('[SettingsStore] initialize: abilityContext is not available');
      return false;
    }
    try {
      const raw = await preferences.getPreferences(this.abilityContext, SettingsStore.PREFERENCES_NAME);
      this.prefs = new PreferencesStringAdapter(raw);
      this.isInitialized = true;
      this.lastInitError = null;
      console.info('[SettingsStore] Preferences initialized successfully');
      return true;
    } catch (e) {
      const originalError = e instanceof Error ? e : new Error(String(e));
      this.lastInitError = StorageError.initializationFailed(originalError);
      console.error(`[SettingsStore] Failed to initialize preferences: ${originalError.message}`);
      this.prefs = null;
      this.isInitialized = false;
      return false;
    }
  }

  getLastInitError(): StorageError | null {
    return this.lastInitError;
  }

  getInitializationState(): InitializationStateResult {
    return {
      initialized: this.isInitialized,
      error: this.lastInitError
    } as InitializationStateResult;
  }

  private async ensureInitialized(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    return this.initialize();
  }

  async saveSettings(settings: AppSettings): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      console.error('[SettingsStore] saveSettings: Storage not initialized');
      return false;
    }
    if (this.prefs === null) {
      console.error('[SettingsStore] saveSettings: Preferences is null after initialization');
      return false;
    }
    try {
      await this.prefs.put(SettingsStore.SETTINGS_JSON_KEY, settings.toJSON());
      await this.prefs.flush();
      console.info('[SettingsStore] Settings saved successfully');
      return true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SettingsStore] Failed to save settings: ${errMsg}`);
      return false;
    }
  }

  async getSettings(): Promise<AppSettings | null> {
    if (!await this.ensureInitialized()) {
      console.error('[SettingsStore] getSettings: Storage not initialized');
      return null;
    }
    if (this.prefs === null) {
      console.error('[SettingsStore] getSettings: Preferences is null after initialization');
      return null;
    }
    try {
      const json = await this.prefs.get(SettingsStore.SETTINGS_JSON_KEY, '');
      if (json.length === 0) {
        console.info('[SettingsStore] No settings found, returning null');
        return null;
      }
      const settings = AppSettings.fromJSON(json);
      console.info('[SettingsStore] Settings loaded successfully');
      return settings;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SettingsStore] Failed to load settings: ${errMsg}`);
      return null;
    }
  }

  async getSettingsWithStatus(): Promise<SettingsLoadResult> {
    if (!await this.ensureInitialized()) {
      return {
        settings: null,
        error: this.lastInitError ?? StorageError.notInitialized()
      };
    }
    if (this.prefs === null) {
      return {
        settings: null,
        error: new StorageError(
          StorageErrorType.INITIALIZATION_FAILED,
          'Preferences is null after initialization'
        )
      };
    }
    try {
      const json = await this.prefs.get(SettingsStore.SETTINGS_JSON_KEY, '');
      if (json.length === 0) {
        return { settings: null };
      }
      const settings = AppSettings.fromJSON(json);
      return { settings: settings };
    } catch (e) {
      const originalError = e instanceof Error ? e : new Error(String(e));
      return {
        settings: null,
        error: StorageError.parseFailed(SettingsStore.SETTINGS_JSON_KEY, originalError)
      };
    }
  }

  async saveFsrsParams(params: FsrsParamsPack): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    try {
      await this.prefs.put(SettingsStore.FSRS_PARAMS_JSON_KEY, params.toJSON());
      await this.prefs.flush();
      console.info('[SettingsStore] FSRS parameters saved successfully');
      return true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[SettingsStore] Failed to save FSRS parameters: ${errMsg}`);
      return false;
    }
  }

  async getFsrsParams(): Promise<FsrsParamsPack | null> {
    if (!await this.ensureInitialized()) {
      return null;
    }
    if (this.prefs === null) {
      return null;
    }
    try {
      const json = await this.prefs.get(SettingsStore.FSRS_PARAMS_JSON_KEY, '');
      if (json.length === 0) {
        return null;
      }
      return FsrsParamsPack.fromJSON(json);
    } catch (e) {
      return null;
    }
  }

  async setPrivacyConsent(accepted: boolean): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    try {
      await this.prefs.put(SettingsStore.PRIVACY_CONSENT_KEY, accepted ? '1' : '0');
      await this.prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  async getPrivacyConsent(): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    try {
      const value = await this.prefs.get(SettingsStore.PRIVACY_CONSENT_KEY, '');
      return value === '1';
    } catch (e) {
      return false;
    }
  }

  async setOnboardingSeen(seen: boolean): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    try {
      await this.prefs.put(SettingsStore.ONBOARDING_SEEN_KEY, seen ? '1' : '0');
      await this.prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  async hasSeenOnboarding(): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    try {
      const value = await this.prefs.get(SettingsStore.ONBOARDING_SEEN_KEY, '');
      return value === '1';
    } catch (e) {
      return false;
    }
  }
}
