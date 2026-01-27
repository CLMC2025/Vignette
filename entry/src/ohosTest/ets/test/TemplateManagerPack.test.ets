import { describe, it, expect } from '@ohos/hypium';

import { TemplateManager, TemplatePack, TemplateItem } from '../../../main/ets/context/TemplateManager';

export default function templateManagerPackTest(): void {
  describe('TemplateManager external pack', () => {
    it('apply and clear external template pack', 0, () => {
      const tm = TemplateManager.getInstance();

      // Start from a clean state
      tm.clearExternalTemplatePack();

      const pack: TemplatePack = {
      templates: [
        { id: 'a1', style: 'conversational', difficulty: 2, template: 'I like {word1}.', pos: 'n.', wordCount: 1 } as TemplateItem,
        { id: 'a2', style: 'formal', difficulty: 3, template: 'The {word1} was approved.', pos: 'n.', wordCount: 1 } as TemplateItem
      ]
    };
      const added = tm.applyExternalTemplatePack(JSON.stringify(pack), false);
      expect(added).assertEqual(2);
      expect(tm.getExternalTemplateCount()).assertEqual(2);

      tm.clearExternalTemplatePack();
      expect(tm.getExternalTemplateCount()).assertEqual(0);
    });
  });
}
