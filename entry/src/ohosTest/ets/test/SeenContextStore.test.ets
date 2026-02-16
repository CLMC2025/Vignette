import { describe, it, expect } from '@ohos/hypium';

import { SeenContextStore } from '../../../main/ets/utils/SeenContextStore';

export default function seenContextStoreTest(): void {
  describe('SeenContextStore', () => {
    it('should persist ids and cap by max size', 0, () => {
      const key = 'test_seen_context_ids_v1';
      AppStorage.setOrCreate(key, '[]');
      const store = new SeenContextStore(key, 3);

      store.add('a');
      store.add('b');
      store.add('b');
      store.add('c');
      store.add('d');

      const loaded = store.load();
      expect(loaded.size).assertEqual(3);
      expect(loaded.has('a')).assertFalse();
      expect(loaded.has('b')).assertTrue();
      expect(loaded.has('c')).assertTrue();
      expect(loaded.has('d')).assertTrue();
    });

    it('should isolate different storage keys (version bump)', 0, () => {
      const oldKey = 'test_seen_context_ids_v1_old';
      const newKey = 'test_seen_context_ids_v2_new';
      AppStorage.setOrCreate(oldKey, JSON.stringify(['x']));
      AppStorage.setOrCreate(newKey, '[]');

      const oldStore = new SeenContextStore(oldKey, 10);
      const newStore = new SeenContextStore(newKey, 10);

      expect(oldStore.has('x')).assertTrue();
      expect(newStore.has('x')).assertFalse();
    });
  });
}
