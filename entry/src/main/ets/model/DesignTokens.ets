// =====================================================
// DesignTokens.ets - Design System Tokens
// Centralized management of design system values
// =====================================================

import Curves from '@ohos.curves';

/**
 * Color tokens
 */
export class Colors {
  // Primary colors - HarmonyOS Blue
  static readonly PRIMARY: ResourceColor = '#007DFF';
  static readonly PRIMARY_DARK: ResourceColor = '#005BB5';
  static readonly PRIMARY_LIGHT: ResourceColor = '#4DA3FF';
  static readonly PRIMARY_LIGHTEST: ResourceColor = '#E6F2FF';
  
  // Secondary colors - 采用参考应用的红色调
  static readonly SECONDARY: ResourceColor = '#F44336';
  static readonly SECONDARY_DARK: ResourceColor = '#D32F2F';
  static readonly SECONDARY_LIGHT: ResourceColor = '#E57373';
  static readonly SECONDARY_LIGHTEST: ResourceColor = '#FFEBEE';
  
  // Success colors
  static readonly SUCCESS: ResourceColor = '#4CAF50';
  static readonly SUCCESS_DARK: ResourceColor = '#388E3C';
  static readonly SUCCESS_LIGHT: ResourceColor = '#81C784';
  static readonly SUCCESS_LIGHTEST: ResourceColor = '#E8F5E9';
  
  // Error colors
  static readonly ERROR: ResourceColor = '#F44336';
  static readonly ERROR_DARK: ResourceColor = '#D32F2F';
  static readonly ERROR_LIGHT: ResourceColor = '#E57373';
  static readonly ERROR_LIGHTEST: ResourceColor = '#FFEBEE';
  
  // Warning colors
  static readonly WARNING: ResourceColor = '#FFEB3B';
  static readonly WARNING_DARK: ResourceColor = '#FBC02D';
  static readonly WARNING_LIGHT: ResourceColor = '#FFF176';
  static readonly WARNING_LIGHTEST: ResourceColor = '#FFFDE7';
  
  // Info colors
  static readonly INFO: ResourceColor = '#00BCD4';
  static readonly INFO_DARK: ResourceColor = '#0097A7';
  static readonly INFO_LIGHT: ResourceColor = '#4DD0E1';
  static readonly INFO_LIGHTEST: ResourceColor = '#E0F7FA';
  
  // Neutral colors
  static readonly WHITE: ResourceColor = '#FFFFFF';
  static readonly BLACK: ResourceColor = '#000000';
  static readonly GRAY_50: ResourceColor = '#FAFAFA';
  static readonly GRAY_100: ResourceColor = '#F5F5F5';
  static readonly GRAY_200: ResourceColor = '#EEEEEE';
  static readonly GRAY_300: ResourceColor = '#E0E0E0';
  static readonly GRAY_400: ResourceColor = '#BDBDBD';
  static readonly GRAY_500: ResourceColor = '#9E9E9E';
  static readonly GRAY_600: ResourceColor = '#757575';
  static readonly GRAY_700: ResourceColor = '#616161';
  static readonly GRAY_800: ResourceColor = '#424242';
  static readonly GRAY_900: ResourceColor = '#212121';
  
  // Background colors
  static readonly BACKGROUND_PRIMARY: ResourceColor = '#FFFFFF';
  static readonly BACKGROUND_SECONDARY: ResourceColor = '#F5F5F5';
  static readonly BACKGROUND_TERTIARY: ResourceColor = '#EEEEEE';
  
  // Text colors
  static readonly TEXT_PRIMARY: ResourceColor = '#212121';
  static readonly TEXT_SECONDARY: ResourceColor = '#757575';
  static readonly TEXT_TERTIARY: ResourceColor = '#9E9E9E';
  static readonly TEXT_DISABLED: ResourceColor = '#BDBDBD';
  
  // Status colors
  static readonly STATUS_NEW: ResourceColor = Colors.PRIMARY;
  static readonly STATUS_LEARNING: ResourceColor = Colors.SECONDARY;
  static readonly STATUS_REVIEW: ResourceColor = '#9C27B0';
  static readonly STATUS_MASTERED: ResourceColor = Colors.SUCCESS;
  static readonly STATUS_SUSPENDED: ResourceColor = Colors.GRAY_500;
  
  // Additional colors for UI
  static readonly PURPLE: ResourceColor = '#9C27B0';
  static readonly INDIGO: ResourceColor = '#3F51B5';
  static readonly BROWN: ResourceColor = '#795548';
  
  // Border colors
  static readonly BORDER_LIGHT: ResourceColor = '#E0E0E0';
  static readonly BORDER_MEDIUM: ResourceColor = '#BDBDBD';
  static readonly BORDER_DARK: ResourceColor = '#9E9E9E';
  
  // Shadow colors
  static readonly SHADOW_LIGHT: ResourceColor = '#0000000D';
  static readonly SHADOW_MEDIUM: ResourceColor = '#00000014';
  static readonly SHADOW_DARK: ResourceColor = '#0000001F';
}

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
  
  // Breakpoints
  static readonly BREAKPOINT_SM: number = 576;
  static readonly BREAKPOINT_MD: number = 768;
  static readonly BREAKPOINT_LG: number = 992;
  static readonly BREAKPOINT_XL: number = 1200;
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
    case '已掌握':
      return Colors.STATUS_MASTERED;
    case '已暂停':
      return Colors.STATUS_SUSPENDED;
    default:
      return Colors.GRAY_500;
  }
}

/**
 * Colors interface
 */
export interface ColorsInterface {
  readonly PRIMARY: ResourceColor;
  readonly PRIMARY_DARK: ResourceColor;
  readonly PRIMARY_LIGHT: ResourceColor;
  readonly PRIMARY_LIGHTEST: ResourceColor;
  readonly SECONDARY: ResourceColor;
  readonly SECONDARY_DARK: ResourceColor;
  readonly SECONDARY_LIGHT: ResourceColor;
  readonly SECONDARY_LIGHTEST: ResourceColor;
  readonly SUCCESS: ResourceColor;
  readonly SUCCESS_DARK: ResourceColor;
  readonly SUCCESS_LIGHT: ResourceColor;
  readonly SUCCESS_LIGHTEST: ResourceColor;
  readonly ERROR: ResourceColor;
  readonly ERROR_DARK: ResourceColor;
  readonly ERROR_LIGHT: ResourceColor;
  readonly ERROR_LIGHTEST: ResourceColor;
  readonly WARNING: ResourceColor;
  readonly WARNING_DARK: ResourceColor;
  readonly WARNING_LIGHT: ResourceColor;
  readonly WARNING_LIGHTEST: ResourceColor;
  readonly INFO: ResourceColor;
  readonly INFO_DARK: ResourceColor;
  readonly INFO_LIGHT: ResourceColor;
  readonly INFO_LIGHTEST: ResourceColor;
  readonly WHITE: ResourceColor;
  readonly BLACK: ResourceColor;
  readonly GRAY_50: ResourceColor;
  readonly GRAY_100: ResourceColor;
  readonly GRAY_200: ResourceColor;
  readonly GRAY_300: ResourceColor;
  readonly GRAY_400: ResourceColor;
  readonly GRAY_500: ResourceColor;
  readonly GRAY_600: ResourceColor;
  readonly GRAY_700: ResourceColor;
  readonly GRAY_800: ResourceColor;
  readonly GRAY_900: ResourceColor;
  readonly BACKGROUND_PRIMARY: ResourceColor;
  readonly BACKGROUND_SECONDARY: ResourceColor;
  readonly BACKGROUND_TERTIARY: ResourceColor;
  readonly TEXT_PRIMARY: ResourceColor;
  readonly TEXT_SECONDARY: ResourceColor;
  readonly TEXT_TERTIARY: ResourceColor;
  readonly TEXT_DISABLED: ResourceColor;
  readonly BORDER_LIGHT: ResourceColor;
  readonly BORDER_MEDIUM: ResourceColor;
  readonly BORDER_DARK: ResourceColor;
  readonly SHADOW_LIGHT: ResourceColor;
  readonly SHADOW_MEDIUM: ResourceColor;
  readonly SHADOW_DARK: ResourceColor;
  readonly STATUS_NEW: ResourceColor;
  readonly STATUS_LEARNING: ResourceColor;
  readonly STATUS_REVIEW: ResourceColor;
  readonly STATUS_MASTERED: ResourceColor;
  readonly STATUS_SUSPENDED: ResourceColor;
  readonly PURPLE: ResourceColor;
  readonly INDIGO: ResourceColor;
  readonly BROWN: ResourceColor;
}

/**
 * Typography interface
 */
export interface TypographyInterface {
  readonly FONT_FAMILY: string;
  readonly FONT_FAMILY_BOLD: string;
  readonly FONT_SIZE_XS: number;
  readonly FONT_SIZE_SM: number;
  readonly FONT_SIZE_BASE: number;
  readonly FONT_SIZE_LG: number;
  readonly FONT_SIZE_XL: number;
  readonly FONT_SIZE_2XL: number;
  readonly FONT_SIZE_3XL: number;
  readonly FONT_SIZE_4XL: number;
  readonly FONT_WEIGHT_LIGHT: number;
  readonly FONT_WEIGHT_REGULAR: number;
  readonly FONT_WEIGHT_MEDIUM: number;
  readonly FONT_WEIGHT_BOLD: number;
  readonly LINE_HEIGHT_TIGHT: number;
  readonly LINE_HEIGHT_NORMAL: number;
  readonly LINE_HEIGHT_RELAXED: number;
}

/**
 * Spacing interface
 */
export interface SpacingInterface {
  readonly XS: number;
  readonly SM: number;
  readonly MD: number;
  readonly LG: number;
  readonly XL: number;
  readonly XXL: number;
  readonly XXXL: number;
}

/**
 * BorderRadius interface
 */
export interface BorderRadiusInterface {
  readonly SM: number;
  readonly MD: number;
  readonly LG: number;
  readonly XL: number;
  readonly XXL: number;
  readonly FULL: number;
}

/**
 * Shadows interface
 */
export interface ShadowsInterface {
  readonly RADIUS_SM: number;
  readonly RADIUS_MD: number;
  readonly RADIUS_LG: number;
  readonly RADIUS_XL: number;
  readonly RADIUS_XXL: number;
  readonly OFFSET_X_SM: number;
  readonly OFFSET_X_MD: number;
  readonly OFFSET_X_LG: number;
  readonly OFFSET_X_XL: number;
  readonly OFFSET_X_XXL: number;
  readonly OFFSET_Y_SM: number;
  readonly OFFSET_Y_MD: number;
  readonly OFFSET_Y_LG: number;
  readonly OFFSET_Y_XL: number;
  readonly OFFSET_Y_XXL: number;
  readonly SM: ShadowOptions;
  readonly MD: ShadowOptions;
  readonly LG: ShadowOptions;
  readonly XL: ShadowOptions;
  readonly XXL: ShadowOptions;
  readonly CARD_ELEVATION_1: ShadowOptions;
  readonly CARD_ELEVATION_2: ShadowOptions;
  readonly CARD_ELEVATION_3: ShadowOptions;
}

/**
 * Animations interface
 */
export interface AnimationsInterface {
  readonly DURATION_INSTANT: number;
  readonly DURATION_TINY: number;
  readonly DURATION_FAST: number;
  readonly DURATION_NORMAL: number;
  readonly DURATION_SLOW: number;
  readonly DURATION_LARGE: number;
  readonly DURATION_XLARGE: number;
  readonly CURVE_EASE_IN: Curve | ICurve;
  readonly CURVE_EASE_OUT: Curve | ICurve;
  readonly CURVE_EASE_IN_OUT: Curve | ICurve;
  readonly CURVE_LINEAR: Curve | ICurve;
  readonly CURVE_SMOOTH: Curve | ICurve;
  readonly CURVE_FAST_OUT_SLOW_IN: Curve | ICurve;
  readonly CURVE_SHARP: Curve | ICurve;
  readonly SPRING_DEFAULT_STIFFNESS: number;
  readonly SPRING_DEFAULT_DAMPING: number;
  readonly SPRING_DEFAULT_MASS: number;
  readonly SPRING_GENTLE: Curve | ICurve;
  readonly SPRING_STIFF: Curve | ICurve;
  readonly SPRING_BOUNCY: Curve | ICurve;
  readonly SPRING_RESPONSIVE: Curve | ICurve;
  readonly SPRING_SOFT: Curve | ICurve;
  readonly SPRING_VIBRANT: Curve | ICurve;
  readonly BOUNCE_IN: Curve | ICurve;
  readonly BOUNCE_OUT: Curve | ICurve;
  readonly BOUNCE_IN_OUT: Curve | ICurve;
  readonly ELASTIC_IN: Curve | ICurve;
  readonly ELASTIC_OUT: Curve | ICurve;
  readonly ELASTIC_IN_OUT: Curve | ICurve;
}

/**
 * Layout interface
 */
export interface LayoutInterface {
  readonly MAX_WIDTH: number;
  readonly CONTAINER_PADDING: number;
  readonly BREAKPOINT_SM: number;
  readonly BREAKPOINT_MD: number;
  readonly BREAKPOINT_LG: number;
  readonly BREAKPOINT_XL: number;
}

/**
 * Interface for DesignTokens object
 */
export interface DesignTokensInterface {
  Colors: ColorsInterface;
  Typography: TypographyInterface;
  Spacing: SpacingInterface;
  BorderRadius: BorderRadiusInterface;
  Shadows: ShadowsInterface;
  Animations: AnimationsInterface;
  Layout: LayoutInterface;
  getStatusColor: (status: string) => ResourceColor;
}

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
  getStatusColor
};
