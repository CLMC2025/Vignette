import { WordItem } from '../model/WordModel';

export class WordDetailCache {
  private static instance: WordDetailCache | null = null;

  private readonly maxSize: number = 50;
  private keys: number[] = [];
  private values: WordItem[] = [];

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
    const value = this.values[index];
    this.keys.splice(index, 1);
    this.values.splice(index, 1);
    this.keys.push(wordId);
    this.values.push(value);
    return value.clone();
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
    this.values.push(word.clone());
    if (this.keys.length > this.maxSize) {
      this.keys.shift();
      this.values.shift();
    }
  }

  clear(): void {
    this.keys = [];
    this.values = [];
  }
}

