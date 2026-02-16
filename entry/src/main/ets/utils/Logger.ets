import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import type common from '@ohos.app.ability.common';
import deviceInfo from '@ohos.deviceInfo';
import { display } from '@kit.ArkUI';

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

export interface LogEntry {
  timestamp: number;
  level: LogLevel;
  tag: string;
  message: string;
  data?: string;
  stack?: string;
  repeatCount: number;
  firstTimestamp: number;
}

interface LogExportData {
  exportTime: string;
  deviceInfo: DeviceInfoData;
  totalCount: number;
  logs: LogEntry[];
}

export interface LogStats {
  total: number;
  debug: number;
  info: number;
  warn: number;
  error: number;
}

export interface TagLogStat {
  tag: string;
  total: number;
  error: number;
  warn: number;
}

export interface ErrorFingerprint {
  key: string;
  tag: string;
  message: string;
  count: number;
  latestTimestamp: number;
}

interface LoggerConfig {
  minLevel: LogLevel;
  maxCacheSize: number;
  enableConsole: boolean;
  enablePersistence: boolean;
  persistenceIncludeInfo: boolean;
  persistenceMaxBytes: number;
  preloadRecentCount: number;
}

interface PersistedLogLine {
  timestamp: number;
  level: number;
  tag: string;
  message: string;
  data?: string;
  stack?: string;
  repeatCount?: number;
  firstTimestamp?: number;
}

interface PersistedFileMeta {
  path: string;
  dateKey: string;
  size: number;
  updatedAt: number;
}

interface DeviceInfoData {
  deviceModel: string;
  osVersion: string;
  apiVersion: number;
  appVersion: string;
  screenWidth: number;
  screenHeight: number;
}

interface PerformanceTimer {
  startTime: number;
  tag: string;
}

export class Logger {
  private static instance: Logger | null = null;
  
  private logCache: LogEntry[] = [];
  private readonly MAX_CACHE_SIZE = 500;
  private readonly MERGE_WINDOW_MS = 1500;
  private readonly MAX_PERSISTENCE_BYTES = 5 * 1024 * 1024;
  private readonly MIN_PERSISTENCE_BYTES = 1 * 1024 * 1024;
  private readonly MAX_PRELOAD_RECENT_COUNT = 500;
  private readonly PERSISTENCE_PREF_KEY = 'logger_config';
  private readonly PERSISTENCE_DIR_NAME = 'logger';
  private readonly META_PREF_KEY = 'persistenceMeta';
  private performanceTimers: Map<string, PerformanceTimer> = new Map();
  private deviceInfo: DeviceInfoData | null = null;
  private appVersion: string = '1.0.0';
  private filesDir: string = '';
  private appContext: common.UIAbilityContext | null = null;
  private persistenceMeta: PersistedFileMeta[] = [];
  
  private config: LoggerConfig = {
    minLevel: LogLevel.DEBUG,
    maxCacheSize: 500,
    enableConsole: true,
    enablePersistence: false,
    persistenceIncludeInfo: false,
    persistenceMaxBytes: 2 * 1024 * 1024,
    preloadRecentCount: 120
  };
  
  private initialized = false;
  
  private constructor() {}
  
  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }
  
  async initialize(context: common.UIAbilityContext, isProduction: boolean = false): Promise<void> {
    if (this.initialized) return;
    
    if (isProduction) {
      this.config.minLevel = LogLevel.WARN;
      this.config.enableConsole = false;
    }
    
    try {
      const pref = preferences.getPreferencesSync(context, { name: this.PERSISTENCE_PREF_KEY });
      const savedLevel = pref.get('minLevel', this.config.minLevel);
      if (typeof savedLevel === 'number') {
        this.config.minLevel = savedLevel;
      }
      const savedEnablePersistence = pref.get('enablePersistence', this.config.enablePersistence);
      if (typeof savedEnablePersistence === 'boolean') {
        this.config.enablePersistence = savedEnablePersistence;
      }
      const savedIncludeInfo = pref.get('persistenceIncludeInfo', this.config.persistenceIncludeInfo);
      if (typeof savedIncludeInfo === 'boolean') {
        this.config.persistenceIncludeInfo = savedIncludeInfo;
      }
      const savedMaxBytes = pref.get('persistenceMaxBytes', this.config.persistenceMaxBytes);
      if (typeof savedMaxBytes === 'number') {
        this.config.persistenceMaxBytes = savedMaxBytes;
      }
      const savedPreloadCount = pref.get('preloadRecentCount', this.config.preloadRecentCount);
      if (typeof savedPreloadCount === 'number') {
        this.config.preloadRecentCount = savedPreloadCount;
      }
      const savedMeta = pref.get(this.META_PREF_KEY, '[]');
      if (typeof savedMeta === 'string' && savedMeta.length > 0) {
        this.persistenceMeta = this.parseMeta(savedMeta);
      }
    } catch (e) {
      // 使用默认配置
    }

    this.config.maxCacheSize = this.normalizeCacheSize(this.config.maxCacheSize);
    this.config.persistenceMaxBytes = this.normalizePersistenceBytes(this.config.persistenceMaxBytes);
    this.config.preloadRecentCount = this.normalizePreloadCount(this.config.preloadRecentCount);
    this.filesDir = context.filesDir;
    this.appContext = context;
    this.collectDeviceInfo(context);
    this.loadPersistedLogsToCache();
    
    this.initialized = true;
    this.info('Logger', '日志管理器初始化完成', `环境: ${isProduction ? '生产' : '开发'}`);
  }

  setAppVersion(version: string): void {
    this.appVersion = version;
  }
  
  private collectDeviceInfo(context: common.UIAbilityContext): void {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.deviceInfo = {
        deviceModel: deviceInfo.productModel || 'Unknown',
        osVersion: deviceInfo.osFullName || 'Unknown',
        apiVersion: deviceInfo.sdkApiVersion || 0,
        appVersion: this.appVersion,
        screenWidth: displayInfo.width,
        screenHeight: displayInfo.height
      };
    } catch (e) {
      this.deviceInfo = {
        deviceModel: 'Unknown',
        osVersion: 'Unknown',
        apiVersion: 0,
        appVersion: this.appVersion,
        screenWidth: 0,
        screenHeight: 0
      };
    }
  }

  getDeviceInfo(): DeviceInfoData {
    if (!this.deviceInfo) {
      return {
        deviceModel: 'Unknown',
        osVersion: 'Unknown',
        apiVersion: 0,
        appVersion: this.appVersion,
        screenWidth: 0,
        screenHeight: 0
      };
    }
    return this.deviceInfo;
  }
  
  setMinLevel(level: LogLevel, context?: common.UIAbilityContext): void {
    this.config.minLevel = level;
    if (context) {
      this.saveConfig(context);
    }
  }

  setMaxCacheSize(maxCacheSize: number): void {
    this.config.maxCacheSize = this.normalizeCacheSize(maxCacheSize);
  }
  
  getMinLevel(): LogLevel {
    return this.config.minLevel;
  }

  getMaxCacheSize(): number {
    return this.config.maxCacheSize;
  }

  setEnablePersistence(enabled: boolean, context?: common.UIAbilityContext): void {
    this.config.enablePersistence = enabled;
    if (context) {
      this.saveConfig(context);
    }
  }

  isPersistenceEnabled(): boolean {
    return this.config.enablePersistence;
  }

  setPersistenceIncludeInfo(enabled: boolean, context?: common.UIAbilityContext): void {
    this.config.persistenceIncludeInfo = enabled;
    if (context) {
      this.saveConfig(context);
    }
  }

  getPersistenceIncludeInfo(): boolean {
    return this.config.persistenceIncludeInfo;
  }

  setPersistenceMaxBytes(maxBytes: number, context?: common.UIAbilityContext): void {
    this.config.persistenceMaxBytes = this.normalizePersistenceBytes(maxBytes);
    if (context) {
      this.saveConfig(context);
    }
  }

  getPersistenceMaxBytes(): number {
    return this.config.persistenceMaxBytes;
  }

  getPersistenceMaxBytesInMB(): number {
    return Math.max(1, Math.round(this.config.persistenceMaxBytes / (1024 * 1024)));
  }

  setPersistenceMaxBytesInMB(mb: number, context?: common.UIAbilityContext): void {
    const normalizedMb = Math.max(1, Math.min(5, Math.floor(mb)));
    this.setPersistenceMaxBytes(normalizedMb * 1024 * 1024, context);
  }
  
  debug(tag: string, message: string, data?: string | Record<string, Object>): void {
    this.log(LogLevel.DEBUG, tag, message, data);
  }
  
  info(tag: string, message: string, data?: string | Record<string, Object>): void {
    this.log(LogLevel.INFO, tag, message, data);
  }
  
  warn(tag: string, message: string, data?: string | Record<string, Object>): void {
    this.log(LogLevel.WARN, tag, message, data);
  }
  
  error(tag: string, message: string, error?: Error | string | Record<string, Object>): void {
    let data: string | undefined;
    let stack: string | undefined;
    
    if (error instanceof Error) {
      data = error.message;
      stack = error.stack;
    } else if (typeof error === 'string') {
      data = error;
    } else if (error !== undefined) {
      try {
        data = JSON.stringify(error);
      } catch (e) {
        data = String(error);
      }
    }
    
    this.logWithStack(LogLevel.ERROR, tag, message, data, stack);
  }

  time(label: string, tag: string = 'Performance'): void {
    this.performanceTimers.set(label, {
      startTime: Date.now(),
      tag
    });
  }

  timeEnd(label: string, tag: string = 'Performance'): number {
    const timer = this.performanceTimers.get(label);
    if (!timer) {
      this.warn('Logger', `Timer '${label}' does not exist`);
      return 0;
    }
    
    const duration = Date.now() - timer.startTime;
    this.performanceTimers.delete(label);
    
    this.log(LogLevel.INFO, timer.tag, `${label} 完成`, `${duration}ms`);
    return duration;
  }

  timeEndWarn(label: string, thresholdMs: number, tag: string = 'Performance'): number {
    const timer = this.performanceTimers.get(label);
    if (!timer) {
      this.warn('Logger', `Timer '${label}' does not exist`);
      return 0;
    }
    
    const duration = Date.now() - timer.startTime;
    this.performanceTimers.delete(label);
    
    if (duration > thresholdMs) {
      this.log(LogLevel.WARN, timer.tag, `${label} 慢操作警告`, `${duration}ms (阈值: ${thresholdMs}ms)`);
    } else {
      this.log(LogLevel.DEBUG, timer.tag, `${label} 完成`, `${duration}ms`);
    }
    return duration;
  }
  
  private log(level: LogLevel, tag: string, message: string, data?: string | Record<string, Object>): void {
    if (level < this.config.minLevel) return;
    
    let dataStr: string | undefined;
    if (data !== undefined) {
      if (typeof data === 'string') {
        dataStr = data;
      } else {
        try {
          dataStr = JSON.stringify(data);
        } catch (e) {
          dataStr = String(data);
        }
      }
    }
    
    const now = Date.now();
    const entry: LogEntry = {
      timestamp: now,
      level,
      tag,
      message,
      data: dataStr,
      repeatCount: 1,
      firstTimestamp: now
    };
    
    const outputEntry = this.addToCache(entry);
    
    if (this.config.enableConsole) {
      this.outputToConsole(outputEntry);
    }
    this.persistIfNeeded(outputEntry);
  }

  private logWithStack(level: LogLevel, tag: string, message: string, data?: string, stack?: string): void {
    if (level < this.config.minLevel) return;
    
    const now = Date.now();
    const entry: LogEntry = {
      timestamp: now,
      level,
      tag,
      message,
      data,
      stack,
      repeatCount: 1,
      firstTimestamp: now
    };
    
    const outputEntry = this.addToCache(entry);
    
    if (this.config.enableConsole) {
      this.outputToConsole(outputEntry);
      if (stack) {
        console.error(`Stack trace:\n${stack}`);
      }
    }
    this.persistIfNeeded(outputEntry);
  }
  
  private addToCache(entry: LogEntry): LogEntry {
    const lastIndex = this.logCache.length - 1;
    if (lastIndex >= 0) {
      const last = this.logCache[lastIndex];
      const sameEntry = last.level === entry.level
        && last.tag === entry.tag
        && last.message === entry.message
        && (last.data ?? '') === (entry.data ?? '')
        && (last.stack ?? '') === (entry.stack ?? '');
      const withinWindow = entry.timestamp - last.timestamp <= this.MERGE_WINDOW_MS;
      if (sameEntry && withinWindow) {
        last.repeatCount += 1;
        last.timestamp = entry.timestamp;
        return last;
      }
    }

    this.logCache.push(entry);

    if (this.logCache.length > this.config.maxCacheSize) {
      this.logCache.shift();
    }

    return entry;
  }

  private normalizeCacheSize(maxCacheSize: number): number {
    const normalized = Math.max(1, Math.floor(maxCacheSize));
    return Math.min(normalized, this.MAX_CACHE_SIZE);
  }

  private normalizePersistenceBytes(maxBytes: number): number {
    const normalized = Math.max(this.MIN_PERSISTENCE_BYTES, Math.floor(maxBytes));
    return Math.min(normalized, this.MAX_PERSISTENCE_BYTES);
  }

  private normalizePreloadCount(count: number): number {
    const normalized = Math.max(20, Math.floor(count));
    return Math.min(normalized, this.MAX_PRELOAD_RECENT_COUNT);
  }

  private shouldPersist(level: LogLevel): boolean {
    if (!this.config.enablePersistence) {
      return false;
    }
    if (level === LogLevel.ERROR || level === LogLevel.WARN) {
      return true;
    }
    return level === LogLevel.INFO && this.config.persistenceIncludeInfo;
  }

  private getPersistenceDateKey(ts: number): string {
    const d = new Date(ts);
    const y = String(d.getFullYear());
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}${m}${day}`;
  }

  private getPersistenceDirPath(): string {
    return `${this.filesDir}/${this.PERSISTENCE_DIR_NAME}`;
  }

  private buildPersistenceFilePath(dateKey: string): string {
    return `${this.getPersistenceDirPath()}/vignette_${dateKey}.jsonl`;
  }

  private ensurePersistenceDir(): void {
    if (this.filesDir.length === 0) {
      return;
    }
    const dirPath = this.getPersistenceDirPath();
    try {
      if (!fileIo.accessSync(dirPath)) {
        fileIo.mkdirSync(dirPath, true);
      }
    } catch (e) {}
  }

  private sanitizeText(value: string): string {
    let sanitized = value;
    const pairPattern = /((token|password|authorization|access_token|refresh_token)\s*[=:]\s*)([^\s,;"'\]\}]+)/gi;
    sanitized = sanitized.replace(pairPattern, '$1***');
    const jsonPattern = /("(token|password|authorization|access_token|refresh_token)"\s*:\s*")(.*?)(")/gi;
    sanitized = sanitized.replace(jsonPattern, '$1***$4');
    const bearerPattern = /(bearer\s+)([A-Za-z0-9\-._~+/]+=*)/gi;
    sanitized = sanitized.replace(bearerPattern, '$1***');
    return sanitized;
  }

  private sanitizeEntry(entry: LogEntry): LogEntry {
    return {
      ...entry,
      message: this.sanitizeText(entry.message),
      data: entry.data ? this.sanitizeText(entry.data) : undefined,
      stack: entry.stack ? this.sanitizeText(entry.stack) : undefined
    };
  }

  private persistIfNeeded(entry: LogEntry): void {
    if (!this.shouldPersist(entry.level) || this.filesDir.length === 0) {
      return;
    }
    this.ensurePersistenceDir();
    const dateKey = this.getPersistenceDateKey(entry.timestamp);
    const filePath = this.buildPersistenceFilePath(dateKey);
    const sanitized = this.sanitizeEntry(entry);
    const line = `${JSON.stringify(sanitized)}\n`;
    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
      fileIo.writeSync(file.fd, line);
      const size = fileIo.statSync(file.fd).size;
      fileIo.closeSync(file);
      this.updateMeta(filePath, dateKey, size, entry.timestamp);
      this.trimPersistenceFiles();
      if (this.appContext) {
        this.saveConfig(this.appContext);
      }
    } catch (e) {
      // 忽略落盘失败，避免影响主流程
    }
  }

  private updateMeta(path: string, dateKey: string, size: number, updatedAt: number): void {
    const index = this.persistenceMeta.findIndex((meta: PersistedFileMeta): boolean => meta.path === path);
    if (index >= 0) {
      this.persistenceMeta[index] = { path, dateKey, size, updatedAt };
    } else {
      this.persistenceMeta.push({ path, dateKey, size, updatedAt });
    }
    this.persistenceMeta.sort((a: PersistedFileMeta, b: PersistedFileMeta): number => a.updatedAt - b.updatedAt);
  }

  private trimPersistenceFiles(): void {
    let total = this.persistenceMeta.reduce((sum: number, item: PersistedFileMeta): number => sum + Math.max(0, item.size), 0);
    while (total > this.config.persistenceMaxBytes && this.persistenceMeta.length > 1) {
      const oldest = this.persistenceMeta.shift();
      if (oldest === undefined) {
        break;
      }
      try {
        fileIo.unlinkSync(oldest.path);
      } catch (e) {}
      total -= Math.max(0, oldest.size);
    }
  }

  private parseMeta(raw: string): PersistedFileMeta[] {
    try {
      const arr = JSON.parse(raw) as PersistedFileMeta[];
      const valid: PersistedFileMeta[] = [];
      for (const item of arr) {
        if (typeof item.path === 'string' && typeof item.dateKey === 'string' && typeof item.size === 'number' && typeof item.updatedAt === 'number') {
          valid.push(item);
        }
      }
      valid.sort((a: PersistedFileMeta, b: PersistedFileMeta): number => a.updatedAt - b.updatedAt);
      return valid;
    } catch (e) {
      return [];
    }
  }

  private loadPersistedLogsToCache(): void {
    if (this.persistenceMeta.length === 0) {
      return;
    }
    const loaded: LogEntry[] = [];
    for (let i = this.persistenceMeta.length - 1; i >= 0; i--) {
      if (loaded.length >= this.config.preloadRecentCount) {
        break;
      }
      const fileMeta = this.persistenceMeta[i];
      const fileLogs = this.readJsonlFile(fileMeta.path);
      for (let j = fileLogs.length - 1; j >= 0; j--) {
        loaded.push(fileLogs[j]);
        if (loaded.length >= this.config.preloadRecentCount) {
          break;
        }
      }
    }
    loaded.reverse();
    for (const entry of loaded) {
      this.addToCache(entry);
    }
  }

  private readJsonlFile(path: string): LogEntry[] {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const size = fileIo.statSync(file.fd).size;
      if (size <= 0) {
        fileIo.closeSync(file);
        return [];
      }
      const buf = new ArrayBuffer(size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const bytes = new Uint8Array(buf);
      let content = '';
      for (let i = 0; i < bytes.length; i++) {
        content += String.fromCharCode(bytes[i]);
      }
      const lines = content.split('\n').filter((line: string): boolean => line.length > 0);
      const result: LogEntry[] = [];
      for (const line of lines) {
        try {
          const parsed = JSON.parse(line) as PersistedLogLine;
          if (typeof parsed.timestamp !== 'number' || typeof parsed.level !== 'number' || typeof parsed.tag !== 'string' || typeof parsed.message !== 'string') {
            continue;
          }
          result.push({
            timestamp: parsed.timestamp,
            level: parsed.level as LogLevel,
            tag: parsed.tag,
            message: parsed.message,
            data: typeof parsed.data === 'string' ? parsed.data : undefined,
            stack: typeof parsed.stack === 'string' ? parsed.stack : undefined,
            repeatCount: typeof parsed.repeatCount === 'number' ? Math.max(1, Math.floor(parsed.repeatCount)) : 1,
            firstTimestamp: typeof parsed.firstTimestamp === 'number' ? parsed.firstTimestamp : parsed.timestamp
          });
        } catch (e) {}
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  private outputToConsole(entry: LogEntry): void {
    const timeStr = new Date(entry.timestamp).toLocaleTimeString();
    const levelStr = LogLevel[entry.level];
    const repeatSuffix = entry.repeatCount > 1 ? ` (x${entry.repeatCount})` : '';
    const logMessage = `[${timeStr}][${levelStr}][${entry.tag}] ${entry.message}${repeatSuffix}`;
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
  
  getLogs(): LogEntry[] {
    return [...this.logCache];
  }
  
  getRecentLogs(count: number): LogEntry[] {
    return this.logCache.slice(-count);
  }
  
  getLogsByLevel(level: LogLevel): LogEntry[] {
    return this.logCache.filter(log => log.level === level);
  }

  searchLogs(keyword: string, level?: LogLevel): LogEntry[] {
    const lowerKeyword = keyword.toLowerCase();
    return this.logCache.filter(log => {
      const matchLevel = level === undefined || log.level === level;
      const matchKeyword = log.message.toLowerCase().includes(lowerKeyword) ||
        log.tag.toLowerCase().includes(lowerKeyword) ||
        (log.data !== undefined && log.data.toLowerCase().includes(lowerKeyword)) ||
        (log.stack !== undefined && log.stack.toLowerCase().includes(lowerKeyword));
      return matchLevel && matchKeyword;
    });
  }
  
  clearLogs(): void {
    this.logCache = [];
    this.performanceTimers.clear();
  }
  
  exportToJson(): string {
    const exportData: LogExportData = {
      exportTime: new Date().toISOString(),
      deviceInfo: this.getDeviceInfo(),
      totalCount: this.getStats().total,
      logs: this.logCache
    };
    return JSON.stringify(exportData, null, 2);
  }
  
  exportToText(): string {
    const device = this.getDeviceInfo();
    const header = [
      '═══════════════════════════════════════',
      'Vignette 日志导出',
      '═══════════════════════════════════════',
      `导出时间: ${new Date().toLocaleString()}`,
      `设备型号: ${device.deviceModel}`,
      `系统版本: ${device.osVersion}`,
      `API版本: ${device.apiVersion}`,
      `应用版本: ${device.appVersion}`,
      `屏幕尺寸: ${device.screenWidth}x${device.screenHeight}`,
      `日志条数: ${this.getStats().total} (合并后 ${this.logCache.length} 条)`,
      '═══════════════════════════════════════',
      ''
    ].join('\n');

    const logs = this.logCache.map(entry => {
      const timeStr = new Date(entry.timestamp).toLocaleString();
      const levelStr = LogLevel[entry.level];
      const repeatSuffix = entry.repeatCount > 1 ? ` (x${entry.repeatCount})` : '';
      let line = `[${timeStr}][${levelStr}][${entry.tag}] ${entry.message}${repeatSuffix}`;
      if (entry.data) {
        line += `\n  数据: ${entry.data}`;
      }
      if (entry.stack) {
        line += `\n  堆栈:\n    ${entry.stack.replace(/\n/g, '\n    ')}`;
      }
      return line;
    }).join('\n\n');

    return header + logs;
  }

  generateDiagnosticReport(): string {
    const device = this.getDeviceInfo();
    const stats = this.getStats();
    const recentErrors = this.getLogsByLevel(LogLevel.ERROR).slice(-10);
    const recentWarns = this.getLogsByLevel(LogLevel.WARN).slice(-10);
    const tagStats = this.getTagStats(5);
    const fingerprints = this.getErrorFingerprints(5);

    const report = [
      '═══════════════════════════════════════════════════════════',
      'Vignette 诊断报告',
      '═══════════════════════════════════════════════════════════',
      '',
      '【设备信息】',
      `  设备型号: ${device.deviceModel}`,
      `  系统版本: ${device.osVersion}`,
      `  API版本: ${device.apiVersion}`,
      `  应用版本: ${device.appVersion}`,
      `  屏幕尺寸: ${device.screenWidth}x${device.screenHeight}`,
      '',
      '【日志统计】',
      `  总条数: ${stats.total}`,
      `  错误: ${stats.error}`,
      `  警告: ${stats.warn}`,
      `  信息: ${stats.info}`,
      `  调试: ${stats.debug}`,
      '',
      '【高频模块 (Top 5)】',
      ...tagStats.map(t => `  ${t.tag}: 总计 ${t.total} | 错误 ${t.error} | 警告 ${t.warn}`),
      tagStats.length === 0 ? '  暂无日志' : '',
      '',
      '【高频告警/错误模式 (Top 5)】',
      ...fingerprints.map(f => `  [${f.tag}] ${f.message} (x${f.count})`),
      fingerprints.length === 0 ? '  暂无告警或错误' : '',
      '',
      '【最近错误 (最多10条)】',
      ...recentErrors.map(e => {
        const time = new Date(e.timestamp).toLocaleString();
        return `  [${time}][${e.tag}] ${e.message}${e.data ? `\n    数据: ${e.data}` : ''}${e.stack ? `\n    堆栈: ${e.stack.split('\n').slice(0, 3).join('\n    ')}` : ''}`;
      }),
      recentErrors.length === 0 ? '  无错误记录' : '',
      '',
      '【最近警告 (最多10条)】',
      ...recentWarns.map(w => {
        const time = new Date(w.timestamp).toLocaleString();
        return `  [${time}][${w.tag}] ${w.message}${w.data ? `\n    数据: ${w.data}` : ''}`;
      }),
      recentWarns.length === 0 ? '  无警告记录' : '',
      '',
      '═══════════════════════════════════════════════════════════',
      '请将此报告发送给开发者以帮助诊断问题',
      '═══════════════════════════════════════════════════════════'
    ].filter(line => line !== undefined).join('\n');

    return report;
  }
  
  getTagStats(limit: number = 10): TagLogStat[] {
    const map = new Map<string, TagLogStat>();
    for (const entry of this.logCache) {
      const stat = map.get(entry.tag) ?? { tag: entry.tag, total: 0, error: 0, warn: 0 };
      const count = Math.max(1, entry.repeatCount);
      stat.total += count;
      if (entry.level === LogLevel.ERROR) {
        stat.error += count;
      } else if (entry.level === LogLevel.WARN) {
        stat.warn += count;
      }
      map.set(entry.tag, stat);
    }
    const out = Array.from(map.values());
    out.sort((a: TagLogStat, b: TagLogStat): number => b.total - a.total);
    return out.slice(0, Math.max(1, limit));
  }

  getErrorFingerprints(limit: number = 10): ErrorFingerprint[] {
    const map = new Map<string, ErrorFingerprint>();
    for (const entry of this.logCache) {
      if (entry.level !== LogLevel.ERROR && entry.level !== LogLevel.WARN) {
        continue;
      }
      const key = `${entry.tag}|${entry.message}`;
      const count = Math.max(1, entry.repeatCount);
      const current = map.get(key);
      if (current === undefined) {
        map.set(key, {
          key,
          tag: entry.tag,
          message: entry.message,
          count,
          latestTimestamp: entry.timestamp
        });
      } else {
        current.count += count;
        current.latestTimestamp = Math.max(current.latestTimestamp, entry.timestamp);
      }
    }
    const out = Array.from(map.values());
    out.sort((a: ErrorFingerprint, b: ErrorFingerprint): number => b.count - a.count);
    return out.slice(0, Math.max(1, limit));
  }

  getStats(): LogStats {
    const stats: LogStats = {
      total: 0,
      debug: 0,
      info: 0,
      warn: 0,
      error: 0
    };

    for (const log of this.logCache) {
      const count = Math.max(1, log.repeatCount);
      stats.total += count;
      if (log.level === LogLevel.DEBUG) {
        stats.debug += count;
      } else if (log.level === LogLevel.INFO) {
        stats.info += count;
      } else if (log.level === LogLevel.WARN) {
        stats.warn += count;
      } else if (log.level === LogLevel.ERROR) {
        stats.error += count;
      }
    }

    return stats;
  }
  
  async exportToFile(context: common.UIAbilityContext): Promise<string> {
    try {
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

  saveConfig(context: common.UIAbilityContext): void {
    try {
      const pref = preferences.getPreferencesSync(context, { name: this.PERSISTENCE_PREF_KEY });
      pref.put('minLevel', this.config.minLevel);
      pref.put('enablePersistence', this.config.enablePersistence);
      pref.put('persistenceIncludeInfo', this.config.persistenceIncludeInfo);
      pref.put('persistenceMaxBytes', this.config.persistenceMaxBytes);
      pref.put('preloadRecentCount', this.config.preloadRecentCount);
      pref.put(this.META_PREF_KEY, JSON.stringify(this.persistenceMeta));
      pref.flush();
    } catch (e) {
      // 忽略保存错误
    }
  }
}

export const logger = Logger.getInstance();

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
