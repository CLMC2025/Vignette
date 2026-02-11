import { describe, it, expect } from '@ohos/hypium';

import { WebDavManifest } from '../../../main/ets/sync/WebDavSyncManager';

export default function webDavManifestTest(): void {
  describe('WebDavManifest', () => {
    it('should parse legacy manifest without eventsAllEtag', 0, () => {
      const legacyJson = JSON.stringify({
        deviceId: 'dev1',
        lastBackupUploadMs: 0,
        lastBackupEtag: '',
        lastEventsSyncMs: 0,
        consumedEventHrefs: [],
        lastModelVersion: 0,
        lastModelEtag: '',
        lastTemplatePackDownloadMs: 0,
        lastTemplatePackEtag: ''
      });

      const m = WebDavManifest.fromJSON(legacyJson, 'fallback');
      expect(m.deviceId).assertEqual('dev1');
      expect(m.eventsAllEtag).assertEqual('');
    });

    it('should include eventsAllEtag when serializing', 0, () => {
      const m = new WebDavManifest('dev1');
      m.eventsAllEtag = 'etag123';
      const json = m.toJSON();
      expect(json.includes('eventsAllEtag')).assertTrue();
    });
  });
}

