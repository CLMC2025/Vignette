// =====================================================
// BaseRepository.ets
// Base class for repositories
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { DBError } from '../DBConstants';

export abstract class BaseRepository {
  protected store: relationalStore.RdbStore | null = null;

  constructor(store: relationalStore.RdbStore | null) {
    this.store = store;
  }

  setStore(store: relationalStore.RdbStore | null) {
    this.store = store;
  }

  protected ensureInitialized(): void {
    if (this.store === null) {
      const repoName = this.constructor.name;
      console.error(`[${repoName}] Operation attempted on uninitialized database`);
      throw new DBError('Database not initialized. Call initialize() first.');
    }
  }
  
  /**
   * Helper to log database operations
   */
  protected logOperation(operation: string, details?: string): void {
    const repoName = this.constructor.name;
    if (details) {
      console.info(`[${repoName}] ${operation}: ${details}`);
    } else {
      console.info(`[${repoName}] ${operation}`);
    }
  }
  
  /**
   * Helper to log database errors
   */
  protected logError(operation: string, error: Error | string | object): void {
    const repoName = this.constructor.name;
    const errMsg = error instanceof Error ? error.message : String(error);
    console.error(`[${repoName}] ${operation} failed: ${errMsg}`);
  }
}
