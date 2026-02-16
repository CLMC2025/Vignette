
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
  static readonly MAX_HISTORY_ITEMS: number = 200;
  static readonly MAX_HISTORY_DAYS: number = 365;

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
   * Prune old history entries
   * Keeps the most recent MAX_HISTORY_ITEMS entries and entries within MAX_HISTORY_DAYS
   */
  pruneOldEntries(): number {
    const now = Date.now();
    const cutoffMs = now - ReviewHistory.MAX_HISTORY_DAYS * 24 * 60 * 60 * 1000;
    
    const recentItems = this.items.filter(item => item.timestamp >= cutoffMs);
    
    if (recentItems.length <= ReviewHistory.MAX_HISTORY_ITEMS) {
      const removed = this.items.length - recentItems.length;
      this.items = recentItems;
      return removed;
    }
    
    this.items = recentItems.slice(-ReviewHistory.MAX_HISTORY_ITEMS);
    return recentItems.length - ReviewHistory.MAX_HISTORY_ITEMS;
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
