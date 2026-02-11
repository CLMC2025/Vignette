import { DesignTokens } from '../../../model/DesignTokens';

@Component
export struct HeroSection {
  @Prop currentBookName: string;
  onStartSession: () => void = () => {};
  onManageBooks: () => void = () => {};

  build() {
    Column() {
      Text('通过微语境科学记忆单词')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_800)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')

      Text(`当前词书：${this.currentBookName}`)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: DesignTokens.Spacing.SM })
        .width('100%')

      Button('开始学习')
        .width('100%')
        .height(64)
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor(DesignTokens.Colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.XL)
        .margin({ top: DesignTokens.Spacing.LG })
        .stateEffect(true)
        .onClick(() => this.onStartSession())

      Button('词书管理')
        .width('100%')
        .height(52)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.PRIMARY)
        .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
        .borderRadius(DesignTokens.BorderRadius.XL)
        .margin({ top: DesignTokens.Spacing.MD })
        .stateEffect(true)
        .onClick(() => this.onManageBooks())
    }
    .width('100%')
    .padding(DesignTokens.Spacing.XL)
    .backgroundColor('#FFFFFFCC')
    .borderRadius(DesignTokens.BorderRadius.XL)
    .border({ width: 1, color: '#E5ECF7' })
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
  }
}
