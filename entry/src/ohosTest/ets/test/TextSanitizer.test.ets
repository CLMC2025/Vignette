import { describe, it, expect } from '@ohos/hypium';

import { TextSanitizer } from '../../../main/ets/utils/TextSanitizer';

export default function textSanitizerTest(): void {
  describe('TextSanitizer', () => {
    it('should strip markdown emphasis markers', 0, () => {
      const input = 'I **really** like *apple*.';
      const out = TextSanitizer.stripMarkdownEmphasis(input);
      expect(out).assertEqual('I really like apple.');
    });

    it('should preserve newlines while normalizing spaces', 0, () => {
      const input = 'Line1   with   spaces\\n\\nLine2\\twith\\t tabs';
      const out = TextSanitizer.sanitizeContext(input);
      expect(out).assertEqual('Line1 with spaces\\n\\nLine2 with tabs');
    });

    it('should remove dangling bold markers', 0, () => {
      const input = '**word is here';
      const out = TextSanitizer.sanitizeContext(input);
      expect(out).assertEqual('word is here');
    });
  });
}
