// =====================================================
// WordListPage.ets - Word list for a selected book
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DBManager } from '../database/DBManager';
import { DesignTokens } from '../model/DesignTokens';
import { AppSettings, QueueItem, WordItem, WordMeaning, WordStatus } from '../model/WordModel';

interface WordListParams {
  bookId?: string;
  bookName?: string;
}

interface RouterParams {
  queue: QueueItem[];
}

@Entry
@Component
struct WordListPage {
  @State private isLoading: boolean = true;
  @State private bookId: string = '';
  @State private bookName: string = '词表';
  @State private searchText: string = '';
  @State private words: WordItem[] = [];
  @State private filteredWords: WordItem[] = [];
  @State private showDetailCard: boolean = false;
  @State private selectedWord: WordItem | null = null;
  @State private dailyNewWords: number = 10;

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.initialize();
  }

  private async initialize(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.context !== null) {
        await this.dbManager.initialize(this.context);
      }
      await this.loadSettings();
      const params = router.getParams() as WordListParams;
      this.bookId = params?.bookId ?? '';
      this.bookName = params?.bookName ?? '词表';
      await this.loadWords();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordListPage] Failed to load words:', errMsg);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadWords(): Promise<void> {
    const allWords = await this.dbManager.getAllWords();
    const list = this.bookId.length > 0
      ? allWords.filter((item: WordItem) => (item.bookId ?? '') === this.bookId)
      : allWords;
    this.words = list;
    this.applyFilter();
  }

  private applyFilter(): void {
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      this.filteredWords = this.words;
      return;
    }
    this.filteredWords = this.words.filter((word: WordItem) => {
      if (word.word.toLowerCase().includes(keyword)) {
        return true;
      }
      return this.getWordMeaningText(word).toLowerCase().includes(keyword);
    });
  }

  private getWordMeaningText(word: WordItem): string {
    const contextMeaning = word.definition?.contextMeaning ?? '';
    const common = word.definition?.commonMeanings ?? [];
    const commonText = common.map((m: WordMeaning) => `${m.pos} ${m.cn}`).join(' ');
    return `${contextMeaning} ${commonText}`.trim();
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW:
        return '新词';
      case WordStatus.LEARNING:
        return '学习中';
      case WordStatus.REVIEW:
        return '复习';
      case WordStatus.MASTERED:
        return '已掌握';
      case WordStatus.SUSPENDED:
        return '已暂停';
      default:
        return '未知';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW:
        return DesignTokens.Colors.PRIMARY;
      case WordStatus.LEARNING:
        return '#FF9800';
      case WordStatus.REVIEW:
        return '#9C27B0';
      case WordStatus.MASTERED:
        return '#4CAF50';
      case WordStatus.SUSPENDED:
        return DesignTokens.Colors.GRAY_500;
      default:
        return DesignTokens.Colors.GRAY_500;
    }
  }

  private openWordCard(word: WordItem): void {
    this.selectedWord = word;
    this.showDetailCard = true;
  }

  private closeWordCard(): void {
    this.showDetailCard = false;
  }

  private addToBook(): void {
    promptAction.showToast({ message: '已加入单词本', duration: 1500 });
  }

  private async loadSettings(): Promise<void> {
    const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
    if (settingsJson !== undefined && settingsJson.length > 0) {
      const settings = AppSettings.fromJSON(settingsJson);
      this.dailyNewWords = settings.dailyNewWords;
    }
  }

  private async startSessionFromBook(): Promise<void> {
    try {
      const queue = await this.dbManager.getLearningQueueByBook(this.bookId, this.dailyNewWords);
      if (queue.length === 0) {
        promptAction.showToast({ message: '当前词书暂无可学习单词', duration: 2000 });
        return;
      }
      const params: RouterParams = { queue };
      router.pushUrl({ url: 'pages/ReadPage', params });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `无法开始学习：${errMsg}`, duration: 2000 });
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('←')
            .fontSize(24)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .accessibilityText('返回')
            .onClick(() => router.back());

          Column() {
            Text(this.bookName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(DesignTokens.Colors.GRAY_900);

            Text(`共 ${this.words.length} 个单词`)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .margin({ top: 4 });
          }
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start);

          Blank();

          Text('开始学习')
            .fontSize(12)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
            .onClick(() => this.startSessionFromBook());
        }
        .width('100%')
        .height(64)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#F5F7FB');

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(DesignTokens.Colors.PRIMARY);

            Text('加载中...')
              .fontSize(14)
              .fontColor(DesignTokens.Colors.GRAY_500)
              .margin({ top: 12 });
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center);
        } else {
          Scroll() {
            Column() {
              Row() {
                Text('🔍')
                  .fontSize(18)
                  .fontColor(DesignTokens.Colors.GRAY_600);

                TextInput({ text: this.searchText, placeholder: '搜索单词或释义' })
                  .layoutWeight(1)
                  .height(44)
                  .fontSize(14)
                  .backgroundColor(Color.Transparent)
                  .onChange((value: string) => {
                    this.searchText = value;
                    this.applyFilter();
                  });
              }
              .width('100%')
              .height(52)
              .padding({ left: 12, right: 12 })
              .backgroundColor('#FFFFFFCC')
              .borderRadius(DesignTokens.BorderRadius.LG)
              .margin({ bottom: 16 });

              if (this.filteredWords.length === 0) {
                Column() {
                  Text('暂无单词')
                    .fontSize(14)
                    .fontColor(DesignTokens.Colors.GRAY_500);
                }
                .width('100%')
                .padding(DesignTokens.Spacing.XXL)
                .alignItems(HorizontalAlign.Center);
              } else {
                List() {
                  ForEach(this.filteredWords, (word: WordItem) => {
                    ListItem() {
                      this.buildWordRow(word);
                    }
                  }, (word: WordItem) => word.id.toString());
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 24 });
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off);
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FB');

      if (this.showDetailCard && this.selectedWord !== null) {
        this.buildWordDetailCard(this.selectedWord as WordItem);
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  buildWordRow(word: WordItem) {
    Column() {
      Row() {
        Text(word.word)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.GRAY_900);

        Blank();

        Text(this.getStatusText(word.status))
          .fontSize(12)
          .fontColor(DesignTokens.Colors.WHITE)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(this.getStatusColor(word.status))
          .borderRadius(12);
      }
      .width('100%');

      Text(this.getWordMeaningText(word))
        .fontSize(12)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ top: 6 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFFCC')
    .borderRadius(DesignTokens.BorderRadius.XL)
    .border({ width: 1, color: '#E5ECF7' })
    .margin({ bottom: 12 })
    .onClick(() => this.openWordCard(word));
  }

  @Builder
  buildWordDetailCard(word: WordItem) {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.4)
        .onClick(() => this.closeWordCard());
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 });

    Column() {
      Column() {
        Row() {
          Column() {
            Text(word.word)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(DesignTokens.Colors.GRAY_900);

            if (word.definition?.phonetic?.length) {
              Text(word.definition?.phonetic ?? '')
                .fontSize(12)
                .fontColor(DesignTokens.Colors.GRAY_500)
                .margin({ top: 4 });
            }
          }
          .alignItems(HorizontalAlign.Start);

          Blank();

          Text('✕')
            .fontSize(18)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .onClick(() => this.closeWordCard());
        }
        .width('100%');

        Divider().color('#EEF1F7').margin({ top: 12, bottom: 12 });

        Text(this.getWordMeaningText(word))
          .fontSize(14)
          .fontColor(DesignTokens.Colors.GRAY_800)
          .lineHeight(20)
          .width('100%');

        Button('加入单词本')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(DesignTokens.Colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.FULL)
          .margin({ top: 16 })
          .onClick(() => this.addToBook());
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFFCC')
      .borderRadius(DesignTokens.BorderRadius.XL);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 });
  }
}
