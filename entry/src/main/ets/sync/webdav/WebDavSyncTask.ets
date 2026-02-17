// =====================================================
// WebDavSyncTask.ets - TaskPool 任务函数
// 将网络操作移到后台线程执行
// =====================================================

import taskpool from '@ohos.taskpool';
import { WebDavClient } from './WebDavClient';
import {
  WebDavManifest,
  safeTrim,
  normalizeRoot,
  generateDeviceId,
  EVENTS_FILE_NAME,
  WORDS_DELTA_FILE_NAME
} from './WebDavCommon';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';

// 同步任务参数接口
export interface SyncTaskParams {
  endpoint: string;
  username: string;
  password: string;
  syncPassword: string;
  remoteRoot: string;
  manifestJson: string;
}

// 同步任务结果
export interface SyncTaskResult {
  success: boolean;
  message: string;
  detail: string;
  step: string;
}

// 备份任务参数
export interface BackupTaskParams extends SyncTaskParams {
  backupFilePath: string;
  backupData: string; // 已经加密的数据
}

// 备份任务结果
export interface BackupTaskResult {
  success: boolean;
  message: string;
  detail: string;
}

// 下载任务参数
export interface DownloadTaskParams extends SyncTaskParams {
  remoteFile: string;
}

// 下载任务结果
export interface DownloadTaskResult {
  success: boolean;
  data: string; // 解密后的数据
  detail: string;
}

// 上传任务参数
export interface UploadTaskParams extends SyncTaskParams {
  remoteFile: string;
  data: string; // 要上传的加密数据
}

// 上传任务结果
export interface UploadTaskResult {
  success: boolean;
  detail: string;
}

// ==================== TaskPool 任务函数 ====================

/**
 * 执行备份上传任务（在 TaskPool 中运行）
 */
@Concurrent
export async function executeBackupUpload(params: BackupTaskParams): Promise<BackupTaskResult> {
  console.info('[WebDavSyncTask] Starting backup upload in taskpool');

  try {
    // 创建 WebDAV 客户端
    const client = new WebDavClient(params.endpoint, params.username, params.password);

    // 上传数据
    console.info('[WebDavSyncTask] Uploading data');
    const putRes = await client.put(params.backupFilePath, params.backupData, 'application/json');
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      const result: BackupTaskResult = {
        success: false,
        message: '上传失败',
        detail: `PUT ${putRes.statusCode}: ${putRes.body}`
      };
      return result;
    }

    console.info('[WebDavSyncTask] Backup upload completed successfully');

    const successResult: BackupTaskResult = {
      success: true,
      message: '备份已上传',
      detail: ''
    };
    return successResult;

  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[WebDavSyncTask] Backup upload failed:', msg);
    const errorResult: BackupTaskResult = {
      success: false,
      message: '备份失败',
      detail: msg
    };
    return errorResult;
  }
}

/**
 * 执行下载任务（在 TaskPool 中运行）
 */
@Concurrent
export async function executeDownload(params: DownloadTaskParams): Promise<DownloadTaskResult> {
  console.info('[WebDavSyncTask] Starting download in taskpool');

  try {
    // 创建 WebDAV 客户端
    const client = new WebDavClient(params.endpoint, params.username, params.password);

    // 下载数据
    const getRes = await client.get(params.remoteFile);
    if (getRes.statusCode === 404) {
      const result: DownloadTaskResult = { success: true, data: '', detail: '文件不存在' };
      return result;
    }
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      const result: DownloadTaskResult = { success: false, data: '', detail: `GET ${getRes.statusCode}: ${getRes.body}` };
      return result;
    }

    // 解密数据
    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Async(getRes.body, params.syncPassword);
    } catch (ce) {
      const errorMsg = ce instanceof CryptoError ? ce.message : String(ce);
      let userFriendlyMsg = errorMsg;
      if (errorMsg.includes('MAC verification failed')) {
        userFriendlyMsg = '同步密码错误或云端数据已损坏。建议：1)检查同步密码是否正确；2)点击"立即同步"重新上传本地数据覆盖云端';
      }
      const result: DownloadTaskResult = { success: false, data: '', detail: userFriendlyMsg };
      return result;
    }

    const successResult: DownloadTaskResult = { success: true, data: plain, detail: '' };
    return successResult;

  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[WebDavSyncTask] Download failed:', msg);
    const errorResult: DownloadTaskResult = { success: false, data: '', detail: msg };
    return errorResult;
  }
}

/**
 * 执行上传任务（在 TaskPool 中运行）
 */
@Concurrent
export async function executeUpload(params: UploadTaskParams): Promise<UploadTaskResult> {
  console.info('[WebDavSyncTask] Starting upload in taskpool');

  try {
    // 创建 WebDAV 客户端
    const client = new WebDavClient(params.endpoint, params.username, params.password);

    // 上传数据
    const putRes = await client.put(params.remoteFile, params.data, 'application/json');
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      const result: UploadTaskResult = { success: false, detail: `PUT ${putRes.statusCode}: ${putRes.body}` };
      return result;
    }

    const successResult: UploadTaskResult = { success: true, detail: '' };
    return successResult;

  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[WebDavSyncTask] Upload failed:', msg);
    const errorResult: UploadTaskResult = { success: false, detail: msg };
    return errorResult;
  }
}

/**
 * 执行事件下载任务（在 TaskPool 中运行）
 */
@Concurrent
export async function executeEventsDownload(params: DownloadTaskParams): Promise<DownloadTaskResult> {
  console.info('[WebDavSyncTask] Starting events download in taskpool');
  // 直接复制 executeDownload 的实现，避免调用其他函数
  try {
    const client = new WebDavClient(params.endpoint, params.username, params.password);
    const getRes = await client.get(params.remoteFile);
    if (getRes.statusCode === 404) {
      const result: DownloadTaskResult = { success: true, data: '', detail: '文件不存在' };
      return result;
    }
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      const result: DownloadTaskResult = { success: false, data: '', detail: `GET ${getRes.statusCode}: ${getRes.body}` };
      return result;
    }
    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Async(getRes.body, params.syncPassword);
    } catch (ce) {
      const errorMsg = ce instanceof CryptoError ? ce.message : String(ce);
      let userFriendlyMsg = errorMsg;
      if (errorMsg.includes('MAC verification failed')) {
        userFriendlyMsg = '同步密码错误或云端数据已损坏。建议：1)检查同步密码是否正确；2)点击"立即同步"重新上传本地数据覆盖云端';
      }
      const result: DownloadTaskResult = { success: false, data: '', detail: userFriendlyMsg };
      return result;
    }
    const successResult: DownloadTaskResult = { success: true, data: plain, detail: '' };
    return successResult;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[WebDavSyncTask] Download failed:', msg);
    const errorResult: DownloadTaskResult = { success: false, data: '', detail: msg };
    return errorResult;
  }
}

/**
 * 执行事件上传任务（在 TaskPool 中运行）
 */
@Concurrent
export async function executeEventsUpload(params: UploadTaskParams): Promise<UploadTaskResult> {
  console.info('[WebDavSyncTask] Starting events upload in taskpool');
  // 直接复制 executeUpload 的实现，避免调用其他函数
  try {
    const client = new WebDavClient(params.endpoint, params.username, params.password);
    const putRes = await client.put(params.remoteFile, params.data, 'application/json');
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      const result: UploadTaskResult = { success: false, detail: `PUT ${putRes.statusCode}: ${putRes.body}` };
      return result;
    }
    const successResult: UploadTaskResult = { success: true, detail: '' };
    return successResult;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[WebDavSyncTask] Upload failed:', msg);
    const errorResult: UploadTaskResult = { success: false, detail: msg };
    return errorResult;
  }
}
