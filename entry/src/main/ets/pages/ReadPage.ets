// =====================================================
// ReadPage.ets - Core Learning Interface
// Implements Snapshot undo mechanism and word interaction
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import media from '@ohos.multimedia.media';
import vibrator from '@ohos.vibrator';
import type common from '@ohos.app.ability.common';
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
import { LearningStepsDecision, LearningStepsPolicy } from '../algorithm/LearningStepsPolicy';
import { DBManager } from '../database/DBManager';
import { DictionaryManager, LookupResult } from '../manager/DictionaryManager';
import { ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import {
  StoryFastGenerationResult,
  StoryGenerationOutcome,
  StoryGenerationPipeline,
  StoryGenerationRequest,
  StorySource
} from '../context/StoryGenerationPipeline';
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
import { SettingsStore } from '../utils/SettingsStore';
import { SeenContextStore } from '../utils/SeenContextStore';
import {
  normalizeQueueFromRouterParams, normalizeWordItem, RawWordItem, RawQueueItem
} from '../utils/RouteParamNormalizer';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { TopBanner, TopBannerType } from '../ui/TopBanner';
import { LoadingAnimation, LoadingType } from '../ui/LoadingAnimations';
import { AddToBookDialog, AddToBookDialogResult } from '../components/AddToBookDialog';
import { CreateBookDialog, CreateBookDialogResult } from '../components/CreateBookDialog';
import { ReviewTimeManager } from '../manager/ReviewTimeManager';
import { HistoryPopResult, HistoryStack } from '../utils/HistoryStack';
import { buildTranslationText } from '../utils/TranslationTextBuilder';
import { ContextDefinitionStore, ContextDefinitionStatus, hashStoryText } from '../utils/ContextDefinitionStore';
import { buildContextDefinitionText } from '../utils/ContextDefinitionTextBuilder';
import { ReadContextSnapshot, ReadPageHistoryEntry, TaskSnapshot } from '../model/ReadContextSnapshot';
import { UserWordBookBrief } from '../database/DBManager';
import { TtsAudioFetcher } from '../utils/TtsAudioFetcher';
import { SystemTtsManager } from '../utils/SystemTtsManager';
import fs from '@ohos.file.fs';
import { ContextWordMeaningStore } from '../utils/ContextWordMeaningStore';
import { SessionTransferStore } from '../utils/SessionTransferStore';
import { openUrl } from '../utils/UrlOpener';
import { ReadPageHeader } from './ReadPageHeader';
import { FeedbackBar, FlashButton, IntervalHints } from './FeedbackBar';
import { WordSidePanel } from './WordSidePanel';
import { ContextSettingsDialog } from './ContextSettingsDialog';
import { StoryView } from './StoryView';
import { StoryWord, DialogState, BannerAction, SessionErrorAction } from './ReadPageModels';
import { SessionErrorView } from './SessionErrorView';
import { TaskLoadingOverlay } from './TaskLoadingOverlay';
import { SessionCompletionView } from './SessionCompletionView';
import { ReadPersistenceController, ReadPagePersistedState } from './ReadPersistenceController';
import { ReadContextController, ReadContextDelegate } from './learning/controllers/ContextController';
import { ReadStoryController, ReadStoryDelegate } from './learning/controllers/StoryController';
import { PreloadedStory } from './ReadPageModels';
import { ReadWordInteractionController, ReadWordInteractionDelegate } from './learning/controllers/WordInteractionController';
import { ReadPageSessionManager, SessionInitResult } from './learning/controllers/SessionManager';
import { ReadPageReviewManager, ReviewResult } from './learning/controllers/ReviewManager';
import { ReadPageSnapshotManager } from './learning/controllers/SnapshotManager';
import { ReadPageTaskManager } from './learning/controllers/TaskManager';
import { ReadPageAudioManager } from './learning/controllers/AudioManager';
import { ReadPageLoader, TaskLoadResult, TaskLoadCallbacks } from './learning/controllers/TaskLoader';
import { ReadPageReviewHandler, ReviewProcessCallbacks } from './ReadPageReviewHandler';
import { TimeboxManager, TimeboxResult } from '../manager/TimeboxManager';

class WordCountRange {
  minWords: number;
  maxWords: number;

  constructor(minWords: number, maxWords: number) {
    this.minWords = minWords;
    this.maxWords = maxWords;
  }
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





  // Removed local interfaces as they are now in ReadPersistenceController

class ReadWordInteractionDelegateImpl implements ReadWordInteractionDelegate {
  private onDialogStateChangeHandler: (state: DialogState) => void;
  private onNotebookWordsChangeHandler: (words: Set<string>) => void;
  private onMeaningExpandedChangeHandler: (expanded: boolean) => void;
  private onJoinedBooksChangeHandler: (ids: string[], count: number) => void;
  private onShowToastHandler: (message: string) => void;
  private onShowBannerHandler: (type: TopBannerType, message: string, duration?: number) => void;

  constructor(
    onDialogStateChange: (state: DialogState) => void,
    onNotebookWordsChange: (words: Set<string>) => void,
    onMeaningExpandedChange: (expanded: boolean) => void,
    onJoinedBooksChange: (ids: string[], count: number) => void,
    onShowToast: (message: string) => void,
    onShowBanner: (type: TopBannerType, message: string, duration?: number) => void
  ) {
    this.onDialogStateChangeHandler = onDialogStateChange;
    this.onNotebookWordsChangeHandler = onNotebookWordsChange;
    this.onMeaningExpandedChangeHandler = onMeaningExpandedChange;
    this.onJoinedBooksChangeHandler = onJoinedBooksChange;
    this.onShowToastHandler = onShowToast;
    this.onShowBannerHandler = onShowBanner;
  }

  onDialogStateChange(state: DialogState): void {
    this.onDialogStateChangeHandler(state);
  }

  onNotebookWordsChange(words: Set<string>): void {
    this.onNotebookWordsChangeHandler(words);
  }

  onMeaningExpandedChange(expanded: boolean): void {
    this.onMeaningExpandedChangeHandler(expanded);
  }

  onJoinedBooksChange(ids: string[], count: number): void {
    this.onJoinedBooksChangeHandler(ids, count);
  }

  onShowToast(message: string): void {
    this.onShowToastHandler(message);
  }

  onShowBanner(type: TopBannerType, message: string, duration?: number): void {
    this.onShowBannerHandler(type, message, duration);
  }
}

class ReadStoryDelegateImpl implements ReadStoryDelegate {
  private onStoryGeneratedHandler: (text: string, error: string, sourceLabel: string) => void;
  private onStoryWordsParsedHandler: (words: StoryWord[]) => void;
  private onStoryTranslationGeneratedHandler: (translation: string) => void;
  private onStoryLoadingHandler: (hint: string) => void;
  private onStoryLoadingEndHandler: () => void;
  private canApplyStoryUpgradeHandler: () => boolean;
  private onStoryUpgradeAvailableHandler: (text: string, error: string, sourceLabel: string) => void;
  private onPreloadedStoryAppliedHandler: (text: string, error: string, sourceLabel: string, hasPreloaded: boolean) => void;
  private onStoryReadyForContextHandler: (contextId: string, word: string, text: string) => void;
  private onRebuildTranslationTextCacheHandler: () => void;

  constructor(
    onStoryGenerated: (text: string, error: string, sourceLabel: string) => void,
    onStoryWordsParsed: (words: StoryWord[]) => void,
    onStoryTranslationGenerated: (translation: string) => void,
    onStoryLoading: (hint: string) => void,
    onStoryLoadingEnd: () => void,
    canApplyStoryUpgrade: () => boolean,
    onStoryUpgradeAvailable: (text: string, error: string, sourceLabel: string) => void,
    onPreloadedStoryApplied: (text: string, error: string, sourceLabel: string, hasPreloaded: boolean) => void,
    onStoryReadyForContext: (contextId: string, word: string, text: string) => void,
    onRebuildTranslationTextCache: () => void
  ) {
    this.onStoryGeneratedHandler = onStoryGenerated;
    this.onStoryWordsParsedHandler = onStoryWordsParsed;
    this.onStoryTranslationGeneratedHandler = onStoryTranslationGenerated;
    this.onStoryLoadingHandler = onStoryLoading;
    this.onStoryLoadingEndHandler = onStoryLoadingEnd;
    this.canApplyStoryUpgradeHandler = canApplyStoryUpgrade;
    this.onStoryUpgradeAvailableHandler = onStoryUpgradeAvailable;
    this.onPreloadedStoryAppliedHandler = onPreloadedStoryApplied;
    this.onStoryReadyForContextHandler = onStoryReadyForContext;
    this.onRebuildTranslationTextCacheHandler = onRebuildTranslationTextCache;
  }

  onStoryGenerated(text: string, error: string, sourceLabel: string): void {
    this.onStoryGeneratedHandler(text, error, sourceLabel);
  }

  onStoryWordsParsed(words: StoryWord[]): void {
    this.onStoryWordsParsedHandler(words);
  }

  onStoryTranslationGenerated(translation: string): void {
    this.onStoryTranslationGeneratedHandler(translation);
  }

  onStoryLoading(hint: string): void {
    this.onStoryLoadingHandler(hint);
  }

  onStoryLoadingEnd(): void {
    this.onStoryLoadingEndHandler();
  }

  canApplyStoryUpgrade(): boolean {
    return this.canApplyStoryUpgradeHandler();
  }

  onStoryUpgradeAvailable(text: string, error: string, sourceLabel: string): void {
    this.onStoryUpgradeAvailableHandler(text, error, sourceLabel);
  }

  onPreloadedStoryApplied(text: string, error: string, sourceLabel: string, hasPreloaded: boolean): void {
    this.onPreloadedStoryAppliedHandler(text, error, sourceLabel, hasPreloaded);
  }

  onStoryReadyForContext(contextId: string, word: string, text: string): void {
    this.onStoryReadyForContextHandler(contextId, word, text);
  }

  onRebuildTranslationTextCache(): void {
    this.onRebuildTranslationTextCacheHandler();
  }
}

class ReadContextDelegateImpl implements ReadContextDelegate {
  private onDefinitionContentChangeHandler: (content: string) => void;
  private onDefinitionLoadingChangeHandler: (loading: boolean) => void;
  private onTranslationTextCacheChangeHandler: (cache: string) => void;

  constructor(
    onDefinitionContentChange: (content: string) => void,
    onDefinitionLoadingChange: (loading: boolean) => void,
    onTranslationTextCacheChange: (cache: string) => void
  ) {
    this.onDefinitionContentChangeHandler = onDefinitionContentChange;
    this.onDefinitionLoadingChangeHandler = onDefinitionLoadingChange;
    this.onTranslationTextCacheChangeHandler = onTranslationTextCacheChange;
  }

  onDefinitionContentChange(content: string): void {
    this.onDefinitionContentChangeHandler(content);
  }

  onDefinitionLoadingChange(loading: boolean): void {
    this.onDefinitionLoadingChangeHandler(loading);
  }

  onTranslationTextCacheChange(cache: string): void {
    this.onTranslationTextCacheChangeHandler(cache);
  }
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
  @State private storySourceLabel: string = '';
  @State private showTranslation: boolean = false;
  @State private storyTranslation: string = '';
  @State private translationTextCache: string = '';
  @State private translationDefinitionLoading: boolean = false;
  @State private definitionContent: string = '';
  @State private definitionLoading: boolean = false;
  @State private currentStoryHash: string = '';
  @State private storyLocked: boolean = false;
  @State private pendingStoryUpgradeText: string = '';
  @State private pendingStoryUpgradeError: string = '';
  @State private pendingStoryUpgradeSourceLabel: string = '';
  @State private showTargetHighlight: boolean = false;
  private targetHighlightTimer: number | null = null;
  // Dialog state
  @State private dialogState: DialogState = new DialogState();
  @State private notebookWords: Set<string> = new Set<string>();
  @State private flashButton: FlashButton = FlashButton.NONE;
  @State private lastReviewHint: string = '';
  @State private ratingIntervalHints: IntervalHints = {
    again: '',
    hard: '',
    good: '',
    easy: ''
  };
  private readonly HISTORY_CAPACITY: number = 5;
  @State private historyStack: HistoryStack<ReadPageHistoryEntry> = new HistoryStack<ReadPageHistoryEntry>(5);
  @State private contextSequence: string[] = [];
  @State private contextCursor: number = -1;
  @State private isReviewCooling: boolean = false;
  @State private bannerType: TopBannerType = TopBannerType.INFO;
  @State private bannerMessage: string = '';
  @State private bannerPrimaryAction: BannerAction = BannerAction.NONE;
  @State private bannerSecondaryAction: BannerAction = BannerAction.NONE;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  // Session load error state
  @State private sessionErrorTitle: string = '';
  @State private sessionErrorMessage: string = '';
  @State private sessionErrorPrimaryAction: SessionErrorAction = SessionErrorAction.NONE;
  @State private sessionErrorSecondaryAction: SessionErrorAction = SessionErrorAction.NONE;
  @State private meaningExpanded: boolean = true;
  @State private hasPreloadedStory: boolean = false;

  // Issue #11 fix: 复习时间状态管理器
  private reviewTimeManager: ReviewTimeManager = ReviewTimeManager.getInstance();

  // Managers & Controllers
  private sessionManager: ReadPageSessionManager | null = null;
  private reviewManager: ReadPageReviewManager | null = null;
  private snapshotManager: ReadPageSnapshotManager = new ReadPageSnapshotManager();
  private taskManager: ReadPageTaskManager | null = null;
  private audioManager: ReadPageAudioManager | null = null;

  private requireTaskManager(): ReadPageTaskManager {
    if (this.taskManager === null) {
      throw new Error('TaskManager not initialized');
    }
    return this.taskManager;
  }
  private storyController: ReadStoryController | null = null;
  private interactionController: ReadWordInteractionController | null = null;
  private interactionDelegate: ReadWordInteractionDelegate = new ReadWordInteractionDelegateImpl(
    (_state: DialogState): void => {},
    (_words: Set<string>): void => {},
    (_expanded: boolean): void => {},
    (_ids: string[], _count: number): void => {},
    (_message: string): void => {},
    (_type: TopBannerType, _message: string, _duration?: number): void => {}
  );
  private persistenceController: ReadPersistenceController = new ReadPersistenceController();
  private contextController: ReadContextController | null = null;
  private readonly emptyWord: WordItem = new WordItem();

  private pronunciationPreferSystemTts: boolean = false;
  @State private isPlayingAudio: boolean = false;
  @State private enableTTS: boolean = true;
  @State private newbieMode: boolean = true;
  @State private contextLengthMin: number = 40;
  @State private contextLengthMax: number = 80;
  @State private externalDictEnabled: boolean = true;
  @State private externalDictUrlTemplate: string = 'https://www.youdao.com/result?word={word}&lang=en';
  private pendingReviewReflection: string = '';
  private bannerTimer: number | null = null;
  private reinforcementPrewarmIds: Set<string> = new Set<string>();
  // Track if current task has been reviewed (prevent duplicate submissions)
  private currentTaskReviewed: boolean = false;
  @State private sessionCompleted: boolean = false;
  private readonly STORAGE_KEY_SESSION_CONTEXT: string = 'read_page_session_context';
  private readonly SESSION_CONTEXT_MAX_AGE_MS: number = 6 * 60 * 60 * 1000;


  private pushHistoryBeforeReview(): void {
    if (this.currentWord === null || !this.sessionManager) {
      return;
    }
    const wordBeforeReview = this.currentWord.clone();
    
    this.snapshotManager.pushHistory(
        wordBeforeReview,
        this.sessionManager.getTaskQueue(),
        this.sessionManager.getTaskIndex(),
        this.storyText,
        this.storyError,
        this.supportWords,
        this.storyTranslation,
        this.showTranslation,
        this.lastReviewHint,
        this.pendingReviewReflection,
        this.contextSequence,
        this.contextCursor,
        this.seenContextIds,
        this.sessionManager.getTodayAttemptsMap(),
        this.sessionManager.getReinforcementInsertedMap(),
        this.session
    );
    this.historyStack = this.snapshotManager.getHistoryStack();
  }


  private loadSeenContextIds(): void {
    this.seenContextIds = this.seenContextStore.load();
  }

  private persistSeenContextIds(): void {
    this.seenContextStore.save(this.seenContextIds);
  }

  // Removed persisted task methods as they are now in ReadPersistenceController
  private persistSessionContext(): void {
    if (this.sessionCompleted) {
      return;
    }
    
    const taskQueue = this.sessionManager?.getTaskQueue() ?? this.taskQueue;
    const taskIndex = this.sessionManager?.getTaskIndex() ?? this.taskIndex;
    const attempts = this.sessionManager?.getTodayAttemptsMap() ?? this.todayAttemptsByWordId;
    const reinforcements = this.sessionManager?.getReinforcementInsertedMap() ?? this.reinforcementInsertedCountByWordId;

    this.persistenceController.persistSessionContext(
      taskQueue,
      taskIndex,
      this.contextSequence,
      this.contextCursor,
      this.seenContextIds,
      this.session,
      attempts,
      reinforcements
    );
  }

  private clearPersistedSessionContext(): void {
    this.persistenceController.clearPersistedSessionContext();
  }

  private tryRestoreSessionContext(): boolean {
    const state = this.persistenceController.tryRestoreSessionContext();
    if (state === null) {
      return false;
    }

    try {
      const rebuiltQueue = this.persistenceController.rebuildTaskQueue(state.taskQueue);
      if (rebuiltQueue.length === 0) {
        this.clearPersistedSessionContext();
        return false;
      }

      this.session = new LearningSession();
      this.session.reviewedCount = Number(state.reviewedCount) || 0;
      this.session.newLearnedCount = Number(state.newLearnedCount) || 0;
      this.taskQueue = rebuiltQueue;
      this.contextSequence = [...state.contextSequence];
      this.contextCursor = Number(state.contextCursor);
      this.seenContextIds = new Set<string>(state.seenContextIds);
      this.persistSeenContextIds();
      this.persistenceController.applyEntriesToMap(state.todayAttemptEntries, this.todayAttemptsByWordId);
      this.persistenceController.applyEntriesToMap(state.reinforcementEntries, this.reinforcementInsertedCountByWordId);

      const byIdIndex = state.currentTaskId.length > 0 ? this.requireTaskManager().findTaskIndexByTaskId(state.currentTaskId, this.taskQueue) : -1;
      if (byIdIndex >= 0) {
        this.taskIndex = byIdIndex;
      } else {
        const safeIndex = Math.max(0, Math.min(Number(state.taskIndex), this.taskQueue.length - 1));
        this.taskIndex = safeIndex;
      }
      
      if (this.sessionManager) {
          this.sessionManager.setSession(this.session);
          this.sessionManager.setTaskQueue(this.taskQueue);
          this.sessionManager.setTaskIndex(this.taskIndex);
          this.sessionManager.setSeenContextIds(this.seenContextIds);
          this.sessionManager.setSessionState(this.todayAttemptsByWordId, this.reinforcementInsertedCountByWordId);
      }

      this.currentTaskReviewed = false;
      this.triggerLoadCurrentTask();
      return true;
    } catch (e) {
      this.clearPersistedSessionContext();
      return false;
    }
  }

  private normalizeNotebookWord(word: string): string {
    return word.trim().toLowerCase();
  }

  private async loadNotebookWords(): Promise<void> {
    try {
      const words = await this.dbManager.getNotebookWords();
      const normalized: string[] = [];
      for (const w of words) {
        const nw = this.normalizeNotebookWord(w);
        if (nw.length > 0) {
          normalized.push(nw);
        }
      }
      this.notebookWords = new Set<string>(normalized);
    } catch (e) {
      this.notebookWords = new Set<string>();
    }
  }





  private cloneDialogState(prev: DialogState): DialogState {
    const next = new DialogState();
    next.isVisible = prev.isVisible;
    next.word = prev.word;
    next.definition = prev.definition;
    next.isLoading = prev.isLoading;
    next.wordItem = prev.wordItem;
    next.hasBeenReviewed = prev.hasBeenReviewed;
    next.canUndo = prev.canUndo;
    next.inNotebook = prev.inNotebook;
    next.notebookBusy = prev.notebookBusy;
    next.notebookError = prev.notebookError;
    return next;
  }



  private moveToTaskById(taskId: string): void {
    const tm = this.requireTaskManager();
    const idx = tm.findTaskIndexByTaskId(taskId, this.taskQueue);
    if (idx < 0) {
      const nextIndex = tm.findNextUnseenTaskIndex(this.taskIndex, this.taskQueue);
      if (nextIndex >= this.taskQueue.length) {
        this.showSessionComplete();
        return;
      }
      this.clearAllTaskStates();
      this.taskIndex = nextIndex;
      if (this.sessionManager) this.sessionManager.setTaskIndex(nextIndex);
      this.triggerLoadCurrentTask();
      return;
    }
    this.clearAllTaskStates();
    this.taskIndex = idx;
    if (this.sessionManager) this.sessionManager.setTaskIndex(idx);
    this.triggerLoadCurrentTask();
  }

  private triggerLoadCurrentTask(): void {
    if (this.isLoadingTask) {
      console.warn('[ReadPage] Task loading already in progress, skipping');
      return;
    }
    this.isLoadingTask = true;
    void this.loadCurrentTask()
      .finally(() => { this.isLoadingTask = false; })
      .catch((err: object | string | number | boolean | null | undefined) => {
        const msg = err instanceof Error ? err.message : String(err);
        console.error('[ReadPage] loadCurrentTask failed:', msg);
      });
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

  private shouldShowTaskLoadingOverlay(): boolean {
    if (this.currentTask === null) {
      return true;
    }
    if (this.hasPreloadedStory && this.storyText.length > 0) {
      return false;
    }
    if (this.currentTask.type === TaskType.STORY && this.storyText.length > 0) {
      return false;
    }
    return true;
  }

  private showBanner(type: TopBannerType, message: string, primary: BannerAction = BannerAction.NONE,
    secondary: BannerAction = BannerAction.NONE): void {
    this.clearBannerTimer();
    this.bannerType = type;
    this.bannerMessage = message;
    this.bannerPrimaryAction = primary;
    this.bannerSecondaryAction = secondary;
  }

  private showBannerForDuration(type: TopBannerType, message: string, durationMs: number): void {
    this.showBanner(type, message);
    this.bannerTimer = setTimeout(() => {
      this.hideBanner();
    }, durationMs);
  }

  private hideBanner(): void {
    this.clearBannerTimer();
    this.bannerType = TopBannerType.NONE;
    this.bannerMessage = '';
    this.bannerPrimaryAction = BannerAction.NONE;
    this.bannerSecondaryAction = BannerAction.NONE;
  }

  /**
   * Issue #6 fix: 完全清理所有任务相关状态，防止目标词残留
   */
  private clearAllTaskStates(): void {
    // 清理故事相关状态
    this.storyText = '';
    this.storyWords = [];
    this.storyError = '';
    this.storyTranslation = '';
    this.storyLocked = false;
    this.pendingStoryUpgradeText = '';
    this.pendingStoryUpgradeError = '';
    this.pendingStoryUpgradeSourceLabel = '';

    // 清理高亮和显示状态
    this.showTargetHighlight = false;
    this.showTranslation = false;
    this.clearTargetHighlightTimer();

    // 清理任务状态
    this.currentTaskReviewed = false;
    this.hasPreloadedStory = false;
    this.isTaskLoading = false;

    // 清理对话框状态
    if (this.dialogState.wordItem !== null) {
      this.dialogState.reset();
    }

    // 清理临时状态
    this.lastReviewHint = '';
    this.pendingReviewReflection = '';

    // Issue #11 fix: 清理复习时间状态管理器
    this.reviewTimeManager.cleanup();

    console.log('[ReadPage] All task states cleared');
  }

  private clearNonStoryTaskStates(): void {
    this.showTargetHighlight = false;
    this.clearTargetHighlightTimer();
    this.showTranslation = false;
    this.currentTaskReviewed = false;
    this.storyLocked = false;
    this.pendingStoryUpgradeText = '';
    this.pendingStoryUpgradeError = '';
    this.pendingStoryUpgradeSourceLabel = '';

    if (this.dialogState.wordItem !== null) {
      this.dialogState.reset();
    }

    this.lastReviewHint = '';
    this.pendingReviewReflection = '';
    this.reviewTimeManager.cleanup();
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
        router.pushUrl({ url: 'pages/BookManager' });
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
      case BannerAction.APPLY_STORY_UPGRADE:
        return '更新语境';
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
        this.triggerLoadCurrentTask();
        return;
      case BannerAction.SETTINGS:
        this.hideBanner();
        router.pushUrl({ url: 'pages/SettingsPage' });
        return;
      case BannerAction.APPLY_STORY_UPGRADE: {
        const text = this.pendingStoryUpgradeText.trim();
        if (text.length === 0) {
          this.hideBanner();
          return;
        }
        if (this.storyController === null || this.currentWord === null) {
          this.hideBanner();
          return;
        }
        const task = this.currentTask;
        this.hideBanner();
        this.closeDialog();
        this.showTranslation = false;
        this.definitionContent = '';
        this.definitionLoading = false;
        this.storyLocked = false;
        this.storyController.applyStoryText(
          text,
          this.pendingStoryUpgradeError,
          this.pendingStoryUpgradeSourceLabel.length > 0 ? this.pendingStoryUpgradeSourceLabel : 'AI生成',
          task,
          this.currentWord,
          this.supportWords,
          (t) => this.requireTaskManager().getContextIdForTask(t)
        );
        this.pendingStoryUpgradeText = '';
        this.pendingStoryUpgradeError = '';
        this.pendingStoryUpgradeSourceLabel = '';
        return;
      }
      case BannerAction.SKIP: {
        this.hideBanner();
        const tm = this.requireTaskManager();
        const nextId = tm.getNextTaskIdBySequenceOrQueue(this.taskIndex, this.taskQueue);
        this.contextSequence = tm.getContextSequence();
        this.contextCursor = tm.getContextCursor();
        if (nextId === null) {
          this.showSessionComplete();
          return;
        }
        this.moveToTaskById(nextId);
        return;
      }
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
  private ctxDefStore: ContextDefinitionStore = ContextDefinitionStore.getInstance();
  private ctxWordMeaningStore: ContextWordMeaningStore = ContextWordMeaningStore.getInstance();
  private learningStepsPolicy: LearningStepsPolicy = new LearningStepsPolicy();
  private wordReviewer: WordReviewer = new WordReviewer(this.learningStepsPolicy);
  private sessionPlanner: SessionPlanner = SessionPlanner.getInstance();
  private contextValidator: ContextValidator | null = null;
  private storyPipeline: StoryGenerationPipeline | null = null;
  private ttsFetcher: TtsAudioFetcher = TtsAudioFetcher.getInstance();
  private systemTts: SystemTtsManager = SystemTtsManager.getInstance();
  private dbInitInFlight: Promise<void> | null = null;
  private dialogRequestToken: number = 0;
  private isLoadingTask: boolean = false;
  // Settings
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';
  private settingsLoaded: boolean = false;
  private settingsConfigured: boolean = false;
  private settingsLoadInFlight: Promise<void> | null = null;
  private lastSettingsLoadMs: number = 0;
  private readonly seenContextStore: SeenContextStore = new SeenContextStore('seen_context_ids_v2', 2000);
  private seenContextIds: Set<string> = new Set<string>();
  private todayAttemptsByWordId: Map<number, number> = new Map<number, number>();
  private reinforcementInsertedCountByWordId: Map<number, number> = new Map<number, number>();
  // Context Generation Settings
  @State private selectedContextStyle: ContextStyle = ContextStyle.RANDOM;
  @State private selectedDifficultyLevel: DifficultyLevel = DifficultyLevel.CET6;
  @State private showContextSettings: boolean = false;
  @State private showAddToBookDialog: boolean = false;
  @State private showCreateBookDialog: boolean = false;
  @State private pendingAddWord: WordItem | null = null;
  @State private joinedBookIds: string[] = [];
  @State private joinedBookCount: number = 0;
  @State private pronunciationMode: string = 'auto';
  @State private showTimeboxDialog: boolean = false;
  @State private timeboxResult: TimeboxResult | null = null;

  private timeboxManager: TimeboxManager = TimeboxManager.getInstance();

  aboutToAppear(): void {
    const startTime = Date.now();
    console.log('[Perf] ReadPage aboutToAppear started');

    // Initialize managers
    this.contextValidator = ContextValidator.getInstance();
    this.storyPipeline = new StoryGenerationPipeline(this.dictManager);

    const interactionDelegate: ReadWordInteractionDelegate = new ReadWordInteractionDelegateImpl(
      (state: DialogState): void => {
        this.dialogState = state;
      },
      (words: Set<string>): void => {
        this.notebookWords = new Set<string>(words);
      },
      (expanded: boolean): void => {
        this.meaningExpanded = expanded;
      },
      (ids: string[], count: number): void => {
        this.joinedBookIds = ids;
        this.joinedBookCount = count;
      },
      (message: string): void => {
        promptAction.showToast({ message: message, duration: 1200 });
      },
      (type: TopBannerType, message: string, duration?: number): void => {
        if (duration !== undefined) {
          this.showBannerForDuration(type, message, duration);
          return;
        }
        this.showBanner(type, message);
      }
    );
    this.interactionDelegate = interactionDelegate;

    // Initialize Managers & Controllers
    this.audioManager = new ReadPageAudioManager(
      this.dictManager,
      this.systemTts,
      this.ttsFetcher,
      (isPlaying: boolean) => { this.isPlayingAudio = isPlaying; }
    );
    void this.audioManager.init();

    const storyDelegate: ReadStoryDelegate = new ReadStoryDelegateImpl(
      (text: string, error: string, source: string): void => {
        this.storyText = text;
        this.storyError = error;
        this.storySourceLabel = source;
        this.storyLocked = false;
        this.pendingStoryUpgradeText = '';
        this.pendingStoryUpgradeError = '';
        this.pendingStoryUpgradeSourceLabel = '';
      },
      (words: StoryWord[]): void => {
        this.storyWords = words;
      },
      (translation: string): void => {
        this.storyTranslation = translation;
      },
      (hint: string): void => {
        this.taskLoadingHint = hint;
        this.isTaskLoading = true;
      },
      (): void => {
        this.isTaskLoading = false;
      },
      (): boolean => {
        return false;
      },
      (text: string, error: string, source: string): void => {
        this.pendingStoryUpgradeText = text;
        this.pendingStoryUpgradeError = error;
        this.pendingStoryUpgradeSourceLabel = source;
        this.showBanner(TopBannerType.INFO, '已生成更优语境，可手动更新。', BannerAction.APPLY_STORY_UPGRADE, BannerAction.NONE);
      },
      (text: string, error: string, source: string, hasPreloaded: boolean): void => {
        this.storyText = text;
        this.storyError = error;
        this.storySourceLabel = source;
        this.hasPreloadedStory = hasPreloaded;
        this.storyLocked = false;
        this.pendingStoryUpgradeText = '';
        this.pendingStoryUpgradeError = '';
        this.pendingStoryUpgradeSourceLabel = '';
      },
      (ctxId: string, word: string, text: string): void => {
        this.contextController?.onStoryReadyForContext(ctxId, word, text);
      },
      (): void => {
        this.contextController?.rebuildTranslationTextCache(
          this.currentWord,
          this.storyText,
          this.storyTranslation,
          this.translationDefinitionLoading
        );
      }
    );
    this.storyController = new ReadStoryController(
      this.storyPipeline,
      this.dictManager,
      this.dbManager,
      this.contextValidator,
      storyDelegate
    );

    this.interactionController = new ReadWordInteractionController(
      this.interactionDelegate,
      this.dbManager,
      this.dictManager,
      this.ctxWordMeaningStore
    );

    const contextDelegate: ReadContextDelegate = new ReadContextDelegateImpl(
      (content: string): void => {
        this.definitionContent = content;
      },
      (loading: boolean): void => {
        this.definitionLoading = loading;
      },
      (cache: string): void => {
        this.translationTextCache = cache;
      }
    );
    this.contextController = new ReadContextController(
      contextDelegate,
      this.ctxDefStore,
      this.dictManager
    );

    this.sessionManager = new ReadPageSessionManager(
      this.sessionPlanner,
      this.dbManager
    );

    this.reviewManager = new ReadPageReviewManager(
      this.wordReviewer,
      this.learningStepsPolicy,
      this.reviewTimeManager,
      this.dbManager
    );

    this.taskManager = new ReadPageTaskManager(
      this.dictManager,
      this.dbManager,
      this.storyController,
      this.contextController
    );
    console.log('[ReadPage] ContextValidator initialized');

    const context = getContext(this) as common.UIAbilityContext;
    this.dbInitInFlight = this.dbManager.initialize(context);
    this.ctxDefStore.injectContext(context);
    void this.ctxDefStore.initialize();
    this.ctxWordMeaningStore.injectContext(context);
    void this.ctxWordMeaningStore.initialize();
    const secureStorage = SecureStorage.getInstance();
    secureStorage.injectContext(context);
    void secureStorage.initialize();
    const settingsStore = SettingsStore.getInstance();
    settingsStore.injectContext(context);
    void settingsStore.initialize();
    this.ttsFetcher.injectContext(context);
    void this.systemTts.ensureReady();

    void this.loadUserSettingsAsync();
    this.initializeSession();

    console.log(`[Perf] ReadPage aboutToAppear took ${Date.now() - startTime}ms`);
  }

  aboutToDisappear(): void {
    const startTime = Date.now();
    console.log('[Perf] ReadPage aboutToDisappear started');

    this.clearTargetHighlightTimer();
    this.clearBannerTimer();
    this.persistSessionContext();
    
    // End timebox session
    this.timeboxManager.endSession();
    
    if (this.audioManager) {
      void this.audioManager.release();
    }
    
    this.systemTts.shutdown();

    console.log(`[Perf] ReadPage aboutToDisappear took ${Date.now() - startTime}ms`);
  }

  private async ensureDbReady(): Promise<void> {
    if (this.dbInitInFlight !== null) {
      await this.dbInitInFlight;
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    this.dbInitInFlight = this.dbManager.initialize(context);
    await this.dbInitInFlight;
  }

  /**
   * Load user settings (API + context preferences + TTS)
   */
  private async loadUserSettingsAsync(): Promise<void> {
    try {
      console.log('[ReadPage] Loading user settings...');

      const settingsStore = SettingsStore.getInstance();
      let settings: AppSettings | null = await settingsStore.getSettings();
      if (settings === null) {
        const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
        if (settingsJson !== undefined && settingsJson.length > 0) {
          settings = AppSettings.fromJSON(settingsJson);
          void settingsStore.saveSettings(settings);
        }
      }

      if (settings !== null) {
        const secureStorage = SecureStorage.getInstance();
        const apiKey = await secureStorage.getApiKey();
        // TTS
        this.enableTTS = settings.enableTTS;
        this.pronunciationMode = settings.pronunciationMode;
        this.newbieMode = settings.newbieMode;
        this.externalDictEnabled = settings.externalDictEnabled;
        this.externalDictUrlTemplate = settings.externalDictUrlTemplate;
        // Load custom context length settings
        this.contextLengthMin = settings.contextLengthMin;
        this.contextLengthMax = settings.contextLengthMax;
        this.learningStepsPolicy.setStepMinutes(settings.learningStepMinutes);
        // Context preferences
        this.selectedContextStyle = settings.contextStyle as ContextStyle;
        this.selectedDifficultyLevel = settings.difficultyLevel as DifficultyLevel;
        this.dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel);
        // Configure API (optional)
        this.dictManager.configure(settings.apiBaseUrl, apiKey, settings.apiModel);
        this.settingsConfigured = this.dictManager.isConfigured();

        console.log('[ReadPage] Settings loaded successfully:', {
          enableTTS: this.enableTTS,
          pronunciationMode: this.pronunciationMode,
          contextStyle: this.selectedContextStyle,
          difficultyLevel: this.selectedDifficultyLevel
        });
      } else {
        console.log('[ReadPage] No settings found, using defaults');
        this.settingsConfigured = this.dictManager.isConfigured();
      }
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      console.warn('[ReadPage] Failed to load settings:', errorMsg);
      this.settingsConfigured = this.dictManager.isConfigured();
    } finally {
      this.settingsLoaded = true;
      this.lastSettingsLoadMs = Date.now();
    }
  }

  private async ensureSettingsLoaded(): Promise<void> {
    if (this.dictManager.isConfigured()) {
      this.settingsConfigured = true;
      return;
    }
    if (this.settingsLoadInFlight !== null) {
      await this.settingsLoadInFlight;
      this.settingsConfigured = this.dictManager.isConfigured();
      return;
    }
    this.settingsLoadInFlight = this.loadUserSettingsAsync();
    try {
      await this.settingsLoadInFlight;
    } finally {
      this.settingsLoadInFlight = null;
      this.settingsConfigured = this.dictManager.isConfigured();
    }
  }

  /**
   * Initialize learning session from router params
   * Issue #3 fix: Optimized for faster startup response
   */
  private async initializeSession(): Promise<void> {
    this.todayAttemptsByWordId.clear();
    this.reinforcementInsertedCountByWordId.clear();
    this.storyText = '';
    this.storyWords = [];
    this.storyError = '';
    this.supportWords = [];
    this.currentStoryHash = '';
    
    if (this.storyController) {
      this.storyController.clearCache();
    }

    // Start timebox session
    this.timeboxManager.startSession();
    
    if (this.sessionManager) {
      this.taskLoadingHint = '准备学习任务...';
      this.isTaskLoading = true;

      const result: SessionInitResult = await this.sessionManager.initializeSession(
        (tasks: TaskItem[]) => this.requireTaskManager().filterOutSeenTasks(tasks)
      );

      if (result.success && result.tasks) {
        this.session = this.sessionManager.getSession()!;
        this.taskQueue = result.tasks;
        this.prewarmReinforcementTasks(this.taskQueue);
        void this.loadCurrentTask();
      } else {
        this.isTaskLoading = false;
        if (result.errorTitle && result.errorMessage) {
          this.showSessionError(
            result.errorTitle,
            result.errorMessage,
            result.primaryAction || SessionErrorAction.NONE,
            result.secondaryAction || SessionErrorAction.NONE
          );
        }
      }
    }
  }



  /**
   * Load current task and prepare content
   */
  // Add error count state (deprecated, use controller)
  @State private taskErrorCount: number = 0;
  private readonly MAX_TASK_ERRORS: number = 3;

  private async loadCurrentTask(): Promise<void> {
    const startTime = Date.now();
    const taskIndex = this.sessionManager?.getTaskIndex() ?? 0;
    const taskQueueLength = this.sessionManager?.getTaskQueue().length ?? 0;
    
    console.log(`[Perf] loadCurrentTask started (task ${taskIndex + 1}/${taskQueueLength})`);

    if (this.sessionManager?.checkSessionComplete()) {
      this.showSessionComplete();
      return;
    }

    this.taskLoadingHint = `加载任务 ${taskIndex + 1}/${taskQueueLength}...`;
    this.isTaskLoading = true;

    try {
      await this.ensureSettingsLoaded();
      const task = this.sessionManager?.getCurrentTask();
      if (!task || !task.word) {
        throw new Error(`Invalid task at index ${taskIndex}`);
      }

      this.currentTask = task;
      this.currentWord = task.word;
      this.updateIntervalHints(this.currentWord);
      this.hasPreloadedStory = false;
      this.showTranslation = false;
      this.showTargetHighlight = false;
      this.clearTargetHighlightTimer();
      this.currentTaskReviewed = false;

      if (this.dialogState.wordItem !== null && this.dialogState.wordItem.id !== task.word.id) {
        this.dialogState.reset();
      }

      this.storyTranslation = '';
      this.contextController?.rebuildTranslationTextCache(
        this.currentWord,
        this.storyText,
        this.storyTranslation,
        this.translationDefinitionLoading
      );
      
      const loadCallbacks: TaskLoadCallbacks = {
        onSnapshotError: (error: Error): void => {
          console.error('[ReadPage] Snapshot error:', error.message);
        },
        onDefinitionLoading: (loading: boolean): void => {
          this.translationDefinitionLoading = loading;
        }
      };
      const result = await ReadPageLoader.loadTaskResources(
        task,
        this.sessionManager!,
        this.taskManager,
        this.storyController,
        this.contextController,
        this.session,
        this.storyTranslation,
        loadCallbacks
      );

      this.currentSnapshot = result.snapshot;
      this.hasPreloadedStory = result.hasPreloadedStory;
      if (!this.hasPreloadedStory) {
          this.storyText = result.storyText ?? '';
          this.storyWords = result.storyWords ?? [];
          this.storyError = result.storyError ?? '';
          this.storySourceLabel = result.storySourceLabel ?? '';
          this.supportWords = result.supportWords;
      }
      
      if (result.definition) {
          if (this.currentWord) {
             const updated = this.currentWord.clone();
             updated.definition = result.definition;
             this.currentWord = updated;
             this.contextController?.rebuildTranslationTextCache(
                this.currentWord,
                this.storyText,
                this.storyTranslation,
                this.translationDefinitionLoading
             );
          }
      }
      
      this.definitionContent = '';
      this.definitionLoading = false;
      this.currentStoryHash = '';
      
      this.clearNonStoryTaskStates();
      
      if (this.taskManager) {
        await this.taskManager.prepareTaskContent(task, this.hasPreloadedStory, this.storyText, this.supportWords);
      }

      console.log('[ReadPage] Task', taskIndex + 1, 'loaded successfully');
      this.sessionManager?.resetTaskErrorCount();
      this.hideBanner();
      this.scheduleTargetHighlight();
      setTimeout((): void => {
         if (this.sessionManager && this.storyController) {
            this.storyController.maybeStartVignettePrewarm(
                this.sessionManager.getTaskQueue(), 
                this.sessionManager.getTaskIndex()
            );
         }
      }, 800);
      void this.preloadNextTask();

    } catch (error) {
       const errorMsg = error instanceof Error ? error.message : String(error);
       console.error('[ReadPage] Failed to load task', taskIndex + 1, ':', errorMsg);
       
       const count = this.sessionManager?.incrementTaskErrorCount() ?? 0;
       const maxErrors = this.sessionManager?.getMaxTaskErrors() ?? 3;

       const info: ErrorInfo = buildUserFacingError(errorMsg);
       const detailLine = info.rawDetail.length > 0 ? `\n\n详情(截断):\n${info.rawDetail}` : '';
       const message = `${info.userMessage} 建议：${info.suggestion}${detailLine}`;
       const primaryAction = info.showRetryAction ? BannerAction.RETRY : BannerAction.SKIP;
       const secondaryAction = info.showSettingsAction ? BannerAction.SETTINGS : BannerAction.NONE;
       this.showBanner(TopBannerType.ERROR, message, primaryAction, secondaryAction);

       if (count >= maxErrors) {
         console.error('[ReadPage] Too many consecutive task errors, ending session');
         this.showBanner(TopBannerType.ERROR, `连续 ${maxErrors} 个任务加载失败，会话已结束。`, BannerAction.NONE,
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


  private async preloadNextTask(): Promise<void> {
    if (this.sessionManager && this.taskManager) {
      await this.taskManager.preloadNextTask(
        this.sessionManager.getTaskIndex(),
        this.sessionManager.getTaskQueue()
      );
    }
  }

  /**
   * Handle word click in story
   */
  private async onWordClick(storyWord: StoryWord): Promise<void> {
    if (this.interactionController) {
      this.storyLocked = true;
      this.pendingReviewReflection = '';
      await this.interactionController.onWordClick(
        storyWord,
        () => this.dialogState,
        this.notebookWords,
        this.currentWord,
        this.session,
        this.storyText,
        this.currentStoryHash,
        () => this.ensureSettingsLoaded()
      );
    }
  }

  private async playPronunciation(word: string): Promise<void> {
    if (this.audioManager) {
      await this.audioManager.playPronunciation(
        word,
        this.enableTTS,
        this.pronunciationMode,
        this.pronunciationPreferSystemTts
      );
    }
  }

  /**
     * Add word to notebook (for new words)
     */
    private async addToNotebook(): Promise<void> {
      if (this.interactionController) {
        await this.interactionController.addToNotebookSafe(
          () => this.dialogState,
          this.notebookWords
        );
      }
    }

  private async removeFromNotebook(): Promise<void> {
    if (this.interactionController) {
      await this.interactionController.removeFromNotebookSafe(
        () => this.dialogState,
        this.notebookWords
      );
    }
  }

  private openAddToBookDialog(word: WordItem): void {
    this.pendingAddWord = word;
    this.showAddToBookDialog = true;
    this.showCreateBookDialog = false;
    if (this.interactionController) {
      void this.interactionController.refreshJoinedBooksForDialog(word.word);
    }
  }

  private dismissAddDialogs(): void {
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = false;
    this.pendingAddWord = null;
  }

  private handleAddDialogSelect(result: AddToBookDialogResult): void {
    if (this.pendingAddWord && this.interactionController) {
      const isJoined = this.isBookJoined(result.bookId);
      void this.interactionController.joinWordToBook(this.pendingAddWord.word, result.bookId, result.bookName, isJoined).then(() => {
        this.dismissAddDialogs();
      });
    }
  }

  private handleAddDialogRequestCreate(): void {
    if (this.pendingAddWord === null) {
      return;
    }
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = true;
  }

  private handleCreateBookCancel(): void {
    this.showCreateBookDialog = false;
    if (this.pendingAddWord !== null) {
      this.showAddToBookDialog = true;
    }
  }

  private handleCreateBookSubmit(result: CreateBookDialogResult): void {
    if (this.pendingAddWord && this.interactionController) {
      void this.interactionController.createBookAndJoin(this.pendingAddWord.word, result.name).then(() => {
        this.dismissAddDialogs();
      });
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

  private async processReview(rating: Rating, reflection: string): Promise<void> {
    if (!this.currentWord || !this.sessionManager || !this.reviewManager) return;

    // Record review for timebox tracking
    const isNewWord = this.currentWord.status === WordStatus.NEW;
    this.timeboxManager.recordReview(isNewWord);

    // Check timebox
    if (this.timeboxManager.isTimeboxReached()) {
      this.timeboxResult = this.timeboxManager.getSessionStats();
      this.showTimeboxDialog = true;
      return;
    }

    // Show reminder if needed
    if (this.timeboxManager.shouldShowReminder()) {
      const remaining = this.timeboxManager.getFormattedRemainingTime();
      promptAction.showToast({
        message: `学习时间即将结束，还剩${remaining}`,
        duration: 2000
      });
    }

    const reviewCallbacks: ReviewProcessCallbacks = {
      onShowBanner: (type: TopBannerType, message: string, duration: number): void => {
        this.showBannerForDuration(type, message, duration);
      },
      onMoveToNext: (): void => {
        this.moveToNextTaskWithDelay();
      }
    };
    const result = await ReadPageReviewHandler.processReview(
      rating,
      reflection,
      this.currentWord,
      this.currentTask,
      this.sessionManager,
      this.reviewManager,
      reviewCallbacks
    );

    if (result) {
        if (result.newQueue) {
            this.taskQueue = result.newQueue;
        }
        
        this.dialogState.wordItem = result.updatedWord;
        this.dialogState.hasBeenReviewed = true;
        this.dialogState.canUndo = true;
        this.lastReviewHint = result.nextReviewHint;
        
        if (this.currentWord.id === result.updatedWord.id) {
            this.currentWord = result.updatedWord;
            this.showTranslation = false;
            this.updateIntervalHints(this.currentWord);
        }
    }
  }

  /**
   * Handle "Forget" (Again) button
   */
  private async handleForget(): Promise<void> {
    const reflection = this.pendingReviewReflection;
    this.pendingReviewReflection = '';
    await this.processReview(Rating.AGAIN, reflection);
  }

  /**
   * Handle "Remember" (Good) button
   */
  private async handleRemember(): Promise<void> {
    const reflection = this.pendingReviewReflection;
    this.pendingReviewReflection = '';
    await this.processReview(Rating.GOOD, reflection);
  }

  /**
   * Handle "Easy" button
   */
  private async handleEasy(): Promise<void> {
    const reflection = this.pendingReviewReflection;
    this.pendingReviewReflection = '';
    await this.processReview(Rating.EASY, reflection);
  }

  private triggerFlash(button: FlashButton): void {
    this.flashButton = button;
    setTimeout(() => {
      this.flashButton = FlashButton.NONE;
    }, 120);
  }

  private updateIntervalHints(word: WordItem | null): void {
    if (!word) {
      this.ratingIntervalHints = {
        again: '',
        hard: '',
        good: '',
        easy: ''
      };
      return;
    }
    const previews = this.wordReviewer.getIntervalPreviews(word);
    this.ratingIntervalHints = {
      again: previews.get(Rating.AGAIN) ?? '',
      hard: previews.get(Rating.HARD) ?? '',
      good: previews.get(Rating.GOOD) ?? '',
      easy: previews.get(Rating.EASY) ?? ''
    };
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getForgetButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.FORGET ? this.colors.ERROR_LIGHT : this.colors.ERROR;
  }

  private getHardButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.HARD ? this.colors.WARNING_LIGHT : this.colors.WARNING;
  }

  private getRememberButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.REMEMBER ? this.colors.SUCCESS_LIGHT : this.colors.SUCCESS;
  }

  private getEasyButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.EASY ? this.colors.PRIMARY_LIGHT : this.colors.PRIMARY;
  }

  private getUndoButtonBorderColor(): ResourceColor {
    return this.flashButton === FlashButton.UNDO ? this.colors.ERROR_LIGHT : this.colors.ERROR;
  }

  private isFirstContextWord(): boolean {
    if (this.currentWord === null) {
      return false;
    }
    return this.currentWord.history.getReviewCount() === 0;
  }

  private showRatingHint(message: string): void {
    if (message.length === 0) {
      return;
    }
    promptAction.showToast({ message: message, duration: 1200 });
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
      promptAction.showToast({ message: '请稍候...', duration: 500 });
      return;
    }
    this.pushHistoryBeforeReview();
    this.triggerFlash(FlashButton.FORGET);
    this.pendingReviewReflection = '';
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
      promptAction.showToast({ message: '请稍候...', duration: 500 });
      return;
    }
    this.pushHistoryBeforeReview();
    this.currentTaskReviewed = true;
    this.triggerFlash(FlashButton.HARD);
    const reflection = this.pendingReviewReflection;
    this.pendingReviewReflection = '';
    this.startReviewCooldown();
    void this.vibrateByRating(Rating.HARD);
    
    // Process review and advance to next task
    void this.processReview(Rating.HARD, reflection);

    console.log(`[Perf] onHardClick took ${Date.now() - startTime}ms`);
  }

  private onRememberClick(): void {
    const startTime = Date.now();
    console.log('[Perf] onRememberClick started');

    if (this.isReviewCooling || this.currentTaskReviewed) {
      promptAction.showToast({ message: '请稍候...', duration: 500 });
      return;
    }
    this.pushHistoryBeforeReview();
    this.triggerFlash(FlashButton.REMEMBER);

    this.currentTaskReviewed = true;
    this.pendingReviewReflection = '';
    this.startReviewCooldown();
    void this.vibrateByRating(Rating.GOOD);
    void this.handleRemember();

    console.log(`[Perf] onRememberClick took ${Date.now() - startTime}ms`);
  }

  private onEasyClick(): void {
    const startTime = Date.now();
    console.log('[Perf] onEasyClick started');

    if (this.isReviewCooling || this.currentTaskReviewed) {
      promptAction.showToast({ message: '请稍候...', duration: 500 });
      return;
    }
    this.pushHistoryBeforeReview();
    this.triggerFlash(FlashButton.EASY);

    this.currentTaskReviewed = true;
    this.pendingReviewReflection = '';
    this.startReviewCooldown();
    void this.vibrateByRating(Rating.EASY);
    void this.handleEasy();

    console.log(`[Perf] onEasyClick took ${Date.now() - startTime}ms`);
  }

  private onUndoClick(): void {
    this.triggerFlash(FlashButton.UNDO);
    void this.vibrateByRating(Rating.HARD);
    void this.handleUndo();
  }

  private async prewarmReinforcementTasks(tasks: TaskItem[]): Promise<void> {
    if (tasks.length === 0) {
      return;
    }
    for (let i: number = 0; i < tasks.length; i++) {
      const task = tasks[i];
      if (task.type !== TaskType.STORY) {
        continue;
      }
      if (this.storyController && this.storyController.hasPreloadedStory(task.id)) {
        continue;
      }
      if (this.reinforcementPrewarmIds.has(task.id)) {
        continue;
      }
      this.reinforcementPrewarmIds.add(task.id);
      try {
        if (this.storyController) {
          await this.storyController.preloadStoryForTask(
            task,
            (t) => this.requireTaskManager().getContextIdForTask(t),
            (contextId: string, word: string, text: string): Promise<void> => {
              if (this.contextController) {
                return this.contextController.preGenerateContextDefinition(contextId, word, text);
              }
              return Promise.resolve();
            }
          );
        }
      } finally {
        this.reinforcementPrewarmIds.delete(task.id);
      }
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
      this.showBannerForDuration(TopBannerType.WARNING, '无法撤回：未找到可用快照。', 1500);
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

      // Update current word if this is the target
      if (this.currentWord !== null && restoredWord.id === this.currentWord.id) {
        this.currentWord = restoredWord;
        this.updateIntervalHints(this.currentWord);
        // Create new snapshot for potential re-review
        this.currentSnapshot = new WordSnapshot(restoredWord);
        this.session.createSnapshot(restoredWord);
        this.contextController?.syncDefinitionForCurrentContext(
          this.showTranslation,
          this.currentTask,
          this.currentWord,
          this.storyText,
          (t) => this.requireTaskManager().getContextIdForTask(t)
    );
      }

      this.showBannerForDuration(TopBannerType.INFO, '已撤销本次评分', 1000);

    } catch (error) {
      console.error('[ReadPage] Failed to undo:', error);
      this.showBannerForDuration(TopBannerType.ERROR, '撤回失败，请稍后再试。', 2000);
    }
  }

  private canUndoLastReviewed(): boolean {
    return !this.historyStack.isEmpty();
  }

  private async undoLastReviewed(): Promise<void> {
    const entry = this.snapshotManager.popHistory();
    this.historyStack = this.snapshotManager.getHistoryStack();

    if (entry === null) {
      this.showBannerForDuration(TopBannerType.INFO, '没有可撤回的记录', 1000);
      return;
    }
    try {
      this.isGeneratingStory = false;
      await this.dbManager.updateWord(entry.wordBeforeReview.clone());

      const snap = entry.context;
      const rebuiltQueue: TaskItem[] = [];
      for (const t of snap.taskQueue) {
        rebuiltQueue.push(t.toTaskItem());
      }
      
      if (this.sessionManager) {
        this.sessionManager.setTaskQueue(rebuiltQueue);
        
        const byIdIndex = snap.currentTaskId.length > 0 ? 
          this.requireTaskManager().findTaskIndexByTaskId(snap.currentTaskId, rebuiltQueue) : -1;
          
        if (byIdIndex >= 0) {
          this.sessionManager.setTaskIndex(byIdIndex);
        } else {
          this.sessionManager.setTaskIndex(
              Math.max(0, Math.min(snap.taskIndex, rebuiltQueue.length - 1))
          );
        }
      }
      this.taskQueue = rebuiltQueue;
      this.taskIndex = this.sessionManager?.getTaskIndex() ?? 0;

      this.contextSequence = [...snap.contextSequence];
      this.contextCursor = snap.contextCursor;
      this.seenContextIds = new Set<string>(snap.seenContextIds);
      this.persistSeenContextIds();
      
      if (this.taskManager) {
          this.taskManager.setContextSequence(this.contextSequence, this.contextCursor);
          this.taskManager.setSeenContextIds(this.seenContextIds);
      }

      const currentTask = this.sessionManager?.getCurrentTask();
      if (!currentTask) throw new Error("No current task after undo");
      
      const currentWord = currentTask.word;
      
      if (this.storyController) {
        const parsedWords = this.storyController.parseStoryIntoWordsForText(snap.storyText, currentWord.word, snap.supportWords);
        const preloaded: PreloadedStory = {
          targetWord: currentWord.word,
          text: snap.storyText,
          words: parsedWords,
          error: snap.storyError,
          supportWords: [...snap.supportWords],
          sourceLabel: '恢复'
        };
        this.storyController.restorePreloadedStory(currentTask.id, preloaded);
      }

      await this.loadCurrentTask();

      this.storyTranslation = snap.storyTranslation;
      this.showTranslation = snap.showTranslation;
      this.contextController?.syncDefinitionForCurrentContext(
        this.showTranslation,
        this.currentTask,
        this.currentWord,
        this.storyText,
        (t) => this.requireTaskManager().getContextIdForTask(t)
      );
      this.lastReviewHint = snap.lastReviewHint;
      this.pendingReviewReflection = snap.pendingReviewReflection;
      this.currentTaskReviewed = false;
      
      if (this.sessionManager) {
          this.sessionManager.restoreWordState(
              entry.wordBeforeReview.id, 
              entry.prevAttempts, 
              entry.prevReinforcementInsertedCount
          );
          this.sessionManager.updateSessionCounts(
              entry.prevSessionReviewedCount, 
              entry.prevSessionNewLearnedCount
          );
      }

      this.reviewTimeManager.cancelReview(entry.wordBeforeReview);
      this.showBannerForDuration(TopBannerType.INFO, '已撤回上一步', 1000);
    } catch (e) {
      console.error('[ReadPage] Undo failed:', e);
      this.showBannerForDuration(TopBannerType.ERROR, '撤回失败，请稍后再试。', 2000);
    }
  }

  /**
   * Close dialog
   */
  private closeDialog(): void {
    this.dialogRequestToken++;
    const next = this.cloneDialogState(this.dialogState);
    next.isVisible = false;
    next.isLoading = false;
    this.dialogState = next;
  }

  /**
   * Move to next task in queue
   */
  private moveToNextTask(): void {
    const tm = this.requireTaskManager();
    const nextId = tm.getNextTaskIdBySequenceOrQueue(this.taskIndex, this.taskQueue);
    this.contextSequence = tm.getContextSequence();
    this.contextCursor = tm.getContextCursor();
    if (nextId === null) {
      this.showSessionComplete();
      return;
    }
    this.moveToTaskById(nextId);
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
    this.sessionCompleted = true;
    this.clearPersistedSessionContext();
    // Check if any words were actually learned
    const totalLearned = this.session.reviewedCount + this.session.newLearnedCount;

    if (totalLearned === 0) {
      // No words learned, show error message instead
      this.showBanner(
        TopBannerType.ERROR,
        '没有学习到任何单词，可能是任务加载失败。请检查配置或网络后重试。',
        BannerAction.NONE,
        BannerAction.NONE
      );
      setTimeout(() => {
        router.back();
      }, 1500);
    }
  }

  /**
   * Go back to home
   */
  private goBack(): void {
    this.closeDialog();
    router.back();
  }

  private buildExternalDictUrl(word: string): string {
    const w = word.trim().toLowerCase();
    if (w.length === 0) {
      return '';
    }
    const template = this.externalDictUrlTemplate.trim();
    if (template.length === 0) {
      return '';
    }
    return template.replace(/\{word\}/g, encodeURIComponent(w));
  }

  private openExternalDict(word: string): void {
    if (!this.externalDictEnabled) {
      return;
    }
    const url = this.buildExternalDictUrl(word);
    if (url.length === 0) {
      promptAction.showToast({ message: '外部词典链接未配置', duration: 1200 });
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    void openUrl(ctx, url);
  }

  private async toggleKnownFromPanel(item: WordItem): Promise<void> {
    try {
      const nextItem = item.clone();
      nextItem.status = nextItem.status === WordStatus.KNOWN ? WordStatus.LEARNING : WordStatus.KNOWN;
      nextItem.updatedAt = Date.now();
      await this.dbManager.updateWord(nextItem);
      const next = this.dialogState.clone();
      next.wordItem = nextItem;
      this.dialogState = next;
      promptAction.showToast({ message: nextItem.status === WordStatus.KNOWN ? '已标记为已知' : '已恢复学习', duration: 900 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `操作失败：${msg}`, duration: 1500 });
    }
  }

  build() {
    Stack() {
      Column() {
        // Header
        ReadPageHeader({
          taskIndex: this.taskIndex,
          taskQueueLength: this.taskQueue.length,
          canUndo: this.canUndoLastReviewed(),
          onBack: () => this.goBack(),
          onUndo: () => this.undoLastReviewed()
        })

        if (this.sessionErrorMessage.length > 0) {
          SessionErrorView({
            errorTitle: this.sessionErrorTitle,
            errorMessage: this.sessionErrorMessage,
            primaryActionLabel: this.getSessionActionLabel(this.sessionErrorPrimaryAction),
            secondaryActionLabel: this.getSessionActionLabel(this.sessionErrorSecondaryAction),
            showPrimaryAction: this.sessionErrorPrimaryAction !== SessionErrorAction.NONE,
            showSecondaryAction: this.sessionErrorSecondaryAction !== SessionErrorAction.NONE,
            onPrimaryAction: () => this.handleSessionErrorAction(this.sessionErrorPrimaryAction),
            onSecondaryAction: () => this.handleSessionErrorAction(this.sessionErrorSecondaryAction)
          })
        } else {
          // Main content
          Scroll() {
            Column() {
              // Story area
              StoryView({
                storyText: this.storyText,
                storyError: this.storyError,
                storySourceLabel: this.storySourceLabel,
                storyWords: this.storyWords,
                currentStoryHash: this.currentStoryHash,
                showTargetHighlight: this.showTargetHighlight,
                showTranslation: this.showTranslation,
                definitionLoading: this.definitionLoading,
                definitionContent: this.definitionContent,
                isGeneratingStory: this.isGeneratingStory,
                currentWord: this.currentWord ?? this.emptyWord,
                onWordClick: (word: StoryWord) => this.onWordClick(word),
                onToggleTranslation: () => this.onToggleTranslationClick(),
                onGenerateStory: () => {
                  if (this.currentTask && this.currentWord) {
                    this.storyController?.generateStory(
                      this.currentTask,
                      this.currentWord,
                      this.supportWords,
                      (t) => this.requireTaskManager().getContextIdForTask(t)
                    );
                  }
                }
                })
            }
            .width('100%')
            .padding(DesignTokens.Layout.CONTAINER_PADDING)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          FeedbackBar({
            flashButton: this.flashButton,
            isReviewCooling: this.isReviewCooling,
            isFirstContextWord: this.isFirstContextWord(),
            intervalHints: this.ratingIntervalHints,
            onForget: () => this.onForgetClick(),
            onHard: () => this.onHardClick(),
            onRemember: () => this.onRememberClick(),
            onEasy: () => this.onEasyClick(),
            onShowHint: (msg: string) => this.showRatingHint(msg)
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_PRIMARY)

      // 浮动撤回按钮已移除，仅保留头部导航栏撤回按钮

      if (this.bannerType !== TopBannerType.NONE && this.bannerMessage.length > 0) {
        TopBanner({
          message: this.bannerMessage,
          type: this.bannerType,
          primaryLabel: this.getBannerActionLabel(this.bannerPrimaryAction),
          secondaryLabel: this.getBannerActionLabel(this.bannerSecondaryAction),
          showClose: true,
          onPrimary: this.bannerPrimaryAction !== BannerAction.NONE
            ? () => this.handleBannerAction(this.bannerPrimaryAction)
            : undefined,
          onSecondary: this.bannerSecondaryAction !== BannerAction.NONE
            ? () => this.handleBannerAction(this.bannerSecondaryAction)
            : undefined,
          onClose: () => this.hideBanner()
        })
      }

      // Word dialog overlay
      if (this.dialogState.isVisible) {
        WordSidePanel({
          dialogState: this.dialogState,
          meaningExpanded: this.meaningExpanded,
          newbieMode: this.newbieMode,
          joinedBookCount: this.joinedBookCount,
          externalDictEnabled: this.externalDictEnabled,
          onClose: () => this.closeDialog(),
          onPlayPronunciation: (word: string) => { void this.playPronunciation(word); },
          onAddToBook: () => {
            const item = this.getDialogWordItemForAdd();
            if (item) this.openAddToBookDialog(item);
          },
          onAddToNotebook: () => { void this.addToNotebook(); },
          onRemoveFromNotebook: () => { void this.removeFromNotebook(); },
          onOpenExternalDict: (word: string) => this.openExternalDict(word),
          onToggleKnown: (wordItem: WordItem) => { void this.toggleKnownFromPanel(wordItem); }
        })
        .align(Alignment.Bottom)
      }

      // Context settings dialog overlay
      if (this.showContextSettings) {
        ContextSettingsDialog({
           selectedContextStyle: $selectedContextStyle,
           selectedDifficultyLevel: $selectedDifficultyLevel,
           onClose: () => { this.showContextSettings = false; },
           onApply: () => {
               this.showContextSettings = false;
               if (this.currentTask && this.currentWord) {
                  this.storyController?.generateStory(
                    this.currentTask,
                    this.currentWord,
                    this.supportWords,
                    (t) => this.requireTaskManager().getContextIdForTask(t)
                  );
               }
             }
        })
      }

      if (this.showAddToBookDialog || this.showCreateBookDialog) {
        this.buildAddToBookFlowDialogs()
      }

      // Task loading overlay
      if (this.isTaskLoading) {
        TaskLoadingOverlay({
          loadingHint: this.taskLoadingHint
        })
      }

      if (this.sessionCompleted) {
        SessionCompletionView({
          reviewedCount: this.session.reviewedCount,
          newLearnedCount: this.session.newLearnedCount,
          onConfirm: () => {
            AppStorage.setOrCreate('today_session_complete_ms', String(Date.now()));
            router.back();
          }
        })
      }

      // Timebox dialog
      if (this.showTimeboxDialog && this.timeboxResult !== null) {
        Column() {
          Column() {
            Text('学习时间到！')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.TEXT_PRIMARY)
              .margin({ bottom: DesignTokens.Spacing.MD })

            Text(`本次学习时长：${this.timeboxManager.formatTime(this.timeboxResult.elapsedMinutes)}`)
              .fontSize(16)
              .fontColor(this.colors.TEXT_SECONDARY)
              .margin({ bottom: DesignTokens.Spacing.SM })

            Text(`复习单词：${this.timeboxResult.cardsReviewed}个`)
              .fontSize(16)
              .fontColor(this.colors.TEXT_SECONDARY)
              .margin({ bottom: DesignTokens.Spacing.SM })

            Text(`新学单词：${this.timeboxResult.newWordsLearned}个`)
              .fontSize(16)
              .fontColor(this.colors.TEXT_SECONDARY)
              .margin({ bottom: DesignTokens.Spacing.LG })

            Row() {
              Button('继续学习')
                .width('40%')
                .height(44)
                .fontSize(16)
                .fontColor(this.colors.PRIMARY)
                .backgroundColor(this.colors.BACKGROUND_SECONDARY)
                .borderRadius(DesignTokens.BorderRadius.MD)
                .onClick(() => {
                  this.showTimeboxDialog = false;
                  this.timeboxManager.startSession();
                })

              Button('结束学习')
                .width('40%')
                .height(44)
                .fontSize(16)
                .fontColor(this.colors.WHITE)
                .backgroundColor(this.colors.PRIMARY)
                .borderRadius(DesignTokens.BorderRadius.MD)
                .onClick(() => {
                  this.showTimeboxDialog = false;
                  router.back();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
          }
          .width('85%')
          .padding(DesignTokens.Spacing.LG)
          .backgroundColor(this.colors.BACKGROUND_PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.LG)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .id('readPage_' + this.themeRefreshToken)
  }


















  private getJoinBookButtonText(): string {
    if (this.joinedBookCount > 0) {
      return `已加入：${this.joinedBookCount}`;
    }
    return '加入词书';
  }

  private isBookJoined(bookId: string): boolean {
    const id = bookId.trim();
    for (const joined of this.joinedBookIds) {
      if (joined === id) {
        return true;
      }
    }
    return false;
  }

  // Helper methods

  private getDialogWordItemForAdd(): WordItem | null {
    if (this.dialogState.wordItem !== null) {
      return this.dialogState.wordItem;
    }
    if (this.dialogState.word.trim().length === 0 || this.dialogState.definition === null) {
      return null;
    }
    const now = Date.now();
    const item = new WordItem(
      0,
      this.dialogState.word.trim().toLowerCase(),
      WordStatus.NEW,
      new FSRSState(),
      new ReviewHistory(),
      this.dialogState.definition,
      now,
      now,
      now,
      '',
      []
    );
    return item;
  }











      


  private onToggleTranslationClick(): void {
    this.storyLocked = true;
    const next = !this.showTranslation;
    this.showTranslation = next;
    if (!next) {
      this.definitionLoading = false;
      return;
    }
    this.definitionContent = '';
    this.definitionLoading = false;

    this.contextController?.syncDefinitionForCurrentContext(
      this.showTranslation,
      this.currentTask,
      this.currentWord,
      this.storyText,
      (t) => this.requireTaskManager().getContextIdForTask(t)
    );
  }



      














  @Builder
  buildAddToBookFlowDialogs() {
    Stack() {
      if (this.pendingAddWord !== null) {
        AddToBookDialog({
          visible: this.showAddToBookDialog,
          word: this.pendingAddWord,
          joinedBookIds: this.joinedBookIds,
          onDismiss: () => this.dismissAddDialogs(),
          onSelectBook: (result: AddToBookDialogResult) => this.handleAddDialogSelect(result),
          onRequestCreateBook: () => this.handleAddDialogRequestCreate()
        })

        CreateBookDialog({
          visible: this.showCreateBookDialog,
          onCancel: () => this.handleCreateBookCancel(),
          onCreate: (result: CreateBookDialogResult) => this.handleCreateBookSubmit(result)
        })
      }
    }
    .width('100%')
    .height('100%');
  }


}
