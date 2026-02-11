import { ContextStyle, DifficultyLevel, TemplateManager } from '../../context/TemplateManager';

export class PromptBuilder {
  private static instance: PromptBuilder | null = null;
  private templateManager: TemplateManager = TemplateManager.getInstance();
  private customContextStyle: string = '';

  private constructor() {}

  static getInstance(): PromptBuilder {
    if (PromptBuilder.instance === null) {
      PromptBuilder.instance = new PromptBuilder();
    }
    return PromptBuilder.instance;
  }

  setCustomContextStyle(style: string): void {
    this.customContextStyle = style;
  }

  buildDefinitionPrompt(word: string, context: string): string {
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
  ],
  "phrases": [
    {"phrase": "common phrase or collocation", "meaning": "Chinese meaning", "example": "Example sentence using this phrase"},
    {"phrase": "another phrase", "meaning": "Chinese meaning", "example": "Example sentence"}
  ],
  "examples": [
    {"sentence": "English example sentence using the word", "translation": "Chinese translation"},
    {"sentence": "Another example sentence", "translation": "Chinese translation"}
  ],
  "frequency": 3,
  "examTags": ["CET4", "CET6"]
}

Rules:
1.Return ONLY valid JSON, no markdown or extra text
2.Include 2-4 common meanings in commonMeanings array
3.Include 2-3 common phrases/collocations in phrases array
4.Include 2-3 example sentences in examples array
5.contextMeaning should be concise (under 20 Chinese characters)
6.Use standard phonetic notation
7.frequency is 1-5 (5 = most frequent)
8.examTags can include: CET4, CET6, KAOYAN, TEM8`;

    return prompt;
  }

  buildContextPrompt(word: string, context: string): string {
    return `Given the word "${word}" in this sentence:  "${context}"

What is the specific Chinese meaning of "${word}" in this context?
Reply with ONLY the Chinese meaning (under 20 characters), no explanation.`;
  }

  buildStoryPrompt(targetWord: string, supportWords: string[]): string {
    const allWords: string[] = [targetWord];
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

  buildEnhancedPrompt(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle,
    difficulty: DifficultyLevel,
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number
  ): string {
    let styleDescription: string = this.templateManager.getStyleName(style);
    
    // Use custom style if selected and provided
    if (style === ContextStyle.CUSTOM && this.customContextStyle.trim().length > 0) {
      styleDescription = this.customContextStyle.trim();
    }
    
    const difficultyDescription: string = this.templateManager.getDifficultyName(difficulty);

    const allWords = [targetWord, ...supportWords];
    const wordList = allWords.join(', ');

    return `You are a creative English writing assistant. Write a short micro-story (${minWords}-${maxWords} words) that naturally incorporates these vocabulary words: ${wordList}

The story should:
1.Be between ${minWords} and ${maxWords} words (count carefully)
2.Use simple, clear English suitable for learners
3.Have a complete mini-narrative (beginning, middle, hint of ending)
4.Make the target word "${targetWord}" appear naturally ${minTargetOccurrences}-${maxTargetOccurrences} times
5.Be interesting and slightly unexpected
6.Style: ${styleDescription}
7.Difficulty level: ${difficultyDescription}
8.Avoid generic template openings like "One quiet morning" or "After class"
9.Avoid filler sentences like "Later, I noticed ..." or "I kept reading ..."

Return ONLY the story text, no word count or explanations.`;
  }

  buildEnhancedPromptWithVariation(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle,
    difficulty: DifficultyLevel,
    minWords: number,
    maxWords: number,
    minTargetOccurrences: number,
    maxTargetOccurrences: number,
    variationKey: string
  ): string {
    const base = this.buildEnhancedPrompt(
      targetWord,
      supportWords,
      style,
      difficulty,
      minWords,
      maxWords,
      minTargetOccurrences,
      maxTargetOccurrences
    );
    return `${base}

Extra requirements:
- Avoid generic template openings like "One quiet morning" or "After class".
- Avoid filler sentences like "Later, I noticed ..." or "I kept reading ...".
- Make the opening sentence different from previous versions.
- Variation key: ${variationKey}`;
  }
}
