import { describe, it, expect } from '@ohos/hypium';

import { InMemoryWebDavPreferences, WebDavStateStore } from '../../../main/ets/utils/WebDavStateStore';

export default function webDavStateStoreTest(): void {
  describe('WebDavStateStore', () => {
    it('should persist and reload settings json across instances', 0, async () => {
      const prefs = new InMemoryWebDavPreferences();
      const store1 = WebDavStateStore.createDetachedForTest(prefs);
      const json = '{"endpoint":"https://example.com/dav","username":"u","password":"p","syncPassword":"sync","remoteRoot":"/root"}';
      const saved = await store1.saveSettingsJson(json);
      expect(saved).assertTrue();

      const store2 = WebDavStateStore.createDetachedForTest(prefs);
      const loaded = await store2.getSettingsJson();
      expect(loaded).assertEqual(json);
    });

    it('should fallback to backup when primary is corrupted', 0, async () => {
      const prefs = new InMemoryWebDavPreferences();
      const store1 = WebDavStateStore.createDetachedForTest(prefs);
      const json = '{"endpoint":"https://example.com/dav","username":"u","password":"p","syncPassword":"sync","remoteRoot":"/root"}';
      await store1.saveSettingsJson(json);

      await prefs.put('webdav_settings_json', '{bad');
      await prefs.flush();

      const store2 = WebDavStateStore.createDetachedForTest(prefs);
      const loaded = await store2.getSettingsJson();
      expect(loaded).assertEqual(json);
    });
  });
}

