// =====================================================
// ReadPage.ets - Core Learning Interface
// Implements Snapshot undo mechanism and word interaction
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import media from '@ohos.multimedia.media';
import vibrator from '@ohos.vibrator';
import {
  WordItem,
  WordStatus,
  FSRSState,
  ReviewHistory,
  WordDefinition,
  WordSnapshot,
  LearningSession,
  QueueItem,
  AppSettings,
  Rating,
  WordMeaning
} from '../model/WordModel';
import { WordReviewer } from '../algorithm/Algorithm';
import { DBManager } from '../database/DBManager';
import { DictionaryManager, LookupResult } from '../manager/DictionaryManager';
import { ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import { StoryGenerationOutcome, StoryGenerationPipeline, StorySource } from '../context/StoryGenerationPipeline';
import {
  SessionPlanner,
  TaskItem,
  TaskType,
  ErrorType,
  TaskDifficulty,
  SessionConfig
} from '../manager/SessionPlanner';
import {
  ContextValidator, ValidationResult, ValidationIssue
} from '../context/ContextValidator';
import { buildUserFacingError, ErrorInfo } from '../utils/ErrorClassifier';
import { SecureStorage } from '../utils/SecureStorage';
import {
  normalizeQueueFromRouterParams, RawWordItem, RawQueueItem
} from '../utils/RouteParamNormalizer';
import { DesignTokens } from '../model/DesignTokens';
import { TopBanner, TopBannerType } from '../ui/TopBanner';

/**
 * Router params interface
 */
interface ReadPageParams {
  queue: QueueItem[];
}

class WordCountRange {
  minWords: number;
  maxWords: number;

  constructor(minWords: number, maxWords: number) {
    this.minWords = minWords;
    this.maxWords = maxWords;
  }
}

enum FlashButton {
  NONE = 'NONE',
  FORGET = 'FORGET',
  HARD = 'HARD',
  REMEMBER = 'REMEMBER',
  UNDO = 'UNDO'
}

enum BannerType {
  NONE = 'NONE',
  ERROR = 'ERROR',
  WARNING = 'WARNING',
  INFO = 'INFO'
}

enum BannerAction {
  NONE = 'NONE',
  RETRY = 'RETRY',
  SETTINGS = 'SETTINGS',
  SKIP = 'SKIP'
}

enum SessionErrorAction {
  NONE = 'NONE',
  RETRY = 'RETRY',
  BACK = 'BACK',
  WORD_BOOKS = 'WORD_BOOKS'
}

/**
 * Interface for objects with toJSON method
 */
interface ToJSONable {
  toJSON?: () => string;
}

/**
 * Interface for objects with clone method
 */
interface Cloneable {
  clone?: () => object;
}

/**
 * Raw FSRS state structure from router params
 */
interface RawFSRSState {
  difficulty?: number;
  stability?: number;
  retrievability?: number;
  reps?: number;
  lapses?: number;
}

/**
 * Raw history item structure
 */
interface RawHistoryItem {
  timestamp: number;
  rating: number;
  scheduledDays: number;
  stateBefore: string | RawFSRSState;
  stateAfter: string | RawFSRSState;
}

/**
 * Raw review history structure
 */
interface RawReviewHistory {
  items?: RawHistoryItem[];
}

/**
 * Common meaning structure
 */
interface CommonMeaning {
  pos: string;
  cn: string;
}

/**
 * Raw word definition structure
 */
interface RawWordDefinition {
  word?: string;
  phonetic?: string;
  pos?: string;
  contextMeaning?: string;
  commonMeanings?: Array<CommonMeaning>;
  source?: string;
}

/**
 * Parsed word in story with position info
 */
class StoryWord {
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

/**
 * Dialog state for word popup
 */
class DialogState {
  isVisible: boolean;
  word: string;
  definition: WordDefinition | null;
  isLoading: boolean;
  wordItem: WordItem | null;
  hasBeenReviewed: boolean;
  canUndo: boolean;

  constructor() {
    this.isVisible = false;
    this.word = '';
    this.definition = null;
    this.isLoading = false;
    this.wordItem = null;
    this.hasBeenReviewed = false;
    this.canUndo = false;
  }

  reset(): void {
    this.isVisible = false;
    this.word = '';
    this.definition = null;
    this.isLoading = false;
    this.wordItem = null;
    this.hasBeenReviewed = false;
    this.canUndo = false;
  }
}

interface PreloadedStory {
  text: string;
  words: StoryWord[];
  error: string;
  supportWords: string[];
}

@Entry
@Component
struct ReadPage {
  // Session state
  @State private session: LearningSession = new LearningSession();
  @State private currentWord: WordItem | null = null;
  @State private currentSnapshot: WordSnapshot | null = null;
  // Task queue state (NEW)
  @State private taskQueue: TaskItem[] = [];
  @State private currentTask: TaskItem | null = null;
  @State private taskIndex: number = 0;
  // Task loading UX (NEW)
  @State private isTaskLoading: boolean = false;
  @State private taskLoadingHint: string = '加载任务中...';
  // Story state
  @State private storyText: string = '';
  @State private storyWords: StoryWord[] = [];
  @State private supportWords: string[] = [];
  @State private isGeneratingStory: boolean = false;
  @State private storyError: string = '';
  @State private showTranslation: boolean = false;
  @State private showTargetHighlight: boolean = false;
  private targetHighlightTimer: number | null = null;
  // Dialog state
  @State private dialogState: DialogState = new DialogState();
  @State private flashButton: FlashButton = FlashButton.NONE;
  @State private lastReviewHint: string = '';
  @State private undoWordIdStack: number[] = [];
  @State private fuzzyMemoryChecked: boolean = false;
  @State private isReviewCooling: boolean = false;
  @State private showUndoHint: boolean = false;
  @State private bannerType: BannerType = BannerType.NONE;
  @State private bannerMessage: string = '';
  @State private bannerPrimaryAction: BannerAction = BannerAction.NONE;
  @State private bannerSecondaryAction: BannerAction = BannerAction.NONE;

  // Session load error state
  @State private sessionErrorTitle: string = '';
  @State private sessionErrorMessage: string = '';
  @State private sessionErrorPrimaryAction: SessionErrorAction = SessionErrorAction.NONE;
  @State private sessionErrorSecondaryAction: SessionErrorAction = SessionErrorAction.NONE;
  @State private meaningExpanded: boolean = true;
  @State private hasPreloadedStory: boolean = false;
  // Audio player
  private avPlayer: media.AVPlayer | null = null;
  @State private isPlayingAudio: boolean = false;
  @State private enableTTS: boolean = true;
  @State private newbieMode: boolean = true;
  private pendingReviewReflection: string = '';
  private undoHintTimer: number | null = null;
  private bannerTimer: number | null = null;
  private isPreloadingNextTask: boolean = false;
  private preloadedTaskIndex: number = -1;
  private preloadedStoryCache: Map<number, PreloadedStory> = new Map<number, PreloadedStory>();
  // Cache for parseStoryIntoWords to avoid redundant parsing
  private cachedStoryText: string = '';
  private cachedStoryWords: StoryWord[] = [];
  // Track if current task has been reviewed (prevent duplicate submissions)
  private currentTaskReviewed: boolean = false;

  private getLastUndoWordId(): number {
    if (this.undoWordIdStack.length === 0) {
      return 0;
    }
    return this.undoWordIdStack[this.undoWordIdStack.length - 1];
  }

  private pushUndoWordId(wordId: number): void {
    const next: number[] = [];
    for (const id of this.undoWordIdStack) {
      if (id !== wordId) {
        next.push(id);
      }
    }
    next.push(wordId);
    while (next.length > 1) {
      next.shift();
    }
    this.undoWordIdStack = next;
  }

  private popUndoWordId(): number {
    const last = this.getLastUndoWordId();
    if (last <= 0) {
      return 0;
    }
    const next = this.undoWordIdStack.slice(0, this.undoWordIdStack.length - 1);
    this.undoWordIdStack = next;
    return last;
  }

  private removeUndoWordId(wordId: number): void {
    const next: number[] = [];
    for (const id of this.undoWordIdStack) {
      if (id !== wordId) {
        next.push(id);
      }
    }
    this.undoWordIdStack = next;
  }

  private clearUndoHintTimer(): void {
    if (this.undoHintTimer !== null) {
      clearTimeout(this.undoHintTimer);
      this.undoHintTimer = null;
    }
  }

  private hideUndoHint(): void {
    this.clearUndoHintTimer();
    if (this.showUndoHint) {
      this.showUndoHint = false;
    }
  }

  private scheduleUndoHint(): void {
    this.hideUndoHint();
    if (!this.canUndoLastReviewed()) {
      return;
    }
    this.showUndoHint = true;
    this.undoHintTimer = setTimeout(() => {
      this.showUndoHint = false;
      this.undoHintTimer = null;
    }, 4000);
  }

  private clearTargetHighlightTimer(): void {
    if (this.targetHighlightTimer !== null) {
      clearTimeout(this.targetHighlightTimer);
      this.targetHighlightTimer = null;
    }
  }

  private scheduleTargetHighlight(): void {
    this.clearTargetHighlightTimer();
    this.showTargetHighlight = false;
    // Issue #2 fix: Increased delay from 800ms to 1500ms to give users more time
    this.targetHighlightTimer = setTimeout(() => {
      this.showTargetHighlight = true;
      this.targetHighlightTimer = null;
    }, 1500);
  }

  private clearBannerTimer(): void {
    if (this.bannerTimer !== null) {
      clearTimeout(this.bannerTimer);
      this.bannerTimer = null;
    }
  }

  private showBanner(type: BannerType, message: string, primary: BannerAction = BannerAction.NONE,
    secondary: BannerAction = BannerAction.NONE): void {
    this.clearBannerTimer();
    this.bannerType = type;
    this.bannerMessage = message;
    this.bannerPrimaryAction = primary;
    this.bannerSecondaryAction = secondary;
  }

  private showBannerForDuration(type: BannerType, message: string, durationMs: number): void {
    this.showBanner(type, message);
    this.bannerTimer = setTimeout(() => {
      this.hideBanner();
    }, durationMs);
  }

  private hideBanner(): void {
    this.clearBannerTimer();
    this.bannerType = BannerType.NONE;
    this.bannerMessage = '';
    this.bannerPrimaryAction = BannerAction.NONE;
    this.bannerSecondaryAction = BannerAction.NONE;
  }

  private showSessionError(title: string, message: string,
    primary: SessionErrorAction = SessionErrorAction.NONE,
    secondary: SessionErrorAction = SessionErrorAction.NONE): void {
    this.sessionErrorTitle = title;
    this.sessionErrorMessage = message;
    this.sessionErrorPrimaryAction = primary;
    this.sessionErrorSecondaryAction = secondary;
  }

  private clearSessionError(): void {
    this.sessionErrorTitle = '';
    this.sessionErrorMessage = '';
    this.sessionErrorPrimaryAction = SessionErrorAction.NONE;
    this.sessionErrorSecondaryAction = SessionErrorAction.NONE;
  }

  private handleSessionErrorAction(action: SessionErrorAction): void {
    switch (action) {
      case SessionErrorAction.RETRY:
        this.clearSessionError();
        this.initializeSession();
        return;
      case SessionErrorAction.BACK:
        router.back();
        return;
      case SessionErrorAction.WORD_BOOKS:
        router.pushUrl({ url: 'pages/WordBookPage' });
        return;
      default:
        return;
    }
  }

  private getBannerActionLabel(action: BannerAction): string {
    switch (action) {
      case BannerAction.RETRY:
        return '重试';
      case BannerAction.SETTINGS:
        return '去设置';
      case BannerAction.SKIP:
        return '跳过';
      default:
        return '';
    }
  }

  private getSessionActionLabel(action: SessionErrorAction): string {
    switch (action) {
      case SessionErrorAction.RETRY:
        return '重试';
      case SessionErrorAction.BACK:
        return '返回';
      case SessionErrorAction.WORD_BOOKS:
        return '前往词书';
      default:
        return '';
    }
  }

  private handleBannerAction(action: BannerAction): void {
    switch (action) {
      case BannerAction.RETRY:
        this.hideBanner();
        this.loadCurrentTask();
        return;
      case BannerAction.SETTINGS:
        this.hideBanner();
        router.pushUrl({ url: 'pages/SettingsPage' });
        return;
      case BannerAction.SKIP:
        this.hideBanner();
        this.taskIndex++;
        this.loadCurrentTask();
        return;
      default:
        return;
    }
  }

  private startReviewCooldown(): void {
    this.isReviewCooling = true;
    setTimeout(() => {
      this.isReviewCooling = false;
    }, 1000);
  }

  // Managers
  private dbManager: DBManager = DBManager.getInstance();
  private dictManager: DictionaryManager = DictionaryManager.getInstance();
  private wordReviewer: WordReviewer = new WordReviewer();
  private sessionPlanner: SessionPlanner = SessionPlanner.getInstance();
  private contextValidator: ContextValidator | null = null;
  private storyPipeline: StoryGenerationPipeline | null = null;
  // Settings
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';
  // Context Generation Settings
  @State private selectedContextStyle: ContextStyle = ContextStyle.CONVERSATIONAL;
  @State private selectedDifficultyLevel: DifficultyLevel = DifficultyLevel.CET6;
  @State private showContextSettings: boolean = false;
  @State private showWordBookSelectionDialog: boolean = false;
  @State private userWordBooks: string[] = [];
  @State private newWordBookName: string = '';
  @State private selectedWordBookId: string = '';

  aboutToAppear(): void {
    const startTime = Date.now();
    console.log('[Perf] ReadPage aboutToAppear started');

    // Initialize managers
    this.contextValidator = ContextValidator.getInstance();
    this.storyPipeline = new StoryGenerationPipeline(this.dictManager);
    console.log('[ReadPage] ContextValidator initialized');

    this.loadUserSettingsAsync();
    this.initializeSession();
    this.initAudioPlayer();

    console.log(`[Perf] ReadPage aboutToAppear took ${Date.now() - startTime}ms`);
  }

  aboutToDisappear(): void {
    const startTime = Date.now();
    console.log('[Perf] ReadPage aboutToDisappear started');

    this.releaseAudioPlayer();

    console.log(`[Perf] ReadPage aboutToDisappear took ${Date.now() - startTime}ms`);
  }

  /**
   * Load user settings (API + context preferences + TTS)
   */
  private async loadUserSettingsAsync(): Promise<void> {
    try {
      console.log('[ReadPage] Loading user settings...');

      const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
      if (settingsJson !== undefined && settingsJson.length > 0) {
        const settings = AppSettings.fromJSON(settingsJson);
        const secureStorage = SecureStorage.getInstance();
        const apiKey = await secureStorage.getApiKey();
        // TTS
        this.enableTTS = settings.enableTTS;
        this.newbieMode = settings.newbieMode;
        // Context preferences
        this.selectedContextStyle = settings.contextStyle as ContextStyle;
        this.selectedDifficultyLevel = settings.difficultyLevel as DifficultyLevel;
        this.dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel);
        // Configure API (optional)
        this.dictManager.configure(settings.apiBaseUrl, apiKey, settings.apiModel);

        console.log('[ReadPage] Settings loaded successfully:', {
          enableTTS: this.enableTTS,
          contextStyle: this.selectedContextStyle,
          difficultyLevel: this.selectedDifficultyLevel
        });
      } else {
        console.log('[ReadPage] No settings found, using defaults');
      }
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      console.warn('[ReadPage] Failed to load settings:', errorMsg);
    }
  }

  /**
   * Initialize learning session from router params
   * Issue #3 fix: Optimized for faster startup response
   */
  private async initializeSession(): Promise<void> {
    const startTime = Date.now();
    console.log('[Perf] initializeSession started');

    this.isTaskLoading = true;
    this.taskLoadingHint = '准备学习任务...';
    this.clearSessionError();
    try {
      console.log('[ReadPage] Initializing learning session...');

      const params = router.getParams() as ReadPageParams;

      // Enhanced parameter validation
      if (!params) {
        console.error('[ReadPage] No parameters received');
        this.showSessionError(
          '学习任务参数错误',
          '未收到学习队列参数，请返回重新进入。',
          SessionErrorAction.BACK,
          SessionErrorAction.RETRY
        );
        return;
      }

      if (!params.queue || !Array.isArray(params.queue)) {
        console.error('[ReadPage] Invalid queue parameter:', params.queue);
        this.showSessionError(
          '学习队列格式错误',
          '学习队列格式不正确，请返回重新进入。',
          SessionErrorAction.BACK,
          SessionErrorAction.RETRY
        );
        return;
      }

      console.log('[ReadPage] Received queue with', params.queue.length, 'items');

      if (params.queue.length === 0) {
        console.error('[ReadPage] Empty queue received');
        this.showSessionError(
          '没有可学习的单词',
          '当前词书中没有可学习的单词，请先导入或切换词书。',
          SessionErrorAction.WORD_BOOKS,
          SessionErrorAction.BACK
        );
        return;
      }

      // Convert router params to real class instances (avoid prototype loss)
      const normalizedQueue = normalizeQueueFromRouterParams(params.queue as Array<RawQueueItem>);

      if (normalizedQueue.length === 0) {
        console.error('[ReadPage] Normalized queue is empty');
        this.showSessionError(
          '学习队列解析失败',
          '队列解析失败，请重试或返回重新进入。',
          SessionErrorAction.RETRY,
          SessionErrorAction.BACK
        );
        return;
      }

      // Convert word queue to task queue using SessionPlanner
      this.session = new LearningSession();
      this.session.addToQueue(normalizedQueue);

      // Generate task queue from word queue
      const words = normalizedQueue.map((item: QueueItem): WordItem => item.word);
      console.log('[ReadPage] Generating task queue for', words.length, 'words...');

      // Issue #3 fix: Task generation is synchronous but fast, move it off critical path
      const taskGenStart = Date.now();
      this.taskQueue = this.sessionPlanner.planMicroContextSession(words);
      this.taskIndex = 0;
      console.log(`[Perf] Task queue generation took ${Date.now() - taskGenStart}ms`);

      console.log('[ReadPage] Task queue generated with', this.taskQueue.length, 'tasks');

      // Validate task queue
      if (!this.taskQueue || this.taskQueue.length === 0) {
        console.error('[ReadPage] Failed to generate task queue');
        this.showSessionError(
          '生成学习任务失败',
          '无法生成学习任务，请重试或切换词书。',
          SessionErrorAction.RETRY,
          SessionErrorAction.WORD_BOOKS
        );
        return;
      }

      // Log task distribution
      const taskTypes = this.taskQueue.reduce((acc: Map<string, number>, task: TaskItem) => {
        const count = acc.get(task.type) || 0;
        acc.set(task.type, count + 1);
        return acc;
      }, new Map<string, number>());

      // Convert Map to object manually since Object.fromEntries is restricted in ArkTS
      const taskDist: Record<string, number> = {} as Record<string, number>;
      taskTypes.forEach((count: number, type: string) => {
        taskDist[type] = count;
      });

      console.log('[ReadPage] Task distribution:', taskDist);

      // Load first task
      console.log('[ReadPage] Loading first task...');
      await this.loadCurrentTask();

      console.log('[ReadPage] Session initialized successfully');
      console.log(`[Perf] initializeSession took ${Date.now() - startTime}ms`);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to initialize session:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      this.showSessionError(
        '学习任务初始化失败',
        `初始化失败：${errorMsg}`,
        SessionErrorAction.RETRY,
        SessionErrorAction.BACK
      );
    } finally {
      this.isTaskLoading = false;
    }
  }

  private async ensureDefinitionLoaded(word: WordItem): Promise<void> {
    const def = word.definition ?? new WordDefinition();
    const hasMeaning = (def.contextMeaning.trim().length > 0) ||
      (def.commonMeanings.length > 0 && def.commonMeanings[0].cn.trim().length > 0);

    if (hasMeaning) {
      return;
    }

    // Issue #3 fix: Add timeout wrapper to prevent hanging
    const DEFINITION_TIMEOUT_MS = 8000; // 8 seconds
    const timeoutPromise = new Promise<void>((_, reject) => {
      setTimeout(() => reject(new Error('Definition lookup timeout')), DEFINITION_TIMEOUT_MS);
    });

    try {
      // 1) Try DB cache
      const cached = await this.dbManager.getCachedDefinition(word.word.trim().toLowerCase());
      if (cached !== null) {
        word.definition = cached;
        return;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn('[ReadPage] getCachedDefinition failed:', msg);
    }

    // 2) Try DictionaryManager with timeout (may call API)
    try {
      const lookupPromise = this.dictManager.lookup(word.word);
      const res: LookupResult = await Promise.race([lookupPromise, timeoutPromise]) as LookupResult;
      if (res.success && res.definition !== null) {
        word.definition = res.definition;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn('[ReadPage] lookup definition failed:', msg);
    }
  }

  /**
   * Initialize audio player for TTS
   */
  private async initAudioPlayer(): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();

      this.avPlayer.on('stateChange', (state: string) => {
        if (state === 'playing') {
          this.isPlayingAudio = true;
        } else if (state === 'completed' || state === 'stopped' || state === 'error') {
          this.isPlayingAudio = false;
        }
      });

      this.avPlayer.on('error', (error: Error) => {
        console.error('[ReadPage] Audio player error:', error);
        this.isPlayingAudio = false;
      });
    } catch (error) {
      console.warn('[ReadPage] Failed to init audio player:', error);
    }
  }

  /**
   * Release audio player
   */
  private releaseAudioPlayer(): void {
    if (this.avPlayer !== null) {
      this.avPlayer.release();
      this.avPlayer = null;
    }
  }

  /**
   * Load current task and prepare content
   */
  // Add error count state
  @State private taskErrorCount: number = 0;
  private readonly MAX_TASK_ERRORS: number = 3;

  private async loadCurrentTask(): Promise<void> {
    const startTime = Date.now();
    console.log(`[Perf] loadCurrentTask started (task ${this.taskIndex + 1}/${this.taskQueue.length})`);

    if (this.taskIndex >= this.taskQueue.length) {
      // Session complete
      this.showSessionComplete();
      return;
    }

    this.isTaskLoading = true;
    this.taskLoadingHint = `加载任务 ${this.taskIndex + 1}/${this.taskQueue.length}...`;

    try {
      console.log('[ReadPage] Loading task', this.taskIndex + 1, 'of', this.taskQueue.length, ':',
        this.taskQueue[this.taskIndex].type);

      const task = this.taskQueue[this.taskIndex];
      this.currentTask = task;
      this.currentWord = task.word;
      this.hasPreloadedStory = false;
      this.showTranslation = false;
      
      // Issue #6 fix: Always reset highlight state to prevent residue from previous context
      this.showTargetHighlight = false;
      this.clearTargetHighlightTimer();
      
      // Reset task reviewed flag for new task
      this.currentTaskReviewed = false;

      // CRITICAL: Create snapshot BEFORE any review modifications
      this.currentSnapshot = new WordSnapshot(task.word);
      this.session.createSnapshot(task.word);

      // Apply preloaded story first (fast path)
      if (this.currentWord !== null) {
        this.applyPreloadedStory(this.currentWord.id);
      }

      // Issue #6 fix: ALWAYS reset story state to prevent target word residue
      // Even if preloaded, we need to ensure clean state
      if (!this.hasPreloadedStory) {
        this.storyText = '';
        this.storyWords = [];
        this.storyError = '';
        this.cachedStoryText = '';
        this.cachedStoryWords = [];
      } else {
        // If preloaded, still clear cached state to ensure fresh parsing
        this.cachedStoryText = '';
        this.cachedStoryWords = [];
      }

      // Parallelize: definition loading and support words fetching
      const loadPromises: Promise<void>[] = [];
      
      // Non-blocking definition preload
      if (this.currentWord !== null) {
        loadPromises.push(this.ensureDefinitionLoaded(this.currentWord));
      }

      // Fetch support words for story generation
      if (!this.hasPreloadedStory) {
        loadPromises.push(this.fetchSupportWords());
      }

      // Wait for all parallel loads
      await Promise.all(loadPromises);

      // Prepare task content based on type
      await this.prepareTaskContent(task);

      console.log('[ReadPage] Task', this.taskIndex + 1, 'loaded successfully');
      console.log(`[Perf] loadCurrentTask took ${Date.now() - startTime}ms`);
      // Reset error count when task loads successfully
      this.taskErrorCount = 0;
      this.hideBanner();
      this.scheduleUndoHint();
      this.scheduleTargetHighlight();
      void this.preloadNextTask();
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to load task', this.taskIndex + 1, ':', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');

      // Increment error count
      this.taskErrorCount++;

      const info: ErrorInfo = buildUserFacingError(errorMsg);
      const detailLine = info.rawDetail.length > 0 ? `

详情(截断):
${info.rawDetail}` : '';
      const message = `${info.userMessage} 建议：${info.suggestion}${detailLine}`;
      const primaryAction = info.showRetryAction ? BannerAction.RETRY : BannerAction.SKIP;
      const secondaryAction = info.showSettingsAction ? BannerAction.SETTINGS : BannerAction.NONE;
      this.showBanner(BannerType.ERROR, message, primaryAction, secondaryAction);

      // If too many consecutive errors, end session
      if (this.taskErrorCount >= this.MAX_TASK_ERRORS) {
        console.error('[ReadPage] Too many consecutive task errors, ending session');
        this.showBanner(BannerType.ERROR, `连续 ${this.MAX_TASK_ERRORS} 个任务加载失败，会话已结束。`, BannerAction.NONE,
          BannerAction.NONE);
        setTimeout(() => {
          router.back();
        }, 1200);
        return;
      }
    } finally {
      this.isTaskLoading = false;
    }
  }

  /**
   * Fetch support words for "Snowball" context
   */
  private async fetchSupportWords(): Promise<void> {
    if (this.currentWord === null) {
      return;
    }

    try {
      const supports = await this.dbManager.getSupportWords(this.currentWord.word, 3);
      this.supportWords = supports.map((w: WordItem): string => w.word);
    } catch (error) {
      console.warn('[ReadPage] Failed to fetch support words:', error);
      this.supportWords = [];
    }
  }

  private applyPreloadedStory(wordId: number): void {
    const cached = this.preloadedStoryCache.get(wordId);
    if (!cached) {
      this.hasPreloadedStory = false;
      return;
    }

    this.storyText = cached.text;
    this.storyWords = cached.words;
    this.storyError = cached.error;
    this.supportWords = cached.supportWords;
    this.hasPreloadedStory = true;
  }

  private async preloadNextTask(): Promise<void> {
    if (this.isPreloadingNextTask) {
      return;
    }
    const nextIndex = this.taskIndex + 1;
    if (nextIndex >= this.taskQueue.length) {
      return;
    }
    if (this.preloadedTaskIndex === nextIndex) {
      return;
    }

    const nextTask = this.taskQueue[nextIndex];
    const word = nextTask.word;
    if (this.preloadedStoryCache.has(word.id)) {
      this.preloadedTaskIndex = nextIndex;
      return;
    }

    this.isPreloadingNextTask = true;
    try {
      await this.preloadStoryForWord(word);
      this.preloadedTaskIndex = nextIndex;
    } finally {
      this.isPreloadingNextTask = false;
    }
  }

  private async preloadStoryForWord(word: WordItem): Promise<void> {
    let supportWords: string[] = [];
    try {
      const supports = await this.dbManager.getSupportWords(word.word, 3);
      supportWords = supports.map((item: WordItem): string => item.word);
    } catch (error) {
      supportWords = [];
    }

    const range = this.getContextWordCountRange(word);
    let outcome: StoryGenerationOutcome;
    if (this.storyPipeline === null) {
      outcome = new StoryGenerationOutcome(
        `After class, I had to ${word.word}. It felt simple and easy to remember.`,
        StorySource.MINIMAL,
        '语境生成器未初始化，已使用最小兜底。'
      );
    } else {
      this.dictManager.setContextPreferences(
        this.selectedContextStyle,
        this.selectedDifficultyLevel
      );
      outcome = await this.storyPipeline.generate({
        targetWord: word.word,
        supportWords: supportWords,
        minWords: range.minWords,
        maxWords: range.maxWords,
        minTargetOccurrences: 2,
        maxTargetOccurrences: 3,
        style: this.selectedContextStyle,
        difficulty: this.selectedDifficultyLevel
      });
    }

    const storyWords = this.parseStoryIntoWordsForText(outcome.story, word.word, supportWords);
    this.preloadedStoryCache.set(word.id, {
      text: outcome.story,
      words: storyWords,
      error: outcome.warningMessage,
      supportWords: supportWords
    });
  }

  /**
   * Prepare task content based on task type
   */
  private async prepareTaskContent(task: TaskItem): Promise<void> {
    try {
      console.log('[ReadPage] Preparing task content for type:', task.type);

      switch (task.type) {
        case TaskType.STORY:
          if (!this.hasPreloadedStory || this.storyText.trim().length === 0) {
            await this.generateStory();
          }
          break;

        case TaskType.CLOZE:
          await this.prepareClozeTask(task);
          break;

        case TaskType.CHOICE:
          await this.prepareChoiceTask(task);
          break;

        case TaskType.COLLOCATION:
          await this.prepareCollocationTask(task);
          break;

        case TaskType.PRONUNCIATION:
          await this.preparePronunciationTask(task);
          break;

        case TaskType.REVIEW_NOTE:
          await this.prepareReviewNoteTask(task);
          break;

        default:
          console.error('[ReadPage] Unknown task type:', task.type);
          throw new Error(`未知的任务类型: ${task.type}`);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to prepare task content:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      throw error instanceof Error ? error : new Error(String(error)); // Re-throw only Error objects
    }
  }

  /**
   * Prepare cloze (fill-in-blank) task
   */
  private async prepareClozeTask(task: TaskItem): Promise<void> {
    if (this.currentWord === null) {
      console.error('[ReadPage] currentWord is null in prepareClozeTask');
      throw new Error('当前单词为空');
    }

    try {
      console.log('[ReadPage] Preparing cloze task for word:', this.currentWord.word);

      // Generate story first if not already generated
      if (this.storyText.trim().length === 0) {
        await this.generateStory();
      }

      const targetWord = this.currentWord.word;
      const blank = '_____';

      // Hard fallback: guarantee we always have some text to operate on
      if (this.storyText.trim().length === 0) {
        this.storyText = `After class, I had to ${targetWord}. It felt simple and easy to remember.`;
        this.parseStoryIntoWords();
      }

      const replaced = this.storyText.replace(
        new RegExp(`\\b${targetWord}\\b`, 'gi'),
        blank
      );

      // If regex didn't match, do a minimal deterministic cloze sentence
      this.storyText = replaced === this.storyText ? `${blank} is something I do every day.` : replaced;
      this.parseStoryIntoWords();

      task.content = `请填写正确的单词: ${blank}`;
      task.correctAnswer = targetWord;

      console.log('[ReadPage] Cloze task prepared successfully');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to prepare cloze task:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * Prepare choice (multiple choice) task
   */
  private async prepareChoiceTask(task: TaskItem): Promise<void> {
    if (this.currentWord === null) {
      console.error('[ReadPage] currentWord is null in prepareChoiceTask');
      throw new Error('当前单词为空');
    }

    try {
      console.log('[ReadPage] Preparing choice task for word:', this.currentWord.word);

      const word = this.currentWord.word;

      // Ensure definition available (may fail if API not configured; we will degrade gracefully)
      await this.ensureDefinitionLoaded(this.currentWord);

      const definition = this.currentWord.definition ?? new WordDefinition();
      const correctMeaning = definition.contextMeaning ||
        (definition.commonMeanings.length > 0 ? definition.commonMeanings[0].cn : '');

      // If no meaning available, degrade to spelling choice to keep the session moving
      if (correctMeaning.trim().length === 0) {
        console.warn('[ReadPage] No meaning available, degrading to spelling choice for word:', word);

        const options = [word, ...this.generateSimilarSoundingWords(word)];
        this.shuffleArray(options);

        task.content = '请选择正确的单词拼写：';
        task.options = options.slice(0, 4);
        task.correctAnswer = word;

        return;
      }

      // Generate distractors (wrong choices)
      const distractors = this.generateDistractors(word, correctMeaning);

      // Shuffle options
      const options = [correctMeaning, ...distractors];
      this.shuffleArray(options);

      task.content = `请选择 "${word}" 的正确释义：`;
      task.options = options.slice(0, 4);
      task.correctAnswer = correctMeaning;

      console.log('[ReadPage] Choice task prepared successfully');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to prepare choice task:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * Prepare collocation task
   */
  private async prepareCollocationTask(task: TaskItem): Promise<void> {
    if (this.currentWord === null) {
      console.error('[ReadPage] currentWord is null in prepareCollocationTask');
      throw new Error('当前单词为空');
    }

    try {
      console.log('[ReadPage] Preparing collocation task for word:', this.currentWord.word);

      const word = this.currentWord.word;

      // Generate common collocations
      const collocations = this.generateCollocations(word);

      if (!collocations || collocations.length === 0) {
        console.error('[ReadPage] No collocations generated for word:', word);
        throw new Error('无法生成单词的搭配');
      }

      task.content = `请选择 "${word}" 的正确搭配：`;
      task.options = collocations;
      task.correctAnswer = collocations[0]; // First one is correct

      console.log('[ReadPage] Collocation task prepared successfully');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to prepare collocation task:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      throw error instanceof Error ? error : new Error(String(error)); // Re-throw only Error objects
    }
  }

  /**
   * Prepare pronunciation task
   */
  private async preparePronunciationTask(task: TaskItem): Promise<void> {
    if (this.currentWord === null) {
      console.error('[ReadPage] currentWord is null in preparePronunciationTask');
      throw new Error('当前单词为空');
    }

    try {
      console.log('[ReadPage] Preparing pronunciation task for word:', this.currentWord.word);

      const word = this.currentWord.word;

      // Generate similar sounding words
      const similarWords = this.generateSimilarSoundingWords(word);

      if (!similarWords) {
        console.error('[ReadPage] No similar words generated for word:', word);
        throw new Error('无法生成相似发音的单词');
      }

      task.content = `请听音选择正确的单词：`;
      task.options = [word, ...similarWords];
      this.shuffleArray(task.options);
      task.correctAnswer = word;

      console.log('[ReadPage] Pronunciation task prepared successfully');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to prepare pronunciation task:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      throw error instanceof Error ? error : new Error(String(error)); // Re-throw only Error objects
    }
  }

  /**
   * Prepare review note task (for error reflection)
   */
  private async prepareReviewNoteTask(task: TaskItem): Promise<void> {
    if (this.currentWord === null) {
      console.error('[ReadPage] currentWord is null in prepareReviewNoteTask');
      throw new Error('当前单词为空');
    }

    try {
      console.log('[ReadPage] Preparing review note task for word:', this.currentWord.word);

      const word = this.currentWord.word;
      const mostFrequentError = this.currentWord.getMostFrequentError();

      task.content = `您刚才忘记了 "${word}"，请选择主要原因：`;
      task.options = [
        '释义错误',
        '用法错误',
        '拼写错误',
        '发音错误',
        '混淆错误'
      ];
      task.correctAnswer = mostFrequentError || '释义错误';

      console.log('[ReadPage] Review note task prepared successfully');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Failed to prepare review note task:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');
      throw error instanceof Error ? error : new Error(String(error)); // Re-throw only Error objects
    }
  }

  /**
   * Generate distractors for choice task
   */
  private generateDistractors(correctWord: string, correctMeaning: string): string[] {
    // Simple implementation: use common wrong meanings or similar words
    // In production, this could use a database of common mistakes
    const distractors: string[] = [];

    // Add some generic distractors
    distractors.push('其他含义');
    distractors.push('相关词汇');
    distractors.push('常见用法');

    return distractors;
  }

  /**
   * Generate collocations for a word
   */
  private generateCollocations(word: string): string[] {
    // Simple implementation: generate common collocations
    // In production, this could use a collocation database
    const collocations: string[] = [];

    // Add some common collocations
    collocations.push(`take ${word}`);
    collocations.push(`make ${word}`);
    collocations.push(`have ${word}`);
    collocations.push(`be ${word}`);

    return collocations;
  }

  /**
   * Generate similar sounding words
   */
  private generateSimilarSoundingWords(word: string): string[] {
    // Simple implementation: find words with similar spelling
    // In production, this could use a phonetic similarity algorithm
    const similarWords: string[] = [];

    // Add some common similar words
    similarWords.push(word + 'e');
    similarWords.push(word.substring(0, word.length - 1) + 'a');
    similarWords.push(word + 'ed');

    return similarWords;
  }

  /**
   * Shuffle array in place
   */
  private shuffleArray<T>(array: T[]): void {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = array[i];
      array[i] = array[j];
      array[j] = temp;
    }
  }

  /**
   * Generate story using AI
   */
  private getContextWordCountRange(word: WordItem): WordCountRange {
    if (this.newbieMode) {
      return new WordCountRange(50, 70);
    }
    const difficulty = word.fsrsState.difficulty;
    if (difficulty >= 6) {
      return new WordCountRange(100, 180);
    }
    return new WordCountRange(50, 70);
  }

  private async generateStory(): Promise<void> {
    if (this.currentWord === null) {
      console.error('[ReadPage] currentWord is null in generateStory');
      throw new Error('当前单词为空');
    }

    this.isGeneratingStory = true;
    this.storyError = '';

    const target = this.currentWord.word;
    const range = this.getContextWordCountRange(this.currentWord);

    // Issue #3 fix: Add timeout to prevent indefinite hanging
    const STORY_GENERATION_TIMEOUT_MS = 15000; // 15 seconds
    const timeoutPromise = new Promise<StoryGenerationOutcome>((_, reject) => {
      setTimeout(() => reject(new Error('Story generation timeout')), STORY_GENERATION_TIMEOUT_MS);
    });

    try {
      console.log('[ReadPage] Generating story for word:', target, 'with support words:', this.supportWords);

      this.dictManager.setContextPreferences(
        this.selectedContextStyle,
        this.selectedDifficultyLevel
      );

      const pipeline = this.storyPipeline;
      if (pipeline === null) {
        this.storyText = `After class, I had to ${target}. It felt simple and easy to remember.`;
        this.storyError = '语境生成器未初始化，已使用最小兜底。';
        this.parseStoryIntoWords();
        return;
      }

      const generationPromise = pipeline.generate({
        targetWord: target,
        supportWords: this.supportWords,
        minWords: range.minWords,
        maxWords: range.maxWords,
        minTargetOccurrences: 2,
        maxTargetOccurrences: 3,
        style: this.selectedContextStyle,
        difficulty: this.selectedDifficultyLevel
      });

      const outcome = await Promise.race([generationPromise, timeoutPromise]) as StoryGenerationOutcome;

      // Validate story quality but do NOT block session on validation errors
      if (this.contextValidator) {
        const validation = this.contextValidator.validate(
          outcome.story,
          target,
          this.selectedDifficultyLevel,
          range.minWords,
          range.maxWords,
          2,
          3
        );

        if (!validation.isValid) {
          this.storyError = `提示：${validation.getSummary()}`;
          console.warn('[ReadPage] Story validation warning:', validation.getSummary());
        }
      }

      this.storyText = outcome.story;
      if (outcome.warningMessage.length > 0) {
        this.storyError = outcome.warningMessage;
      }
      this.parseStoryIntoWords();
      console.log('[ReadPage] Story generated successfully');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadPage] Exception occurred during story generation:', errorMsg);
      console.error('[ReadPage] Error stack:', error instanceof Error ? error.stack : 'N/A');

      // Best-effort fallback: ensure UI and tasks can continue
      const info = buildUserFacingError(errorMsg);
      this.storyError = info.userMessage;
      this.storyText = `After class, I had to ${target}. It felt simple and easy to remember.`;
      this.parseStoryIntoWords();
    } finally {
      this.isGeneratingStory = false;
      console.log('[ReadPage] Story generation process completed');
    }
  }

  /**
   * Parse story text into clickable words
   */
  private parseStoryIntoWords(): void {
    const startTime = Date.now();

    // CRITICAL: Skip if text unchanged (cache hit)
    if (this.storyText === this.cachedStoryText && this.cachedStoryWords.length > 0) {
      this.storyWords = this.cachedStoryWords;
      console.log(`[Perf] parseStoryIntoWords skipped (cached), ${this.cachedStoryWords.length} words`);
      return;
    }

    const targetWord = this.currentWord?.word ?? '';
    const words = this.parseStoryIntoWordsForText(this.storyText, targetWord, this.supportWords);

    // Update cache
    this.cachedStoryText = this.storyText;
    this.cachedStoryWords = words;
    this.storyWords = words;

    console.log(`[Perf] parseStoryIntoWords took ${Date.now() - startTime}ms, parsed ${words.length} words`);
  }

  private parseStoryIntoWordsForText(text: string, targetWord: string, supportWords: string[]): StoryWord[] {
    const startTime = Date.now();
    const words: StoryWord[] = [];
    if (text.length === 0) {
      return words;
    }

    const targetLower = targetWord.toLowerCase();
    const supportSet = new Set<string>(supportWords.map((w: string): string => w.toLowerCase()));

    const regex = /([a-zA-Z']+)|([^a-zA-Z'\s]+)/g;
    let match: RegExpExecArray | null = null;
    let currentIndex = 0;

    while ((match = regex.exec(text)) !== null) {
      const fullMatch = match[0];
      const isWord = match[1] !== undefined;
      const startIndex = match.index;

      if (startIndex > currentIndex) {
        // Whitespace is handled implicitly in the UI
      }

      const lowerWord = fullMatch.toLowerCase();
      const storyWord = new StoryWord(
        fullMatch,
        startIndex,
        startIndex + fullMatch.length,
        isWord && lowerWord === targetLower,
        isWord && supportSet.has(lowerWord),
        !isWord
      );

      words.push(storyWord);
      currentIndex = startIndex + fullMatch.length;
    }

    console.log(`[Perf] parseStoryIntoWordsForText took ${Date.now() - startTime}ms for ${text.length} chars`);
    return words;
  }

  /**
   * Handle word click in story
   */
  private async onWordClick(storyWord: StoryWord): Promise<void> {
    const startTime = Date.now();
    console.log('[Perf] onWordClick started');

    if (storyWord.isPunctuation) {
      return;
    }

    const word = storyWord.word.toLowerCase().replace(/[^a-zA-Z]/g, '');
    if (word.length === 0) {
      return;
    }
    this.hideUndoHint();

    // Show dialog
    this.dialogState.reset();
    this.dialogState.isVisible = true;
    this.fuzzyMemoryChecked = false;
    this.pendingReviewReflection = '';
    this.dialogState.word = word;
    this.dialogState.isLoading = true;

    // Check if this word is in our database
    try {
      const wordItem = await this.dbManager.getWordByWord(word);
      if (wordItem !== null) {
        this.dialogState.wordItem = wordItem;
        this.dialogState.canUndo = wordItem.history.getReviewCount() > 0;
        this.meaningExpanded = wordItem.status === WordStatus.NEW;

        // Create snapshot for this word if not current target
        if (this.currentWord !== null && wordItem.id !== this.currentWord.id) {
          this.session.createSnapshot(wordItem);
        }
      } else {
        this.meaningExpanded = true;
      }
    } catch (error) {
      console.warn('[ReadPage] Failed to lookup word in DB:', error);
      this.meaningExpanded = true;
    }

    // Lookup definition
    const lookupStart = Date.now();
    try {
      const context = this.storyText;
      const result: LookupResult = await this.dictManager.lookup(word, context);

      if (result.success && result.definition !== null) {
        this.dialogState.definition = result.definition;
      } else {
        this.dialogState.definition = new WordDefinition(
          word, '', '', 'Definition not found', [], 'local'
        );
      }
      console.log(`[Perf] Dictionary lookup took ${Date.now() - lookupStart}ms`);
    } catch (error) {
      this.dialogState.definition = new WordDefinition(
        word, '', '', 'Failed to load definition', [], 'local'
      );
    } finally {
      this.dialogState.isLoading = false;
    }

    console.log(`[Perf] onWordClick took ${Date.now() - startTime}ms`);
  }

  /**
   * Play word pronunciation
   * Issue #7 fix: Enhanced reliability with retry logic and better state management
   */
  private async playPronunciation(word: string): Promise<void> {
    if (!word || word.length === 0) {
      console.warn('[ReadPage] Cannot play pronunciation: empty word');
      return;
    }

    // If already playing, stop first then play new word
    if (this.isPlayingAudio && this.avPlayer !== null) {
      try {
        await this.avPlayer.stop();
        await this.avPlayer.reset();
      } catch (e) {
        console.warn('[ReadPage] Error stopping previous audio:', e);
      }
      this.isPlayingAudio = false;
    }

    if (this.avPlayer === null) {
      console.warn('[ReadPage] Audio player not initialized');
      // Try to reinitialize
      try {
        await this.initAudioPlayer();
      } catch (e) {
        console.error('[ReadPage] Failed to initialize audio player:', e);
        return;
      }
    }

    try {
      const url = this.dictManager.getTTSUrl(word, 1);
      if (this.avPlayer !== null) {
        this.avPlayer.url = url;
        await this.avPlayer.prepare();
        await this.avPlayer.play();
      }
    } catch (error) {
      console.error('[ReadPage] Failed to play pronunciation:', error);
      this.isPlayingAudio = false;
      
      // Retry once on failure
      try {
        console.log('[ReadPage] Retrying pronunciation playback...');
        if (this.avPlayer !== null) {
          await this.avPlayer.reset();
          const url = this.dictManager.getTTSUrl(word, 1);
          this.avPlayer.url = url;
          await this.avPlayer.prepare();
          await this.avPlayer.play();
        }
      } catch (retryError) {
        console.error('[ReadPage] Pronunciation retry failed:', retryError);
        this.isPlayingAudio = false;
      }
    }
  }

  /**
   * Add word to notebook (for new words)
   */
  private async addToNotebook(): Promise<void> {
    if (this.dialogState.word.length === 0) {
      return;
    }

    try {
      // Check if already exists
      const existing = await this.dbManager.getWordByWord(this.dialogState.word);
      if (existing !== null) {
        promptAction.showToast({ message: '单词已在单词本中', duration: 1500 });
        this.dialogState.wordItem = existing;
        return;
      }

      // Create new word item
      const newWord = new WordItem(
        0,
        this.dialogState.word,
        WordStatus.NEW,
        undefined,
        undefined,
        this.dialogState.definition ?? new WordDefinition(),
        Date.now(),
        Date.now(),
        Date.now(),
        'UserAdded',
        []
      );

      const rowId = await this.dbManager.insertWord(newWord);
      if (rowId > 0) {
        newWord.id = rowId;
        this.dialogState.wordItem = newWord;
        this.session.createSnapshot(newWord);
        promptAction.showToast({ message: '已加入单词本', duration: 1500 });
      }
    } catch (error) {
      console.error('[ReadPage] Failed to add word:', error);
      this.showBannerForDuration(BannerType.ERROR, '添加失败，请稍后再试。', 2000);
    }
  }

  private async removeFromNotebook(): Promise<void> {
    const wordItem = this.dialogState.wordItem;
    if (wordItem === null) {
      return;
    }

    try {
      await this.dbManager.deleteWord(wordItem.id);
      this.dialogState.wordItem = null;
      promptAction.showToast({ message: '已从单词本移除', duration: 1500 });
      this.closeDialog();
    } catch (error) {
      console.error('[ReadPage] Failed to remove word:', error);
      this.showBannerForDuration(BannerType.ERROR, '移除失败，请稍后再试。', 2000);
    }
  }

  private async openWordBookSelectionDialog(): Promise<void> {
    await this.loadUserWordBooks();
    this.showWordBookSelectionDialog = true;
  }

  private async loadUserWordBooks(): Promise<void> {
    try {
      const allWords = await this.dbManager.getAllWords();
      const bookIds = new Set<string>();
      for (const word of allWords) {
        if (word.bookId && word.bookId.length > 0) {
          bookIds.add(word.bookId);
        }
      }
      this.userWordBooks = Array.from(bookIds).filter((id: string): boolean => {
        const builtInIds = ['cet4', 'cet6', 'kaoyan'];
        return !builtInIds.includes(id);
      });
    } catch (error) {
      console.error('[ReadPage] Failed to load user word books:', error);
      this.userWordBooks = [];
    }
  }

  private selectWordBook(bookId: string): void {
    this.selectedWordBookId = bookId;
  }

  private async createWordBook(): Promise<void> {
    if (this.newWordBookName.trim().length === 0) {
      promptAction.showToast({ message: '请输入词书名称', duration: 1500 });
      return;
    }

    try {
      const bookId = this.newWordBookName.trim();
      this.selectedWordBookId = bookId;
      this.userWordBooks.push(bookId);
      this.newWordBookName = '';
      promptAction.showToast({ message: '词书创建成功', duration: 1500 });
    } catch (error) {
      console.error('[ReadPage] Failed to create word book:', error);
      promptAction.showToast({ message: '创建词书失败，请稍后再试。', duration: 2000 });
    }
  }

  private async addToWordBook(): Promise<void> {
    if (this.currentWord === null || this.selectedWordBookId.length === 0) {
      return;
    }

    try {
      const existingWord = await this.dbManager.getWordByWord(this.currentWord.word);
      if (existingWord !== null) {
        await this.dbManager.deleteWord(existingWord.id);
      }

      const updatedWord = new WordItem(
        this.currentWord.id,
        this.currentWord.word,
        this.currentWord.status,
        this.currentWord.fsrsState,
        this.currentWord.history,
        this.currentWord.definition,
        this.currentWord.dueDate,
        this.currentWord.createdAt,
        this.currentWord.updatedAt,
        this.selectedWordBookId
      );

      await this.dbManager.updateWord(updatedWord);
      this.currentWord = updatedWord;
      this.showWordBookSelectionDialog = false;
      this.selectedWordBookId = '';
      promptAction.showToast({ message: '已加入单词本', duration: 1500 });
    } catch (error) {
      console.error('[ReadPage] Failed to add to word book:', error);
      this.showBannerForDuration(BannerType.ERROR, '添加失败，请稍后再试。', 2000);
    }
  }

  /**
   * Move to next task with a short delay to allow UI updates
   */
  private moveToNextTaskWithDelay(): void {
    setTimeout(() => {
      this.moveToNextTask();
    }, 600);
  }

  /**
   * Handle "Forget" (Again) button
   */
  private async handleForget(): Promise<void> {
    await this.processReview(Rating.AGAIN);
    // Advance to next task after processing review for current task
    this.moveToNextTaskWithDelay();
  }

  /**
   * Handle "Remember" (Good) button
   */
  private async handleRemember(): Promise<void> {
    await this.processReview(Rating.GOOD);
    // Advance to next task after processing review for current task
    this.moveToNextTaskWithDelay();
  }

  private triggerFlash(button: FlashButton): void {
    this.flashButton = button;
    setTimeout(() => {
      this.flashButton = FlashButton.NONE;
    }, 120);
  }

  private getForgetButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.FORGET ? '#FF7961' : '#F44336';
  }

  private getHardButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.HARD ? '#FFB74D' : '#FF9800';
  }

  private getRememberButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.REMEMBER ? '#66BB6A' : '#4CAF50';
  }

  private getUndoButtonBorderColor(): ResourceColor {
    return this.flashButton === FlashButton.UNDO ? '#FF7961' : '#F44336';
  }

  private async vibrateByRating(rating: Rating): Promise<void> {
    try {
      const durationMs = rating === Rating.AGAIN ? 35 : 20;
      await vibrator.startVibration(
        { type: 'time', duration: durationMs },
        { id: 0, usage: 'notification' }
      );
    } catch (e) {
      return;
    }
  }

  private onForgetClick(): void {
    const startTime = Date.now();
    console.log('[Perf] onForgetClick started');

    if (this.isReviewCooling || this.currentTaskReviewed) {
      return;
    }
    this.triggerFlash(FlashButton.FORGET);
    this.pendingReviewReflection = '';
    this.fuzzyMemoryChecked = false;
    this.startReviewCooldown();
    this.currentTaskReviewed = true;
    void this.vibrateByRating(Rating.AGAIN);
    void this.handleForget();

    console.log(`[Perf] onForgetClick took ${Date.now() - startTime}ms`);
  }

  private onHardClick(): void {
    const startTime = Date.now();
    console.log('[Perf] onHardClick started');

    if (this.isReviewCooling || this.currentTaskReviewed) {
      return;
    }
    this.currentTaskReviewed = true;
    this.triggerFlash(FlashButton.HARD);
    this.pendingReviewReflection = '';
    this.fuzzyMemoryChecked = false;
    this.startReviewCooldown();
    void this.vibrateByRating(Rating.HARD);
    
    // Process review and advance to next task
    this.processReview(Rating.HARD).then(() => {
      this.moveToNextTaskWithDelay();
    });

    console.log(`[Perf] onHardClick took ${Date.now() - startTime}ms`);
  }

  private onRememberClick(): void {
    const startTime = Date.now();
    console.log('[Perf] onRememberClick started');

    if (this.isReviewCooling || this.currentTaskReviewed) {
      return;
    }
    this.triggerFlash(FlashButton.REMEMBER);
    if (this.fuzzyMemoryChecked) {
      this.currentTaskReviewed = true;
      this.pendingReviewReflection = 'fuzzy';
      this.fuzzyMemoryChecked = false;
      this.startReviewCooldown();
      void this.vibrateByRating(Rating.HARD);
      
      // Process review and advance to next task
      this.processReview(Rating.HARD).then(() => {
        this.moveToNextTaskWithDelay();
      });
      
      console.log(`[Perf] onRememberClick took ${Date.now() - startTime}ms`);
      return;
    }

    this.currentTaskReviewed = true;
    this.pendingReviewReflection = '';
    this.startReviewCooldown();
    void this.vibrateByRating(Rating.GOOD);
    void this.handleRemember();

    console.log(`[Perf] onRememberClick took ${Date.now() - startTime}ms`);
  }

  private onUndoClick(): void {
    this.triggerFlash(FlashButton.UNDO);
    void this.vibrateByRating(Rating.HARD);
    void this.handleUndo();
  }

  private formatNextReviewHint(dueDateMs: number): string {
    const diff = dueDateMs - Date.now();
    if (diff <= 0) {
      return '现在可复习';
    }

    const minuteMs = 60 * 1000;
    const hourMs = 60 * minuteMs;
    const dayMs = 24 * hourMs;

    if (diff < hourMs) {
      const minutes = Math.max(1, Math.round(diff / minuteMs));
      return `${minutes}分钟后复习`;
    }

    if (diff < dayMs) {
      const hours = Math.max(1, Math.round(diff / hourMs));
      return `${hours}小时后复习`;
    }

    const days = Math.max(1, Math.round(diff / dayMs));
    return `${days}天后复习`;
  }

  /**
   * Process review with given rating
   */
  private async processReview(rating: Rating): Promise<void> {
    const startTime = Date.now();
    console.log(`[Perf] processReview started with rating: ${rating}`);

    const wordItem = this.dialogState.wordItem;
    if (wordItem === null) {
      return;
    }

    try {
      const reflection = this.pendingReviewReflection;
      this.pendingReviewReflection = '';

      // Snapshot state before mutation (WordReviewer updates in-place)
      const prevStateJson = wordItem.fsrsState.toJSON();

      // Get last review time for elapsed calculation
      const lastReviewMs = wordItem.history.getReviewCount() > 0
        ? wordItem.history.items[wordItem.history.getReviewCount() - 1].timestamp
        : 0;

      // Process review using FSRS algorithm
      const updatedWord = this.wordReviewer.processReview(wordItem, rating, lastReviewMs);

      const newStateJson = updatedWord.fsrsState.toJSON();

      // Handle error tags for AGAIN rating
      if (rating === Rating.AGAIN) {
        wordItem.incrementLapse();
        wordItem.updateLeechLevel(wordItem.history.items.slice(-7).map(h => h.rating));
      }

      // Update in database
      const dbStart = Date.now();
      await this.dbManager.updateWord(updatedWord);
      console.log(`[Perf] Database update took ${Date.now() - dbStart}ms`);

      // Write review event log for WebDAV evolution pipeline
      const reviewCount = updatedWord.history.getReviewCount();
      const eventTs = reviewCount > 0 ? updatedWord.history.items[reviewCount - 1].timestamp : Date.now();
      try {
        await this.dbManager.addReviewEvent(updatedWord.id, rating as number, eventTs, prevStateJson, newStateJson, '',
          reflection);
      } catch (e) {
        // Review should still be saved even if event logging fails
        console.warn('[ReadPage] Failed to log review event:', e);
      }

      // Update state
      this.dialogState.wordItem = updatedWord;
      this.dialogState.hasBeenReviewed = true;
      this.dialogState.canUndo = true;
      this.lastReviewHint = this.formatNextReviewHint(updatedWord.dueDate);
      this.pushUndoWordId(updatedWord.id);

      // Update current word if this is the target
      if (this.currentWord !== null && updatedWord.id === this.currentWord.id) {
        this.currentWord = updatedWord;
        this.showTranslation = false;

        // Track session progress
        if (rating === Rating.AGAIN) {
          // Word will be shown again later
          // Insert reinforcement tasks for forgotten words
          await this.insertReinforcementTasks(updatedWord, rating, false);
        } else if (rating === Rating.HARD) {
          const reduce = reflection === 'fuzzy';
          await this.insertReinforcementTasks(updatedWord, rating, reduce);

          if (updatedWord.status === WordStatus.LEARNING || updatedWord.status === WordStatus.NEW) {
            this.session.newLearnedCount++;
          } else {
            this.session.reviewedCount++;
          }
        } else {
          if (updatedWord.status === WordStatus.LEARNING || updatedWord.status === WordStatus.NEW) {
            this.session.newLearnedCount++;
          } else {
            this.session.reviewedCount++;
          }
        }
      }

      let message = `下次复习：${this.lastReviewHint}`;
      if (rating === Rating.AGAIN) {
        message = `更快复习 · ${this.lastReviewHint}`;
      } else if (rating === Rating.HARD) {
        message = `更近复习 · ${this.lastReviewHint}`;
      } else if (rating === Rating.GOOD) {
        message = `会了 · ${this.lastReviewHint}`;
      }
      this.showBannerForDuration(BannerType.INFO, message, 1000);

      console.log(`[Perf] processReview took ${Date.now() - startTime}ms`);
    } catch (error) {
      console.error('[ReadPage] Failed to process review:', error);
      this.showBannerForDuration(BannerType.ERROR, '保存复习失败，请稍后再试。', 2000);
    }
  }

  /**
   * Insert reinforcement tasks after forgetting
   */
  private async insertReinforcementTasks(word: WordItem, rating: Rating, reduce: boolean = false): Promise<void> {
    try {
      // Generate reinforcement tasks using SessionPlanner
      const reinforcementTasks = this.sessionPlanner.generateReinforcementTasks(word, rating);
      let tasksToInsert = reinforcementTasks;
      if (reduce && reinforcementTasks.length > 1) {
        const keep = Math.max(1, Math.floor(reinforcementTasks.length / 2));
        tasksToInsert = reinforcementTasks.slice(0, keep);
      }

      // Insert tasks after current task
      const insertIndex = this.taskIndex + 1;
      this.taskQueue.splice(insertIndex, 0, ...tasksToInsert);

      promptAction.showToast({
        message: `已添加 ${tasksToInsert.length} 个强化任务`,
        duration: 2000
      });
    } catch (error) {
      console.error('[ReadPage] Failed to insert reinforcement tasks:', error);
      this.showBannerForDuration(BannerType.WARNING, '强化任务插入失败，已继续当前流程。', 1500);
    }
  }

  /**
   * Handle Undo - CRITICAL:  Restore from Snapshot
   */
  private async handleUndo(): Promise<void> {
    const wordItem = this.dialogState.wordItem;
    if (wordItem === null) {
      return;
    }

    // Get snapshot
    const snapshot = this.session.getSnapshot(wordItem.id);
    if (snapshot === null) {
      this.showBannerForDuration(BannerType.WARNING, '无法撤回：未找到可用快照。', 1500);
      return;
    }

    try {
      // CRITICAL: Restore the snapshot directly to DB
      const restoredWord = snapshot.restore();

      // Force write snapshot back to database
      await this.dbManager.updateWord(restoredWord);

      // Update UI state
      this.dialogState.wordItem = restoredWord;
      this.dialogState.hasBeenReviewed = false;
      this.dialogState.canUndo = false;
      this.lastReviewHint = '';
      this.removeUndoWordId(restoredWord.id);

      // Update current word if this is the target
      if (this.currentWord !== null && restoredWord.id === this.currentWord.id) {
        this.currentWord = restoredWord;
        this.showTranslation = false;
        // Create new snapshot for potential re-review
        this.currentSnapshot = new WordSnapshot(restoredWord);
        this.session.createSnapshot(restoredWord);
      }

      this.showBannerForDuration(BannerType.INFO, '已撤销本次评分', 1000);

    } catch (error) {
      console.error('[ReadPage] Failed to undo:', error);
      this.showBannerForDuration(BannerType.ERROR, '撤回失败，请稍后再试。', 2000);
    }
  }

  private canUndoLastReviewed(): boolean {
    const wordId = this.getLastUndoWordId();
    if (wordId <= 0) {
      return false;
    }
    const snapshot = this.session.getSnapshot(wordId);
    return snapshot !== null;
  }

  private async undoLastReviewed(): Promise<void> {
    if (!this.canUndoLastReviewed()) {
      return;
    }
    const wordId = this.getLastUndoWordId();
    const snapshot = this.session.getSnapshot(wordId);
    if (snapshot === null) {
      return;
    }

    try {
      const restoredWord = snapshot.restore();
      await this.dbManager.updateWord(restoredWord);

      if (this.currentWord !== null && restoredWord.id === this.currentWord.id) {
        this.currentWord = restoredWord;
        this.showTranslation = false;
        this.currentSnapshot = new WordSnapshot(restoredWord);
        this.session.createSnapshot(restoredWord);
      }

      if (this.dialogState.wordItem !== null && restoredWord.id === this.dialogState.wordItem.id) {
        this.dialogState.wordItem = restoredWord;
        this.dialogState.hasBeenReviewed = false;
        this.dialogState.canUndo = false;
      }

      this.lastReviewHint = '';
      this.popUndoWordId();
      this.showBannerForDuration(BannerType.INFO, '已撤回上一步', 1000);

      if (this.taskIndex > 0) {
        this.taskIndex--;
        await this.loadCurrentTask();
      }
    } catch (e) {
      this.showBannerForDuration(BannerType.ERROR, '撤回失败，请稍后再试。', 2000);
    }
  }

  private onFloatingUndoClick(): void {
    this.hideUndoHint();
    this.triggerFlash(FlashButton.UNDO);
    void this.vibrateByRating(Rating.HARD);
    void this.undoLastReviewed();
  }

  /**
   * Close dialog
   */
  private closeDialog(): void {
    this.dialogState.isVisible = false;
  }

  /**
   * Move to next task in queue
   */
  private moveToNextTask(): void {
    if (this.taskIndex < this.taskQueue.length - 1) {
      this.taskIndex++;
      this.loadCurrentTask();
    } else {
      this.showSessionComplete();
    }
  }

  /**
   * Move to next word in queue (legacy, for compatibility)
   */
  private moveToNextWord(): void {
    this.moveToNextTask();
  }

  /**
   * Show session complete dialog
   */
  private showSessionComplete(): void {
    // Check if any words were actually learned
    const totalLearned = this.session.reviewedCount + this.session.newLearnedCount;

    if (totalLearned === 0) {
      // No words learned, show error message instead
      this.showBanner(
        BannerType.ERROR,
        '没有学习到任何单词，可能是任务加载失败。请检查配置或网络后重试。',
        BannerAction.NONE,
        BannerAction.NONE
      );
      setTimeout(() => {
        router.back();
      }, 1500);
    } else {
      // Normal session completion
      promptAction.showDialog({
        title: '会话完成!',
        message: `复习: ${this.session.reviewedCount}\n新学: ${this.session.newLearnedCount}`,
        buttons: [{ text: '确定', color: '#2196F3' }]
      }).then(() => {
        AppStorage.setOrCreate('today_session_complete_ms', String(Date.now()));
        router.back();
      });
    }
  }

  /**
   * Go back to home
   */
  private goBack(): void {
    router.back();
  }

  build() {
    Stack() {
      Column() {
        // Header
        this.buildHeader()

        if (this.sessionErrorMessage.length > 0) {
          this.buildSessionErrorView()
        } else {
          // Main content
          Scroll() {
            Column() {
              // Story area
              this.buildStoryArea()
            }
            .width('100%')
            .padding(DesignTokens.Layout.CONTAINER_PADDING)
          }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .onScroll(() => this.hideUndoHint())

          this.buildRatingButtons()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignTokens.Colors.GRAY_50)

      if (this.showUndoHint && !this.dialogState.isVisible && !this.isTaskLoading && this.sessionErrorMessage.length === 0) {
        this.buildUndoHintButton()
      }

      if (this.bannerType !== BannerType.NONE && this.bannerMessage.length > 0) {
        TopBanner({
          message: this.bannerMessage,
          type: this.bannerType === BannerType.ERROR
            ? TopBannerType.ERROR
            : this.bannerType === BannerType.WARNING
              ? TopBannerType.WARNING
              : TopBannerType.INFO,
          primaryLabel: this.getBannerActionLabel(this.bannerPrimaryAction),
          secondaryLabel: this.getBannerActionLabel(this.bannerSecondaryAction),
          onPrimary: this.bannerPrimaryAction !== BannerAction.NONE
            ? () => this.handleBannerAction(this.bannerPrimaryAction)
            : undefined,
          onSecondary: this.bannerSecondaryAction !== BannerAction.NONE
            ? () => this.handleBannerAction(this.bannerSecondaryAction)
            : undefined
        })
      }

      // Word dialog overlay
      if (this.dialogState.isVisible) {
        this.buildWordDialog()
      }

      // Context settings dialog overlay
      if (this.showContextSettings) {
        this.buildContextSettingsDialog()
      }

      // Word book selection dialog overlay
      if (this.showWordBookSelectionDialog) {
        this.buildWordBookSelectionDialog()
      }

      // Task loading overlay
      if (this.isTaskLoading) {
        this.buildTaskLoadingOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildUndoHintButton() {
    Button() {
      Row() {
        Text('↶')
          .fontSize(16)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .margin({ right: DesignTokens.Spacing.XS })

        Text('撤回')
          .fontSize(12)
          .fontColor(DesignTokens.Colors.GRAY_900)
      }
    }
    .height(36)
    .padding({ left: DesignTokens.Spacing.MD, right: DesignTokens.Spacing.MD })
    .borderRadius(18)
    .backgroundColor(DesignTokens.Colors.WHITE)
    .opacity(0.9)
    .shadow(DesignTokens.Shadows.SM)
    .position({ x: DesignTokens.Spacing.LG, y: 68 })
    .accessibilityText('撤回上一张卡片')
    .onClick(() => this.onFloatingUndoClick())
  }

  @Builder
  buildTaskLoadingOverlay() {
    Column() {
      LoadingProgress()
        .width(56)
        .height(56)
        .color(DesignTokens.Colors.PRIMARY)
        .animation({
          duration: DesignTokens.Animations.DURATION_NORMAL,
          curve: DesignTokens.Animations.CURVE_EASE_IN_OUT,
          iterations: -1
        })

      Text(this.taskLoadingHint)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.WHITE)
        .margin({ top: DesignTokens.Spacing.LG })
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width('80%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(DesignTokens.Colors.BLACK + 'CC')
    .position({ x: 0, y: 0 })
    .zIndex(100)
  }

  @Builder
  buildSessionErrorView() {
    Column() {
      Image($r('sys.media.ohos_ic_public_fail'))
        .width(56)
        .height(56)
        .fillColor(DesignTokens.Colors.ERROR)

      Text(this.sessionErrorTitle)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .margin({ top: DesignTokens.Spacing.LG })

      Text(this.sessionErrorMessage)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: DesignTokens.Spacing.SM })
        .textAlign(TextAlign.Center)

      Row({ space: DesignTokens.Spacing.MD }) {
        if (this.sessionErrorSecondaryAction !== SessionErrorAction.NONE) {
          Button(this.getSessionActionLabel(this.sessionErrorSecondaryAction))
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .onClick(() => this.handleSessionErrorAction(this.sessionErrorSecondaryAction));
        }

        if (this.sessionErrorPrimaryAction !== SessionErrorAction.NONE) {
          Button(this.getSessionActionLabel(this.sessionErrorPrimaryAction))
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(DesignTokens.Colors.PRIMARY)
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .onClick(() => this.handleSessionErrorAction(this.sessionErrorPrimaryAction));
        }
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.XL })
    }
    .width('100%')
    .layoutWeight(1)
    .padding(DesignTokens.Spacing.XXL)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildHeader() {
    Row() {
      // Back button
      Image($r('sys.media.ohos_ic_public_arrow_left'))
        .width(24)
        .height(24)
        .fillColor(DesignTokens.Colors.GRAY_900)
        .onClick(() => this.goBack())

      // Title & progress
      Column() {
        Text('微语境学习')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)

        Text(`第 ${Math.min(this.taskIndex + 1, this.taskQueue.length)} / ${this.taskQueue.length} 个单词`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)

        Progress({
          value: Math.min(this.taskIndex + 1, this.taskQueue.length),
          total: Math.max(1, this.taskQueue.length),
          type: ProgressType.Linear
        })
          .width(120)
          .height(4)
          .color(DesignTokens.Colors.PRIMARY)
          .backgroundColor(DesignTokens.Colors.GRAY_300)
          .margin({ top: DesignTokens.Spacing.XS })
      }
      .margin({ left: DesignTokens.Spacing.LG })

      Blank()

      Button('撤回')
        .height(36)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.canUndoLastReviewed() ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_400)
        .backgroundColor(this.canUndoLastReviewed() ? DesignTokens.Colors.PRIMARY_LIGHTEST : DesignTokens.Colors.GRAY_200)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .enabled(this.canUndoLastReviewed())
        .onClick(() => this.onFloatingUndoClick())
    }
    .width('100%')
    .height(64)
    .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING })
    .backgroundColor(DesignTokens.Colors.WHITE)
  }

  @Builder
  buildTargetWord() {
    Column() {
      if (this.currentWord !== null) {
        // Status badge
        Text(this.getStatusText(this.currentWord.status))
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(this.getStatusColor(this.currentWord.status))
          .padding({
            left: DesignTokens.Spacing.MD,
            right: DesignTokens.Spacing.MD,
            top: DesignTokens.Spacing.XS,
            bottom: DesignTokens.Spacing.XS
          })
          .borderRadius(DesignTokens.BorderRadius.LG)

        // Word
        Row() {
          Text(this.currentWord.word)
            .fontSize(DesignTokens.Typography.FONT_SIZE_3XL)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(DesignTokens.Colors.GRAY_900)

          // Speaker icon
          Image($r('sys.media.ohos_ic_public_sound'))
            .width(28)
            .height(28)
            .fillColor(DesignTokens.Colors.PRIMARY)
            .margin({ left: DesignTokens.Spacing.LG })
            .onClick(() => {
              if (this.currentWord !== null) {
                this.playPronunciation(this.currentWord.word);
              }
            })
        }
        .margin({ top: DesignTokens.Spacing.LG })

        // Support words
        if (this.supportWords.length > 0) {
          Row() {
            Text('关联词汇:  ')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_600)

            ForEach(this.supportWords, (word: string, index: number) => {
              Text(word)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.SUCCESS)
                .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
                .margin({ left: index > 0 ? DesignTokens.Spacing.SM : DesignTokens.Spacing.XS })
            })
          }
          .margin({ top: DesignTokens.Spacing.MD })
        }

        // Add to notebook button
        Button('加入单词本')
          .width('100%')
          .height(40)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(DesignTokens.Colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.FULL)
          .margin({ top: DesignTokens.Spacing.LG })
          .onClick(() => {
            if (this.currentWord !== null) {
              this.openWordBookSelectionDialog();
            }
          })
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.XXL)
    .backgroundColor(DesignTokens.Colors.WHITE)
    .borderRadius(DesignTokens.BorderRadius.XL)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildStoryArea() {
    Column() {
      Text('微语境')
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      if (this.isGeneratingStory) {
        // Loading state
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(DesignTokens.Colors.PRIMARY)

          Text('Generating story...')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ top: DesignTokens.Spacing.LG })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(DesignTokens.Colors.GRAY_100)
        .borderRadius(DesignTokens.BorderRadius.LG)

      } else if (this.storyText.length > 0) {
        // Story display (even if storyError exists: treat as warning)
        Column() {
          if (this.storyError.length > 0) {
            Row() {
              Text(this.storyError)
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(DesignTokens.Colors.WARNING_DARK)
            }
            .width('100%')
            .padding({
              left: DesignTokens.Spacing.MD,
              right: DesignTokens.Spacing.MD,
              top: DesignTokens.Spacing.SM,
              bottom: DesignTokens.Spacing.SM
            })
            .backgroundColor(DesignTokens.Colors.WARNING_LIGHT + '20')
            .borderRadius(DesignTokens.BorderRadius.MD)
            .margin({ bottom: DesignTokens.Spacing.MD })
          }

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.storyWords, (storyWord: StoryWord, index: number) => {
              Text(storyWord.word + (this.needsSpaceAfter(index) ? ' ' : ''))
                .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
                .lineHeight(DesignTokens.Typography.FONT_SIZE_LG * 1.6)
                .fontColor(this.getWordColor(storyWord))
                .fontWeight(storyWord.isTarget ? DesignTokens.Typography.FONT_WEIGHT_MEDIUM :
                  DesignTokens.Typography.FONT_WEIGHT_REGULAR)
                .decoration({
                  type: (storyWord.isTarget && this.showTargetHighlight) ? TextDecorationType.Underline : TextDecorationType.None,
                  color: DesignTokens.Colors.PRIMARY
                })
                .onClick(() => this.onWordClick(storyWord))
            }, (storyWord: StoryWord, index: number): string => `word-${index}-${storyWord.startIndex}`)
          }
          .width('100%')
          .padding(DesignTokens.Spacing.LG)
          .backgroundColor(DesignTokens.Colors.WHITE)
          .borderRadius(DesignTokens.BorderRadius.LG)

          Text(this.showTranslation ? '点击收起完整释义' : '点击显示完整释义')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: DesignTokens.Spacing.MD })
            .onClick(() => {
              this.showTranslation = !this.showTranslation;
            })

          if (this.showTranslation) {
            Text(this.getTranslationText())
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_800)
              .lineHeight(DesignTokens.Typography.FONT_SIZE_BASE * 1.6)
              .padding(DesignTokens.Spacing.MD)
              .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
              .borderRadius(DesignTokens.BorderRadius.LG)
              .margin({ top: DesignTokens.Spacing.SM })
          }
        }
        .width('100%')

      } else if (this.storyError.length > 0) {
        // Error state (no story text)
        Column() {
          Image($r('sys.media.ohos_ic_public_fail'))
            .width(48)
            .height(48)
            .fillColor(DesignTokens.Colors.ERROR)

          Text(this.storyError)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.ERROR)
            .margin({ top: DesignTokens.Spacing.LG })
            .textAlign(TextAlign.Center)

          Button('重试生成')
            .margin({ top: DesignTokens.Spacing.XL })
            .backgroundColor(DesignTokens.Colors.PRIMARY)
            .fontColor(DesignTokens.Colors.WHITE)
            .onClick(() => {
              this.generateStory();
            })
        }
        .width('100%')
        .padding(DesignTokens.Spacing.XXL)
        .backgroundColor(DesignTokens.Colors.GRAY_100)
        .borderRadius(DesignTokens.BorderRadius.LG)

      } else {
        // Empty state
        Text('点击下方按钮生成情境故事')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .width('100%')
          .padding(DesignTokens.Spacing.XXL)
          .textAlign(TextAlign.Center)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.LG)
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.XXL)
    .backgroundColor(DesignTokens.Colors.WHITE)
    .borderRadius(DesignTokens.BorderRadius.XL)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildGenerateButton() {
    Button(this.storyText.length > 0 ? '重新生成故事' : '生成故事')
      .width('100%')
      .height(56)
      .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
      .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
      .fontColor(DesignTokens.Colors.WHITE)
      .backgroundColor(this.isGeneratingStory ? DesignTokens.Colors.GRAY_500 : DesignTokens.Colors.SUCCESS)
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ top: DesignTokens.Spacing.XXL })
      .enabled(!this.isGeneratingStory)
      .stateEffect(true)
      .onClick(() => this.generateStory())
  }

  @Builder
  buildRatingButtons() {
    Row({ space: DesignTokens.Spacing.SM }) {
      Button('不认识')
        .layoutWeight(1)
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor('#F44336')
        .borderRadius(DesignTokens.BorderRadius.XL)
        .enabled(!this.isReviewCooling)
        .stateEffect(true)
        .onClick(() => this.onForgetClick())

      Button('有点印象')
        .layoutWeight(1)
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor('#FFB300')
        .borderRadius(DesignTokens.BorderRadius.XL)
        .enabled(!this.isReviewCooling)
        .stateEffect(true)
        .onClick(() => this.onHardClick())

      Button('认识')
        .layoutWeight(1)
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor('#4CAF50')
        .borderRadius(DesignTokens.BorderRadius.XL)
        .enabled(!this.isReviewCooling)
        .stateEffect(true)
        .onClick(() => this.onRememberClick())
    }
    .width('100%')
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      bottom: DesignTokens.Spacing.LG
    })
    .backgroundColor(DesignTokens.Colors.WHITE)
  }

  @Builder
  buildNavigationButtons() {
    Row() {
      // Previous (disabled for now, could implement later)
      Button('上一个')
        .width('45%')
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .backgroundColor(DesignTokens.Colors.GRAY_300)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .enabled(false)
        .opacity(0.5)
        .stateEffect(true)

      Blank()

      // Next
      Button('下一个单词')
        .width('45%')
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor(DesignTokens.Colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .stateEffect(true)
        .onClick(() => this.moveToNextWord())
    }
    .width('100%')
    .margin({ top: DesignTokens.Spacing.XXL })
  }

  @Builder
  buildWordDialog() {
    // Overlay background
    Column() {
      // Backdrop
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => this.closeDialog())
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })

    // Dialog content
    Column() {
      // Dialog card
      Column() {
        // Header with word and close
        Row() {
          Column() {
            Row() {
              // Issue #7 fix: Make word text also clickable for pronunciation
              Text(this.dialogState.word)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#212121')
                .onClick(() => this.playPronunciation(this.dialogState.word))

              // Speaker
              Image($r('sys.media.ohos_ic_public_sound'))
                .width(24)
                .height(24)
                .fillColor('#2196F3')
                .margin({ left: 8 })
                .onClick(() => this.playPronunciation(this.dialogState.word))
            }

            // Phonetic
            if (this.dialogState.definition !== null && this.dialogState.definition.phonetic.length > 0) {
              Text(this.dialogState.definition.phonetic)
                .fontSize(14)
                .fontColor('#757575')
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // Close button
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(24)
            .height(24)
            .fillColor('#9E9E9E')
            .onClick(() => this.closeDialog())
        }
        .width('100%')
        .padding({
          left: 20,
          right: 20,
          top: 20,
          bottom: 12
        })

        Divider().color('#EEEEEE')

        // Content
        if (this.dialogState.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#2196F3')
            Text('Loading definition...')
              .fontSize(14)
              .fontColor('#999999')
              .margin({ top: 8 })
          }
          .width('100%')
          .height(120)
          .justifyContent(FlexAlign.Center)

        } else if (this.dialogState.definition !== null) {
          Scroll() {
            Column() {
              Row() {
                Text('释义')
                  .fontSize(12)
                  .fontColor('#666666')

                Blank()

                Text(this.meaningExpanded ? '收起' : '展开')
                  .fontSize(12)
                  .fontColor('#2196F3')
              }
              .width('100%')
              .margin({ bottom: 8 })
              .onClick(() => {
                this.meaningExpanded = !this.meaningExpanded;
              })

              if (!this.meaningExpanded) {
                Column() {
                  Text('回忆一下？')
                    .fontSize(14)
                    .fontColor('#666666')

                  Text('点击展开释义')
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 4 })
                }
                .width('100%')
                .height(48)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor('#F5F5F5')
                .borderRadius(8)
                .onClick(() => {
                  this.meaningExpanded = true;
                })
              } else {
                Column() {
                  // Context meaning (highlighted)
                  if (this.dialogState.definition.contextMeaning.length > 0) {
                    Column() {
                      Row() {
                        Text(this.dialogState.definition.pos)
                          .fontSize(12)
                          .fontColor('#FFFFFF')
                          .backgroundColor('#2196F3')
                          .padding({
                            left: 8,
                            right: 8,
                            top: 2,
                            bottom: 2
                          })
                          .borderRadius(4)
                          .visibility(this.dialogState.definition.pos.length > 0 ? Visibility.Visible : Visibility.None)

                        Text('In this context:')
                          .fontSize(12)
                          .fontColor('#666666')
                          .margin({ left: 8 })
                      }

                      Text(this.dialogState.definition.contextMeaning)
                        .fontSize(18)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#333333')
                        .margin({ top: 8 })
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor('#E3F2FD')
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }

                  // Other meanings
                  if (this.dialogState.definition.commonMeanings.length > 0) {
                    Column() {
                      Text('其他释义')
                        .fontSize(12)
                        .fontColor('#666666')
                        .margin({ bottom: 8 })

                      ForEach(this.dialogState.definition.commonMeanings, (meaning: WordMeaning) => {
                        Row() {
                          Text(meaning.pos)
                            .fontSize(14)
                            .fontColor('#FF9800')
                            .fontWeight(FontWeight.Medium)
                            .width(40)

                          Text(meaning.cn)
                            .fontSize(14)
                            .fontColor('#333333')
                            .layoutWeight(1)
                        }
                        .width('100%')
                        .margin({ bottom: 6 })
                      })
                    }
                    .width('100%')
                    .margin({ top: 16 })
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
                .constraintSize({ minHeight: 120, maxHeight: 220 })
              }
            }
            .width('100%')
            .padding(20)
          }
          .constraintSize({ maxHeight: this.newbieMode ? 420 : 250 })
        }

        Divider().color('#EEEEEE')

        // Action buttons
        this.buildDialogButtons()
      }
      .width('90%')
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
  }

  @Builder
  buildDialogButtons() {
    Column() {
      if (this.dialogState.wordItem === null) {
        // Word not in notebook - show Add button
        Button('加入单词本')
          .width('100%')
          .height(48)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#4CAF50')
          .borderRadius(24)
          .onClick(() => this.addToNotebook())

      } else {
        // Word already in notebook - show Remove button
        Button('已加入（点此撤销）')
          .width('100%')
          .height(48)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#666666')
          .backgroundColor('#E0E0E0')
          .borderRadius(24)
          .onClick(() => this.removeFromNotebook())
      }
    }
    .width('100%')
    .padding(20)
  }

  // Helper methods

  private needsSpaceAfter(index: number): boolean {
    if (index >= this.storyWords.length - 1) {
      return false;
    }
    const current = this.storyWords[index];
    const next = this.storyWords[index + 1];

    // No space before punctuation
    if (next.isPunctuation) {
      return false;
    }

    // Space after words and some punctuation
    return true;
  }

  private getWordColor(storyWord: StoryWord): ResourceColor {
    if (storyWord.isSupport) {
      return '#2E7D32';
    }
    if (storyWord.isPunctuation) {
      return '#333333';
    }
    return '#333333';
  }

  private getTranslationText(): string {
    // Issue #5 fix: Show full story context meaning, not just single word definition
    // If we have a story, show a brief explanation of the context
    if (this.storyText.length > 0 && this.currentWord !== null) {
      const definition = this.currentWord.definition;
      let translationText = '';
      
      // For now, show a comprehensive explanation combining story context and word meanings
      translationText += `【语境说明】\n这段语境讲述了一个包含单词"${this.currentWord.word}"的场景。\n\n`;
      
      // Add target word's context-specific meaning if available
      if (definition !== null && definition.contextMeaning.length > 0) {
        translationText += `【目标词释义】\n${definition.contextMeaning}\n\n`;
      }
      
      // Add common meanings for reference
      if (definition !== null && definition.commonMeanings.length > 0) {
        translationText += '【词典释义】\n';
        for (let i = 0; i < definition.commonMeanings.length; i++) {
          const meaning = definition.commonMeanings[i];
          translationText += `${meaning.pos}: ${meaning.cn}`;
          if (i < definition.commonMeanings.length - 1) {
            translationText += '\n';
          }
        }
      }
      
      return translationText.length > 0 ? translationText : '暂无释义';
    }
    
    if (this.currentWord === null) {
      return '暂无释义';
    }

    const definition = this.currentWord.definition;
    if (definition === null) {
      return '暂无释义';
    }

    let translationText: string = '';

    // Add context-specific meaning
    if (definition.contextMeaning.length > 0) {
      translationText += definition.contextMeaning;
    }

    // Add all common meanings for complete definition
    if (definition.commonMeanings.length > 0) {
      if (translationText.length > 0) {
        translationText += '\n\n';
      }
      translationText += '其他释义:\n';
      for (let i = 0; i < definition.commonMeanings.length; i++) {
        const meaning = definition.commonMeanings[i];
        translationText += `${meaning.pos}: ${meaning.cn}`;
        if (i < definition.commonMeanings.length - 1) {
          translationText += '\n';
        }
      }
    }

    return translationText.length > 0 ? translationText : '暂无释义';
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW:
        return '新词';
      case WordStatus.LEARNING:
        return '学习中';
      case WordStatus.REVIEW:
        return '复习';
      case WordStatus.MASTERED:
        return '已掌握';
      case WordStatus.SUSPENDED:
        return '已暂停';
      default:
        return '未知';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW:
        return '#2196F3';
      case WordStatus.LEARNING:
        return '#FF9800';
      case WordStatus.REVIEW:
        return '#9C27B0';
      case WordStatus.MASTERED:
        return '#4CAF50';
      case WordStatus.SUSPENDED:
        return '#9E9E9E';
      default:
        return '#9E9E9E';
    }
  }

  @Builder
  buildContextSettingsDialog() {
    Column() {
      // Backdrop
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showContextSettings = false;
        })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })

    // Dialog content
    Column() {
      // Dialog card
      Column() {
        // Header
        Row() {
          Text('语境设置')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)

          // Close button
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(24)
            .height(24)
            .fillColor('#666666')
            .onClick(() => {
              this.showContextSettings = false;
            })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // Context style selection
        Column() {
          Text('语境风格')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 8 })

          Row() {
            ForEach([
              ContextStyle.CONVERSATIONAL,
              ContextStyle.FORMAL,
              ContextStyle.HUMOROUS,
              ContextStyle.NARRATIVE,
              ContextStyle.TECHNICAL
            ], (style: ContextStyle) => {
              Text(this.getContextStyleName(style))
                .fontSize(14)
                .fontColor(this.selectedContextStyle === style ? '#FFFFFF' : '#333333')
                .backgroundColor(this.selectedContextStyle === style ? '#2196F3' : '#F5F5F5')
                .padding({
                  left: 12,
                  right: 12,
                  top: 6,
                  bottom: 6
                })
                .borderRadius(16)
                .margin({ right: 8 })
                .onClick(() => {
                  this.selectedContextStyle = style;
                })
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 20 })

        // Difficulty level selection
        Column() {
          Text('难度级别')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 8 })

          Row() {
            ForEach([
              DifficultyLevel.CET4,
              DifficultyLevel.CET6,
              DifficultyLevel.IELTS,
              DifficultyLevel.TOEFL,
              DifficultyLevel.GRE
            ], (level: DifficultyLevel) => {
              Text(this.getDifficultyName(level))
                .fontSize(14)
                .fontColor(this.selectedDifficultyLevel === level ? '#FFFFFF' : '#333333')
                .backgroundColor(this.selectedDifficultyLevel === level ? '#2196F3' : '#F5F5F5')
                .padding({
                  left: 12,
                  right: 12,
                  top: 6,
                  bottom: 6
                })
                .borderRadius(16)
                .margin({ right: 8 })
                .onClick(() => {
                  this.selectedDifficultyLevel = level;
                })
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 20 })

        // Apply button
        Button('应用设置')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#2196F3')
          .borderRadius(22)
          .onClick(() => {
            this.showContextSettings = false;
            // Regenerate story with new settings
            this.generateStory();
          })
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
  }

  @Builder
  buildWordBookSelectionDialog() {
    Column() {
      // Backdrop
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showWordBookSelectionDialog = false;
        })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })

    // Dialog content
    Column() {
      // Dialog card
      Column() {
        // Header
        Row() {
          Text('选择词书')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)

          // Close button
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(24)
            .height(24)
            .fillColor('#666666')
            .onClick(() => {
              this.showWordBookSelectionDialog = false;
            })
        }
        .width('100%')
        .margin({ bottom: 20 })

        Divider().color('#EEEEEE')

        // Word book list
        Scroll() {
          Column() {
            // Issue #4 fix: Always show create button prominently at the top
            Column() {
              Row() {
                TextInput({ text: this.newWordBookName, placeholder: '输入新词书名称' })
                  .layoutWeight(1)
                  .height(48)
                  .fontSize(16)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .onChange((value: string) => {
                    this.newWordBookName = value;
                  })

                Button('创建词书')
                  .height(48)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#2196F3')
                  .borderRadius(8)
                  .margin({ left: 12 })
                  .onClick(() => {
                    this.createWordBook();
                  })
              }
              .width('100%')
              .margin({ bottom: 16 })
            }
            .width('100%')

            if (this.userWordBooks.length === 0) {
              Column() {
                Text('暂无自建词书，请先创建')
                  .fontSize(14)
                  .fontColor('#999999')
                  .textAlign(TextAlign.Center)
                  .margin({ top: 12, bottom: 12 })
              }
              .width('100%')
            } else {
              Divider().color('#EEEEEE').margin({ bottom: 12 })

              Text('选择已有词书:')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ bottom: 8 })

              ForEach(this.userWordBooks, (bookId: string) => {
                Row() {
                  Text(bookId)
                    .fontSize(16)
                    .fontColor('#333333')
                    .layoutWeight(1)

                  if (this.selectedWordBookId === bookId) {
                    Image($r('sys.media.ohos_ic_public_ok'))
                      .width(24)
                      .height(24)
                      .fillColor('#2196F3')
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(this.selectedWordBookId === bookId ? '#E3F2FD' : '#FFFFFF')
                .borderRadius(8)
                .border({
                  width: this.selectedWordBookId === bookId ? 2 : 1,
                  color: this.selectedWordBookId === bookId ? '#2196F3' : '#E0E0E0'
                })
                .margin({ bottom: 8 })
                .onClick(() => {
                  this.selectWordBook(bookId);
                })
              }, (bookId: string): string => bookId)
            }
          }
        }
        .width('100%')
        .constraintSize({ maxHeight: 400 })

        Divider().color('#EEEEEE').margin({ top: 12 })

        // Confirm button
        Button('确认添加')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#2196F3')
          .borderRadius(22)
          .margin({ top: 12 })
          .onClick(() => {
            this.addToWordBook();
          })
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
  }

  private getContextStyleName(style: ContextStyle): string {
    switch (style) {
      case ContextStyle.CONVERSATIONAL:
        return '对话式';
      case ContextStyle.FORMAL:
        return '正式';
      case ContextStyle.HUMOROUS:
        return '幽默';
      case ContextStyle.NARRATIVE:
        return '叙述式';
      case ContextStyle.TECHNICAL:
        return '技术性';
      default:
        return String(style);
    }
  }

  private getDifficultyName(level: DifficultyLevel): string {
    const map = new Map<DifficultyLevel, string>();
    map.set(DifficultyLevel.CET4, '四级');
    map.set(DifficultyLevel.CET6, '六级');
    map.set(DifficultyLevel.IELTS, '雅思');
    map.set(DifficultyLevel.TOEFL, '托福');
    map.set(DifficultyLevel.SAT, 'SAT');
    map.set(DifficultyLevel.GRE, 'GRE');
    return map.get(level) ?? String(level);
  }
}
