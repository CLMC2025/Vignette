import { describe, it, expect } from '@ohos/hypium';

import { BookKind, classifyBookId } from '../../../main/ets/utils/BookIdClassifier';

export default function bookIdClassifierTest(): void {
  describe('BookIdClassifier', () => {
    it('should classify built-in ids as system', 0, () => {
      expect(classifyBookId('cet4')).assertEqual(BookKind.System);
      expect(classifyBookId('cet6')).assertEqual(BookKind.System);
      expect(classifyBookId('kaoyan')).assertEqual(BookKind.System);
    });

    it('should classify other ids as user', 0, () => {
      expect(classifyBookId('user_1')).assertEqual(BookKind.User);
    });
  });
}
