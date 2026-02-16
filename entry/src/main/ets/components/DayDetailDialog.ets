import { DesignTokens } from '../model/DesignTokens';
import { HeatmapDailyStats } from '../model/HeatmapData';

interface ProgressItem {
  label: string;
  value: number;
  color: ResourceColor;
}

@Component
export struct DayDetailDialog {
  @Link visible: boolean;
  @Prop stats: HeatmapDailyStats;
  onClose: () => void = () => {};

  private readonly BAR_HEIGHT: number = 8;
  private readonly BAR_RADIUS: number = 6;
  private readonly HEADER_FONT: number = 18;
  private readonly VALUE_FONT: number = 14;
  private readonly LABEL_FONT: number = 12;
  private readonly PERCENT_SCALE: number = 100;
  private readonly MS_PER_MINUTE: number = 60 * 1000;

  private formatDate(dateMs: number): string {
    const date = new Date(dateMs);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${year}年${month}月${day}日`;
  }

  private formatDuration(durationMs: number): string {
    if (durationMs <= 0) {
      return '0 分钟';
    }
    const minutes = Math.max(1, Math.round(durationMs / this.MS_PER_MINUTE));
    return `${minutes} 分钟`;
  }

  private getTotalReviews(): number {
    return this.stats.totalReviews;
  }

  private getPercent(value: number): number {
    const total = this.getTotalReviews();
    if (total <= 0) {
      return 0;
    }
    return Math.round((value / total) * this.PERCENT_SCALE);
  }

  private handleClose(): void {
    this.visible = false;
    this.onClose();
  }

  @Builder
  private buildProgressItem(item: ProgressItem): void {
    Column() {
      Row() {
        Text(item.label)
          .fontSize(this.LABEL_FONT)
          .fontColor(DesignTokens.Colors.GRAY_600)
        Blank()
        Text(`${item.value}`)
          .fontSize(this.VALUE_FONT)
          .fontColor(DesignTokens.Colors.GRAY_900)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.XS })

      Stack() {
        Row()
          .width('100%')
          .height(this.BAR_HEIGHT)
          .backgroundColor(DesignTokens.Colors.GRAY_200)
          .borderRadius(this.BAR_RADIUS)

        Row()
          .width(`${this.getPercent(item.value)}%`)
          .height(this.BAR_HEIGHT)
          .backgroundColor(item.color)
          .borderRadius(this.BAR_RADIUS)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: DesignTokens.Spacing.MD })
  }

  @Builder
  private buildSummaryRow(label: string, value: string): void {
    Row() {
      Text(label)
        .fontSize(this.LABEL_FONT)
        .fontColor(DesignTokens.Colors.GRAY_600)
      Blank()
      Text(value)
        .fontSize(this.VALUE_FONT)
        .fontColor(DesignTokens.Colors.GRAY_900)
    }
    .width('100%')
    .margin({ bottom: DesignTokens.Spacing.SM })
  }

  build() {
    if (this.visible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(DesignTokens.Colors.BLACK)
          .opacity(0.45)
          .onClick(() => this.handleClose())

        Column() {
          Column() {
            Row() {
              Text('学习详情')
                .fontSize(this.HEADER_FONT)
                .fontColor(DesignTokens.Colors.GRAY_900)
                .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
              Blank()
              Text('关闭')
                .fontSize(this.VALUE_FONT)
                .fontColor(DesignTokens.Colors.GRAY_600)
                .onClick(() => this.handleClose())
            }
            .width('100%')
            .margin({ bottom: DesignTokens.Spacing.SM })

            Text(this.formatDate(this.stats.dateMs))
              .fontSize(this.LABEL_FONT)
              .fontColor(DesignTokens.Colors.GRAY_500)
              .margin({ bottom: DesignTokens.Spacing.LG })

            this.buildProgressItem({
              label: '认识',
              value: this.stats.knownCount,
              color: DesignTokens.Colors.SUCCESS
            })
            this.buildProgressItem({
              label: '模糊',
              value: this.stats.fuzzyCount,
              color: DesignTokens.Colors.WARNING
            })
            this.buildProgressItem({
              label: '忘记',
              value: this.stats.forgottenCount,
              color: DesignTokens.Colors.ERROR
            })

            this.buildSummaryRow('新学', `${this.stats.newCount}`)
            this.buildSummaryRow('复习', `${this.stats.reviewCount}`)
            this.buildSummaryRow('总复习次数', `${this.stats.totalReviews}`)
            this.buildSummaryRow('学习时长', this.formatDuration(this.stats.durationMs))
          }
          .width('100%')
          .padding(DesignTokens.Spacing.XL)
          .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.XL)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(200)
    }
  }
}
