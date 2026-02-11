import { describe, it, expect } from '@ohos/hypium';

import { DictionaryManager } from '../../../main/ets/manager/DictionaryManager';

export default function dictionaryManagerVignetteCacheTest(): void {
  describe('DictionaryManager vignette cache preference', () => {
    it('should prefer cached vignette when available', 0, async () => {
      const dm = DictionaryManager.getInstance() as unknown as Record<string, object>;
      const originalDb = dm['db'];
      let called = 0;
      dm['db'] = {
        getCachedVignette: async (_key: string): Promise<string> => {
          called++;
          return 'After class, I went abroad. It felt simple and easy to remember.';
        }
      } as unknown as object;

      try {
        const res = await (DictionaryManager.getInstance()).generateStory('abroad', [], 50, 70, 2, 3);
        expect(res.success).assertTrue();
        expect(res.story.toLowerCase().includes('abroad')).assertTrue();
        expect(called > 0).assertTrue();
      } finally {
        dm['db'] = originalDb;
      }
    });
  });
}
