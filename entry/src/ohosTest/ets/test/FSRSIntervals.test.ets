import { describe, it, expect } from '@ohos/hypium';

import { WordReviewer } from '../../../main/ets/algorithm/Algorithm';
import { WordItem, WordStatus, Rating } from '../../../main/ets/model/WordModel';

export default function fsrsIntervalsTest(): void {
  describe('FSRS intervals adjustments', () => {
    it('should schedule AGAIN dynamically based on FSRS', 0, () => {
      const reviewer = new WordReviewer();
      const word = new WordItem(1, 'apple', WordStatus.NEW);
      reviewer.processReview(word, Rating.AGAIN, 0);
      const count = word.history.getReviewCount();
      expect(count).assertEqual(1);
      const scheduled = word.history.items[0].scheduledDays;
      // FSRS-6 dynamic interval should be small but positive
      // With default params, S0(1) = w[0] = 0.212
      // I = S = 0.212 days = ~5 hours
      // So it should be > 0 and < 1 day
      expect(scheduled > 0).assertTrue();
      expect(scheduled < 1.0).assertTrue();
    });

    it('should schedule GOOD as days on first review', 0, () => {
      const reviewer = new WordReviewer();
      const word = new WordItem(2, 'banana', WordStatus.NEW);
      reviewer.processReview(word, Rating.GOOD, 0);
      const scheduled = word.history.items[0].scheduledDays;
      expect(scheduled >= 1).assertTrue();
    });

    it('should schedule HARD as days on first review', 0, () => {
      const reviewer = new WordReviewer();
      const word = new WordItem(3, 'cat', WordStatus.NEW);
      reviewer.processReview(word, Rating.HARD, 0);
      const scheduled = word.history.items[0].scheduledDays;
      expect(scheduled >= 1).assertTrue();
    });
  });
}
