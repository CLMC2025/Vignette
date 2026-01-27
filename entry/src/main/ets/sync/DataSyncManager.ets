// =====================================================
// DataSyncManager.ets - 数据同步管理器
// 统一管理数据导出、导入和同步操作
// =====================================================

import { VersionControl, ChangeType } from './VersionControl';
import { DataExportImport, ExportData, SyncResult, ExportedWord, ExportedDefinition } from './DataExportImport';
import { DBManager } from '../database/DBManager';
import { WordItem, WordDefinition, WordStatus } from '../model/WordModel';

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

  constructor() {
    this.imported = 0;
    this.updated = 0;
    this.total = 0;
    this.errors = [];
    this.sampleUpdatedWords = [];
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

  /**
   * 导出数据
   */
  async exportData(): Promise<ExportResult> {
    if (this.syncStatus !== SyncStatus.IDLE) {
      return { success: false, data: '', error: '同步操作正在进行中' };
    }

    this.syncStatus = SyncStatus.EXPORTING;

    try {
      // 获取所有单词
      const words = await this.dbManager.getAllWords();

      // 获取所有缓存的定义
      const definitions = await this.getAllCachedDefinitions();

      // 导出为JSON
      const jsonData = this.exportImport.exportToJSON(words, definitions, this.versionControl);

      // 增加版本号
      this.versionControl.incrementVersion('数据导出');

      // 记录变更
      this.versionControl.recordChange(
        ChangeType.UPDATE,
        'export',
        0,
        '导出数据',
        '',
        `${words.length} 个单词`
      );

      this.syncStatus = SyncStatus.IDLE;

      return { success: true, data: jsonData, error: '' };
    } catch (e) {
      this.syncStatus = SyncStatus.ERROR;
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
      // 导入数据
      const importResult = this.exportImport.importFromJSON(jsonData, this.versionControl);
      const data: ExportData = importResult.data;
      const result: SyncResult = importResult.result;

      if (result.hasErrors()) {
        this.syncStatus = SyncStatus.ERROR;
        return result;
      }

      // 处理导入的单词
      for (const word of data.words) {
        try {
          // 转换为WordItem
          const wordItem = this.convertToWordItem(word);

          // 检查是否已存在
          const existing = await this.dbManager.getWordByWord(wordItem.word);
          if (existing === null) {
            // 插入新单词
            await this.dbManager.insertWord(wordItem);
            result.imported++;

            // 记录变更
            this.versionControl.recordChange(
              ChangeType.INSERT,
              'word',
              wordItem.id,
              `导入单词: ${wordItem.word}`
            );
          } else {
            // 更新现有单词
            wordItem.id = existing.id;
            await this.dbManager.updateWord(wordItem);
            result.updated++;

            // 记录变更
            this.versionControl.recordChange(
              ChangeType.UPDATE,
              'word',
              wordItem.id,
              `更新单词: ${wordItem.word}`
            );
          }
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入单词失败: ${errMsg}`);
        }
      }

      // 处理导入的定义
      for (const def of data.definitions) {
        try {
          const wordDef = WordDefinition.fromJSON(def.definition);
          await this.dbManager.cacheDefinition(def.word, wordDef);
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`导入定义失败: ${errMsg}`);
        }
      }

      // 更新版本控制
      if (data.versionControl !== undefined && data.versionControl.length > 0) {
        this.versionControl = VersionControl.fromJSON(data.versionControl);
      } else {
        this.versionControl.incrementVersion('数据导入');
      }

      this.syncStatus = SyncStatus.IDLE;

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
    // 这里需要扩展DBManager以支持获取所有定义
    // 暂时返回空数组
    return [];
  }

  /**
   * 转换为WordItem
   */
  private convertToWordItem(exportedWord: ExportedWord): WordItem {
    return new WordItem(
      exportedWord.id,
      exportedWord.word,
      exportedWord.status as WordStatus,
      undefined,
      undefined,
      undefined,
      exportedWord.dueDate,
      exportedWord.createdAt,
      exportedWord.updatedAt,
      exportedWord.bookId,
      exportedWord.tags
    );
  }

  /**
   * 保存备份
   */
  private async saveBackup(fileName: string, data: string): Promise<void> {
    // 这里需要实现文件保存功能
    // 暂时只记录备份信息
    const backupInfo = new BackupInfo(
      fileName,
      Date.now(),
      data.length,
      0 // 需要从数据中计算
    );
    this.backups.push(backupInfo);
  }

  /**
   * 获取最后备份时间
   */
  private getLastBackupTime(): number {
    if (this.backups.length === 0) {
      return 0;
    }
    return this.backups[this.backups.length - 1].timestamp;
  }

  /**
   * 清理旧备份
   */
  private async cleanOldBackups(): Promise<void> {
    while (this.backups.length > this.syncConfig.maxBackupCount) {
      const oldBackup = this.backups.shift();
      if (oldBackup !== undefined) {
        // 删除旧备份文件
        await this.deleteBackup(oldBackup.fileName);
      }
    }
  }

  /**
   * 删除备份
   */
  private async deleteBackup(fileName: string): Promise<void> {
    // 这里需要实现文件删除功能
    console.log(`[DataSyncManager] Deleting backup: ${fileName}`);
  }

  /**
   * 获取备份列表
   */
  getBackups(): BackupInfo[] {
    return [...this.backups];
  }

  /**
   * 恢复备份
   */
  async restoreBackup(fileName: string): Promise<SyncResult> {
    try {
      // 这里需要实现从文件读取数据的功能
      // 暂时返回空结果
      return new SyncResult();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      const result = new SyncResult();
      result.addError(`恢复备份失败: ${errMsg}`);
      return result;
    }
  }

  /**
   * 合并数据（用于解决冲突）
   */
  async mergeData(otherData: ExportData): Promise<SyncResult> {
    const result = new SyncResult();

    try {
      // 比较版本
      const otherVersionControl = VersionControl.fromJSON(otherData.versionControl);
      const comparison = VersionControl.compareVersions(
        this.versionControl.getCurrentVersion(),
        otherVersionControl.getCurrentVersion()
      );

      if (comparison === 0) {
        // 版本相同，检查时间戳
        const resolved = this.versionControl.resolveConflict(
          otherVersionControl.getCurrentVersion()
        );

        if (resolved === this.versionControl.getCurrentVersion()) {
          result.addError('当前数据较新，无需合并');
          return result;
        }
      }

      // 合并单词数据
      for (const word of otherData.words) {
        try {
          const existing = await this.dbManager.getWordByWord(word.word);
          if (existing === null) {
            // 新单词，直接添加
            const wordItem = this.convertToWordItem(word);
            await this.dbManager.insertWord(wordItem);
            result.imported++;
          } else {
            // 已存在，比较时间戳
            if (word.updatedAt > existing.updatedAt) {
              // 导入的数据更新
              const wordItem = this.convertToWordItem(word);
              wordItem.id = existing.id;
              await this.dbManager.updateWord(wordItem);
              result.updated++;
            } else {
              // 当前数据更新，跳过
              result.skipped++;
            }
          }
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e);
          result.addError(`合并单词失败: ${errMsg}`);
        }
      }

      // 更新版本控制
      this.versionControl = otherVersionControl;

      return result;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      result.addError(`合并数据失败: ${errMsg}`);
      return result;
    }
  }

  /**
   * 重置同步状态
   */
  resetSyncStatus(): void {
    this.syncStatus = SyncStatus.IDLE;
  }

  /**
   * 获取同步统计
   */
  getSyncStats(): SyncStats {
    const stats: SyncStats = {
      totalBackups: this.backups.length,
      totalChanges: this.versionControl.getChangeLog().length,
      lastSyncTime: this.versionControl.getCurrentVersion().timestamp
    };
    return stats;
  }
}

export interface ExportResult {
  success: boolean;
  data: string;
  error: string;
}

export interface SyncStats {
  totalBackups: number;
  totalChanges: number;
  lastSyncTime: number;
}
