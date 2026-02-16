import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { StoryWord } from './ReadPageModels';
import { LoadingAnimation, LoadingType } from '../ui/LoadingAnimations';
import { hashStoryText } from '../utils/ContextDefinitionStore';
import { WordItem } from '../model/WordModel';

@Component
export struct StoryView {
  @Prop storyText: string;
  @Prop storyError: string;
  @Prop storySourceLabel: string;
  @Prop storyWords: StoryWord[];
  @Prop currentStoryHash: string;
  @Prop showTargetHighlight: boolean;
  @Prop showTranslation: boolean;
  @Prop definitionLoading: boolean;
  @Prop definitionContent: string;
  @Prop isGeneratingStory: boolean;
  @Prop currentWord: WordItem;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  onWordClick: (word: StoryWord) => void = () => {};
  onToggleTranslation: () => void = () => {};
  onGenerateStory: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private needsSpaceAfter(index: number): boolean {
    if (index >= this.storyWords.length - 1) {
      return false;
    }
    const next = this.storyWords[index + 1];
    if (next.isPunctuation) {
      return false;
    }
    return true;
  }

  private getWordColor(storyWord: StoryWord): ResourceColor {
    if (storyWord.isPunctuation) {
      return this.colors.TEXT_SECONDARY;
    }
    return this.colors.TEXT_PRIMARY;
  }

  private normalizeStoryToken(raw: string): string {
    return raw.toLowerCase().replace(/[^a-z]/g, '');
  }

  private isCurrentTargetStoryWord(storyWord: StoryWord): boolean {
    if (this.currentWord.word.length === 0) {
      return false;
    }
    if (storyWord.isPunctuation) {
      return false;
    }
    const token = this.normalizeStoryToken(storyWord.word);
    const target = this.normalizeStoryToken(this.currentWord.word);
    if (token.length === 0 || target.length === 0) {
      return false;
    }
    return token === target;
  }

  private getTranslationText(): string {
    return this.definitionContent.length > 0 ? this.definitionContent : '暂无释义';
  }

  build() {
    Column() {
      Text('微语境')
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.GRAY_600)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      if (this.storyText.length > 0) {
        // Story display
        Column() {
          if (this.storySourceLabel.length > 0) {
            Row() {
              Blank()
              Text(`来源：${this.storySourceLabel}`)
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(this.colors.GRAY_500)
            }
            .width('100%')
            .margin({ bottom: DesignTokens.Spacing.SM })
          }
          if (this.storyError.length > 0) {
            Row() {
              Text(this.storyError)
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(this.colors.WARNING_DARK)
            }
            .width('100%')
            .padding({
              left: DesignTokens.Spacing.MD,
              right: DesignTokens.Spacing.MD,
              top: DesignTokens.Spacing.SM,
              bottom: DesignTokens.Spacing.SM
            })
            .backgroundColor(this.colors.WARNING_LIGHT + '20')
            .borderRadius(DesignTokens.BorderRadius.MD)
            .margin({ bottom: DesignTokens.Spacing.MD })
          }

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.storyWords, (storyWord: StoryWord, index: number) => {
              Text(storyWord.word + (this.needsSpaceAfter(index) ? ' ' : ''))
                .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
                .lineHeight(DesignTokens.Typography.FONT_SIZE_LG * 1.6)
                .fontColor(this.getWordColor(storyWord))
                .fontWeight(this.isCurrentTargetStoryWord(storyWord) ? DesignTokens.Typography.FONT_WEIGHT_MEDIUM :
                  DesignTokens.Typography.FONT_WEIGHT_REGULAR)
                .decoration({
                  type: (this.isCurrentTargetStoryWord(storyWord) && this.showTargetHighlight) ? TextDecorationType.Underline : TextDecorationType.None,
                  color: this.colors.PRIMARY
                })
                .onClick(() => this.onWordClick(storyWord))
            }, (storyWord: StoryWord, index: number): string => {
              const storyHash = this.currentStoryHash.length > 0 ? this.currentStoryHash : hashStoryText(this.storyText);
              return `word-${storyHash}-${index}-${storyWord.startIndex}`;
            })
          }
          .width('100%')
          .padding(DesignTokens.Spacing.LG)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.LG)

          Text(this.showTranslation ? '点击收起完整释义' : '点击显示完整释义')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.colors.GRAY_600)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: DesignTokens.Spacing.MD })
            .onClick(() => {
              this.onToggleTranslation();
            })

          if (this.showTranslation) {
            Column() {
              if (this.definitionLoading && this.definitionContent.length === 0) {
                Row() {
                  LoadingAnimation({ type: LoadingType.SPINNER, animSize: 18, color: this.colors.PRIMARY, duration: 900 })
                  Text('释义更新中...')
                    .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                    .fontColor(this.colors.GRAY_800)
                    .margin({ left: DesignTokens.Spacing.SM })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              if (this.definitionContent.length > 0 || !this.definitionLoading) {
                Text(this.getTranslationText())
                  .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                  .fontColor(this.colors.GRAY_800)
                  .lineHeight(DesignTokens.Typography.FONT_SIZE_BASE * 1.6)
              }
            }
            .padding(DesignTokens.Spacing.MD)
            .backgroundColor(this.colors.PRIMARY_LIGHTEST)
            .borderRadius(DesignTokens.BorderRadius.LG)
            .margin({ top: DesignTokens.Spacing.SM })
          }
        }
        .width('100%')

      } else if (this.isGeneratingStory) {
        // Loading state
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(this.colors.PRIMARY)

          Text('Generating story...')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.GRAY_500)
            .margin({ top: DesignTokens.Spacing.LG })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.colors.GRAY_100)
        .borderRadius(DesignTokens.BorderRadius.LG)

      } else if (this.storyError.length > 0) {
        // Error state (no story text)
        Column() {
          Image($r('sys.media.ohos_ic_public_fail'))
            .width(48)
            .height(48)
            .fillColor(this.colors.ERROR)

          Text(this.storyError)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.ERROR)
            .margin({ top: DesignTokens.Spacing.LG })
            .textAlign(TextAlign.Center)

          Button('重试生成')
            .margin({ top: DesignTokens.Spacing.XL })
            .backgroundColor(this.colors.PRIMARY)
            .fontColor(this.colors.WHITE)
            .onClick(() => {
              this.onGenerateStory();
            })
        }
        .width('100%')
        .padding(DesignTokens.Spacing.XXL)
        .backgroundColor(this.colors.GRAY_100)
        .borderRadius(DesignTokens.BorderRadius.LG)

      } else {
        // Empty state
        Text('点击下方按钮生成情境故事')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(this.colors.GRAY_500)
          .width('100%')
          .padding(DesignTokens.Spacing.XXL)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.LG)
      }
    }
    .width('100%')
    .padding(DesignTokens.Spacing.XXL)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.XL)
    .alignItems(HorizontalAlign.Center)
  }
}
