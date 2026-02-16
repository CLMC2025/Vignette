import { ContextStyle, DifficultyLevel, ContextTemplate, TemplateParams, TemplateItem, TemplatePack } from './TemplateTypes';
import { TemplateLoader } from './TemplateLoader';
import { TemplateBuilder } from './TemplateBuilder';

// Re-export for compatibility
export { ContextStyle, DifficultyLevel, ContextTemplate, TemplateParams, TemplateItem, TemplatePack };

/**
 * 模板管理器
 */
export class TemplateManager {
  private static instance: TemplateManager | null = null;
  private templates: Map<string, ContextTemplate[]>;
  private initialized: boolean = false;
  
  private loader: TemplateLoader;
  private builder: TemplateBuilder;

  private constructor() {
    this.templates = new Map();
    this.loader = new TemplateLoader();
    this.builder = new TemplateBuilder(this.templates);
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

    this.loader.loadDefaultTemplates(this.templates);
    this.loadExternalTemplatePackFromStorage();
    this.initialized = true;
    console.info('[TemplateManager] Templates initialized');
  }

  /**
   * Apply an external template pack JSON.
   */
  applyExternalTemplatePack(packJson: string, persist: boolean = true): number {
    if (!this.initialized) {
      this.loader.loadDefaultTemplates(this.templates);
    }
    return this.loader.applyExternalTemplatePack(packJson, this.templates, persist);
  }

  /**
   * Remove persisted external pack and clear in-memory external templates.
   */
  clearExternalTemplatePack(): void {
    this.loader.clearExternalTemplatesInMemory(this.templates);
    AppStorage.setOrCreate<string>(TemplateLoader.EXTERNAL_PACK_KEY, '');
  }

  /**
   * How many external templates are currently loaded.
   */
  getExternalTemplateCount(): number {
    let cnt = 0;
    this.templates.forEach((templates: ContextTemplate[]) => {
      for (const t of templates) {
        if (t.id.startsWith(TemplateLoader.EXTERNAL_ID_PREFIX)) {
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
    return AppStorage.get<string>(TemplateLoader.EXTERNAL_PACK_KEY) ?? '';
  }

  private loadExternalTemplatePackFromStorage(): void {
    const raw = AppStorage.get<string>(TemplateLoader.EXTERNAL_PACK_KEY) ?? '';
    if (raw.trim().length === 0) {
      return;
    }
    // Do not persist again.
    this.loader.applyExternalTemplatePack(raw, this.templates, false);
  }

  /**
   * 根据参数获取模板
   */
  getTemplate(params: TemplateParams, seed: number = -1): ContextTemplate | null {
    if (!this.initialized) {
      this.initialize();
    }
    return this.builder.getTemplate(params, seed);
  }

  /**
   * 生成语境
   */
  generateContext(words: string[], params: TemplateParams): string | null {
    if (!this.initialized) {
      this.initialize();
    }
    return this.builder.generateContext(words, params);
  }

  /**
   * 获取所有可用风格
   */
  getAvailableStyles(): ContextStyle[] {
    const styles: ContextStyle[] = [
      ContextStyle.RANDOM,
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
      DifficultyLevel.BEGINNER,
      DifficultyLevel.CET4,
      DifficultyLevel.CET6,
      DifficultyLevel.POSTGRADUATE,
      DifficultyLevel.IELTS,
      DifficultyLevel.TOEFL,
      DifficultyLevel.SAT,
      DifficultyLevel.GRE,
      DifficultyLevel.ADVANCED
    ];
    return levels;
  }

  /**
   * 获取风格的中文名称
   */
  getStyleName(style: ContextStyle): string {
    switch (style) {
      case ContextStyle.RANDOM:
        return '随机';
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
      case ContextStyle.CUSTOM:
        return '自定义';
      default:
        return style;
    }
  }

  getDifficultyName(level: DifficultyLevel): string {
    switch (level) {
      case DifficultyLevel.BEGINNER:
        return '入门';
      case DifficultyLevel.CET4:
        return '四级';
      case DifficultyLevel.CET6:
        return '六级';
      case DifficultyLevel.POSTGRADUATE:
        return '考研';
      case DifficultyLevel.IELTS:
        return '雅思';
      case DifficultyLevel.TOEFL:
        return '托福';
      case DifficultyLevel.SAT:
        return 'SAT';
      case DifficultyLevel.GRE:
        return 'GRE';
      case DifficultyLevel.ADVANCED:
        return '高级';
      default:
        return String(level);
    }
  }

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

  recommendDifficulty(userLevel: number): DifficultyLevel {
    if (userLevel <= 1) {
      return DifficultyLevel.CET4;
    }
    if (userLevel <= 2) {
      return DifficultyLevel.CET6;
    }
    if (userLevel <= 3) {
      return DifficultyLevel.POSTGRADUATE;
    }
    if (userLevel <= 4) {
      return DifficultyLevel.IELTS;
    }
    if (userLevel <= 5) {
      return DifficultyLevel.TOEFL;
    }
    if (userLevel <= 6) {
      return DifficultyLevel.SAT;
    }
    return DifficultyLevel.GRE;
  }
}

export interface TemplateStats {
  totalTemplates: number;
  stylesCount: number;
  difficultiesCount: number;
}
