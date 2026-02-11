import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import type common from '@ohos.app.ability.common';

/**
 * 日志级别枚举
 */
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

/**
 * 日志条目
 */
export interface LogEntry {
  timestamp: number;
  level: LogLevel;
  tag: string;
  message: string;
  data?: string;
}

/**
 * 日志导出数据结构
 */
interface LogExportData {
  exportTime: string;
  totalCount: number;
  logs: LogEntry[];
}

/**
 * 日志统计数据结构
 */
export interface LogStats {
  total: number;
  debug: number;
  info: number;
  warn: number;
  error: number;
}

/**
 * 日志配置
 */
interface LoggerConfig {
  minLevel: LogLevel;
  maxCacheSize: number;
  enableConsole: boolean;
  enablePersistence: boolean;
}

/**
 * 统一日志管理器
 * 
 * 功能：
 * 1. 分级日志：DEBUG/INFO/WARN/ERROR
 * 2. 内存缓存：限制条数，自动清理
 * 3. 环境感知：开发/生产自动切换级别
 * 4. 导出功能：支持导出日志给开发者
 * 5. 持久化：可选保存到 Preferences
 */
export class Logger {
  private static instance: Logger | null = null;
  
  private logCache: LogEntry[] = [];
  private readonly MAX_CACHE_SIZE = 500;
  
  private config: LoggerConfig = {
    minLevel: LogLevel.DEBUG, // 开发环境默认 DEBUG
    maxCacheSize: 500,
    enableConsole: true,
    enablePersistence: false
  };
  
  private initialized = false;
  
  private constructor() {}
  
  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }
  
  /**
   * 初始化日志管理器
   * @param isProduction 是否为生产环境
   */
  async initialize(isProduction: boolean = false): Promise<void> {
    if (this.initialized) return;
    
    // 生产环境提高日志级别，减少输出
    if (isProduction) {
      this.config.minLevel = LogLevel.WARN;
      this.config.enableConsole = false; // 生产环境关闭控制台输出
    }
    
    // 从存储加载配置
    try {
      const context = getContext(this);
      const pref = preferences.getPreferencesSync(context, { name: 'logger_config' });
      const savedLevel = pref.get('minLevel', this.config.minLevel);
      if (typeof savedLevel === 'number') {
        this.config.minLevel = savedLevel;
      }
    } catch (e) {
      // 使用默认配置
    }

    this.config.maxCacheSize = this.normalizeCacheSize(this.config.maxCacheSize);
    
    this.initialized = true;
    this.info('Logger', '日志管理器初始化完成', `环境: ${isProduction ? '生产' : '开发'}`);
  }
  
  /**
   * 设置最小日志级别
   */
  setMinLevel(level: LogLevel): void {
    this.config.minLevel = level;
    this.saveConfig();
  }

  setMaxCacheSize(maxCacheSize: number): void {
    this.config.maxCacheSize = this.normalizeCacheSize(maxCacheSize);
  }
  
  /**
   * 获取最小日志级别
   */
  getMinLevel(): LogLevel {
    return this.config.minLevel;
  }

  getMaxCacheSize(): number {
    return this.config.maxCacheSize;
  }
  
  /**
   * 记录 DEBUG 日志
   */
  debug(tag: string, message: string, data?: string): void {
    this.log(LogLevel.DEBUG, tag, message, data);
  }
  
  /**
   * 记录 INFO 日志
   */
  info(tag: string, message: string, data?: string): void {
    this.log(LogLevel.INFO, tag, message, data);
  }
  
  /**
   * 记录 WARN 日志
   */
  warn(tag: string, message: string, data?: string): void {
    this.log(LogLevel.WARN, tag, message, data);
  }
  
  /**
   * 记录 ERROR 日志
   */
  error(tag: string, message: string, data?: string): void {
    this.log(LogLevel.ERROR, tag, message, data);
  }
  
  /**
   * 核心日志方法
   */
  private log(level: LogLevel, tag: string, message: string, data?: string): void {
    // 检查级别
    if (level < this.config.minLevel) return;
    
    const entry: LogEntry = {
      timestamp: Date.now(),
      level,
      tag,
      message,
      data
    };
    
    // 添加到缓存
    this.addToCache(entry);
    
    // 控制台输出
    if (this.config.enableConsole) {
      this.outputToConsole(entry);
    }
  }
  
  /**
   * 添加到缓存（环形缓冲区）
   */
  private addToCache(entry: LogEntry): void {
    this.logCache.push(entry);
    
    // 超出限制时移除最旧的
    if (this.logCache.length > this.config.maxCacheSize) {
      this.logCache.shift();
    }
  }

  private normalizeCacheSize(maxCacheSize: number): number {
    const normalized = Math.max(1, Math.floor(maxCacheSize));
    return Math.min(normalized, this.MAX_CACHE_SIZE);
  }

  /**
   * 输出到控制台
   */
  private outputToConsole(entry: LogEntry): void {
    const timeStr = new Date(entry.timestamp).toLocaleTimeString();
    const levelStr = LogLevel[entry.level];
    const logMessage = `[${timeStr}][${levelStr}][${entry.tag}] ${entry.message}`;
    switch (entry.level) {
      case LogLevel.DEBUG:
        console.debug(logMessage, entry.data || '');
        break;
      case LogLevel.INFO:
        console.info(logMessage, entry.data || '');
        break;
      case LogLevel.WARN:
        console.warn(logMessage, entry.data || '');
        break;
      case LogLevel.ERROR:
        console.error(logMessage, entry.data || '');
        break;
    }
  }
  
  /**
   * 获取所有日志
   */
  getLogs(): LogEntry[] {
    return [...this.logCache];
  }
  
  /**
   * 获取最近 N 条日志
   */
  getRecentLogs(count: number): LogEntry[] {
    return this.logCache.slice(-count);
  }
  
  /**
   * 按级别获取日志
   */
  getLogsByLevel(level: LogLevel): LogEntry[] {
    return this.logCache.filter(log => log.level === level);
  }
  
  /**
   * 清空日志缓存
   */
  clearLogs(): void {
    this.logCache = [];
    this.info('Logger', '日志缓存已清空');
  }
  
  /**
   * 导出日志为 JSON 字符串
   */
  exportToJson(): string {
    const exportData: LogExportData = {
      exportTime: new Date().toISOString(),
      totalCount: this.logCache.length,
      logs: this.logCache
    };
    return JSON.stringify(exportData, null, 2);
  }
  
  /**
   * 导出日志为文本格式
   */
  exportToText(): string {
    return this.logCache.map(entry => {
      const timeStr = new Date(entry.timestamp).toLocaleString();
      const levelStr = LogLevel[entry.level];
      let line = `[${timeStr}][${levelStr}][${entry.tag}] ${entry.message}`;
      if (entry.data) {
        line += ` | ${entry.data}`;
      }
      return line;
    }).join('\n');
  }
  
  /**
   * 获取日志统计
   */
  getStats(): LogStats {
    const stats: LogStats = {
      total: this.logCache.length,
      debug: this.logCache.filter(l => l.level === LogLevel.DEBUG).length,
      info: this.logCache.filter(l => l.level === LogLevel.INFO).length,
      warn: this.logCache.filter(l => l.level === LogLevel.WARN).length,
      error: this.logCache.filter(l => l.level === LogLevel.ERROR).length
    };
    return stats;
  }
  
  /**
   * 导出日志到文件
   */
  async exportToFile(): Promise<string> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const filesDir = context.filesDir;
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `vignette_logs_${timestamp}.txt`;
      const filePath = `${filesDir}/${fileName}`;
      
      const logs = this.exportToText();
      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, logs);
      fileIo.closeSync(file);
      
      this.info('Logger', `日志已导出到文件`, filePath);
      return filePath;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      this.error('Logger', '导出日志到文件失败', errMsg);
      throw new Error(`导出日志失败: ${errMsg}`);
    }
  }

  /**
   * 保存配置
   */
  private saveConfig(): void {
    try {
      const context = getContext(this);
      const pref = preferences.getPreferencesSync(context, { name: 'logger_config' });
      pref.put('minLevel', this.config.minLevel);
      pref.flush();
    } catch (e) {
      // 忽略保存错误
    }
  }
}

/**
 * 便捷导出
 */
export const logger = Logger.getInstance();

/**
 * 日志标签接口
 */
export interface LogTagsInterface {
  APP: string;
  UI: string;
  DB: string;
  SYNC: string;
  AI: string;
  FSRS: string;
  CACHE: string;
  NETWORK: string;
  STORAGE: string;
}

/**
 * 日志标签常量
 */
export const LogTags: LogTagsInterface = {
  APP: 'App',
  UI: 'UI',
  DB: 'Database',
  SYNC: 'Sync',
  AI: 'AI',
  FSRS: 'FSRS',
  CACHE: 'Cache',
  NETWORK: 'Network',
  STORAGE: 'Storage'
};
