import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';

import { DBManager } from '../database/DBManager';
import { DesignTokens } from '../model/DesignTokens';
import { WordItem, WordMeaning, WordStatus } from '../model/WordModel';
import resourceManager from '@ohos.resourceManager';
import { BuiltInWordBooks, buildWordItemsForBook, loadWordBookWords, WordBookDefinition } from '../model/WordBookCatalog';
import { WordDetailCache } from '../utils/WordDetailCache';
import { CurrentBookStore } from '../utils/CurrentBookStore';

interface WordListParams {
  bookId?: string;
  bookName?: string;
  bookType?: string;
}

type SortType = 'default' | 'alphabet' | 'status' | 'time';

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
  @State private loadingHint: string = '加载中...';
  @State private isPageLoading: boolean = false;
  @State private loadErrorMessage: string = '';
  @State private loadMoreErrorMessage: string = '';
  @State private bookId: string = '';
  @State private bookName: string = '词表';
  @State private bookType: string = 'system';
  @State private totalCount: number = 0;
  @State private searchText: string = '';
  @State private items: WordItem[] = [];
  @State private filtered: WordItem[] = [];
  @State private hasMore: boolean = true;
  @State private sortType: SortType = 'default';
  @StorageProp('CurrentThemeId') currentThemeId: string = 'light';

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  private readonly pageSize: number = 50;
  private pageOffset: number = 0;
  private listSource: WordListDataSource = new WordListDataSource();
  private useResourceWords: boolean = false;
  private resourceWords: WordItem[] = [];

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.init();
  }

  private async init(): Promise<void> {
    this.isLoading = true;
    this.loadingHint = '加载中...';
    this.loadErrorMessage = '';
    this.loadMoreErrorMessage = '';
    try {
      if (this.context !== null) {
        await this.dbManager.initialize(this.context);
        this.resourceMgr = this.context.resourceManager;
      }
      const params = router.getParams() as WordListParams;
      this.bookId = String(params?.bookId ?? '');
      this.bookName = String(params?.bookName ?? '词表');
      this.bookType = String(params?.bookType ?? 'system');
      if (this.bookId.trim().length > 0) {
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
    const fileWords = await loadWordBookWords(this.resourceMgr, def);
    const fileCount = fileWords.length;
    const imported = await this.dbManager.getSystemWordBookWordCount(this.bookId);
    if (imported > 0 && imported >= fileCount) {
      this.useResourceWords = false;
      this.resourceWords = [];
      return;
    }
    const words = await buildWordItemsForBook(def, this.resourceMgr);
    this.useResourceWords = true;
    this.resourceWords = words;
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
    await this.loadNextPage();
  }

  private async loadNextPage(): Promise<void> {
    if (this.isPageLoading || !this.hasMore) {
      return;
    }
    this.isPageLoading = true;
    this.loadMoreErrorMessage = '';
    try {
      let page: WordItem[] = [];
      if (this.bookType === 'user') {
        page = await this.dbManager.getUserWordBookWordsPaged(this.bookId, this.pageSize, this.pageOffset);
      } else if (!this.useResourceWords) {
        page = await this.dbManager.getSystemWordBookWordsPaged(this.bookId, this.pageSize, this.pageOffset);
      } else {
        const start = this.pageOffset;
        const end = Math.min(start + this.pageSize, this.resourceWords.length);
        page = this.resourceWords.slice(start, end);
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
      this.loadMoreErrorMessage = errMsg;
    } finally {
      this.isPageLoading = false;
    }
  }

  private applyFilter(): void {
    const keyword = this.searchText.trim().toLowerCase();
    let result: WordItem[] = [];
    if (keyword.length === 0) {
      result = this.items;
    } else {
      result = this.items.filter((w: WordItem) => {
        if (w.word.toLowerCase().includes(keyword)) {
          return true;
        }
        return this.getWordMeaningTextForSearch(w).toLowerCase().includes(keyword);
      });
    }
    this.filtered = this.sortWords(result, this.sortType);
    this.listSource.updateData(this.filtered);
  }

  private sortWords(words: WordItem[], sort: SortType): WordItem[] {
    const sorted = [...words];
    if (sort === 'alphabet') {
      sorted.sort((a: WordItem, b: WordItem) => a.word.localeCompare(b.word));
      return sorted;
    }
    if (sort === 'status') {
      sorted.sort((a: WordItem, b: WordItem) => a.status.localeCompare(b.status));
      return sorted;
    }
    if (sort === 'time') {
      sorted.sort((a: WordItem, b: WordItem) => b.createdAt - a.createdAt);
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
    return '暂无释义（点击查看）';
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
      default:
        return '未知';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW:
        return DesignTokens.Colors.PRIMARY;
      case WordStatus.LEARNING:
        return '#FF9800';
      case WordStatus.REVIEW:
        return '#9C27B0';
      case WordStatus.RELEARNING:
        return '#E91E63';
      default:
        return DesignTokens.Colors.GRAY_500;
    }
  }

  private openWordDetail(word: WordItem): void {
    if (this.useResourceWords) {
      promptAction.showToast({ message: '未导入词书，暂不支持详情', duration: 1500 });
      return;
    }
    WordDetailCache.getInstance().set(word);
    router.pushUrl({ url: 'pages/WordDetailPage', params: { wordId: word.id, wordText: word.word } });
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .accessibilityText('返回')
          .onClick(() => router.back());

        Column() {
          Text(this.bookName)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(DesignTokens.Colors.GRAY_900);

          Text(`共 ${this.totalCount} 个单词`)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({ top: 4 });
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start);

        Blank();
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.currentThemeId.length > 0 ? DesignTokens.Colors.BACKGROUND_PRIMARY : DesignTokens.Colors.BACKGROUND_PRIMARY);

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(DesignTokens.Colors.PRIMARY);

          Text(this.loadingHint)
            .fontSize(14)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ top: 12 });
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      } else if (this.loadErrorMessage.length > 0) {
        Column() {
          Text('加载失败')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.GRAY_900);
          Text(this.loadErrorMessage)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ top: 6 });
          Button('重试')
            .type(ButtonType.Normal)
            .backgroundColor(DesignTokens.Colors.PRIMARY)
            .fontColor(Color.White)
            .borderRadius(12)
            .height(36)
            .margin({ top: 16 })
            .onClick(() => void this.init());
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center);
      } else {
        Column() {
          Row() {
            Text('🔍')
              .fontSize(18)
              .fontColor(DesignTokens.Colors.GRAY_600);

            TextInput({ text: this.searchText, placeholder: '搜索单词或释义（已加载部分）' })
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => {
                this.searchText = value;
                this.applyFilter();
              });
          }
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 12 })
          .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
          .borderRadius(DesignTokens.BorderRadius.LG)
          .margin({ top: 12 });

          Row() {
            Text(`共 ${this.filtered.length} 个单词`)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.GRAY_500);

            Blank();

            Button(this.getSortLabel())
              .type(ButtonType.Normal)
              .height(32)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
              .borderRadius(16)
              .onClick(() => this.cycleSortType());
          }
          .width('100%')
          .margin({ top: 10, bottom: 12 });

          if (this.filtered.length === 0) {
            Column() {
              Text('暂无单词')
                .fontSize(14)
                .fontColor(DesignTokens.Colors.GRAY_500);
            }
            .layoutWeight(1)
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center);
          } else {
            List() {
              LazyForEach(this.listSource, (word: WordItem) => {
                ListItem() {
                  this.buildWordRow(word);
                }
              }, (word: WordItem) => word.word)

              if (this.isPageLoading) {
                ListItem() {
                  Row() {
                    LoadingProgress()
                      .width(20)
                      .height(20)
                      .color(DesignTokens.Colors.PRIMARY);

                    Text('加载更多...')
                      .fontSize(12)
                      .fontColor(DesignTokens.Colors.GRAY_600)
                      .margin({ left: 10 });
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 18 })
                  .justifyContent(FlexAlign.Center);
                }
              } else if (this.loadMoreErrorMessage.length > 0) {
                ListItem() {
                  Text('加载失败，点击重试')
                    .fontSize(12)
                    .fontColor(DesignTokens.Colors.PRIMARY)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 10, bottom: 18 })
                    .onClick(() => void this.loadNextPage());
                }
              } else if (!this.hasMore) {
                ListItem() {
                  Text('已加载全部')
                    .fontSize(12)
                    .fontColor(DesignTokens.Colors.GRAY_500)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 10, bottom: 18 });
                }
              } else {
                ListItem() {
                  Text('上拉加载更多')
                    .fontSize(12)
                    .fontColor(DesignTokens.Colors.GRAY_500)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 10, bottom: 18 });
                }
              }
            }
            .layoutWeight(1)
            .width('100%')
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
    .backgroundColor(this.currentThemeId.length > 0 ? DesignTokens.Colors.BACKGROUND_PRIMARY : DesignTokens.Colors.BACKGROUND_PRIMARY);
  }

  @Builder
  private buildWordRow(word: WordItem) {
    Column() {
      Row() {
        Text(word.word)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(this.getStatusText(word.status))
          .fontSize(12)
          .fontColor(DesignTokens.Colors.WHITE)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(this.getStatusColor(word.status))
          .borderRadius(12)
          .margin({ left: 12 });
      }
      .width('100%');

      Text(this.getWordMeaningTextForDisplay(word))
        .fontSize(12)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: 6 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(DesignTokens.BorderRadius.XL)
    .border({ width: 1, color: '#E5ECF7' })
    .margin({ bottom: 12 })
    .onClick(() => this.openWordDetail(word));
  }

  private getSortLabel(): string {
    if (this.sortType === 'alphabet') {
      return '按字母';
    }
    if (this.sortType === 'status') {
      return '按状态';
    }
    if (this.sortType === 'time') {
      return '按时间';
    }
    return '默认排序';
  }

  private cycleSortType(): void {
    if (this.sortType === 'default') {
      this.sortType = 'alphabet';
      this.applyFilter();
      return;
    }
    if (this.sortType === 'alphabet') {
      this.sortType = 'status';
      this.applyFilter();
      return;
    }
    if (this.sortType === 'status') {
      this.sortType = 'time';
      this.applyFilter();
      return;
    }
    this.sortType = 'default';
    this.applyFilter();
  }
}
