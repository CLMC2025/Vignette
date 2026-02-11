import { WordDefinition } from '../../model/WordModel';
import { ValidationResult } from '../../context/ContextValidator';

/**
 * Cache statistics for debugging
 */
export class CacheStats {
  memoryHits: number = 0;
  dbHits: number = 0;
  apiHits: number = 0;
  misses: number = 0;

  getTotalRequests(): number {
    return this.memoryHits + this.dbHits + this.apiHits + this.misses;
  }

  getHitRate(): number {
    const total = this.getTotalRequests();
    if (total === 0) return 0;
    return (this.memoryHits + this.dbHits) / total;
  }
}

/**
 * Dictionary lookup result
 */
export class LookupResult {
  success: boolean;
  definition: WordDefinition | null;
  error: string;
  source: string;

  constructor(
    success: boolean = false,
    definition: WordDefinition | null = null,
    error: string = '',
    source: string = ''
  ) {
    this.success = success;
    this.definition = definition;
    this.error = error;
    this.source = source;
  }

  static createSuccess(definition: WordDefinition, source: string): LookupResult {
    return new LookupResult(true, definition, '', source);
  }

  static createFailure(error: string): LookupResult {
    return new LookupResult(false, null, error, '');
  }
}

/**
 * Story generation result
 */
export enum StoryOrigin {
  CACHE = 'CACHE',
  AI = 'AI',
  OFFLINE = 'OFFLINE',
  MINIMAL = 'MINIMAL'
}

export class StoryResult {
  success: boolean;
  story: string;
  error: string;
  origin: StoryOrigin;

  constructor(success: boolean = false, story: string = '', error: string = '', origin: StoryOrigin = StoryOrigin.OFFLINE) {
    this.success = success;
    this.story = story;
    this.error = error;
    this.origin = origin;
  }

  static createSuccess(story: string, origin: StoryOrigin): StoryResult {
    return new StoryResult(true, story, '', origin);
  }

  static createFailure(error: string): StoryResult {
    return new StoryResult(false, '', error, StoryOrigin.OFFLINE);
  }
}

/**
 * Context generation result interface
 */
export interface ContextGenerationResult {
  context: string;
  validation: ValidationResult;
}

/**
 * Context improvement result interface
 */
export interface ContextImprovementResult {
  improvedContext: string;
  validation: ValidationResult;
  improvements: string[];
}

/**
 * Context generation statistics interface
 */
export interface ContextGenerationStats {
  templateCount: number;
  wordDatabaseSize: number;
  availableStyles: number;
  availableDifficulties: number;
}

/**
 * Meaning item for parsing
 */
export class MeaningItem {
  pos: string = '';
  cn: string = '';
}

/**
 * Phrase item for parsing
 */
export class PhraseItemData {
  phrase: string = '';
  meaning: string = '';
  example: string = '';
}

/**
 * Example item for parsing
 */
export class ExampleItemData {
  sentence: string = '';
  translation: string = '';
}

/**
 * AI-generated definition structure (for parsing)
 */
export class AIDefinitionResult {
  word: string = '';
  phonetic: string = '';
  pos: string = '';
  contextMeaning: string = '';
  commonMeanings: MeaningItem[] = [];
  phrases: PhraseItemData[] = [];
  examples: ExampleItemData[] = [];
  frequency: number = 0;
  examTags: string[] = [];
}

/**
 * Custom Error for API errors
 */
export class APIError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'APIError';
  }
}
