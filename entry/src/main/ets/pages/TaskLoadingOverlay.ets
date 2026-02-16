import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';


@Component
export struct TaskLoadingOverlay {
  @Prop loadingHint: string;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  build() {
    Column() {
      LoadingProgress()
        .width(56)
        .height(56)
        .color(this.colors.PRIMARY)
        .animation({
          duration: DesignTokens.Animations.DURATION_NORMAL,
          curve: DesignTokens.Animations.CURVE_EASE_IN_OUT,
          iterations: -1
        })

      Text(this.loadingHint)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.WHITE)
        .margin({ top: DesignTokens.Spacing.LG })
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width('80%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.colors.BLACK + 'CC')
    .position({ x: 0, y: 0 })
    .zIndex(100)
  }
}
