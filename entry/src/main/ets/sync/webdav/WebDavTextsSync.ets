import { DBManager, TextRow } from '../../database/DBManager';
import type { IWebDavBackend } from './IWebDavBackend';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { WebDavSettings, WebDavManifest, WebDavSyncResult, TEXTS_FILE_NAME, safeTrim } from './WebDavCommon';
import { taskpool } from '@kit.ArkTS';
import { executeEncrypt, EncryptTaskParams, EncryptTaskResult } from './WebDavSyncTask';

export interface TextJSON {
  id: number;
  title: string;
  content: string;
  sourceType: string;
  sourceRef: string;
  createdAt: number;
  updatedAt: number;
}

export class WebDavTextsSync {
  private db: DBManager;
  private store: WebDavStateStore;

  constructor(db: DBManager, store: WebDavStateStore) {
    this.db = db;
    this.store = store;
  }

  private serializeTexts(texts: TextRow[]): string {
    const jsonTexts: TextJSON[] = texts.map(t => {
      const item: TextJSON = {
        id: t.id,
        title: t.title,
        content: t.content,
        sourceType: t.sourceType,
        sourceRef: t.sourceRef,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt
      };
      return item;
    });
    return JSON.stringify(jsonTexts);
  }

  private parseTexts(json: string): TextRow[] {
    try {
      const arr = JSON.parse(json) as TextJSON[];
      const out: TextRow[] = [];
      for (const obj of arr) {
        if (obj.title && obj.content) {
          out.push({
            id: obj.id ?? 0,
            title: obj.title,
            content: obj.content,
            sourceType: obj.sourceType ?? 'paste',
            sourceRef: obj.sourceRef ?? '',
            createdAt: obj.createdAt ?? Date.now(),
            updatedAt: obj.updatedAt ?? Date.now()
          });
        }
      }
      return out;
    } catch (e) {
      return [];
    }
  }

  async uploadTexts(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteRoot: string
  ): Promise<WebDavSyncResult> {
    const texts = await this.db.listTexts(1000);

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const remoteFile = `${remoteRoot}/${TEXTS_FILE_NAME}`;
    const json = this.serializeTexts(texts);

    // Use TaskPool for encryption to avoid blocking main thread
    console.info('[WebDavTextsSync] Encrypting texts data in TaskPool');
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
        console.info(`[WebDavTextsSync] Encryption complete ms=${Date.now() - encryptStartMs}`);
      } else {
        throw new Error(result.detail);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`[WebDavTextsSync] TaskPool encryption failed: ${msg}, falling back to main thread`);
      enc = await WebDavCrypto.encryptUtf8Offloaded(json, settings.syncPassword);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const headRes = await client.head(remoteFile);
    const etag = safeTrim(headRes.headers['etag'] ?? '');

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const putRes = await client.put(remoteFile, enc, 'application/json', etag.length > 0 ? { 'If-Match': etag } : {});
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传文本库失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    manifest.lastTextsSyncMs = Date.now();
    const headAfter = await client.head(remoteFile);
    manifest.textsEtag = safeTrim(headAfter.headers['etag'] ?? '');
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok(`已上传 ${texts.length} 个文本`);
  }

  async downloadAndMergeTexts(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteRoot: string
  ): Promise<WebDavSyncResult> {
    const remoteFile = `${remoteRoot}/${TEXTS_FILE_NAME}`;
    const headRes = await client.head(remoteFile);

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    if (headRes.statusCode === 404) {
      return WebDavSyncResult.ok('服务器上没有文本库数据');
    }

    if (headRes.statusCode < 200 || headRes.statusCode >= 300) {
      return WebDavSyncResult.fail('检查文本库失败', `HEAD ${headRes.statusCode}: ${headRes.body}`);
    }

    const remoteEtag = safeTrim(headRes.headers['etag'] ?? '');
    if (remoteEtag === manifest.textsEtag) {
      return WebDavSyncResult.ok('文本库已是最新');
    }

    const getRes = await client.get(remoteFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return WebDavSyncResult.fail('拉取文本库失败', `GET ${getRes.statusCode}: ${getRes.body}`);
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
      return WebDavSyncResult.fail('解密文本库失败', userFriendlyMsg);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const texts = this.parseTexts(plain);

    // 验证数据有效性
    if (texts.length === 0 && plain.length > 0 && plain !== '[]') {
      return WebDavSyncResult.fail('文本库数据解析失败', '解析后的数据为空，但原始数据不为空');
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    // 安全策略：先备份本地数据，再清空写入
    const localBackup = await this.db.listTexts(10000);

    try {
      // 先清空再写入，确保数据一致性
      await this.db.clearAllTexts();
      await this.db.syncTexts(texts);

      // 只有数据库操作成功后，才更新 manifest
      manifest.textsEtag = remoteEtag;
      manifest.lastTextsSyncMs = Date.now();
      await this.store.saveManifestJson(manifest.toJSON());

      return WebDavSyncResult.ok(`拉取完成：导入 ${texts.length} 个文本`);
    } catch (e) {
      // 如果写入失败，恢复本地备份
      console.error('[WebDavTextsSync] 写入失败，恢复本地备份:', e);
      try {
        await this.db.clearAllTexts();
        await this.db.syncTexts(localBackup);
      } catch (restoreError) {
        console.error('[WebDavTextsSync] 恢复备份也失败:', restoreError);
      }
      const msg = e instanceof Error ? e.message : String(e);
      return WebDavSyncResult.fail('保存文本库失败', msg);
    }
  }
}
