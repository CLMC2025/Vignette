// =====================================================
// ChartModel.ets - Chart Logic and Types
// =====================================================

/**
 * Chart Types
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
 * Chart Data Point
 */
export class ChartDataPoint {
  label: string;
  value: number;
  color: ResourceColor;
  timestamp: number;

  constructor(
    label: string,
    value: number,
    color: ResourceColor = '#2196F3',
    timestamp: number = Date.now()
  ) {
    this.label = label;
    this.value = value;
    this.color = color;
    this.timestamp = timestamp;
  }
}

/**
 * Chart Dataset
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
 * Learning Progress Data
 */
export class LearningProgressData {
  date: number;
  wordsLearned: number;
  wordsReviewed: number;
  accuracy: number;
  studyTime: number;  // minutes

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
 * Vocabulary Distribution Data
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
    color: ResourceColor = '#2196F3'
  ) {
    this.category = category;
    this.count = count;
    this.percentage = percentage;
    this.color = color;
  }
}

/**
 * Statistics Card Data
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
