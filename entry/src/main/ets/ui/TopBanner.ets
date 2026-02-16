// =====================================================
// TopBanner.ets - Global top banner component
// =====================================================

import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

export enum TopBannerType {
  NONE = 'NONE',
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
  @Prop showClose: boolean = true;
  onPrimary?: () => void;
  onSecondary?: () => void;
  onClose?: () => void;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getBackgroundColor(): ResourceColor {
    switch (this.type) {
      case TopBannerType.ERROR:
        return this.colors.ERROR_DARK;
      case TopBannerType.WARNING:
        return this.colors.WARNING_DARK;
      case TopBannerType.INFO:
      default:
        return this.colors.INFO_DARK;
    }
  }

  private getTextColor(): ResourceColor {
    if (this.type === TopBannerType.WARNING) {
      return this.colors.TEXT_PRIMARY;
    }
    return this.colors.WHITE;
  }

  private getActionBackgroundColor(): ResourceColor {
    switch (this.type) {
      case TopBannerType.ERROR:
        return this.colors.ERROR_LIGHTEST;
      case TopBannerType.WARNING:
        return this.colors.WARNING_LIGHTEST;
      case TopBannerType.INFO:
      default:
        return this.colors.INFO_LIGHTEST;
    }
  }

  private getActionTextColor(): ResourceColor {
    return this.colors.TEXT_PRIMARY;
  }

  build() {
    Row() {
      Text(this.message)
        .fontSize(12)
        .fontColor(this.getTextColor())
        .layoutWeight(1)
        .maxLines(2)

      if (this.primaryLabel.length > 0 && this.onPrimary) {
        Button(this.primaryLabel)
          .fontSize(12)
          .height(28)
          .backgroundColor(this.getActionBackgroundColor())
          .fontColor(this.getActionTextColor())
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
          .backgroundColor(this.getActionBackgroundColor())
          .fontColor(this.getActionTextColor())
          .borderRadius(14)
          .margin({ left: DesignTokens.Spacing.SM })
          .onClick(() => {
            if (this.onSecondary) {
              this.onSecondary();
            }
          })
      }

      // Close button
      if (this.showClose) {
        Text('✕')
          .fontSize(16)
          .fontColor(this.getTextColor())
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .margin({ left: DesignTokens.Spacing.SM })
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
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
