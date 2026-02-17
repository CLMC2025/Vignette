import { DBManager, ReviewEventRow } from '../../database/DBManager';
import type { IWebDavBackend } from './IWebDavBackend';
import { WebDavCrypto, CryptoError } from './WebDavCrypto';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { WebDavSettings, WebDavManifest, WebDavSyncResult, ReviewEventJSON, safeTrim } from './WebDavCommon';
import { WebDavConflictResolver } from '../WebDavConflictResolver';

export class WebDavEventsSync {
  private db: DBManager;
  private store: WebDavStateStore;

  constructor(db: DBManager, store: WebDavStateStore) {
    this.db = db;
    this.store = store;
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
        reflection: e.reflection,
        scheduledDays: e.scheduledDays
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
          reflection: (obj['reflection'] as string) ?? '',
          scheduledDays: (obj['scheduledDays'] as number) ?? 0
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

  async uploadLocalReviewEvents(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const events = await this.db.getReviewEventsAfter(manifest.lastEventsSyncMs);
    if (events.length === 0) {
      return WebDavSyncResult.ok('没有新的复习记录需要上传');
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const headRes = await client.head(remoteFile);
    if (headRes.statusCode >= 400 && headRes.statusCode !== 404) {
      return WebDavSyncResult.fail('上传复习记录失败', `HEAD ${headRes.statusCode}: ${headRes.body}`);
    }
    const etag = safeTrim(headRes.headers['etag'] ?? '');

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    let mergedJsonl = '';
    if (headRes.statusCode === 404) {
      mergedJsonl = this.serializeEventsJsonl(events);
    } else {
      const getRes = await client.get(remoteFile);
      if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        return WebDavSyncResult.fail('上传复习记录失败', `GET ${getRes.statusCode}: ${getRes.body}`);
      }
      let remotePlain = '';
      try {
        remotePlain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
      } catch (ce) {
        remotePlain = '';
      }
      mergedJsonl = `${remotePlain}${this.serializeEventsJsonl(events)}`;
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const enc = await WebDavCrypto.encryptUtf8Offloaded(mergedJsonl, settings.syncPassword);
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    const putRes = await client.put(remoteFile, enc, 'application/json', etag.length > 0 ? { 'If-Match': etag } : {});
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      return WebDavSyncResult.fail('上传复习记录失败', `PUT ${putRes.statusCode}: ${putRes.body}`);
    }

    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    // Advance sync cursor to last event timestamp
    let maxTs = manifest.lastEventsSyncMs;
    for (const e of events) {
      if (e.timestamp > maxTs) maxTs = e.timestamp;
    }
    manifest.lastEventsSyncMs = maxTs;
    const headAfter = await client.head(remoteFile);
    manifest.eventsAllEtag = safeTrim(headAfter.headers['etag'] ?? '');
    await this.store.saveManifestJson(manifest.toJSON());

    return WebDavSyncResult.ok(`已上传 ${events.length} 条复习记录`);
  }

  async downloadAndMergeRemoteEvents(
    client: IWebDavBackend,
    settings: WebDavSettings,
    manifest: WebDavManifest,
    remoteFile: string
  ): Promise<WebDavSyncResult> {
    const headRes = await client.head(remoteFile);
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    const conflict = WebDavConflictResolver.checkEventsDownload(headRes, manifest);
    if (conflict) {
      return conflict;
    }

    const getRes = await client.get(remoteFile);
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      return WebDavSyncResult.fail('拉取复习记录失败', `GET ${getRes.statusCode}: ${getRes.body}`);
    }
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    let plain = '';
    try {
      plain = await WebDavCrypto.decryptUtf8Offloaded(getRes.body, settings.syncPassword);
    } catch (ce) {
      const errorMsg = ce instanceof CryptoError ? ce.message : String(ce);
      // 提供更友好的错误提示
      let userFriendlyMsg = errorMsg;
      if (errorMsg.includes('MAC verification failed')) {
        userFriendlyMsg = '同步密码错误或云端数据已损坏。建议：1)检查同步密码是否正确；2)点击"立即同步"重新上传本地数据覆盖云端';
      }
      return WebDavSyncResult.fail('解密复习记录失败', userFriendlyMsg);
    }
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    const events = this.parseEventsJsonl(plain);
    
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    
    const inserted = await this.db.insertReviewEvents(events);
    manifest.eventsAllEtag = safeTrim(headRes.headers['etag'] ?? '');
    await this.store.saveManifestJson(manifest.toJSON());
    
    return WebDavSyncResult.ok(`拉取完成：导入事件 ${inserted}`);
  }
}
