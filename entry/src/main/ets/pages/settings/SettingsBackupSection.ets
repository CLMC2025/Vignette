import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DesignTokens } from '../../model/DesignTokens';
import { DataSyncManager, SyncStatus } from '../../sync/DataSyncManager';
import { DataFileTransfer } from '../../sync/DataFileTransfer';
import { formatError } from './SettingsCommon';
import { logger } from '../../utils/Logger';

@Component
export struct SettingsBackupSection {
  // Local state
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State exportResult: string = '';
  @State importResult: string = '';
  
  private syncManager: DataSyncManager = DataSyncManager.getInstance();

  onShowDialog: (title: string, message: string, data: string, isImport: boolean) => void = () => {};

  // ==================== Local Backup Logic ====================

  private makeBackupFileName(): string {
    const d = new Date();
    const pad = (n: number): string => String(n).padStart(2, '0');
    const y = d.getFullYear();
    const m = pad(d.getMonth() + 1);
    const day = pad(d.getDate());
    const hh = pad(d.getHours());
    const mm = pad(d.getMinutes());
    return `weiyu_backup_${y}${m}${day}_${hh}${mm}.json`;
  }

  private async exportData(): Promise<void> {
    if (this.syncManager.getSyncStatus() !== SyncStatus.IDLE) {
      promptAction.showToast({ message: '同步操作正在进行中', duration: 2000 });
      return;
    }

    this.isExporting = true;
    this.exportResult = '';
    logger.info('Settings', '开始导出备份');

    try {
      const result = await this.syncManager.exportData();

      if (result.success) {
        const context = getContext(this) as common.UIAbilityContext;
        const saveRes = await DataFileTransfer.saveJsonToPickedFile(context, this.makeBackupFileName(), result.data);
        if (saveRes.ok) {
          this.exportResult = `✅ 导出成功！数据大小: ${result.data.length} 字符`;
          promptAction.showToast({ message: '已保存为备份文件', duration: 1500 });
          logger.info('Settings', '备份导出成功');
        } else if (saveRes.cancelled) {
          this.exportResult = '已取消导出';
          logger.info('Settings', '备份导出取消');
        } else {
          console.warn(`[SettingsPage] export fallback to clipboard: ${saveRes.error}`);
          this.exportResult = `❌ 导出错误: ${saveRes.error}`;
          this.onShowDialog('导出数据（回退复制）', '系统文件选择器异常，已回退为复制方式（建议升级/修复系统文件管理器后再试保存）。', result.data, false);
          logger.warn('Settings', '备份导出回退', saveRes.error);
        }
      } else {
        this.exportResult = `❌ 导出失败: ${result.error}`;
        logger.error('Settings', '备份导出失败', result.error);
      }
    } catch (e) {
      const errMsg = formatError(e);
      this.exportResult = `❌ 导出错误: ${errMsg}`;
      logger.error('Settings', '备份导出异常', errMsg);
    } finally {
      this.isExporting = false;
    }
  }

  private async importData(): Promise<void> {
    if (this.syncManager.getSyncStatus() !== SyncStatus.IDLE) {
      promptAction.showToast({ message: '同步操作正在进行中', duration: 2000 });
      return;
    }
    if (this.isImporting) {
      return;
    }
    this.isImporting = true;
    this.importResult = '';
    logger.info('Settings', '开始导入备份');
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const readRes = await DataFileTransfer.readJsonFromPickedFile(context);
      if (readRes.ok) {
        const jsonData = readRes.data.trim();
        if (jsonData.length === 0) {
          this.importResult = '导入文件为空';
          logger.warn('Settings', '导入备份为空');
          return;
        }
        await this.confirmImportFromJson(jsonData);
        return;
      }
      if (readRes.cancelled) {
        this.importResult = '已取消导入';
        logger.info('Settings', '导入备份取消');
        return;
      }
      console.warn(`[SettingsPage] import fallback to paste: ${readRes.error}`);
      this.importResult = `❌ 导入错误: ${readRes.error}`;
      this.onShowDialog('导入数据（回退粘贴）', '系统文件选择器异常，请粘贴之前导出的 JSON 备份数据。', '', true);
      logger.warn('Settings', '导入备份回退', readRes.error);
    } catch (e) {
      const errMsg = formatError(e);
      this.importResult = `❌ 导入错误: ${errMsg}`;
      this.onShowDialog('导入数据（回退粘贴）', '读取备份文件失败，请粘贴之前导出的 JSON 备份数据。', '', true);
      logger.error('Settings', '导入备份异常', errMsg);
    } finally {
      this.isImporting = false;
    }
  }

  private async confirmImportFromJson(jsonData: string): Promise<void> {
    const preview = await this.syncManager.previewImport(jsonData);
    if (preview.errors.length > 0) {
      this.importResult = `❌ 解析失败: ${preview.errors.join(', ')}`;
      logger.error('Settings', '导入预览失败', preview.errors.join(', '));
      return;
    }

    const sample = preview.sampleUpdatedWords.length > 0 ? `\n示例：${preview.sampleUpdatedWords.join('、')}` : '';
    const msg = `将覆盖更新 ${preview.updated} 词，新增 ${preview.imported} 词，共 ${preview.total} 词。${sample}\n确认继续导入？`;
    const clicked = await promptAction.showDialog({
      title: '导入预览',
      message: msg,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '继续导入', color: '#2196F3' }
      ]
    });

    if (clicked.index === 0) {
      this.importResult = '已取消导入';
      logger.info('Settings', '导入确认取消');
      return;
    }

    const result = await this.syncManager.importData(jsonData);
    if (result.hasErrors()) {
      this.importResult = `❌ 导入失败: ${result.errors.join(', ')}`;
      logger.error('Settings', '导入执行失败', result.errors.join(', '));
    } else {
      this.importResult = `✅ 导入成功！${result.getSummary()}`;
      logger.info('Settings', '导入执行成功');
    }
  }

  build() {
    Column() {
      Text('本地备份与恢复')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        Button(this.isExporting ? '导出中...' : '导出数据')
          .width('100%')
          .height(48)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(this.isExporting ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.LG)
          .enabled(!this.isExporting)
          .margin({ top: DesignTokens.Spacing.LG, left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .onClick(() => { this.exportData(); })

        if (this.exportResult.length > 0) {
          Text(this.exportResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.exportResult.includes('✅') ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.ERROR)
            .margin({ top: DesignTokens.Spacing.SM })
            .textAlign(TextAlign.Center)
        }

        Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.MD })

        Button(this.isImporting ? '导入中...' : '导入数据')
          .width('100%')
          .height(48)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(this.isImporting ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.SUCCESS)
          .borderRadius(DesignTokens.BorderRadius.LG)
          .enabled(!this.isImporting)
          .margin({ top: DesignTokens.Spacing.MD, bottom: DesignTokens.Spacing.LG, left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .onClick(() => { this.importData(); })

        if (this.importResult.length > 0) {
          Text(this.importResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.importResult.includes('✅') ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.ERROR)
            .margin({ bottom: DesignTokens.Spacing.LG })
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    }
    .width('100%')
  }
}
