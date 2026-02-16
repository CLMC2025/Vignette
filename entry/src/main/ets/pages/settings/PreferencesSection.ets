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

  // Compact option button
  @Builder
  buildOptionButton(label: string, isSelected: boolean, onClick: () => void) {
    Text(label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(isSelected ? this.colors.WHITE : this.colors.TEXT_PRIMARY)
      .fontWeight(isSelected ? DesignTokens.Typography.FONT_WEIGHT_MEDIUM : DesignTokens.Typography.FONT_WEIGHT_REGULAR)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(isSelected ? this.colors.PRIMARY : this.colors.GRAY_100)
      .borderRadius(DesignTokens.BorderRadius.MD)
      .onClick(onClick)
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
              this.buildOptionButton('浅色', this.themeId === 'light', () => {
                this.themeId = 'light';
                ThemeManager.getInstance().setTheme('light');
              })
              this.buildOptionButton('深色', this.themeId === 'dark', () => {
                this.themeId = 'dark';
                ThemeManager.getInstance().setTheme('dark');
              })
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
                this.buildOptionButton('自动', this.pronunciationMode === 'auto', () => {
                  this.pronunciationMode = 'auto';
                })
                this.buildOptionButton('在线', this.pronunciationMode === 'online', () => {
                  this.pronunciationMode = 'online';
                })
                this.buildOptionButton('系统', this.pronunciationMode === 'system', () => {
                  this.pronunciationMode = 'system';
                })
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
            this.buildOptionButton('随机', this.selectedContextStyle === ContextStyle.RANDOM, () => {
              this.selectedContextStyle = ContextStyle.RANDOM;
            })
            this.buildOptionButton('对话', this.selectedContextStyle === ContextStyle.CONVERSATIONAL, () => {
              this.selectedContextStyle = ContextStyle.CONVERSATIONAL;
            })
            this.buildOptionButton('正式', this.selectedContextStyle === ContextStyle.FORMAL, () => {
              this.selectedContextStyle = ContextStyle.FORMAL;
            })
            this.buildOptionButton('幽默', this.selectedContextStyle === ContextStyle.HUMOROUS, () => {
              this.selectedContextStyle = ContextStyle.HUMOROUS;
            })
            this.buildOptionButton('叙述', this.selectedContextStyle === ContextStyle.NARRATIVE, () => {
              this.selectedContextStyle = ContextStyle.NARRATIVE;
            })
            this.buildOptionButton('技术', this.selectedContextStyle === ContextStyle.TECHNICAL, () => {
              this.selectedContextStyle = ContextStyle.TECHNICAL;
            })
            this.buildOptionButton('自定义', this.selectedContextStyle === ContextStyle.CUSTOM, () => {
              this.selectedContextStyle = ContextStyle.CUSTOM;
            })
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
            this.buildOptionButton('入门', this.selectedDifficultyLevel === DifficultyLevel.BEGINNER, () => {
              this.selectedDifficultyLevel = DifficultyLevel.BEGINNER;
            })
            this.buildOptionButton('四级', this.selectedDifficultyLevel === DifficultyLevel.CET4, () => {
              this.selectedDifficultyLevel = DifficultyLevel.CET4;
            })
            this.buildOptionButton('六级', this.selectedDifficultyLevel === DifficultyLevel.CET6, () => {
              this.selectedDifficultyLevel = DifficultyLevel.CET6;
            })
            this.buildOptionButton('考研', this.selectedDifficultyLevel === DifficultyLevel.POSTGRADUATE, () => {
              this.selectedDifficultyLevel = DifficultyLevel.POSTGRADUATE;
            })
            this.buildOptionButton('雅思', this.selectedDifficultyLevel === DifficultyLevel.IELTS, () => {
              this.selectedDifficultyLevel = DifficultyLevel.IELTS;
            })
            this.buildOptionButton('托福', this.selectedDifficultyLevel === DifficultyLevel.TOEFL, () => {
              this.selectedDifficultyLevel = DifficultyLevel.TOEFL;
            })
            this.buildOptionButton('SAT', this.selectedDifficultyLevel === DifficultyLevel.SAT, () => {
              this.selectedDifficultyLevel = DifficultyLevel.SAT;
            })
            this.buildOptionButton('GRE', this.selectedDifficultyLevel === DifficultyLevel.GRE, () => {
              this.selectedDifficultyLevel = DifficultyLevel.GRE;
            })
            this.buildOptionButton('高级', this.selectedDifficultyLevel === DifficultyLevel.ADVANCED, () => {
              this.selectedDifficultyLevel = DifficultyLevel.ADVANCED;
            })
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
