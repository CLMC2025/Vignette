// =====================================================
// TemplateManager.ets - 语境模板管理系统
// 提供基于模板的语境生成功能，支持离线使用
// =====================================================

/**
 * 语境风格枚举
 */
export enum ContextStyle {
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
  IELTS = 3,    // 雅思
  TOEFL = 4,    // 托福
  SAT = 5,      // SAT
  GRE = 6,      // GRE
  ADVANCED = 7  // 高级
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

/**
 * 模板管理器
 */
export class TemplateManager {
  private static instance: TemplateManager | null = null;
  private templates: Map<string, ContextTemplate[]>;
  private initialized: boolean = false;
  private static readonly EXTERNAL_PACK_KEY: string = 'offline_template_pack_json';
  private static readonly EXTERNAL_ID_PREFIX: string = 'pack_';

  private constructor() {
    this.templates = new Map();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): TemplateManager {
    if (TemplateManager.instance === null) {
      TemplateManager.instance = new TemplateManager();
    }
    return TemplateManager.instance;
  }

  /**
   * 初始化模板库
   */
  initialize(): void {
    if (this.initialized) {
      return;
    }

    this.loadDefaultTemplates();
    // Optional: user-provided offline template pack (downloaded via WebDAV, etc.)
    this.loadExternalTemplatePackFromStorage();
    this.initialized = true;
    console.info('[TemplateManager] Templates initialized');
  }

  /**
   * Apply an external template pack JSON.
   *
   * Supported formats:
   * - Array<TemplateRecord>
   * - { templates: Array<TemplateRecord>, version?: number }
   *
   * If persist=true, the raw JSON will be stored in AppStorage and automatically
   * loaded on next app launch.
   */
  applyExternalTemplatePack(packJson: string, persist: boolean = true): number {
    if (packJson.trim().length === 0) {
      return 0;
    }

    // Ensure defaults are loaded.
    if (!this.initialized) {
      this.loadDefaultTemplates();
    }

    // Clear previous external pack templates (keep built-in + custom templates).
    this.clearExternalTemplatesInMemory();

    let data: TemplatePack | TemplateItem[];
    try {
      data = JSON.parse(packJson);
    } catch (e) {
      console.warn('[TemplateManager] Invalid template pack JSON');
      return 0;
    }

    const list: TemplateItem[] = Array.isArray(data)
      ? data
      : (data && typeof data === 'object' && Array.isArray(data.templates))
        ? data.templates
        : [];

    let added = 0;
    for (let i = 0; i < list.length; i++) {
      const obj = list[i];
      if (!obj || typeof obj !== 'object') {
        continue;
      }

      const styleStr = String(obj.style ?? '');
      const style = this.parseStyle(styleStr);
      if (style === null) {
        continue;
      }

      const difficultyNum = typeof obj.difficulty === 'number'
        ? obj.difficulty
        : Number(obj.difficulty ?? 3);
      const difficulty = this.parseDifficulty(difficultyNum);
      if (difficulty === null) {
        continue;
      }

      const tpl = String(obj.template ?? '').trim();
      const pos = String(obj.pos ?? '').trim();
      const wc = typeof obj.wordCount === 'number' ? obj.wordCount : Number(obj.wordCount ?? 1);

      if (tpl.length === 0 || !Number.isFinite(wc) || wc <= 0) {
        continue;
      }

      // Ensure it contains at least {word1}.
      if (!tpl.includes('{word1}')) {
        continue;
      }

      const idRaw = String(obj.id ?? '');
      const id = idRaw.trim().length > 0
        ? `${TemplateManager.EXTERNAL_ID_PREFIX}${idRaw.trim()}`
        : `${TemplateManager.EXTERNAL_ID_PREFIX}${styleStr}_${difficultyNum}_${i}`;

      const template = new ContextTemplate(id, style, difficulty, tpl, pos, Math.round(wc));
      if (!template.isValid()) {
        continue;
      }
      this.addCustomTemplate(template);
      added++;
    }

    if (persist) {
      // AppStorage is a global store in ArkUI.
      AppStorage.setOrCreate<string>(TemplateManager.EXTERNAL_PACK_KEY, packJson);
    }

    console.info(`[TemplateManager] External template pack applied: ${added} templates`);
    return added;
  }

  /**
   * Remove persisted external pack and clear in-memory external templates.
   */
  clearExternalTemplatePack(): void {
    this.clearExternalTemplatesInMemory();
    AppStorage.setOrCreate<string>(TemplateManager.EXTERNAL_PACK_KEY, '');
  }

  /**
   * How many external templates are currently loaded.
   */
  getExternalTemplateCount(): number {
    let cnt = 0;
    this.templates.forEach((templates: ContextTemplate[]) => {
      for (const t of templates) {
        if (t.id.startsWith(TemplateManager.EXTERNAL_ID_PREFIX)) {
          cnt++;
        }
      }
    });
    return cnt;
  }

  /**
   * Get raw persisted pack JSON (may be empty string).
   */
  getPersistedExternalPackJson(): string {
    return AppStorage.get<string>(TemplateManager.EXTERNAL_PACK_KEY) ?? '';
  }

  private loadExternalTemplatePackFromStorage(): void {
    const raw = AppStorage.get<string>(TemplateManager.EXTERNAL_PACK_KEY) ?? '';
    if (raw.trim().length === 0) {
      return;
    }
    // Do not persist again.
    this.applyExternalTemplatePack(raw, false);
  }

  private clearExternalTemplatesInMemory(): void {
    this.templates.forEach((templates: ContextTemplate[], style: string) => {
      const kept = templates.filter((t: ContextTemplate): boolean => !t.id.startsWith(TemplateManager.EXTERNAL_ID_PREFIX));
      this.templates.set(style, kept);
    });
  }

  private parseStyle(styleStr: string): ContextStyle | null {
    switch (styleStr) {
      case ContextStyle.CONVERSATIONAL:
      case ContextStyle.FORMAL:
      case ContextStyle.HUMOROUS:
      case ContextStyle.NARRATIVE:
      case ContextStyle.TECHNICAL:
      case ContextStyle.CUSTOM:
        return styleStr as ContextStyle;
      default:
        return null;
    }
  }

  private parseDifficulty(v: number): DifficultyLevel | null {
    const n = Math.round(v);
    switch (n) {
      case DifficultyLevel.CET4:
      case DifficultyLevel.CET6:
      case DifficultyLevel.IELTS:
      case DifficultyLevel.TOEFL:
      case DifficultyLevel.SAT:
      case DifficultyLevel.GRE:
        return n as DifficultyLevel;
      default:
        return null;
    }
  }

  /**
   * 加载默认模板
   */
  private loadDefaultTemplates(): void {
    // 对话式模板
    const conversationalTemplates: ContextTemplate[] = [
      new ContextTemplate(
        'conv_1_1',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.CET4,
        'I saw a {word1} in the park today.',
        'n.',
        1
      ),
      new ContextTemplate(
        'conv_2_1',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.CET4,
        'Can you pass me the {word1}? I need it for my homework.',
        'n.',
        1
      ),
      new ContextTemplate(
        'conv_3_1',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.CET6,
        'I was really {word1} when I heard the news.',
        'adj.',
        1
      ),
      new ContextTemplate(
        'conv_4_2',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.IELTS,
        'The {word1} of the {word2} was quite remarkable.',
        'n.',
        2
      ),
      new ContextTemplate(
        'conv_5_2',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.TOEFL,
        'To {word1} or not to {word2}, that is the question.',
        'v.',
        2
      )
    ];

    // 正式模板
    const formalTemplates: ContextTemplate[] = [
      new ContextTemplate(
        'formal_1_1',
        ContextStyle.FORMAL,
        DifficultyLevel.CET6,
        'The {word1} represents a significant advancement in the field.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_2_1',
        ContextStyle.FORMAL,
        DifficultyLevel.IELTS,
        'The {word1} process requires careful consideration.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_3_2',
        ContextStyle.FORMAL,
        DifficultyLevel.TOEFL,
        'The {word1} of {word2} demonstrates the complexity of the system.',
        'n.',
        2
      )
    ];

    // 幽默模板
    const humorousTemplates: ContextTemplate[] = [
      new ContextTemplate(
        'humor_1_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.CET4,
        'My {word1} is so lazy, it needs a vacation.',
        'n.',
        1
      ),
      new ContextTemplate(
        'humor_2_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.CET6,
        'I tried to {word1}, but my brain went on strike.',
        'v.',
        1
      ),
      new ContextTemplate(
        'humor_3_2',
        ContextStyle.HUMOROUS,
        DifficultyLevel.IELTS,
        'The {word1} was so {word2}, it made the cat laugh.',
        'adj.',
        2
      )
    ];

    // 叙述式模板
    const narrativeTemplates: ContextTemplate[] = [
      new ContextTemplate(
        'narr_1_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.CET4,
        'She picked up the {word1} and smiled.',
        'n.',
        1
      ),
      new ContextTemplate(
        'narr_2_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.CET6,
        'The {word1} changed everything that day.',
        'n.',
        1
      ),
      new ContextTemplate(
        'narr_3_2',
        ContextStyle.NARRATIVE,
        DifficultyLevel.IELTS,
        'The {word1} led to a {word2} that surprised everyone.',
        'n.',
        2
      )
    ];

    // 技术性模板
    const technicalTemplates: ContextTemplate[] = [
      new ContextTemplate(
        'tech_1_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.CET6,
        'The {word1} algorithm optimizes the process.',
        'n.',
        1
      ),
      new ContextTemplate(
        'tech_2_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.IELTS,
        'The {word1} interface provides seamless integration.',
        'n.',
        1
      ),
      new ContextTemplate(
        'tech_3_2',
        ContextStyle.TECHNICAL,
        DifficultyLevel.TOEFL,
        'The {word1} of {word2} ensures data integrity.',
        'n.',
        2
      )
    ];

    this.templates.set('conversational', conversationalTemplates);
    this.templates.set('formal', formalTemplates);
    this.templates.set('humorous', humorousTemplates);
    this.templates.set('narrative', narrativeTemplates);
    this.templates.set('technical', technicalTemplates);
  }

  /**
   * 根据参数获取模板
   */
  getTemplate(params: TemplateParams): ContextTemplate | null {
    if (!this.initialized) {
      this.initialize();
    }

    const styleTemplates = this.templates.get(params.style);
    if (styleTemplates === undefined) {
      return null;
    }

    // 筛选匹配难度的模板
    const matchingTemplates = styleTemplates.filter(
      (template: ContextTemplate): boolean => {
        return template.difficulty === params.difficulty &&
               template.wordCount === params.wordCount &&
               (params.pos === '' || template.pos === params.pos);
      }
    );

    if (matchingTemplates.length === 0) {
      // 如果没有完全匹配的，返回最接近的
      return this.getClosestTemplate(styleTemplates, params);
    }

    // 随机选择一个匹配的模板
    const randomIndex = Math.floor(Math.random() * matchingTemplates.length);
    return matchingTemplates[randomIndex];
  }

  /**
   * 获取最接近的模板
   */
  private getClosestTemplate(
    templates: ContextTemplate[],
    params: TemplateParams
  ): ContextTemplate | null {
    if (templates.length === 0) {
      return null;
    }

    // 优先匹配词性和单词数量
    const filtered = templates.filter(
      (template: ContextTemplate): boolean => {
        return template.wordCount === params.wordCount &&
               (params.pos === '' || template.pos === params.pos);
      }
    );

    if (filtered.length === 0) {
      // 如果没有匹配的，返回第一个
      return templates[0];
    }

    // 选择难度最接近的
    filtered.sort((a: ContextTemplate, b: ContextTemplate): number => {
      const diffA = Math.abs(a.difficulty - params.difficulty);
      const diffB = Math.abs(b.difficulty - params.difficulty);
      return diffA - diffB;
    });

    return filtered[0];
  }

  /**
   * 生成语境
   */
  generateContext(words: string[], params: TemplateParams): string | null {
    const template = this.getTemplate(params);
    if (template === null) {
      return null;
    }

    return template.fill(words);
  }

  /**
   * 获取所有可用风格
   */
  getAvailableStyles(): ContextStyle[] {
    const styles: ContextStyle[] = [
      ContextStyle.CONVERSATIONAL,
      ContextStyle.FORMAL,
      ContextStyle.HUMOROUS,
      ContextStyle.NARRATIVE,
      ContextStyle.TECHNICAL
    ];
    return styles;
  }

  /**
   * 获取所有可用难度级别
   */
  getAvailableDifficulties(): DifficultyLevel[] {
    const levels: DifficultyLevel[] = [
      DifficultyLevel.CET4,
      DifficultyLevel.CET6,
      DifficultyLevel.IELTS,
      DifficultyLevel.TOEFL,
      DifficultyLevel.SAT,
      DifficultyLevel.GRE
    ];
    return levels;
  }

  /**
   * 获取风格的中文名称
   */
  getStyleName(style: ContextStyle): string {
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
        return style;
    }
  }

  /**
   * 获取难度的中文名称
   */
  getDifficultyName(level: DifficultyLevel): string {
    switch (level) {
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
        return String(level);
    }
  }

  /**
   * 添加自定义模板
   */
  addCustomTemplate(template: ContextTemplate): void {
    const style = template.style;
    if (!this.templates.has(style)) {
      this.templates.set(style, []);
    }

    const styleTemplates = this.templates.get(style);
    if (styleTemplates !== undefined) {
      styleTemplates.push(template);
    }
  }

  /**
   * 获取模板统计
   */
  getTemplateStats(): TemplateStats {
    let total = 0;
    const styles = new Set<ContextStyle>();
    const difficulties = new Set<DifficultyLevel>();

    this.templates.forEach((templates: ContextTemplate[]) => {
      total += templates.length;
      templates.forEach((template: ContextTemplate) => {
        styles.add(template.style);
        difficulties.add(template.difficulty);
      });
    });

    const stats: TemplateStats = {
      totalTemplates: total,
      stylesCount: styles.size,
      difficultiesCount: difficulties.size
    };
    return stats;
  }

  /**
   * 根据用户水平推荐难度
   */
  recommendDifficulty(userLevel: number): DifficultyLevel {
    if (userLevel <= 1) {
      return DifficultyLevel.CET4;
    } else if (userLevel <= 2) {
      return DifficultyLevel.CET6;
    } else if (userLevel <= 3) {
      return DifficultyLevel.IELTS;
    } else if (userLevel <= 4) {
      return DifficultyLevel.TOEFL;
    } else if (userLevel <= 5) {
      return DifficultyLevel.SAT;
    } else {
      return DifficultyLevel.GRE;
    }
  }

  /**
   * 验证单词数量
   */
  validateWordCount(count: number): boolean {
    return count >= 1 && count <= 5;
  }
}

export interface TemplateStats {
  totalTemplates: number;
  stylesCount: number;
  difficultiesCount: number;
}
