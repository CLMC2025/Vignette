// =====================================================
// DataSyncManager.ets - 数据同步管理器
// 统一管理数据导出、导入和同步操作
// =====================================================

import { VersionControl, ChangeType } from './VersionControl';
import { DataExportImport, ExportData, SyncResult, ExportedWord, ExportedDefinition, ExportedUserBook, ExportedUserBookInput } from './DataExportImport';
import { DBManager, UserWordBook, NotebookWordEntry, ReviewEventRow, DailyActivity } from '../database/DBManager';
import { TextRow } from '../database/repositories/TextRepository';
import { WordItem, WordDefinition, WordStatus, FSRSState, ReviewHistory, UserActions, normalizeWordStatus } from '../model/WordModel';
import { FsrsParamsPack } from '../model/FsrsParamsPack';
import { SettingsStore } from '../utils/SettingsStore';
import { FSRSAlgorithm } from '../algorithm/Algorithm';
import { util } from '@kit.ArkTS';


/**
 * 导出操作状态（修复：定义缺失的 ExportResult 类型）
 */
export interface ExportResult {
  success: boolean;
  data: string;  // JSON字符串
  error: string;
}

/**
 * 同步状态
 */
export enum SyncStatus {
  IDLE = 'IDLE',
  EXPORTING = 'EXPORTING',
  IMPORTING = 'IMPORTING',
  SYNCING = 'SYNCING',
  ERROR = 'ERROR'
}

/**
 * 同步配置
 */
export class SyncConfig {
  autoBackup: boolean;
  backupInterval: number; // 毫秒
  maxBackupCount: number;
  enableCompression: boolean;

  constructor(
    autoBackup: boolean = true,
    backupInterval: number = 24 * 60 * 60 * 1000, // 24小时
    maxBackupCount: number = 5,
    enableCompression: boolean = false
  ) {
    this.autoBackup = autoBackup;
    this.backupInterval = backupInterval;
    this.maxBackupCount = maxBackupCount;
    this.enableCompression = enableCompression;
  }
}

/**
 * 备份信息
 */
export class BackupInfo {
  fileName: string;
  timestamp: number;
  size: number;
  wordCount: number;

  constructor(fileName: string, timestamp: number, size: number, wordCount: number) {
    this.fileName = fileName;
    this.timestamp = timestamp;
    this.size = size;
    this.wordCount = wordCount;
  }
}

export class ImportPreview {
  imported: number;
  updated: number;
  total: number;
  errors: string[];
  sampleUpdatedWords: string[];
  notebookCount: number;
  textsCount: number;
  reviewEventsCount: number;

  constructor() {
    this.imported = 0;
    this.updated = 0;
    this.total = 0;
    this.errors = [];
    this.sampleUpdatedWords = [];
    this.notebookCount = 0;
    this.textsCount = 0;
    this.reviewEventsCount = 0;
  }
}

/**
 * 数据同步管理器
 */
export class DataSyncManager {
  private static instance: DataSyncManager | null = null;
  private versionControl: VersionControl;
  private exportImport: DataExportImport;
  private dbManager: DBManager;
  private syncStatus: SyncStatus = SyncStatus.IDLE;
  private syncConfig: SyncConfig;
  private backups: BackupInfo[] = [];

  private constructor() {
    this.versionControl = new VersionControl();
    this.exportImport = new DataExportImport();
    this.dbManager = DBManager.getInstance();
    this.syncConfig = new SyncConfig();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): DataSyncManager {
    if (DataSyncManager.instance === null) {
      DataSyncManager.instance = new DataSyncManager();
    }
    return DataSyncManager.instance;
  }

  /**
   * 获取同步状态
   */
  getSyncStatus(): SyncStatus {
    return this.syncStatus;
  }

  /**
   * 获取版本控制
   */
  getVersionControl(): VersionControl {
    return this.versionControl;
  }

  /**
   * 获取同步配置
   */
  getSyncConfig(): SyncConfig {
    return this.syncConfig;
  }

  /**
   * 设置同步配置
   */
  setSyncConfig(config: SyncConfig): void {
    this.syncConfig = config;
  }

  // 实现缺失的方法
  getLastBackupTime(): number {
    // 查找最新备份时间
    if (this.backups.length === 0) {
      return 0; // 表示从未备份
    }
    
    let latestTime = 0;
    for (const backup of this.backups) {
      if (backup.timestamp > latestTime) {
        latestTime = backup.timestamp;
      }
    }
    return latestTime;
  }

  async saveBackup(fileName: string, data: string): Promise<boolean> {
    try {
      // 实际存储逻辑取决于存储机制，这里简化处理
      // 假设有底层API用于持久化保存
      console.info(`[DataSyncManager] Saving backup to ${fileName}`);
      
      // 保存备份信息到本地管理
      const textEncoder = new util.TextEncoder();
      const encodedBytes = textEncoder.encode(data);
      const size = encodedBytes.byteLength;
      const wordCount = 0; // 这里可能需要解析data来获取单词数量，暂时为0
      const backupInfo = new BackupInfo(fileName, Date.now(), size, wordCount);
      this.backups.push(backupInfo);
      
      return true;
    } catch (e) {
      console.error('[DataSyncManager] Failed to save backup:', e);
      return false;
    }
  }

  async cleanOldBackups(): Promise<boolean> {
    try {
      if (this.backups.length <= this.syncConfig.maxBackupCount) {
        return true; // 没有超过限制，无需清理
      }

      // 按时间排序并保留最新的最大备份数
      this.backups.sort((a, b) => b.timestamp - a.timestamp);
      const toRemove = this.backups.slice(this.syncConfig.maxBackupCount);
      
      // 移除超出数量限制的备份
      this.backups = this.backups.slice(0, this.syncConfig.maxBackupCount);
      
      // 这里实际的删除逻辑需要对应底层存储API
      console.info(`[DataSyncManager] Removed ${toRemove.length} old backups`);
      
      return true;
    } catch (e) {
      console.error('[DataSyncManager] Failed to clean old backups:', e);
      return false;
    }
  }

  /**
   * 导出数据
   */
  async exportData(): Promise<ExportResult> {
    try {
      const totalWords = await this.dbManager.getWordCount();
      console.info(`[DataSyncManager] Exporting ${totalWords} words in batches`);

      const batchSize = 500;
      const words: WordItem[] = [];

      for (let offset = 0; offset < totalWords; offset += batchSize) {
        const batch = await this.dbManager.getWordsPaged(batchSize, offset);
        words.push(...batch);

        if (offset % 1000 === 0) {
          console.info(`[DataSyncManager] Exported ${words.length}/${totalWords} words`);
        }

        await new Promise<void>((resolve) => setTimeout(resolve, 0));
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      const userBooks = await this.dbManager.getUserWordBooks();
      const exportedBooks: ExportedUserBook[] = [];
      for (const book of userBooks) {
        const input: ExportedUserBookInput = {
          id: book.id,
          name: book.name,
          description: book.description,
          category: book.category,
          difficulty: book.difficulty,
          coverColor: book.coverColor,
          icon: book.icon,
          createdAt: book.createdAt,
          updatedAt: book.updatedAt
        };
        exportedBooks.push(new ExportedUserBook(input));
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // Export notebook (收藏的单词)
      const notebook = await this.dbManager.getNotebookWordsWithTime();
      console.info(`[DataSyncManager] Exporting ${notebook.length} notebook words`);

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // Export texts (文本库)
      const texts = await this.dbManager.listTexts(10000);
      console.info(`[DataSyncManager] Exporting ${texts.length} texts`);

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // Export review events (复习事件)
      const reviewEvents = await this.dbManager.getRecentReviewEvents(50000);
      console.info(`[DataSyncManager] Exporting ${reviewEvents.length} review events`);

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 注意：每日活动（dailyActivity）是从复习事件派生的，不需要单独导出

      const settingsStore = SettingsStore.getInstance();
      const fsrsParams = await settingsStore.getFsrsParams();
      const fsrsParamsJson = fsrsParams !== null ? fsrsParams.toJSON() : '';

      // 先递增版本号，确保导出的 JSON 包含递增后的版本
      this.versionControl.incrementVersion('数据导出');

      const jsonData = await this.exportImport.exportToJSONAsync(
        words, [], this.versionControl, fsrsParamsJson, exportedBooks,
        notebook, texts, reviewEvents, []
      );

      this.versionControl.recordChange(
        ChangeType.UPDATE,
        'export',
        0,
        '导出数据',
        '',
        `${words.length} 个单词, ${exportedBooks.length} 本词书, ${notebook.length} 个收藏, ${texts.length} 个文本, ${reviewEvents.length} 条复习记录`
      );

      return { success: true, data: jsonData, error: '' };
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[DataSyncManager] Export failed:', errMsg);
      return { success: false, data: '', error: errMsg };
    }
  }

  /**
   * 导入数据
   */
  async importData(jsonData: string): Promise<SyncResult> {
    if (this.syncStatus !== SyncStatus.IDLE) {
      const result = new SyncResult();
      result.addError('同步操作正在进行中');
      return result;
    }

    this.syncStatus = SyncStatus.IMPORTING;

    try {
      // 使用异步解析避免阻塞主线程
      console.info('[DataSyncManager] Starting async JSON import');
      const importResult = await this.exportImport.importFromJSONAsync(jsonData, this.versionControl);
      const data: ExportData = importResult.data;
      const result: SyncResult = importResult.result;

      if (result.hasErrors()) {
        this.syncStatus = SyncStatus.ERROR;
        return result;
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      if (data.fsrsParamsJson.length > 0) {
        const params = FsrsParamsPack.fromJSON(data.fsrsParamsJson);
        if (params !== null) {
          const settingsStore = SettingsStore.getInstance();
          await settingsStore.saveFsrsParams(params);
          FSRSAlgorithm.getInstance().setParameters(params.w, params.requestRetention, params.maximumInterval);
        }
      }

      // 批量处理单词导入，每批 50 条，每批后 yield 给 UI 线程
      const batchSize = 50;
      console.info(`[DataSyncManager] Processing ${data.words.length} words in batches of ${batchSize}`);
      
      let transactionActive = false;
      
      for (let i = 0; i < data.words.length; i += batchSize) {
        const batch = data.words.slice(i, i + batchSize);
        
        if (!transactionActive) {
          this.dbManager.beginTransaction();
          transactionActive = true;
        }
        
        let batchHasError = false;
        
        for (const word of batch) {
          try {
            const wordItem = this.convertToWordItem(word);
            
            // 智能合并状态，保留用户操作状态而非完全覆盖
            const existing = await this.dbManager.getWordByWord(wordItem.word);
            if (existing === null) {
              await this.dbManager.insertWord(wordItem);
              result.imported++;

              this.versionControl.recordChange(
                ChangeType.INSERT,
                'word',
                wordItem.id,
                `导入单词: ${wordItem.word}`
              );
            } else {
              // 执行智能合并
              const mergedWordItem = this.mergeWordItem(existing, wordItem);
              
              mergedWordItem.id = existing.id;  // 保留本地ID
              await this.dbManager.updateWord(mergedWordItem);
              result.updated++;

              this.versionControl.recordChange(
                ChangeType.UPDATE,
                'word',
                mergedWordItem.id,
                `更新单词: ${mergedWordItem.word}`
              );
            }
          } catch (e) {
            const errMsg = e instanceof Error ? e.message : String(e);
            result.addError(`导入单词失败: ${errMsg}`);
            batchHasError = true;
          }
        }
        
        if (batchHasError) {
          this.dbManager.rollBack();
          transactionActive = false;
          console.warn(`[DataSyncManager] Batch rolled back due to errors`);
        } else {
          this.dbManager.commit();
          transactionActive = false;
        }
        
        // 每批后 yield 给 UI 线程
        await new Promise<void>((resolve) => setTimeout(resolve, 0));
        
        if ((i + batchSize) % 500 === 0) {
          console.info(`[DataSyncManager] Processed ${i + batchSize}/${data.words.length} words`);
        }
      }
      
      if (transactionActive) {
        this.dbManager.commit();
        transactionActive = false;
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 批量处理定义
      const defBatchSize = 100;
      console.info(`[DataSyncManager] Processing ${data.definitions.length} definitions in batches of ${defBatchSize}`);
      
      for (let i = 0; i < data.definitions.length; i += defBatchSize) {
        const batch = data.definitions.slice(i, i + defBatchSize);
        
        for (const def of batch) {
          try {
            const wordDef = WordDefinition.fromJSON(def.definition);
            await this.dbManager.cacheDefinition(def.word, wordDef);
          } catch (e) {
            const errMsg = e instanceof Error ? e.message : String(e);
            result.addError(`导入定义失败: ${errMsg}`);
          }
        }
        
        // 每批后 yield 给 UI 线程
        await new Promise<void>((resolve) => setTimeout(resolve, 0));
      }

      const existingUserBooks = await this.dbManager.getUserWordBooks();
      const userBookMap = new Map<string, UserWordBook>();
      for (const existingBook of existingUserBooks) {
        userBookMap.set(existingBook.id, existingBook);
      }

      for (const book of data.userBooks) {
        try {
          const existing = userBookMap.get(book.id);

          if (existing === undefined) {
            const newBookId = await this.dbManager.createUserWordBook(
              book.name,
              book.description,
              book.category || '其他',
              book.difficulty || '初级',
              book.coverColor || '',
              book.icon || '📓'
            );
            const createdBook = await this.dbManager.getUserWordBookById(newBookId);
            if (createdBook !== null) {
              userBookMap.set(createdBook.id, createdBook);
            }
            console.info(`[DataSyncManager] Created user book: ${book.name} (${newBookId})`);
          } else if (book.updatedAt > existing.updatedAt) {
            await this.dbManager.updateUserWordBook({
              id: existing.id,
              name: book.name,
              description: book.description,
              wordCount: existing.wordCount,
              isUserCreated: true,
              createdAt: existing.createdAt,
              updatedAt: book.updatedAt,
              category: book.category,
              difficulty: book.difficulty,
              coverColor: book.coverColor,
              icon: book.icon
            });
            const refreshedBook = await this.dbManager.getUserWordBookById(existing.id);
            if (refreshedBook !== null) {
              userBookMap.set(refreshedBook.id, refreshedBook);
            }
            console.info(`[DataSyncManager] Updated user book: ${book.name}`);
          }
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入词书失败: ${errMsg}`);
        }
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 导入单词本（收藏的单词）
      if (data.notebook.length > 0) {
        console.info(`[DataSyncManager] Importing ${data.notebook.length} notebook words`);
        try {
          await this.dbManager.syncNotebookWords(data.notebook);
          console.info(`[DataSyncManager] Imported ${data.notebook.length} notebook words`);
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入收藏失败: ${errMsg}`);
        }
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 导入文本库
      if (data.texts.length > 0) {
        console.info(`[DataSyncManager] Importing ${data.texts.length} texts`);
        try {
          await this.dbManager.syncTexts(data.texts);
          console.info(`[DataSyncManager] Imported ${data.texts.length} texts`);
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入文本失败: ${errMsg}`);
        }
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      // 导入复习事件（每日活动是从复习事件派生的，不需要单独导入）
      if (data.reviewEvents.length > 0) {
        console.info(`[DataSyncManager] Importing ${data.reviewEvents.length} review events`);
        try {
          await this.dbManager.insertReviewEvents(data.reviewEvents);
          console.info(`[DataSyncManager] Imported ${data.reviewEvents.length} review events`);
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入复习事件失败: ${errMsg}`);
        }
      }

      // 注意：每日活动（dailyActivity）是从复习事件派生的，不需要单独导入
      // 如果备份数据中有 dailyActivity，可以忽略，因为它会在导入复习事件后自动重新计算

      this.versionControl.incrementVersion('数据导入');

      this.syncStatus = SyncStatus.IDLE;
      
      console.info(`[DataSyncManager] Import complete: imported=${result.imported}, updated=${result.updated}`);

      return result;
    } catch (e) {
      this.syncStatus = SyncStatus.ERROR;
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[DataSyncManager] Import failed:', errMsg);
      const result = new SyncResult();
      result.addError(`导入失败: ${errMsg}`);
      return result;
    }
  }

  async previewImport(jsonData: string): Promise<ImportPreview> {
    const preview = new ImportPreview();
    try {
      const importResult = this.exportImport.importFromJSON(jsonData, this.versionControl);
      const data: ExportData = importResult.data;
      const result: SyncResult = importResult.result;
      if (result.hasErrors()) {
        preview.errors = result.errors.slice(0);
        return preview;
      }

      preview.total = data.words.length;
      for (const word of data.words) {
        const w = word.word;
        if (w.length === 0) continue;
        const existing = await this.dbManager.getWordByWord(w);
        if (existing === null) {
          preview.imported++;
        } else {
          preview.updated++;
          if (preview.sampleUpdatedWords.length < 5) {
            preview.sampleUpdatedWords.push(w);
          }
        }
      }

      // 预览新增的数据字段
      preview.notebookCount = data.notebook.length;
      preview.textsCount = data.texts.length;
      preview.reviewEventsCount = data.reviewEvents.length;

      return preview;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      preview.errors.push(msg);
      return preview;
    }
  }

  /**
   * 自动备份
   */
  async autoBackup(): Promise<boolean> {
    if (!this.syncConfig.autoBackup) {
      return false;
    }

    const lastBackup = this.getLastBackupTime();
    const now = Date.now();

    if (now - lastBackup < this.syncConfig.backupInterval) {
      return false;
    }

    try {
      const result = await this.exportData();
      if (result.success) {
        // 保存备份
        const fileName = this.exportImport.generateExportFileName();
        await this.saveBackup(fileName, result.data);

        // 清理旧备份
        await this.cleanOldBackups();

        return true;
      }
      return false;
    } catch (e) {
      console.error('[DataSyncManager] Auto backup failed:', e);
      return false;
    }
  }

  /**
   * 获取所有缓存的定义
   */
  private async getAllCachedDefinitions(): Promise<ExportedDefinition[]> {
    const rows = await this.dbManager.getAllDefinitions();
    return rows.map((row): ExportedDefinition => new ExportedDefinition(
      row.word,
      row.definition,
      row.source,
      row.createdAt
    ));
  }

  /**
   * 增量导出数据（仅导出指定时间后变更的数据）
   */
  async exportIncremental(sinceMs: number, includeDefinitions: boolean = false): Promise<ExportResult> {
    try {
      const words = await this.dbManager.getLearnedWordsUpdatedAfter(sinceMs);
      console.info(`[DataSyncManager] Incremental export: ${words.length} words updated after ${sinceMs}`);

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      let definitions: ExportedDefinition[] = [];
      if (includeDefinitions) {
        definitions = await this.getAllCachedDefinitions();
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 0));

      const userBooks = await this.dbManager.getUserWordBooks();
      const exportedBooks: ExportedUserBook[] = [];
      for (const book of userBooks) {
        if (book.updatedAt > sinceMs) {
          const input: ExportedUserBookInput = {
            id: book.id,
            name: book.name,
            description: book.description,
            category: book.category,
            difficulty: book.difficulty,
            coverColor: book.coverColor,
            icon: book.icon,
            createdAt: book.createdAt,
            updatedAt: book.updatedAt
          };
          exportedBooks.push(new ExportedUserBook(input));
        }
      }

      const settingsStore = SettingsStore.getInstance();
      const fsrsParams = await settingsStore.getFsrsParams();
      const fsrsParamsJson = fsrsParams !== null ? fsrsParams.toJSON() : '';
      const jsonData = await this.exportImport.exportToJSONAsync(words, definitions, this.versionControl, fsrsParamsJson, exportedBooks);

      return { success: true, data: jsonData, error: '' };
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[DataSyncManager] Incremental export failed:', errMsg);
      return { success: false, data: '', error: errMsg };
    }
  }

  /**
   * 智能合并WordItem对象，保留用户特定的操作状态
   * 算法状态由FSRS决定，用户状态由用户操作决定
   */
  private mergeWordItem(local: WordItem, remote: WordItem): WordItem {
    const merged = local.clone();
      
    // === FSRS算法状态更新策略 ===
    // 在FSRS算法状态下，采用时间戳驱动的合并 - 更晚的值被保留
    if (remote.updatedAt > local.updatedAt) {
      merged.fsrsState = remote.fsrsState.clone();
      merged.history = ReviewHistory.fromJSON(remote.history.toJSON());
      merged.definition = WordDefinition.fromJSON(remote.definition.toJSON());
      merged.dueDate = remote.dueDate;
      merged.status = remote.status;  // 仅当远程时间戳更新时更新算法状态
      merged.lapseCount = remote.lapseCount;
      merged.leechLevel = remote.leechLevel;
      merged.errorTags = [...remote.errorTags];  // 修改以修复spread语法问题
      merged.suspendUntil = remote.suspendUntil;
      merged.updatedAt = remote.updatedAt;  // 更新主要时间戳
    }
    
    // === 用户操作状态保护策略 ===
    // 无论何时都保护本地用户的个性化设置
    // 对于时间戳敏感的字段，比较子字段时间戳以确定哪个更新
    
    // 1. 保留本地收藏状态，但考虑远程数据（例如：某台设备取消了收藏）
    if (remote.userActions.lastNotebookAt > local.userActions.lastNotebookAt) {
      merged.userActions.isNotebook = remote.userActions.isNotebook;
      merged.userActions.lastNotebookAt = remote.userActions.lastNotebookAt;
    } else {
      // 本地状态更新，保留本地设置
      merged.userActions.isNotebook = local.userActions.isNotebook;
      merged.userActions.lastNotebookAt = local.userActions.lastNotebookAt;
    }
    
    // 2. 用户标记状态处理（熟悉/困难等）
    if (remote.userActions.lastUserStatusAt > local.userActions.lastUserStatusAt) {
      merged.userActions.userStatus = remote.userActions.userStatus;
      merged.userActions.lastUserStatusAt = remote.userActions.lastUserStatusAt;
    } else {
      merged.userActions.userStatus = local.userActions.userStatus;
      merged.userActions.lastUserStatusAt = local.userActions.lastUserStatusAt;
    }
    
    // 3. 添加到词书的状态处理 - 合并用户词书ID，保留双方添加的词书
    const tempLocalBookIds = [...local.userActions.userBookIds];  // 创建副本以避免直接修改
    const tempRemoteBookIds = [...remote.userActions.userBookIds];  // 创建副本以避免直接修改
    // 替换复杂的spread语法以避免ArkTS编译错误
    const combinedBookIds = new Set<string>();
    for (const id of tempLocalBookIds) {
      combinedBookIds.add(id);
    }
    for (const id of tempRemoteBookIds) {
      combinedBookIds.add(id);
    }
    
    merged.userActions.userBookIds = [];
    for (const id of combinedBookIds) {
      merged.userActions.userBookIds.push(id);
    }
    
    // 4. 书签时间更新
    merged.userActions.addedToBooksAt = new Map(local.userActions.addedToBooksAt); // 克隆本地设置
    // 4. 书签时间更新
    merged.userActions.addedToBooksAt = new Map(local.userActions.addedToBooksAt); // 克隆本地设置
    for (const entry of remote.userActions.addedToBooksAt.entries()) {
      const bookId = entry[0];
      const timestamp = entry[1];
      if (!merged.userActions.addedToBooksAt.has(bookId) || 
          timestamp > (merged.userActions.addedToBooksAt.get(bookId) || 0)) {
        merged.userActions.addedToBooksAt.set(bookId, timestamp);
      }
    }
    
    // 5. 保留用户自定义标签，合并来自不同的设备
    const tempLocalCustomTags = [...local.userActions.customTags];  // 创建副本以避免直接修改
    const tempRemoteCustomTags = [...remote.userActions.customTags];  // 创建副本以避免直接修改
    // 替换复杂的spread语法以避免ArkTS编译错误
    const combinedCustomTags = new Set<string>();
    for (const tag of tempLocalCustomTags) {
      combinedCustomTags.add(tag);
    }
    for (const tag of tempRemoteCustomTags) {
      combinedCustomTags.add(tag);
    }
    
    merged.userActions.customTags = [];
    for (const tag of combinedCustomTags) {
      merged.userActions.customTags.push(tag);
    }
    
    // 6. 保留用户的笔记（如果都有笔记，保留最近一个设备上的笔记）
    if (remote.userActions.lastCustomChangeAt > local.userActions.lastCustomChangeAt) {
      merged.userActions.notes = remote.userActions.notes;
    } 
    // 如果本地修改更近，则保留本地笔记（默认）
    
    // 7. 确保更新用户状态的时间戳是最新的
    merged.userActions.lastCustomChangeAt = Math.max(
      local.userActions.lastCustomChangeAt, 
      remote.userActions.lastCustomChangeAt
    );
    
    // 8. 更新FSRS更新时间戳为两者最大值，确保FSRS状态正确追踪
    merged.updatedAt = Math.max(
      merged.updatedAt,
      remote.updatedAt,
      merged.userActions.lastCustomChangeAt
    );

    return merged;
  }


  /**
   * 增量导入数据（合并策略：按数据类型智能处理）
   */
  async importIncremental(jsonData: string): Promise<SyncResult> {
    try {
      const importResult = this.exportImport.importFromJSON(jsonData, this.versionControl);
      const data: ExportData = importResult.data;
      const result: SyncResult = importResult.result;

      if (result.hasErrors()) {
        this.syncStatus = SyncStatus.ERROR;
        return result;
      }

      if (data.fsrsParamsJson.length > 0) {
        const params = FsrsParamsPack.fromJSON(data.fsrsParamsJson);
        if (params !== null) {
          const settingsStore = SettingsStore.getInstance();
          await settingsStore.saveFsrsParams(params);
          FSRSAlgorithm.getInstance().setParameters(params.w, params.requestRetention, params.maximumInterval);
        }
      }

      for (const word of data.words) {
        try {
          const remoteWordItem = this.convertToWordItem(word);
          const localWordItem = await this.dbManager.getWordByWord(remoteWordItem.word);

          if (localWordItem === null) {
            // 新单词，直接添加
            await this.dbManager.insertWord(remoteWordItem);
            result.imported++;
          } else {
            // 执行智能合并
            const mergedWordItem = this.mergeWordItem(localWordItem, remoteWordItem);
            
            // 更新本地单词项目 - 确保保留本地ID
            mergedWordItem.id = localWordItem.id;
            await this.dbManager.updateWord(mergedWordItem);
            result.updated++;
          }
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入单词失败: ${errMsg}`);
        }

        if ((result.imported + result.updated + result.skipped) % 50 === 0) {
          await new Promise<void>((resolve) => setTimeout(resolve, 0));
        }
      }

      this.dbManager.beginTransaction();
      try {
        for (const def of data.definitions) {
          try {
            const wordDef = WordDefinition.fromJSON(def.definition);
            await this.dbManager.cacheDefinition(def.word, wordDef);
          } catch (e) {
            const errMsg = e instanceof Error ? e.message : String(e);
            result.addError(`导入定义失败: ${errMsg}`);
          }
        }
        this.dbManager.commit();
      } catch (e) {
        this.dbManager.rollBack();
        const errMsg = e instanceof Error ? e.message : String(e);
        result.addError(`定义导入事务失败: ${errMsg}`);
      }

      const existingUserBooks = await this.dbManager.getUserWordBooks();
      const userBookMap = new Map<string, UserWordBook>();
      for (const existingBook of existingUserBooks) {
        userBookMap.set(existingBook.id, existingBook);
      }

      for (const book of data.userBooks) {
        try {
          const existing = userBookMap.get(book.id);

          if (existing === undefined) {
            const newBookId = await this.dbManager.createUserWordBook(
              book.name,
              book.description,
              book.category || '其他',
              book.difficulty || '初级',
              book.coverColor || '',
              book.icon || '📓'  // 修复语法错误
            );
            const createdBook = await this.dbManager.getUserWordBookById(newBookId);
            if (createdBook !== null) {
              userBookMap.set(createdBook.id, createdBook);
            }
          } else if (book.updatedAt > existing.updatedAt) {
            await this.dbManager.updateUserWordBook({
              id: existing.id,
              name: book.name,
              description: book.description,
              wordCount: existing.wordCount,
              isUserCreated: true,
              createdAt: existing.createdAt,
              updatedAt: book.updatedAt,
              category: book.category,
              difficulty: book.difficulty,
              coverColor: book.coverColor,
              icon: book.icon
            });
            const refreshedBook = await this.dbManager.getUserWordBookById(existing.id);
            if (refreshedBook !== null) {
              userBookMap.set(refreshedBook.id, refreshedBook);
            }
          }
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入词书失败: ${errMsg}`);
        }
      }

      return result;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[DataSyncManager] Incremental import failed:', errMsg);
      const result = new SyncResult();
      result.addError(`导入失败: ${errMsg}`);
      return result;
    }
  }

  /**
   * 转换为WordItem
   */
  private convertToWordItem(exportedWord: ExportedWord): WordItem {
    let definition: WordDefinition = new WordDefinition();
    if (exportedWord.definition && exportedWord.definition.length > 0 && 
        (exportedWord.definitionSource === 'ai' || exportedWord.definitionSource === 'local')) {
      try {
        definition = WordDefinition.fromJSON(exportedWord.definition);
      } catch (e) {
        console.warn(`[DataSyncManager] Failed to parse definition for ${exportedWord.word}`);
      }
    }

    let fsrsState: FSRSState = new FSRSState();
    if (exportedWord.fsrsState && exportedWord.fsrsState.length > 0) {
      try {
        fsrsState = FSRSState.fromJSON(exportedWord.fsrsState);
      } catch (e) {
        console.warn(`[DataSyncManager] Failed to parse fsrsState for ${exportedWord.word}`);
      }
    }

    let history: ReviewHistory = new ReviewHistory();
    if (exportedWord.history && exportedWord.history.length > 0) {
      try {
        history = ReviewHistory.fromJSON(exportedWord.history);
      } catch (e) {
        console.warn(`[DataSyncManager] Failed to parse history for ${exportedWord.word}`);
      }
    }
    
    // 处理用户操作状态 - 如果存在则使用导出的数据，否则使用默认值
    let userActions: UserActions;
    if (exportedWord.userActions) {
      // 从导出的数据中重建用户操作状态
      const addedToBooksAt = new Map<string, number>(exportedWord.userActions.addedToBooksAt);
      userActions = new UserActions(
        exportedWord.userActions.isNotebook,
        [...exportedWord.userActions.userBookIds],  // 修复spread语法问题
        [...exportedWord.userActions.customTags],   // 修复spread语法问题
        exportedWord.userActions.notes,
        exportedWord.userActions.userStatus,
        addedToBooksAt,
        exportedWord.userActions.lastNotebookAt,
        exportedWord.userActions.lastUserStatusAt,
        exportedWord.userActions.lastCustomChangeAt
      );
    } else {
      // 默认用户操作状态
      userActions = new UserActions(false, [], [], '', 'normal', new Map(), 0, 0, 0);
    }

    const wordItem = new WordItem(
      exportedWord.id,  // ID可能会由数据库重置，但我们需要传递初始值以支持merge逻辑
      exportedWord.word,
      normalizeWordStatus(exportedWord.status),  // 使用正确的工厂函数
      fsrsState,  // fsrsState (第4个参数) - 修复类型错误
      history,    // history (第5个参数)
      definition, // definition (第6个参数)
      exportedWord.dueDate,     // dueDate (第7个参数)
      exportedWord.createdAt,   // createdAt (第8个参数)
      exportedWord.updatedAt,   // updatedAt (第9个参数)
      exportedWord.bookId,      // bookId (第10个参数)

      [],                        // tags: string[] (第11个参数)
      exportedWord.lapseCount,   // lapseCount (第12个参数)
      exportedWord.leechLevel,   // leechLevel (第13个参数)
      exportedWord.errorTags || [], // errorTags (第14个参数)
      exportedWord.suspendUntil || 0, // suspendUntil (第15个参数)
      userActions                   // userActions (第16个参数)
    );
    return wordItem; // 修复：添加缺失的返回值语句
  }
}