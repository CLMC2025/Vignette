import { describe, it, expect } from '@ohos/hypium';

import { StoryGenerationPipeline, StoryGenerator, StorySource, StoryGenerationRequest } from '../../../main/ets/context/StoryGenerationPipeline';
import { StoryResult } from '../../../main/ets/manager/DictionaryManager';
import { ContextStyle, DifficultyLevel } from '../../../main/ets/context/TemplateManager';

class SuccessGenerator implements StoryGenerator {
  async generateStory(
    _targetWord: string,
    _supportWords: string[],
    _minWords: number,
    _maxWords: number,
    _minTargetOccurrences: number,
    _maxTargetOccurrences: number
  ): Promise<StoryResult> {
    return StoryResult.createSuccess('The apple fell near the river, and the day felt calm.');
  }
}

class FailingGenerator implements StoryGenerator {
  async generateStory(
    _targetWord: string,
    _supportWords: string[],
    _minWords: number,
    _maxWords: number,
    _minTargetOccurrences: number,
    _maxTargetOccurrences: number
  ): Promise<StoryResult> {
    throw new Error('network timeout');
  }
}

class EmptyStoryGenerator implements StoryGenerator {
  async generateStory(
    _targetWord: string,
    _supportWords: string[],
    _minWords: number,
    _maxWords: number,
    _minTargetOccurrences: number,
    _maxTargetOccurrences: number
  ): Promise<StoryResult> {
    return new StoryResult(true, '', '');
  }
}

export default function storyGenerationPipelineTest() {
  describe('StoryGenerationPipeline', () => {
    const baseRequest: StoryGenerationRequest = {
      targetWord: 'apple',
      supportWords: ['tree', 'river'],
      minWords: 50,
      maxWords: 70,
      minTargetOccurrences: 2,
      maxTargetOccurrences: 3,
      style: ContextStyle.CONVERSATIONAL,
      difficulty: DifficultyLevel.CET4
    };

    it('should return primary story when generator succeeds', 0, async () => {
      const pipeline = new StoryGenerationPipeline(new SuccessGenerator());
      const outcome = await pipeline.generate(baseRequest);
      expect(outcome.source).assertEqual(StorySource.PRIMARY);
      expect(outcome.story.length > 0).assertTrue();
    });

    it('should fallback to offline when generator fails', 0, async () => {
      const pipeline = new StoryGenerationPipeline(new FailingGenerator());
      const outcome = await pipeline.generate(baseRequest);
      expect(outcome.source === StorySource.OFFLINE || outcome.source === StorySource.MINIMAL).assertTrue();
      expect(outcome.story.length > 0).assertTrue();
    });

    it('should fallback when generator returns empty story', 0, async () => {
      const pipeline = new StoryGenerationPipeline(new EmptyStoryGenerator());
      const outcome = await pipeline.generate(baseRequest);
      expect(outcome.source === StorySource.OFFLINE || outcome.source === StorySource.MINIMAL).assertTrue();
      expect(outcome.story.length > 0).assertTrue();
    });

    it('should return offline first and upgrade in background', 0, async () => {
      const pipeline = new StoryGenerationPipeline(new SuccessGenerator());
      const fast = await pipeline.generateFastFirst(baseRequest);
      expect(fast.initial.source === StorySource.OFFLINE || fast.initial.source === StorySource.MINIMAL).assertTrue();
      expect(fast.initial.story.length > 0).assertTrue();
      if (fast.upgradePromise === null) {
        expect(false).assertTrue();
        return;
      }
      const upgraded = await fast.upgradePromise;
      expect(upgraded.source).assertEqual(StorySource.PRIMARY);
      expect(upgraded.story.length > 0).assertTrue();
    });
  });
}
