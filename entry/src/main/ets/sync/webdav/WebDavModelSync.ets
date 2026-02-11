import { TemplateManager } from '../../context/TemplateManager';
import type { IWebDavBackend } from './IWebDavBackend';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { WebDavSettings, WebDavManifest, WebDavSyncResult, safeTrim } from './WebDavCommon';
import { WebDavConflictResolver } from '../WebDavConflictResolver';

export class WebDavModelSync {
  private store: WebDavStateStore;

  constructor(store: WebDavStateStore) {
    this.store = store;
  }

  async downloadTemplatePack(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const headRes = await client.head(remoteFile);
    
    const conflict = WebDavConflictResolver.checkTemplatePackDownload(headRes, manifest);
    if (conflict) {
      return conflict;
    }

    const res = await client.get(remoteFile);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return WebDavSyncResult.fail('下载离线模板包失败', `HTTP ${res.statusCode}: ${res.body}`);
    }

    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(res.body, settings.syncPassword);
    } catch (ce) {
      const msg = ce instanceof CryptoError ? ce.message : String(ce);
      return WebDavSyncResult.fail('解密离线模板包失败', msg);
    }
    
    const tm = TemplateManager.getInstance();
    const added = tm.applyExternalTemplatePack(plain, true);

    const etagHeader = safeTrim(res.headers['etag'] ?? '');
    if (etagHeader.length > 0) {
      manifest.lastTemplatePackEtag = etagHeader;
    }
    manifest.lastTemplatePackDownloadMs = Date.now();
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok(`已下载离线模板包：新增 ${added} 条模板`);
  }

  async uploadTemplatePack(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const tm = TemplateManager.getInstance();
    const packJson = tm.getPersistedExternalPackJson();
    if (packJson.trim().length === 0) {
      return WebDavSyncResult.fail('没有可上传的离线模板包', 'no_template_pack');
    }

    const encrypted = await WebDavCrypto.encryptUtf8Offloaded(packJson, settings.syncPassword);
    const putRes = await client.put(remoteFile, encrypted, 'application/json');

    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传离线模板包失败', `HTTP ${putRes.statusCode}: ${putRes.body}`);
    }

    const etagFromPut = safeTrim(putRes.headers['etag'] ?? '');
    if (etagFromPut.length > 0) {
      manifest.lastTemplatePackEtag = etagFromPut;
    } else {
      const headRes = await client.head(remoteFile);
      manifest.lastTemplatePackEtag = safeTrim(headRes.headers['etag'] ?? '');
    }
    manifest.lastTemplatePackDownloadMs = Date.now();
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok('已上传离线模板包');
  }
}
