import { DesignTokens } from '../../../model/DesignTokens';
import { ColorsInterface } from '../../../model/TokenInterfaces';
import { ThemeManager } from '../../../manager/ThemeManager';

@Component
export struct LearningProgressCard {
  @Prop todayDoneCount: number = 0;
  @Prop todayTotalCount: number = 0;
  @Prop newWordsToday: number = 0;
  @Prop reviewDue: number = 0;
  @Prop totalWords: number = 0;
  @Prop dailyNewWords: number = 10;
  @Prop streakDays: number = 0;
  onStartLearning: () => void = () => {};

  @State private animatedProgress: number = 0;
  @State private buttonScale: number = 1;
  @State private cardScale: number = 1;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    this.animateProgress();
  }

  private animateProgress(): void {
    animateTo({
      duration: 1000,
      curve: Curve.FastOutSlowIn,
      delay: 300
    }, () => {
      this.animatedProgress = this.getProgressPercent();
    });
  }

  private getProgressPercent(): number {
    if (this.todayTotalCount <= 0) {
      return 0;
    }
    return Math.min(100, Math.round((this.todayDoneCount / this.todayTotalCount) * 100));
  }

  private getProgressText(): string {
    return `${this.todayDoneCount}/${this.todayTotalCount}`;
  }

  private getGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 6) {
      return '夜深了，注意休息';
    } else if (hour < 12) {
      return '早上好，开始今日学习';
    } else if (hour < 14) {
      return '中午好，午休后学习';
    } else if (hour < 18) {
      return '下午好，继续加油';
    } else if (hour < 22) {
      return '晚上好，坚持学习';
    } else {
      return '夜深了，注意休息';
    }
  }

  private getMotivationalText(): string {
    const percent = this.getProgressPercent();
    if (percent === 0) {
      return '开始今天的学习之旅吧！';
    } else if (percent < 30) {
      return '好的开始，继续加油！';
    } else if (percent < 60) {
      return '进展顺利，保持节奏！';
    } else if (percent < 100) {
      return '即将完成，冲刺一下！';
    } else {
      return '太棒了！今日目标达成！🎉';
    }
  }

  private handleButtonPress(): void {
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      this.buttonScale = 0.95;
    });
  }

  private handleButtonRelease(): void {
    animateTo({
      duration: 150,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.buttonScale = 1;
    });
  }

  @Builder
  private buildStatItem(label: string, value: number, icon: string): void {
    Row({ space: 8 }) {
      Text(icon).fontSize(16)
      Column() {
        Text(String(value))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.WHITE)
        Text(label)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private buildProgressRing(): void {
    Stack() {
      Column()
        .width(80)
        .height(80)
        .borderRadius(40)
        .border({
          width: 6,
          color: 'rgba(255,255,255,0.2)'
        })

      Column()
        .width(80)
        .height(80)
        .borderRadius(40)
        .border({
          width: 6,
          color: this.colors.WHITE
        })
        .clip(true)

      Column() {
        Text(`${this.animatedProgress}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.WHITE)
      }
    }
  }

  build() {
    Stack() {
      Column()
        .width(200)
        .height(200)
        .borderRadius(100)
        .backgroundColor('rgba(255,255,255,0.05)')
        .position({ x: -80, y: -80 })

      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('rgba(255,255,255,0.03)')
        .position({ x: '70%', y: '50%' })

      Column() {
        Row() {
          Column({ space: 4 }) {
            Text(this.getGreeting())
              .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
              .fontColor(this.colors.WHITE)

            Text(this.getMotivationalText())
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor('rgba(255,255,255,0.8)')
              .margin({ top: 2 })

            if (this.streakDays > 0) {
              Row({ space: 6 }) {
                Text('🔥')
                  .fontSize(14)
                Text(`已连续坚持 ${this.streakDays} 天`)
                  .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                  .fontColor('rgba(255,255,255,0.95)')
                  .fontWeight(FontWeight.Medium)
              }
              .padding({
                left: 12,
                right: 12,
                top: 6,
                bottom: 6
              })
              .backgroundColor('rgba(255,255,255,0.15)')
              .borderRadius(DesignTokens.BorderRadius.FULL)
              .margin({ top: 8 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          this.buildProgressRing()
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row() {
          this.buildStatItem('新词', this.newWordsToday, '📖')
          Column()
            .width(1)
            .height(20)
            .backgroundColor('rgba(255,255,255,0.2)')
            .margin({ left: 16, right: 16 })
          this.buildStatItem('待复习', this.reviewDue, '🔄')
          Column()
            .width(1)
            .height(20)
            .backgroundColor('rgba(255,255,255,0.2)')
            .margin({ left: 16, right: 16 })
          this.buildStatItem('总词数', this.totalWords, '📚')
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: 24 })

        Blank()

        Button() {
          Row({ space: 8 }) {
            Text('▶')
              .fontSize(16)
              .fontColor(this.colors.PRIMARY)
            Text('开始今日学习')
              .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
              .fontColor(this.colors.PRIMARY)
          }
        }
        .width('100%')
        .height(50)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .type(ButtonType.Capsule)
        .margin({ top: 24 })
        .shadow({
          radius: 12,
          color: 'rgba(255,255,255,0.3)',
          offsetX: 0,
          offsetY: 4,
          fill: true
        })
        .scale({ x: this.buttonScale, y: this.buttonScale })
        .onClick(() => {
          this.onStartLearning();
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.handleButtonPress();
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.handleButtonRelease();
          }
        })
      }
      .padding(DesignTokens.Spacing.XL)
    }
    .width('100%')
    .height(260)
    .linearGradient({
      angle: 135,
      colors: [
        [this.colors.PRIMARY as string, 0],
        [this.colors.PRIMARY_DARK as string, 1]
      ]
    })
    .borderRadius(DesignTokens.BorderRadius.XL)
    .shadow({
      radius: 16,
      color: 'rgba(0, 125, 255, 0.35)',
      offsetX: 0,
      offsetY: 10,
      fill: true
    })
    .scale({ x: this.cardScale, y: this.cardScale })
  }
}

@Component
export struct CompactProgressCard {
  @Prop todayDoneCount: number = 0;
  @Prop todayTotalCount: number = 0;
  @Prop streakDays: number = 0;
  @State private animatedProgress: number = 0;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    animateTo({
      duration: 800,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.animatedProgress = this.getProgressPercent();
    });
  }

  private getProgressPercent(): number {
    if (this.todayTotalCount <= 0) {
      return 0;
    }
    return Math.min(100, Math.round((this.todayDoneCount / this.todayTotalCount) * 100));
  }

  build() {
    Row() {
      Stack() {
        Progress({ value: this.animatedProgress, total: 100, type: ProgressType.Ring })
          .width(56)
          .height(56)
          .color(this.colors.PRIMARY)
          .style({ strokeWidth: 4 })
          .backgroundColor(this.colors.GRAY_100)

        Text(`${this.animatedProgress}%`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.PRIMARY)
      }

      Column({ space: 4 }) {
        Text(`今日进度 ${this.todayDoneCount}/${this.todayTotalCount}`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(this.colors.TEXT_PRIMARY)

        if (this.streakDays > 0) {
          Row({ space: 4 }) {
            Text('🔥')
              .fontSize(12)
            Text(`连续学习 ${this.streakDays} 天`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(this.colors.TEXT_SECONDARY)
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: DesignTokens.Spacing.MD })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
  }
}

@Component
export struct MiniProgressCard {
  @Prop progress: number = 0;
  @Prop label: string = '今日进度';
  @Prop showStreak: boolean = false;
  @Prop streakDays: number = 0;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.label)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.TEXT_SECONDARY)

        Blank()

        Text(`${Math.round(this.progress)}%`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.PRIMARY)
      }
      .width('100%')

      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(6)
        .color(this.colors.PRIMARY)
        .backgroundColor(this.colors.GRAY_100)
        .borderRadius(3)

      if (this.showStreak && this.streakDays > 0) {
        Row({ space: 4 }) {
          Text('🔥')
            .fontSize(10)
          Text(`${this.streakDays}天连续`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(this.colors.TEXT_TERTIARY)
        }
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
  }
}
