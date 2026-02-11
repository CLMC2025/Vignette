// =====================================================
// TokenInterfaces.ets - Interfaces for Design System Tokens
// =====================================================

import Curves from '@ohos.curves';

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
  readonly STATUS_RELEARNING: ResourceColor;
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
 * Shadow options interface helper
 */
export interface ShadowOptions {
  radius: number | Resource;
  type?: ShadowType;
  color?: Color | string | Resource;
  offsetX?: number | Resource;
  offsetY?: number | Resource;
  fill?: boolean;
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
