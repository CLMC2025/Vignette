// =====================================================
// UICommon.ets - Shared UI Interfaces and Types
// =====================================================

/**
 * Margin options interface
 */
export interface MarginOptions {
  top?: Length;
  right?: Length;
  bottom?: Length;
  left?: Length;
}

/**
 * Padding options interface
 */
export interface PaddingOptions {
  top?: Length;
  right?: Length;
  bottom?: Length;
  left?: Length;
}

/**
 * Padding/Margin combined interface
 */
export interface PaddingMargin {
  left: Length;
  right: Length;
  top: Length;
  bottom: Length;
}

/**
 * Scale options interface
 */
export interface ScaleOptions {
  x?: number;
  y?: number;
  z?: number;
  centerX?: number | string;
  centerY?: number | string;
}

/**
 * Translate options interface
 */
export interface TranslateOptions {
  x?: number | string;
  y?: number | string;
  z?: number | string;
}

/**
 * Rotate options interface
 */
export interface RotateOptions {
  angle?: number | string;
  x?: number;
  y?: number;
  z?: number;
  centerX?: number | string;
  centerY?: number | string;
}

/**
 * Position options interface
 */
export interface PositionOptions {
  x?: number | string;
  y?: number | string;
}

/**
 * Constraint size options interface
 */
export interface ConstraintSizeOptions {
  minWidth?: Length;
  maxWidth?: Length;
  minHeight?: Length;
  maxHeight?: Length;
}

/**
 * Border radius options interface
 */
export interface BorderRadiusOptions {
  topLeft?: Length;
  topRight?: Length;
  bottomLeft?: Length;
  bottomRight?: Length;
}

/**
 * Text overflow options interface
 */
export interface TextOverflowOptions {
  overflow: TextOverflow;
}

/**
 * Shadow options interface
 */
export interface ShadowOptions {
  radius: number | Resource;
  color?: Color | string | Resource | number;
  offsetX?: number | Resource;
  offsetY?: number | Resource;
  fill?: boolean;
}

/**
 * Border options interface
 */
export interface BorderOptions {
  width: Length;
  color: ResourceColor;
  style?: BorderStyle;
}

/**
 * Circle options interface
 */
export interface CircleOptions {
  width?: Length;
  height?: Length;
  radius?: Length;
}

/**
 * List options interface
 */
export interface ListOptions {
  space?: number | string;
  initialIndex?: number;
  scroller?: Scroller;
  width?: number | string;
  height?: number | string;
}

/**
 * Progress options interface
 */
export interface ProgressOptions {
  value: number;
  total: number;
  type?: ProgressType;
}

/**
 * Flex options interface
 */
export interface FlexOptions {
  direction?: FlexDirection;
  wrap?: FlexWrap;
  justifyContent?: FlexAlign;
  alignItems?: ItemAlign;
  alignContent?: FlexAlign;
}

/**
 * Toast options interface
 */
export interface ToastOptions {
  message: string;
  duration?: number;
  bottom?: string | number;
}

/**
 * Animation options interface
 */
export interface AnimationOptions {
  duration?: number;
  tempo?: number;
  curve?: Curve | ICurve;
  delay?: number;
  iterations?: number;
  playMode?: PlayMode;
  onFinish?: () => void;
}

/**
 * Array from options interface
 */
export interface ArrayFromOptions {
  length?: number;
  value?: Function;
}
