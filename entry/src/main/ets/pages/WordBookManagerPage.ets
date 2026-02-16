import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import resourceManager from '@ohos.resourceManager';
import { DBManager } from '../database/DBManager';
import { BuiltInWordBooks, WordBookDefinition, BookProgress } from '../model/WordBookCatalog';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { CurrentBookStore } from '../utils/CurrentBookStore';
import { BookCard, BookCardData } from '../components/BookCard';
import { WordLevelLoader } from '../manager/WordLevelLoader';

@Entry
@Component
struct WordBookManagerPage {
  @State isLoading: boolean = false;
  @State systemBooks: BookCardData[] = [];
  @State userBooks: BookCardData[] = [];
  @State currentBookId: string = '';
  @StorageProp('current_book_id') @Watch('onCurrentBookIdChange') currentBookIdToken: string = '';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State loadErrorMessage: string = '';
  @State searchText: string = '';
  @State showSearchInput: boolean = false;

  @State showCreateBook: boolean = false;
  @State newBookName: string = '';
  @State newBookCategory: string = '其他';
  @State newBookCategoryTag: string = '';
  @State newBookDifficulty: string = '初级';
  @State isCreatingBook: boolean = false;

  @State showSwitchDialog: boolean = false;
  @State pendingSwitchBookId: string = '';
  @State pendingSwitchBookName: string = '';
  @State switchMode: 'keep' | 'reset' = 'keep';
  @State isSwitching: boolean = false;

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  private systemBookCountCache: Map<string, number> = new Map<string, number>();
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';
  private isNavigating: boolean = false;
  private isDataLoaded: boolean = false;
  private readonly DEFAULT_BOOK_COVER: string = JSON.stringify(['#a8edea', '#fed6e3']);

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext | null;
    this.context = ctx;
    this.resourceMgr = ctx ? ctx.resourceManager : null;
    console.log('[WordBookManager] aboutToAppear, isDataLoaded:', this.isDataLoaded);
    void this.loadData();
  }

  onPageShow(): void {
    if (this.isDataLoaded && !this.isLoading) {
      void this.loadData();
    }
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private onCurrentBookIdChange(): void {
    const v = this.currentBookIdToken ?? '';
    if (typeof v === 'string' && v.length > 0 && v !== this.currentBookId) {
      this.currentBookId = v;
    }
  }

  private async loadData(force: boolean = false): Promise<void> {
    if (this.isLoading && !force) {
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
          category: b.category ?? '其他',
          difficulty: b.difficulty ?? '初级',
          progress: progress,
          estimatedDays,
          dailyGoal,
          sourceLabel: '自建词书',
          isCurrent: b.id === this.currentBookId,
          isImported: true,
          isUserBook: true,
          coverColor: b.coverColor ? JSON.parse(b.coverColor) : undefined,
          icon: b.icon || '📓'
        };
        userBookCards.push(card);
      }
      this.userBooks = userBookCards;
      console.log('[WordBookManager] User books loaded');

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
          category: b.category as string,
          difficulty: b.difficulty as string,
          progress: this.buildBookProgress(progress, isImported ? progress.newWords : displayCount),
          estimatedDays: b.estimatedDays,
          dailyGoal: b.dailyGoal,
          sourceLabel: this.buildSourceLabel(b.source),
          isCurrent: b.id === this.currentBookId,
          isImported: isImported,
          isUserBook: false,
          coverColor: b.coverColor,
          icon: b.icon
        };
        sysBookCards.push(card);
      }
      this.systemBooks = sysBookCards;
      console.log('[WordBookManager] System books loaded:', sysBookCards.length);

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

  private getFilteredBooks(): BookCardData[] {
    let allBooks = [...this.userBooks, ...this.systemBooks];
    
    if (this.searchText.trim().length > 0) {
      const keyword = this.searchText.trim().toLowerCase();
      allBooks = allBooks.filter(b => 
        b.name.toLowerCase().includes(keyword) ||
        (b.description ?? '').toLowerCase().includes(keyword)
      );
    }
    
    return allBooks;
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

  private async handleBookAction(id: string, action: string): Promise<void> {
    if (this.isNavigating) {
      return;
    }
    if (action !== 'learn') {
      return;
    }
    
    const targetBook = [...this.systemBooks, ...this.userBooks].find(b => b.id === id);
    const bookName = targetBook ? targetBook.name : id;
    
    if (id === this.currentBookId) {
      promptAction.showToast({ message: '已经是当前词书', duration: 1500 });
      return;
    }
    
    this.pendingSwitchBookId = id;
    this.pendingSwitchBookName = bookName;
    this.switchMode = 'keep';
    this.showSwitchDialog = true;
  }

  private async confirmSwitch(): Promise<void> {
    if (this.isSwitching) {
      return;
    }
    this.isSwitching = true;
    
    try {
      await this.setCurrentBook(this.pendingSwitchBookId, this.switchMode === 'reset');
      this.showSwitchDialog = false;
      promptAction.showToast({ 
        message: this.switchMode === 'keep' ? '已切换词书，学习记录已保留' : '已切换词书，学习记录已重置', 
        duration: 1500 
      });
    } catch (e) {
      const errText = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `切换失败：${errText}`, duration: 2000 });
    } finally {
      this.isSwitching = false;
    }
  }

  private cancelSwitch(): void {
    this.showSwitchDialog = false;
    this.pendingSwitchBookId = '';
    this.pendingSwitchBookName = '';
  }

  private async setCurrentBook(id: string, resetProgress: boolean = false): Promise<void> {
    this.currentBookId = id;
    AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, id);
    const store = CurrentBookStore.getInstance();
    if (this.context === null) {
      return;
    }
    store.injectContext(this.context);
    await store.setCurrentBookId(id);
    
    if (resetProgress) {
      await this.dbManager.initialize(this.context);
      await this.dbManager.resetBookProgress(id);
    }
    
    this.systemBooks = this.systemBooks.map(b => this.withCurrentFlag(b, id));
    this.userBooks = this.userBooks.map(b => this.withCurrentFlag(b, id));
    AppStorage.setOrCreate('home_refresh_token', Date.now());
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

  private buildSourceLabel(source: string): string {
    return source.length > 0 ? source : 'Builtin';
  }

  private openCreateBook(): void {
    this.newBookName = '';
    this.newBookCategory = '其他';
    this.newBookCategoryTag = '';
    this.newBookDifficulty = 'CET-4';
    this.showCreateBook = true;
  }

  private async createBook(): Promise<void> {
    if (this.isCreatingBook) {
      return;
    }
    const name = this.newBookName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入词书名称', duration: 1500 });
      return;
    }
    if (name.length > 20) {
      promptAction.showToast({ message: '词书名称不能超过20个字符', duration: 1500 });
      return;
    }
    if (this.context === null) {
      promptAction.showToast({ message: '上下文初始化失败', duration: 1500 });
      return;
    }
    const normalizedTag = this.newBookCategoryTag.trim();
    const category = this.newBookCategory === '自定义'
      ? (normalizedTag.length > 0 ? normalizedTag : '其他')
      : (this.newBookCategory === '其他' && normalizedTag.length > 0 ? normalizedTag : this.newBookCategory);
    this.isCreatingBook = true;
    try {
      await this.dbManager.initialize(this.context);
      await this.dbManager.createUserWordBook(
        name,
        '用户自定义词书',
        category,
        this.newBookDifficulty,
        this.DEFAULT_BOOK_COVER,
        '📓'
      );
      this.showCreateBook = false;
      await this.loadData(true);
      promptAction.showToast({ message: '创建成功', duration: 1500 });
    } catch (e) {
      const errText = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `创建失败：${errText}`, duration: 2000 });
    } finally {
      this.isCreatingBook = false;
    }
  }

  private navigateToImport(): void {
    void router.pushUrl({ url: 'pages/ImportPage' });
  }

  @Builder
  private buildCreateBookOverlay(): void {
    if (this.showCreateBook) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.35)')
          .onClick(() => {
            if (!this.isCreatingBook) this.showCreateBook = false;
          });

        Column({ space: 12 }) {
          Text('创建词书')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.GRAY_900);

          TextInput({ text: this.newBookName, placeholder: '词书名称（最多20字）' })
            .width('100%')
            .height(40)
            .fontSize(14)
            .backgroundColor(this.colors.GRAY_100)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .maxLength(20)
            .onChange((value: string) => {
              this.newBookName = value;
            });

          Row() {
            Text('分类')
              .fontSize(13)
              .fontColor(this.colors.GRAY_600)
              .margin({ right: 8 });
            Select([{ value: '其他' }, { value: '自定义' }, { value: '考试' }, { value: '学术' }, { value: '商务' }, { value: '旅游' }, { value: '日常' }])
              .value(this.newBookCategory)
              .font({ size: 13 })
              .height(34)
              .onSelect((_: number, value: string) => {
                this.newBookCategory = value;
              });

            Blank();

            Text('难度')
              .fontSize(13)
              .fontColor(this.colors.GRAY_600)
              .margin({ right: 8 });
            Select([
              { value: 'CET-4' },
              { value: 'CET-6' },
              { value: '考研' },
              { value: 'IELTS' },
              { value: 'TOEFL' },
              { value: 'GRE' },
              { value: 'TEM-4' },
              { value: 'TEM-8' }
            ])
              .value(this.newBookDifficulty)
              .font({ size: 13 })
              .height(34)
              .onSelect((_: number, value: string) => {
                this.newBookDifficulty = value;
              });
          }
          .width('100%');

          if (this.newBookCategory === '自定义' || this.newBookCategory === '其他') {
            Row() {
              Text(this.newBookCategory === '自定义' ? '自定义分类' : '标签')
                .fontSize(13)
                .fontColor(this.colors.GRAY_600)
                .margin({ right: 8 });

              TextInput({ text: this.newBookCategoryTag, placeholder: this.newBookCategory === '自定义' ? '请输入分类（如：四级、托福）' : '可选：输入标签（如：科技、口语）' })
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .backgroundColor(this.colors.GRAY_100)
                .borderRadius(8)
                .padding({ left: 12, right: 12 })
                .maxLength(20)
                .onChange((value: string) => {
                  this.newBookCategoryTag = value;
                });
            }
            .width('100%');
          }

          Row() {
            Text('取消')
              .fontSize(14)
              .fontColor(this.colors.GRAY_700)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(8)
              .onClick(() => {
                if (!this.isCreatingBook) this.showCreateBook = false;
              });

            Blank();

            Text(this.isCreatingBook ? '创建中...' : '创建')
              .fontSize(14)
              .fontColor(this.colors.WHITE)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.isCreatingBook ? this.colors.GRAY_400 : this.colors.PRIMARY)
              .borderRadius(8)
              .onClick(() => {
                if (!this.isCreatingBook) void this.createBook();
              });
          }
          .width('100%');
        }
        .width('86%')
        .padding(16)
        .backgroundColor(this.colors.SURFACE_ELEVATED)
        .borderRadius(12);
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private buildSwitchDialog(): void {
    if (this.showSwitchDialog) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.35)')
          .onClick(() => {
            if (!this.isSwitching) this.cancelSwitch();
          });

        Column({ space: 16 }) {
          Text('切换词书')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.GRAY_900);

          Text(`即将切换到「${this.pendingSwitchBookName}」`)
            .fontSize(14)
            .fontColor(this.colors.GRAY_700);

          Column({ space: 12 }) {
            Row() {
              Radio({ value: 'keep', group: 'switchMode' })
                .checked(this.switchMode === 'keep')
                .onChange((isChecked: boolean) => {
                  if (isChecked) this.switchMode = 'keep';
                });
              Column() {
                Text('保留学习记录')
                  .fontSize(14)
                  .fontColor(this.colors.GRAY_900);
                Text('已学过的单词将保留进度')
                  .fontSize(12)
                  .fontColor(this.colors.GRAY_500);
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 8 });
            }
            .width('100%')
            .onClick(() => {
              this.switchMode = 'keep';
            });

            Row() {
              Radio({ value: 'reset', group: 'switchMode' })
                .checked(this.switchMode === 'reset')
                .onChange((isChecked: boolean) => {
                  if (isChecked) this.switchMode = 'reset';
                });
              Column() {
                Text('重新开始')
                  .fontSize(14)
                  .fontColor(this.colors.GRAY_900);
                Text('清除该词书的学习进度')
                  .fontSize(12)
                  .fontColor(this.colors.GRAY_500);
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 8 });
            }
            .width('100%')
            .onClick(() => {
              this.switchMode = 'reset';
            });
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.colors.GRAY_50)
          .borderRadius(8);

          Row() {
            Text('取消')
              .fontSize(14)
              .fontColor(this.colors.GRAY_700)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(8)
              .onClick(() => {
                if (!this.isSwitching) this.cancelSwitch();
              });

            Blank();

            Text(this.isSwitching ? '切换中...' : '确认切换')
              .fontSize(14)
              .fontColor(this.colors.WHITE)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.isSwitching ? this.colors.GRAY_400 : this.colors.PRIMARY)
              .borderRadius(8)
              .onClick(() => {
                if (!this.isSwitching) void this.confirmSwitch();
              });
          }
          .width('100%');
        }
        .width('86%')
        .padding(16)
        .backgroundColor(this.colors.SURFACE_ELEVATED)
        .borderRadius(12);
      }
      .width('100%')
      .height('100%');
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('←')
            .fontSize(24)
            .fontColor(this.colors.GRAY_900)
            .onClick(() => router.back())
            .padding(8);

          Text('词书')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.GRAY_900)
            .layoutWeight(1)
            .margin({ left: 8 });

          Text('＋')
            .fontSize(18)
            .fontColor(this.colors.GRAY_500)
            .onClick(() => this.openCreateBook())
            .padding(8);

          Text('⇪')
            .fontSize(16)
            .fontColor(this.colors.GRAY_500)
            .onClick(() => this.navigateToImport())
            .padding(8);

          if (this.showSearchInput) {
            TextInput({ text: this.searchText, placeholder: '搜索' })
              .width(100)
              .height(32)
              .fontSize(13)
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(8)
              .onChange((value: string) => {
                this.searchText = value;
              });
          } else {
            Text('🔍')
              .fontSize(18)
              .fontColor(this.colors.GRAY_500)
              .onClick(() => {
                this.showSearchInput = true;
              })
              .padding(8);
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 8, right: 8 })
        .backgroundColor(this.colors.BACKGROUND_PRIMARY);

        if (this.isLoading) {
          Column() {
            LoadingProgress().width(32).height(32).color(this.colors.GRAY_400)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.loadErrorMessage.length > 0) {
          Column() {
            Text('加载失败')
              .fontSize(16)
              .fontColor(this.colors.GRAY_600)
            Text(this.loadErrorMessage)
              .fontSize(12)
              .fontColor(this.colors.GRAY_500)
              .margin({ top: 6 })
            Text('重试')
              .fontSize(14)
              .fontColor(this.colors.PRIMARY)
              .margin({ top: 16 })
              .onClick(() => this.loadData())
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.getFilteredBooks(), (book: BookCardData) => {
              ListItem() {
                BookCard({
                  bookId: book.id,
                  name: book.name,
                  description: book.description ?? '',
                  wordCount: book.wordCount,
                  difficulty: book.difficulty ?? '',
                  category: book.category ?? '',
                  progressMastered: book.progress.mastered,
                  progressLearning: book.progress.learning,
                  progressNewWords: book.progress.newWords,
                  estimatedDays: book.estimatedDays,
                  dailyGoal: book.dailyGoal,
                  sourceLabel: book.sourceLabel,
                  isCurrent: book.id === this.currentBookId,
                  isImported: book.isImported,
                  isUserBook: book.isUserBook,
                  coverColor: book.coverColor ? JSON.stringify(book.coverColor) : '',
                  bookIcon: book.icon ?? '📚',
                  onCardClick: (id: string): void => { this.handleBookClick(id); },
                  onActionClick: (id: string, action: string): void => { void this.handleBookAction(id, action); }
                })
              }
            }, (book: BookCardData) => book.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_SECONDARY)
      this.buildCreateBookOverlay();
      this.buildSwitchDialog();
    }
    .width('100%')
    .height('100%')
    .id('wordBookManager_' + this.themeRefreshToken)
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
      isUserBook: book.isUserBook,
      coverColor: book.coverColor,
      icon: book.icon
    };
    return updated;
  }

  private async getBuiltInWordCount(book: WordBookDefinition): Promise<number> {
    const start = Date.now();
    if (book.levelTag && book.levelTag.length > 0) {
      const levelLoader = WordLevelLoader.getInstance();
      const isLoaded = levelLoader.isLoaded();
      console.info(`[WordBookManager] getBuiltInWordCount for ${book.id}: isLoaded=${isLoaded}`);
      if (isLoaded) {
        const words = levelLoader.getWordsByLevel(book.levelTag);
        const elapsed = Date.now() - start;
        console.info(`[WordBookManager] getBuiltInWordCount for ${book.id}: ${words.length} words in ${elapsed}ms`);
        return words.length;
      }
    }
    const elapsed = Date.now() - start;
    console.info(`[WordBookManager] getBuiltInWordCount for ${book.id}: fallback to ${book.wordCount} in ${elapsed}ms`);
    return book.wordCount;
  }

  private buildBookProgress(base: BookProgress, newWords: number): BookProgress {
    return new BookProgress(base.mastered, base.learning, newWords);
  }
}
