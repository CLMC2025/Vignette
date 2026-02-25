import { DBManager, NotebookWordEntry } from '../../database/DBManager';
import type { IWebDavBackend } from './IWebDavBackend';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { WebDavSettings, WebDavManifest, WebDavSyncResult, NOTEBOOK_FILE_NAME, safeTrim } from './WebDavCommon';
import { taskpool } from '@kit.ArkTS';
import { executeEncrypt, EncryptTaskParams, EncryptTaskResult } from './WebDavSyncTask';

export interface NotebookWordJSON {
  word: string;
  createdAt: number;
}

export class WebDavNotebookSync {
  private db: DBManager;
  private store: WebDavStateStore;

  constructor(db: DBManager, store: WebDavStateStore) {
    this.db = db;
    this.store = store;
  }

  private serializeNotebook(entries: NotebookWordEntry[]): string {
    const jsonEntries: NotebookWordJSON[] = entries.map(e => {
      const item: NotebookWordJSON = {
        word: e.word,
        createdAt: e.createdAt
      };
      return item;
    });
    return JSON.stringify(jsonEntries);
  }

  private parseNotebook(json: string): NotebookWordEntry[] {
    try {
      const arr = JSON.parse(json) as NotebookWordJSON[];
      const out: NotebookWordEntry[] = [];
      for (const obj of arr) {
        if (obj.word && obj.word.length > 0) {
          out.push({
            word: obj.word,
            createdAt: obj.createdAt ?? Date.now()
          });
        }
      }
      return out;
    } catch (e) {
      return [];
    }
  }

  async uploadNotebook(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteRoot: string
  ): Promise<WebDavSyncResult> {
    const entries = await this.db.getNotebookWordsWithTime();

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const remoteFile = `${remoteRoot}/${NOTEBOOK_FILE_NAME}`;
    const json = this.serializeNotebook(entries);

    // Use TaskPool for encryption to avoid blocking main thread
    console.info('[WebDavNotebookSync] Encrypting notebook data in TaskPool');
    const encryptStartMs = Date.now();
    const taskParams: EncryptTaskParams = {
      plainData: json,
      syncPassword: settings.syncPassword
    };

    let enc: string;
    try {
      const result = await taskpool.execute(executeEncrypt, taskParams) as EncryptTaskResult;
      if (result.success) {
        enc = result.data;
        console.info(`[WebDavNotebookSync] Encryption complete ms=${Date.now() - encryptStartMs}`);
      } else {
        throw new Error(result.detail);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`[WebDavNotebookSync] TaskPool encryption failed: ${msg}, falling back to main thread`);
      enc = await WebDavCrypto.encryptUtf8Offloaded(json, settings.syncPassword);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const headRes = await client.head(remoteFile);
    const etag = safeTrim(headRes.headers['etag'] ?? '');

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const putRes = await client.put(remoteFile, enc, 'application/json', etag.length > 0 ? { 'If-Match': etag } : {});
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传单词本失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    manifest.lastNotebookSyncMs = Date.now();
    const headAfter = await client.head(remoteFile);
    manifest.notebookEtag = safeTrim(headAfter.headers['etag'] ?? '');
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok(`已上传 ${entries.length} 个单词本单词`);
  }

  async downloadAndMergeNotebook(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteRoot: string
  ): Promise<WebDavSyncResult> {
    const remoteFile = `${remoteRoot}/${NOTEBOOK_FILE_NAME}`;
    const headRes = await client.head(remoteFile);
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    if (headRes.statusCode === 404) {
      return WebDavSyncResult.ok('服务器上没有单词本数据');
    }
    
    if (headRes.statusCode < 200 || headRes.statusCode >= 300) {
      return WebDavSyncResult.fail('检查单词本失败', `HEAD ${headRes.statusCode}: ${headRes.body}`);
    }

    const remoteEtag = safeTrim(headRes.headers['etag'] ?? '');
    if (remoteEtag === manifest.notebookEtag) {
      return WebDavSyncResult.ok('单词本已是最新');
    }

    const getRes = await client.get(remoteFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return WebDavSyncResult.fail('拉取单词本失败', `GET ${getRes.statusCode}: ${getRes.body}`);
    }
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
    } catch (ce) {
      const errorMsg = ce instanceof CryptoError ? ce.message : String(ce);
      let userFriendlyMsg = errorMsg;
      if (errorMsg.includes('MAC verification failed')) {
        userFriendlyMsg = '同步密码错误或云端数据已损坏。建议：1)检查同步密码是否正确；2)点击"立即同步"重新上传本地数据覆盖云端';
      }
      return WebDavSyncResult.fail('解密单词本失败', userFriendlyMsg);
    }
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const entries = this.parseNotebook(plain);

    // 验证数据有效性
    if (entries.length === 0 && plain.length > 0 && plain !== '[]') {
      return WebDavSyncResult.fail('单词本数据解析失败', '解析后的数据为空，但原始数据不为空');
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    // 安全策略：先备份本地数据，再清空写入
    const localBackup = await this.db.getNotebookWordsWithTime();

    try {
      // 先清空再写入，确保数据一致性
      await this.db.clearNotebook();
      await this.db.syncNotebookWords(entries);

      // 只有数据库操作成功后，才更新 manifest
      manifest.notebookEtag = remoteEtag;
      manifest.lastNotebookSyncMs = Date.now();
      await this.store.saveManifestJson(manifest.toJSON());

      return WebDavSyncResult.ok(`拉取完成：导入 ${entries.length} 个单词本单词`);
    } catch (e) {
      // 如果写入失败，恢复本地备份
      console.error('[WebDavNotebookSync] 写入失败，恢复本地备份:', e);
      try {
        await this.db.clearNotebook();
        await this.db.syncNotebookWords(localBackup);
      } catch (restoreError) {
        console.error('[WebDavNotebookSync] 恢复备份也失败:', restoreError);
      }
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('保存单词本失败', msg);
    }
  }
}
