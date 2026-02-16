import { DesignTokens } from '../../../model/DesignTokens';
import { ColorsInterface } from '../../../model/TokenInterfaces';
import { ThemeManager } from '../../../manager/ThemeManager';

export interface StatCardData {
  icon: string;
  value: number | string;
  label: string;
  color: ResourceColor;
}

@Component
export struct StatCard {
  @Prop icon: string = '';
  @Prop value: number | string = 0;
  @Prop label: string = '';
  @Prop color: ResourceColor = this.colors.PRIMARY;
  @Prop cardWidth: number = 80;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  build() {
    Column() {
      Text(this.icon)
        .fontSize(24)
        .margin({ bottom: DesignTokens.Spacing.XS })

      Text(typeof this.value === 'number' ? String(this.value) : this.value)
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(this.color)

      Text(this.label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
        .fontColor(this.colors.TEXT_SECONDARY)
        .margin({ top: 2 })
    }
    .width(this.cardWidth)
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct StatCardRow {
  @Prop stats: StatCardData[] = [];
  @State private scrollOffset: number = 0;

  build() {
    if (this.stats.length === 0) {
      Row() {}
    } else {
      Row() {
        ForEach(this.stats, (stat: StatCardData) => {
          StatCard({
            icon: stat.icon,
            value: stat.value,
            label: stat.label,
            color: stat.color,
            cardWidth: 80
          })
        }, (stat: StatCardData, index: number) => `${stat.label}-${index}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
  }
}
