// =====================================================
// TopBanner.ets - Global top banner component
// =====================================================

import { DesignTokens } from '../model/DesignTokens';

export enum TopBannerType {
  ERROR = 'ERROR',
  WARNING = 'WARNING',
  INFO = 'INFO'
}

@Component
export struct TopBanner {
  @Prop message: string;
  @Prop type: TopBannerType = TopBannerType.INFO;
  @Prop primaryLabel: string = '';
  @Prop secondaryLabel: string = '';
  @Prop onPrimary?: () => void;
  @Prop onSecondary?: () => void;

  private getBackgroundColor(): ResourceColor {
    switch (this.type) {
      case TopBannerType.ERROR:
        return DesignTokens.Colors.ERROR;
      case TopBannerType.WARNING:
        return DesignTokens.Colors.WARNING;
      case TopBannerType.INFO:
      default:
        return DesignTokens.Colors.GRAY_700;
    }
  }

  build() {
    Row() {
      Text(this.message)
        .fontSize(12)
        .fontColor(DesignTokens.Colors.WHITE)
        .layoutWeight(1)
        .maxLines(2)

      if (this.primaryLabel.length > 0 && this.onPrimary) {
        Button(this.primaryLabel)
          .fontSize(12)
          .height(28)
          .backgroundColor(DesignTokens.Colors.WHITE)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .borderRadius(14)
          .margin({ left: DesignTokens.Spacing.SM })
          .onClick(() => {
            if (this.onPrimary) {
              this.onPrimary();
            }
          })
      }

      if (this.secondaryLabel.length > 0 && this.onSecondary) {
        Button(this.secondaryLabel)
          .fontSize(12)
          .height(28)
          .backgroundColor(DesignTokens.Colors.WHITE + 'CC')
          .fontColor(DesignTokens.Colors.GRAY_900)
          .borderRadius(14)
          .margin({ left: DesignTokens.Spacing.SM })
          .onClick(() => {
            if (this.onSecondary) {
              this.onSecondary();
            }
          })
      }
    }
    .width('100%')
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG,
      top: DesignTokens.Spacing.SM,
      bottom: DesignTokens.Spacing.SM
    })
    .backgroundColor(this.getBackgroundColor())
    .position({ x: 0, y: 0 })
    .zIndex(200)
  }
}
