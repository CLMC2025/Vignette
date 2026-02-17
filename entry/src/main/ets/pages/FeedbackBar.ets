import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import vibrator from '@ohos.vibrator';

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

  /**
   * Provide haptic feedback on button press
   */
  private triggerHapticFeedback(intensity: 'light' | 'medium' | 'heavy' = 'medium'): void {
    try {
      const duration = intensity === 'light' ? 10 : (intensity === 'medium' ? 20 : 35);
      vibrator.startVibration({
        type: 'time',
        duration: duration
      });
    } catch (e) {
      // Haptic feedback not critical, silently ignore errors
    }
  }

  private getForgetButtonBg(): ResourceColor {
    if (!this.isReviewCooling) {
      return this.flashButton === FlashButton.FORGET ? this.colors.ERROR_LIGHT : this.colors.ERROR;
    }
    // Disabled state: dimmed version
    return this.colors.GRAY_300;
  }

  private getHardButtonBg(): ResourceColor {
    if (!this.isReviewCooling) {
      return this.flashButton === FlashButton.HARD ? this.colors.WARNING_LIGHT : this.colors.WARNING;
    }
    return this.colors.GRAY_300;
  }

  private getRememberButtonBg(): ResourceColor {
    if (!this.isReviewCooling) {
      return this.flashButton === FlashButton.REMEMBER ? this.colors.SUCCESS_LIGHT : this.colors.SUCCESS;
    }
    return this.colors.GRAY_300;
  }

  private getEasyButtonBg(): ResourceColor {
    if (!this.isReviewCooling) {
      return this.flashButton === FlashButton.EASY ? this.colors.PRIMARY_LIGHT : this.colors.PRIMARY;
    }
    return this.colors.GRAY_300;
  }

  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      Button() {
        Column() {
          Text('重来')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
            .fontColor(this.colors.WHITE)
            .opacity(this.isReviewCooling ? 0.5 : 1.0)

          if (this.intervalHints.again.length > 0) {
            Text(this.intervalHints.again)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor(this.colors.WHITE)
              .opacity(this.isReviewCooling ? 0.4 : 0.85)
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
        .accessibilityLevel('yes')
        .accessibilityText('重来：标记为不记得，这个单词会很快再次出现')
        .onClick(() => {
          this.triggerHapticFeedback('medium');
          this.onForget();
        })
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
              .opacity(this.isReviewCooling ? 0.5 : 1.0)

            if (this.intervalHints.hard.length > 0) {
              Text(this.intervalHints.hard)
                .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
                .fontColor(this.colors.WHITE)
                .opacity(this.isReviewCooling ? 0.4 : 0.85)
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
          .accessibilityLevel('yes')
          .accessibilityText('困难：记忆模糊，会在较短时间内再次复习')
          .onClick(() => {
            this.triggerHapticFeedback('light');
            this.onHard();
          })
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
            .opacity(this.isReviewCooling ? 0.5 : 1.0)

          if (this.intervalHints.good.length > 0) {
            Text(this.intervalHints.good)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor(this.colors.WHITE)
              .opacity(this.isReviewCooling ? 0.4 : 0.85)
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
        .accessibilityLevel('yes')
        .accessibilityText('良好：记忆清楚，按默认间隔复习')
        .onClick(() => {
          this.triggerHapticFeedback('light');
          this.onRemember();
        })
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
            .opacity(this.isReviewCooling ? 0.5 : 1.0)

          if (this.intervalHints.easy.length > 0) {
            Text(this.intervalHints.easy)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor(this.colors.WHITE)
              .opacity(this.isReviewCooling ? 0.4 : 0.85)
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
        .accessibilityLevel('yes')
        .accessibilityText('简单：记忆牢固，延长复习间隔')
        .onClick(() => {
          this.triggerHapticFeedback('light');
          this.onEasy();
        })
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
