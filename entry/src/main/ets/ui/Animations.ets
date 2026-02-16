// =====================================================
// Animations.ets - 动画组件库
// 提供常用的动画效果和过渡效果
// =====================================================

/**
 * 动画类型
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
  FLIP = 'flip'
}

/**
 * 动画方向
 */
export enum AnimationDirection {
  LEFT = 'left',
  RIGHT = 'right',
  TOP = 'top',
  BOTTOM = 'bottom',
  CENTER = 'center'
}

/**
 * 动画配置
 */
export class AnimationConfig {
  type: AnimationType;
  direction: AnimationDirection;
  duration: number;  // 毫秒
  delay: number;     // 毫秒
  curve: Curve;
  iterations: number;

  constructor(
    type: AnimationType = AnimationType.FADE_IN,
    direction: AnimationDirection = AnimationDirection.CENTER,
    duration: number = 300,
    delay: number = 0,
    curve: Curve = Curve.EaseInOut,
    iterations: number = 1
  ) {
    this.type = type;
    this.direction = direction;
    this.duration = duration;
    this.delay = delay;
    this.curve = curve;
    this.iterations = iterations;
  }

  /**
   * 创建淡入动画
   */
  static fadeIn(duration: number = 300): AnimationConfig {
    return new AnimationConfig(
      AnimationType.FADE_IN,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseInOut
    );
  }

  /**
   * 创建淡出动画
   */
  static fadeOut(duration: number = 300): AnimationConfig {
    return new AnimationConfig(
      AnimationType.FADE_OUT,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseInOut
    );
  }

  /**
   * 创建滑入动画
   */
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

  /**
   * 创建滑出动画
   */
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

  /**
   * 创建缩放动画
   */
  static scaleIn(duration: number = 300): AnimationConfig {
    return new AnimationConfig(
      AnimationType.SCALE_IN,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseOut
    );
  }

  /**
   * 创建弹跳动画
   */
  static bounce(duration: number = 500): AnimationConfig {
    return new AnimationConfig(
      AnimationType.BOUNCE,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseOut
    );
  }

  /**
   * 创建翻转动画
   */
  static flip(duration: number = 600): AnimationConfig {
    return new AnimationConfig(
      AnimationType.FLIP,
      AnimationDirection.CENTER,
      duration,
      0,
      Curve.EaseInOut
    );
  }
}

/**
 * 动画状态
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

  /**
   * 开始动画
   */
  start(config: AnimationConfig): void {
    this.isAnimating = true;
    this.progress = 0;
    this.currentConfig = config;
  }

  /**
   * 更新进度
   */
  updateProgress(progress: number): void {
    this.progress = Math.max(0, Math.min(1, progress));
    
    if (this.progress >= 1) {
      this.isAnimating = false;
    }
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.isAnimating = false;
    this.progress = 0;
    this.currentConfig = null;
  }
}

/**
 * 动画控制器
 */
export class AnimationController {
  private static instance: AnimationController | null = null;
  private animationStates: Map<string, AnimationState>;

  private constructor() {
    this.animationStates = new Map();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): AnimationController {
    if (AnimationController.instance === null) {
      AnimationController.instance = new AnimationController();
    }
    return AnimationController.instance;
  }

  /**
   * 开始动画
   */
  startAnimation(key: string, config: AnimationConfig): void {
    const state = this.getOrCreateState(key);
    state.start(config);
  }

  /**
   * 更新动画进度
   */
  updateAnimation(key: string, progress: number): void {
    const state = this.animationStates.get(key);
    if (state !== undefined) {
      state.updateProgress(progress);
    }
  }

  /**
   * 检查是否正在动画
   */
  isAnimating(key: string): boolean {
    const state = this.animationStates.get(key);
    return state !== undefined && state.isAnimating;
  }

  /**
   * 获取动画进度
   */
  getAnimationProgress(key: string): number {
    const state = this.animationStates.get(key);
    return state !== undefined ? state.progress : 0;
  }

  /**
   * 停止动画
   */
  stopAnimation(key: string): void {
    const state = this.animationStates.get(key);
    if (state !== undefined) {
      state.reset();
    }
  }

  /**
   * 停止所有动画
   */
  stopAllAnimations(): void {
    this.animationStates.forEach((state: AnimationState) => {
      state.reset();
    });
  }

  /**
   * 获取或创建动画状态
   */
  private getOrCreateState(key: string): AnimationState {
    let state = this.animationStates.get(key);
    
    if (state === undefined) {
      state = new AnimationState();
      this.animationStates.set(key, state);
    }
    
    return state;
  }

  /**
   * 获取所有动画状态
   */
  getAllStates(): Map<string, AnimationState> {
    return new Map(this.animationStates);
  }

  /**
   * 清空所有动画状态
   */
  clearAllStates(): void {
    this.animationStates.clear();
  }
}

/**
 * 动画构建器
 */
@Builder
function AnimatedContent(
  key: string,
  config: AnimationConfig,
  progress: number
): void {
  Column() {
    // 内容直接嵌入，不通过函数调用
  }
  .opacity(progress)
  .scale({
    x: config.type === AnimationType.SCALE_IN ? progress : 1,
    y: config.type === AnimationType.SCALE_IN ? progress : 1
  })
  .animation({
    duration: config.duration,
    curve: config.curve,
    iterations: config.iterations,
    playMode: PlayMode.Normal
  })
}

/**
 * 淡入动画组件
 */
@Builder
function FadeIn(
  key: string,
  duration: number = 300,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .opacity(progress)
  .animation({
    duration: duration,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 淡出动画组件
 */
@Builder
function FadeOut(
  key: string,
  duration: number = 300,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .opacity(1 - progress)
  .animation({
    duration: duration,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 滑入动画组件
 */
@Builder
function SlideIn(
  key: string,
  direction: AnimationDirection = AnimationDirection.RIGHT,
  duration: number = 300
): void {
  Column() {
    // 内容直接嵌入
  }
  .translate({
    x: direction === AnimationDirection.LEFT ? -100 : 
       direction === AnimationDirection.RIGHT ? 100 : 0,
    y: direction === AnimationDirection.TOP ? -100 : 
       direction === AnimationDirection.BOTTOM ? 100 : 0
  })
  .animation({
    duration: duration,
    curve: Curve.EaseOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 滑出动画组件
 */
@Builder
function SlideOut(
  key: string,
  direction: AnimationDirection = AnimationDirection.LEFT,
  duration: number = 300
): void {
  Column() {
    // 内容直接嵌入
  }
  .translate({
    x: direction === AnimationDirection.LEFT ? 100 : 
       direction === AnimationDirection.RIGHT ? -100 : 0,
    y: direction === AnimationDirection.TOP ? 100 : 
       direction === AnimationDirection.BOTTOM ? -100 : 0
  })
  .animation({
    duration: duration,
    curve: Curve.EaseIn,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 缩放动画组件
 */
@Builder
function ScaleIn(
  key: string,
  duration: number = 300,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .scale({
    x: progress,
    y: progress
  })
  .opacity(progress)
  .animation({
    duration: duration,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 弹跳动画组件
 */
@Builder
function Bounce(
  key: string,
  duration: number = 500,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .scale({
    x: 1 + Math.sin(progress * Math.PI * 2) * 0.1,
    y: 1 + Math.sin(progress * Math.PI * 2) * 0.1
  })
  .animation({
    duration: duration,
    curve: Curve.EaseOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 翻转动画组件
 */
@Builder
function Flip(
  key: string,
  duration: number = 600,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .rotate({
    angle: progress * 180,
    centerX: '50%',
    centerY: '50%'
  })
  .animation({
    duration: duration,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 脉冲动画组件
 */
@Builder
function Pulse(
  key: string,
  duration: number = 1000,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .scale({
    x: 1 + Math.sin(progress * Math.PI * 2) * 0.1,
    y: 1 + Math.sin(progress * Math.PI * 2) * 0.1
  })
  .animation({
    duration: duration,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 旋转动画组件
 */
@Builder
function Rotate(
  key: string,
  duration: number = 500,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .rotate({
    angle: progress * 360,
    centerX: '50%',
    centerY: '50%'
  })
  .animation({
    duration: duration,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 交错动画组件
 */
@Builder
function StaggeredAnimation(
  key: string,
  count: number,
  duration: number = 300,
  staggerDelay: number = 100,
  progress: number
): void {
  Column() {
    ForEach(Array.from({ length: count }), (item: ESObject, index: number) => {
      Column() {
        // 内容直接嵌入
      }
      .opacity(progress)
      .translate({
        x: (1 - progress) * 100
      })
      .animation({
        duration: duration,
        delay: index * staggerDelay,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    })
  }
}

/**
 * 列表项动画组件
 */
@Builder
function ListItemAnimation(
  key: string,
  index: number,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .opacity(progress)
  .translate({
    y: (1 - progress) * 50
  })
  .animation({
    duration: 300,
    delay: index * 50,
    curve: Curve.EaseOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 页面转场动画
 */
@Builder
function PageTransition(
  key: string,
  type: AnimationType = AnimationType.SLIDE_IN,
  direction: AnimationDirection = AnimationDirection.RIGHT,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .width('100%')
  .height('100%')
  .opacity(progress)
  .translate({
    x: type === AnimationType.SLIDE_IN ? 
       (direction === AnimationDirection.LEFT ? -1 : 1) * (1 - progress) * 100 : 0,
    y: type === AnimationType.SLIDE_IN ? 
       (direction === AnimationDirection.TOP ? -1 : 1) * (1 - progress) * 100 : 0
  })
  .animation({
    duration: 300,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 加载动画组件
 */
@Builder
function LoadingProgressAnimation(
  key: string,
  size: number = 48,
  color: ResourceColor = '#2196F3',
  progress: number
): void {
  Column() {
    LoadingProgress()
      .width(size)
      .height(size)
      .color(color)
  }
  .rotate({
    angle: progress * 360,
    centerX: '50%',
    centerY: '50%'
  })
  .animation({
    duration: 1000,
    curve: Curve.Linear,
    iterations: -1,
    playMode: PlayMode.Normal
  })
}

/**
 * 成功动画组件
 */
@Builder
function SuccessAnimation(
  key: string,
  progress: number
): void {
  Column() {
    Row() {
      Image($r('sys.media.ohos_ic_public_ok'))
        .width(24)
        .height(24)
        .fillColor(DesignTokens.Colors.SUCCESS)
        .scale({
          x: progress,
          y: progress
        })
      
      Text('成功！')
        .fontSize(16)
        .fontColor(DesignTokens.Colors.SUCCESS)
        .margin({ left: 8 })
        .opacity(progress)
    }
    .justifyContent(FlexAlign.Center)
    .animation({
      duration: 500,
      curve: Curve.EaseOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }
}

/**
 * 错误动画组件
 */
@Builder
function ErrorAnimation(
  key: string,
  progress: number
): void {
  Column() {
    Row() {
      Image($r('sys.media.ohos_ic_public_fail'))
        .width(24)
        .height(24)
        .fillColor(DesignTokens.Colors.ERROR)
        .scale({
          x: progress,
          y: progress
        })
      
      Text('错误')
        .fontSize(16)
        .fontColor(DesignTokens.Colors.ERROR)
        .margin({ left: 8 })
        .opacity(progress)
    }
    .justifyContent(FlexAlign.Center)
    .animation({
      duration: 500,
      curve: Curve.EaseOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }
}

/**
 * 进度动画组件
 */
@Builder
function ProgressAnimation(
  key: string,
  progress: number
): void {
  Column() {
    // 内容直接嵌入
  }
  .width('100%')
  .animation({
    duration: 300,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  })
}

/**
 * 卡片翻转动画组件
 */
@Builder
function CardFlip(
  key: string,
  duration: number = 600,
  progress: number
): void {
  Stack() {
    // 正面
    Column() {
      // 正面内容直接嵌入
    }
    .width('100%')
    .height('100%')
    .rotate({
      angle: progress < 0.5 ? progress * 180 : 180,
      centerX: '50%',
      centerY: '50%'
    })
    .opacity(progress < 0.5 ? 1 : 0)
    .animation({
      duration: duration,
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })

    // 反面
    Column() {
      // 反面内容直接嵌入
    }
    .width('100%')
    .height('100%')
    .rotate({
      angle: progress >= 0.5 ? (progress - 0.5) * 180 + 180 : 180,
      centerX: '50%',
      centerY: '50%'
    })
    .opacity(progress >= 0.5 ? 1 : 0)
    .animation({
      duration: duration,
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }
  .width('100%')
  .height('100%')
}
