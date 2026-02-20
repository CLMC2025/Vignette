import { DesignTokens } from '../model/DesignTokens';
import { SpringAnimator, SpringPresets, SpringPreset, SpringCurves } from './SpringAnimations';
import { ThemeManager } from '../manager/ThemeManager';
import { ColorsInterface } from '../model/TokenInterfaces';

export type SpringCardVariant = 'elevated' | 'filled' | 'outlined' | 'glass';

@Component
export struct SpringCard {
  @Prop variant: SpringCardVariant = 'elevated';
  @Prop preset: SpringPreset = SpringPresets.BOUNCY;
  @Prop borderRadius: number = DesignTokens.BorderRadius.XL;
  @Prop padding: number = DesignTokens.Spacing.LG;
  @Prop disabled: boolean = false;
  @Prop enableScale: boolean = true;
  @Prop enableShadow: boolean = true;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  @State private elevation: number = 2;
  @State private isHovered: boolean = false;
  onClick?: () => void;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getBackgroundColor(): ResourceColor {
    const isDark = ThemeManager.getInstance().isDarkMode();

    switch (this.variant) {
      case 'elevated':
        return this.colors.SURFACE_PRIMARY;
      case 'filled':
        return isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.05)';
      case 'outlined':
        return 'transparent';
      case 'glass':
        return isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(255, 255, 255, 0.7)';
      default:
        return this.colors.SURFACE_PRIMARY;
    }
  }

  private getBorderColor(): ResourceColor {
    const isDark = ThemeManager.getInstance().isDarkMode();
    if (this.variant === 'outlined') {
      return this.colors.BORDER;
    }
    if (this.variant === 'glass') {
      return isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(255, 255, 255, 0.3)';
    }
    return 'transparent';
  }

  private handlePress(): void {
    if (this.disabled) return;
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 70 }, () => {
      this.isPressed = true;
      if (this.enableScale) {
        this.scaleValue = 0.97;
      }
      this.elevation = 1;
    });
  }

  private handleRelease(): void {
    if (this.disabled) return;
    SpringAnimator.animate(this.preset, { duration: 450 }, () => {
      this.isPressed = false;
      if (this.enableScale) {
        this.scaleValue = 1;
      }
      this.elevation = this.isHovered ? 4 : 2;
    });
  }

  build() {
    Column() {
    }
    .width('100%')
    .padding(this.padding)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(this.borderRadius)
    .border({
      width: this.variant === 'outlined' ? 1 : (this.variant === 'glass' ? 1 : 0),
      color: this.getBorderColor()
    })
    .shadow(this.enableShadow && this.variant === 'elevated' ? {
      radius: this.elevation * 4,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetX: 0,
      offsetY: this.elevation,
      fill: true
    } : {
      radius: 0,
      color: 'transparent',
      offsetX: 0,
      offsetY: 0
    })
    .opacity(this.disabled ? 0.5 : 1)
    .scale(this.enableScale ? { x: this.scaleValue, y: this.scaleValue } : { x: 1, y: 1 })
    .animation({
      duration: 200,
      curve: SpringCurves.gentle()
    })
    .onClick(() => {
      if (!this.disabled && this.onClick) {
        this.onClick();
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
export struct SpringListItem {
  @Prop preset: SpringPreset = SpringPresets.GENTLE;
  @Prop padding: number = DesignTokens.Spacing.MD;
  @Prop disabled: boolean = false;
  @Prop showDivider: boolean = true;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  onClick?: () => void;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private handlePress(): void {
    if (this.disabled) return;
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 60 }, () => {
      this.isPressed = true;
      this.scaleValue = 0.98;
    });
  }

  private handleRelease(): void {
    if (this.disabled) return;
    SpringAnimator.animate(this.preset, { duration: 350 }, () => {
      this.isPressed = false;
      this.scaleValue = 1;
    });
  }

  build() {
    Column() {
    }
    .width('100%')
    .padding(this.padding)
    .backgroundColor(this.isPressed ? this.colors.SURFACE_SECONDARY : 'transparent')
    .opacity(this.disabled ? 0.5 : 1)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .onClick(() => {
      if (!this.disabled && this.onClick) {
        this.onClick();
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
export struct SpringExpandableCard {
  @Prop title: string = '';
  @Prop preset: SpringPreset = SpringPresets.BOUNCY;
  @Prop initiallyExpanded: boolean = false;
  @Prop borderRadius: number = DesignTokens.BorderRadius.XL;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private isExpanded: boolean = false;
  @State private contentHeight: number = 0;
  @State private rotation: number = 0;
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;

  aboutToAppear(): void {
    this.isExpanded = this.initiallyExpanded;
    this.rotation = this.isExpanded ? 180 : 0;
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private toggle(): void {
    SpringAnimator.animate(this.preset, { duration: 400 }, () => {
      this.isExpanded = !this.isExpanded;
      this.rotation = this.isExpanded ? 180 : 0;
    });
  }

  private handlePress(): void {
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 60 }, () => {
      this.isPressed = true;
      this.scaleValue = 0.98;
    });
  }

  private handleRelease(): void {
    SpringAnimator.animate(this.preset, { duration: 350 }, () => {
      this.isPressed = false;
      this.scaleValue = 1;
    });
  }

  @Builder
  contentBuilder(): void {
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(DesignTokens.Typography.FONT_SIZE_MD)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.TEXT_PRIMARY)
          .layoutWeight(1)

        Text('▼')
          .fontSize(12)
          .fontColor(this.colors.TEXT_SECONDARY)
          .rotate({ angle: this.rotation })
          .animation({
            duration: 400,
            curve: SpringCurves.bouncy()
          })
      }
      .width('100%')
      .padding(DesignTokens.Spacing.MD)
      .justifyContent(FlexAlign.SpaceBetween)
      .onClick(() => {
        this.toggle();
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.handlePress();
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.handleRelease();
        }
      })

      if (this.isExpanded) {
        Column() {
          this.contentBuilder();
        }
        .width('100%')
        .padding({
          left: DesignTokens.Spacing.MD,
          right: DesignTokens.Spacing.MD,
          bottom: DesignTokens.Spacing.MD
        })
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: SpringCurves.gentle() }))
      }
    }
    .width('100%')
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(this.borderRadius)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .shadow({
      radius: 4,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: 2,
      fill: true
    })
  }
}

@Component
export struct SpringChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  @Prop preset: SpringPreset = SpringPresets.PLAYFUL;
  @Prop icon?: string;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  onClick?: () => void;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private handlePress(): void {
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 50 }, () => {
      this.isPressed = true;
      this.scaleValue = 0.92;
    });
  }

  private handleRelease(): void {
    SpringAnimator.animate(this.preset, { duration: 350 }, () => {
      this.isPressed = false;
      this.scaleValue = 1;
    });
  }

  build() {
    Row() {
      if (this.icon) {
        Text(this.icon)
          .fontSize(14)
          .fontColor(this.selected ? '#FFFFFF' : this.colors.TEXT_PRIMARY)
          .margin({ right: 4 })
      }

      Text(this.label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selected ? '#FFFFFF' : this.colors.TEXT_PRIMARY)
    }
    .padding({ top: 6, bottom: 6, left: 14, right: 14 })
    .backgroundColor(this.selected ? this.colors.PRIMARY : this.colors.SURFACE_SECONDARY)
    .borderRadius(20)
    .border({
      width: this.selected ? 0 : 1,
      color: this.colors.BORDER
    })
    .opacity(this.isPressed ? 0.9 : 1)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .onClick(() => {
      if (this.onClick) {
        this.onClick();
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
