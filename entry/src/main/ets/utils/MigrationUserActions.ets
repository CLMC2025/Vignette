/**
 * 数据库迁移脚本：将现有单词数据迁移到支持UserActions的格式
 * 用于解决用户状态重置问题 - 001-migrate-user-actions.ts
 */

import { DBManager } from '../database/DBManager';
import { WordItem } from '../model/WordModel';
import { UserActions } from '../model/WordModel';
import { NotebookWordEntry } from '../database/DBManager';

async function migrateUserActions() {
  console.log('[Migration] Starting UserActions migration...');
  
  try {
    // 获取数据库实例
    const dbManager = DBManager.getInstance();
    
    // 获取所有现有单词
    const allWords = await dbManager.getAllWords();
    console.log(`[Migration] Found ${allWords.length} words to migrate`);
    
    // 获取所有收藏单词状态（从notebook表）
    const notebookWords = await dbManager.getNotebookWords();
    const notebookSet = new Set(notebookWords);
    
    let migratedCount = 0;
    let errorCount = 0;
    
    // 遌装每一个单词，确保有正确的UserActions结构
    for (const wordItem of allWords) {
      try {
        // 从数据库获取最新的wordItem副本，确保没有并发更新冲突
        const latestWordItem = await dbManager.getWordById(wordItem.id);
        if (!latestWordItem) {
          console.warn(`[Migration] Word with ID ${wordItem.id} not found in database`);
          continue;
        }
        
        // 确保UserActions已初始化
        const updatedWordItem = latestWordItem.clone();
        if (!updatedWordItem.userActions) {
          // 创建新的UserActions实例
          updatedWordItem.userActions = new UserActions();
        }
        
        // 从notebook表中复制收藏状态
        if (notebookSet.has(wordItem.word)) {
          updatedWordItem.userActions.favorite(); // 将其標記為已收藏
        }
        
        // 获取该单词所属的用户词书
        const wordBooks = await dbManager.getUserWordBooksContainingWord(wordItem.word);
        for (const book of wordBooks) {
          updatedWordItem.userActions.addToBook(book.id);
        }
        
        // 更新单词记录
        await dbManager.updateWord(updatedWordItem);
        migratedCount++;
        
        if (migratedCount % 50 === 0) {
          console.log(`[Migration] Processed ${migratedCount}/${allWords.length} words`);
        }
      } catch (e) {
        console.error(`[Migration] Failed to migrate word ${wordItem.word}:`, e);
        errorCount++;
      }
    }
    
    console.log(`[Migration] Completed! Successfully migrated ${migratedCount} words, ${errorCount} errors occurred.`);
    
    // 对于未出现在原有notebook表中的记录执行完整性检查
    const notebookEntries = await dbManager.getNotebookWordsWithTime();
    console.log(`[Migration] Checking notebook integrity with ${notebookEntries.length} notebook entries...`);
    
    let integrityIssues = 0;
    for (const entry of notebookEntries) {
      const wordItem = await dbManager.getWordByWord(entry.word);
      if (wordItem && (!wordItem.userActions || !wordItem.userActions.isNotebook)) {
        // 更新该单词的收藏状态
        const updatedWord = wordItem.clone();
        if (!updatedWord.userActions) {
          updatedWord.userActions = new UserActions();
        }  
        updatedWord.userActions.favorite();
        await dbManager.updateWord(updatedWord);
        integrityIssues++;
      }
    }
    
    console.log(`[Migration] Integrity check completed. Fixed ${integrityIssues} notebook inconsistencies.`);
    
    return {
      success: true,
      migratedCount,
      errorCount,
      integrityIssuesFixed: integrityIssues
    };
    
  } catch (e) {
    console.error('[Migration] Critical error during migration:', e);
    return {
      success: false,
      error: e.message,
      migratedCount: 0,
      errorCount: 0,
      integrityIssuesFixed: 0
    };
  }
}

// 运行迁移
migrateUserActions()
  .then(result => {
    if (result.success) {
      console.log('[Migration] Migration completed successfully!');
      console.log(`Summary: ${result.migratedCount} migrated, ${result.errorCount} errors, ${result.integrityIssuesFixed} fixed`);
    } else {
      console.error('[Migration] Migration failed:', result.error);
    }
  })
  .catch(err => {
    console.error('[Migration] Unexpected error:', err);
  });

export { migrateUserActions };