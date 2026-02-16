import { DesignTokens } from '../model/DesignTokens';
import { BookProgress } from '../model/WordBookCatalog';

export interface BookCardData {
  id: string;
  name: string;
  description?: string;
  wordCount: number;
  difficulty?: string;
  category?: string;
  progress: BookProgress;
  estimatedDays: number;
  dailyGoal: number;
  sourceLabel: string;
  isCurrent: boolean;
  isImported: boolean;
  isUserBook: boolean;
  coverColor?: string[];
  icon?: string;
}

@Component
export struct BookCard {
  @Prop bookId: string;
  @Prop name: string;
  @Prop description: string = '';
  @Prop wordCount: number;
  @Prop difficulty: string = '';
  @Prop category: string = '';
  @Prop progressMastered: number;
  @Prop progressLearning: number;
  @Prop progressNewWords: number;
  @Prop estimatedDays: number = 0;
  @Prop dailyGoal: number = 0;
  @Prop sourceLabel: string = '';
  @Prop isCurrent: boolean;
  @Prop isImported: boolean;
  @Prop isUserBook: boolean;
  @Prop coverColor: string = '';
  @Prop bookIcon: string = '';
  @Prop showLearnButton: boolean = true;
  onCardClick?: (id: string) => void;
  onActionClick?: (id: string, action: string) => void;

  build() {
    Row() {
      Column() {
        Row() {
          Text(this.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);

          if (this.isCurrent) {
            Text('当前')
              .fontSize(12)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 8 });
          }
        }
        .width('100%');

        Text(`${this.wordCount} 词`)
          .fontSize(13)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .margin({ top: 4 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        if (this.onCardClick) {
          this.onCardClick(this.bookId);
        }
      });

      if (this.showLearnButton && !this.isCurrent) {
        Button('学习')
          .width(64)
          .height(32)
          .fontSize(13)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(DesignTokens.Colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .onClick(() => {
            if (this.onActionClick) {
              this.onActionClick(this.bookId, 'learn');
            }
          });
      }

      Text('›')
        .fontSize(20)
        .fontColor(DesignTokens.Colors.GRAY_400)
        .margin({ left: 8 })
        .onClick(() => {
          if (this.onCardClick) {
            this.onCardClick(this.bookId);
          }
        });
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(12)
  }
}
