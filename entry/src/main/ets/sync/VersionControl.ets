// =====================================================
// VersionControl.ets - 数据版本控制系统
// 实现数据版本管理、时间戳追踪和变更日志
// =====================================================

/**
 * 版本信息
 */
export class VersionInfo {
  version: number;
  timestamp: number;
  description: string;

  constructor(version: number = 1, timestamp: number = Date.now(), description: string = '') {
    this.version = version;
    this.timestamp = timestamp;
    this.description = description;
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, number | string> = {
      'version': this.version,
      'timestamp': this.timestamp,
      'description': this.description
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): VersionInfo {
    try {
      const obj = JSON.parse(json) as Record<string, number | string>;
      return new VersionInfo(
        obj['version'] as number ?? 1,
        obj['timestamp'] as number ?? Date.now(),
        obj['description'] as string ?? ''
      );
    } catch (e) {
      return new VersionInfo();
    }
  }
}

/**
 * 变更日志条目
 */
export class ChangeLogEntry {
  id: string;
  timestamp: number;
  changeType: ChangeType;
  entityType: string;
  entityId: number;
  description: string;
  previousValue: string;
  newValue: string;

  constructor(
    changeType: ChangeType,
    entityType: string,
    entityId: number,
    description: string,
    previousValue: string = '',
    newValue: string = ''
  ) {
    this.id = this.generateId();
    this.timestamp = Date.now();
    this.changeType = changeType;
    this.entityType = entityType;
    this.entityId = entityId;
    this.description = description;
    this.previousValue = previousValue;
    this.newValue = newValue;
  }

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, number | string> = {
      'id': this.id,
      'timestamp': this.timestamp,
      'changeType': this.changeType,
      'entityType': this.entityType,
      'entityId': this.entityId,
      'description': this.description,
      'previousValue': this.previousValue,
      'newValue': this.newValue
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): ChangeLogEntry {
    try {
      const obj = JSON.parse(json) as Record<string, number | string>;
      return new ChangeLogEntry(
        obj['changeType'] as ChangeType ?? ChangeType.UPDATE,
        obj['entityType'] as string ?? '',
        obj['entityId'] as number ?? 0,
        obj['description'] as string ?? '',
        obj['previousValue'] as string ?? '',
        obj['newValue'] as string ?? ''
      );
    } catch (e) {
      return new ChangeLogEntry(ChangeType.UPDATE, '', 0, '');
    }
  }
}

/**
 * 变更类型枚举
 */
export enum ChangeType {
  INSERT = 'INSERT',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE'
}

/**
 * 版本控制系统
 */
export class VersionControl {
  private currentVersion: VersionInfo;
  private changeLog: ChangeLogEntry[];
  private maxLogSize: number = 1000;

  constructor() {
    this.currentVersion = new VersionInfo();
    this.changeLog = [];
  }

  /**
   * 获取当前版本
   */
  getCurrentVersion(): VersionInfo {
    return this.currentVersion;
  }

  /**
   * 增加版本号
   */
  incrementVersion(description: string = ''): void {
    this.currentVersion.version++;
    this.currentVersion.timestamp = Date.now();
    this.currentVersion.description = description;
  }

  /**
   * 更新时间戳（不增加版本号）
   * 
   * 注意：
   * 1. 此方法仅更新内存中的时间戳，不负责持久化。
   * 2. VersionControl 通常嵌入在导出数据中一起持久化。
   * 3. 调用者需确保不存在并发修改（WebDavSyncManager 已通过 status 字段防止并发备份）。
   */
  updateTimestamp(): void {
    this.currentVersion.timestamp = Date.now();
  }

  /**
   * 记录变更
   */
  recordChange(
    changeType: ChangeType,
    entityType: string,
    entityId: number,
    description: string,
    previousValue: string = '',
    newValue: string = ''
  ): void {
    const entry = new ChangeLogEntry(
      changeType,
      entityType,
      entityId,
      description,
      previousValue,
      newValue
    );

    this.changeLog.push(entry);

    // 限制日志大小
    if (this.changeLog.length > this.maxLogSize) {
      this.changeLog.shift();
    }
  }

  /**
   * 获取变更日志
   */
  getChangeLog(): ChangeLogEntry[] {
    return [...this.changeLog];
  }

  /**
   * 获取特定实体的变更历史
   */
  getEntityHistory(entityType: string, entityId: number): ChangeLogEntry[] {
    return this.changeLog.filter(
      (entry: ChangeLogEntry): boolean => entry.entityType === entityType && entry.entityId === entityId
    );
  }

  /**
   * 获取指定时间之后的变更
   */
  getChangesAfter(timestamp: number): ChangeLogEntry[] {
    return this.changeLog.filter(
      (entry: ChangeLogEntry): boolean => entry.timestamp > timestamp
    );
  }

  /**
   * 清空变更日志
   */
  clearChangeLog(): void {
    this.changeLog = [];
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, string | number> = {
      'currentVersion': this.currentVersion.toJSON(),
      'changeLog': JSON.stringify(this.changeLog)
    };
    return JSON.stringify(obj);
  }

  /**
   * 从JSON反序列化
   */
  static fromJSON(json: string): VersionControl {
    try {
      const obj = JSON.parse(json) as Record<string, string | number>;
      const vc = new VersionControl();

      if (obj['currentVersion'] !== undefined) {
        vc.currentVersion = VersionInfo.fromJSON(obj['currentVersion'] as string);
      }

      if (obj['changeLog'] !== undefined) {
        const logArray = JSON.parse(obj['changeLog'] as string) as string[];
        vc.changeLog = logArray.map((entry: string): ChangeLogEntry => ChangeLogEntry.fromJSON(entry));
      }

      return vc;
    } catch (e) {
      return new VersionControl();
    }
  }

  /**
   * 比较两个版本
   */
  static compareVersions(version1: VersionInfo, version2: VersionInfo): number {
    if (version1.version < version2.version) {
      return -1;
    } else if (version1.version > version2.version) {
      return 1;
    }
    return 0;
  }

  /**
   * 检查版本冲突
   */
  hasConflict(otherVersion: VersionInfo): boolean {
    return this.currentVersion.version !== otherVersion.version &&
           this.currentVersion.timestamp !== otherVersion.timestamp;
  }

  /**
   * 解决版本冲突（基于时间戳）
   */
  resolveConflict(otherVersion: VersionInfo): VersionInfo {
    if (this.currentVersion.timestamp > otherVersion.timestamp) {
      return this.currentVersion;
    } else {
      return otherVersion;
    }
  }
}
