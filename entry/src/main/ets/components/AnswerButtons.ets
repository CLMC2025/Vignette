// =====================================================
// AnswerButtons.ets - Rating Buttons Component
// Displays four rating buttons with dynamic intervals
// =====================================================

import { Rating } from '../../model/WordModel';

/**
 * Answer button configuration
 */
interface ButtonConfig {
  rating: Rating;
  text: string;
  color: ResourceColor;
  interval: string;
}

/**
 * AnswerButtons - Four rating buttons with intervals
 */
@Component
export struct AnswerButtons {
  @Prop intervals: Map<Rating, number>; // Intervals in days
  onRate?: (rating: Rating) => void;
  
  build() {
    Column({ space: 8 }) {
      // Top row: AGAIN and HARD
      Row({ space: 8 }) {
        this.buildButton(this.getAgainConfig())
        this.buildButton(this.getHardConfig())
      }
      .width('100%')
      
      // Bottom row: GOOD and EASY
      Row({ space: 8 }) {
        this.buildButton(this.getGoodConfig())
        this.buildButton(this.getEasyConfig())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
  }
  
  /**
   * Build individual button
   */
  @Builder
  private buildButton(config: ButtonConfig) {
    Button() {
      Column({ space: 4 }) {
        Text(config.text)
          .fontSize(16)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
        
        Text(config.interval)
          .fontSize(12)
          .fontColor(Color.White)
          .opacity(0.9)
      }
      .padding({ top: 12, bottom: 12 })
    }
    .backgroundColor(config.color)
    .borderRadius(8)
    .layoutWeight(1)
    .height(80)
    .onClick(() => {
      if (this.onRate) {
        this.onRate(config.rating);
      }
    })
  }
  
  /**
   * Get AGAIN button config
   */
  private getAgainConfig(): ButtonConfig {
    return {
      rating: Rating.AGAIN,
      text: '重来',
      color: '#F44336', // Red
      interval: this.formatInterval(this.intervals?.get(Rating.AGAIN) ?? 0)
    };
  }
  
  /**
   * Get HARD button config
   */
  private getHardConfig(): ButtonConfig {
    return {
      rating: Rating.HARD,
      text: '困难',
      color: '#FF9800', // Orange
      interval: this.formatInterval(this.intervals?.get(Rating.HARD) ?? 0)
    };
  }
  
  /**
   * Get GOOD button config
   */
  private getGoodConfig(): ButtonConfig {
    return {
      rating: Rating.GOOD,
      text: '良好',
      color: '#4CAF50', // Green
      interval: this.formatInterval(this.intervals?.get(Rating.GOOD) ?? 0)
    };
  }
  
  /**
   * Get EASY button config
   */
  private getEasyConfig(): ButtonConfig {
    return {
      rating: Rating.EASY,
      text: '简单',
      color: '#2196F3', // Blue
      interval: this.formatInterval(this.intervals?.get(Rating.EASY) ?? 0)
    };
  }
  
  /**
   * Format interval in days to readable string
   */
  private formatInterval(days: number): string {
    if (days < 0.01) {
      // Less than ~15 minutes
      const minutes = Math.round(days * 24 * 60);
      return `${minutes}分钟`;
    } else if (days < 1) {
      // Less than 1 day, show hours
      const hours = Math.round(days * 24);
      return `${hours}小时`;
    } else if (days < 30) {
      // Less than 30 days
      return `${Math.round(days)}天`;
    } else if (days < 365) {
      // Less than 1 year, show months
      const months = Math.round(days / 30);
      return `${months}个月`;
    } else {
      // Over 1 year
      const years = (days / 365).toFixed(1);
      return `${years}年`;
    }
  }
}
