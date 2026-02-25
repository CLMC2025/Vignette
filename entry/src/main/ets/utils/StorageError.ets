export enum StorageErrorType {
  NOT_INITIALIZED = 'NOT_INITIALIZED',
  INITIALIZATION_FAILED = 'INITIALIZATION_FAILED',
  CONTEXT_NOT_INJECTED = 'CONTEXT_NOT_INJECTED',
  READ_FAILED = 'READ_FAILED',
  WRITE_FAILED = 'WRITE_FAILED',
  PARSE_FAILED = 'PARSE_FAILED',
  FLUSH_FAILED = 'FLUSH_FAILED'
}

export class StorageError extends Error {
  readonly type: StorageErrorType;
  readonly originalError?: Error;

  constructor(type: StorageErrorType, message: string, originalError?: Error) {
    super(message);
    this.type = type;
    this.originalError = originalError;
    this.name = 'StorageError';
  }

  static notInitialized(): StorageError {
    return new StorageError(
      StorageErrorType.NOT_INITIALIZED,
      'Storage not initialized'
    );
  }

  static contextNotInjected(): StorageError {
    return new StorageError(
      StorageErrorType.CONTEXT_NOT_INJECTED,
      'Ability context not injected'
    );
  }

  static initializationFailed(originalError?: Error): StorageError {
    return new StorageError(
      StorageErrorType.INITIALIZATION_FAILED,
      `Failed to initialize storage: ${originalError?.message ?? 'unknown error'}`,
      originalError
    );
  }

  static readFailed(key: string, originalError?: Error): StorageError {
    return new StorageError(
      StorageErrorType.READ_FAILED,
      `Failed to read key "${key}": ${originalError?.message ?? 'unknown error'}`,
      originalError
    );
  }

  static writeFailed(key: string, originalError?: Error): StorageError {
    return new StorageError(
      StorageErrorType.WRITE_FAILED,
      `Failed to write key "${key}": ${originalError?.message ?? 'unknown error'}`,
      originalError
    );
  }

  static parseFailed(key: string, originalError?: Error): StorageError {
    return new StorageError(
      StorageErrorType.PARSE_FAILED,
      `Failed to parse value for key "${key}": ${originalError?.message ?? 'unknown error'}`,
      originalError
    );
  }

  static flushFailed(originalError?: Error): StorageError {
    return new StorageError(
      StorageErrorType.FLUSH_FAILED,
      `Failed to flush storage: ${originalError?.message ?? 'unknown error'}`,
      originalError
    );
  }
}

export interface StorageResult<T> {
  success: boolean;
  value?: T;
  error?: StorageError;
}

export class StorageResultBuilder {
  static success<T>(value: T): StorageResult<T> {
    return { success: true, value: value };
  }

  static failure<T>(error: StorageError): StorageResult<T> {
    return { success: false, error: error };
  }

  static notInitialized<T>(): StorageResult<T> {
    return StorageResultBuilder.failure(StorageError.notInitialized());
  }

  static contextNotInjected<T>(): StorageResult<T> {
    return StorageResultBuilder.failure(StorageError.contextNotInjected());
  }
}
