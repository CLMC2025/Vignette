import { WordDefinition } from '../../model/WordModel';
import { DBManager } from '../../database/DBManager';
import { Constants } from '../../utils/Constants';
import { CacheStats } from './DictionaryModels';

export class DictionaryCache {
  private static instance: DictionaryCache | null = null;
  
  // Level 1: Memory cache using array-based storage for ArkTS compatibility
  private memoryCacheKeys: string[] = [];
  private memoryCacheValues: WordDefinition[] = [];
  private readonly MAX_MEMORY_CACHE_SIZE: number = Constants.CACHE_DEFINITION_CACHE_SIZE;

  private stats: CacheStats = new CacheStats();
  private db: DBManager = DBManager.getInstance();

  private constructor() {}

  static getInstance(): DictionaryCache {
    if (DictionaryCache.instance === null) {
      DictionaryCache.instance = new DictionaryCache();
    }
    return DictionaryCache.instance;
  }

  getStats(): CacheStats {
    return this.stats;
  }

  clearMemoryCache(): void {
    this.memoryCacheKeys = [];
    this.memoryCacheValues = [];
    console.info('[DictionaryCache] Memory cache cleared');
  }

  getFromMemoryCache(word: string): WordDefinition | null {
    const index = this.memoryCacheKeys.indexOf(word);
    if (index >= 0) {
      return this.memoryCacheValues[index];
    }
    return null;
  }

  addToMemoryCache(word: string, definition: WordDefinition): void {
    // Check if already exists
    const existingIndex = this.memoryCacheKeys.indexOf(word);
    if (existingIndex >= 0) {
      // Update existing
      this.memoryCacheValues[existingIndex] = definition;
      return;
    }

    // Evict oldest if at capacity
    if (this.memoryCacheKeys.length >= this.MAX_MEMORY_CACHE_SIZE) {
      this.memoryCacheKeys.shift();
      this.memoryCacheValues.shift();
    }

    // Add new entry
    this.memoryCacheKeys.push(word);
    this.memoryCacheValues.push(definition);
  }

  async getFromDb(word: string): Promise<WordDefinition | null> {
    try {
      return await this.db.getCachedDefinition(word);
    } catch (e) {
      console.warn(`[DictionaryCache] DB lookup failed: ${e}`);
      return null;
    }
  }

  async cacheToDb(word: string, definition: WordDefinition): Promise<void> {
    try {
      await this.db.cacheDefinition(word, definition);
    } catch (e) {
      console.warn(`[DictionaryCache] Failed to cache to DB: ${e}`);
    }
  }

  async clearDbCache(word: string): Promise<void> {
    try {
      await this.db.clearCachedDefinition(word);
    } catch (e) {
      console.warn(`[DictionaryCache] Failed to clear DB cache: ${e}`);
    }
  }

  recordMemoryHit(): void {
    this.stats.memoryHits++;
  }

  recordDbHit(): void {
    this.stats.dbHits++;
  }

  recordApiHit(): void {
    this.stats.apiHits++;
  }

  recordMiss(): void {
    this.stats.misses++;
  }
}
