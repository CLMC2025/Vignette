import { ContextStyle, DifficultyLevel, TemplateItem, TemplatePack, ContextTemplate } from './TemplateTypes';

export class TemplateLoader {
  public static readonly EXTERNAL_PACK_KEY: string = 'offline_template_pack_json';
  public static readonly EXTERNAL_ID_PREFIX: string = 'pack_';

  public loadDefaultTemplates(templates: Map<string, ContextTemplate[]>): void {
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
        'conv_6_1',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.CET4,
        'I used {word1} to help my friend this afternoon.',
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
        'conv_beg_1_1',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.BEGINNER,
        'This is my {word1}.',
        'n.',
        1
      ),
      new ContextTemplate(
        'conv_pg_2_2',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.POSTGRADUATE,
        'The {word1} of the {word2} came up in our discussion.',
        'n.',
        2
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
      ),
      new ContextTemplate(
        'conv_sat_3_2',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.SAT,
        'The {word1} of {word2} really surprised me today.',
        'n.',
        2
      ),
      new ContextTemplate(
        'conv_gre_3_2',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.GRE,
        'We debated {word1} and {word2} during the seminar.',
        'n.',
        2
      ),
      new ContextTemplate(
        'conv_adv_2_1',
        ContextStyle.CONVERSATIONAL,
        DifficultyLevel.ADVANCED,
        'That {word1} feels more nuanced than I expected.',
        'n.',
        1
      )
    ];

    // 正式模板
    const formalTemplates: ContextTemplate[] = [
      new ContextTemplate(
        'formal_0_1',
        ContextStyle.FORMAL,
        DifficultyLevel.CET4,
        'In this text, {word1} is an important idea to remember.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_beg_0_1',
        ContextStyle.FORMAL,
        DifficultyLevel.BEGINNER,
        'The {word1} is a basic concept in this lesson.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_1_1',
        ContextStyle.FORMAL,
        DifficultyLevel.CET6,
        'The {word1} represents a significant advancement in the field.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_1_1b',
        ContextStyle.FORMAL,
        DifficultyLevel.CET6,
        'In recent years, the concept of {word1} has gained wide attention.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_1_1c',
        ContextStyle.FORMAL,
        DifficultyLevel.CET6,
        '{word1} plays a crucial role in shaping the final outcome.',
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
        'formal_pg_1_1',
        ContextStyle.FORMAL,
        DifficultyLevel.POSTGRADUATE,
        'The {word1} addresses a key challenge in this field.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_gre_2_2',
        ContextStyle.FORMAL,
        DifficultyLevel.GRE,
        'The {word1} of {word2} illustrates a complex principle.',
        'n.',
        2
      ),
      new ContextTemplate(
        'formal_sat_2_1',
        ContextStyle.FORMAL,
        DifficultyLevel.SAT,
        'The {word1} provides a strong foundation for the argument.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_adv_2_1',
        ContextStyle.FORMAL,
        DifficultyLevel.ADVANCED,
        'The {word1} embodies a nuanced perspective.',
        'n.',
        1
      ),
      new ContextTemplate(
        'formal_4_2',
        ContextStyle.FORMAL,
        DifficultyLevel.CET6,
        'The {word1} of {word2} suggests a careful and balanced approach.',
        'n.',
        2
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
        'humor_4_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.CET4,
        'I asked {word1} for help, and it laughed at me.',
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
        'humor_beg_1_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.BEGINNER,
        'My {word1} tried to help and made things worse.',
        'n.',
        1
      ),
      new ContextTemplate(
        'humor_pg_2_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.POSTGRADUATE,
        'The {word1} was so intense, even my coffee needed a break.',
        'n.',
        1
      ),
      new ContextTemplate(
        'humor_sat_2_2',
        ContextStyle.HUMOROUS,
        DifficultyLevel.SAT,
        'I tried to {word1}, but my {word2} called it a day.',
        'v.',
        2
      ),
      new ContextTemplate(
        'humor_tofl_3_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.TOEFL,
        'My {word1} was so dramatic, it deserved an award.',
        'n.',
        1
      ),
      new ContextTemplate(
        'humor_gre_3_2',
        ContextStyle.HUMOROUS,
        DifficultyLevel.GRE,
        'The {word1} and {word2} joined forces to confuse me.',
        'n.',
        2
      ),
      new ContextTemplate(
        'humor_adv_2_1',
        ContextStyle.HUMOROUS,
        DifficultyLevel.ADVANCED,
        'My {word1} was so refined, it asked for a tuxedo.',
        'n.',
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
        'narr_4_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.CET4,
        'At the corner of the street, the {word1} caught his eye.',
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
        'narr_beg_1_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.BEGINNER,
        'He held the {word1} and walked home.',
        'n.',
        1
      ),
      new ContextTemplate(
        'narr_pg_2_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.POSTGRADUATE,
        'He studied the {word1} all night before the test.',
        'n.',
        1
      ),
      new ContextTemplate(
        'narr_tofl_2_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.TOEFL,
        'The {word1} lingered in her thoughts for days.',
        'n.',
        1
      ),
      new ContextTemplate(
        'narr_sat_3_2',
        ContextStyle.NARRATIVE,
        DifficultyLevel.SAT,
        'A {word1} brought a {word2} he could not ignore.',
        'n.',
        2
      ),
      new ContextTemplate(
        'narr_gre_3_2',
        ContextStyle.NARRATIVE,
        DifficultyLevel.GRE,
        'The {word1} led to a {word2} he could not ignore.',
        'n.',
        2
      ),
      new ContextTemplate(
        'narr_adv_4_1',
        ContextStyle.NARRATIVE,
        DifficultyLevel.ADVANCED,
        'The {word1} revealed a subtle turning point.',
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
        'tech_0_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.CET4,
        'We use {word1} to make the task faster and easier.',
        'n.',
        1
      ),
      new ContextTemplate(
        'tech_beg_0_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.BEGINNER,
        'The {word1} is a simple tool for this task.',
        'n.',
        1
      ),
      new ContextTemplate(
        'tech_1_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.CET6,
        'The {word1} algorithm optimizes the process.',
        'n.',
        1
      ),
      new ContextTemplate(
        'tech_pg_2_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.POSTGRADUATE,
        'The {word1} framework improves the study design.',
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
        'tech_sat_2_1',
        ContextStyle.TECHNICAL,
        DifficultyLevel.SAT,
        'The {word1} model improves accuracy under stress.',
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
      ),
      new ContextTemplate(
        'tech_adv_3_2',
        ContextStyle.TECHNICAL,
        DifficultyLevel.ADVANCED,
        'The {word1} of {word2} reveals hidden constraints.',
        'n.',
        2
      ),
      new ContextTemplate(
        'tech_gre_3_2',
        ContextStyle.TECHNICAL,
        DifficultyLevel.GRE,
        'The {word1} and {word2} metrics capture long-term variance.',
        'n.',
        2
      )
    ];

    templates.set('conversational', conversationalTemplates);
    templates.set('formal', formalTemplates);
    templates.set('humorous', humorousTemplates);
    templates.set('narrative', narrativeTemplates);
    templates.set('technical', technicalTemplates);
  }

  public applyExternalTemplatePack(
    packJson: string, 
    templates: Map<string, ContextTemplate[]>, 
    persist: boolean = true
  ): number {
    if (packJson.trim().length === 0) {
      return 0;
    }

    this.clearExternalTemplatesInMemory(templates);

    let data: TemplatePack | TemplateItem[];
    try {
      data = JSON.parse(packJson);
    } catch (e) {
      console.warn('[TemplateLoader] Invalid template pack JSON');
      return 0;
    }

    let difficultySchemaVersion = 1;
    if (!Array.isArray(data) && data && typeof data === 'object') {
      const schemaRaw = (data as TemplatePack).difficultySchemaVersion;
      if (typeof schemaRaw === 'number' && Number.isFinite(schemaRaw)) {
        difficultySchemaVersion = Math.round(schemaRaw);
      }
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
      const difficulty = this.parseDifficultyWithSchema(difficultyNum, difficultySchemaVersion);
      if (difficulty === null) {
        continue;
      }

      const tpl = String(obj.template ?? '').trim();
      const pos = String(obj.pos ?? '').trim();
      const wc = typeof obj.wordCount === 'number' ? obj.wordCount : Number(obj.wordCount ?? 1);

      if (tpl.length === 0 || !Number.isFinite(wc) || wc <= 0) {
        continue;
      }

      if (!tpl.includes('{word1}')) {
        continue;
      }

      const idRaw = String(obj.id ?? '');
      const id = idRaw.trim().length > 0
        ? `${TemplateLoader.EXTERNAL_ID_PREFIX}${idRaw.trim()}`
        : `${TemplateLoader.EXTERNAL_ID_PREFIX}${styleStr}_${difficultyNum}_${i}`;

      const template = new ContextTemplate(id, style, difficulty, tpl, pos, Math.round(wc));
      if (!template.isValid()) {
        continue;
      }
      this.addTemplateToMap(templates, template);
      added++;
    }

    if (persist) {
      AppStorage.setOrCreate<string>(TemplateLoader.EXTERNAL_PACK_KEY, packJson);
    }

    console.info(`[TemplateLoader] External template pack applied: ${added} templates`);
    return added;
  }

  public clearExternalTemplatesInMemory(templates: Map<string, ContextTemplate[]>): void {
    templates.forEach((list: ContextTemplate[], style: string) => {
      const kept = list.filter((t: ContextTemplate): boolean => !t.id.startsWith(TemplateLoader.EXTERNAL_ID_PREFIX));
      templates.set(style, kept);
    });
  }

  private addTemplateToMap(templates: Map<string, ContextTemplate[]>, template: ContextTemplate): void {
    const style = template.style;
    if (!templates.has(style)) {
      templates.set(style, []);
    }
    const list = templates.get(style);
    if (list) {
      list.push(template);
    }
  }

  private parseStyle(styleStr: string): ContextStyle | null {
    switch (styleStr) {
      case ContextStyle.RANDOM:
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
      case DifficultyLevel.BEGINNER:
      case DifficultyLevel.CET4:
      case DifficultyLevel.CET6:
      case DifficultyLevel.POSTGRADUATE:
      case DifficultyLevel.IELTS:
      case DifficultyLevel.TOEFL:
      case DifficultyLevel.SAT:
      case DifficultyLevel.GRE:
      case DifficultyLevel.ADVANCED:
        return n as DifficultyLevel;
      default:
        return null;
    }
  }

  private parseDifficultyLegacy(v: number): DifficultyLevel | null {
    const n = Math.round(v);
    switch (n) {
      case 0:
        return DifficultyLevel.BEGINNER;
      case 1:
        return DifficultyLevel.CET4;
      case 2:
        return DifficultyLevel.CET6;
      case 3:
        return DifficultyLevel.IELTS;
      case 4:
        return DifficultyLevel.TOEFL;
      case 5:
        return DifficultyLevel.SAT;
      case 6:
        return DifficultyLevel.GRE;
      case 7:
        return DifficultyLevel.ADVANCED;
      default:
        return null;
    }
  }

  private parseDifficultyWithSchema(v: number, schemaVersion: number): DifficultyLevel | null {
    if (schemaVersion < 2) {
      return this.parseDifficultyLegacy(v);
    }
    return this.parseDifficulty(v);
  }
}
