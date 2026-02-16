import { describe, it, expect } from '@ohos/hypium';

import { WebDavSyncManager, WebDavSettings, WebDavSyncResult, WebDavSyncStatus } from '../../../main/ets/sync/WebDavSyncManager';

interface SyncManagerPatch {
  [key: string]: Object | string | number | boolean;
}

export default function webDavSyncManagerIncrementalTest(): void {
  describe('WebDavSyncManager syncIncremental', () => {
    it('should download remote events first and then upload local events', 0, async () => {
      const manager = WebDavSyncManager.getInstance();
      const patch = manager as SyncManagerPatch;
      const originalCreateClient = patch['createClient'];
      const originalPreflight = patch['preflightRemoteRoot'];
      const originalIncrementalSync = patch['incrementalSync'];
      const originalEventsSync = patch['eventsSync'];

      const steps: string[] = [];

      patch['settings'] = new WebDavSettings('https://example.com/dav', 'user', 'pass', 'sync-pass', '/sync-root');
      patch['createClient'] = (): Object => {
        return {};
      };
      patch['preflightRemoteRoot'] = async (): Promise<WebDavSyncResult | null> => {
        return null;
      };
      patch['incrementalSync'] = {
        downloadAndMergeWordsDelta: async (): Promise<WebDavSyncResult> => {
          steps.push('words-download');
          return WebDavSyncResult.ok('单词拉取完成');
        },
        uploadWordsDelta: async (): Promise<WebDavSyncResult> => {
          steps.push('words-upload');
          return WebDavSyncResult.ok('单词上传完成');
        }
      } as Object;
      patch['eventsSync'] = {
        downloadAndMergeRemoteEvents: async (): Promise<WebDavSyncResult> => {
          steps.push('events-download');
          return WebDavSyncResult.ok('拉取完成：导入事件 2');
        },
        uploadLocalReviewEvents: async (): Promise<WebDavSyncResult> => {
          steps.push('events-upload');
          return WebDavSyncResult.ok('已上传 1 条复习记录');
        }
      } as Object;

      try {
        const result = await manager.syncIncremental();
        expect(result.success).assertTrue();
        expect(result.message.includes('事件下载：拉取完成：导入事件 2')).assertTrue();
        expect(result.message.includes('事件上传：已上传 1 条复习记录')).assertTrue();
        expect(steps.join(',')).assertEqual('words-download,words-upload,events-download,events-upload');
        expect(manager.getStatus()).assertEqual(WebDavSyncStatus.IDLE);
      } finally {
        patch['createClient'] = originalCreateClient;
        patch['preflightRemoteRoot'] = originalPreflight;
        patch['incrementalSync'] = originalIncrementalSync;
        patch['eventsSync'] = originalEventsSync;
      }
    });

    it('should set ERROR status and include failing step when events download fails', 0, async () => {
      const manager = WebDavSyncManager.getInstance();
      const patch = manager as SyncManagerPatch;
      const originalCreateClient = patch['createClient'];
      const originalPreflight = patch['preflightRemoteRoot'];
      const originalIncrementalSync = patch['incrementalSync'];
      const originalEventsSync = patch['eventsSync'];

      patch['settings'] = new WebDavSettings('https://example.com/dav', 'user', 'pass', 'sync-pass', '/sync-root');
      patch['createClient'] = (): Object => {
        return {};
      };
      patch['preflightRemoteRoot'] = async (): Promise<WebDavSyncResult | null> => {
        return null;
      };
      patch['incrementalSync'] = {
        downloadAndMergeWordsDelta: async (): Promise<WebDavSyncResult> => {
          return WebDavSyncResult.ok('单词拉取完成');
        },
        uploadWordsDelta: async (): Promise<WebDavSyncResult> => {
          return WebDavSyncResult.ok('单词上传完成');
        }
      } as Object;
      patch['eventsSync'] = {
        downloadAndMergeRemoteEvents: async (): Promise<WebDavSyncResult> => {
          return WebDavSyncResult.fail('拉取复习记录失败', 'GET 500: boom');
        },
        uploadLocalReviewEvents: async (): Promise<WebDavSyncResult> => {
          return WebDavSyncResult.ok('不应执行');
        }
      } as Object;

      try {
        const result = await manager.syncIncremental();
        expect(result.success).assertFalse();
        expect(result.message).assertEqual('增量同步失败（事件下载）');
        expect(result.detail.includes('STEP 事件下载')).assertTrue();
        expect(result.detail.includes('GET 500: boom')).assertTrue();
        expect(manager.getStatus()).assertEqual(WebDavSyncStatus.ERROR);
      } finally {
        patch['createClient'] = originalCreateClient;
        patch['preflightRemoteRoot'] = originalPreflight;
        patch['incrementalSync'] = originalIncrementalSync;
        patch['eventsSync'] = originalEventsSync;
      }
    });
  });
}
