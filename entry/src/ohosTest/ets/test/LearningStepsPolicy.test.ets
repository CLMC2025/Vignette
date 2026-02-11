import { describe, it, expect } from '@ohos/hypium';
import { LearningStepsPolicy } from '../../../main/ets/algorithm/LearningStepsPolicy';
import { WordItem, WordStatus, Rating, FSRSState } from '../../../main/ets/model/WordModel';

/**
 * Learning Steps Policy Tests
 * 
 * Validates the separation of learning steps from FSRS scheduling
 */
export default function learningStepsPolicyTest(): void {
  describe('Learning Steps Policy', () => {
    const policy = new LearningStepsPolicy();

    describe('AGAIN Rating (Always Override)', () => {
      it('should override with 5-minute interval for AGAIN on new word', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.NEW);
        word.fsrsState = new FSRSState(5.0, 0, 1.0, 0, 0);
        
        const decision = policy.decide(word, WordStatus.LEARNING, Rating.AGAIN);
        
        expect(decision.shouldOverrideInterval).assertTrue();
        expect(decision.intervalDays).assertClose(5 / (24 * 60), 0.0001);
        expect(decision.shouldRequeueInSession).assertTrue();
      });

      it('should override with 5-minute interval for AGAIN even after graduation', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 15.0, 0.9, 5, 1); // Graduated word
        
        const decision = policy.decide(word, WordStatus.REVIEW, Rating.AGAIN);
        
        expect(decision.shouldOverrideInterval).assertTrue();
        expect(decision.intervalDays).assertClose(5 / (24 * 60), 0.0001);
      });
    });

    describe('Learning Phase (First 2 Reviews)', () => {
      it('should identify word in learning phase (reps < 2)', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.LEARNING);
        word.fsrsState = new FSRSState(5.0, 3.0, 1.0, 1, 0);
        
        expect(LearningStepsPolicy.isInLearningPhase(word)).assertTrue();
      });

      it('should override HARD with 120-minute interval during learning', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.LEARNING);
        word.fsrsState = new FSRSState(5.0, 1.0, 1.0, 1, 0); // reps = 1
        
        const decision = policy.decide(word, WordStatus.LEARNING, Rating.HARD);
        
        expect(decision.shouldOverrideInterval).assertTrue();
        expect(decision.intervalDays).assertClose(120 / (24 * 60), 0.001);
        expect(decision.shouldRequeueInSession).assertFalse();
        expect(decision.allowReinforcementOnPass).assertTrue();
      });

      it('should trust FSRS for GOOD during learning phase', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.LEARNING);
        word.fsrsState = new FSRSState(5.0, 2.0, 1.0, 1, 0);
        
        const decision = policy.decide(word, WordStatus.LEARNING, Rating.GOOD);
        
        expect(decision.shouldOverrideInterval).assertFalse();
      });

      it('should trust FSRS for EASY during learning phase', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.LEARNING);
        word.fsrsState = new FSRSState(5.0, 5.0, 1.0, 1, 0);
        
        const decision = policy.decide(word, WordStatus.EASY, Rating.EASY);
        
        expect(decision.shouldOverrideInterval).assertFalse();
      });
    });

    describe('Graduation Criteria (reps >= 2)', () => {
      it('should graduate after 2 successful reviews', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 8.0, 0.9, 2, 0); // reps = 2
        
        expect(LearningStepsPolicy.isInLearningPhase(word)).assertFalse();
      });

      it('should trust FSRS for HARD after graduation by reps', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 5.0, 0.9, 2, 0);
        
        const decision = policy.decide(word, WordStatus.REVIEW, Rating.HARD);
        
        expect(decision.shouldOverrideInterval).assertFalse();
      });

      it('should trust FSRS for all ratings after graduation', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 10.0, 0.9, 3, 0);
        
        const goodDecision = policy.decide(word, WordStatus.REVIEW, Rating.GOOD);
        const hardDecision = policy.decide(word, WordStatus.REVIEW, Rating.HARD);
        const easyDecision = policy.decide(word, WordStatus.REVIEW, Rating.EASY);
        
        expect(goodDecision.shouldOverrideInterval).assertFalse();
        expect(hardDecision.shouldOverrideInterval).assertFalse();
        expect(easyDecision.shouldOverrideInterval).assertFalse();
      });
    });

    describe('Graduation Criteria (stability >= 7 days)', () => {
      it('should graduate when stability reaches 7 days', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 7.0, 0.9, 1, 0); // reps=1 but stability=7
        
        expect(LearningStepsPolicy.isInLearningPhase(word)).assertFalse();
      });

      it('should trust FSRS after stability graduation', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 10.0, 0.9, 1, 0); // High stability, low reps
        
        const decision = policy.decide(word, WordStatus.REVIEW, Rating.HARD);
        
        expect(decision.shouldOverrideInterval).assertFalse();
      });
    });

    describe('Edge Cases', () => {
      it('should handle brand new word (reps=0)', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.NEW);
        word.fsrsState = new FSRSState(5.0, 0, 1.0, 0, 0);
        
        const goodDecision = policy.decide(word, WordStatus.LEARNING, Rating.GOOD);
        
        expect(goodDecision.shouldOverrideInterval).assertFalse(); // Trust FSRS initial intervals
      });

      it('should handle word at graduation boundary (reps=2, stability=6.9)', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.LEARNING);
        word.fsrsState = new FSRSState(5.0, 6.9, 0.9, 1, 0);
        
        expect(LearningStepsPolicy.isInLearningPhase(word)).assertTrue(); // Still learning
      });

      it('should handle word just graduated (reps=2, stability=7.0)', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 7.0, 0.9, 2, 0);
        
        expect(LearningStepsPolicy.isInLearningPhase(word)).assertFalse(); // Graduated
      });

      it('should handle word with many lapses but still in learning', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.LEARNING);
        word.fsrsState = new FSRSState(7.0, 2.0, 0.5, 1, 5); // High lapses
        
        expect(LearningStepsPolicy.isInLearningPhase(word)).assertTrue();
        
        const hardDecision = policy.decide(word, WordStatus.LEARNING, Rating.HARD);
        expect(hardDecision.shouldOverrideInterval).assertTrue(); // Still use learning steps
      });
    });

    describe('Status Transitions', () => {
      it('should trust FSRS when transitioning NEW -> REVIEW (rapid learner)', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.NEW);
        word.fsrsState = new FSRSState(3.0, 15.0, 1.0, 0, 0); // Easy word, will get high stability
        
        const decision = policy.decide(word, WordStatus.REVIEW, Rating.EASY);
        
        expect(decision.shouldOverrideInterval).assertFalse();
      });

      it('should apply learning steps for NEW -> LEARNING transition', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.NEW);
        word.fsrsState = new FSRSState(6.0, 0, 1.0, 0, 0);
        
        const hardDecision = policy.decide(word, WordStatus.LEARNING, Rating.HARD);
        
        expect(hardDecision.shouldOverrideInterval).assertTrue();
      });
    });

    describe('Consistency with FSRS v5', () => {
      it('should not interfere with FSRS intervals for graduated words', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.REVIEW);
        word.fsrsState = new FSRSState(5.0, 30.0, 0.9, 5, 0);
        
        const ratings = [Rating.HARD, Rating.GOOD, Rating.EASY];
        
        for (const rating of ratings) {
          const decision = policy.decide(word, WordStatus.REVIEW, rating);
          expect(decision.shouldOverrideInterval).assertFalse();
        }
      });

      it('should allow FSRS to calculate intervals for first GOOD review', 0, () => {
        const word = new WordItem(1, 'test', WordStatus.NEW);
        word.fsrsState = new FSRSState(5.0, 0, 1.0, 0, 0);
        
        const decision = policy.decide(word, WordStatus.LEARNING, Rating.GOOD);
        
        // FSRS v5 will calculate initial stability w[2] = 3.173 days
        expect(decision.shouldOverrideInterval).assertFalse();
      });
    });
  });
}
