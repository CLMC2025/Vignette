import { describe, it, expect } from '@ohos/hypium';

import { buildTranslationText } from '../../../main/ets/utils/TranslationTextBuilder';
import { WordDefinition, WordMeaning } from '../../../main/ets/model/WordModel';

export default function translationTextBuilderTest(): void {
  describe('TranslationTextBuilder', () => {
    it('should show placeholders when loading', 0, () => {
      const text = buildTranslationText({
        storyText: 'hello world',
        storyTranslation: '',
        targetWord: 'test',
        definition: new WordDefinition('test', '', '', '', [], 'local'),
        definitionLoading: true
      });
      expect(text.includes('加载中')).assertTrue();
      expect(text.includes('完整语境翻译')).assertTrue();
      expect(text.includes('完整词典释义')).assertTrue();
    });

    it('should include context and common meanings when present', 0, () => {
      const def = new WordDefinition('run', '', 'v.', '跑', [
        new WordMeaning('v.', '跑'),
        new WordMeaning('n.', '跑步')
      ], 'local');
      def.contextMeaning = '跑（在这里）';
      const text = buildTranslationText({
        storyText: 'I run fast.',
        storyTranslation: '我跑得很快。',
        targetWord: 'run',
        definition: def,
        definitionLoading: false
      });
      expect(text.includes('我跑得很快')).assertTrue();
      expect(text.includes('跑（在这里）')).assertTrue();
      expect(text.includes('v.: 跑')).assertTrue();
      expect(text.includes('n.: 跑步')).assertTrue();
    });
  });
}

