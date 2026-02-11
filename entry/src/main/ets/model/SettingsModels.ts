
/**
 * App settings model
 */
export class AppSettings {
  apiBaseUrl: string;
  apiModel: string;
  dailyNewWords: number;
  dailyTotalTasks: number;
  dailyReviewWords: number;
  studyFlowMode: string;
  enableTTS: boolean;
  pronunciationMode: string;
  newbieMode: boolean;
  theme: string;
  contextStyle: string; // ContextStyle enum value
  customContextStyle: string; // Custom context style input by user
  difficultyLevel: number; // DifficultyLevel enum value
  difficultySchemaVersion: number;
  enableVignetteCache: boolean;
  vignetteCacheMaxBytes: number;
  contextLengthMin: number;
  contextLengthMax: number;

  constructor(
    apiBaseUrl: string = 'https://api.deepseek.com',
    apiModel: string = 'deepseek-chat',
    dailyNewWords: number = 10,
    dailyTotalTasks: number = 20,
    dailyReviewWords: number = 20,
    studyFlowMode: string = 'combined',
    enableTTS: boolean = true,
    pronunciationMode: string = 'auto',
    newbieMode: boolean = true,
    theme: string = 'light',
    contextStyle: string = 'random',
    customContextStyle: string = '',
    difficultyLevel: number = 1, // Default to CET4
    enableVignetteCache: boolean = true,
    vignetteCacheMaxBytes: number = 2_000_000,
    contextLengthMin: number = 0,
    contextLengthMax: number = 0,
    difficultySchemaVersion: number = 2
  ) {
    this.apiBaseUrl = apiBaseUrl;
    this.apiModel = apiModel;
    this.dailyNewWords = dailyNewWords;
    this.dailyTotalTasks = dailyTotalTasks;
    this.dailyReviewWords = dailyReviewWords;
    this.studyFlowMode = studyFlowMode;
    this.enableTTS = enableTTS;
    this.pronunciationMode = pronunciationMode;
    this.newbieMode = newbieMode;
    this.theme = theme;
    this.contextStyle = contextStyle;
    this.customContextStyle = customContextStyle;
    this.difficultyLevel = difficultyLevel;
    this.difficultySchemaVersion = difficultySchemaVersion;
    this.enableVignetteCache = enableVignetteCache;
    this.vignetteCacheMaxBytes = vignetteCacheMaxBytes;
    this.contextLengthMin = contextLengthMin;
    this.contextLengthMax = contextLengthMax;
  }

  /**
   * Serialize to JSON
   */
  toJSON(): string {
    const obj: Record<string, string | number | boolean> = {
      "apiBaseUrl": this.apiBaseUrl,
      "apiModel": this.apiModel,
      "dailyNewWords": this.dailyNewWords,
      "dailyTotalTasks": this.dailyTotalTasks,
      "dailyReviewWords": this.dailyReviewWords,
      "studyFlowMode": this.studyFlowMode,
      "enableTTS": this.enableTTS,
      "pronunciationMode": this.pronunciationMode,
      "newbieMode": this.newbieMode,
      "theme": this.theme,
      "contextStyle": this.contextStyle,
      "customContextStyle": this.customContextStyle,
      "difficultyLevel": this.difficultyLevel,
      "difficultySchemaVersion": this.difficultySchemaVersion,
      "enableVignetteCache": this.enableVignetteCache,
      "vignetteCacheMaxBytes": this.vignetteCacheMaxBytes,
      "contextLengthMin": this.contextLengthMin,
      "contextLengthMax": this.contextLengthMax
    };
    return JSON.stringify(obj);
  }

  /**
   * Deserialize from JSON (backward compatible)
   */
  static fromJSON(json: string): AppSettings {
    try {
      const obj = JSON.parse(json) as Record<string, string | number | boolean>;
      const schemaRaw = obj['difficultySchemaVersion'] as number;
      const schemaVersion = typeof schemaRaw === 'number' && Number.isFinite(schemaRaw)
        ? Math.round(schemaRaw)
        : 1;
      const rawDifficulty = obj['difficultyLevel'] as number;
      const normalizedDifficulty = typeof rawDifficulty === 'number' && Number.isFinite(rawDifficulty)
        ? Math.round(rawDifficulty)
        : 1;
      const difficultyLevel = schemaVersion < 2
        ? AppSettings.mapLegacyDifficulty(normalizedDifficulty)
        : normalizedDifficulty;
      return new AppSettings(
        (obj['apiBaseUrl'] as string) ?? 'https://api.deepseek.com',
        (obj['apiModel'] as string) ?? 'deepseek-chat',
        (obj['dailyNewWords'] as number) ?? 10,
        (obj['dailyTotalTasks'] as number) ?? 20,
        (obj['dailyReviewWords'] as number) ?? 20,
        (obj['studyFlowMode'] as string) ?? 'combined',
        (obj['enableTTS'] as boolean) ?? true,
        (obj['pronunciationMode'] as string) ?? 'auto',
        (obj['newbieMode'] as boolean) ?? true,
        (obj['theme'] as string) ?? 'light',
        (obj['contextStyle'] as string) ?? 'random',
        (obj['customContextStyle'] as string) ?? '',
        difficultyLevel, // Default to CET4
        (obj['enableVignetteCache'] as boolean) ?? true,
        (obj['vignetteCacheMaxBytes'] as number) ?? 2_000_000,
        (obj['contextLengthMin'] as number) ?? 0,
        (obj['contextLengthMax'] as number) ?? 0,
        2
      );
    } catch (e) {
      return new AppSettings();
    }
  }

  private static mapLegacyDifficulty(value: number): number {
    if (value >= 3 && value <= 7) {
      return value + 1;
    }
    if (value < 0 || value > 8) {
      return 1;
    }
    return value;
  }
}
