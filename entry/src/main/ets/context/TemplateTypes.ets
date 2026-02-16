/**
 * 语境风格枚举
 */
export enum ContextStyle {
  RANDOM = 'random',               // 随机
  CONVERSATIONAL = 'conversational',  // 对话式
  FORMAL = 'formal',               // 正式
  HUMOROUS = 'humorous',            // 幽默
  NARRATIVE = 'narrative',          // 叙述式
  TECHNICAL = 'technical',          // 技术性
  CUSTOM = 'custom'                 // 自定义
}

/**
 * 难度级别枚举（基于考试等级）
 */
export enum DifficultyLevel {
  BEGINNER = 0, // 入门
  CET4 = 1,     // 四级
  CET6 = 2,     // 六级
  POSTGRADUATE = 3, // 考研
  IELTS = 4,    // 雅思
  TOEFL = 5,    // 托福
  SAT = 6,      // SAT
  GRE = 7,      // GRE
  ADVANCED = 8  // 高级
}

/**
 * 模板项接口
 */
export interface TemplateItem {
  id?: string;
  style: string;
  difficulty: number;
  template: string;
  pos?: string;
  wordCount?: number;
}

/**
 * 模板包接口
 */
export interface TemplatePack {
  templates?: TemplateItem[];
  difficultySchemaVersion?: number;
}

/**
 * 语境模板
 */
export class ContextTemplate {
  id: string;
  style: ContextStyle;
  difficulty: DifficultyLevel;
  template: string;
  pos: string;  // 词性
  wordCount: number;

  constructor(
    id: string,
    style: ContextStyle,
    difficulty: DifficultyLevel,
    template: string,
    pos: string,
    wordCount: number = 1
  ) {
    this.id = id;
    this.style = style;
    this.difficulty = difficulty;
    this.template = template;
    this.pos = pos;
    this.wordCount = wordCount;
  }

  /**
   * 填充模板
   */
  fill(words: string[]): string {
    let result = this.template;
    for (let i = 0; i < words.length && i < this.wordCount; i++) {
      result = result.replace(`{word${i + 1}}`, words[i]);
    }
    return result;
  }

  /**
   * 验证模板
   */
  isValid(): boolean {
    return this.template.length > 0 && this.wordCount > 0;
  }
}

/**
 * 模板参数
 */
export class TemplateParams {
  style: ContextStyle;
  difficulty: DifficultyLevel;
  pos: string;
  wordCount: number;

  constructor(
    style: ContextStyle = ContextStyle.CONVERSATIONAL,
    difficulty: DifficultyLevel = DifficultyLevel.IELTS,
    pos: string = 'n.',
    wordCount: number = 1
  ) {
    this.style = style;
    this.difficulty = difficulty;
    this.pos = pos;
    this.wordCount = wordCount;
  }
}
