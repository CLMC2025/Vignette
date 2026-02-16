import { describe, it, expect } from '@ohos/hypium';

import { FSRSAlgorithm, WordReviewer } from '../../../main/ets/algorithm/Algorithm';
import { WordItem, WordStatus, Rating, FSRSState } from '../../../main/ets/model/WordModel';

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

    it('should increase recall stability when difficulty decreases with same stability and retrievability', 0, () => {
      const algorithm = FSRSAlgorithm.getInstance();
      const baseState = new FSRSState(8.5, 10, 1, 3, 0);

      const hardWordState = baseState.clone();
      hardWordState.difficulty = 9.0;
      const easierWordState = baseState.clone();
      easierWordState.difficulty = 3.0;

      const hardResult = algorithm.review(hardWordState, Rating.GOOD, 5, false);
      const easyResult = algorithm.review(easierWordState, Rating.GOOD, 5, false);

      expect(easyResult.newState.stability > hardResult.newState.stability).assertTrue();
      expect(easyResult.intervalDays > hardResult.intervalDays).assertTrue();
    });

    it('should increase recall stability when retrievability is lower with same difficulty and rating', 0, () => {
      const algorithm = FSRSAlgorithm.getInstance();
      const sameState = new FSRSState(5.5, 8, 1, 3, 0);

      const highRetrievability = algorithm.review(sameState.clone(), Rating.GOOD, 1, false);
      const lowRetrievability = algorithm.review(sameState.clone(), Rating.GOOD, 30, false);

      expect(lowRetrievability.newState.stability > highRetrievability.newState.stability).assertTrue();
      expect(lowRetrievability.intervalDays > highRetrievability.intervalDays).assertTrue();
    });

    it('should preserve rating order and positive stability for recall regression set', 0, () => {
      const algorithm = FSRSAlgorithm.getInstance();
      const reviewState = new FSRSState(5.0, 6.0, 1.0, 4, 1);

      const again = algorithm.review(reviewState.clone(), Rating.AGAIN, 9, false);
      const hard = algorithm.review(reviewState.clone(), Rating.HARD, 9, false);
      const good = algorithm.review(reviewState.clone(), Rating.GOOD, 9, false);
      const easy = algorithm.review(reviewState.clone(), Rating.EASY, 9, false);

      expect(again.newState.stability >= 0.1).assertTrue();
      expect(hard.newState.stability >= 0.1).assertTrue();
      expect(good.newState.stability >= 0.1).assertTrue();
      expect(easy.newState.stability >= 0.1).assertTrue();

      expect(again.intervalDays < hard.intervalDays).assertTrue();
      expect(hard.intervalDays <= good.intervalDays).assertTrue();
      expect(good.intervalDays <= easy.intervalDays).assertTrue();
    });
  });
}
