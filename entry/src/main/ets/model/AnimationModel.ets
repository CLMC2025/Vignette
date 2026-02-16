// =====================================================
// AnimationModel.ets - Animation Logic and Types
// Pure logic file, no UI syntax
// =====================================================

import Curves from '@ohos.curves';
import {
  MarginOptions,
  PaddingOptions,
  ScaleOptions,
  TranslateOptions,
  RotateOptions,
  ArrayFromOptions,
  AnimationOptions
} from './UICommon';

// Re-export common types for consumers who import from here
export {
  MarginOptions,
  PaddingOptions,
  ScaleOptions,
  TranslateOptions,
  RotateOptions,
  ArrayFromOptions,
  AnimationOptions
};

/**
 * Animation Types
 */
export enum AnimationType {
  FADE_IN = 'fade_in',
  FADE_OUT = 'fade_out',
  SLIDE_IN = 'slide_in',
  SLIDE_OUT = 'slide_out',
  SCALE_IN = 'scale_in',
  SCALE_OUT = 'scale_out',
  ROTATE_IN = 'rotate_in',
  ROTATE_OUT = 'rotate_out',
  BOUNCE = 'bounce',
  FLIP = 'flip',
  SPRING = 'spring'
}

/**
 * Animation Directions
 */
export enum AnimationDirection {
  LEFT = 'left',
  RIGHT = 'right',
  TOP = 'top',
  BOTTOM = 'bottom',
  CENTER = 'center'
}

/**
 * Animation Configuration
 */
export class AnimationConfig {
  type: AnimationType;
  direction: AnimationDirection;
  duration: number;  // ms
  delay: number;     // ms
  curve: Curve | ICurve;
  iterations: number;
  stiffness: number; // Spring stiffness
  damping: number;   // Spring damping ratio
  mass: number;      // Spring mass

  constructor(
    type: AnimationType = AnimationType.FADE_IN,
    direction: AnimationDirection = AnimationDirection.CENTER,
    duration: number = 300,
    delay: number = 0,
    curve: Curve | ICurve = Curve.EaseInOut,
    iterations: number = 1,
    stiffness: number = 300,
    damping: number = 15,
    mass: number = 1
  ) {
    this.type = type;
    this.direction = direction;
    this.duration = duration;
    this.delay = delay;
    this.curve = curve;
    this.iterations = iterations;
    this.stiffness = stiffness;
    this.damping = damping;
    this.mass = mass;
  }

  static fadeIn(duration: number = 300): AnimationConfig {
    return new AnimationConfig(
      AnimationType.FADE_IN,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseInOut
    );
  }

  static fadeOut(duration: number = 300): AnimationConfig {
    return new AnimationConfig(
      AnimationType.FADE_OUT,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseInOut
    );
  }

  static slideIn(
    direction: AnimationDirection = AnimationDirection.RIGHT,
    duration: number = 300
  ): AnimationConfig {
    return new AnimationConfig(
      AnimationType.SLIDE_IN,
      direction,
      duration,
      0,
      Curve.EaseOut
    );
  }

  static slideOut(
    direction: AnimationDirection = AnimationDirection.LEFT,
    duration: number = 300
  ): AnimationConfig {
    return new AnimationConfig(
      AnimationType.SLIDE_OUT,
      direction,
      duration,
      0,
      Curve.EaseIn
    );
  }

  static scaleIn(duration: number = 300): AnimationConfig {
    return new AnimationConfig(
      AnimationType.SCALE_IN,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseOut
    );
  }

  static bounce(duration: number = 500): AnimationConfig {
    return new AnimationConfig(
      AnimationType.BOUNCE,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseOut
    );
  }

  static flip(duration: number = 600): AnimationConfig {
    return new AnimationConfig(
      AnimationType.FLIP,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseInOut
    );
  }

  /**
   * 创建弹簧曲线动画
   */
  static spring(
    direction: AnimationDirection = AnimationDirection.CENTER,
    stiffness: number = 300,
    damping: number = 15,
    mass: number = 1
  ): AnimationConfig {
    return new AnimationConfig(
      AnimationType.SPRING,
      direction,
      0, // 弹簧动画时长由物理模型自动计算
      0,
      Curves.springMotion(stiffness, damping, mass),
      1,
      stiffness,
      damping,
      mass
    );
  }

  /**
   * 创建柔和的弹簧动画
   */
  static springGentle(direction: AnimationDirection = AnimationDirection.CENTER): AnimationConfig {
    return AnimationConfig.spring(direction, 150, 12, 1);
  }

  /**
   * 创建僵硬的弹簧动画
   */
  static springStiff(direction: AnimationDirection = AnimationDirection.CENTER): AnimationConfig {
    return AnimationConfig.spring(direction, 500, 20, 1);
  }

  /**
   * 创建弹跳的弹簧动画
   */
  static springBouncy(direction: AnimationDirection = AnimationDirection.CENTER): AnimationConfig {
    return AnimationConfig.spring(direction, 200, 8, 1);
  }

  /**
   * 创建响应式弹簧动画
   */
  static springResponsive(direction: AnimationDirection = AnimationDirection.CENTER): AnimationConfig {
    return AnimationConfig.spring(direction, 250, 15, 1);
  }
}

/**
 * Animation State
 */
export class AnimationState {
  isAnimating: boolean;
  progress: number;  // 0-1
  currentConfig: AnimationConfig | null;

  constructor() {
    this.isAnimating = false;
    this.progress = 0;
    this.currentConfig = null;
  }

  start(config: AnimationConfig): void {
    this.isAnimating = true;
    this.progress = 0;
    this.currentConfig = config;
  }

  updateProgress(progress: number): void {
    this.progress = Math.max(0, Math.min(1, progress));
    
    if (this.progress >= 1) {
      this.isAnimating = false;
    }
  }

  reset(): void {
    this.isAnimating = false;
    this.progress = 0;
    this.currentConfig = null;
  }
}

/**
 * Animation Controller
 */
export class AnimationController {
  private static instance: AnimationController | null = null;
  private animationStates: Map<string, AnimationState>;

  private constructor() {
    this.animationStates = new Map();
  }

  static getInstance(): AnimationController {
    if (AnimationController.instance === null) {
      AnimationController.instance = new AnimationController();
    }
    return AnimationController.instance;
  }

  startAnimation(key: string, config: AnimationConfig): void {
    const state = this.getOrCreateState(key);
    state.start(config);
  }

  updateAnimation(key: string, progress: number): void {
    const state = this.animationStates.get(key);
    if (state !== undefined) {
      state.updateProgress(progress);
    }
  }

  isAnimating(key: string): boolean {
    const state = this.animationStates.get(key);
    return state !== undefined && state.isAnimating;
  }

  getAnimationProgress(key: string): number {
    const state = this.animationStates.get(key);
    return state !== undefined ? state.progress : 0;
  }

  stopAnimation(key: string): void {
    const state = this.animationStates.get(key);
    if (state !== undefined) {
      state.reset();
    }
  }

  stopAllAnimations(): void {
    this.animationStates.forEach((state: AnimationState) => {
      state.reset();
    });
  }

  private getOrCreateState(key: string): AnimationState {
    let state = this.animationStates.get(key);
    
    if (state === undefined) {
      state = new AnimationState();
      this.animationStates.set(key, state);
    }
    
    return state;
  }

  getAllStates(): Map<string, AnimationState> {
    return new Map(this.animationStates);
  }

  clearAllStates(): void {
    this.animationStates.clear();
  }
}
