// =====================================================
// ReadingPage.ets - Reading Mode with Word Selection
// Split layout: article text + word details
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { DeckManager } from '../../manager/DeckManager';
import { SRSCard } from '../../model/DeckCardModel';

/**
 * Router params
 */
interface ReadingParams {
  deckId: number;
  materialId: number;
  title: string;
}

/**
 * Word info for selection
 */
interface WordInfo {
  word: string;
  position: number;
  isNew: boolean;
  isLearning: boolean;
  isKnown: boolean;
}

/**
 * ReadingPage - Reading mode with word selection
 */
@Entry
@Component
struct ReadingPage {
  @State private content: string = '';
  @State private words: WordInfo[] = [];
  @State private selectedWord: WordInfo | null = null;
  @State private showDetailPanel: boolean = false;
  @State private isLoading: boolean = true;
  
  private deckId: number = 0;
  private materialId: number = 0;
  private title: string = '';
  private deckManager: DeckManager = DeckManager.getInstance();
  
  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as ReadingParams;
    if (!params) {
      router.back();
      return;
    }
    
    this.deckId = params.deckId;
    this.materialId = params.materialId;
    this.title = params.title;
    
    await this.loadContent();
  }
  
  /**
   * Load reading content
   */
  private async loadContent(): Promise<void> {
    try {
      this.isLoading = true;
      
      // TODO: Load actual content from database/storage
      // For now, use placeholder
      this.content = 'The quick brown fox jumps over the lazy dog. ' +
        'This is a sample reading material. ' +
        'Click on any word to see its details and add it to your learning deck.';
      
      // Parse words (simplified)
      this.parseWords();
    } catch (error) {
      console.error('[ReadingPage] Failed to load content:', error);
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }
  
  /**
   * Parse words from content
   */
  private parseWords(): void {
    // Simple word parsing (split by spaces and punctuation)
    const wordPattern = /\b[a-zA-Z]+\b/g;
    const matches = this.content.matchAll(wordPattern);
    
    this.words = [];
    let index = 0;
    for (const match of matches) {
      if (match.index !== undefined) {
        this.words.push({
          word: match[0],
          position: match.index,
          isNew: true, // TODO: Check against database
          isLearning: false,
          isKnown: false
        });
      }
    }
  }
  
  /**
   * Handle word tap
   */
  private onWordTap(wordInfo: WordInfo): void {
    this.selectedWord = wordInfo;
    this.showDetailPanel = true;
  }
  
  /**
   * Add word to learning
   */
  private async addToLearning(): Promise<void> {
    if (!this.selectedWord) return;
    
    try {
      // Extract context around word
      const contextStart = Math.max(0, this.selectedWord.position - 50);
      const contextEnd = Math.min(this.content.length, this.selectedWord.position + 50);
      const context = this.content.substring(contextStart, contextEnd);
      
      // Add card to deck
      await this.deckManager.addCardToReadingDeck(
        this.deckId,
        this.selectedWord.word,
        '', // TODO: Get definition
        context,
        this.selectedWord.position
      );
      
      promptAction.showToast({ message: `已添加: ${this.selectedWord.word}` });
      this.showDetailPanel = false;
    } catch (error) {
      console.error('[ReadingPage] Failed to add word:', error);
      promptAction.showToast({ message: '添加失败' });
    }
  }
  
  /**
   * Mark word as known
   */
  private markAsKnown(): void {
    if (!this.selectedWord) return;
    
    // TODO: Update database
    promptAction.showToast({ message: `已标记: ${this.selectedWord.word}` });
    this.showDetailPanel = false;
  }
  
  build() {
    Row() {
      // Main content area
      Column() {
        // Header
        Row() {
          Button('←')
            .fontSize(18)
            .backgroundColor(Color.Transparent)
            .fontColor('#333333')
            .onClick(() => router.back())
          
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 16 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        
        if (this.isLoading) {
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
        } else {
          // Reading content
          Scroll() {
            Text() {
              this.buildInteractiveText()
            }
            .fontSize(16)
            .lineHeight(28)
          }
          .width('100%')
          .layoutWeight(1)
          .padding(16)
        }
      }
      .layoutWeight(1)
      .height('100%')
      
      // Detail panel (slide from right)
      if (this.showDetailPanel && this.selectedWord) {
        this.buildDetailPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
  
  /**
   * Build interactive text with clickable words
   */
  @Builder
  private buildInteractiveText() {
    // Simplified: render words with colors
    let lastPos = 0;
    
    for (const wordInfo of this.words) {
      // Add text before word
      if (wordInfo.position > lastPos) {
        Span(this.content.substring(lastPos, wordInfo.position))
          .fontColor('#333333');
      }
      
      // Add clickable word
      Span(wordInfo.word)
        .fontColor(this.getWordColor(wordInfo))
        .decoration({
          type: TextDecorationType.Underline,
          color: this.getWordColor(wordInfo)
        })
        .onClick(() => this.onWordTap(wordInfo));
      
      lastPos = wordInfo.position + wordInfo.word.length;
    }
    
    // Add remaining text
    if (lastPos < this.content.length) {
      Span(this.content.substring(lastPos))
        .fontColor('#333333');
    }
  }
  
  /**
   * Get word color based on status
   */
  private getWordColor(wordInfo: WordInfo): ResourceColor {
    if (wordInfo.isKnown) {
      return '#CCCCCC'; // Light gray for known
    } else if (wordInfo.isLearning) {
      return '#333333'; // Black for learning
    } else {
      return '#999999'; // Gray for new
    }
  }
  
  /**
   * Build detail panel
   */
  @Builder
  private buildDetailPanel() {
    Column() {
      // Close button
      Row() {
        Spacer()
        Button('×')
          .fontSize(24)
          .backgroundColor(Color.Transparent)
          .fontColor('#666666')
          .onClick(() => this.showDetailPanel = false)
      }
      .width('100%')
      .padding(16)
      
      // Word
      Text(this.selectedWord!.word)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 8 })
      
      // Context
      Text('语境:')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 24 })
      
      Text(this.extractContext(this.selectedWord!.position))
        .fontSize(14)
        .fontColor('#666666')
        .lineHeight(22)
        .margin({ top: 8 })
      
      Spacer()
      
      // Actions
      Column({ space: 12 }) {
        Button('加入学习')
          .width('100%')
          .backgroundColor('#2196F3')
          .onClick(() => this.addToLearning())
        
        Button('标记已知')
          .width('100%')
          .backgroundColor('#EEEEEE')
          .fontColor('#333333')
          .onClick(() => this.markAsKnown())
      }
      .padding(16)
    }
    .width(300)
    .height('100%')
    .backgroundColor(Color.White)
    .shadow({ radius: 8, color: '#20000000', offsetX: -2 })
  }
  
  /**
   * Extract context around position
   */
  private extractContext(position: number): string {
    const start = Math.max(0, position - 50);
    const end = Math.min(this.content.length, position + 50);
    return this.content.substring(start, end);
  }
}
