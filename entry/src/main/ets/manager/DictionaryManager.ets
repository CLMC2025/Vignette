// =====================================================
// DictionaryManager.ets - Facade for Dictionary Operations
// Delegates to DictionaryCache, AiClient, PromptBuilder
// =====================================================

import resourceManager from '@ohos.resourceManager';
import { WordDefinition } from '../model/WordModel';
import { DBManager } from '../database/DBManager';
import { TemplateManager, ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import { OfflineContextGenerator, GenerationResult } from '../context/OfflineContext';
import { ContextValidator, ValidationResult, ValidationIssue, ValidationIssueType, IssueSeverity } from '../context/ContextValidator';
import { StoryGenerator } from '../context/StoryGenerationPipeline';
import { Constants } from '../utils/Constants';

import { CacheStats, LookupResult, StoryResult, StoryOrigin, ContextGenerationResult, ContextImprovementResult, ContextGenerationStats } from './dictionary/DictionaryModels';
import { DictionaryCache } from './dictionary/DictionaryCache';
import { AiClient } from './dictionary/AiClient';
import { PromptBuilder } from './dictionary/PromptBuilder';
import { ResponseParser } from './dictionary/ResponseParser';
import { BuiltInDictionary, BuiltInDictStats } from './BuiltInDictionary';

// Re-export for consumers
export { CacheStats, LookupResult, StoryResult, StoryOrigin } from './dictionary/DictionaryModels';
export { TTSPlayer } from './TTSPlayer';

export class DictionaryManager implements StoryGenerator {
  private static instance: DictionaryManager | null = null;

  private cache: DictionaryCache = DictionaryCache.getInstance();
  private aiClient: AiClient = AiClient.getInstance();
  private promptBuilder: PromptBuilder = PromptBuilder.getInstance();
  private parser: ResponseParser = ResponseParser.getInstance();
  private builtInDict: BuiltInDictionary = BuiltInDictionary.getInstance();
  
  // DB (for vignette cache)
  private db: DBManager = DBManager.getInstance();

  // Context Generation
  private templateManager: TemplateManager = TemplateManager.getInstance();
  private offlineGenerator: OfflineContextGenerator = OfflineContextGenerator.getInstance();
  private contextValidator: ContextValidator = ContextValidator.getInstance();
  private defaultContextStyle: ContextStyle = ContextStyle.RANDOM;
  private defaultDifficultyLevel: DifficultyLevel = DifficultyLevel.CET4;

  // Offline vignette cache settings
  private vignetteCacheEnabled: boolean = true;
  private vignetteCacheMaxBytes: number = Constants.CACHE_VIGNETTE_CACHE_MAX_SIZE_MB * 1_000_000;
  private vignetteCacheMaxEntries: number = Constants.CACHE_VIGNETTE_CACHE_MAX_ENTRIES;
  private vignetteCacheMaxVariantsPerWord: number = 3;

  private constructor() {}

  static getInstance(): DictionaryManager {
    if (DictionaryManager.instance === null) {
      DictionaryManager.instance = new DictionaryManager();
    }
    return DictionaryManager.instance;
  }

  configure(baseUrl: string, apiKey: string, model: string = 'deepseek-chat'): void {
    this.aiClient.configure(baseUrl, apiKey, model);
    console.info('[DictionaryManager] API configured');
  }

  setResourceManager(rm: resourceManager.ResourceManager): void {
    this.builtInDict.setResourceManager(rm);
  }

  async initializeBuiltInDictionary(): Promise<void> {
    await this.builtInDict.initialize();
  }

  getBuiltInDictStats(): BuiltInDictStats {
    return this.builtInDict.getStats();
  }

  setVignetteCacheSettings(enabled: boolean, maxBytes: number, maxEntries: number): void {
    this.vignetteCacheEnabled = enabled;
    this.vignetteCacheMaxBytes = Math.max(100_000, maxBytes);
    this.vignetteCacheMaxEntries = Math.max(50, maxEntries);
  }

  setVignetteVariantSettings(maxVariantsPerWord: number): void {
    this.vignetteCacheMaxVariantsPerWord = Math.max(1, maxVariantsPerWord);
  }

  isConfigured(): boolean {
    return this.aiClient.isConfigured();
  }

  getStats(): CacheStats {
    return this.cache.getStats();
  }

  clearMemoryCache(): void {
    this.cache.clearMemoryCache();
  }

  peekDefinition(word: string): WordDefinition | null {
    const normalizedWord = word.toLowerCase().trim();
    if (normalizedWord.length === 0) {
      return null;
    }
    const cached = this.cache.getFromMemoryCache(normalizedWord);
    if (cached === null) {
      return null;
    }
    return WordDefinition.fromJSON(cached.toJSON());
  }

  async lookup(word: string, context: string = '', forceAI: boolean = false): Promise<LookupResult> {
    const normalizedWord = word.toLowerCase().trim();

    if (normalizedWord.length === 0) {
      return LookupResult.createFailure('Empty word');
    }

    if (normalizedWord.length > 100) {
      return LookupResult.createFailure('Word too long');
    }

    if (!/^[a-zA-Z'\-]+$/.test(normalizedWord)) {
      return LookupResult.createFailure('Invalid word format');
    }

    if (!forceAI) {
      const memoryResult = this.cache.getFromMemoryCache(normalizedWord);
      if (memoryResult !== null) {
        this.cache.recordMemoryHit();
        console.info(`[DictionaryManager] Memory cache hit: ${normalizedWord}`);

        if (memoryResult.hasBasicInfo() && memoryResult.isLocalDefinition()) {
          return LookupResult.createSuccess(memoryResult, 'local');
        }

        if (context.length > 0 && this.isConfigured()) {
          const contextDef = await this.getContextMeaning(memoryResult, context);
          return LookupResult.createSuccess(contextDef, 'memory');
        }

        return LookupResult.createSuccess(memoryResult, 'memory');
      }
    }

    if (!forceAI) {
      const dbResult = await this.cache.getFromDb(normalizedWord);
      if (dbResult !== null) {
        this.cache.recordDbHit();
        console.info(`[DictionaryManager] DB cache hit: ${normalizedWord}`);

        this.cache.addToMemoryCache(normalizedWord, dbResult);

        if (dbResult.hasBasicInfo() && dbResult.isLocalDefinition()) {
          return LookupResult.createSuccess(dbResult, 'local');
        }

        if (context.length > 0 && this.isConfigured()) {
          const contextDef = await this.getContextMeaning(dbResult, context);
          return LookupResult.createSuccess(contextDef, 'db');
        }

        return LookupResult.createSuccess(dbResult, 'db');
      }
    }

    if (!forceAI) {
      const builtInResult = await this.builtInDict.lookup(normalizedWord);
      if (builtInResult !== null && builtInResult.hasBasicInfo()) {
        console.info(`[DictionaryManager] Built-in dict hit: ${normalizedWord}`);
        
        this.cache.addToMemoryCache(normalizedWord, builtInResult);
        await this.cache.cacheToDb(normalizedWord, builtInResult);
        
        return LookupResult.createSuccess(builtInResult, 'builtin');
      }
    }

    if (!this.isConfigured()) {
      this.cache.recordMiss();
      return LookupResult.createFailure('API not configured.Please set your API key in Settings.');
    }

    try {
      const aiResult = await this.fetchFromAI(normalizedWord, context);
      this.cache.recordApiHit();
      console.info(`[DictionaryManager] AI API hit: ${normalizedWord}`);

      this.cache.addToMemoryCache(normalizedWord, aiResult);
      await this.cache.cacheToDb(normalizedWord, aiResult);

      return LookupResult.createSuccess(aiResult, 'ai');
    } catch (e) {
      this.cache.recordMiss();
      const errMsg = this.parser.formatError(e);
      console.error(`[DictionaryManager] AI lookup failed: ${errMsg}`);
      return LookupResult.createFailure(`API error: ${errMsg}`);
    }
  }

  async enhanceDefinition(word: string): Promise<LookupResult> {
    return await this.lookup(word, '', true);
  }

  private async fetchFromAI(word: string, context: string): Promise<WordDefinition> {
    const prompt = this.promptBuilder.buildDefinitionPrompt(word, context);
    const response = await this.aiClient.callAI(prompt);
    return this.parser.parseDefinitionResponse(word, response);
  }

  private async getContextMeaning(
    definition: WordDefinition,
    context: string
  ): Promise<WordDefinition> {
    if (!this.isConfigured()) {
      return definition;
    }

    try {
      const prompt = this.promptBuilder.buildContextPrompt(definition.word, context);
      const response = await this.aiClient.callAI(prompt);

      const contextMeaning = this.parser.parseContextResponse(response);

      const updatedDef = WordDefinition.fromJSON(definition.toJSON());
      updatedDef.contextMeaning = contextMeaning;

      return updatedDef;
    } catch (e) {
      const errMsg = this.parser.formatError(e);
      console.warn(`[DictionaryManager] Context lookup failed: ${errMsg}`);
      return definition;
    }
  }

  async lookupContextMeaning(word: string, context: string): Promise<string> {
    const normalizedWord = word.trim();
    if (normalizedWord.length === 0) return '';
    const normalizedContext = context.trim();
    if (normalizedContext.length === 0) return '';
    if (!this.isConfigured()) return '';

    try {
      const prompt = this.promptBuilder.buildContextPrompt(normalizedWord, normalizedContext);
      const response = await this.aiClient.callAI(prompt);
      return this.parser.parseContextResponse(response);
    } catch (e) {
      const errMsg = this.parser.formatError(e);
      console.warn(`[DictionaryManager] Context lookup failed: ${errMsg}`);
      return '';
    }
  }

  async generateStory(
    targetWord: string,
    supportWords: string[],
    minWords: number = 50,
    maxWords: number = 70,
    minTargetOccurrences: number = 2,
    maxTargetOccurrences: number = 3,
    preferCacheFirst: boolean = true
  ): Promise<StoryResult> {
    const normalizedTarget = targetWord.trim();
    const cleanedSupport: string[] = supportWords
      .map((w: string): string => w.trim())
      .filter((w: string): boolean => w.length > 0 && w.toLowerCase() !== normalizedTarget.toLowerCase());

    if (preferCacheFirst) {
      const cachedPreferred = await this.tryGetCachedVignette(normalizedTarget);
      if (cachedPreferred !== null) {
        const validation = this.contextValidator.validate(
          cachedPreferred,
          normalizedTarget,
          this.defaultDifficultyLevel,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences
        );
        if (validation.isValid) {
          if (this.isConfigured()) {
            void this.refreshCachedVignetteInBackground(
              normalizedTarget,
              cleanedSupport,
              minWords,
              maxWords,
              minTargetOccurrences,
              maxTargetOccurrences
            );
          }
          return StoryResult.createSuccess(cachedPreferred, StoryOrigin.CACHE);
        }
      }
    }

    const effectiveStyle = this.resolveContextStyle(this.defaultContextStyle);
    const effectiveDifficulty = this.defaultDifficultyLevel;

    if (this.isConfigured()) {
      try {
        const prompt = this.promptBuilder.buildEnhancedPrompt(
          normalizedTarget,
          cleanedSupport,
          effectiveStyle,
          effectiveDifficulty,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences
        );

        const response = await this.aiClient.callAI(prompt);
        const story = this.parser.parseStoryResponse(response, normalizedTarget, cleanedSupport);

        const validation = this.contextValidator.validate(
          story,
          normalizedTarget,
          effectiveDifficulty,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences
        );
        if (validation.isValid) {
          await this.cacheVignetteIfEnabled(normalizedTarget, story);
          return StoryResult.createSuccess(story, StoryOrigin.AI);
        }

        console.warn(`[DictionaryManager] Story validation failed, fallback offline: ${validation.getSummary()}`);
      } catch (e) {
        const errMsg = this.parser.formatError(e);
        console.warn(`[DictionaryManager] Story AI failed, fallback offline: ${errMsg}`);
      }
    } else {
      console.info('[DictionaryManager] API not configured, using offline story generation');
    }

    const cached = await this.tryGetCachedVignette(normalizedTarget);
    if (cached !== null) {
      const validation = this.contextValidator.validate(
        cached,
        normalizedTarget,
        this.defaultDifficultyLevel,
        minWords,
        maxWords,
        minTargetOccurrences,
        maxTargetOccurrences
      );
      if (validation.isValid) {
        return StoryResult.createSuccess(cached, StoryOrigin.CACHE);
      }
    }

    const offline = this.generateContextOffline(
      normalizedTarget,
      cleanedSupport,
      effectiveStyle,
      effectiveDifficulty
    );

    if (offline.context.length > 0) {
      const adjustedOffline = this.enforceContextConstraints(
        offline.context,
        normalizedTarget,
        cleanedSupport,
        minWords,
        maxWords,
        minTargetOccurrences,
        maxTargetOccurrences
      );
      return StoryResult.createSuccess(adjustedOffline, StoryOrigin.OFFLINE);
    }

    const minimal = this.enforceContextConstraints(
      this.buildMinimalStory(normalizedTarget, cleanedSupport),
      normalizedTarget,
      cleanedSupport,
      minWords,
      maxWords,
      minTargetOccurrences,
      maxTargetOccurrences
    );
    return StoryResult.createSuccess(minimal, StoryOrigin.MINIMAL);
  }

  private async refreshCachedVignetteInBackground(
    targetWord: string,
    supportWords: string[],
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number
  ): Promise<void> {
    if (!this.vignetteCacheEnabled || !this.isConfigured()) {
      return;
    }
    const normalizedTarget = targetWord.trim();
    if (normalizedTarget.length === 0) {
      return;
    }
    try {
      const effectiveStyle = this.resolveContextStyle(this.defaultContextStyle);
      const effectiveDifficulty = this.defaultDifficultyLevel;
      const prompt = this.promptBuilder.buildEnhancedPrompt(
        normalizedTarget,
        supportWords,
        effectiveStyle,
        effectiveDifficulty,
        minWords,
        maxWords,
        minTargetOccurrences,
        maxTargetOccurrences
      );
      const response = await this.aiClient.callAI(prompt);
      const story = this.parser.parseStoryResponse(response, normalizedTarget, supportWords);
      const validation = this.contextValidator.validate(
        story,
        normalizedTarget,
        effectiveDifficulty,
        minWords,
        maxWords,
        minTargetOccurrences,
        maxTargetOccurrences
      );
      if (validation.isValid) {
        await this.cacheVignetteIfEnabled(normalizedTarget, story);
      }
    } catch (e) {
      return;
    }
  }

  private buildMinimalStory(targetWord: string, supportWords: string[]): string {
    const sw = supportWords.slice(0, 2);
    const parts: string[] = [];

    if (sw.length > 0) {
      parts.push(`After class, I met my friend and we talked about ${sw[0]}.`);
    } else {
      parts.push('After class, I walked home and thought about my day.');
    }

    if (sw.length > 1) {
      parts.push(`Suddenly, I had to ${targetWord} because ${sw[1]} surprised us.`);
    } else {
      parts.push(`Suddenly, I had to ${targetWord}, and I learned something new.`);
    }

    parts.push('It felt simple, real, and easy to remember.');

    return parts.join(' ');
  }

  private enforceContextConstraints(
    context: string,
    targetWord: string,
    supportWords: string[],
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number
  ): string {
    let out = context.replace(/\s+/g, ' ').trim();
    if (out.length === 0) return out;

    let occ = this.countTargetWordOccurrences(out, targetWord);
    let tries = 0;
    while (occ < minTargetOccurrences && tries < 4) {
      const sw = supportWords.length > 0 ? supportWords[tries % supportWords.length] : '';
      if (sw.length > 0) {
        out = `${out} Later, ${targetWord} appeared again near ${sw}.`;
      } else {
        out = `${out} Later, I noticed ${targetWord} again in the same scene.`;
      }
      occ = this.countTargetWordOccurrences(out, targetWord);
      tries++;
    }

    let wc = this.countWords(out);
    let padTries = 0;
    while (minWords > 0 && wc < minWords && padTries < 6) {
      const canUseTarget = occ < maxTargetOccurrences;
      const sw = supportWords.length > 0 ? supportWords[padTries % supportWords.length] : '';
      if (canUseTarget) {
        if (sw.length > 0) {
          out = `${out} I kept reading, and ${targetWord} felt connected to ${sw}.`;
        } else {
          out = `${out} I kept reading, and ${targetWord} started to feel familiar.`;
        }
        occ = this.countTargetWordOccurrences(out, targetWord);
      } else {
        if (sw.length > 0) {
          out = `${out} I kept reading, thinking about ${sw} and the surrounding details.`;
        } else {
          out = `${out} I kept reading, focusing on the surrounding details.`;
        }
      }
      wc = this.countWords(out);
      padTries++;
    }

    if (maxWords > 0 && wc > maxWords) {
      out = this.trimToMaxWords(out, maxWords);
    }
    return out;
  }

  private trimToMaxWords(text: string, maxWords: number): string {
    const sentences: string[] = [];
    let cur = '';
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i);
      cur += ch;
      if (ch === '.' || ch === '!' || ch === '?') {
        const s = cur.trim();
        if (s.length > 0) sentences.push(s);
        cur = '';
      }
    }
    const last = cur.trim();
    if (last.length > 0) sentences.push(last);

    let out = '';
    for (const s of sentences) {
      const next = out.length === 0 ? s : `${out} ${s}`;
      if (this.countWords(next) <= maxWords) {
        out = next;
      } else {
        break;
      }
    }
    return out.length > 0 ? out : text;
  }

  private countWords(text: string): number {
    const matches = text.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g);
    if (matches === null) {
      const trimmed = text.trim();
      if (trimmed.length === 0) return 0;
      const parts = trimmed.split(/\s+/).filter((s: string): boolean => s.length > 0);
      return parts.length;
    }
    return matches.length;
  }

  private countTargetWordOccurrences(text: string, targetWord: string): number {
    const escaped = this.escapeRegExp(targetWord.trim());
    if (escaped.length === 0) return 0;
    const re = new RegExp(`\\b${escaped}\\b`, 'gi');
    const matches = text.match(re);
    return matches === null ? 0 : matches.length;
  }

  private escapeRegExp(text: string): string {
    return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  private async tryGetCachedVignette(targetWord: string): Promise<string | null> {
    if (!this.vignetteCacheEnabled) {
      return null;
    }
    const key = targetWord.trim().toLowerCase();
    if (key.length === 0) return null;

    try {
      const v = await this.db.getCachedVignette(key);
      if (v.length === 0) return null;

      if (!v.toLowerCase().includes(key)) {
        return null;
      }

      const validation = this.contextValidator.validate(v, key, this.defaultDifficultyLevel);
      if (validation.isValid) {
        return v;
      }

      console.warn(`[DictionaryManager] Cached vignette validation failed: ${validation.getSummary()}`);
      return v;
    } catch (e) {
      const errMsg = this.parser.formatError(e);
      console.warn(`[DictionaryManager] getCachedVignette failed: ${errMsg}`);
      return null;
    }
  }

  async getCachedVignetteOnly(targetWord: string): Promise<string | null> {
    return await this.tryGetCachedVignette(targetWord);
  }

  private async cacheVignetteIfEnabled(targetWord: string, story: string): Promise<void> {
    if (!this.vignetteCacheEnabled) {
      return;
    }
    const key = targetWord.trim().toLowerCase();
    if (key.length === 0 || story.trim().length === 0) {
      return;
    }

    try {
      await this.db.upsertVignetteCache(key, story);
      await this.db.pruneVignetteCache(this.vignetteCacheMaxBytes, this.vignetteCacheMaxEntries);
    } catch (e) {
      const errMsg = this.parser.formatError(e);
      console.warn(`[DictionaryManager] cache vignette failed: ${errMsg}`);
    }
  }

  async getVignetteVariantCount(targetWord: string): Promise<number> {
    if (!this.vignetteCacheEnabled) {
      return 0;
    }
    const key = targetWord.trim().toLowerCase();
    if (key.length === 0) {
      return 0;
    }
    try {
      return await this.db.getVignetteVariantCount(key);
    } catch (e) {
      return 0;
    }
  }

  async warmVignetteVariants(
    targetWord: string,
    supportWords: string[],
    desiredVariants: number,
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number,
    style: ContextStyle,
    difficulty: DifficultyLevel
  ): Promise<void> {
    if (!this.vignetteCacheEnabled || !this.isConfigured()) {
      return;
    }
    const normalizedTarget = targetWord.trim();
    if (normalizedTarget.length === 0) {
      return;
    }
    const cleanedSupport: string[] = supportWords
      .map((w: string): string => w.trim())
      .filter((w: string): boolean => w.length > 0 && w.toLowerCase() !== normalizedTarget.toLowerCase());
    const want = Math.max(1, desiredVariants);
    const currentCount = await this.getVignetteVariantCount(normalizedTarget);
    const maxToWarm = Math.min(want, this.vignetteCacheMaxVariantsPerWord);
    if (currentCount >= maxToWarm) {
      return;
    }
    console.log(
      '[DictionaryManager] Warm vignette variants: word=' + normalizedTarget +
      ', existing=' + String(currentCount) +
      ', target=' + String(maxToWarm)
    );
    const missing = maxToWarm - currentCount;
    for (let i = 0; i < missing; i++) {
      try {
        const variationKey = `${Date.now()}|${normalizedTarget}|${currentCount + i}`;
        const prompt = this.promptBuilder.buildEnhancedPromptWithVariation(
          normalizedTarget,
          cleanedSupport,
          style,
          difficulty,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences,
          variationKey
        );
        const response = await this.aiClient.callAI(prompt);
        const story = this.parser.parseStoryResponse(response, normalizedTarget, cleanedSupport);
        const validation = this.contextValidator.validate(
          story,
          normalizedTarget,
          difficulty,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences
        );
        if (validation.isValid) {
          await this.cacheVignetteIfEnabled(normalizedTarget, story);
        }
      } catch (e) {
        return;
      }
    }
  }

  getTTSUrl(word: string, type: number = 1): string {
    const encoded = encodeURIComponent(word.trim().toLowerCase());
    return `https://dict.youdao.com/dictvoice?audio=${encoded}&type=${type}`;
  }

  async preloadDefinitions(words: string[]): Promise<number> {
    let loaded = 0;

    for (const word of words) {
      const cached = this.cache.getFromMemoryCache(word.toLowerCase());
      if (cached !== null) {
        continue;
      }

      try {
        const result = await this.lookup(word);
        if (result.success) {
          loaded++;
        }
      } catch (e) {
        const errMsg = this.parser.formatError(e);
        console.warn(`[DictionaryManager] Preload failed for ${word}: ${errMsg}`);
      }
      
      // Delay helper needed, but I don't have it anymore.
      // I'll assume usage of setTimeout in a Promise.
      await new Promise<void>(resolve => setTimeout(resolve, 100));
    }

    console.info(`[DictionaryManager] Preloaded ${loaded}/${words.length} definitions`);
    return loaded;
  }

  setContextPreferences(style: ContextStyle, difficulty: DifficultyLevel, customStyle: string = ''): void {
    this.defaultContextStyle = style;
    this.promptBuilder.setCustomContextStyle(customStyle);
    this.defaultDifficultyLevel = difficulty;
  }

  async generateContextWithAI(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle = this.defaultContextStyle,
    difficulty: DifficultyLevel = this.defaultDifficultyLevel
  ): Promise<ContextGenerationResult> {
    const effectiveStyle = this.resolveContextStyle(style);
    const effectiveDifficulty = difficulty;
    if (!this.isConfigured()) {
      return this.generateContextOffline(targetWord, supportWords, effectiveStyle, effectiveDifficulty);
    }

    try {
      const prompt = this.promptBuilder.buildEnhancedPrompt(targetWord, supportWords, effectiveStyle, effectiveDifficulty, 50, 70, 2, 3);
      const response = await this.aiClient.callAI(prompt);
      const context = this.parser.parseStoryResponse(response, targetWord, supportWords);

      const validation = this.contextValidator.validate(context, targetWord, effectiveDifficulty, 50, 70, 2, 3);

      return { context, validation };
    } catch (e) {
      const errMsg = this.parser.formatError(e);
      console.error('[DictionaryManager] AI context generation failed:', errMsg);
      
      return this.generateContextOffline(targetWord, supportWords, effectiveStyle, effectiveDifficulty);
    }
  }

  generateContextOffline(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle = this.defaultContextStyle,
    difficulty: DifficultyLevel = this.defaultDifficultyLevel
  ): ContextGenerationResult {
    const result = this.offlineGenerator.generateContext(
      targetWord,
      supportWords,
      style,
      difficulty
    );

    if (!result.success) {
      const validation = new ValidationResult();
      validation.addIssue(new ValidationIssue(
        ValidationIssueType.SEMANTIC_ERROR,
        IssueSeverity.ERROR,
        result.error,
        '尝试使用AI生成或检查词汇拼写'
      ));
      validation.isValid = false;

      return { context: '', validation };
    }

    const validation = this.contextValidator.validate(result.context, targetWord, difficulty);

    return { context: result.context, validation };
  }

  async translateStory(story: string): Promise<string> {
    if (!story || story.length === 0) {
      return '';
    }

    try {
      const prompt = `请将以下英文故事翻译成中文，保持原意和风格：\n\n${story}`;
      const response = await this.aiClient.callAI(prompt);
      return response.trim();
    } catch (error) {
      console.error('[DictionaryManager] Story translation failed:', error);
      return '';
    }
  }

  private resolveContextStyle(style: ContextStyle): ContextStyle {
    if (style !== ContextStyle.RANDOM) {
      return style;
    }
    const styles: ContextStyle[] = [
      ContextStyle.CONVERSATIONAL,
      ContextStyle.FORMAL,
      ContextStyle.HUMOROUS,
      ContextStyle.NARRATIVE,
      ContextStyle.TECHNICAL
    ];
    const idx = Math.floor(Math.random() * styles.length);
    return styles[idx];
  }

  async generateMultipleContexts(
    targetWord: string,
    supportWords: string[],
    count: number = 3,
    useAI: boolean = true
  ): Promise<ContextGenerationResult[]> {
    const results: ContextGenerationResult[] = [];

    for (let i = 0; i < count; i++) {
      if (useAI && this.isConfigured()) {
        const result = await this.generateContextWithAI(
          targetWord,
          supportWords,
          this.defaultContextStyle,
          this.defaultDifficultyLevel
        );
        results.push(result);
      } else {
        const result = this.generateContextOffline(
          targetWord,
          supportWords,
          this.defaultContextStyle,
          this.defaultDifficultyLevel
        );
        results.push(result);
      }
    }

    return results;
  }

  getBestContext(
    contexts: ContextGenerationResult[]
  ): ContextGenerationResult {
    if (contexts.length === 0) {
      return { context: '', validation: new ValidationResult() };
    }

    contexts.sort((a, b) => b.validation.score - a.validation.score);

    return contexts[0];
  }

  validateAndImproveContext(
    context: string,
    targetWord: string,
    difficulty: DifficultyLevel = this.defaultDifficultyLevel
  ): ContextImprovementResult {
    const validation = this.contextValidator.validate(context, targetWord, difficulty);
    const improvements = this.contextValidator.generateImprovements(validation);

    let improvedContext = context;
    if (improvements.length > 0) {
      improvedContext = this.contextValidator.cleanContext(context);
    }

    return { improvedContext, validation, improvements };
  }

  getContextGenerationStats(): ContextGenerationStats {
    const templateStats = this.templateManager.getTemplateStats();
    const generatorStats = this.offlineGenerator.getGenerationStats();

    return {
      templateCount: templateStats.totalTemplates,
      wordDatabaseSize: generatorStats.totalWords,
      availableStyles: this.templateManager.getAvailableStyles().length,
      availableDifficulties: this.templateManager.getAvailableDifficulties().length
    };
  }

  isContextSuitableForAI(context: string): boolean {
    return this.contextValidator.isSuitableForAI(context);
  }

  isContextSuitableForOffline(context: string): boolean {
    return this.contextValidator.isSuitableForOffline(context);
  }

  getRecommendedDifficulty(userLevel: number): DifficultyLevel {
    return this.templateManager.recommendDifficulty(userLevel);
  }

  getAvailableContextStyles(): ContextStyle[] {
    return this.templateManager.getAvailableStyles();
  }

  getAvailableDifficultyLevels(): DifficultyLevel[] {
    return this.templateManager.getAvailableDifficulties();
  }

  getContextStyleName(style: ContextStyle): string {
    return this.templateManager.getStyleName(style);
  }

  getDifficultyName(level: DifficultyLevel): string {
    return this.templateManager.getDifficultyName(level);
  }
}
