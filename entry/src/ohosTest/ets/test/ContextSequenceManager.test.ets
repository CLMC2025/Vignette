import { describe, it, expect } from '@ohos/hypium';

import { ContextSequenceManager } from '../../../main/ets/utils/ContextSequenceManager';

export default function contextSequenceManagerTest(): void {
  describe('ContextSequenceManager', () => {
    it('should support linear undo and redo-first forward', 0, () => {
      const mgr = new ContextSequenceManager();
      mgr.init('ctx1');

      const fresh: string[] = ['ctx2', 'ctx3', 'ctx4'];
      const getFresh = (): string | null => fresh.shift() ?? null;
      const exists = (id: string): boolean => id !== 'missing';

      expect(mgr.next(getFresh, exists)).assertEqual('ctx2');
      expect(mgr.next(getFresh, exists)).assertEqual('ctx3');
      expect(mgr.getCursor()).assertEqual(2);

      expect(mgr.undo()).assertEqual('ctx2');
      expect(mgr.undo()).assertEqual('ctx1');
      expect(mgr.getCursor()).assertEqual(0);

      const forward1 = mgr.next(() => 'ctx4', exists);
      expect(forward1).assertEqual('ctx2');
      expect(mgr.getCursor()).assertEqual(1);

      const forward2 = mgr.next(() => 'ctx4', exists);
      expect(forward2).assertEqual('ctx3');
      expect(mgr.getCursor()).assertEqual(2);
    });

    it('should trim future when redo id is missing', 0, () => {
      const mgr = new ContextSequenceManager();
      mgr.restore(['a', 'missing'], 0);
      const next = mgr.next(() => 'b', (id: string) => id !== 'missing');
      expect(next).assertEqual('b');
      expect(mgr.getSequence()).assertEqual(['a', 'b']);
      expect(mgr.getCursor()).assertEqual(1);
    });
  });
}

