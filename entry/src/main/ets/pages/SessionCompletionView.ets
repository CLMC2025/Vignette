import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';


@Component
export struct SessionCompletionView {
  @Prop reviewedCount: number;
  @Prop newLearnedCount: number;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  onConfirm: () => void = () => {};

  build() {
    Column() {
      Image($r('sys.media.ohos_ic_public_ok'))
        .width(64)
        .height(64)
        .fillColor(this.colors.PRIMARY)
        .margin({ bottom: DesignTokens.Spacing.LG })

      Text('会话完成!')
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(this.colors.GRAY_900)
        .margin({ bottom: DesignTokens.Spacing.MD })

      Column() {
        Row() {
          Text('复习单词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.GRAY_600)
          Blank()
          Text(this.reviewedCount.toString())
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.colors.PRIMARY)
        }
        .width('100%')
        .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

        Divider().color(this.colors.GRAY_200)

        Row() {
          Text('新学单词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.GRAY_600)
          Blank()
          Text(this.newLearnedCount.toString())
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.colors.SUCCESS)
        }
        .width('100%')
        .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
      }
      .width('80%')
      .padding(DesignTokens.Spacing.MD)
      .backgroundColor(this.colors.BACKGROUND_SECONDARY)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .margin({ bottom: DesignTokens.Spacing.XXL })

      Button('确定')
        .width('60%')
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.colors.WHITE)
        .backgroundColor(this.colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .onClick(() => this.onConfirm())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
  }
}
