// =====================================================
// WordBookCatalog.ets - Built-in word book definitions
// =====================================================

import resourceManager from '@ohos.resourceManager';
import { WordDefinition, WordItem, WordStatus, FSRSState, ReviewHistory } from './WordModel';

export interface WordBookDefinition {
  id: string;
  name: string;
  hasUpdate: boolean;
  fileName: string;
  wordCount: number;
  source: string;
  license: string;
}

export const BuiltInWordBooks: WordBookDefinition[] = [
  {
    id: 'cet4',
    name: 'CET-4 核心词汇',
    hasUpdate: true,
    fileName: 'wordbooks/cet4.txt',
    wordCount: 5919,
    source: 'NYIST-OS/WordList',
    license: 'MIT'
  },
  {
    id: 'cet6',
    name: 'CET-6 核心词汇',
    hasUpdate: true,
    fileName: 'wordbooks/cet6.txt',
    wordCount: 1996,
    source: 'NYIST-OS/WordList',
    license: 'MIT'
  },
  {
    id: 'kaoyan',
    name: '考研英语高频词汇',
    hasUpdate: true,
    fileName: 'wordbooks/kaoyan.txt',
    wordCount: 800,
    source: 'NYIST-OS/WordList (CET-6 subset curated for V1)',
    license: 'MIT'
  }
];

function uint8ArrayToString(uint8Array: Uint8Array): string {
  let result = '';
  for (let i = 0; i < uint8Array.length; i++) {
    result += String.fromCharCode(uint8Array[i]);
  }
  return result;
}

function normalizeWordList(words: string[]): string[] {
  const cleaned = words
    .map((word: string): string => word.trim().toLowerCase())
    .filter((word: string): boolean => word.length > 0);

  const seen = new Set<string>();
  const unique: string[] = [];
  for (const word of cleaned) {
    if (!seen.has(word)) {
      seen.add(word);
      unique.push(word);
    }
  }
  return unique;
}

export async function loadWordBookWords(
  resourceMgr: resourceManager.ResourceManager,
  book: WordBookDefinition
): Promise<string[]> {
  const uint8Array = await resourceMgr.getRawFileContent(book.fileName);
  const content = uint8ArrayToString(uint8Array);
  const words = content.split(/\r?\n/);
  return normalizeWordList(words);
}

export async function buildWordItemsForBook(
  book: WordBookDefinition,
  resourceMgr: resourceManager.ResourceManager
): Promise<WordItem[]> {
  const wordList = await loadWordBookWords(resourceMgr, book);
  const words: WordItem[] = [];
  const now = Date.now();

  for (const word of wordList) {
    const def = new WordDefinition(word, '', '', '', [], 'builtin');
    words.push(new WordItem(
      0,
      word,
      WordStatus.NEW,
      new FSRSState(),
      new ReviewHistory(),
      def,
      now,
      now,
      now,
      book.id,
      []
    ));
  }

  return words;
}
