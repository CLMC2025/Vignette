import { DesignTokens } from '../model/DesignTokens';
import { SpringAnimator, SpringPresets } from '../ui/SpringAnimations';

export interface GlassCardStyle {
  blurRadius: number;
  backgroundColor: ResourceColor;
  borderColor: ResourceColor;
  borderWidth: number;
  borderRadius: number;
  opacity: number;
  shadowRadius: number;
  shadowColor: ResourceColor;
}

export class GlassCardConfig {
  style: GlassCardStyle;
  padding: number;
  enableGradient: boolean;
  gradientColors: Array<[ResourceColor, number]>;

  constructor() {
    this.style = {
      blurRadius: 20,
      backgroundColor: 'rgba(255, 255, 255, 0.7)',
      borderColor: 'rgba(255, 255, 255, 0.3)',
      borderWidth: 1,
      borderRadius: DesignTokens.BorderRadius.XL,
      opacity: 0.9,
      shadowRadius: 16,
      shadowColor: 'rgba(0, 0, 0, 0.1)'
    };
    this.padding = DesignTokens.Spacing.XL;
    this.enableGradient = false;
    this.gradientColors = [['rgba(255, 255, 255, 0.8)', 0], ['rgba(255, 255, 255, 0.4)', 1]];
  }

  static default(): GlassCardConfig {
    return new GlassCardConfig();
  }

  static primary(): GlassCardConfig {
    const config = new GlassCardConfig();
    config.style.backgroundColor = 'rgba(0, 125, 255, 0.15)';
    config.style.borderColor = 'rgba(0, 125, 255, 0.3)';
    config.gradientColors = [['rgba(0, 125, 255, 0.2)', 0], ['rgba(0, 125, 255, 0.05)', 1]];
    config.enableGradient = true;
    return config;
  }

  static elevated(): GlassCardConfig {
    const config = new GlassCardConfig();
    config.style.shadowRadius = 24;
    config.style.shadowColor = 'rgba(0, 0, 0, 0.15)';
    config.style.blurRadius = 30;
    return config;
  }

  static dark(): GlassCardConfig {
    const config = new GlassCardConfig();
    config.style.backgroundColor = 'rgba(30, 30, 30, 0.8)';
    config.style.borderColor = 'rgba(255, 255, 255, 0.1)';
    config.style.shadowColor = 'rgba(0, 0, 0, 0.3)';
    config.gradientColors = [['rgba(50, 50, 50, 0.9)', 0], ['rgba(30, 30, 30, 0.7)', 1]];
    config.enableGradient = true;
    return config;
  }
}

@Component
export struct GlassCard {
  @Prop config: GlassCardConfig = GlassCardConfig.default();
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  onCardClick?: () => void;

  private handlePress(): void {
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 80 }, () => {
      this.scaleValue = 0.97;
      this.isPressed = true;
    });
  }

  private handleRelease(): void {
    SpringAnimator.animate(SpringPresets.BOUNCY, { duration: 400 }, () => {
      this.scaleValue = 1;
      this.isPressed = false;
    });
  }

  build() {
    Column() {
      Column() {
        Column() {
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.config.style.backgroundColor)
        .borderRadius(this.config.style.borderRadius)
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }
    .width('100%')
    .padding(this.config.padding)
    .border({
      width: this.config.style.borderWidth,
      color: this.config.style.borderColor
    })
    .borderRadius(this.config.style.borderRadius)
    .shadow({
      radius: this.config.style.shadowRadius,
      color: this.config.style.shadowColor,
      offsetX: 0,
      offsetY: 8,
      fill: true
    })
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .opacity(this.isPressed ? 0.95 : 1)
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.handlePress();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.handleRelease();
      }
    })
  }
}

@Component
export struct GradientGlassCard {
  @Prop gradientColors: Array<[ResourceColor, number]> = [
    [DesignTokens.Colors.PRIMARY as string, 0],
    [DesignTokens.Colors.PRIMARY_DARK as string, 1]
  ];
  @Prop borderRadius: number = DesignTokens.BorderRadius.XL;
  @Prop padding: number = DesignTokens.Spacing.XL;
  @Prop enableGlow: boolean = true;
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  onCardClick?: () => void;

  private handlePress(): void {
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 80 }, () => {
      this.scaleValue = 0.97;
      this.isPressed = true;
    });
  }

  private handleRelease(): void {
    SpringAnimator.animate(SpringPresets.ELASTIC, { duration: 450 }, () => {
      this.scaleValue = 1;
      this.isPressed = false;
    });
  }

  build() {
    Stack() {
      if (this.enableGlow) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 135,
            colors: this.gradientColors
          })
          .blur(20)
          .opacity(0.5)
          .borderRadius(this.borderRadius)
          .position({ x: 0, y: 10 })
      }

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: this.gradientColors
        })
        .borderRadius(this.borderRadius)
        .shadow({
          radius: this.enableGlow ? 20 : 8,
          color: this.gradientColors[0][0] as string,
          offsetX: 0,
          offsetY: this.enableGlow ? 12 : 4,
          fill: true
        })
    }
    .width('100%')
    .padding(this.padding)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.handlePress();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.handleRelease();
      }
    })
  }
}

@Component
export struct ShimmerGlassCard {
  @Prop borderRadius: number = DesignTokens.BorderRadius.XL;
  @Prop padding: number = DesignTokens.Spacing.XL;
  @Prop baseColor: ResourceColor = 'rgba(255, 255, 255, 0.8)';
  @Prop shimmerColor: ResourceColor = 'rgba(255, 255, 255, 0.95)';
  @State private shimmerPosition: number = -100;
  private shimmerAnimation: boolean = false;

  aboutToAppear(): void {
    this.startShimmer();
  }

  private startShimmer(): void {
    if (this.shimmerAnimation) return;
    this.shimmerAnimation = true;
    
    const animate = (): void => {
      animateTo({
        duration: 2000,
        curve: Curve.Linear,
        onFinish: () => {
          this.shimmerPosition = -100;
          setTimeout(() => animate(), 500);
        }
      }, () => {
        this.shimmerPosition = 400;
      });
    };
    animate();
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.baseColor)
        .borderRadius(this.borderRadius)

      Column()
        .width(100)
        .height('100%')
        .linearGradient({
          angle: 90,
          colors: [
            ['transparent', 0],
            [this.shimmerColor as string, 0.5],
            ['transparent', 1]
          ]
        })
        .borderRadius(this.borderRadius)
        .position({ x: this.shimmerPosition, y: 0 })
        .clip(true)
    }
    .width('100%')
    .padding(this.padding)
    .borderRadius(this.borderRadius)
    .border({
      width: 1,
      color: 'rgba(255, 255, 255, 0.3)'
    })
    .shadow({
      radius: 12,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetX: 0,
      offsetY: 4,
      fill: true
    })
    .clip(true)
  }
}

@Component
export struct InteractiveGlassCard {
  @Prop height: number | string = 'auto';
  @Prop borderRadius: number = DesignTokens.BorderRadius.XL;
  @Prop padding: number = DesignTokens.Spacing.XL;
  @State private isHovered: boolean = false;
  @State private isPressed: boolean = false;
  @State private elevation: number = 4;
  @State private scaleValue: number = 1;
  onCardClick?: () => void;

  private getBackgroundColor(): ResourceColor {
    if (this.isPressed) {
      return 'rgba(255, 255, 255, 0.85)';
    }
    if (this.isHovered) {
      return 'rgba(255, 255, 255, 0.8)';
    }
    return 'rgba(255, 255, 255, 0.7)';
  }

  private handleHover(isHover: boolean): void {
    SpringAnimator.animate(SpringPresets.GENTLE, { duration: 300 }, () => {
      this.isHovered = isHover;
      this.elevation = isHover ? 8 : 4;
    });
  }

  private handlePress(): void {
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 80 }, () => {
      this.isPressed = true;
      this.elevation = 2;
      this.scaleValue = 0.98;
    });
  }

  private handleRelease(): void {
    SpringAnimator.animate(SpringPresets.BOUNCY, { duration: 400 }, () => {
      this.isPressed = false;
      this.elevation = 4;
      this.scaleValue = 1;
    });
  }

  build() {
    Column()
      .width('100%')
      .height(this.height)
      .padding(this.padding)
      .backgroundColor(this.getBackgroundColor())
      .borderRadius(this.borderRadius)
      .border({
        width: 1,
        color: 'rgba(255, 255, 255, 0.4)'
      })
      .shadow({
        radius: this.elevation * 2,
        color: `rgba(0, 0, 0, ${0.05 + this.elevation * 0.01})`,
        offsetX: 0,
        offsetY: this.elevation,
        fill: true
      })
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .onClick(() => {
        if (this.onCardClick) {
          this.onCardClick();
        }
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.handlePress();
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.handleRelease();
        }
      })
  }
}
