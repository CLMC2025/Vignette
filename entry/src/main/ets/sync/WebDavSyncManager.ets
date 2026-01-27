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
import { DBManager, ReviewEventRow } from '../database/DBManager';
import { WebDavClient } from './webdav/WebDavClient';
import { WebDavCrypto, CryptoError } from './webdav/WebDavCrypto';
import { parsePropfindMeta, parsePropfindList, WebDavResourceMeta } from './webdav/WebDavXmlParser';
import { buildUserFacingError, ErrorInfo } from '../utils/ErrorClassifier';
import { OptimizerService } from '../evolve/OptimizerService';
import { EvolveModelStore, EvolveModelPackage } from '../evolve/ModelStore';
import { TemplateManager } from '../context/TemplateManager';

export enum WebDavSyncStatus {
  IDLE = 'IDLE',
  TESTING = 'TESTING',
  SYNCING = 'SYNCING',
  RESTORING = 'RESTORING',
  EVOLVING = 'EVOLVING',
  ERROR = 'ERROR'
}

export interface WebDavSettingsJSON {
  endpoint: string;
  username: string;
  password: string;
  syncPassword: string;
  remoteRoot: string;
}

// JSON interfaces for type-safe serialization
export interface WebDavManifestJSON {
  deviceId: string;
  lastBackupUploadMs: number;
  lastBackupEtag: string;
  lastEventsSyncMs: number;
  consumedEventHrefs: string[];
  lastModelVersion: number;
  lastModelEtag: string;
  lastTemplatePackDownloadMs: number;
  lastTemplatePackEtag: string;
}

// Review event JSON representation for JSON Lines format
export interface ReviewEventJSON {
  id: string;
  wordId: number;
  rating: number;
  timestamp: number;
  prevStateJson: string;
  newStateJson: string;
  errorTag: string;
  reflection: string;
}

export class WebDavSettings {
  endpoint: string;
  username: string;
  password: string;
  syncPassword: string;
  remoteRoot: string;

  constructor(
    endpoint: string = '',
    username: string = '',
    password: string = '',
    syncPassword: string = '',
    remoteRoot: string = '/weiyu_vignette'
  ) {
    this.endpoint = endpoint;
    this.username = username;
    this.password = password;
    this.syncPassword = syncPassword;
    this.remoteRoot = remoteRoot;
  }

  toJSON(): string {
    const obj: WebDavSettingsJSON = {
      endpoint: this.endpoint,
      username: this.username,
      password: this.password,
      syncPassword: this.syncPassword,
      remoteRoot: this.remoteRoot
    };
    return JSON.stringify(obj);
  }

  static fromJSON(json: string): WebDavSettings {
    try {
      const obj = JSON.parse(json) as Record<string, string>;
      return new WebDavSettings(
        obj['endpoint'] ?? '',
        obj['username'] ?? '',
        obj['password'] ?? '',
        obj['syncPassword'] ?? '',
        obj['remoteRoot'] ?? '/weiyu_vignette'
      );
    } catch (e) {
      return new WebDavSettings();
    }
  }
}

export class WebDavManifest {
  deviceId: string;
  lastBackupUploadMs: number;
  lastBackupEtag: string;
  lastEventsSyncMs: number;
  consumedEventHrefs: string[];
  lastModelVersion: number;
  lastModelEtag: string;
  lastTemplatePackDownloadMs: number;
  lastTemplatePackEtag: string;

  constructor(
    deviceId: string,
    lastBackupUploadMs: number = 0,
    lastBackupEtag: string = '',
    lastEventsSyncMs: number = 0,
    consumedEventHrefs: string[] = [],
    lastModelVersion: number = 0,
    lastModelEtag: string = '',
    lastTemplatePackDownloadMs: number = 0,
    lastTemplatePackEtag: string = ''
  ) {
    this.deviceId = deviceId;
    this.lastBackupUploadMs = lastBackupUploadMs;
    this.lastBackupEtag = lastBackupEtag;
    this.lastEventsSyncMs = lastEventsSyncMs;
    this.consumedEventHrefs = consumedEventHrefs;
    this.lastModelVersion = lastModelVersion;
    this.lastModelEtag = lastModelEtag;
    this.lastTemplatePackDownloadMs = lastTemplatePackDownloadMs;
    this.lastTemplatePackEtag = lastTemplatePackEtag;
  }

  toJSON(): string {
    // Use object directly without explicit type declaration
    const obj: WebDavManifestJSON = {
      deviceId: this.deviceId,
      lastBackupUploadMs: this.lastBackupUploadMs,
      lastBackupEtag: this.lastBackupEtag,
      lastEventsSyncMs: this.lastEventsSyncMs,
      consumedEventHrefs: this.consumedEventHrefs,
      lastModelVersion: this.lastModelVersion,
      lastModelEtag: this.lastModelEtag,
      lastTemplatePackDownloadMs: this.lastTemplatePackDownloadMs,
      lastTemplatePackEtag: this.lastTemplatePackEtag
    };
    return JSON.stringify(obj);
  }

  static fromJSON(json: string, fallbackDeviceId: string): WebDavManifest {
    try {
      const obj: WebDavManifestJSON = JSON.parse(json);
      return new WebDavManifest(
        obj.deviceId ?? fallbackDeviceId,
        obj.lastBackupUploadMs ?? 0,
        obj.lastBackupEtag ?? '',
        obj.lastEventsSyncMs ?? 0,
        obj.consumedEventHrefs ?? [],
        obj.lastModelVersion ?? 0,
        obj.lastModelEtag ?? '',
        obj.lastTemplatePackDownloadMs ?? 0,
        obj.lastTemplatePackEtag ?? ''
      );
    } catch (e) {
      return new WebDavManifest(fallbackDeviceId);
    }
  }
}

export class WebDavSyncResult {
  success: boolean;
  message: string;
  detail: string;
  userError: ErrorInfo | null;

  constructor(success: boolean, message: string, detail: string = '', userError: ErrorInfo | null = null) {
    this.success = success;
    this.message = message;
    this.detail = detail;
    this.userError = userError;
  }

  static ok(message: string): WebDavSyncResult {
    return new WebDavSyncResult(true, message, '');
  }

  static fail(message: string, detail: string): WebDavSyncResult {
    return new WebDavSyncResult(false, message, detail, buildUserFacingError(detail));
  }
}

function safeTrim(s: string): string {
  return s.trim();
}

function normalizeRoot(root: string): string {
  let r = root.trim();
  if (r.length === 0) {
    r = '/weiyu_vignette';
  }
  if (!r.startsWith('/')) {
    r = `/${r}`;
  }
  // remove trailing slash
  r = r.replace(/\/+$/g, '');
  return r;
}

function parseHttpDateMillis(s: string): number {
  const t = Date.parse(s);
  if (Number.isNaN(t)) return 0;
  return t;
}

function generateDeviceId(): string {
  const rand = Math.random().toString(36).substring(2, 10);
  return `dev_${Date.now()}_${rand}`;
}

export class WebDavBackupPlainResult {
  result: WebDavSyncResult;
  plain: string;

  constructor(result: WebDavSyncResult, plain: string) {
    this.result = result;
    this.plain = plain;
  }
}

export class WebDavSyncManager {
  private static instance: WebDavSyncManager | null = null;

  private readonly SETTINGS_KEY: string = 'webdav_settings';
  private readonly MANIFEST_KEY: string = 'webdav_manifest';
  private readonly SNAPSHOT_KEY: string = 'webdav_last_snapshot_json';

  private status: WebDavSyncStatus = WebDavSyncStatus.IDLE;

  // Offline template pack (optional). Stored as encrypted JSON on WebDAV.
  private static readonly TEMPLATE_PACK_REMOTE_PATH: string = 'templates/template_pack.json.enc';
  private settings: WebDavSettings = new WebDavSettings();
  private manifest: WebDavManifest = new WebDavManifest(generateDeviceId());

  private syncManager: DataSyncManager = DataSyncManager.getInstance();
  private db: DBManager = DBManager.getInstance();
  private optimizer: OptimizerService = OptimizerService.getInstance();

  private constructor() {
    this.load();
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

  setSettings(settings: WebDavSettings): void {
    this.settings = settings;
    this.persist();
  }

  getManifest(): WebDavManifest {
    return this.manifest;
  }

  private load(): void {
    const s = AppStorage.get<string>(this.SETTINGS_KEY);
    if (s !== undefined && s.length > 0) {
      this.settings = WebDavSettings.fromJSON(s);
      this.settings.remoteRoot = normalizeRoot(this.settings.remoteRoot);
    }

    let deviceId = AppStorage.get<string>('device_id');
    if (deviceId === undefined || deviceId.length === 0) {
      deviceId = generateDeviceId();
      AppStorage.setOrCreate('device_id', deviceId);
    }

    const m = AppStorage.get<string>(this.MANIFEST_KEY);
    if (m !== undefined && m.length > 0) {
      this.manifest = WebDavManifest.fromJSON(m, deviceId);
    } else {
      this.manifest = new WebDavManifest(deviceId);
    }
  }

  private persist(): void {
    AppStorage.setOrCreate(this.SETTINGS_KEY, this.settings.toJSON());
    AppStorage.setOrCreate(this.MANIFEST_KEY, this.manifest.toJSON());
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

  private createClient(): WebDavClient {
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

  private async ensureCollection(client: WebDavClient, path: string): Promise<void> {
    // Create nested collections step-by-step
    const parts = path.replace(/^\/+/, '').split('/');
    let curr = '';
    for (const part of parts) {
      if (part.length === 0) continue;
      curr += `/${part}`;
      const res = await client.mkcol(curr);
      // 201 Created: ok; 405 Method Not Allowed: already exists (common)
      if (res.statusCode === 201 || res.statusCode === 405 || res.statusCode === 301 || res.statusCode === 302) {
        continue;
      }
      if (res.statusCode === 0) {
        throw new Error(`MKCOL failed: ${res.body}`);
      }
      if (res.statusCode >= 400 && res.statusCode !== 409) {
        // 409 means parent missing, but we create step-by-step so shouldn't happen
        throw new Error(`MKCOL failed: ${res.statusCode} ${res.body}`);
      }
    }
  }

  async testConnection(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.TESTING;
    try {
      const client = this.createClient();
      const root = this.rootPath();
      await this.ensureCollection(client, root);
      const meta = await client.propfind(root, '0');
      if (meta.statusCode >= 200 && meta.statusCode < 300) {
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.ok('WebDAV 连接成功');
      }
      this.status = WebDavSyncStatus.ERROR;
      return WebDavSyncResult.fail('WebDAV 连接失败', `PROPFIND ${meta.statusCode}: ${meta.body}`);
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
      await this.ensureCollection(client, this.rootPath('data'));

      const exportResult = await this.syncManager.exportData();
      if (!exportResult.success) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('导出失败', exportResult.error);
      }

      const enc = WebDavCrypto.encryptUtf8(exportResult.data, this.settings.syncPassword);
      const remoteFile = this.rootPath('data', 'backup.json.enc');
      const putRes = await client.put(remoteFile, enc, 'application/json');
      if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('上传失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
      }

      // Refresh meta
      const propRes = await client.propfind(remoteFile, '0');
      const meta = parsePropfindMeta(propRes.body);
      this.manifest.lastBackupUploadMs = Date.now();
      this.manifest.lastBackupEtag = meta.etag;
      this.persist();

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok('备份已上传');
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
      const remoteFile = this.rootPath('data', 'backup.json.enc');

      if (!force) {
        const propRes = await client.propfind(remoteFile, '0');
        if (propRes.statusCode >= 400 || propRes.statusCode === 0) {
          this.status = WebDavSyncStatus.ERROR;
          return new WebDavBackupPlainResult(
            WebDavSyncResult.fail('获取云端备份信息失败', `PROPFIND ${propRes.statusCode}: ${propRes.body}`),
            ''
          );
        }
        const meta = parsePropfindMeta(propRes.body);
        const remoteMs = parseHttpDateMillis(meta.lastModified);
        if (remoteMs > 0 && remoteMs <= this.manifest.lastBackupUploadMs) {
          this.status = WebDavSyncStatus.IDLE;
          return new WebDavBackupPlainResult(WebDavSyncResult.ok('云端备份未更新，无需恢复'), '');
        }
      }

      const snapshot = await this.syncManager.exportData();
      if (snapshot.success) {
        AppStorage.setOrCreate(this.SNAPSHOT_KEY, snapshot.data);
      }

      const getRes = await client.get(remoteFile);
      if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return new WebDavBackupPlainResult(
          WebDavSyncResult.fail('下载失败', `GET ${getRes.statusCode}: ${getRes.body}`),
          ''
        );
      }

      let plain: string;
      try {
        plain = WebDavCrypto.decryptUtf8(getRes.body, this.settings.syncPassword);
      } catch (ce) {
        const msg = ce instanceof CryptoError ? ce.message : String(ce);
        this.status = WebDavSyncStatus.ERROR;
        return new WebDavBackupPlainResult(WebDavSyncResult.fail('解密失败', msg), '');
      }

      this.status = WebDavSyncStatus.IDLE;
      return new WebDavBackupPlainResult(WebDavSyncResult.ok('已下载云端备份'), plain);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return new WebDavBackupPlainResult(WebDavSyncResult.fail('下载失败', msg), '');
    }
  }

  async importPlainBackup(plain: string): Promise<WebDavSyncResult> {
    if (plain.length === 0) return WebDavSyncResult.fail('导入失败', '备份内容为空');

    this.status = WebDavSyncStatus.RESTORING;
    try {
      const importRes = await this.syncManager.importData(plain);
      if (importRes.hasErrors()) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('导入失败', importRes.errors.join('; '));
      }
      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`恢复完成：导入 ${importRes.imported}，更新 ${importRes.updated}`);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('导入失败', msg);
    }
  }

  async restoreFromCloud(force: boolean = false): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.RESTORING;
    try {
      const client = this.createClient();
      const remoteFile = this.rootPath('data', 'backup.json.enc');

      // Conflict check: if not forced, only restore when remote is newer than local upload record
      if (!force) {
        const propRes = await client.propfind(remoteFile, '0');
        if (propRes.statusCode >= 400 || propRes.statusCode === 0) {
          this.status = WebDavSyncStatus.ERROR;
          return WebDavSyncResult.fail('获取云端备份信息失败', `PROPFIND ${propRes.statusCode}: ${propRes.body}`);
        }
        const meta = parsePropfindMeta(propRes.body);
        const remoteMs = parseHttpDateMillis(meta.lastModified);
        if (remoteMs > 0 && remoteMs <= this.manifest.lastBackupUploadMs) {
          this.status = WebDavSyncStatus.IDLE;
          return WebDavSyncResult.ok('云端备份未更新，无需恢复');
        }
      }

      // Snapshot local data before import
      const snapshot = await this.syncManager.exportData();
      if (snapshot.success) {
        AppStorage.setOrCreate(this.SNAPSHOT_KEY, snapshot.data);
      }

      const getRes = await client.get(remoteFile);
      if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('下载失败', `GET ${getRes.statusCode}: ${getRes.body}`);
      }

      let plain: string;
      try {
        plain = WebDavCrypto.decryptUtf8(getRes.body, this.settings.syncPassword);
      } catch (ce) {
        const msg = ce instanceof CryptoError ? ce.message : String(ce);
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('解密失败', msg);
      }

      const importRes = await this.syncManager.importData(plain);
      if (importRes.hasErrors()) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('导入失败', importRes.errors.join('; '));
      }

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`恢复完成：导入 ${importRes.imported}，更新 ${importRes.updated}`);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('恢复失败', msg);
    }
  }

  getLastSnapshot(): string {
    return AppStorage.get<string>(this.SNAPSHOT_KEY) ?? '';
  }

  // ==================== Review Events Sync ====================

  private buildEventsRemoteDir(): string {
    return this.rootPath('events', this.manifest.deviceId);
  }

  private buildEventsFileName(count: number): string {
    const ts = Date.now();
    return `events_${this.manifest.deviceId}_${ts}_${count}.jsonl.enc`;
  }

  private serializeEventsJsonl(events: ReviewEventRow[]): string {
    // JSON Lines for append-friendly uploads
    let out = '';
    for (const e of events) {
      const obj: ReviewEventJSON = {
        id: e.id,
        wordId: e.wordId,
        rating: e.rating,
        timestamp: e.timestamp,
        prevStateJson: e.prevStateJson,
        newStateJson: e.newStateJson,
        errorTag: e.errorTag,
        reflection: e.reflection
      };
      out += `${JSON.stringify(obj)}\n`;
    }
    return out;
  }

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
          reflection: (obj['reflection'] as string) ?? ''
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

  async uploadLocalReviewEvents(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const dir = this.buildEventsRemoteDir();
      await this.ensureCollection(client, dir);

      const events = await this.db.getReviewEventsAfter(this.manifest.lastEventsSyncMs);
      if (events.length === 0) {
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.ok('没有新的复习记录需要上传');
      }

      const jsonl = this.serializeEventsJsonl(events);
      const enc = WebDavCrypto.encryptUtf8(jsonl, this.settings.syncPassword);
      const filePath = `${dir}/${this.buildEventsFileName(events.length)}`;
      const putRes = await client.put(filePath, enc, 'application/json');
      if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('上传复习记录失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
      }

      // Advance sync cursor to last event timestamp
      let maxTs = this.manifest.lastEventsSyncMs;
      for (const e of events) {
        if (e.timestamp > maxTs) maxTs = e.timestamp;
      }
      this.manifest.lastEventsSyncMs = maxTs;
      this.persist();

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`已上传 ${events.length} 条复习记录`);
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
      const eventsRoot = this.rootPath('events');
      await this.ensureCollection(client, eventsRoot);

      const listRes = await client.propfind(eventsRoot, 'infinity');
      if (listRes.statusCode < 200 || listRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('列出云端复习记录失败', `PROPFIND ${listRes.statusCode}: ${listRes.body}`);
      }

      const resources = parsePropfindList(listRes.body);
      // Filter .jsonl.enc files
      const fileMetas: WebDavResourceMeta[] = [];
      for (const r of resources) {
        if (r.href.endsWith('.jsonl.enc')) {
          fileMetas.push(r);
        }
      }

      let importedCount = 0;
      let newFiles = 0;
      for (const meta of fileMetas) {
        const href = meta.href;
        if (this.manifest.consumedEventHrefs.includes(href)) {
          continue;
        }
        // WebDAV href may be absolute path; try to use it directly if startsWith('/'), else prefix with endpoint.
        const getRes = await client.get(href);
        if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
          continue;
        }
        let plain = '';
        try {
          plain = WebDavCrypto.decryptUtf8(getRes.body, this.settings.syncPassword);
        } catch (ce) {
          continue;
        }
        const events = this.parseEventsJsonl(plain);
        const inserted = await this.db.insertReviewEvents(events);
        importedCount += inserted;
        this.manifest.consumedEventHrefs.push(href);
        newFiles++;
      }

      // Keep manifest list bounded
      if (this.manifest.consumedEventHrefs.length > 1000) {
        this.manifest.consumedEventHrefs = this.manifest.consumedEventHrefs.slice(-800);
      }

      this.persist();
      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`拉取完成：新文件 ${newFiles}，导入事件 ${importedCount}`);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('拉取复习记录失败', msg);
    }
  }

  // ==================== Model Sync / Evolution ====================

  async uploadLocalModel(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const model = EvolveModelStore.getLocalModel();
      if (model === null) {
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.ok('本地暂无可上传的模型');
      }

      const client = this.createClient();
      const modelDir = this.rootPath('model');
      await this.ensureCollection(client, modelDir);

      const json = JSON.stringify(model);
      const enc = WebDavCrypto.encryptUtf8(json, this.settings.syncPassword);
      const filePath = this.rootPath('model', 'policy.json.enc');
      const putRes = await client.put(filePath, enc, 'application/json');
      if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('上传模型失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
      }

      // Refresh ETag for cache/consistency
      const propRes = await client.propfind(filePath, '0');
      if (propRes.statusCode >= 200 && propRes.statusCode < 300) {
        const meta = parsePropfindMeta(propRes.body);
        if (meta.etag.length > 0) {
          this.manifest.lastModelEtag = meta.etag;
        }
      }
      this.manifest.lastModelVersion = model.version;
      this.persist();

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok('模型已上传');
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('上传模型失败', msg);
    }
  }

  async downloadModelIfNewer(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      const filePath = this.rootPath('model', 'policy.json.enc');
      const propRes = await client.propfind(filePath, '0');
      if (propRes.statusCode < 200 || propRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.ok('云端暂无模型');
      }

      const meta = parsePropfindMeta(propRes.body);
      const etag = meta.etag;
      // ETag-only cache: if unchanged, skip.
      if (etag.length > 0 && etag === this.manifest.lastModelEtag) {
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.ok('模型未更新');
      }

      const getRes = await client.get(filePath);
      if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('下载模型失败', `GET ${getRes.statusCode}: ${getRes.body}`);
      }

      let plain = '';
      try {
        plain = WebDavCrypto.decryptUtf8(getRes.body, this.settings.syncPassword);
      } catch (ce) {
        const msg = ce instanceof CryptoError ? ce.message : String(ce);
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('解密模型失败', msg);
      }

      const model = JSON.parse(plain) as EvolveModelPackage;
      if (model.version <= this.manifest.lastModelVersion) {
        this.status = WebDavSyncStatus.IDLE;
        if (etag.length > 0) {
          this.manifest.lastModelEtag = etag;
          this.persist();
        }
        return WebDavSyncResult.ok('模型版本未提升');
      }

      EvolveModelStore.saveLocalModel(model);
      this.manifest.lastModelVersion = model.version;
      if (etag.length > 0) {
        this.manifest.lastModelEtag = etag;
      }
      this.persist();

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`已应用云端模型 v${model.version}`);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('下载模型失败', msg);
    }
  }

  // ==================== Offline Template Pack ====================

  private templatePackFilePath(): string {
    return this.rootPath(WebDavSyncManager.TEMPLATE_PACK_REMOTE_PATH);
  }

  /**
   * Download an optional offline template pack from WebDAV.
   * The pack file is encrypted with syncPassword.
   */
  async downloadTemplatePack(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      await this.ensureCollection(client, this.rootPath('templates'));

      // Check ETag before downloading (best-effort).
      const metaRes = await client.propfind(this.templatePackFilePath(), '0');
      if (metaRes.statusCode >= 200 && metaRes.statusCode < 300) {
        const meta = parsePropfindMeta(metaRes.body);
        const etag = safeTrim(meta.etag);
        if (etag.length > 0 && etag === this.manifest.lastTemplatePackEtag) {
          this.status = WebDavSyncStatus.IDLE;
          return WebDavSyncResult.ok('离线模板包已是最新');
        }
      }

      const res = await client.get(this.templatePackFilePath());
      if (res.statusCode === 404) {
        this.status = WebDavSyncStatus.IDLE;
        return WebDavSyncResult.fail('云端不存在离线模板包', 'HTTP 404');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('下载离线模板包失败', `HTTP ${res.statusCode}: ${res.body}`);
      }

      const plain = WebDavCrypto.decryptUtf8(res.body, this.settings.syncPassword);
      const tm = TemplateManager.getInstance();
      const added = tm.applyExternalTemplatePack(plain, true);

      const etagHeader = safeTrim(res.headers['etag'] ?? '');
      if (etagHeader.length > 0) {
        this.manifest.lastTemplatePackEtag = etagHeader;
      }
      this.manifest.lastTemplatePackDownloadMs = Date.now();
      this.persist();

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`已下载离线模板包：新增 ${added} 条模板`);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('下载离线模板包失败', msg);
    }
  }

  /**
   * Upload the current persisted offline template pack to WebDAV.
   * Useful for moving template packs across devices without a server.
   */
  async uploadTemplatePack(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    const tm = TemplateManager.getInstance();
    const packJson = tm.getPersistedExternalPackJson();
    if (packJson.trim().length === 0) {
      return WebDavSyncResult.fail('没有可上传的离线模板包', 'no_template_pack');
    }

    this.status = WebDavSyncStatus.SYNCING;
    try {
      const client = this.createClient();
      await this.ensureCollection(client, this.rootPath('templates'));

      const encrypted = WebDavCrypto.encryptUtf8(packJson, this.settings.syncPassword);
      const putRes = await client.put(this.templatePackFilePath(), encrypted, 'application/json');

      if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
        this.status = WebDavSyncStatus.ERROR;
        return WebDavSyncResult.fail('上传离线模板包失败', `HTTP ${putRes.statusCode}: ${putRes.body}`);
      }

      const etag = safeTrim(putRes.headers['etag'] ?? '');
      if (etag.length > 0) {
        this.manifest.lastTemplatePackEtag = etag;
      }
      this.manifest.lastTemplatePackDownloadMs = Date.now();
      this.persist();

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok('已上传离线模板包');
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('上传离线模板包失败', msg);
    }
  }

  async evolveNow(): Promise<WebDavSyncResult> {
    const missing = this.requireConfigured();
    if (missing !== null) return missing;

    this.status = WebDavSyncStatus.EVOLVING;
    try {
      // 1) pull remote events into local DB
      const pullRes = await this.downloadAndMergeRemoteEvents();
      if (!pullRes.success) {
        this.status = WebDavSyncStatus.ERROR;
        return pullRes;
      }

      // 2) train policy from local history
      const model = await this.optimizer.trainFromLocalHistory();
      EvolveModelStore.saveLocalModel(model);
      this.manifest.lastModelVersion = model.version;
      this.persist();

      // 3) upload the new model
      const upRes = await this.uploadLocalModel();
      if (!upRes.success) {
        this.status = WebDavSyncStatus.ERROR;
        return upRes;
      }

      this.status = WebDavSyncStatus.IDLE;
      return WebDavSyncResult.ok(`进化完成：模型 v${model.version}`);
    } catch (e) {
      this.status = WebDavSyncStatus.ERROR;
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('进化失败', msg);
    }
  }
}
