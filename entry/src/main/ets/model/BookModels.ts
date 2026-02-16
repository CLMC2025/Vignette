
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
  isUserCreated: boolean;

  constructor(
    id: string,
    name: string,
    description: string,
    category: ExamCategory,
    totalWords: number,
    version: string = '1.0',
    lastUpdated: number = Date.now(),
    isUserCreated: boolean = false
  ) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.category = category;
    this.totalWords = totalWords;
    this.version = version;
    this.lastUpdated = lastUpdated;
    this.isUserCreated = isUserCreated;
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
