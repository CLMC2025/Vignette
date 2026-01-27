// =====================================================
// LevelDetector.ets - 用户水平检测器
// 检测用户的词汇量、阅读理解和语法水平
// =====================================================

/**
 * 测试类型
 */
export enum TestType {
  VOCABULARY = 'vocabulary',       // 词汇量测试
  READING = 'reading',            // 阅读理解测试
  GRAMMAR = 'grammar'              // 语法知识测试
}

/**
 * 测试题目
 */
export class TestQuestion {
  id: string;
  type: TestType;
  question: string;
  options: string[];
  correctAnswer: number;
  difficulty: number;  // 1-5级

  constructor(
    id: string,
    type: TestType,
    question: string,
    options: string[],
    correctAnswer: number,
    difficulty: number
  ) {
    this.id = id;
    this.type = type;
    this.question = question;
    this.options = options;
    this.correctAnswer = correctAnswer;
    this.difficulty = difficulty;
  }

  /**
   * 检查答案是否正确
   */
  checkAnswer(answer: number): boolean {
    return answer === this.correctAnswer;
  }
}

/**
 * 测试题目数据结构（用于导入导出）
 */
export interface TestQuestionData {
  id: string;
  type: TestType;
  question: string;
  options: string[];
  correctAnswer: number;
  difficulty: number;
}

/**
 * 测试统计信息
 */
export interface TestStats {
  totalQuestions: number;
  vocabularyQuestions: number;
  readingQuestions: number;
  grammarQuestions: number;
  averageDifficulty: number;
}

/**
 * 测试结果
 */
export class TestResult {
  type: TestType;
  score: number;  // 0-100
  correctCount: number;
  totalQuestions: number;
  timeSpent: number;  // 毫秒

  constructor(
    type: TestType,
    score: number = 0,
    correctCount: number = 0,
    totalQuestions: number = 0,
    timeSpent: number = 0
  ) {
    this.type = type;
    this.score = score;
    this.correctCount = correctCount;
    this.totalQuestions = totalQuestions;
    this.timeSpent = timeSpent;
  }

  /**
   * 获取评级
   */
  getRating(): string {
    if (this.score >= 90) return '优秀';
    if (this.score >= 80) return '良好';
    if (this.score >= 70) return '中等';
    if (this.score >= 60) return '及格';
    return '不及格';
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, number | string> = {
      'type': this.type,
      'score': this.score,
      'correctCount': this.correctCount,
      'totalQuestions': this.totalQuestions,
      'timeSpent': this.timeSpent
    };
    return JSON.stringify(obj);
  }
}

/**
 * 水平检测结果
 */
export class LevelDetectionResult {
  vocabularyLevel: number;  // 0-10级
  readingLevel: number;      // 0-10级
  grammarLevel: number;      // 0-10级
  overallLevel: number;      // 0-10级
  vocabularyResult: TestResult;
  readingResult: TestResult;
  grammarResult: TestResult;
  estimatedVocabSize: number;
  confidence: number;  // 0-100

  constructor() {
    this.vocabularyLevel = 0;
    this.readingLevel = 0;
    this.grammarLevel = 0;
    this.overallLevel = 0;
    this.vocabularyResult = new TestResult(TestType.VOCABULARY);
    this.readingResult = new TestResult(TestType.READING);
    this.grammarResult = new TestResult(TestType.GRAMMAR);
    this.estimatedVocabSize = 0;
    this.confidence = 0;
  }

  /**
   * 计算综合水平
   */
  calculateOverallLevel(): void {
    this.overallLevel = Math.round(
      (this.vocabularyLevel + this.readingLevel + this.grammarLevel) / 3
    );
  }

  /**
   * 获取水平描述
   */
  getLevelDescription(): string {
    if (this.overallLevel >= 9) return '专家级';
    if (this.overallLevel >= 7) return '高级';
    if (this.overallLevel >= 5) return '中级';
    if (this.overallLevel >= 3) return '初级';
    return '入门';
  }

  /**
   * 获取建议
   */
  getRecommendations(): string[] {
    const recommendations: string[] = [];

    if (this.vocabularyLevel < 5) {
      recommendations.push('建议：增加词汇量，多背诵常用单词');
    }

    if (this.readingLevel < 5) {
      recommendations.push('建议：多阅读英文文章，提高理解能力');
    }

    if (this.grammarLevel < 5) {
      recommendations.push('建议：加强语法学习，掌握基本句型');
    }

    if (this.overallLevel >= 7) {
      recommendations.push('建议：可以尝试更高级的学习材料');
    }

    return recommendations;
  }

  /**
   * 序列化为JSON
   */
  toJSON(): string {
    const obj: Record<string, number | string | string[]> = {
      'vocabularyLevel': this.vocabularyLevel,
      'readingLevel': this.readingLevel,
      'grammarLevel': this.grammarLevel,
      'overallLevel': this.overallLevel,
      'levelDescription': this.getLevelDescription(),
      'estimatedVocabSize': this.estimatedVocabSize,
      'confidence': this.confidence,
      'recommendations': this.getRecommendations()
    };
    return JSON.stringify(obj);
  }
}

/**
 * 水平检测器
 */
export class LevelDetector {
  private static instance: LevelDetector | null = null;
  private vocabularyQuestions: TestQuestion[] = [];
  private readingQuestions: TestQuestion[] = [];
  private grammarQuestions: TestQuestion[] = [];

  private constructor() {
    this.initializeQuestions();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): LevelDetector {
    if (LevelDetector.instance === null) {
      LevelDetector.instance = new LevelDetector();
    }
    return LevelDetector.instance;
  }

  /**
   * 初始化测试题目
   */
  private initializeQuestions(): void {
    this.vocabularyQuestions = this.createVocabularyQuestions();
    this.readingQuestions = this.createReadingQuestions();
    this.grammarQuestions = this.createGrammarQuestions();
  }

  /**
   * 创建词汇量测试题目
   */
  private createVocabularyQuestions(): TestQuestion[] {
    return [
      new TestQuestion(
        'vocab_1',
        TestType.VOCABULARY,
        'What does "abundant" mean?',
        ['Scarce', 'Plentiful', 'Small', 'Difficult'],
        1,
        3
      ),
      new TestQuestion(
        'vocab_2',
        TestType.VOCABULARY,
        'Choose the synonym for "beautiful":',
        ['Ugly', 'Attractive', 'Boring', 'Scary'],
        1,
        2
      ),
      new TestQuestion(
        'vocab_3',
        TestType.VOCABULARY,
        'What is the opposite of "ancient"?',
        ['Modern', 'Old', 'Historical', 'Traditional'],
        0,
        2
      ),
      new TestQuestion(
        'vocab_4',
        TestType.VOCABULARY,
        'Which word means "to make something better"?',
        ['Improve', 'Worsen', 'Ignore', 'Destroy'],
        0,
        2
      ),
      new TestQuestion(
        'vocab_5',
        TestType.VOCABULARY,
        'What does "meticulous" mean?',
        ['Careless', 'Careful', 'Fast', 'Slow'],
        1,
        4
      ),
      new TestQuestion(
        'vocab_6',
        TestType.VOCABULARY,
        'Choose the correct word: "She was ___ by the news."',
        ['surprised', 'surprise', 'surprising', 'surprises'],
        0,
        3
      ),
      new TestQuestion(
        'vocab_7',
        TestType.VOCABULARY,
        'What does "eloquent" mean?',
        ['Silent', 'Fluent', 'Stuttering', 'Rude'],
        1,
        4
      ),
      new TestQuestion(
        'vocab_8',
        TestType.VOCABULARY,
        'Which word means "to happen suddenly"?',
        ['Gradually', 'Abruptly', 'Slowly', 'Quickly'],
        1,
        3
      ),
      new TestQuestion(
        'vocab_9',
        TestType.VOCABULARY,
        'What is the meaning of "ubiquitous"?',
        ['Rare', 'Common', 'Strange', 'Unique'],
        1,
        5
      ),
      new TestQuestion(
        'vocab_10',
        TestType.VOCABULARY,
        'Choose the antonym for "expand":',
        ['Grow', 'Shrink', 'Increase', 'Enlarge'],
        1,
        3
      )
    ];
  }

  /**
   * 创建阅读理解测试题目
   */
  private createReadingQuestions(): TestQuestion[] {
    return [
      new TestQuestion(
        'read_1',
        TestType.READING,
        'Based on the text, what is the main idea?',
        ['The author likes cats', 'Cats are popular pets', 'Cats are independent', 'Dogs are better'],
        1,
        2
      ),
      new TestQuestion(
        'read_2',
        TestType.READING,
        'What does the author suggest about cat training?',
        ['It is impossible', 'It requires patience', 'It is quick', 'It is unnecessary'],
        1,
        2
      ),
      new TestQuestion(
        'read_3',
        TestType.READING,
        'What is the tone of the passage?',
        ['Critical', 'Informative', 'Humorous', 'Argumentative'],
        1,
        2
      ),
      new TestQuestion(
        'read_4',
        TestType.READING,
        'According to the text, what makes cats unique?',
        ['Their size', 'Their independence', 'Their color', 'Their diet'],
        1,
        2
      ),
      new TestQuestion(
        'read_5',
        TestType.READING,
        'What can be inferred from the passage?',
        ['All cats are the same', 'Cats vary in personality', 'Cats are always friendly', 'Cats are difficult to care for'],
        1,
        3
      )
    ];
  }

  /**
   * 创建语法知识测试题目
   */
  private createGrammarQuestions(): TestQuestion[] {
    return [
      new TestQuestion(
        'grammar_1',
        TestType.GRAMMAR,
        'Choose the correct form: "She ___ to the store yesterday."',
        ['go', 'goes', 'went', 'going'],
        2,
        1
      ),
      new TestQuestion(
        'grammar_2',
        TestType.GRAMMAR,
        'Which sentence is correct?',
        ['He don\'t like it', 'He doesn\'t like it', 'He not like it', 'He don\'t likes it'],
        1,
        2
      ),
      new TestQuestion(
        'grammar_3',
        TestType.GRAMMAR,
        'Choose the correct tense: "I ___ there tomorrow."',
        ['will go', 'will went', 'will going', 'will gone'],
        0,
        2
      ),
      new TestQuestion(
        'grammar_4',
        TestType.GRAMMAR,
        'Which is correct?',
        ['There is many people', 'There are many people', 'There is much people', 'There are much people'],
        1,
        2
      ),
      new TestQuestion(
        'grammar_5',
        TestType.GRAMMAR,
        'Choose the correct article: "___ apple is red."',
        ['A', 'An', 'The', 'No article'],
        1,
        1
      ),
      new TestQuestion(
        'grammar_6',
        TestType.GRAMMAR,
        'Which sentence uses the correct preposition?',
        ['I\'m good in math', 'I\'m good at math', 'I\'m good on math', 'I\'m good with math'],
        1,
        2
      ),
      new TestQuestion(
        'grammar_7',
        TestType.GRAMMAR,
        'Choose the correct form: "They ___ playing football."',
        ['is', 'are', 'am', 'be'],
        1,
        1
      ),
      new TestQuestion(
        'grammar_8',
        TestType.GRAMMAR,
        'Which is the correct comparative form?',
        ['More good', 'Better', 'Gooder', 'Goodest'],
        1,
        2
      ),
      new TestQuestion(
        'grammar_9',
        TestType.GRAMMAR,
        'Choose the correct pronoun: "___ book is this?"',
        ['Who', 'Whose', 'Which', 'What'],
        1,
        2
      ),
      new TestQuestion(
        'grammar_10',
        TestType.GRAMMAR,
        'Which sentence is grammatically correct?',
        ['She have a car', 'She has a car', 'She having a car', 'She haves a car'],
        1,
        2
      )
    ];
  }

  /**
   * 执行水平检测
   */
  async detectLevel(): Promise<LevelDetectionResult> {
    const result = new LevelDetectionResult();

    // 1. 词汇量测试
    result.vocabularyResult = await this.runTest(TestType.VOCABULARY);
    result.vocabularyLevel = this.calculateLevel(result.vocabularyResult.score);

    // 2. 阅读理解测试
    result.readingResult = await this.runTest(TestType.READING);
    result.readingLevel = this.calculateLevel(result.readingResult.score);

    // 3. 语法知识测试
    result.grammarResult = await this.runTest(TestType.GRAMMAR);
    result.grammarLevel = this.calculateLevel(result.grammarResult.score);

    // 4. 计算综合水平
    result.calculateOverallLevel();

    // 5. 估算词汇量
    result.estimatedVocabSize = this.estimateVocabularySize(result.vocabularyLevel);

    // 6. 计算置信度
    result.confidence = this.calculateConfidence(result);

    return result;
  }

  /**
   * 运行测试
   */
  private async runTest(type: TestType): Promise<TestResult> {
    let questions: TestQuestion[] = [];

    switch (type) {
      case TestType.VOCABULARY:
        questions = this.vocabularyQuestions;
        break;
      case TestType.READING:
        questions = this.readingQuestions;
        break;
      case TestType.GRAMMAR:
        questions = this.grammarQuestions;
        break;
    }

    const startTime = Date.now();
    let correctCount = 0;

    // 模拟用户答题（实际应用中应该由用户交互完成）
    for (const question of questions) {
      // 随机模拟答案
      const userAnswer = Math.floor(Math.random() * question.options.length);
      if (question.checkAnswer(userAnswer)) {
        correctCount++;
      }
    }

    const endTime = Date.now();
    const timeSpent = endTime - startTime;

    const score = (correctCount / questions.length) * 100;

    return new TestResult(
      type,
      score,
      correctCount,
      questions.length,
      timeSpent
    );
  }

  /**
   * 计算水平等级（0-10）
   */
  private calculateLevel(score: number): number {
    // 将0-100的分数映射到0-10的等级
    return Math.floor(score / 10);
  }

  /**
   * 估算词汇量
   */
  private estimateVocabularySize(level: number): number {
    // 根据水平估算词汇量
    const vocabSizes: number[] = [
      500,    // 0级
      1000,   // 1级
      2000,   // 2级
      3500,   // 3级
      5000,   // 4级
      7500,   // 5级
      10000,  // 6级
      15000,  // 7级
      20000,  // 8级
      30000   // 9-10级
    ];

    return vocabSizes[Math.min(level, vocabSizes.length - 1)];
  }

  /**
   * 计算置信度
   */
  private calculateConfidence(result: LevelDetectionResult): number {
    // 基于三个测试的一致性计算置信度
    const levels = [result.vocabularyLevel, result.readingLevel, result.grammarLevel];
    const avg = levels.reduce((sum: number, level: number) => sum + level, 0) / levels.length;
    const variance = levels.reduce((sum: number, level: number) => 
      sum + Math.pow(level - avg, 2), 0
    ) / levels.length;

    // 方差越小，置信度越高
    const confidence = Math.max(0, 100 - variance * 10);
    return Math.min(100, confidence);
  }

  /**
   * 获取指定难度的题目
   */
  getQuestionsByDifficulty(difficulty: number): TestQuestion[] {
    const allQuestions = [
      ...this.vocabularyQuestions,
      ...this.readingQuestions,
      ...this.grammarQuestions
    ];

    return allQuestions.filter((q: TestQuestion): boolean => q.difficulty === difficulty);
  }

  /**
   * 获取指定类型的题目
   */
  getQuestionsByType(type: TestType): TestQuestion[] {
    switch (type) {
      case TestType.VOCABULARY:
        return this.vocabularyQuestions;
      case TestType.READING:
        return this.readingQuestions;
      case TestType.GRAMMAR:
        return this.grammarQuestions;
    }
  }

  /**
   * 获取题目总数
   */
  getTotalQuestionCount(): number {
    return this.vocabularyQuestions.length +
           this.readingQuestions.length +
           this.grammarQuestions.length;
  }

  /**
   * 添加自定义题目
   */
  addCustomQuestion(question: TestQuestion): void {
    switch (question.type) {
      case TestType.VOCABULARY:
        this.vocabularyQuestions.push(question);
        break;
      case TestType.READING:
        this.readingQuestions.push(question);
        break;
      case TestType.GRAMMAR:
        this.grammarQuestions.push(question);
        break;
    }
  }

  /**
   * 重置测试
   */
  resetTest(): void {
    this.initializeQuestions();
  }

  /**
   * 获取测试统计
   */
  getTestStatistics(): TestStats {
    const total = this.getTotalQuestionCount();
    const avgDifficulty = (
      this.vocabularyQuestions.reduce((sum: number, q: TestQuestion) => sum + q.difficulty, 0) +
      this.readingQuestions.reduce((sum: number, q: TestQuestion) => sum + q.difficulty, 0) +
      this.grammarQuestions.reduce((sum: number, q: TestQuestion) => sum + q.difficulty, 0)
    ) / total;

    return {
      totalQuestions: total,
      vocabularyQuestions: this.vocabularyQuestions.length,
      readingQuestions: this.readingQuestions.length,
      grammarQuestions: this.grammarQuestions.length,
      averageDifficulty: avgDifficulty
    };
  }

  /**
   * 导出测试题目
   */
  exportQuestions(): string {
    const allQuestions = [
      ...this.vocabularyQuestions,
      ...this.readingQuestions,
      ...this.grammarQuestions
    ];

    const data: TestQuestionData[] = allQuestions.map((q: TestQuestion): TestQuestionData => ({
      id: q.id,
      type: q.type,
      question: q.question,
      options: q.options,
      correctAnswer: q.correctAnswer,
      difficulty: q.difficulty
    }));

    return JSON.stringify(data);
  }

  /**
   * 导入测试题目
   */
  importQuestions(json: string): boolean {
    try {
      const data = JSON.parse(json) as TestQuestionData[];

      for (const item of data) {
        const question = new TestQuestion(
          item.id,
          item.type,
          item.question,
          item.options,
          item.correctAnswer,
          item.difficulty
        );
        this.addCustomQuestion(question);
      }

      return true;
    } catch (e) {
      console.error('[LevelDetector] Import failed:', e);
      return false;
    }
  }
}
