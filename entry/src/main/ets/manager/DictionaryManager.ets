// =====================================================
// DictionaryManager.ets - 3-Level Cache Dictionary
// Level 1: Memory Map (fastest)
// Level 2: Local DB (persistent)
// Level 3: AI API (fallback)
// =====================================================

import http from '@ohos.net.http';
import { WordDefinition, WordMeaning } from '../model/WordModel';
import { DBManager } from '../database/DBManager';
import { TemplateManager, ContextStyle, DifficultyLevel, TemplateParams } from '../context/TemplateManager';
import { OfflineContextGenerator, GenerationResult } from '../context/OfflineContext';
import { ContextValidator, ValidationResult, ValidationIssue, ValidationIssueType, IssueSeverity } from '../context/ContextValidator';
import { StoryGenerator } from '../context/StoryGenerationPipeline';

/**
 * API Message structure
 */
class APIMessage {
  role: string = '';
  content:  string = '';
}

/**
 * API Choice structure
 */
class APIChoice {
  index: number = 0;
  message: APIMessage = new APIMessage();
  finish_reason: string = '';
}

/**
 * API Response structure for DeepSeek/SiliconFlow
 */
class APIResponse {
  id: string = '';
  object: string = '';
  created:  number = 0;
  model: string = '';
  choices: APIChoice[] = [];
}



/**
 * Chat completion request payload
 */
class ChatCompletionRequest {
  model: string = '';
  messages: APIMessage[] = [];
  temperature: number = 0.3;
  max_tokens: number = 500;
}

/**
 * API request options interface
 */
interface APIRequestOptions {
  method: http.RequestMethod;
  header: Record<string, string>;
  extraData: string;
  connectTimeout: number;
  readTimeout: number;
}

/**
 * Context generation result interface
 */
interface ContextGenerationResult {
  context: string;
  validation: ValidationResult;
}

/**
 * Context improvement result interface
 */
interface ContextImprovementResult {
  improvedContext: string;
  validation: ValidationResult;
  improvements: string[];
}

/**
 * Context generation statistics interface
 */
interface ContextGenerationStats {
  templateCount: number;
  wordDatabaseSize: number;
  availableStyles: number;
  availableDifficulties: number;
}

/**
 * Meaning item for parsing
 */
class MeaningItem {
  pos: string = '';
  cn: string = '';
}

/**
 * AI-generated definition structure (for parsing)
 */
class AIDefinitionResult {
  word:  string = '';
  phonetic: string = '';
  pos: string = '';
  contextMeaning: string = '';
  commonMeanings: MeaningItem[] = [];
}

/**
 * Cache statistics for debugging
 */
export class CacheStats {
  memoryHits: number = 0;
  dbHits: number = 0;
  apiHits: number = 0;
  misses: number = 0;

  getTotalRequests(): number {
    return this.memoryHits + this.dbHits + this.apiHits + this.misses;
  }

  getHitRate(): number {
    const total = this.getTotalRequests();
    if (total === 0) return 0;
    return (this.memoryHits + this.dbHits) / total;
  }
}

/**
 * Dictionary lookup result
 */
export class LookupResult {
  success: boolean;
  definition: WordDefinition | null;
  error: string;
  source: string;

  constructor(
    success: boolean = false,
    definition: WordDefinition | null = null,
    error: string = '',
    source:  string = ''
  ) {
    this.success = success;
    this.definition = definition;
    this.error = error;
    this.source = source;
  }

  static createSuccess(definition: WordDefinition, source: string): LookupResult {
    return new LookupResult(true, definition, '', source);
  }

  static createFailure(error: string): LookupResult {
    return new LookupResult(false, null, error, '');
  }
}

/**
 * Story generation result
 */
export class StoryResult {
  success:  boolean;
  story: string;
  error: string;

  constructor(success: boolean = false, story:  string = '', error:  string = '') {
    this.success = success;
    this.story = story;
    this.error = error;
  }

  static createSuccess(story: string): StoryResult {
    return new StoryResult(true, story, '');
  }

  static createFailure(error: string): StoryResult {
    return new StoryResult(false, '', error);
  }
}

/**
 * Custom Error for API errors
 */
class APIError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'APIError';
  }
}

/**
 * DictionaryManager - Singleton for word lookups with 3-level cache
 */
export class DictionaryManager implements StoryGenerator {
  private static instance: DictionaryManager | null = null;

  // Level 1: Memory cache using array-based storage for ArkTS compatibility
  private memoryCacheKeys: string[] = [];
  private memoryCacheValues: WordDefinition[] = [];
  private readonly MAX_MEMORY_CACHE_SIZE:  number = 500;

  // Statistics
  private stats: CacheStats = new CacheStats();

  // Offline vignette cache (AI-generated contexts stored in DB)
  private vignetteCacheEnabled: boolean = true;
  private vignetteCacheMaxBytes: number = 2_000_000;
  private vignetteCacheMaxEntries: number = 1000;

  // DB (for vignette cache)
  private db: DBManager = DBManager.getInstance();

  // API Configuration (loaded from AppStorage)
private apiBaseUrl: string = 'https://api.deepseek.com';
private apiKey: string = '';
private model: string = 'deepseek-chat';

// Context Generation Configuration
private templateManager: TemplateManager = TemplateManager.getInstance();
private offlineGenerator: OfflineContextGenerator = OfflineContextGenerator.getInstance();
private contextValidator: ContextValidator = ContextValidator.getInstance();
private defaultContextStyle: ContextStyle = ContextStyle.CONVERSATIONAL;
private customContextStyle: string = '';
private defaultDifficultyLevel: DifficultyLevel = DifficultyLevel.CET4;

  private constructor() {}

  /**
   * Get singleton instance
   */
  static getInstance(): DictionaryManager {
    if (DictionaryManager.instance === null) {
      DictionaryManager.instance = new DictionaryManager();
    }
    return DictionaryManager.instance;
  }

  /**
   * Configure API settings
   */
  configure(baseUrl: string, apiKey: string, model: string = 'deepseek-chat'): void {
    this.apiBaseUrl = baseUrl;
    this.apiKey = apiKey;
    this.model = model;
    console.info('[DictionaryManager] API configured');
  }

  /**
   * Configure whether to cache AI-generated contexts for offline reuse.
   */
  setVignetteCacheSettings(enabled: boolean, maxBytes: number, maxEntries: number): void {
    this.vignetteCacheEnabled = enabled;
    this.vignetteCacheMaxBytes = Math.max(100_000, maxBytes);
    this.vignetteCacheMaxEntries = Math.max(50, maxEntries);
  }

  /**
   * Check if API is configured
   */
  isConfigured(): boolean {
    return this.apiKey.length > 0;
  }

  /**
   * Get cache statistics
   */
  getStats(): CacheStats {
    return this.stats;
  }

  /**
   * Clear memory cache
   */
  clearMemoryCache(): void {
    this.memoryCacheKeys = [];
    this.memoryCacheValues = [];
    console.info('[DictionaryManager] Memory cache cleared');
  }

  /**
   * Get from memory cache
   */
  private getFromMemoryCache(word: string): WordDefinition | null {
    const index = this.memoryCacheKeys.indexOf(word);
    if (index >= 0) {
      return this.memoryCacheValues[index];
    }
    return null;
  }

  /**
   * Add to memory cache with LRU eviction
   */
  private addToMemoryCache(word: string, definition: WordDefinition): void {
    // Check if already exists
    const existingIndex = this.memoryCacheKeys.indexOf(word);
    if (existingIndex >= 0) {
      // Update existing
      this.memoryCacheValues[existingIndex] = definition;
      return;
    }

    // Evict oldest if at capacity
    if (this.memoryCacheKeys.length >= this.MAX_MEMORY_CACHE_SIZE) {
      this.memoryCacheKeys.shift();
      this.memoryCacheValues.shift();
    }

    // Add new entry
    this.memoryCacheKeys.push(word);
    this.memoryCacheValues.push(definition);
  }

  /**
   * Look up a word definition with optional context
   * @param word The word to look up
   * @param context Optional sentence context for contextual meaning
   */
  async lookup(word: string, context:  string = ''): Promise<LookupResult> {
    const normalizedWord = word.toLowerCase().trim();

    if (normalizedWord.length === 0) {
      return LookupResult.createFailure('Empty word');
    }

    // Level 1: Check memory cache
    const memoryResult = this.getFromMemoryCache(normalizedWord);
    if (memoryResult !== null) {
      this.stats.memoryHits++;
      console.info(`[DictionaryManager] Memory cache hit:  ${normalizedWord}`);

      // If context provided, update context meaning via AI
      if (context.length > 0 && this.isConfigured()) {
        const contextDef = await this.getContextMeaning(memoryResult, context);
        return LookupResult.createSuccess(contextDef, 'memory');
      }

      return LookupResult.createSuccess(memoryResult, 'memory');
    }

    // Level 2: Check DB cache
    try {
      const dbManager = DBManager.getInstance();
      const dbResult = await dbManager.getCachedDefinition(normalizedWord);

      if (dbResult !== null) {
        this.stats.dbHits++;
        console.info(`[DictionaryManager] DB cache hit:  ${normalizedWord}`);

        // Add to memory cache
        this.addToMemoryCache(normalizedWord, dbResult);

        // If context provided, update context meaning via AI
        if (context.length > 0 && this.isConfigured()) {
          const contextDef = await this.getContextMeaning(dbResult, context);
          return LookupResult.createSuccess(contextDef, 'db');
        }

        return LookupResult.createSuccess(dbResult, 'db');
      }
    } catch (e) {
      const errMsg = this.formatError(e);
      console.warn(`[DictionaryManager] DB lookup failed: ${errMsg}`);
    }

    // Level 3: Call AI API
    if (! this.isConfigured()) {
      this.stats.misses++;
      return LookupResult.createFailure('API not configured.Please set your API key in Settings.');
    }

    try {
      const aiResult = await this.fetchFromAI(normalizedWord, context);
      this.stats.apiHits++;
      console.info(`[DictionaryManager] AI API hit: ${normalizedWord}`);

      // Cache the result
      this.addToMemoryCache(normalizedWord, aiResult);
      await this.cacheToDb(normalizedWord, aiResult);

      return LookupResult.createSuccess(aiResult, 'ai');
    } catch (e) {
      this.stats.misses++;
      const errMsg = this.formatError(e);
      console.error(`[DictionaryManager] AI lookup failed: ${errMsg}`);
      return LookupResult.createFailure(`API error: ${errMsg}`);
    }
  }

  /**
   * Cache definition to database
   */
  private async cacheToDb(word: string, definition:  WordDefinition): Promise<void> {
    try {
      const dbManager = DBManager.getInstance();
      await dbManager.cacheDefinition(word, definition);
    } catch (e) {
      const errMsg = this.formatError(e);
      console.warn(`[DictionaryManager] Failed to cache to DB: ${errMsg}`);
    }
  }

  /**
   * Fetch definition from AI API
   */
  private async fetchFromAI(word: string, context: string): Promise<WordDefinition> {
    const prompt = this.buildDefinitionPrompt(word, context);
    const response = await this.callAI(prompt);

    return this.parseDefinitionResponse(word, response);
  }

  /**
   * Get context-specific meaning for a cached definition
   */
  private async getContextMeaning(
    definition: WordDefinition,
    context: string
  ): Promise<WordDefinition> {
    if (! this.isConfigured()) {
      return definition;
    }

    try {
      const prompt = this.buildContextPrompt(definition.word, context);
      const response = await this.callAI(prompt);

      // Parse just the context meaning
      const contextMeaning = this.parseContextResponse(response);

      // Clone and update definition
      const updatedDef = WordDefinition.fromJSON(definition.toJSON());
      updatedDef.contextMeaning = contextMeaning;

      return updatedDef;
    } catch (e) {
      const errMsg = this.formatError(e);
      console.warn(`[DictionaryManager] Context lookup failed: ${errMsg}`);
      return definition;
    }
  }

  /**
   * Build prompt for full definition lookup
   */
  private buildDefinitionPrompt(word: string, context: string): string {
    let prompt = `You are a professional English-Chinese dictionary.Provide the definition for the word "${word}".`;

    if (context.length > 0) {
      prompt += ` The word appears in this context: "${context}"`;
    }

    prompt += `

Return a JSON object with this exact structure:
{
  "word": "${word}",
  "phonetic": "phonetic transcription with slashes like /wɜːrd/",
  "pos": "primary part of speech in this context (n./v./adj./adv./prep./conj.)",
  "contextMeaning": "Chinese meaning specific to the given context, or most common meaning if no context",
  "commonMeanings": [
    {"pos": "n.", "cn": "Chinese meaning as noun"},
    {"pos": "v.", "cn": "Chinese meaning as verb"}
  ]
}

Rules:
1.Return ONLY valid JSON, no markdown or extra text
2.Include 2-4 common meanings in commonMeanings array
3.contextMeaning should be concise (under 20 Chinese characters)
4.Use standard phonetic notation`;

    return prompt;
  }

  /**
   * Build prompt for context-only lookup
   */
  private buildContextPrompt(word: string, context: string): string {
    return `Given the word "${word}" in this sentence:  "${context}"

What is the specific Chinese meaning of "${word}" in this context?
Reply with ONLY the Chinese meaning (under 20 characters), no explanation.`;
  }

  /**
   * Call AI API
   */
  private buildChatCompletionsUrl(): string {
    let base = this.apiBaseUrl.trim();
    if (base.endsWith('/')) {
      base = base.slice(0, -1);
    }
    // If base already includes version prefix, append relative endpoint once.
    if (base.endsWith('/v1') || base.endsWith('/api/v3')) {
      return `${base}/chat/completions`;
    }
    return `${base}/v1/chat/completions`;
  }
  /**
   * Call AI API with retry mechanism
   */
  private async callAI(prompt: string): Promise<string> {
    const maxRetries = 3;
    const initialDelay = 1000; // 1 second
    let lastError: Error | null = null;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      const httpRequest = http.createHttp();
      const url = this.buildChatCompletionsUrl();

      const msg = new APIMessage();
      msg.role = 'user';
      msg.content = prompt;
      const messages: APIMessage[] = [msg];

      const requestBody = new ChatCompletionRequest();
      requestBody.model = this.model;
      requestBody.messages = messages;
      requestBody.temperature = 0.3;
      requestBody.max_tokens = 500;
      const requestBodyStr: string = JSON.stringify(requestBody);

      const headers = {} as Record<string, string>;
      headers['Content-Type'] = 'application/json';
      headers['Authorization'] = `Bearer ${this.apiKey}`;

      const requestOptions: APIRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: requestBodyStr,
        connectTimeout: 30000,
        readTimeout: 30000
      };

      try {
        const response: http.HttpResponse = await httpRequest.request(url, requestOptions);

        if (response.responseCode !== 200) {
          let errBody = '';
          const r = response.result as string | ArrayBuffer;
          if (typeof r === 'string') {
            errBody = r;
          } else if (r instanceof ArrayBuffer) {
            errBody = this.decodeResult(r);
          }
          const trimmed = errBody.trim();
          const detail = trimmed.length > 0 ? `: ${trimmed.slice(0, 200)}` : '';
          throw new APIError(`API returned status ${response.responseCode}${detail}`);
        }

        let responseStr: string = '';
        const result = response.result as string | ArrayBuffer;
        if (typeof result === 'string') {
          responseStr = result;
        } else if (result instanceof ArrayBuffer) {
          responseStr = this.decodeResult(result);
        } else {
          throw new APIError('Unsupported response type');
        }

        const responseData = JSON.parse(responseStr) as APIResponse;

        if (responseData.choices.length === 0) {
          throw new APIError('No response from AI');
        }

        // Success, return the result
        httpRequest.destroy();
        return responseData.choices[0].message.content;
      } catch (e) {
        httpRequest.destroy();
        // 修复结构化类型错误，确保类型检查通过
        let errorInstance: Error;
        if (e instanceof Error) {
          errorInstance = e;
        } else {
          // 使用类型断言确保类型安全
          const errorMessage = this.formatError(e as Error | string | object);
          errorInstance = new Error(errorMessage);
          errorInstance.name = 'APIError';
        }
        lastError = errorInstance;
        
        // Don't retry on certain errors
        if (e instanceof APIError) {
          // Check if it's a client error (4xx) that shouldn't be retried
          if (e.message.includes('400') || e.message.includes('401') || e.message.includes('403') || e.message.includes('404')) {
            throw e;
          }
        }
        
        // If this is the last attempt, throw the error
        if (attempt === maxRetries - 1) {
          throw lastError;
        }
        
        // Calculate exponential backoff delay with jitter
        const delay = initialDelay * Math.pow(2, attempt) + Math.random() * 1000;
        console.info(`[DictionaryManager] API call failed, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await this.delay(delay);
      }
    }
    
    // This should never be reached, but if it is, throw the last error
    throw lastError || new APIError('Unknown error occurred');
  }



  /**
   * 格式化错误信息
   * @param e 错误对象，可能是Error实例或普通对象
   * @returns 格式化后的错误信息字符串
   */
  private formatError(e: Error | string | object): string {
    if (e instanceof Error) {
      return e.message;
    }
    if (typeof e === 'string') {
      return e;
    }
    if (typeof e === 'object' && e !== null) {
      try {
        return JSON.stringify(e);
      } catch (_) {
        return String(e);
      }
    }
    return String(e);
  }



  private decodeResult(buf: ArrayBuffer): string {
    // Use manual decoding for ArkTS compatibility
    const u8 = new Uint8Array(buf);
    let out: string = '';
    for (let i = 0; i < u8.length; i++) {
      out += String.fromCharCode(u8[i]);
    }
    return out;
  }

  /**
   * Parse AI response into WordDefinition
   */
  private parseDefinitionResponse(word:  string, response: string): WordDefinition {
    try {
      // Clean up response - remove markdown code blocks if present
      let cleanResponse = response.trim();
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.slice(7);
      } else if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse.slice(3);
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.slice(0, -3);
      }
      cleanResponse = cleanResponse.trim();

      const parsed = JSON.parse(cleanResponse) as AIDefinitionResult;

      const meanings: WordMeaning[] = [];
      if (parsed.commonMeanings !== undefined && Array.isArray(parsed.commonMeanings)) {
        for (let i = 0; i < parsed.commonMeanings.length; i++) {
          const m = parsed.commonMeanings[i];
          meanings.push(new WordMeaning(m.pos ??  '', m.cn ??  ''));
        }
      }

      return new WordDefinition(
        parsed.word ??  word,
        parsed.phonetic ?? '',
        parsed.pos ?? '',
        parsed.contextMeaning ?? '',
        meanings,
        'ai'
      );
    } catch (e) {
      const errMsg = this.formatError(e);
      console.error(`[DictionaryManager] Failed to parse AI response: ${errMsg}`);

      // Return basic definition
      return new WordDefinition(
        word,
        '',
        '',
        response.slice(0, 50), // Use raw response as fallback
        [],
        'ai'
      );
    }
  }

  /**
   * Parse context-only response
   */
  private parseContextResponse(response: string): string {
    return response.trim().slice(0, 50);
  }

  /**
   * Generate a micro-story using target and support words
   */
  async generateStory(
    targetWord: string,
    supportWords: string[],
    minWords: number = 50,
    maxWords: number = 70,
    minTargetOccurrences: number = 2,
    maxTargetOccurrences: number = 3
  ): Promise<StoryResult> {
    const normalizedTarget = targetWord.trim();
    const cleanedSupport: string[] = supportWords
      .map((w: string): string => w.trim())
      .filter((w: string): boolean => w.length > 0 && w.toLowerCase() !== normalizedTarget.toLowerCase());

    // 1) Prefer AI when configured, but always allow safe fallback.
    if (this.isConfigured()) {
      try {
        // Use enhanced prompt with current style/difficulty preferences
        const prompt = this.buildEnhancedPrompt(
          normalizedTarget,
          cleanedSupport,
          this.defaultContextStyle,
          this.defaultDifficultyLevel,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences
        );

        const response = await this.callAI(prompt);
        const story = this.parseStoryResponse(response, normalizedTarget, cleanedSupport);

        // Validate quality; if poor, fall back to offline templates.
        const validation = this.contextValidator.validate(
          story,
          normalizedTarget,
          this.defaultDifficultyLevel,
          minWords,
          maxWords,
          minTargetOccurrences,
          maxTargetOccurrences
        );
        if (validation.isValid) {
          await this.cacheVignetteIfEnabled(normalizedTarget, story);
          return StoryResult.createSuccess(story);
        }

        console.warn(`[DictionaryManager] Story validation failed, fallback offline: ${validation.getSummary()}`);
      } catch (e) {
        const errMsg = this.formatError(e);
        console.warn(`[DictionaryManager] Story AI failed, fallback offline: ${errMsg}`);
      }
    } else {
      console.info('[DictionaryManager] API not configured, using offline story generation');
    }

    // 1.5) If offline / AI failed, try cached AI vignette for better variety.
    const cached = await this.tryGetCachedVignette(normalizedTarget);
    if (cached !== null) {
      const adjustedCached = this.enforceContextConstraints(
        cached,
        normalizedTarget,
        cleanedSupport,
        minWords,
        maxWords,
        minTargetOccurrences,
        maxTargetOccurrences
      );
      return StoryResult.createSuccess(adjustedCached);
    }

    // 2) Offline generation (templates)
    const offline = this.generateContextOffline(
      normalizedTarget,
      cleanedSupport,
      this.defaultContextStyle,
      this.defaultDifficultyLevel
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
      return StoryResult.createSuccess(adjustedOffline);
    }

    // 3) Last resort: minimal deterministic story to avoid task load failure
    const minimal = this.enforceContextConstraints(
      this.buildMinimalStory(normalizedTarget, cleanedSupport),
      normalizedTarget,
      cleanedSupport,
      minWords,
      maxWords,
      minTargetOccurrences,
      maxTargetOccurrences
    );
    return StoryResult.createSuccess(minimal);
  }


  /**
   * Build prompt for story generation
   */
  private buildStoryPrompt(targetWord: string, supportWords: string[]): string {
    const allWords:  string[] = [targetWord];
    for (const w of supportWords) {
      allWords.push(w);
    }
    const wordList = allWords.join(', ');

    return `You are a creative English writing assistant.Write a short micro-story (exactly 50 words) that naturally incorporates these vocabulary words:  ${wordList}

The story should:
1.Be exactly 50 words (count carefully)
2.Use simple, clear English suitable for learners
3.Have a complete mini-narrative (beginning, middle, hint of ending)
4.Make the target word "${targetWord}" appear in a memorable context
5.Be interesting and slightly unexpected

Return ONLY the story text, no word count or explanations.`;
  }

  /**
   * Parse and validate story response
   */
  private parseStoryResponse(
    response: string,
    targetWord:  string,
    _supportWords: string[]
  ): string {
    let story = response.trim();

    // Remove any markdown formatting
    if (story.startsWith('"') && story.endsWith('"')) {
      story = story.slice(1, -1);
    }

    // Remove ** symbols around target words (Issue #2 fix)
    story = story.replace(/\*\*/g, '');
    
    // Remove any remaining markdown bold/italic markers
    story = story.replace(/\*/g, '');
    
    // Normalize whitespace
    story = story.replace(/\s+/g, ' ').trim();

    // Validate that target word is included
    const lowerStory = story.toLowerCase();
    if (!lowerStory.includes(targetWord.toLowerCase())) {
      console.warn(`[DictionaryManager] Story doesn't contain target word: ${targetWord}`);
    }

    return story;
  }


/**
 * Build a minimal story as the ultimate fallback.
 * This guarantees the target word appears, so UI never blocks on task content generation.
 */
private buildMinimalStory(targetWord: string, supportWords: string[]): string {
  const sw = supportWords.slice(0, 2);
  const parts: string[] = [];

  // Sentence 1: set the scene
  if (sw.length > 0) {
    parts.push(`After class, I met my friend and we talked about ${sw[0]}.`);
  } else {
    parts.push('After class, I walked home and thought about my day.');
  }

  // Sentence 2: include target word (guaranteed)
  if (sw.length > 1) {
    parts.push(`Suddenly, I had to ${targetWord} because ${sw[1]} surprised us.`);
  } else {
    parts.push(`Suddenly, I had to ${targetWord}, and I learned something new.`);
  }

  // Sentence 3: simple closing
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

  /**
   * Try read cached AI vignette from local DB for offline reuse.
   */
  private async tryGetCachedVignette(targetWord: string): Promise<string | null> {
    if (!this.vignetteCacheEnabled) {
      return null;
    }
    const key = targetWord.trim().toLowerCase();
    if (key.length === 0) return null;

    try {
      const v = await this.db.getCachedVignette(key);
      if (v.length === 0) return null;

      // Safety: ensure target word is still included.
      if (!v.toLowerCase().includes(key)) {
        return null;
      }

      const validation = this.contextValidator.validate(v, key, this.defaultDifficultyLevel);
      if (validation.isValid) {
        return v;
      }

      // If validation fails but the target word is included, still allow it.
      console.warn(`[DictionaryManager] Cached vignette validation failed: ${validation.getSummary()}`);
      return v;
    } catch (e) {
      const errMsg = this.formatError(e);
      console.warn(`[DictionaryManager] getCachedVignette failed: ${errMsg}`);
      return null;
    }
  }

  /**
   * Cache AI-generated vignette for offline reuse with LRU pruning.
   */
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
      const errMsg = this.formatError(e);
      console.warn(`[DictionaryManager] cache vignette failed: ${errMsg}`);
    }
  }
  /**
   * Get TTS audio URL for a word (Youdao)
   */
  getTTSUrl(word: string, type: number = 1): string {
    // type: 1 = US pronunciation, 2 = UK pronunciation
    const encoded = encodeURIComponent(word.trim().toLowerCase());
    return `https://dict.youdao.com/dictvoice?audio=${encoded}&type=${type}`;
  }

  /**
   * Preload definitions for a list of words (background caching)
   */
  async preloadDefinitions(words: string[]): Promise<number> {
    let loaded = 0;

    for (const word of words) {
      // Check if already cached
      const cached = this.getFromMemoryCache(word.toLowerCase());
      if (cached !== null) {
        continue;
      }

      try {
        const result = await this.lookup(word);
        if (result.success) {
          loaded++;
        }
      } catch (e) {
        const errMsg = this.formatError(e);
        console.warn(`[DictionaryManager] Preload failed for ${word}: ${errMsg}`);
      }

      // Small delay to avoid rate limiting
      await this.delay(100);
    }

    console.info(`[DictionaryManager] Preloaded ${loaded}/${words.length} definitions`);
    return loaded;
  }

  /**
   * Simple delay helper
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  // ==================== CONTEXT GENERATION METHODS ====================

  /**
   * Set context generation preferences
   */
  setContextPreferences(style: ContextStyle, difficulty: DifficultyLevel, customStyle: string = ''): void {
    this.defaultContextStyle = style;
    this.customContextStyle = customStyle;
    this.defaultDifficultyLevel = difficulty;
  }

  /**
   * Generate context with AI (enhanced version)
   */
  async generateContextWithAI(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle = this.defaultContextStyle,
    difficulty: DifficultyLevel = this.defaultDifficultyLevel
  ): Promise<ContextGenerationResult> {
    if (!this.isConfigured()) {
      return this.generateContextOffline(targetWord, supportWords, style, difficulty);
    }

    try {
      // Build enhanced prompt with style and difficulty
      const prompt = this.buildEnhancedPrompt(targetWord, supportWords, style, difficulty, 50, 70, 2, 3);
      const response = await this.callAI(prompt);
      const context = this.parseStoryResponse(response, targetWord, supportWords);

      // Validate the generated context
      const validation = this.contextValidator.validate(context, targetWord, difficulty, 50, 70, 2, 3);

      return { context, validation };
    } catch (e) {
      const errMsg = this.formatError(e);
      console.error('[DictionaryManager] AI context generation failed:', errMsg);
      
      // Fallback to offline generation
      return this.generateContextOffline(targetWord, supportWords, style, difficulty);
    }
  }

  /**
   * Generate context offline (using templates)
   */
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

    // Validate the generated context
    const validation = this.contextValidator.validate(result.context, targetWord, difficulty);

    return { context: result.context, validation };
  }

  /**
   * Get style description in Chinese
   */
  private getStyleDescription(style: ContextStyle): string {
    switch (style) {
      case ContextStyle.CONVERSATIONAL:
        return '对话式';
      case ContextStyle.FORMAL:
        return '正式';
      case ContextStyle.HUMOROUS:
        return '幽默';
      case ContextStyle.NARRATIVE:
        return '叙述式';
      case ContextStyle.TECHNICAL:
        return '技术性';
      default:
        return '对话式';
    }
  }

  /**
   * Get difficulty description in Chinese
   */
  private getDifficultyDescription(difficulty: DifficultyLevel): string {
    switch (difficulty) {
      case DifficultyLevel.CET4:
        return '四级';
      case DifficultyLevel.CET6:
        return '六级';
      case DifficultyLevel.IELTS:
        return '雅思';
      case DifficultyLevel.TOEFL:
        return '托福';
      case DifficultyLevel.SAT:
        return 'SAT';
      case DifficultyLevel.GRE:
        return 'GRE';
      default:
        return '四级';
    }
  }

  /**
   * Build enhanced prompt with style and difficulty
   */
  private buildEnhancedPrompt(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle,
    difficulty: DifficultyLevel,
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number
  ): string {
    let styleDescription: string = this.getStyleDescription(style);
    
    // Use custom style if selected and provided
    if (style === ContextStyle.CUSTOM && this.customContextStyle.trim().length > 0) {
      styleDescription = this.customContextStyle.trim();
    }
    
    const difficultyDescription: string = this.getDifficultyDescription(difficulty);

    const allWords = [targetWord, ...supportWords];
    const wordList = allWords.join(', ');

    // Issue #2 & #8 fix: Enhanced prompt with better diversity instructions
    return `You are a creative English writing assistant. Write a short micro-story (${minWords}-${maxWords} words) that naturally incorporates these vocabulary words: ${wordList}

The story should:
1. Be between ${minWords} and ${maxWords} words (count carefully)
2. Use simple, clear English suitable for learners
3. Have a complete mini-narrative (beginning, middle, hint of ending)
4. Make the target word "${targetWord}" appear naturally ${minTargetOccurrences}-${maxTargetOccurrences} times
5. Be interesting and slightly unexpected
6. Style: ${styleDescription}
7. Difficulty level: ${difficultyDescription}
8. IMPORTANT: Vary the position of "${targetWord}" - avoid placing it in the same sentence position each time
9. IMPORTANT: Use diverse sentence structures and varied contexts
10. IMPORTANT: Do NOT use markdown formatting like ** or * around words

Return ONLY the plain story text, no word count, no explanations, no formatting symbols.`;
  }

  /**
   * Generate multiple context variants
   */
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

  /**
   * Get best context from multiple options
   */
  getBestContext(
    contexts: ContextGenerationResult[]
  ): ContextGenerationResult {
    if (contexts.length === 0) {
      return { context: '', validation: new ValidationResult() };
    }

    // Sort by validation score
    contexts.sort((a, b) => b.validation.score - a.validation.score);

    return contexts[0];
  }

  /**
   * Validate and improve context
   */
  validateAndImproveContext(
    context: string,
    targetWord: string,
    difficulty: DifficultyLevel = this.defaultDifficultyLevel
  ): ContextImprovementResult {
    const validation = this.contextValidator.validate(context, targetWord, difficulty);
    const improvements = this.contextValidator.generateImprovements(validation);

    // Apply improvements if available
    let improvedContext = context;
    if (improvements.length > 0) {
      improvedContext = this.contextValidator.cleanContext(context);
    }

    return { improvedContext, validation, improvements };
  }

  /**
   * Get context generation statistics
   */
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

  /**
   * Check if context is suitable for AI generation
   */
  isContextSuitableForAI(context: string): boolean {
    return this.contextValidator.isSuitableForAI(context);
  }

  /**
   * Check if context is suitable for offline generation
   */
  isContextSuitableForOffline(context: string): boolean {
    return this.contextValidator.isSuitableForOffline(context);
  }

  /**
   * Get recommended difficulty for user
   */
  getRecommendedDifficulty(userLevel: number): DifficultyLevel {
    return this.templateManager.recommendDifficulty(userLevel);
  }

  /**
   * Get available context styles
   */
  getAvailableContextStyles(): ContextStyle[] {
    return this.templateManager.getAvailableStyles();
  }

  /**
   * Get available difficulty levels
   */
  getAvailableDifficultyLevels(): DifficultyLevel[] {
    return this.templateManager.getAvailableDifficulties();
  }

  /**
   * Get style name in Chinese
   */
  getContextStyleName(style: ContextStyle): string {
    return this.templateManager.getStyleName(style);
  }

  /**
   * Get difficulty name in Chinese
   */
  getDifficultyName(level: DifficultyLevel): string {
    return this.templateManager.getDifficultyName(level);
  }
}

/**
 * TTS Player helper class
 */
export class TTSPlayer {
  private static instance: TTSPlayer | null = null;
  private dictionaryManager: DictionaryManager;

  private constructor() {
    this.dictionaryManager = DictionaryManager.getInstance();
  }

  static getInstance(): TTSPlayer {
    if (TTSPlayer.instance === null) {
      TTSPlayer.instance = new TTSPlayer();
    }
    return TTSPlayer.instance;
  }

  /**
   * Get the TTS URL for playback
   */
  getAudioUrl(word:  string, usAccent: boolean = true): string {
    const type = usAccent ?  1 : 2;
    return this.dictionaryManager.getTTSUrl(word, type);
  }
}
