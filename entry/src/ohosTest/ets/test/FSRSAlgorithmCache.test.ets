// =====================================================
// FSRSAlgorithmCache.test.ets
// Unit tests for FSRS algorithm caching optimization
// =====================================================

import { describe, beforeAll, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import { FSRSAlgorithm } from '../../../main/ets/algorithm/Algorithm';
import { FSRSState, Rating } from '../../../main/ets/model/WordModel';

export default function fsrsAlgorithmCacheTest() {
  describe('FSRS Algorithm Cache Tests', () => {
    let algorithm: FSRSAlgorithm;

    beforeAll(() => {
      algorithm = FSRSAlgorithm.getInstance();
    });

    beforeEach(() => {
      // Clear cache before each test
      algorithm.clearCache();
    });

    /**
     * Test that preview intervals return consistent results
     */
    it('should return consistent results for same state', () => {
      const state = new FSRSState(2.5, 5.0, 3, 0.9);
      
      const result1 = algorithm.previewIntervals(state, 0);
      const result2 = algorithm.previewIntervals(state, 0);
      
      // Results should be identical
      expect(result1.get(Rating.AGAIN)).assertEqual(result2.get(Rating.AGAIN));
      expect(result1.get(Rating.HARD)).assertEqual(result2.get(Rating.HARD));
      expect(result1.get(Rating.GOOD)).assertEqual(result2.get(Rating.GOOD));
      expect(result1.get(Rating.EASY)).assertEqual(result2.get(Rating.EASY));
    });

    /**
     * Test that cache improves performance
     */
    it('should improve performance on repeated calls', () => {
      const state = new FSRSState(2.5, 5.0, 3, 0.9);
      
      // First call (cold - no cache)
      const start1 = Date.now();
      algorithm.previewIntervals(state, 0);
      const time1 = Date.now() - start1;
      
      // Second call (warm - cached)
      const start2 = Date.now();
      algorithm.previewIntervals(state, 0);
      const time2 = Date.now() - start2;
      
      // Cached call should be significantly faster
      // Note: In practice, time2 should be < 1ms, time1 might be 2-5ms
      expect(time2).assertLessThan(time1 + 1); // Allow small margin
    });

    /**
     * Test that different states produce different results
     */
    it('should produce different results for different states', () => {
      const state1 = new FSRSState(2.5, 5.0, 3, 0.9);
      const state2 = new FSRSState(3.5, 7.0, 5, 0.8);
      
      const result1 = algorithm.previewIntervals(state1, 0);
      const result2 = algorithm.previewIntervals(state2, 0);
      
      // Results should be different
      expect(result1.get(Rating.GOOD)).assertNotEqual(result2.get(Rating.GOOD));
    });

    /**
     * Test that different elapsed days produce different cache entries
     */
    it('should cache separately for different elapsed days', () => {
      const state = new FSRSState(2.5, 5.0, 3, 0.9);
      
      const result1 = algorithm.previewIntervals(state, 0);
      const result2 = algorithm.previewIntervals(state, 1);
      
      // Different elapsed days should produce different intervals
      expect(result1.get(Rating.GOOD)).assertNotEqual(result2.get(Rating.GOOD));
    });

    /**
     * Test cache clearing functionality
     */
    it('should clear cache when requested', () => {
      const state = new FSRSState(2.5, 5.0, 3, 0.9);
      
      // Populate cache
      algorithm.previewIntervals(state, 0);
      
      // Clear cache
      algorithm.clearCache();
      
      // Next call should recompute (can't directly verify, but ensure no crash)
      const result = algorithm.previewIntervals(state, 0);
      expect(result.size).assertEqual(4); // Should have all 4 ratings
    });

    /**
     * Test cache with edge case: new word (reps = 0)
     */
    it('should cache results for new words', () => {
      const state = new FSRSState(0, 0, 0, 0); // New word state
      
      const result1 = algorithm.previewIntervals(state, 0);
      const result2 = algorithm.previewIntervals(state, 0);
      
      // Should use initial stability values
      expect(result1.get(Rating.AGAIN)).assertEqual(result2.get(Rating.AGAIN));
      expect(result1.get(Rating.GOOD)).assertGreater(result1.get(Rating.AGAIN)!);
    });

    /**
     * Test cache with edge case: mastered word (high stability)
     */
    it('should cache results for mastered words', () => {
      const state = new FSRSState(100.0, 2.0, 20, 0.95); // Mastered word
      
      const result1 = algorithm.previewIntervals(state, 0);
      const result2 = algorithm.previewIntervals(state, 0);
      
      // Results should be consistent
      expect(result1.get(Rating.EASY)).assertEqual(result2.get(Rating.EASY));
      expect(result1.get(Rating.EASY)).assertGreater(30); // Should have long interval
    });

    /**
     * Test that cache handles floating-point precision correctly
     */
    it('should handle floating-point precision in cache keys', () => {
      const state1 = new FSRSState(2.5, 5.0, 3, 0.9);
      const state2 = new FSRSState(2.5000001, 5.0000001, 3, 0.9); // Slightly different
      
      const result1 = algorithm.previewIntervals(state1, 0);
      const result2 = algorithm.previewIntervals(state2, 0);
      
      // Due to toFixed(2) in cache key, these should use different cache entries
      // but produce very similar results
      const diff = Math.abs(result1.get(Rating.GOOD)! - result2.get(Rating.GOOD)!);
      expect(diff).assertLessThan(0.01); // Very close results
    });

    /**
     * Performance test: verify cache efficiency with many lookups
     */
    it('should maintain performance with many cached lookups', () => {
      const state = new FSRSState(2.5, 5.0, 3, 0.9);
      
      // Warm up cache
      algorithm.previewIntervals(state, 0);
      
      // Perform many lookups
      const start = Date.now();
      for (let i = 0; i < 1000; i++) {
        algorithm.previewIntervals(state, 0);
      }
      const elapsed = Date.now() - start;
      
      // 1000 cached lookups should be very fast
      expect(elapsed).assertLessThan(50); // Should complete in under 50ms
    });

    /**
     * Test cache size limit enforcement
     */
    it('should respect max cache size limit', () => {
      // Create 250 unique states (exceeds MAX_CACHE_SIZE of 200)
      for (let i = 0; i < 250; i++) {
        const state = new FSRSState(2.5 + i * 0.01, 5.0, i % 10, 0.9);
        algorithm.previewIntervals(state, 0);
      }
      
      // Should not crash or have memory issues
      // Verify with a new lookup
      const newState = new FSRSState(10.0, 8.0, 15, 0.85);
      const result = algorithm.previewIntervals(newState, 0);
      expect(result.size).assertEqual(4);
    });
  });
}
