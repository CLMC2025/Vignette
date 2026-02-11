import router from '@ohos.router';
import { DBManager } from '../../database/DBManager';
import { BuiltInWordBooks } from '../../model/WordBookCatalog';
import { CurrentBookStore } from '../../utils/CurrentBookStore';
import { DesignTokens } from '../../model/DesignTokens';

@Component
export struct WordBookTabContent {
  @State currentBookName: string = '未选择词书';
  @State currentBookId: string = '';
  @State totalBooks: number = 0;

  private dbManager: DBManager = DBManager.getInstance();
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';

  async aboutToAppear() {
    await this.loadCurrentBook();
    await this.loadBookStats();
  }

  async onPageShow() {
    await this.loadCurrentBook();
    await this.loadBookStats();
  }

  private async loadCurrentBook(): Promise<void> {
    let stored = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
    if (stored.length === 0) {
      const fallback = await CurrentBookStore.getInstance().getCurrentBookId();
      if (fallback.trim().length > 0) {
        stored = fallback;
        AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, stored);
      }
    }
    this.currentBookId = stored;
    if (stored.length === 0) {
      this.currentBookName = '未选择词书';
      return;
    }
    const builtIn = BuiltInWordBooks.find((book) => book.id === stored);
    if (builtIn) {
      this.currentBookName = builtIn.name;
      return;
    }
    try {
      const userBooks = await this.dbManager.getUserWordBooks();
      for (const book of userBooks) {
        if (book.id === stored) {
          this.currentBookName = book.name;
          return;
        }
      }
    } catch (e) {
      // ignore
    }
    this.currentBookName = stored;
  }

  private async loadBookStats(): Promise<void> {
    try {
      const userBooks = await this.dbManager.getUserWordBooks();
      this.totalBooks = BuiltInWordBooks.length + userBooks.length;
    } catch (e) {
      this.totalBooks = BuiltInWordBooks.length;
    }
  }

  private jumpToWordList(): void {
    router.pushUrl({
      url: 'pages/WordBookManagerPage'
    });
  }

  build() {
    Column() {
      // Current Book Card
      Column() {
        Text('当前词书')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ bottom: DesignTokens.Spacing.XS })
        
        Text(this.currentBookName)
          .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .margin({ bottom: DesignTokens.Spacing.MD })

        Button('切换/管理词书')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(DesignTokens.Colors.PRIMARY)
          .height(44)
          .width('100%')
          .borderRadius(DesignTokens.BorderRadius.MD)
          .onClick(() => {
            this.jumpToWordList();
          })
      }
      .width('100%')
      .padding(DesignTokens.Spacing.LG)
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
      .margin({ bottom: DesignTokens.Spacing.LG })

      // Stats
      Row() {
        Text(`共 ${this.totalBooks} 本词书`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_500)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      top: DesignTokens.Spacing.LG
    })
  }
}
