import { DesignTokens } from '../model/DesignTokens';

@Component
export struct SessionErrorView {
  @Prop errorTitle: string;
  @Prop errorMessage: string;
  @Prop primaryActionLabel: string;
  @Prop secondaryActionLabel: string;
  @Prop showPrimaryAction: boolean;
  @Prop showSecondaryAction: boolean;
  
  onPrimaryAction: () => void = () => {};
  onSecondaryAction: () => void = () => {};

  build() {
    Column() {
      Image($r('sys.media.ohos_ic_public_fail'))
        .width(56)
        .height(56)
        .fillColor(DesignTokens.Colors.ERROR)

      Text(this.errorTitle)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .margin({ top: DesignTokens.Spacing.LG })

      Text(this.errorMessage)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: DesignTokens.Spacing.SM })
        .textAlign(TextAlign.Center)

      Row({ space: DesignTokens.Spacing.MD }) {
        if (this.showSecondaryAction) {
          Button(this.secondaryActionLabel)
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .onClick(() => this.onSecondaryAction());
        }

        if (this.showPrimaryAction) {
          Button(this.primaryActionLabel)
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(DesignTokens.Colors.PRIMARY)
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .onClick(() => this.onPrimaryAction());
        }
      }
      .width('100%')
      .margin({ top: DesignTokens.Spacing.XL })
    }
    .width('100%')
    .layoutWeight(1)
    .padding(DesignTokens.Spacing.XXL)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
