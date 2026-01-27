// =====================================================
// LoadingAnimations.ets - 自定义加载动画组件
// 提供各种生动有趣的加载动画效果
// =====================================================

import { DesignTokens } from '../model/DesignTokens';

/**
 * 加载动画类型
 */
export enum LoadingType {
  SPINNER = 'spinner',
  PULSE = 'pulse',
  WAVE = 'wave',
  DOTS = 'dots',
  BOUNCING_BALLS = 'bouncing_balls'
}

/**
 * 基础加载动画配置
 */
export interface LoadingConfig {
  type?: LoadingType;
  size?: number;
  color?: ResourceColor;
  duration?: number;
}

/**
 * 旋转加载动画组件
 */
@Component
struct SpinnerAnimation {
  @Prop animSize: number;
  @Prop color: ResourceColor;
  @Prop duration: number;

  build() {
    Stack() {
      Circle()
        .width(this.animSize)
        .height(this.animSize)
        .stroke(this.color)
        .strokeWidth(4)
        .fill(Color.Transparent)
        .rotate({ angle: 0 })
        .animation({
          duration: this.duration,
          curve: Curve.Linear,
          iterations: -1,
          playMode: PlayMode.Normal
        })
    }
    .width(this.animSize)
    .height(this.animSize)
  }
}

/**
 * 脉冲加载动画组件
 */
@Component
struct PulseAnimation {
  @Prop animSize: number;
  @Prop color: ResourceColor;
  @Prop duration: number;

  build() {
    Stack() {
      Circle()
        .width(this.animSize)
        .height(this.animSize)
        .fill(this.color)
        .opacity(0.6)
        .scale({ x: 0.8, y: 0.8 })
        .animation({
          duration: this.duration,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })
        
      Circle()
        .width(this.animSize * 0.6)
        .height(this.animSize * 0.6)
        .fill(this.color)
        .opacity(0.8)
        .animation({
          duration: this.duration,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })
      
      Circle()
        .width(this.animSize * 0.4)
        .height(this.animSize * 0.4)
        .fill(this.color)
        .animation({
          duration: this.duration,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })
    }
    .width(this.animSize)
    .height(this.animSize)
  }
}

/**
 * 波浪加载动画组件
 */
@Component
struct WaveAnimation {
  @Prop animSize: number;
  @Prop color: ResourceColor;
  @Prop duration: number;

  build() {
    Row() {
      ForEach([1, 2, 3, 4, 5], (index: number) => {
        Column() {
          Circle()
            .width(this.animSize * 0.15)
            .height(this.animSize * 0.15)
            .fill(this.color)
            .scale({ y: 0.5 })
            .animation({
              duration: this.duration,
              curve: Curve.EaseInOut,
              delay: index * 100,
              iterations: -1,
              playMode: PlayMode.Alternate
            })
        }
        .margin({ left: this.animSize * 0.05, right: this.animSize * 0.05 })
      })
    }
    .width(this.animSize)
    .height(this.animSize)
    .justifyContent(FlexAlign.Center)
  }
}

/**
 * 圆点加载动画组件
 */
@Component
struct DotsAnimation {
  @Prop animSize: number;
  @Prop color: ResourceColor;
  @Prop duration: number;

  build() {
    Stack() {
      ForEach([0, 120, 240], (angle: number, index: number) => {
        Circle()
          .width(this.animSize * 0.2)
          .height(this.animSize * 0.2)
          .fill(this.color)
          .position({
            x: this.animSize / 2 - Math.cos(angle * Math.PI / 180) * this.animSize * 0.3,
            y: this.animSize / 2 - Math.sin(angle * Math.PI / 180) * this.animSize * 0.3
          })
          .opacity(0.3 + (index % 3) * 0.35)
          .animation({
            duration: this.duration,
            curve: Curve.EaseInOut,
            delay: index * 200,
            iterations: -1,
            playMode: PlayMode.Alternate
          })
      })
    }
    .width(this.animSize)
    .height(this.animSize)
    .alignContent(Alignment.Center)
  }
}

/**
 * 弹跳小球加载动画组件
 */
@Component
struct BouncingBallsAnimation {
  @Prop animSize: number;
  @Prop color: ResourceColor;
  @Prop duration: number;

  build() {
    Row() {
      ForEach([0, 1, 2], (index: number) => {
        Column() {
          Circle()
            .width(this.animSize * 0.2)
            .height(this.animSize * 0.2)
            .fill(this.color)
            .translate({ y: 0 })
            .animation({
              duration: this.duration,
              curve: Curve.EaseOut,
              delay: index * 100,
              iterations: -1,
              playMode: PlayMode.Alternate
            })
        }
        .margin({ left: this.animSize * 0.05, right: this.animSize * 0.05 })
      })
    }
    .width(this.animSize)
    .height(this.animSize)
    .justifyContent(FlexAlign.Center)
  }
}

/**
 * 通用加载动画组件
 */
@Component
export struct LoadingAnimation {
  @Prop type: LoadingType = LoadingType.SPINNER;
  @Prop animSize: number = 48;
  @Prop color: ResourceColor = DesignTokens.Colors.PRIMARY;
  @Prop text?: string;
  @Prop duration?: number;

  /**
   * 获取动画持续时间
   */
  private getAnimDuration(): number {
    return this.duration || (this.type === LoadingType.PULSE ? 1500 : 1000);
  }

  build() {
    Column() {
      if (this.type === LoadingType.SPINNER) {
        SpinnerAnimation({
          animSize: this.animSize,
          color: this.color,
          duration: this.getAnimDuration()
        });
      } else if (this.type === LoadingType.PULSE) {
        PulseAnimation({
          animSize: this.animSize,
          color: this.color,
          duration: this.getAnimDuration()
        });
      } else if (this.type === LoadingType.WAVE) {
        WaveAnimation({
          animSize: this.animSize,
          color: this.color,
          duration: this.getAnimDuration()
        });
      } else if (this.type === LoadingType.DOTS) {
        DotsAnimation({
          animSize: this.animSize,
          color: this.color,
          duration: this.getAnimDuration()
        });
      } else if (this.type === LoadingType.BOUNCING_BALLS) {
        BouncingBallsAnimation({
          animSize: this.animSize,
          color: this.color,
          duration: this.getAnimDuration()
        });
      }

      if (this.text) {
        Text(this.text)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.MD })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }
}

// 移除重复导出语句
