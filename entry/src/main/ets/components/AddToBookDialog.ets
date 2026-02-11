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
          .backgroundColor('#000000')
          .opacity(0.45)
          .onClick(() => this.dismiss());

        Column() {
          Row() {
            Text('选择词书')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(DesignTokens.Colors.GRAY_900);

            Blank();

            Text('✕')
              .fontSize(18)
              .fontColor(DesignTokens.Colors.GRAY_500)
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => this.dismiss());
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 });

          Divider()
            .color(DesignTokens.Colors.GRAY_200);

          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(DesignTokens.Colors.PRIMARY);

              Text('加载中...')
                .fontSize(14)
                .fontColor(DesignTokens.Colors.GRAY_600)
                .margin({ top: 12 });
            }
            .width('100%')
            .padding(28)
            .alignItems(HorizontalAlign.Center);
          } else if (this.loadError.length > 0) {
            Column() {
              Text('加载失败')
                .fontSize(16)
                .fontColor(DesignTokens.Colors.GRAY_900)
                .margin({ bottom: 8 });

              Text(this.loadError)
                .fontSize(12)
                .fontColor(DesignTokens.Colors.GRAY_600)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Center)
                .margin({ bottom: 16 });

              Button('重试')
                .height(40)
                .fontSize(14)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(DesignTokens.Colors.PRIMARY)
                .borderRadius(20)
                .onClick(() => void this.loadBooks());
            }
            .width('100%')
            .padding(28)
            .alignItems(HorizontalAlign.Center);
          } else if (this.books.length === 0) {
            Column() {
              Text('还没有创建词书')
                .fontSize(16)
                .fontColor(DesignTokens.Colors.GRAY_900)
                .margin({ bottom: 8 });

              Text('创建你的第一个词书后，才能把单词加入其中。')
                .fontSize(13)
                .fontColor(DesignTokens.Colors.GRAY_600)
                .textAlign(TextAlign.Center)
                .margin({ bottom: 18 });

              Button('创建词书')
                .width('70%')
                .height(44)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(DesignTokens.Colors.PRIMARY)
                .borderRadius(22)
                .onClick(() => this.requestCreateBook());
            }
            .width('100%')
            .padding(28)
            .alignItems(HorizontalAlign.Center);
          } else {
            List() {
              ForEach(this.books, (book: UserWordBook) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(book.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(DesignTokens.Colors.GRAY_900)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%');

                      Text(`${book.wordCount} 词`)
                        .fontSize(12)
                        .fontColor(DesignTokens.Colors.GRAY_600)
                        .margin({ top: 4 });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    if (this.isJoined(book.id)) {
                      Text('已加入')
                        .fontSize(12)
                        .fontColor(DesignTokens.Colors.PRIMARY)
                        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                        .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
                        .borderRadius(12);
                    } else {
                      Text('›')
                        .fontSize(18)
                        .fontColor(DesignTokens.Colors.GRAY_500);
                    }
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  .onClick(() => this.selectBook(book));
                }
              }, (book: UserWordBook) => book.id);
            }
            .width('100%')
            .layoutWeight(1)
            .divider({ strokeWidth: 1, color: DesignTokens.Colors.GRAY_200 });

            Button('创建新词书')
              .width('92%')
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
              .borderRadius(22)
              .margin({ top: 14, bottom: 16 })
              .onClick(() => this.requestCreateBook());
          }
        }
        .width('92%')
        .height('70%')
        .backgroundColor('#FFFFFF')
        .borderRadius(DesignTokens.BorderRadius.XL)
        .position({ x: '4%', y: '15%' });
      }
    }
    .width(this.visible ? '100%' : '0%')
    .height(this.visible ? '100%' : '0%');
  }
}
