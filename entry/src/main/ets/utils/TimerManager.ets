// =====================================================
// TimerManager.ets - 统一的定时器管理工具
// 防止内存泄漏，自动清理定时器
// =====================================================

/**
 * 定时器类型
 */
export type TimerId = number;

/**
 * 定时器管理器
 * 用于统一管理 setTimeout/setInterval，防止内存泄漏
 * 
 * 使用示例:
 * ```typescript
 * class MyComponent {
 *   private timerManager = new TimerManager();
 *   
 *   startTimer(): void {
 *     this.timerManager.setTimeout(() => {
 *       console.info('Timer triggered');
 *     }, 1000);
 *   }
 *   
 *   aboutToDisappear(): void {
 *     this.timerManager.clearAll();
 *   }
 * }
 * ```
 */
export class TimerManager {
  private timers: Set<TimerId> = new Set();
  private destroyed: boolean = false;

  /**
   * 设置超时定时器
   * @param callback 回调函数
   * @param delay 延迟时间（毫秒）
   * @returns 定时器 ID
   */
  setTimeout(callback: () => void, delay: number): TimerId {
    if (this.destroyed) {
      console.warn('[TimerManager] setTimeout called after destroy, ignoring');
      return -1;
    }

    const timerId = setTimeout(() => {
      this.timers.delete(timerId);
      try {
        callback();
      } catch (e) {
        const errMsg = e instanceof Error ? e.message : String(e);
        console.error(`[TimerManager] Timer callback error: ${errMsg}`);
      }
    }, delay);

    this.timers.add(timerId);
    return timerId;
  }

  /**
   * 设置间隔定时器
   * @param callback 回调函数
   * @param interval 间隔时间（毫秒）
   * @returns 定时器 ID
   */
  setInterval(callback: () => void, interval: number): TimerId {
    if (this.destroyed) {
      console.warn('[TimerManager] setInterval called after destroy, ignoring');
      return -1;
    }

    const timerId = setInterval(() => {
      try {
        callback();
      } catch (e) {
        const errMsg = e instanceof Error ? e.message : String(e);
        console.error(`[TimerManager] Interval callback error: ${errMsg}`);
      }
    }, interval);

    this.timers.add(timerId);
    return timerId;
  }

  /**
   * 清除指定定时器
   * @param timerId 定时器 ID
   */
  clearTimeout(timerId: TimerId): void {
    if (timerId <= 0) {
      return;
    }

    try {
      clearTimeout(timerId);
    } catch (e) {
      // 忽略清除错误
    }
    this.timers.delete(timerId);
  }

  /**
   * 清除指定间隔定时器
   * @param timerId 定时器 ID
   */
  clearInterval(timerId: TimerId): void {
    if (timerId <= 0) {
      return;
    }

    try {
      clearInterval(timerId);
    } catch (e) {
      // 忽略清除错误
    }
    this.timers.delete(timerId);
  }

  /**
   * 清除所有定时器
   * 应在组件 aboutToDisappear 中调用
   */
  clearAll(): void {
    console.info(`[TimerManager] Clearing ${this.timers.size} timers`);
    
    for (const timerId of this.timers) {
      try {
        clearTimeout(timerId);
        clearInterval(timerId);
      } catch (e) {
        // 忽略清除错误
      }
    }
    
    this.timers.clear();
    this.destroyed = true;
  }

  /**
   * 获取当前活跃的定时器数量
   */
  getActiveTimerCount(): number {
    return this.timers.size;
  }

  /**
   * 检查是否已销毁
   */
  isDestroyed(): boolean {
    return this.destroyed;
  }
}

/**
 * 延迟函数，用于 async/await 场景
 * @param ms 延迟毫秒数
 * @returns Promise
 */
export async function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    try {
      setTimeout(() => resolve(), ms);
    } catch (e) {
      // setTimeout 不可用时立即 resolve
      console.warn('[TimerManager] setTimeout unavailable in delay, resolving immediately');
      resolve();
    }
  });
}

/**
 * 带超时的 Promise
 * @param promise 原始 Promise
 * @param timeoutMs 超时时间（毫秒）
 * @param errorMessage 超时错误消息
 * @returns 带超时的 Promise
 */
export async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  errorMessage: string = 'Operation timed out'
): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      setTimeout(() => reject(new Error(errorMessage)), timeoutMs);
    })
  ]);
}
