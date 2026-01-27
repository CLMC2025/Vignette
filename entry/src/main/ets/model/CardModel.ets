// =====================================================
// CardModel.ets - Card Logic and Types
// =====================================================

import { PaddingMargin } from './UICommon';

/**
 * Statistical Item Interface
 */
export interface StatItem {
  label: string;
  value: string | number;
}

/**
 * Action Item Interface
 */
export interface ActionItem {
  text: string;
  onClick: () => void;
}

/**
 * Card Item Interface
 */
export interface CardItem {
  title: string;
  description: string;
  onClick: () => void;
}

/**
 * Card Types
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
 * Card Style Configuration
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
    backgroundColor: ResourceColor = '#FFFFFF',
    borderRadius: number = 12,
    elevation: number = 0,
    shadowColor: ResourceColor = '#000000',
    shadowOpacity: number = 0.1,
    padding: PaddingMargin = { left: 16, right: 16, top: 16, bottom: 16 },
    margin: PaddingMargin = { left: 0, right: 0, top: 0, bottom: 0 }
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

  static basic(): CardStyle {
    return new CardStyle(
      CardType.BASIC,
      '#FFFFFF',
      12,
      0,
      '#000000',
      0.1,
      { left: 16, right: 16, top: 16, bottom: 16 },
      { left: 0, right: 0, top: 0, bottom: 0 }
    );
  }

  static elevated(): CardStyle {
    return new CardStyle(
      CardType.ELEVATED,
      '#FFFFFF',
      16,
      4,
      '#000000',
      0.15,
      { left: 20, right: 20, top: 20, bottom: 20 },
      { left: 8, right: 8, top: 8, bottom: 8 }
    );
  }

  static outlined(): CardStyle {
    return new CardStyle(
      CardType.OUTLINED,
      '#FFFFFF',
      12,
      0,
      '#2196F3',
      0.2,
      { left: 16, right: 16, top: 16, bottom: 16 },
      { left: 0, right: 0, top: 0, bottom: 0 }
    );
  }

  static filled(): CardStyle {
    return new CardStyle(
      CardType.FILLED,
      '#2196F3',
      12,
      0,
      '#000000',
      0.1,
      { left: 16, right: 16, top: 16, bottom: 16 },
      { left: 0, right: 0, top: 0, bottom: 0 }
    );
  }

  static interactive(): CardStyle {
    return new CardStyle(
      CardType.INTERACTIVE,
      '#FFFFFF',
      16,
      2,
      '#2196F3',
      0.15,
      { left: 20, right: 20, top: 20, bottom: 20 },
      { left: 8, right: 8, top: 8, bottom: 8 }
    );
  }
}

/**
 * Card State Management
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

  reset(): void {
    this.isPressed = false;
    this.isFocused = false;
    this.isDisabled = false;
    this.isSelected = false;
    this.isLoading = false;
  }

  isActive(): boolean {
    return this.isPressed || this.isFocused || this.isSelected;
  }
}
