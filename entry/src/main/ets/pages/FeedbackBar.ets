import { DesignTokens } from '../model/DesignTokens';

export enum FlashButton {
  NONE = 'NONE',
  FORGET = 'FORGET',
  HARD = 'HARD',
  REMEMBER = 'REMEMBER',
  EASY = 'EASY',
  UNDO = 'UNDO'
}

@Component
export struct FeedbackBar {
  @Prop flashButton: FlashButton;
  @Prop isReviewCooling: boolean;
  @Prop isFirstContextWord: boolean;

  onForget: () => void = () => {};
  onHard: () => void = () => {};
  onRemember: () => void = () => {};
  onEasy: () => void = () => {};
  onShowHint: (msg: string) => void = () => {};

  private getForgetButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.FORGET ? '#FF7961' : '#F44336';
  }

  private getHardButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.HARD ? '#FFB74D' : '#FF9800';
  }

  private getRememberButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.REMEMBER ? '#66BB6A' : '#4CAF50';
  }

  private getEasyButtonBg(): ResourceColor {
    return this.flashButton === FlashButton.EASY ? '#64B5F6' : '#2196F3';
  }

  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      // Again (Red)
      Button('重来')
        .layoutWeight(1)
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
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
        Button('困难')
          .layoutWeight(1)
          .height(48)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.WHITE)
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

      Button('良好')
        .layoutWeight(1)
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
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

      Button('简单')
        .layoutWeight(1)
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(DesignTokens.Colors.WHITE)
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
    .backgroundColor(DesignTokens.Colors.WHITE)
  }
}
