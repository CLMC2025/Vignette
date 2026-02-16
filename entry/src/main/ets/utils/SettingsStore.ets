import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

import { AppSettings } from '../model/WordModel';
import { FsrsParamsPack } from '../model/FsrsParamsPack';

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
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      return false;
    }
    try {
      const raw = await preferences.getPreferences(this.abilityContext, SettingsStore.PREFERENCES_NAME);
      this.prefs = new PreferencesStringAdapter(raw);
      this.isInitialized = true;
      return true;
    } catch (e) {
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

  async saveSettings(settings: AppSettings): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    try {
      await this.prefs.put(SettingsStore.SETTINGS_JSON_KEY, settings.toJSON());
      await this.prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  async getSettings(): Promise<AppSettings | null> {
    if (!await this.ensureInitialized()) {
      return null;
    }
    if (this.prefs === null) {
      return null;
    }
    try {
      const json = await this.prefs.get(SettingsStore.SETTINGS_JSON_KEY, '');
      if (json.length === 0) {
        return null;
      }
      return AppSettings.fromJSON(json);
    } catch (e) {
      return null;
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
      return true;
    } catch (e) {
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
