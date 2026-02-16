// =====================================================
// DBConstants.ets
// Shared database constants
// =====================================================

/**
 * Table names
 */
export const TABLE_WORDS = 'words';
export const TABLE_DEFINITIONS = 'definitions';
export const TABLE_WORD_IDENTITIES = 'word_identities';
export const TABLE_VERSION_CONTROL = 'version_control';
export const TABLE_CHANGE_LOG = 'change_log';
export const TABLE_REVIEW_EVENTS = 'review_events';
export const TABLE_VIGNETTE_CACHE = 'vignette_cache';
export const TABLE_VIGNETTE_CACHE_ITEMS = 'vignette_cache_items';
export const TABLE_USER_NOTEBOOK_WORDS = 'user_notebook_words';
export const TABLE_USER_WORD_BOOKS = 'user_word_books';
export const TABLE_USER_WORD_BOOK_WORDS = 'user_word_book_words';
export const TABLE_SYSTEM_WORD_BOOK_WORDS = 'system_word_book_words';
export const TABLE_TEXTS = 'texts';

export const SYSTEM_WORD_BOOK_IDS: string[] = ['cet4', 'cet6', 'kaoyan'];

/**
 * Column constants
 */
export class WordColumns {
  static readonly ID = 'id';
  static readonly WORD = 'word';
  static readonly STATUS = 'status';
  static readonly FSRS_STATE = 'fsrs_state';
  static readonly HISTORY = 'history';
  static readonly DEFINITION = 'definition';
  static readonly DUE_DATE = 'due_date';
  static readonly CREATED_AT = 'created_at';
  static readonly UPDATED_AT = 'updated_at';
  static readonly BOOK_ID = 'book_id';
  static readonly TAGS = 'tags';
}

export class WordIdentityColumns {
  static readonly WORD = 'word';
  static readonly STATUS = 'status';
  static readonly FSRS_STATE = 'fsrs_state';
  static readonly HISTORY = 'history';
  static readonly DUE_DATE = 'due_date';
  static readonly CREATED_AT = 'created_at';
  static readonly UPDATED_AT = 'updated_at';
  static readonly TOTAL_REPS = 'total_reps';
  static readonly TOTAL_LAPSES = 'total_lapses';
  static readonly FIRST_BOOK_ID = 'first_book_id';
}

/**
 * Custom Error class for database errors
 */
export class DBError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DBError';
  }
}
