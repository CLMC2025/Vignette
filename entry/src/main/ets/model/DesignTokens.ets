// =====================================================
// DesignTokens.ets - Design System Tokens
// Centralized management of design system values
// =====================================================

import Curves from '@ohos.curves';
import { ThemeManager } from '../manager/ThemeManager';
import { 
  ColorsInterface,
  TypographyInterface,
  SpacingInterface,
  BorderRadiusInterface,
  ShadowsInterface,
  AnimationsInterface,
  LayoutInterface,
  DesignTokensInterface,
  ShadowOptions,
  GradientColorStop,
  GradientsInterface,
  ElevationInterface,
  MotionInterface,
  OpacityInterface,
  ZIndexInterface
} from './TokenInterfaces';

/**
 * Color tokens - Proxy to ThemeManager
 */
export const Colors: ColorsInterface = {
  get PRIMARY(): ResourceColor { return ThemeManager.getInstance().getColors().PRIMARY; },
  get PRIMARY_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().PRIMARY_DARK; },
  get PRIMARY_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().PRIMARY_LIGHT; },
  get PRIMARY_LIGHTEST(): ResourceColor { return ThemeManager.getInstance().getColors().PRIMARY_LIGHTEST; },
  
  get SECONDARY(): ResourceColor { return ThemeManager.getInstance().getColors().SECONDARY; },
  get SECONDARY_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().SECONDARY_DARK; },
  get SECONDARY_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().SECONDARY_LIGHT; },
  get SECONDARY_LIGHTEST(): ResourceColor { return ThemeManager.getInstance().getColors().SECONDARY_LIGHTEST; },
  
  get SUCCESS(): ResourceColor { return ThemeManager.getInstance().getColors().SUCCESS; },
  get SUCCESS_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().SUCCESS_DARK; },
  get SUCCESS_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().SUCCESS_LIGHT; },
  get SUCCESS_LIGHTEST(): ResourceColor { return ThemeManager.getInstance().getColors().SUCCESS_LIGHTEST; },
  
  get ERROR(): ResourceColor { return ThemeManager.getInstance().getColors().ERROR; },
  get ERROR_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().ERROR_DARK; },
  get ERROR_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().ERROR_LIGHT; },
  get ERROR_LIGHTEST(): ResourceColor { return ThemeManager.getInstance().getColors().ERROR_LIGHTEST; },
  
  get WARNING(): ResourceColor { return ThemeManager.getInstance().getColors().WARNING; },
  get WARNING_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().WARNING_DARK; },
  get WARNING_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().WARNING_LIGHT; },
  get WARNING_LIGHTEST(): ResourceColor { return ThemeManager.getInstance().getColors().WARNING_LIGHTEST; },
  
  get INFO(): ResourceColor { return ThemeManager.getInstance().getColors().INFO; },
  get INFO_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().INFO_DARK; },
  get INFO_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().INFO_LIGHT; },
  get INFO_LIGHTEST(): ResourceColor { return ThemeManager.getInstance().getColors().INFO_LIGHTEST; },
  
  get WHITE(): ResourceColor { return ThemeManager.getInstance().getColors().WHITE; },
  get BLACK(): ResourceColor { return ThemeManager.getInstance().getColors().BLACK; },
  get GRAY_50(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_50; },
  get GRAY_100(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_100; },
  get GRAY_200(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_200; },
  get GRAY_300(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_300; },
  get GRAY_400(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_400; },
  get GRAY_500(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_500; },
  get GRAY_600(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_600; },
  get GRAY_700(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_700; },
  get GRAY_800(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_800; },
  get GRAY_900(): ResourceColor { return ThemeManager.getInstance().getColors().GRAY_900; },
  
  get BACKGROUND_PRIMARY(): ResourceColor { return ThemeManager.getInstance().getColors().BACKGROUND_PRIMARY; },
  get BACKGROUND_SECONDARY(): ResourceColor { return ThemeManager.getInstance().getColors().BACKGROUND_SECONDARY; },
  get BACKGROUND_TERTIARY(): ResourceColor { return ThemeManager.getInstance().getColors().BACKGROUND_TERTIARY; },
  get SURFACE_PRIMARY(): ResourceColor { return ThemeManager.getInstance().getColors().SURFACE_PRIMARY; },
  get SURFACE_ELEVATED(): ResourceColor { return ThemeManager.getInstance().getColors().SURFACE_ELEVATED; },
  
  get TEXT_PRIMARY(): ResourceColor { return ThemeManager.getInstance().getColors().TEXT_PRIMARY; },
  get TEXT_SECONDARY(): ResourceColor { return ThemeManager.getInstance().getColors().TEXT_SECONDARY; },
  get TEXT_TERTIARY(): ResourceColor { return ThemeManager.getInstance().getColors().TEXT_TERTIARY; },
  get TEXT_DISABLED(): ResourceColor { return ThemeManager.getInstance().getColors().TEXT_DISABLED; },
  
  get BORDER_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().BORDER_LIGHT; },
  get BORDER_MEDIUM(): ResourceColor { return ThemeManager.getInstance().getColors().BORDER_MEDIUM; },
  get BORDER_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().BORDER_DARK; },
  
  get SHADOW_LIGHT(): ResourceColor { return ThemeManager.getInstance().getColors().SHADOW_LIGHT; },
  get SHADOW_MEDIUM(): ResourceColor { return ThemeManager.getInstance().getColors().SHADOW_MEDIUM; },
  get SHADOW_DARK(): ResourceColor { return ThemeManager.getInstance().getColors().SHADOW_DARK; },
  
  get STATUS_NEW(): ResourceColor { return ThemeManager.getInstance().getColors().STATUS_NEW; },
  get STATUS_LEARNING(): ResourceColor { return ThemeManager.getInstance().getColors().STATUS_LEARNING; },
  get STATUS_REVIEW(): ResourceColor { return ThemeManager.getInstance().getColors().STATUS_REVIEW; },
  get STATUS_RELEARNING(): ResourceColor { return ThemeManager.getInstance().getColors().STATUS_RELEARNING; },
  
  get PURPLE(): ResourceColor { return ThemeManager.getInstance().getColors().PURPLE; },
  get INDIGO(): ResourceColor { return ThemeManager.getInstance().getColors().INDIGO; },
  get BROWN(): ResourceColor { return ThemeManager.getInstance().getColors().BROWN; }
};

/**
 * Typography tokens
 */
export class Typography {
  // Font families
  static readonly FONT_FAMILY: string = 'HarmonyOS Sans';
  static readonly FONT_FAMILY_BOLD: string = 'HarmonyOS Sans Bold';
  
  // Font sizes
  static readonly FONT_SIZE_XS: number = 10;
  static readonly FONT_SIZE_SM: number = 12;
  static readonly FONT_SIZE_BASE: number = 14;
  static readonly FONT_SIZE_LG: number = 16;
  static readonly FONT_SIZE_XL: number = 18;
  static readonly FONT_SIZE_2XL: number = 24;
  static readonly FONT_SIZE_3XL: number = 32;
  static readonly FONT_SIZE_4XL: number = 40;
  
  // Font weights
  static readonly FONT_WEIGHT_LIGHT: number = 300;
  static readonly FONT_WEIGHT_REGULAR: number = 400;
  static readonly FONT_WEIGHT_MEDIUM: number = 500;
  static readonly FONT_WEIGHT_BOLD: number = 700;
  
  // Line heights
  static readonly LINE_HEIGHT_TIGHT: number = 1.2;
  static readonly LINE_HEIGHT_NORMAL: number = 1.5;
  static readonly LINE_HEIGHT_RELAXED: number = 1.8;
}

/**
 * Spacing tokens
 */
export class Spacing {
  static readonly XS: number = 4;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 20;
  static readonly XXL: number = 24;
  static readonly XXXL: number = 32;
}

/**
 * Border radius tokens
 */
export class BorderRadius {
  static readonly SM: number = 4;
  static readonly MD: number = 8;
  static readonly LG: number = 12;
  static readonly XL: number = 16;
  static readonly XXL: number = 24;
  static readonly FULL: number = 9999;
}

/**
 * Shadow tokens
 */
export class Shadows {
  // Common shadow properties
  static readonly RADIUS_SM: number = 2;
  static readonly RADIUS_MD: number = 4;
  static readonly RADIUS_LG: number = 8;
  static readonly RADIUS_XL: number = 16;
  static readonly RADIUS_XXL: number = 24;
  
  static readonly OFFSET_X_SM: number = 0;
  static readonly OFFSET_X_MD: number = 0;
  static readonly OFFSET_X_LG: number = 0;
  static readonly OFFSET_X_XL: number = 0;
  static readonly OFFSET_X_XXL: number = 0;
  
  static readonly OFFSET_Y_SM: number = 1;
  static readonly OFFSET_Y_MD: number = 2;
  static readonly OFFSET_Y_LG: number = 4;
  static readonly OFFSET_Y_XL: number = 8;
  static readonly OFFSET_Y_XXL: number = 16;
  
  // Shadow options
  static readonly SM: ShadowOptions = {
    radius: Shadows.RADIUS_SM,
    color: Colors.SHADOW_LIGHT,
    offsetX: Shadows.OFFSET_X_SM,
    offsetY: Shadows.OFFSET_Y_SM,
    fill: true
  };
  
  static readonly MD: ShadowOptions = {
    radius: Shadows.RADIUS_MD,
    color: Colors.SHADOW_MEDIUM,
    offsetX: Shadows.OFFSET_X_MD,
    offsetY: Shadows.OFFSET_Y_MD,
    fill: true
  };
  
  static readonly LG: ShadowOptions = {
    radius: Shadows.RADIUS_LG,
    color: Colors.SHADOW_DARK,
    offsetX: Shadows.OFFSET_X_LG,
    offsetY: Shadows.OFFSET_Y_LG,
    fill: true
  };
  
  static readonly XL: ShadowOptions = {
    radius: Shadows.RADIUS_XL,
    color: Colors.SHADOW_DARK,
    offsetX: Shadows.OFFSET_X_XL,
    offsetY: Shadows.OFFSET_Y_XL,
    fill: true
  };
  
  static readonly XXL: ShadowOptions = {
    radius: Shadows.RADIUS_XXL,
    color: Colors.SHADOW_DARK,
    offsetX: Shadows.OFFSET_X_XXL,
    offsetY: Shadows.OFFSET_Y_XXL,
    fill: true
  };
  
  // Card shadows for different elevations
  static readonly CARD_ELEVATION_1: ShadowOptions = {
    radius: 4,
    color: Colors.SHADOW_LIGHT,
    offsetX: 0,
    offsetY: 2,
    fill: true
  };
  
  static readonly CARD_ELEVATION_2: ShadowOptions = {
    radius: 6,
    color: Colors.SHADOW_MEDIUM,
    offsetX: 0,
    offsetY: 3,
    fill: true
  };
  
  static readonly CARD_ELEVATION_3: ShadowOptions = {
    radius: 8,
    color: Colors.SHADOW_DARK,
    offsetX: 0,
    offsetY: 4,
    fill: true
  };
}

/**
 * Animation tokens
 */
export class Animations {
  // Duration options
  static readonly DURATION_INSTANT: number = 0;
  static readonly DURATION_TINY: number = 75;
  static readonly DURATION_FAST: number = 150;
  static readonly DURATION_NORMAL: number = 300;
  static readonly DURATION_SLOW: number = 500;
  static readonly DURATION_LARGE: number = 750;
  static readonly DURATION_XLARGE: number = 1000;
  
  // Basic curves
  static readonly CURVE_EASE_IN: Curve | ICurve = Curve.EaseIn;
  static readonly CURVE_EASE_OUT: Curve | ICurve = Curve.EaseOut;
  static readonly CURVE_EASE_IN_OUT: Curve | ICurve = Curve.EaseInOut;
  static readonly CURVE_LINEAR: Curve | ICurve = Curve.Linear;
  
  // Cubic bezier curves
  static readonly CURVE_SMOOTH: Curve | ICurve = Curve.EaseInOut;
  static readonly CURVE_FAST_OUT_SLOW_IN: Curve | ICurve = Curve.FastOutSlowIn;
  static readonly CURVE_SHARP: Curve | ICurve = Curve.EaseOut;
  
  // Spring curve constants
  static readonly SPRING_DEFAULT_STIFFNESS: number = 300;
  static readonly SPRING_DEFAULT_DAMPING: number = 15;
  static readonly SPRING_DEFAULT_MASS: number = 1;
  
  // Spring curve presets
  static readonly SPRING_GENTLE: Curve | ICurve = Curve.EaseInOut;
  static readonly SPRING_STIFF: Curve | ICurve = Curve.EaseOut;
  static readonly SPRING_BOUNCY: Curve | ICurve = Curve.FastOutSlowIn;
  static readonly SPRING_RESPONSIVE: Curve | ICurve = Curve.EaseInOut;
  static readonly SPRING_SOFT: Curve | ICurve = Curve.EaseIn;
  static readonly SPRING_VIBRANT: Curve | ICurve = Curve.FastOutSlowIn;
  
  // Bounce curves
  static readonly BOUNCE_IN: Curve | ICurve = Curve.EaseIn;
  static readonly BOUNCE_OUT: Curve | ICurve = Curve.EaseOut;
  static readonly BOUNCE_IN_OUT: Curve | ICurve = Curve.EaseInOut;
  
  // Elastic curves
  static readonly ELASTIC_IN: Curve | ICurve = Curve.EaseIn;
  static readonly ELASTIC_OUT: Curve | ICurve = Curve.EaseOut;
  static readonly ELASTIC_IN_OUT: Curve | ICurve = Curve.EaseInOut;
}

/**
 * Layout tokens
 */
export class Layout {
  static readonly MAX_WIDTH: number = 1200;
  static readonly CONTAINER_PADDING: number = Spacing.LG;
  
  static readonly BREAKPOINT_SM: number = 576;
  static readonly BREAKPOINT_MD: number = 768;
  static readonly BREAKPOINT_LG: number = 992;
  static readonly BREAKPOINT_XL: number = 1200;
}

export class Gradients {
  private static createGradient(color1: ResourceColor, color2: ResourceColor): GradientColorStop[] {
    return [
      { color: color1, position: 0 },
      { color: color2, position: 1 }
    ];
  }

  static readonly PRIMARY: GradientColorStop[] = [
    { color: '#007DFF', position: 0 },
    { color: '#005BB5', position: 1 }
  ];

  static readonly SUCCESS: GradientColorStop[] = [
    { color: '#4CAF50', position: 0 },
    { color: '#388E3C', position: 1 }
  ];

  static readonly WARNING: GradientColorStop[] = [
    { color: '#FFEB3B', position: 0 },
    { color: '#FF8F00', position: 1 }
  ];

  static readonly ERROR: GradientColorStop[] = [
    { color: '#F44336', position: 0 },
    { color: '#D32F2F', position: 1 }
  ];

  static readonly INFO: GradientColorStop[] = [
    { color: '#00BCD4', position: 0 },
    { color: '#0097A7', position: 1 }
  ];

  static readonly PURPLE: GradientColorStop[] = [
    { color: '#9C27B0', position: 0 },
    { color: '#7B1FA2', position: 1 }
  ];

  static readonly SUNSET: GradientColorStop[] = [
    { color: '#FF512F', position: 0 },
    { color: '#DD2476', position: 1 }
  ];

  static readonly OCEAN: GradientColorStop[] = [
    { color: '#2193b0', position: 0 },
    { color: '#6dd5ed', position: 1 }
  ];

  static readonly MINT: GradientColorStop[] = [
    { color: '#00b09b', position: 0 },
    { color: '#96c93d', position: 1 }
  ];

  static readonly GLASS_LIGHT: GradientColorStop[] = [
    { color: 'rgba(255, 255, 255, 0.9)', position: 0 },
    { color: 'rgba(255, 255, 255, 0.6)', position: 1 }
  ];

  static readonly GLASS_DARK: GradientColorStop[] = [
    { color: 'rgba(50, 50, 50, 0.9)', position: 0 },
    { color: 'rgba(30, 30, 30, 0.7)', position: 1 }
  ];
}

export class Elevation {
  static readonly LEVEL_0: number = 0;
  static readonly LEVEL_1: number = 2;
  static readonly LEVEL_2: number = 4;
  static readonly LEVEL_3: number = 8;
  static readonly LEVEL_4: number = 16;
  static readonly LEVEL_5: number = 24;

  static getShadow(level: number): ShadowOptions {
    switch (level) {
      case 0:
        return { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0, fill: false };
      case 1:
        return { radius: 2, color: Colors.SHADOW_LIGHT, offsetX: 0, offsetY: 1, fill: true };
      case 2:
        return { radius: 4, color: Colors.SHADOW_LIGHT, offsetX: 0, offsetY: 2, fill: true };
      case 3:
        return { radius: 8, color: Colors.SHADOW_MEDIUM, offsetX: 0, offsetY: 4, fill: true };
      case 4:
        return { radius: 16, color: Colors.SHADOW_MEDIUM, offsetX: 0, offsetY: 8, fill: true };
      case 5:
        return { radius: 24, color: Colors.SHADOW_DARK, offsetX: 0, offsetY: 12, fill: true };
      default:
        return { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0, fill: false };
    }
  }
}

interface SpringConfig {
  stiffness: number;
  damping: number;
  mass: number;
}

export class Motion {
  static readonly DURATION_ENTER: number = 150;
  static readonly DURATION_EXIT: number = 100;
  static readonly DURATION_EMPHASIS: number = 300;
  static readonly DURATION_COMPLEX: number = 500;

  static readonly CURVE_STANDARD: Curve | ICurve = Curve.FastOutSlowIn;
  static readonly CURVE_DECELERATE: Curve | ICurve = Curve.EaseOut;
  static readonly CURVE_ACCELERATE: Curve | ICurve = Curve.EaseIn;
  static readonly CURVE_SHARP: Curve | ICurve = Curve.Linear;

  static readonly SPRING_CONFIG: SpringConfig = {
    stiffness: 300,
    damping: 30,
    mass: 1
  };
}

export class Opacity {
  static readonly DISABLED: number = 0.38;
  static readonly FOCUS: number = 0.12;
  static readonly HOVER: number = 0.08;
  static readonly PRESSED: number = 0.12;
  static readonly DRAGGED: number = 0.16;
}

export class ZIndex {
  static readonly BASE: number = 0;
  static readonly DROPDOWN: number = 1000;
  static readonly STICKY: number = 1100;
  static readonly FIXED: number = 1200;
  static readonly MODAL_BACKDROP: number = 1300;
  static readonly MODAL: number = 1400;
  static readonly POPOVER: number = 1500;
  static readonly TOOLTIP: number = 1600;
}

/**
 * Status text colors mapping
 */
export function getStatusColor(status: string): ResourceColor {
  switch (status) {
    case '新词':
      return Colors.STATUS_NEW;
    case '学习中':
      return Colors.STATUS_LEARNING;
    case '复习':
      return Colors.STATUS_REVIEW;
    case '重新学习':
      return Colors.STATUS_RELEARNING;
    default:
      return Colors.GRAY_500;
  }
}

/**
 * Colors interface
 */
/**
 * Export all tokens as a single object for easy import
 */
export const DesignTokens: DesignTokensInterface = {
  Colors,
  Typography,
  Spacing,
  BorderRadius,
  Shadows,
  Animations,
  Layout,
  getStatusColor,
  Gradients,
  Elevation,
  Motion,
  Opacity,
  ZIndex
};
