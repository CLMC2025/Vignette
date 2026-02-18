// =====================================================
// WordListPage.ets - Word list for a selected book
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import resourceManager from '@ohos.resourceManager';
import { DBManager } from '../database/DBManager';
import { DesignTokens } from '../model/DesignTokens';
import { AppSettings, QueueItem, WordItem, WordMeaning, WordStatus, FSRSState, ReviewHistory, WordDefinition as WordDef } from '../model/WordModel';
import { BuiltInWordBooks, loadWordBookWords } from '../model/WordBookCatalog';
import { AddToBookDialog, AddToBookDialogResult } from '../components/AddToBookDialog';
import { CreateBookDialog, CreateBookDialogResult } from '../components/CreateBookDialog';
import { SessionTransferStore } from '../utils/SessionTransferStore';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

interface SimpleWord {
  word: string;
  status: WordStatus;
}

interface LearningOrderPolicyJson {
  learningOrderPolicy?: string;
}

interface WordListParams {
  bookId?: string;
  bookName?: string;
  bookType?: string;
}

interface RouterParams {
  sessionId: string;
}

type SortType = 'default' | 'alphabet' | 'status' | 'time';

@Entry
@Component
struct WordListPage {
  @State private isLoading: boolean = true;
  @State private loadingMessage: string = '正在加载词书...';
  @State private bookId: string = '';
  @State private bookName: string = '词表';
  @State private bookType: string = 'system';
  @State private searchText: string = '';
  @State private words: WordItem[] = [];
  @State private simpleWords: SimpleWord[] = [];
  @State private displayWords: SimpleWord[] = [];
  @State private currentPage: number = 0;
  @State private pageSize: number = 100;
  @State private hasMore: boolean = false;
  @State private dailyNewWords: number = 10;
  @State private learningOrderPolicy: string = 'due_first';
  @State private sortType: SortType = 'default';
  @State private showSortMenu: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  // Add to book dialog states
  @State private showAddToBookDialog: boolean = false;
  @State private showCreateBookDialog: boolean = false;
  @State private pendingAddWord: WordItem | null = null;
  @State private joinedBookIds: string[] = [];

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';

  aboutToAppear(): void {
    console.info('[WordListPage] aboutToAppear called');
    this.context = getContext(this) as common.UIAbilityContext;
    console.info(`[WordListPage] context = ${this.context ? 'ok' : 'null'}`);
    void this.initialize();
  }

  private async initialize(): Promise<void> {
    const totalStart = Date.now();
    this.isLoading = true;
    console.info('[WordListPage] initialize started');
    try {
      if (this.context !== null) {
        const dbStart = Date.now();
        await this.dbManager.initialize(this.context);
        console.info(`[WordListPage] DB initialized in ${Date.now() - dbStart}ms`);
      }
      await this.loadSettings();
      const params = router.getParams() as WordListParams;
      this.bookId = params?.bookId ?? '';
      this.bookName = params?.bookName ?? '词表';
      this.bookType = params?.bookType ?? 'system';
      console.info(`[WordListPage] Loading book: ${this.bookId}`);
      await this.loadWords();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordListPage] Failed to load words:', errMsg);
    } finally {
      this.isLoading = false;
      console.info(`[WordListPage] initialize completed in ${Date.now() - totalStart}ms`);
    }
  }

  private async loadWords(): Promise<void> {
    const loadStart = Date.now();
    console.info(`[WordListPage] loadWords started: bookType=${this.bookType}, bookId=${this.bookId}`);
    
    // 系统词书直接从 rawfile 加载，避免查询整个数据库
    if (this.bookType === 'system' && this.bookId.length > 0 && this.context !== null) {
      console.info(`[WordListPage] Loading system book from rawfile`);
      this.loadingMessage = '正在加载词书单词...';
      const rawfileWords = await this.loadWordsFromRawfile();
      console.info(`[WordListPage] rawfileWords.length = ${rawfileWords.length}`);
      if (rawfileWords.length > 0) {
        this.simpleWords = rawfileWords.map((w: string): SimpleWord => ({
          word: w,
          status: WordStatus.NEW
        }));
        this.updateDisplayWords();
        console.info(`[WordListPage] loadWords completed in ${Date.now() - loadStart}ms (rawfile path)`);
        return;
      }
    }
    
    // 用户词书查询数据库
    console.info(`[WordListPage] Loading user book from database`);
    this.loadingMessage = '正在查询数据库...';
    const allWords = await this.dbManager.getAllWords();
    let list = this.bookId.length > 0
      ? allWords.filter((item: WordItem) => (item.bookId ?? '') === this.bookId)
      : allWords;
    
    this.words = list;
    this.simpleWords = list.map((item: WordItem): SimpleWord => ({
      word: item.word,
      status: item.status
    }));
    this.updateDisplayWords();
    console.info(`[WordListPage] loadWords completed in ${Date.now() - loadStart}ms (database path)`);
  }

  private async loadWordsFromRawfile(): Promise<string[]> {
    const bookDef = BuiltInWordBooks.find((book) => book.id === this.bookId);
    if (bookDef === undefined) {
      return [];
    }
    const startTime = Date.now();
    console.info(`[WordListPage] Start loading words for book ${this.bookId}`);
    try {
      const resourceMgr = this.context!.resourceManager;
      const words = await loadWordBookWords(resourceMgr, bookDef);
      const elapsed = Date.now() - startTime;
      console.info(`[WordListPage] Loaded ${words.length} words from rawfile for book ${this.bookId} in ${elapsed}ms`);
      return words;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[WordListPage] Failed to load words from rawfile:`, errMsg);
      return [];
    }
  }

  private updateDisplayWords(): void {
    const filtered = this.applyFilterSimple();
    const start = 0;
    const end = Math.min(this.pageSize, filtered.length);
    this.displayWords = filtered.slice(start, end);
    this.hasMore = filtered.length > this.pageSize;
    this.currentPage = 0;
  }

  private loadMoreWords(): void {
    if (!this.hasMore) {
      return;
    }
    const filtered = this.applyFilterSimple();
    const nextPage = this.currentPage + 1;
    const start = nextPage * this.pageSize;
    const end = Math.min(start + this.pageSize, filtered.length);
    
    if (start < filtered.length) {
      const moreWords = filtered.slice(start, end);
      this.displayWords = [...this.displayWords, ...moreWords];
      this.currentPage = nextPage;
      this.hasMore = end < filtered.length;
    }
  }

  private applyFilterSimple(): SimpleWord[] {
    let result = this.simpleWords;
    
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length > 0) {
      result = result.filter((w: SimpleWord) => w.word.toLowerCase().includes(keyword));
    }
    
    return result;
  }

  private applyFilter(): void {
    this.updateDisplayWords();
  }

  private sortWords(words: WordItem[], sort: SortType): WordItem[] {
    const sorted = [...words];
    switch (sort) {
      case 'alphabet':
        sorted.sort((a: WordItem, b: WordItem) => a.word.localeCompare(b.word));
        break;
      case 'status':
        sorted.sort((a: WordItem, b: WordItem) => a.status.localeCompare(b.status));
        break;
      case 'time':
        sorted.sort((a: WordItem, b: WordItem) => b.createdAt - a.createdAt);
        break;
      default:
        // Keep original order
        break;
    }
    return sorted;
  }

  private getWordMeaningTextForSearch(word: WordItem): string {
    const contextMeaning = word.definition?.contextMeaning ?? '';
    const common = word.definition?.commonMeanings ?? [];
    const commonText = common.map((m: WordMeaning) => `${m.pos} ${m.cn}`).join(' ');
    return `${contextMeaning} ${commonText}`.trim();
  }

  private getWordMeaningTextForDisplay(word: WordItem): string {
    const text = this.getWordMeaningTextForSearch(word);
    if (text.length > 0) {
      return text;
    }
    return '暂无释义（点击查看详情）';
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW:
        return '新词';
      case WordStatus.LEARNING:
        return '学习中';
      case WordStatus.REVIEW:
        return '复习';
      case WordStatus.RELEARNING:
        return '重新学习';
      case WordStatus.KNOWN:
        return '已知';
      default:
        return '未知';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW:
        return this.colors.PRIMARY;
      case WordStatus.LEARNING:
        return this.colors.STATUS_LEARNING;
      case WordStatus.REVIEW:
        return this.colors.STATUS_REVIEW;
      case WordStatus.RELEARNING:
        return this.colors.STATUS_RELEARNING;
      case WordStatus.KNOWN:
        return this.colors.SUCCESS;
      default:
        return this.colors.GRAY_500;
    }
  }

  private navigateToWordDetail(word: WordItem): void {
    router.pushUrl({
      url: 'pages/WordDetailPage',
      params: {
        wordId: word.id,
        wordText: word.word
      }
    });
  }

  private getSortLabel(sort: SortType): string {
    switch (sort) {
      case 'alphabet':
        return '按字母';
      case 'status':
        return '按状态';
      case 'time':
        return '按时间';
      default:
        return '默认排序';
    }
  }

  // Add to book functionality
  private openAddToBookDialog(word: WordItem): void {
    this.pendingAddWord = word;
    this.showAddToBookDialog = true;
    this.showCreateBookDialog = false;
    void this.refreshJoinedBooksForDialog(word.word);
  }

  private dismissAddDialogs(): void {
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = false;
    this.pendingAddWord = null;
  }

  private async refreshJoinedBooksForDialog(wordText: string): Promise<void> {
    try {
      const books = await this.dbManager.getUserWordBooksContainingWord(wordText);
      this.joinedBookIds = books.map((b) => b.id);
    } catch (e) {
      console.error('[WordListPage] Failed to refresh joined books:', e);
      this.joinedBookIds = [];
    }
  }

  private handleAddDialogSelect(result: AddToBookDialogResult): void {
    void this.joinPendingWordToBook(result.bookId, result.bookName);
  }

  private handleAddDialogRequestCreate(): void {
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = true;
  }

  private handleCreateBookCancel(): void {
    this.showCreateBookDialog = false;
    if (this.pendingAddWord !== null) {
      this.showAddToBookDialog = true;
    }
  }

  private handleCreateBookSubmit(result: CreateBookDialogResult): void {
    void this.createBookAndJoin(result.name);
  }

  private async createBookAndJoin(bookName: string): Promise<void> {
    if (this.pendingAddWord === null) {
      return;
    }
    try {
      const bookId = await this.dbManager.createUserWordBook(bookName, '', '其他', '初级', '', '📓');
      await this.joinPendingWordToBook(bookId, bookName);
      this.dismissAddDialogs();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `创建词书失败：${errMsg}`, duration: 2000 });
      this.showCreateBookDialog = false;
      this.showAddToBookDialog = true;
    }
  }

  private async joinPendingWordToBook(bookId: string, bookName: string): Promise<void> {
    if (this.pendingAddWord === null) {
      return;
    }
    try {
      await this.dbManager.addWordToUserWordBook(bookId, this.pendingAddWord.word);
      promptAction.showToast({ message: `已加入「${bookName}」`, duration: 1500 });
      this.dismissAddDialogs();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加入失败：${errMsg}`, duration: 2000 });
    }
  }

  private async loadSettings(): Promise<void> {
    const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
    if (settingsJson !== undefined && settingsJson.length > 0) {
      const settings = AppSettings.fromJSON(settingsJson);
      this.dailyNewWords = settings.dailyNewWords;
      this.learningOrderPolicy = this.parseLearningOrderPolicy(settings.toJSON());
    }
  }

  private parseLearningOrderPolicy(settingsJson: string): string {
    try {
      const parsed = JSON.parse(settingsJson) as LearningOrderPolicyJson;
      const v = parsed.learningOrderPolicy;
      if (typeof v === 'string' && v.length > 0) {
        return v;
      }
    } catch (e) { /* JSON 解析失败，使用默认值 */ }
    return 'due_first';
  }

  private interleaveQueue(reviewWords: WordItem[], newWords: WordItem[]): WordItem[] {
    const result: WordItem[] = [];
    const maxLen = Math.max(reviewWords.length, newWords.length);
    for (let i = 0; i < maxLen; i++) {
      const r = reviewWords[i];
      if (r) result.push(r);
      const n = newWords[i];
      if (n) result.push(n);
    }
    return result;
  }

  private shuffleQueue(words: WordItem[]): WordItem[] {
    const out = [...words];
    for (let i = out.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  private applyLearningOrder(words: WordItem[]): WordItem[] {
    if (words.length <= 1) {
      return words;
    }
    const policy = this.learningOrderPolicy;
    if (policy === 'random') {
      return this.shuffleQueue(words);
    }
    if (policy === 'alphabet') {
      const out = [...words];
      out.sort((a: WordItem, b: WordItem) => a.word.localeCompare(b.word));
      return out;
    }
    const newWords = words.filter((w: WordItem) => w.status === WordStatus.NEW);
    const reviewWords = words.filter((w: WordItem) => w.status !== WordStatus.NEW);
    if (policy === 'new_first') {
      return newWords.concat(reviewWords);
    }
    if (policy === 'interleave') {
      return this.interleaveQueue(reviewWords, newWords);
    }
    return words;
  }

  private async startSessionFromBook(): Promise<void> {
    try {
      const words = await this.dbManager.getLearningQueueByBook(this.bookId, this.dailyNewWords);
      const orderedWords = this.applyLearningOrder(words);
      if (words.length === 0) {
        promptAction.showToast({ message: '当前词书暂无可学习单词', duration: 2000 });
        return;
      }
      const queue: QueueItem[] = orderedWords.map((word: WordItem) => {
        const priority = word.status === WordStatus.NEW ? 1 : 0;
        return new QueueItem(word, priority);
      });
      const sessionId = SessionTransferStore.getInstance().put(queue);
      const params: RouterParams = { sessionId: sessionId };
      router.pushUrl({ url: 'pages/ReadPage', params: params });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `无法开始学习：${errMsg}`, duration: 2000 });
    }
  }

  build() {
    Stack() {
      Column() {
        // Header
        Row() {
          Text('←')
            .fontSize(24)
            .fontColor(this.colors.GRAY_900)
            .accessibilityText('返回')
            .onClick(() => router.back());

          Column() {
            Text(this.bookName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.GRAY_900);

            Text(`共 ${this.words.length} 个单词`)
              .fontSize(12)
              .fontColor(this.colors.GRAY_600)
              .margin({ top: 4 });
          }
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start);

          Blank();

          Text('开始学习')
            .fontSize(12)
            .fontColor(this.colors.PRIMARY)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .backgroundColor(this.colors.PRIMARY_LIGHTEST)
            .onClick(() => this.startSessionFromBook());
        }
        .width('100%')
        .height(64)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.colors.BACKGROUND_PRIMARY)

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(this.colors.PRIMARY);

            Text(this.loadingMessage)
              .fontSize(14)
              .fontColor(this.colors.GRAY_500)
              .margin({ top: 12 });
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center);
        } else {
          Scroll() {
            Column() {
              // Search and Sort Row
              Row() {
                Row() {
                  Text('🔍')
                    .fontSize(18)
                    .fontColor(this.colors.GRAY_600);

                  TextInput({ text: this.searchText, placeholder: '搜索单词或释义' })
                    .layoutWeight(1)
                    .height(44)
                    .fontSize(14)
                    .backgroundColor(Color.Transparent)
                    .onChange((value: string) => {
                      this.searchText = value;
                      this.applyFilter();
                    });
                }
                .layoutWeight(1)
                .height(52)
                .padding({ left: 12, right: 12 })
                .backgroundColor(this.colors.BACKGROUND_SECONDARY)
                .borderRadius(DesignTokens.BorderRadius.LG);

                // Sort Button
                Button() {
                  Text(this.getSortLabel(this.sortType))
                    .fontSize(12)
                    .fontColor(this.colors.PRIMARY);
                }
                .type(ButtonType.Normal)
                .height(40)
                .backgroundColor(this.colors.PRIMARY_LIGHTEST)
                .borderRadius(20)
                .margin({ left: 8 })
                .onClick(() => {
                  this.showSortMenu = true;
                });
              }
              .width('100%')
              .margin({ bottom: 16 });

              // Sort Menu
              if (this.showSortMenu) {
                Column() {
                  Row() {
                    Text('排序方式')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.colors.GRAY_700);

                    Blank();

                    Text('✕')
                      .fontSize(16)
                      .fontColor(this.colors.GRAY_500)
                      .onClick(() => {
                        this.showSortMenu = false;
                      });
                  }
                  .width('100%')
                  .margin({ bottom: 8 });

                  Row({ space: 8 }) {
                    this.buildSortChip('default', '默认排序');
                    this.buildSortChip('alphabet', '按字母');
                    this.buildSortChip('status', '按状态');
                    this.buildSortChip('time', '按时间');
                  }
                  .width('100%');
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.colors.SURFACE_PRIMARY)
                .borderRadius(12)
                .margin({ bottom: 12 });
              }

              // Result count
              Row() {
                Text(`共 ${this.simpleWords.length} 个单词`)
                  .fontSize(12)
                  .fontColor(this.colors.GRAY_500);

                Blank();
              }
              .width('100%')
              .margin({ bottom: 8 });

              if (this.displayWords.length === 0) {
                Column() {
                  Text('暂无单词')
                    .fontSize(14)
                    .fontColor(this.colors.GRAY_500);
                }
                .width('100%')
                .padding(DesignTokens.Spacing.XXL)
                .alignItems(HorizontalAlign.Center);
              } else {
                List() {
                  ForEach(this.displayWords, (word: SimpleWord) => {
                    ListItem() {
                      this.buildWordRow(word);
                    }
                  }, (word: SimpleWord) => word.word);
                  
                  if (this.hasMore) {
                    ListItem() {
                      Row() {
                        Text('加载更多')
                          .fontSize(14)
                          .fontColor(this.colors.PRIMARY)
                          .onClick(() => this.loadMoreWords());
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.Center)
                      .padding(16);
                    }
                  }
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 24 });
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off);
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_PRIMARY)

      // Add to book dialogs
      if (this.showAddToBookDialog || this.showCreateBookDialog) {
        this.buildAddToBookFlowDialogs();
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  buildSortChip(sort: SortType, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.sortType === sort ? this.colors.WHITE : this.colors.GRAY_700)
      .backgroundColor(this.sortType === sort ? this.colors.PRIMARY : this.colors.BACKGROUND_SECONDARY)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.sortType = sort;
        this.applyFilter();
        this.showSortMenu = false;
      });
  }

  @Builder
  buildWordRow(word: SimpleWord) {
    Column() {
      Row() {
        Text(word.word)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.GRAY_900)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(this.getStatusText(word.status))
          .fontSize(12)
          .fontColor(this.colors.WHITE)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(this.getStatusColor(word.status))
          .borderRadius(12)
          .margin({ left: 12 });
      }
      .width('100%');
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.colors.SURFACE_ELEVATED)
    .borderRadius(12)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.goToWordDetail(word.word);
    });
  }

  private goToWordDetail(word: string): void {
    router.pushUrl({
      url: 'pages/WordDetail',
      params: { word: word }
    }).catch((err: Error) => {
      console.error('[WordListPage] Navigation failed:', err.message);
    });
  }

  @Builder
  buildAddToBookFlowDialogs() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.colors.BLACK)
        .opacity(0.45)
        .onClick(() => this.dismissAddDialogs());

      if (this.showAddToBookDialog) {
        Column() {
          AddToBookDialog({
            visible: this.showAddToBookDialog,
            word: this.pendingAddWord,
            joinedBookIds: this.joinedBookIds,
            onDismiss: () => this.dismissAddDialogs(),
            onSelectBook: (result: AddToBookDialogResult) => this.handleAddDialogSelect(result),
            onRequestCreateBook: () => this.handleAddDialogRequestCreate()
          });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      }

      if (this.showCreateBookDialog) {
        Column() {
          CreateBookDialog({
            visible: this.showCreateBookDialog,
            onCancel: () => this.handleCreateBookCancel(),
            onCreate: (result: CreateBookDialogResult) => this.handleCreateBookSubmit(result)
          });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      }
    }
    .width('100%')
    .height('100%')
    .id('wordList_' + this.themeRefreshToken)
  }
}
