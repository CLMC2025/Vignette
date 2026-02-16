import { DataSyncManager } from '../DataSyncManager';
import type { IWebDavBackend } from './IWebDavBackend';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { WebDavSettings, WebDavManifest, WebDavSyncResult, WebDavBackupPlainResult, safeTrim, parseHttpDateMillis } from './WebDavCommon';
import { WebDavConflictResolver } from '../WebDavConflictResolver';

export class WebDavBackupManager {
  private syncManager: DataSyncManager;
  private store: WebDavStateStore;

  constructor(syncManager: DataSyncManager, store: WebDavStateStore) {
    this.syncManager = syncManager;
    this.store = store;
  }

  async backupToCloud(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const exportStartMs = Date.now();
    const exportResult = await this.syncManager.exportData();
    const exportElapsedMs = Date.now() - exportStartMs;
    console.info(`[WebDAV] backup export ms=${exportElapsedMs}`);
    if (!exportResult.success) {
      return WebDavSyncResult.fail('导出失败', exportResult.error);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 50));

    const dataSize = exportResult.data.length;
    console.info(`[WebDAV] backup data size=${dataSize}`);
    
    if (dataSize > 5 * 1024 * 1024) {
      console.warn(`[WebDAV] backup data too large: ${dataSize} bytes`);
    }

    const encStartMs = Date.now();
    const enc = await WebDavCrypto.encryptUtf8Offloaded(exportResult.data, settings.syncPassword);
    const encElapsedMs = Date.now() - encStartMs;
    console.info(`[WebDAV] backup encrypt ms=${encElapsedMs}`);
    
    await new Promise<void>((resolve) => setTimeout(resolve, 50));
    
    const putStartMs = Date.now();
    const putRes = await client.put(remoteFile, enc, 'application/json');
    const putElapsedMs = Date.now() - putStartMs;
    console.info(`[WebDAV] backup put status=${putRes.statusCode} ms=${putElapsedMs}`);
    
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
    }

    const headRes = await client.head(remoteFile);
    manifest.lastBackupUploadMs = Date.now();
    manifest.lastBackupEtag = safeTrim(headRes.headers['etag'] ?? '');
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok('备份已上传');
  }

  async downloadBackupPlain(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string,
    legacyRemoteFile: string,
    force: boolean
  ): Promise<WebDavBackupPlainResult> {
    let targetFile = remoteFile;
    
    if (!force) {
      let headRes = await client.head(targetFile);
      if (headRes.statusCode === 404) {
        const legacyHead = await client.head(legacyRemoteFile);
        if (legacyHead.statusCode !== 404) {
          targetFile = legacyRemoteFile;
          headRes = legacyHead;
        }
      }
      
      const conflict = WebDavConflictResolver.checkBackupRestore(headRes, manifest, force);
      if (conflict) {
        // Special handling for "IDLE" status result from resolver which means we should stop but it's not an error
        // But here we need to return WebDavBackupPlainResult
        return new WebDavBackupPlainResult(conflict, '');
      }
    }

    const snapshot = await this.syncManager.exportData();
    if (snapshot.success) {
      await this.store.saveSnapshotJson(snapshot.data);
    }

    const getRes = await client.get(targetFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return new WebDavBackupPlainResult(
        WebDavSyncResult.fail('下载失败', `GET ${getRes.statusCode}: ${getRes.body}`),
        ''
      );
    }

    let plain: string;
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
    } catch (ce) {
      const msg = ce instanceof CryptoError ? ce.message : String(ce);
      return new WebDavBackupPlainResult(WebDavSyncResult.fail('解密失败', msg), '');
    }

    return new WebDavBackupPlainResult(WebDavSyncResult.ok('已下载云端备份'), plain);
  }

  async restoreFromCloud(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string,
    legacyRemoteFile: string,
    force: boolean
  ): Promise<WebDavSyncResult> {
    let targetFile = remoteFile;

    // Conflict check
    if (!force) {
      let headRes = await client.head(targetFile);
      if (headRes.statusCode === 404) {
        const legacyHead = await client.head(legacyRemoteFile);
        if (legacyHead.statusCode !== 404) {
          targetFile = legacyRemoteFile;
          headRes = legacyHead;
        }
      }
      
      const conflict = WebDavConflictResolver.checkBackupRestore(headRes, manifest, force);
      if (conflict) {
        return conflict;
      }
    }

    // Snapshot local data before import
    const snapshot = await this.syncManager.exportData();
    if (snapshot.success) {
      await this.store.saveSnapshotJson(snapshot.data);
    }

    const getRes = await client.get(targetFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return WebDavSyncResult.fail('下载失败', `GET ${getRes.statusCode}: ${getRes.body}`);
    }

    let plain: string;
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
    } catch (ce) {
      const msg = ce instanceof CryptoError ? ce.message : String(ce);
      return WebDavSyncResult.fail('解密失败', msg);
    }

    const importRes = await this.syncManager.importData(plain);
    if (importRes.hasErrors()) {
      return WebDavSyncResult.fail('导入失败', importRes.errors.join('; '));
    }

    return WebDavSyncResult.ok(`恢复完成：导入 ${importRes.imported}，更新 ${importRes.updated}`);
  }

  async importPlainBackup(plain: string): Promise<WebDavSyncResult> {
    if (plain.length === 0) return WebDavSyncResult.fail('导入失败', '备份内容为空');

    try {
      const importRes = await this.syncManager.importData(plain);
      if (importRes.hasErrors()) {
        return WebDavSyncResult.fail('导入失败', importRes.errors.join('; '));
      }
      return WebDavSyncResult.ok(`恢复完成：导入 ${importRes.imported}，更新 ${importRes.updated}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('导入失败', msg);
    }
  }
}
