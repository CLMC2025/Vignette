
import { WordItem, WordSnapshot } from './WordEntities';

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
