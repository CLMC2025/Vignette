import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';

import { DBManager } from '../database/DBManager';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { WordItem, WordMeaning, WordStatus, FSRSState, ReviewHistory, WordDefinition } from '../model/WordModel';
import resourceManager from '@ohos.resourceManager';
import { BuiltInWordBooks, buildWordItemsForBook, loadWordBookWords, WordBookDefinition } from '../model/WordBookCatalog';
import { WordDetailCache } from '../utils/WordDetailCache';
import { CurrentBookStore } from '../utils/CurrentBookStore';

interface WordListParams {
  bookId?: string;
  bookName?: string;
  bookType?: string;
  setAsCurrent?: boolean;
}

type SortType = 'default' | 'alphabet' | 'status' | 'time';
type SortDirection = 'asc' | 'desc';
type StatusFilter = '全部' | '新词' | '学习中' | '已掌握';

class WordListDataSource implements IDataSource {
  private items: WordItem[] = [];
  private listener: DataChangeListener | null = null;

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): WordItem {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listener = listener;
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    if (this.listener === listener) {
      this.listener = null;
    }
  }

  updateData(items: WordItem[]): void {
    this.items = items;
    if (this.listener !== null) {
      this.listener.onDataReloaded();
    }
  }
}

@Entry
@Component
struct WordList {
  @State private isLoading: boolean = true;
  @State private isPageLoading: boolean = false;
  @State private loadErrorMessage: string = '';
  @State private bookId: string = '';
  @State private bookName: string = '词表';
  @State private bookType: string = 'system';
  @State private totalCount: number = 0;
  @State private searchText: string = '';
  @State private items: WordItem[] = [];
  @State private filtered: WordItem[] = [];
  @State private hasMore: boolean = true;
  @State private sortType: SortType = 'default';
  @State private sortDirection: SortDirection = 'asc';
  @State private selectedStatus: StatusFilter = '全部';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  private readonly pageSize: number = 50;
  private pageOffset: number = 0;
  private listSource: WordListDataSource = new WordListDataSource();
  private useResourceWords: boolean = false;
  private resourceWords: WordItem[] = [];
  private resourceWordsSorted: WordItem[] = [];

  private readonly statusFilters: StatusFilter[] = ['全部', '新词', '学习中', '已掌握'];

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.init();
  }

  private async init(): Promise<void> {
    this.isLoading = true;
    this.loadErrorMessage = '';
    try {
      if (this.context !== null) {
        await this.dbManager.initialize(this.context);
        this.resourceMgr = this.context.resourceManager;
      }
      const params = router.getParams() as WordListParams;
      this.bookId = String(params?.bookId ?? '');
      this.bookName = String(params?.bookName ?? '词表');
      this.bookType = String(params?.bookType ?? 'system');
      const setAsCurrent = Boolean(params?.setAsCurrent);
      if (setAsCurrent && this.bookId.trim().length > 0) {
        AppStorage.setOrCreate('current_book_id', this.bookId);
        if (this.context !== null) {
          const store = CurrentBookStore.getInstance();
          store.injectContext(this.context);
          void store.setCurrentBookId(this.bookId);
        }
      }
      if (this.bookType === 'system') {
        await this.prepareSystemBookSource();
      }
      await this.loadHeaderCount();
      await this.resetAndLoad();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加载失败：${errMsg}`, duration: 2000 });
      this.loadErrorMessage = errMsg;
    } finally {
      this.isLoading = false;
    }
  }

  private async prepareSystemBookSource(): Promise<void> {
    if (this.bookId.trim().length === 0) {
      return;
    }
    const def = BuiltInWordBooks.find((b: WordBookDefinition) => b.id === this.bookId);
    if (!def) {
      return;
    }
    if (this.resourceMgr === null) {
      return;
    }
    
    // 直接从 rawfile 加载单词列表，不导入数据库
    const words = await loadWordBookWords(this.resourceMgr, def);
    if (words.length > 0) {
      this.useResourceWords = true;
      this.resourceWords = words.map((w: string): WordItem => {
        return new WordItem(
          0,
          w,
          WordStatus.NEW,
          new FSRSState(),
          new ReviewHistory(),
          new WordDefinition(w, '', '', '', [], 'builtin'),
          Date.now(),
          Date.now(),
          Date.now(),
          def.id,
          def.tags
        );
      });
      this.resourceWordsSorted = [...this.resourceWords];
    }
  }

  private async importSystemBook(def: WordBookDefinition, words: WordItem[]): Promise<void> {
    promptAction.showToast({ message: `正在导入${def.name}...`, duration: 2000 });

    let successCount = 0;
    for (const w of words) {
      try {
        await this.dbManager.insertWord(w);
        await this.dbManager.addWordToSystemWordBook(def.id, w.word);
        successCount++;
      } catch (e) {
        console.warn(`[WordList] Failed to import word: ${w.word}`, e);
      }
    }

    promptAction.showToast({ message: `成功导入 ${successCount} 个单词`, duration: 2000 });
  }

  private async loadHeaderCount(): Promise<void> {
    if (this.bookId.trim().length === 0) {
      this.totalCount = 0;
      return;
    }
    if (this.bookType === 'user') {
      this.totalCount = await this.dbManager.getUserWordBookWordCount(this.bookId);
      return;
    }
    if (this.useResourceWords) {
      this.totalCount = this.resourceWords.length;
      return;
    }
    this.totalCount = await this.dbManager.getSystemWordBookWordCount(this.bookId);
  }

  private async resetAndLoad(): Promise<void> {
    this.items = [];
    this.filtered = [];
    this.pageOffset = 0;
    this.hasMore = true;
    this.listSource.updateData([]);
    if (this.useResourceWords) {
      this.resourceWordsSorted = this.sortWords(this.resourceWords, this.sortType, this.sortDirection);
    }
    await this.loadNextPage();
  }

  private async loadNextPage(): Promise<void> {
    if (this.isPageLoading || !this.hasMore) {
      return;
    }
    this.isPageLoading = true;
    try {
      let page: WordItem[] = [];
      if (this.bookType === 'user') {
        page = await this.dbManager.getUserWordBookWordsPaged(this.bookId, this.pageSize, this.pageOffset, this.sortType, this.sortDirection);
      } else if (!this.useResourceWords) {
        page = await this.dbManager.getSystemWordBookWordsPaged(this.bookId, this.pageSize, this.pageOffset, this.sortType, this.sortDirection);
      } else {
        const start = this.pageOffset;
        const end = Math.min(start + this.pageSize, this.resourceWordsSorted.length);
        page = this.resourceWordsSorted.slice(start, end);
      }
      if (page.length < this.pageSize) {
        this.hasMore = false;
      }
      this.pageOffset = this.pageOffset + page.length;
      this.items = this.items.concat(page);
      this.applyFilter();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加载失败：${errMsg}`, duration: 2000 });
    } finally {
      this.isPageLoading = false;
    }
  }

  private applyFilter(): void {
    const keyword = this.searchText.trim().toLowerCase();
    let result: WordItem[] = [];

    result = this.items.filter((w: WordItem) => {
      if (this.selectedStatus !== '全部') {
        const statusMatch = this.matchStatusFilter(w.status);
        if (!statusMatch) {
          return false;
        }
      }

      if (keyword.length > 0) {
        if (w.word.toLowerCase().includes(keyword)) {
          return true;
        }
        return this.getWordMeaningTextForSearch(w).toLowerCase().includes(keyword);
      }
      return true;
    });

    this.filtered = this.sortWords(result, this.sortType, this.sortDirection);
    this.listSource.updateData(this.filtered);
  }

  private matchStatusFilter(status: WordStatus): boolean {
    switch (this.selectedStatus) {
      case '新词':
        return status === WordStatus.NEW;
      case '学习中':
        return status === WordStatus.LEARNING || status === WordStatus.REVIEW || status === WordStatus.RELEARNING;
      case '已掌握':
        return status === WordStatus.KNOWN;
      default:
        return true;
    }
  }

  private getStatusSortWeight(status: WordStatus): number {
    switch (status) {
      case WordStatus.NEW:
        return 0;
      case WordStatus.LEARNING:
        return 1;
      case WordStatus.RELEARNING:
        return 2;
      case WordStatus.REVIEW:
        return 3;
      case WordStatus.KNOWN:
        return 4;
      default:
        return 99;
    }
  }

  private sortWords(words: WordItem[], sort: SortType, direction: SortDirection): WordItem[] {
    const sorted = [...words];
    if (sort === 'alphabet') {
      sorted.sort((a: WordItem, b: WordItem) => a.word.localeCompare(b.word));
      if (direction === 'desc') {
        sorted.reverse();
      }
      return sorted;
    }
    if (sort === 'status') {
      sorted.sort((a: WordItem, b: WordItem) => {
        const wa = this.getStatusSortWeight(a.status);
        const wb = this.getStatusSortWeight(b.status);
        if (wa !== wb) {
          return wa - wb;
        }
        return a.word.localeCompare(b.word);
      });
      if (direction === 'desc') {
        sorted.reverse();
      }
      return sorted;
    }
    if (sort === 'time') {
      sorted.sort((a: WordItem, b: WordItem) => a.createdAt - b.createdAt);
      if (direction === 'desc') {
        sorted.reverse();
      }
      return sorted;
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
    return '暂无释义';
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW:
        return '';
      case WordStatus.LEARNING:
        return '学习中';
      case WordStatus.REVIEW:
        return '复习';
      case WordStatus.RELEARNING:
        return '重学';
      case WordStatus.KNOWN:
        return '已掌握';
      default:
        return '';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.LEARNING:
        return this.colors.WARNING;
      case WordStatus.REVIEW:
        return this.colors.PRIMARY;
      case WordStatus.RELEARNING:
        return this.colors.ERROR;
      case WordStatus.KNOWN:
        return this.colors.SUCCESS;
      default:
        return this.colors.GRAY_400;
    }
  }

  private getStatusBgColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.LEARNING:
        return this.colors.WARNING_LIGHTEST;
      case WordStatus.REVIEW:
        return this.colors.PRIMARY_LIGHTEST;
      case WordStatus.RELEARNING:
        return this.colors.ERROR_LIGHTEST;
      case WordStatus.KNOWN:
        return this.colors.SUCCESS_LIGHTEST;
      default:
        return this.colors.GRAY_100;
    }
  }

  private openWordDetail(word: WordItem): void {
    WordDetailCache.getInstance().set(word);
    router.pushUrl({ url: 'pages/WordDetailPage', params: { wordId: word.id, wordText: word.word } });
  }

  private getSortDisplayText(): string {
    switch (this.sortType) {
      case 'alphabet':
        return '字母';
      case 'status':
        return '状态';
      case 'time':
        return '时间';
      default:
        return '默认';
    }
  }

  private applySortType(value: string): void {
    let nextType: SortType = 'default';
    if (value === '字母') nextType = 'alphabet';
    else if (value === '状态') nextType = 'status';
    else if (value === '时间') nextType = 'time';

    this.sortType = nextType;
    if (nextType === 'time') {
      this.sortDirection = 'desc';
    } else {
      this.sortDirection = 'asc';
    }
    void this.resetAndLoad();
  }

  private toggleSortDirection(): void {
    this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    void this.resetAndLoad();
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

        Text(this.bookName)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.GRAY_900)
          .layoutWeight(1)
          .margin({ left: 8 });

        Text(`${this.totalCount}`)
          .fontSize(14)
          .fontColor(this.colors.GRAY_500);
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 16 })
      .backgroundColor(this.colors.BACKGROUND_PRIMARY);

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.colors.GRAY_400);
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else if (this.loadErrorMessage.length > 0) {
        Column() {
          Text('加载失败')
            .fontSize(16)
            .fontColor(this.colors.GRAY_600);
          Text('重试')
            .fontSize(14)
            .fontColor(this.colors.PRIMARY)
            .margin({ top: 12 })
            .onClick(() => void this.init());
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        Column() {
          Row() {
            TextInput({ text: this.searchText, placeholder: '搜索' })
              .layoutWeight(1)
              .height(36)
              .fontSize(14)
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(8)
              .onChange((value: string) => {
                this.searchText = value;
                this.applyFilter();
              });

            if (this.searchText.length > 0) {
              Text('✕')
                .fontSize(14)
                .fontColor(this.colors.GRAY_500)
                .margin({ left: 8 })
                .onClick(() => {
                  this.searchText = '';
                  this.applyFilter();
                });
            }
          }
          .width('100%')
          .margin({ top: 8 });

          Row() {
            ForEach(this.statusFilters, (status: StatusFilter) => {
              Text(status)
                .fontSize(13)
                .fontColor(this.selectedStatus === status ? this.colors.PRIMARY : this.colors.GRAY_600)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.selectedStatus = status;
                  this.applyFilter();
                });
            }, (status: StatusFilter) => status)
          }
          .width('100%')
          .margin({ top: 8 });

          Row() {
            Text('排序')
              .fontSize(13)
              .fontColor(this.colors.GRAY_600)
              .margin({ right: 8 });

            Select([{ value: '默认' }, { value: '字母' }, { value: '状态' }, { value: '时间' }])
              .value(this.getSortDisplayText())
              .font({ size: 13 })
              .height(34)
              .onSelect((_: number, value: string) => {
                this.applySortType(value);
              });

            if (this.sortType === 'alphabet' || this.sortType === 'time' || this.sortType === 'status') {
              Text(this.sortDirection === 'asc' ? '↑' : '↓')
                .fontSize(14)
                .fontColor(this.colors.GRAY_600)
                .margin({ left: 10 })
                .padding(6)
                .onClick(() => this.toggleSortDirection());
            }
          }
          .width('100%')
          .margin({ top: 8 });

          if (this.filtered.length === 0) {
            Column() {
              Text('没有找到单词')
                .fontSize(15)
                .fontColor(this.colors.GRAY_500);
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center);
          } else {
            List() {
              LazyForEach(this.listSource, (word: WordItem, index: number) => {
                ListItem() {
                  Column() {
                    Row() {
                      Column() {
                        Text(word.word)
                          .fontSize(17)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.colors.TEXT_PRIMARY);

                        // 系统词书不显示释义（避免加载慢）
                        if (!this.useResourceWords) {
                          Text(this.getWordMeaningTextForDisplay(word))
                            .fontSize(13)
                            .fontColor(this.colors.TEXT_SECONDARY)
                            .margin({ top: 6 })
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis });
                        }
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start);

                      if (word.status !== WordStatus.NEW) {
                        Text(this.getStatusText(word.status))
                          .fontSize(12)
                          .fontColor(this.colors.TEXT_TERTIARY);
                      }
                    }
                    .width('100%')
                    .padding({ top: 16, bottom: 16 });

                    if (index < this.filtered.length - 1) {
                      Divider()
                        .color(this.colors.GRAY_200)
                        .margin({ left: 0, right: 0 });
                    }
                  }
                  .width('100%')
                  .onClick(() => this.openWordDetail(word));
                }
              }, (word: WordItem) => word.word)

              if (this.isPageLoading) {
                ListItem() {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color(this.colors.GRAY_400);
                }
              } else if (!this.hasMore && this.filtered.length > 0) {
                ListItem() {
                  Text('— 到底了 —')
                    .fontSize(12)
                    .fontColor(this.colors.GRAY_400)
                    .padding({ top: 16, bottom: 16 })
                    .width('100%')
                    .textAlign(TextAlign.Center);
                }
              }
            }
            .layoutWeight(1)
            .width('100%')
            .margin({ top: 8 })
            .scrollBar(BarState.Off)
            .onReachEnd(() => void this.loadNextPage());
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 });
      }
    }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_SECONDARY);
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart);
  }
}
