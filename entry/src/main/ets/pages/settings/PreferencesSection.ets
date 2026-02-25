// =====================================================
// PreferencesSection.ets
// User learning preferences - Optimized card-based layout
// =====================================================

import { DesignTokens } from '../../model/DesignTokens';
import { SelectOption } from './SettingsCommon';
import { ContextStyle, DifficultyLevel } from '../../context/TemplateManager';
import { ThemeManager } from '../../manager/ThemeManager';
import { DBManager } from '../../database/DBManager';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { OptionButton } from './OptionButton';

const STUDY_FLOW_OPTIONS: SelectOption[] = [
  { value: '合并（复习优先）' },
  { value: '分开设置' }
];

const STUDY_FLOW_MODES: string[] = [
  'combined',
  'separate'
];

const LEARNING_ORDER_OPTIONS: SelectOption[] = [
  { value: '复习优先' },
  { value: '新词优先' },
  { value: '交错(1:1)' },
  { value: '随机' }
];

const LEARNING_ORDER_POLICIES: string[] = [
  'due_first',
  'new_first',
  'interleave',
  'random'
];

@Component
export struct PreferencesSection {
  @Link dailyNewWords: number;
  @Link dailyTotalTasks: number;
  @Link dailyReviewWords: number;
  @Link studyFlowMode: string;
  @Link learningOrderPolicy: string;
  @Link enableTTS: boolean;
  @Link pronunciationMode: string;
  @Link newbieMode: boolean;
  @Link themeId: string;
  @Link selectedContextStyle: ContextStyle;
  @Link customContextStyle: string;
  @Link selectedDifficultyLevel: DifficultyLevel;
  @Link contextLengthMin: number;
  @Link contextLengthMax: number;
  @Link learningStepMinutes: number[];
  @Link timeboxEnabled: boolean;
  @Link timeboxLimitMinutes: number;
  @Link timeboxReminderMinutes: number;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private dbManager: DBManager = DBManager.getInstance();

  private getLearningStepMinutes(index: number): number {
    const value = this.learningStepMinutes[index];
    if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
      return Math.round(value);
    }
    if (index === 1) {
      return 120;
    }
    return 5;
  }

  private updateLearningStepMinutes(index: number, value: number): void {
    const rounded: number = Math.max(1, Math.round(value));
    const base: number[] = this.learningStepMinutes.length > 0
      ? [...this.learningStepMinutes]
      : [5, 120];
    while (base.length <= index) {
      base.push(index === 1 ? 120 : 5);
    }
    base[index] = rounded;
    this.learningStepMinutes = base;
  }

  private parseNumberInput(value: string, fallback: number, min: number, max: number): number {
    if (value.trim().length === 0) {
      return fallback;
    }
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      return fallback;
    }
    const rounded = Math.round(parsed);
    if (rounded < min) {
      return min;
    }
    if (rounded > max) {
      return max;
    }
    return rounded;
  }

  // Number input with unit
  @Builder
  buildNumberInput(value: number, placeholder: string, unit: string, onChange: (val: number) => void, min: number, max: number) {
    Row() {
      TextInput({ text: value > 0 ? `${value}` : '', placeholder: placeholder })
        .width(60)
        .height(36)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
        .type(InputType.Number)
        .backgroundColor(this.colors.GRAY_100)
        .borderRadius(DesignTokens.BorderRadius.SM)
        .onChange((text: string) => {
          const parsed = this.parseNumberInput(text, value, min, max);
          onChange(parsed);
        })

      Text(unit)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.TEXT_SECONDARY)
        .margin({ left: DesignTokens.Spacing.XS })
    }
  }

  build() {
    Column() {
      // ========== Appearance ==========
      Column() {
        Text('外观')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

        Column() {
          Row() {
            Text('主题')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            Row({ space: DesignTokens.Spacing.SM }) {
              OptionButton({ label: '浅色', isSelected: this.themeId === 'light', onButtonClick: () => {
                this.themeId = 'light';
                ThemeManager.getInstance().setTheme('light');
              }})
              OptionButton({ label: '深色', isSelected: this.themeId === 'dark', onButtonClick: () => {
                this.themeId = 'dark';
                ThemeManager.getInstance().setTheme('dark');
              }})
            }
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
        }
        .width('100%')
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .padding(DesignTokens.Spacing.MD)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.LG })

      // ========== Study Flow ==========
      Column() {
        Text('学习流程')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

        Column() {
          // Study flow mode
          Row() {
            Text('学习模式')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            Select(STUDY_FLOW_OPTIONS)
              .selected(STUDY_FLOW_MODES.indexOf(this.studyFlowMode) >= 0 ? STUDY_FLOW_MODES.indexOf(this.studyFlowMode) : 0)
              .value(this.studyFlowMode === 'separate' ? STUDY_FLOW_OPTIONS[1].value : STUDY_FLOW_OPTIONS[0].value)
              .font({ size: DesignTokens.Typography.FONT_SIZE_SM })
              .fontColor(this.colors.TEXT_PRIMARY)
              .selectedOptionFont({ size: DesignTokens.Typography.FONT_SIZE_SM })
              .optionFont({ size: DesignTokens.Typography.FONT_SIZE_SM })
              .onSelect((index: number) => {
                this.studyFlowMode = STUDY_FLOW_MODES[index] ?? 'combined';
              })
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          Divider().color(this.colors.GRAY_200)

          // Learning order
          Row() {
            Text('出题顺序')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            Select(LEARNING_ORDER_OPTIONS)
              .selected(LEARNING_ORDER_POLICIES.indexOf(this.learningOrderPolicy) >= 0 ? LEARNING_ORDER_POLICIES.indexOf(this.learningOrderPolicy) : 0)
              .value(LEARNING_ORDER_OPTIONS[LEARNING_ORDER_POLICIES.indexOf(this.learningOrderPolicy) >= 0 ? LEARNING_ORDER_POLICIES.indexOf(this.learningOrderPolicy) : 0].value)
              .font({ size: DesignTokens.Typography.FONT_SIZE_SM })
              .fontColor(this.colors.TEXT_PRIMARY)
              .selectedOptionFont({ size: DesignTokens.Typography.FONT_SIZE_SM })
              .optionFont({ size: DesignTokens.Typography.FONT_SIZE_SM })
              .onSelect((index: number) => {
                this.learningOrderPolicy = LEARNING_ORDER_POLICIES[index] ?? 'due_first';
              })
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          Divider().color(this.colors.GRAY_200)

          // Daily tasks
          if (this.studyFlowMode === 'combined') {
            Row() {
              Text('每日任务量')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Blank()
              this.buildNumberInput(this.dailyTotalTasks, '10-100', '词', (val) => {
                this.dailyTotalTasks = val;
              }, 10, 100)
            }
            .width('100%')
            .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
          } else {
            Row() {
              Text('每日复习')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Blank()
              this.buildNumberInput(this.dailyReviewWords, '10-100', '词', (val) => {
                this.dailyReviewWords = val;
              }, 10, 100)
            }
            .width('100%')
            .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

            Divider().color(this.colors.GRAY_200)

            Row() {
              Text('每日新词')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Blank()
              this.buildNumberInput(this.dailyNewWords, '5-30', '词', (val) => {
                this.dailyNewWords = val;
              }, 5, 30)
            }
            .width('100%')
            .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
          }
        }
        .width('100%')
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .padding(DesignTokens.Spacing.MD)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.LG })

      // ========== Learning Steps ==========
      Column() {
        Text('记忆算法')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

        Column() {
          Text('调整新学和重新学习阶段的时间间隔')
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(this.colors.TEXT_SECONDARY)
            .margin({ bottom: DesignTokens.Spacing.SM })

          Row() {
            Text('再学间隔')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            this.buildNumberInput(this.getLearningStepMinutes(0), '1-240', '分钟', (val) => {
              this.updateLearningStepMinutes(0, val);
            }, 1, 240)
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          Divider().color(this.colors.GRAY_200)

          Row() {
            Text('困难间隔')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            this.buildNumberInput(this.getLearningStepMinutes(1), '1-240', '分钟', (val) => {
              this.updateLearningStepMinutes(1, val);
            }, 1, 240)
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
        }
        .width('100%')
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .padding(DesignTokens.Spacing.MD)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.LG })

      // ========== Voice Settings ==========
      Column() {
        Text('语音')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

        Column() {
          Row() {
            Column() {
              Text('启用发音')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Text('学习过程中播放单词发音')
                .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
                .fontColor(this.colors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.enableTTS })
              .selectedColor(this.colors.PRIMARY)
              .switchPointColor(this.colors.WHITE)
              .onChange((isOn: boolean) => {
                this.enableTTS = isOn;
              })
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          if (this.enableTTS) {
            Divider().color(this.colors.GRAY_200)

            Row() {
              Text('发音方式')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Blank()
              Row({ space: DesignTokens.Spacing.SM }) {
                OptionButton({ label: '自动', isSelected: this.pronunciationMode === 'auto', onButtonClick: () => {
                  this.pronunciationMode = 'auto';
                }})
                OptionButton({ label: '在线', isSelected: this.pronunciationMode === 'online', onButtonClick: () => {
                  this.pronunciationMode = 'online';
                }})
                OptionButton({ label: '系统', isSelected: this.pronunciationMode === 'system', onButtonClick: () => {
                  this.pronunciationMode = 'system';
                }})
              }
            }
            .width('100%')
            .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
          }
        }
        .width('100%')
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .padding(DesignTokens.Spacing.MD)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.LG })

      // ========== Context Style ==========
      Column() {
        Text('语境生成')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

        Column() {
          // Context style
          Text('语境风格')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.colors.TEXT_SECONDARY)
            .margin({ bottom: DesignTokens.Spacing.SM })

          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            OptionButton({ label: '随机', isSelected: this.selectedContextStyle === ContextStyle.RANDOM, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.RANDOM;
            }})
            OptionButton({ label: '对话', isSelected: this.selectedContextStyle === ContextStyle.CONVERSATIONAL, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.CONVERSATIONAL;
            }})
            OptionButton({ label: '正式', isSelected: this.selectedContextStyle === ContextStyle.FORMAL, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.FORMAL;
            }})
            OptionButton({ label: '幽默', isSelected: this.selectedContextStyle === ContextStyle.HUMOROUS, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.HUMOROUS;
            }})
            OptionButton({ label: '叙述', isSelected: this.selectedContextStyle === ContextStyle.NARRATIVE, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.NARRATIVE;
            }})
            OptionButton({ label: '技术', isSelected: this.selectedContextStyle === ContextStyle.TECHNICAL, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.TECHNICAL;
            }})
            OptionButton({ label: '自定义', isSelected: this.selectedContextStyle === ContextStyle.CUSTOM, onButtonClick: () => {
              this.selectedContextStyle = ContextStyle.CUSTOM;
            }})
          }
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

          // Custom style input
          if (this.selectedContextStyle === ContextStyle.CUSTOM) {
            TextInput({
              text: this.customContextStyle,
              placeholder: '输入自定义风格，如：科幻、古风、商务'
            })
              .width('100%')
              .height(40)
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(DesignTokens.BorderRadius.MD)
              .margin({ bottom: DesignTokens.Spacing.SM })
              .onChange((value: string) => {
                this.customContextStyle = value;
              })
          }

          Divider().color(this.colors.GRAY_200)

          // Difficulty level
          Text('难度级别')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.colors.TEXT_SECONDARY)
            .margin({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            OptionButton({ label: '入门', isSelected: this.selectedDifficultyLevel === DifficultyLevel.BEGINNER, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.BEGINNER;
            }})
            OptionButton({ label: '四级', isSelected: this.selectedDifficultyLevel === DifficultyLevel.CET4, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.CET4;
            }})
            OptionButton({ label: '六级', isSelected: this.selectedDifficultyLevel === DifficultyLevel.CET6, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.CET6;
            }})
            OptionButton({ label: '考研', isSelected: this.selectedDifficultyLevel === DifficultyLevel.POSTGRADUATE, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.POSTGRADUATE;
            }})
            OptionButton({ label: '雅思', isSelected: this.selectedDifficultyLevel === DifficultyLevel.IELTS, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.IELTS;
            }})
            OptionButton({ label: '托福', isSelected: this.selectedDifficultyLevel === DifficultyLevel.TOEFL, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.TOEFL;
            }})
            OptionButton({ label: 'SAT', isSelected: this.selectedDifficultyLevel === DifficultyLevel.SAT, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.SAT;
            }})
            OptionButton({ label: 'GRE', isSelected: this.selectedDifficultyLevel === DifficultyLevel.GRE, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.GRE;
            }})
            OptionButton({ label: '高级', isSelected: this.selectedDifficultyLevel === DifficultyLevel.ADVANCED, onButtonClick: () => {
              this.selectedDifficultyLevel = DifficultyLevel.ADVANCED;
            }})
          }
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

          Divider().color(this.colors.GRAY_200)

          // Context length
          Row() {
            Text('最短词数')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            this.buildNumberInput(this.contextLengthMin, '自动', '词', (val) => {
              this.contextLengthMin = val;
              if (this.contextLengthMax > 0 && this.contextLengthMax < this.contextLengthMin) {
                this.contextLengthMax = this.contextLengthMin;
              }
            }, 0, 100)
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          Divider().color(this.colors.GRAY_200)

          Row() {
            Text('最长词数')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.TEXT_PRIMARY)
            Blank()
            this.buildNumberInput(this.contextLengthMax, '自动', '词', (val) => {
              this.contextLengthMax = val;
              if (this.contextLengthMin > 0 && this.contextLengthMin > this.contextLengthMax) {
                this.contextLengthMin = this.contextLengthMax;
              }
            }, 0, 200)
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
        }
        .width('100%')
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .padding(DesignTokens.Spacing.MD)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.LG })

      // ========== Timebox ==========
      Column() {
        Text('学习提醒')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .width('100%')
          .margin({ bottom: DesignTokens.Spacing.SM })

        Column() {
          Row() {
            Column() {
              Text('启用提醒')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Text('学习达到设定时间后提醒休息')
                .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
                .fontColor(this.colors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.timeboxEnabled })
              .selectedColor(this.colors.PRIMARY)
              .switchPointColor(this.colors.WHITE)
              .onChange((isOn: boolean) => {
                this.timeboxEnabled = isOn;
              })
          }
          .width('100%')
          .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

          if (this.timeboxEnabled) {
            Divider().color(this.colors.GRAY_200)

            Row() {
              Text('学习时长')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Blank()
              this.buildNumberInput(this.timeboxLimitMinutes, '5-120', '分钟', (val) => {
                this.timeboxLimitMinutes = val;
              }, 5, 120)
            }
            .width('100%')
            .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })

            Divider().color(this.colors.GRAY_200)

            Row() {
              Text('提前提醒')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(this.colors.TEXT_PRIMARY)
              Blank()
              this.buildNumberInput(this.timeboxReminderMinutes, '1-30', '分钟', (val) => {
                this.timeboxReminderMinutes = val;
              }, 1, 30)
            }
            .width('100%')
            .padding({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.SM })
          }
        }
        .width('100%')
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
        .padding(DesignTokens.Spacing.MD)
      }
      .width('100%')
      .margin({ bottom: DesignTokens.Spacing.LG })
    }
    .width('100%')
    .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.LG })
    .id('preferences_' + this.themeRefreshToken)
  }
}
