import { describe, it, expect } from '@ohos/hypium';

import { WordItem } from '../../../main/ets/model/WordModel';
import { WordDetailCache } from '../../../main/ets/utils/WordDetailCache';

export default function wordDetailCacheTest(): void {
  describe('WordDetailCache', () => {
    it('should store and return cloned values', 0, () => {
      const cache = WordDetailCache.getInstance();
      cache.clear();
      const w = new WordItem(1, 'abandon');
      cache.set(w);
      const got = cache.get(1);
      expect(got !== null).assertTrue();
      expect(got!.word).assertEqual('abandon');
      got!.word = 'changed';
      const got2 = cache.get(1);
      expect(got2 !== null).assertTrue();
      expect(got2!.word).assertEqual('abandon');
    });

    it('should ignore invalid ids', 0, () => {
      const cache = WordDetailCache.getInstance();
      cache.clear();
      const w = new WordItem(0, 'x');
      cache.set(w);
      const got = cache.get(0);
      expect(got === null).assertTrue();
    });
  });
}

