import { describe, it, expect } from '@ohos/hypium';

import { addNotebookWord, removeNotebookWord } from '../../../main/ets/utils/NotebookWordSet';

export default function notebookWordSetTest(): void {
  describe('NotebookWordSet', () => {
    it('should add and remove with new Set instances', 0, () => {
      const s1 = new Set<string>();
      const s2 = addNotebookWord(s1, 'a');
      expect(s1.has('a')).assertFalse();
      expect(s2.has('a')).assertTrue();

      const s3 = removeNotebookWord(s2, 'a');
      expect(s2.has('a')).assertTrue();
      expect(s3.has('a')).assertFalse();
    });
  });
}

