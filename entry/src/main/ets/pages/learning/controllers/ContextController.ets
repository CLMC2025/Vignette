import { ContextDefinitionStore, ContextDefinitionStatus, hashStoryText } from '../../../utils/ContextDefinitionStore';
import { DictionaryManager, LookupResult } from '../../../manager/DictionaryManager';
import { buildContextDefinitionText } from '../../../utils/ContextDefinitionTextBuilder';
import { buildTranslationText } from '../../../utils/TranslationTextBuilder';
import { WordDefinition, WordItem } from '../../../model/WordModel';
import { TaskItem } from '../../../manager/SessionPlanner';

export interface ReadContextDelegate {
  onDefinitionContentChange(content: string): void;
  onDefinitionLoadingChange(loading: boolean): void;
  onTranslationTextCacheChange(cache: string): void;
}

export class ReadContextController {
  private delegate: ReadContextDelegate;
  private ctxDefStore: ContextDefinitionStore;
  private dictManager: DictionaryManager;

  // State tracked by controller to avoid passing it every time
  private currentStoryHash: string = '';

  constructor(
    delegate: ReadContextDelegate,
    ctxDefStore: ContextDefinitionStore,
    dictManager: DictionaryManager
  ) {
    this.delegate = delegate;
    this.ctxDefStore = ctxDefStore;
    this.dictManager = dictManager;
  }

  public getCurrentStoryHash(): string {
    return this.currentStoryHash;
  }

  public setCurrentStoryHash(hash: string): void {
    this.currentStoryHash = hash;
  }

  public hasDefinitionMeaning(definition: WordDefinition): boolean {
    if (definition.contextMeaning.trim().length > 0) {
      return true;
    }
    for (let i = 0; i < definition.commonMeanings.length; i++) {
      if (definition.commonMeanings[i].cn.trim().length > 0) {
        return true;
      }
    }
    return false;
  }

  public rebuildTranslationTextCache(
    currentWord: WordItem | null,
    storyText: string,
    storyTranslation: string,
    definitionLoading: boolean
  ): void {
    if (currentWord === null) {
      this.delegate.onTranslationTextCacheChange('');
      return;
    }
    const cache = buildTranslationText({
      storyText: storyText,
      storyTranslation: storyTranslation,
      targetWord: currentWord.word,
      definition: currentWord.definition,
      definitionLoading: definitionLoading
    });
    this.delegate.onTranslationTextCacheChange(cache);
  }

  public onStoryReadyForContext(contextId: string, targetWord: string, storyText: string): void {
    if (contextId.length === 0 || storyText.length === 0 || targetWord.length === 0) {
      return;
    }
    const hash = hashStoryText(storyText);
    this.currentStoryHash = hash;
    void this.preGenerateContextDefinition(contextId, targetWord, storyText);
  }

  public async preGenerateContextDefinition(contextId: string, targetWord: string, storyText: string): Promise<void> {
    if (contextId.length === 0 || storyText.length === 0 || targetWord.length === 0) {
      return;
    }
    const hash = hashStoryText(storyText);
    const existing = await this.ctxDefStore.load(contextId, hash);
    if (existing !== null && existing.status === ContextDefinitionStatus.OK &&
      existing.definitionText.length > 0 && existing.formatVersion >= ContextDefinitionStore.FORMAT_VERSION) {
      return;
    }
    try {
      const results = await Promise.all([
        this.dictManager.lookup(targetWord, storyText),
        this.dictManager.translateStory(storyText)
      ]);
      const res = results[0] as LookupResult;
      const translation = results[1] as string;
      if (res.success && res.definition !== null) {
        const text = this.buildStoredDefinitionText(translation, targetWord, res.definition);
        await this.ctxDefStore.save(contextId, hash, {
          status: ContextDefinitionStatus.OK,
          definitionText: text,
          storyTranslation: translation,
          createdAt: Date.now(),
          formatVersion: ContextDefinitionStore.FORMAT_VERSION
        });
      } else {
        await this.ctxDefStore.save(contextId, hash, {
          status: ContextDefinitionStatus.FAILED,
          definitionText: '',
          storyTranslation: '',
          createdAt: Date.now(),
          formatVersion: ContextDefinitionStore.FORMAT_VERSION
        });
      }
    } catch (e) {
      await this.ctxDefStore.save(contextId, hash, {
        status: ContextDefinitionStatus.FAILED,
        definitionText: '',
        storyTranslation: '',
        createdAt: Date.now(),
        formatVersion: ContextDefinitionStore.FORMAT_VERSION
      });
    }
  }

  public syncDefinitionForCurrentContext(
    showTranslation: boolean,
    currentTask: TaskItem | null,
    currentWord: WordItem | null,
    storyText: string,
    getContextIdForTask: (task: TaskItem) => string
  ): void {
    if (!showTranslation) {
      return;
    }
    if (currentTask === null || currentWord === null) {
      this.delegate.onDefinitionContentChange('暂无释义');
      this.delegate.onDefinitionLoadingChange(false);
      return;
    }
    if (storyText.length === 0) {
      this.delegate.onDefinitionContentChange('暂无释义');
      this.delegate.onDefinitionLoadingChange(false);
      return;
    }

    const taskId = currentTask.id;
    const contextId = getContextIdForTask(currentTask);
    const storyHash = hashStoryText(storyText);
    this.currentStoryHash = storyHash;

    const cached = this.ctxDefStore.getCached(contextId, storyHash);
    if (cached !== null && cached.status === ContextDefinitionStatus.OK && cached.definitionText.length > 0) {
      this.delegate.onDefinitionContentChange(cached.definitionText);
      if (cached.formatVersion >= ContextDefinitionStore.FORMAT_VERSION) {
        this.delegate.onDefinitionLoadingChange(false);
        return;
      }
    }

    this.delegate.onDefinitionLoadingChange(true);
    void this.loadDefinitionFromStoreOrFallback(
      taskId,
      contextId,
      storyHash,
      currentWord.word,
      storyText,
      showTranslation,
      currentTask.id
    );
  }

  private async loadDefinitionFromStoreOrFallback(
    taskId: string,
    contextId: string,
    storyHash: string,
    targetWord: string,
    storyText: string,
    showTranslation: boolean,
    currentTaskId: string
  ): Promise<void> {
    try {
      const record = await this.ctxDefStore.load(contextId, storyHash);
      
      // Verification check to ensure we are still on the same task/context
      if (currentTaskId !== taskId || this.currentStoryHash !== storyHash || !showTranslation) {
        return;
      }

      if (record !== null && record.status === ContextDefinitionStatus.OK &&
        record.definitionText.length > 0 && record.formatVersion >= ContextDefinitionStore.FORMAT_VERSION) {
        this.delegate.onDefinitionContentChange(record.definitionText);
        this.delegate.onDefinitionLoadingChange(false);
        return;
      }
      
      if (record !== null && record.status === ContextDefinitionStatus.OK && record.definitionText.length > 0) {
        this.delegate.onDefinitionContentChange(record.definitionText);
      }

      // Fallback: Generate on the fly
      const results = await Promise.all([
        this.dictManager.lookup(targetWord, storyText),
        this.dictManager.translateStory(storyText)
      ]);
      
      // Re-check state
      if (currentTaskId !== taskId || this.currentStoryHash !== storyHash || !showTranslation) {
        return;
      }

      const res = results[0] as LookupResult;
      const translation = results[1] as string;

      if (res.success && res.definition !== null) {
        const text = this.buildStoredDefinitionText(translation, targetWord, res.definition);
        this.delegate.onDefinitionContentChange(text);
        
        await this.ctxDefStore.save(contextId, storyHash, {
          status: ContextDefinitionStatus.OK,
          definitionText: text,
          storyTranslation: translation,
          createdAt: Date.now(),
          formatVersion: ContextDefinitionStore.FORMAT_VERSION
        });
      } else {
        this.delegate.onDefinitionContentChange('暂无释义');
      }
    } catch (e) {
      console.warn('[ReadContextController] Failed to load definition:', e);
      if (currentTaskId === taskId && this.currentStoryHash === storyHash && showTranslation) {
         this.delegate.onDefinitionContentChange('加载失败');
      }
    } finally {
      if (currentTaskId === taskId && this.currentStoryHash === storyHash && showTranslation) {
        this.delegate.onDefinitionLoadingChange(false);
      }
    }
  }

  private buildStoredDefinitionText(storyTranslation: string, targetWord: string, definition: WordDefinition): string {
    return buildContextDefinitionText({
      storyTranslation,
      targetWord,
      definition
    });
  }
}
