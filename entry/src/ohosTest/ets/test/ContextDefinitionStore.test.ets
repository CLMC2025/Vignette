import { describe, it, expect } from '@ohos/hypium';

import { ContextDefinitionStore, ContextDefinitionStatus, hashStoryText, normalizeContextDefinitionRecord } from '../../../main/ets/utils/ContextDefinitionStore';

export default function contextDefinitionStoreTest(): void {
  describe('ContextDefinitionStore', () => {
    it('should hash deterministically', 0, () => {
      const h1 = hashStoryText('abc');
      const h2 = hashStoryText('abc');
      const h3 = hashStoryText('abcd');
      expect(h1).assertEqual(h2);
      expect(h1 === h3).assertFalse();
    });

    it('should cache in memory by taskId and storyHash', 0, () => {
      const store = ContextDefinitionStore.getInstance();
      store.setCached('t1', 'h1', {
        status: ContextDefinitionStatus.OK,
        definitionText: 'x',
        storyTranslation: 'y',
        createdAt: 1,
        formatVersion: ContextDefinitionStore.FORMAT_VERSION
      });
      const got = store.getCached('t1', 'h1');
      expect(got !== null).assertTrue();
      expect(got!.definitionText).assertEqual('x');
      expect(store.getCached('t1', 'h2') === null).assertTrue();
    });

    it('should normalize v1 record', 0, () => {
      const record = normalizeContextDefinitionRecord({
        status: 'ok',
        definitionText: 'x',
        createdAt: 1
      });
      expect(record !== null).assertTrue();
      expect(record!.formatVersion).assertEqual(1);
      expect(record!.storyTranslation).assertEqual('');
    });
  });
}
