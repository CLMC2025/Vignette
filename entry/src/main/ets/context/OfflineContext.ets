// =====================================================
// OfflineContext.ets - 离线语境生成器
// 使用模板系统实现离线语境生成，无需AI API
// =====================================================

import { TemplateManager, ContextStyle, DifficultyLevel, TemplateParams } from './TemplateManager';

/**
 * 生成结果
 */
export class GenerationResult {
  success: boolean;
  context: string;
  error: string;

  constructor(success: boolean = false, context: string = '', error: string = '') {
    this.success = success;
    this.context = context;
    this.error = error;
  }
}

/**
 * 词汇信息
 */
export class WordInfo {
  word: string;
  pos: string;  // 词性
  meaning: string;  // 中文含义

  constructor(word: string, pos: string = 'n.', meaning: string = '') {
    this.word = word;
    this.pos = pos;
    this.meaning = meaning;
  }
}

/**
 * 离线语境生成器
 */
export class OfflineContextGenerator {
  private static instance: OfflineContextGenerator | null = null;
  private templateManager: TemplateManager;
  private wordDatabase: Map<string, WordInfo>;

  private constructor() {
    this.templateManager = TemplateManager.getInstance();
    this.wordDatabase = new Map();
    this.initializeWordDatabase();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): OfflineContextGenerator {
    if (OfflineContextGenerator.instance === null) {
      OfflineContextGenerator.instance = new OfflineContextGenerator();
    }
    return OfflineContextGenerator.instance;
  }

  /**
   * 初始化词汇数据库
   */
  private initializeWordDatabase(): void {
    // 常用词汇及其词性和含义
    const commonWords: WordInfo[] = [
      new WordInfo('happy', 'adj.', '快乐的'),
      new WordInfo('study', 'v.', '学习'),
      new WordInfo('learn', 'v.', '学习'),
      new WordInfo('book', 'n.', '书'),
      new WordInfo('friend', 'n.', '朋友'),
      new WordInfo('good', 'adj.', '好的'),
      new WordInfo('time', 'n.', '时间'),
      new WordInfo('work', 'v.', '工作'),
      new WordInfo('play', 'v.', '玩'),
      new WordInfo('love', 'v.', '爱'),
      new WordInfo('home', 'n.', '家'),
      new WordInfo('school', 'n.', '学校'),
      new WordInfo('teacher', 'n.', '老师'),
      new WordInfo('student', 'n.', '学生'),
      new WordInfo('family', 'n.', '家庭'),
      new WordInfo('food', 'n.', '食物'),
      new WordInfo('water', 'n.', '水'),
      new WordInfo('music', 'n.', '音乐'),
      new WordInfo('movie', 'n.', '电影'),
      new WordInfo('travel', 'v.', '旅行'),
      new WordInfo('help', 'v.', '帮助'),
      new WordInfo('make', 'v.', '制作'),
      new WordInfo('take', 'v.', '拿'),
      new WordInfo('give', 'v.', '给'),
      new WordInfo('see', 'v.', '看'),
      new WordInfo('go', 'v.', '去'),
      new WordInfo('come', 'v.', '来'),
      new WordInfo('think', 'v.', '想'),
      new WordInfo('know', 'v.', '知道'),
      new WordInfo('want', 'v.', '想要'),
      new WordInfo('need', 'v.', '需要'),
      new WordInfo('like', 'v.', '喜欢'),
      new WordInfo('have', 'v.', '有'),
      new WordInfo('be', 'v.', '是'),
      new WordInfo('do', 'v.', '做'),
      new WordInfo('say', 'v.', '说'),
      new WordInfo('tell', 'v.', '告诉'),
      new WordInfo('ask', 'v.', '问'),
      new WordInfo('answer', 'v.', '回答'),
      new WordInfo('read', 'v.', '读'),
      new WordInfo('write', 'v.', '写'),
      new WordInfo('listen', 'v.', '听'),
      new WordInfo('speak', 'v.', '说'),
      new WordInfo('watch', 'v.', '看'),
      new WordInfo('look', 'v.', '看'),
      new WordInfo('find', 'v.', '找'),
      new WordInfo('use', 'v.', '使用'),
      new WordInfo('try', 'v.', '尝试'),
      new WordInfo('start', 'v.', '开始'),
      new WordInfo('stop', 'v.', '停止'),
      new WordInfo('finish', 'v.', '完成'),
      new WordInfo('begin', 'v.', '开始'),
      new WordInfo('end', 'v.', '结束'),
      new WordInfo('open', 'v.', '打开'),
      new WordInfo('close', 'v.', '关闭'),
      new WordInfo('big', 'adj.', '大的'),
      new WordInfo('small', 'adj.', '小的'),
      new WordInfo('new', 'adj.', '新的'),
      new WordInfo('old', 'adj.', '旧的'),
      new WordInfo('long', 'adj.', '长的'),
      new WordInfo('short', 'adj.', '短的'),
      new WordInfo('fast', 'adj.', '快的'),
      new WordInfo('slow', 'adj.', '慢的'),
      new WordInfo('hot', 'adj.', '热的'),
      new WordInfo('cold', 'adj.', '冷的'),
      new WordInfo('easy', 'adj.', '容易的'),
      new WordInfo('hard', 'adj.', '困难的'),
      new WordInfo('important', 'adj.', '重要的'),
      new WordInfo('interesting', 'adj.', '有趣的'),
      new WordInfo('beautiful', 'adj.', '美丽的'),
      new WordInfo('different', 'adj.', '不同的'),
      new WordInfo('same', 'adj.', '相同的'),
      new WordInfo('first', 'adj.', '第一'),
      new WordInfo('last', 'adj.', '最后的'),
      new WordInfo('next', 'adj.', '下一个'),
      new WordInfo('many', 'adj.', '许多'),
      new WordInfo('few', 'adj.', '一些'),
      new WordInfo('all', 'adj.', '所有的'),
      new WordInfo('some', 'adj.', '一些'),
      new WordInfo('every', 'adj.', '每个'),
      new WordInfo('other', 'adj.', '其他的'),
      new WordInfo('another', 'adj.', '另一个'),
      new WordInfo('people', 'n.', '人们'),
      new WordInfo('place', 'n.', '地方'),
      new WordInfo('thing', 'n.', '东西'),
      new WordInfo('way', 'n.', '方式'),
      new WordInfo('day', 'n.', '天'),
      new WordInfo('week', 'n.', '周'),
      new WordInfo('month', 'n.', '月'),
      new WordInfo('year', 'n.', '年'),
      new WordInfo('morning', 'n.', '早晨'),
      new WordInfo('afternoon', 'n.', '下午'),
      new WordInfo('evening', 'n.', '晚上'),
      new WordInfo('night', 'n.', '晚上'),
      new WordInfo('today', 'n.', '今天'),
      new WordInfo('tomorrow', 'n.', '明天'),
      new WordInfo('yesterday', 'n.', '昨天'),
      new WordInfo('problem', 'n.', '问题'),
      new WordInfo('answer', 'n.', '答案'),
      new WordInfo('question', 'n.', '问题'),
      new WordInfo('idea', 'n.', '想法'),
      new WordInfo('story', 'n.', '故事'),
      new WordInfo('news', 'n.', '新闻'),
      new WordInfo('world', 'n.', '世界'),
      new WordInfo('life', 'n.', '生活'),
      new WordInfo('love', 'n.', '爱'),
      new WordInfo('hope', 'n.', '希望'),
      new WordInfo('dream', 'n.', '梦想'),
      new WordInfo('success', 'n.', '成功'),
      new WordInfo('failure', 'n.', '失败'),
      new WordInfo('chance', 'n.', '机会'),
      new WordInfo('change', 'n.', '变化'),
      new WordInfo('future', 'n.', '未来'),
      new WordInfo('past', 'n.', '过去'),
      new WordInfo('present', 'n.', '现在')
    ];

    for (const wordInfo of commonWords) {
      this.wordDatabase.set(wordInfo.word.toLowerCase(), wordInfo);
    }
  }

  /**
   * 生成语境
   */
  generateContext(
    targetWord: string,
    supportWords: string[],
    style: ContextStyle = ContextStyle.CONVERSATIONAL,
    difficulty: DifficultyLevel = DifficultyLevel.IELTS
  ): GenerationResult {
    try {
      // 初始化模板管理器
      this.templateManager.initialize();

      // 获取目标词汇信息
      const targetWordInfo = this.getWordInfo(targetWord);
      const supportWordInfos = supportWords.map((word: string): WordInfo => this.getWordInfo(word));

      // 确定词性（默认为名词）
      const pos = targetWordInfo.pos;

      // 创建模板参数
      const params = new TemplateParams(
        style,
        difficulty,
        pos,
        Math.min(supportWords.length + 1, 3) // 最多3个单词
      );

      // 使用模板生成语境
      const context = this.templateManager.generateContext(
        [targetWord, ...supportWords],
        params
      );

      if (context === null) {
        return new GenerationResult(false, '', '无法生成语境：没有合适的模板');
      }

      return new GenerationResult(true, context, '');
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[OfflineContextGenerator] Generation failed:', errMsg);
      return new GenerationResult(false, '', `生成失败: ${errMsg}`);
    }
  }

  /**
   * 获取词汇信息
   */
  private getWordInfo(word: string): WordInfo {
    const lowerWord = word.toLowerCase();
    const wordInfo = this.wordDatabase.get(lowerWord);

    if (wordInfo !== undefined) {
      return wordInfo;
    }

    // 如果词汇不在数据库中，创建默认信息
    return new WordInfo(word, 'n.', '');
  }

  /**
   * 添加词汇到数据库
   */
  addWord(word: string, pos: string = 'n.', meaning: string = ''): void {
    const wordInfo = new WordInfo(word, pos, meaning);
    this.wordDatabase.set(word.toLowerCase(), wordInfo);
  }

  /**
   * 批量添加词汇
   */
  addWords(words: WordInfo[]): void {
    for (const word of words) {
      this.addWord(word.word, word.pos, word.meaning);
    }
  }

  /**
   * 检查词汇是否在数据库中
   */
  hasWord(word: string): boolean {
    return this.wordDatabase.has(word.toLowerCase());
  }

  /**
   * 获取数据库大小
   */
  getDatabaseSize(): number {
    return this.wordDatabase.size;
  }

  /**
   * 获取所有词汇
   */
  getAllWords(): WordInfo[] {
    return Array.from(this.wordDatabase.values());
  }

  /**
   * 搜索词汇
   */
  searchWords(prefix: string): WordInfo[] {
    const lowerPrefix = prefix.toLowerCase();
    const results: WordInfo[] = [];

    this.wordDatabase.forEach((wordInfo: WordInfo, word: string) => {
      if (word.startsWith(lowerPrefix)) {
        results.push(wordInfo);
      }
    });

    return results;
  }

  /**
   * 根据词性获取词汇
   */
  getWordsByPos(pos: string): WordInfo[] {
    const results: WordInfo[] = [];

    this.wordDatabase.forEach((wordInfo: WordInfo) => {
      if (wordInfo.pos === pos) {
        results.push(wordInfo);
      }
    });

    return results;
  }

  /**
   * 获取随机词汇
   */
  getRandomWords(count: number): WordInfo[] {
    const allWords = this.getAllWords();
    const shuffled = allWords.sort(() => 0.5 - Math.random());
    return shuffled.slice(0, Math.min(count, allWords.length));
  }

  /**
   * 生成多个语境变体
   */
  generateMultipleContexts(
    targetWord: string,
    supportWords: string[],
    count: number = 3,
    style: ContextStyle = ContextStyle.CONVERSATIONAL,
    difficulty: DifficultyLevel = DifficultyLevel.IELTS
  ): GenerationResult[] {
    const results: GenerationResult[] = [];
    const styles: ContextStyle[] = [
      ContextStyle.CONVERSATIONAL,
      ContextStyle.FORMAL,
      ContextStyle.HUMOROUS,
      ContextStyle.NARRATIVE,
      ContextStyle.TECHNICAL
    ];

    for (let i = 0; i < count; i++) {
      // 使用不同的风格生成
      const currentStyle = styles[i % styles.length];

      const result = this.generateContext(
        targetWord,
        supportWords,
        currentStyle,
        difficulty
      );

      results.push(result);
    }

    return results;
  }

  /**
   * 验证生成的语境
   */
  validateContext(context: string, targetWord: string): boolean {
    if (context.length === 0) {
      return false;
    }

    // 检查目标词汇是否在语境中
    const lowerContext = context.toLowerCase();
    const lowerTargetWord = targetWord.toLowerCase();

    if (!lowerContext.includes(lowerTargetWord)) {
      return false;
    }

    // 检查语境长度是否合理
    if (context.length < 10 || context.length > 200) {
      return false;
    }

    return true;
  }

  /**
   * 获取生成统计
   */
  getGenerationStats(): GenerationStats {
    const stats: GenerationStats = {
      totalWords: this.getDatabaseSize(),
      availableStyles: this.templateManager.getAvailableStyles().length,
      availableDifficulties: this.templateManager.getAvailableDifficulties().length
    };
    return stats;
  }

  /**
   * 清空词汇数据库
   */
  clearDatabase(): void {
    this.wordDatabase.clear();
    this.initializeWordDatabase();
  }

  /**
   * 导出词汇数据库
   */
  exportDatabase(): string {
    const words = this.getAllWords();
    const data: ExportedWordInfo[] = words.map((wordInfo: WordInfo): ExportedWordInfo => ({
      word: wordInfo.word,
      pos: wordInfo.pos,
      meaning: wordInfo.meaning
    }));
    return JSON.stringify(data);
  }

  /**
   * 导入词汇数据库
   */
  importDatabase(json: string): boolean {
    try {
      const data = JSON.parse(json) as Array<WordImportData>;
      const wordInfos = data.map((item) => new WordInfo(item.word, item.pos, item.meaning));
      this.addWords(wordInfos);
      return true;
    } catch (e) {
      console.error('[OfflineContextGenerator] Import failed:', e);
      return false;
    }
  }
}

export interface GenerationStats {
  totalWords: number;
  availableStyles: number;
  availableDifficulties: number;
}

export interface WordImportData {
  word: string;
  pos: string;
  meaning: string;
}

export interface ExportedWordInfo {
  word: string;
  pos: string;
  meaning: string;
}
