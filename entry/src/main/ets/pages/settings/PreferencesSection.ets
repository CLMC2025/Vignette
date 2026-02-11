// =====================================================
// PreferencesSection.ets
// User learning preferences and study flow settings
// =====================================================

import { DesignTokens } from '../../model/DesignTokens';
import { SelectOption } from './SettingsCommon';
import { ContextStyle, DifficultyLevel } from '../../context/TemplateManager';

const STUDY_FLOW_OPTIONS: SelectOption[] = [
  { value: '合并（复习优先）' },
  { value: '分开设置' }
];

const STUDY_FLOW_MODES: string[] = [
  'combined',
  'separate'
];

@Component
export struct PreferencesSection {
  @Link dailyNewWords: number;
  @Link dailyTotalTasks: number;
  @Link dailyReviewWords: number;
  @Link studyFlowMode: string;
  @Link enableTTS: boolean;
  @Link pronunciationMode: string;
  @Link newbieMode: boolean;
  @Link selectedContextStyle: ContextStyle;
  @Link customContextStyle: string;
  @Link selectedDifficultyLevel: DifficultyLevel;
  @Link contextLengthMin: number;
  @Link contextLengthMax: number;

  @Builder
  buildPronunciationOption(value: string, label: string) {
    Text(label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(this.pronunciationMode === value ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_700)
      .backgroundColor(this.pronunciationMode === value ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_200)
      .padding({
        left: DesignTokens.Spacing.MD,
        right: DesignTokens.Spacing.MD,
        top: DesignTokens.Spacing.XS,
        bottom: DesignTokens.Spacing.XS
      })
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ right: DesignTokens.Spacing.SM })
      .onClick(() => {
        this.pronunciationMode = value;
      })
  }

  @Builder
  buildContextStyleOption(value: ContextStyle, label: string) {
    Text(label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(this.selectedContextStyle === value ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_700)
      .backgroundColor(this.selectedContextStyle === value ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_200)
      .padding({
        left: DesignTokens.Spacing.MD,
        right: DesignTokens.Spacing.MD,
        top: DesignTokens.Spacing.XS,
        bottom: DesignTokens.Spacing.XS
      })
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ right: DesignTokens.Spacing.SM })
      .onClick(() => {
        this.selectedContextStyle = value;
      })
  }

  @Builder
  buildDifficultyOption(value: DifficultyLevel, label: string) {
    Text(label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(this.selectedDifficultyLevel === value ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_700)
      .backgroundColor(this.selectedDifficultyLevel === value ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_200)
      .padding({
        left: DesignTokens.Spacing.MD,
        right: DesignTokens.Spacing.MD,
        top: DesignTokens.Spacing.XS,
        bottom: DesignTokens.Spacing.XS
      })
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ right: DesignTokens.Spacing.SM })
      .onClick(() => {
        this.selectedDifficultyLevel = value;
      })
  }

  build() {
    Column() {
      Text('学习量与偏好')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        Text('学习流程')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.LG,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          Text('先复习再学习')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_700)

          Blank()

          Select(STUDY_FLOW_OPTIONS)
            .selected(STUDY_FLOW_MODES.indexOf(this.studyFlowMode) >= 0 ? STUDY_FLOW_MODES.indexOf(this.studyFlowMode) : 0)
            .value(this.studyFlowMode === 'separate' ? STUDY_FLOW_OPTIONS[1].value : STUDY_FLOW_OPTIONS[0].value)
            .font({ size: DesignTokens.Typography.FONT_SIZE_BASE })
            .fontColor(DesignTokens.Colors.GRAY_700)
            .selectedOptionFont({ size: DesignTokens.Typography.FONT_SIZE_BASE })
            .optionFont({ size: DesignTokens.Typography.FONT_SIZE_BASE })
            .onSelect((index: number) => {
              this.studyFlowMode = STUDY_FLOW_MODES[index] ?? 'combined';
            })
        }
        .width('100%')
        .height(56)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        if (this.studyFlowMode === 'combined') {
          Text('每日学习总量')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({
              top: DesignTokens.Spacing.LG,
              left: DesignTokens.Spacing.LG,
              bottom: DesignTokens.Spacing.XS
            })

          Row() {
            Text(`${this.dailyTotalTasks}`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)

            Blank()

            Text('每天总任务量（复习优先）')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })

          Slider({
            value: this.dailyTotalTasks,
            min: 10,
            max: 100,
            step: 10,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .padding({
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })
            .blockColor(DesignTokens.Colors.PRIMARY)
            .trackColor(DesignTokens.Colors.GRAY_300)
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .showTips(true)
            .onChange((value: number) => {
              this.dailyTotalTasks = Math.round(value);
            })
        } else {
          Text('每日复习')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({
              top: DesignTokens.Spacing.LG,
              left: DesignTokens.Spacing.LG,
              bottom: DesignTokens.Spacing.XS
            })

          Row() {
            Text(`${this.dailyReviewWords}`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            Blank()
            Text('每天复习的数量')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })

          Slider({
            value: this.dailyReviewWords,
            min: 10,
            max: 100,
            step: 10,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .padding({
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })
            .blockColor(DesignTokens.Colors.PRIMARY)
            .trackColor(DesignTokens.Colors.GRAY_300)
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .showTips(true)
            .onChange((value: number) => {
              this.dailyReviewWords = Math.round(value);
            })

          Text('每日新词')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({
              top: DesignTokens.Spacing.MD,
              left: DesignTokens.Spacing.LG,
              bottom: DesignTokens.Spacing.XS
            })

          Row() {
            Text(`${this.dailyNewWords}`)
              .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
              .fontColor(DesignTokens.Colors.PRIMARY)
              .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)

            Blank()

            Text('每天学习的新单词数量')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })

          Slider({
            value: this.dailyNewWords,
            min: 5,
            max: 30,
            step: 5,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .padding({
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })
            .blockColor(DesignTokens.Colors.PRIMARY)
            .trackColor(DesignTokens.Colors.GRAY_300)
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .showTips(true)
            .onChange((value: number) => {
              this.dailyNewWords = Math.round(value);
            })
        }

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Enable TTS
        Row() {
          Column() {
            Text('启用发音')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)
            Text('在学习过程中播放单词发音')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }

          Blank()

          Toggle({ type: ToggleType.Switch, isOn: this.enableTTS })
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .switchPointColor(DesignTokens.Colors.WHITE)
            .onChange((isOn: boolean) => {
              this.enableTTS = isOn;
            })
        }
        .width('100%')
        .height(64)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Text('发音方式')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          this.buildPronunciationOption('auto', '自动')
          this.buildPronunciationOption('online', '在线')
          this.buildPronunciationOption('system', '系统TTS')
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          bottom: DesignTokens.Spacing.SM
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Context Style
        Text('语境风格')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Column() {
          Row() {
            this.buildContextStyleOption(ContextStyle.RANDOM, '随机')
            this.buildContextStyleOption(ContextStyle.CONVERSATIONAL, '对话')
            this.buildContextStyleOption(ContextStyle.FORMAL, '正式')
          }
          .margin({
            bottom: DesignTokens.Spacing.SM
          })

          Row() {
            this.buildContextStyleOption(ContextStyle.HUMOROUS, '幽默')
            this.buildContextStyleOption(ContextStyle.NARRATIVE, '叙述')
            this.buildContextStyleOption(ContextStyle.TECHNICAL, '技术')
          }
          .margin({
            bottom: DesignTokens.Spacing.SM
          })

          Row() {
            this.buildContextStyleOption(ContextStyle.CUSTOM, '自定义')
          }
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Custom Style Input
        if (this.selectedContextStyle === ContextStyle.CUSTOM) {
          Column() {
            Text('自定义风格描述')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .margin({
                top: DesignTokens.Spacing.MD,
                left: DesignTokens.Spacing.LG,
                bottom: DesignTokens.Spacing.XS
              })

            TextInput({
              text: this.customContextStyle,
              placeholder: '输入自定义风格描述，如：科幻、古风、商务'
            })
              .width('100%')
              .height(44)
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .backgroundColor(DesignTokens.Colors.GRAY_100)
              .borderRadius(DesignTokens.BorderRadius.MD)
              .padding({
                left: DesignTokens.Spacing.LG,
                right: DesignTokens.Spacing.LG
              })
              .onChange((value: string) => {
                this.customContextStyle = value;
              })
          }
        }

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          top: DesignTokens.Spacing.MD
        })

        // Difficulty Level
        Text('难度级别')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Column() {
          Row() {
            this.buildDifficultyOption(DifficultyLevel.BEGINNER, '入门')
            this.buildDifficultyOption(DifficultyLevel.CET4, '四级')
            this.buildDifficultyOption(DifficultyLevel.CET6, '六级')
            this.buildDifficultyOption(DifficultyLevel.POSTGRADUATE, '考研')
          }
          .margin({ bottom: DesignTokens.Spacing.SM })

          Row() {
            this.buildDifficultyOption(DifficultyLevel.IELTS, '雅思')
            this.buildDifficultyOption(DifficultyLevel.TOEFL, '托福')
            this.buildDifficultyOption(DifficultyLevel.SAT, 'SAT')
            this.buildDifficultyOption(DifficultyLevel.GRE, 'GRE')
          }
          .margin({ bottom: DesignTokens.Spacing.SM })

          Row() {
            this.buildDifficultyOption(DifficultyLevel.ADVANCED, '高级')
          }
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          top: DesignTokens.Spacing.MD
        })

        // Context Length
        Text('语境长度 (词数)')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          Text('最短')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .width(30)

          Slider({
            value: this.contextLengthMin,
            min: 0,
            max: 100,
            step: 5,
            style: SliderStyle.OutSet
          })
            .layoutWeight(1)
            .blockColor(DesignTokens.Colors.PRIMARY)
            .trackColor(DesignTokens.Colors.GRAY_300)
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .onChange((value: number) => {
              this.contextLengthMin = Math.round(value);
              // If not auto (0), ensure min <= max
              if (this.contextLengthMin > 0 && this.contextLengthMax > 0 && this.contextLengthMax < this.contextLengthMin) {
                this.contextLengthMax = this.contextLengthMin;
              }
            })

          Text(this.contextLengthMin === 0 ? '自动' : `${this.contextLengthMin}`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Row() {
          Text('最长')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .width(30)

          Slider({
            value: this.contextLengthMax,
            min: 0,
            max: 200,
            step: 5,
            style: SliderStyle.OutSet
          })
            .layoutWeight(1)
            .blockColor(DesignTokens.Colors.PRIMARY)
            .trackColor(DesignTokens.Colors.GRAY_300)
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .onChange((value: number) => {
              this.contextLengthMax = Math.round(value);
              // If not auto (0), ensure min <= max
              if (this.contextLengthMax > 0 && this.contextLengthMin > 0 && this.contextLengthMin > this.contextLengthMax) {
                this.contextLengthMin = this.contextLengthMax;
              }
            })

          Text(this.contextLengthMax === 0 ? '自动' : `${this.contextLengthMax}`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })
      }
      .width('100%')
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    }
    .width('100%')
  }
}
