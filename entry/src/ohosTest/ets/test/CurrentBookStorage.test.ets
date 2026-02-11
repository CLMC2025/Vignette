import { describe, it, expect } from '@ohos/hypium';

import { BuiltInWordBooks, WordBookDefinition } from '../../../main/ets/model/WordBookCatalog';

export default function currentBookStorageTest(): void {
  describe('CurrentBookStorage', () => {
    it('should persist current_book_id in AppStorage', 0, () => {
      AppStorage.setOrCreate('current_book_id', '');
      AppStorage.setOrCreate('current_book_id', 'cet4');
      const stored = AppStorage.get('current_book_id') as string;
      expect(stored).assertEqual('cet4');
    });

    it('should include builtin wordbook ids', 0, () => {
      const ids: string[] = BuiltInWordBooks.map((b: WordBookDefinition): string => b.id);
      expect(ids.includes('cet4')).assertTrue();
      expect(ids.includes('cet6')).assertTrue();
      expect(ids.includes('kaoyan')).assertTrue();
    });
  });
}

