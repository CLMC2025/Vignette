import { WebDavManifest, WebDavSyncResult, safeTrim, parseHttpDateMillis } from './webdav/WebDavCommon';
import { WebDavResponse } from './webdav/WebDavClient';

export class WebDavConflictResolver {
  /**
   * Check if backup restore should proceed based on remote HEAD response and local manifest.
   * Returns a result if the operation should be skipped or if there was an error.
   * Returns null if the operation should proceed.
   */
  static checkBackupRestore(
    headRes: WebDavResponse,
    manifest: WebDavManifest,
    force: boolean
  ): WebDavSyncResult | null {
    if (headRes.statusCode === 404) {
      return WebDavSyncResult.fail('云端暂无备份', '云端不存在备份文件，请先在其他设备上创建备份');
    }
    if (headRes.statusCode >= 400 || headRes.statusCode === 0) {
      return WebDavSyncResult.fail('获取云端备份信息失败', `HEAD ${headRes.statusCode}: ${headRes.body}`);
    }

    if (!force) {
      const remoteMs = parseHttpDateMillis(safeTrim(headRes.headers['last-modified'] ?? ''));
      if (remoteMs > 0 && remoteMs <= manifest.lastBackupUploadMs) {
        return WebDavSyncResult.ok('云端备份未更新，无需恢复');
      }
    }
    return null; // Should proceed
  }

  /**
   * Check if events download should proceed.
   */
  static checkEventsDownload(
    headRes: WebDavResponse,
    manifest: WebDavManifest
  ): WebDavSyncResult | null {
    if (headRes.statusCode === 404) {
      return WebDavSyncResult.ok('云端暂无复习记录');
    }
    if (headRes.statusCode < 200 || headRes.statusCode >= 400) {
      return WebDavSyncResult.fail('拉取复习记录失败', `HEAD ${headRes.statusCode}: ${headRes.body}`);
    }
    const etag = safeTrim(headRes.headers['etag'] ?? '');
    if (etag.length > 0 && etag === manifest.eventsAllEtag) {
      return WebDavSyncResult.ok('云端复习记录未更新');
    }
    return null; // Should proceed
  }

  /**
   * Check if template pack download should proceed.
   */
  static checkTemplatePackDownload(
    headRes: WebDavResponse,
    manifest: WebDavManifest
  ): WebDavSyncResult | null {
    if (headRes.statusCode === 404) {
      return WebDavSyncResult.fail('云端不存在离线模板包', 'HTTP 404');
    }
    if (headRes.statusCode < 200 || headRes.statusCode >= 400) {
      return WebDavSyncResult.fail('下载离线模板包失败', `HEAD ${headRes.statusCode}: ${headRes.body}`);
    }
    const etag = safeTrim(headRes.headers['etag'] ?? '');
    if (etag.length > 0 && etag === manifest.lastTemplatePackEtag) {
      return WebDavSyncResult.ok('离线模板包已是最新');
    }
    return null; // Should proceed
  }
}
