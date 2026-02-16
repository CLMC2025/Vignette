
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
  learningOrderPolicy: string;
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
  learningStepMinutes: number[];
  timeboxEnabled: boolean;
  timeboxLimitMinutes: number;
  timeboxReminderMinutes: number;
  externalDictEnabled: boolean;
  externalDictUrlTemplate: string;

  constructor(
    apiBaseUrl: string = 'https://api.deepseek.com',
    apiModel: string = 'deepseek-chat',
    dailyNewWords: number = 10,
    dailyTotalTasks: number = 20,
    dailyReviewWords: number = 20,
    studyFlowMode: string = 'combined',
    learningOrderPolicy: string = 'due_first',
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
    learningStepMinutes: number[] = [5, 120],
    difficultySchemaVersion: number = 2,
    timeboxEnabled: boolean = true,
    timeboxLimitMinutes: number = 30,
    timeboxReminderMinutes: number = 5,
    externalDictEnabled: boolean = true,
    externalDictUrlTemplate: string = 'https://www.youdao.com/result?word={word}&lang=en'
  ) {
    this.apiBaseUrl = apiBaseUrl;
    this.apiModel = apiModel;
    this.dailyNewWords = dailyNewWords;
    this.dailyTotalTasks = dailyTotalTasks;
    this.dailyReviewWords = dailyReviewWords;
    this.studyFlowMode = studyFlowMode;
    this.learningOrderPolicy = learningOrderPolicy;
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
    this.learningStepMinutes = learningStepMinutes;
    this.timeboxEnabled = timeboxEnabled;
    this.timeboxLimitMinutes = timeboxLimitMinutes;
    this.timeboxReminderMinutes = timeboxReminderMinutes;
    this.externalDictEnabled = externalDictEnabled;
    this.externalDictUrlTemplate = externalDictUrlTemplate;
  }

  /**
   * Serialize to JSON
   */
  toJSON(): string {
    const obj: Record<string, string | number | boolean | number[]> = {
      "apiBaseUrl": this.apiBaseUrl,
      "apiModel": this.apiModel,
      "dailyNewWords": this.dailyNewWords,
      "dailyTotalTasks": this.dailyTotalTasks,
      "dailyReviewWords": this.dailyReviewWords,
      "studyFlowMode": this.studyFlowMode,
      "learningOrderPolicy": this.learningOrderPolicy,
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
      "contextLengthMax": this.contextLengthMax,
      "learningStepMinutes": this.learningStepMinutes,
      "timeboxEnabled": this.timeboxEnabled,
      "timeboxLimitMinutes": this.timeboxLimitMinutes,
      "timeboxReminderMinutes": this.timeboxReminderMinutes,
      "externalDictEnabled": this.externalDictEnabled,
      "externalDictUrlTemplate": this.externalDictUrlTemplate
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
      const rawSteps: unknown = obj['learningStepMinutes'];
      const normalizedDifficulty = typeof rawDifficulty === 'number' && Number.isFinite(rawDifficulty)
        ? Math.round(rawDifficulty)
        : 1;
      const difficultyLevel = schemaVersion < 2
        ? AppSettings.mapLegacyDifficulty(normalizedDifficulty)
        : normalizedDifficulty;
      const learningStepMinutes = AppSettings.normalizeStepMinutes(rawSteps);
      const learningOrderPolicy = (obj['learningOrderPolicy'] as string) ?? 'due_first';
      return new AppSettings(
        (obj['apiBaseUrl'] as string) ?? 'https://api.deepseek.com',
        (obj['apiModel'] as string) ?? 'deepseek-chat',
        (obj['dailyNewWords'] as number) ?? 10,
        (obj['dailyTotalTasks'] as number) ?? 20,
        (obj['dailyReviewWords'] as number) ?? 20,
        (obj['studyFlowMode'] as string) ?? 'combined',
        learningOrderPolicy,
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
        learningStepMinutes,
        2,
        (obj['timeboxEnabled'] as boolean) ?? true,
        (obj['timeboxLimitMinutes'] as number) ?? 30,
        (obj['timeboxReminderMinutes'] as number) ?? 5,
        (obj['externalDictEnabled'] as boolean) ?? true,
        (obj['externalDictUrlTemplate'] as string) ?? 'https://www.youdao.com/result?word={word}&lang=en'
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

  private static normalizeStepMinutes(value: unknown): number[] {
    if (!Array.isArray(value)) {
      return [5, 120];
    }
    const normalized: number[] = [];
    for (const item of value) {
      if (typeof item === 'number' && Number.isFinite(item) && item > 0) {
        normalized.push(Math.round(item));
      }
    }
    if (normalized.length === 0) {
      return [5, 120];
    }
    return normalized;
  }
}
