// =====================================================
// ProgressCharts.ets - 进度图表组件库
// 提供各种进度可视化和统计图表
// =====================================================

import { DesignTokens } from '../model/DesignTokens';

/**
 * 图表类型
 */
export enum ChartType {
  LINE = 'line',
  BAR = 'bar',
  PIE = 'pie',
  DONUT = 'donut',
  AREA = 'area',
  RADIAL_BAR = 'radial_bar'
}

/**
 * 图表数据点
 */
export class ChartDataPoint {
  label: string;
  value: number;
  color: ResourceColor;
  timestamp: number;

  constructor(
    label: string,
    value: number,
    color: ResourceColor = DesignTokens.Colors.PRIMARY,
    timestamp: number = Date.now()
  ) {
    this.label = label;
    this.value = value;
    this.color = color;
    this.timestamp = timestamp;
  }
}

/**
 * 图表数据集
 */
export class ChartDataset {
  label: string;
  data: ChartDataPoint[];
  type: ChartType;

  constructor(
    label: string,
    data: ChartDataPoint[],
    type: ChartType = ChartType.BAR
  ) {
    this.label = label;
    this.data = data;
    this.type = type;
  }
}

/**
 * 学习进度数据
 */
export class LearningProgressData {
  date: number;
  wordsLearned: number;
  wordsReviewed: number;
  accuracy: number;
  studyTime: number;  // 分钟

  constructor(
    date: number,
    wordsLearned: number = 0,
    wordsReviewed: number = 0,
    accuracy: number = 0,
    studyTime: number = 0
  ) {
    this.date = date;
    this.wordsLearned = wordsLearned;
    this.wordsReviewed = wordsReviewed;
    this.accuracy = accuracy;
    this.studyTime = studyTime;
  }
}

/**
 * 词汇分布数据
 */
export class VocabularyDistributionData {
  category: string;
  count: number;
  percentage: number;
  color: ResourceColor;

  constructor(
    category: string,
    count: number,
    percentage: number = 0,
    color: ResourceColor = DesignTokens.Colors.PRIMARY
  ) {
    this.category = category;
    this.count = count;
    this.percentage = percentage;
    this.color = color;
  }
}

/**
 * 统计卡片数据
 */
export class StatsCardData {
  title: string;
  value: string | number;
  subtitle: string;
  trend: 'up' | 'down' | 'stable';
  trendPercentage: number;
  icon: string;

  constructor(
    title: string,
    value: string | number,
    subtitle: string = '',
    trend: 'up' | 'down' | 'stable' = 'stable',
    trendPercentage: number = 0,
    icon: string = ''
  ) {
    this.title = title;
    this.value = value;
    this.subtitle = subtitle;
    this.trend = trend;
    this.trendPercentage = trendPercentage;
    this.icon = icon;
  }
}

/**
 * 进度图表组件
 */
@Builder
function ProgressChart(
  title: string,
  progress: number,
  total: number,
  color: ResourceColor = DesignTokens.Colors.PRIMARY
): void {
  Column() {
    Text(title)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(DesignTokens.Colors.GRAY_600)
      .margin({ bottom: DesignTokens.Spacing.SM })

    Stack() {
      Progress({
        value: progress,
        total: total,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(8)
        .color(color)
        .backgroundColor(DesignTokens.Colors.GRAY_300)

      Text(`${total > 0 ? Math.round(progress / total * 100) : 0}%`)
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(color)
    }
    .width('100%')
    .height(100)
    .alignContent(Alignment.Center)
  }
  .width('100%')
  .padding(DesignTokens.Spacing.LG)
  .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
  .borderRadius(DesignTokens.BorderRadius.LG)
}

/**
 * 线性图表组件
 */
@Builder
function LineChart(
  title: string,
  data: ChartDataPoint[],
  showLabels: boolean = true
): void {
  Column() {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
        .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
      .margin({ bottom: 16 })

    Stack() {
      // 简化实现：使用Progress模拟线图
      ForEach(data, (point: ChartDataPoint, index: number) => {
        Column() {
          if (showLabels && index < data.length - 1) {
            Text(point.label)
              .fontSize(10)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
              .margin({ bottom: 4 })
          }
          
          Row() {
            Circle({ width: 8, height: 8 })
              .fill(point.color)
              .margin({ right: 4 })
            
            Text(`${point.value}`)
              .fontSize(12)
            .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .position({ x: `${index * 80 + 20}vp`, y: '180vp' })
      }, (point: ChartDataPoint, index: number) => `line-${index}-${point.label}`)
    }
    .width('100%')
    .height(200)
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(12)
  }
  .width('100%')
  .padding(16)
  .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
  .borderRadius(12)
}

/**
 * 条形图组件
 */
@Builder
function BarChart(
  title: string,
  data: ChartDataPoint[]
): void {
  Column() {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
      .margin({ bottom: 16 })

    Row() {
      ForEach(data, (point: ChartDataPoint, index: number) => {
        Column() {
          Text(point.label)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .margin({ bottom: 4 })
          
          Column() {
            Row()
              .width('100%')
              .height(150)
              .backgroundColor(point.color)
              .borderRadius({ topLeft: 4, topRight: 4, bottomLeft: 4, bottomRight: 4 })
              .justifyContent(FlexAlign.End)
              .alignItems(VerticalAlign.Bottom)
              .padding({ right: 8, bottom: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
      }, (point: ChartDataPoint, index: number) => `bar-${index}-${point.label}`)
    }
    .width('100%')
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(12)
    .padding(16)
  }
  .width('100%')
  .padding(16)
  .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
  .borderRadius(12)
}

/**
 * 饼图组件
 */
@Builder
function PieChart(
  title: string,
  data: ChartDataPoint[]
): void {
  Column() {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
      .margin({ bottom: 16 })

    Row() {
      // 饼图区域
      Stack() {
        // Simplified implementation: use a single Progress component instead of nested ForEach
        Progress({
          value: 50, // Show 50% for simplicity
          total: 100,
          type: ProgressType.Ring
        })
        .width(120)
        .height(120)
        .color(DesignTokens.Colors.PRIMARY)
      }
      .width(120)
      .height(120)
      .margin({ right: 24 })
      
      // 图例
      Column() {
        ForEach(data, (point: ChartDataPoint, index: number) => {
          Row() {
            Circle({ width: 12, height: 12 })
              .fill(point.color)
              .margin({ right: 8 })
            
            Text(point.label)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
            
            Text(`${point.value}`)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ bottom: 8 })
        }, (point: ChartDataPoint, index: number) => `pie-${index}-${point.label}`)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(12)
    .padding(16)
  }
  .width('100%')
  .padding(16)
  .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
  .borderRadius(12)
}

/**
 * 统计卡片网格组件
 */
@Builder
function StatsGrid(
  stats: StatsCardData[]
): void {
  Grid() {
    ForEach(stats, (stat: StatsCardData, index: number) => {
      GridItem() {
        Column() {
          Row() {
            Text(stat.title)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
              .layoutWeight(1)
            
            if (stat.icon.length > 0) {
              Text(stat.icon)
                .fontSize(24)
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ bottom: 8 })
          
          Text(stat.value.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
            .margin({ bottom: 4 })
          
          if (stat.subtitle.length > 0) {
            Text(stat.subtitle)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
          }
          
          if (stat.trendPercentage !== 0) {
            Row() {
              if (stat.trend === 'up') {
                Text('↑')
                  .fontSize(14)
                  .fontColor(DesignTokens.Colors.SUCCESS)
                  .fontWeight(FontWeight.Bold)
                  .margin({ right: 4 })
              } else if (stat.trend === 'down') {
                Text('↓')
                  .fontSize(14)
                  .fontColor(DesignTokens.Colors.ERROR)
                  .fontWeight(FontWeight.Bold)
                  .margin({ right: 4 })
              }
              
              Text(`${Math.abs(stat.trendPercentage)}%`)
                .fontSize(12)
                .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.End)
            .margin({ top: 4 })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
        .borderRadius(12)
        .shadow({
          radius: 8,
          color: DesignTokens.Colors.SHADOW_LIGHT,
          offsetX: 0,
          offsetY: 2,
          fill: true
        })
      }
    })
  }
  .columnsTemplate('1fr 1fr')
  .columnsGap(12)
  .rowsGap(12)
  .padding(16)
}, (stat: StatsCardData, index: number) => `stat-${index}-${stat.title}`)

/**
 * 学习曲线组件
 */
@Builder
function LearningCurve(
  title: string,
  data: LearningProgressData[]
): void {
  Column() {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
      .margin({ bottom: 16 })

    // 简化实现：使用Progress模拟曲线
    Column() {
      ForEach(data, (item: LearningProgressData, index: number) => {
        Row() {
          Text(`${item.date}`)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
            .width(80)
          
          Blank()
          
          Column() {
            Row() {
              Text('学习:')
                .fontSize(12)
                .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
                .margin({ right: 4 })
              
              Text(`${item.wordsLearned}`)
                .fontSize(14)
                .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: 4 })
            
            Row() {
              Text('复习:')
                .fontSize(12)
                .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
                .margin({ right: 4 })
              
              Text(`${item.wordsReviewed}`)
                .fontSize(14)
                .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
        .borderRadius(8)
        .margin({ bottom: 8 })
      })
    }
    .width('100%')
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(12)
    .padding(16)
  }
}, (item: LearningProgressData, index: number) => `progress-${index}-${item.date}`)

/**
 * 词汇分布图表组件
 */
@Builder
function VocabularyDistribution(
  title: string,
  data: VocabularyDistributionData[]
): void {
  Column() {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
      .margin({ bottom: 16 })

    Row() {
      ForEach(data, (item: VocabularyDistributionData, index: number) => {
        Column() {
          Text(item.category)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .margin({ bottom: 4 })
          
          Row() {
            Row()
              .width('100%')
              .height(24)
              .backgroundColor(item.color)
              .borderRadius({ topLeft: 4, topRight: 4, bottomLeft: 4, bottomRight: 4 })
              .justifyContent(FlexAlign.End)
              .alignItems(VerticalAlign.Bottom)
              .padding({ right: 8 })

            Text(`${item.count} (${item.percentage}%)`)
              .fontSize(14)
            .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ bottom: 8 })
        }
        .width('100%')
        .layoutWeight(1)
      })
    }
    .width('100%')
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(12)
    .padding(16)
  }
  .width('100%')
  .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
  .borderRadius(12)
}, (item: VocabularyDistributionData, index: number) => `vocab-${index}-${item.category}`)

/**
 * 综合进度面板
 */
@Builder
function ProgressDashboard(
  stats: StatsCardData[],
  learningData: LearningProgressData[],
  vocabData: VocabularyDistributionData[]
): void {
  Column() {
    // 统计卡片
    Column() {
      StatsGrid(stats)
    }
    .margin({ bottom: 24 })
    
    // 学习曲线
    Column() {
      LearningCurve('学习趋势', learningData)
    }
    .margin({ bottom: 24 })
    
    // 词汇分布
    VocabularyDistribution('词汇分布', vocabData)
  }
  .width('100%')
  .padding(16)
  .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
}

/**
 * 简单进度条组件
 */
@Builder
function SimpleProgressBar(
  progress: number,
  total: number,
  color: ResourceColor = DesignTokens.Colors.PRIMARY,
  showPercentage: boolean = true
): void {
  Row() {
    Progress({
      value: progress,
      total: total,
      type: ProgressType.Linear
    })
    .width('100%')
    .height(8)
    .color(color)
    .backgroundColor(DesignTokens.Colors.GRAY_300)
    .layoutWeight(1)
    
    if (showPercentage) {
      Text(`${Math.round(progress / total * 100)}%`)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({ left: DesignTokens.Spacing.LG })
    }
  }
  .width('100%')
  .justifyContent(FlexAlign.SpaceBetween)
}

/**
 * 环形进度条组件
 */
@Builder
function CircularProgress(
  progress: number,
  total: number,
  color: ResourceColor = DesignTokens.Colors.PRIMARY,
  size: number = 120
): void {
  Stack() {
    Progress({
      value: progress,
      total: total,
      type: ProgressType.Ring
    })
    .width(size)
    .height(size)
    .color(color)
    
    Column() {
      Text(`${Math.round(progress / total * 100)}%`)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      
      Text(`${progress} / ${total}`)
        .fontSize(14)
        .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
        .margin({ top: 8 })
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
  }
  .width(size)
  .height(size)
}

/**
 * 目标进度组件
 */
@Builder
function GoalProgress(
  title: string,
  current: number,
  target: number,
  unit: string = '个'
): void {
  Column() {
    Text(title)
      .fontSize(14)
      .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
      .margin({ bottom: 8 })
    
    Row() {
      Progress({
        value: current,
        total: target,
        type: ProgressType.Linear
      })
      .width('100%')
      .height(12)
      .color(DesignTokens.Colors.PRIMARY)
      .backgroundColor(DesignTokens.Colors.BORDER_LIGHT)
      .layoutWeight(1)
    
      Column() {
        Text(`${current} / ${target}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
        
        Text(`${unit}`)
          .fontSize(12)
          .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.End)
      .margin({ left: 16 })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding(16)
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: DesignTokens.Colors.SHADOW_LIGHT,
      offsetX: 0,
      offsetY: 2,
      fill: true
    })
  }
  .width('100%')
  .margin({ bottom: 16 })
}
