import { describe, it, expect } from '@ohos/hypium';

import { AppSettings } from '../../../main/ets/model/WordModel';
import { InMemorySettingsPreferences, SettingsStore } from '../../../main/ets/utils/SettingsStore';

export default function settingsStoreTest(): void {
  describe('SettingsStore', () => {
    it('should be singleton', 0, () => {
      expect(SettingsStore.getInstance() === SettingsStore.getInstance()).assertTrue();
    });

    it('should fail gracefully without context', 0, async () => {
      const store = SettingsStore.getInstance();
      const settings = new AppSettings();
      const saved = await store.saveSettings(settings);
      expect(saved).assertFalse();
      const loaded = await store.getSettings();
      expect(loaded === null).assertTrue();
    });

    it('should flush when saving settings', 0, async () => {
      const store = SettingsStore.getInstance();
      const prefs = new InMemorySettingsPreferences();
      store.injectPreferencesForTest(prefs);
      const settings = new AppSettings();
      const saved = await store.saveSettings(settings);
      expect(saved).assertTrue();
      expect(prefs.flushCount).assertEqual(1);
    });

    it('should persist privacy consent', 0, async () => {
      const store = SettingsStore.getInstance();
      const prefs = new InMemorySettingsPreferences();
      store.injectPreferencesForTest(prefs);
      const stored = await store.setPrivacyConsent(true);
      expect(stored).assertTrue();
      const consent = await store.getPrivacyConsent();
      expect(consent).assertTrue();
    });
  });
}
