import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

@Component
export struct ReadPageHeader {
  @Prop taskIndex: number;
  @Prop taskQueueLength: number;
  @Prop canUndo: boolean;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  onBack: () => void = () => {};
  onUndo: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  build() {
    Row() {
      Image($r('sys.media.ohos_ic_public_arrow_left'))
        .width(24)
        .height(24)
        .fillColor(this.colors.GRAY_900)
        .onClick(() => this.onBack())

      Column() {
        Text('微语境学习')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontColor(this.colors.GRAY_900)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)

        Text(`第 ${Math.min(this.taskIndex + 1, this.taskQueueLength)} / ${this.taskQueueLength} 个单词`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_600)

        Progress({
          value: Math.min(this.taskIndex + 1, this.taskQueueLength),
          total: Math.max(1, this.taskQueueLength),
          type: ProgressType.Linear
        })
          .width(120)
          .height(4)
          .color(this.colors.PRIMARY)
          .backgroundColor(this.colors.GRAY_300)
          .margin({ top: DesignTokens.Spacing.XS })
      }
      .margin({ left: DesignTokens.Spacing.LG })

      Blank()

      Button('撤回')
        .height(36)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.canUndo ? this.colors.PRIMARY : this.colors.GRAY_400)
        .backgroundColor(this.canUndo ? this.colors.PRIMARY_LIGHTEST : this.colors.GRAY_200)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .enabled(this.canUndo)
        .onClick(() => this.onUndo())
    }
    .width('100%')
    .height(68)
    .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING })
    .backgroundColor(this.colors.SURFACE_ELEVATED)
  }
}
