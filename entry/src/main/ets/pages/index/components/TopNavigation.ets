import { DesignTokens } from '../../../model/DesignTokens';
import { ThemeManager } from '../../../manager/ThemeManager';
import { ColorsInterface } from '../../../model/TokenInterfaces';

@Component
export struct TopNavigation {
  onSettingsClick: () => void = () => {};
  @State private greetingText: string = '';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  aboutToAppear(): void {
    this.updateGreeting();
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private updateGreeting(): void {
    const hour = new Date().getHours();
    if (hour < 6) {
      this.greetingText = '夜深了';
    } else if (hour < 12) {
      this.greetingText = '早上好';
    } else if (hour < 14) {
      this.greetingText = '中午好';
    } else if (hour < 18) {
      this.greetingText = '下午好';
    } else if (hour < 22) {
      this.greetingText = '晚上好';
    } else {
      this.greetingText = '夜深了';
    }
  }

  build() {
    Row() {
      Row({ space: DesignTokens.Spacing.SM }) {
        Stack() {
          Column()
            .width(32)
            .height(32)
            .backgroundColor(this.colors.PRIMARY)
            .borderRadius(DesignTokens.BorderRadius.MD)

          Text('V')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors.WHITE)
        }

        Column({ space: 2 }) {
          Text('微语单词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.colors.TEXT_PRIMARY)

          Text(this.greetingText)
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(this.colors.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Column() {
        Text('⚙')
          .fontSize(20)
          .fontColor(this.colors.TEXT_SECONDARY)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.colors.SURFACE_PRIMARY)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .onClick(() => this.onSettingsClick())
    }
    .width('100%')
    .height(56)
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG
    })
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
  }
}

@Component
export struct CompactTopNavigation {
  title: string = '微语单词';
  onBackClick?: () => void;
  onSettingsClick?: () => void;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  build() {
    Row() {
      if (this.onBackClick) {
        Text('←')
          .fontSize(22)
          .fontColor(this.colors.TEXT_PRIMARY)
          .onClick(() => {
            if (this.onBackClick) {
              this.onBackClick();
            }
          })
          .padding({ right: DesignTokens.Spacing.SM })
      }

      Text(this.title)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(this.colors.TEXT_PRIMARY)
        .layoutWeight(1)

      if (this.onSettingsClick) {
        Text('⚙')
          .fontSize(20)
          .fontColor(this.colors.TEXT_SECONDARY)
          .onClick(() => {
            if (this.onSettingsClick) {
              this.onSettingsClick();
            }
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG
    })
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
  }
}
