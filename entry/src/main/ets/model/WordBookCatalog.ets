// =====================================================
// WordBookCatalog.ets - Built-in word book definitions
// =====================================================

import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import { WordDefinition, WordItem, WordStatus, FSRSState, ReviewHistory } from './WordModel';
import { GradientColorStop } from './TokenInterfaces';
import { BookImportParser } from '../utils/BookImportParser';
import { WordLevelLoader } from '../manager/WordLevelLoader';

export enum BookDifficulty {
  Intro = '入门',
  Basic = '初级',
  Intermediate = '中级',
  Advanced = '高级',
  Expert = '专家'
}

export enum BookCategory {
  Exam = '考试',
  Academic = '学术',
  Business = '商务',
  Travel = '旅游',
  Daily = '日常',
  Phrase = '短语',
  Kids = '少儿',
  Other = '其他'
}

export class BookProgress {
  mastered: number;
  learning: number;
  newWords: number;

  constructor(mastered: number = 0, learning: number = 0, newWords: number = 0) {
    this.mastered = mastered;
    this.learning = learning;
    this.newWords = newWords;
  }
}

export class BookCategoryGradients {
  static readonly EXAM: GradientColorStop[] = [
    { color: '#667EEA', position: 0 },
    { color: '#764BA2', position: 1 }
  ];

  static readonly ACADEMIC: GradientColorStop[] = [
    { color: '#E6E9F0', position: 0 },
    { color: '#EEF1F5', position: 1 }
  ];

  static readonly BUSINESS: GradientColorStop[] = [
    { color: '#30CFD0', position: 0 },
    { color: '#330867', position: 1 }
  ];

  static readonly TRAVEL: GradientColorStop[] = [
    { color: '#5EE7DF', position: 0 },
    { color: '#B490CA', position: 1 }
  ];

  static readonly DAILY: GradientColorStop[] = [
    { color: '#FF9A9E', position: 0 },
    { color: '#FECFEF', position: 1 }
  ];

  static readonly PHRASE: GradientColorStop[] = [
    { color: '#84FAB0', position: 0 },
    { color: '#8FD3F4', position: 1 }
  ];

  static readonly KIDS: GradientColorStop[] = [
    { color: '#A18CD1', position: 0 },
    { color: '#FBC2EB', position: 1 }
  ];

  static readonly OTHER: GradientColorStop[] = [
    { color: '#a8edea', position: 0 },
    { color: '#fed6e3', position: 1 }
  ];

  static getByCategory(category: string): GradientColorStop[] {
    switch (category) {
      case '考试':
        return BookCategoryGradients.EXAM;
      case '学术':
        return BookCategoryGradients.ACADEMIC;
      case '商务':
        return BookCategoryGradients.BUSINESS;
      case '旅游':
        return BookCategoryGradients.TRAVEL;
      case '日常':
        return BookCategoryGradients.DAILY;
      case '短语':
        return BookCategoryGradients.PHRASE;
      case '少儿':
        return BookCategoryGradients.KIDS;
      default:
        return BookCategoryGradients.OTHER;
    }
  }
}

export class BookDifficultyColors {
  static readonly INTRO: ResourceColor = '#4CAF50';
  static readonly BASIC: ResourceColor = '#8BC34A';
  static readonly INTERMEDIATE: ResourceColor = '#FF9800';
  static readonly ADVANCED: ResourceColor = '#F44336';
  static readonly EXPERT: ResourceColor = '#9C27B0';

  static getByDifficulty(difficulty: string): ResourceColor {
    switch (difficulty) {
      case '入门':
        return BookDifficultyColors.INTRO;
      case '初级':
        return BookDifficultyColors.BASIC;
      case '中级':
        return BookDifficultyColors.INTERMEDIATE;
      case '高级':
        return BookDifficultyColors.ADVANCED;
      case '专家':
        return BookDifficultyColors.EXPERT;
      default:
        return BookDifficultyColors.BASIC;
    }
  }
}

export interface WordBookDefinition {
  id: string;
  name: string;
  hasUpdate: boolean;
  fileName: string;
  wordCount: number;
  source: string;
  description: string;
  difficulty: BookDifficulty;
  category: BookCategory;
  tags: string[];
  coverColor: string[];
  icon: string;
  estimatedDays: number;
  dailyGoal: number;
  levelTag?: string;
}

export const BuiltInWordBooks: WordBookDefinition[] = [
  {
    id: 'cet4',
    name: 'CET-4 核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 4544,
    source: 'KyleBing/english-vocabulary',
    description: '大学英语四级考试核心词汇，涵盖听力、阅读、写作常用词。',
    difficulty: BookDifficulty.Intermediate,
    category: BookCategory.Exam,
    tags: ['CET4', '大学英语', '考试'],
    coverColor: ['#4FACFE', '#00F2FE'],
    icon: '📘',
    estimatedDays: 60,
    dailyGoal: 100,
    levelTag: 'CET4'
  },
  {
    id: 'cet6',
    name: 'CET-6 核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 3991,
    source: 'KyleBing/english-vocabulary',
    description: '大学英语六级考试进阶词汇，提升阅读理解与高级写作能力。',
    difficulty: BookDifficulty.Advanced,
    category: BookCategory.Exam,
    tags: ['CET6', '大学英语', '进阶'],
    coverColor: ['#667EEA', '#764BA2'],
    icon: '📙',
    estimatedDays: 30,
    dailyGoal: 70,
    levelTag: 'CET6'
  },
  {
    id: 'kaoyan',
    name: '考研英语高频词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 5047,
    source: 'KyleBing/english-vocabulary',
    description: '研究生入学考试英语高频词汇，针对性突破考研难点。',
    difficulty: BookDifficulty.Advanced,
    category: BookCategory.Exam,
    tags: ['考研', '升学', '高频'],
    coverColor: ['#FF9A9E', '#FECFEF'],
    icon: '🎓',
    estimatedDays: 15,
    dailyGoal: 60,
    levelTag: 'KAIOYAN'
  },
  {
    id: 'ielts',
    name: '雅思核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 5256,
    source: 'KyleBing/english-vocabulary',
    description: '雅思考试必备核心词汇，覆盖听说读写四项。',
    difficulty: BookDifficulty.Advanced,
    category: BookCategory.Exam,
    tags: ['IELTS', '出国', '留学'],
    coverColor: ['#89F7FE', '#66A6FF'],
    icon: '🌏',
    estimatedDays: 45,
    dailyGoal: 70,
    levelTag: 'IELTS'
  },
  {
    id: 'toefl',
    name: '托福核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 10367,
    source: 'KyleBing/english-vocabulary',
    description: '托福考试学术词汇，攻克北美留学语言关。',
    difficulty: BookDifficulty.Advanced,
    category: BookCategory.Exam,
    tags: ['TOEFL', '北美', '留学'],
    coverColor: ['#E0C3FC', '#8EC5FC'],
    icon: '🗽',
    estimatedDays: 50,
    dailyGoal: 70,
    levelTag: 'TOEFL'
  },
  {
    id: 'gre',
    name: 'GRE核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 10022,
    source: 'KyleBing/english-vocabulary',
    description: 'GRE考试高难度词汇，挑战词汇量巅峰。',
    difficulty: BookDifficulty.Expert,
    category: BookCategory.Exam,
    tags: ['GRE', '研究生', '学术'],
    coverColor: ['#434343', '#000000'],
    icon: '🧠',
    estimatedDays: 60,
    dailyGoal: 50,
    levelTag: 'GRE'
  },
  {
    id: 'gmat',
    name: 'GMAT核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 3312,
    source: 'KyleBing/english-vocabulary',
    description: 'GMAT考试词汇，商学院入学必备。',
    difficulty: BookDifficulty.Expert,
    category: BookCategory.Exam,
    tags: ['GMAT', '商科', 'MBA'],
    coverColor: ['#11998e', '#38ef7d'],
    icon: '📊',
    estimatedDays: 40,
    dailyGoal: 60,
    levelTag: 'GMAT'
  },
  {
    id: 'sat',
    name: 'SAT核心词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 4486,
    source: 'KyleBing/english-vocabulary',
    description: 'SAT考试核心词汇，美国大学入学必备。',
    difficulty: BookDifficulty.Advanced,
    category: BookCategory.Exam,
    tags: ['SAT', '美国', '本科'],
    coverColor: ['#ee0979', '#ff6a00'],
    icon: '🎯',
    estimatedDays: 35,
    dailyGoal: 60,
    levelTag: 'SAT'
  },
  {
    id: 'high',
    name: '高中英语词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 5750,
    source: 'KyleBing/english-vocabulary',
    description: '高中英语课标词汇，高考必备。',
    difficulty: BookDifficulty.Intermediate,
    category: BookCategory.Exam,
    tags: ['高中', '高考', '课标'],
    coverColor: ['#f093fb', '#f5576c'],
    icon: '📖',
    estimatedDays: 45,
    dailyGoal: 80,
    levelTag: 'HIGH'
  },
  {
    id: 'junior',
    name: '初中英语词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 2481,
    source: 'KyleBing/english-vocabulary',
    description: '初中英语课标词汇，中考必备。',
    difficulty: BookDifficulty.Basic,
    category: BookCategory.Exam,
    tags: ['初中', '中考', '课标'],
    coverColor: ['#4facfe', '#00f2fe'],
    icon: '📕',
    estimatedDays: 30,
    dailyGoal: 70,
    levelTag: 'JUNIOR'
  },
  {
    id: 'primary',
    name: '小学英语词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 710,
    source: 'KyleBing/english-vocabulary',
    description: '小学英语课标词汇，启蒙必备。',
    difficulty: BookDifficulty.Intro,
    category: BookCategory.Kids,
    tags: ['小学', '启蒙', '基础'],
    coverColor: ['#a8edea', '#fed6e3'],
    icon: '🌈',
    estimatedDays: 20,
    dailyGoal: 40,
    levelTag: 'PRIMARY'
  },
  {
    id: 'bec',
    name: '商务英语词汇',
    hasUpdate: true,
    fileName: '',
    wordCount: 2832,
    source: 'KyleBing/english-vocabulary',
    description: '职场商务交流必备词汇，提升专业形象。',
    difficulty: BookDifficulty.Intermediate,
    category: BookCategory.Business,
    tags: ['BEC', '职场', '商务'],
    coverColor: ['#30CFD0', '#330867'],
    icon: '💼',
    estimatedDays: 30,
    dailyGoal: 70,
    levelTag: 'BEC'
  }
];

function uint8ArrayToString(uint8Array: Uint8Array): string {
  const decoder = new util.TextDecoder('utf-8');
  return decoder.decode(uint8Array);
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
  const totalStart = Date.now();
  if (book.levelTag && book.levelTag.length > 0) {
    const levelLoader = WordLevelLoader.getInstance();
    levelLoader.setResourceManager(resourceMgr);
    const initStart = Date.now();
    await levelLoader.initialize();
    const initElapsed = Date.now() - initStart;
    const getStart = Date.now();
    const words = levelLoader.getWordsByLevel(book.levelTag);
    const getElapsed = Date.now() - getStart;
    const totalElapsed = Date.now() - totalStart;
    console.info(`[loadWordBookWords] Level ${book.levelTag}: init=${initElapsed}ms, getWords=${getElapsed}ms, total=${totalElapsed}ms, count=${words.length}`);
    return words;
  }
  
  if (!book.fileName || book.fileName.length === 0) {
    return [];
  }
  
  const uint8Array = await resourceMgr.getRawFileContent(book.fileName);
  const content = uint8ArrayToString(uint8Array);
  const words = content.split(/\r?\n/);
  return normalizeWordList(words);
}

export async function buildWordItemsForBook(
  book: WordBookDefinition,
  resourceMgr: resourceManager.ResourceManager
): Promise<WordItem[]> {
  if (book.levelTag && book.levelTag.length > 0) {
    const levelLoader = WordLevelLoader.getInstance();
    levelLoader.setResourceManager(resourceMgr);
    await levelLoader.initialize();
    const words = levelLoader.getWordsByLevel(book.levelTag);
    
    const now = Date.now();
    const items: WordItem[] = [];
    for (let i = 0; i < words.length; i++) {
      const word = words[i];
      const def = new WordDefinition(word, '', '', '', [], 'import');
      items.push(new WordItem(
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
        book.tags
      ));
    }
    return items;
  }
  
  if (!book.fileName || book.fileName.length === 0) {
    return [];
  }
  
  const uint8Array = await resourceMgr.getRawFileContent(book.fileName);
  const content = uint8ArrayToString(uint8Array);
  const result = BookImportParser.parseText(content, book.id, book.tags);
  return result.words;
}
