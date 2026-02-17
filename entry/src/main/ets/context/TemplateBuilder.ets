import { ContextStyle, DifficultyLevel, ContextTemplate, TemplateParams } from './TemplateTypes';

export class TemplateBuilder {
  private templates: Map<string, ContextTemplate[]>;

  constructor(templates: Map<string, ContextTemplate[]>) {
    this.templates = templates;
  }

  /**
   * 生成语境
   */
  generateContext(words: string[], params: TemplateParams): string | null {
    const seed = this.getSeedForWords(words, params);
    const template = this.getTemplate(params, seed);
    if (template === null) {
      return null;
    }

    return template.fill(words);
  }

  /**
   * 根据参数获取模板
   */
  getTemplate(params: TemplateParams, seed: number = -1): ContextTemplate | null {
    const resolvedStyle = params.style === ContextStyle.RANDOM
      ? this.pickRandomBuiltInStyle(seed)
      : params.style;

    const styleTemplates = this.templates.get(resolvedStyle);
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
      return this.getClosestTemplate(styleTemplates, params, seed);
    }

    // 随机选择一个匹配的模板
    if (seed >= 0) {
      const idx = seed % matchingTemplates.length;
      return matchingTemplates[idx];
    }
    // NOTE: Math.random() is acceptable here for UI/UX randomization (not security-critical)
    // This is used only for template selection in story generation
    const randomIndex = Math.floor(Math.random() * matchingTemplates.length);
    return matchingTemplates[randomIndex];
  }

  private pickRandomBuiltInStyle(seed: number = -1): ContextStyle {
    const styles: ContextStyle[] = [
      ContextStyle.CONVERSATIONAL,
      ContextStyle.FORMAL,
      ContextStyle.HUMOROUS,
      ContextStyle.NARRATIVE,
      ContextStyle.TECHNICAL
    ];
    // NOTE: Math.random() is acceptable here for UI/UX randomization (not security-critical)
    const idx = seed >= 0 ? (seed % styles.length) : Math.floor(Math.random() * styles.length);
    return styles[idx];
  }

  private getSeedForWords(words: string[], params: TemplateParams): number {
    const now = new Date();
    const y = now.getFullYear();
    const m = now.getMonth() + 1;
    const d = now.getDate();
    const seedStr = `${y}-${m}-${d}|${words.join(',')}|${params.style}|${params.difficulty}|${params.pos}|${params.wordCount}`;
    let hash = 2166136261;
    for (let i = 0; i < seedStr.length; i++) {
      hash ^= seedStr.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  /**
   * 获取最接近的模板
   */
  private getClosestTemplate(
    templates: ContextTemplate[],
    params: TemplateParams,
    seed: number = -1
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
      if (seed >= 0) {
        return templates[seed % templates.length];
      }
      // NOTE: Math.random() is acceptable here for UI/UX randomization (not security-critical)
      const randomIndex = Math.floor(Math.random() * templates.length);
      return templates[randomIndex];
    }

    // 选择难度最接近的
    filtered.sort((a: ContextTemplate, b: ContextTemplate): number => {
      const diffA = Math.abs(a.difficulty - params.difficulty);
      const diffB = Math.abs(b.difficulty - params.difficulty);
      return diffA - diffB;
    });

    const bestDiff = Math.abs(filtered[0].difficulty - params.difficulty);
    const bestCandidates: ContextTemplate[] = [];
    for (const t of filtered) {
      const diff = Math.abs(t.difficulty - params.difficulty);
      if (diff === bestDiff) {
        bestCandidates.push(t);
      } else {
        break;
      }
    }
    if (bestCandidates.length === 0) {
      return filtered[0];
    }
    if (seed >= 0) {
      return bestCandidates[seed % bestCandidates.length];
    }
    // NOTE: Math.random() is acceptable here for UI/UX randomization (not security-critical)
    const randomIndex = Math.floor(Math.random() * bestCandidates.length);
    return bestCandidates[randomIndex];
  }
}
