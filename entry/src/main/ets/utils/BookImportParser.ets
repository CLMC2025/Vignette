// =====================================================
// BookImportParser.ets - Helper to parse wordbook files
// =====================================================

import { WordItem, WordStatus, WordDefinition, FSRSState, ReviewHistory } from '../model/WordModel';

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
}

export interface ImportJsonWord {
  word?: string;
  w?: string;
  meaning?: string;
  m?: string;
  def?: string;
  definition?: string;
}

export interface ImportJsonRoot {
  words?: ImportJsonWord[];
}

export class BookImportParser {
  /**
   * Parse content from text string (TXT/CSV/JSON)
   */
  static parseText(content: string, bookId: string = 'default', tags: string[] = []): ImportPreviewResult {
    const lines = content.split(/\r?\n/);
    const seen = new Set<string>();
    const words: WordItem[] = [];
    const errors: ImportErrorDetail[] = [];
    let invalid = 0;
    let dup = 0;

    // Simple detection
    let format: 'txt' | 'csv' | 'json' | 'unknown' = 'txt';
    const trimmedContent = content.trim();
    if (trimmedContent.startsWith('{') || trimmedContent.startsWith('[')) {
      format = 'json';
    } else if (content.includes(',') && !content.includes('\t')) {
      format = 'csv';
    }

    if (format === 'json') {
      try {
        const parsed = JSON.parse(content) as ImportJsonWord[] | ImportJsonRoot;
        const list: ImportJsonWord[] = Array.isArray(parsed) ? parsed : (parsed.words || []);
        for (let i = 0; i < list.length; i++) {
          const item = list[i];
          const w = item.word || item.w;
          if (w && typeof w === 'string') {
            const norm = w.trim().toLowerCase();
            if (seen.has(norm)) {
              dup++;
              errors.push({
                line: i + 1,
                message: '重复单词',
                content: w
              });
              continue;
            }
            seen.add(norm);
            words.push(BookImportParser.createWordItem(norm, bookId, tags));
          } else {
            invalid++;
            errors.push({
              line: i + 1,
              message: '缺少单词字段',
              content: JSON.stringify(item)
            });
          }
        }
        return { words, invalidCount: invalid, duplicateCount: dup, format: 'json', errors };
      } catch (e) {
        const errMsg = e instanceof Error ? e.message : String(e);
        errors.push({
          line: 1,
          message: `JSON解析失败: ${errMsg}`,
          content: content.substring(0, 100)
        });
        // Fallback to line parsing if JSON fails
        format = 'txt';
      }
    }

    for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      const line = lines[lineIndex];
      const s = line.trim();
      if (s.length === 0) continue;
      if (s.startsWith('#') || s.startsWith('//')) continue;

      let word = '';
      if (s.includes('\t')) {
        const parts = s.split('\t');
        word = parts[0];
      } else if (s.includes(',') && format === 'csv') {
        // Simple CSV split, not handling quotes yet for simplicity
        const parts = s.split(',');
        word = parts[0];
      } else {
        // Space separated, assume first word is key
        const parts = s.split(/\s+/);
        word = parts[0];
      }

      word = word.trim().toLowerCase();

      if (word.length === 0) {
        invalid++;
        errors.push({
          line: lineIndex + 1,
          message: '单词为空',
          content: s
        });
        continue;
      }

      if (!/^[a-zA-Z][a-zA-Z\-\']*$/.test(word)) {
        invalid++;
        errors.push({
          line: lineIndex + 1,
          message: '格式错误（应为英文单词）',
          content: s
        });
        continue;
      }

      if (seen.has(word)) {
        dup++;
        errors.push({
          line: lineIndex + 1,
          message: '重复单词',
          content: word
        });
        continue;
      }
      seen.add(word);

      words.push(BookImportParser.createWordItem(word, bookId, tags));
    }

    return { words, invalidCount: invalid, duplicateCount: dup, format: format === 'csv' ? 'csv' : 'txt', errors };
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

  /**
   * Validate a single word format
   */
  static isValidWord(word: string): boolean {
    if (!word || word.trim().length === 0) {
      return false;
    }
    return /^[a-zA-Z][a-zA-Z\-\']*$/.test(word.trim());
  }

  /**
   * Get format description
   */
  static getFormatDescription(format: 'txt' | 'csv' | 'json' | 'unknown'): string {
    switch (format) {
      case 'txt':
        return 'TXT (Tab分隔)';
      case 'csv':
        return 'CSV (逗号分隔)';
      case 'json':
        return 'JSON 格式';
      default:
        return '未知格式';
    }
  }
}
