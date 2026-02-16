import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DBManager } from '../../database/DBManager';
import { BuiltInWordBooks, buildWordItemsForBook, loadWordBookWords, WordBookDefinition } from '../../model/WordBookCatalog';
import { WordItem, WordStatus, QueueItem, AppSettings } from '../../model/WordModel';
import { SessionTransferStore } from '../../utils/SessionTransferStore';
import { CurrentBookStore } from '../../utils/CurrentBookStore';
import { BookKind, classifyBookId } from '../../utils/BookIdClassifier';
import { SettingsStore } from '../../utils/SettingsStore';
import { SecureStorage } from '../../utils/SecureStorage';
import { RouterParams } from './IndexTypes';
import { DesignTokens } from '../../model/DesignTokens';
import { HeatmapDailyStats } from '../../model/HeatmapData';
import { LearningHeatmap } from '../../components/LearningHeatmap';
import { DayDetailDialog } from '../../components/DayDetailDialog';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';

interface HeatmapRange {
  startMs: number;
  endMs: number;
}

interface LearningOrderPolicyJson {
  learningOrderPolicy?: string;
}

interface DialogIndexResult {
  index: number;
}

@Component
export struct HomeTabContent {
  @State currentBookName: string = '未选择词书';
  @State currentBookId: string = '';
  @State dailyNewWords: number = 10;
  @State dailyReviewWords: number = 20;
  @State dailyTotalTasks: number = 20;
  @State studyFlowMode: string = 'combined';
  @State learningOrderPolicy: string = 'due_first';
  @State isApiConfigured: boolean = false;
  @State heatmapData: HeatmapDailyStats[] = [];
  @State showDayDetailDialog: boolean = false;
  @State selectedDayStats: HeatmapDailyStats = {
    dateMs: 0,
    knownCount: 0,
    fuzzyCount: 0,
    forgottenCount: 0,
    newCount: 0,
    reviewCount: 0,
    durationMs: 0,
    totalReviews: 0
  };
  @State todayDoneCount: number = 0;
  @State newWordsToday: number = 0;
  @State reviewDue: number = 0;
  @State totalWords: number = 0;
  @State streakDays: number = 0;
  @State isLoading: boolean = true;
  @State lastRefreshTime: number = 0;
  @StorageProp('home_refresh_token') @Watch('onHomeRefreshTokenChange') homeRefreshToken: number = 0;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State searchQuery: string = '';

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }
  @State searchLoading: boolean = false;

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';
  private readonly STORAGE_KEY_STREAK_DAYS: string = 'learning_streak_days';
  private readonly STORAGE_KEY_STREAK_LAST_MS: string = 'learning_streak_last_ms';
  private readonly DAY_MS: number = 24 * 60 * 60 * 1000;
  private readonly HEATMAP_COLUMNS: number = 53;
  private readonly HEATMAP_DAYS: number = this.HEATMAP_COLUMNS * 7 - 1;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.loadAllData();
  }

  onPageShow(): void {
    void this.refreshDataIfNeeded();
  }

  onHomeRefreshTokenChange(): void {
    void this.refreshDataIfNeeded();
  }

  private async refreshDataIfNeeded(): Promise<void> {
    const now = Date.now();
    if (now - this.lastRefreshTime > 1000) {
      this.lastRefreshTime = now;
      await this.loadAllData();
    }
  }

  private async loadAllData(): Promise<void> {
    await Promise.all([
      this.loadSettings(),
      this.loadCurrentBook(),
      this.loadProgressData()
    ]);
    setTimeout(() => {
      void this.loadHeatmapData();
    }, 100);
  }

  private getStartOfDayMs(ts: number): number {
    const d = new Date(ts);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
  }

  private getHeatmapRange(): HeatmapRange {
    const todayStart = this.getStartOfDayMs(Date.now());
    const endMs = todayStart + this.DAY_MS - 1;
    const startMs = todayStart - this.HEATMAP_DAYS * this.DAY_MS;
    return { startMs, endMs };
  }

  private async loadHeatmapData(): Promise<void> {
    try {
      const range = this.getHeatmapRange();
      this.heatmapData = await this.dbManager.getHeatmapDailyStats(range.startMs, range.endMs);
    } catch (e) {
      this.heatmapData = [];
    }
  }

  private async loadProgressData(): Promise<void> {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayMs = today.getTime();
      const tomorrowMs = todayMs + this.DAY_MS;

      const currentBookId = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
      const progressResults = await Promise.all([
        this.dbManager.getUniqueReviewedWordCountBetween(todayMs, tomorrowMs),
        this.dbManager.getWordCounts(),
        this.dbManager.getReviewDueCount(),
        currentBookId.length > 0
          ? (classifyBookId(currentBookId) === BookKind.System
            ? this.dbManager.getSystemWordBookWordCount(currentBookId)
            : this.dbManager.getUserWordBookWordCount(currentBookId))
          : Promise.resolve(0)
      ]);

      this.todayDoneCount = progressResults[0] as number;
      const counts = progressResults[1] as Map<WordStatus, number>;
      this.newWordsToday = counts.get(WordStatus.NEW) ?? 0;
      this.reviewDue = progressResults[2] as number;
      this.totalWords = progressResults[3] as number;

      void this.loadStreakDays();
    } catch (e) {
      // ignore
    }
  }

  private async loadStreakDays(): Promise<void> {
    try {
      const storedStreak = AppStorage.get<number>(this.STORAGE_KEY_STREAK_DAYS) ?? 0;
      const lastMs = AppStorage.get<number>(this.STORAGE_KEY_STREAK_LAST_MS) ?? 0;
      const todayStart = this.getStartOfDayMs(Date.now());
      const yesterdayStart = todayStart - this.DAY_MS;

      if (lastMs >= todayStart) {
        this.streakDays = storedStreak;
      } else if (lastMs >= yesterdayStart) {
        this.streakDays = storedStreak;
      } else {
        const todayCount = await this.dbManager.getUniqueReviewedWordCountBetween(todayStart, todayStart + this.DAY_MS);
        if (todayCount > 0) {
          this.streakDays = 1;
          AppStorage.setOrCreate(this.STORAGE_KEY_STREAK_DAYS, 1);
          AppStorage.setOrCreate(this.STORAGE_KEY_STREAK_LAST_MS, todayStart);
        } else {
          this.streakDays = 0;
        }
      }
    } catch (e) {
      this.streakDays = 0;
    }
  }

  private async loadSettings(): Promise<void> {
    try {
      const settingsStore = SettingsStore.getInstance();
      const settings = await settingsStore.getSettings();

      if (settings !== null) {
        this.dailyNewWords = settings.dailyNewWords;
        this.dailyReviewWords = settings.dailyReviewWords;
        this.dailyTotalTasks = settings.dailyTotalTasks;
        this.studyFlowMode = settings.studyFlowMode;
        this.learningOrderPolicy = this.parseLearningOrderPolicy(settings.toJSON());
        const secureStorage = SecureStorage.getInstance();
        const apiKey = await secureStorage.getApiKey();
        this.isApiConfigured = settings.apiBaseUrl.length > 0 && apiKey.length > 0;
      } else {
        this.dailyNewWords = 10;
        this.dailyReviewWords = 20;
        this.dailyTotalTasks = 20;
        this.studyFlowMode = 'combined';
        this.learningOrderPolicy = 'due_first';
        this.isApiConfigured = false;
      }
    } catch (e) {
      this.dailyNewWords = 10;
      this.dailyReviewWords = 20;
      this.dailyTotalTasks = 20;
      this.studyFlowMode = 'combined';
      this.learningOrderPolicy = 'due_first';
      this.isApiConfigured = false;
    }
  }

  private parseLearningOrderPolicy(settingsJson: string): string {
    try {
      const parsed = JSON.parse(settingsJson) as LearningOrderPolicyJson;
      const v = parsed.learningOrderPolicy;
      if (typeof v === 'string' && v.length > 0) {
        return v;
      }
    } catch (e) {}
    return 'due_first';
  }

  private normalizeLookupWord(raw: string): string {
    const trimmed = raw.trim().toLowerCase();
    if (trimmed.length === 0) {
      return '';
    }
    return trimmed.replace(/[^a-zA-Z'-]/g, '');
  }

  private async ensureWordIdForDetailPage(word: string): Promise<number> {
    const existing = await this.dbManager.getWordByWord(word);
    if (existing !== null && existing.id > 0) {
      return existing.id;
    }

    const item = new WordItem(0, word);
    item.bookId = 'user_added';
    item.updatedAt = Date.now();
    const rowId = await this.dbManager.insertWord(item);
    if (rowId > 0) {
      return rowId;
    }
    const after = await this.dbManager.getWordByWord(word);
    return after?.id ?? 0;
  }

  private async doSearchWord(): Promise<void> {
    if (this.searchLoading) {
      return;
    }
    const normalizedWord = this.normalizeLookupWord(this.searchQuery);
    if (normalizedWord.length === 0) {
      return;
    }

    this.searchLoading = true;
    try {
      const wordId = await this.ensureWordIdForDetailPage(normalizedWord);
      if (wordId <= 0) {
        promptAction.showToast({ message: '无法打开单词详情', duration: 1500 });
        return;
      }
      await router.pushUrl({
        url: 'pages/WordDetailPage',
        params: { wordId: wordId, wordText: normalizedWord }
      });
    } catch (e) {
      const errText = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: errText.length > 0 ? errText : '搜索失败', duration: 2000 });
    } finally {
      this.searchLoading = false;
    }
  }

  private interleaveQueue(reviewWords: WordItem[], newWords: WordItem[]): WordItem[] {
    const result: WordItem[] = [];
    const maxLen = Math.max(reviewWords.length, newWords.length);
    for (let i = 0; i < maxLen; i++) {
      const r = reviewWords[i];
      if (r) result.push(r);
      const n = newWords[i];
      if (n) result.push(n);
    }
    return result;
  }

  private shuffleQueue(words: WordItem[]): WordItem[] {
    const out = [...words];
    for (let i = out.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  private applyLearningOrder(words: WordItem[]): WordItem[] {
    if (words.length <= 1) {
      return words;
    }
    const policy = this.learningOrderPolicy;
    if (policy === 'random') {
      return this.shuffleQueue(words);
    }
    if (policy === 'alphabet') {
      const out = [...words];
      out.sort((a: WordItem, b: WordItem) => a.word.localeCompare(b.word));
      return out;
    }
    const newWords = words.filter((w: WordItem) => w.status === WordStatus.NEW);
    const reviewWords = words.filter((w: WordItem) => w.status !== WordStatus.NEW);
    if (policy === 'new_first') {
      return newWords.concat(reviewWords);
    }
    if (policy === 'interleave') {
      return this.interleaveQueue(reviewWords, newWords);
    }
    return words;
  }

  private async loadCurrentBook(): Promise<void> {
    let stored = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
    if (stored.length === 0) {
      const fallback = await CurrentBookStore.getInstance().getCurrentBookId();
      if (fallback.trim().length > 0) {
        stored = fallback;
        AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, stored);
      }
    }
    this.currentBookId = stored;
    if (stored.length === 0) {
      this.currentBookName = '未选择词书';
      return;
    }
    const builtIn = BuiltInWordBooks.find((book) => book.id === stored);
    if (builtIn) {
      this.currentBookName = builtIn.name;
      return;
    }
    try {
      const userBooks = await this.dbManager.getUserWordBooks();
      for (const book of userBooks) {
        if (book.id === stored) {
          this.currentBookName = book.name;
          return;
        }
      }
    } catch (e) {
      // ignore
    }
    this.currentBookName = stored;
  }

  private jumpToWordList(): void {
    router.pushUrl({ url: 'pages/WordBookManagerPage' });
  }

  private navigateToSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' });
  }

  private async ensureSystemBookImported(bookId: string): Promise<void> {
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return;
    }
    if (this.context === null) {
      return;
    }
    const def = BuiltInWordBooks.find((b: WordBookDefinition) => b.id === normalizedBookId);
    if (!def) {
      return;
    }
    const rm = this.context.resourceManager;
    const fileWords = await loadWordBookWords(rm, def);
    const fileCount = fileWords.length;
    if (fileCount === 0) {
      return;
    }
    const imported = await this.dbManager.getSystemWordBookWordCount(normalizedBookId);
    if (imported > 0 && imported >= fileCount) {
      return;
    }
    const words = await buildWordItemsForBook(def, rm);
    for (const w of words) {
      await this.dbManager.insertWord(w);
      await this.dbManager.addWordToSystemWordBook(def.id, w.word);
    }
  }

  private async startSession(): Promise<void> {
    if (this.currentBookId.length === 0) {
      const result = await (promptAction.showDialog({
        title: '未选择词书',
        message: '请先选择或导入词书再开始学习。',
        buttons: [
          { text: '前往词书', color: String(this.colors.PRIMARY) },
          { text: '取消', color: String(this.colors.TEXT_SECONDARY) }
        ]
      }) as Promise<DialogIndexResult>);
      if (result.index === 0) {
        this.jumpToWordList();
      }
      return;
    }
    if (!this.isApiConfigured) {
      const result = await (promptAction.showDialog({
        title: 'API未配置',
        message: '请在设置中配置API密钥以生成情境故事。',
        buttons: [
          { text: '前往设置', color: String(this.colors.PRIMARY) },
          { text: '继续', color: String(this.colors.TEXT_SECONDARY) }
        ]
      }) as Promise<DialogIndexResult>);
      if (result.index === 0) {
        this.navigateToSettings();
      } else {
        this.doStartSession();
      }
    } else {
      this.doStartSession();
    }
  }

  private async doStartSession(): Promise<void> {
    try {
      const kind = classifyBookId(this.currentBookId);
      if (kind === BookKind.System) {
        await this.ensureSystemBookImported(this.currentBookId);
      }
      
      const learningLimit = this.studyFlowMode === 'combined'
        ? this.dailyTotalTasks
        : this.dailyNewWords;
      
      const queueWords = kind === BookKind.System
        ? await this.dbManager.getLearningQueueByBook(this.currentBookId, learningLimit)
        : await this.dbManager.getLearningQueueByUserWordBook(this.currentBookId, learningLimit);
      const orderedQueueWords = this.applyLearningOrder(queueWords);

      if (queueWords.length === 0) {
        const result = await (promptAction.showDialog({
          title: '没有可学习的单词',
          message: '当前词书没有可学习的单词，请导入或切换词书。',
          buttons: [
            { text: '前往词书', color: String(this.colors.PRIMARY) },
            { text: '取消', color: String(this.colors.TEXT_SECONDARY) }
          ]
        }) as Promise<DialogIndexResult>);
        if (result.index === 0) {
          this.jumpToWordList();
        }
        return;
      }

      const queue: QueueItem[] = orderedQueueWords.map((word: WordItem) => {
        const priority = word.status === WordStatus.NEW ? 1 : 0;
        return new QueueItem(word, priority);
      });

      const validQueue = queue.filter((item: QueueItem): boolean => {
        if (!item || !item.word) {
          return false;
        }
        return true;
      });

      if (validQueue.length === 0) {
        promptAction.showToast({ message: '学习队列中存在无效数据', duration: 2000 });
        return;
      }

      const sessionId = SessionTransferStore.getInstance().put(validQueue);
      const params: RouterParams = { sessionId: sessionId };
      router.pushUrl({ url: 'pages/ReadPage', params: params });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `无法开始学习会话: ${errMsg}`, duration: 2000 });
    }
  }

  private handleHeatmapDaySelect(stats: HeatmapDailyStats): void {
    this.selectedDayStats = stats;
    this.showDayDetailDialog = true;
  }

  private handleDayDetailClose(): void {
    this.showDayDetailDialog = false;
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          Row() {
            TextInput({ text: this.searchQuery, placeholder: '搜索单词' })
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .fontColor(this.colors.TEXT_PRIMARY)
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.searchQuery = value;
              })

            Text(this.searchLoading ? '搜索中' : '搜索')
              .fontSize(14)
              .fontColor(this.colors.WHITE)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .backgroundColor(this.searchLoading ? this.colors.GRAY_400 : this.colors.PRIMARY)
              .borderRadius(10)
              .margin({ left: 10 })
              .onClick(() => {
                void this.doSearchWord();
              })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.colors.SURFACE_PRIMARY)
          .borderRadius(12)

            Row() {
              Column() {
                Text(this.currentBookName)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.GRAY_900)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });

                Text(`${this.totalWords} 词`)
                  .fontSize(13)
                  .fontColor(this.colors.GRAY_500)
                  .margin({ top: 2 });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Text('›')
                .fontSize(18)
                .fontColor(this.colors.GRAY_400);
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .borderRadius(12)
            .onClick(() => this.jumpToWordList());

            Row() {
              Column() {
                Text('单词本')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.GRAY_900);

                Text('收藏的重点单词')
                  .fontSize(13)
                  .fontColor(this.colors.GRAY_500)
                  .margin({ top: 2 });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Text('›')
                .fontSize(18)
                .fontColor(this.colors.GRAY_400);
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .borderRadius(12)
            .margin({ top: 12 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/NotebookPage' });
            });

            Column() {
              Row() {
                Column() {
                  Text('今日')
                    .fontSize(13)
                    .fontColor(this.colors.GRAY_500);

                  Row() {
                    Text(`${this.todayDoneCount}`)
                      .fontSize(28)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.colors.GRAY_900);

                    Text(`/${this.studyFlowMode === 'combined' ? this.dailyTotalTasks : this.dailyNewWords}`)
                      .fontSize(14)
                      .fontColor(this.colors.GRAY_400);
                  }
                  .margin({ top: 4 });
                }
                .alignItems(HorizontalAlign.Start);

                Blank();

                Column() {
                  Text('待复习')
                    .fontSize(13)
                    .fontColor(this.colors.GRAY_500);

                  Text(`${this.reviewDue}`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.colors.GRAY_900)
                    .margin({ top: 4 });
                }
                .alignItems(HorizontalAlign.End);
              }
              .width('100%');

              Progress({
                value: this.todayDoneCount,
                total: this.studyFlowMode === 'combined' ? this.dailyTotalTasks : this.dailyNewWords,
                type: ProgressType.Linear
              })
                .width('100%')
                .height(4)
                .color(this.colors.PRIMARY)
                .backgroundColor(this.colors.GRAY_200)
                .margin({ top: 16 });

              Text('开始学习')
                .fontSize(15)
                .fontColor(this.colors.WHITE)
                .width('100%')
                .height(44)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.colors.PRIMARY)
                .borderRadius(8)
                .margin({ top: 16 })
                .onClick(() => this.startSession());

              Text('文本库')
                .fontSize(15)
                .fontColor(this.colors.PRIMARY)
                .width('100%')
                .height(44)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.colors.PRIMARY_LIGHTEST)
                .borderRadius(8)
                .margin({ top: 10 })
                .onClick(() => {
                  router.pushUrl({ url: 'pages/TextsPage' });
                });
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .borderRadius(12)
            .margin({ top: 12 });

            Column() {
              Row() {
                Text('学习记录')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors.GRAY_900);

                Blank();

                if (this.streakDays > 0) {
                  Text(`连续 ${this.streakDays} 天`)
                    .fontSize(12)
                    .fontColor(this.colors.GRAY_500);
                }
              }
              .width('100%');

              LearningHeatmap({
                data: this.heatmapData,
                columns: this.HEATMAP_COLUMNS,
                showLegend: true,
                onDayClick: (stats: HeatmapDailyStats) => {
                  this.handleHeatmapDaySelect(stats);
                }
              });
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .borderRadius(12)
            .margin({ top: 12 });
          }
          .width('100%')
          .padding(16);
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)

      DayDetailDialog({
        visible: $showDayDetailDialog,
        stats: this.selectedDayStats,
        onClose: () => this.handleDayDetailClose()
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeRefreshToken >= 0 ? this.colors.BACKGROUND_SECONDARY : this.colors.BACKGROUND_SECONDARY)
    .id('homeTab_' + this.themeRefreshToken)
  }
}
