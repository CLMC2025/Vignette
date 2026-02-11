// =====================================================
// LoggerSection.ets
// Logger stats and export
// =====================================================

import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DesignTokens } from '../../model/DesignTokens';
import { logger, LogStats } from '../../utils/Logger';
import { DataFileTransfer } from '../../sync/DataFileTransfer';
import { formatError } from './SettingsCommon';

@Component
export struct LoggerSection {
  @Link logStats: LogStats;
  @State isLogExporting: boolean = false;

  private makeLogFileName(): string {
    const d = new Date();
    const pad = (n: number): string => String(n).padStart(2, '0');
    const y = d.getFullYear();
    const m = pad(d.getMonth() + 1);
    const day = pad(d.getDate());
    const hh = pad(d.getHours());
    const mm = pad(d.getMinutes());
    return `weiyu_logs_${y}${m}${day}_${hh}${mm}.txt`;
  }

  private async exportLogs(): Promise<void> {
    if (this.isLogExporting) {
      return;
    }
    this.isLogExporting = true;
    logger.info('Settings', '开始导出日志');
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const logText = logger.exportToText();
      const saveRes = await DataFileTransfer.saveJsonToPickedFile(context, this.makeLogFileName(), logText);
      if (saveRes.ok) {
        promptAction.showToast({ message: '日志已导出', duration: 1500 });
        logger.info('Settings', '日志导出成功');
      } else if (saveRes.cancelled) {
        promptAction.showToast({ message: '已取消导出', duration: 1500 });
        logger.info('Settings', '日志导出取消');
      } else {
        promptAction.showToast({ message: `导出失败: ${saveRes.error}`, duration: 2000 });
        logger.error('Settings', '日志导出失败', saveRes.error);
      }
    } catch (e) {
      const errMsg = formatError(e);
      promptAction.showToast({ message: `导出失败: ${errMsg}`, duration: 2000 });
      logger.error('Settings', '日志导出异常', errMsg);
    } finally {
      this.isLogExporting = false;
    }
  }

  private clearLogs(): void {
    logger.clearLogs();
    this.logStats = logger.getStats();
    promptAction.showToast({ message: '日志已清空', duration: 1500 });
    logger.info('Settings', '日志已清空');
  }

  build() {
    Column() {
      Text('日志与调试')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        Row() {
          Text(`日志条数: ${this.logStats.total} 条`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_700)
          Blank()
          Text(`缓存上限: ${logger.getMaxCacheSize()} 条`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_500)
        }
        .width('100%')
        .height(56)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        Divider().color(DesignTokens.Colors.GRAY_200)

        Row() {
          Text('日志导出')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_700)
          Blank()
          Button(this.isLogExporting ? '导出中...' : '一键导出', { type: ButtonType.Capsule, stateEffect: true })
            .width(120)
            .height(32)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.isLogExporting ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.PRIMARY)
            .enabled(!this.isLogExporting)
            .onClick(() => {
              this.exportLogs();
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        Divider().color(DesignTokens.Colors.GRAY_200)

        Row() {
          Text('清空日志')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_700)
          Blank()
          Button('清空', { type: ButtonType.Capsule, stateEffect: true })
            .width(80)
            .height(32)
            .fontSize(12)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(DesignTokens.Colors.ERROR)
            .onClick(() => {
              this.clearLogs();
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
      }
      .width('100%')
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow({
        color: DesignTokens.Colors.SHADOW_LIGHT,
        radius: DesignTokens.Shadows.RADIUS_SM,
        offsetX: DesignTokens.Shadows.OFFSET_X_SM,
        offsetY: DesignTokens.Shadows.OFFSET_Y_SM
      })
    }
    .width('100%')
  }
}
