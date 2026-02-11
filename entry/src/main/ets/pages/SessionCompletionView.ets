import { DesignTokens } from '../model/DesignTokens';


@Component
export struct SessionCompletionView {
  @Prop reviewedCount: number;
  @Prop newLearnedCount: number;
  
  onConfirm: () => void = () => {};

  build() {
    Column() {
      Image($r('sys.media.ohos_ic_public_ok'))
        .width(64)
        .height(64)
        .fillColor(DesignTokens.Colors.PRIMARY)
        .margin({ bottom: DesignTokens.Spacing.LG })

      Text('会话完成!')
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .margin({ bottom: DesignTokens.Spacing.MD })

      Column() {
        Row() {
          Text('复习单词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_600)
          Blank()
          Text(this.reviewedCount.toString())
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(DesignTokens.Colors.PRIMARY)
        }
        .width('100%')
        .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

        Divider().color(DesignTokens.Colors.GRAY_200)

        Row() {
          Text('新学单词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_600)
          Blank()
          Text(this.newLearnedCount.toString())
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(DesignTokens.Colors.SUCCESS)
        }
        .width('100%')
        .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
      }
      .width('80%')
      .padding(DesignTokens.Spacing.MD)
      .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .margin({ bottom: DesignTokens.Spacing.XXL })

      Button('确定')
        .width('60%')
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor(DesignTokens.Colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .onClick(() => this.onConfirm())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(DesignTokens.Colors.BACKGROUND_PRIMARY)
  }
}
