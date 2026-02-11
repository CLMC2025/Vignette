import { TaskItem, TaskType, TaskDifficulty, ErrorType } from '../manager/SessionPlanner';
import { WordItem } from './WordModel';

export class TaskSnapshot {
  id: string;
  type: TaskType;
  word: WordItem;
  difficulty: TaskDifficulty;
  content: string;
  options: string[];
  correctAnswer: string;
  userAnswer: string;
  isCorrect: boolean;
  errorTag: ErrorType | null;
  reflection: string;
  isReinforcement: boolean;
  priority: number;
  estimatedTime: number;

  constructor(
    id: string,
    type: TaskType,
    word: WordItem,
    difficulty: TaskDifficulty,
    content: string,
    options: string[],
    correctAnswer: string,
    userAnswer: string,
    isCorrect: boolean,
    errorTag: ErrorType | null,
    reflection: string,
    isReinforcement: boolean,
    priority: number,
    estimatedTime: number
  ) {
    this.id = id;
    this.type = type;
    this.word = word;
    this.difficulty = difficulty;
    this.content = content;
    this.options = options;
    this.correctAnswer = correctAnswer;
    this.userAnswer = userAnswer;
    this.isCorrect = isCorrect;
    this.errorTag = errorTag;
    this.reflection = reflection;
    this.isReinforcement = isReinforcement;
    this.priority = priority;
    this.estimatedTime = estimatedTime;
  }

  static fromTask(task: TaskItem): TaskSnapshot {
    const options: string[] = task.options ? [...task.options] : [];
    const correctAnswer: string = task.correctAnswer ?? '';
    const userAnswer: string = task.userAnswer ?? '';
    const isCorrect: boolean = task.isCorrect ?? false;
    const errorTag: ErrorType | null = task.errorTag ?? null;
    const reflection: string = task.reflection ?? '';
    return new TaskSnapshot(
      task.id,
      task.type,
      task.word.clone(),
      task.difficulty,
      task.content,
      options,
      correctAnswer,
      userAnswer,
      isCorrect,
      errorTag,
      reflection,
      task.isReinforcement,
      task.priority,
      task.estimatedTime
    );
  }

  toTaskItem(): TaskItem {
    const task = new TaskItem(
      this.id,
      this.type,
      this.word.clone(),
      this.difficulty,
      this.content,
      this.isReinforcement,
      this.priority,
      this.estimatedTime
    );
    if (this.options.length > 0) {
      task.options = [...this.options];
    }
    if (this.correctAnswer.length > 0) {
      task.correctAnswer = this.correctAnswer;
    }
    if (this.userAnswer.length > 0) {
      task.userAnswer = this.userAnswer;
    }
    if (this.isCorrect) {
      task.isCorrect = true;
    }
    if (this.errorTag !== null) {
      task.errorTag = this.errorTag;
    }
    if (this.reflection.length > 0) {
      task.reflection = this.reflection;
    }
    return task;
  }
}

export class ReadContextSnapshot {
  taskIndex: number;
  taskQueue: TaskSnapshot[];
  currentTaskId: string;
  storyText: string;
  storyError: string;
  supportWords: string[];
  storyTranslation: string;
  showTranslation: boolean;
  lastReviewHint: string;
  pendingReviewReflection: string;
  contextSequence: string[];
  contextCursor: number;
  seenContextIds: string[];

  constructor(
    taskIndex: number,
    taskQueue: TaskSnapshot[],
    currentTaskId: string,
    storyText: string,
    storyError: string,
    supportWords: string[],
    storyTranslation: string,
    showTranslation: boolean,
    lastReviewHint: string,
    pendingReviewReflection: string,
    contextSequence: string[],
    contextCursor: number,
    seenContextIds: string[]
  ) {
    this.taskIndex = taskIndex;
    this.taskQueue = taskQueue;
    this.currentTaskId = currentTaskId;
    this.storyText = storyText;
    this.storyError = storyError;
    this.supportWords = supportWords;
    this.storyTranslation = storyTranslation;
    this.showTranslation = showTranslation;
    this.lastReviewHint = lastReviewHint;
    this.pendingReviewReflection = pendingReviewReflection;
    this.contextSequence = contextSequence;
    this.contextCursor = contextCursor;
    this.seenContextIds = seenContextIds;
  }
}

export class ReadPageHistoryEntry {
  wordBeforeReview: WordItem;
  context: ReadContextSnapshot;
  createdAtMs: number;
  prevAttempts: number;
  prevReinforcementInsertedCount: number;
  prevSessionReviewedCount: number;
  prevSessionNewLearnedCount: number;

  constructor(
    wordBeforeReview: WordItem,
    context: ReadContextSnapshot,
    createdAtMs: number,
    prevAttempts: number,
    prevReinforcementInsertedCount: number,
    prevSessionReviewedCount: number,
    prevSessionNewLearnedCount: number
  ) {
    this.wordBeforeReview = wordBeforeReview;
    this.context = context;
    this.createdAtMs = createdAtMs;
    this.prevAttempts = prevAttempts;
    this.prevReinforcementInsertedCount = prevReinforcementInsertedCount;
    this.prevSessionReviewedCount = prevSessionReviewedCount;
    this.prevSessionNewLearnedCount = prevSessionNewLearnedCount;
  }
}
