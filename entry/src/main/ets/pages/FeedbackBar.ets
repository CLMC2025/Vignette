import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

export enum FlashButton {
  NONE = 'NONE',
  FORGET = 'FORGET',
  HARD = 'HARD',
  REMEMBER = 'REMEMBER',
  EASY = 'EASY',
  UNDO = 'UNDO'
}

export interface IntervalHints {
  again: string;
  hard: string;
  good: string;
  easy: string;
}

@Component
export struct FeedbackBar {
  @Prop flashButton: FlashButton;
  @Prop isReviewCooling: boolean;
  @Prop isFirstContextWord: boolean;
  @Prop intervalHints: IntervalHints;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  onForget: () => void = () => {};
  onHard: () => void = () => {};
  onRemember: () => void = () => {};
  onEasy: () => void = () => {};
  onShowHint: (msg: string) => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getForgetButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.FORGET ? this.colors.ERROR_LIGHT : this.colors.ERROR;
  }

  private getHardButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.HARD ? this.colors.WARNING_LIGHT : this.colors.WARNING;
  }

  private getRememberButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.REMEMBER ? this.colors.SUCCESS_LIGHT : this.colors.SUCCESS;
  }

  private getEasyButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.EASY ? this.colors.PRIMARY_LIGHT : this.colors.PRIMARY;
  }

  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      Button() {
        Column() {
          Text('重来')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
            .fontColor(this.colors.WHITE)

          if (this.intervalHints.again.length > 0) {
            Text(this.intervalHints.again)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor(this.colors.WHITE)
              .opacity(0.85)
              .margin({ top: DesignTokens.Spacing.XS })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
        .layoutWeight(1)
        .height(52)
        .backgroundColor(this.getForgetButtonBg())
        .borderRadius(DesignTokens.BorderRadius.XL)
        .enabled(!this.isReviewCooling)
        .stateEffect(true)
        .onClick(() => this.onForget())
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              this.onShowHint('这个单词会很快再次出现');
            })
        )

      if (!this.isFirstContextWord) {
        Button() {
          Column() {
            Text('困难')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
              .fontColor(this.colors.WHITE)

            if (this.intervalHints.hard.length > 0) {
              Text(this.intervalHints.hard)
                .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
                .fontColor(this.colors.WHITE)
                .opacity(0.85)
                .margin({ top: DesignTokens.Spacing.XS })
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
          .layoutWeight(1)
          .height(52)
          .backgroundColor(this.getHardButtonBg())
          .borderRadius(DesignTokens.BorderRadius.XL)
          .enabled(!this.isReviewCooling)
          .stateEffect(true)
          .onClick(() => this.onHard())
          .gesture(
            LongPressGesture({ repeat: false, duration: 500 })
              .onAction(() => {
                this.onShowHint('这个单词会在较短时间内再次复习');
              })
          )
      }

      Button() {
        Column() {
          Text('良好')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
            .fontColor(this.colors.WHITE)

          if (this.intervalHints.good.length > 0) {
            Text(this.intervalHints.good)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor(this.colors.WHITE)
              .opacity(0.85)
              .margin({ top: DesignTokens.Spacing.XS })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
        .layoutWeight(1)
        .height(52)
        .backgroundColor(this.getRememberButtonBg())
        .borderRadius(DesignTokens.BorderRadius.XL)
        .enabled(!this.isReviewCooling)
        .stateEffect(true)
        .onClick(() => this.onRemember())
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              this.onShowHint('按默认间隔复习');
            })
        )

      Button() {
        Column() {
          Text('简单')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
            .fontColor(this.colors.WHITE)

          if (this.intervalHints.easy.length > 0) {
            Text(this.intervalHints.easy)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor(this.colors.WHITE)
              .opacity(0.85)
              .margin({ top: DesignTokens.Spacing.XS })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
        .layoutWeight(1)
        .height(52)
        .backgroundColor(this.getEasyButtonBg())
        .borderRadius(DesignTokens.BorderRadius.XL)
        .enabled(!this.isReviewCooling)
        .stateEffect(true)
        .onClick(() => this.onEasy())
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              this.onShowHint('延长复习间隔');
            })
        )
    }
    .width('100%')
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      bottom: DesignTokens.Spacing.LG
    })
    .backgroundColor(this.colors.SURFACE_ELEVATED)
  }
}
