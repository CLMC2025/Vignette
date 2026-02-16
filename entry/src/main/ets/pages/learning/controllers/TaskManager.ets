import { TaskItem, TaskType } from '../../../manager/SessionPlanner';
import { WordItem, WordDefinition } from '../../../model/WordModel';
import { DictionaryManager, LookupResult } from '../../../manager/DictionaryManager';
import { DBManager } from '../../../database/DBManager';
import { ReadStoryController } from './StoryController';
import { ReadContextController } from './ContextController';

export class ReadPageTaskManager {
  private dictManager: DictionaryManager;
  private dbManager: DBManager;
  private storyController: ReadStoryController | null = null;
  private contextController: ReadContextController | null = null;
  
  private contextSequence: string[] = [];
  private contextCursor: number = -1;
  private seenContextIds: Set<string> = new Set<string>();

  constructor(
    dictManager: DictionaryManager,
    dbManager: DBManager,
    storyController: ReadStoryController | null,
    contextController: ReadContextController | null
  ) {
    this.dictManager = dictManager;
    this.dbManager = dbManager;
    this.storyController = storyController;
    this.contextController = contextController;
  }
  
  public setControllers(storyController: ReadStoryController | null, contextController: ReadContextController | null): void {
      this.storyController = storyController;
      this.contextController = contextController;
  }
  
  public getContextSequence(): string[] {
    return this.contextSequence;
  }
  
  public getContextCursor(): number {
    return this.contextCursor;
  }
  
  public setContextSequence(seq: string[], cursor: number): void {
    this.contextSequence = seq;
    this.contextCursor = cursor;
  }
  
  public setSeenContextIds(ids: Set<string>): void {
    this.seenContextIds = ids;
  }
  
  public getContextIdForTask(task: TaskItem): string {
    return String(task.word.id);
  }

  public markTaskAsSeen(task: TaskItem): void {
    if (task.isReinforcement) {
      return;
    }
    const id = this.getContextIdForTask(task);
    if (!this.seenContextIds.has(id)) {
      this.seenContextIds.add(id);
      // Note: Persistence is handled by the caller or controller usually, 
      // but here we just update the set. 
      // ReadPage handles persistence via seenContextStore.save(this.seenContextIds)
    }
  }

  public filterOutSeenTasks(tasks: TaskItem[]): TaskItem[] {
    const filtered: TaskItem[] = [];
    for (const task of tasks) {
      if (task.isReinforcement) {
        filtered.push(task);
        continue;
      }
      const id = this.getContextIdForTask(task);
      if (!this.seenContextIds.has(id)) {
        filtered.push(task);
      }
    }
    return filtered;
  }
  
  public findNextUnseenTaskIndex(fromIndex: number, taskQueue: TaskItem[]): number {
    const start = Math.max(-1, fromIndex);
    for (let i = start + 1; i < taskQueue.length; i++) {
      const task = taskQueue[i];
      if (task.isReinforcement) {
        return i;
      }
      const id = this.getContextIdForTask(task);
      if (!this.seenContextIds.has(id)) {
        return i;
      }
    }
    return taskQueue.length;
  }
  
  public findTaskIndexByTaskId(taskId: string, taskQueue: TaskItem[]): number {
    for (let i = 0; i < taskQueue.length; i++) {
      if (taskQueue[i].id === taskId) {
        return i;
      }
    }
    return -1;
  }
  
  public initializeContextSequenceForFirstTask(taskQueue: TaskItem[]): void {
    if (taskQueue.length === 0) {
      this.contextSequence = [];
      this.contextCursor = -1;
      return;
    }
    const firstId = taskQueue[0].id;
    this.contextSequence = [firstId];
    this.contextCursor = 0;
  }
  
  public getNextTaskIdBySequenceOrQueue(currentTaskIndex: number, taskQueue: TaskItem[]): string | null {
    if (this.contextCursor >= 0 && this.contextCursor < this.contextSequence.length - 1) {
      const nextId = this.contextSequence[this.contextCursor + 1];
      const idx = this.findTaskIndexByTaskId(nextId, taskQueue);
      if (idx >= 0) {
        this.contextCursor += 1;
        return nextId;
      }
      // If nextId not found in queue (should not happen), truncate sequence
      this.contextSequence = this.contextSequence.slice(0, this.contextCursor + 1);
    }

    const nextIndex = this.findNextUnseenTaskIndex(currentTaskIndex, taskQueue);
    if (nextIndex >= taskQueue.length) {
      return null;
    }
    const nextId = taskQueue[nextIndex].id;
    this.contextSequence = [...this.contextSequence, nextId];
    this.contextCursor = this.contextSequence.length - 1;
    return nextId;
  }

  public async fetchSupportWords(word: WordItem): Promise<string[]> {
    try {
      const supports = await this.dbManager.getSupportWords(word.word, 3);
      return supports.map((w: WordItem) => w.word);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn('[ReadPageTaskManager] Failed to fetch support words:', message);
      return [];
    }
  }

  public async ensureDefinitionLoaded(word: WordItem): Promise<WordDefinition | null> {
    try {
      if (word.definition && word.definition.word.length > 0) return word.definition;

      const cached = await this.dbManager.getCachedDefinition(word.word.trim().toLowerCase());
      if (cached !== null) return cached;

      const res: LookupResult = await this.dictManager.lookup(word.word);
      if (res.success && res.definition !== null) {
        return res.definition;
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn('[ReadPageTaskManager] ensureDefinitionLoaded failed:', message);
    }
    return null;
  }
  
  public async prepareTaskContent(task: TaskItem, hasPreloadedStory: boolean, storyText: string, supportWords: string[]): Promise<void> {
    try {
      if (task.type === TaskType.STORY) {
        if (!hasPreloadedStory || storyText.trim().length === 0) {
          if (this.storyController) {
            await this.storyController.generateStory(task, task.word, supportWords, (t) => this.getContextIdForTask(t));
          }
        }
      }
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      console.error('[ReadPageTaskManager] Failed to prepare task content:', err.message);
      throw err;
    }
  }
  
  public async preloadNextTask(currentIndex: number, taskQueue: TaskItem[]): Promise<void> {
      const nextIndex = currentIndex + 1;
      if (nextIndex >= taskQueue.length) return;
      
      const nextTask = taskQueue[nextIndex];
      if (this.storyController?.hasPreloadedStory(nextTask.id)) return;
      
    if (this.storyController) {
      await this.storyController.preloadStoryForTask(
        nextTask,
        (t) => this.getContextIdForTask(t),
        (contextId: string, word: string, text: string): Promise<void> => {
          if (this.contextController) {
            return this.contextController.preGenerateContextDefinition(contextId, word, text);
          }
          return Promise.resolve();
        }
      );
    }
  }
}
