/**
 * TimeboxManager.ets - Timebox management for learning sessions
 * Controls learning session duration and provides reminders
 */

export interface TimeboxConfig {
  enabled: boolean;
  limitMinutes: number;
  reminderMinutesBefore: number;
}

export interface TimeboxResult {
  elapsedMinutes: number;
  cardsReviewed: number;
  newWordsLearned: number;
  sessionStartTime: number;
}

export interface TimeboxState {
  sessionStartTime: number;
  cardsReviewed: number;
  newWordsLearned: number;
  lastReminderTime: number;
}

const DEFAULT_CONFIG: TimeboxConfig = {
  enabled: true,
  limitMinutes: 30,
  reminderMinutesBefore: 5
};

const STORAGE_KEY_CONFIG = 'timebox_config';
const STORAGE_KEY_STATE = 'timebox_state';

export class TimeboxManager {
  private static instance: TimeboxManager | null = null;
  private config: TimeboxConfig = DEFAULT_CONFIG;
  private state: TimeboxState | null = null;

  private constructor() {
    this.loadConfig();
  }

  static getInstance(): TimeboxManager {
    if (TimeboxManager.instance === null) {
      TimeboxManager.instance = new TimeboxManager();
    }
    return TimeboxManager.instance;
  }

  private loadConfig(): void {
    const stored = AppStorage.get<string>(STORAGE_KEY_CONFIG);
    if (stored && stored.length > 0) {
      try {
        const parsed = JSON.parse(stored) as TimeboxConfig;
        this.config = {
          enabled: parsed.enabled !== undefined ? parsed.enabled : DEFAULT_CONFIG.enabled,
          limitMinutes: parsed.limitMinutes !== undefined ? parsed.limitMinutes : DEFAULT_CONFIG.limitMinutes,
          reminderMinutesBefore: parsed.reminderMinutesBefore !== undefined ? parsed.reminderMinutesBefore : DEFAULT_CONFIG.reminderMinutesBefore
        };
      } catch (e) {
        this.config = DEFAULT_CONFIG;
      }
    }
  }

  private saveConfig(): void {
    AppStorage.setOrCreate(STORAGE_KEY_CONFIG, JSON.stringify(this.config));
  }

  private saveState(): void {
    if (this.state !== null) {
      AppStorage.setOrCreate(STORAGE_KEY_STATE, JSON.stringify(this.state));
    }
  }

  private loadState(): void {
    const stored = AppStorage.get<string>(STORAGE_KEY_STATE);
    if (stored && stored.length > 0) {
      try {
        this.state = JSON.parse(stored) as TimeboxState;
      } catch (e) {
        this.state = null;
      }
    }
  }

  getConfig(): TimeboxConfig {
    return {
      enabled: this.config.enabled,
      limitMinutes: this.config.limitMinutes,
      reminderMinutesBefore: this.config.reminderMinutesBefore
    };
  }

  updateConfig(newConfig: Partial<TimeboxConfig>): void {
    this.config = {
      enabled: newConfig.enabled !== undefined ? newConfig.enabled : this.config.enabled,
      limitMinutes: newConfig.limitMinutes !== undefined ? newConfig.limitMinutes : this.config.limitMinutes,
      reminderMinutesBefore: newConfig.reminderMinutesBefore !== undefined ? newConfig.reminderMinutesBefore : this.config.reminderMinutesBefore
    };
    this.saveConfig();
  }

  startSession(): void {
    this.state = {
      sessionStartTime: Date.now(),
      cardsReviewed: 0,
      newWordsLearned: 0,
      lastReminderTime: 0
    };
    this.saveState();
  }

  endSession(): TimeboxResult | null {
    if (this.state === null) {
      return null;
    }

    const result: TimeboxResult = {
      elapsedMinutes: this.getElapsedMinutes(),
      cardsReviewed: this.state.cardsReviewed,
      newWordsLearned: this.state.newWordsLearned,
      sessionStartTime: this.state.sessionStartTime
    };

    this.state = null;
    AppStorage.delete(STORAGE_KEY_STATE);

    return result;
  }

  recordReview(isNewWord: boolean): void {
    if (this.state === null) {
      return;
    }
    this.state.cardsReviewed++;
    if (isNewWord) {
      this.state.newWordsLearned++;
    }
    this.saveState();
  }

  getElapsedMinutes(): number {
    if (this.state === null) {
      return 0;
    }
    const elapsedMs = Date.now() - this.state.sessionStartTime;
    return Math.floor(elapsedMs / (60 * 1000));
  }

  getRemainingMinutes(): number {
    if (this.state === null || !this.config.enabled) {
      return -1;
    }
    const elapsed = this.getElapsedMinutes();
    return Math.max(0, this.config.limitMinutes - elapsed);
  }

  isTimeboxReached(): boolean {
    if (this.state === null || !this.config.enabled) {
      return false;
    }
    return this.getElapsedMinutes() >= this.config.limitMinutes;
  }

  shouldShowReminder(): boolean {
    if (this.state === null || !this.config.enabled) {
      return false;
    }

    const remaining = this.getRemainingMinutes();
    const shouldRemind = remaining <= this.config.reminderMinutesBefore && remaining > 0;

    if (shouldRemind) {
      const now = Date.now();
      const minIntervalMs = 60 * 1000;
      if (now - this.state.lastReminderTime >= minIntervalMs) {
        this.state.lastReminderTime = now;
        this.saveState();
        return true;
      }
    }

    return false;
  }

  getSessionStats(): TimeboxResult | null {
    if (this.state === null) {
      return null;
    }

    return {
      elapsedMinutes: this.getElapsedMinutes(),
      cardsReviewed: this.state.cardsReviewed,
      newWordsLearned: this.state.newWordsLearned,
      sessionStartTime: this.state.sessionStartTime
    };
  }

  isActive(): boolean {
    return this.state !== null;
  }

  getProgressPercent(): number {
    if (this.state === null || !this.config.enabled) {
      return 0;
    }
    const elapsed = this.getElapsedMinutes();
    return Math.min(100, Math.round((elapsed / this.config.limitMinutes) * 100));
  }

  formatTime(minutes: number): string {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours}小时${mins}分钟`;
    }
    return `${mins}分钟`;
  }

  getFormattedRemainingTime(): string {
    const remaining = this.getRemainingMinutes();
    if (remaining < 0) {
      return '';
    }
    return this.formatTime(remaining);
  }

  getFormattedElapsedTime(): string {
    return this.formatTime(this.getElapsedMinutes());
  }
}
