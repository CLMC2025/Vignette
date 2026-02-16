import { buildUserFacingError, ErrorInfo } from '../../utils/ErrorClassifier';

export enum WebDavSyncStatus {
  IDLE = 'IDLE',
  TESTING = 'TESTING',
  SYNCING = 'SYNCING',
  RESTORING = 'RESTORING',
  ERROR = 'ERROR'
}

export interface WebDavSettingsJSON {
  endpoint: string;
  username: string;
  password: string;
  syncPassword: string;
  remoteRoot: string;
  requireRemoteRootExists?: boolean;
}

// JSON interfaces for type-safe serialization
export interface WebDavManifestJSON {
  deviceId: string;
  lastBackupUploadMs: number;
  lastBackupEtag: string;
  lastEventsSyncMs: number;
  consumedEventHrefs: string[];
  eventsAllEtag?: string;
  lastModelVersion: number;
  lastModelEtag: string;
  lastTemplatePackDownloadMs: number;
  lastTemplatePackEtag: string;
  lastWordsSyncMs?: number;
  wordsDeltaEtag?: string;
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
  scheduledDays?: number;
}

export class WebDavSettings {
  endpoint: string;
  username: string;
  password: string;
  syncPassword: string;
  remoteRoot: string;
  requireRemoteRootExists: boolean;

  constructor(
    endpoint: string = '',
    username: string = '',
    password: string = '',
    syncPassword: string = '',
    remoteRoot: string = '/weiyu_vignette',
    requireRemoteRootExists: boolean = false
  ) {
    this.endpoint = endpoint;
    this.username = username;
    this.password = password;
    this.syncPassword = syncPassword;
    this.remoteRoot = remoteRoot;
    this.requireRemoteRootExists = requireRemoteRootExists;
  }

  toJSON(): string {
    const obj: WebDavSettingsJSON = {
      endpoint: this.endpoint,
      username: this.username,
      password: this.password,
      syncPassword: this.syncPassword,
      remoteRoot: this.remoteRoot,
      requireRemoteRootExists: this.requireRemoteRootExists
    };
    return JSON.stringify(obj);
  }

  static fromJSON(json: string): WebDavSettings {
    try {
      const obj: WebDavSettingsJSON = JSON.parse(json);
      return new WebDavSettings(
        obj.endpoint ?? '',
        obj.username ?? '',
        obj.password ?? '',
        obj.syncPassword ?? '',
        obj.remoteRoot ?? '/weiyu_vignette',
        obj.requireRemoteRootExists ?? false
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
  eventsAllEtag: string;
  lastModelVersion: number;
  lastModelEtag: string;
  lastTemplatePackDownloadMs: number;
  lastTemplatePackEtag: string;
  lastWordsSyncMs: number;
  wordsDeltaEtag: string;

  constructor(
    deviceId: string,
    lastBackupUploadMs: number = 0,
    lastBackupEtag: string = '',
    lastEventsSyncMs: number = 0,
    consumedEventHrefs: string[] = [],
    eventsAllEtag: string = '',
    lastModelVersion: number = 0,
    lastModelEtag: string = '',
    lastTemplatePackDownloadMs: number = 0,
    lastTemplatePackEtag: string = '',
    lastWordsSyncMs: number = 0,
    wordsDeltaEtag: string = ''
  ) {
    this.deviceId = deviceId;
    this.lastBackupUploadMs = lastBackupUploadMs;
    this.lastBackupEtag = lastBackupEtag;
    this.lastEventsSyncMs = lastEventsSyncMs;
    this.consumedEventHrefs = consumedEventHrefs;
    this.eventsAllEtag = eventsAllEtag;
    this.lastModelVersion = lastModelVersion;
    this.lastModelEtag = lastModelEtag;
    this.lastTemplatePackDownloadMs = lastTemplatePackDownloadMs;
    this.lastTemplatePackEtag = lastTemplatePackEtag;
    this.lastWordsSyncMs = lastWordsSyncMs;
    this.wordsDeltaEtag = wordsDeltaEtag;
  }

  toJSON(): string {
    const obj: WebDavManifestJSON = {
      deviceId: this.deviceId,
      lastBackupUploadMs: this.lastBackupUploadMs,
      lastBackupEtag: this.lastBackupEtag,
      lastEventsSyncMs: this.lastEventsSyncMs,
      consumedEventHrefs: this.consumedEventHrefs,
      eventsAllEtag: this.eventsAllEtag,
      lastModelVersion: this.lastModelVersion,
      lastModelEtag: this.lastModelEtag,
      lastTemplatePackDownloadMs: this.lastTemplatePackDownloadMs,
      lastTemplatePackEtag: this.lastTemplatePackEtag,
      lastWordsSyncMs: this.lastWordsSyncMs,
      wordsDeltaEtag: this.wordsDeltaEtag
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
        obj.eventsAllEtag ?? '',
        obj.lastModelVersion ?? 0,
        obj.lastModelEtag ?? '',
        obj.lastTemplatePackDownloadMs ?? 0,
        obj.lastTemplatePackEtag ?? '',
        obj.lastWordsSyncMs ?? 0,
        obj.wordsDeltaEtag ?? ''
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

export class WebDavBackupPlainResult {
  result: WebDavSyncResult;
  plain: string;

  constructor(result: WebDavSyncResult, plain: string) {
    this.result = result;
    this.plain = plain;
  }
}

export function safeTrim(s: string): string {
  return s.trim();
}

export function normalizeRoot(root: string): string {
  let r = root.trim();
  if (r.length === 0) {
    r = '/weiyu_vignette';
  }
  if (!r.startsWith('/')) {
    r = `/${r}`;
  }
  // remove trailing slash, but preserve root '/'
  if (r !== '/') {
    r = r.replace(/\/+$/g, '');
    if (r.length === 0) {
      r = '/';
    }
  }
  return r;
}

export function parseHttpDateMillis(s: string): number {
  const t = Date.parse(s);
  if (Number.isNaN(t)) return 0;
  return t;
}

export function generateDeviceId(): string {
  const rand = Math.random().toString(36).substring(2, 10);
  return `dev_${Date.now()}_${rand}`;
}

export const BACKUP_FILE_NAME: string = 'backup.json.enc';
export const EVENTS_FILE_NAME: string = 'events_all.jsonl.enc';
export const MODEL_FILE_NAME: string = 'policy.json.enc';
export const TEMPLATE_PACK_FILE_NAME: string = 'template_pack.json.enc';
export const WORDS_DELTA_FILE_NAME: string = 'words_delta.json.enc';
export const DEFINITIONS_FILE_NAME: string = 'definitions.json.enc';
