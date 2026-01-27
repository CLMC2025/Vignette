// =====================================================
// WordDetailPage.ets - Word details page
// Shows definition, learning status, FSRS metrics and history summary
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';

import { DesignTokens } from '../model/DesignTokens';
import { LoadingAnimation, LoadingType } from '../ui/LoadingAnimations';
import { DBManager } from '../database/DBManager';
import { WordItem, WordStatus, WordMeaning } from '../model/WordModel';

interface WordDetailParams {
  wordId?: number;
}

@Entry
@Component
struct WordDetailPage {
  @State private isLoading: boolean = true;
  @State private word: WordItem | null = null;
  @State private showAlgorithmDetails: boolean = false;

  private wordId: number = 0;
  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.init();
  }

  private async init(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.context !== null) {
        await this.dbManager.initialize(this.context);
      }

      const params = router.getParams() as WordDetailParams;
      this.wordId = Number(params?.wordId ?? 0);
      if (this.wordId <= 0) {
        promptAction.showToast({ message: '无法打开单词详情：参数缺失', duration: 1500 });
        router.back();
        return;
      }

      const w = await this.dbManager.getWordById(this.wordId);
      if (w === null) {
        promptAction.showToast({ message: '单词不存在或已被删除', duration: 1500 });
        router.back();
        return;
      }
      this.word = w;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] init failed:', errMsg);
      promptAction.showToast({ message: `加载详情失败：${errMsg}`, duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW: return '新词';
      case WordStatus.LEARNING: return '学习中';
      case WordStatus.REVIEW: return '复习';
      case WordStatus.MASTERED: return '已掌握';
      case WordStatus.SUSPENDED: return '已暂停';
      default: return '未知';
    }
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW: return '#2196F3';
      case WordStatus.LEARNING: return '#FF9800';
      case WordStatus.REVIEW: return '#9C27B0';
      case WordStatus.MASTERED: return '#4CAF50';
      case WordStatus.SUSPENDED: return '#9E9E9E';
      default: return '#9E9E9E';
    }
  }

  private formatTime(ts: number): string {
    if (ts <= 0) return '-';
    const d = new Date(ts);
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private formatRelativeTime(ts: number): string {
    const diff = ts - Date.now();
    const minuteMs = 60 * 1000;
    const hourMs = 60 * minuteMs;
    const dayMs = 24 * hourMs;

    if (diff <= 0) return '现在';
    if (diff < hourMs) {
      const minutes = Math.max(1, Math.round(diff / minuteMs));
      return `${minutes}分钟`;
    }
    if (diff < dayMs) {
      const hours = Math.max(1, Math.round(diff / hourMs));
      return `${hours}小时`;
    }
    const days = Math.max(1, Math.round(diff / dayMs));
    return `${days}天`;
  }

  private getMasteryLabel(word: WordItem): string {
    const stability = word.fsrsState.stability;
    if (word.status === WordStatus.MASTERED || stability >= 30) {
      return '🌳 已成树';
    }
    if (stability >= 10) {
      return '🌿 成长中';
    }
    if (stability >= 3) {
      return '🌱 发芽';
    }
    return '🌰 种子';
  }

  private getNextReviewLabel(word: WordItem): string {
    const formatted = this.formatTime(word.dueDate);
    const relative = this.formatRelativeTime(word.dueDate);
    if (relative === '现在') {
      return `${formatted}（现在可复习）`;
    }
    return `${formatted}（还有${relative}）`;
  }

  private buildMeaningLine(m: WordMeaning): string {
    const pos = m.pos.trim().length > 0 ? `${m.pos} ` : '';
    const cn = m.cn.trim().length > 0 ? m.cn : '-';
    return `${pos}${cn}`;
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .accessibilityText('返回')
          .onClick(() => router.back())
          .padding({ right: 12, top: 6, bottom: 6 })

        Text('单词详情')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
          .fontColor(DesignTokens.Colors.GRAY_900)

        Blank()
      }
      .width('100%')
      .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING, top: 12, bottom: 12 })

      if (this.isLoading) {
        Column() {
          LoadingAnimation({
            type: LoadingType.PULSE,
            animSize: 60,
            color: DesignTokens.Colors.PRIMARY,
            text: '加载中...'
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.word === null) {
        Column() {
          Text('暂无数据')
            .fontSize(16)
            .fontColor(DesignTokens.Colors.GRAY_600)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // Word header card
            Column() {
              Row() {
                Text((this.word as WordItem).word)
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(DesignTokens.Colors.GRAY_900)

                Blank()

                Column() {
                  Text(this.getMasteryLabel(this.word as WordItem))
                    .fontSize(12)
                    .fontColor(DesignTokens.Colors.GRAY_800)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(DesignTokens.Colors.GRAY_100)
                    .borderRadius(10)

                  Text(this.getStatusText((this.word as WordItem).status))
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                    .backgroundColor(this.getStatusColor((this.word as WordItem).status))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .margin({ top: 6 })
                }
              }
              .width('100%')

              if ((this.word as WordItem).definition.phonetic.trim().length > 0) {
                Text(`[${(this.word as WordItem).definition.phonetic}]`)
                  .fontSize(14)
                  .fontColor(DesignTokens.Colors.GRAY_600)
                  .margin({ top: 8 })
              }

              if ((this.word as WordItem).definition.contextMeaning.trim().length > 0) {
                Text((this.word as WordItem).definition.contextMeaning)
                  .fontSize(16)
                  .fontColor(DesignTokens.Colors.GRAY_800)
                  .margin({ top: 10 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)

            // Meaning section
            Column() {
              Text('常用释义')
                .fontSize(14)
                .fontColor(DesignTokens.Colors.GRAY_700)
                .fontWeight(FontWeight.Medium)
              if ((this.word as WordItem).definition.commonMeanings.length === 0) {
                Text('暂无释义（可在设置中配置 API 后自动生成）')
              } else {
                Column() {
                  ForEach((this.word as WordItem).definition.commonMeanings, (m: WordMeaning, idx: number) => {
                    Text(`${idx + 1}. ${this.buildMeaningLine(m)}`)
                      .fontSize(14)
                      .fontColor(DesignTokens.Colors.GRAY_800)
                      .margin({ top: 6 })
                  }, (m: WordMeaning) => `${m.pos}-${m.cn}`)
                }
                .width('100%')
                .margin({ top: 6 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .margin({ top: 12 })

            // Learning data
            Column() {
              Text('学习数据')
                .fontSize(14)
                .fontColor(DesignTokens.Colors.GRAY_700)
                .fontWeight(FontWeight.Medium)

              this.buildKV('下次复习', this.getNextReviewLabel(this.word as WordItem))
              this.buildKV('复习次数', `${(this.word as WordItem).history.getReviewCount()}`)
              this.buildKV('错误次数', `${(this.word as WordItem).lapseCount}`)
              if ((this.word as WordItem).tags.length > 0) {
                this.buildKV('标签', (this.word as WordItem).tags.join(', '))
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .margin({ top: 12 })

            Column() {
              Row() {
                Text('算法参数')
                  .fontSize(14)
                  .fontColor(DesignTokens.Colors.GRAY_700)
                  .fontWeight(FontWeight.Medium)

                Blank()

                Text(this.showAlgorithmDetails ? '收起' : '展开')
                  .fontSize(12)
                  .fontColor(DesignTokens.Colors.PRIMARY)
              }
              .width('100%')
              .onClick(() => {
                this.showAlgorithmDetails = !this.showAlgorithmDetails;
              })

              if (this.showAlgorithmDetails) {
                this.buildKV('稳定度 Stability', (this.word as WordItem).fsrsState.stability.toFixed(2))
                this.buildKV('难度 Difficulty', (this.word as WordItem).fsrsState.difficulty.toFixed(2))
                this.buildKV('创建时间', this.formatTime((this.word as WordItem).createdAt))
                this.buildKV('更新时间', this.formatTime((this.word as WordItem).updatedAt))
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .margin({ top: 12, bottom: 24 })
          }
          .width('100%')
          .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignTokens.Colors.GRAY_50)
  }

  @Builder
  private buildKV(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(DesignTokens.Colors.GRAY_600)
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor(DesignTokens.Colors.GRAY_900)
    }
    .width('100%')
    .margin({ top: 10 })
  }
}
