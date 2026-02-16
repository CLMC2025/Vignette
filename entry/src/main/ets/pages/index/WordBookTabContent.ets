import router from '@ohos.router';
import { DBManager } from '../../database/DBManager';
import { BuiltInWordBooks, BookProgress } from '../../model/WordBookCatalog';
import { CurrentBookStore } from '../../utils/CurrentBookStore';
import { DesignTokens } from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';

interface CurrentBookInfo {
  id: string;
  name: string;
  icon: string;
  wordCount: number;
  progress: BookProgress;
}

@Component
export struct WordBookTabContent {
  @State currentBook: CurrentBookInfo | null = null;
  @State totalBooks: number = 0;
  @State isLoading: boolean = true;
  @StorageProp('current_book_id') @Watch('onCurrentBookIdChange') currentBookIdToken: string = '';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private dbManager: DBManager = DBManager.getInstance();
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';

  aboutToAppear(): void {
    void this.loadData();
  }

  onPageShow(): void {
    void this.loadData();
  }

  onCurrentBookIdChange(): void {
    void this.loadData();
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      let stored = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
      if (stored.length === 0) {
        const fallback = await CurrentBookStore.getInstance().getCurrentBookId();
        if (fallback.trim().length > 0) {
          stored = fallback;
          AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, stored);
        }
      }

      if (stored.length > 0) {
        this.currentBook = await this.loadBookInfo(stored);
      } else {
        this.currentBook = null;
      }

      const userBooks = await this.dbManager.getUserWordBooks();
      this.totalBooks = BuiltInWordBooks.length + userBooks.length;
    } catch (e) {
      console.error('[WordBookTabContent] Load failed:', e);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadBookInfo(bookId: string): Promise<CurrentBookInfo | null> {
    const builtIn = BuiltInWordBooks.find((book) => book.id === bookId);
    if (builtIn) {
      const progress = await this.dbManager.getBookProgress(bookId, true);
      const wordCount = await this.dbManager.getSystemWordBookWordCount(bookId);
      return {
        id: builtIn.id,
        name: builtIn.name,
        icon: builtIn.icon,
        wordCount: wordCount > 0 ? wordCount : builtIn.wordCount,
        progress: progress
      };
    }

    try {
      const userBooks = await this.dbManager.getUserWordBooks();
      for (const book of userBooks) {
        if (book.id === bookId) {
          const progress = await this.dbManager.getBookProgress(bookId, false);
          return {
            id: book.id,
            name: book.name,
            icon: book.icon ?? '📚',
            wordCount: book.wordCount,
            progress: progress
          };
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  private getProgressPercent(): number {
    if (this.currentBook === null || this.currentBook.wordCount === 0) {
      return 0;
    }
    const learned = this.currentBook.progress.mastered + this.currentBook.progress.learning;
    return Math.min(100, Math.round((learned / this.currentBook.wordCount) * 100));
  }

  private jumpToManager(): void {
    router.pushUrl({ url: 'pages/WordBookManagerPage' });
  }

  private startLearning(): void {
    if (this.currentBook === null) {
      return;
    }
    router.pushUrl({
      url: 'pages/WordList',
      params: {
        bookId: this.currentBook.id,
        bookName: this.currentBook.name,
        bookType: 'system'
      }
    });
  }

  build() {
    Column() {
      if (this.isLoading) {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(this.colors.GRAY_400);
        }
        .width('100%')
        .height(60)
        .justifyContent(FlexAlign.Center);
      } else if (this.currentBook !== null) {
        Row() {
          Column() {
            Text(this.currentBook.icon)
              .fontSize(24);
          }
          .width(44)
          .height(44)
          .backgroundColor(this.colors.GRAY_100)
          .borderRadius(8)
          .justifyContent(FlexAlign.Center);

          Column() {
            Text(this.currentBook.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.GRAY_900)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Row() {
              Text(`${this.currentBook.wordCount} 词`)
                .fontSize(13)
                .fontColor(this.colors.GRAY_500);

              if (this.getProgressPercent() > 0) {
                Text('·')
                  .fontSize(13)
                  .fontColor(this.colors.GRAY_400)
                  .margin({ left: 6, right: 6 });

                Text(`${this.getProgressPercent()}%`)
                  .fontSize(13)
                  .fontColor(this.colors.GRAY_500);
              }
            }
            .margin({ top: 2 });
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start);

          Text('›')
            .fontSize(18)
            .fontColor(this.colors.GRAY_400)
            .onClick(() => this.jumpToManager());
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(12)
        .onClick(() => this.startLearning());
      } else {
        Row() {
          Column() {
            Text('📚')
              .fontSize(24);
          }
          .width(44)
          .height(44)
          .backgroundColor(this.colors.GRAY_100)
          .borderRadius(8)
          .justifyContent(FlexAlign.Center);

          Column() {
            Text('选择词书')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.GRAY_900);

            Text(`${this.totalBooks} 本词书可选`)
              .fontSize(13)
              .fontColor(this.colors.GRAY_500)
              .margin({ top: 2 });
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start);

          Text('›')
            .fontSize(18)
            .fontColor(this.colors.GRAY_400);
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(12)
        .onClick(() => this.jumpToManager());
      }
    }
    .width('100%')
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      top: DesignTokens.Spacing.MD
    })
    .backgroundColor(this.colors.BACKGROUND_SECONDARY)
    .id('wordBookTab_' + this.themeRefreshToken)
  }
}
