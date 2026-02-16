import { describe, it, expect } from '@ohos/hypium';

import { isUniqueConstraintErrorMessage } from '../../../main/ets/utils/DatabaseErrorUtil';

export default function databaseErrorUtilTest(): void {
  describe('DatabaseErrorUtil', () => {
    it('should detect unique constraint messages', 0, () => {
      expect(isUniqueConstraintErrorMessage('UNIQUE constraint failed: words.word')).assertTrue();
      expect(isUniqueConstraintErrorMessage('SQLITE_CONSTRAINT_UNIQUE')).assertTrue();
      expect(isUniqueConstraintErrorMessage('SQLite: Abort due to constraint violation')).assertTrue();
      expect(isUniqueConstraintErrorMessage('SQLite: abort due to constraint violation')).assertTrue();
    });

    it('should ignore other messages', 0, () => {
      expect(isUniqueConstraintErrorMessage('network error')).assertFalse();
      expect(isUniqueConstraintErrorMessage('not null constraint failed')).assertFalse();
    });
  });
}
