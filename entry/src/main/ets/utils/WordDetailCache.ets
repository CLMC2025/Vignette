import { WordItem } from '../model/WordModel';

interface CacheEntry {
  word: WordItem;
  cachedAt: number;
}

export class WordDetailCache {
  private static instance: WordDetailCache | null = null;

  private readonly maxSize: number = 50;
  private keys: number[] = [];
  private values: CacheEntry[] = [];

  private constructor() {}

  static getInstance(): WordDetailCache {
    if (WordDetailCache.instance === null) {
      WordDetailCache.instance = new WordDetailCache();
    }
    return WordDetailCache.instance;
  }

  get(wordId: number): WordItem | null {
    const index = this.keys.indexOf(wordId);
    if (index < 0) {
      return null;
    }
    const entry = this.values[index];
    // 移动到队尾（最近使用）
    this.keys.splice(index, 1);
    this.values.splice(index, 1);
    this.keys.push(wordId);
    this.values.push(entry);
    return entry.word.clone();
  }

  set(word: WordItem): void {
    const wordId = word.id;
    if (wordId <= 0) {
      return;
    }
    const index = this.keys.indexOf(wordId);
    if (index >= 0) {
      this.keys.splice(index, 1);
      this.values.splice(index, 1);
    }
    this.keys.push(wordId);
    this.values.push({
      word: word.clone(),
      cachedAt: Date.now()
    });
    if (this.keys.length > this.maxSize) {
      this.keys.shift();
      this.values.shift();
    }
  }

  /**
   * 检查缓存数据是否比数据库数据更新
   * @param wordId 单词ID
   * @param dbUpdatedAt 数据库中的更新时间
   * @returns true 如果缓存数据更新或相等
   */
  isCacheFresh(wordId: number, dbUpdatedAt: number): boolean {
    const index = this.keys.indexOf(wordId);
    if (index < 0) {
      return false;
    }
    const entry = this.values[index];
    return entry.word.updatedAt >= dbUpdatedAt;
  }

  /**
   * 获取缓存条目的更新时间
   * @param wordId 单词ID
   * @returns 更新时间戳，如果缓存不存在返回 0
   */
  getCachedUpdatedAt(wordId: number): number {
    const index = this.keys.indexOf(wordId);
    if (index < 0) {
      return 0;
    }
    return this.values[index].word.updatedAt;
  }

  /**
   * 使缓存失效
   * @param wordId 单词ID
   */
  invalidate(wordId: number): void {
    const index = this.keys.indexOf(wordId);
    if (index >= 0) {
      this.keys.splice(index, 1);
      this.values.splice(index, 1);
    }
  }

  clear(): void {
    this.keys = [];
    this.values = [];
  }
}

