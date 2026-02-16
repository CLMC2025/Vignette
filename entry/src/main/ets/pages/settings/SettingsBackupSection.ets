import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DesignTokens } from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';
import { DataSyncManager, SyncStatus } from '../../sync/DataSyncManager';
import { DataFileTransfer } from '../../sync/DataFileTransfer';
import { formatError } from './SettingsCommon';
import { logger } from '../../utils/Logger';
import router from '@ohos.router';

interface DialogIndexResult {
  index: number;
}

interface BackupData {
  words?: object[];
}

@Component
export struct SettingsBackupSection {
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State exportResult: string = '';
  @State importResult: string = '';
  @State lastExportTime: string = '从未';
  @State wordCount: number = 0;

  private syncManager: DataSyncManager = DataSyncManager.getInstance();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  onShowDialog: (title: string, message: string, data: string, isImport: boolean) => void = () => {};

  aboutToAppear(): void {
    void this.loadStats();
  }

  private async loadStats(): Promise<void> {
    try {
      const result = await this.syncManager.exportData();
      if (result.success) {
        const data: BackupData = JSON.parse(result.data) as BackupData;
        this.wordCount = data.words?.length ?? 0;
      }
    } catch (e) {
      console.error('[SettingsBackupSection] Failed to load stats:', e);
    }
  }

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
          this.exportResult = '导出成功';
          this.lastExportTime = new Date().toLocaleString();
          promptAction.showToast({ message: '已保存为备份文件', duration: 1500 });
          logger.info('Settings', '备份导出成功');
        } else if (saveRes.cancelled) {
          this.exportResult = '已取消导出';
          logger.info('Settings', '备份导出取消');
        } else {
          console.warn(`[SettingsPage] export fallback to clipboard: ${saveRes.error}`);
          this.exportResult = '导出失败';
          this.onShowDialog('导出数据（回退复制）', '系统文件选择器异常，已回退为复制方式（建议升级/修复系统文件管理器后再试保存）。', result.data, false);
          logger.warn('Settings', '备份导出回退', saveRes.error);
        }
      } else {
        this.exportResult = '导出失败';
        logger.error('Settings', '备份导出失败', result.error);
      }
    } catch (e) {
      const errMsg = formatError(e);
      this.exportResult = '导出错误';
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
      this.importResult = '导入错误';
      this.onShowDialog('导入数据（回退粘贴）', '系统文件选择器异常，请粘贴之前导出的 JSON 备份数据。', '', true);
      logger.warn('Settings', '导入备份回退', readRes.error);
    } catch (e) {
      const errMsg = formatError(e);
      this.importResult = '导入错误';
      this.onShowDialog('导入数据（回退粘贴）', '读取备份文件失败，请粘贴之前导出的 JSON 备份数据。', '', true);
      logger.error('Settings', '导入备份异常', errMsg);
    } finally {
      this.isImporting = false;
    }
  }

  private async confirmImportFromJson(jsonData: string): Promise<void> {
    const preview = await this.syncManager.previewImport(jsonData);
    if (preview.errors.length > 0) {
      this.importResult = '解析失败';
      logger.error('Settings', '导入预览失败', preview.errors.join(', '));
      return;
    }

    const sample = preview.sampleUpdatedWords.length > 0 ? `\n示例：${preview.sampleUpdatedWords.join('、')}` : '';
    const msg = `将覆盖更新 ${preview.updated} 词，新增 ${preview.imported} 词，共 ${preview.total} 词。${sample}\n确认继续导入？`;

    try {
      const dialogResult = await promptAction.showDialog({
        title: '导入预览',
        message: msg,
        buttons: [
          { text: '取消', color: String(this.colors.TEXT_SECONDARY) },
          { text: '继续导入', color: String(this.colors.PRIMARY) }
        ]
      });

      const clicked = dialogResult as DialogIndexResult;
      if (clicked.index === 0) {
        this.importResult = '已取消导入';
        logger.info('Settings', '导入确认取消');
        return;
      }

      const result = await this.syncManager.importData(jsonData);
      if (result.hasErrors()) {
        this.importResult = '导入失败';
        logger.error('Settings', '导入执行失败', result.errors.join(', '));
      } else {
        this.importResult = '导入成功';
        logger.info('Settings', '导入执行成功');
        void this.loadStats();
      }
    } catch (e) {
      this.importResult = '已取消导入';
    }
  }

  private navigateToSyncSettings(): void {
    router.pushUrl({
      url: 'pages/SettingsPage',
      params: { section: 'sync' }
    });
  }

  @Builder
  private buildExportCard() {
    Column() {
      Row() {
        Text('导出数据')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.TEXT_PRIMARY)

        Blank()

        Button(this.isExporting ? '导出中...' : '导出')
          .width(80)
          .height(36)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.WHITE)
          .backgroundColor(this.isExporting ? this.colors.GRAY_400 : this.colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .enabled(!this.isExporting)
          .onClick(() => { void this.exportData(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      Text('将学习数据导出为JSON文件')
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      if (this.wordCount > 0) {
        Text(`当前共有 ${this.wordCount} 个单词`)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.TEXT_TERTIARY)
          .width('100%')
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.XS })
      }

      if (this.exportResult.length > 0) {
        Text(this.exportResult)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.exportResult === '导出成功' ? this.colors.SUCCESS : this.colors.ERROR)
          .width('100%')
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.SM })
      }
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.MD, bottom: DesignTokens.Spacing.MD })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
  }

  @Builder
  private buildImportCard() {
    Column() {
      Row() {
        Text('导入数据')
          .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.TEXT_PRIMARY)

        Blank()

        Button(this.isImporting ? '导入中...' : '导入')
          .width(80)
          .height(36)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.WHITE)
          .backgroundColor(this.isImporting ? this.colors.GRAY_400 : this.colors.SUCCESS)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .enabled(!this.isImporting)
          .onClick(() => { void this.importData(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      Text('从JSON文件恢复学习数据')
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      Text('导入将覆盖现有数据，请谨慎操作')
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.WARNING)
        .width('100%')
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.XS })

      if (this.importResult.length > 0) {
        Text(this.importResult)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.importResult === '导入成功' ? this.colors.SUCCESS : this.colors.ERROR)
          .width('100%')
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.SM })
      }
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.MD, bottom: DesignTokens.Spacing.MD })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ top: DesignTokens.Spacing.MD })
  }

  @Builder
  private buildCloudSyncHint() {
    Row() {
      Column() {
        Text('推荐使用云端同步')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.TEXT_PRIMARY)

        Text('配置WebDAV后可自动同步，无需手动备份')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.colors.TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('去设置 >')
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.PRIMARY)
        .onClick(() => this.navigateToSyncSettings())
    }
    .width('100%')
    .height(64)
    .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
    .backgroundColor(this.colors.PRIMARY_LIGHTEST)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ top: DesignTokens.Spacing.MD })
  }

  build() {
    Column() {
      Text('本地备份与恢复')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      this.buildExportCard()
      this.buildImportCard()
      this.buildCloudSyncHint()
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
  }
}
