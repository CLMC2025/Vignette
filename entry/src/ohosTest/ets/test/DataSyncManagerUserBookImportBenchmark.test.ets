import { describe, it, expect } from '@ohos/hypium';

import { DataSyncManager } from '../../../main/ets/sync/DataSyncManager';
import { UserWordBook } from '../../../main/ets/database/DBManager';

interface SyncManagerPatch {
  [key: string]: Object | string | number | boolean;
}

interface BenchmarkStats {
  elapsedMs: number;
  getUserWordBooksCalls: number;
}

interface FakeDbManager {
  getWordByWord(word: string): Promise<Object | null>;
  insertWord(word: Object): Promise<void>;
  updateWord(word: Object): Promise<void>;
  cacheDefinition(word: string, definition: Object): Promise<void>;
  getUserWordBooks(): Promise<UserWordBook[]>;
  createUserWordBook(
    name: string,
    description: string,
    category: string,
    difficulty: string,
    coverColor: string,
    icon: string
  ): Promise<string>;
  getUserWordBookById(bookId: string): Promise<UserWordBook | null>;
  updateUserWordBook(book: UserWordBook): Promise<void>;
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

function buildImportPayload(bookCount: number): string {
  const userBooks: Object[] = [];
  const now = Date.now();
  for (let i = 0; i < bookCount; i++) {
    userBooks.push({
      id: `book-${i}`,
      name: `Book ${i}`,
      description: 'benchmark',
      category: '其他',
      difficulty: '初级',
      coverColor: '["#a8edea", "#fed6e3"]',
      icon: '📓',
      createdAt: now,
      updatedAt: now + i
    });
  }

  const payload: Object = {
    version: '1.0',
    timestamp: now,
    appVersion: '1.0.0',
    words: [],
    definitions: [],
    userBooks,
    versionControl: '',
    fsrsParamsJson: ''
  };
  return JSON.stringify(payload);
}

function createFakeDb(stats: BenchmarkStats): FakeDbManager {
  const booksById = new Map<string, UserWordBook>();

  return {
    async getWordByWord(_word: string): Promise<Object | null> {
      return null;
    },
    async insertWord(_word: Object): Promise<void> {
      return;
    },
    async updateWord(_word: Object): Promise<void> {
      return;
    },
    async cacheDefinition(_word: string, _definition: Object): Promise<void> {
      return;
    },
    async getUserWordBooks(): Promise<UserWordBook[]> {
      stats.getUserWordBooksCalls++;
      await sleep(2);
      return Array.from(booksById.values());
    },
    async createUserWordBook(
      name: string,
      description: string,
      category: string,
      difficulty: string,
      coverColor: string,
      icon: string
    ): Promise<string> {
      const id = `created-${booksById.size + 1}`;
      const now = Date.now();
      booksById.set(id, {
        id,
        name,
        description,
        wordCount: 0,
        isUserCreated: true,
        createdAt: now,
        updatedAt: now,
        category,
        difficulty,
        coverColor,
        icon
      });
      return id;
    },
    async getUserWordBookById(bookId: string): Promise<UserWordBook | null> {
      const book = booksById.get(bookId);
      return book === undefined ? null : book;
    },
    async updateUserWordBook(book: UserWordBook): Promise<void> {
      booksById.set(book.id, book);
    }
  };
}

async function runBenchmark(bookCount: number): Promise<BenchmarkStats> {
  const manager = DataSyncManager.getInstance();
  const patch = manager as SyncManagerPatch;
  const originalDbManager = patch['dbManager'];
  const stats: BenchmarkStats = {
    elapsedMs: 0,
    getUserWordBooksCalls: 0
  };

  patch['dbManager'] = createFakeDb(stats) as Object;

  try {
    const payload = buildImportPayload(bookCount);
    const start = Date.now();
    const result = await manager.importData(payload);
    stats.elapsedMs = Date.now() - start;
    expect(result.hasErrors()).assertFalse();
    return stats;
  } finally {
    patch['dbManager'] = originalDbManager;
  }
}

export default function dataSyncManagerUserBookImportBenchmarkTest(): void {
  describe('DataSyncManager user book import benchmark', () => {
    it('should keep getUserWordBooks fixed and improve batch import for 500/1000 books', 0, async () => {
      const benchmark500 = await runBenchmark(500);
      const benchmark1000 = await runBenchmark(1000);

      expect(benchmark500.getUserWordBooksCalls).assertEqual(1);
      expect(benchmark1000.getUserWordBooksCalls).assertEqual(1);

      expect(benchmark500.elapsedMs < 1500).assertTrue();
      expect(benchmark1000.elapsedMs < 2500).assertTrue();
      expect(benchmark1000.elapsedMs < benchmark500.elapsedMs * 3).assertTrue();
    });
  });
}
