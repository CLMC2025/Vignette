import { describe, it, expect } from '@ohos/hypium';

import { normalizeQueueFromRouterParams, RawQueueItem, RawWordItem } from '../../../main/ets/utils/RouteParamNormalizer';
import { FSRSState, WordDefinition, WordItem } from '../../../main/ets/model/WordModel';

export default function routeParamNormalizerTest() {
  describe('RouteParamNormalizer', () => {
    it('should rebuild WordItem instances from plain router params', 0, () => {
      const fsrs = new FSRSState();
      fsrs.stability = 2.5;
      fsrs.difficulty = 5;

      const def = new WordDefinition();
      def.word = 'apple';
      def.contextMeaning = 'n. 苹果';

      // Simulate prototype loss (router serialization)
      const rawWord: RawWordItem = {
        id: 1,
        word: 'apple',
        status: 'NEW',
        fsrsState: fsrs.toJSON(),
        history: '[]',
        definition: def.toJSON(),
        dueDate: Date.now(),
        createdAt: Date.now(),
        updatedAt: Date.now(),
        bookId: 'default',
        tags: ['fruit']
      };

      const rawQueue: Array<RawQueueItem> = [
        { word: rawWord, priority: 1 }
      ];

      const normalized = normalizeQueueFromRouterParams(rawQueue);
      expect(normalized.length).assertEqual(1);

      const w = normalized[0].word;
      expect(w instanceof WordItem).assertTrue();
      expect(typeof (w as WordItem).clone).assertEqual('function');
      expect(w.word).assertEqual('apple');
      expect(w.definition?.contextMeaning).assertContain('苹果');
    });
  });
}
