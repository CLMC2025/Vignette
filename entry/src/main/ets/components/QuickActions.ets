import { DesignTokens } from '../model/DesignTokens';

export interface QuickActionItem {
  icon: string;
  label: string;
  color: ResourceColor;
  bgColor: ResourceColor;
  onClick: () => void;
}

@Component
export struct QuickActions {
  @Prop actions: QuickActionItem[] = [];
  @State private pressedIndex: number = -1;

  private defaultActions(): QuickActionItem[] {
    return [
      {
        icon: '▶',
        label: '开始学习',
        color: DesignTokens.Colors.WHITE,
        bgColor: DesignTokens.Colors.PRIMARY,
        onClick: () => {}
      },
      {
        icon: '🔄',
        label: '复习单词',
        color: DesignTokens.Colors.SUCCESS_DARK,
        bgColor: DesignTokens.Colors.SUCCESS_LIGHTEST,
        onClick: () => {}
      },
      {
        icon: '📊',
        label: '学习统计',
        color: DesignTokens.Colors.INFO_DARK,
        bgColor: DesignTokens.Colors.INFO_LIGHTEST,
        onClick: () => {}
      },
      {
        icon: '📚',
        label: '词书管理',
        color: DesignTokens.Colors.WARNING_DARK,
        bgColor: DesignTokens.Colors.WARNING_LIGHTEST,
        onClick: () => {}
      }
    ];
  }

  private getActions(): QuickActionItem[] {
    return this.actions.length > 0 ? this.actions : this.defaultActions();
  }

  @Builder
  private buildActionItem(action: QuickActionItem, index: number): void {
    Column({ space: DesignTokens.Spacing.SM }) {
      Column() {
        Text(action.icon)
          .fontSize(22)
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(action.bgColor)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .scale({
        x: this.pressedIndex === index ? 0.92 : 1,
        y: this.pressedIndex === index ? 0.92 : 1
      })

      Text(action.label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .onClick(() => {
      action.onClick();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
          this.pressedIndex = index;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
          this.pressedIndex = -1;
        });
      }
    })
  }

  build() {
    Row() {
      ForEach(this.getActions(), (action: QuickActionItem, index: number) => {
        this.buildActionItem(action, index);
      }, (action: QuickActionItem, index: number) => `action-${index}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
  }
}

@Component
export struct QuickActionsGrid {
  @Prop actions: QuickActionItem[] = [];
  @State private pressedIndex: number = -1;

  private defaultActions(): QuickActionItem[] {
    return [
      {
        icon: '▶',
        label: '开始学习',
        color: DesignTokens.Colors.WHITE,
        bgColor: DesignTokens.Colors.PRIMARY,
        onClick: () => {}
      },
      {
        icon: '🔄',
        label: '复习单词',
        color: DesignTokens.Colors.SUCCESS_DARK,
        bgColor: DesignTokens.Colors.SUCCESS_LIGHTEST,
        onClick: () => {}
      },
      {
        icon: '📊',
        label: '学习统计',
        color: DesignTokens.Colors.INFO_DARK,
        bgColor: DesignTokens.Colors.INFO_LIGHTEST,
        onClick: () => {}
      },
      {
        icon: '📚',
        label: '词书管理',
        color: DesignTokens.Colors.WARNING_DARK,
        bgColor: DesignTokens.Colors.WARNING_LIGHTEST,
        onClick: () => {}
      }
    ];
  }

  private getActions(): QuickActionItem[] {
    return this.actions.length > 0 ? this.actions : this.defaultActions();
  }

  @Builder
  private buildGridItem(action: QuickActionItem, index: number): void {
    Column({ space: DesignTokens.Spacing.SM }) {
      Column() {
        Text(action.icon)
          .fontSize(24)
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(action.bgColor)
      .borderRadius(DesignTokens.BorderRadius.XL)
      .scale({
        x: this.pressedIndex === index ? 0.92 : 1,
        y: this.pressedIndex === index ? 0.92 : 1
      })

      Text(action.label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('50%')
    .padding(DesignTokens.Spacing.SM)
    .onClick(() => {
      action.onClick();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
          this.pressedIndex = index;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
          this.pressedIndex = -1;
        });
      }
    })
  }

  build() {
    Column() {
      ForEach([0, 2], (startIndex: number) => {
        Row() {
          ForEach(
            this.getActions().slice(startIndex, startIndex + 2),
            (action: QuickActionItem, localIndex: number) => {
              this.buildGridItem(action, startIndex + localIndex);
            },
            (action: QuickActionItem, localIndex: number) => `grid-${startIndex + localIndex}`
          )
        }
        .width('100%')
      }, (startIndex: number) => `row-${startIndex}`)
    }
    .width('100%')
  }
}

@Component
export struct QuickActionCard {
  @Prop icon: string = '';
  @Prop label: string = '';
  @Prop description: string = '';
  @Prop color: ResourceColor = DesignTokens.Colors.PRIMARY;
  @Prop badge: number = 0;
  onCardClick?: () => void;
  @State private isPressed: boolean = false;

  build() {
    Row({ space: DesignTokens.Spacing.MD }) {
      Column() {
        Text(this.icon)
          .fontSize(22)
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.color)
      .borderRadius(DesignTokens.BorderRadius.LG)

      Column({ space: 2 }) {
        Text(this.label)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.TEXT_PRIMARY)

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.badge > 0) {
        Column() {
          Text(this.badge > 99 ? '99+' : String(this.badge))
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontWeight(FontWeight.Bold)
            .fontColor(DesignTokens.Colors.WHITE)
        }
        .constraintSize({ minWidth: 20 })
        .height(20)
        .padding({ left: 6, right: 6 })
        .backgroundColor(DesignTokens.Colors.ERROR)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .justifyContent(FlexAlign.Center)
      }

      Text('›')
        .fontSize(20)
        .fontColor(DesignTokens.Colors.GRAY_400)
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick();
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
          this.isPressed = true;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
          this.isPressed = false;
        });
      }
    })
  }
}

@Component
export struct QuickActionRow {
  @Prop actions: QuickActionItem[] = [];
  @State private pressedIndex: number = -1;

  private defaultActions(): QuickActionItem[] {
    return [
      {
        icon: '▶',
        label: '学习',
        color: DesignTokens.Colors.WHITE,
        bgColor: DesignTokens.Colors.PRIMARY,
        onClick: () => {}
      },
      {
        icon: '🔄',
        label: '复习',
        color: DesignTokens.Colors.SUCCESS_DARK,
        bgColor: DesignTokens.Colors.SUCCESS_LIGHTEST,
        onClick: () => {}
      },
      {
        icon: '📊',
        label: '统计',
        color: DesignTokens.Colors.INFO_DARK,
        bgColor: DesignTokens.Colors.INFO_LIGHTEST,
        onClick: () => {}
      }
    ];
  }

  private getActions(): QuickActionItem[] {
    return this.actions.length > 0 ? this.actions : this.defaultActions();
  }

  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      ForEach(this.getActions(), (action: QuickActionItem, index: number) => {
        Column() {
          Text(action.icon)
            .fontSize(18)
            .fontColor(action.color)
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(action.bgColor)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .scale({
          x: this.pressedIndex === index ? 0.92 : 1,
          y: this.pressedIndex === index ? 0.92 : 1
        })
        .onClick(() => {
          action.onClick();
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
              this.pressedIndex = index;
            });
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
              this.pressedIndex = -1;
            });
          }
        })
      }, (action: QuickActionItem, index: number) => `row-action-${index}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
  }
}
