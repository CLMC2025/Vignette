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
 * Retry configuration
 */
export interface RetryConfig {
  maxRetries?: number;           // Maximum number of retry attempts (default: 3)
  initialDelayMs?: number;       // Initial delay before first retry (default: 1000ms)
  maxDelayMs?: number;          // Maximum delay between retries (default: 30000ms)
  backoffMultiplier?: number;   // Exponential backoff multiplier (default: 2.0)
  retryableStatusCodes?: number[]; // HTTP status codes that should trigger retry (default: [408, 429, 500, 502, 503, 504])
}

/**
 * Unified network manager with lifecycle management
 * Features:
 * - Automatic retry with exponential backoff
 * - Request lifecycle management (cancellation)
 * - Response caching with TTL
 * - Request deduplication
 */
export class NetworkManager {
  private activeRequests: Map<string, http.HttpRequest> = new Map<string, http.HttpRequest>();
  private cache: Map<string, CachedResponse<unknown>> = new Map<string, CachedResponse<unknown>>();
  private readonly MAX_CACHE_SIZE: number = 100;
  
  // Default retry configuration
  private defaultRetryConfig: RetryConfig = {
    maxRetries: 3,
    initialDelayMs: 1000,
    maxDelayMs: 30000,
    backoffMultiplier: 2.0,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504]
  };

  /**
   * Make an HTTP request with automatic lifecycle management and retry
   * @param requestId Unique identifier for this request (used for cancellation and caching)
   * @param url Request URL
   * @param options Request options
   * @param cacheDurationMs Cache duration in milliseconds (0 to disable caching)
   * @param retryConfig Retry configuration (undefined to use defaults)
   * @returns Parsed response data
   */
  async request<T>(
    requestId: string,
    url: string,
    options: NetworkRequestOptions = {},
    cacheDurationMs: number = 0,
    retryConfig?: RetryConfig
  ): Promise<T> {
    // Check cache first
    if (cacheDurationMs > 0) {
      const cached = this.getCached<T>(requestId);
      if (cached !== null) {
        console.info(`[NetworkManager] Cache hit for ${requestId}`);
        return cached;
      }
    }

    // Use default retry config if not provided
    const config: Required<RetryConfig> = {
      maxRetries: retryConfig?.maxRetries ?? this.defaultRetryConfig.maxRetries!,
      initialDelayMs: retryConfig?.initialDelayMs ?? this.defaultRetryConfig.initialDelayMs!,
      maxDelayMs: retryConfig?.maxDelayMs ?? this.defaultRetryConfig.maxDelayMs!,
      backoffMultiplier: retryConfig?.backoffMultiplier ?? this.defaultRetryConfig.backoffMultiplier!,
      retryableStatusCodes: retryConfig?.retryableStatusCodes ?? this.defaultRetryConfig.retryableStatusCodes!
    };

    let lastError: Error | null = null;
    
    for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        // Make the request
        const data = await this.makeRequest<T>(requestId, url, options);
        
        // Cache the result if requested
        if (cacheDurationMs > 0) {
          this.setCached<T>(requestId, data, cacheDurationMs);
        }
        
        return data;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        
        // Check if we should retry
        const shouldRetry = this.shouldRetryError(lastError, config.retryableStatusCodes);
        
        if (!shouldRetry || attempt >= config.maxRetries) {
          // No more retries, throw the error
          console.error(`[NetworkManager] Request ${requestId} failed after ${attempt + 1} attempts: ${lastError.message}`);
          throw lastError;
        }
        
        // Calculate delay with exponential backoff
        const delayMs = Math.min(
          config.initialDelayMs * Math.pow(config.backoffMultiplier, attempt),
          config.maxDelayMs
        );
        
        console.warn(`[NetworkManager] Request ${requestId} failed (attempt ${attempt + 1}/${config.maxRetries + 1}), retrying in ${delayMs}ms: ${lastError.message}`);
        
        // Wait before retrying
        await this.sleep(delayMs);
      }
    }
    
    // Should never reach here, but satisfy TypeScript
    throw lastError!;
  }

  /**
   * Make a single HTTP request without retry logic
   * @private
   */
  private async makeRequest<T>(
    requestId: string,
    url: string,
    options: NetworkRequestOptions
  ): Promise<T> {
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
      if (response.responseCode !== 200 && response.responseCode !== 201) {
        const error = new Error(`HTTP ${response.responseCode}: ${response.result}`);
        (error as Error & { statusCode?: number }).statusCode = response.responseCode;
        throw error;
      }

      return response.result as T;
    } finally {
      // Clean up
      this.activeRequests.delete(requestId);
      httpRequest.destroy();
    }
  }

  /**
   * Determine if an error should trigger a retry
   * @private
   */
  private shouldRetryError(error: Error, retryableStatusCodes: number[]): boolean {
    // Check if error has a status code
    const statusCode = (error as Error & { statusCode?: number }).statusCode;
    
    if (statusCode !== undefined) {
      // Retry on specific HTTP status codes
      return retryableStatusCodes.includes(statusCode);
    }
    
    // Retry on network errors (timeout, connection refused, etc.)
    const errorMsg = error.message.toLowerCase();
    return errorMsg.includes('timeout') ||
           errorMsg.includes('network') ||
           errorMsg.includes('connection') ||
           errorMsg.includes('econnrefused') ||
           errorMsg.includes('enotfound');
  }

  /**
   * Sleep for specified milliseconds
   * @private
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
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
