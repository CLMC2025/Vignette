export class Constants {
  static readonly VERSION: string = '1.0.0';

  // Cache Constants
  static readonly CACHE_MAX_MEMORY_CACHE_SIZE: number = 500;
  static readonly CACHE_VIGNETTE_CACHE_MAX_ENTRIES: number = 1000;
  static readonly CACHE_VIGNETTE_CACHE_MAX_SIZE_MB: number = 2;
  static readonly CACHE_DEFINITION_CACHE_SIZE: number = 500;

  // Network Constants
  static readonly NETWORK_CONNECT_TIMEOUT_MS: number = 30000;
  static readonly NETWORK_READ_TIMEOUT_MS: number = 30000;
  static readonly NETWORK_WRITE_TIMEOUT_MS: number = 30000;
  static readonly NETWORK_MAX_RETRY_COUNT: number = 3;
  static readonly NETWORK_INITIAL_RETRY_DELAY_MS: number = 1000;
  static readonly NETWORK_MAX_RETRY_DELAY_MS: number = 10000;

  // AI Constants
  static readonly AI_DEFAULT_MAX_TOKENS: number = 500;
  static readonly AI_DEFAULT_TEMPERATURE: number = 0.7;
  static readonly AI_WARMUP_VARIANT_COUNT: number = 2;

  // Timeout Constants
  static readonly TIMEOUT_STORY_GENERATION_MS: number = 15000;
  static readonly TIMEOUT_DEFINITION_LOOKUP_MS: number = 10000;
  static readonly TIMEOUT_TTS_PLAY_MS: number = 5000;
  static readonly TIMEOUT_ANIMATION_DURATION_MS: number = 300;
  static readonly TIMEOUT_HIGHLIGHT_DURATION_MS: number = 2000;

  // Session Constants
  static readonly SESSION_DEFAULT_DAILY_NEW_LIMIT: number = 20;
  static readonly SESSION_MAX_TASKS_PER_WORD: number = 3;
  static readonly SESSION_MIN_VIGNETTE_WORDS: number = 30;
  static readonly SESSION_MAX_VIGNETTE_WORDS: number = 100;
  static readonly SESSION_TARGET_WORD_FREQUENCY: number = 3;
  static readonly SESSION_MIN_VIGNETTE_LENGTH: number = 50;
  static readonly SESSION_SUPPORT_WORD_MIN_COUNT: number = 1;
  static readonly SESSION_SUPPORT_WORD_MAX_COUNT: number = 3;

  // FSRS Algorithm Constants
  static readonly FSRS_DEFAULT_REQUEST_RETENTION: number = 0.9;
  static readonly FSRS_DEFAULT_MAXIMUM_INTERVAL: number = 36500;
  static readonly FSRS_LEARNING_STEPS: number[] = [1, 10];
  static readonly FSRS_GRADUATING_INTERVAL_DAYS: number = 1;
  static readonly FSRS_EASY_BONUS: number = 1.3;
  static readonly FSRS_HARD_INTERVAL_MODIFIER: number = 1.2;

  // Sync Constants
  static readonly SYNC_MAX_EVENTS_PER_BATCH: number = 100;
  static readonly SYNC_COMPRESSION_THRESHOLD_BYTES: number = 1024;

  // UI Constants
  static readonly UI_ANIMATION_SHORT_DURATION: number = 150;
  static readonly UI_ANIMATION_MEDIUM_DURATION: number = 300;
  static readonly UI_ANIMATION_LONG_DURATION: number = 500;
  static readonly UI_DEBOUNCE_DELAY_MS: number = 300;
}
