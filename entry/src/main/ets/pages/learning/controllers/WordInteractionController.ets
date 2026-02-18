import promptAction from '@ohos.promptAction';
import { DBManager, AddToUserWordBookOutcome, UserWordBookBrief } from '../../../database/DBManager';
import { DictionaryManager, LookupResult } from '../../../manager/DictionaryManager';
import { WordItem, WordStatus, WordDefinition, LearningSession } from '../../../model/WordModel';
import { StoryWord, DialogState } from '../../ReadPageModels';
import { addNotebookWord, removeNotebookWord } from '../../../utils/NotebookWordSet';
import { TopBannerType } from '../../../ui/TopBanner';
import { ContextWordMeaningStore } from '../../../utils/ContextWordMeaningStore';
import { hashStoryText } from '../../../utils/ContextDefinitionStore';
import { UserStateManager, UserWordState } from '../../../manager/UserStateManager';
import { validateUserWordBookName } from '../../../utils/UserWordBookNameValidator';

export interface ReadWordInteractionDelegate {
  onDialogStateChange(state: DialogState): void;
  onNotebookWordsChange(words: Set<string>): void;
  onMeaningExpandedChange(expanded: boolean): void;
  onJoinedBooksChange(ids: string[], count: number): void;
  onShowToast(message: string): void;
  onShowBanner(type: TopBannerType, message: string, duration?: number): void;
}

export class ReadWordInteractionController {
  private delegate: ReadWordInteractionDelegate;
  private dbManager: DBManager;
  private dictManager: DictionaryManager;
  private ctxWordMeaningStore: ContextWordMeaningStore;
  private dialogRequestToken: number = 0;

  constructor(
    delegate: ReadWordInteractionDelegate,
    dbManager: DBManager,
    dictManager: DictionaryManager,
    ctxWordMeaningStore: ContextWordMeaningStore
  ) {
    this.delegate = delegate;
    this.dbManager = dbManager;
    this.dictManager = dictManager;
    this.ctxWordMeaningStore = ctxWordMeaningStore;
  }

  /**
   * Handle word click in story
   */
  public async onWordClick(
    storyWord: StoryWord,
    getState: () => DialogState,
    notebookWords: Set<string>,
    currentWord: WordItem | null,
    session: LearningSession | null,
    storyText: string,
    currentStoryHash: string,
    ensureSettingsLoaded: () => Promise<void>
  ): Promise<void> {
    const startTime = Date.now();
    console.log('[Perf] onWordClick started');

    if (storyWord.isPunctuation) {
      return;
    }

    const word = storyWord.word.toLowerCase().replace(/[^a-zA-Z]/g, '');
    if (word.length === 0) {
      return;
    }

    const requestWord = word;
    const requestToken = ++this.dialogRequestToken;

    const currentState = getState();
    if (currentState.isVisible && currentState.word === requestWord && currentState.definition !== null) {
      return;
    }

    const cachedBaseDefinition = this.dictManager.peekDefinition(word);

    const base = new DialogState();
    base.isVisible = true;
    this.delegate.onJoinedBooksChange([], 0);
    base.word = word;
    base.isLoading = false;
    base.inNotebook = notebookWords.has(this.normalizeNotebookWord(word));
    base.definition = cachedBaseDefinition;
    
    this.delegate.onDialogStateChange(base);
    void this.refreshJoinedBooksForDialog(word);

    // Check if this word is in our database
    try {
      const wordItem = await this.dbManager.getWordByWord(word);
      if (requestToken !== this.dialogRequestToken) {
        return;
      }

      if (wordItem !== null) {
        const latest = getState();
        const next = this.cloneDialogState(latest);
        next.wordItem = wordItem;
        next.canUndo = wordItem.history.getReviewCount() > 0;
        this.delegate.onDialogStateChange(next);
        this.delegate.onMeaningExpandedChange(wordItem.status === WordStatus.NEW);

        // Create snapshot for this word if not current target
        if (currentWord !== null && wordItem.id !== currentWord.id && session) {
          session.createSnapshot(wordItem);
        }
      } else {
        this.delegate.onMeaningExpandedChange(true);
      }
    } catch (error) {
      console.warn('[ReadWordInteractionController] Failed to lookup word in DB:', error);
      this.delegate.onMeaningExpandedChange(true);
    }

    // Lookup definition
    let loadingTimer: number | null = null;
    let finalDefinition: WordDefinition | null = null;

    try {
      let baseDef: WordDefinition = cachedBaseDefinition ?? new WordDefinition(
        word, '', '', 'Definition not found', [], 'local'
      );

      if (cachedBaseDefinition === null) {
        loadingTimer = setTimeout(() => {
          if (requestToken !== this.dialogRequestToken) return;
          const latest = getState();
          if (latest.definition !== null) return;

          const next = this.cloneDialogState(latest);
          next.isLoading = true;
          this.delegate.onDialogStateChange(next);
        }, 250);

        const result: LookupResult = await this.dictManager.lookup(word, '');
        if (requestToken !== this.dialogRequestToken) return;
        
        if (result.success && result.definition !== null) {
          baseDef = result.definition;
        }
      }
      
      if (requestToken !== this.dialogRequestToken) return;

      {
        const latest = getState();
        const next = this.cloneDialogState(latest);
        next.definition = baseDef;
        next.isLoading = false;
        this.delegate.onDialogStateChange(next);
      }

      const storyHash = currentStoryHash.length > 0 ? currentStoryHash : hashStoryText(storyText);
      const key = this.ctxWordMeaningStore.buildKey(word, storyHash);
      const cachedMeaning = await this.ctxWordMeaningStore.getContextMeaning(key);
      
      if (requestToken !== this.dialogRequestToken) return;

      let merged = WordDefinition.fromJSON(baseDef.toJSON());
      if (cachedMeaning.length > 0) {
        merged.contextMeaning = cachedMeaning;
      } else if (storyText.trim().length > 0) {
        await ensureSettingsLoaded();
        if (requestToken !== this.dialogRequestToken) return;
        
        if (this.dictManager.isConfigured()) {
          const generatedMeaning = await this.dictManager.lookupContextMeaning(word, storyText);
          if (requestToken !== this.dialogRequestToken) return;
          
          if (generatedMeaning.length > 0) {
            merged.contextMeaning = generatedMeaning;
            void this.ctxWordMeaningStore.setContextMeaning(key, generatedMeaning);
          }
        }
      }
      finalDefinition = merged;
      {
        const latest = getState();
        const next = this.cloneDialogState(latest);
        next.definition = finalDefinition;
        next.isLoading = false;
        this.delegate.onDialogStateChange(next);
      }

    } catch (error) {
      if (requestToken !== this.dialogRequestToken) return;
      console.warn('[ReadWordInteractionController] Failed to load definition:', error);
      
      finalDefinition = new WordDefinition(
        word, '', '', 'Failed to load definition', [], 'local'
      );
    } finally {
      if (loadingTimer !== null) {
        clearTimeout(loadingTimer);
      }
      
      if (requestToken === this.dialogRequestToken && finalDefinition !== null) {
        const latest = getState();
        const next = this.cloneDialogState(latest);
        next.definition = finalDefinition;
        next.isLoading = false;
        this.delegate.onDialogStateChange(next);
      }

      if (requestToken === this.dialogRequestToken) {
        const latest = getState();
        if (latest.wordItem !== null && latest.wordItem.status === WordStatus.NEW) {
          try {
            const updated = latest.wordItem.clone();
            updated.status = WordStatus.LEARNING;
            updated.dueDate = Date.now();
            updated.updatedAt = Date.now();
            await this.dbManager.updateWord(updated);
            if (requestToken !== this.dialogRequestToken) return;
            const after = getState();
            const next = this.cloneDialogState(after);
            next.wordItem = updated;
            this.delegate.onDialogStateChange(next);
          } catch (_) { /* 更新单词失败（可能竞态），忽略 */ }
        }
      }
      console.log(`[Perf] onWordClick took ${Date.now() - startTime}ms`);
    }
  }

  /**
   * Add word to notebook (for new words)
   */
  public async addToNotebookSafe(
    getState: () => DialogState,
    notebookWords: Set<string>
  ): Promise<void> {
    const currentState = getState();
    const word = this.normalizeNotebookWord(currentState.word);
    if (word.length === 0) return;
    if (currentState.notebookBusy || currentState.inNotebook) return;

    {
      const next = this.cloneDialogState(currentState);
      next.notebookBusy = true;
      next.notebookError = '';
      next.inNotebook = true;
      this.delegate.onDialogStateChange(next);
    }

    const newSet = addNotebookWord(notebookWords, word);
    this.delegate.onNotebookWordsChange(newSet);

    try {
      await this.dbManager.addWordToNotebook(word);
      this.delegate.onShowToast('已收藏');
      
      const latest = getState();
      const next = this.cloneDialogState(latest);
      next.notebookBusy = false;
      next.inNotebook = true; 
      this.delegate.onDialogStateChange(next);

    } catch (error) {
      console.error('[ReadWordInteractionController] Failed to add word:', error);
      const revertedSet = removeNotebookWord(newSet, word);
      this.delegate.onNotebookWordsChange(revertedSet);

      const latest = getState();
      const next = this.cloneDialogState(latest);
      next.inNotebook = false;
      next.notebookError = '添加失败';
      next.notebookBusy = false;
      this.delegate.onDialogStateChange(next);
      
      this.delegate.onShowBanner(TopBannerType.ERROR, '添加失败，请稍后再试。', 2000);
    }
  }

  public async removeFromNotebookSafe(
    getState: () => DialogState,
    notebookWords: Set<string>
  ): Promise<void> {
    const currentState = getState();
    const word = this.normalizeNotebookWord(currentState.word);
    if (word.length === 0) return;
    if (currentState.notebookBusy || !currentState.inNotebook) return;

    {
      const next = this.cloneDialogState(currentState);
      next.notebookBusy = true;
      next.notebookError = '';
      next.inNotebook = false;
      this.delegate.onDialogStateChange(next);
    }

    const newSet = removeNotebookWord(notebookWords, word);
    this.delegate.onNotebookWordsChange(newSet);

    try {
      await this.dbManager.removeWordFromNotebook(word);
      this.delegate.onShowToast('已取消收藏');
      
      const latest = getState();
      const next = this.cloneDialogState(latest);
      next.notebookBusy = false;
      next.inNotebook = false;
      this.delegate.onDialogStateChange(next);

    } catch (error) {
      console.error('[ReadWordInteractionController] Failed to remove word:', error);
      const revertedSet = addNotebookWord(newSet, word);
      this.delegate.onNotebookWordsChange(revertedSet);

      const latest = getState();
      const next = this.cloneDialogState(latest);
      next.inNotebook = true;
      next.notebookError = '移除失败';
      next.notebookBusy = false;
      this.delegate.onDialogStateChange(next);

      this.delegate.onShowBanner(TopBannerType.ERROR, '移除失败，请稍后再试。', 2000);
    }
  }

  public async joinWordToBook(word: string, bookId: string, bookName: string, isJoined: boolean): Promise<void> {
    try {
      const userStateManager = UserStateManager.getInstance();
      if (isJoined) {
        await this.dbManager.removeWordFromUserWordBook(bookId, word);
        this.delegate.onShowToast(`已从“${bookName}”移除`);
      } else {
        const outcome = await this.dbManager.addWordToUserWordBook(bookId, word);
        userStateManager.updateWordState(word, UserWordState.ADDED, bookId);
        if (outcome === AddToUserWordBookOutcome.Already) {
          this.delegate.onShowToast(`已加入“${bookName}”`);
        } else {
          this.delegate.onShowToast(`已成功加入“${bookName}”`);
        }
      }
      await this.refreshJoinedBooksForDialog(word);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      this.delegate.onShowBanner(TopBannerType.ERROR, `操作失败：${errMsg}`, 2000);
    }
  }

  public async createBookAndJoin(word: string, name: string): Promise<void> {
    const normalized = name.trim();
    const err = validateUserWordBookName(normalized);
    if (err.length > 0) {
      this.delegate.onShowToast(err);
      return;
    }

    try {
      const bookId = await this.dbManager.createUserWordBook(normalized);
      const outcome = await this.dbManager.addWordToUserWordBook(bookId, word);
      
      const userStateManager = UserStateManager.getInstance();
      userStateManager.updateWordState(word, UserWordState.ADDED, bookId);

      if (outcome === AddToUserWordBookOutcome.Already) {
        this.delegate.onShowToast(`已加入“${normalized}”`);
      } else {
        this.delegate.onShowToast(`已成功加入“${normalized}”`);
      }
      await this.refreshJoinedBooksForDialog(word);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      this.delegate.onShowBanner(TopBannerType.ERROR, `创建或加入失败：${errMsg}`, 2000);
    }
  }

  public async refreshJoinedBooksForDialog(word: string): Promise<void> {
    const normalized = word.trim().toLowerCase();
    if (normalized.length === 0) {
      this.delegate.onJoinedBooksChange([], 0);
      return;
    }
    try {
      const briefList = await this.dbManager.getUserWordBooksContainingWord(normalized);
      const ids = briefList.map((b: UserWordBookBrief) => b.id);
      this.delegate.onJoinedBooksChange(ids, briefList.length);
    } catch (error) {
      console.error('[ReadWordInteractionController] Failed to refresh joined books:', JSON.stringify(error));
      this.delegate.onJoinedBooksChange([], 0);
    }
  }

  private normalizeNotebookWord(word: string): string {
    return word.trim().toLowerCase();
  }

  private cloneDialogState(state: DialogState): DialogState {
    const next = new DialogState();
    next.isVisible = state.isVisible;
    next.word = state.word;
    next.definition = state.definition;
    next.isLoading = state.isLoading;
    next.wordItem = state.wordItem;
    next.hasBeenReviewed = state.hasBeenReviewed;
    next.canUndo = state.canUndo;
    next.inNotebook = state.inNotebook;
    next.notebookBusy = state.notebookBusy;
    next.notebookError = state.notebookError;
    return next;
  }
}
