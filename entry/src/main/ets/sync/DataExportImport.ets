// =====================================================
// DataExportImport.ets - 数据导出和导入功能
// 支持JSON格式导出、数据压缩和冲突解决
// =====================================================

import { VersionControl } from './VersionControl';
import { WordItem, UserActions } from '../model/WordModel';
import { util } from '@kit.ArkTS';
import taskpool from '@ohos.taskpool';
import { stringifyJson, parseJson } from './webdav/WebDavCryptoTask';
import { NotebookWordEntry, DailyActivity, ReviewEventRow } from '../database/DBManager';
import { TextRow } from '../database/repositories/TextRepository';

/**
 * 用户操作状态导出接口 - 必须是命名的接口，不能是内联字面量
 */
export interface ExportedUserActions {
  isNotebook: boolean;
  userBookIds: string[];
  customTags: string[];
  notes: string;
  userStatus: string;
  addedToBooksAt: [string, number][];
  lastNotebookAt: number;
  lastUserStatusAt: number;
  lastCustomChangeAt: number;
}

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
  // 新增：用户操作状态导出字段 - 必须使用命名接口
  userActions?: ExportedUserActions;
  
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
    
    // 新增：导出用户操作状态
    this.userActions = {
      isNotebook: word.userActions.isNotebook,
      userBookIds: [...word.userActions.userBookIds],
      customTags: [...word.userActions.customTags],
      notes: word.userActions.notes,
      userStatus: word.userActions.userStatus,
      addedToBooksAt: Array.from(word.userActions.addedToBooksAt.entries()),
      lastNotebookAt: word.userActions.lastNotebookAt,
      lastUserStatusAt: word.userActions.lastUserStatusAt,
      lastCustomChangeAt: word.userActions.lastCustomChangeAt
    };
  }
}

/**
 * 导入时的单词数据（包含用户操作状态）
 */
export class ImportedWordData {
  exportedWord: ExportedWord; // 原始导出数据
  userActions?: UserActions;  // 解析后的用户操作状态

  constructor(exportedWord: ExportedWord) {
    this.exportedWord = exportedWord;
    
    // 如果存在用户操作状态数据，则解析它
    if (exportedWord.userActions) {
      const addedToBooksAtMap = new Map<string, number>(exportedWord.userActions.addedToBooksAt);
      this.userActions = new UserActions(
        exportedWord.userActions.isNotebook,
        [...exportedWord.userActions.userBookIds],
        [...exportedWord.userActions.customTags],
        exportedWord.userActions.notes,
        exportedWord.userActions.userStatus,
        addedToBooksAtMap,
        exportedWord.userActions.lastNotebookAt,
        exportedWord.userActions.lastUserStatusAt,
        exportedWord.userActions.lastCustomChangeAt
      );
    }
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
  notebook?: NotebookWordEntry[];
  texts?: TextRow[];
  reviewEvents?: ReviewEventRow[];
  dailyActivity?: DailyActivity[];
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
  notebook: NotebookWordEntry[];
  texts: TextRow[];
  reviewEvents: ReviewEventRow[];
  dailyActivity: DailyActivity[];
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
  notebook: NotebookWordEntry[];
  texts: TextRow[];
  reviewEvents: ReviewEventRow[];
  dailyActivity: DailyActivity[];

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
    this.notebook = [];
    this.texts = [];
    this.reviewEvents = [];
    this.dailyActivity = [];
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
      fsrsParamsJson: this.fsrsParamsJson,
      notebook: this.notebook,
      texts: this.texts,
      reviewEvents: this.reviewEvents,
      dailyActivity: this.dailyActivity
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

      // 验证数据格式
      if (data.version === '1.0') {
        // 在此版本中简单地继续返回数据，处理逻辑由调用者处理
      } else {
        // 版本不受支持
      }
      return data;
    } catch (e) {
      return new ExportData();
    }
  }

  /**
   * 離線導入處理邏輯
   */
  // 这行有问题的静态类型定义不再需要，注释掉
}

/**
 * 同步結果
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
    return `导入: ${this.imported}, 更新: ${this.updated}, 冲突: ${this.conflicts}, 跳過: ${this.skipped}`;
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
    userBooks: ExportedUserBook[] = [],
    notebook: NotebookWordEntry[] = [],
    texts: TextRow[] = [],
    reviewEvents: ReviewEventRow[] = [],
    dailyActivity: DailyActivity[] = []
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
      fsrsParamsJson: fsrsParamsJson,
      notebook: notebook,
      texts: texts,
      reviewEvents: reviewEvents,
      dailyActivity: dailyActivity
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
    userBooks: ExportedUserBook[] = [],
    notebook: NotebookWordEntry[] = [],
    texts: TextRow[] = [],
    reviewEvents: ReviewEventRow[] = [],
    dailyActivity: DailyActivity[] = []
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
      fsrsParamsJson: fsrsParamsJson,
      notebook: notebook,
      texts: texts,
      reviewEvents: reviewEvents,
      dailyActivity: dailyActivity
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
   * 从JSON字符串导入数据（异步解析版本，避免阻塞主线程）
   */
  async importFromJSONAsync(
    json: string,
    currentVersion: VersionControl
  ): Promise<ImportResult> {
    const result = new SyncResult();

    try {
      // 使用 taskpool 异步解析 JSON，避免阻塞主线程
      console.info('[DataExportImport] Parsing JSON in taskpool');
      const task = new taskpool.Task(parseJson, json);
      const obj = await taskpool.execute(task) as ExportDataJSON;
      console.info('[DataExportImport] JSON parsing complete');
      
      // 构造 ExportData
      const importData = new ExportData();
      if (obj.version !== undefined) {
        importData.version = obj.version;
      }
      if (obj.timestamp !== undefined) {
        importData.timestamp = obj.timestamp;
      }
      if (obj.appVersion !== undefined) {
        importData.appVersion = obj.appVersion;
      }
      if (obj.words !== undefined) {
        importData.words = obj.words;
      }
      if (obj.definitions !== undefined) {
        importData.definitions = obj.definitions;
      }
      if (obj.userBooks !== undefined) {
        importData.userBooks = obj.userBooks;
      }
      if (obj.versionControl !== undefined) {
        importData.versionControl = obj.versionControl;
      }
      if (obj.fsrsParamsJson !== undefined) {
        importData.fsrsParamsJson = obj.fsrsParamsJson;
      }

      // 验證數據格式
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
   * 从JSON字符串导入数据
   */
  importFromJSON(
    json: string,
    currentVersion: VersionControl
  ): ImportResult {
    const result = new SyncResult();

    try {
      const importData = ExportData.fromJSON(json);

      // 验證數據格式
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
   * 
   * 注意：不再检查应用级版本号。增量同步应该在词条级别按 updatedAt 时间戳做 upsert 合并，
   * 而不是用版本号拦截数据。这是主流应用（如 Anki、墨墨背单词）的标准做法。
   */
  private processImportV1(
    importData: ExportData,
    currentVersion: VersionControl,
    result: SyncResult
  ): ImportResult {
    // 移除版本號檢查邏輯，直接放行所有數據
    // 由上層（DataSyncManager.importIncremental 等方法）按詞條粒度做 upsert
    return { data: importData, result };
  }

  /**
   * 合並舊版本數據
   */
  private mergeOldData(
    importData: ExportData,
    currentVersion: VersionControl,
    result: SyncResult
  ): ImportResult {
    // 檢查衝突
    const importVersionControl = VersionControl.fromJSON(importData.versionControl);
    const importVersionInfo = importVersionControl.getCurrentVersion();
    const currentVersionInfo = currentVersion.getCurrentVersion();

    if (currentVersion.hasConflict(importVersionInfo)) {
      // 有衝突，需要用戶選擇
      result.conflicts++;
      result.addError('檢測到版本衝突，請手動解決');
      return { data: importData, result };
    }

    // 無衝突，合併數據
    for (const word of importData.words) {
      // 檢查單詞是否已存在
      result.skipped++;
    }

    return { data: importData, result };
  }

  /**
   * 合並相同版本數據
   */
  private mergeSameVersion(
    importData: ExportData,
    currentVersion: VersionControl,
    result: SyncResult
  ): ImportResult {
    const importVersionControl = VersionControl.fromJSON(importData.versionControl);
    const importVersionInfo = importVersionControl.getCurrentVersion();
    const currentVersionInfo = currentVersion.getCurrentVersion();

    // 比較時間戳
    if (importVersionInfo.timestamp > currentVersionInfo.timestamp) {
      // 導入的數據更新，使用導入數據
      result.imported = importData.words.length;
    } else {
      // 當前數據更新，跳過導入
      result.skipped = importData.words.length;
    }

    return { data: importData, result };
  }

  /**
   * 壓縮數據（簡化版，實際可使用pako等庫）
   */
  compressData(data: string): string {
    // 簡化實現，實際應使用壓縮庫
    return data;
  }

  /**
   * 解壓數據（簡化版）
   */
  decompressData(data: string): string {
    // 簡化實現，實際應使用壓縮庫
    return data;
  }

  /**
   * 驗證導出數據
   */
  validateExportData(data: ExportData): boolean {
    // 檢查必要字段
    if (data.version === undefined || data.version === '') {
      return false;
    }
    if (data.timestamp === undefined || data.timestamp <= 0) {
      return false;
    }
    if (data.words === undefined || !Array.isArray(data.words)) {
      return false;
    }

    // 檢查單詞數據
    for (const word of data.words) {
      if (word.word === undefined || word.word === '') {
        return false;
      }
    }

    return true;
  }

  /**
   * 生成導出文件名
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
   * 計算數據大小
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
   * 導出統計信息
   */
  getExportStats(data: ExportData): string {
    const wordCount = data.words.length;
    const definitionCount = data.definitions.length;
    const dataSize = this.calculateDataSize(data.toJSON());

    return `单詞: ${wordCount}, 定義: ${definitionCount}, 大小: ${dataSize}`;
  }
}