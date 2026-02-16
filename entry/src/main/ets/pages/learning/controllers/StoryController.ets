import { StoryGenerationPipeline, StoryGenerationOutcome, StoryGenerationRequest, StorySource, StoryFastGenerationResult } from '../../../context/StoryGenerationPipeline';
import { DictionaryManager } from '../../../manager/DictionaryManager';
import { DBManager } from '../../../database/DBManager';
import { ContextValidator } from '../../../context/ContextValidator';
import { WordItem } from '../../../model/WordModel';
import { TaskItem, TaskType } from '../../../manager/SessionPlanner';
import { StoryWord, PreloadedStory } from '../../ReadPageModels';
import { ContextStyle, DifficultyLevel } from '../../../context/TemplateManager';
import { buildUserFacingError } from '../../../utils/ErrorClassifier';
import { hashStoryText } from '../../../utils/ContextDefinitionStore';

export interface WordCountRange {
  minWords: number;
  maxWords: number;
}

export interface ReadStoryDelegate {
  onStoryGenerated(text: string, error: string, sourceLabel: string): void;
  onStoryWordsParsed(words: StoryWord[]): void;
  onStoryTranslationGenerated(translation: string): void;
  onStoryLoading(hint: string): void;
  onStoryLoadingEnd(): void;
  canApplyStoryUpgrade(): boolean;
  onStoryUpgradeAvailable(text: string, error: string, sourceLabel: string): void;
  onPreloadedStoryApplied(text: string, error: string, sourceLabel: string, hasPreloaded: boolean): void;
  onStoryReadyForContext(contextId: string, word: string, text: string): void;
  onRebuildTranslationTextCache(): void;
}

export class ReadStoryController {
  private storyPipeline: StoryGenerationPipeline | null = null;
  private dictManager: DictionaryManager;
  private dbManager: DBManager;
  private contextValidator: ContextValidator | null = null;
  
  private preloadedStoryCache: Map<string, PreloadedStory> = new Map<string, PreloadedStory>();
  private preloadSeqCounter: number = 0;
  private preloadSeqByTaskId: Map<string, number> = new Map<string, number>();
  
  private vignettePrewarmStarted: boolean = false;
  private readonly VIGNETTE_PREWARM_LAST_MS_KEY: string = 'vignette_prewarm_last_ms';
  
  private cachedStoryText: string = '';
  private cachedStoryWords: StoryWord[] = [];
  
  private storyGenerationSeq: number = 0;
  
  private delegate: ReadStoryDelegate;

  // Settings
  public selectedContextStyle: ContextStyle = ContextStyle.RANDOM;
  public selectedDifficultyLevel: DifficultyLevel = DifficultyLevel.CET4;
  public newbieMode: boolean = true;
  public contextLengthMin: number = 40;
  public contextLengthMax: number = 80;

  constructor(
    storyPipeline: StoryGenerationPipeline | null,
    dictManager: DictionaryManager,
    dbManager: DBManager,
    contextValidator: ContextValidator | null,
    delegate: ReadStoryDelegate
  ) {
    this.storyPipeline = storyPipeline;
    this.dictManager = dictManager;
    this.dbManager = dbManager;
    this.contextValidator = contextValidator;
    this.delegate = delegate;
  }

  public applyStoryText(
    text: string,
    error: string,
    sourceLabel: string,
    currentTask: TaskItem | null,
    currentWord: WordItem,
    supportWords: string[],
    getContextIdForTask: (task: TaskItem) => string
  ): void {
    if (text.trim().length === 0) {
      return;
    }
    this.delegate.onStoryGenerated(text, error, sourceLabel);
    if (currentTask !== null) {
      this.delegate.onStoryReadyForContext(getContextIdForTask(currentTask), currentWord.word, text);
    }
    this.delegate.onRebuildTranslationTextCache();
    void this.generateStoryTranslation(text);
    this.parseStoryIntoWords(text, currentWord, supportWords);
  }
  
  public setPipeline(pipeline: StoryGenerationPipeline) {
    this.storyPipeline = pipeline;
  }
  
  public setContextValidator(validator: ContextValidator) {
    this.contextValidator = validator;
  }

  public clearCache() {
    this.preloadedStoryCache.clear();
    this.preloadSeqByTaskId.clear();
    this.preloadSeqCounter = 0;
    this.cachedStoryText = '';
    this.cachedStoryWords = [];
    this.storyGenerationSeq = 0;
  }

  public getPreloadedStory(taskId: string): PreloadedStory | undefined {
    return this.preloadedStoryCache.get(taskId);
  }

  public hasPreloadedStory(taskId: string): boolean {
    return this.preloadedStoryCache.has(taskId);
  }

  public restorePreloadedStory(taskId: string, story: PreloadedStory): void {
    this.preloadedStoryCache.set(taskId, story);
  }

  public getContextWordCountRange(word: WordItem): WordCountRange {
    if (this.newbieMode) {
      return { minWords: 50, maxWords: 70 } as WordCountRange;
    }
    if (this.contextLengthMin > 0 && this.contextLengthMax > 0) {
      return { minWords: this.contextLengthMin, maxWords: this.contextLengthMax } as WordCountRange;
    }
    const difficulty = word.fsrsState.difficulty;
    if (difficulty >= 6) {
      return { minWords: 100, maxWords: 180 } as WordCountRange;
    }
    return { minWords: 50, maxWords: 70 } as WordCountRange;
  }

  private getStorySourceLabel(source: StorySource): string {
    switch (source) {
      case StorySource.AI:
        return 'AI生成';
      case StorySource.CACHE:
        return 'AI缓存';
      case StorySource.OFFLINE:
        return '离线模板';
      case StorySource.MINIMAL:
        return '最小兜底';
      default:
        return 'AI生成';
    }
  }

  public async generateStory(
    currentTask: TaskItem | null, 
    currentWord: WordItem, 
    supportWords: string[],
    getContextIdForTask: (task: TaskItem) => string
  ): Promise<void> {
    this.storyGenerationSeq += 1;
    const seq = this.storyGenerationSeq;
    
    const target = currentWord.word;
    const range = this.getContextWordCountRange(currentWord);

    const STORY_GENERATION_TIMEOUT_MS = 15000;
    const timeoutPromise = new Promise<StoryGenerationOutcome>((_, reject) => {
      setTimeout((): void => reject(new Error('Story generation timeout')), STORY_GENERATION_TIMEOUT_MS);
    });

    try {
      console.log('[ReadStoryController] Generating story for word:', target);
      
      this.dictManager.setContextPreferences(
        this.selectedContextStyle,
        this.selectedDifficultyLevel
      );

      const pipeline = this.storyPipeline;
      if (pipeline === null) {
        const fallbackStory = `After class, I had to ${target}. It felt simple and easy to remember.`;
        const error = '语境生成器未初始化，已使用最小兜底。';
        this.delegate.onStoryGenerated(fallbackStory, error, '最小兜底');
        if (currentTask !== null) {
          this.delegate.onStoryReadyForContext(getContextIdForTask(currentTask), currentWord.word, fallbackStory);
        }
        this.delegate.onRebuildTranslationTextCache();
        this.parseStoryIntoWords(fallbackStory, currentWord);
        return;
      }

      const request: StoryGenerationRequest = {
        targetWord: target,
        supportWords: supportWords,
        minWords: range.minWords,
        maxWords: range.maxWords,
        minTargetOccurrences: 2,
        maxTargetOccurrences: 3,
        style: this.selectedContextStyle,
        difficulty: this.selectedDifficultyLevel
      };

      const taskId = currentTask?.id ?? '';
      const wordAtStart = currentWord.word;

      const fastResult: StoryFastGenerationResult = await pipeline.generateFastFirst(request);
      const initialOutcome = fastResult.initial;

      if (this.storyGenerationSeq !== seq) {
        return;
      }
      if (currentTask !== null && (currentTask.id !== taskId || currentWord.word !== wordAtStart)) {
        return;
      }
      if (initialOutcome.story.trim().length === 0) {
        return;
      }

      const initialSourceLabel = this.getStorySourceLabel(initialOutcome.source);

      this.applyStoryText(
        initialOutcome.story,
        initialOutcome.warningMessage,
        initialSourceLabel,
        currentTask,
        currentWord,
        supportWords,
        getContextIdForTask
      );

      const upgradePromise = fastResult.upgradePromise;
      if (upgradePromise !== null) {
        void (async (): Promise<void> => {
          try {
            const upgraded = await Promise.race([upgradePromise, timeoutPromise]) as StoryGenerationOutcome;
            if (this.storyGenerationSeq !== seq) {
              return;
            }
            if (currentTask !== null && (currentTask.id !== taskId || currentWord.word !== wordAtStart)) {
              return;
            }
            if (upgraded.story.trim().length === 0) {
              return;
            }

            let warningText = upgraded.warningMessage;
            if (this.contextValidator) {
              const validation = this.contextValidator.validate(
                upgraded.story,
                target,
                this.selectedDifficultyLevel,
                range.minWords,
                range.maxWords,
                2,
                3
              );

              if (!validation.isValid) {
                const summary = validation.getSummary();
                warningText = summary.length > 0 ? `提示：${summary}` : warningText;
              }
            }

            const sourceLabel = this.getStorySourceLabel(upgraded.source);

            if (this.delegate.canApplyStoryUpgrade()) {
              this.applyStoryText(
                upgraded.story,
                warningText,
                sourceLabel,
                currentTask,
                currentWord,
                supportWords,
                getContextIdForTask
              );
              return;
            }
            this.delegate.onStoryUpgradeAvailable(upgraded.story, warningText, sourceLabel);
          } catch (_) {}
        })();
      }
      return;
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[ReadStoryController] Exception occurred during story generation:', errorMsg);

      const info = buildUserFacingError(errorMsg);
      const fallbackStory = `After class, I had to ${target}. It felt simple and easy to remember.`;
      
      this.delegate.onStoryGenerated(fallbackStory, info.userMessage, '最小兜底');
      
      if (currentTask !== null) {
        this.delegate.onStoryReadyForContext(getContextIdForTask(currentTask), currentWord.word, fallbackStory);
      }
      this.delegate.onRebuildTranslationTextCache();
      this.parseStoryIntoWords(fallbackStory, currentWord);
    } finally {
      this.delegate.onStoryLoadingEnd();
      console.log('[ReadStoryController] Story generation process completed');
    }
  }

  private async generateStoryTranslation(story: string): Promise<void> {
    if (story.length === 0) {
      this.delegate.onStoryTranslationGenerated('');
      this.delegate.onRebuildTranslationTextCache();
      return;
    }

    try {
      console.log('[ReadStoryController] Generating story translation...');
      const translation = await this.dictManager.translateStory(story);
      this.delegate.onStoryTranslationGenerated(translation);
      this.delegate.onRebuildTranslationTextCache();
      console.log('[ReadStoryController] Story translation completed');
    } catch (error) {
      console.error('[ReadStoryController] Failed to generate story translation:', error);
      this.delegate.onStoryTranslationGenerated('');
      this.delegate.onRebuildTranslationTextCache();
    }
  }

  public parseStoryIntoWords(storyText: string, currentWord: WordItem, supportWords: string[] = []): void {
    const startTime = Date.now();

    if (storyText === this.cachedStoryText && this.cachedStoryWords.length > 0) {
      const currentTarget = currentWord.word?.toLowerCase() ?? '';
      const hasTargetWord = this.cachedStoryWords.some(word =>
        word.word.toLowerCase() === currentTarget && word.isTarget
      );

      if (hasTargetWord || currentTarget.length === 0) {
        this.delegate.onStoryWordsParsed(this.cachedStoryWords);
        console.log(`[Perf] parseStoryIntoWords skipped (cached), ${this.cachedStoryWords.length} words`);
        return;
      }
    }

    const targetWord = currentWord.word ?? '';
    const words = this.parseStoryIntoWordsForText(storyText, targetWord, supportWords);

    this.cachedStoryText = storyText;
    this.cachedStoryWords = words;
    this.delegate.onStoryWordsParsed(words);

    console.log(`[Perf] parseStoryIntoWords took ${Date.now() - startTime}ms, parsed ${words.length} words`);
  }

  public parseStoryIntoWordsForText(text: string, targetWord: string, supportWords: string[]): StoryWord[] {
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

    return words;
  }
  
  public applyPreloadedStory(taskId: string, currentWord: WordItem): void {
    const cached = this.preloadedStoryCache.get(taskId);
    if (!cached) {
      this.delegate.onPreloadedStoryApplied('', '', '', false);
      return;
    }
    const target = currentWord.word ?? '';
    if (target.length === 0 || cached.targetWord !== target) {
      this.delegate.onPreloadedStoryApplied('', '', '', false);
      return;
    }

    const label = cached.sourceLabel.length > 0 ? `${cached.sourceLabel}（预加载）` : '预加载';
    this.delegate.onPreloadedStoryApplied(cached.text, cached.error, label, true);
    this.cachedStoryText = '';
    this.cachedStoryWords = [];
    this.parseStoryIntoWords(cached.text, currentWord, cached.supportWords);
    this.delegate.onStoryLoadingEnd();
  }

  public async preloadStoryForTask(
    task: TaskItem, 
    getContextIdForTask: (task: TaskItem) => string,
    preGenerateContextDefinition: (contextId: string, word: string, text: string) => Promise<void>
  ): Promise<void> {
    this.preloadSeqCounter += 1;
    const preloadSeq = this.preloadSeqCounter;
    this.preloadSeqByTaskId.set(task.id, preloadSeq);

    const word = task.word;
    let supportWords: string[] = [];
    try {
      const supports = await this.dbManager.getSupportWords(word.word, 3);
      supportWords = supports.map((item: WordItem): string => item.word);
    } catch (error) {
      supportWords = [];
    }

    const range = this.getContextWordCountRange(word);
    let outcome: StoryGenerationOutcome;
    let upgradePromise: Promise<StoryGenerationOutcome> | null = null;
    
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
      const request: StoryGenerationRequest = {
        targetWord: word.word,
        supportWords: supportWords,
        minWords: range.minWords,
        maxWords: range.maxWords,
        minTargetOccurrences: 2,
        maxTargetOccurrences: 3,
        style: this.selectedContextStyle,
        difficulty: this.selectedDifficultyLevel
      };
      const fast: StoryFastGenerationResult = await this.storyPipeline.generateFastFirst(request);
      outcome = fast.initial;
      upgradePromise = this.dictManager.isConfigured() ? fast.upgradePromise : null;
    }

    const storyWords = this.parseStoryIntoWordsForText(outcome.story, word.word, supportWords);
    this.preloadedStoryCache.set(task.id, {
      targetWord: word.word,
      text: outcome.story,
      words: storyWords,
      error: outcome.warningMessage,
      supportWords: supportWords,
      sourceLabel: this.getStorySourceLabel(outcome.source)
    });
    void preGenerateContextDefinition(getContextIdForTask(task), word.word, outcome.story);

    if (upgradePromise !== null) {
      const taskId = task.id;
      const wordAtStart = word.word;
      const seqAtStart = preloadSeq;
      void (async (): Promise<void> => {
        try {
          const upgraded = await upgradePromise!;
          if (upgraded.story.trim().length === 0) {
            return;
          }
          const currentSeq = this.preloadSeqByTaskId.get(taskId) ?? -1;
          if (currentSeq !== seqAtStart) {
            return;
          }
          const cached = this.preloadedStoryCache.get(taskId);
          if (cached === undefined) {
            return;
          }
          if (wordAtStart !== word.word) {
            return;
          }
          const upgradedWords = this.parseStoryIntoWordsForText(upgraded.story, wordAtStart, supportWords);
          this.preloadedStoryCache.set(taskId, {
            targetWord: wordAtStart,
            text: upgraded.story,
            words: upgradedWords,
            error: upgraded.warningMessage,
            supportWords: supportWords,
            sourceLabel: this.getStorySourceLabel(upgraded.source)
          });
          void preGenerateContextDefinition(getContextIdForTask(task), wordAtStart, upgraded.story);
        } catch (e) {
          return;
        }
      })();
    }
  }

  public maybeStartVignettePrewarm(taskQueue: TaskItem[], taskIndex: number): void {
    if (this.vignettePrewarmStarted) {
      return;
    }
    if (!this.dictManager.isConfigured()) {
      return;
    }
    const now = Date.now();
    const lastRaw = AppStorage.get<string>(this.VIGNETTE_PREWARM_LAST_MS_KEY) ?? '0';
    const last = Number(lastRaw);
    const lastMs = Number.isFinite(last) ? last : 0;
    const cooldownMs = 6 * 60 * 60 * 1000;
    if (now - lastMs < cooldownMs) {
      return;
    }
    this.vignettePrewarmStarted = true;
    AppStorage.setOrCreate(this.VIGNETTE_PREWARM_LAST_MS_KEY, String(now));
    setTimeout(() => {
      void this.prewarmUpcomingVignettes(taskQueue, taskIndex);
    }, 0);
  }

  private async delayMs(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  private async prewarmUpcomingVignettes(taskQueue: TaskItem[], taskIndex: number): Promise<void> {
    if (!this.dictManager.isConfigured()) {
      return;
    }
    if (taskQueue.length === 0) {
      return;
    }
    // DB is assumed ready if we are here
    
    this.dictManager.setContextPreferences(
      this.selectedContextStyle,
      this.selectedDifficultyLevel
    );

    const unique: Set<string> = new Set<string>();
    const upcoming: WordItem[] = [];
    for (let i = taskIndex; i < taskQueue.length && upcoming.length < 8; i++) {
      const t = taskQueue[i];
      if (t.type !== TaskType.STORY) {
        continue;
      }
      const w = t.word.word.trim().toLowerCase();
      if (w.length === 0 || unique.has(w)) {
        continue;
      }
      unique.add(w);
      upcoming.push(t.word);
    }

    for (let i = 0; i < upcoming.length; i++) {
      const wordItem = upcoming[i];
      let supportWords: string[] = [];
      try {
        const supports = await this.dbManager.getSupportWords(wordItem.word, 3);
        supportWords = supports.map((it: WordItem): string => it.word);
      } catch (e) {
        supportWords = [];
      }
      const range = this.getContextWordCountRange(wordItem);
      try {
        await this.dictManager.warmVignetteVariants(
          wordItem.word,
          supportWords,
          1,
          range.minWords,
          range.maxWords,
          2,
          3,
          this.selectedContextStyle,
          this.selectedDifficultyLevel
        );
      } catch (e) {
      }
      await this.delayMs(160);
    }
  }
}
