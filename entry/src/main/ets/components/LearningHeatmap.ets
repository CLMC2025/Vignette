import promptAction from '@ohos.promptAction';
import { DesignTokens } from '../model/DesignTokens';
import { HeatmapDailyStats } from '../model/HeatmapData';

interface HeatmapCell {
  dateMs: number;
  level: number;
  isFuture: boolean;
  stats: HeatmapDailyStats | null;
}

@Component
export struct LearningHeatmap {
  @Link @Watch('onDataChange') data: HeatmapDailyStats[];
  @Prop columns: number = 53;
  @Prop showLegend: boolean = true;
  onDayClick?: (stats: HeatmapDailyStats) => void;

  private scroller: Scroller = new Scroller();

  private readonly WEEK_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];
  private readonly CELL_SIZE: number = 12;
  private readonly CELL_GAP: number = 3;

  private readonly LEVELS: number[] = [0, 1, 2, 3, 4];
  private readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  @State private pressedCellKey: string = '';
  @State private hoveredCellKey: string = '';
  @State private cachedColumns: HeatmapCell[][] = [];
  @State private renderVersion: number = 0;

  private dataMapCache: Map<number, HeatmapDailyStats> | null = null;
  private lastDataLength: number = -1;

  private onDataChange(): void {
    console.info(`[LearningHeatmap] onDataChange: data.length=${this.data.length}`);
    this.cachedColumns = this.buildColumns();
    this.renderVersion++;
  }

  aboutToAppear(): void {
    console.info(`[LearningHeatmap] aboutToAppear: data.length=${this.data.length}`);
    this.cachedColumns = this.buildColumns();
    this.renderVersion++;
  }

  aboutToUpdate(): void {
    console.info(`[LearningHeatmap] aboutToUpdate: data.length=${this.data.length}`);
    this.cachedColumns = this.buildColumns();
  }

  private getStartOfDayMs(ts: number): number {
    const d = new Date(ts);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
  }

  private buildDataMap(): Map<number, HeatmapDailyStats> {
    if (this.dataMapCache !== null && this.lastDataLength === this.data.length) {
      return this.dataMapCache;
    }

    const map: Map<number, HeatmapDailyStats> = new Map();
    for (const item of this.data) {
      const dayKey = this.getStartOfDayMs(item.dateMs);
      map.set(dayKey, item);
      console.info(`[LearningHeatmap] buildDataMap: dateMs=${item.dateMs}, dayKey=${dayKey}, totalReviews=${item.totalReviews}`);
    }
    console.info(`[LearningHeatmap] buildDataMap: total ${map.size} days`);

    this.dataMapCache = map;
    this.lastDataLength = this.data.length;
    return map;
  }

  private getLevel(total: number): number {
    if (total <= 0) return 0;
    if (total >= 50) return 4;
    if (total >= 20) return 3;
    if (total >= 5) return 2;
    return 1;
  }

  private getLevelColor(level: number): ResourceColor {
    switch (level) {
      case 4:
        return '#1B5E20';
      case 3:
        return DesignTokens.Colors.SUCCESS_DARK;
      case 2:
        return DesignTokens.Colors.SUCCESS;
      case 1:
        return DesignTokens.Colors.SUCCESS_LIGHT;
      default:
        return DesignTokens.Colors.GRAY_100;
    }
  }

  private buildColumns(): HeatmapCell[][] {
    const columns: HeatmapCell[][] = [];
    for (let i = 0; i < this.columns; i++) {
      columns.push([]);
    }

    const dataMap = this.buildDataMap();
    const todayStart = this.getStartOfDayMs(Date.now());

    const endDate = new Date(todayStart);
    const endDayOfWeek = endDate.getDay();
    const daysToSunday = endDayOfWeek === 0 ? 0 : (7 - endDayOfWeek);
    endDate.setDate(endDate.getDate() + daysToSunday);

    const startDate = new Date(endDate);
    startDate.setDate(startDate.getDate() - (this.columns * 7 - 1));
    console.info(`[LearningHeatmap] buildColumns: startDate=${startDate.toISOString()}, endDate=${endDate.toISOString()}, todayStart=${todayStart}`);

    let matchedDays = 0;
    const startTs = startDate.getTime();
    for (let col = 0; col < this.columns; col++) {
      for (let row = 0; row < 7; row++) {
        const dateTs = startTs + (col * 7 + row) * this.DAY_MS;
        const dateMs = this.getStartOfDayMs(dateTs);
        const stats = dataMap.get(dateMs) ?? null;
        if (stats) {
          matchedDays++;
        }
        const total = stats ? stats.totalReviews : 0;
        const level = this.getLevel(total);

        columns[col].push({
          dateMs: dateMs,
          level: level,
          isFuture: dateMs > todayStart,
          stats: stats
        });
      }
    }
    console.info(`[LearningHeatmap] buildColumns: matched ${matchedDays} days with data`);

    return columns;
  }

  private ensureStats(cell: HeatmapCell): HeatmapDailyStats {
    if (cell.stats) {
      return cell.stats;
    }
    return {
      dateMs: cell.dateMs,
      knownCount: 0,
      fuzzyCount: 0,
      forgottenCount: 0,
      newCount: 0,
      reviewCount: 0,
      durationMs: 0,
      totalReviews: 0
    };
  }

  private formatDate(dateMs: number): string {
    const d = new Date(dateMs);
    const month = d.getMonth() + 1;
    const day = d.getDate();
    const weekDay = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()];
    return `${month}月${day}日 ${weekDay}`;
  }

  private getCellKey(col: number, row: number): string {
    return `${col}-${row}`;
  }

  private handleCellClick(cell: HeatmapCell): void {
    if (cell.isFuture) {
      return;
    }
    const stats = this.ensureStats(cell);
    if (this.onDayClick) {
      this.onDayClick(stats);
    }
  }

  private handleCellLongPress(cell: HeatmapCell): void {
    if (cell.isFuture) {
      return;
    }
    const dateText = this.formatDate(cell.dateMs);
    const reviewCount = cell.stats ? cell.stats.totalReviews : 0;
    promptAction.showToast({
      message: `${dateText} - 复习${reviewCount}次`,
      duration: 1500
    });
  }

  @Builder
  private buildCell(cell: HeatmapCell, col: number, row: number): void {
    Column()
      .width(this.CELL_SIZE)
      .height(this.CELL_SIZE)
      .borderRadius(DesignTokens.BorderRadius.SM)
      .backgroundColor(this.getLevelColor(cell.level))
      .opacity(cell.isFuture ? 0.3 : 1)
      .scale({
        x: this.pressedCellKey === this.getCellKey(col, row) ? 1.3 : this.hoveredCellKey === this.getCellKey(col, row) ? 1.15 : 1,
        y: this.pressedCellKey === this.getCellKey(col, row) ? 1.3 : this.hoveredCellKey === this.getCellKey(col, row) ? 1.15 : 1
      })
      .shadow(this.hoveredCellKey === this.getCellKey(col, row) || this.pressedCellKey === this.getCellKey(col, row) ? {
        radius: 4,
        color: DesignTokens.Colors.SUCCESS,
        offsetX: 0,
        offsetY: 2,
        fill: true
      } : {
        radius: 0,
        color: 'transparent',
        offsetX: 0,
        offsetY: 0,
        fill: false
      })
      .animation({
        duration: 150,
        curve: Curve.FastOutSlowIn
      })
      .onClick(() => this.handleCellClick(cell))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedCellKey = this.getCellKey(col, row);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          setTimeout(() => {
            this.pressedCellKey = '';
          }, 100);
        }
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            this.handleCellLongPress(cell);
          })
      )
  }

  @Builder
  private buildLegend(): void {
    Row() {
      Text('较少')
        .fontSize(10)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .margin({ right: DesignTokens.Spacing.SM })

      Row() {
        ForEach(this.LEVELS, (level: number) => {
          Column()
            .width(this.CELL_SIZE)
            .height(this.CELL_SIZE)
            .borderRadius(2)
            .backgroundColor(this.getLevelColor(level))
            .margin({ right: this.CELL_GAP })
        }, (level: number) => level.toString())
      }

      Text('较多')
        .fontSize(10)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .margin({ left: DesignTokens.Spacing.SM })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: DesignTokens.Spacing.MD })
  }

  build() {
    Column({ space: DesignTokens.Spacing.SM }) {
      Row() {
        Column({ space: this.CELL_GAP }) {
          ForEach(this.WEEK_LABELS, (label: string) => {
            Text(label)
              .fontSize(9)
              .fontColor(DesignTokens.Colors.GRAY_400)
              .width(14)
              .height(this.CELL_SIZE)
              .textAlign(TextAlign.Center)
          }, (label: string) => label)
        }
        .margin({ right: 6 })

        Scroll(this.scroller) {
          Row({ space: this.CELL_GAP }) {
            ForEach(this.cachedColumns, (column: HeatmapCell[], colIndex: number) => {
              Column({ space: this.CELL_GAP }) {
                ForEach(column, (cell: HeatmapCell, rowIndex: number) => {
                  this.buildCell(cell, colIndex, rowIndex);
                }, (cell: HeatmapCell, rowIndex: number) => `${this.renderVersion}-${cell.dateMs}-${cell.level}-${rowIndex}`)
              }
            }, (column: HeatmapCell[], colIndex: number) => {
              const levelSum = column.reduce((sum: number, cell: HeatmapCell) => sum + cell.level, 0);
              return `col-${colIndex}-${this.renderVersion}-${levelSum}`;
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .onAppear(() => {
          setTimeout(() => {
            this.scroller.scrollEdge(Edge.End);
          }, 100);
        })
      }
      .width('100%')

      if (this.showLegend) {
        this.buildLegend();
      }
      
      if (this.data.length === 0) {
        Text('暂无学习记录，开始学习后将显示数据')
          .fontSize(12)
          .fontColor(DesignTokens.Colors.GRAY_400)
          .margin({ top: DesignTokens.Spacing.SM })
      }
    }
    .width('100%')
  }
}

@Component
export struct CompactHeatmap {
  @Prop data: HeatmapDailyStats[] = [];
  @Prop maxDays: number = 30;

  private getStartOfDayMs(ts: number): number {
    const d = new Date(ts);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
  }

  private buildRecentData(): HeatmapDailyStats[] {
    const todayStart = this.getStartOfDayMs(Date.now());
    const result: HeatmapDailyStats[] = [];
    const dataMap: Map<number, HeatmapDailyStats> = new Map();

    for (const item of this.data) {
      dataMap.set(this.getStartOfDayMs(item.dateMs), item);
    }

    for (let i = this.maxDays - 1; i >= 0; i--) {
      const dateMs = todayStart - i * 24 * 60 * 60 * 1000;
      const stats = dataMap.get(dateMs);
      if (stats) {
        result.push(stats);
      } else {
        result.push({
          dateMs: dateMs,
          knownCount: 0,
          fuzzyCount: 0,
          forgottenCount: 0,
          newCount: 0,
          reviewCount: 0,
          durationMs: 0,
          totalReviews: 0
        });
      }
    }

    return result;
  }

  private getLevel(total: number, maxTotal: number): number {
    if (total <= 0) return 0;
    if (maxTotal <= 0) return 1;
    const ratio = total / maxTotal;
    if (ratio >= 0.75) return 3;
    if (ratio >= 0.4) return 2;
    return 1;
  }

  private getColor(level: number): ResourceColor {
    switch (level) {
      case 3:
        return DesignTokens.Colors.SUCCESS_DARK;
      case 2:
        return DesignTokens.Colors.SUCCESS;
      case 1:
        return DesignTokens.Colors.SUCCESS_LIGHT;
      default:
        return DesignTokens.Colors.GRAY_200;
    }
  }

  build() {
    Row({ space: 2 }) {
      ForEach(this.buildRecentData(), (stats: HeatmapDailyStats) => {
        Column()
          .width(8)
          .height(32)
          .borderRadius(2)
          .backgroundColor(this.getColor(this.getLevel(stats.totalReviews, 20)))
      }, (stats: HeatmapDailyStats) => stats.dateMs.toString())
    }
    .width('100%')
  }
}

@Component
export struct WeeklyHeatmapBar {
  @Prop data: HeatmapDailyStats[] = [];

  private getWeekData(): number[] {
    const todayStart = this.getStartOfDayMs(Date.now());
    const weekStart = todayStart - 6 * 24 * 60 * 60 * 1000;
    const result: number[] = [];
    const dataMap: Map<number, number> = new Map();

    for (const item of this.data) {
      dataMap.set(this.getStartOfDayMs(item.dateMs), item.totalReviews);
    }

    for (let i = 0; i < 7; i++) {
      const dateMs = weekStart + i * 24 * 60 * 60 * 1000;
      result.push(dataMap.get(dateMs) ?? 0);
    }

    return result;
  }

  private getStartOfDayMs(ts: number): number {
    const d = new Date(ts);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
  }

  private getDayLabel(index: number): string {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    const today = new Date().getDay();
    const adjustedToday = today === 0 ? 6 : today - 1;
    const targetIndex = (adjustedToday - 6 + index + 7) % 7;
    return labels[targetIndex];
  }

  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      ForEach(this.getWeekData(), (count: number, index: number) => {
        Column({ space: 4 }) {
          Column()
            .width(32)
            .height(Math.max(4, Math.min(48, count * 4)))
            .backgroundColor(count > 0 ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.GRAY_200)
            .borderRadius(4)

          Text(this.getDayLabel(index))
            .fontSize(10)
            .fontColor(DesignTokens.Colors.GRAY_500)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.End)
      }, (count: number, index: number) => `week-${index}`)
    }
    .width('100%')
    .height(80)
    .alignItems(VerticalAlign.Bottom)
  }
}
