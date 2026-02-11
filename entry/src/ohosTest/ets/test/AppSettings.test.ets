import { describe, it, expect } from '@ohos/hypium';

import { AppSettings } from '../../../main/ets/model/WordModel';

export default function appSettingsTest(): void {
  describe('AppSettings', () => {
    it('should default pronunciationMode when missing', 0, () => {
      const json = '{"enableTTS":true}';
      const s = AppSettings.fromJSON(json);
      expect(s.pronunciationMode).assertEqual('auto');
    });

    it('should roundtrip pronunciationMode', 0, () => {
      const s = new AppSettings('https://x', 'm', 10, true, 'system');
      const s2 = AppSettings.fromJSON(s.toJSON());
      expect(s2.pronunciationMode).assertEqual('system');
    });
  });
}

