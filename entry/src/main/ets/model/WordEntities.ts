
import { FSRSState, ReviewHistory, Rating } from './FSRSModels';

/**
 * Word learning status enum
 */
export enum WordStatus {
  NEW = 'NEW',           // Never reviewed
  LEARNING = 'LEARNING', // In active learning (reviewed < 2 times)
  REVIEW = 'REVIEW',     // In spaced repetition cycle
  RELEARNING = 'RELEARNING', // After lapse, in relearning steps
  KNOWN = 'KNOWN'        // User marked as known, excluded from review queue
}

export function normalizeWordStatus(raw: string): WordStatus {
  switch (raw) {
    case WordStatus.NEW:
      return WordStatus.NEW;
    case WordStatus.LEARNING:
      return WordStatus.LEARNING;
    case WordStatus.REVIEW:
      return WordStatus.REVIEW;
    case WordStatus.RELEARNING:
      return WordStatus.RELEARNING;
    case WordStatus.KNOWN:
      return WordStatus.KNOWN;
    case 'MASTERED':
      return WordStatus.KNOWN;
    case 'SUSPENDED':
      return WordStatus.REVIEW;
    default:
      return WordStatus.NEW;
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
 * Complete word definition from dictionary
 */
export class WordDefinition {
  word:  string;
  phonetic: string;
  pos: string;
  contextMeaning: string;
  commonMeanings: WordMeaning[];
  source:  string;
  phrases: PhraseItem[];
  examples: ExampleItem[];
  frequency: number;
  examTags: string[];

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

  isLocalDefinition(): boolean {
    return this.source === 'local' || this.source === 'builtin';
  }

  isAiGenerated(): boolean {
    return this.source === 'ai';
  }

  isBuiltIn(): boolean {
    return this.source === 'builtin';
  }

  canEnhance(): boolean {
    return this.source === 'local' || this.source === 'import' || this.source === 'builtin';
  }

  hasBasicInfo(): boolean {
    return this.phonetic.length > 0 || this.commonMeanings.length > 0;
  }

  hasRichContent(): boolean {
    return this.phrases.length > 0 || this.examples.length > 0;
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
    if (this.fsrsState.reps === 0 && this.fsrsState.stability <= 0) {
      this.status = WordStatus.NEW;
    } else if (this.fsrsState.lapses > 0 && this.fsrsState.stability < 1) {
      this.status = WordStatus.RELEARNING;
    } else if (this.fsrsState.reps < 2 || this.fsrsState.stability < 1) {
      this.status = WordStatus.LEARNING;
    } else {
      this.status = WordStatus.REVIEW;
    }
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

  /**
   * Mark word as known (user already knows this word)
   * Word will be excluded from review queue
   */
  markAsKnown(): void {
    this.status = WordStatus.KNOWN;
    this.dueDate = 0;
    this.updatedAt = Date.now();
  }

  /**
   * Check if word is marked as known
   */
  isKnown(): boolean {
    return this.status === WordStatus.KNOWN;
  }

  /**
   * Restore word to learning queue from known status
   */
  restoreToLearning(): void {
    if (this.status === WordStatus.KNOWN) {
      this.status = WordStatus.NEW;
      this.dueDate = Date.now();
      this.updatedAt = Date.now();
    }
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
