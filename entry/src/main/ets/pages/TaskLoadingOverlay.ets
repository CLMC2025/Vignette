import { DesignTokens } from '../model/DesignTokens';


@Component
export struct TaskLoadingOverlay {
  @Prop loadingHint: string;

  build() {
    Column() {
      LoadingProgress()
        .width(56)
        .height(56)
        .color(DesignTokens.Colors.PRIMARY)
        .animation({
          duration: DesignTokens.Animations.DURATION_NORMAL,
          curve: DesignTokens.Animations.CURVE_EASE_IN_OUT,
          iterations: -1
        })

      Text(this.loadingHint)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.WHITE)
        .margin({ top: DesignTokens.Spacing.LG })
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width('80%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(DesignTokens.Colors.BLACK + 'CC')
    .position({ x: 0, y: 0 })
    .zIndex(100)
  }
}
