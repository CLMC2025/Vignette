// =====================================================
// WordLevelLoader.ets - Word Level Tag Loader
// Loads word level tags from word_levels.txt
// Provides dynamic wordbook generation based on level tags
// =====================================================

import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';

export interface WordLevelEntry {
  word: string;
  levels: string[];
}

export class WordLevelLoader {
  private static instance: WordLevelLoader | null = null;
  
  private cache: Map<string, string[]> = new Map();
  private levelIndex: Map<string, Set<string>> = new Map();
  private sortedLevelCache: Map<string, string[]> = new Map();
  private loaded: boolean = false;
  private loading: boolean = false;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  
  private constructor() {}
  
  static getInstance(): WordLevelLoader {
    if (WordLevelLoader.instance === null) {
      WordLevelLoader.instance = new WordLevelLoader();
    }
    return WordLevelLoader.instance;
  }
  
  setResourceManager(rm: resourceManager.ResourceManager): void {
    this.resourceMgr = rm;
  }
  
  async initialize(): Promise<void> {
    if (this.loaded || this.loading) {
      return;
    }
    
    if (this.resourceMgr === null) {
      console.warn('[WordLevelLoader] ResourceManager not set, skip loading');
      return;
    }
    
    this.loading = true;
    console.info('[WordLevelLoader] Starting to load word_levels.txt...');
    
    const startTime = Date.now();
    let totalWords = 0;
    
    try {
      const uint8Array = await this.resourceMgr.getRawFileContent('wordbooks/word_levels.txt');
      const decoder = new util.TextDecoder('utf-8');
      const content = decoder.decode(uint8Array);
      const lines = content.split(/\r?\n/);
      
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.length === 0 || trimmed.startsWith('#')) {
          continue;
        }
        
        const entry = this.parseLine(trimmed);
        if (entry !== null) {
          this.cache.set(entry.word, entry.levels);
          
          for (const level of entry.levels) {
            if (!this.levelIndex.has(level)) {
              this.levelIndex.set(level, new Set());
            }
            this.levelIndex.get(level)!.add(entry.word);
          }
          
          totalWords++;
        }
      }
      
      this.buildSortedCache();
      
      this.loaded = true;
      const elapsed = Date.now() - startTime;
      console.info(`[WordLevelLoader] Loaded ${totalWords} words with levels in ${elapsed}ms`);
      
      const levelKeys: string[] = [];
      this.levelIndex.forEach((_: Set<string>, key: string) => {
        levelKeys.push(key);
      });
      console.info(`[WordLevelLoader] Available levels: ${levelKeys.join(', ')}`);
    } catch (e) {
      console.error(`[WordLevelLoader] Failed to load word_levels.txt: ${e}`);
    } finally {
      this.loading = false;
    }
  }
  
  private parseLine(line: string): WordLevelEntry | null {
    const parts = line.split(/\s+/);
    if (parts.length < 2) {
      return null;
    }
    
    const word = parts[0].toLowerCase();
    const levelsStr = parts.slice(1).join('');
    const levels = levelsStr.split(',').map(l => l.trim()).filter(l => l.length > 0);
    
    return { word, levels };
  }
  
  private buildSortedCache(): void {
    const sortStart = Date.now();
    this.levelIndex.forEach((words: Set<string>, level: string) => {
      const arr: string[] = [];
      words.forEach((w: string) => {
        arr.push(w);
      });
      arr.sort();
      this.sortedLevelCache.set(level, arr);
    });
    const sortElapsed = Date.now() - sortStart;
    console.info(`[WordLevelLoader] Built sorted cache in ${sortElapsed}ms`);
  }
  
  isLoaded(): boolean {
    return this.loaded;
  }
  
  getWordLevels(word: string): string[] {
    if (!this.loaded) {
      return [];
    }
    
    const normalized = word.toLowerCase().trim();
    const levels = this.cache.get(normalized);
    if (levels === undefined) {
      return [];
    }
    const result: string[] = [];
    levels.forEach((l: string) => {
      result.push(l);
    });
    return result;
  }
  
  hasLevel(word: string, level: string): boolean {
    if (!this.loaded) {
      return false;
    }
    
    const normalized = word.toLowerCase().trim();
    const levels = this.cache.get(normalized);
    return levels ? levels.includes(level) : false;
  }
  
  getWordsByLevel(level: string): string[] {
    if (!this.loaded) {
      return [];
    }
    
    const cached = this.sortedLevelCache.get(level);
    if (cached !== undefined) {
      return cached;
    }
    
    const words = this.levelIndex.get(level);
    if (words === undefined) {
      return [];
    }
    const result: string[] = [];
    words.forEach((w: string) => {
      result.push(w);
    });
    result.sort();
    this.sortedLevelCache.set(level, result);
    return result;
  }
  
  getWordsByLevels(levels: string[], matchAll: boolean = false): string[] {
    if (!this.loaded || levels.length === 0) {
      return [];
    }
    
    if (levels.length === 1) {
      return this.getWordsByLevel(levels[0]);
    }
    
    const result: string[] = [];
    
    if (matchAll) {
      this.cache.forEach((wordLevels: string[], word: string) => {
        let allMatch = true;
        for (const l of levels) {
          if (!wordLevels.includes(l)) {
            allMatch = false;
            break;
          }
        }
        if (allMatch) {
          result.push(word);
        }
      });
    } else {
      const wordSet = new Set<string>();
      for (const level of levels) {
        const words = this.levelIndex.get(level);
        if (words !== undefined) {
          words.forEach((w: string) => {
            wordSet.add(w);
          });
        }
      }
      wordSet.forEach((w: string) => {
        result.push(w);
      });
    }
    
    return result.sort();
  }
  
  getAvailableLevels(): string[] {
    const result: string[] = [];
    this.levelIndex.forEach((_: Set<string>, key: string) => {
      result.push(key);
    });
    return result.sort();
  }
  
  getLevelStats(): Map<string, number> {
    const stats = new Map<string, number>();
    this.levelIndex.forEach((words: Set<string>, level: string) => {
      stats.set(level, words.size);
    });
    return stats;
  }
  
  getTotalWordCount(): number {
    return this.cache.size;
  }
  
  clear(): void {
    this.cache.clear();
    this.levelIndex.clear();
    this.sortedLevelCache.clear();
    this.loaded = false;
  }
}
