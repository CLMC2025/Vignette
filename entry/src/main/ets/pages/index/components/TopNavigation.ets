import { DesignTokens } from '../../../model/DesignTokens';

@Component
export struct TopNavigation {
  onSettingsClick: () => void = () => {};

  build() {
    Row() {
      Row() {
        Text('🟦')
          .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
          .margin({ right: DesignTokens.Spacing.SM })

        Text('微语单词')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
          .fontColor(DesignTokens.Colors.GRAY_900)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Text('⚙')
        .fontSize(22)
        .fontColor(DesignTokens.Colors.GRAY_700)
        .onClick(() => this.onSettingsClick())
    }
    .width('100%')
    .height(64)
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      top: DesignTokens.Spacing.SM,
      bottom: DesignTokens.Spacing.SM
    })
    .backgroundColor('#F5F7FB')
  }
}
