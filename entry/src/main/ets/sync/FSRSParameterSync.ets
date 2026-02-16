/**
 * FSRSParameterSync.ets - Cloud Sync for FSRS Parameters
 * Handles synchronization of optimized parameters with cloud storage
 */

import { FSRSParameterStore, DifficultyParameters } from '../algorithm/FSRSOptimizer';
import { WebDavClient } from './webdav/WebDavClient';
import { WebDavStateStore } from '../utils/WebDavStateStore';
import { WebDavSettings } from './webdav/WebDavCommon';

export interface FSRSParameterSyncResult {
  success: boolean;
  action: 'upload' | 'download' | 'none' | 'conflict';
  message: string;
  localTimestamp?: number;
  remoteTimestamp?: number;
}

export interface FSRSParameterSyncConfig {
  enabled: boolean;
  autoSync: boolean;
  conflictStrategy: 'local' | 'remote' | 'newer';
}

interface RemoteFileInfo {
  exists: boolean;
  lastModified?: number;
  content?: string;
}

interface RemoteData {
  timestamp?: number;
  globalParams?: number[];
  difficultyParams?: DifficultyParameters;
  autoState?: AutoOptimizeState;
}

interface AutoOptimizeState {
  lastReviewCount: number;
  lastOptimizeTime: number;
  totalReviewsSinceOptimize: number;
  shouldPrompt: boolean;
}

const FSRS_PARAMS_FILE = 'fsrs_params.json';

function createDefaultSyncConfig(): FSRSParameterSyncConfig {
  return {
    enabled: true,
    autoSync: true,
    conflictStrategy: 'newer'
  };
}

function copySyncConfig(src: FSRSParameterSyncConfig): FSRSParameterSyncConfig {
  return {
    enabled: src.enabled,
    autoSync: src.autoSync,
    conflictStrategy: src.conflictStrategy
  };
}

function mergeSyncConfig(base: FSRSParameterSyncConfig, partial: Partial<FSRSParameterSyncConfig>): FSRSParameterSyncConfig {
  return {
    enabled: partial.enabled !== undefined ? partial.enabled : base.enabled,
    autoSync: partial.autoSync !== undefined ? partial.autoSync : base.autoSync,
    conflictStrategy: partial.conflictStrategy !== undefined ? partial.conflictStrategy : base.conflictStrategy
  };
}

export class FSRSParameterSync {
  private static instance: FSRSParameterSync | null = null;
  private config: FSRSParameterSyncConfig;
  private paramStore: FSRSParameterStore;
  private lastSyncTime: number = 0;
  private store: WebDavStateStore;
  private settings: WebDavSettings | null = null;

  private constructor() {
    this.config = createDefaultSyncConfig();
    this.paramStore = FSRSParameterStore.getInstance();
    this.store = WebDavStateStore.getInstance();
  }

  static getInstance(): FSRSParameterSync {
    if (FSRSParameterSync.instance === null) {
      FSRSParameterSync.instance = new FSRSParameterSync();
    }
    return FSRSParameterSync.instance;
  }

  getConfig(): FSRSParameterSyncConfig {
    return copySyncConfig(this.config);
  }

  setConfig(config: Partial<FSRSParameterSyncConfig>): void {
    this.config = mergeSyncConfig(this.config, config);
  }

  getLastSyncTime(): number {
    return this.lastSyncTime;
  }

  setWebDavSettings(settings: WebDavSettings): void {
    this.settings = settings;
  }

  private createClient(): WebDavClient | null {
    if (this.settings === null) {
      return null;
    }
    return new WebDavClient(
      this.settings.endpoint,
      this.settings.username,
      this.settings.password
    );
  }

  private buildPath(fileName: string): string {
    if (this.settings === null) {
      return '/' + fileName;
    }
    const root = this.settings.remoteRoot.replace(/\/+$/g, '').replace(/^\/+/g, '');
    if (root.length === 0) {
      return '/' + fileName;
    }
    return '/' + root + '/' + fileName;
  }

  private async getRemoteFileInfo(client: WebDavClient, path: string): Promise<RemoteFileInfo> {
    const headRes = await client.head(path);
    if (headRes.statusCode >= 200 && headRes.statusCode < 400) {
      const lastModifiedStr = headRes.headers['last-modified'] ?? headRes.headers['date'] ?? '';
      let lastModified = 0;
      if (lastModifiedStr.length > 0) {
        lastModified = Date.parse(lastModifiedStr);
        if (isNaN(lastModified)) {
          lastModified = 0;
        }
      }
      const info: RemoteFileInfo = {
        exists: true,
        lastModified: lastModified
      };
      return info;
    }
    
    if (headRes.statusCode === 404) {
      const info: RemoteFileInfo = { exists: false };
      return info;
    }

    const getRes = await client.get(path);
    if (getRes.statusCode >= 200 && getRes.statusCode < 300) {
      const info: RemoteFileInfo = {
        exists: true,
        content: getRes.body
      };
      return info;
    }

    const info: RemoteFileInfo = { exists: false };
    return info;
  }

  async uploadParameters(): Promise<FSRSParameterSyncResult> {
    if (!this.config.enabled) {
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: '参数同步已禁用'
      };
      return result;
    }

    const client = this.createClient();
    if (client === null) {
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: 'WebDAV 未配置'
      };
      return result;
    }

    try {
      const paramsJson = this.paramStore.exportToJSON();
      const path = this.buildPath(FSRS_PARAMS_FILE);
      
      const uploadRes = await client.put(path, paramsJson, 'application/json');

      if (uploadRes.statusCode >= 200 && uploadRes.statusCode < 300) {
        this.lastSyncTime = Date.now();
        const result: FSRSParameterSyncResult = {
          success: true,
          action: 'upload',
          message: '参数已上传到云端',
          localTimestamp: this.paramStore.getTimestamp()
        };
        return result;
      } else {
        const result: FSRSParameterSyncResult = {
          success: false,
          action: 'upload',
          message: `上传失败: HTTP ${uploadRes.statusCode}`
        };
        return result;
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'upload',
        message: `上传失败: ${errMsg}`
      };
      return result;
    }
  }

  async downloadParameters(): Promise<FSRSParameterSyncResult> {
    if (!this.config.enabled) {
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: '参数同步已禁用'
      };
      return result;
    }

    const client = this.createClient();
    if (client === null) {
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: 'WebDAV 未配置'
      };
      return result;
    }

    try {
      const path = this.buildPath(FSRS_PARAMS_FILE);
      const downloadRes = await client.get(path);

      if (downloadRes.statusCode >= 200 && downloadRes.statusCode < 300 && downloadRes.body.length > 0) {
        const importSuccess = this.paramStore.importFromJSON(downloadRes.body);
        
        if (importSuccess) {
          this.lastSyncTime = Date.now();
          const result: FSRSParameterSyncResult = {
            success: true,
            action: 'download',
            message: '参数已从云端下载',
            remoteTimestamp: this.paramStore.getTimestamp()
          };
          return result;
        } else {
          const result: FSRSParameterSyncResult = {
            success: false,
            action: 'download',
            message: '参数格式无效'
          };
          return result;
        }
      } else if (downloadRes.statusCode === 404) {
        const result: FSRSParameterSyncResult = {
          success: false,
          action: 'download',
          message: '云端暂无参数文件'
        };
        return result;
      } else {
        const result: FSRSParameterSyncResult = {
          success: false,
          action: 'download',
          message: `下载失败: HTTP ${downloadRes.statusCode}`
        };
        return result;
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'download',
        message: `下载失败: ${errMsg}`
      };
      return result;
    }
  }

  async syncParameters(): Promise<FSRSParameterSyncResult> {
    if (!this.config.enabled) {
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: '参数同步已禁用'
      };
      return result;
    }

    const client = this.createClient();
    if (client === null) {
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: 'WebDAV 未配置'
      };
      return result;
    }

    try {
      const localTimestamp = this.paramStore.getTimestamp();
      const localParams = this.paramStore.loadParameters();
      const path = this.buildPath(FSRS_PARAMS_FILE);
      
      const remoteInfo = await this.getRemoteFileInfo(client, path);
      
      if (!remoteInfo.exists) {
        if (localParams !== null) {
          return await this.uploadParameters();
        }
        const result: FSRSParameterSyncResult = {
          success: true,
          action: 'none',
          message: '本地和云端都无参数'
        };
        return result;
      }

      let remoteContent = remoteInfo.content;
      if (remoteContent === undefined) {
        const downloadRes = await client.get(path);
        if (downloadRes.statusCode >= 200 && downloadRes.statusCode < 300) {
          remoteContent = downloadRes.body;
        } else {
          const result: FSRSParameterSyncResult = {
            success: false,
            action: 'download',
            message: '无法获取云端参数'
          };
          return result;
        }
      }

      const parsed: object = JSON.parse(remoteContent as string);
      const remoteData = parsed as RemoteData;
      const remoteParamsTimestamp = remoteData.timestamp ?? 0;

      if (localParams === null) {
        this.paramStore.importFromJSON(remoteContent as string);
        this.lastSyncTime = Date.now();
        const result: FSRSParameterSyncResult = {
          success: true,
          action: 'download',
          message: '已从云端下载参数（本地无参数）',
          remoteTimestamp: remoteParamsTimestamp
        };
        return result;
      }

      if (localTimestamp === remoteParamsTimestamp) {
        this.lastSyncTime = Date.now();
        const result: FSRSParameterSyncResult = {
          success: true,
          action: 'none',
          message: '本地和云端参数已同步',
          localTimestamp: localTimestamp,
          remoteTimestamp: remoteParamsTimestamp
        };
        return result;
      }

      switch (this.config.conflictStrategy) {
        case 'local':
          return await this.uploadParameters();
          
        case 'remote':
          this.paramStore.importFromJSON(remoteContent as string);
          this.lastSyncTime = Date.now();
          const remoteResult: FSRSParameterSyncResult = {
            success: true,
            action: 'download',
            message: '已使用云端参数（冲突策略：远程优先）',
            remoteTimestamp: remoteParamsTimestamp
          };
          return remoteResult;
          
        case 'newer':
        default:
          if (localTimestamp > remoteParamsTimestamp) {
            return await this.uploadParameters();
          } else {
            this.paramStore.importFromJSON(remoteContent as string);
            this.lastSyncTime = Date.now();
            const newerResult: FSRSParameterSyncResult = {
              success: true,
              action: 'download',
              message: '已使用较新的云端参数',
              localTimestamp: localTimestamp,
              remoteTimestamp: remoteParamsTimestamp
            };
            return newerResult;
          }
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      const result: FSRSParameterSyncResult = {
        success: false,
        action: 'none',
        message: `同步失败: ${errMsg}`
      };
      return result;
    }
  }

  checkAutoSyncNeeded(currentReviewCount: number, lastSyncReviewCount: number): boolean {
    if (!this.config.enabled || !this.config.autoSync) {
      return false;
    }
    const syncInterval = 100;
    return currentReviewCount - lastSyncReviewCount >= syncInterval;
  }

  async mergeParameters(
    localParams: DifficultyParameters,
    remoteParams: DifficultyParameters
  ): Promise<DifficultyParameters> {
    const merged: DifficultyParameters = {
      global: this.copyArray(localParams.global),
      cet4: this.copyArray(localParams.cet4),
      cet6: this.copyArray(localParams.cet6),
      kaoyan: this.copyArray(localParams.kaoyan),
      custom: this.copyArray(localParams.custom)
    };

    if (remoteParams.global && remoteParams.global.length === 21) {
      merged.global = this.averageArrays(localParams.global, remoteParams.global);
    }
    if (remoteParams.cet4 && remoteParams.cet4.length === 21) {
      merged.cet4 = this.averageArrays(localParams.cet4, remoteParams.cet4);
    }
    if (remoteParams.cet6 && remoteParams.cet6.length === 21) {
      merged.cet6 = this.averageArrays(localParams.cet6, remoteParams.cet6);
    }
    if (remoteParams.kaoyan && remoteParams.kaoyan.length === 21) {
      merged.kaoyan = this.averageArrays(localParams.kaoyan, remoteParams.kaoyan);
    }
    if (remoteParams.custom && remoteParams.custom.length === 21) {
      merged.custom = this.averageArrays(localParams.custom, remoteParams.custom);
    }

    return merged;
  }

  private copyArray(arr: number[]): number[] {
    const result: number[] = [];
    for (let i = 0; i < arr.length; i++) {
      result.push(arr[i]);
    }
    return result;
  }

  private averageArrays(a: number[], b: number[]): number[] {
    const result: number[] = [];
    const len = a.length < b.length ? a.length : b.length;
    for (let i = 0; i < len; i++) {
      result.push((a[i] + b[i]) / 2);
    }
    return result;
  }
}
