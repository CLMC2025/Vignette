import type common from '@ohos.app.ability.common';
import { WebDavSyncManager } from './WebDavSyncManager';
import { WebDavStateStore } from '../utils/WebDavStateStore';

export class AutoWebDavSyncManager {
  private static instance: AutoWebDavSyncManager | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  private readonly store: WebDavStateStore = WebDavStateStore.getInstance();
  private readonly webdav: WebDavSyncManager = WebDavSyncManager.getInstance();
  private busy: boolean = false;

  private constructor() {}

  static getInstance(): AutoWebDavSyncManager {
    if (AutoWebDavSyncManager.instance === null) {
      AutoWebDavSyncManager.instance = new AutoWebDavSyncManager();
    }
    return AutoWebDavSyncManager.instance;
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.abilityContext = context;
    this.store.injectContext(context);
    await this.store.initialize();
    await this.webdav.initialize(context);
  }

  private isWebDavConfigured(): boolean {
    const s = this.webdav.getSettings();
    return s.endpoint.trim().length > 0 && s.username.trim().length > 0;
  }

  async tryRun(reason: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const now = Date.now();
    try {
      if (this.abilityContext === null) {
        this.busy = false;
        return;
      }
      if (!this.isWebDavConfigured()) {
        this.busy = false;
        return;
      }
      const enabled = await this.store.getAutoSyncEnabled();
      if (!enabled) {
        this.busy = false;
        return;
      }
      const intervalHours = await this.store.getAutoSyncIntervalHours();
      const intervalMs = Math.max(1, intervalHours) * 60 * 60 * 1000;
      const lastRun = await this.store.getAutoSyncLastRunMs();
      if (lastRun > 0 && now - lastRun < intervalMs) {
        this.busy = false;
        return;
      }
      await this.store.setAutoSyncLastRunMs(now);
      await this.store.setAutoSyncLastError('');

      console.info(`[WebDAV] autosync start reason=${reason}`);

      const pullEvents = await this.webdav.downloadAndMergeRemoteEvents();
      if (!pullEvents.success) {
        await this.store.setAutoSyncLastError(`pull_events: ${pullEvents.message} ${pullEvents.detail}`);
        console.warn(`[WebDAV] autosync failed step=pull_events msg=${pullEvents.message}`);
        this.busy = false;
        return;
      }

      const pushEvents = await this.webdav.uploadReviewEvents();
      if (!pushEvents.success) {
        await this.store.setAutoSyncLastError(`push_events: ${pushEvents.message} ${pushEvents.detail}`);
        console.warn(`[WebDAV] autosync failed step=push_events msg=${pushEvents.message}`);
        this.busy = false;
        return;
      }

      const uploadBackupEnabled = await this.store.getAutoSyncUploadBackupEnabled();
      if (uploadBackupEnabled) {
        const backup = await this.webdav.backupToCloud();
        if (!backup.success) {
          await this.store.setAutoSyncLastError(`backup: ${backup.message} ${backup.detail}`);
          console.warn(`[WebDAV] autosync failed step=backup msg=${backup.message}`);
          this.busy = false;
          return;
        }
      }

      await this.store.setAutoSyncLastSuccessMs(now);
      console.info('[WebDAV] autosync success');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await this.store.setAutoSyncLastError(`exception: ${msg}`);
      console.error(`[WebDAV] autosync exception: ${msg}`);
    } finally {
      this.busy = false;
    }
  }
}
