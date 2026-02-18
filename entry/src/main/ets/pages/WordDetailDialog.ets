import { DialogState } from './ReadPageModels';
import { WordDefinition, WordMeaning } from '../model/WordModel';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

@Component
export struct WordDetailDialog {
  @Link dialogState: DialogState;
  @Link meaningExpanded: boolean;
  @Prop newbieMode: boolean;
  @Prop joinedBookCount: number;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  onClose: () => void = () => {};
  onPlayPronunciation: (word: string) => void = () => {};
  onAddToBook: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getJoinBookButtonText(): string {
    if (this.joinedBookCount > 0) {
      return `已加入：${this.joinedBookCount}`;
    }
    return '加入词书';
  }

  @Builder
  buildDialogButtons() {
    Column() {
      Button(this.getJoinBookButtonText())
        .width('100%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colors.WHITE)
        .backgroundColor(this.colors.SUCCESS)
        .borderRadius(24)
        .onClick(() => {
          this.onAddToBook();
        })
    }
    .width('100%')
    .padding(20)
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
      // Dialog card
      Column() {
        // Header with word and close
        Row() {
          Column() {
            Row() {
              // Issue #7 fix: Make word text also clickable for pronunciation
              Text(this.dialogState.word)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.colors.TEXT_PRIMARY)
                .onClick(() => {
                  this.onPlayPronunciation(this.dialogState.word);
                })

              // Speaker
              Image($r('sys.media.ohos_ic_public_sound'))
                .width(24)
                .height(24)
                .fillColor(this.colors.PRIMARY)
                .margin({ left: 8 })
                .onClick(() => {
                  this.onPlayPronunciation(this.dialogState.word);
                })
            }

            // Phonetic
            if (this.dialogState.definition !== null && this.dialogState.definition.phonetic.length > 0) {
              Text(this.dialogState.definition.phonetic)
                .fontSize(14)
                .fontColor(this.colors.TEXT_SECONDARY)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // Close button
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(24)
            .height(24)
            .fillColor(this.colors.TEXT_TERTIARY)
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({
          left: 20,
          right: 20,
          top: 20,
          bottom: 12
        })

        Divider().color(this.colors.BORDER_LIGHT)

        // Content
        if (this.dialogState.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(this.colors.PRIMARY)
            Text('Loading definition...')
              .fontSize(14)
              .fontColor(this.colors.TEXT_TERTIARY)
              .margin({ top: 8 })
          }
          .width('100%')
          .height(120)
          .justifyContent(FlexAlign.Center)

        } else if (this.dialogState.definition !== null) {
          Scroll() {
            Column() {
              Row() {
                Text('释义')
                  .fontSize(12)
                  .fontColor(this.colors.TEXT_SECONDARY)

                Blank()

                Text(this.meaningExpanded ? '收起' : '展开')
                  .fontSize(12)
                  .fontColor(this.colors.PRIMARY)
              }
              .width('100%')
              .margin({ bottom: 8 })
              .onClick(() => {
                this.meaningExpanded = !this.meaningExpanded;
              })

              if (!this.meaningExpanded) {
                Column() {
                  Text('回忆一下？')
                    .fontSize(14)
                    .fontColor(this.colors.TEXT_SECONDARY)

                  Text('点击展开释义')
                    .fontSize(12)
                    .fontColor(this.colors.TEXT_TERTIARY)
                    .margin({ top: 4 })
                }
                .width('100%')
                .height(48)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor(this.colors.BACKGROUND_SECONDARY)
                .borderRadius(8)
                .onClick(() => {
                  this.meaningExpanded = true;
                })
              } else {
                Column() {
                  // Context meaning (highlighted)
                  if (this.dialogState.definition.contextMeaning.length > 0) {
                    Column() {
                      Row() {
                        Text(this.dialogState.definition.pos)
                          .fontSize(12)
                          .fontColor(this.colors.WHITE)
                          .backgroundColor(this.colors.PRIMARY)
                          .padding({
                            left: 8,
                            right: 8,
                            top: 2,
                            bottom: 2
                          })
                          .borderRadius(4)
                          .visibility(this.dialogState.definition.pos.length > 0 ? Visibility.Visible : Visibility.None)

                        Text('In this context:')
                          .fontSize(12)
                          .fontColor(this.colors.TEXT_SECONDARY)
                          .margin({ left: 8 })
                      }

                      Text(this.dialogState.definition.contextMeaning)
                        .fontSize(18)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.colors.TEXT_PRIMARY)
                        .margin({ top: 8 })
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor(this.colors.PRIMARY_LIGHTEST)
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }

                  // Other meanings
                  if (this.dialogState.definition.commonMeanings.length > 0) {
                    Column() {
                      Text('其他释义')
                        .fontSize(12)
                        .fontColor(this.colors.TEXT_SECONDARY)
                        .margin({ bottom: 8 })

                      ForEach(this.dialogState.definition.commonMeanings, (meaning: WordMeaning, index: number) => {
                        Row() {
                          Text(meaning.pos)
                            .fontSize(14)
                            .fontColor(this.colors.WARNING)
                            .fontWeight(FontWeight.Medium)
                            .width(40)

                          Text(meaning.cn)
                            .fontSize(14)
                            .fontColor(this.colors.TEXT_PRIMARY)
                            .layoutWeight(1)
                        }
                        .width('100%')
                        .margin({ bottom: 6 })
                      }, (meaning: WordMeaning, index: number) => `meaning-${index}-${meaning.pos}`)
                    }
                    .width('100%')
                    .margin({ top: 16 })
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
                .constraintSize({ minHeight: 120, maxHeight: 220 })
              }
            }
            .width('100%')
            .padding(20)
          }
          .constraintSize({ maxHeight: this.newbieMode ? 420 : 250 })
        }

        Divider().color(this.colors.BORDER_LIGHT)

        // Action buttons
        this.buildDialogButtons()
      }
      .width('90%')
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
