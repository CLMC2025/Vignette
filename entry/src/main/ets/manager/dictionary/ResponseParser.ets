import { WordDefinition, WordMeaning, PhraseItem, ExampleItem } from '../../model/WordModel';
import { TextSanitizer } from '../../utils/TextSanitizer';
import { AIDefinitionResult, PhraseItemData, ExampleItemData } from './DictionaryModels';

export class ResponseParser {
  private static instance: ResponseParser | null = null;

  private constructor() {}

  static getInstance(): ResponseParser {
    if (ResponseParser.instance === null) {
      ResponseParser.instance = new ResponseParser();
    }
    return ResponseParser.instance;
  }

  formatError(e: Error | string | object): string {
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

  parseDefinitionResponse(word: string, response: string): WordDefinition {
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
          meanings.push(new WordMeaning(m.pos ?? '', m.cn ?? ''));
        }
      }

      const phrases: PhraseItem[] = [];
      if (parsed.phrases !== undefined && Array.isArray(parsed.phrases)) {
        for (const p of parsed.phrases) {
          phrases.push(new PhraseItem(p.phrase ?? '', p.meaning ?? '', p.example ?? ''));
        }
      }

      const examples: ExampleItem[] = [];
      if (parsed.examples !== undefined && Array.isArray(parsed.examples)) {
        for (const e of parsed.examples) {
          examples.push(new ExampleItem(e.sentence ?? '', e.translation ?? ''));
        }
      }

      return new WordDefinition(
        parsed.word ?? word,
        parsed.phonetic ?? '',
        parsed.pos ?? '',
        parsed.contextMeaning ?? '',
        meanings,
        'ai',
        phrases,
        examples,
        parsed.frequency ?? 0,
        parsed.examTags ?? []
      );
    } catch (e) {
      const errMsg = this.formatError(e);
      console.error(`[ResponseParser] Failed to parse AI response: ${errMsg}`);

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

  parseContextResponse(response: string): string {
    return response.trim().slice(0, 50);
  }

  parseStoryResponse(
    response: string,
    targetWord: string,
    _supportWords: string[]
  ): string {
    let story = response.trim();

    // Remove any markdown formatting
    if (story.startsWith('"') && story.endsWith('"')) {
      story = story.slice(1, -1);
    }

    story = TextSanitizer.sanitizeContext(story);

    // Validate that target word is included
    const lowerStory = story.toLowerCase();
    if (!lowerStory.includes(targetWord.toLowerCase())) {
      console.warn(`[ResponseParser] Story doesn't contain target word: ${targetWord}`);
    }

    return story;
  }
}
