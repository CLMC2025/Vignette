// =====================================================
// BuiltInDictionary.ets - Built-in wordbook dictionary service
// Provides fast local definition lookup from built-in wordbooks
// =====================================================

import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import { WordDefinition, WordMeaning } from '../model/WordModel';

interface WordBookEntry {
  word: string;
  phonetic: string;
  meanings: WordMeaning[];
}

export interface BuiltInDictStats {
  loaded: boolean;
  wordCount: number;
}

export class BuiltInDictionary {
  private static instance: BuiltInDictionary | null = null;
  
  private cache: Map<string, WordDefinition> = new Map();
  private loaded: boolean = false;
  private loading: boolean = false;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  
  private constructor() {}
  
  static getInstance(): BuiltInDictionary {
    if (BuiltInDictionary.instance === null) {
      BuiltInDictionary.instance = new BuiltInDictionary();
    }
    return BuiltInDictionary.instance;
  }
  
  setResourceManager(rm: resourceManager.ResourceManager): void {
    this.resourceMgr = rm;
  }
  
  async initialize(): Promise<void> {
    if (this.loaded || this.loading) {
      return;
    }
    
    if (this.resourceMgr === null) {
      console.warn('[BuiltInDictionary] ResourceManager not set, skip loading');
      return;
    }
    
    this.loading = true;
    console.info('[BuiltInDictionary] Starting to load master.txt...');
    
    const startTime = Date.now();
    let totalWords = 0;
    
    try {
      const uint8Array = await this.resourceMgr.getRawFileContent('wordbooks/master.txt');
      const decoder = new util.TextDecoder('utf-8');
      const content = decoder.decode(uint8Array);
      const lines = content.split(/\r?\n/);
      
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.length === 0 || trimmed.startsWith('#')) {
          continue;
        }
        
        const entry = this.parseLine(trimmed);
        if (entry !== null && !this.cache.has(entry.word)) {
          const def = new WordDefinition(
            entry.word,
            entry.phonetic,
            entry.meanings.length > 0 ? entry.meanings[0].pos : '',
            '',
            entry.meanings,
            'builtin'
          );
          this.cache.set(entry.word, def);
          totalWords++;
        }
      }
      
      this.loaded = true;
      const elapsed = Date.now() - startTime;
      console.info(`[BuiltInDictionary] Loaded ${totalWords} words in ${elapsed}ms`);
    } catch (e) {
      console.warn(`[BuiltInDictionary] Failed to load master.txt: ${e}`);
    } finally {
      this.loading = false;
    }
  }
  
  private parseLine(line: string): WordBookEntry | null {
    const wordMatch = line.match(/^([a-zA-Z][a-zA-Z\-\']*)\s*(?:\[([^\]]+)\])?\s*(.*)$/);
    if (!wordMatch) {
      const simpleWord = line.match(/^([a-zA-Z][a-zA-Z\-\']*)$/);
      if (simpleWord) {
        return {
          word: simpleWord[1].toLowerCase(),
          phonetic: '',
          meanings: []
        };
      }
      return null;
    }
    
    const word = wordMatch[1].toLowerCase();
    const phonetic = wordMatch[2] ? wordMatch[2].trim() : '';
    const rest = wordMatch[3] ? wordMatch[3].trim() : '';
    
    const meanings = this.parseMeanings(rest);
    
    return {
      word,
      phonetic,
      meanings
    };
  }
  
  private parseMeanings(text: string): WordMeaning[] {
    const meanings: WordMeaning[] = [];
    const posMap = new Map<string, Set<string>>();
    
    if (text.length === 0) {
      return meanings;
    }
    
    // 标准词性标记列表
    const validPosList = ['n', 'v', 'adj', 'adv', 'vt', 'vi', 'prep', 'conj', 'art', 'pron', 'num', 'int', 'interj', 'aux', 'modal'];
    const validPosPattern = validPosList.join('|');
    // 匹配标准词性标记，后面跟着释义（非英文字符）
    const posPattern = new RegExp(`\\b(${validPosPattern})\\.?\\s*([^a-zA-Z]+?)(?=\\s*(?:${validPosPattern})\\.|\\s*$)`, 'gi');
    
    let match: RegExpExecArray | null = null;
    
    while ((match = posPattern.exec(text)) !== null) {
      const pos: string = match[1].trim();
      const meaning: string = match[2].trim();
      
      if (pos.length > 0 && meaning.length > 0) {
        const normalizedPos: string = pos.endsWith('.') ? pos : pos + '.';
        
        // 按词性分组收集释义
        if (!posMap.has(normalizedPos)) {
          posMap.set(normalizedPos, new Set());
        }
        
        // 拆分释义（按逗号、分号分隔）并去重
        const parts = meaning.split(/[,;，；]/).map(p => p.trim()).filter(p => p.length > 0);
        for (const part of parts) {
          posMap.get(normalizedPos)!.add(part);
        }
      }
    }
    
    // 合并相同词性的释义
    posMap.forEach((meaningSet, pos) => {
      const meaningsArr = Array.from(meaningSet);
      // 最多取 6 个释义，避免过长
      const limitedMeanings = meaningsArr.slice(0, 6);
      meanings.push(new WordMeaning(pos, limitedMeanings.join('；')));
    });
    
    if (meanings.length === 0 && text.length > 0) {
      meanings.push(new WordMeaning('', text));
    }
    
    return meanings;
  }
  
  async lookup(word: string): Promise<WordDefinition | null> {
    if (!this.loaded) {
      await this.initialize();
    }
    
    const normalized = word.toLowerCase().trim();
    if (normalized.length === 0) {
      return null;
    }
    
    const def = this.cache.get(normalized);
    if (def !== undefined) {
      return WordDefinition.fromJSON(def.toJSON());
    }
    
    return null;
  }
  
  hasDefinition(word: string): boolean {
    if (!this.loaded) {
      return false;
    }
    
    const normalized = word.toLowerCase().trim();
    return this.cache.has(normalized);
  }
  
  getStats(): BuiltInDictStats {
    const stats: BuiltInDictStats = {
      loaded: this.loaded,
      wordCount: this.cache.size
    };
    return stats;
  }
  
  clear(): void {
    this.cache.clear();
    this.loaded = false;
  }
}
