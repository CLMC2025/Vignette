import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

export interface WebDavStringPreferences {
  get(key: string, defValue: string): Promise<string>;
  put(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
}

class PreferencesStringAdapter implements WebDavStringPreferences {
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

export class InMemoryWebDavPreferences implements WebDavStringPreferences {
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

class StoredJsonKeys {
  primaryKey: string;
  backupKey: string;
  backupTsKey: string;

  constructor(primaryKey: string, backupKey: string, backupTsKey: string) {
    this.primaryKey = primaryKey;
    this.backupKey = backupKey;
    this.backupTsKey = backupTsKey;
  }
}

export class WebDavStateStore {
  private static readonly PREFERENCES_NAME: string = 'webdav_state_store';
  private static instance: WebDavStateStore | null = null;

  private static readonly SETTINGS_KEYS: StoredJsonKeys = new StoredJsonKeys(
    'webdav_settings_json',
    'webdav_settings_json_bak',
    'webdav_settings_json_bak_ts'
  );

  private static readonly MANIFEST_KEYS: StoredJsonKeys = new StoredJsonKeys(
    'webdav_manifest_json',
    'webdav_manifest_json_bak',
    'webdav_manifest_json_bak_ts'
  );

  private static readonly SNAPSHOT_KEYS: StoredJsonKeys = new StoredJsonKeys(
    'webdav_last_snapshot_json',
    'webdav_last_snapshot_json_bak',
    'webdav_last_snapshot_json_bak_ts'
  );

  private static readonly AUTOSYNC_ENABLED_KEY: string = 'webdav_autosync_enabled';
  private static readonly AUTOSYNC_INTERVAL_HOURS_KEY: string = 'webdav_autosync_interval_hours';
  private static readonly AUTOSYNC_UPLOAD_MODEL_KEY: string = 'webdav_autosync_upload_model_enabled';
  private static readonly AUTOSYNC_UPLOAD_BACKUP_KEY: string = 'webdav_autosync_backup_enabled';
  private static readonly AUTOSYNC_LAST_RUN_MS_KEY: string = 'webdav_autosync_last_run_ms';
  private static readonly AUTOSYNC_LAST_SUCCESS_MS_KEY: string = 'webdav_autosync_last_success_ms';
  private static readonly AUTOSYNC_LAST_ERROR_KEY: string = 'webdav_autosync_last_error';

  private prefs: WebDavStringPreferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;

  private constructor() {}

  static getInstance(): WebDavStateStore {
    if (WebDavStateStore.instance === null) {
      WebDavStateStore.instance = new WebDavStateStore();
    }
    return WebDavStateStore.instance;
  }

  static createDetachedForTest(prefs: WebDavStringPreferences): WebDavStateStore {
    const store = new WebDavStateStore();
    store.injectPreferencesForTest(prefs);
    return store;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  injectPreferencesForTest(prefs: WebDavStringPreferences): void {
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
      const raw = await preferences.getPreferences(this.abilityContext, WebDavStateStore.PREFERENCES_NAME);
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

  async getSettingsJson(): Promise<string> {
    return this.getJsonWithBackup(WebDavStateStore.SETTINGS_KEYS);
  }

  async saveSettingsJson(json: string): Promise<boolean> {
    return this.saveJsonWithBackup(WebDavStateStore.SETTINGS_KEYS, json);
  }

  async getManifestJson(): Promise<string> {
    return this.getJsonWithBackup(WebDavStateStore.MANIFEST_KEYS);
  }

  async saveManifestJson(json: string): Promise<boolean> {
    return this.saveJsonWithBackup(WebDavStateStore.MANIFEST_KEYS, json);
  }

  async getSnapshotJson(): Promise<string> {
    return this.getJsonWithBackup(WebDavStateStore.SNAPSHOT_KEYS);
  }

  async saveSnapshotJson(json: string): Promise<boolean> {
    return this.saveJsonWithBackup(WebDavStateStore.SNAPSHOT_KEYS, json);
  }

  async getAutoSyncEnabled(): Promise<boolean> {
    const v = await this.safeGetString(WebDavStateStore.AUTOSYNC_ENABLED_KEY);
    if (v.length === 0) return true;
    return v === '1' || v.toLowerCase() === 'true';
  }

  async setAutoSyncEnabled(enabled: boolean): Promise<void> {
    await this.safePutString(WebDavStateStore.AUTOSYNC_ENABLED_KEY, enabled ? '1' : '0');
    await this.safeFlush();
  }

  async getAutoSyncIntervalHours(): Promise<number> {
    const v = await this.safeGetString(WebDavStateStore.AUTOSYNC_INTERVAL_HOURS_KEY);
    const n = Number(v);
    if (!Number.isFinite(n) || n <= 0) return 6;
    return Math.floor(n);
  }

  async setAutoSyncIntervalHours(hours: number): Promise<void> {
    const h = Math.max(1, Math.floor(hours));
    await this.safePutString(WebDavStateStore.AUTOSYNC_INTERVAL_HOURS_KEY, String(h));
    await this.safeFlush();
  }

  async getAutoSyncUploadModelEnabled(): Promise<boolean> {
    const v = await this.safeGetString(WebDavStateStore.AUTOSYNC_UPLOAD_MODEL_KEY);
    if (v.length === 0) return true;
    return v === '1' || v.toLowerCase() === 'true';
  }

  async setAutoSyncUploadModelEnabled(enabled: boolean): Promise<void> {
    await this.safePutString(WebDavStateStore.AUTOSYNC_UPLOAD_MODEL_KEY, enabled ? '1' : '0');
    await this.safeFlush();
  }

  async getAutoSyncUploadBackupEnabled(): Promise<boolean> {
    const v = await this.safeGetString(WebDavStateStore.AUTOSYNC_UPLOAD_BACKUP_KEY);
    if (v.length === 0) return false;
    return v === '1' || v.toLowerCase() === 'true';
  }

  async setAutoSyncUploadBackupEnabled(enabled: boolean): Promise<void> {
    await this.safePutString(WebDavStateStore.AUTOSYNC_UPLOAD_BACKUP_KEY, enabled ? '1' : '0');
    await this.safeFlush();
  }

  async getAutoSyncLastRunMs(): Promise<number> {
    const v = await this.safeGetString(WebDavStateStore.AUTOSYNC_LAST_RUN_MS_KEY);
    const n = Number(v);
    return Number.isFinite(n) && n > 0 ? n : 0;
  }

  async setAutoSyncLastRunMs(ms: number): Promise<void> {
    const n = Math.max(0, Math.floor(ms));
    await this.safePutString(WebDavStateStore.AUTOSYNC_LAST_RUN_MS_KEY, String(n));
    await this.safeFlush();
  }

  async getAutoSyncLastSuccessMs(): Promise<number> {
    const v = await this.safeGetString(WebDavStateStore.AUTOSYNC_LAST_SUCCESS_MS_KEY);
    const n = Number(v);
    return Number.isFinite(n) && n > 0 ? n : 0;
  }

  async setAutoSyncLastSuccessMs(ms: number): Promise<void> {
    const n = Math.max(0, Math.floor(ms));
    await this.safePutString(WebDavStateStore.AUTOSYNC_LAST_SUCCESS_MS_KEY, String(n));
    await this.safeFlush();
  }

  async getAutoSyncLastError(): Promise<string> {
    return await this.safeGetString(WebDavStateStore.AUTOSYNC_LAST_ERROR_KEY);
  }

  async setAutoSyncLastError(msg: string): Promise<void> {
    await this.safePutString(WebDavStateStore.AUTOSYNC_LAST_ERROR_KEY, msg);
    await this.safeFlush();
  }

  private isJsonValid(json: string): boolean {
    if (json.length === 0) {
      return false;
    }
    try {
      const parsed: object = JSON.parse(json) as object;
      return typeof parsed === 'object' && parsed !== null;
    } catch (e) {
      return false;
    }
  }

  private async getJsonWithBackup(keys: StoredJsonKeys): Promise<string> {
    if (!await this.ensureInitialized()) {
      return '';
    }
    if (this.prefs === null) {
      return '';
    }

    const primary = await this.safeGetString(keys.primaryKey);
    if (this.isJsonValid(primary)) {
      return primary;
    }

    const backup = await this.safeGetString(keys.backupKey);
    if (!this.isJsonValid(backup)) {
      return '';
    }

    await this.safePutString(keys.primaryKey, backup);
    await this.safeFlush();
    return backup;
  }

  private async saveJsonWithBackup(keys: StoredJsonKeys, json: string): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }
    if (this.prefs === null) {
      return false;
    }
    if (!this.isJsonValid(json)) {
      return false;
    }
    try {
      await this.prefs.put(keys.primaryKey, json);
      await this.prefs.put(keys.backupKey, json);
      await this.prefs.put(keys.backupTsKey, String(Date.now()));
      await this.prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  private async safeGetString(key: string): Promise<string> {
    if (this.prefs === null) {
      return '';
    }
    try {
      return await this.prefs.get(key, '');
    } catch (e) {
      return '';
    }
  }

  private async safePutString(key: string, value: string): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(key, value);
    } catch (e) {
      return;
    }
  }

  private async safeFlush(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.flush();
    } catch (e) {
      return;
    }
  }
}
