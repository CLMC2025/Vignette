// =====================================================
// EnhancedCards.ets - 增强卡片组件库
// 提供各种增强的卡片组件，支持动画和交互
// =====================================================

import { DesignTokens } from '../model/DesignTokens';

/**
 * 内外边距接口
 */
export interface PaddingMargin {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

/**
 * 统计项接口
 */
export interface StatItem {
  label: string;
  value: string | number;
}

/**
 * 操作项接口
 */
export interface ActionItem {
  text: string;
  onClick: () => void;
}

/**
 * 卡片项接口
 */
export interface CardItem {
  title: string;
  description: string;
  onClick: () => void;
}

/**
 * 卡片类型
 */
export enum CardType {
  BASIC = 'basic',
  ELEVATED = 'elevated',
  OUTLINED = 'outlined',
  FILLED = 'filled',
  INTERACTIVE = 'interactive',
  ANIMATED = 'animated'
}

/**
 * 卡片样式
 */
export class CardStyle {
  type: CardType;
  backgroundColor: ResourceColor;
  borderRadius: number;
  elevation: number;
  shadowColor: ResourceColor;
  shadowOpacity: number;
  padding: PaddingMargin;
  margin: PaddingMargin;

  constructor(
    type: CardType = CardType.BASIC,
    backgroundColor: ResourceColor = DesignTokens.Colors.SURFACE_PRIMARY,
    borderRadius: number = DesignTokens.BorderRadius.LG,
    elevation: number = 0,
    shadowColor: ResourceColor = DesignTokens.Colors.SHADOW_DARK,
    shadowOpacity: number = 0.1,
    padding: PaddingMargin = { 
      left: DesignTokens.Spacing.LG, 
      right: DesignTokens.Spacing.LG, 
      top: DesignTokens.Spacing.LG, 
      bottom: DesignTokens.Spacing.LG 
    },
    margin: PaddingMargin = { 
      left: 0, 
      right: 0, 
      top: 0, 
      bottom: 0 
    }
  ) {
    this.type = type;
    this.backgroundColor = backgroundColor;
    this.borderRadius = borderRadius;
    this.elevation = elevation;
    this.shadowColor = shadowColor;
    this.shadowOpacity = shadowOpacity;
    this.padding = padding;
    this.margin = margin;
  }

  /**
   * 创建基础卡片样式
   */
  static basic(): CardStyle {
    return new CardStyle(
      CardType.BASIC,
      DesignTokens.Colors.SURFACE_PRIMARY,
      DesignTokens.BorderRadius.LG,
      0,
      DesignTokens.Colors.SHADOW_DARK,
      0.1,
      { 
        left: DesignTokens.Spacing.LG, 
        right: DesignTokens.Spacing.LG, 
        top: DesignTokens.Spacing.LG, 
        bottom: DesignTokens.Spacing.LG 
      },
      { left: 0, right: 0, top: 0, bottom: 0 }
    );
  }

  /**
   * 创建凸起卡片样式
   */
  static elevated(): CardStyle {
    return new CardStyle(
      CardType.ELEVATED,
      DesignTokens.Colors.SURFACE_ELEVATED,
      DesignTokens.BorderRadius.XL,
      4,
      DesignTokens.Colors.SHADOW_MEDIUM,
      0.15,
      { 
        left: DesignTokens.Spacing.XL, 
        right: DesignTokens.Spacing.XL, 
        top: DesignTokens.Spacing.XL, 
        bottom: DesignTokens.Spacing.XL 
      },
      { 
        left: DesignTokens.Spacing.SM, 
        right: DesignTokens.Spacing.SM, 
        top: DesignTokens.Spacing.SM, 
        bottom: DesignTokens.Spacing.SM 
      }
    );
  }

  /**
   * 创建轮廓卡片样式
   */
  static outlined(): CardStyle {
    return new CardStyle(
      CardType.OUTLINED,
      DesignTokens.Colors.SURFACE_PRIMARY,
      DesignTokens.BorderRadius.LG,
      0,
      DesignTokens.Colors.PRIMARY,
      0.2,
      { 
        left: DesignTokens.Spacing.LG, 
        right: DesignTokens.Spacing.LG, 
        top: DesignTokens.Spacing.LG, 
        bottom: DesignTokens.Spacing.LG 
      },
      { left: 0, right: 0, top: 0, bottom: 0 }
    );
  }

  /**
   * 创建填充卡片样式
   */
  static filled(): CardStyle {
    return new CardStyle(
      CardType.FILLED,
      DesignTokens.Colors.PRIMARY,
      DesignTokens.BorderRadius.LG,
      0,
      DesignTokens.Colors.SHADOW_DARK,
      0.1,
      { 
        left: DesignTokens.Spacing.LG, 
        right: DesignTokens.Spacing.LG, 
        top: DesignTokens.Spacing.LG, 
        bottom: DesignTokens.Spacing.LG 
      },
      { left: 0, right: 0, top: 0, bottom: 0 }
    );
  }

  /**
   * 创建交互卡片样式
   */
  static interactive(): CardStyle {
    return new CardStyle(
      CardType.INTERACTIVE,
      DesignTokens.Colors.SURFACE_PRIMARY,
      DesignTokens.BorderRadius.XL,
      2,
      DesignTokens.Colors.PRIMARY,
      0.15,
      { 
        left: DesignTokens.Spacing.XL, 
        right: DesignTokens.Spacing.XL, 
        top: DesignTokens.Spacing.XL, 
        bottom: DesignTokens.Spacing.XL 
      },
      { 
        left: DesignTokens.Spacing.SM, 
        right: DesignTokens.Spacing.SM, 
        top: DesignTokens.Spacing.SM, 
        bottom: DesignTokens.Spacing.SM 
      }
    );
  }
}

/**
 * 卡片状态
 */
export class CardState {
  isPressed: boolean;
  isFocused: boolean;
  isDisabled: boolean;
  isSelected: boolean;
  isLoading: boolean;

  constructor() {
    this.isPressed = false;
    this.isFocused = false;
    this.isDisabled = false;
    this.isSelected = false;
    this.isLoading = false;
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.isPressed = false;
    this.isFocused = false;
    this.isDisabled = false;
    this.isSelected = false;
    this.isLoading = false;
  }

  /**
   * 检查是否处于活动状态
   */
  isActive(): boolean {
    return this.isPressed || this.isFocused || this.isSelected;
  }
}

/**
 * 基础卡片组件配置
 */
export interface BaseCardConfig {
  style?: CardStyle;
}

/**
 * 交互卡片组件配置
 */
export interface InteractiveCardConfig extends BaseCardConfig {
  state: CardState;
  onClick: () => void;
}

/**
 * 单词卡片组件配置
 */
export interface WordCardConfig {
  word: string;
  definition: string;
  state: CardState;
  onWordClick: () => void;
}

/**
 * 进度卡片组件配置
 */
export interface ProgressCardConfig {
  title: string;
  progress: number;
  total: number;
  state: CardState;
}

/**
 * 统计卡片组件配置
 */
export interface StatsCardConfig {
  title: string;
  stats: Array<StatItem>;
  state: CardState;
}

/**
 * 图片卡片组件配置
 */
export interface ImageCardConfig {
  imageUrl: string;
  title: string;
  subtitle: string;
  state: CardState;
  onClick: () => void;
}

/**
 * 列表项卡片组件配置
 */
export interface ListItemCardConfig {
  title: string;
  description: string;
  state: CardState;
  onClick: () => void;
}

/**
 * 操作卡片组件配置
 */
export interface ActionCardConfig {
  title: string;
  description: string;
  actions: Array<ActionItem>;
  state: CardState;
}

/**
 * 加载卡片组件配置
 */
export interface LoadingCardConfig {
  message?: string;
}

/**
 * 错误卡片组件配置
 */
export interface ErrorCardConfig {
  title: string;
  message: string;
  onRetry?: () => void;
}

/**
 * 成功卡片组件配置
 */
export interface SuccessCardConfig {
  title: string;
  message: string;
  onContinue?: () => void;
}

/**
 * 信息卡片组件配置
 */
export interface InfoCardConfig {
  title: string;
  message: string;
  onDismiss?: () => void;
}

/**
 * 警告卡片组件配置
 */
export interface WarningCardConfig {
  title: string;
  message: string;
  onConfirm?: () => void;
  onCancel?: () => void;
}

/**
 * 卡片网格组件配置
 */
export interface CardGridConfig {
  items: Array<CardItem>;
}

/**
 * 卡片列表组件配置
 */
export interface CardListConfig {
  items: Array<CardItem>;
}

/**
 * 卡片组件工具类
 */
export class CardUtils {
  /**
   * 创建基础卡片样式
   */
  static createBasicStyle(): CardStyle {
    return CardStyle.basic();
  }

  /**
   * 创建凸起卡片样式
   */
  static createElevatedStyle(): CardStyle {
    return CardStyle.elevated();
  }

  /**
   * 创建轮廓卡片样式
   */
  static createOutlinedStyle(): CardStyle {
    return CardStyle.outlined();
  }

  /**
   * 创建填充卡片样式
   */
  static createFilledStyle(): CardStyle {
    return CardStyle.filled();
  }

  /**
   * 创建交互卡片样式
   */
  static createInteractiveStyle(): CardStyle {
    return CardStyle.interactive();
  }

  /**
   * 创建默认卡片状态
   */
  static createDefaultState(): CardState {
    return new CardState();
  }
}
