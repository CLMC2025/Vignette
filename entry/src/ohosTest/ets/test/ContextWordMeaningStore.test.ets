import { describe, it, expect } from '@ohos/hypium';

import { ContextWordMeaningStore } from '../../../main/ets/utils/ContextWordMeaningStore';

export default function contextWordMeaningStoreTest(): void {
  describe('ContextWordMeaningStore', () => {
    it('should build stable keys', 0, () => {
      const store = ContextWordMeaningStore.getInstance();
      const key1 = store.buildKey('abandon', 'h1');
      const key2 = store.buildKey('abandon', 'h1');
      const key3 = store.buildKey('abandon', 'h2');
      expect(key1).assertEqual(key2);
      expect(key1 === key3).assertFalse();
    });
  });
}

