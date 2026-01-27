// =====================================================
// WordModel.ets - Core Data Structures for Vignette
// Strict ArkTS Mode - No 'any' types allowed
// =====================================================

/**
 * Word learning status enum
 */
export enum WordStatus {
  NEW = 'NEW',           // Never reviewed
  LEARNING = 'LEARNING', // In active learning (reviewed < 2 times)
  REVIEW = 'REVIEW',     // In spaced repetition cycle
  MASTERED = 'MASTERED', // Stability > 21 days
  SUSPENDED = 'SUSPENDED' // User suspended
}

/**
 * Review rating enum (FSRS standard)
 */
export enum Rating {
  AGAIN = 1,  // Complete blackout
  HARD = 2,   // Recalled with difficulty
  GOOD = 3,   // Recalled with effort
  EASY = 4    // Instant recall
}

/**
 * Word state for FSRS algorithm
 */
export class FSRSState {
  difficulty: number;      // D:  [1, 10], default 5
  stability: number;       // S: days until R drops to 90%
  retrievability: number;  // R: probability of recall [0, 1]
  reps: number;            // Number of successful reviews
  lapses: number;          // Number of times forgotten

  constructor(
    difficulty: number = 5.0,
    stability: number = 0.0,
    retrievability: number = 1.0,
    reps: number = 0,
    lapses: number = 0
  ) {
    this.difficulty = difficulty;
    this.stability = stability;
    this.retrievability = retrievability;
    this.reps = reps;
    this.lapses = lapses;
  }

  /**
   * Create a deep clone for snapshot
   */
  clone(): FSRSState {
    return new FSRSState(
      this.difficulty,
      this.stability,
      this.retrievability,
      this.reps,
      this.lapses
    );
  }

  /**
   * Serialize to JSON string for DB storage
   */
  toJSON(): string {
    const obj: Record<string, number> = {
      "difficulty": this.difficulty,
      "stability": this.stability,
      "retrievability": this.retrievability,
      "reps": this.reps,
      "lapses": this.lapses
    };
    return JSON.stringify(obj);
  }

  /**
   * Deserialize from JSON string
   */
  static fromJSON(json: string): FSRSState {
    try {
      const obj: Record<string, number> = JSON.parse(json) as Record<string, number>;
      return new FSRSState(
        obj['difficulty'] ?? 5.0,
        obj['stability'] ?? 0.0,
        obj['retrievability'] ?? 1.0,
        obj['reps'] ?? 0,
        obj['lapses'] ?? 0
      );
    } catch (e) {
      return new FSRSState();
    }
  }
}

/**
 * Single history entry for review tracking
 */
export class HistoryItem {
  timestamp:  number;       // Unix timestamp ms
  rating: Rating;          // User's rating
  stateBefore: FSRSState;  // State before review
  stateAfter: FSRSState;   // State after review
  scheduledDays: number;   // Days until next review

  constructor(
    timestamp: number,
    rating: Rating,
    stateBefore: FSRSState,
    stateAfter: FSRSState,
    scheduledDays: number
  ) {
    this.timestamp = timestamp;
    this.rating = rating;
    this.stateBefore = stateBefore;
    this.stateAfter = stateAfter;
    this.scheduledDays = scheduledDays;
  }

  /**
   * Serialize to plain object for JSON
   */
  toObject(): Record<string, number | string> {
    return {
      "timestamp": this.timestamp,
      "rating": this.rating,
      "stateBefore": this.stateBefore.toJSON(),
      "stateAfter": this.stateAfter.toJSON(),
      "scheduledDays": this.scheduledDays
    };
  }

  /**
   * Deserialize from plain object
   */
  static fromObject(obj: Record<string, number | string>): HistoryItem {
    return new HistoryItem(
      obj['timestamp'] as number,
      obj['rating'] as Rating,
      FSRSState.fromJSON(obj['stateBefore'] as string),
      FSRSState.fromJSON(obj['stateAfter'] as string),
      obj['scheduledDays'] as number
    );
  }
}

/**
 * Review history collection
 */
export class ReviewHistory {
  items: HistoryItem[];

  constructor(items: HistoryItem[] = []) {
    this.items = items;
  }

  /**
   * Add a new history entry
   */
  addEntry(item: HistoryItem): void {
    this.items.push(item);
  }

  /**
   * Remove the last entry (for undo)
   */
  removeLastEntry(): HistoryItem | null {
    if (this.items.length > 0) {
      return this.items.pop() ??  null;
    }
    return null;
  }

  /**
   * Get total review count
   */
  getReviewCount(): number {
    return this.items.length;
  }

  /**
   * Serialize to JSON string
   */
  toJSON(): string {
    const arr: Record<string, number | string>[] = [];
    for (const item of this.items) {
      arr.push(item.toObject());
    }
    return JSON.stringify(arr);
  }

  /**
   * Deserialize from JSON string
   */
  static fromJSON(json: string): ReviewHistory {
    try {
      const arr: Record<string, number | string>[] = JSON.parse(json) as Record<string, number | string>[];
      const items:  HistoryItem[] = [];
      for (const obj of arr) {
        items.push(HistoryItem.fromObject(obj));
      }
      return new ReviewHistory(items);
    } catch (e) {
      return new ReviewHistory();
    }
  }
}

/**
 * Word meaning structure
 */
export class WordMeaning {
  pos: string;  // Part of speech (n., v., adj., etc.)
  cn: string;   // Chinese meaning

  constructor(pos:  string, cn: string) {
    this.pos = pos;
    this.cn = cn;
  }
}

/**
 * Phrase item for common collocations
 */
export class PhraseItem {
  phrase: string;     // The phrase (e.g., "abandon oneself to")
  meaning: string;    // Chinese meaning
  example: string;    // Example sentence

  constructor(phrase: string, meaning: string, example: string) {
    this.phrase = phrase;
    this.meaning = meaning;
    this.example = example;
  }
}

/**
 * Example sentence with translation
 */
export class ExampleItem {
  sentence: string;    // English sentence
  translation: string; // Chinese translation

  constructor(sentence: string, translation: string) {
    this.sentence = sentence;
    this.translation = translation;
  }
}

/**
 * Exam category enum
 */
export enum ExamCategory {
  CET4 = 'CET4',
  CET6 = 'CET6',
  KAOYAN = 'KAOYAN',
  TEM8 = 'TEM8'
}

/**
 * Sort type enum
 */
export enum SortType {
  ALPHABETICAL = 'ALPHABETICAL',
  FREQUENCY = 'FREQUENCY',
  EXAM_IMPORTANCE = 'EXAM_IMPORTANCE'
}

/**
 * Search filter interface
 */
export interface SearchFilter {
  category?: ExamCategory;
  minFrequency?: number;
  maxFrequency?: number;
  examTags?: string[];
}

/**
 * Word book metadata
 */
export class WordBookMetadata {
  id: string;
  name: string;
  description: string;
  category: ExamCategory;
  totalWords: number;
  version: string;
  lastUpdated: number;

  constructor(
    id: string,
    name: string,
    description: string,
    category: ExamCategory,
    totalWords: number,
    version: string = '1.0',
    lastUpdated: number = Date.now()
  ) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.category = category;
    this.totalWords = totalWords;
    this.version = version;
    this.lastUpdated = lastUpdated;
  }
}

/**
 * Complete word definition from dictionary
 */
export class WordDefinition {
  word:  string;
  phonetic: string;
  pos: string;                    // Primary POS in context
  contextMeaning: string;         // Meaning in current context
  commonMeanings: WordMeaning[];  // All common meanings
  source:  string;                 // 'ai' | 'db' | 'local'
  phrases: PhraseItem[];           // Common collocations
  examples: ExampleItem[];         // Example sentences
  frequency: number;               // Frequency level (1-5, 5 = most frequent)
  examTags: string[];              // Exam tags: CET4, CET6, KAOYAN, TEM8

  constructor(
    word: string = '',
    phonetic: string = '',
    pos: string = '',
    contextMeaning: string = '',
    commonMeanings: WordMeaning[] = [],
    source: string = 'local',
    phrases: PhraseItem[] = [],
    examples: ExampleItem[] = [],
    frequency: number = 0,
    examTags: string[] = []
  ) {
    this.word = word;
    this.phonetic = phonetic;
    this.pos = pos;
    this.contextMeaning = contextMeaning;
    this.commonMeanings = commonMeanings;
    this.source = source;
    this.phrases = phrases;
    this.examples = examples;
    this.frequency = frequency;
    this.examTags = examTags;
  }

  /**
   * Serialize to JSON string
   */
  toJSON(): string {
    const meanings: Record<string, string>[] = [];
    for (const m of this.commonMeanings) {
      meanings.push({ "pos": m.pos, "cn": m.cn });
    }
    const phraseData: Record<string, string>[] = [];
    for (const p of this.phrases) {
      phraseData.push({ "phrase": p.phrase, "meaning": p.meaning, "example": p.example });
    }
    const exampleData: Record<string, string>[] = [];
    for (const e of this.examples) {
      exampleData.push({ "sentence": e.sentence, "translation": e.translation });
    }
    const obj: Record<string, string | Record<string, string>[] | number | string[]> = {
      "word": this.word,
      "phonetic": this.phonetic,
      "pos": this.pos,
      "contextMeaning": this.contextMeaning,
      "commonMeanings": meanings,
      "source": this.source,
      "phrases": phraseData,
      "examples": exampleData,
      "frequency": this.frequency,
      "examTags": this.examTags
    };
    return JSON.stringify(obj);
  }

  /**
   * Deserialize from JSON string
   */
  static fromJSON(json:  string): WordDefinition {
    try {
      const obj = JSON.parse(json) as Record<string, string | Record<string, string>[] | number | string[]>;
      const meaningsRaw = obj['commonMeanings'] as Record<string, string>[];
      const meanings: WordMeaning[] = [];
      for (const m of meaningsRaw) {
        meanings.push(new WordMeaning(m['pos'] ??  '', m['cn'] ?? ''));
      }
      const phraseRaw = obj['phrases'] as Record<string, string>[];
      const phrases: PhraseItem[] = [];
      for (const p of phraseRaw) {
        phrases.push(new PhraseItem(p['phrase'] ?? '', p['meaning'] ?? '', p['example'] ?? ''));
      }
      const exampleRaw = obj['examples'] as Record<string, string>[];
      const examples: ExampleItem[] = [];
      for (const e of exampleRaw) {
        examples.push(new ExampleItem(e['sentence'] ?? '', e['translation'] ?? ''));
      }
      return new WordDefinition(
        obj['word'] as string ??  '',
        obj['phonetic'] as string ?? '',
        obj['pos'] as string ?? '',
        obj['contextMeaning'] as string ??  '',
        meanings,
        obj['source'] as string ?? 'local',
        phrases,
        examples,
        obj['frequency'] as number ?? 0,
        obj['examTags'] as string[] ?? []
      );
    } catch (e) {
      return new WordDefinition();
    }
  }
}

/**
 * Main WordItem class - represents a vocabulary word
 */
export class WordItem {
  id: number;                     // Primary key
  word: string;                   // The English word
  status: WordStatus;             // Current learning status
  fsrsState: FSRSState;           // FSRS algorithm state
  history: ReviewHistory;         // Review history
  definition: WordDefinition;     // Cached definition
  dueDate: number;                // Next review timestamp (ms)
  createdAt: number;              // When word was added
  updatedAt: number;              // Last update timestamp
  bookId: string;                 // Source book (e.g., 'CET4')
  tags: string[];                 // User tags
  lapseCount: number;              // Total lapse count (for leech detection)
  leechLevel: number;             // Leech level (0-3, for stubborn word strategy)
  errorTags: string[];            // Error type tags (for targeted reinforcement)
  suspendUntil: number;            // Suspension timestamp (for leech cooldown)

  constructor(
    id: number = 0,
    word: string = '',
    status: WordStatus = WordStatus.NEW,
    fsrsState: FSRSState = new FSRSState(),
    history: ReviewHistory = new ReviewHistory(),
    definition: WordDefinition = new WordDefinition(),
    dueDate: number = Date.now(),
    createdAt: number = Date.now(),
    updatedAt: number = Date.now(),
    bookId: string = '',
    tags: string[] = [],
    lapseCount: number = 0,
    leechLevel: number = 0,
    errorTags: string[] = [],
    suspendUntil: number = 0
  ) {
    this.id = id;
    this.word = word;
    this.status = status;
    this.fsrsState = fsrsState;
    this.history = history;
    this.definition = definition;
    this.dueDate = dueDate;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.bookId = bookId;
    this.tags = tags;
    this.lapseCount = lapseCount;
    this.leechLevel = leechLevel;
    this.errorTags = errorTags;
    this.suspendUntil = suspendUntil;
  }

  /**
   * Create a deep clone for Snapshot mechanism
   */
  clone(): WordItem {
    return new WordItem(
      this.id,
      this.word,
      this.status,
      this.fsrsState.clone(),
      ReviewHistory.fromJSON(this.history.toJSON()),
      WordDefinition.fromJSON(this.definition.toJSON()),
      this.dueDate,
      this.createdAt,
      this.updatedAt,
      this.bookId,
      [...this.tags],
      this.lapseCount,
      this.leechLevel,
      [...this.errorTags],
      this.suspendUntil
    );
  }

  /**
   * Check if word is due for review
   */
  isDue(): boolean {
    return this.dueDate <= Date.now();
  }

  /**
   * Check if word is new (never reviewed)
   */
  isNew(): boolean {
    return this.status === WordStatus.NEW;
  }

  /**
   * Update status based on FSRS state
   */
  updateStatusFromState(): void {
    if (this.fsrsState.reps === 0) {
      this.status = WordStatus.NEW;
    } else if (this.fsrsState.reps < 2) {
      this.status = WordStatus.LEARNING;
    } else if (this.fsrsState.stability >= 21) {
      this.status = WordStatus.MASTERED;
    } else {
      this.status = WordStatus.REVIEW;
    }
  }

  /**
   * Check if word is suspended
   */
  isSuspended(): boolean {
    return this.suspendUntil > Date.now();
  }

  /**
   * Check if word is a leech (stubborn word)
   */
  isLeech(): boolean {
    return this.leechLevel >= 2;
  }

  /**
   * Increment lapse count
   */
  incrementLapse(): void {
    this.lapseCount++;
  }

  /**
   * Update leech level based on recent performance
   */
  updateLeechLevel(recentRatings: Rating[]): void {
    const againOrHardCount = recentRatings.filter((r: Rating): boolean =>
      r === Rating.AGAIN || r === Rating.HARD
    ).length;

    if (againOrHardCount >= 4) {
      this.leechLevel = Math.min(this.leechLevel + 1, 3);
    } else if (againOrHardCount <= 1) {
      this.leechLevel = Math.max(this.leechLevel - 1, 0);
    }
  }

  /**
   * Suspend word for cooldown period
   */
  suspend(days: number): void {
    this.suspendUntil = Date.now() + (days * 24 * 60 * 60 * 1000);
    this.status = WordStatus.SUSPENDED;
  }

  /**
   * Resume word from suspension
   */
  resume(): void {
    this.suspendUntil = 0;
    this.updateStatusFromState();
  }

  /**
   * Add error tag for targeted reinforcement
   */
  addErrorTag(errorType: string): void {
    if (!this.errorTags.includes(errorType)) {
      this.errorTags.push(errorType);
    }
  }

  /**
   * Check if word has specific error type
   */
  hasErrorTag(errorType: string): boolean {
    return this.errorTags.includes(errorType);
  }

  /**
   * Get most frequent error type
   */
  getMostFrequentError(): string {
    if (this.errorTags.length === 0) return '';

    const frequencyMap = new Map<string, number>();
    for (const tag of this.errorTags) {
      const count = frequencyMap.get(tag) ?? 0;
      frequencyMap.set(tag, count + 1);
    }

    let mostFrequent = '';
    let maxCount = 0;
    const entries = frequencyMap.entries();
    let entry = entries.next();
    while (!entry.done) {
      const tag = entry.value[0];
      const count = entry.value[1];
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = tag;
      }
      entry = entries.next();
    }

    return mostFrequent;
  }
}

/**
 * Snapshot for undo mechanism
 * Immutable copy of WordItem at a point in time
 */
export class WordSnapshot {
  wordId: number;
  snapshot: WordItem;
  createdAt:  number;

  constructor(wordItem: WordItem) {
    this.wordId = wordItem.id;
    this.snapshot = wordItem.clone();
    this.createdAt = Date.now();
  }

  /**
   * Restore the snapshot
   */
  restore(): WordItem {
    return this.snapshot.clone();
  }
}

/**
 * Session queue item for learning session
 */
export class QueueItem {
  word: WordItem;
  priority: number;  // 0 = Review (highest), 1 = New

  constructor(word:  WordItem, priority:  number) {
    this.word = word;
    this.priority = priority;
  }
}

/**
 * Learning session state
 */
export class LearningSession {
  queue: QueueItem[];
  currentIndex:  number;
  startTime: number;
  reviewedCount: number;
  newLearnedCount: number;
  snapshots: Map<number, WordSnapshot>;  // wordId -> snapshot

  constructor() {
    this.queue = [];
    this.currentIndex = 0;
    this.startTime = Date.now();
    this.reviewedCount = 0;
    this.newLearnedCount = 0;
    this.snapshots = new Map();
  }

  /**
   * Add items to queue
   */
  addToQueue(items: QueueItem[]): void {
    for (const item of items) {
      this.queue.push(item);
    }
    // Sort by priority (review first, then new)
    this.queue.sort((a: QueueItem, b: QueueItem): number => a.priority - b.priority);
  }

  /**
   * Get current word
   */
  getCurrentWord(): WordItem | null {
    if (this.currentIndex < this.queue.length) {
      return this.queue[this.currentIndex].word;
    }
    return null;
  }

  /**
   * Create snapshot for current word
   */
  createSnapshot(word: WordItem): void {
    this.snapshots.set(word.id, new WordSnapshot(word));
  }

  /**
   * Get snapshot for word
   */
  getSnapshot(wordId: number): WordSnapshot | null {
    return this.snapshots.get(wordId) ??  null;
  }

  /**
   * Move to next word
   */
  moveNext(): boolean {
    if (this.currentIndex < this.queue.length - 1) {
      this.currentIndex++;
      return true;
    }
    return false;
  }

  /**
   * Check if session is complete
   */
  isComplete(): boolean {
    return this.currentIndex >= this.queue.length;
  }

  /**
   * Get progress percentage
   */
  getProgress(): number {
    if (this.queue.length === 0) return 100;
    return Math.round((this.currentIndex / this.queue.length) * 100);
  }
}

/**
 * Story generation context
 */
export class StoryContext {
  targetWord: string;
  supportWords: string[];
  generatedStory: string;
  timestamp: number;

  constructor(
    targetWord: string = '',
    supportWords: string[] = [],
    generatedStory: string = '',
    timestamp: number = Date.now()
  ) {
    this.targetWord = targetWord;
    this.supportWords = supportWords;
    this.generatedStory = generatedStory;
    this.timestamp = timestamp;
  }
}

/**
 * App settings model
 */
export class AppSettings {
  apiBaseUrl: string;
  apiModel: string;
  dailyNewWords: number;
  enableTTS: boolean;
  newbieMode: boolean;
  theme: string;
  contextStyle: string; // ContextStyle enum value
  customContextStyle: string; // Custom context style input by user
  difficultyLevel: number; // DifficultyLevel enum value
  enableVignetteCache: boolean;
  vignetteCacheMaxBytes: number;
  schedulerMode: string;

  constructor(
    apiBaseUrl: string = 'https://api.deepseek.com',
    apiModel: string = 'deepseek-chat',
    dailyNewWords: number = 10,
    enableTTS: boolean = true,
    newbieMode: boolean = true,
    theme: string = 'light',
    contextStyle: string = 'conversational',
    customContextStyle: string = '',
    difficultyLevel: number = 1, // Default to CET4
    enableVignetteCache: boolean = true,
    vignetteCacheMaxBytes: number = 2_000_000,
    schedulerMode: string = 'FSRS'
  ) {
    this.apiBaseUrl = apiBaseUrl;
    this.apiModel = apiModel;
    this.dailyNewWords = dailyNewWords;
    this.enableTTS = enableTTS;
    this.newbieMode = newbieMode;
    this.theme = theme;
    this.contextStyle = contextStyle;
    this.customContextStyle = customContextStyle;
    this.difficultyLevel = difficultyLevel;
    this.enableVignetteCache = enableVignetteCache;
    this.vignetteCacheMaxBytes = vignetteCacheMaxBytes;
    this.schedulerMode = schedulerMode;
  }

  /**
   * Serialize to JSON
   */
  toJSON(): string {
    const obj: Record<string, string | number | boolean> = {
      "apiBaseUrl": this.apiBaseUrl,
      "apiModel": this.apiModel,
      "dailyNewWords": this.dailyNewWords,
      "enableTTS": this.enableTTS,
      "newbieMode": this.newbieMode,
      "theme": this.theme,
      "contextStyle": this.contextStyle,
      "customContextStyle": this.customContextStyle,
      "difficultyLevel": this.difficultyLevel,
      "enableVignetteCache": this.enableVignetteCache,
      "vignetteCacheMaxBytes": this.vignetteCacheMaxBytes,
      "schedulerMode": this.schedulerMode
    };
    return JSON.stringify(obj);
  }

  /**
   * Deserialize from JSON (backward compatible)
   */
  static fromJSON(json: string): AppSettings {
    try {
      const obj = JSON.parse(json) as Record<string, string | number | boolean>;
      return new AppSettings(
        (obj['apiBaseUrl'] as string) ?? 'https://api.deepseek.com',
        (obj['apiModel'] as string) ?? 'deepseek-chat',
        (obj['dailyNewWords'] as number) ?? 10,
        (obj['enableTTS'] as boolean) ?? true,
        (obj['newbieMode'] as boolean) ?? true,
        (obj['theme'] as string) ?? 'light',
        (obj['contextStyle'] as string) ?? 'conversational',
        (obj['customContextStyle'] as string) ?? '',
        (obj['difficultyLevel'] as number) ?? 1, // Default to CET4
        (obj['enableVignetteCache'] as boolean) ?? true,
        (obj['vignetteCacheMaxBytes'] as number) ?? 2_000_000,
        (obj['schedulerMode'] as string) ?? 'FSRS'
      );
    } catch (e) {
      return new AppSettings();
    }
  }
}
