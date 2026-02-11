// =====================================================
// ReviewerPage.ets - Study/Review Page
// Card review interface with FSRS integration
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { StudyManager, SessionStats } from '../../manager/StudyManager';
import { SRSCard } from '../../model/DeckCardModel';
import { Rating } from '../../model/WordModel';
import { ContextView, ContextData } from '../../components/ContextView';
import { AnswerButtons } from '../../components/AnswerButtons';

/**
 * Router params interface
 */
interface ReviewerParams {
  deckId: number;
}

/**
 * ReviewerPage - Card review interface
 */
@Entry
@Component
struct ReviewerPage {
  @State private currentCard: SRSCard | null = null;
  @State private showAnswer: boolean = false;
  @State private intervals: Map<Rating, number> = new Map();
  @State private stats: SessionStats = new SessionStats();
  @State private isInitializing: boolean = true;
  @State private isCompleted: boolean = false;
  
  private deckId: number = 0;
  private studyManager: StudyManager | null = null;
  
  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as ReviewerParams;
    if (!params || !params.deckId) {
      promptAction.showToast({ message: '参数错误' });
      router.back();
      return;
    }
    
    this.deckId = params.deckId;
    await this.initialize();
  }
  
  /**
   * Initialize study session
   */
  private async initialize(): Promise<void> {
    try {
      this.isInitializing = true;
      
      this.studyManager = new StudyManager(this.deckId);
      await this.studyManager.initialize();
      
      this.stats = this.studyManager.getSessionStats();
      
      if (this.studyManager.hasMore()) {
        this.loadCurrentCard();
      } else {
        this.isCompleted = true;
      }
    } catch (error) {
      console.error('[ReviewerPage] Initialization failed:', error);
      promptAction.showToast({ message: '初始化失败' });
      router.back();
    } finally {
      this.isInitializing = false;
    }
  }
  
  /**
   * Load current card and preview intervals
   */
  private loadCurrentCard(): void {
    if (!this.studyManager) return;
    
    this.currentCard = this.studyManager.getCurrentCard();
    this.showAnswer = false;
    
    if (this.currentCard) {
      this.intervals = this.studyManager.previewIntervals(this.currentCard);
    }
  }
  
  /**
   * Process rating
   */
  private async processRating(rating: Rating): Promise<void> {
    if (!this.studyManager || !this.currentCard) return;
    
    try {
      await this.studyManager.processRating(rating);
      this.stats = this.studyManager.getSessionStats();
      
      if (this.studyManager.hasMore()) {
        this.loadCurrentCard();
      } else {
        this.isCompleted = true;
      }
    } catch (error) {
      console.error('[ReviewerPage] Failed to process rating:', error);
      promptAction.showToast({ message: '处理评分失败' });
    }
  }
  
  /**
   * Undo last review
   */
  private async undoReview(): Promise<void> {
    if (!this.studyManager) return;
    
    const success = await this.studyManager.undoLastReview();
    if (success) {
      this.loadCurrentCard();
      this.stats = this.studyManager.getSessionStats();
      this.isCompleted = false;
      promptAction.showToast({ message: '已撤销' });
    } else {
      promptAction.showToast({ message: '无法撤销' });
    }
  }
  
  build() {
    Column() {
      if (this.isInitializing) {
        // Loading state
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('准备中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.isCompleted) {
        // Completion screen
        this.buildCompletionView()
      } else if (this.currentCard) {
        // Review interface
        this.buildReviewView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
  
  /**
   * Build review view
   */
  @Builder
  private buildReviewView() {
    Column() {
      // Progress bar
      Row() {
        Button('←')
          .fontSize(18)
          .backgroundColor(Color.Transparent)
          .fontColor('#333333')
          .onClick(() => router.back())
        
        Spacer()
        
        Text(`${this.stats.reviewedCount + 1} / ${this.stats.totalCount}`)
          .fontSize(16)
          .fontColor('#666666')
        
        Spacer()
        
        Button('撤销')
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .fontColor('#2196F3')
          .onClick(() => this.undoReview())
          .enabled(this.stats.reviewedCount > 0)
      }
      .width('100%')
      .padding(16)
      
      // Card content
      Column() {
        // Front (word)
        Text(this.currentCard!.front)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ top: 40 })
        
        // Context (if available)
        if (this.currentCard!.context) {
          ContextView({
            context: {
              text: this.currentCard!.context,
              type: this.currentCard!.contextType,
              targetWord: this.currentCard!.front
            } as ContextData
          })
          .margin({ top: 24, left: 16, right: 16 })
        }
        
        Spacer()
        
        if (this.showAnswer) {
          // Back (definition)
          Column({ space: 8 }) {
            Divider()
              .color('#EEEEEE')
              .margin({ bottom: 16 })
            
            Text(this.currentCard!.back)
              .fontSize(18)
              .fontColor('#333333')
              .lineHeight(28)
          }
          .width('100%')
          .padding(16)
        } else {
          // Show answer button
          Button('显示答案')
            .fontSize(18)
            .width('80%')
            .height(50)
            .backgroundColor('#2196F3')
            .borderRadius(25)
            .onClick(() => this.showAnswer = true)
        }
        
        Spacer()
      }
      .layoutWeight(1)
      .width('100%')
      
      // Rating buttons (shown after answer revealed)
      if (this.showAnswer) {
        AnswerButtons({
          intervals: this.intervals,
          onRate: (rating: Rating) => this.processRating(rating)
        })
      }
    }
    .width('100%')
    .height('100%')
  }
  
  /**
   * Build completion view
   */
  @Builder
  private buildCompletionView() {
    Column() {
      Text('🎉')
        .fontSize(64)
        .margin({ top: 60 })
      
      Text('完成学习!')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24 })
      
      // Statistics
      Column({ space: 16 }) {
        Row() {
          Text('已复习:')
            .fontSize(16)
            .fontColor('#666666')
          Spacer()
          Text(`${this.stats.reviewedCount}`)
            .fontSize(16)
            .fontColor('#333333')
            .fontWeight(FontWeight.Bold)
        }
        .width('80%')
        
        if (this.stats.newCount > 0) {
          Row() {
            Text('新卡片:')
              .fontSize(16)
              .fontColor('#666666')
            Spacer()
            Text(`${this.stats.newCount}`)
              .fontSize(16)
              .fontColor('#4CAF50')
              .fontWeight(FontWeight.Bold)
          }
          .width('80%')
        }
        
        if (this.stats.learningCount > 0) {
          Row() {
            Text('学习中:')
              .fontSize(16)
              .fontColor('#666666')
            Spacer()
            Text(`${this.stats.learningCount}`)
              .fontSize(16)
              .fontColor('#9C27B0')
              .fontWeight(FontWeight.Bold)
          }
          .width('80%')
        }
        
        if (this.stats.reviewCount > 0) {
          Row() {
            Text('复习:')
              .fontSize(16)
              .fontColor('#666666')
            Spacer()
            Text(`${this.stats.reviewCount}`)
              .fontSize(16)
              .fontColor('#FF9800')
              .fontWeight(FontWeight.Bold)
          }
          .width('80%')
        }
      }
      .margin({ top: 40 })
      .padding(24)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .width('90%')
      
      Spacer()
      
      Button('返回')
        .fontSize(18)
        .width('80%')
        .height(50)
        .backgroundColor('#2196F3')
        .borderRadius(25)
        .margin({ bottom: 40 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
