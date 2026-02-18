import promptAction from '@ohos.promptAction';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { DialogState } from './ReadPageModels';
import { WordItem, WordMeaning, WordStatus } from '../model/WordModel';

interface MoreActionButton {
  text: string;
  color: string | Resource;
}

interface DialogIndexResult {
  index: number;
}

@Component
export struct WordSidePanel {
  @Link dialogState: DialogState;
  @Link meaningExpanded: boolean;
  @Prop newbieMode: boolean;
  @Prop joinedBookCount: number;
  @Prop externalDictEnabled: boolean = false;
  @Prop externalDictLabel: string = '外部词典';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  onClose: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }
  onPlayPronunciation: (word: string) => void = () => {};
  onAddToBook: () => void = () => {};
  onAddToNotebook: () => void = () => {};
  onRemoveFromNotebook: () => void = () => {};
  onOpenExternalDict: (word: string) => void = () => {};
  onToggleKnown: (wordItem: WordItem) => void = () => {};

  private getKnownButtonText(item: WordItem): string {
    return item.status === WordStatus.KNOWN ? '恢复学习' : '标记已知';
  }

  private getJoinBookButtonText(): string {
    if (this.joinedBookCount > 0) {
      return `加入更多词书（已加入：${this.joinedBookCount}）`;
    }
    return '加入词书';
  }

  private getNotebookButtonText(): string {
    return this.dialogState.inNotebook ? '取消收藏' : '收藏';
  }

  private async openMoreActions(): Promise<void> {
    try {
      const buttons: MoreActionButton[] = [
        { text: this.getJoinBookButtonText(), color: this.colors.PRIMARY as string | Resource }
      ];
      if (this.externalDictEnabled) {
        buttons.push({ text: this.externalDictLabel, color: this.colors.PRIMARY as string | Resource });
      }
      buttons.push({ text: '取消', color: this.colors.TEXT_SECONDARY as string | Resource });

      const result = await (promptAction.showDialog({
        title: '更多操作',
        message: '可选择加入词书或打开外部词典。',
        buttons
      }) as Promise<DialogIndexResult>);

      if (result.index === 0) {
        this.onAddToBook();
        return;
      }
      if (this.externalDictEnabled && result.index === 1) {
        this.onOpenExternalDict(this.dialogState.word);
        return;
      }
    } catch (_) { /* 对话框选择取消或失败，忽略 */ }
  }

  build() {
    Column() {
      if (this.dialogState.isVisible) {
        Column()
          .width(48)
          .height(4)
          .backgroundColor(this.colors.GRAY_300)
          .borderRadius(2)
          .margin({ top: 10, bottom: 10 })

        Row() {
          Column() {
            Row() {
              Text(this.dialogState.word)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.colors.GRAY_900)
                .onClick(() => {
                  this.onPlayPronunciation(this.dialogState.word);
                })

              Image($r('sys.media.ohos_ic_public_sound'))
                .width(20)
                .height(20)
                .fillColor(this.colors.PRIMARY)
                .margin({ left: 8 })
                .onClick(() => {
                  this.onPlayPronunciation(this.dialogState.word);
                })
            }

            if (this.dialogState.definition !== null && this.dialogState.definition.phonetic.length > 0) {
              Text(this.dialogState.definition.phonetic)
                .fontSize(13)
                .fontColor(this.colors.GRAY_500)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('✕')
            .fontSize(18)
            .fontColor(this.colors.GRAY_500)
            .padding(8)
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 10 })

        Divider()
          .color(this.colors.GRAY_200)

        if (this.dialogState.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(this.colors.PRIMARY)
            Text('查询中...')
              .fontSize(13)
              .fontColor(this.colors.GRAY_500)
              .margin({ top: 8 })
          }
          .width('100%')
          .height(140)
          .justifyContent(FlexAlign.Center)
        } else if (this.dialogState.definition !== null) {
          Scroll() {
            Column() {
              if (this.dialogState.definition.contextMeaning.length > 0) {
                Column() {
                  if (this.dialogState.definition.pos.length > 0) {
                    Text(this.dialogState.definition.pos)
                      .fontSize(12)
                      .fontColor(this.colors.WHITE)
                      .backgroundColor(this.colors.PRIMARY)
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(4)
                  }

                  Text(this.dialogState.definition.contextMeaning)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.GRAY_900)
                    .margin({ top: this.dialogState.definition.pos.length > 0 ? 8 : 0 })
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.colors.PRIMARY_LIGHTEST)
                .borderRadius(10)
                .margin({ bottom: 12 })
              }

              Row() {
                Text('释义')
                  .fontSize(12)
                  .fontColor(this.colors.GRAY_600)

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

              if (this.meaningExpanded) {
                if (this.dialogState.definition.commonMeanings.length > 0) {
                  ForEach(this.dialogState.definition.commonMeanings, (meaning: WordMeaning, idx: number) => {
                    Row() {
                      Text(meaning.pos)
                        .fontSize(13)
                        .fontColor(this.colors.WARNING_DARK)
                        .width(44)

                      Text(meaning.cn)
                        .fontSize(14)
                        .fontColor(this.colors.GRAY_900)
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .margin({ bottom: idx === this.dialogState.definition!.commonMeanings.length - 1 ? 0 : 10 })
                  }, (meaning: WordMeaning, idx: number) => `meaning-${idx}-${meaning.pos}`)
                } else if (this.dialogState.definition.contextMeaning.length === 0) {
                  Text('暂无释义')
                    .fontSize(14)
                    .fontColor(this.colors.GRAY_600)
                }
              } else {
                Column() {
                  Text(this.newbieMode ? '先回忆一下？' : '点击展开释义')
                    .fontSize(13)
                    .fontColor(this.colors.GRAY_600)
                }
                .width('100%')
                .height(44)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor(this.colors.GRAY_100)
                .borderRadius(10)
                .onClick(() => {
                  this.meaningExpanded = true;
                })
              }
            }
            .width('100%')
            .padding(16)
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 360 })

          Row() {
            Button(this.getNotebookButtonText())
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.dialogState.inNotebook ? this.colors.GRAY_800 : this.colors.WHITE)
              .backgroundColor(this.dialogState.inNotebook ? this.colors.GRAY_100 : this.colors.PRIMARY)
              .borderRadius(22)
              .onClick(() => {
                if (this.dialogState.inNotebook) {
                  this.onRemoveFromNotebook();
                } else {
                  this.onAddToNotebook();
                }
              })

            Button(this.dialogState.wordItem !== null ? this.getKnownButtonText(this.dialogState.wordItem) : '标记已知')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.WHITE)
              .backgroundColor(this.colors.PRIMARY)
              .borderRadius(22)
              .margin({ left: 12 })
              .onClick(() => {
                if (this.dialogState.wordItem !== null) {
                  this.onToggleKnown(this.dialogState.wordItem);
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 10 })

          Column() {
            if (this.joinedBookCount > 0) {
              Text(`已加入词书：${this.joinedBookCount}`)
                .fontSize(12)
                .fontColor(this.colors.GRAY_500)
            }

            Text('更多操作')
              .fontSize(13)
              .fontColor(this.colors.PRIMARY)
              .margin({ top: this.joinedBookCount > 0 ? 6 : 0 })
              .onClick(() => { void this.openMoreActions(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
    }
    .width('100%')
.backgroundColor(this.colors.SURFACE_ELEVATED)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
