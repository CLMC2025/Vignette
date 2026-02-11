// =====================================================
// DeckPickerPage.ets - Deck Selection Page
// Shows all decks with statistics
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { DeckManager } from '../../manager/DeckManager';
import { Deck, DeckStats } from '../../model/DeckModel';

/**
 * DeckPickerPage - Main deck selection interface
 */
@Entry
@Component
struct DeckPickerPage {
  @State private decks: Deck[] = [];
  @State private isLoading: boolean = true;
  @State private showCreateMenu: boolean = false;
  
  private deckManager: DeckManager = DeckManager.getInstance();
  
  async aboutToAppear(): Promise<void> {
    await this.loadDecks();
  }
  
  async onPageShow(): Promise<void> {
    // Refresh decks when returning to page
    await this.loadDecks();
  }
  
  /**
   * Load decks with statistics
   */
  private async loadDecks(): Promise<void> {
    try {
      this.isLoading = true;
      this.decks = await this.deckManager.getDecksWithStats();
    } catch (error) {
      console.error('[DeckPickerPage] Failed to load decks:', error);
      promptAction.showToast({ message: '加载牌组失败' });
    } finally {
      this.isLoading = false;
    }
  }
  
  /**
   * Navigate to reviewer page
   */
  private openDeck(deck: Deck): void {
    if (!deck.stats || deck.stats.totalCount === 0) {
      promptAction.showToast({ message: '该牌组暂无到期卡片' });
      return;
    }
    
    router.pushUrl({
      url: 'pages/study/ReviewerPage',
      params: { deckId: deck.id }
    });
  }
  
  /**
   * Create deck from word book
   */
  private async createBookDeck(): Promise<void> {
    // TODO: Show dialog to select book
    // For now, create a test deck
    try {
      const deck = await this.deckManager.createBookDeck('cet4', 'CET-4词汇');
      promptAction.showToast({ message: `已创建牌组: ${deck.name}` });
      await this.loadDecks();
    } catch (error) {
      console.error('[DeckPickerPage] Failed to create deck:', error);
      promptAction.showToast({ message: '创建牌组失败' });
    }
  }
  
  /**
   * Navigate to reading list
   */
  private openReadingList(): void {
    router.pushUrl({ url: 'pages/reading/ReadingListPage' });
  }
  
  build() {
    Column() {
      // Header
      Row() {
        Text('我的牌组')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        
        Spacer()
        
        // Add button
        Button({ type: ButtonType.Circle }) {
          Text('+')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .backgroundColor('#2196F3')
        .bindMenu([
          {
            value: '从单词书创建',
            action: () => this.createBookDeck()
          },
          {
            value: '阅读材料',
            action: () => this.openReadingList()
          }
        ])
      }
      .width('100%')
      .padding(16)
      
      if (this.isLoading) {
        // Loading state
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.decks.length === 0) {
        // Empty state
        Column() {
          Text('📚')
            .fontSize(48)
          Text('还没有牌组')
            .fontSize(18)
            .fontColor('#333333')
            .margin({ top: 16 })
          Text('点击右上角 + 号创建牌组')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // Deck list
        List({ space: 12 }) {
          ForEach(this.decks, (deck: Deck) => {
            ListItem() {
              this.buildDeckCard(deck)
            }
          }, (deck: Deck) => deck.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
  
  /**
   * Build deck card
   */
  @Builder
  private buildDeckCard(deck: Deck) {
    Column() {
      // Deck name
      Text(deck.name)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      
      // Statistics
      if (deck.stats) {
        Row({ space: 16 }) {
          // New cards
          if (deck.stats.newCount > 0) {
            Row({ space: 4 }) {
              Text(`${deck.stats.newCount}`)
                .fontSize(16)
                .fontColor('#4CAF50')
                .fontWeight(FontWeight.Bold)
              Text('新')
                .fontSize(12)
                .fontColor('#4CAF50')
            }
          }
          
          // Learning cards
          if (deck.stats.learningCount > 0) {
            Row({ space: 4 }) {
              Text(`${deck.stats.learningCount}`)
                .fontSize(16)
                .fontColor('#9C27B0')
                .fontWeight(FontWeight.Bold)
              Text('学')
                .fontSize(12)
                .fontColor('#9C27B0')
            }
          }
          
          // Review cards
          if (deck.stats.reviewCount > 0) {
            Row({ space: 4 }) {
              Text(`${deck.stats.reviewCount}`)
                .fontSize(16)
                .fontColor('#FF9800')
                .fontWeight(FontWeight.Bold)
              Text('复')
                .fontSize(12)
                .fontColor('#FF9800')
            }
          }
          
          // Relearning cards
          if (deck.stats.relearnCount > 0) {
            Row({ space: 4 }) {
              Text(`${deck.stats.relearnCount}`)
                .fontSize(16)
                .fontColor('#F44336')
                .fontWeight(FontWeight.Bold)
              Text('重')
                .fontSize(12)
                .fontColor('#F44336')
            }
          }
          
          // No due cards
          if (deck.stats.totalCount === 0) {
            Text('暂无到期卡片')
              .fontSize(14)
              .fontColor('#999999')
          }
        }
        .margin({ top: 8 })
      }
      
      // Deck type indicator
      Text(deck.isBookDeck() ? '单词书' : '阅读材料')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: '#10000000', offsetY: 2 })
    .onClick(() => this.openDeck(deck))
  }
}
