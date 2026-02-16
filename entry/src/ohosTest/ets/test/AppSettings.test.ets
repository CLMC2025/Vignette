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

    it('should default external dict settings when missing', 0, () => {
      const json = '{"enableTTS":true}';
      const s = AppSettings.fromJSON(json);
      expect(s.externalDictEnabled).assertEqual(true);
      expect(s.externalDictUrlTemplate.includes('{word}')).assertEqual(true);
    });

    it('should roundtrip external dict settings', 0, () => {
      const s = new AppSettings('https://x', 'm');
      s.externalDictEnabled = false;
      s.externalDictUrlTemplate = 'https://example.com/?q={word}';
      const s2 = AppSettings.fromJSON(s.toJSON());
      expect(s2.externalDictEnabled).assertEqual(false);
      expect(s2.externalDictUrlTemplate).assertEqual('https://example.com/?q={word}');
    });
  });
}
