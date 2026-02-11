import { DialogState } from './ReadPageModels';
import { WordDefinition, WordMeaning } from '../model/WordModel';

@Component
export struct WordDetailDialog {
  @Link dialogState: DialogState;
  @Link meaningExpanded: boolean;
  @Prop newbieMode: boolean;
  @Prop joinedBookCount: number;

  onClose: () => void = () => {};
  onPlayPronunciation: (word: string) => void = () => {};
  onAddToBook: () => void = () => {};

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
        .fontColor('#FFFFFF')
        .backgroundColor('#4CAF50')
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
        .backgroundColor('#000000')
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
                .fontColor('#212121')
                .onClick(() => {
                  this.onPlayPronunciation(this.dialogState.word);
                })

              // Speaker
              Image($r('sys.media.ohos_ic_public_sound'))
                .width(24)
                .height(24)
                .fillColor('#2196F3')
                .margin({ left: 8 })
                .onClick(() => {
                  this.onPlayPronunciation(this.dialogState.word);
                })
            }

            // Phonetic
            if (this.dialogState.definition !== null && this.dialogState.definition.phonetic.length > 0) {
              Text(this.dialogState.definition.phonetic)
                .fontSize(14)
                .fontColor('#757575')
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // Close button
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(24)
            .height(24)
            .fillColor('#9E9E9E')
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({
          left: 20,
          right: 20,
          top: 20,
          bottom: 12
        })

        Divider().color('#EEEEEE')

        // Content
        if (this.dialogState.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#2196F3')
            Text('Loading definition...')
              .fontSize(14)
              .fontColor('#999999')
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
                  .fontColor('#666666')

                Blank()

                Text(this.meaningExpanded ? '收起' : '展开')
                  .fontSize(12)
                  .fontColor('#2196F3')
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
                    .fontColor('#666666')

                  Text('点击展开释义')
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 4 })
                }
                .width('100%')
                .height(48)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor('#F5F5F5')
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
                          .fontColor('#FFFFFF')
                          .backgroundColor('#2196F3')
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
                          .fontColor('#666666')
                          .margin({ left: 8 })
                      }

                      Text(this.dialogState.definition.contextMeaning)
                        .fontSize(18)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#333333')
                        .margin({ top: 8 })
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor('#E3F2FD')
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }

                  // Other meanings
                  if (this.dialogState.definition.commonMeanings.length > 0) {
                    Column() {
                      Text('其他释义')
                        .fontSize(12)
                        .fontColor('#666666')
                        .margin({ bottom: 8 })

                      ForEach(this.dialogState.definition.commonMeanings, (meaning: WordMeaning) => {
                        Row() {
                          Text(meaning.pos)
                            .fontSize(14)
                            .fontColor('#FF9800')
                            .fontWeight(FontWeight.Medium)
                            .width(40)

                          Text(meaning.cn)
                            .fontSize(14)
                            .fontColor('#333333')
                            .layoutWeight(1)
                        }
                        .width('100%')
                        .margin({ bottom: 6 })
                      })
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

        Divider().color('#EEEEEE')

        // Action buttons
        this.buildDialogButtons()
      }
      .width('90%')
      .backgroundColor('#FFFFFF')
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
