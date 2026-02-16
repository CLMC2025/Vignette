import { DesignTokens } from '../model/DesignTokens';

export interface AchievementData {
  icon: string;
  title: string;
  description: string;
  progress?: number;
  total?: number;
}

@Component
export struct AchievementBanner {
  @Prop streakDays: number = 0;
  @Prop totalWords: number = 0;
  @Prop todayGoal: number = 0;
  @Prop todayDone: number = 0;
  @State private isPressed: boolean = false;
  @State private shimmerOffset: number = -100;
  onBannerClick?: () => void;

  aboutToAppear(): void {
    this.startShimmerAnimation();
  }

  private startShimmerAnimation(): void {
    const animate = (): void => {
      animateTo({
        duration: 2500,
        curve: Curve.Linear,
        onFinish: () => {
          this.shimmerOffset = -100;
          setTimeout(() => animate(), 800);
        }
      }, () => {
        this.shimmerOffset = 500;
      });
    };
    setTimeout(() => animate(), 500);
  }

  private getStreakMessage(): string {
    if (this.streakDays === 0) {
      return '开始你的学习之旅';
    } else if (this.streakDays < 7) {
      return '良好的开始！';
    } else if (this.streakDays < 30) {
      return '坚持就是胜利！';
    } else if (this.streakDays < 100) {
      return '学习达人！';
    } else {
      return '传奇学习者！';
    }
  }

  private getNextMilestone(): number {
    const milestones = [7, 14, 30, 60, 100, 365];
    for (const milestone of milestones) {
      if (this.streakDays < milestone) {
        return milestone;
      }
    }
    return 365;
  }

  private getProgressToNextMilestone(): number {
    const next = this.getNextMilestone();
    const prev = this.streakDays < 7 ? 0 :
                 this.streakDays < 14 ? 7 :
                 this.streakDays < 30 ? 14 :
                 this.streakDays < 60 ? 30 :
                 this.streakDays < 100 ? 60 : 100;
    return ((this.streakDays - prev) / (next - prev)) * 100;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [
            [DesignTokens.Colors.WARNING as string, 0],
            [DesignTokens.Colors.WARNING_DARK as string, 1]
          ]
        })
        .borderRadius(DesignTokens.BorderRadius.XL)

      Column()
        .width(80)
        .height('100%')
        .linearGradient({
          angle: 90,
          colors: [
            ['transparent', 0],
            ['rgba(255,255,255,0.3)', 0.5],
            ['transparent', 1]
          ]
        })
        .position({ x: this.shimmerOffset, y: 0 })

      Row({ space: DesignTokens.Spacing.MD }) {
        Column() {
          Text(this.streakDays >= 100 ? '🏆' : '🔥')
            .fontSize(32)
        }
        .width(56)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(255,255,255,0.2)')
        .borderRadius(DesignTokens.BorderRadius.LG)

        Column({ space: 4 }) {
          Text(`连续学习 ${this.streakDays} 天`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(DesignTokens.Colors.WHITE)

          Text(this.getStreakMessage())
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor('rgba(255,255,255,0.85)')

          Row({ space: 8 }) {
            Progress({
              value: this.getProgressToNextMilestone(),
              total: 100,
              type: ProgressType.Linear
            })
              .width(100)
              .height(4)
              .color(DesignTokens.Colors.WHITE)
              .backgroundColor('rgba(255,255,255,0.3)')
              .borderRadius(2)

            Text(`距离 ${this.getNextMilestone()} 天`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
              .fontColor('rgba(255,255,255,0.7)')
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text('›')
            .fontSize(24)
            .fontColor('rgba(255,255,255,0.8)')
        }
      }
      .width('100%')
      .height('100%')
      .padding(DesignTokens.Spacing.LG)
    }
    .width('100%')
    .height(88)
    .borderRadius(DesignTokens.BorderRadius.XL)
    .shadow({
      radius: 12,
      color: 'rgba(255, 152, 0, 0.3)',
      offsetX: 0,
      offsetY: 6,
      fill: true
    })
    .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
    .onClick(() => {
      if (this.onBannerClick) {
        this.onBannerClick();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
          this.isPressed = true;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
          this.isPressed = false;
        });
      }
    })
    .clip(true)
  }
}

@Component
export struct MiniAchievementBadge {
  @Prop streakDays: number = 0;
  @Prop badgeSize: number = 48;

  private getBadgeIcon(): string {
    if (this.streakDays >= 100) return '🏆';
    if (this.streakDays >= 30) return '⭐';
    if (this.streakDays >= 7) return '🔥';
    return '🌱';
  }

  private getBadgeColor(): ResourceColor {
    if (this.streakDays >= 100) return DesignTokens.Colors.WARNING;
    if (this.streakDays >= 30) return DesignTokens.Colors.SUCCESS;
    if (this.streakDays >= 7) return DesignTokens.Colors.ERROR;
    return DesignTokens.Colors.INFO;
  }

  build() {
    Stack() {
      Column()
        .width(this.badgeSize)
        .height(this.badgeSize)
        .backgroundColor(this.getBadgeColor())
        .borderRadius(this.badgeSize / 2)

      Text(this.getBadgeIcon())
        .fontSize(this.badgeSize * 0.45)
    }
    .width(this.badgeSize)
    .height(this.badgeSize)
  }
}

@Component
export struct MilestoneCard {
  @Prop currentStreak: number = 0;
  @Prop milestone: number = 7;
  @Prop icon: string = '🎯';
  @Prop reward: string = '初级学者';
  @State private isPressed: boolean = false;

  private isCompleted(): boolean {
    return this.currentStreak >= this.milestone;
  }

  private getProgress(): number {
    return Math.min(100, (this.currentStreak / this.milestone) * 100);
  }

  build() {
    Row({ space: DesignTokens.Spacing.MD }) {
      Column() {
        Text(this.icon)
          .fontSize(24)
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.isCompleted() ? DesignTokens.Colors.SUCCESS_LIGHTEST : DesignTokens.Colors.GRAY_100)
      .borderRadius(DesignTokens.BorderRadius.LG)

      Column({ space: 4 }) {
        Text(`${this.milestone}天连续学习`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.TEXT_PRIMARY)

        Text(this.reward)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.TEXT_SECONDARY)

        Progress({
          value: this.getProgress(),
          total: 100,
          type: ProgressType.Linear
        })
          .width('100%')
          .height(4)
          .color(this.isCompleted() ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.PRIMARY)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(2)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.isCompleted()) {
        Column() {
          Text('✓')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(DesignTokens.Colors.WHITE)
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(DesignTokens.Colors.SUCCESS)
        .borderRadius(14)
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    .opacity(this.isCompleted() ? 1 : 0.8)
    .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
          this.isPressed = true;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
          this.isPressed = false;
        });
      }
    })
  }
}

@Component
export struct WordCountBadge {
  @Prop totalWords: number = 0;
  @State private animatedCount: number = 0;

  aboutToAppear(): void {
    animateTo({
      duration: 1000,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.animatedCount = this.totalWords;
    });
  }

  private getLevel(): string {
    if (this.totalWords < 100) return '初学者';
    if (this.totalWords < 500) return '入门者';
    if (this.totalWords < 1000) return '进阶者';
    if (this.totalWords < 3000) return '熟练者';
    if (this.totalWords < 5000) return '精通者';
    return '大师';
  }

  private getLevelColor(): ResourceColor {
    if (this.totalWords < 100) return DesignTokens.Colors.GRAY_500;
    if (this.totalWords < 500) return DesignTokens.Colors.INFO;
    if (this.totalWords < 1000) return DesignTokens.Colors.SUCCESS;
    if (this.totalWords < 3000) return DesignTokens.Colors.PRIMARY;
    if (this.totalWords < 5000) return DesignTokens.Colors.PURPLE;
    return DesignTokens.Colors.WARNING;
  }

  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      Column() {
        Text('📚')
          .fontSize(20)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.getLevelColor() as string)
      .borderRadius(DesignTokens.BorderRadius.LG)

      Column({ space: 2 }) {
        Row({ space: 4 }) {
          Text(String(this.animatedCount))
            .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(DesignTokens.Colors.TEXT_PRIMARY)

          Text('词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
        }

        Text(this.getLevel())
          .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
          .fontColor(this.getLevelColor())
          .fontWeight(FontWeight.Medium)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding(DesignTokens.Spacing.SM)
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
  }
}
