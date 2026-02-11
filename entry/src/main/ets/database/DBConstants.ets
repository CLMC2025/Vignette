// =====================================================
// DBConstants.ets
// Shared database constants
// =====================================================

/**
 * Table names
 */
export const TABLE_WORDS = 'words';
export const TABLE_DEFINITIONS = 'definitions';
export const TABLE_VERSION_CONTROL = 'version_control';
export const TABLE_CHANGE_LOG = 'change_log';
export const TABLE_REVIEW_EVENTS = 'review_events';
export const TABLE_VIGNETTE_CACHE = 'vignette_cache';
export const TABLE_VIGNETTE_CACHE_ITEMS = 'vignette_cache_items';
export const TABLE_USER_NOTEBOOK_WORDS = 'user_notebook_words';
export const TABLE_USER_WORD_BOOKS = 'user_word_books';
export const TABLE_USER_WORD_BOOK_WORDS = 'user_word_book_words';
export const TABLE_SYSTEM_WORD_BOOK_WORDS = 'system_word_book_words';
export const TABLE_DECKS = 'decks';
export const TABLE_CARDS = 'cards';

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

export class DeckColumns {
  static readonly ID = 'id';
  static readonly NAME = 'name';
  static readonly TYPE = 'type';
  static readonly SOURCE_ID = 'source_id';
  static readonly CONFIG = 'config';
  static readonly CREATED_AT = 'created_at';
  static readonly UPDATED_AT = 'updated_at';
}

export class CardColumns {
  static readonly ID = 'id';
  static readonly DECK_ID = 'deck_id';
  static readonly WORD_ID = 'word_id';
  static readonly FRONT = 'front';
  static readonly BACK = 'back';
  static readonly CONTEXT = 'context';
  static readonly CONTEXT_TYPE = 'context_type';
  static readonly FSRS_STATE = 'fsrs_state';
  static readonly DUE_DATE = 'due_date';
  static readonly INTERVAL = 'interval';
  static readonly REPS = 'reps';
  static readonly LAPSES = 'lapses';
  static readonly QUEUE = 'queue';
  static readonly LEFT = 'left';
  static readonly SOURCE_TYPE = 'source_type';
  static readonly SOURCE_MATERIAL_ID = 'source_material_id';
  static readonly SOURCE_POSITION = 'source_position';
  static readonly CREATED_AT = 'created_at';
  static readonly UPDATED_AT = 'updated_at';
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
