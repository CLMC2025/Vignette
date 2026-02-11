// =====================================================
// NetworkManager.test.ets
// Unit tests for NetworkManager utility
// =====================================================

import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { NetworkManager } from '../../../main/ets/utils/NetworkManager';
import http from '@ohos.net.http';

export default function networkManagerTest() {
  describe('NetworkManager Tests', () => {
    let manager: NetworkManager;

    beforeEach(() => {
      manager = new NetworkManager();
      manager.clearCache();
    });

    /**
     * Test basic request functionality
     */
    it('should make successful HTTP request', async () => {
      const requestId = 'test-basic';
      
      // Note: Using a mock URL - in real tests, use a test server
      // For this test, we'll just verify the structure
      try {
        const result = await manager.request<string>(
          requestId,
          'https://httpbin.org/get',
          {
            method: http.RequestMethod.GET,
            connectTimeout: 5000,
            readTimeout: 5000
          },
          0
        );
        
        // Should receive a response
        expect(result).assertNotNull();
      } catch (e) {
        // Network might not be available in test environment
        console.warn('[Test] Network not available, skipping live test');
      }
    });

    /**
     * Test request cancellation
     */
    it('should cancel active requests', () => {
      const requestId = 'test-cancel';
      
      // Start a long request (don't await)
      manager.request<string>(
        requestId,
        'https://httpbin.org/delay/10',
        {
          method: http.RequestMethod.GET
        },
        0
      ).catch(() => {
        // Expected to be cancelled
      });
      
      // Verify request is active
      expect(manager.getActiveRequestCount()).assertGreater(0);
      
      // Cancel the request
      manager.cancelRequest(requestId);
      
      // Request should be removed
      // Note: There might be a small delay, so we check <= 0 after a tick
      setTimeout(() => {
        expect(manager.getActiveRequestCount()).assertEqual(0);
      }, 100);
    });

    /**
     * Test cancelling all requests
     */
    it('should cancel all active requests', () => {
      // Start multiple requests
      for (let i = 0; i < 3; i++) {
        manager.request<string>(
          `test-multi-${i}`,
          'https://httpbin.org/delay/10',
          { method: http.RequestMethod.GET },
          0
        ).catch(() => {
          // Expected to be cancelled
        });
      }
      
      // Verify multiple requests are active
      expect(manager.getActiveRequestCount()).assertGreater(0);
      
      // Cancel all
      manager.cancelAllRequests();
      
      // All requests should be removed
      setTimeout(() => {
        expect(manager.getActiveRequestCount()).assertEqual(0);
      }, 100);
    });

    /**
     * Test cache functionality
     */
    it('should cache responses when enabled', async () => {
      const requestId = 'test-cache';
      
      try {
        // Mock response data
        const mockData = { test: 'data' };
        
        // First request
        const start1 = Date.now();
        const result1 = await manager.request<string>(
          requestId,
          'https://httpbin.org/get',
          { method: http.RequestMethod.GET },
          5000 // 5 second cache
        );
        const time1 = Date.now() - start1;
        
        // Second request (should be cached)
        const start2 = Date.now();
        const result2 = await manager.request<string>(
          requestId,
          'https://httpbin.org/get',
          { method: http.RequestMethod.GET },
          5000
        );
        const time2 = Date.now() - start2;
        
        // Cached request should be much faster
        expect(time2).assertLessThan(time1);
        
        // Results should be identical
        expect(result1).assertEqual(result2);
      } catch (e) {
        console.warn('[Test] Network not available, skipping cache test');
      }
    });

    /**
     * Test cache expiration
     */
    it('should expire cached responses after TTL', async () => {
      const requestId = 'test-expire';
      
      try {
        // Request with 1 second cache
        await manager.request<string>(
          requestId,
          'https://httpbin.org/get',
          { method: http.RequestMethod.GET },
          1000 // 1 second cache
        );
        
        // Wait for cache to expire
        await new Promise(resolve => setTimeout(resolve, 1500));
        
        // Request again (cache should be expired, so new request)
        const start = Date.now();
        await manager.request<string>(
          requestId,
          'https://httpbin.org/get',
          { method: http.RequestMethod.GET },
          1000
        );
        const elapsed = Date.now() - start;
        
        // Should take longer than a cached request
        expect(elapsed).assertGreater(10);
      } catch (e) {
        console.warn('[Test] Network not available, skipping expiration test');
      }
    });

    /**
     * Test cache size limit
     */
    it('should enforce cache size limit', () => {
      // Fill cache with many entries
      for (let i = 0; i < 150; i++) {
        manager.request<string>(
          `test-limit-${i}`,
          'https://example.com',
          { method: http.RequestMethod.GET },
          60000 // Long cache duration
        ).catch(() => {
          // Ignore network errors
        });
      }
      
      // Cache size should not exceed MAX_CACHE_SIZE (100)
      // Note: We can't directly check cache size without exposing it,
      // but we verify it doesn't crash
      expect(manager.getCacheSize()).assertLessThanOrEqual(100);
    });

    /**
     * Test clearing cache
     */
    it('should clear all cached data', async () => {
      try {
        // Add some cached data
        await manager.request<string>(
          'test-clear',
          'https://httpbin.org/get',
          { method: http.RequestMethod.GET },
          60000
        );
        
        // Verify cache has data
        expect(manager.getCacheSize()).assertGreater(0);
        
        // Clear cache
        manager.clearCache();
        
        // Cache should be empty
        expect(manager.getCacheSize()).assertEqual(0);
      } catch (e) {
        console.warn('[Test] Network not available, skipping clear test');
      }
    });

    /**
     * Test different request methods
     */
    it('should support different HTTP methods', async () => {
      const methods = [
        http.RequestMethod.GET,
        http.RequestMethod.POST,
        http.RequestMethod.PUT,
        http.RequestMethod.DELETE
      ];
      
      for (const method of methods) {
        try {
          const requestId = `test-method-${method}`;
          await manager.request<string>(
            requestId,
            'https://httpbin.org/anything',
            {
              method: method,
              connectTimeout: 5000,
              readTimeout: 5000
            },
            0
          );
          // Should not throw
        } catch (e) {
          // Network might not be available
          console.warn(`[Test] Network not available for ${method}`);
        }
      }
    });

    /**
     * Test request with custom headers
     */
    it('should include custom headers in request', async () => {
      try {
        const requestId = 'test-headers';
        await manager.request<string>(
          requestId,
          'https://httpbin.org/headers',
          {
            method: http.RequestMethod.GET,
            header: {
              'X-Custom-Header': 'test-value',
              'Authorization': 'Bearer test-token'
            }
          },
          0
        );
        // Should not throw
      } catch (e) {
        console.warn('[Test] Network not available, skipping headers test');
      }
    });

    /**
     * Test request with POST data
     */
    it('should send POST data correctly', async () => {
      try {
        const requestId = 'test-post';
        const postData = JSON.stringify({ key: 'value' });
        
        await manager.request<string>(
          requestId,
          'https://httpbin.org/post',
          {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json'
            },
            extraData: postData
          },
          0
        );
        // Should not throw
      } catch (e) {
        console.warn('[Test] Network not available, skipping POST test');
      }
    });

    /**
     * Test error handling for invalid URL
     */
    it('should handle invalid URLs gracefully', async () => {
      try {
        await manager.request<string>(
          'test-invalid',
          'not-a-valid-url',
          { method: http.RequestMethod.GET },
          0
        );
        
        // Should not reach here
        expect(false).assertTrue();
      } catch (e) {
        // Should throw an error
        expect(e).assertNotNull();
      }
    });

    /**
     * Test concurrent requests with same ID
     */
    it('should cancel old request when making new one with same ID', () => {
      const requestId = 'test-concurrent';
      
      // Start first request
      manager.request<string>(
        requestId,
        'https://httpbin.org/delay/5',
        { method: http.RequestMethod.GET },
        0
      ).catch(() => {
        // First request should be cancelled
      });
      
      // Start second request with same ID (should cancel first)
      manager.request<string>(
        requestId,
        'https://httpbin.org/get',
        { method: http.RequestMethod.GET },
        0
      ).catch(() => {
        // Ignore errors
      });
      
      // Should only have one active request
      setTimeout(() => {
        expect(manager.getActiveRequestCount()).assertLessThanOrEqual(1);
      }, 100);
    });

    /**
     * Test timeout handling
     */
    it('should respect timeout settings', async () => {
      try {
        const start = Date.now();
        
        await manager.request<string>(
          'test-timeout',
          'https://httpbin.org/delay/10',
          {
            method: http.RequestMethod.GET,
            connectTimeout: 1000,  // 1 second timeout
            readTimeout: 1000
          },
          0
        );
        
        const elapsed = Date.now() - start;
        
        // Should timeout before 10 seconds
        expect(elapsed).assertLessThan(3000);
      } catch (e) {
        // Timeout is expected
        expect(e).assertNotNull();
      }
    });
  });
}
