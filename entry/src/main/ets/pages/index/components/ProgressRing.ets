import { DesignTokens } from '../../../model/DesignTokens';
import { ColorsInterface } from '../../../model/TokenInterfaces';
import { ThemeManager } from '../../../manager/ThemeManager';

@Component
export struct ProgressRing {
  @Prop progress: number = 0;
  @Prop ringSize: number = 120;
  @Prop strokeWidth: number = 10;
  @Prop ringColor: ResourceColor = this.colors.PRIMARY;
  @Prop bgColor: ResourceColor = this.colors.BORDER_LIGHT;
  @Prop showPercent: boolean = true;
  @Prop centerText: string = '';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getDisplayPercent(): string {
    return `${Math.round(this.progress)}%`;
  }

  build() {
    Stack() {
      Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
        .width(this.ringSize)
        .height(this.ringSize)
        .color(this.ringColor)
        .style({ strokeWidth: this.strokeWidth })

      Column() {
        if (this.centerText.length > 0) {
          Text(this.centerText)
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.colors.TEXT_PRIMARY)
        } else if (this.showPercent) {
          Text(this.getDisplayPercent())
            .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.ringColor)
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width(this.ringSize)
    .height(this.ringSize)
  }
}

@Component
export struct AnimatedProgressRing {
  @Prop @Watch('onProgressChange') progress: number = 0;
  @State private animatedProgress: number = 0;
  @Prop ringSize: number = 120;
  @Prop strokeWidth: number = 10;
  @Prop ringColor: ResourceColor = this.colors.PRIMARY;
  @Prop bgColor: ResourceColor = this.colors.BORDER_LIGHT;
  @Prop showPercent: boolean = true;
  @Prop centerText: string = '';
  @Prop duration: number = 800;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    this.animatedProgress = 0;
    animateTo({
      duration: this.duration,
      curve: Curve.EaseOut
    }, () => {
      this.animatedProgress = Math.max(0, Math.min(100, this.progress));
    });
  }

  onProgressChange(): void {
    animateTo({
      duration: this.duration,
      curve: Curve.EaseOut
    }, () => {
      this.animatedProgress = Math.max(0, Math.min(100, this.progress));
    });
  }

  private getDisplayPercent(): string {
    return `${Math.round(this.animatedProgress)}%`;
  }

  build() {
    Stack() {
      Progress({ value: this.animatedProgress, total: 100, type: ProgressType.Ring })
        .width(this.ringSize)
        .height(this.ringSize)
        .color(this.ringColor)
        .style({ strokeWidth: this.strokeWidth })

      Column() {
        if (this.centerText.length > 0) {
          Text(this.centerText)
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.colors.TEXT_PRIMARY)
        } else if (this.showPercent) {
          Text(this.getDisplayPercent())
            .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.ringColor)
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width(this.ringSize)
    .height(this.ringSize)
  }
}
