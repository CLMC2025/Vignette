// =====================================================
// WordBookManager.ets - Built-in Word Book Management
// Handles loading, searching, and organizing word books
// =====================================================

import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import {
  WordDefinition,
  WordMeaning,
  PhraseItem,
  ExampleItem,
  ExamCategory,
  SortType,
  SearchFilter,
  WordBookMetadata
} from '../model/WordModel';

/**
 * Word data structure from JSON
 */
class WordDataRaw {
  word: string = '';
  phonetic: string = '';
  frequency: number = 0;
  examTags: string[] = [];
  meanings: WordMeaningRaw[] = [];
  phrases: PhraseRaw[] = [];
  examples: ExampleRaw[] = [];
}

class WordMeaningRaw {
  pos: string = '';
  cn: string = '';
}

class PhraseRaw {
  phrase: string = '';
  meaning: string = '';
  example: string = '';
}

class ExampleRaw {
  sentence: string = '';
  translation: string = '';
}

/**
 * Word book data structure
 */
class WordBookDataRaw {
  metadata: WordBookMetadataRaw = new WordBookMetadataRaw();
  words: WordDataRaw[] = [];
}

class WordBookMetadataRaw {
  id: string = '';
  name: string = '';
  description: string = '';
  category: string = '';
  totalWords: number = 0;
  version: string = '1.0';
  lastUpdated: number = Date.now();
}

/**
 * Word data with full definition
 */
export class WordData {
  word: string;
  phonetic: string;
  frequency: number;
  examTags: string[];
  meanings: WordMeaning[];
  phrases: PhraseItem[];
  examples: ExampleItem[];

  constructor(
    word: string,
    phonetic: string,
    frequency: number,
    examTags: string[],
    meanings: WordMeaning[],
    phrases: PhraseItem[],
    examples: ExampleItem[]
  ) {
    this.word = word;
    this.phonetic = phonetic;
    this.frequency = frequency;
    this.examTags = examTags;
    this.meanings = meanings;
    this.phrases = phrases;
    this.examples = examples;
  }

  toWordDefinition(): WordDefinition {
    return new WordDefinition(
      this.word,
      this.phonetic,
      this.meanings.length > 0 ? this.meanings[0].pos : '',
      this.meanings.length > 0 ? this.meanings[0].cn : '',
      this.meanings,
      'wordbook',
      this.phrases,
      this.examples,
      this.frequency,
      this.examTags
    );
  }
}

/**
 * Word book data with metadata
 */
export class WordBookData {
  metadata: WordBookMetadata;
  words: WordData[];
  wordMap: Map<string, WordData>;

  constructor(metadata: WordBookMetadata, words: WordData[]) {
    this.metadata = metadata;
    this.words = words;
    this.wordMap = new Map<string, WordData>();
    for (const word of words) {
      this.wordMap.set(word.word.toLowerCase(), word);
    }
  }

  getWord(word: string): WordData | null {
    return this.wordMap.get(word.toLowerCase()) ?? null;
  }
}

/**
 * Word Book Manager - Singleton for managing built-in word books
 */
export class WordBookManager {
  private static instance: WordBookManager | null = null;

  private loadedBooks: Map<string, WordBookData> = new Map<string, WordBookData>();
  private resourceManager: resourceManager.ResourceManager | null = null;

  private constructor() {}

  static getInstance(): WordBookManager {
    if (WordBookManager.instance === null) {
      WordBookManager.instance = new WordBookManager();
    }
    return WordBookManager.instance;
  }

  async initialize(resourceMgr: resourceManager.ResourceManager): Promise<void> {
    this.resourceManager = resourceMgr;
    console.info('[WordBookManager] Initialized');
  }

  async loadWordBook(bookId: string): Promise<WordBookData | null> {
    if (this.loadedBooks.has(bookId)) {
      console.info(`[WordBookManager] Book ${bookId} already loaded`);
      return this.loadedBooks.get(bookId) ?? null;
    }

    if (this.resourceManager === null) {
      console.error('[WordBookManager] Resource manager not initialized');
      return null;
    }

    try {
      const fileName = `wordbooks/${bookId.toLowerCase()}.json`;
      const uint8Array = await this.resourceManager.getRawFileContent(fileName);
      const jsonString = this.uint8ArrayToString(uint8Array);

      const raw = JSON.parse(jsonString) as WordBookDataRaw;
      const bookData = this.parseWordBookData(raw);

      this.loadedBooks.set(bookId, bookData);
      console.info(`[WordBookManager] Loaded book ${bookId} with ${bookData.words.length} words`);

      return bookData;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[WordBookManager] Failed to load book ${bookId}: ${errMsg}`);
      return null;
    }
  }

  async preloadBook(bookId: string): Promise<void> {
    await this.loadWordBook(bookId);
  }

  async preloadAllBooks(): Promise<void> {
    const bookIds = ['cet4_core', 'cet6_core', 'kaoyan_highfreq', 'cet_phrases', 'kaoyan_phrases'];
    for (const bookId of bookIds) {
      await this.preloadBook(bookId);
    }
  }

  getWordsByCategory(category: ExamCategory): WordData[] {
    const allWords: WordData[] = [];
    for (const bookData of this.loadedBooks.values()) {
      if (bookData.metadata.category === category) {
        allWords.push(...bookData.words);
      }
    }
    return allWords;
  }

  sortWords(words: WordData[], sortType: SortType): WordData[] {
    const sorted = [...words];
    switch (sortType) {
      case SortType.ALPHABETICAL:
        sorted.sort((a, b) => a.word.localeCompare(b.word));
        break;
      case SortType.FREQUENCY:
        sorted.sort((a, b) => b.frequency - a.frequency);
        break;
      case SortType.EXAM_IMPORTANCE:
        sorted.sort((a, b) => {
          const aImportance = this.calculateExamImportance(a);
          const bImportance = this.calculateExamImportance(b);
          if (aImportance !== bImportance) {
            return bImportance - aImportance;
          }
          return b.frequency - a.frequency;
        });
        break;
    }
    return sorted;
  }

  searchWords(keyword: string, filters?: SearchFilter): WordData[] {
    const allWords: WordData[] = [];
    for (const bookData of this.loadedBooks.values()) {
      allWords.push(...bookData.words);
    }

    const lowerKeyword = keyword.toLowerCase().trim();
    let results = allWords.filter((word) => {
      const matchesKeyword = word.word.toLowerCase().includes(lowerKeyword) ||
        word.phonetic.toLowerCase().includes(lowerKeyword) ||
        word.meanings.some((m) => m.cn.includes(keyword));

      if (!matchesKeyword) {
        return false;
      }

      if (filters) {
        if (filters.category && !word.examTags.includes(filters.category)) {
          return false;
        }
        if (filters.minFrequency !== undefined && word.frequency < filters.minFrequency) {
          return false;
        }
        if (filters.maxFrequency !== undefined && word.frequency > filters.maxFrequency) {
          return false;
        }
        if (filters.examTags && filters.examTags.length > 0) {
          const hasTag = filters.examTags.some((tag) => word.examTags.includes(tag));
          if (!hasTag) {
            return false;
          }
        }
      }

      return true;
    });

    return results;
  }

  getWordDetails(word: string): WordData | null {
    const lowerWord = word.toLowerCase();
    for (const bookData of this.loadedBooks.values()) {
      const found = bookData.getWord(lowerWord);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }

  getWordDefinition(word: string): WordDefinition | null {
    const wordData = this.getWordDetails(word);
    if (wordData !== null) {
      return wordData.toWordDefinition();
    }
    return null;
  }

  getBookMetadata(bookId: string): WordBookMetadata | null {
    const bookData = this.loadedBooks.get(bookId);
    if (bookData !== undefined) {
      return bookData.metadata;
    }
    return null;
  }

  getAllBookMetadata(): WordBookMetadata[] {
    const metadataList: WordBookMetadata[] = [];
    for (const bookData of this.loadedBooks.values()) {
      metadataList.push(bookData.metadata);
    }
    return metadataList;
  }

  getLoadedBookIds(): string[] {
    return Array.from(this.loadedBooks.keys());
  }

  isBookLoaded(bookId: string): boolean {
    return this.loadedBooks.has(bookId);
  }

  clearCache(): void {
    this.loadedBooks.clear();
    console.info('[WordBookManager] Cache cleared');
  }

  private parseWordBookData(raw: WordBookDataRaw): WordBookData {
    const metadata = new WordBookMetadata(
      raw.metadata.id,
      raw.metadata.name,
      raw.metadata.description,
      raw.metadata.category as ExamCategory,
      raw.metadata.totalWords,
      raw.metadata.version,
      raw.metadata.lastUpdated
    );

    const words: WordData[] = [];
    for (const wordRaw of raw.words) {
      const meanings: WordMeaning[] = [];
      for (const m of wordRaw.meanings) {
        meanings.push(new WordMeaning(m.pos, m.cn));
      }

      const phrases: PhraseItem[] = [];
      for (const p of wordRaw.phrases) {
        phrases.push(new PhraseItem(p.phrase, p.meaning, p.example));
      }

      const examples: ExampleItem[] = [];
      for (const e of wordRaw.examples) {
        examples.push(new ExampleItem(e.sentence, e.translation));
      }

      words.push(new WordData(
        wordRaw.word,
        wordRaw.phonetic,
        wordRaw.frequency,
        wordRaw.examTags,
        meanings,
        phrases,
        examples
      ));
    }

    return new WordBookData(metadata, words);
  }

  private calculateExamImportance(word: WordData): number {
    let score = 0;
    if (word.examTags.includes('CET4')) {
      score += 1;
    }
    if (word.examTags.includes('CET6')) {
      score += 2;
    }
    if (word.examTags.includes('KAOYAN')) {
      score += 3;
    }
    if (word.examTags.includes('TEM8')) {
      score += 4;
    }
    return score;
  }

  private uint8ArrayToString(uint8Array: Uint8Array): string {
    const decoder = new util.TextDecoder('utf-8');
    return decoder.decode(uint8Array);
  }
}