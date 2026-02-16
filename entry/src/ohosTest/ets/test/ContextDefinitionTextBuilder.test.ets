import { describe, it, expect } from '@ohos/hypium';

import { buildContextDefinitionText } from '../../../main/ets/utils/ContextDefinitionTextBuilder';
import { ExampleItem, PhraseItem, WordDefinition, WordMeaning } from '../../../main/ets/model/WordModel';

export default function contextDefinitionTextBuilderTest(): void {
  describe('ContextDefinitionTextBuilder', () => {
    it('should include translation and phonetic/pos when present', 0, () => {
      const def = new WordDefinition(
        'ability',
        '/əˈbɪləti/',
        'n.',
        '能力（在这里）',
        [new WordMeaning('n.', '能力；才能')],
        'ai'
      );
      def.phrases = [new PhraseItem('have the ability to', '有能力做', 'He has the ability to adapt.')];
      def.examples = [new ExampleItem('She has great ability.', '她很有能力。')];
      def.frequency = 4;
      def.examTags = ['CET6'];

      const text = buildContextDefinitionText({
        storyTranslation: '这是中文翻译。',
        targetWord: 'ability',
        definition: def
      });
      expect(text.includes('完整语境翻译')).assertTrue();
      expect(text.includes('/əˈbɪləti/')).assertTrue();
      expect(text.includes('n.')).assertTrue();
      expect(text.includes('常用短语/搭配')).assertTrue();
      expect(text.includes('例句')).assertTrue();
      expect(text.includes('词汇信息')).assertTrue();
    });

    it('should return fallback when empty', 0, () => {
      const text = buildContextDefinitionText({
        storyTranslation: '',
        targetWord: 'x',
        definition: new WordDefinition()
      });
      expect(text.length > 0).assertTrue();
    });
  });
}
