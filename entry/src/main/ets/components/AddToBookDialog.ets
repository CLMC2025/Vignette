import { DBManager, UserWordBook } from '../database/DBManager';
import { DesignTokens } from '../model/DesignTokens';
import { WordItem } from '../model/WordModel';

export interface AddToBookDialogResult {
  bookId: string;
  bookName: string;
}

@Component
export struct AddToBookDialog {
  @Prop visible: boolean = false;
  @Prop word: WordItem | null = null;
  @Prop joinedBookIds: string[] = [];
  onDismiss: (() => void) | undefined = undefined;
  onSelectBook: ((result: AddToBookDialogResult) => void) | undefined = undefined;
  onRequestCreateBook: (() => void) | undefined = undefined;

  @State private isLoading: boolean = false;
  @State private books: UserWordBook[] = [];
  @State private loadError: string = '';

  private dbManager: DBManager = DBManager.getInstance();

  aboutToAppear(): void {
    if (this.visible) {
      void this.loadBooks();
    }
  }

  aboutToUpdate(): void {
    if (this.visible && this.books.length === 0 && !this.isLoading && this.loadError.length === 0) {
      void this.loadBooks();
    }
  }

  private dismiss(): void {
    if (this.onDismiss !== undefined) {
      this.onDismiss();
    }
  }

  private requestCreateBook(): void {
    if (this.onRequestCreateBook !== undefined) {
      this.onRequestCreateBook();
    }
  }

  private selectBook(book: UserWordBook): void {
    if (this.onSelectBook !== undefined) {
      const result: AddToBookDialogResult = { bookId: book.id, bookName: book.name };
      this.onSelectBook(result);
    }
  }

  private isJoined(bookId: string): boolean {
    const target = bookId.trim();
    for (const id of this.joinedBookIds) {
      if (id === target) {
        return true;
      }
    }
    return false;
  }

  private async loadBooks(): Promise<void> {
    this.isLoading = true;
    this.loadError = '';
    try {
      const list = await this.dbManager.getUserWordBooks();
      this.books = list;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      this.loadError = errMsg.length > 0 ? errMsg : '加载失败';
      this.books = [];
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Stack() {
      if (this.visible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(DesignTokens.Colors.BLACK)
          .opacity(0.4)
          .onClick(() => this.dismiss());

        Column() {
          Text('添加到词书')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .width('100%')
            .margin({ bottom: 12 });

          if (this.isLoading) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color(DesignTokens.Colors.GRAY_400)
              .margin({ top: 20, bottom: 20 });
          } else if (this.loadError.length > 0) {
            Text('加载失败')
              .fontSize(14)
              .fontColor(DesignTokens.Colors.GRAY_500)
              .onClick(() => void this.loadBooks())
              .padding(20);
          } else if (this.books.length === 0) {
            Column() {
              Text('还没有创建词书')
                .fontSize(14)
                .fontColor(DesignTokens.Colors.GRAY_600);

              Text('创建')
                .fontSize(14)
                .fontColor(DesignTokens.Colors.PRIMARY)
                .margin({ top: 12 })
                .onClick(() => this.requestCreateBook());
            }
            .padding(20);
          } else {
            List() {
              ForEach(this.books, (book: UserWordBook) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(book.name)
                        .fontSize(15)
                        .fontColor(DesignTokens.Colors.GRAY_900);

                      Text(`${book.wordCount} 词`)
                        .fontSize(12)
                        .fontColor(DesignTokens.Colors.GRAY_500)
                        .margin({ top: 2 });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    if (this.isJoined(book.id)) {
                      Text('已加入')
                        .fontSize(12)
                        .fontColor(DesignTokens.Colors.GRAY_400);
                    } else {
                      Text('›')
                        .fontSize(16)
                        .fontColor(DesignTokens.Colors.GRAY_400);
                    }
                  }
                  .width('100%')
                  .padding({ top: 12, bottom: 12 })
                  .onClick(() => {
                    if (!this.isJoined(book.id)) {
                      this.selectBook(book);
                    }
                  });
                }
              }, (book: UserWordBook) => book.id);
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off);

            Text('创建新词书')
              .fontSize(14)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .onClick(() => this.requestCreateBook());
          }
        }
        .width('85%')
        .constraintSize({ maxHeight: '60%' })
        .padding(20)
        .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
        .borderRadius(12);
      }
    }
    .width(this.visible ? '100%' : '0%')
    .height(this.visible ? '100%' : '0%')
    .alignContent(Alignment.Center);
  }
}
