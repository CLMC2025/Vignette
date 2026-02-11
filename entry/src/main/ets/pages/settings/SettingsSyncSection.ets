import promptAction from '@ohos.promptAction';
import { DesignTokens } from '../../model/DesignTokens';
import { WebDavSyncManager, WebDavSettings, WebDavSyncResult } from '../../sync/WebDavSyncManager';
import { DataSyncManager } from '../../sync/DataSyncManager';
import { WebDavStateStore } from '../../utils/WebDavStateStore';
import { SelectOption } from './SettingsCommon';

const WEBDAV_AUTOSYNC_INTERVAL_HOURS: number[] = [1, 3, 6, 12, 24];
const WEBDAV_AUTOSYNC_INTERVAL_OPTIONS: SelectOption[] = [
  { value: '每1小时' },
  { value: '每3小时' },
  { value: '每6小时（默认）' },
  { value: '每12小时' },
  { value: '每24小时' }
];

@Component
export struct SettingsSyncSection {
  @Link webdavEndpoint: string;
  @Link webdavUsername: string;
  @Link webdavPassword: string;
  @Link webdavSyncPassword: string;
  @Link webdavRemoteRoot: string;
  @Link showWebdavPassword: boolean;
  @Link showWebdavSyncPassword: boolean;
  @Link webdavAutoSyncEnabled: boolean;
  @Link webdavAutoSyncIntervalIndex: number;
  @Link webdavAutoSyncUploadModelEnabled: boolean;
  @Link webdavAutoSyncUploadBackupEnabled: boolean;
  @Link webdavAutoSyncLastSuccessMs: number;
  @Link webdavAutoSyncLastError: string;

  // Local state for feedback
  @State webdavResult: string = '';
  @State webdavBackupResult: string = '';
  @State webdavBusy: boolean = false;

  private webdavManager: WebDavSyncManager = WebDavSyncManager.getInstance();
  private webdavStateStore: WebDavStateStore = WebDavStateStore.getInstance();
  private syncManager: DataSyncManager = DataSyncManager.getInstance();

  private async saveWebDavAutoSyncSettings(): Promise<void> {
    await this.webdavStateStore.setAutoSyncEnabled(this.webdavAutoSyncEnabled);
    const hours = WEBDAV_AUTOSYNC_INTERVAL_HOURS[this.webdavAutoSyncIntervalIndex] ?? 6;
    await this.webdavStateStore.setAutoSyncIntervalHours(hours);
    await this.webdavStateStore.setAutoSyncUploadModelEnabled(this.webdavAutoSyncUploadModelEnabled);
    await this.webdavStateStore.setAutoSyncUploadBackupEnabled(this.webdavAutoSyncUploadBackupEnabled);
  }

  private formatWebDavAutoSyncLastSuccess(): string {
    const ms = this.webdavAutoSyncLastSuccessMs;
    if (ms <= 0) {
      return '从未';
    }
    try {
      return new Date(ms).toLocaleString();
    } catch {
      return String(ms);
    }
  }

  private async saveWebDavSettings(): Promise<boolean> {
    const s = new WebDavSettings(
      this.webdavEndpoint.trim(),
      this.webdavUsername.trim(),
      this.webdavPassword,
      this.webdavSyncPassword,
      this.webdavRemoteRoot.trim().length > 0 ? this.webdavRemoteRoot.trim() : '/weiyu_sync',
      true
    );
    const saved = await this.webdavManager.setSettings(s);
    this.webdavResult = saved ? 'WebDAV 设置已保存' : 'WebDAV 设置保存失败';
    return saved;
  }

  private async runWebDavAction(fn: () => Promise<WebDavSyncResult>): Promise<void> {
    if (this.webdavBusy) {
      return;
    }
    this.webdavBusy = true;
    try {
      const res = await fn();
      if (res.success) {
        this.webdavResult = `✅ ${res.message}`;
      } else {
        // Simple error display, avoiding the large summarizer logic for now or inline it if needed
        this.webdavResult = `⚠️ ${res.message}：${res.detail}`;
      }
      promptAction.showToast({ message: res.message, duration: 1200 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.webdavResult = `⚠️ WebDAV 操作异常：${msg}`;
      promptAction.showToast({ message: 'WebDAV 操作异常', duration: 1200 });
    } finally {
      this.webdavBusy = false;
    }
  }

  private async runWebDavBackupAction(fn: () => Promise<WebDavSyncResult>): Promise<void> {
    if (this.webdavBusy) {
      return;
    }
    this.webdavBusy = true;
    try {
      const res = await fn();
      if (res.success) {
        this.webdavBackupResult = `✅ ${res.message}`;
      } else {
        this.webdavBackupResult = `⚠️ ${res.message}：${res.detail}`;
      }
      promptAction.showToast({ message: res.message, duration: 1200 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.webdavBackupResult = `⚠️ WebDAV 操作异常：${msg}`;
      promptAction.showToast({ message: 'WebDAV 操作异常', duration: 1200 });
    } finally {
      this.webdavBusy = false;
    }
  }

  private async webdavBackup(): Promise<void> {
    await this.runWebDavBackupAction(async () => {
      return this.webdavManager.backupToCloud();
    });
  }

  private async webdavRestore(): Promise<void> {
    await this.runWebDavBackupAction(async () => {
      return this.webdavRestoreWithPreview();
    });
  }

  private async webdavRestoreWithPreview(): Promise<WebDavSyncResult> {
    const download = await this.webdavManager.downloadBackupPlain(false);
    if (!download.result.success) {
      return download.result;
    }
    if (download.plain.length === 0) {
      return download.result;
    }

    const preview = await this.syncManager.previewImport(download.plain);
    if (preview.errors.length > 0) {
      return WebDavSyncResult.fail('预览失败', preview.errors.join('; '));
    }

    const sample = preview.sampleUpdatedWords.length > 0
      ? `\n示例：${preview.sampleUpdatedWords.join('、')}`
      : '';
    const msg = `将覆盖更新 ${preview.updated} 词，新增 ${preview.imported} 词，共 ${preview.total} 词。${sample}\n确认继续恢复？`;
    const clicked = await promptAction.showDialog({
      title: '恢复预览',
      message: msg,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '继续恢复', color: '#2196F3' }
      ]
    });

    if (clicked.index === 0) {
      return WebDavSyncResult.ok('已取消恢复');
    }

    return await this.webdavManager.importPlainBackup(download.plain);
  }

  private async webdavTest(): Promise<void> {
    await this.runWebDavAction(async () => {
      const saved = await this.saveWebDavSettings();
      if (!saved) return WebDavSyncResult.fail('WebDAV 连接失败', '保存设置失败');
      return this.webdavManager.testConnection();
    });
  }

  build() {
    Column() {
      Text('WebDAV 配置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        // Endpoint
        Text('WebDAV 地址')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.LG, left: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.XS })

        TextInput({ text: this.webdavEndpoint, placeholder: 'https://dav.example.com/dav/' })
          .width('100%')
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .onChange((value: string) => { this.webdavEndpoint = value; })

        // Username
        Text('账号')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.MD, left: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.XS })

        TextInput({ text: this.webdavUsername, placeholder: 'username' })
          .width('100%')
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .onChange((value: string) => { this.webdavUsername = value; })

        // Password
        Text('密码')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.MD, left: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.XS })

        Row() {
          TextInput({ text: this.webdavPassword, placeholder: 'password' })
            .type(this.showWebdavPassword ? InputType.Normal : InputType.Password)
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.SM })
            .onChange((value: string) => { this.webdavPassword = value; })

          Button(this.showWebdavPassword ? '隐藏' : '显示')
            .margin({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.LG })
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .backgroundColor(DesignTokens.Colors.GRAY_200)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .onClick(() => { this.showWebdavPassword = !this.showWebdavPassword; })
        }

        // Sync password
        Text('同步密码（用于 AES 加密）')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.MD, left: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.XS })

        Row() {
          TextInput({ text: this.webdavSyncPassword, placeholder: 'sync password' })
            .type(this.showWebdavSyncPassword ? InputType.Normal : InputType.Password)
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.SM })
            .onChange((value: string) => { this.webdavSyncPassword = value; })

          Button(this.showWebdavSyncPassword ? '隐藏' : '显示')
            .margin({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.LG })
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .backgroundColor(DesignTokens.Colors.GRAY_200)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .onClick(() => { this.showWebdavSyncPassword = !this.showWebdavSyncPassword; })
        }

        // Root path
        Text('远端目录')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.MD, left: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.XS })

        TextInput({ text: this.webdavRemoteRoot, placeholder: '/weiyu_sync' })
          .width('100%')
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .onChange((value: string) => { this.webdavRemoteRoot = value; })

        Text('提示：请先在 WebDAV 服务端创建该目录（只需一次）；本应用不自动创建目录。')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({ top: DesignTokens.Spacing.XS, left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        // Auto Sync Settings
        Row() {
          Column() {
            Text('自动同步（增量）')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)
            Text('进入前台时按间隔自动同步复习记录与模型')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.webdavAutoSyncEnabled })
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .switchPointColor(DesignTokens.Colors.WHITE)
            .onChange((isOn: boolean) => {
              this.webdavAutoSyncEnabled = isOn;
              this.saveWebDavAutoSyncSettings();
            })
        }
        .width('100%')
        .height(72)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        if (this.webdavAutoSyncEnabled) {
          Row() {
            Text('同步间隔')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)
            Blank()
            Select(WEBDAV_AUTOSYNC_INTERVAL_OPTIONS)
              .selected(this.webdavAutoSyncIntervalIndex)
              .value(WEBDAV_AUTOSYNC_INTERVAL_OPTIONS[this.webdavAutoSyncIntervalIndex].value)
              .font({ size: DesignTokens.Typography.FONT_SIZE_BASE })
              .fontColor(DesignTokens.Colors.GRAY_700)
              .selectedOptionFont({ size: DesignTokens.Typography.FONT_SIZE_BASE })
              .optionFont({ size: DesignTokens.Typography.FONT_SIZE_BASE })
              .onSelect((index: number) => {
                this.webdavAutoSyncIntervalIndex = index;
                this.saveWebDavAutoSyncSettings();
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .alignItems(VerticalAlign.Center)

          Row() {
            Column() {
              Text('自动上传模型')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.GRAY_700)
              Text('用于多端算法同步')
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(DesignTokens.Colors.GRAY_600)
            }
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.webdavAutoSyncUploadModelEnabled })
              .selectedColor(DesignTokens.Colors.PRIMARY)
              .switchPointColor(DesignTokens.Colors.WHITE)
              .onChange((isOn: boolean) => {
                this.webdavAutoSyncUploadModelEnabled = isOn;
                this.saveWebDavAutoSyncSettings();
              })
          }
          .width('100%')
          .height(64)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

          Row() {
            Column() {
              Text('自动上传全量备份（兜底）')
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.GRAY_700)
              Text('只上传，不自动恢复覆盖本地')
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(DesignTokens.Colors.GRAY_600)
            }
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.webdavAutoSyncUploadBackupEnabled })
              .selectedColor(DesignTokens.Colors.PRIMARY)
              .switchPointColor(DesignTokens.Colors.WHITE)
              .onChange((isOn: boolean) => {
                this.webdavAutoSyncUploadBackupEnabled = isOn;
                this.saveWebDavAutoSyncSettings();
              })
          }
          .width('100%')
          .height(64)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

          Text(`上次自动同步：${this.formatWebDavAutoSyncLastSuccess()}${this.webdavAutoSyncLastError.length > 0 ? `\n最近错误：${this.webdavAutoSyncLastError}` : ''}`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.webdavAutoSyncLastError.length > 0 ? DesignTokens.Colors.GRAY_700 : DesignTokens.Colors.GRAY_600)
            .margin({ top: DesignTokens.Spacing.XS, left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
        }

        // Actions
        Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.MD })

        Row() {
          Button(this.webdavBusy ? '处理中...' : '保存设置')
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.webdavBusy ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.GRAY_600)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .enabled(!this.webdavBusy)
            .onClick(async () => { await this.saveWebDavSettings(); })

          Button(this.webdavBusy ? '处理中...' : '测试连接')
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.webdavBusy ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.PRIMARY)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .enabled(!this.webdavBusy)
            .margin({ left: DesignTokens.Spacing.SM })
            .onClick(async () => { await this.webdavTest(); })
        }
        .margin({ top: DesignTokens.Spacing.SM, left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        if (this.webdavResult.length > 0) {
          Text(this.webdavResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.webdavResult.includes('✅') ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.GRAY_600)
            .margin({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.LG })
            .textAlign(TextAlign.Center)
        }

        Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.SM })

        Text('云端备份与恢复')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)
          .margin({ top: DesignTokens.Spacing.MD, left: DesignTokens.Spacing.LG })

        Row() {
          Button(this.webdavBusy ? '处理中...' : '立即备份')
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.webdavBusy ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.SUCCESS)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .enabled(!this.webdavBusy)
            .onClick(async () => { await this.webdavBackup(); })

          Button(this.webdavBusy ? '处理中...' : '从云端恢复')
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.webdavBusy ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.WARNING)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .enabled(!this.webdavBusy)
            .margin({ left: DesignTokens.Spacing.SM })
            .onClick(async () => { await this.webdavRestore(); })
        }
        .margin({ top: DesignTokens.Spacing.SM, left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        if (this.webdavBackupResult.length > 0) {
          Text(this.webdavBackupResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.webdavBackupResult.includes('✅') ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.GRAY_600)
            .margin({ top: DesignTokens.Spacing.SM, bottom: DesignTokens.Spacing.LG })
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
