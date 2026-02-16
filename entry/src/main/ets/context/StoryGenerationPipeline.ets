// =====================================================
// StoryGenerationPipeline.ets - Story generation with fallback
// =====================================================

import { OfflineContextGenerator } from './OfflineContext';
import { ContextStyle, DifficultyLevel } from './TemplateManager';
import { StoryOrigin, StoryResult } from '../manager/DictionaryManager';
import { ErrorCategory, buildUserFacingError } from '../utils/ErrorClassifier';
import { TextSanitizer } from '../utils/TextSanitizer';

export enum StorySource {
  AI = 'AI',
  CACHE = 'CACHE',
  OFFLINE = 'OFFLINE',
  MINIMAL = 'MINIMAL'
}

export interface StoryGenerator {
  isConfigured?(): boolean;
  generateStory(
    targetWord: string,
    supportWords: string[],
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number,
    preferCacheFirst?: boolean
  ): Promise<StoryResult>;
  getCachedVignetteOnly?(targetWord: string): Promise<string | null>;
}

export class StoryGenerationOutcome {
  story: string;
  source: StorySource;
  warningMessage: string;
  errorCategory: ErrorCategory | null;

  constructor(
    story: string,
    source: StorySource,
    warningMessage: string = '',
    errorCategory: ErrorCategory | null = null
  ) {
    this.story = story;
    this.source = source;
    this.warningMessage = warningMessage;
    this.errorCategory = errorCategory;
  }
}

export interface StoryGenerationRequest {
  targetWord: string;
  supportWords: string[];
  minWords: number;
  maxWords: number;
  minTargetOccurrences: number;
  maxTargetOccurrences: number;
  style: ContextStyle;
  difficulty: DifficultyLevel;
}

export interface StoryFastGenerationResult {
  initial: StoryGenerationOutcome;
  upgradePromise: Promise<StoryGenerationOutcome> | null;
}

export class StoryGenerationPipeline {
  private generator: StoryGenerator;
  private offlineGenerator: OfflineContextGenerator;

  constructor(generator: StoryGenerator, offlineGenerator?: OfflineContextGenerator) {
    this.generator = generator;
    this.offlineGenerator = offlineGenerator ?? OfflineContextGenerator.getInstance();
  }

  private getSeedForRequest(request: StoryGenerationRequest): number {
    const now = new Date();
    const y = now.getFullYear();
    const m = now.getMonth() + 1;
    const d = now.getDate();
    const dayKey = `${y}-${m}-${d}`;
    const seedStr =
      `${dayKey}|${request.targetWord}|${request.supportWords.join(',')}|${request.minWords}-${request.maxWords}` +
      `|${request.minTargetOccurrences}-${request.maxTargetOccurrences}|${request.style}|${request.difficulty}`;
    return this.hashToUint32(seedStr);
  }

  private hashToUint32(input: string): number {
    let hash = 2166136261;
    for (let i = 0; i < input.length; i++) {
      hash ^= input.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  private countWords(text: string): number {
    const matches = text.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g);
    return matches === null ? 0 : matches.length;
  }

  private countTargetOccurrences(text: string, targetWord: string): number {
    const target = targetWord.trim();
    if (target.length === 0) {
      return 0;
    }
    const escaped = target.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(`\\b${escaped}\\b`, 'gi');
    const matches = text.match(re);
    return matches === null ? 0 : matches.length;
  }

  private trimToMaxWords(text: string, maxWords: number): string {
    if (maxWords <= 0) {
      return text;
    }
    const sentences: string[] = [];
    let cur = '';
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i);
      cur += ch;
      if (ch === '.' || ch === '!' || ch === '?') {
        const s = cur.trim();
        if (s.length > 0) {
          sentences.push(s);
        }
        cur = '';
      }
    }
    const last = cur.trim();
    if (last.length > 0) {
      sentences.push(last);
    }

    let out = '';
    for (const s of sentences) {
      const next = out.length === 0 ? s : `${out} ${s}`;
      if (this.countWords(next) <= maxWords) {
        out = next;
      } else {
        break;
      }
    }
    if (out.length > 0) return out.trim();
    const words = text.trim().split(/\s+/);
    const sliced = words.slice(0, Math.max(1, maxWords)).join(' ');
    return sliced.trim();
  }

  private buildPadSentence(
    seed: number,
    index: number,
    targetWord: string,
    supportWords: string[],
    allowTarget: boolean
  ): string {
    const sw = supportWords.length > 0 ? supportWords[(seed + index) % supportWords.length] : '';
    const withTarget: string[] = [
      `Later, I noticed ${targetWord} again in the same scene.`,
      `In the end, ${targetWord} stayed in my mind and felt easy to recall.`,
      sw.length > 0 ? `I kept thinking about ${targetWord} and how it connected to ${sw}.` : `I kept thinking about ${targetWord} and how it fit the moment.`,
      sw.length > 0 ? `Soon, ${targetWord} showed up near ${sw}, and the meaning felt clearer.` : `Soon, ${targetWord} showed up again, and the meaning felt clearer.`,
      `That small detail made ${targetWord} feel real, not just a word on a page.`
    ];
    const withoutTarget: string[] = [
      'The details were simple, but they made the moment feel real.',
      sw.length > 0 ? `I also thought about ${sw} and the surrounding details.` : 'I also thought about the surrounding details.',
      'The scene felt ordinary, yet it was easy to remember.',
      'The meaning became clearer as the story moved forward.',
      'It was short, but it left a small impression.'
    ];

    const pool = allowTarget ? withTarget : withoutTarget;
    const idx = (seed + index) % pool.length;
    return pool[idx];
  }

  private buildIntroSentence(seed: number, supportWords: string[]): string {
    const sw = supportWords.length > 0 ? supportWords[seed % supportWords.length] : '';
    const pool: string[] = [
      'One quiet morning, everything felt a little different.',
      'On the way home, I noticed something I had missed before.',
      'In a small moment, the details suddenly mattered.',
      'During a simple conversation, the idea became clearer.',
      sw.length > 0 ? `While thinking about ${sw}, the scene started to make sense.` : 'While thinking about it, the scene started to make sense.',
      'Without warning, the situation changed in a small but memorable way.'
    ];
    return pool[seed % pool.length];
  }

  private enforceConstraints(text: string, request: StoryGenerationRequest): string {
    let out = text.replace(/\s+/g, ' ').trim();
    if (out.length === 0) {
      return out;
    }

    const seed = this.getSeedForRequest(request);
    if ((seed % 2) === 0) {
      const intro = this.buildIntroSentence(seed, request.supportWords);
      if (intro.trim().length > 0) {
        out = `${intro} ${out}`.trim();
      }
    }
    let occ = this.countTargetOccurrences(out, request.targetWord);
    let tries = 0;
    while (occ < request.minTargetOccurrences && tries < 8) {
      const s = this.buildPadSentence(seed, tries, request.targetWord, request.supportWords, true);
      out = `${out} ${s}`.trim();
      occ = this.countTargetOccurrences(out, request.targetWord);
      tries++;
    }

    let wc = this.countWords(out);
    let padTries = 0;
    while (request.minWords > 0 && wc < request.minWords && padTries < 20) {
      const allowTarget = occ < request.maxTargetOccurrences;
      const s = this.buildPadSentence(seed, tries + padTries, request.targetWord, request.supportWords, allowTarget);
      out = `${out} ${s}`.trim();
      occ = this.countTargetOccurrences(out, request.targetWord);
      wc = this.countWords(out);
      padTries++;
    }

    if (request.maxWords > 0 && wc > request.maxWords) {
      out = this.trimToMaxWords(out, request.maxWords);
    }

    return out.trim();
  }

  async generateFastFirst(request: StoryGenerationRequest): Promise<StoryFastGenerationResult> {
    const target = request.targetWord.trim();
    const supports = request.supportWords;
    if (this.generator.getCachedVignetteOnly !== undefined) {
      const cached = await this.generator.getCachedVignetteOnly(target);
      if (cached !== null && cached.trim().length > 0) {
        const sanitized = TextSanitizer.sanitizeContext(cached);
        let adjusted = TextSanitizer.sanitizeContext(sanitized);
        if (request.maxWords > 0 && this.countWords(adjusted) > request.maxWords) {
          adjusted = this.trimToMaxWords(adjusted, request.maxWords);
        }
        const occ = this.countTargetOccurrences(adjusted, request.targetWord);
        const wc = this.countWords(adjusted);
        if (request.minWords > 0 && wc < request.minWords) {
          adjusted = '';
        }
        if (request.minTargetOccurrences > 0 && occ < request.minTargetOccurrences) {
          adjusted = '';
        }
        if (adjusted.length > 0) {
          const canUpgrade = this.generator.isConfigured !== undefined && this.generator.isConfigured();
          const upgradePromise: Promise<StoryGenerationOutcome> | null = canUpgrade ? this.generate(request) : null;
          return {
            initial: new StoryGenerationOutcome(adjusted, StorySource.CACHE),
            upgradePromise: upgradePromise
          };
        }
      }
    }
    const offline = this.offlineGenerator.generateContext(
      target,
      supports,
      request.style,
      request.difficulty
    );

    let initial: StoryGenerationOutcome;
    if (offline.success && offline.context.trim().length > 0) {
      const sanitized = TextSanitizer.sanitizeContext(offline.context);
      const adjusted = TextSanitizer.sanitizeContext(this.enforceConstraints(sanitized, request));
      initial = new StoryGenerationOutcome(adjusted, StorySource.OFFLINE);
    } else {
      const minimal = `After class, I had to ${target}. It felt simple and easy to remember.`;
      const sanitizedMinimal = TextSanitizer.sanitizeContext(minimal);
      const adjustedMinimal = TextSanitizer.sanitizeContext(this.enforceConstraints(sanitizedMinimal, request));
      initial = new StoryGenerationOutcome(adjustedMinimal, StorySource.MINIMAL);
    }

    const canUpgrade = this.generator.isConfigured !== undefined && this.generator.isConfigured();
    const upgradePromise: Promise<StoryGenerationOutcome> | null = canUpgrade ? this.generate(request) : null;
    const result: StoryFastGenerationResult = {
      initial: initial,
      upgradePromise: upgradePromise
    };
    return result;
  }

  async generate(request: StoryGenerationRequest): Promise<StoryGenerationOutcome> {
    const target = request.targetWord.trim();
    const supports = request.supportWords;
    console.log('[StoryGenerationPipeline] Generating story for:', target);

    try {
      const result = await this.generator.generateStory(
        target,
        supports,
        request.minWords,
        request.maxWords,
        request.minTargetOccurrences,
        request.maxTargetOccurrences,
        false
      );

      if (result.success && result.story.trim().length > 0) {
        const sanitized = TextSanitizer.sanitizeContext(result.story);
        if (result.origin === StoryOrigin.AI) {
          return new StoryGenerationOutcome(sanitized, StorySource.AI);
        }
        if (result.origin === StoryOrigin.CACHE) {
          return new StoryGenerationOutcome(sanitized, StorySource.CACHE);
        }
        if (result.origin === StoryOrigin.MINIMAL) {
          return new StoryGenerationOutcome(sanitized, StorySource.MINIMAL);
        }
        return new StoryGenerationOutcome(sanitized, StorySource.OFFLINE);
      }

      const rawError = result.error.length > 0
        ? result.error
        : 'parse error: empty story';
      const info = buildUserFacingError(rawError);
      return await this.generateOfflineFallback(request, info.userMessage, info.category);
    } catch (e) {
      const rawError = e instanceof Error ? e.message : String(e);
      const info = buildUserFacingError(rawError);
      return await this.generateOfflineFallback(request, info.userMessage, info.category);
    }
  }

  private async generateOfflineFallback(
    request: StoryGenerationRequest,
    warningMessage: string,
    category: ErrorCategory
  ): Promise<StoryGenerationOutcome> {
    console.warn('[StoryGenerationPipeline] Falling back to offline story generation:', warningMessage);

    const offline = this.offlineGenerator.generateContext(
      request.targetWord,
      request.supportWords,
      request.style,
      request.difficulty
    );

    if (offline.success && offline.context.trim().length > 0) {
      const sanitized = TextSanitizer.sanitizeContext(offline.context);
      const adjusted = TextSanitizer.sanitizeContext(this.enforceConstraints(sanitized, request));
      return new StoryGenerationOutcome(
        adjusted,
        StorySource.OFFLINE,
        `${warningMessage}，已使用离线兜底。`,
        category
      );
    }

    const minimal = `After class, I had to ${request.targetWord}. It felt simple and easy to remember.`;
    const sanitizedMinimal = TextSanitizer.sanitizeContext(minimal);
    const adjustedMinimal = TextSanitizer.sanitizeContext(this.enforceConstraints(sanitizedMinimal, request));
    return new StoryGenerationOutcome(
      adjustedMinimal,
      StorySource.MINIMAL,
      `${warningMessage}，已使用最小兜底。`,
      category
    );
  }
}
