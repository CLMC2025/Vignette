import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import resourceManager from '@ohos.resourceManager';
import { DBManager } from '../database/DBManager';
import { BuiltInWordBooks, WordBookDefinition, BookCategory, BookDifficulty, BookProgress, buildWordItemsForBook, loadWordBookWords } from '../model/WordBookCatalog';
import { DesignTokens } from '../model/DesignTokens';
import { CurrentBookStore } from '../utils/CurrentBookStore';
import { BookCard, BookCardData } from '../components/BookCard';

@Entry
@Component
struct WordBookManagerPage {
  @State isLoading: boolean = false;
  @State systemBooks: BookCardData[] = [];
  @State userBooks: BookCardData[] = [];
  @State currentBookId: string = '';
  @State loadErrorMessage: string = '';

  @State totalWords: number = 0;
  @State masteredWords: number = 0;
  @State learningWords: number = 0;

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  private systemBookCountCache: Map<string, number> = new Map<string, number>();
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';
  private isNavigating: boolean = false;
  private isDataLoaded: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext | null;
    this.context = ctx;
    this.resourceMgr = ctx ? ctx.resourceManager : null;
    console.log('[WordBookManager] aboutToAppear, isDataLoaded:', this.isDataLoaded);
    // Always reload data when page appears
    void this.loadData();
  }

  async onPageShow(): Promise<void> {
    if (this.isDataLoaded && !this.isLoading) {
      void this.loadData();
    }
  }

  private async loadData(): Promise<void> {
    if (this.isLoading) {
      console.log('[WordBookManager] Already loading, skip');
      return;
    }
    console.log('[WordBookManager] Start loading data...');
    this.isLoading = true;
    this.loadErrorMessage = '';
    try {
      if (this.context === null) {
        console.error('[WordBookManager] Context is null');
        this.loadErrorMessage = '上下文初始化失败';
        this.isLoading = false;
        return;
      }
      console.log('[WordBookManager] Initializing database...');
      await this.dbManager.initialize(this.context);
      console.log('[WordBookManager] Database initialized');

      const store = CurrentBookStore.getInstance();
      store.injectContext(this.context);
      await store.initialize();
      this.currentBookId = await store.getCurrentBookId();
      console.log('[WordBookManager] Current book ID:', this.currentBookId);

      // Load User Books
      console.log('[WordBookManager] Loading user books...');
      const userBookDefs = await this.dbManager.getUserWordBooks();
      console.log('[WordBookManager] User books count:', userBookDefs.length);
      const userBookCards: BookCardData[] = [];
      for (const b of userBookDefs) {
        const progress: BookProgress = await this.dbManager.getBookProgress(b.id, false);
        const dailyGoal = this.getDefaultDailyGoal(b.wordCount);
        const estimatedDays = this.getEstimatedDays(b.wordCount, dailyGoal);

        const card: BookCardData = {
          id: b.id,
          name: b.name,
          description: b.description,
          wordCount: b.wordCount,
          category: (b.category as BookCategory) || BookCategory.Other,
          difficulty: (b.difficulty as BookDifficulty) || BookDifficulty.Basic,
          progress: progress,
          estimatedDays,
          dailyGoal,
          sourceLabel: '自建词书',
          isCurrent: b.id === this.currentBookId,
          isImported: true,
          isUserBook: true
        };
        userBookCards.push(card);
      }
      this.userBooks = userBookCards;
      console.log('[WordBookManager] User books loaded');

      // Load System Books
      console.log('[WordBookManager] Loading system books...');
      const sysBookCards: BookCardData[] = [];
      for (const b of BuiltInWordBooks) {
        const importedCount = await this.dbManager.getSystemWordBookWordCount(b.id);
        const isImported = importedCount > 0;
        let progress: BookProgress = new BookProgress();

        if (isImported) {
          progress = await this.dbManager.getBookProgress(b.id, true);
        }
        const displayCount = isImported ? importedCount : await this.getBuiltInWordCount(b);

        const card: BookCardData = {
          id: b.id,
          name: b.name,
          description: b.description,
          wordCount: displayCount,
          category: b.category,
          difficulty: b.difficulty,
          progress: this.buildBookProgress(progress, isImported ? progress.newWords : displayCount),
          estimatedDays: b.estimatedDays,
          dailyGoal: b.dailyGoal,
          sourceLabel: this.buildSourceLabel(b.source, b.license),
          isCurrent: b.id === this.currentBookId,
          isImported: isImported,
          isUserBook: false
        };
        sysBookCards.push(card);
      }
      this.systemBooks = sysBookCards;
      console.log('[WordBookManager] System books loaded:', sysBookCards.length);

      this.calculateGlobalStats();
      this.isDataLoaded = true;
      console.log('[WordBookManager] Data loading completed');

    } catch (e) {
      console.error('[WordBookManager] Load failed:', e);
      const errText = e instanceof Error ? e.message : String(e);
      this.loadErrorMessage = errText.length > 0 ? errText : '加载失败，请稍后重试';
      promptAction.showToast({ message: '加载失败: ' + this.loadErrorMessage, duration: 3000 });
    } finally {
      console.log('[WordBookManager] Setting isLoading to false');
      this.isLoading = false;
    }
  }

  private calculateGlobalStats(): void {
    const current = [...this.userBooks, ...this.systemBooks].find(b => b.id === this.currentBookId);
    if (!current) {
      this.totalWords = 0;
      this.masteredWords = 0;
      this.learningWords = 0;
      return;
    }
    this.totalWords = current.wordCount;
    this.masteredWords = current.progress.mastered;
    this.learningWords = current.progress.learning;
  }

  private async handleBookClick(id: string): Promise<void> {
    if (this.isNavigating) {
      return;
    }

    const book = [...this.systemBooks, ...this.userBooks].find(b => b.id === id);
    if (!book) {
      return;
    }

    this.isNavigating = true;
    await this.setCurrentBook(id);
    try {
      await router.pushUrl({
        url: 'pages/WordList',
        params: {
          bookId: book.id,
          bookName: book.name,
          bookType: book.isUserBook ? 'user' : 'system'
        }
      });
    } catch (e) {
      console.error('[WordBookManager] Navigation failed:', e);
    } finally {
      setTimeout(() => {
        this.isNavigating = false;
      }, 500);
    }
  }

  private async handleImport(id: string, action: string): Promise<void> {
    if (action === 'import') {
      const def = BuiltInWordBooks.find(b => b.id === id);
      if (def) {
        this.isLoading = true;
        try {
          if (this.resourceMgr === null) {
            promptAction.showToast({ message: '导入失败：资源管理器不可用' });
            return;
          }
          const words = await buildWordItemsForBook(def, this.resourceMgr);
          let inserted = 0;
          for (const w of words) {
             const rowId = await this.dbManager.insertWord(w);
             if (rowId > 0) inserted++;
             await this.dbManager.addWordToSystemWordBook(def.id, w.word);
          }
          promptAction.showToast({ message: `成功导入 ${inserted} 个单词` });
          await this.loadData();
        } catch (e) {
          promptAction.showToast({ message: '导入失败: ' + (e instanceof Error ? e.message : String(e)) });
        } finally {
          this.isLoading = false;
        }
      }
    }
  }

  private async setCurrentBook(id: string): Promise<void> {
    this.currentBookId = id;
    AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, id);
    const store = CurrentBookStore.getInstance();
    if (this.context === null) {
      return;
    }
    store.injectContext(this.context);
    await store.setCurrentBookId(id);
    
    this.systemBooks = this.systemBooks.map(b => this.withCurrentFlag(b, id));
    this.userBooks = this.userBooks.map(b => this.withCurrentFlag(b, id));
    this.calculateGlobalStats();
  }

  private getDefaultDailyGoal(wordCount: number): number {
    if (wordCount <= 200) return 20;
    if (wordCount <= 1000) return 40;
    if (wordCount <= 3000) return 60;
    return 80;
  }

  private getEstimatedDays(wordCount: number, dailyGoal: number): number {
    const safeGoal = Math.max(1, dailyGoal);
    return Math.max(1, Math.ceil(wordCount / safeGoal));
  }

  private buildSourceLabel(source: string, license: string): string {
    const src = source.length > 0 ? source : 'Builtin';
    const lic = license.length > 0 ? license : 'MIT';
    return `${src} · ${lic}`;
  }

  build(): void {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .onClick(() => router.back())

        Text('词书管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .margin({ left: 16 })

        Blank()

        Button('导入词书')
          .type(ButtonType.Normal)
          .height(32)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(DesignTokens.Colors.PRIMARY)
          .borderRadius(12)
          .onClick(() => router.pushUrl({ url: 'pages/ImportPage' }))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(DesignTokens.Colors.BACKGROUND_PRIMARY)

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48).color(DesignTokens.Colors.PRIMARY)
          Text('加载中...').fontSize(14).fontColor(DesignTokens.Colors.GRAY_500).margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadErrorMessage.length > 0) {
        Column() {
          Text('加载失败')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.GRAY_900)
          Text(this.loadErrorMessage)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ top: 6 })
          Button('重试')
            .type(ButtonType.Normal)
            .backgroundColor(DesignTokens.Colors.PRIMARY)
            .fontColor(Color.White)
            .borderRadius(12)
            .height(36)
            .margin({ top: 16 })
            .onClick(() => this.loadData())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.buildSummaryCard()

            if (this.currentBookId.length > 0) {
              this.buildSection('当前正在学习',
                [...this.systemBooks, ...this.userBooks].filter(b => b.id === this.currentBookId)
              )
            }

            if (this.userBooks.length > 0) {
              this.buildSection('我的词书', this.userBooks.filter(b => b.id !== this.currentBookId))
            }

            this.buildSection('系统词书', this.systemBooks.filter(b => b.id !== this.currentBookId))

            Blank().height(32)
          }
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignTokens.Colors.BACKGROUND_PRIMARY)
  }

  @Builder
  private buildSummaryCard(): void {
    Column() {
      Row() {
        this.buildSummaryItem('总词数', this.totalWords, DesignTokens.Colors.PRIMARY)
        this.buildSummaryItem('已掌握', this.masteredWords, DesignTokens.Colors.SUCCESS)
        this.buildSummaryItem('学习中', this.learningWords, DesignTokens.Colors.WARNING)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({ width: 1, color: DesignTokens.Colors.BORDER_LIGHT })
    .margin({ top: 16, bottom: 12 })
    .margin({ bottom: 12 })
  }

  @Builder
  private buildSummaryItem(label: string, value: number, color: ResourceColor): void {
    Column() {
      Text(value.toString())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .width('33%')
  }

  @Builder
  buildSection(title: string, books: BookCardData[]): void {
    if (books.length > 0) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .width('100%')
        .margin({ bottom: 12, top: 8 })
      List({ space: 12 }) {
        ForEach(books, (book: BookCardData) => {
          ListItem() {
            BookCard({
              bookId: book.id,
              name: book.name,
              description: book.description ?? '',
              wordCount: book.wordCount,
              difficulty: book.difficulty,
              category: book.category,
              progressMastered: book.progress.mastered,
              progressLearning: book.progress.learning,
              progressNewWords: book.progress.newWords,
              estimatedDays: book.estimatedDays,
              dailyGoal: book.dailyGoal,
              sourceLabel: book.sourceLabel,
              isCurrent: book.isCurrent,
              isImported: book.isImported,
              isUserBook: book.isUserBook,
              onClickBook: (id: string): void => { this.handleBookClick(id); },
              onAction: (id: string, action: string): void => { this.handleImport(id, action); }
            })
          }
        }, (book: BookCardData) => book.id)
      }
    }
  }

  private withCurrentFlag(book: BookCardData, currentId: string): BookCardData {
    const updated: BookCardData = {
      id: book.id,
      name: book.name,
      description: book.description,
      wordCount: book.wordCount,
      difficulty: book.difficulty,
      category: book.category,
      progress: book.progress,
      estimatedDays: book.estimatedDays,
      dailyGoal: book.dailyGoal,
      sourceLabel: book.sourceLabel,
      isCurrent: book.id === currentId,
      isImported: book.isImported,
      isUserBook: book.isUserBook
    };
    return updated;
  }

  private async getBuiltInWordCount(book: WordBookDefinition): Promise<number> {
    const cached = this.systemBookCountCache.get(book.id);
    if (cached !== undefined) {
      return cached;
    }
    if (this.resourceMgr === null) {
      return book.wordCount;
    }
    try {
      const words = await loadWordBookWords(this.resourceMgr, book);
      const count = words.length > 0 ? words.length : book.wordCount;
      this.systemBookCountCache.set(book.id, count);
      return count;
    } catch (e) {
      return book.wordCount;
    }
  }

  private buildBookProgress(base: BookProgress, newWords: number): BookProgress {
    return new BookProgress(base.mastered, base.learning, newWords);
  }
}
