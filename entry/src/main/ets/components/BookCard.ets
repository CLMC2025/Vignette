import { DesignTokens } from '../model/DesignTokens';
import { BookDifficulty, BookCategory, BookProgress } from '../model/WordBookCatalog';

export interface BookCardData {
  id: string;
  name: string;
  description?: string;
  wordCount: number;
  difficulty?: BookDifficulty;
  category?: BookCategory;
  progress: BookProgress;
  estimatedDays: number;
  dailyGoal: number;
  sourceLabel: string;
  isCurrent: boolean;
  isImported: boolean; // For system books: true if imported
  isUserBook: boolean;
}

@Component
export struct BookCard {
  @Prop bookId: string;
  @Prop name: string;
  @Prop description: string = '';
  @Prop wordCount: number;
  @Prop difficulty: BookDifficulty | undefined;
  @Prop category: BookCategory | undefined;
  @Prop progressMastered: number;
  @Prop progressLearning: number;
  @Prop progressNewWords: number;
  @Prop estimatedDays: number = 0;
  @Prop dailyGoal: number = 0;
  @Prop sourceLabel: string = '';
  @Prop isCurrent: boolean;
  @Prop isImported: boolean;
  @Prop isUserBook: boolean;
  onClickBook?: (id: string) => void;
  onAction?: (id: string, action: string) => void;

  build() {
    Column() {
      Row() {
        Text(this.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.isCurrent) {
          Text('当前')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor(DesignTokens.Colors.SUCCESS)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .margin({ left: 8 })
        }

        Blank()

        Text(`${this.getProgressPercent()}%`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(DesignTokens.Colors.SUCCESS)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.getProgressSummary())
        .fontSize(11)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .margin({ top: 6 })

      Progress({ value: this.getProgressPercent(), total: 100, type: ProgressType.Linear })
        .color(DesignTokens.Colors.SUCCESS)
        .backgroundColor(DesignTokens.Colors.BORDER_LIGHT)
        .height(4)
        .width('100%')
        .margin({ top: 8 })

      Row() {
        Blank()

        if (this.isUserBook || this.isImported) {
          Button(this.isCurrent ? '正在学习' : '开始学习')
            .type(ButtonType.Normal)
            .borderRadius(12)
            .backgroundColor(this.isCurrent ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.PRIMARY)
            .fontColor(Color.White)
            .height(28)
            .fontSize(12)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              if (this.onClickBook) {
                this.onClickBook(this.bookId);
              }
            })
        } else {
          Button('导入词书')
            .type(ButtonType.Normal)
            .borderRadius(12)
            .backgroundColor(DesignTokens.Colors.PRIMARY)
            .fontColor(Color.White)
            .height(28)
            .fontSize(12)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              if (this.onAction) {
                this.onAction(this.bookId, 'import');
              }
            })
        }
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({ width: 1, color: DesignTokens.Colors.BORDER_LIGHT })
    .onClick(() => {
      if (this.onClickBook) {
        this.onClickBook(this.bookId);
      }
    })
  }

  private getProgressPercent(): number {
    if (this.wordCount === 0) {
      return 0;
    }
    const learned = this.progressMastered + this.progressLearning;
    return Math.min(100, Math.round((learned / this.wordCount) * 100));
  }

  private getProgressSummary(): string {
    return `已掌握 ${this.progressMastered} · 学习中 ${this.progressLearning} · 共 ${this.wordCount} 词`;
  }
}
