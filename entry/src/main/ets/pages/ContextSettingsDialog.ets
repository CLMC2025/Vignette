import { ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

@Component
export struct ContextSettingsDialog {
  @Link selectedContextStyle: ContextStyle;
  @Link selectedDifficultyLevel: DifficultyLevel;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  onClose: () => void = () => {};
  onApply: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getContextStyleName(style: ContextStyle): string {
    switch (style) {
      case ContextStyle.RANDOM:
        return '随机';
      case ContextStyle.CONVERSATIONAL:
        return '对话';
      case ContextStyle.FORMAL:
        return '正式';
      case ContextStyle.HUMOROUS:
        return '幽默';
      case ContextStyle.NARRATIVE:
        return '叙事';
      case ContextStyle.TECHNICAL:
        return '技术';
      default:
        return '随机';
    }
  }

  private getDifficultyName(level: DifficultyLevel): string {
    switch (level) {
      case DifficultyLevel.BEGINNER:
        return '初学者';
      case DifficultyLevel.CET4:
        return '四级';
      case DifficultyLevel.CET6:
        return '六级';
      case DifficultyLevel.POSTGRADUATE:
        return '考研';
      case DifficultyLevel.IELTS:
        return '雅思';
      case DifficultyLevel.TOEFL:
        return '托福';
      case DifficultyLevel.SAT:
        return 'SAT';
      case DifficultyLevel.GRE:
        return 'GRE';
      case DifficultyLevel.ADVANCED:
        return '高级';
      default:
        return '四级';
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.colors.BLACK)
        .opacity(0.5)
        .onClick(() => this.onClose())

      Column() {
        Column() {
          Row() {
            Text('语境设置')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.TEXT_PRIMARY)
              .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_cancel'))
              .width(24)
              .height(24)
              .fillColor(this.colors.TEXT_SECONDARY)
              .onClick(() => this.onClose())
          }
          .width('100%')
          .margin({ bottom: 20 })

          Column() {
            Text('语境风格')
              .fontSize(14)
              .fontColor(this.colors.TEXT_SECONDARY)
              .margin({ bottom: 8 })

            Row() {
              ForEach([
                ContextStyle.RANDOM,
                ContextStyle.CONVERSATIONAL,
                ContextStyle.FORMAL,
                ContextStyle.HUMOROUS,
                ContextStyle.NARRATIVE,
                ContextStyle.TECHNICAL
              ], (style: ContextStyle) => {
                Text(this.getContextStyleName(style))
                  .fontSize(14)
                  .fontColor(this.selectedContextStyle === style ? this.colors.WHITE : this.colors.TEXT_PRIMARY)
                  .backgroundColor(this.selectedContextStyle === style ? this.colors.PRIMARY : this.colors.BACKGROUND_SECONDARY)
                  .padding({
                    left: 12,
                    right: 12,
                    top: 6,
                    bottom: 6
                  })
                  .borderRadius(16)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.selectedContextStyle = style;
                  })
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          Column() {
            Text('难度级别')
              .fontSize(14)
              .fontColor(this.colors.TEXT_SECONDARY)
              .margin({ bottom: 8 })

            Column() {
              Row() {
                ForEach([
                  DifficultyLevel.BEGINNER,
                  DifficultyLevel.CET4,
                  DifficultyLevel.CET6,
                  DifficultyLevel.POSTGRADUATE
                ], (level: DifficultyLevel) => {
                  Text(this.getDifficultyName(level))
                    .fontSize(14)
                  .fontColor(this.selectedDifficultyLevel === level ? this.colors.WHITE : this.colors.TEXT_PRIMARY)
                  .backgroundColor(this.selectedDifficultyLevel === level ? this.colors.PRIMARY : this.colors.BACKGROUND_SECONDARY)
                    .padding({
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: 6
                    })
                    .borderRadius(16)
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.selectedDifficultyLevel = level;
                    })
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ bottom: 8 })

              Row() {
                ForEach([
                  DifficultyLevel.IELTS,
                  DifficultyLevel.TOEFL,
                  DifficultyLevel.SAT,
                  DifficultyLevel.GRE
                ], (level: DifficultyLevel) => {
                  Text(this.getDifficultyName(level))
                    .fontSize(14)
                  .fontColor(this.selectedDifficultyLevel === level ? this.colors.WHITE : this.colors.TEXT_PRIMARY)
                  .backgroundColor(this.selectedDifficultyLevel === level ? this.colors.PRIMARY : this.colors.BACKGROUND_SECONDARY)
                    .padding({
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: 6
                    })
                    .borderRadius(16)
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.selectedDifficultyLevel = level;
                    })
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ bottom: 8 })

              Row() {
                ForEach([
                  DifficultyLevel.ADVANCED
                ], (level: DifficultyLevel) => {
                  Text(this.getDifficultyName(level))
                    .fontSize(14)
                  .fontColor(this.selectedDifficultyLevel === level ? this.colors.WHITE : this.colors.TEXT_PRIMARY)
                  .backgroundColor(this.selectedDifficultyLevel === level ? this.colors.PRIMARY : this.colors.BACKGROUND_SECONDARY)
                    .padding({
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: 6
                    })
                    .borderRadius(16)
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.selectedDifficultyLevel = level;
                    })
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          Button('应用设置')
            .width('100%')
            .height(44)
            .fontSize(16)
            .fontColor(this.colors.WHITE)
            .backgroundColor(this.colors.PRIMARY)
            .borderRadius(22)
            .onClick(() => {
              this.onApply();
            })
        }
        .width('90%')
        .padding(20)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(16)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: 0 })
    }
    .width('100%')
    .height('100%')
  }
}
