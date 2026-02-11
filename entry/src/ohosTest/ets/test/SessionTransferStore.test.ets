import { describe, it, expect } from '@ohos/hypium';

import { QueueItem, WordItem } from '../../../main/ets/model/WordModel';
import { SessionTransferStore } from '../../../main/ets/utils/SessionTransferStore';

export default function sessionTransferStoreTest(): void {
  describe('SessionTransferStore', () => {
    it('should put and take queues', 0, () => {
      const store = SessionTransferStore.getInstance();
      const q: QueueItem[] = [new QueueItem(new WordItem(1, 'abandon'), 0)];
      const id = store.put(q);
      expect(id.length > 0).assertTrue();
      const taken = store.take(id);
      expect(taken !== null).assertTrue();
      expect(taken!.length).assertEqual(1);
      expect(taken![0].word.word).assertEqual('abandon');
      const taken2 = store.take(id);
      expect(taken2 === null).assertTrue();
    });
  });
}

