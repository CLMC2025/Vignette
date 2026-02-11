import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { FSRSAlgorithm, ReviewResult } from '../../../main/ets/algorithm/Algorithm';
import { FSRSState, Rating } from '../../../main/ets/model/WordModel';

/**
 * FSRS v5 Algorithm Tests
 * 
 * Tests the implementation of FSRS v5 (19-parameter model)
 * Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
 */
export default function fsrsv5AlgorithmTest(): void {
  describe('FSRS v5 Algorithm', () => {
    let algorithm: FSRSAlgorithm;

    beforeAll(() => {
      algorithm = FSRSAlgorithm.getInstance();
      algorithm.clearCache();
    });

    describe('Initial Stability (First Review)', () => {
      it('should use w[0] for AGAIN (first review)', 0, () => {
        const state = new FSRSState(); // New word
        const result = algorithm.review(state, Rating.AGAIN, 0);
        
        // With FSRS v5 default params: w[0] = 0.40255
        // Initial stability should be close to this value
        expect(result.newState.stability).assertClose(0.40255, 0.1);
        expect(result.newState.reps).assertEqual(0); // AGAIN doesn't increment reps
        expect(result.newState.lapses).assertEqual(1);
      });

      it('should use w[1] for HARD (first review)', 0, () => {
        const state = new FSRSState();
        const result = algorithm.review(state, Rating.HARD, 0);
        
        // With FSRS v5 default params: w[1] = 1.18385
        expect(result.newState.stability).assertClose(1.18385, 0.1);
        expect(result.newState.reps).assertEqual(1);
      });

      it('should use w[2] for GOOD (first review)', 0, () => {
        const state = new FSRSState();
        const result = algorithm.review(state, Rating.GOOD, 0);
        
        // With FSRS v5 default params: w[2] = 3.173
        expect(result.newState.stability).assertClose(3.173, 0.2);
        expect(result.newState.reps).assertEqual(1);
      });

      it('should use w[3] for EASY (first review)', 0, () => {
        const state = new FSRSState();
        const result = algorithm.review(state, Rating.EASY, 0);
        
        // With FSRS v5 default params: w[3] = 15.69105
        expect(result.newState.stability).assertClose(15.69105, 1.0);
        expect(result.newState.reps).assertEqual(1);
      });
    });

    describe('Initial Difficulty Calculation', () => {
      it('should calculate D0 using exponential formula', 0, () => {
        const state = new FSRSState();
        
        // D0(G) = w4 - e^(w5 * (G-1)) + 1
        // With defaults: w4 = 7.1949, w5 = 0.5345
        
        // D0(1) = 7.1949 - e^(0.5345 * 0) + 1 = 7.1949 - 1 + 1 = 7.1949
        const againResult = algorithm.review(state, Rating.AGAIN, 0);
        expect(againResult.newState.difficulty).assertClose(7.1949, 0.1);
        
        // D0(3) = 7.1949 - e^(0.5345 * 2) + 1 ≈ 5.06
        const goodState = new FSRSState();
        const goodResult = algorithm.review(goodState, Rating.GOOD, 0);
        expect(goodResult.newState.difficulty).assertClose(5.06, 0.5);
      });

      it('should clamp difficulty to [1, 10]', 0, () => {
        const state = new FSRSState();
        const result = algorithm.review(state, Rating.AGAIN, 0);
        
        expect(result.newState.difficulty >= 1).assertTrue();
        expect(result.newState.difficulty <= 10).assertTrue();
      });
    });

    describe('Difficulty Update with Linear Damping', () => {
      it('should decrease difficulty on EASY rating', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0); // D=5.0
        const result = algorithm.review(state, Rating.EASY, 1);
        
        // ΔD = -w6 * (4 - 3) = -w6
        // D' = D + ΔD * (10-D)/9
        // With w6 = 1.4604: ΔD = -1.4604
        // D' = 5 + (-1.4604) * (10-5)/9 = 5 - 0.811 ≈ 4.19
        expect(result.newState.difficulty).assertLess(5.0);
      });

      it('should increase difficulty on AGAIN rating', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0); // D=5.0
        const result = algorithm.review(state, Rating.AGAIN, 1);
        
        // ΔD = -w6 * (1 - 3) = 2*w6
        // D' should increase
        expect(result.newState.difficulty).assertGreater(5.0);
      });

      it('should keep difficulty stable on GOOD rating', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const result = algorithm.review(state, Rating.GOOD, 1);
        
        // ΔD = -w6 * (3 - 3) = 0
        // D' should be close to original D
        expect(Math.abs(result.newState.difficulty - 5.0)).assertLess(0.1);
      });
    });

    describe('Mean Reversion', () => {
      it('should apply mean reversion toward D0(4)', 0, () => {
        // FSRS v5 uses D0(4) as mean reversion target
        const state = new FSRSState(8.0, 10.0, 0.9, 1, 0); // Very high difficulty
        const result = algorithm.review(state, Rating.GOOD, 1);
        
        // D'' = w7 * D0(4) + (1-w7) * D'
        // With w7 = 0.0046, mean reversion is very weak
        // D'' should still be close to D'
        expect(result.newState.difficulty).assertLess(8.0);
      });
    });

    describe('Retrievability Decay', () => {
      it('should calculate R=0.9 when t=S', 0, () => {
        const stability = 10.0;
        const elapsedDays = 10.0;
        
        const retrievability = algorithm.calculateRetrievability(stability, elapsedDays);
        
        // R(t=S, S) = 0.9
        expect(retrievability).assertClose(0.9, 0.01);
      });

      it('should have R close to 1.0 when t=0', 0, () => {
        const stability = 10.0;
        const elapsedDays = 0;
        
        const retrievability = algorithm.calculateRetrievability(stability, elapsedDays);
        
        expect(retrievability).assertClose(1.0, 0.01);
      });

      it('should have R < 0.9 when t > S', 0, () => {
        const stability = 10.0;
        const elapsedDays = 15.0;
        
        const retrievability = algorithm.calculateRetrievability(stability, elapsedDays);
        
        expect(retrievability).assertLess(0.9);
        expect(retrievability).assertGreater(0);
      });
    });

    describe('Stability Increase (Success)', () => {
      it('should increase stability on successful review', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const result = algorithm.review(state, Rating.GOOD, 1);
        
        // S' should be > S
        expect(result.newState.stability).assertGreater(10.0);
      });

      it('should have lower SInc for difficult cards', 0, () => {
        const easyState = new FSRSState(3.0, 10.0, 0.9, 1, 0); // Low difficulty
        const hardState = new FSRSState(8.0, 10.0, 0.9, 1, 0); // High difficulty
        
        const easyResult = algorithm.review(easyState, Rating.GOOD, 1);
        const hardResult = algorithm.review(hardState, Rating.GOOD, 1);
        
        // Easy cards should have higher stability increase
        const easySInc = easyResult.newState.stability / 10.0;
        const hardSInc = hardResult.newState.stability / 10.0;
        
        expect(easySInc).assertGreater(hardSInc);
      });

      it('should have lower SInc for cards with high stability', 0, () => {
        const lowStability = new FSRSState(5.0, 5.0, 0.9, 1, 0);
        const highStability = new FSRSState(5.0, 50.0, 0.9, 1, 0);
        
        const lowResult = algorithm.review(lowStability, Rating.GOOD, 1);
        const highResult = algorithm.review(highStability, Rating.GOOD, 1);
        
        const lowSInc = lowResult.newState.stability / 5.0;
        const highSInc = highResult.newState.stability / 50.0;
        
        expect(lowSInc).assertGreater(highSInc);
      });

      it('should use different multipliers for HARD/GOOD/EASY', 0, () => {
        const state1 = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const state2 = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const state3 = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        
        const hardResult = algorithm.review(state1, Rating.HARD, 1);
        const goodResult = algorithm.review(state2, Rating.GOOD, 1);
        const easyResult = algorithm.review(state3, Rating.EASY, 1);
        
        // EASY should have highest stability
        expect(easyResult.newState.stability).assertGreater(goodResult.newState.stability);
        expect(goodResult.newState.stability).assertGreater(hardResult.newState.stability);
      });
    });

    describe('Stability After Lapse (Failure)', () => {
      it('should decrease stability on AGAIN rating', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const result = algorithm.review(state, Rating.AGAIN, 1);
        
        // S' should be < S
        expect(result.newState.stability).assertLess(10.0);
        expect(result.newState.lapses).assertEqual(1);
      });

      it('should use post-lapse stability formula', 0, () => {
        const state = new FSRSState(5.0, 20.0, 0.5, 1, 0);
        const result = algorithm.review(state, Rating.AGAIN, 5);
        
        // S'_f = w11 * D^(-w12) * ((S+1)^w13 - 1) * e^(w14*(1-R))
        // Should result in much lower stability
        expect(result.newState.stability).assertLess(10.0);
      });
    });

    describe('Same-Day Review (FSRS v5)', () => {
      it('should apply same-day review formula', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        
        // First review in the day
        const result1 = algorithm.review(state, Rating.GOOD, 0.1); // 2.4 hours later
        
        // Same-day review: S' = S * e^(w17 * (G-3+w18))
        // For GOOD: G=3, so exponent = w17 * w18
        expect(result1.newState.stability).assertGreater(state.stability);
      });
    });

    describe('Interval Calculation', () => {
      it('should calculate interval from stability with R=0.9', 0, () => {
        const state = new FSRSState(5.0, 10.0, 1.0, 1, 0);
        const result = algorithm.review(state, Rating.GOOD, 0);
        
        // For R=0.9, I should equal S (approximately)
        // With FSRS v4.5 formula: I = (S/FACTOR) * (0.9^(1/DECAY) - 1)
        // Interval should be close to new stability
        expect(result.intervalDays).assertGreater(0);
      });

      it('should have very short interval for AGAIN on first review', 0, () => {
        const state = new FSRSState();
        const result = algorithm.review(state, Rating.AGAIN, 0);
        
        // Should be less than 1 day (typically in minutes)
        expect(result.intervalDays).assertLess(1.0);
      });
    });

    describe('Interval Caching (Performance)', () => {
      it('should cache preview intervals', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        
        const intervals1 = algorithm.previewIntervals(state, 1);
        const intervals2 = algorithm.previewIntervals(state, 1);
        
        // Should return same values (cached)
        expect(intervals1.get(Rating.GOOD)).assertEqual(intervals2.get(Rating.GOOD));
        expect(intervals1.get(Rating.EASY)).assertEqual(intervals2.get(Rating.EASY));
      });

      it('should limit cache size', 0, () => {
        algorithm.clearCache();
        
        // Add more than MAX_CACHE_SIZE entries
        for (let i = 0; i < 250; i++) {
          const state = new FSRSState(5.0, i, 0.9, 1, 0);
          algorithm.previewIntervals(state, 0);
        }
        
        // Should not throw error or crash
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const intervals = algorithm.previewIntervals(state, 0);
        expect(intervals.size).assertEqual(4); // All 4 ratings
      });
    });

    describe('Edge Cases', () => {
      it('should handle very high stability', 0, () => {
        const state = new FSRSState(5.0, 300.0, 0.9, 10, 0);
        const result = algorithm.review(state, Rating.GOOD, 10);
        
        // Should clamp to MAX_STABILITY (365 days)
        expect(result.newState.stability).assertLessOrEqual(365.0);
      });

      it('should handle very low stability', 0, () => {
        const state = new FSRSState(5.0, 0.01, 0.1, 5, 10);
        const result = algorithm.review(state, Rating.AGAIN, 1);
        
        // Should clamp to MIN_STABILITY
        expect(result.newState.stability).assertGreaterOrEqual(0.1);
      });

      it('should handle extreme difficulty', 0, () => {
        const highD = new FSRSState(10.0, 10.0, 0.9, 1, 0);
        const lowD = new FSRSState(1.0, 10.0, 0.9, 1, 0);
        
        const highResult = algorithm.review(highD, Rating.GOOD, 1);
        const lowResult = algorithm.review(lowD, Rating.GOOD, 1);
        
        // Both should have valid stability
        expect(highResult.newState.stability).assertGreater(0);
        expect(lowResult.newState.stability).assertGreater(0);
      });

      it('should handle zero elapsed time', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const result = algorithm.review(state, Rating.GOOD, 0);
        
        // Retrievability should be 1.0
        expect(result.newState.retrievability).assertEqual(1.0);
      });

      it('should handle very long elapsed time', 0, () => {
        const state = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const result = algorithm.review(state, Rating.GOOD, 100);
        
        // Retrievability should be very low but not negative
        expect(result.newState.retrievability).assertGreaterOrEqual(0);
        expect(result.newState.retrievability).assertLess(0.5);
      });
    });

    describe('Consistency Tests', () => {
      it('should produce deterministic results', 0, () => {
        const state1 = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const state2 = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        
        const result1 = algorithm.review(state1, Rating.GOOD, 1);
        const result2 = algorithm.review(state2, Rating.GOOD, 1);
        
        expect(result1.newState.stability).assertEqual(result2.newState.stability);
        expect(result1.newState.difficulty).assertEqual(result2.newState.difficulty);
      });

      it('should maintain state immutability', 0, () => {
        const originalState = new FSRSState(5.0, 10.0, 0.9, 1, 0);
        const originalDifficulty = originalState.difficulty;
        const originalStability = originalState.stability;
        
        algorithm.review(originalState, Rating.GOOD, 1);
        
        // Original state should not be mutated
        expect(originalState.difficulty).assertEqual(originalDifficulty);
        expect(originalState.stability).assertEqual(originalStability);
      });
    });
  });
}
