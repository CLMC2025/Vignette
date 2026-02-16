import { describe, it, expect } from '@ohos/hypium';

import { HistoryStack } from '../../../main/ets/utils/HistoryStack';

export default function historyStackTest(): void {
  describe('HistoryStack', () => {
    it('should keep max capacity and pop in LIFO order', 0, () => {
      let stack = new HistoryStack<number>(5);
      stack = stack.push(1);
      stack = stack.push(2);
      stack = stack.push(3);
      stack = stack.push(4);
      stack = stack.push(5);
      stack = stack.push(6);

      expect(stack.size()).assertEqual(5);
      expect(stack.toArray()[0]).assertEqual(2);

      const r1 = stack.pop();
      expect(r1.item).assertEqual(6);
      const r2 = r1.stack.pop();
      expect(r2.item).assertEqual(5);
    });

    it('should return null when popping empty stack', 0, () => {
      const stack = new HistoryStack<string>(3);
      const res = stack.pop();
      expect(res.item).assertEqual(null);
      expect(res.stack.size()).assertEqual(0);
    });
  });
}
