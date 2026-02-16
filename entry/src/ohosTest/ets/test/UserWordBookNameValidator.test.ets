import { describe, it, expect } from '@ohos/hypium';

import { validateUserWordBookName } from '../../../main/ets/utils/UserWordBookNameValidator';

export default function userWordBookNameValidatorTest(): void {
  describe('UserWordBookNameValidator', () => {
    it('should reject empty name', 0, () => {
      const err = validateUserWordBookName('   ');
      expect(err.length > 0).assertTrue();
    });

    it('should reject overlong name', 0, () => {
      const err = validateUserWordBookName('123456789012345678901');
      expect(err).assertEqual('词书名称不能超过20个字符');
    });

    it('should accept trimmed name', 0, () => {
      const err = validateUserWordBookName('  我的词书  ');
      expect(err).assertEqual('');
    });
  });
}

