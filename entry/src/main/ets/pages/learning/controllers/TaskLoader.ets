
import { TaskItem, TaskType } from '../../../manager/SessionPlanner';
import { WordItem, WordSnapshot, WordDefinition, LearningSession } from '../../../model/WordModel';
import { ReadPageSessionManager } from './SessionManager';
import { ReadPageTaskManager } from './TaskManager';
import { ReadStoryController } from './StoryController';
import { ReadContextController } from './ContextController';
import { StoryWord, PreloadedStory } from '../../ReadPageModels';

export interface TaskLoadResult {
  snapshot: WordSnapshot | null;
  supportWords: string[];
  hasPreloadedStory: boolean;
  storyText?: string;
  storyWords?: StoryWord[];
  storyError?: string;
  storySourceLabel?: string;
  definition: WordDefinition | null; // If loaded/updated
}

export interface TaskLoadCallbacks {
  onSnapshotError: (error: Error) => void;
  onDefinitionLoading: (loading: boolean) => void;
}

export class ReadPageLoader {
  
  private static async ensureDefinitionLoaded(
    word: WordItem,
    storyText: string,
    storyTranslation: string,
    taskManager: ReadPageTaskManager | null,
    contextController: ReadContextController | null,
    onLoading: (loading: boolean) => void
  ): Promise<WordDefinition | null> {
    try {
      const def = word.definition ?? new WordDefinition();
      const hasMeaning = contextController?.hasDefinitionMeaning(def) ?? false;

      if (hasMeaning) {
        return null;
      }

      const DEFINITION_TIMEOUT_MS = 8000;
      const timeoutPromise = new Promise<WordDefinition | null>((resolve) => {
        setTimeout((): void => resolve(null), DEFINITION_TIMEOUT_MS);
      });

      // We assume word IS current because this is called during task load
      onLoading(true);
      contextController?.rebuildTranslationTextCache(
        word,
        storyText,
        storyTranslation,
        true
      );

      let loadedDef: WordDefinition | null = null;
      try {
        if (taskManager) {
          loadedDef = await Promise.race([taskManager.ensureDefinitionLoaded(word), timeoutPromise]);
        }
      } finally {
         onLoading(false);
         contextController?.rebuildTranslationTextCache(
            word,
            storyText,
            storyTranslation,
            false
         );
      }
      return loadedDef;
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      console.warn('[ReadPageLoader] ensureDefinitionLoaded failed:', message);
      return null;
    }
  }

  static async loadTaskResources(
    task: TaskItem,
    sessionManager: ReadPageSessionManager,
    taskManager: ReadPageTaskManager | null,
    storyController: ReadStoryController | null,
    contextController: ReadContextController | null,
    session: LearningSession,
    storyTranslation: string,
    callbacks: TaskLoadCallbacks
  ): Promise<TaskLoadResult> {
    
    // 1. Snapshot
    let snapshot: WordSnapshot | null = null;
    try {
      snapshot = new WordSnapshot(task.word);
      session.createSnapshot(task.word);
    } catch (snapshotError) {
      const err = snapshotError instanceof Error ? snapshotError : new Error(String(snapshotError));
      callbacks.onSnapshotError(err);
    }

    // 2. Story setup
    let storyText = '';
    let storyWords: StoryWord[] = [];
    let storyError = '';
    let supportWords: string[] = [];
    let hasPreloadedStory = false;
    let storySourceLabel = '';

    if (storyController) {
        if (storyController.hasPreloadedStory(task.id)) {
            // Apply preloaded story. This triggers callbacks in ReadPage.
            // Ensure ReadPage currentWord is already set!
            storyController.applyPreloadedStory(task.id, task.word);
            hasPreloadedStory = true;
            // We don't get the text here directly, it comes via callback.
            // But we need to know if we have it.
        } else {
            // Cleared values are default
        }
    }

    if (hasPreloadedStory && taskManager && contextController) {
        // This relies on storyText being updated via callback in ReadPage.
        // But we don't have access to the updated storyText here yet if it's async?
        // ReadStoryController.applyPreloadedStory is synchronous in logic but might be async in effect?
        // Looking at code, it seems to call delegate immediately.
        
        // If we want to be safe, we might need to fetch it from controller if possible.
        // Or we rely on ReadPage handling the context ready event.
        
        // taskManager.getContextIdForTask is now public/accessible
        const ctxId = taskManager.getContextIdForTask(task);
        // contextController.onStoryReadyForContext is called via delegate
    }

    const loadPromises: Promise<void>[] = [];
    
    // 3. Definition loading
    let loadedDefinition: WordDefinition | null = null;
    loadPromises.push(
        ReadPageLoader.ensureDefinitionLoaded(
            task.word,
            storyText, // Note: This might be empty if preloaded!
            storyTranslation,
            taskManager,
            contextController,
            callbacks.onDefinitionLoading
        ).then(def => {
            loadedDefinition = def;
        })
    );
      
    // 4. Support words loading
    if (!hasPreloadedStory && taskManager) {
       loadPromises.push(taskManager.fetchSupportWords(task.word).then(words => {
           supportWords = words;
       }));
    }
    
    await Promise.all(loadPromises);
    
    // 5. Prepare task content (context sequence etc)
    if (taskManager) {
      // prepareTaskContent needs the *final* storyText. 
      // If we have preloaded story, storyText variable here is empty!
      // This is a problem. 
      
      // We need to get the story text.
      // Since we can't easily get it, maybe we should let ReadPage call prepareTaskContent?
      // Or we pass a callback "getStoryText()"
    }
    
    const result: TaskLoadResult = {
      snapshot,
      supportWords,
      hasPreloadedStory,
      definition: loadedDefinition
    };

    if (!hasPreloadedStory) {
       result.storyText = storyText;
       result.storyWords = storyWords;
       result.storyError = storyError;
       result.storySourceLabel = storySourceLabel;
    }

    return result;
  }
}
