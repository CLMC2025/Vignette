/**
 * FSRSOptimizationSection.ets - FSRS Parameter Optimization UI
 * Settings section for FSRS algorithm optimization
 */

import router from '@ohos.router';
import {
  FSRSOptimizer,
  FSRSParameterStore,
  OptimizationResult,
  OptimizationProgress
} from '../../algorithm/FSRSOptimizer';
import { FSRSAlgorithm } from '../../algorithm/Algorithm';
import { HistoryItem } from '../../model/FSRSModels';
import { DBManager } from '../../database/DBManager';
import { WebDavSyncManager } from '../../sync/WebDavSyncManager';
import promptAction from '@ohos.promptAction';
import * as DesignTokens from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';

@Component
export struct FSRSOptimizationSection {
  @State isOptimizing: boolean = false;
  @State progress: number = 0;
  @State progressText: string = '';
  @State hasOptimizedParams: boolean = false;
  @State reviewCount: number = 0;
  @State lastOptimizedTime: number = 0;
  @State showResultDialog: boolean = false;
  @State optimizationResult: OptimizationResult | null = null;
  @State showAutoOptimizePrompt: boolean = false;
  @State autoOptimizeReason: string = '';
  @State webdavConfigured: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private optimizer: FSRSOptimizer = FSRSOptimizer.getInstance();
  private paramStore: FSRSParameterStore = FSRSParameterStore.getInstance();
  private algorithm: FSRSAlgorithm = FSRSAlgorithm.getInstance();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    this.hasOptimizedParams = this.paramStore.hasOptimizedParameters();
    this.lastOptimizedTime = this.paramStore.getTimestamp();
    this.checkWebDavConfig();
    void this.loadReviewCount();
    void this.checkAutoOptimize();
  }

  private checkWebDavConfig(): void {
    const webdavManager = WebDavSyncManager.getInstance();
    const settings = webdavManager.getSettings();
    this.webdavConfigured = settings.endpoint.length > 0 && settings.username.length > 0;
  }

  private async loadReviewCount(): Promise<void> {
    try {
      const dbManager = DBManager.getInstance();
      this.reviewCount = await dbManager.getTotalHistoryCount();
    } catch (e) {
      console.error('[FSRSOptimizationSection] Failed to load review count:', e);
    }
  }

  private async checkAutoOptimize(): Promise<void> {
    const result = this.optimizer.checkAutoOptimize(this.reviewCount);
    if (result.shouldPrompt) {
      this.autoOptimizeReason = result.reason;
      this.showAutoOptimizePrompt = true;
    }
  }

  private async startOptimization(): Promise<void> {
    if (this.isOptimizing) {
      return;
    }

    if (this.reviewCount < 100) {
      promptAction.showToast({
        message: `需要至少100条复习记录，当前只有${this.reviewCount}条`,
        duration: 2000
      });
      return;
    }

    this.isOptimizing = true;
    this.progress = 0;
    this.progressText = '准备优化...';

    try {
      const dbManager = DBManager.getInstance();
      const words = await dbManager.getAllWords();

      const allHistory: HistoryItem[] = [];
      for (let i = 0; i < words.length; i++) {
        const word = words[i];
        const items = word.history.items;
        for (let j = 0; j < items.length; j++) {
          allHistory.push(items[j]);
        }
      }

      const result = await this.optimizer.optimize(allHistory, (p: OptimizationProgress) => {
        this.progress = p.progress * 100;
        this.progressText = `优化中... ${p.epoch}/${p.totalEpochs} 轮 (Adam优化器)`;
      });

      this.optimizationResult = result;

      if (result.success) {
        this.paramStore.saveParameters(result.newParameters);

        const diffParams = this.optimizer.getDifficultyParameters();
        this.paramStore.saveDifficultyParameters(diffParams);

        const autoState = this.optimizer.getAutoOptimizeState();
        this.paramStore.saveAutoOptimizeState(autoState);

        this.algorithm.reloadParameters();
        this.hasOptimizedParams = true;
        this.lastOptimizedTime = Date.now();
        this.showResultDialog = true;
        this.showAutoOptimizePrompt = false;
      } else {
        promptAction.showToast({
          message: result.errorMessage || '优化失败',
          duration: 2000
        });
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[FSRSOptimizationSection] Optimization failed:', errMsg);
      promptAction.showToast({
        message: '优化失败: ' + errMsg,
        duration: 2000
      });
    } finally {
      this.isOptimizing = false;
      this.progress = 0;
      this.progressText = '';
    }
  }

  private resetToDefault(): void {
    this.algorithm.resetToDefault();
    this.hasOptimizedParams = false;
    this.lastOptimizedTime = 0;
    promptAction.showToast({
      message: '已恢复默认参数',
      duration: 1500
    });
  }

  private navigateToSyncSettings(): void {
    router.pushUrl({
      url: 'pages/SettingsPage',
      params: { section: 'sync' }
    });
  }

  private formatTime(timestamp: number): string {
    if (timestamp === 0) return '从未';
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  private calculateImprovement(): string {
    if (this.optimizationResult === null) {
      return '0';
    }
    if (this.optimizationResult.lossBefore > 0) {
      const improvement = ((this.optimizationResult.lossBefore - this.optimizationResult.lossAfter) / this.optimizationResult.lossBefore * 100).toFixed(1);
      return improvement;
    }
    return '0';
  }

  @Builder
  private buildHeader() {
    Row() {
      Column() {
        Text('Adam优化器')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(this.colors.GRAY_700)
        Text('自适应学习率，更快收敛')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.GRAY_500)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      if (this.hasOptimizedParams) {
        Text('已优化')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.SUCCESS)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.colors.SUCCESS_LIGHTEST)
          .borderRadius(4)
      }
    }
    .width('100%')
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG
    })
  }

  @Builder
  private buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.GRAY_600)

      Blank()

      Text(value)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.TEXT_PRIMARY)
    }
    .width('100%')
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG,
      top: DesignTokens.Spacing.SM
    })
  }

  @Builder
  private buildProgressIndicator() {
    Column() {
      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .color(this.colors.PRIMARY)
        .margin({ top: DesignTokens.Spacing.MD })

      Text(this.progressText)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.GRAY_600)
        .margin({ top: DesignTokens.Spacing.SM })
    }
    .width('100%')
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG,
      top: DesignTokens.Spacing.MD
    })
  }

  @Builder
  private buildActionButtons() {
    Row() {
      Button(this.isOptimizing ? '优化中...' : '开始优化')
        .width('45%')
        .height(40)
        .fontSize(14)
        .fontColor(this.isOptimizing ? this.colors.GRAY_500 : this.colors.WHITE)
        .backgroundColor(this.isOptimizing ? this.colors.GRAY_200 : this.colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.MD)
        .enabled(!this.isOptimizing && this.reviewCount >= 100)
        .onClick(() => {
          void this.startOptimization();
        })

      Button('恢复默认')
        .width('45%')
        .height(40)
        .fontSize(14)
        .fontColor(this.colors.GRAY_700)
        .backgroundColor(this.colors.GRAY_100)
        .borderRadius(DesignTokens.BorderRadius.MD)
        .enabled(!this.isOptimizing && this.hasOptimizedParams)
        .onClick(() => {
          this.resetToDefault();
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG,
      top: DesignTokens.Spacing.MD
    })
  }

  @Builder
  private buildWebDavStatus() {
    Divider()
      .color(this.colors.GRAY_200)
      .margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.LG })

    Row() {
      Column() {
        Text('云端同步')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(this.colors.TEXT_PRIMARY)
        Text(this.webdavConfigured ? '已配置 WebDAV' : '未配置 WebDAV')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.webdavConfigured ? this.colors.SUCCESS : this.colors.GRAY_500)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('去设置 >')
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.PRIMARY)
        .onClick(() => {
          this.navigateToSyncSettings();
        })
    }
    .width('100%')
    .padding({
      left: DesignTokens.Spacing.LG,
      right: DesignTokens.Spacing.LG,
      top: DesignTokens.Spacing.MD
    })
  }

  @Builder
  private buildResultDialog() {
    if (this.optimizationResult !== null) {
      Column() {
        Text('优化结果')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.TEXT_PRIMARY)
          .margin({ bottom: DesignTokens.Spacing.MD })

        Column() {
          this.buildResultRow('优化算法', 'Adam优化器', this.colors.PRIMARY)
          this.buildResultRow('复习记录数', `${this.optimizationResult.reviewCount}`, this.colors.TEXT_PRIMARY)
          this.buildResultRow('训练轮数', `${this.optimizationResult.epochsRun}`, this.colors.TEXT_PRIMARY)
          this.buildResultRow('优化前损失', `${this.optimizationResult.lossBefore.toFixed(4)}`, this.colors.TEXT_PRIMARY)
          this.buildResultRow('优化后损失', `${this.optimizationResult.lossAfter.toFixed(4)}`, this.colors.SUCCESS)
          this.buildResultRow('损失降低', `${this.calculateImprovement()}%`, this.colors.SUCCESS)
        }
        .width('100%')
        .padding(DesignTokens.Spacing.MD)
        .backgroundColor(this.colors.BACKGROUND_SECONDARY)
        .borderRadius(DesignTokens.BorderRadius.MD)

        Button('确定')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor(this.colors.WHITE)
          .backgroundColor(this.colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .margin({ top: DesignTokens.Spacing.LG })
          .onClick(() => {
            this.showResultDialog = false;
          })
      }
      .width('85%')
      .padding(DesignTokens.Spacing.LG)
      .backgroundColor(this.colors.BACKGROUND_PRIMARY)
      .borderRadius(DesignTokens.BorderRadius.LG)
    }
  }

  @Builder
  private buildResultRow(label: string, value: string, valueColor: ResourceColor) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.colors.TEXT_SECONDARY)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(valueColor)
    }
    .width('100%')
    .margin({ bottom: DesignTokens.Spacing.SM })
  }

  @Builder
  private buildAutoOptimizePrompt() {
    Column() {
      Text('参数优化建议')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)
        .margin({ bottom: DesignTokens.Spacing.MD })

      Text(this.autoOptimizeReason)
        .fontSize(14)
        .fontColor(this.colors.TEXT_SECONDARY)
        .margin({ bottom: DesignTokens.Spacing.LG })

      Row() {
        Button('稍后提醒')
          .width('45%')
          .height(40)
          .fontSize(14)
          .fontColor(this.colors.GRAY_700)
          .backgroundColor(this.colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .onClick(() => {
            this.showAutoOptimizePrompt = false;
          })

        Button('立即优化')
          .width('45%')
          .height(40)
          .fontSize(14)
          .fontColor(this.colors.WHITE)
          .backgroundColor(this.colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .onClick(() => {
            this.showAutoOptimizePrompt = false;
            void this.startOptimization();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('85%')
    .padding(DesignTokens.Spacing.LG)
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
  }

  build() {
    Column() {
      Text('FSRS参数优化')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      this.buildHeader()
      this.buildInfoRow('复习记录数', `${this.reviewCount}`)
      this.buildInfoRow('上次优化时间', this.formatTime(this.lastOptimizedTime))

      if (this.isOptimizing) {
        this.buildProgressIndicator()
      }

      this.buildActionButtons()
      this.buildWebDavStatus()

      Text('提示：优化器使用Adam算法自动调整学习率。参数将通过WebDAV自动同步。')
        .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
        .fontColor(this.colors.GRAY_500)
        .width('100%')
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          top: DesignTokens.Spacing.MD
        })
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .bindSheet($$this.showResultDialog, this.buildResultDialog(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: Color.Transparent,
      dragBar: false
    })
    .bindSheet($$this.showAutoOptimizePrompt, this.buildAutoOptimizePrompt(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: Color.Transparent,
      dragBar: false
    })
  }
}
