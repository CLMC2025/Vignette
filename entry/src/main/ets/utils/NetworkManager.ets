// =====================================================
// NetworkManager.ets - Unified HTTP request manager
// Provides request lifecycle management, caching, and cancellation
// =====================================================

import http from '@ohos.net.http';

/**
 * Cached response with expiration
 */
class CachedResponse<T> {
  data: T;
  expiresAt: number;

  constructor(data: T, expiresAt: number) {
    this.data = data;
    this.expiresAt = expiresAt;
  }

  isExpired(): boolean {
    return Date.now() > this.expiresAt;
  }
}

/**
 * Network request options
 */
export interface NetworkRequestOptions {
  method?: http.RequestMethod;
  header?: Record<string, string>;
  extraData?: string | Object;
  connectTimeout?: number;
  readTimeout?: number;
  expectDataType?: http.HttpDataType;
}

/**
 * Unified network manager with lifecycle management
 */
export class NetworkManager {
  private activeRequests: Map<string, http.HttpRequest> = new Map<string, http.HttpRequest>();
  private cache: Map<string, CachedResponse<unknown>> = new Map<string, CachedResponse<unknown>>();
  private readonly MAX_CACHE_SIZE: number = 100;

  /**
   * Make an HTTP request with automatic lifecycle management
   * @param requestId Unique identifier for this request (used for cancellation and caching)
   * @param url Request URL
   * @param options Request options
   * @param cacheDurationMs Cache duration in milliseconds (0 to disable caching)
   * @returns Parsed response data
   */
  async request<T>(
    requestId: string,
    url: string,
    options: NetworkRequestOptions = {},
    cacheDurationMs: number = 0
  ): Promise<T> {
    // Check cache first
    if (cacheDurationMs > 0) {
      const cached = this.getCached<T>(requestId);
      if (cached !== null) {
        console.info(`[NetworkManager] Cache hit for ${requestId}`);
        return cached;
      }
    }

    // Cancel any existing request with the same ID
    this.cancelRequest(requestId);

    // Create new HTTP request
    const httpRequest = http.createHttp();
    this.activeRequests.set(requestId, httpRequest);

    try {
      // Set default options
      const requestOptions: http.HttpRequestOptions = {
        method: options.method ?? http.RequestMethod.GET,
        header: options.header ?? {},
        extraData: options.extraData,
        connectTimeout: options.connectTimeout ?? 15000,
        readTimeout: options.readTimeout ?? 20000,
        expectDataType: options.expectDataType ?? http.HttpDataType.STRING
      };

      console.info(`[NetworkManager] Request ${requestId}: ${options.method ?? 'GET'} ${url}`);
      
      const response = await httpRequest.request(url, requestOptions);

      // Check response status
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
      }

      const data = response.result as T;

      // Cache the result if requested
      if (cacheDurationMs > 0) {
        this.setCached<T>(requestId, data, cacheDurationMs);
      }

      return data;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error(`[NetworkManager] Request ${requestId} failed: ${errorMsg}`);
      throw error;
    } finally {
      // Clean up
      this.activeRequests.delete(requestId);
      httpRequest.destroy();
    }
  }

  /**
   * Cancel a specific request
   * @param requestId Request ID to cancel
   */
  cancelRequest(requestId: string): void {
    const req = this.activeRequests.get(requestId);
    if (req !== undefined) {
      console.info(`[NetworkManager] Cancelling request: ${requestId}`);
      req.destroy();
      this.activeRequests.delete(requestId);
    }
  }

  /**
   * Cancel all active requests
   * Call this when a page is being destroyed
   */
  cancelAllRequests(): void {
    console.info(`[NetworkManager] Cancelling ${this.activeRequests.size} active requests`);
    this.activeRequests.forEach((req: http.HttpRequest) => {
      req.destroy();
    });
    this.activeRequests.clear();
  }

  /**
   * Get cached data if available and not expired
   */
  private getCached<T>(key: string): T | null {
    const cached = this.cache.get(key);
    if (cached === undefined) {
      return null;
    }

    if (cached.isExpired()) {
      this.cache.delete(key);
      return null;
    }

    return cached.data as T;
  }

  /**
   * Store data in cache
   */
  private setCached<T>(key: string, data: T, durationMs: number): void {
    // Enforce cache size limit
    if (this.cache.size >= this.MAX_CACHE_SIZE) {
      // Remove oldest entry (first key)
      const firstKey = this.cache.keys().next().value;
      if (firstKey !== undefined) {
        this.cache.delete(firstKey);
      }
    }

    const expiresAt = Date.now() + durationMs;
    this.cache.set(key, new CachedResponse<T>(data, expiresAt));
  }

  /**
   * Clear all cached data
   */
  clearCache(): void {
    this.cache.clear();
  }

  /**
   * Get number of active requests
   */
  getActiveRequestCount(): number {
    return this.activeRequests.size;
  }

  /**
   * Get cache size
   */
  getCacheSize(): number {
    return this.cache.size;
  }
}
