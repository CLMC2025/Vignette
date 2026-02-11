import { DesignTokens } from '../model/DesignTokens';

@Component
export struct ReadPageHeader {
  @Prop taskIndex: number;
  @Prop taskQueueLength: number;
  @Prop canUndo: boolean;
  onBack: () => void = () => {};
  onUndo: () => void = () => {};

  build() {
    Row() {
      // Back button
      Image($r('sys.media.ohos_ic_public_arrow_left'))
        .width(24)
        .height(24)
        .fillColor(DesignTokens.Colors.GRAY_900)
        .onClick(() => this.onBack())

      // Title & progress
      Column() {
        Text('微语境学习')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)

        Text(`第 ${Math.min(this.taskIndex + 1, this.taskQueueLength)} / ${this.taskQueueLength} 个单词`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)

        Progress({
          value: Math.min(this.taskIndex + 1, this.taskQueueLength),
          total: Math.max(1, this.taskQueueLength),
          type: ProgressType.Linear
        })
          .width(120)
          .height(4)
          .color(DesignTokens.Colors.PRIMARY)
          .backgroundColor(DesignTokens.Colors.GRAY_300)
          .margin({ top: DesignTokens.Spacing.XS })
      }
      .margin({ left: DesignTokens.Spacing.LG })

      Blank()

      Button('撤回')
        .height(36)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.canUndo ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_400)
        .backgroundColor(this.canUndo ? DesignTokens.Colors.PRIMARY_LIGHTEST : DesignTokens.Colors.GRAY_200)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .enabled(this.canUndo)
        .onClick(() => this.onUndo())
    }
    .width('100%')
    .height(64)
    .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING })
    .backgroundColor(DesignTokens.Colors.WHITE)
  }
}
