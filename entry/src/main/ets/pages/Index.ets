// =====================================================
// Index.ets - Dashboard & Main Entry Point
// Shows stats and word list, starts learning sessions
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import notificationManager from '@ohos.notificationManager';
import { DesignTokens } from '../model/DesignTokens';
import { LoadingAnimation, LoadingType } from '../ui/LoadingAnimations';
import {
  WordItem,
  WordStatus,
  WordMeaning,
  QueueItem,
  AppSettings
} from '../model/WordModel';
import { DBManager, MockDataGenerator } from '../database/DBManager';
import { DictionaryManager } from '../manager/DictionaryManager';
import { BuiltInWordBooks, WordBookDefinition } from '../model/WordBookCatalog';
import { ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import { EvolveScheduler, SchedulerMode } from '../evolve/EvolveScheduler';
import { SecureStorage } from '../utils/SecureStorage';
import { parseSchedulerMode } from '../utils/SettingsUtils';
import { CelebrationParticles } from '../ui/CelebrationParticles';
import { WebDavManifest, WebDavSettings } from '../sync/WebDavSyncManager';
import { FeatureFlags } from '../utils/FeatureFlags';

/**
 * Notification normal content interface
 */
interface AppNotificationNormalContent {
  title: string;
  text: string;
}

/**
 * Notification basic content interface
 */
interface AppNotificationBasicContent {
  contentType: notificationManager.ContentType;
  normal: AppNotificationNormalContent;
}

/**
 * Notification content interface for backup reminders
 */
interface AppNotificationContent {
  content: AppNotificationBasicContent;
}

/**
 * Simple notification request interface
 */
interface AppNotificationRequest {
  id: number;
  slotId: string;
  content: AppNotificationContent;
}

/**
 * Dashboard statistics
 */
class DashboardStats {
  newWordsToday: number = 0;
  reviewDue: number = 0;
  totalWords: number = 0;
  masteredWords: number = 0;
}

/**
 * Filter options for word list
 */
enum WordFilter {
  ALL = '全部',
  NEW = '新词',
  LEARNING = '学习中',
  REVIEW = '复习',
  MASTERED = '已掌握'
}

/**
 * Router params interface
 */
interface RouterParams {
  queue: QueueItem[];
}

interface WordDetailParams {
  wordId: number;
}

interface GeneratedObjectLiteralInterface_1 {
  title: string;
  text: string;
}

@Entry
@Component
struct Index {
  // Dashboard state
  @State private stats: DashboardStats = new DashboardStats();
  @State private isLoading: boolean = true;

  // Word list state
  @State private words: WordItem[] = [];
  @State private filteredWords: WordItem[] = [];
  @State private selectedFilter: WordFilter = WordFilter.ALL;
  @State private searchText: string = '';

  // Settings
  @State private dailyNewWords: number = 10;
  @State private isApiConfigured: boolean = false;

  // Today progress
  @State private todayDoneCount: number = 0;
  @State private todayTotalCount: number = 0;
  @State private streakDays: number = 0;
  @State private wordListHighlight: boolean = false;
  @State private currentBookId: string = '';
  @State private currentBookName: string = '未选择词书';

  // Celebration
  @State private showCelebration: boolean = false;
  @State private celebrationSeed: number = 0;

  // Database
  private dbManager:  DBManager = DBManager.getInstance();
  private dictManager: DictionaryManager = DictionaryManager.getInstance();
  private context: common.UIAbilityContext | null = null;

  // Storage keys
  private readonly STORAGE_KEY_SETTINGS:  string = 'app_settings';
  private readonly STORAGE_KEY_CELEBRATE_MS: string = 'today_session_complete_ms';
  private readonly STORAGE_KEY_FIRST_RUN_MS: string = 'first_run_ms';
  private readonly STORAGE_KEY_BACKUP_REMINDER_MS: string = 'last_backup_reminder_ms';
  private readonly STORAGE_KEY_STREAK_DAYS: string = 'learning_streak_days';
  private readonly STORAGE_KEY_STREAK_LAST_MS: string = 'learning_streak_last_ms';
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.initializeApp();
  }

  async onPageShow(): Promise<void> {
    // Inject ability context into SecureStorage
    const secureStorage = SecureStorage.getInstance();
    const context = getContext(this) as common.UIAbilityContext;
    secureStorage.injectContext(context);
    
    await this.loadSettings(); // 重新加载设置，确保API配置状态已更新
    await this.loadDashboardData();
    await this.loadCurrentBook();
    this.maybeTriggerCelebration();
    await this.checkBackupReminder();
  }

  private async initializeApp(): Promise<void> {
    this.isLoading = true;

    try {
      if (this.context !== null) {
        await this.dbManager.initialize(this.context);
      }
      await this.loadSettings();
      await this.loadDashboardData();
      await this.loadCurrentBook();
      if (AppStorage.get<string>(this.STORAGE_KEY_FIRST_RUN_MS) === undefined) {
        AppStorage.setOrCreate(this.STORAGE_KEY_FIRST_RUN_MS, String(Date.now()));
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message :  String(e);
      console.error('[Index] Failed to initialize:', errMsg);
      promptAction.showToast({ message: 'Failed to initialize app', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private async loadSettings(): Promise<void> {
    try {
      console.log('[Index] loadSettings: Starting to load settings');
      
      // Load settings from AppStorage
      const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
      console.log('[Index] loadSettings: Loaded settings from AppStorage:', settingsJson ? 'yes' : 'no');
      
      let settings: AppSettings;
      if (settingsJson !== undefined && settingsJson.length > 0) {
        settings = AppSettings.fromJSON(settingsJson);
        console.log('[Index] loadSettings: Parsed settings from JSON');
      } else {
        // Use default settings if none exist
        settings = new AppSettings();
        console.log('[Index] loadSettings: Using default settings');
      }
      
      this.dailyNewWords = settings.dailyNewWords;
      
      // Load API key from secure storage
      const secureStorage = SecureStorage.getInstance();
      const apiKey = await secureStorage.getApiKey();
      console.log('[Index] loadSettings: Loaded API key, length:', apiKey.length);

      // Check if API is configured
      const isConfigured = settings.apiBaseUrl.length > 0 && apiKey.length > 0;
      console.log('[Index] loadSettings: API configured:', isConfigured, 'Base URL:', settings.apiBaseUrl, 'API Key length:', apiKey.length);
      
      this.isApiConfigured = isConfigured;

      // Always configure manager with stored values so it can decide to fallback
      this.dictManager.configure(settings.apiBaseUrl, apiKey, settings.apiModel);
      console.log('[Index] loadSettings: Dictionary manager configured with API key');
      
      this.dictManager.setContextPreferences(settings.contextStyle as ContextStyle, settings.difficultyLevel as DifficultyLevel);

      // Offline vignette cache (AI-generated contexts)
      this.dictManager.setVignetteCacheSettings(
        settings.enableVignetteCache,
        settings.vignetteCacheMaxBytes,
        1000
      );

      // Scheduler mode
      const mode = parseSchedulerMode(settings.schedulerMode);
      EvolveScheduler.setMode(mode);
      
      console.log('[Index] loadSettings: Settings loaded successfully, API status:', this.isApiConfigured ? 'ready' : 'not configured');
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[Index] loadSettings: Failed to load settings:', errMsg);
      
      // Reset API status to false in case of error
      this.isApiConfigured = false;
    }
  }

  private async loadCurrentBook(): Promise<void> {
    const stored = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
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
    // Fallback to DB-based name
    this.currentBookName = stored;
  }



  private async loadDashboardData(): Promise<void> {
    try {
      const counts = await this.dbManager.getWordCounts();

      this.stats.newWordsToday = counts.get(WordStatus.NEW) ?? 0;
      this.stats.reviewDue = await this.dbManager.getReviewDueCount();
      this.stats.masteredWords = counts.get(WordStatus.MASTERED) ?? 0;

      let total = 0;
      counts.forEach((count: number) => {
        total += count;
      });
      this.stats.totalWords = total;

      this.words = await this.dbManager.getAllWords();
      this.applyFilter();
      await this.loadTodayProgress();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[Index] Failed to load dashboard data:', errMsg);
    }
  }

  private getStartOfDayMs(nowMs: number): number {
    const d = new Date(nowMs);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
  }

  private async loadTodayProgress(): Promise<void> {
    const now = Date.now();
    const start = this.getStartOfDayMs(now);
    const total = this.getTodayTargetReviewCount() + this.getTodayTargetNewCount();
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

  private getTodayTargetNewCount(): number {
    return Math.min(this.stats.newWordsToday, this.dailyNewWords);
  }

  private getTodayTargetReviewCount(): number {
    return this.stats.reviewDue;
  }

  private maybeTriggerCelebration(): void {
    const raw = AppStorage.get<string>(this.STORAGE_KEY_CELEBRATE_MS);
    if (raw === undefined || raw.length === 0) return;

    const ms = Number(raw);
    if (!Number.isFinite(ms) || ms <= 0) {
      AppStorage.setOrCreate(this.STORAGE_KEY_CELEBRATE_MS, '');
      return;
    }

    const now = Date.now();
    if (now - ms > 60 * 1000) {
      AppStorage.setOrCreate(this.STORAGE_KEY_CELEBRATE_MS, '');
      return;
    }

    AppStorage.setOrCreate(this.STORAGE_KEY_CELEBRATE_MS, '');
    this.celebrationSeed = this.celebrationSeed + 1;
    this.showCelebration = true;
    setTimeout(() => {
      this.showCelebration = false;
    }, 1600);
  }

  private async publishBackupReminderNotification(): Promise<void> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        if (this.context !== null) {
          try {
            await notificationManager.requestEnableNotification(this.context);
          } catch (_) {
          }
        }
      }

      // 创建通知通道 - 简化实现，避免复杂的API调用
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);

      // 创建类型化的通知请求
      const notificationRequest: AppNotificationRequest = {
        id: Number(Date.now()),
        slotId: 'backup_reminder',
        content: {
          content: {
            contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
            normal: {
              title: '备份提醒',
              text: '已超过3天未备份，建议立即在设置页执行备份。'
            }
          }
        }
      };

      // 使用SDK兼容的方式发布通知
      await notificationManager.publish(notificationRequest as notificationManager.NotificationRequest);
    } catch (e) {
      promptAction.showToast({ message: '已超过3天未备份，请在设置中备份', duration: 2000 });
    }
  }

  private async checkBackupReminder(): Promise<void> {
    try {
      if (!FeatureFlags.isBackupReminderEnabled()) return;
      const settingsJson = AppStorage.get<string>('webdav_settings') ?? '';
      if (settingsJson.length === 0) return;
      const settings = WebDavSettings.fromJSON(settingsJson);
      if (settings.endpoint.length === 0 || settings.username.length === 0) return;

      const now = Date.now();
      const firstRunRaw = AppStorage.get<string>(this.STORAGE_KEY_FIRST_RUN_MS) ?? String(now);
      const firstRunMs = Number(firstRunRaw);

      // 获取deviceId
      let deviceId = AppStorage.get<string>('device_id') ?? '';
      if (deviceId === '') {
        // 生成新的deviceId
        deviceId = `dev_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
        AppStorage.setOrCreate('device_id', deviceId);
      }
      const manifestJson = AppStorage.get<string>('webdav_manifest') ?? '';
      const manifest = WebDavManifest.fromJSON(manifestJson, deviceId);
      const lastBackupMs = manifest.lastBackupUploadMs > 0 ? manifest.lastBackupUploadMs : firstRunMs;

      const threeDaysMs = 3 * 24 * 60 * 60 * 1000;
      if (now - lastBackupMs < threeDaysMs) return;

      const lastRemindRaw = AppStorage.get<string>(this.STORAGE_KEY_BACKUP_REMINDER_MS) ?? '0';
      const lastRemindMs = Number(lastRemindRaw);
      const oneDayMs = 24 * 60 * 60 * 1000;
      if (now - lastRemindMs < oneDayMs) return;

      AppStorage.setOrCreate(this.STORAGE_KEY_BACKUP_REMINDER_MS, String(now));
      await this.publishBackupReminderNotification();
    } catch (e) {
      return;
    }
  }

  private getTodayProgressValue(): number {
    if (this.todayTotalCount <= 0) return 0;
    return Math.round((this.todayDoneCount / this.todayTotalCount) * 100);
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

  private jumpToWordList(): void {
    router.pushUrl({
      url: 'pages/WordBookPage'
    });
  }

  private getTodayProgressSummary(): string {
    if (this.isTodayComplete()) {
      return '今日已完成✅';
    }
    return `已完成 ${this.todayDoneCount} / ${this.todayTotalCount}`;
  }

  private getTodayProgressLabel(): string {
    const x = this.getTodayTargetNewCount();
    const y = this.getTodayTargetReviewCount();
    return `${this.todayDoneCount}/(${x}+${y})`;
  }

  private applyFilter(): void {
    let filtered = this.words;

    if (this.selectedFilter !== WordFilter.ALL) {
      let targetStatus:  WordStatus | null = null;
      switch (this.selectedFilter) {
        case WordFilter.NEW:
          targetStatus = WordStatus.NEW;
          break;
        case WordFilter.LEARNING:
          targetStatus = WordStatus.LEARNING;
          break;
        case WordFilter.REVIEW:
          targetStatus = WordStatus.REVIEW;
          break;
        case WordFilter.MASTERED:
          targetStatus = WordStatus.MASTERED;
          break;
      }
      if (targetStatus !== null) {
        const status = targetStatus;
        filtered = filtered.filter((w: WordItem): boolean => w.status === status);
      }
    }

    if (this.searchText.length > 0) {
      const search = this.searchText.toLowerCase();
      filtered = filtered.filter((w: WordItem): boolean => {
        if (w.word.toLowerCase().includes(search)) return true;
        const meaning = this.getWordMeaningText(w).toLowerCase();
        return meaning.includes(search);
      });
    }

    filtered.sort((a: WordItem, b: WordItem): number => {
      const dueA = a.dueDate > 0 ? a.dueDate : Number.MAX_SAFE_INTEGER;
      const dueB = b.dueDate > 0 ? b.dueDate : Number.MAX_SAFE_INTEGER;
      if (dueA !== dueB) {
        return dueA - dueB;
      }
      return a.word.localeCompare(b.word);
    });

    this.filteredWords = filtered;
  }

  private getWordMeaningText(word: WordItem): string {
    const contextMeaning = word.definition?.contextMeaning ?? '';
    const common = word.definition?.commonMeanings ?? [];
    const commonText = common.map((m: WordMeaning) => `${m.pos} ${m.cn}`).join(' ');
    return `${contextMeaning} ${commonText}`.trim();
  }

  private async startSession(): Promise<void> {
    if (this.currentBookId.length === 0) {
      promptAction.showDialog({
        title: '未选择词书',
        message: '请先选择或导入词书再开始学习。',
        buttons: [
          { text: '前往词书', color: '#2196F3' },
          { text: '取消', color: '#666666' }
        ]
      }).then((result) => {
        if (result.index === 0) {
          this.jumpToWordList();
        }
      });
      return;
    }
    if (!this.isApiConfigured) {
      promptAction.showDialog({
        title:  'API未配置',
        message: '请在设置中配置API密钥以生成情境故事。',
        buttons: [
          { text: '前往设置', color: '#2196F3' },
          { text: '继续', color: '#666666' }
        ]
      }).then((result) => {
        if (result.index === 0) {
          this.navigateToSettings();
        } else {
          this.doStartSession();
        }
      });
    } else {
      this.doStartSession();
    }
  }

  private async doStartSession(): Promise<void> {
    try {
      console.log('[Index] Starting session with book:', this.currentBookId, 'dailyNewWords:', this.dailyNewWords);
      const queue = await this.dbManager.getLearningQueueByBook(this.currentBookId, this.dailyNewWords);
      console.log('[Index] Learning queue size:', queue.length);

      if (queue.length === 0) {
        promptAction.showDialog({
          title: '没有可学习的单词',
          message: '当前词书没有可学习的单词，请导入或切换词书。',
          buttons: [
            { text: '前往词书', color: '#2196F3' },
            { text: '取消', color: '#666666' }
          ]
        }).then((result) => {
          if (result.index === 0) {
            this.jumpToWordList();
          }
        });
        return;
      }

      // Validate queue format before passing to ReadPage
      const validQueue = queue.filter((item: QueueItem) => {
        if (!item || !item.word) {
          console.error('[Index] Invalid queue item:', item);
          return false;
        }
        return true;
      });

      if (validQueue.length === 0) {
        promptAction.showToast({ message: '学习队列中存在无效数据', duration: 2000 });
        return;
      }

      const params: RouterParams = { queue:  validQueue };
      router.pushUrl({
        url: 'pages/ReadPage',
        params:  params
      });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[Index] Failed to start session:', errMsg);
      promptAction.showToast({ message: `无法开始学习会话: ${errMsg}`, duration: 2000 });
    }
  }

  private async importMockWords(): Promise<void> {
    try {
      this.isLoading = true;

      const cet4Words = MockDataGenerator.generateCET4Words();
      const learnedWords = MockDataGenerator.generateLearnedWords();

      const cet4Count = await this.dbManager.insertWords(cet4Words);
      const learnedCount = await this.dbManager.insertWords(learnedWords);

      promptAction.showToast({
        message: `已导入 ${cet4Count + learnedCount} 个单词`,
        duration: 2000
      });

      await this.loadDashboardData();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[Index] Failed to import words:', errMsg);
      promptAction.showToast({ message:  '导入单词失败', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private async clearAllWords(): Promise<void> {
    promptAction.showDialog({
      title:  '清空所有单词? ',
      message:  '这将删除所有单词和学习进度，不可恢复。',
      buttons: [
        { text:  '取消', color: '#666666' },
        { text: '清空所有', color: '#F44336' }
      ]
    }).then(async (result) => {
      if (result.index === 1) {
        try {
          await this.dbManager.deleteAllWords();
          await this.loadDashboardData();
          promptAction.showToast({ message: '已清空所有单词', duration: 1500 });
        } catch (e) {
          const errMsg = e instanceof Error ?  e.message : String(e);
          console.error('[Index] Failed to clear words:', errMsg);
        }
      }
    });
  }

  private navigateToSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' });
  }

  private openWordDetail(wordId: number): void {
    if (wordId <= 0) {
      promptAction.showToast({ message: '无效的单词ID', duration: 1500 });
      return;
    }

    const params: WordDetailParams = { wordId: wordId };
    router.pushUrl({
      url: 'pages/WordDetailPage',
      params: params
    });
  }

  private onFilterChange(filter: WordFilter): void {
    this.selectedFilter = filter;
    this.applyFilter();
  }

  private onSearchChange(text: string): void {
    this.searchText = text;
    this.applyFilter();
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW: return '新词';
      case WordStatus.LEARNING: return '学习中';
      case WordStatus.REVIEW: return '复习';
      case WordStatus.MASTERED: return '已掌握';
      case WordStatus.SUSPENDED: return '已暂停';
      default: return '未知';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW: return '#2196F3';
      case WordStatus.LEARNING: return '#FF9800';
      case WordStatus.REVIEW: return '#9C27B0';
      case WordStatus.MASTERED:  return '#4CAF50';
      case WordStatus.SUSPENDED: return '#9E9E9E';
      default: return '#9E9E9E';
    }
  }

  private formatDueDate(timestamp: number): string {
    const now = Date.now();
    const diff = timestamp - now;

    if (diff < 0) {
      const hours = Math.abs(Math.floor(diff / (1000 * 60 * 60)));
      if (hours < 24) {
        return `${hours}小时逾期`;
      }
      const days = Math.floor(hours / 24);
      return `${days}天逾期`;
    }

    const hours = Math.floor(diff / (1000 * 60 * 60));
    if (hours < 24) {
      return `${hours}小时后`;
    }
    const days = Math.floor(hours / 24);
    return `${days}天后`;
  }

  private getFilterOptions(): WordFilter[] {
    return [WordFilter.ALL, WordFilter.NEW, WordFilter.LEARNING, WordFilter.REVIEW, WordFilter.MASTERED];
  }

  build() {
    Stack() {
      Column() {
        this.buildTopNavigation()

        if (this.isLoading) {
          Column() {
            LoadingAnimation({
              type: LoadingType.PULSE,
              animSize: 60,
              color: DesignTokens.Colors.PRIMARY,
              text: '加载中...'
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              this.buildHeroSection()
              this.buildLearningProgressCard()
            }
            .width('100%')
            .padding({
              left: DesignTokens.Layout.CONTAINER_PADDING,
              right: DesignTokens.Layout.CONTAINER_PADDING,
              bottom: DesignTokens.Spacing.XXXL
            })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FB')

      if (this.showCelebration) {
        CelebrationParticles({ seed: this.celebrationSeed })
          .width('100%')
          .height('100%')
          .enabled(false)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildTopNavigation() {
    Row() {
      Row() {
        Text('🟦')
          .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
          .margin({ right: DesignTokens.Spacing.SM })

        Text('微语单词')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
          .fontColor(DesignTokens.Colors.GRAY_900)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Text('⚙')
        .fontSize(22)
        .fontColor(DesignTokens.Colors.GRAY_700)
        .onClick(() => this.navigateToSettings())
    }
    .width('100%')
    .height(64)
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      top: DesignTokens.Spacing.SM,
      bottom: DesignTokens.Spacing.SM
    })
    .backgroundColor('#F5F7FB')
  }

  @Builder
  buildHeroSection() {
    Column() {
      Text('通过微语境科学记忆单词')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_800)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')

      Text(`当前词书：${this.currentBookName}`)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: DesignTokens.Spacing.SM })
        .width('100%')

      Button('开始学习')
        .width('100%')
        .height(64)
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor(DesignTokens.Colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.XL)
        .margin({ top: DesignTokens.Spacing.LG })
        .stateEffect(true)
        .onClick(() => this.startSession())

      Button('词书管理')
        .width('100%')
        .height(52)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.PRIMARY)
        .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
        .borderRadius(DesignTokens.BorderRadius.XL)
        .margin({ top: DesignTokens.Spacing.MD })
        .stateEffect(true)
        .onClick(() => this.jumpToWordList())
    }
    .width('100%')
    .padding(DesignTokens.Spacing.XL)
    .backgroundColor('#FFFFFFCC')
    .borderRadius(DesignTokens.BorderRadius.XL)
    .border({ width: 1, color: '#E5ECF7' })
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
  }

  @Builder
  buildLearningProgressCard() {
    Column() {
      Row() {
        Text('今日学习进度')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.GRAY_800)

        Blank()

        Text(this.getTodayProgressSummary())
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.MD })

      Progress({
        value: this.isTodayComplete() ? 100 : this.getTodayProgressValue(),
        total: 100,
        type: ProgressType.Linear
      })
        .height(8)
        .width('100%')
        .color(DesignTokens.Colors.PRIMARY)
        .backgroundColor(DesignTokens.Colors.GRAY_200)

      Row({ space: DesignTokens.Spacing.MD }) {
        this.buildMiniStatCard('新词', Math.min(this.stats.newWordsToday, this.dailyNewWords), DesignTokens.Colors.PRIMARY)
        this.buildMiniStatCard('待复习', this.stats.reviewDue, DesignTokens.Colors.SECONDARY)
        this.buildMiniStatCard('累计', this.stats.totalWords, DesignTokens.Colors.GRAY_700)
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.MD })

      if (this.streakDays > 0) {
        Text(`连续学习 ${this.streakDays} 天`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .margin({ top: DesignTokens.Spacing.SM })
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.LG)
    .backgroundColor('#FFFFFFCC')
    .borderRadius(DesignTokens.BorderRadius.XL)
    .border({ width: 1, color: '#E5ECF7' })
    .margin({ top: DesignTokens.Spacing.LG })
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
  }

  @Builder
  buildMiniStatCard(label: string, value: number, color: ResourceColor) {
    Column() {
      Text(`${value}`)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(color)

      Text(label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(DesignTokens.Colors.GRAY_50)
    .borderRadius(DesignTokens.BorderRadius.MD)
    .border({ width: 1, color: DesignTokens.Colors.BORDER_LIGHT })
  }

  @Builder
  buildRecommendedBooks() {
    Column() {
      Row() {
        Text('推荐词书')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.GRAY_800)

        Blank()

        Text('查看全部')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.PRIMARY)
          .onClick(() => this.jumpToWordList())
      }
      .width('100%')

      Row({ space: DesignTokens.Spacing.MD }) {
        ForEach(BuiltInWordBooks.slice(0, 3), (book: WordBookDefinition) => {
          this.buildRecommendedBookCard(book.id, book.name, book.wordCount)
        }, (book: WordBookDefinition) => book.id)
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.MD })
    }
    .width('100%')
    .margin({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.XXXL })
  }

  @Builder
  buildRecommendedBookCard(bookId: string, name: string, total: number) {
    Column() {
      Text(name)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`${total} 词`)
        .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .margin({ top: DesignTokens.Spacing.XS })
    }
    .layoutWeight(1)
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor('#FFFFFFCC')
    .borderRadius(DesignTokens.BorderRadius.LG)
    .border({ width: 1, color: '#E5ECF7' })
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/WordListPage',
        params: {
          bookId,
          bookName: name
        }
      });
    })
  }

  private getOverallProgressValue(): number {
    if (this.stats.totalWords <= 0) {
      return 0;
    }
    const value = (this.stats.masteredWords / this.stats.totalWords) * 100;
    return Math.min(100, Math.max(0, Number(value.toFixed(1))));
  }

  private getWordCountByStatus(status: WordStatus): number {
    return this.words.reduce((total: number, item: WordItem) => {
      return total + (item.status === status ? 1 : 0);
    }, 0);
  }

  @Builder
  buildStatsSection() {
    Column() {
      Text("今日进度")
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Grid() {
        GridItem() {
          this.buildStatCard('新词', `${Math.min(this.stats.newWordsToday, this.dailyNewWords)}`,
            `共 ${this.dailyNewWords}`, DesignTokens.Colors.PRIMARY, DesignTokens.Colors.PRIMARY_LIGHT + '20', '📚')
        }

        GridItem() {
          this.buildStatCard('待复习', `${this.stats.reviewDue}`, '个单词', DesignTokens.Colors.SECONDARY, DesignTokens.Colors.SECONDARY_LIGHT + '20', '🔄')
        }

        GridItem() {
          this.buildStatCard('总单词', `${this.stats.totalWords}`, '个', '#9C27B0', '#F3E5F5', '📊')
        }

        GridItem() {
          this.buildStatCard('已掌握', `${this.stats.masteredWords}`, '个单词', DesignTokens.Colors.SUCCESS, DesignTokens.Colors.SUCCESS_LIGHT + '20', '✅')
        }
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(DesignTokens.Spacing.MD)
      .rowsGap(DesignTokens.Spacing.MD)
    }
  }

  @Builder
  buildStatCard(title: string, value: string, subtitle: string, color:  ResourceColor, bgColor: ResourceColor, icon: string) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
          .margin({ right: DesignTokens.Spacing.SM })
          .fontColor(color)
        
        Text(title)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Text(value)
        .fontSize(DesignTokens.Typography.FONT_SIZE_3XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(color)
        .margin({ top: DesignTokens.Spacing.SM })
        .width('100%')
        .textAlign(TextAlign.Start)

      Text(subtitle)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .margin({ top: DesignTokens.Spacing.XS })
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding(DesignTokens.Spacing.LG)
    .backgroundColor(bgColor)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_2)
    .animation({
      duration: DesignTokens.Animations.DURATION_NORMAL,
      curve: DesignTokens.Animations.CURVE_EASE_OUT
    })
  }

  @Builder
  buildStartButton() {
    Column() {
      // 开始学习按钮
      Button() {
        Row() {
          Text('开始学习')
            .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(DesignTokens.Colors.WHITE)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(64)
      .backgroundColor(DesignTokens.Colors.PRIMARY)
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ top: DesignTokens.Spacing.XXL })
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_2)
      .stateEffect(true)
      .animation({
        duration: DesignTokens.Animations.DURATION_NORMAL,
        curve: DesignTokens.Animations.CURVE_EASE_OUT
      })
      .accessibilityText('开始学习会话')
      .onClick(() => this.startSession())

      // 辅助按钮区域
      Row() {
        Button('提前复习')
          .layoutWeight(1)
          .height(56)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(DesignTokens.Colors.SECONDARY)
          .borderRadius(DesignTokens.BorderRadius.FULL)
          .margin({ top: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.MD })
          .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
          .stateEffect(true)
          .onClick(() => this.startSession())

        Button('去词书')
          .layoutWeight(1)
          .height(56)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.GRAY_700)
          .backgroundColor(DesignTokens.Colors.GRAY_200)
          .borderRadius(DesignTokens.BorderRadius.FULL)
          .margin({ top: DesignTokens.Spacing.LG })
          .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
          .stateEffect(true)
          .onClick(() => this.jumpToWordList())
      }
    }
  }

  @Builder
  buildTodayProgressIndicator() {
    Column() {
      Row() {
        Text('今日进度')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)

        Blank()

        Text(this.getTodayProgressSummary())
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.isTodayComplete() ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.GRAY_700)
      }
      .width('100%')

      if (this.streakDays > 0) {
        Text(`连续 ${this.streakDays} 天`)
          .fontSize(12)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .margin({ top: 4 })
          .width('100%')
      }

      // 环形进度条
      Column() {
        Stack() {
          Progress({
            value: this.isTodayComplete() ? 100 : this.getTodayProgressValue(),
            total: 100,
            type: ProgressType.Ring
          })
            .width(120)
            .height(120)
            .color(DesignTokens.Colors.SUCCESS)
            .backgroundColor(DesignTokens.Colors.GRAY_200)
            .style({
              strokeWidth: 12
            })

          Column() {
            Text(`${this.isTodayComplete() ? 100 : this.getTodayProgressValue()}%`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_3XL)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
              .fontColor(DesignTokens.Colors.GRAY_900)

            Text(this.getTodayProgressLabel())
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .margin({ top: DesignTokens.Spacing.XS })
          }
        }
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      if (this.isTodayComplete()) {
        Row() {
          Button('提前复习')
            .layoutWeight(1)
            .height(48)
            .fontSize(13)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHT + '30')
            .borderRadius(24)
            .onClick(() => this.startSession())
            .stateEffect(true)
            .animation({
              duration: DesignTokens.Animations.DURATION_FAST,
              curve: DesignTokens.Animations.CURVE_EASE_OUT
            })

          Button('去词书')
            .layoutWeight(1)
            .height(48)
            .fontSize(13)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .backgroundColor(DesignTokens.Colors.GRAY_200)
            .borderRadius(24)
            .margin({ left: DesignTokens.Spacing.SM })
            .onClick(() => this.jumpToWordList())
            .stateEffect(true)
            .animation({
              duration: DesignTokens.Animations.DURATION_FAST,
              curve: DesignTokens.Animations.CURVE_EASE_OUT
            })
        }
        .width('100%')

        Text('建议：添加新词，保持连续学习')
          .fontSize(12)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .margin({ top: 8 })
          .width('100%')
      } else {
        Row() {
          Text(`${this.todayDoneCount} / ${this.todayTotalCount}`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
            .fontColor(DesignTokens.Colors.GRAY_800)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.LG)
    .backgroundColor(DesignTokens.Colors.WHITE)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ top: DesignTokens.Spacing.MD })
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    .accessibilityText('今日学习进度')
    .accessibilityDescription(this.getTodayProgressLabel())
  }

  @Builder
  buildQuickActions() {
    Row() {
      Button('导入CET-4词汇')
        .height(40)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.PRIMARY)
        .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHT + '20')
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .stateEffect(true)
        .animation({
          duration: DesignTokens.Animations.DURATION_FAST,
          curve: DesignTokens.Animations.CURVE_EASE_OUT
        })
        .onClick(() => this.importMockWords())
        .margin({ right: DesignTokens.Spacing.SM })

      Button('导入词书')
        .height(40)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.SUCCESS)
        .backgroundColor(DesignTokens.Colors.SUCCESS_LIGHT + '20')
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .stateEffect(true)
        .animation({
          duration: DesignTokens.Animations.DURATION_FAST,
          curve: DesignTokens.Animations.CURVE_EASE_OUT
        })
        .onClick(() => {
          router.pushUrl({
            url: 'pages/ImportPage'
          });
        })
        .margin({ right: DesignTokens.Spacing.SM })

      Button('清空所有')
        .height(40)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.ERROR)
        .backgroundColor(DesignTokens.Colors.ERROR_LIGHT + '20')
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .stateEffect(true)
        .animation({
          duration: DesignTokens.Animations.DURATION_FAST,
          curve: DesignTokens.Animations.CURVE_EASE_OUT
        })
        .onClick(() => this.clearAllWords())
    }
    .width('100%')
    .margin({ top: DesignTokens.Spacing.XXL })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildWordList() {
    Column() {
      Row() {
        Text('单词本')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)

        Blank()

        Text(`${this.filteredWords.length} 个单词`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_500)
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.XXL })

      Row() {
        Text('🔍')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontColor(DesignTokens.Colors.GRAY_400)

        TextInput({ text: this.searchText, placeholder: '搜索单词...' })
          .layoutWeight(1)
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.FULL)
          .padding({
            left: DesignTokens.Spacing.SM,
            right: DesignTokens.Spacing.LG
          })
          .margin({ left: DesignTokens.Spacing.SM })
          .onChange((value:  string) => this.onSearchChange(value))
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.MD })

      Scroll() {
        Row() {
          ForEach(this.getFilterOptions(), (filter: WordFilter) => {
            Text(filter)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.selectedFilter === filter ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_600)
            .backgroundColor(this.selectedFilter === filter ? DesignTokens.Colors.PRIMARY :  DesignTokens.Colors.GRAY_100)
            .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
            .borderRadius(DesignTokens.BorderRadius.LG)
            .margin({ right: DesignTokens.Spacing.MD })
            .onClick(() => this.onFilterChange(filter))
          })
        }
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.MD })

      if (this.filteredWords.length === 0) {
        Column() {
          Text('📁')
            .fontSize(DesignTokens.Typography.FONT_SIZE_4XL)
            .fontColor(DesignTokens.Colors.GRAY_300)

          Text('未找到单词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ top: DesignTokens.Spacing.LG })

          Text('请导入一些单词开始学习!')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_400)
            .margin({ top: DesignTokens.Spacing.SM })
        }
        .width('100%')
        .padding(DesignTokens.Spacing.XXXL)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.filteredWords, (word: WordItem) => {
            ListItem() {
              this.buildWordItem(word)
            }
          }, (word: WordItem) => word.id.toString())
        }
      }
    }
    .borderRadius(DesignTokens.BorderRadius.LG)
    .borderWidth(this.wordListHighlight ? 1 : 0)
    .borderColor(this.wordListHighlight ? DesignTokens.Colors.PRIMARY : Color.Transparent)
    .padding(this.wordListHighlight ? DesignTokens.Spacing.MD : 0)
  }

  @Builder
  buildWordItem(word: WordItem) {
    Row() {
      // 侧边颜色条
      Column()
        .width(4)
        .height('100%')
        .backgroundColor(this.getStatusColor(word.status))
        .borderRadius(DesignTokens.BorderRadius.LG)

      Column() {
        Row() {
          Text(word.word)
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
            .fontColor(DesignTokens.Colors.GRAY_900)

          Blank()

          // 稳定性进度条
          Column() {
            Text(`S:  ${word.fsrsState.stability.toFixed(1)}`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)

            Progress({
              value: Math.min(word.fsrsState.stability, 30),
              total: 30,
              type: ProgressType.Linear
            })
              .width(50)
              .height(4)
              .color(DesignTokens.Colors.SUCCESS)
              .backgroundColor(DesignTokens.Colors.GRAY_300)
              .margin({ top: DesignTokens.Spacing.XS })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Row() {
          // 状态标签
          Text(this.getStatusText(word.status))
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.getStatusColor(word.status))
            .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM, top: DesignTokens.Spacing.XS, bottom: DesignTokens.Spacing.XS })
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .margin({ right: DesignTokens.Spacing.MD })

          // 复习次数
          if (word.history.getReviewCount() > 0) {
            Text(`${word.history.getReviewCount()} 次复习`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_500)
              .margin({ right: DesignTokens.Spacing.MD })
          }

          // 到期时间
          if (word.status !== WordStatus.NEW && word.status !== WordStatus.MASTERED) {
            Text(this.formatDueDate(word.dueDate))
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(word.dueDate <= Date.now() ? DesignTokens.Colors.ERROR : DesignTokens.Colors.GRAY_500)
          }
        }
        .margin({ top: DesignTokens.Spacing.XS })

        // 单词释义（仅显示部分）
        Text(this.getWordMeaningText(word))
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.SM })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: DesignTokens.Spacing.LG })
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
    .backgroundColor(DesignTokens.Colors.WHITE)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ bottom: DesignTokens.Spacing.MD })
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    .onClick(() => this.openWordDetail(word.id))
    .animation({
      duration: DesignTokens.Animations.DURATION_FAST,
      curve: DesignTokens.Animations.CURVE_EASE_OUT
    })
  }
}
