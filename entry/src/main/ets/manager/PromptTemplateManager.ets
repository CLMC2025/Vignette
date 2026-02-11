/**
 * PromptTemplateManager - AI提示词模板版本管理
 * 用于管理提示词模板的版本、性能和优化
 */

/**
 * 提示词模板类型
 */
export enum PromptTemplateType {
  DEFINITION = 'definition',
  STORY_GENERATION = 'story_generation',
  STORY_TRANSLATION = 'story_translation',
  CONTEXT_MEANING = 'context_meaning',
  WORD_BOOK_CREATION = 'word_book_creation'
}

/**
 * 提示词模板状态
 */
export enum PromptTemplateStatus {
  ACTIVE = 'active',
  DEPRECATED = 'deprecated',
  TESTING = 'testing',
  DRAFT = 'draft'
}

/**
 * 提示词模板接口
 */
export interface PromptTemplate {
  id: string;
  version: number;
  type: PromptTemplateType;
  name: string;
  description: string;
  template: string;
  parameters: string[];
  validationRules: ValidationRule[];
  status: PromptTemplateStatus;
  createdAt: number;
  updatedAt: number;
  performanceMetrics?: PromptPerformanceMetrics;
  tags: string[];
}

/**
 * 验证规则条件类型
 */
export type ValidationCondition = boolean | string | ValidationLengthCondition | ValidationCustomFunction;

/**
 * 长度验证条件
 */
export interface ValidationLengthCondition {
  min?: number;
  max?: number;
}

/**
 * 自定义验证函数
 */
export type ValidationCustomFunction = (value: string) => boolean;

/**
 * 验证规则
 */
export interface ValidationRule {
  type: 'required' | 'format' | 'length' | 'regex' | 'custom';
  field: string;
  condition: ValidationCondition;
  errorMessage: string;
}

/**
 * 提示词性能指标
 */
export interface PromptPerformanceMetrics {
  successRate: number; // 成功率 (0-1)
  averageResponseTime: number; // 平均响应时间 (ms)
  userSatisfaction: number; // 用户满意度 (0-1)
  repetitionRate: number; // 重复率 (0-1)
  errorRate: number; // 错误率 (0-1)
  usageCount: number; // 使用次数
  lastUsedAt: number; // 最后使用时间
}

/**
 * 提示词优化建议
 */
export interface PromptOptimization {
  templateId: string;
  suggestion: string;
  impact: 'high' | 'medium' | 'low';
  category: 'clarity' | 'diversity' | 'accuracy' | 'performance';
  estimatedImprovement: number; // 预期改善程度 (0-1)
}

/**
 * 验证结果
 */
export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

/**
 * 提示词模板管理器 - 单例模式
 */
export class PromptTemplateManager {
  private static instance: PromptTemplateManager | null = null;
  
  // 模板存储
  private templates: Map<string, PromptTemplate> = new Map();
  private templateHistory: Map<string, PromptTemplate[]> = new Map();
  
  // 当前激活的模板
  private activeTemplates: Map<PromptTemplateType, string> = new Map();
  
  // A/B测试分组
  private abTestGroups: Map<string, string> = new Map();
  
  private constructor() {
    this.initializeDefaultTemplates();
  }
  
  /**
   * 获取单例实例
   */
  static getInstance(): PromptTemplateManager {
    if (PromptTemplateManager.instance === null) {
      PromptTemplateManager.instance = new PromptTemplateManager();
    }
    return PromptTemplateManager.instance;
  }
  
  /**
   * 初始化默认模板
   */
  private initializeDefaultTemplates(): void {
    // 词汇定义模板
    this.addTemplate({
      id: 'definition_v2',
      version: 2,
      type: PromptTemplateType.DEFINITION,
      name: '增强词汇定义模板',
      description: '提供更准确、更丰富的词汇定义，包含语境含义',
      template: 'You are a professional English-Chinese dictionary with expertise in contextual word analysis.\n\nProvide a comprehensive definition for the word "${word}"${context}.\n\nReturn a JSON object with this exact structure:\n{\n  "word": "${word}",\n  "phonetic": "phonetic transcription with slashes like /wɜːrd/",\n  "pos": "primary part of speech in this context (n./v./adj./adv./prep./conj.)",\n  "contextMeaning": "Chinese meaning specific to the given context, or most common meaning if no context",\n  "commonMeanings": [\n    {"pos": "n.", "cn": "Chinese meaning as noun"},\n    {"pos": "v.", "cn": "Chinese meaning as verb"}\n  ],\n  "exampleSentences": [\n    {"en": "Example sentence in English", "cn": "中文翻译"}\n  ],\n  "etymology": "Brief etymology if interesting (optional)",\n  "usageNotes": "Important usage notes or common mistakes (optional)"\n}\n\nRequirements:\n1. Return ONLY valid JSON, no markdown or extra text\n2. Include 2-4 common meanings in commonMeanings array\n3. contextMeaning should be concise (under 20 Chinese characters)\n4. Use standard phonetic notation\n5. Provide 2-3 natural example sentences\n6. Focus on practical, everyday usage\n7. Avoid overly academic or rare definitions',
      parameters: ['word', 'context'],
      validationRules: [
        { type: 'required', field: 'word', condition: true, errorMessage: 'Word parameter is required' },
        { type: 'format', field: 'output', condition: 'json', errorMessage: 'Output must be valid JSON' }
      ],
      status: PromptTemplateStatus.ACTIVE,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      tags: ['definition', 'comprehensive', 'contextual']
    });
    
    // 故事生成模板
    this.addTemplate({
      id: 'story_generation_v4',
      version: 4,
      type: PromptTemplateType.STORY_GENERATION,
      name: '自然语境生成模板v4',
      description: '优化自然度和连贯性，支持自定义长度，避免模板化',
      template: 'You are an expert English writing coach creating immersive learning materials.\n\nTask: Write a natural, engaging micro-story (${minWords}-${maxWords} words) featuring the word "${targetWord}".\n\nCore Elements:\n- Vocabulary: Naturally integrate [${wordList}].\n- Target Word: Ensure "${targetWord}" appears ${minTargetOccurrences}-${maxTargetOccurrences} times in meaningful, varied contexts.\n- Level: ${difficultyDescription}\n- Style: ${styleDescription}\n\nQuality Guidelines:\n1. Narrative Flow: Create a coherent scene or moment with a clear beginning, middle, and end. Avoid disjointed sentences.\n2. Natural Context: The target word should fit seamlessly. Avoid "textbook style" forced usage.\n3. Show, Don\'t Just Tell: Use sensory details and action to reveal meaning.\n4. Emotional Resonance: Aim for a specific tone (humorous, mysterious, reflective, daily life) to aid memory.\n5. Sentence Variety: Mix short punchy sentences with longer descriptive ones.\n\nRestrictions:\n- No markdown/bolding.\n- No meta-commentary (e.g., "Here is the story").\n- Strict length control: Keep within ${minWords}-${maxWords} words.\n\nOutput:\nReturn ONLY the raw story text.',
      parameters: ['wordList', 'targetWord', 'minWords', 'maxWords', 'minTargetOccurrences', 'maxTargetOccurrences', 'styleDescription', 'difficultyDescription'],
      validationRules: [
        { type: 'required', field: 'wordList', condition: true, errorMessage: 'Word list is required' },
        { type: 'length', field: 'output', condition: { min: 20, max: 300 }, errorMessage: 'Story length valid range 20-300' }
      ],
      status: PromptTemplateStatus.ACTIVE,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      tags: ['story', 'natural', 'immersive', 'v4']
    });
    
    // 故事翻译模板
    this.addTemplate({
      id: 'story_translation_v2',
      version: 2,
      type: PromptTemplateType.STORY_TRANSLATION,
      name: '语境翻译模板',
      description: '提供完整语境的准确翻译，而非逐词翻译',
      template: 'You are a professional literary translator specializing in contextual translation.\n\nTranslate the following English story into natural, fluent Chinese:\n\n"${story}"\n\nTRANSLATION REQUIREMENTS:\n1. Translate the ENTIRE story as a complete narrative\n2. Preserve the original tone, emotion, and narrative flow\n3. Use natural Chinese expressions and idioms where appropriate\n4. Maintain the story\'s pacing and dramatic structure\n5. Ensure cultural references are properly localized\n6. Keep the translation faithful but not overly literal\n7. Preserve any humor, irony, or emotional nuances\n8. Use appropriate Chinese sentence structures and flow\n\nIMPORTANT:\n- Do NOT provide word-by-word translation\n- Do NOT add explanations or notes\n- Do NOT skip any parts of the story\n- Do NOT use overly academic or archaic language\n- Focus on readability and naturalness in Chinese\n\nReturn ONLY the complete Chinese translation of the story.',
      parameters: ['story'],
      validationRules: [
        { type: 'required', field: 'story', condition: true, errorMessage: 'Story content is required' },
        { type: 'length', field: 'output', condition: { min: 20 }, errorMessage: 'Translation should be substantial' }
      ],
      status: PromptTemplateStatus.ACTIVE,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      tags: ['translation', 'contextual', 'complete', 'natural']
    });
    
    // 设置默认激活模板
    this.setActiveTemplate(PromptTemplateType.DEFINITION, 'definition_v2');
    this.setActiveTemplate(PromptTemplateType.STORY_GENERATION, 'story_generation_v4');
    this.setActiveTemplate(PromptTemplateType.STORY_TRANSLATION, 'story_translation_v2');
  }
  
  /**
   * 添加新模板
   */
  addTemplate(template: PromptTemplate): void {
    const key = `${template.id}_v${template.version}`;
    this.templates.set(key, template);
    
    // 添加到历史记录
    if (!this.templateHistory.has(template.id)) {
      this.templateHistory.set(template.id, []);
    }
    this.templateHistory.get(template.id)!.push(template);
  }
  
  /**
   * 获取激活的模板
   */
  getActiveTemplate(type: PromptTemplateType): PromptTemplate | null {
    const templateId = this.activeTemplates.get(type);
    if (!templateId) return null;
    
    // 找到最新版本的激活模板
    const templates = this.getTemplateHistory(templateId);
    return templates.length > 0 ? templates[templates.length - 1] : null;
  }
  
  /**
   * 设置激活模板
   */
  setActiveTemplate(type: PromptTemplateType, templateId: string): void {
    const templates = this.getTemplateHistory(templateId);
    if (templates.length === 0) {
      throw new Error(`Template ${templateId} not found`);
    }
    
    const latestTemplate = templates[templates.length - 1];
    if (latestTemplate.status !== PromptTemplateStatus.ACTIVE) {
      throw new Error(`Template ${templateId} is not active`);
    }
    
    this.activeTemplates.set(type, templateId);
  }
  
  /**
   * 获取模板历史
   */
  getTemplateHistory(templateId: string): PromptTemplate[] {
    return this.templateHistory.get(templateId) || [];
  }
  
  /**
   * 渲染模板（替换参数）
   */
  renderTemplate(templateId: string, parameters: Record<string, string>): string {
    const templates = this.getTemplateHistory(templateId);
    if (templates.length === 0) {
      throw new Error(`Template ${templateId} not found`);
    }
    
    const template = templates[templates.length - 1];
    let rendered = template.template;
    
    // 替换参数
    const keys: string[] = Object.keys(parameters);
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i];
      const value: string = parameters[key];
      const placeholder: string = '${' + key + '}';
      rendered = rendered.replace(new RegExp(placeholder, 'g'), value);
    }
    
    return rendered;
  }
  
  /**
   * 验证模板输出
   */
  validateOutput(templateId: string, output: string): ValidationResult {
    const template: PromptTemplate | null = this.getActiveTemplate(this.getTemplateType(templateId));
    if (template === null) {
      const result: ValidationResult = { valid: false, errors: ['Template not found'] };
      return result;
    }

    const errors: string[] = [];

    for (let i: number = 0; i < template.validationRules.length; i++) {
      const rule: ValidationRule = template.validationRules[i];
      switch (rule.type) {
        case 'required':
          if (output.length === 0) {
            errors.push(rule.errorMessage);
          }
          break;
        case 'format':
          if (rule.condition === 'json') {
            try {
              JSON.parse(output);
            } catch (e) {
              errors.push(rule.errorMessage);
            }
          }
          break;
        case 'length':
          const lengthCondition: ValidationLengthCondition = rule.condition as ValidationLengthCondition;
          if (lengthCondition.min !== undefined && output.length < lengthCondition.min) {
            errors.push(rule.errorMessage);
          }
          if (lengthCondition.max !== undefined && output.length > lengthCondition.max) {
            errors.push(rule.errorMessage);
          }
          break;
      }
    }

    const result: ValidationResult = { valid: errors.length === 0, errors: errors };
    return result;
  }
  
  /**
   * 更新模板性能指标
   */
  updatePerformanceMetrics(templateId: string, metrics: Partial<PromptPerformanceMetrics>): void {
    const templates: PromptTemplate[] = this.getTemplateHistory(templateId);
    if (templates.length === 0) {
      return;
    }

    const latestTemplate: PromptTemplate = templates[templates.length - 1];
    if (latestTemplate.performanceMetrics === undefined) {
      latestTemplate.performanceMetrics = {
        successRate: 0,
        averageResponseTime: 0,
        userSatisfaction: 0,
        repetitionRate: 0,
        errorRate: 0,
        usageCount: 0,
        lastUsedAt: Date.now()
      };
    }

    // 手动复制属性，替代 Object.assign
    if (metrics.successRate !== undefined) {
      latestTemplate.performanceMetrics.successRate = metrics.successRate;
    }
    if (metrics.averageResponseTime !== undefined) {
      latestTemplate.performanceMetrics.averageResponseTime = metrics.averageResponseTime;
    }
    if (metrics.userSatisfaction !== undefined) {
      latestTemplate.performanceMetrics.userSatisfaction = metrics.userSatisfaction;
    }
    if (metrics.repetitionRate !== undefined) {
      latestTemplate.performanceMetrics.repetitionRate = metrics.repetitionRate;
    }
    if (metrics.errorRate !== undefined) {
      latestTemplate.performanceMetrics.errorRate = metrics.errorRate;
    }
    if (metrics.usageCount !== undefined) {
      latestTemplate.performanceMetrics.usageCount = metrics.usageCount;
    }
    if (metrics.lastUsedAt !== undefined) {
      latestTemplate.performanceMetrics.lastUsedAt = metrics.lastUsedAt;
    }

    latestTemplate.performanceMetrics.lastUsedAt = Date.now();
  }
  
  /**
   * 获取优化建议
   */
  getOptimizationSuggestions(): PromptOptimization[] {
    const suggestions: PromptOptimization[] = [];
    
    for (const template of this.templates.values()) {
      if (!template.performanceMetrics) continue;
      
      const metrics = template.performanceMetrics;
      
      // 基于性能指标生成建议
      if (metrics.repetitionRate > 0.3) {
        suggestions.push({
          templateId: template.id,
          suggestion: '增加更多样化的表达和句式结构',
          impact: 'high',
          category: 'diversity',
          estimatedImprovement: 0.4
        });
      }
      
      if (metrics.successRate < 0.8) {
        suggestions.push({
          templateId: template.id,
          suggestion: '优化提示词结构以提高成功率',
          impact: 'high',
          category: 'accuracy',
          estimatedImprovement: 0.3
        });
      }
      
      if (metrics.averageResponseTime > 5000) {
        suggestions.push({
          templateId: template.id,
          suggestion: '简化提示词以减少响应时间',
          impact: 'medium',
          category: 'performance',
          estimatedImprovement: 0.2
        });
      }
    }
    
    return suggestions.sort((a, b) => b.estimatedImprovement - a.estimatedImprovement);
  }
  
  /**
   * A/B测试分组
   */
  getABTestTemplate(type: PromptTemplateType, userId: string): PromptTemplate {
    const groupKey = `${type}_${userId}`;
    
    if (!this.abTestGroups.has(groupKey)) {
      // 随机分配到A/B组
      const templates = Array.from(this.templates.values())
        .filter(t => t.type === type && t.status === PromptTemplateStatus.ACTIVE);
      
      if (templates.length === 0) {
        throw new Error(`No active templates for type ${type}`);
      }
      
      const randomIndex = Math.floor(Math.random() * templates.length);
      this.abTestGroups.set(groupKey, templates[randomIndex].id);
    }
    
    const templateId = this.abTestGroups.get(groupKey)!;
    const templates = this.getTemplateHistory(templateId);
    return templates[templates.length - 1];
  }
  
  /**
   * 获取模板类型
   */
  private getTemplateType(templateId: string): PromptTemplateType {
    const templates = this.getTemplateHistory(templateId);
    return templates.length > 0 ? templates[0].type : PromptTemplateType.DEFINITION;
  }
  
  /**
   * 导出模板数据
   */
  exportTemplates(): PromptTemplate[] {
    return Array.from(this.templates.values());
  }
  
  /**
   * 导入模板数据
   */
  importTemplates(templates: PromptTemplate[]): void {
    for (const template of templates) {
      this.addTemplate(template);
    }
  }
  
  /**
   * 清理过期数据
   */
  cleanup(): void {
    const now: number = Date.now();
    const MAX_HISTORY_AGE: number = 30 * 24 * 60 * 60 * 1000; // 30天

    // 清理旧的A/B测试分组
    const keys: string[] = Array.from(this.abTestGroups.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i];
      const parts: string[] = key.split('_');
      const timestampPart: string = parts.length > 1 ? parts[1] : '0';
      const timestamp: number = parseInt(timestampPart) || 0;
      if (now - timestamp > MAX_HISTORY_AGE) {
        this.abTestGroups.delete(key);
      }
    }
  }
}