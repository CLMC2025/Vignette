import { DesignTokens } from '../model/DesignTokens';
import { SpringAnimator, SpringPresets, SpringPreset, SpringCurves } from './SpringAnimations';
import { ThemeManager } from '../manager/ThemeManager';
import { ColorsInterface } from '../model/TokenInterfaces';

export type SpringButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type SpringButtonSize = 'small' | 'medium' | 'large';

export interface SpringButtonStyle {
  backgroundColor: ResourceColor;
  textColor: ResourceColor;
  borderColor: ResourceColor;
  borderWidth: number;
  borderRadius: number;
  padding: Padding;
  fontSize: number;
  fontWeight: number;
}

@Component
export struct SpringButton {
  @Prop label: string = '';
  @Prop variant: SpringButtonVariant = 'primary';
  @Prop size: SpringButtonSize = 'medium';
  @Prop disabled: boolean = false;
  @Prop preset: SpringPreset = SpringPresets.BOUNCY;
  @Prop icon?: string;
  @Prop iconPosition: 'left' | 'right' = 'left';
  @Prop fullWidth: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  @State private isHovered: boolean = false;
  onClick?: () => void;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getStyle(): SpringButtonStyle {
    const isDark = this.colors.BACKGROUND === '#1A1A1A' ||
                   this.colors.BACKGROUND === '#121212';

    const sizeConfig = this.getSizeConfig();

    switch (this.variant) {
      case 'primary':
        return {
          backgroundColor: this.colors.PRIMARY,
          textColor: '#FFFFFF',
          borderColor: this.colors.PRIMARY,
          borderWidth: 0,
          borderRadius: sizeConfig.borderRadius,
          padding: sizeConfig.padding,
          fontSize: sizeConfig.fontSize,
          fontWeight: FontWeight.Medium
        };
      case 'secondary':
        return {
          backgroundColor: isDark ? 'rgba(255, 255, 255, 0.12)' : 'rgba(0, 0, 0, 0.06)',
          textColor: this.colors.TEXT_PRIMARY,
          borderColor: 'transparent',
          borderWidth: 0,
          borderRadius: sizeConfig.borderRadius,
          padding: sizeConfig.padding,
          fontSize: sizeConfig.fontSize,
          fontWeight: FontWeight.Medium
        };
      case 'outline':
        return {
          backgroundColor: 'transparent',
          textColor: this.colors.PRIMARY,
          borderColor: this.colors.PRIMARY,
          borderWidth: 1.5,
          borderRadius: sizeConfig.borderRadius,
          padding: sizeConfig.padding,
          fontSize: sizeConfig.fontSize,
          fontWeight: FontWeight.Medium
        };
      case 'ghost':
        return {
          backgroundColor: 'transparent',
          textColor: this.colors.TEXT_PRIMARY,
          borderColor: 'transparent',
          borderWidth: 0,
          borderRadius: sizeConfig.borderRadius,
          padding: sizeConfig.padding,
          fontSize: sizeConfig.fontSize,
          fontWeight: FontWeight.Medium
        };
      case 'danger':
        return {
          backgroundColor: this.colors.ERROR,
          textColor: '#FFFFFF',
          borderColor: this.colors.ERROR,
          borderWidth: 0,
          borderRadius: sizeConfig.borderRadius,
          padding: sizeConfig.padding,
          fontSize: sizeConfig.fontSize,
          fontWeight: FontWeight.Medium
        };
      default:
        return {
          backgroundColor: this.colors.PRIMARY,
          textColor: '#FFFFFF',
          borderColor: this.colors.PRIMARY,
          borderWidth: 0,
          borderRadius: sizeConfig.borderRadius,
          padding: sizeConfig.padding,
          fontSize: sizeConfig.fontSize,
          fontWeight: FontWeight.Medium
        };
    }
  }

  private getSizeConfig(): { padding: Padding; fontSize: number; borderRadius: number } {
    switch (this.size) {
      case 'small':
        return {
          padding: { top: 6, bottom: 6, left: 12, right: 12 },
          fontSize: 13,
          borderRadius: 8
        };
      case 'large':
        return {
          padding: { top: 14, bottom: 14, left: 28, right: 28 },
          fontSize: 17,
          borderRadius: 14
        };
      default:
        return {
          padding: { top: 10, bottom: 10, left: 20, right: 20 },
          fontSize: 15,
          borderRadius: 10
        };
    }
  }

  private handlePress(): void {
    if (this.disabled) return;
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 60 }, () => {
      this.scaleValue = 0.95;
      this.isPressed = true;
    });
  }

  private handleRelease(): void {
    if (this.disabled) return;
    SpringAnimator.animate(this.preset, { duration: 400 }, () => {
      this.scaleValue = 1;
      this.isPressed = false;
    });
  }

  private getHoverBackgroundColor(): ResourceColor {
    if (this.disabled) {
      return this.getStyle().backgroundColor;
    }
    if (this.isPressed) {
      return this.getStyle().backgroundColor;
    }
    if (this.isHovered && this.variant === 'ghost') {
      return 'rgba(0, 0, 0, 0.05)';
    }
    return this.getStyle().backgroundColor;
  }

  build() {
    Row() {
      if (this.icon && this.iconPosition === 'left') {
        Text(this.icon)
          .fontSize(this.getStyle().fontSize + 2)
          .margin({ right: 6 })
      }

      Text(this.label)
        .fontSize(this.getStyle().fontSize)
        .fontWeight(this.getStyle().fontWeight)
        .fontColor(this.disabled ? this.colors.TEXT_TERTIARY : this.getStyle().textColor)

      if (this.icon && this.iconPosition === 'right') {
        Text(this.icon)
          .fontSize(this.getStyle().fontSize + 2)
          .margin({ left: 6 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .width(this.fullWidth ? '100%' : 'auto')
    .padding(this.getStyle().padding)
    .backgroundColor(this.getHoverBackgroundColor())
    .borderRadius(this.getStyle().borderRadius)
    .border({
      width: this.getStyle().borderWidth,
      color: this.disabled ? this.colors.BORDER : this.getStyle().borderColor
    })
    .opacity(this.disabled ? 0.5 : 1)
    .scale({ x: this.scaleValue, y: this.scaleValue })
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
export struct SpringIconButton {
  @Prop icon: string = '';
  @Prop size: number = 44;
  @Prop disabled: boolean = false;
  @Prop preset: SpringPreset = SpringPresets.BOUNCY;
  @Prop backgroundColor?: ResourceColor;
  @Prop iconColor?: ResourceColor;
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
      this.scaleValue = 0.9;
      this.isPressed = true;
    });
  }

  private handleRelease(): void {
    if (this.disabled) return;
    SpringAnimator.animate(this.preset, { duration: 400 }, () => {
      this.scaleValue = 1;
      this.isPressed = false;
    });
  }

  build() {
    Row() {
      Text(this.icon)
        .fontSize(this.size * 0.5)
        .fontColor(this.disabled ? this.colors.TEXT_TERTIARY : (this.iconColor ?? this.colors.TEXT_PRIMARY))
    }
    .width(this.size)
    .height(this.size)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.backgroundColor ?? 'transparent')
    .borderRadius(this.size / 2)
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
export struct SpringFloatingButton {
  @Prop icon: string = '+';
  @Prop size: number = 56;
  @Prop disabled: boolean = false;
  @Prop preset: SpringPreset = SpringPresets.ELASTIC;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private isPressed: boolean = false;
  @State private scaleValue: number = 1;
  @State private elevation: number = 6;
  onClick?: () => void;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private handlePress(): void {
    if (this.disabled) return;
    SpringAnimator.animate(SpringPresets.SNAPPY, { duration: 60 }, () => {
      this.scaleValue = 0.92;
      this.isPressed = true;
      this.elevation = 4;
    });
  }

  private handleRelease(): void {
    if (this.disabled) return;
    SpringAnimator.animate(this.preset, { duration: 500 }, () => {
      this.scaleValue = 1;
      this.isPressed = false;
      this.elevation = 6;
    });
  }

  build() {
    Row() {
      Text(this.icon)
        .fontSize(this.size * 0.45)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
    }
    .width(this.size)
    .height(this.size)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.colors.PRIMARY)
    .borderRadius(this.size / 2)
    .shadow({
      radius: this.elevation * 2,
      color: 'rgba(0, 0, 0, 0.25)',
      offsetX: 0,
      offsetY: this.elevation,
      fill: true
    })
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
