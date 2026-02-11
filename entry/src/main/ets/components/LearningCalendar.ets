import { DesignTokens } from '../model/DesignTokens';

export interface DailyActivity {
  date: number; // timestamp
  count: number;
}

@Component
export struct LearningCalendar {
  @Prop activities: DailyActivity[];
  @State currentMonth: Date = new Date();

  private getMonthDays(): Date[] {
    const year = this.currentMonth.getFullYear();
    const month = this.currentMonth.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    
    const days: Date[] = [];
    
    // Fill previous month days
    const startDayOfWeek = firstDay.getDay() === 0 ? 6 : firstDay.getDay() - 1; // Mon=0
    for (let i = startDayOfWeek; i > 0; i--) {
      days.push(new Date(year, month, 1 - i));
    }
    
    // Fill current month days
    for (let i = 1; i <= lastDay.getDate(); i++) {
      days.push(new Date(year, month, i));
    }
    
    // Fill next month days to complete grid (up to 42 cells)
    const remaining = 42 - days.length;
    for (let i = 1; i <= remaining; i++) {
      days.push(new Date(year, month + 1, i));
    }
    
    return days;
  }

  private getActivityLevel(date: Date): number {
    const dStr = date.toDateString();
    const activity = this.activities.find(a => new Date(a.date).toDateString() === dStr);
    if (!activity) return 0;
    if (activity.count >= 50) return 4;
    if (activity.count >= 30) return 3;
    if (activity.count >= 10) return 2;
    return 1;
  }

  private getLevelColor(level: number): string {
    switch (level) {
      case 4: return '#2E7D32'; // High
      case 3: return '#4CAF50';
      case 2: return '#81C784';
      case 1: return '#C8E6C9';
      default: return '#F1F3F4'; // None
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text(`${this.currentMonth.getFullYear()}年 ${this.currentMonth.getMonth() + 1}月`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.GRAY_900)
        
        Blank()
        
        Row() {
          Text('<')
            .fontSize(20)
            .padding(8)
            .onClick(() => {
              const d = new Date(this.currentMonth);
              d.setMonth(d.getMonth() - 1);
              this.currentMonth = d;
            })
          
          Text('>')
            .fontSize(20)
            .padding(8)
            .onClick(() => {
              const d = new Date(this.currentMonth);
              d.setMonth(d.getMonth() + 1);
              this.currentMonth = d;
            })
        }
      }
      .width('100%')
      .padding({ bottom: 12 })

      // Week Header
      Row() {
        ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string) => {
          Text(day)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .width('14.28%')
            .textAlign(TextAlign.Center)
        })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // Days Grid
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.getMonthDays(), (date: Date) => {
          Column() {
            Column() {
              // Only show day number if current month
              if (date.getMonth() === this.currentMonth.getMonth()) {
                Text(date.getDate().toString())
                  .fontSize(10)
                  .fontColor(this.getActivityLevel(date) > 2 ? Color.White : DesignTokens.Colors.GRAY_700)
              }
            }
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor(this.getLevelColor(this.getActivityLevel(date)))
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
          .width('14.28%')
          .height(32)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0000000D', offsetY: 2 })
  }
}
