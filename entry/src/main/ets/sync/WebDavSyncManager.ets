// =====================================================
// WebDavSyncManager.ets - WebDAV-only sync & evolution pipeline
//
// Features:
// - Backup/restore: encrypted export/import of app data
// - Review events sync: encrypted JSONL upload/download
// - Model sync: encrypted policy upload/download
// - Conflict policy: Last-Modified/ETag check + snapshot backup
//
// This module is designed for a "no server" deployment.
// =====================================================

import { DataSyncManager } from './DataSyncManager';
import { DBManager } from '../database/DBManager';
import { WebDavClient } from './webdav/WebDavClient';
import type { IWebDavBackend } from './webdav/IWebDavBackend';
import { WebDavStateStore } from '../utils/WebDavStateStore';
import type common from '@ohos.app.ability.common';
import { 
  WebDavSettings, WebDavManifest, WebDavSyncResult, WebDavSyncStatus, 
  WebDavBackupPlainResult, safeTrim, normalizeRoot, generateDeviceId,
  BACKUP_FILE_NAME, EVENTS_FILE_NAME, TEMPLATE_PACK_FILE_NAME,
  WORDS_DELTA_FILE_NAME, DEFINITIONS_FILE_NAME
} from './webdav/WebDavCommon';
import { WebDavBackupManager } from './webdav/WebDavBackupManager';
import { WebDavEventsSync } from './webdav/WebDavEventsSync';
import { WebDavModelSync } from './webdav/WebDavModelSync';
import { WebDavIncrementalSync } from './webdav/WebDavIncrementalSync';
import taskpool from '@ohos.taskpool';
import { 
  executeBackupUpload, 
  executeDownload, 
  executeUpload,
  BackupTaskParams, 
  BackupTaskResult,
  DownloadTaskParams,
  DownloadTaskResult,
  UploadTaskParams,
  UploadTaskResult
} from './webdav/WebDavSyncTask';
import { WebDavCrypto } from './webdav/WebDavCrypto';

// 复习事件行接口
interface ReviewEventRow {
  id: string;
  wordId: number;
  rating: number;
  timestamp: number;
  prevStateJson: string;
  newStateJson: string;
  errorTag: string;
  reflection: string;
  scheduledDays: number;
}

export { 
  WebDavSyncStatus, 
  WebDavSettingsJSON, 
  WebDavManifestJSON, 
  ReviewEventJSON, 
  WebDavSettings, 
  WebDavManifest, 
  WebDavSyncResult, 
  WebDavBackupPlainResult 
} from './webdav/WebDavCommon';

export class WebDavSyncManager {
  private static instance: WebDavSyncManager | null = null;

  private status: WebDavSyncStatus = WebDavSyncStatus.IDLE;

  private settings: WebDavSettings = new WebDavSettings();
  private manifest: WebDavManifest = new WebDavManifest(generateDeviceId());
  private lastSnapshotJson: string = '';
  private storeReady: boolean = false;
  private store: WebDavStateStore = WebDavStateStore.getInstance();
  private remoteLayoutKey: string = '';
  private remoteLayoutBase: string = '/';
  private remoteLayoutPrefix: string = '';

  private syncManager: DataSyncManager = DataSyncManager.getInstance();
  private db: DBManager = DBManager.getInstance();

  private backupManager: WebDavBackupManager;
  private eventsSync: WebDavEventsSync;
  private modelSync: WebDavModelSync;
  private incrementalSync: WebDavIncrementalSync;

  private constructor() {
    this.backupManager = new WebDavBackupManager(this.syncManager, this.store);
    this.eventsSync = new WebDavEventsSync(this.db, this.store);
    this.modelSync = new WebDavModelSync(this.store);
    this.incrementalSync = new WebDavIncrementalSync(this.syncManager, this.store);
  }

  static getInstance(): WebDavSyncManager {
    if (WebDavSyncManager.instance === null) {
      WebDavSyncManager.instance = new WebDavSyncManager();
    }
    return WebDavSyncManager.instance;
  }

  getStatus(): WebDavSyncStatus {
    return this.status;
  }

  getSettings(): WebDavSettings {
    return this.settings;
  }

  async setSettings(settings: WebDavSettings): Promise<boolean> {
    this.settings = settings;
    this.settings.remoteRoot = normalizeRoot(this.settings.remoteRoot);
    this.remoteLayoutKey = '';
    
    if (!this.storeReady) {
      console.warn('[WebDavSyncManager] setSettings: store not ready, settings cached but not saved');
    }
    
    const saved = this.storeReady ? await this.store.saveSettingsJson(this.settings.toJSON()) : false;
    return saved || this.storeReady === false;
  }

  getManifest(): WebDavManifest {
    return this.manifest;
  }

  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    if (this.storeReady) {
      return true;
    }
    this.store.injectContext(context);
    const ok = await this.store.initialize();
    if (!ok) {
      return false;
    }

    const settingsJson = await this.store.getSettingsJson();
    if (settingsJson.length > 0) {
      this.settings = WebDavSettings.fromJSON(settingsJson);
      this.settings.remoteRoot = normalizeRoot(this.settings.remoteRoot);
    }

    const manifestJson = await this.store.getManifestJson();
    if (manifestJson.length > 0) {
      this.manifest = WebDavManifest.fromJSON(manifestJson, this.manifest.deviceId);
    } else {
      await this.store.saveManifestJson(this.manifest.toJSON());
    }

    const snapshotJson = await this.store.getSnapshotJson();
    if (snapshotJson.length > 0) {
      this.lastSnapshotJson = snapshotJson;
    }

    this.storeReady = true;
    return true;
  }

  private requireConfigured(): WebDavSyncResult | null {
    if (safeTrim(this.settings.endpoint).length === 0) {
      return WebDavSyncResult.fail('未配置 WebDAV 地址', 'WebDAV endpoint is empty');
    }
    if (safeTrim(this.settings.username).length === 0 || safeTrim(this.settings.password).length === 0) {
      return WebDavSyncResult.fail('未配置 WebDAV 账号', 'WebDAV username/password is empty');
    }
    if (safeTrim(this.settings.syncPassword).length < 4) {
      return WebDavSyncResult.fail('同步密码过短', 'Sync password is too short');
    }
    return null;
  }

  private createClient(): IWebDavBackend {
    return new WebDavClient(
      this.settings.endpoint,
      this.settings.username,
      this.settings.password
    );
  }

  private rootPath(...parts: string[]): string {
    const base = normalizeRoot(this.settings.remoteRoot);
    let p = base;
    for (const part of parts) {
      const clean = part.replace(/^\/+|\/+$/g, '');
      if (clean.length > 0) {
        p = `${p}/${clean}`;
      }
    }
    return p;
  }

  private sanitizePrefix(remoteRoot: string): string {
    const raw = remoteRoot.replace(/^\/+/, '').replace(/\/+$/g, '');
    const replaced = raw.replace(/\/+/g, '_').replace(/[^0-9a-zA-Z_-]+/g, '_');
    const trimmed = replaced.replace(/^_+|_+$/g, '');
    const out = trimmed.length > 0 ? trimmed : 'weiyu_vignette';
    return out.length > 64 ? out.slice(0, 64) : out;
  }

  private composeRemotePath(base: string, prefix: string, fileName: string): string {
    const b = base.replace(/\/+$/g, '') || '/';
    const name = prefix.length > 0 ? `${prefix}${fileName}` : fileName;
    if (b === '/') {
      return `/${name}`;
    }
    return `${b}/${name}`;
  }

  private backupFilePath(): string {
    return this.composeRemotePath(this.remoteLayoutBase, this.remoteLayoutPrefix, BACKUP_FILE_NAME);
  }

  private legacyBackupFilePath(): string {
    return this.rootPath('data', BACKUP_FILE_NAME);
  }

  private eventsFilePath(): string {
    return this.composeRemotePath(this.remoteLayoutBase, this.remoteLayoutPrefix, EVENTS_FILE_NAME);
  }

  private templatePackFilePath(): string {
    return this.composeRemotePath(this.remoteLayoutBase, this.remoteLayoutPrefix, TEMPLATE_PACK_FILE_NAME);
  }

  private wordsDeltaFilePath(): string {
    return this.composeRemotePath(this.remoteLayoutBase, this.remoteLayoutPrefix, WORDS_DELTA_FILE_NAME);
  }

  private definitionsFilePath(): string {
    return this.composeRemotePath(this.remoteLayoutBase, this.remoteLayoutPrefix, DEFINITIONS_FILE_NAME);
  }

  private isCollectionReachable(statusCode: number): boolean {
    if (statusCode >= 200 && statusCode < 400) {
      return true;
    }
    return statusCode === 405;
  }

  private async probeRootWritable(client: IWebDavBackend, prefix: string): Promise<WebDavSyncResult | null> {
    const probeName = `.probe_${Date.now()}.txt`;
    const probePath = this.composeRemotePath('/', prefix, probeName);
    const putRes = await client.put(probePath, 'probe', 'text/plain');
    if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
      await client.delete(probePath);
      return null;
    }
    if (putRes.statusCode === 401 || putRes.statusCode === 403) {
      const msg = putRes.statusCode === 401 ? '鉴权失败（可能需要应用专用密码）' : '根目录权限不足，无法使用根目录前缀模式';
      return WebDavSyncResult.fail('WebDAV 连接失败', `STEP endpoint PUT ${putRes.statusCode}: ${msg}；请在 WebDAV 端创建 ${this.settings.remoteRoot} 或填写一个已存在且有权限的远端目录`);
    }
    if (putRes.statusCode === 409) {
      return WebDavSyncResult.fail('WebDAV 连接失败', `STEP endpoint PUT 409: 路径不存在（AncestorNotFound）；请检查 WebDAV 地址是否指向可用的根目录（例如以 /dav/ 结尾），或先在 WebDAV 端创建 ${this.settings.remoteRoot}`);
    }
    return WebDavSyncResult.fail('WebDAV 连接失败', `STEP endpoint PUT ${putRes.statusCode}: ${putRes.body}`);
  }

  private async probeCollectionWritable(client: IWebDavBackend, base: string): Promise<WebDavSyncResult | null> {
    const probeName = `.probe_${Date.now()}.txt`;
    const probePath = this.composeRemotePath(base, '', probeName);
    const putRes = await client.put(probePath, 'probe', 'text/plain');
    if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
      await client.delete(probePath);
      return null;
    }
    if (putRes.statusCode === 401 || putRes.statusCode === 403) {
      const msg = putRes.statusCode === 401 ? '鉴权失败（可能需要应用专用密码）' : '权限不足（目录可能不可写）';
      return WebDavSyncResult.fail('WebDAV 连接失败', `STEP remoteRoot PUT ${putRes.statusCode}: ${msg}`);
    }
    if (putRes.statusCode === 404) {
      return WebDavSyncResult.fail('WebDAV 连接失败', `STEP remoteRoot PUT 404: 远端目录不存在或不可用，请先创建 ${this.settings.remoteRoot}`);
    }
    if (putRes.statusCode === 409) {
      return WebDavSyncResult.fail('WebDAV 连接失败', `STEP remoteRoot PUT 409: 路径不存在（AncestorNotFound）；请先创建 ${this.settings.remoteRoot}`);
    }
    return WebDavSyncResult.fail('WebDAV 连接失败', `STEP remoteRoot PUT ${putRes.statusCode}: ${putRes.body}`);
  }

  private async preflightRemoteRoot(client: IWebDavBackend): Promise<WebDavSyncResult | null> {
    const key = `${safeTrim(this.settings.endpoint)}|${safeTrim(this.settings.remoteRoot)}`;
    if (this.remoteLayoutKey === key) {
      return null;
    }

    const remoteRoot = normalizeRoot(this.settings.remoteRoot);
    if (remoteRoot === '/') {
      this.remoteLayoutKey = key;
      this.remoteLayoutBase = '/';
      this.remoteLayoutPrefix = '';
      return null;
    }

    const rootHead = await client.head(remoteRoot);
    if (this.isCollectionReachable(rootHead.statusCode)) {
      this.remoteLayoutKey = key;
      this.remoteLayoutBase = remoteRoot;
      this.remoteLayoutPrefix = '';
      return null;
    }

    // 目录不存在，尝试创建
    if (rootHead.statusCode === 404) {
      console.info(`[WebDavSyncManager] Remote directory ${remoteRoot} not found, trying to create it`);
      const createResult = await this.ensureRemoteDirectory(client, remoteRoot);
      if (createResult !== null) {
        return createResult;
      }
      // 创建成功，重新检查
      const recheckHead = await client.head(remoteRoot);
      if (this.isCollectionReachable(recheckHead.statusCode)) {
        this.remoteLayoutKey = key;
        this.remoteLayoutBase = remoteRoot;
        this.remoteLayoutPrefix = '';
        return null;
      }
    }

    const probeRemoteRoot = await this.probeCollectionWritable(client, remoteRoot);
    if (probeRemoteRoot === null) {
      this.remoteLayoutKey = key;
      this.remoteLayoutBase = remoteRoot;
      this.remoteLayoutPrefix = '';
      return null;
    }

    if (this.settings.requireRemoteRootExists) {
      return probeRemoteRoot;
    }

    const prefix = `${this.sanitizePrefix(remoteRoot)}__`;
    const probe = await this.probeRootWritable(client, prefix);
    if (probe !== null) {
      return probe;
    }
    this.remoteLayoutKey = key;
    this.remoteLayoutBase = '/';
    this.remoteLayoutPrefix = prefix;
    return null;
  }

  /**
   * 确保远程目录存在，如果不存在则创建
   */
  private async ensureRemoteDirectory(client: IWebDavBackend, path: string): Promise<WebDavSyncResult | null> {
    try {
      // 递归创建父目录
      const lastSlash = path.lastIndexOf('/');
      if (lastSlash > 0) {
        const parent = path.substring(0, lastSlash);
        if (parent.length > 0 && parent !== '/') {
          const parentHead = await client.head(parent);
          if (parentHead.statusCode === 404) {
            const parentResult = await this.ensureRemoteDirectory(client, parent);
            if (parentResult !== null) {
              return parentResult;
            }
          }
        }
      }

      // 创建当前目录（通过 PUT 一个 .keep 文件）
      const keepFile = path.endsWith('/') ? `${path}.keep` : `${path}/.keep`;
      const putRes = await client.put(keepFile, 'keep', 'text/plain');
      if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
        console.info(`[WebDavSyncManager] Created remote directory: ${path}`);
        return null;
      }
      if (putRes.statusCode === 401 || putRes.statusCode === 403) {
        return WebDavSyncResult.fail('创建目录失败', `权限不足: ${putRes.statusCode}`);
      }
      return WebDavSyncResult.fail('创建目录失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('创建目录失败', msg);
    }
  }

  async testConnection(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.TESTING;
    try {
      const client = this.createClient();
      const remoteRoot = normalizeRoot(this.settings.remoteRoot);
      if (remoteRoot !== '/') {
        const rootHead = await client.head(remoteRoot);
        if (this.isCollectionReachable(rootHead.statusCode)) {
          this.remoteLayoutKey = `${safeTrim(this.settings.endpoint)}|${safeTrim(this.settings.remoteRoot)}`;
          this.remoteLayoutBase = remoteRoot;
          this.remoteLayoutPrefix = '';
          this.status = WebDavSyncStatus.IDLE;
          return WebDavSyncResult.ok('WebDAV 连接成功');
        }

        const probeRemoteRoot = await this.probeCollectionWritable(client, remoteRoot);
        if (probeRemoteRoot === null) {
          this.remoteLayoutKey = `${safeTrim(this.settings.endpoint)}|${safeTrim(this.settings.remoteRoot)}`;
          this.remoteLayoutBase = remoteRoot;
          this.remoteLayoutPrefix = '';
          this.status = WebDavSyncStatus.IDLE;
          return WebDavSyncResult.ok('WebDAV 连接成功');
        }

        if (this.settings.requireRemoteRootExists) {
          this.status = WebDavSyncStatus.ERROR;
          return probeRemoteRoot;
        }

        const prefix = `${this.sanitizePrefix(remoteRoot)}__`;
        const probe = await this.probeRootWritable(client, prefix);
        if (probe !== null) {
          this.status = WebDavSyncStatus.ERROR;
          return probe;
        }
        this.remoteLayoutKey = `${safeTrim(this.settings.endpoint)}|${safeTrim(this.settings.remoteRoot)}`;
        this.remoteLayoutBase = '/';
        this.remoteLayoutPrefix = prefix;
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.ok('WebDAV 连接成功（已使用根目录前缀模式）');
      }

      const probe = await this.probeRootWritable(client, '');
      if (probe !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return probe;
      }
      this.remoteLayoutKey = `${safeTrim(this.settings.endpoint)}|${safeTrim(this.settings.remoteRoot)}`;
      this.remoteLayoutBase = '/';
      this.remoteLayoutPrefix = '';
      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok('WebDAV 连接成功');
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('WebDAV 连接失败', msg);
    }
  }

  // ==================== Backup / Restore ====================

  async backupToCloud(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.backupManager.backupToCloud(
        client,
        this.settings,
        this.manifest,
        this.backupFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('备份失败', msg);
    }
  }

  async downloadBackupPlain(force: boolean = false): Promise<WebDavBackupPlainResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return new WebDavBackupPlainResult(missing, '');

    this.status = WebDavSyncStatus.RESTORING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return new WebDavBackupPlainResult(preflight, '');
      }

      const result = await this.backupManager.downloadBackupPlain(
        client,
        this.settings,
        this.manifest,
        this.backupFilePath(),
        this.legacyBackupFilePath(),
        force
      );
      
      this.status = result.result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return new WebDavBackupPlainResult(WebDavSyncResult.fail('下载失败', msg), '');
    }
  }

  async importPlainBackup(plain: string): Promise<WebDavSyncResult> {
    this.status = WebDavSyncStatus.RESTORING;
    const result = await this.backupManager.importPlainBackup(plain);
    this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
    return result;
  }

  async restoreFromCloud(force: boolean = false): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.RESTORING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.backupManager.restoreFromCloud(
        client,
        this.settings,
        this.manifest,
        this.backupFilePath(),
        this.legacyBackupFilePath(),
        force
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('恢复失败', msg);
    }
  }

  getLastSnapshot(): string {
    return this.lastSnapshotJson;
  }

  // ==================== Review Events Sync ====================

  async uploadLocalReviewEvents(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.eventsSync.uploadLocalReviewEvents(
        client,
        this.settings,
        this.manifest,
        this.eventsFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('上传复习记录失败', msg);
    }
  }

  /**
   * Backward compatible alias for UI.
   */
  async uploadReviewEvents(): Promise<WebDavSyncResult> {
    return this.uploadLocalReviewEvents();
  }

  async downloadAndMergeRemoteEvents(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.eventsSync.downloadAndMergeRemoteEvents(
        client,
        this.settings,
        this.manifest,
        this.eventsFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('拉取复习记录失败', msg);
    }
  }

  // ==================== Offline Template Pack ====================

  async downloadTemplatePack(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.modelSync.downloadTemplatePack(
        client,
        this.settings,
        this.manifest,
        this.templatePackFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('下载离线模板包失败', msg);
    }
  }

  async uploadTemplatePack(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.modelSync.uploadTemplatePack(
        client,
        this.settings,
        this.manifest,
        this.templatePackFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('上传离线模板包失败', msg);
    }
  }

  // ==================== Incremental Sync ====================

  async syncIncremental(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    // 检查是否已经在同步中
    if (this.status === WebDavSyncStatus.SYNCING) {
      return WebDavSyncResult.fail('同步操作正在进行中', '请等待当前同步完成后再试');
    }

    this.status = WebDavSyncStatus.SYNCING;

    // 先确保远程目录存在
    const client = this.createClient();
    const preflight = await this.preflightRemoteRoot(client);
    if (preflight !== null) {
      this.status = WebDavSyncStatus.ERROR;
      return preflight;
    }

    // yield 给 UI 线程
    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    try {
      const syncManager = DataSyncManager.getInstance();
      const dbManager = DBManager.getInstance();

      // ========== 步骤 1: 单词下载 ==========
      console.info('[WebDavSyncManager] Step 1: Download words delta');
      const downloadParams: DownloadTaskParams = {
        endpoint: this.settings.endpoint,
        username: this.settings.username,
        password: this.settings.password,
        syncPassword: this.settings.syncPassword,
        remoteRoot: this.settings.remoteRoot,
        manifestJson: this.manifest.toJSON(),
        remoteFile: this.wordsDeltaFilePath()
      };
      const downloadResult = await taskpool.execute(new taskpool.Task(executeDownload, downloadParams)) as DownloadTaskResult;

      if (!downloadResult.success) {
        return WebDavSyncResult.fail('增量同步失败（单词下载）', downloadResult.detail);
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 如果有数据，导入单词
      if (downloadResult.data.length > 0) {
        const importResult = await syncManager.importIncremental(downloadResult.data);
        if (importResult.hasErrors()) {
          return WebDavSyncResult.fail('增量同步失败（单词下载）', importResult.errors.join('; '));
        }
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // ========== 步骤 2: 单词上传 ==========
      console.info('[WebDavSyncManager] Step 2: Upload words delta');
      const exportResult = await syncManager.exportIncremental(this.manifest.lastWordsSyncMs, false);
      if (!exportResult.success) {
        return WebDavSyncResult.fail('增量同步失败（单词上传）', exportResult.error);
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      if (exportResult.data.length > 0) {
        // 加密数据
        const enc = await WebDavCrypto.encryptUtf8Async(exportResult.data, this.settings.syncPassword);

        // yield 给 UI 线程
        await new Promise<void>((resolve) => setTimeout(resolve, 0));

        const uploadParams: UploadTaskParams = {
          endpoint: this.settings.endpoint,
          username: this.settings.username,
          password: this.settings.password,
          syncPassword: this.settings.syncPassword,
          remoteRoot: this.settings.remoteRoot,
          manifestJson: this.manifest.toJSON(),
          remoteFile: this.wordsDeltaFilePath(),
          data: enc
        };
        const uploadResult = await taskpool.execute(new taskpool.Task(executeUpload, uploadParams)) as UploadTaskResult;

        if (!uploadResult.success) {
          return WebDavSyncResult.fail('增量同步失败（单词上传）', uploadResult.detail);
        }
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // ========== 步骤 3: 事件下载 ==========
      console.info('[WebDavSyncManager] Step 3: Download events');
      const eventsDownloadParams: DownloadTaskParams = {
        endpoint: this.settings.endpoint,
        username: this.settings.username,
        password: this.settings.password,
        syncPassword: this.settings.syncPassword,
        remoteRoot: this.settings.remoteRoot,
        manifestJson: this.manifest.toJSON(),
        remoteFile: this.eventsFilePath()
      };
      const eventsDownloadResult = await taskpool.execute(new taskpool.Task(executeDownload, eventsDownloadParams)) as DownloadTaskResult;

      if (!eventsDownloadResult.success) {
        return WebDavSyncResult.fail('增量同步失败（事件下载）', eventsDownloadResult.detail);
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 如果有数据，导入事件
      if (eventsDownloadResult.data.length > 0) {
        const events = this.parseEventsJsonl(eventsDownloadResult.data);
        await dbManager.insertReviewEvents(events);
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // ========== 步骤 4: 事件上传 ==========
      console.info('[WebDavSyncManager] Step 4: Upload events');
      const events = await dbManager.getReviewEventsAfter(this.manifest.lastEventsSyncMs);

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      if (events.length > 0) {
        const eventsJsonl = this.serializeEventsJsonl(events);

        // yield 给 UI 线程
        await new Promise<void>((resolve) => setTimeout(resolve, 0));

        const enc = await WebDavCrypto.encryptUtf8Async(eventsJsonl, this.settings.syncPassword);

        // yield 给 UI 线程
        await new Promise<void>((resolve) => setTimeout(resolve, 0));

        const eventsUploadParams: UploadTaskParams = {
          endpoint: this.settings.endpoint,
          username: this.settings.username,
          password: this.settings.password,
          syncPassword: this.settings.syncPassword,
          remoteRoot: this.settings.remoteRoot,
          manifestJson: this.manifest.toJSON(),
          remoteFile: this.eventsFilePath(),
          data: enc
        };
        const eventsUploadResult = await taskpool.execute(new taskpool.Task(executeUpload, eventsUploadParams)) as UploadTaskResult;

        if (!eventsUploadResult.success) {
          return WebDavSyncResult.fail('增量同步失败（事件上传）', eventsUploadResult.detail);
        }
      }

      return WebDavSyncResult.ok('同步完成');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('增量同步失败', msg);
    } finally {
      // 确保状态总是重置为 IDLE
      this.status = WebDavSyncStatus.IDLE;
    }
  }

  /**
   * 在 TaskPool 中执行备份（后台执行，不阻塞 UI）
   */
  async backupToCloudInBackground(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    // 检查是否已经在同步中
    if (this.status === WebDavSyncStatus.SYNCING) {
      return WebDavSyncResult.fail('同步操作正在进行中', '请等待当前同步完成后再试');
    }

    this.status = WebDavSyncStatus.SYNCING;

    // 先确保远程目录存在
    const client = this.createClient();
    const preflight = await this.preflightRemoteRoot(client);
    if (preflight !== null) {
      this.status = WebDavSyncStatus.ERROR;
      return preflight;
    }

    // yield 给 UI 线程
    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    try {
      const syncManager = DataSyncManager.getInstance();

      // 导出数据（在主线程执行，需要数据库）
      console.info('[WebDavSyncManager] Exporting data');
      const exportResult = await syncManager.exportData();
      if (!exportResult.success) {
        return WebDavSyncResult.fail('备份失败', exportResult.error);
      }

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 加密数据（在主线程执行）
      console.info('[WebDavSyncManager] Encrypting data');
      const enc = await WebDavCrypto.encryptUtf8Async(exportResult.data, this.settings.syncPassword);

      // yield 给 UI 线程
      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 上传数据（在 TaskPool 中执行）
      console.info('[WebDavSyncManager] Uploading data');
      const params: BackupTaskParams = {
        endpoint: this.settings.endpoint,
        username: this.settings.username,
        password: this.settings.password,
        syncPassword: this.settings.syncPassword,
        remoteRoot: this.settings.remoteRoot,
        manifestJson: this.manifest.toJSON(),
        backupFilePath: this.backupFilePath(),
        backupData: enc
      };

      const task = new taskpool.Task(executeBackupUpload, params);
      const result = await taskpool.execute(task) as BackupTaskResult;

      if (result.success) {
        return WebDavSyncResult.ok(result.message);
      } else {
        return WebDavSyncResult.fail('备份失败', result.detail);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('备份失败', msg);
    } finally {
      // 确保状态总是重置为 IDLE
      this.status = WebDavSyncStatus.IDLE;
    }
  }

  // 序列化事件为 JSON Lines
  private serializeEventsJsonl(events: ReviewEventRow[]): string {
    let out = '';
    for (const e of events) {
      // 使用 Record<string, Object> 类型来避免对象字面量类型检查问题
      const obj: Record<string, Object> = {
        'id': e.id,
        'wordId': e.wordId,
        'rating': e.rating,
        'timestamp': e.timestamp,
        'prevStateJson': e.prevStateJson,
        'newStateJson': e.newStateJson,
        'errorTag': e.errorTag,
        'reflection': e.reflection,
        'scheduledDays': e.scheduledDays
      };
      out += `${JSON.stringify(obj)}\n`;
    }
    return out;
  }

  // 解析 JSON Lines
  private parseEventsJsonl(jsonl: string): ReviewEventRow[] {
    const lines = jsonl.split(/\r?\n/);
    const out: ReviewEventRow[] = [];
    for (const line of lines) {
      const s = line.trim();
      if (s.length === 0) continue;
      try {
        const obj = JSON.parse(s) as Record<string, string | number>;
        const row: ReviewEventRow = {
          id: (obj['id'] as string) ?? '',
          wordId: (obj['wordId'] as number) ?? 0,
          rating: (obj['rating'] as number) ?? 0,
          timestamp: (obj['timestamp'] as number) ?? 0,
          prevStateJson: (obj['prevStateJson'] as string) ?? '{}',
          newStateJson: (obj['newStateJson'] as string) ?? '{}',
          errorTag: (obj['errorTag'] as string) ?? '',
          reflection: (obj['reflection'] as string) ?? '',
          scheduledDays: (obj['scheduledDays'] as number) ?? 0
        };
        if (row.id.length > 0 && row.wordId > 0 && row.timestamp > 0) {
          out.push(row);
        }
      } catch (e) {
        // skip malformed line
      }
    }
    return out;
  }

  private buildIncrementalStepFailure(step: string, result: WebDavSyncResult): WebDavSyncResult {
    const detail = result.detail.length > 0 ? result.detail : result.message;
    return WebDavSyncResult.fail(`增量同步失败（${step}）`, `STEP ${step}: ${detail}`);
  }

  private async withTimeout<T>(promise: Promise<T>, ms: number, errorMsg: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(errorMsg));
      }, ms);
      promise
        .then((result: T) => {
          clearTimeout(timer);
          resolve(result);
        })
        .catch((err: Error) => {
          clearTimeout(timer);
          reject(err);
        });
    });
  }

  async uploadWordsDelta(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.incrementalSync.uploadWordsDelta(
        client,
        this.settings,
        this.manifest,
        this.wordsDeltaFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('上传单词增量失败', msg);
    }
  }

  async downloadWordsDelta(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.incrementalSync.downloadAndMergeWordsDelta(
        client,
        this.settings,
        this.manifest,
        this.wordsDeltaFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('下载单词增量失败', msg);
    }
  }

  async uploadDefinitions(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.incrementalSync.uploadDefinitions(
        client,
        this.settings,
        this.manifest,
        this.definitionsFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('上传释义数据失败', msg);
    }
  }

  async downloadDefinitions(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const preflight = await this.preflightRemoteRoot(client);
      if (preflight !== null) {
        this.status = WebDavSyncStatus.ERROR;
        return preflight;
      }

      const result = await this.incrementalSync.downloadDefinitions(
        client,
        this.settings,
        this.definitionsFilePath()
      );
      this.status = result.success ? WebDavSyncStatus.IDLE : WebDavSyncStatus.ERROR;
      return result;
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('下载释义数据失败', msg);
    }
  }
}
