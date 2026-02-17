// =====================================================
// DataExportImport.ets - 数据导出和导入功能
// 支持JSON格式导出、数据压缩和冲突解决
// =====================================================

import { VersionControl } from './VersionControl';
import { WordItem } from '../model/WordModel';
import { util } from '@kit.ArkTS';
import taskpool from '@ohos.taskpool';
import { stringifyJson } from './webdav/WebDavCryptoTask';

/**
 * 导出的单词数据（智能同步释义：仅同步非 builtin 来源）
 */
export class ExportedWord {
  id: number;
  word: string;
  status: string;
  fsrsState: string;
  history: string;
  definition: string;
  definitionSource: string;
  dueDate: number;
  createdAt: number;
  updatedAt: number;
  bookId: string;
  tags: string[];
  lapseCount: number;
  leechLevel: number;
  errorTags: string[];
  suspendUntil: number;

  constructor(word: WordItem) {
    this.id = word.id;
    this.word = word.word;
    this.status = word.status;
    this.fsrsState = word.fsrsState.toJSON();
    this.history = word.history.toJSON();
    this.definitionSource = word.definition.source;
    if (word.definition.source === 'ai' || word.definition.source === 'local') {
      this.definition = word.definition.toJSON();
    } else {
      this.definition = '';
    }
    this.dueDate = word.dueDate;
    this.createdAt = word.createdAt;
    this.updatedAt = word.updatedAt;
    this.bookId = word.bookId;
    this.tags = word.tags;
    this.lapseCount = word.lapseCount;
    this.leechLevel = word.leechLevel;
    this.errorTags = word.errorTags;
    this.suspendUntil = word.suspendUntil;
  }
}

/**
 * 导出的定义数据
 */
export class ExportedDefinition {
  word: string;
  definition: string;
  source: string;
  createdAt: number;

  constructor(word: string, definition: string, source: string, createdAt: number) {
    this.word = word;
    this.definition = definition;
    this.source = source;
    this.createdAt = createdAt;
  }
}

/**
 * 导出的用户词书数据
 */
export class ExportedUserBook {
  id: string;
  name: string;
  description: string;
  category: string;
  difficulty: string;
  coverColor: string;
  icon: string;
  createdAt: number;
  updatedAt: number;

  constructor(book: ExportedUserBookInput) {
    this.id = book.id;
    this.name = book.name;
    this.description = book.description || '';
    this.category = book.category || '其他';
    this.difficulty = book.difficulty || '初级';
    this.coverColor = book.coverColor || '["#a8edea", "#fed6e3"]';
    this.icon = book.icon || '📓';
    this.createdAt = book.createdAt;
    this.updatedAt = book.updatedAt;
  }
}

/**
 * 导出的用户词书输入接口
 */
export interface ExportedUserBookInput {
  id: string;
  name: string;
  description: string;
  category?: string;
  difficulty?: string;
  coverColor?: string;
  icon?: string;
  createdAt: number;
  updatedAt: number;
}

/**
 * 导出数据结构
 */
/**
 * JSON导出数据接口
 */
export interface ExportDataJSON {
  version?: string;
  timestamp?: number;
  appVersion?: string;
  words?: ExportedWord[];
  definitions?: ExportedDefinition[];
  userBooks?: ExportedUserBook[];
  versionControl?: string;
  fsrsParamsJson?: string;
}

interface GeneratedObjectLiteralInterface_1 {
  version: string;
  timestamp: number;
  appVersion: string;
  words: ExportedWord[];
  definitions: ExportedDefinition[];
  userBooks: ExportedUserBook[];
  versionControl: string;
  fsrsParamsJson: string;
}

export class ExportData {
  version: string;
  timestamp: number;
  appVersion: string;
  words: ExportedWord[];
  definitions: ExportedDefinition[];
  userBooks: ExportedUserBook[];
  versionControl: string;
  fsrsParamsJson: string;

  constructor(
    version: string = '1.0',
    timestamp: number = Date.now(),
    appVersion: string = '1.0.0'
  ) {
    this.version = version;
    this.timestamp = timestamp;
    this.appVersion = appVersion;
    this.words = [];
    this.definitions = [];
    this.userBooks = [];
    this.versionControl = '';
    this.fsrsParamsJson = '';
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: GeneratedObjectLiteralInterface_1 = {
      version: this.version,
      timestamp: this.timestamp,
      appVersion: this.appVersion,
      words: this.words,
      definitions: this.definitions,
      userBooks: this.userBooks,
      versionControl: this.versionControl,
      fsrsParamsJson: this.fsrsParamsJson
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): ExportData {
    try {
      const obj = JSON.parse(json) as ExportDataJSON;
      const data = new ExportData();

      if (obj.version !== undefined) {
        data.version = obj.version;
      }
      if (obj.timestamp !== undefined) {
        data.timestamp = obj.timestamp;
      }
      if (obj.appVersion !== undefined) {
        data.appVersion = obj.appVersion;
      }
      if (obj.words !== undefined) {
        data.words = obj.words;
      }
      if (obj.definitions !== undefined) {
        data.definitions = obj.definitions;
      }
      if (obj.userBooks !== undefined) {
        data.userBooks = obj.userBooks;
      }
      if (obj.versionControl !== undefined) {
        data.versionControl = obj.versionControl;
      }
      if (obj.fsrsParamsJson !== undefined) {
        data.fsrsParamsJson = obj.fsrsParamsJson;
      }

      return data;
    } catch (e) {
      return new ExportData();
    }
  }
}

/**
 * 同步结果
 */
export class SyncResult {
  imported: number;
  updated: number;
  conflicts: number;
  skipped: number;
  errors: string[];

  constructor() {
    this.imported = 0;
    this.updated = 0;
    this.conflicts = 0;
    this.skipped = 0;
    this.errors = [];
  }

  /**
   * 添加错误信息
   */
  addError(error: string): void {
    this.errors.push(error);
  }

  /**
   * 是否有错误
   */
  hasErrors(): boolean {
    return this.errors.length > 0;
  }

  /**
   * 获取摘要信息
   */
  getSummary(): string {
    return `导入: ${this.imported}, 更新: ${this.updated}, 冲突: ${this.conflicts}, 跳过: ${this.skipped}`;
  }
}

export interface ImportResult {
  data: ExportData;
  result: SyncResult;
}

/**
 * 数据导出导入管理器
 */
export class DataExportImport {
  /**
   * 导出数据为JSON字符串
   */
  exportToJSON(
    words: WordItem[],
    definitions: ExportedDefinition[],
    versionControl: VersionControl,
    fsrsParamsJson: string = '',
    userBooks: ExportedUserBook[] = []
  ): string {
    const exportedWords: ExportedWord[] = [];
    const batchSize = 100;
    
    for (let i = 0; i < words.length; i += batchSize) {
      const batch = words.slice(i, i + batchSize);
      for (const word of batch) {
        exportedWords.push(new ExportedWord(word));
      }
    }

    const obj: GeneratedObjectLiteralInterface_1 = {
      version: '1.0',
      timestamp: Date.now(),
      appVersion: '1.0.0',
      words: exportedWords,
      definitions: definitions,
      userBooks: userBooks,
      versionControl: versionControl.toJSON(),
      fsrsParamsJson: fsrsParamsJson
    };

    return JSON.stringify(obj);
  }

  /**
   * 导出数据为JSON字符串（异步版本，使用taskpool避免主线程阻塞）
   */
  async exportToJSONAsync(
    words: WordItem[],
    definitions: ExportedDefinition[],
    versionControl: VersionControl,
    fsrsParamsJson: string = '',
    userBooks: ExportedUserBook[] = []
  ): Promise<string> {
    const exportedWords: ExportedWord[] = [];
    const batchSize = 50;
    
    for (let i = 0; i < words.length; i += batchSize) {
      const batch = words.slice(i, i + batchSize);
      for (const word of batch) {
        exportedWords.push(new ExportedWord(word));
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 0));
    }

    const obj: GeneratedObjectLiteralInterface_1 = {
      version: '1.0',
      timestamp: Date.now(),
      appVersion: '1.0.0',
      words: exportedWords,
      definitions: definitions,
      userBooks: userBooks,
      versionControl: versionControl.toJSON(),
      fsrsParamsJson: fsrsParamsJson
    };

    try {
      const task = new taskpool.Task(stringifyJson, obj);
      const result = await taskpool.execute(task) as string;
      return result;
    } catch (e) {
      console.error('[DataExportImport] Taskpool stringify failed, falling back to sync:', e);
      return JSON.stringify(obj);
    }
  }

  /**
   * 从JSON字符串导入数据
   */
  importFromJSON(
    json: string,
    currentVersion: VersionControl
  ): ImportResult {
    const result = new SyncResult();

    try {
      const importData = ExportData.fromJSON(json);

      // 验证数据格式
      if (importData.version === '1.0') {
        return this.processImportV1(importData, currentVersion, result);
      } else {
        result.addError(`不支持的数据版本: ${importData.version}`);
        return { data: importData, result };
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      result.addError(`导入失败: ${errMsg}`);
      return { data: new ExportData(), result };
    }
  }

  /**
   * 处理V1版本数据导入
   */
  private processImportV1(
    importData: ExportData,
    currentVersion: VersionControl,
    result: SyncResult
  ): ImportResult {
    const currentVersionInfo = currentVersion.getCurrentVersion();
    const importVersionControl = VersionControl.fromJSON(importData.versionControl);
    const importVersionInfo = importVersionControl.getCurrentVersion();

    // 版本比较
    const comparison = VersionControl.compareVersions(currentVersionInfo, importVersionInfo);

    if (comparison < 0) {
      // 导入较新版本的数据
      result.addError('导入的数据版本较新，建议先更新应用');
      return { data: importData, result };
    } else {
      // 导入同版本或较旧版本的数据：允许导入，由上层按词条粒度合并（upsert）
      return { data: importData, result };
    }
  }

  /**
   * 合并旧版本数据
   */
  private mergeOldData(
    importData: ExportData,
    currentVersion: VersionControl,
    result: SyncResult
  ): ImportResult {
    // 检查冲突
    const importVersionControl = VersionControl.fromJSON(importData.versionControl);
    const importVersionInfo = importVersionControl.getCurrentVersion();
    const currentVersionInfo = currentVersion.getCurrentVersion();

    if (currentVersion.hasConflict(importVersionInfo)) {
      // 有冲突，需要用户选择
      result.conflicts++;
      result.addError('检测到版本冲突，请手动解决');
      return { data: importData, result };
    }

    // 无冲突，合并数据
    for (const word of importData.words) {
      // 检查单词是否已存在
      result.skipped++;
    }

    return { data: importData, result };
  }

  /**
   * 合并相同版本数据
   */
  private mergeSameVersion(
    importData: ExportData,
    currentVersion: VersionControl,
    result: SyncResult
  ): ImportResult {
    const importVersionControl = VersionControl.fromJSON(importData.versionControl);
    const importVersionInfo = importVersionControl.getCurrentVersion();
    const currentVersionInfo = currentVersion.getCurrentVersion();

    // 比较时间戳
    if (importVersionInfo.timestamp > currentVersionInfo.timestamp) {
      // 导入的数据更新，使用导入数据
      result.imported = importData.words.length;
    } else {
      // 当前数据更新，跳过导入
      result.skipped = importData.words.length;
    }

    return { data: importData, result };
  }

  /**
   * 压缩数据（简化版，实际可使用pako等库）
   */
  compressData(data: string): string {
    // 简化实现，实际应使用压缩库
    return data;
  }

  /**
   * 解压数据（简化版）
   */
  decompressData(data: string): string {
    // 简化实现，实际应使用压缩库
    return data;
  }

  /**
   * 验证导出数据
   */
  validateExportData(data: ExportData): boolean {
    // 检查必要字段
    if (data.version === undefined || data.version === '') {
      return false;
    }
    if (data.timestamp === undefined || data.timestamp <= 0) {
      return false;
    }
    if (data.words === undefined || !Array.isArray(data.words)) {
      return false;
    }

    // 检查单词数据
    for (const word of data.words) {
      if (word.word === undefined || word.word === '') {
        return false;
      }
    }

    return true;
  }

  /**
   * 生成导出文件名
   */
  generateExportFileName(): string {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');

    return `vignette_backup_${year}${month}${day}_${hours}${minutes}.json`;
  }

  /**
   * 计算数据大小
   */
  calculateDataSize(data: string): string {
    const encoder = new util.TextEncoder();
    const encoded = encoder.encode(data);
    const byteLength = encoded.length;
    const kb = byteLength / 1024;
    const mb = kb / 1024;

    if (mb >= 1) {
      return `${mb.toFixed(2)} MB`;
    } else if (kb >= 1) {
      return `${kb.toFixed(2)} KB`;
    } else {
      return `${byteLength} B`;
    }
  }

  /**
   * 导出统计信息
   */
  getExportStats(data: ExportData): string {
    const wordCount = data.words.length;
    const definitionCount = data.definitions.length;
    const dataSize = this.calculateDataSize(data.toJSON());

    return `单词: ${wordCount}, 定义: ${definitionCount}, 大小: ${dataSize}`;
  }
}
