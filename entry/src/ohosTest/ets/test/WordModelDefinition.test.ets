import { describe, it, expect } from '@ohos/hypium';

import { WordDefinition, WordMeaning, WordItem } from '../../../main/ets/model/WordModel';

export default function wordModelDefinitionTest(): void {
  describe('WordModelDefinition', () => {
    it('should serialize and deserialize WordDefinition', 0, () => {
      const meanings: WordMeaning[] = [
        new WordMeaning('n.', '测试'),
        new WordMeaning('v.', '验证')
      ];
      const def = new WordDefinition('abandon', '[əˈbændən]', 'v.', '', meanings, 'db');
      const json = def.toJSON();
      const parsed = WordDefinition.fromJSON(json);
      expect(parsed.word).assertEqual('abandon');
      expect(parsed.phonetic).assertEqual('[əˈbændən]');
      expect(parsed.commonMeanings.length).assertEqual(2);
      expect(parsed.commonMeanings[0].pos).assertEqual('n.');
      expect(parsed.commonMeanings[0].cn).assertEqual('测试');
    });

    it('should deep-clone WordItem definition', 0, () => {
      const meanings: WordMeaning[] = [new WordMeaning('n.', '测试')];
      const def = new WordDefinition('ability', '', '', '', meanings, 'builtin');
      const word = new WordItem(1, 'ability');
      word.definition = def;
      const cloned = word.clone();
      cloned.definition.commonMeanings.push(new WordMeaning('v.', '修改'));
      expect(word.definition.commonMeanings.length).assertEqual(1);
      expect(cloned.definition.commonMeanings.length).assertEqual(2);
    });
  });
}

