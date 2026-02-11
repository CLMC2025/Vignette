// =====================================================
// ContextView.ets - Context Display Component
// Shows context text with type badge and highlighted word
// =====================================================

import { ContextType } from '../../model/DeckCardModel';

/**
 * Context data interface
 */
export interface ContextData {
  text: string;
  type: ContextType;
  targetWord?: string;
}

/**
 * ContextView - Displays context with type badge and word highlighting
 */
@Component
export struct ContextView {
  @Prop context: ContextData;
  
  build() {
    if (!this.context || !this.context.text) {
      return;
    }
    
    Column({ space: 8 }) {
      // Type badge
      Row() {
        Text(this.getTypeBadgeText())
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(4)
          .backgroundColor(this.getTypeBadgeColor())
      }
      
      // Context text with highlighting
      Text() {
        if (this.context.targetWord) {
          this.highlightWord(this.context.text, this.context.targetWord);
        } else {
          Span(this.context.text)
            .fontSize(14)
            .fontColor('#666666');
        }
      }
      .lineHeight(22)
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
  }
  
  /**
   * Get badge text based on context type
   */
  private getTypeBadgeText(): string {
    switch (this.context.type) {
      case ContextType.STORY:
        return 'AI生成';
      case ContextType.SENTENCE:
        return '例句';
      case ContextType.READING:
        return '原文';
      default:
        return '语境';
    }
  }
  
  /**
   * Get badge color based on context type
   */
  private getTypeBadgeColor(): ResourceColor {
    switch (this.context.type) {
      case ContextType.STORY:
        return '#2196F3'; // Blue for AI
      case ContextType.SENTENCE:
        return '#FF9800'; // Orange for sentence
      case ContextType.READING:
        return '#4CAF50'; // Green for reading
      default:
        return '#9E9E9E'; // Gray default
    }
  }
  
  /**
   * Highlight target word in context text
   */
  private highlightWord(text: string, targetWord: string): void {
    const lowerText = text.toLowerCase();
    const lowerTarget = targetWord.toLowerCase();
    const index = lowerText.indexOf(lowerTarget);
    
    if (index === -1) {
      // Word not found, show text as-is
      Span(text)
        .fontSize(14)
        .fontColor('#666666');
      return;
    }
    
    // Split text into parts: before, target, after
    const before = text.substring(0, index);
    const target = text.substring(index, index + targetWord.length);
    const after = text.substring(index + targetWord.length);
    
    // Render with highlighting
    if (before) {
      Span(before)
        .fontSize(14)
        .fontColor('#666666');
    }
    
    Span(target)
      .fontSize(14)
      .fontColor('#2196F3')
      .fontWeight(FontWeight.Bold)
      .decoration({ type: TextDecorationType.Underline, color: '#2196F3' });
    
    if (after) {
      Span(after)
        .fontSize(14)
        .fontColor('#666666');
    }
  }
}
