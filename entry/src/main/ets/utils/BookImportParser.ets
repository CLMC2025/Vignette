// =====================================================
// BookImportParser.ets - Helper to parse wordbook files
// Supports plain words and words with phonetic/meaning
// =====================================================

import { WordItem, WordStatus, WordDefinition, FSRSState, ReviewHistory, WordMeaning } from '../model/WordModel';

export interface ImportErrorDetail {
  line: number;
  message: string;
  content: string;
}

export interface ImportPreviewResult {
  words: WordItem[];
  invalidCount: number;
  duplicateCount: number;
  format: 'txt' | 'csv' | 'json' | 'unknown';
  errors: ImportErrorDetail[];
  hasLocalDefinitions: boolean;
  localDefinitionCount: number;
}

export interface ImportJsonWord {
  word?: string;
  w?: string;
  meaning?: string;
  m?: string;
  def?: string;
  definition?: string;
  phonetic?: string;
  pos?: string;
}

export interface ImportJsonRoot {
  words?: ImportJsonWord[];
}

export interface ParsedWordEntry {
  word: string;
  phonetic: string;
  meanings: WordMeaning[];
  hasDefinition: boolean;
}

export interface JsonParseResult {
  words: WordItem[];
  invalidCount: number;
  duplicateCount: number;
  errors: ImportErrorDetail[];
  localDefinitionCount: number;
}

export class BookImportParser {
  private static readonly WORD_ONLY_PATTERN = /^[a-zA-Z][a-zA-Z\-\']*$/;
  
  private static readonly PHONETIC_PATTERN = /\[([^\]]+)\]/;
  
  private static readonly POS_MEANING_PATTERN = /([a-z]+\.)\s*([^a-z]+\s*(?:[,，;；]\s*[^a-z]+\s*)*)/gi;
  
  private static readonly SIMPLE_MEANING_PATTERN = /^([a-zA-Z][a-zA-Z\-\']*)\s*(?:\[([^\]]+)\])?\s*(.*)$/;

  static parseText(content: string, bookId: string = 'default', tags: string[] = []): ImportPreviewResult {
    const lines = content.split(/\r?\n/);
    const seen = new Set<string>();
    const words: WordItem[] = [];
    const errors: ImportErrorDetail[] = [];
    let invalid = 0;
    let dup = 0;
    let localDefCount = 0;

    let format: 'txt' | 'csv' | 'json' | 'unknown' = 'txt';
    const trimmedContent = content.trim();
    if (trimmedContent.startsWith('{') || trimmedContent.startsWith('[')) {
      format = 'json';
    } else if (content.includes(',') && !content.includes('\t') && !content.includes('[')) {
      format = 'csv';
    }

    if (format === 'json') {
      const jsonResult = BookImportParser.parseJsonFormat(content, bookId, tags, seen);
      return {
        words: jsonResult.words,
        invalidCount: jsonResult.invalidCount,
        duplicateCount: jsonResult.duplicateCount,
        format: 'json',
        errors: jsonResult.errors,
        hasLocalDefinitions: jsonResult.localDefinitionCount > 0,
        localDefinitionCount: jsonResult.localDefinitionCount
      };
    }

    for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      const line = lines[lineIndex];
      const s = line.trim();
      if (s.length === 0) continue;
      if (s.startsWith('#') || s.startsWith('//')) continue;

      const parsed = BookImportParser.parseWordLine(s);
      if (parsed === null) {
        invalid++;
        errors.push({
          line: lineIndex + 1,
          message: '格式错误（应为英文单词）',
          content: s
        });
        continue;
      }

      const normalizedWord = parsed.word.toLowerCase();

      if (seen.has(normalizedWord)) {
        dup++;
        errors.push({
          line: lineIndex + 1,
          message: '重复单词',
          content: parsed.word
        });
        continue;
      }
      seen.add(normalizedWord);

      if (parsed.hasDefinition) {
        localDefCount++;
      }

      words.push(BookImportParser.createWordItemFromParsed(parsed, bookId, tags));
    }

    return {
      words,
      invalidCount: invalid,
      duplicateCount: dup,
      format: format === 'csv' ? 'csv' : 'txt',
      errors,
      hasLocalDefinitions: localDefCount > 0,
      localDefinitionCount: localDefCount
    };
  }

  static parseWordLine(line: string): ParsedWordEntry | null {
    const trimmed = line.trim();
    if (trimmed.length === 0) return null;

    const match = trimmed.match(BookImportParser.SIMPLE_MEANING_PATTERN);
    if (!match) return null;

    const word = match[1].toLowerCase();
    if (!BookImportParser.WORD_ONLY_PATTERN.test(word)) return null;

    const phonetic = match[2] ? match[2].trim() : '';
    const rest = match[3] ? match[3].trim() : '';

    if (rest.length === 0) {
      return {
        word,
        phonetic: '',
        meanings: [],
        hasDefinition: false
      };
    }

    const meanings = BookImportParser.parseMeanings(rest);

    return {
      word,
      phonetic,
      meanings,
      hasDefinition: meanings.length > 0 || phonetic.length > 0
    };
  }

  private static parseMeanings(text: string): WordMeaning[] {
    const meanings: WordMeaning[] = [];
    
    const posPattern = /([a-z]+\.?)\s*([^a-z]+?)(?=\s*[a-z]+\.|\s*$)/gi;
    let match: RegExpExecArray | null = null;
    
    while ((match = posPattern.exec(text)) !== null) {
      const pos: string = match[1].trim();
      const meaning: string = match[2].trim();
      
      if (pos.length > 0 && meaning.length > 0) {
        const normalizedPos: string = pos.endsWith('.') ? pos : pos + '.';
        meanings.push(new WordMeaning(normalizedPos, meaning));
      }
    }

    if (meanings.length === 0 && text.length > 0) {
      meanings.push(new WordMeaning('', text));
    }

    return meanings;
  }

  private static parseJsonFormat(
    content: string,
    bookId: string,
    tags: string[],
    seen: Set<string>
  ): JsonParseResult {
    const words: WordItem[] = [];
    const errors: ImportErrorDetail[] = [];
    let invalid = 0;
    let dup = 0;
    let localDefCount = 0;

    try {
      const parsed = JSON.parse(content) as ImportJsonWord[] | ImportJsonRoot;
      const list: ImportJsonWord[] = Array.isArray(parsed) ? parsed : (parsed.words || []);
      
      for (let i = 0; i < list.length; i++) {
        const item = list[i];
        const w = (item.word || item.w || '').trim().toLowerCase();
        
        if (!w || !BookImportParser.WORD_ONLY_PATTERN.test(w)) {
          invalid++;
          errors.push({
            line: i + 1,
            message: '缺少或无效单词字段',
            content: JSON.stringify(item)
          });
          continue;
        }
        
        if (seen.has(w)) {
          dup++;
          errors.push({
            line: i + 1,
            message: '重复单词',
            content: w
          });
          continue;
        }
        seen.add(w);

        const phonetic = (item.phonetic || '').trim();
        const pos = (item.pos || '').trim();
        const meaning = (item.meaning || item.m || item.def || item.definition || '').trim();
        
        const meanings: WordMeaning[] = [];
        if (pos && meaning) {
          meanings.push(new WordMeaning(pos, meaning));
        } else if (meaning) {
          meanings.push(new WordMeaning('', meaning));
        }

        const hasDef = phonetic.length > 0 || meanings.length > 0;
        if (hasDef) {
          localDefCount++;
        }

        const parsedEntry: ParsedWordEntry = {
          word: w,
          phonetic,
          meanings,
          hasDefinition: hasDef
        };

        words.push(BookImportParser.createWordItemFromParsed(parsedEntry, bookId, tags));
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      errors.push({
        line: 1,
        message: `JSON解析失败: ${errMsg}`,
        content: content.substring(0, 100)
      });
    }

    return {
      words: words,
      invalidCount: invalid,
      duplicateCount: dup,
      errors: errors,
      localDefinitionCount: localDefCount
    };
  }

  private static createWordItemFromParsed(parsed: ParsedWordEntry, bookId: string, tags: string[]): WordItem {
    const def = new WordDefinition(
      parsed.word,
      parsed.phonetic,
      parsed.meanings.length > 0 ? parsed.meanings[0].pos : '',
      '',
      parsed.meanings,
      parsed.hasDefinition ? 'local' : 'import'
    );
    
    const now = Date.now();
    return new WordItem(
      0,
      parsed.word,
      WordStatus.NEW,
      new FSRSState(),
      new ReviewHistory(),
      def,
      now,
      now,
      now,
      bookId,
      tags
    );
  }

  private static createWordItem(word: string, bookId: string, tags: string[]): WordItem {
    const def = new WordDefinition(word, '', '', '', [], 'import');
    const now = Date.now();
    return new WordItem(
      0,
      word,
      WordStatus.NEW,
      new FSRSState(),
      new ReviewHistory(),
      def,
      now,
      now,
      now,
      bookId,
      tags
    );
  }

  static isValidWord(word: string): boolean {
    if (!word || word.trim().length === 0) {
      return false;
    }
    return BookImportParser.WORD_ONLY_PATTERN.test(word.trim());
  }

  static getFormatDescription(format: 'txt' | 'csv' | 'json' | 'unknown'): string {
    switch (format) {
      case 'txt':
        return 'TXT (支持单词+释义格式)';
      case 'csv':
        return 'CSV (逗号分隔)';
      case 'json':
        return 'JSON 格式';
      default:
        return '未知格式';
    }
  }

  static getSupportedFormatsDescription(): string {
    return `支持的词书格式：
1. 纯单词格式（每行一个单词）：
   apple
   banana

2. 单词+音标+释义格式：
   pile [paɪl] n. 堆 v. 堆起
   abandon [əˈbændən] v. 放弃，遗弃

3. JSON格式：
   [{"word": "apple", "phonetic": "ˈæpl", "meaning": "n. 苹果"}]`;
  }
}
