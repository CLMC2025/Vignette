import { DataSyncManager } from '../DataSyncManager';
import type { IWebDavBackend } from './IWebDavBackend';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { WebDavSettings, WebDavManifest, WebDavSyncResult, safeTrim, WORDS_DELTA_FILE_NAME, DEFINITIONS_FILE_NAME } from './WebDavCommon';

export class WebDavIncrementalSync {
  private syncManager: DataSyncManager;
  private store: WebDavStateStore;

  constructor(syncManager: DataSyncManager, store: WebDavStateStore) {
    this.syncManager = syncManager;
    this.store = store;
  }

  async uploadWordsDelta(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const exportResult = await this.syncManager.exportIncremental(manifest.lastWordsSyncMs, false);
    if (!exportResult.success) {
      return WebDavSyncResult.fail('导出增量数据失败', exportResult.error);
    }

    if (exportResult.data.length === 0) {
      return WebDavSyncResult.ok('没有新的单词数据需要同步');
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    let data: Record<string, Object[]> | null = null;
    try {
      data = JSON.parse(exportResult.data) as Record<string, Object[]>;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('解析增量数据失败', msg);
    }

    if (data === null) {
      return WebDavSyncResult.ok('没有新的单词数据需要同步');
    }

    const words = data['words'];
    if (!words || !Array.isArray(words) || words.length === 0) {
      return WebDavSyncResult.ok('没有新的单词数据需要同步');
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const enc = await WebDavCrypto.encryptUtf8Offloaded(exportResult.data, settings.syncPassword);
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    const putRes = await client.put(remoteFile, enc, 'application/json');
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传增量数据失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const headRes = await client.head(remoteFile);
    manifest.lastWordsSyncMs = Date.now();
    manifest.wordsDeltaEtag = safeTrim(headRes.headers['etag'] ?? '');
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok(`已上传 ${words.length} 个单词变更`);
  }

  async downloadAndMergeWordsDelta(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const headRes = await client.head(remoteFile);
    if (headRes.statusCode === 404) {
      return WebDavSyncResult.ok('云端暂无单词增量数据');
    }
    if (headRes.statusCode < 200 || headRes.statusCode >= 300) {
      return WebDavSyncResult.fail('获取单词增量信息失败', `HEAD ${headRes.statusCode}`);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const etag = safeTrim(headRes.headers['etag'] ?? '');
    if (etag.length > 0 && etag === manifest.wordsDeltaEtag) {
      return WebDavSyncResult.ok('单词增量数据已是最新');
    }

    const getRes = await client.get(remoteFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return WebDavSyncResult.fail('下载单词增量失败', `GET ${getRes.statusCode}`);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
    } catch (ce) {
      const msg = ce instanceof CryptoError ? ce.message : String(ce);
      return WebDavSyncResult.fail('解密单词增量失败', msg);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const importResult = await this.syncManager.importIncremental(plain);
    if (importResult.hasErrors()) {
      return WebDavSyncResult.fail('导入单词增量失败', importResult.errors.join('; '));
    }

    manifest.wordsDeltaEtag = etag;
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok(`同步完成：导入 ${importResult.imported}，更新 ${importResult.updated}，跳过 ${importResult.skipped}`);
  }

  async uploadDefinitions(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const exportResult = await this.syncManager.exportIncremental(0, true);
    if (!exportResult.success) {
      return WebDavSyncResult.fail('导出释义数据失败', exportResult.error);
    }

    const enc = await WebDavCrypto.encryptUtf8Offloaded(exportResult.data, settings.syncPassword);
    const putRes = await client.put(remoteFile, enc, 'application/json');
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传释义数据失败', `PUT ${putRes.statusCode}`);
    }

    return WebDavSyncResult.ok('释义数据已上传');
  }

  async downloadDefinitions(
    client: IWebDavBackend,
    settings: WebDavSettings,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const headRes = await client.head(remoteFile);
    if (headRes.statusCode === 404) {
      return WebDavSyncResult.fail('云端暂无释义数据', 'HTTP 404');
    }
    if (headRes.statusCode < 200 || headRes.statusCode >= 300) {
      return WebDavSyncResult.fail('获取释义数据信息失败', `HEAD ${headRes.statusCode}`);
    }

    const getRes = await client.get(remoteFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return WebDavSyncResult.fail('下载释义数据失败', `GET ${getRes.statusCode}`);
    }

    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
    } catch (ce) {
      const msg = ce instanceof CryptoError ? ce.message : String(ce);
      return WebDavSyncResult.fail('解密释义数据失败', msg);
    }

    const importResult = await this.syncManager.importIncremental(plain);
    if (importResult.hasErrors()) {
      return WebDavSyncResult.fail('导入释义数据失败', importResult.errors.join('; '));
    }

    return WebDavSyncResult.ok(`释义数据已导入`);
  }
}
