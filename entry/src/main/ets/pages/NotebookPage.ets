import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DBManager, NotebookWordEntry } from '../database/DBManager';
import { DesignTokens } from '../model/DesignTokens';
import { WordItem, WordMeaning, WordStatus } from '../model/WordModel';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

class NotebookWordDataSource implements IDataSource {
  private words: NotebookWordEntry[] = [];

  constructor(words: NotebookWordEntry[]) {
    this.words = words;
  }

  totalCount(): number {
    return this.words.length;
  }

  getData(index: number): NotebookWordEntry {
    return this.words[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {}

  unregisterDataChangeListener(listener: DataChangeListener): void {}
}

@Entry
@Component
struct NotebookPage {
  @State private isLoading: boolean = true;
  @State private notebookWords: NotebookWordEntry[] = [];
  @State private wordItems: Map<string, WordItem> = new Map<string, WordItem>();
  @State private searchText: string = '';
  @State private filteredWords: NotebookWordEntry[] = [];
  @State private dataSource: NotebookWordDataSource = new NotebookWordDataSource([]);
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.initialize();
  }

  onPageShow(): void {
    // 页面显示时刷新数据，确保单词状态同步
    // 使用延迟执行，避免影响页面进入动画
    setTimeout(() => {
      void this.refreshWordItems();
    }, 300);
  }

  private async refreshWordItems(): Promise<void> {
    if (this.notebookWords.length === 0) {
      return;
    }
    try {
      // 只检查前50个单词，避免大量查询
      const visibleWords = this.filteredWords.slice(0, 50);
      let hasChanges = false;

      for (const nw of visibleWords) {
        const item = await this.dbManager.getWordByWord(nw.word);
        if (item !== null) {
          const existing = this.wordItems.get(nw.word);
          if (existing === undefined || existing.status !== item.status || existing.id !== item.id) {
            this.wordItems.set(nw.word, item);
            hasChanges = true;
          }
        }
      }
      if (hasChanges) {
        this.applyFilter();
      }
    } catch (e) {
      console.warn('[NotebookPage] refreshWordItems failed:', e);
    }
  }

  private async initialize(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.context !== null) {
        await this.dbManager.initialize(this.context);
      }
      await this.loadNotebookWords();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[NotebookPage] Failed to load:', errMsg);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadNotebookWords(): Promise<void> {
    const words = await this.dbManager.getNotebookWordsWithTime();
    this.notebookWords = words.sort((a: NotebookWordEntry, b: NotebookWordEntry) => b.createdAt - a.createdAt);

    for (const nw of this.notebookWords) {
      const item = await this.dbManager.getWordByWord(nw.word);
      if (item !== null) {
        this.wordItems.set(nw.word, item);
      }
    }

    this.applyFilter();
  }

  private applyFilter(): void {
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      this.filteredWords = [...this.notebookWords];
    } else {
      this.filteredWords = this.notebookWords.filter((nw: NotebookWordEntry) => {
        if (nw.word.toLowerCase().includes(keyword)) {
          return true;
        }
        const item = this.wordItems.get(nw.word);
        if (item !== undefined) {
          const meaningText = this.getWordMeaningText(item);
          if (meaningText.toLowerCase().includes(keyword)) {
            return true;
          }
        }
        return false;
      });
    }
    this.dataSource = new NotebookWordDataSource(this.filteredWords);
  }

  private getWordMeaningText(word: WordItem): string {
    const contextMeaning = word.definition?.contextMeaning ?? '';
    const common = word.definition?.commonMeanings ?? [];
    const commonText = common.map((m: WordMeaning) => `${m.pos} ${m.cn}`).join(' ');
    return `${contextMeaning} ${commonText}`.trim();
  }

  private async removeFromNotebook(word: string): Promise<void> {
    try {
      await this.dbManager.removeWordFromNotebook(word);
      this.notebookWords = this.notebookWords.filter((nw: NotebookWordEntry) => nw.word !== word);
      this.wordItems.delete(word);
      this.applyFilter();
      promptAction.showToast({ message: '已取消收藏', duration: 1500 });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `移除失败：${errMsg}`, duration: 2000 });
    }
  }

  private navigateToWordDetail(nw: NotebookWordEntry): Promise<void> {
    const item = this.wordItems.get(nw.word);
    const wordId = item?.id ?? 0;
    return router.pushUrl({
      url: 'pages/WordDetailPage',
      params: {
        wordId: wordId,
        wordText: nw.word
      }
    });
  }

  private formatDate(ts: number): string {
    const d = new Date(ts);
    return `${d.getMonth() + 1}/${d.getDate()}`;
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(this.colors.GRAY_900)
          .onClick(() => router.back());

        Column() {
          Text('单词本')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors.GRAY_900);

          Text(`共 ${this.notebookWords.length} 个收藏`)
            .fontSize(12)
            .fontColor(this.colors.GRAY_600)
            .margin({ top: 4 });
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start);

        Blank();
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.colors.BACKGROUND_PRIMARY);

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(this.colors.PRIMARY);

          Text('加载中...')
            .fontSize(14)
            .fontColor(this.colors.GRAY_500)
            .margin({ top: 12 });
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      } else {
        Column() {
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
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.colors.BACKGROUND_SECONDARY)
          .borderRadius(DesignTokens.BorderRadius.LG);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 });

        if (this.filteredWords.length === 0) {
          Column() {
            Text('📚')
              .fontSize(48);

            Text(this.notebookWords.length === 0 ? '还没有收藏单词' : '未找到匹配的单词')
              .fontSize(14)
              .fontColor(this.colors.GRAY_500)
              .margin({ top: 12 });

            if (this.notebookWords.length === 0) {
              Text('学习时点击单词可收藏到单词本')
                .fontSize(12)
                .fontColor(this.colors.GRAY_400)
                .margin({ top: 8 });
            }
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center);
        } else {
          List({ space: 12 }) {
            LazyForEach(this.dataSource, (nw: NotebookWordEntry) => {
              ListItem() {
                this.buildWordCard(nw);
              }
            }, (nw: NotebookWordEntry) => nw.word);
          }
          .width('100%')
          .layoutWeight(1)
          .cachedCount(8)
          .scrollBar(BarState.Off)
          .padding({ left: 16, right: 16, bottom: 24 });
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .id('notebook_' + this.themeRefreshToken);
  }

  @Builder
  buildWordCard(nw: NotebookWordEntry) {
    Column() {
      Row() {
        Text(nw.word)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.GRAY_900)
          .layoutWeight(1);

        Text(this.formatDate(nw.createdAt))
          .fontSize(12)
          .fontColor(this.colors.GRAY_400);
      }
      .width('100%');

      Text(this.getWordMeaningText(this.wordItems.get(nw.word) ?? new WordItem(0, nw.word)))
        .fontSize(13)
        .fontColor(this.colors.GRAY_600)
        .margin({ top: 6 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Row() {
        Blank();

        Text('取消收藏')
          .fontSize(12)
          .fontColor(this.colors.GRAY_500)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.colors.GRAY_100)
          .borderRadius(16)
          .onClick(() => {
            void this.removeFromNotebook(nw.word);
          });
      }
      .width('100%')
      .margin({ top: 10 });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.XL)
    .onClick(() => {
      void this.navigateToWordDetail(nw);
    });
  }
}
