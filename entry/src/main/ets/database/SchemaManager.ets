import relationalStore from '@ohos.data.relationalStore';
import {
  TABLE_WORDS,
  TABLE_DEFINITIONS,
  TABLE_VERSION_CONTROL,
  TABLE_CHANGE_LOG,
  TABLE_REVIEW_EVENTS,
  TABLE_VIGNETTE_CACHE,
  TABLE_VIGNETTE_CACHE_ITEMS,
  TABLE_USER_NOTEBOOK_WORDS,
  TABLE_USER_WORD_BOOKS,
  TABLE_USER_WORD_BOOK_WORDS,
  TABLE_SYSTEM_WORD_BOOK_WORDS
} from './DBConstants';

/**
 * SQL statements for table creation
 */
const SQL_CREATE_WORDS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_WORDS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'NEW',
    fsrs_state TEXT NOT NULL DEFAULT '{}',
    history TEXT NOT NULL DEFAULT '[]',
    definition TEXT NOT NULL DEFAULT '{}',
    due_date INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    book_id TEXT DEFAULT '',
    tags TEXT DEFAULT '[]'
  )
`;

const SQL_CREATE_DEFINITIONS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_DEFINITIONS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL UNIQUE,
    definition TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'local',
    created_at INTEGER NOT NULL
  )
`;

const SQL_CREATE_SYSTEM_WORD_BOOK_WORDS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_SYSTEM_WORD_BOOK_WORDS} (
    book_id TEXT NOT NULL,
    word TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (book_id, word)
  )
`;

const SQL_CREATE_VERSION_CONTROL = `
  CREATE TABLE IF NOT EXISTS ${TABLE_VERSION_CONTROL} (
    id INTEGER PRIMARY KEY,
    version INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    description TEXT DEFAULT ''
  )
`;

const SQL_CREATE_CHANGE_LOG = `
  CREATE TABLE IF NOT EXISTS ${TABLE_CHANGE_LOG} (
    id TEXT PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    change_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    previous_value TEXT DEFAULT '',
    new_value TEXT DEFAULT ''
  )
`;

const SQL_CREATE_REVIEW_EVENTS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_REVIEW_EVENTS} (
    id TEXT PRIMARY KEY,
    word_id INTEGER NOT NULL,
    rating INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    prev_state_json TEXT NOT NULL,
    new_state_json TEXT NOT NULL,
    error_tag TEXT DEFAULT '',
    reflection TEXT DEFAULT ''
  )
`;

const SQL_CREATE_VIGNETTE_CACHE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_VIGNETTE_CACHE} (
    word TEXT PRIMARY KEY,
    vignette TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    size_bytes INTEGER NOT NULL
  )
`;

const SQL_CREATE_VIGNETTE_CACHE_ITEMS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_VIGNETTE_CACHE_ITEMS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL,
    vignette TEXT NOT NULL,
    vignette_hash INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    size_bytes INTEGER NOT NULL,
    UNIQUE (word, vignette_hash)
  )
`;

const SQL_CREATE_USER_NOTEBOOK_WORDS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_USER_NOTEBOOK_WORDS} (
    word TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL
  )
`;

const SQL_CREATE_USER_WORD_BOOKS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_USER_WORD_BOOKS} (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    description TEXT DEFAULT '',
    category TEXT DEFAULT '其他',
    difficulty TEXT DEFAULT '初级',
    cover_color TEXT DEFAULT '["#a8edea", "#fed6e3"]',
    icon TEXT DEFAULT '📓'
  )
`;

const SQL_CREATE_USER_WORD_BOOK_WORDS = `
  CREATE TABLE IF NOT EXISTS ${TABLE_USER_WORD_BOOK_WORDS} (
    book_id TEXT NOT NULL,
    word TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (book_id, word)
  )
`;

const SQL_CREATE_INDEX_WORD = `
  CREATE INDEX IF NOT EXISTS idx_words_word ON ${TABLE_WORDS}(word)
`;

const SQL_CREATE_INDEX_STATUS = `
  CREATE INDEX IF NOT EXISTS idx_words_status ON ${TABLE_WORDS}(status)
`;

const SQL_CREATE_INDEX_DUE = `
  CREATE INDEX IF NOT EXISTS idx_words_due ON ${TABLE_WORDS}(due_date)
`;

const SQL_CREATE_INDEX_CREATED = `
  CREATE INDEX IF NOT EXISTS idx_words_created ON ${TABLE_WORDS}(created_at)
`;

const SQL_CREATE_INDEX_STATUS_CREATED = `
  CREATE INDEX IF NOT EXISTS idx_words_status_created ON ${TABLE_WORDS}(status, created_at)
`;

const SQL_CREATE_INDEX_BOOK_STATUS_CREATED = `
  CREATE INDEX IF NOT EXISTS idx_words_book_status_created ON ${TABLE_WORDS}(book_id, status, created_at)
`;

const SQL_CREATE_INDEX_REVIEW_TS = `
  CREATE INDEX IF NOT EXISTS idx_review_events_ts ON ${TABLE_REVIEW_EVENTS}(timestamp)
`;

const SQL_CREATE_INDEX_REVIEW_TS_WORD = `
  CREATE INDEX IF NOT EXISTS idx_review_events_ts_word ON ${TABLE_REVIEW_EVENTS}(timestamp, word_id)
`;

const SQL_CREATE_INDEX_VIGNETTE_USED = `
  CREATE INDEX IF NOT EXISTS idx_vignette_cache_used ON ${TABLE_VIGNETTE_CACHE}(last_used_at)
`;

const SQL_CREATE_INDEX_VIGNETTE_ITEMS_WORD_USED = `
  CREATE INDEX IF NOT EXISTS idx_vignette_items_word_used ON ${TABLE_VIGNETTE_CACHE_ITEMS}(word, last_used_at)
`;

const SQL_CREATE_INDEX_VIGNETTE_ITEMS_USED = `
  CREATE INDEX IF NOT EXISTS idx_vignette_items_used ON ${TABLE_VIGNETTE_CACHE_ITEMS}(last_used_at)
`;

const SQL_CREATE_INDEX_USER_WORD_BOOK_WORDS_BOOK = `
  CREATE INDEX IF NOT EXISTS idx_user_word_book_words_book ON ${TABLE_USER_WORD_BOOK_WORDS}(book_id)
`;

const SQL_CREATE_INDEX_USER_WORD_BOOK_WORDS_WORD = `
  CREATE INDEX IF NOT EXISTS idx_user_word_book_words_word ON ${TABLE_USER_WORD_BOOK_WORDS}(word)
`;

const SQL_CREATE_INDEX_SYSTEM_WORD_BOOK_WORDS_BOOK = `
  CREATE INDEX IF NOT EXISTS idx_system_word_book_words_book ON ${TABLE_SYSTEM_WORD_BOOK_WORDS}(book_id)
`;

const SQL_CREATE_INDEX_SYSTEM_WORD_BOOK_WORDS_WORD = `
  CREATE INDEX IF NOT EXISTS idx_system_word_book_words_word ON ${TABLE_SYSTEM_WORD_BOOK_WORDS}(word)
`;

interface ColumnDef {
  name: string;
  type: string;
  default: string;
}

/**
 * Handles database schema creation and upgrades
 */
export class SchemaManager {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  async createTables(): Promise<void> {
    await this.store.executeSql(SQL_CREATE_WORDS);
    await this.store.executeSql(SQL_CREATE_DEFINITIONS);
    await this.store.executeSql(SQL_CREATE_SYSTEM_WORD_BOOK_WORDS);
    await this.store.executeSql(SQL_CREATE_VERSION_CONTROL);
    await this.store.executeSql(SQL_CREATE_CHANGE_LOG);
    await this.store.executeSql(SQL_CREATE_REVIEW_EVENTS);
    await this.store.executeSql(SQL_CREATE_VIGNETTE_CACHE);
    await this.store.executeSql(SQL_CREATE_VIGNETTE_CACHE_ITEMS);
    await this.store.executeSql(SQL_CREATE_USER_NOTEBOOK_WORDS);
    await this.store.executeSql(SQL_CREATE_USER_WORD_BOOKS);
    await this.store.executeSql(SQL_CREATE_USER_WORD_BOOK_WORDS);

    await this.store.executeSql(SQL_CREATE_INDEX_WORD);
    await this.store.executeSql(SQL_CREATE_INDEX_STATUS);
    await this.store.executeSql(SQL_CREATE_INDEX_DUE);
    await this.store.executeSql(SQL_CREATE_INDEX_CREATED);
    await this.store.executeSql(SQL_CREATE_INDEX_STATUS_CREATED);
    await this.store.executeSql(SQL_CREATE_INDEX_BOOK_STATUS_CREATED);
    await this.store.executeSql(SQL_CREATE_INDEX_REVIEW_TS);
    await this.store.executeSql(SQL_CREATE_INDEX_REVIEW_TS_WORD);
    await this.store.executeSql(SQL_CREATE_INDEX_VIGNETTE_USED);
    await this.store.executeSql(SQL_CREATE_INDEX_VIGNETTE_ITEMS_WORD_USED);
    await this.store.executeSql(SQL_CREATE_INDEX_VIGNETTE_ITEMS_USED);
    await this.store.executeSql(SQL_CREATE_INDEX_USER_WORD_BOOK_WORDS_BOOK);
    await this.store.executeSql(SQL_CREATE_INDEX_USER_WORD_BOOK_WORDS_WORD);
    await this.store.executeSql(SQL_CREATE_INDEX_SYSTEM_WORD_BOOK_WORDS_BOOK);
    await this.store.executeSql(SQL_CREATE_INDEX_SYSTEM_WORD_BOOK_WORDS_WORD);
  }

  async upgradeTables(): Promise<void> {
    // Check if new columns exist in user_word_books
    // If not, add them. This is a simple migration strategy.
    try {
      const columnsToAdd: ColumnDef[] = [
        { name: 'description', type: 'TEXT', default: "''" },
        { name: 'category', type: 'TEXT', default: "'其他'" },
        { name: 'difficulty', type: 'TEXT', default: "'初级'" },
        { name: 'cover_color', type: 'TEXT', default: "'[\"#a8edea\", \"#fed6e3\"]'" },
        { name: 'icon', type: 'TEXT', default: "'📓'" }
      ];

      for (const col of columnsToAdd) {
        try {
          const sql = `ALTER TABLE ${TABLE_USER_WORD_BOOKS} ADD COLUMN ${col.name} ${col.type} DEFAULT ${col.default}`;
          await this.store.executeSql(sql);
        } catch (e) {
          // Column likely exists
        }
      }
    } catch (e) {
      console.warn('[SchemaManager] Upgrade tables warning:', e);
    }
  }
}
