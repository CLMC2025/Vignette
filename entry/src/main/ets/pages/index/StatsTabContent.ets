import { LearningProgressCard } from './components/LearningProgressCard';
import { DBManager } from '../../database/DBManager';
import { WordStatus, AppSettings } from '../../model/WordModel';
import { DashboardStats } from './IndexTypes';
import { BuiltInWordBooks, WordBookDefinition } from '../../model/WordBookCatalog';
import { BookKind, classifyBookId } from '../../utils/BookIdClassifier';
import { SettingsStore } from '../../utils/SettingsStore';
import { DesignTokens } from '../../model/DesignTokens';

@Component
export struct StatsTabContent {
  @State stats: DashboardStats = new DashboardStats();
  @State todayDoneCount: number = 0;
  @State todayTotalCount: number = 0;
  @State streakDays: number = 0;
  @State dailyNewWords: number = 10;

  private dbManager: DBManager = DBManager.getInstance();
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';
  private readonly STORAGE_KEY_STREAK_DAYS: string = 'learning_streak_days';
  private readonly STORAGE_KEY_STREAK_LAST_MS: string = 'learning_streak_last_ms';

  async aboutToAppear() {
    await this.loadSettings();
    await this.loadDashboardData();
  }

  async onPageShow() {
    await this.loadSettings();
    await this.loadDashboardData();
  }

  private async loadSettings(): Promise<void> {
    try {
      const settingsStore = SettingsStore.getInstance();
      const persisted = await settingsStore.getSettings();
      let settings: AppSettings;
      if (persisted !== null) {
        settings = persisted;
      } else {
        const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
        if (settingsJson && settingsJson.length > 0) {
          settings = AppSettings.fromJSON(settingsJson);
        } else {
          settings = new AppSettings();
        }
      }
      this.dailyNewWords = settings.dailyNewWords;
    } catch (e) {
      // ignore
    }
  }

  private async loadDashboardData(): Promise<void> {
    try {
      const counts = await this.dbManager.getWordCounts();
      this.stats.newWordsToday = counts.get(WordStatus.NEW) ?? 0;
      this.stats.reviewDue = await this.dbManager.getReviewDueCount();
      await this.updateCurrentBookTotalWords();
      await this.loadTodayProgress();
    } catch (e) {
      // ignore
    }
  }

  private async updateCurrentBookTotalWords(): Promise<void> {
    const currentBookId = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
    if (currentBookId.length === 0) {
      this.stats.totalWords = 0;
      return;
    }
    const kind = classifyBookId(currentBookId);
    if (kind === BookKind.System) {
      const importedCount = await this.dbManager.getSystemWordBookWordCount(currentBookId);
      if (importedCount > 0) {
        this.stats.totalWords = importedCount;
        return;
      }
      const builtIn = BuiltInWordBooks.find((book: WordBookDefinition) => book.id === currentBookId);
      this.stats.totalWords = builtIn ? builtIn.wordCount : 0;
      return;
    }
    const map = await this.dbManager.getAllBookCounts();
    const count = map.get(currentBookId);
    if (count !== undefined) {
      this.stats.totalWords = count;
      return;
    }
    const userBooks = await this.dbManager.getUserWordBooks();
    const found = userBooks.find((book) => book.id === currentBookId);
    this.stats.totalWords = found ? found.wordCount : 0;
  }

  private getStartOfDayMs(nowMs: number): number {
    const d = new Date(nowMs);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
  }

  private async loadTodayProgress(): Promise<void> {
    const now = Date.now();
    const start = this.getStartOfDayMs(now);
    const total = this.stats.reviewDue + Math.min(this.stats.newWordsToday, this.dailyNewWords);
    if (total <= 0) {
      this.todayDoneCount = 0;
      this.todayTotalCount = 0;
      this.loadStreakFromStorage();
      return;
    }

    try {
      const done = await this.dbManager.getUniqueReviewedWordCountBetween(start, now);
      this.todayDoneCount = Math.min(done, total);
      this.todayTotalCount = total;
      this.updateStreakIfComplete();
    } catch (e) {
      this.todayDoneCount = 0;
      this.todayTotalCount = total;
      this.loadStreakFromStorage();
    }
  }

  private isTodayComplete(): boolean {
    if (this.todayTotalCount <= 0) return true;
    return this.todayDoneCount >= this.todayTotalCount;
  }

  private loadStreakFromStorage(): void {
    const stored = AppStorage.get<string>(this.STORAGE_KEY_STREAK_DAYS);
    const streak = Number(stored ?? '0');
    this.streakDays = Number.isFinite(streak) ? streak : 0;
  }

  private updateStreakIfComplete(): void {
    if (!this.isTodayComplete() || this.todayTotalCount <= 0) {
      this.loadStreakFromStorage();
      return;
    }

    const now = Date.now();
    const todayStart = this.getStartOfDayMs(now);
    const lastRaw = AppStorage.get<string>(this.STORAGE_KEY_STREAK_LAST_MS);
    const lastMs = Number(lastRaw ?? '0');
    const lastDayStart = this.getStartOfDayMs(lastMs);

    const stored = AppStorage.get<string>(this.STORAGE_KEY_STREAK_DAYS);
    let streak = Number(stored ?? '0');
    if (!Number.isFinite(streak)) {
      streak = 0;
    }

    if (lastDayStart === todayStart) {
      this.streakDays = Math.max(1, streak);
      return;
    }

    const oneDayMs = 24 * 60 * 60 * 1000;
    if (lastDayStart > 0 && todayStart - lastDayStart <= oneDayMs) {
      streak = Math.max(1, streak) + 1;
    } else {
      streak = 1;
    }

    this.streakDays = streak;
    AppStorage.setOrCreate(this.STORAGE_KEY_STREAK_DAYS, String(streak));
    AppStorage.setOrCreate(this.STORAGE_KEY_STREAK_LAST_MS, String(now));
  }

  build() {
    Column() {
      LearningProgressCard({
        todayDoneCount: this.todayDoneCount,
        todayTotalCount: this.todayTotalCount,
        newWordsToday: this.stats.newWordsToday,
        reviewDue: this.stats.reviewDue,
        totalWords: this.stats.totalWords,
        dailyNewWords: this.dailyNewWords,
        streakDays: this.streakDays
      })
    }
    .width('100%')
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      bottom: DesignTokens.Spacing.MD
    })
  }
}
