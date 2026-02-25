// =====================================================
// Logger.ets - 统一的日志管理工具
// 提供分级日志、生产环境禁用、日志格式化功能
// =====================================================

/**
 * 日志级别
 */
export enum LogLevel {
  VERBOSE = 0,  // 详细日志
  DEBUG = 1,    // 调试信息
  INFO = 2,     // 一般信息
  WARN = 3,     // 警告
  ERROR = 4,    // 错误
  NONE = 5      // 禁用所有日志
}

/**
 * 日志配置
 */
export interface LoggerConfig {
  minLevel: LogLevel;        // 最低日志级别
  enableTimestamp: boolean;  // 是否显示时间戳
  enableTag: boolean;        // 是否显示标签
  productionMode: boolean;   // 生产模式（禁用 DEBUG/VERBOSE）
}

/**
 * 默认配置
 */
const DEFAULT_CONFIG: LoggerConfig = {
  minLevel: LogLevel.INFO,
  enableTimestamp: true,
  enableTag: true,
  productionMode: false
};

/**
 * Logger 工具类
 * 
 * 使用示例:
 * ```typescript
 * const logger = new Logger('MyComponent');
 * logger.info('组件已加载');
 * logger.debug('详细调试信息');
 * logger.error('发生错误', error);
 * ```
 */
export class Logger {
  private tag: string;
  private config: LoggerConfig;

  constructor(tag: string, config?: Partial<LoggerConfig>) {
    this.tag = tag;
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * 设置全局日志级别
   */
  static setGlobalLevel(level: LogLevel): void {
    DEFAULT_CONFIG.minLevel = level;
  }

  /**
   * 启用生产模式（禁用 DEBUG/VERBOSE 日志）
   */
  static enableProductionMode(): void {
    DEFAULT_CONFIG.productionMode = true;
    DEFAULT_CONFIG.minLevel = LogLevel.WARN;
  }

  /**
   * 启用调试模式
   */
  static enableDebugMode(): void {
    DEFAULT_CONFIG.productionMode = false;
    DEFAULT_CONFIG.minLevel = LogLevel.VERBOSE;
  }

  /**
   * 格式化日志消息
   */
  private formatMessage(level: string, message: string): string {
    const parts: string[] = [];

    if (this.config.enableTimestamp) {
      parts.push(`[${this.formatTimestamp()}]`);
    }

    if (this.config.enableTag) {
      parts.push(`[${this.tag}]`);
    }

    parts.push(`[${level}]`);
    parts.push(message);

    return parts.join(' ');
  }

  /**
   * 格式化时间戳
   */
  private formatTimestamp(): string {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    const ms = String(now.getMilliseconds()).padStart(3, '0');
    return `${hours}:${minutes}:${seconds}.${ms}`;
  }

  /**
   * 检查是否应该记录日志
   */
  private shouldLog(level: LogLevel): boolean {
    if (this.config.productionMode && level < LogLevel.WARN) {
      return false;
    }
    return level >= this.config.minLevel;
  }

  /**
   * 详细日志
   */
  v(message: string, ...args: unknown[]): void {
    if (!this.shouldLog(LogLevel.VERBOSE)) return;
    console.log(this.formatMessage('V', message), ...args);
  }

  /**
   * 调试日志
   */
  d(message: string, ...args: unknown[]): void {
    if (!this.shouldLog(LogLevel.DEBUG)) return;
    console.info(this.formatMessage('D', message), ...args);
  }

  /**
   * 信息日志
   */
  i(message: string, ...args: unknown[]): void {
    if (!this.shouldLog(LogLevel.INFO)) return;
    console.info(this.formatMessage('I', message), ...args);
  }

  /**
   * 警告日志
   */
  w(message: string, ...args: unknown[]): void {
    if (!this.shouldLog(LogLevel.WARN)) return;
    console.warn(this.formatMessage('W', message), ...args);
  }

  /**
   * 错误日志
   */
  e(message: string, error?: unknown): void {
    if (!this.shouldLog(LogLevel.ERROR)) return;
    
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(this.formatMessage('E', `${message}: ${errorMsg}`));
    
    // 记录错误堆栈（如果有）
    if (error instanceof Error && error.stack) {
      console.error(`[STACK] ${error.stack}`);
    }
  }

  /**
   * 性能日志（记录耗时）
   */
  performance(label: string, startTime: number): void {
    if (!this.shouldLog(LogLevel.INFO)) return;
    const elapsed = Date.now() - startTime;
    console.info(this.formatMessage('P', `${label}: ${elapsed}ms`));
  }

  /**
   * 创建子 Logger（添加子标签）
   */
  createChild(subTag: string): Logger {
    return new Logger(`${this.tag}.${subTag}`, this.config);
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<LoggerConfig>): void {
    this.config = { ...this.config, ...config };
  }
}

/**
 * 预定义的 Logger 实例（常用模块）
 */
export const Loggers = {
  app: new Logger('App'),
  db: new Logger('Database'),
  network: new Logger('Network'),
  sync: new Logger('Sync'),
  ai: new Logger('AI'),
  fsrs: new Logger('FSRS'),
  ui: new Logger('UI')
} as const;

/**
 * 日志性能监控装饰器
 * 
 * 使用示例:
 * ```typescript
 * class MyService {
 *   @LogPerformance()
 *   async loadData(): Promise<void> {
 *     // ...
 *   }
 * }
 * ```
 */
export function LogPerformance(label?: string) {
  return function (target: Object, propertyKey: string, descriptor: PropertyDescriptor) {
    const originalMethod = descriptor.value;
    const methodName = label || propertyKey;
    const logger = new Logger(target.constructor.name);

    descriptor.value = async function (...args: unknown[]) {
      const startTime = Date.now();
      logger.d(`[${methodName}] 开始执行`);
      
      try {
        const result = await originalMethod.apply(this, args);
        const elapsed = Date.now() - startTime;
        logger.d(`[${methodName}] 执行完成，耗时：${elapsed}ms`);
        return result;
      } catch (error) {
        const elapsed = Date.now() - startTime;
        logger.e(`[${methodName}] 执行失败，耗时：${elapsed}ms`, error);
        throw error;
      }
    };

    return descriptor;
  };
}
