import { WordItem, WordDefinition } from '../model/WordModel';

export class StoryWord {
  word: string;
  startIndex: number;
  endIndex: number;
  isTarget: boolean;
  isSupport: boolean;
  isPunctuation: boolean;

  constructor(
    word: string,
    startIndex: number,
    endIndex: number,
    isTarget: boolean = false,
    isSupport: boolean = false,
    isPunctuation: boolean = false
  ) {
    this.word = word;
    this.startIndex = startIndex;
    this.endIndex = endIndex;
    this.isTarget = isTarget;
    this.isSupport = isSupport;
    this.isPunctuation = isPunctuation;
  }
}

export interface PreloadedStory {
  targetWord: string;
  text: string;
  words: StoryWord[];
  error: string;
  supportWords: string[];
  sourceLabel: string;
}

export class DialogState {
  isVisible: boolean;
  word: string;
  definition: WordDefinition | null;
  isLoading: boolean;
  wordItem: WordItem | null;
  hasBeenReviewed: boolean;
  canUndo: boolean;
  inNotebook: boolean;
  notebookBusy: boolean;
  notebookError: string;

  constructor() {
    this.isVisible = false;
    this.word = '';
    this.definition = null;
    this.isLoading = false;
    this.wordItem = null;
    this.hasBeenReviewed = false;
    this.canUndo = false;
    this.inNotebook = false;
    this.notebookBusy = false;
    this.notebookError = '';
  }

  clone(): DialogState {
    const state = new DialogState();
    state.isVisible = this.isVisible;
    state.word = this.word;
    state.definition = this.definition;
    state.isLoading = this.isLoading;
    state.wordItem = this.wordItem;
    state.hasBeenReviewed = this.hasBeenReviewed;
    state.canUndo = this.canUndo;
    state.inNotebook = this.inNotebook;
    state.notebookBusy = this.notebookBusy;
    state.notebookError = this.notebookError;
    return state;
  }

  reset(): void {
    this.isVisible = false;
    this.word = '';
    this.definition = null;
    this.isLoading = false;
    this.wordItem = null;
    this.hasBeenReviewed = false;
    this.canUndo = false;
    this.inNotebook = false;
    this.notebookBusy = false;
    this.notebookError = '';
  }
}

export enum BannerAction {
  NONE = 'NONE',
  RETRY = 'RETRY',
  SETTINGS = 'SETTINGS',
  SKIP = 'SKIP',
  APPLY_STORY_UPGRADE = 'APPLY_STORY_UPGRADE'
}

export enum SessionErrorAction {
  NONE = 'NONE',
  RETRY = 'RETRY',
  BACK = 'BACK',
  WORD_BOOKS = 'WORD_BOOKS'
}
