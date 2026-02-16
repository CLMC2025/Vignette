// =====================================================
// VignetteCacheRepository.ets
// CRUD for vignette cache
// =====================================================

import relationalStore from '@ohos.data.relationalStore';
import { BaseRepository } from './BaseRepository';
import { DBError, TABLE_VIGNETTE_CACHE_ITEMS, TABLE_VIGNETTE_CACHE } from '../DBConstants';
import { VignetteCacheItemRow, VignetteCacheStats } from '../DBManager';

export class VignetteCacheRepository extends BaseRepository {

  async migrateVignetteCacheToItems(): Promise<void> {
    if (this.store === null) return;

    try {
      // Check if old table exists and has data
      const sqlCheck = `SELECT count(*) as cnt FROM ${TABLE_VIGNETTE_CACHE}`;
      const rs = await this.store.querySql(sqlCheck, []);
      if (rs.goToFirstRow()) {
        const cnt = rs.getLong(rs.getColumnIndex('cnt'));
        if (cnt === 0) {
          rs.close();
          return;
        }
      }
      rs.close();

      console.info('[VignetteCacheRepository] Migrating old cache to items...');
      const sqlMigrate = `
        INSERT OR IGNORE INTO ${TABLE_VIGNETTE_CACHE_ITEMS} (word, vignette, vignette_hash, created_at, last_used_at, size_bytes)
        SELECT word, vignette, 0, created_at, last_used_at, size_bytes FROM ${TABLE_VIGNETTE_CACHE}
      `;
      await this.store.executeSql(sqlMigrate);

      // Clean up old table (optional, maybe keep for safety or drop later)
      const sqlDelete = `DELETE FROM ${TABLE_VIGNETTE_CACHE}`;
      await this.store.executeSql(sqlDelete);
      console.info('[VignetteCacheRepository] Migration done.');
    } catch (e) {
      console.warn('[VignetteCacheRepository] Migration skipped or failed:', e);
    }
  }

  async cacheVignetteItem(word: string, vignette: string, vignetteHash: number): Promise<void> {
    this.ensureInitialized();
    const normalizedWord = word.trim().toLowerCase();
    const now = Date.now();
    const size = vignette.length; // Approximate bytes

    const bucket: relationalStore.ValuesBucket = {
      'word': normalizedWord,
      'vignette': vignette,
      'vignette_hash': vignetteHash,
      'created_at': now,
      'last_used_at': now,
      'size_bytes': size
    };

    try {
      await this.store!.insert(TABLE_VIGNETTE_CACHE_ITEMS, bucket);
    } catch (e) {
      // If unique constraint (word, hash) fails, update last_used_at
      const predicates = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE_ITEMS);
      predicates.equalTo('word', normalizedWord)
        .and()
        .equalTo('vignette_hash', vignetteHash);
      const updateBucket: relationalStore.ValuesBucket = {
        'last_used_at': now
      };
      await this.store!.update(updateBucket, predicates);
    }
  }

  async getCachedVignetteItems(word: string): Promise<VignetteCacheItemRow[]> {
    this.ensureInitialized();
    const normalizedWord = word.trim().toLowerCase();
    const predicates = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE_ITEMS);
    predicates.equalTo('word', normalizedWord);
    predicates.orderByDesc('last_used_at');

    const resultSet = await this.store!.query(predicates);
    const items: VignetteCacheItemRow[] = [];

    while (resultSet.goToNextRow()) {
      items.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')) as number,
        word: resultSet.getString(resultSet.getColumnIndex('word')),
        vignette: resultSet.getString(resultSet.getColumnIndex('vignette')),
        vignetteHash: resultSet.getLong(resultSet.getColumnIndex('vignette_hash')) as number,
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')) as number,
        lastUsedAt: resultSet.getLong(resultSet.getColumnIndex('last_used_at')) as number,
        sizeBytes: resultSet.getLong(resultSet.getColumnIndex('size_bytes')) as number
      });
    }
    resultSet.close();
    return items;
  }

  async getCachedVignette(word: string): Promise<string> {
    this.ensureInitialized();
    const normalizedWord = word.trim().toLowerCase();
    const predicates = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE_ITEMS);
    predicates.equalTo('word', normalizedWord);
    predicates.orderByDesc('last_used_at');
    predicates.limitAs(1);
    const columns: string[] = ['vignette'];
    const resultSet = await this.store!.query(predicates, columns);
    let vignette = '';
    if (resultSet.goToFirstRow()) {
      vignette = resultSet.getString(resultSet.getColumnIndex('vignette'));
    }
    resultSet.close();
    return vignette;
  }

  async getVignetteVariantCount(word: string): Promise<number> {
    this.ensureInitialized();
    const normalizedWord = word.trim().toLowerCase();
    const sql = `SELECT COUNT(1) as cnt FROM ${TABLE_VIGNETTE_CACHE_ITEMS} WHERE word = ?`;
    const rs = await this.store!.querySql(sql, [normalizedWord]);
    let count = 0;
    if (rs.goToFirstRow()) {
      count = Number(rs.getLong(rs.getColumnIndex('cnt')));
    }
    rs.close();
    return count;
  }

  async getVignetteCacheStats(): Promise<VignetteCacheStats> {
    this.ensureInitialized();
    const sql = `SELECT COUNT(1) as cnt, SUM(size_bytes) as size FROM ${TABLE_VIGNETTE_CACHE_ITEMS}`;
    const rs = await this.store!.querySql(sql, []);
    let count = 0;
    let size = 0;
    if (rs.goToFirstRow()) {
      count = Number(rs.getLong(rs.getColumnIndex('cnt')));
      size = Number(rs.getLong(rs.getColumnIndex('size')));
    }
    rs.close();
    return { count, sizeBytes: size };
  }

  async pruneVignetteCache(maxBytes: number, maxEntries: number): Promise<number> {
    this.ensureInitialized();
    const stats = await this.getVignetteCacheStats();
    const bytesToRemove = Math.max(0, stats.sizeBytes - maxBytes);
    const entriesToRemove = Math.max(0, stats.count - maxEntries);
    if (bytesToRemove === 0 && entriesToRemove === 0) {
      return 0;
    }
    const sqlSelect = `SELECT id, size_bytes FROM ${TABLE_VIGNETTE_CACHE_ITEMS} ORDER BY last_used_at ASC`;
    const rs = await this.store!.querySql(sqlSelect, []);
    let removedBytes = 0;
    let removedCount = 0;
    const idsToDelete: number[] = [];

    while (rs.goToNextRow()) {
      const id = Number(rs.getLong(rs.getColumnIndex('id')));
      const size = Number(rs.getLong(rs.getColumnIndex('size_bytes')));
      idsToDelete.push(id);
      removedBytes += size;
      removedCount += 1;
      if (removedBytes >= bytesToRemove && removedCount >= entriesToRemove) {
        break;
      }
    }
    rs.close();

    if (idsToDelete.length > 0) {
      const placeholders = idsToDelete.map(() => '?').join(',');
      const sqlDelete = `DELETE FROM ${TABLE_VIGNETTE_CACHE_ITEMS} WHERE id IN (${placeholders})`;
      await this.store!.executeSql(sqlDelete, idsToDelete);
    }

    return idsToDelete.length;
  }

  async clearVignetteCache(): Promise<void> {
    this.ensureInitialized();
    const predicates = new relationalStore.RdbPredicates(TABLE_VIGNETTE_CACHE_ITEMS);
    await this.store!.delete(predicates);
  }
}
