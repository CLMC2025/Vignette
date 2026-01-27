// =====================================================
// StoryGenerationPipeline.ets - Story generation with fallback
// =====================================================

import { OfflineContextGenerator } from './OfflineContext';
import { ContextStyle, DifficultyLevel } from './TemplateManager';
import { StoryResult } from '../manager/DictionaryManager';
import { ErrorCategory, buildUserFacingError } from '../utils/ErrorClassifier';

export enum StorySource {
  PRIMARY = 'PRIMARY',
  OFFLINE = 'OFFLINE',
  MINIMAL = 'MINIMAL'
}

export interface StoryGenerator {
  generateStory(
    targetWord: string,
    supportWords: string[],
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number
  ): Promise<StoryResult>;
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

export class StoryGenerationPipeline {
  private generator: StoryGenerator;
  private offlineGenerator: OfflineContextGenerator;

  constructor(generator: StoryGenerator, offlineGenerator?: OfflineContextGenerator) {
    this.generator = generator;
    this.offlineGenerator = offlineGenerator ?? OfflineContextGenerator.getInstance();
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
        request.maxTargetOccurrences
      );

      if (result.success && result.story.trim().length > 0) {
        console.log('[StoryGenerationPipeline] Story generated from primary provider');
        return new StoryGenerationOutcome(result.story, StorySource.PRIMARY);
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
      return new StoryGenerationOutcome(
        offline.context,
        StorySource.OFFLINE,
        `${warningMessage}，已使用离线兜底。`,
        category
      );
    }

    const minimal = `After class, I had to ${request.targetWord}. It felt simple and easy to remember.`;
    return new StoryGenerationOutcome(
      minimal,
      StorySource.MINIMAL,
      `${warningMessage}，已使用最小兜底。`,
      category
    );
  }
}
