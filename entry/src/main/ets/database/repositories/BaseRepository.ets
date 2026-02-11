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
      throw new DBError('Database not initialized. Call initialize() first.');
    }
  }
}
