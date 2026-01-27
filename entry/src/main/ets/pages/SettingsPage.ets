// =====================================================
// SettingsPage.ets - App Configuration Page
// API Key management and user preferences
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import type common from '@ohos.app.ability.common';
import { AppSettings } from '../model/WordModel';
import { DictionaryManager } from '../manager/DictionaryManager';
import { DataSyncManager, SyncStatus } from '../sync/DataSyncManager';
import { WebDavSyncManager, WebDavSettings, WebDavSyncResult } from '../sync/WebDavSyncManager';
import { EvolveScheduler, SchedulerMode } from '../evolve/EvolveScheduler';
import { DBManager } from '../database/DBManager';
import { ContextStyle, DifficultyLevel, TemplateManager } from '../context/TemplateManager';
import { SecureStorage } from '../utils/SecureStorage';
import { parseSchedulerMode } from '../utils/SettingsUtils';
import { DesignTokens } from '../model/DesignTokens';

/**
 * Select option interface for dropdown components
 */
export interface SelectOption {
  value: string;
}

/**
 * Preset API providers
 */
class APIProvider {
  name: string;
  baseUrl: string;
  models: string[];

  constructor(name:  string, baseUrl:  string, models: string[]) {
    this.name = name;
    this.baseUrl = baseUrl;
    this.models = models;
  }
}

/**
 * Available API providers
 */
const API_PROVIDERS: APIProvider[] = [
  new APIProvider('DeepSeek', 'https://api.deepseek.com', ['deepseek-chat', 'deepseek-coder']),
  new APIProvider('SiliconFlow', 'https://api.siliconflow.cn', ['deepseek-ai/DeepSeek-V3.2', 'Qwen/Qwen2.5-72B-Instruct']),
  new APIProvider('OpenAI Compatible', 'https://api.openai.com/v1', ['gpt-4o-mini', 'gpt-4o']),
  new APIProvider('Volcano Engine', 'https://ark.cn-beijing.volces.com/api/v3', ['glm-4-7-251222', 'doubao-seed-1-6-251015']),
  new APIProvider('Custom', '', [])
];

const SCHEDULER_OPTIONS: SelectOption[] = [
  { value: 'FSRS（默认）' },
  { value: '进化策略（SSP-MMC）' },
  { value: '混合（更保守）' }
];

const SCHEDULER_MODES: SchedulerMode[] = [
  SchedulerMode.FSRS,
  SchedulerMode.SSPMMC,
  SchedulerMode.HYBRID
];

/**
 * 错误对象接口定义
 */
interface ErrorObject {
  message?: string;
  code?: number | string;
  name?: string;
}

@Entry
@Component
struct SettingsPage {
  // API Configuration
  @State selectedProviderIndex: number = 0;
  @State apiBaseUrl: string = 'https://api.deepseek.com';
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek-chat';
  @State showApiKey: boolean = false;

  // Preferences
  @State dailyNewWords: number = 10;
  @State enableTTS: boolean = true;
  @State newbieMode: boolean = true;
  @State selectedTheme: string = 'light';

  // Offline vignette cache
  @State enableVignetteCache: boolean = true;
  @State vignetteCacheMaxMB: number = 2;

  // Offline template pack (optional, downloaded via WebDAV)
  @State offlineTemplatePackCount: number = 0;

  // Scheduler
  @State schedulerModeIndex: number = 0;

  // Context preferences
  @State selectedContextStyle: ContextStyle = ContextStyle.CONVERSATIONAL;
  @State customContextStyle: string = '';
  @State selectedDifficultyLevel: DifficultyLevel = DifficultyLevel.CET4;

  // Data Sync
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State exportResult: string = '';
  @State importResult: string = '';
  @State showSyncDialog: boolean = false;
  @State syncDialogTitle: string = '';
  @State syncDialogMessage: string = '';
  @State syncDialogData: string = '';
  @State syncDialogIsImport: boolean = false;

  // Sync Manager
  private syncManager: DataSyncManager = DataSyncManager.getInstance();

  // WebDAV Sync & Evolve
  @State webdavEndpoint: string = '';
  @State webdavUsername: string = '';
  @State webdavPassword: string = '';
  @State webdavSyncPassword: string = '';
  @State webdavRemoteRoot: string = '/weiyu_sync';
  @State showWebdavPassword: boolean = false;
  @State showWebdavSyncPassword: boolean = false;
  @State webdavResult: string = '';
  @State webdavBusy: boolean = false;
  @State showWebdavMore: boolean = false;
  @State showWebdavAdvanced: boolean = false;
  @State templatePackStatus: string = '';
  @State templatePackProgress: number = 0;

  private webdavManager: WebDavSyncManager = WebDavSyncManager.getInstance();

  // UI State
  @State isTesting: boolean = false;
  @State testResult: string = '';
  @State testSuccess: boolean = false;

  // Scroll functionality - simplified
  @State showBackTop: boolean = false;

  // Storage keys
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';

  async aboutToAppear(): Promise<void> {
    // Inject ability context into SecureStorage
    const secureStorage = SecureStorage.getInstance();
    const context = getContext(this) as common.UIAbilityContext;
    secureStorage.injectContext(context);
    
    await this.loadSettings();
    this.loadWebDavSettings();
    this.offlineTemplatePackCount = TemplateManager.getInstance().getExternalTemplateCount();
  }

  async aboutToDisappear(): Promise<void> {
    await this.saveSettings();
  }

  // Handle scroll event to show/hide back to top button
  private onScroll(offset: number, yOffset: number): void {
    // Show back to top button when scrolled down more than 500px
    this.showBackTop = yOffset > 500;
  }

  // Scroll to top functionality removed due to API issues
  private scrollToTop(): void {
    // Simplified implementation - no scroll controller
  }

  // Build back to top button
  @Builder
  buildBackToTopButton() {
    if (this.showBackTop) {
      Button('↑')
        .width(44)
        .height(44)
        .fontSize(20)
        .fontColor(DesignTokens.Colors.WHITE)
        .backgroundColor(DesignTokens.Colors.PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.FULL)
        .shadow(DesignTokens.Shadows.LG)
        .stateEffect(true)
        .onClick(() => this.scrollToTop())
        .position({ x: '90%', y: '90%' })
        .zIndex(100)
    }
  }

  private loadWebDavSettings(): void {
    const s = this.webdavManager.getSettings();
    this.webdavEndpoint = s.endpoint;
    this.webdavUsername = s.username;
    this.webdavPassword = s.password;
    this.webdavSyncPassword = s.syncPassword;
    this.webdavRemoteRoot = s.remoteRoot;
  }

  private saveWebDavSettings(): void {
    const s = new WebDavSettings(
      this.webdavEndpoint.trim(),
      this.webdavUsername.trim(),
      this.webdavPassword,
      this.webdavSyncPassword,
      this.webdavRemoteRoot.trim().length > 0 ? this.webdavRemoteRoot.trim() : '/weiyu_sync'
    );
    this.webdavManager.setSettings(s);
    this.webdavResult = 'WebDAV 设置已保存';
  }

  private async loadSettings(): Promise<void> {
    try {
      console.log('[SettingsPage] loadSettings: Starting to load settings');

      // Load API key from secure storage
      const secureStorage = SecureStorage.getInstance();
      this.apiKey = await secureStorage.getApiKey();
      console.log('[SettingsPage] loadSettings: Loaded API key, length:', this.apiKey.length);

      // Load other settings from AppStorage
      const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
      console.log('[SettingsPage] loadSettings: Loaded settings from AppStorage:', settingsJson ? 'yes' : 'no');

      if (settingsJson !== undefined && settingsJson.length > 0) {
        const settings = AppSettings.fromJSON(settingsJson);
        this.apiBaseUrl = settings.apiBaseUrl;
        this.selectedModel = settings.apiModel;
        this.selectedContextStyle = settings.contextStyle as ContextStyle;
        this.customContextStyle = settings.customContextStyle;
        this.selectedDifficultyLevel = settings.difficultyLevel as DifficultyLevel;
        this.dailyNewWords = settings.dailyNewWords;
        this.enableTTS = settings.enableTTS;
        this.newbieMode = settings.newbieMode;
        this.selectedTheme = settings.theme;

        // Offline vignette cache
        this.enableVignetteCache = settings.enableVignetteCache;
        this.vignetteCacheMaxMB = Math.max(1, Math.round(settings.vignetteCacheMaxBytes / 1_000_000));

        // Scheduler mode
        const mode = parseSchedulerMode(settings.schedulerMode);
        const idx = SCHEDULER_MODES.indexOf(mode);
        this.schedulerModeIndex = idx >= 0 ? idx : 0;

        this.updateProviderFromUrl(settings.apiBaseUrl);
        console.log('[SettingsPage] loadSettings: Updated provider from URL:', this.apiBaseUrl);
      }

      console.log('[SettingsPage] loadSettings: Settings loaded successfully');
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.warn('[SettingsPage] loadSettings: Failed to load settings:', errMsg);
    }
  }

  private updateProviderFromUrl(url: string): void {
    // Match known providers by base URL; keep user's model if still valid.
    for (let i = 0; i < API_PROVIDERS.length - 1; i++) {
      if (API_PROVIDERS[i].baseUrl === url) {
        this.selectedProviderIndex = i;
        const models = API_PROVIDERS[i].models;
        if (models.length > 0 && models.indexOf(this.selectedModel) < 0) {
          this.selectedModel = models[0];
        }
        return;
      }
    }
    // Custom
    this.selectedProviderIndex = API_PROVIDERS.length - 1;
  }



  private async saveSettings(): Promise<void> {
    try {
      console.log('[SettingsPage] saveSettings: Starting to save settings');

      const schedulerMode: SchedulerMode = SCHEDULER_MODES[this.schedulerModeIndex] ?? SchedulerMode.FSRS;
      const cacheMaxBytes: number = Math.max(100_000, Math.round(this.vignetteCacheMaxMB * 1_000_000));

      // Save API key securely
      const secureStorage = SecureStorage.getInstance();
      const keySaved = await secureStorage.saveApiKey(this.apiKey);
      console.log('[SettingsPage] saveSettings: API key saved:', keySaved);
      
      if (!keySaved) {
        console.error('[SettingsPage] saveSettings: Failed to save API key');
        promptAction.showToast({
          message: 'API密钥保存失败，请重试',
          duration: 2000
        });
        return;
      }

      // Save other settings to AppStorage (without API key)
      const settings = new AppSettings(
        this.apiBaseUrl,
        this.selectedModel,
        this.dailyNewWords,
        this.enableTTS,
        this.newbieMode,
        this.selectedTheme,
        this.selectedContextStyle,
        this.customContextStyle,
        this.selectedDifficultyLevel,
        this.enableVignetteCache,
        cacheMaxBytes,
        schedulerMode
      );

      AppStorage.setOrCreate(this.STORAGE_KEY_SETTINGS, settings.toJSON());
      console.log('[SettingsPage] saveSettings: App settings saved to AppStorage');

      // Update dictionary manager with latest settings
      const dictManager = DictionaryManager.getInstance();
      dictManager.configure(this.apiBaseUrl, this.apiKey, this.selectedModel);
      dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel, this.customContextStyle);
      dictManager.setVignetteCacheSettings(this.enableVignetteCache, cacheMaxBytes, 1000);
      EvolveScheduler.setMode(schedulerMode);
      console.log('[SettingsPage] saveSettings: Dictionary manager configured');

      // Only show toast if not in background save (e.g., aboutToDisappear)
      const currentRouterStack = parseInt(router.getLength());
      if (currentRouterStack > 0) {
        promptAction.showToast({
          message: '配置保存成功',
          duration: 2000
        });
      }
      console.log('[SettingsPage] saveSettings: Settings saved successfully');
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[SettingsPage] saveSettings: Failed to save settings:', errMsg);
      promptAction.showToast({
        message: '保存失败: ' + errMsg,
        duration: 2000
      });
    }
  }

  private formatError(e: Error | ErrorObject | string | number | boolean): string {
    if (e instanceof Error) {
      return e.message;
    }
    if (typeof e === 'string') {
      return e;
    }
    if (typeof e === 'object' && e !== null) {
      const errorObj = e as ErrorObject;
      if (errorObj.message && typeof errorObj.message === 'string') {
        return errorObj.message;
      }
      return String(e);
    }
    return String(e);
  }

  private formatModelSummary(): string {
    const v = EvolveScheduler.getModelVersion();
    const t = EvolveScheduler.getModelTrainedAtMs();
    if (v <= 0) {
      return '未训练';
    }
    if (t <= 0) {
      return `v${v}`;
    }
    try {
      const ts = new Date(t).toLocaleString();
      return `v${v} · ${ts}`;
    } catch {
      return `v${v}`;
    }
  }



  private async testConnection(): Promise<void> {
    if (this.apiKey.length === 0) {
      this.testResult = '❌ 请先输入API密钥';
      this.testSuccess = false;
      return;
    }

    this.isTesting = true;
    this.testResult = '正在测试连接...';

    try {
      const dictManager = DictionaryManager.getInstance();
      dictManager.configure(this.apiBaseUrl, this.apiKey, this.selectedModel);
      dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel);

      const result = await dictManager.lookup('test', '');

      if (result.success) {
        this.testResult = '✅ 连接成功！';
        this.testSuccess = true;
        await this.saveSettings(); // 自动保存配置
      } else {
        // 优化错误信息，提供更友好的提示
        let errorMsg = result.error;
        let suggestion = '';

        // 根据错误类型提供相应的解决建议
        if (errorMsg.includes('401') || errorMsg.includes('Unauthorized')) {
          suggestion = ' 请检查API密钥是否正确';
        } else if (errorMsg.includes('404') || errorMsg.includes('Not Found')) {
          suggestion = ' 请检查API地址是否正确';
        } else if (errorMsg.includes('timeout') || errorMsg.includes('Timeout')) {
          suggestion = ' 连接超时，请检查网络连接或稍后重试';
        } else if (errorMsg.includes('network') || errorMsg.includes('Network')) {
          suggestion = ' 网络错误，请检查网络连接';
        }

        this.testResult = `❌ ${errorMsg}${suggestion}`;
        this.testSuccess = false;
      }
    } catch (e) {
      const errMsg = this.formatError(e);
      let suggestion = '';

      // 根据错误类型提供相应的解决建议
      if (errMsg.includes('network') || errMsg.includes('Network')) {
        suggestion = ' 网络错误，请检查网络连接';
      } else if (errMsg.includes('invalid') || errMsg.includes('Invalid')) {
        suggestion = ' 请检查API配置是否正确';
      }

      this.testResult = `❌ 连接失败: ${errMsg}${suggestion}`;
      this.testSuccess = false;
    } finally {
      this.isTesting = false;
    }
  }

  private onProviderChange(index:  number): void {
    this.selectedProviderIndex = index;
    const provider = API_PROVIDERS[index];

    if (provider.name !== 'Custom') {
      this.apiBaseUrl = provider.baseUrl;
      // Only reset model if it's not in the provider's model list
      if (provider.models.length > 0 && !provider.models.includes(this.selectedModel)) {
        this.selectedModel = provider.models[0];
      }
    }

    this.testResult = '';
  }

  private getProviderOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (const provider of API_PROVIDERS) {
      options.push({ value: provider.name });
    }
    return options;
  }

  private getModelOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    const provider = API_PROVIDERS[this.selectedProviderIndex];
    for (const model of provider.models) {
      options.push({ value: model });
    }
    return options;
  }

  // ==================== DATA SYNC METHODS ====================

  /**
   * 导出数据
   */
  private async exportData(): Promise<void> {
    if (this.syncManager.getSyncStatus() !== SyncStatus.IDLE) {
      promptAction.showToast({ message: '同步操作正在进行中', duration: 2000 });
      return;
    }

    this.isExporting = true;
    this.exportResult = '';

    try {
      const result = await this.syncManager.exportData();

      if (result.success) {
        this.exportResult = `✅ 导出成功！数据大小: ${result.data.length} 字符`;

        // 保存到文件（简化实现）
        this.displaySyncDialog('导出成功', '数据已生成（请复制保存）。', result.data, false);
      } else {
        this.exportResult = `❌ 导出失败: ${result.error}`;
      }
    } catch (e) {
      const errMsg = this.formatError(e);
      this.exportResult = `❌ 导出错误: ${errMsg}`;
    } finally {
      this.isExporting = false;
    }
  }

  /**
   * 导入数据
   */
  private async importData(): Promise<void> {
    // Open import dialog; user pastes JSON then taps "导入".this.displaySyncDialog('导入数据', '请粘贴之前导出的 JSON 数据（建议先在外部保存备份）。', '', true);
  }

  /**
   * 显示同步对话框
   */
  private displaySyncDialog(title: string, message: string, data: string, isImport: boolean = false): void {
    this.syncDialogTitle = title;
    this.syncDialogMessage = message;
    this.syncDialogData = data;
    this.syncDialogIsImport = isImport;
    this.showSyncDialog = true;
  }

  /**
   * 关闭同步对话框
   */
  private closeSyncDialog(): void {
    this.showSyncDialog = false;
    this.syncDialogTitle = '';
    this.syncDialogMessage = '';
    this.syncDialogData = '';
    this.syncDialogIsImport = false;
  }

  /**
   * 复制数据到剪贴板
   */
  private async copyToClipboard(data: string): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.clearData();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, data);
      systemPasteboard.setPasteData(pasteData);
      promptAction.showToast({ message: '已复制到剪贴板', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  /**
   * Show model suggestions based on selected provider
   */
  @Builder
  private showModelSuggestions() {
    // ArkTS @Builder only allows UI component syntax, no TypeScript declarations
    // We'll use a different approach: show model suggestions as separate elements
    Row() {
      Text('推荐: ')
        .fontSize(12)
        .fontColor('#999999')

      // Show first model if available
      if (API_PROVIDERS[this.selectedProviderIndex].models[0]) {
        Text(API_PROVIDERS[this.selectedProviderIndex].models[0])
          .fontSize(12)
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedModel = API_PROVIDERS[this.selectedProviderIndex].models[0];
          })
      }

      // Show second model if available
      if (API_PROVIDERS[this.selectedProviderIndex].models[1]) {
        Text(API_PROVIDERS[this.selectedProviderIndex].models[1])
          .fontSize(12)
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedModel = API_PROVIDERS[this.selectedProviderIndex].models[1];
          })
      }

      // Show third model if available
      if (API_PROVIDERS[this.selectedProviderIndex].models[2]) {
        Text(API_PROVIDERS[this.selectedProviderIndex].models[2])
          .fontSize(12)
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedModel = API_PROVIDERS[this.selectedProviderIndex].models[2];
          })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .margin({ top: 4 })
  }

  build() {
    Stack() {
      Column() {
        this.buildHeader()

        Scroll() {
          Column() {
            this.buildAPISection()
            this.buildDataSyncSection()
            this.buildWebDavSection()
            this.buildPreferencesSection()
            this.buildAboutSection()
            this.buildSaveButton()
          }
          .width('100%')
          .padding({
            left: DesignTokens.Layout.CONTAINER_PADDING,
            right: DesignTokens.Layout.CONTAINER_PADDING,
            bottom: DesignTokens.Spacing.XXXL
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onScroll((offset: number, yOffset: number) => this.onScroll(offset, yOffset))
      }
      .width('100%')
      .height('100%')
      .backgroundColor(DesignTokens.Colors.GRAY_50)

      // Sync Dialog Overlay
      if (this.showSyncDialog) {
        this.buildSyncDialog()
      }

      // Back to top button
      this.buildBackToTopButton()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildSyncDialog() {
    Column() {
      // Backdrop
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => this.closeSyncDialog())
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })

    // Dialog Content
    Column() {
      Column() {
        Text(this.syncDialogTitle.length > 0 ? this.syncDialogTitle : '数据同步')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ bottom: 12 })

        if (this.syncDialogMessage.length > 0) {
          Text(this.syncDialogMessage)
            .fontSize(13)
            .fontColor('#666666')
            .margin({ bottom: 12 })
        }

        // Data area
        TextArea({ text: this.syncDialogData, placeholder: this.syncDialogIsImport ? '在此粘贴 JSON...' : '' })
          .width('100%')
          .height(180)
          .fontSize(12)
          .backgroundColor('#F7F7F7')
          .borderRadius(8)
          .padding(8)
          .enabled(this.syncDialogIsImport)
          .onChange((value: string) => {
            this.syncDialogData = value;
          })
          .margin({ bottom: 16 })

        Row() {
          if (!this.syncDialogIsImport) {
            Button('复制')
              .width('45%')
              .height(44)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#2196F3')
              .borderRadius(22)
              .onClick(() => {
                this.copyToClipboard(this.syncDialogData.length > 0 ? this.syncDialogData : this.syncDialogMessage);
              })

            Blank()

            Button('关闭')
              .width('45%')
              .height(44)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#666666')
              .borderRadius(22)
              .onClick(() => this.closeSyncDialog())
          } else {
            Button('导入')
              .width('45%')
              .height(44)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#4CAF50')
              .borderRadius(22)
              .enabled(!this.isImporting && this.syncDialogData.trim().length > 0)
              .onClick(() => {
                this.confirmImportFromDialog();
              })

            Blank()

            Button('取消')
              .width('45%')
              .height(44)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#666666')
              .borderRadius(22)
              .enabled(!this.isImporting)
              .onClick(() => this.closeSyncDialog())
          }
        }
      }
      .width('90%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .shadow({
        color: '#00000020',
        radius: 8,
        offsetX: 0,
        offsetY: 4
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
  }

  // Import from dialog data
  private async confirmImportFromDialog(): Promise<void> {
    if (this.isImporting) {
      return;
    }

    const jsonData = this.syncDialogData.trim();
    if (jsonData.length === 0) {
      return;
    }

    this.isImporting = true;
    this.importResult = '';

    try {
      const preview = await this.syncManager.previewImport(jsonData);
      if (preview.errors.length > 0) {
        this.importResult = `❌ 解析失败: ${preview.errors.join(', ')}`;
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
        return;
      }

      const result = await this.syncManager.importData(jsonData);
      if (result.hasErrors()) {
        this.importResult = `❌ 导入失败: ${result.errors.join(', ')}`;
      } else {
        this.importResult = `✅ 导入成功！${result.getSummary()}`;
      }
    } catch (e) {
      const errMsg = this.formatError(e);
      this.importResult = `❌ 导入错误: ${errMsg}`;
    } finally {
      this.isImporting = false;
      this.closeSyncDialog();
    }
  }

  @Builder
  buildHeader() {
    Row() {
      Text('←')
        .fontSize(DesignTokens.Typography.FONT_SIZE_2XL)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .onClick(() => {
          router.back();
        })

      Text('设置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .margin({ left: DesignTokens.Spacing.LG })

      Blank()
    }
    .width('100%')
    .height(56)
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING
    })
    .backgroundColor(DesignTokens.Colors.WHITE)
    .shadow({
      color: '#00000010',
      radius: 4,
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildAPISection() {
    Column() {
      Text('API配置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        // Provider Selection
        this.buildProviderSettingItem()

        // Base URL
        this.buildBaseUrlSettingItem()

        // API Key
        this.buildApiKeySettingItem()

        // Model Selection
        this.buildModelSettingItem()

        // Test Connection Button
        Column() {
          Button(this.isTesting ? '测试中...' : '测试连接')
            .width('100%')
            .height(48)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.isTesting ? 
              DesignTokens.Colors.GRAY_400 : 
              DesignTokens.Colors.SUCCESS
            )
            .borderRadius(DesignTokens.BorderRadius.LG)
            .enabled(!this.isTesting)
            .margin({
              top: DesignTokens.Spacing.SM
            })
            .onClick(() => {
              this.testConnection();
            })

          if (this.testResult.length > 0) {
            Text(this.testResult)
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(this.testSuccess ? 
                DesignTokens.Colors.SUCCESS : 
                DesignTokens.Colors.ERROR
              )
              .margin({
                top: DesignTokens.Spacing.SM
              })
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          bottom: DesignTokens.Spacing.LG
        })
      }
      .width('100%')
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    }
    .width('100%')
  }

  /**
   * 构建设置项
   */
  @Builder
  buildProviderSettingItem() {
    Column() {
      Row() {
        Text('提供商')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)

        Blank()

        Select(this.getProviderOptions())
          .selected(this.selectedProviderIndex)
          .value(API_PROVIDERS[this.selectedProviderIndex].name)
          .font({
            size: DesignTokens.Typography.FONT_SIZE_BASE
          })
          .fontColor(DesignTokens.Colors.GRAY_700)
          .selectedOptionFont({
            size: DesignTokens.Typography.FONT_SIZE_BASE
          })
          .optionFont({
            size: DesignTokens.Typography.FONT_SIZE_BASE
          })
          .onSelect((index: number) => {
            this.onProviderChange(index);
          })
      }
      .width('100%')
      .height(56)
      .padding({
        left: DesignTokens.Spacing.LG,
        right: DesignTokens.Spacing.LG
      })
      .alignItems(VerticalAlign.Center)

      Divider().color(DesignTokens.Colors.GRAY_200).margin({
        left: DesignTokens.Spacing.LG
      })
    }
  }

  /**
   * 构建基础URL设置项
   */
  @Builder
  buildBaseUrlSettingItem() {
    Column() {
      Row() {
        Text('基础URL')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)

        Blank()

        if (this.selectedProviderIndex === API_PROVIDERS.length - 1) {
          TextInput({ 
            text: this.apiBaseUrl, 
            placeholder: 'https://api.example.com' 
          })
            .width(200)
            .height(40)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .textAlign(TextAlign.End)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({
              left: DesignTokens.Spacing.SM,
              right: DesignTokens.Spacing.SM
            })
            .onChange((value: string) => {
              this.apiBaseUrl = value;
            })
        } else {
          Text(this.apiBaseUrl)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .maxLines(1)
            .textOverflow({
              overflow: TextOverflow.Ellipsis
            })
            .constraintSize({ maxWidth: 200 })
        }
      }
      .width('100%')
      .height(56)
      .padding({
        left: DesignTokens.Spacing.LG,
        right: DesignTokens.Spacing.LG
      })
      .alignItems(VerticalAlign.Center)

      Divider().color(DesignTokens.Colors.GRAY_200).margin({
        left: DesignTokens.Spacing.LG
      })
    }
  }

  /**
   * 构建API密钥设置项
   */
  @Builder
  buildApiKeySettingItem() {
    Column() {
      Row() {
        Text('API密钥')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)

        Blank()

        Row() {
          TextInput({ 
            text: this.apiKey, 
            placeholder: '输入您的API密钥'
          })
            .width(180)
            .height(40)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .type(this.showApiKey ? InputType.Normal : InputType.Password)
            .textAlign(TextAlign.End)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({
              left: DesignTokens.Spacing.SM,
              right: DesignTokens.Spacing.SM
            })
            .onChange((value: string) => {
              this.apiKey = value;
              this.testResult = '';
            })

          Text(this.showApiKey ? '👁' : '👁‍🗨')
            .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
            .margin({ left: DesignTokens.Spacing.SM })
            .onClick(() => {
              this.showApiKey = !this.showApiKey;
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({
        left: DesignTokens.Spacing.LG,
        right: DesignTokens.Spacing.LG
      })
      .alignItems(VerticalAlign.Center)

      Divider().color(DesignTokens.Colors.GRAY_200).margin({
        left: DesignTokens.Spacing.LG
      })
    }
  }

  /**
   * 构建模型设置项
   */
  @Builder
  buildModelSettingItem() {
    Column() {
      Row() {
        Text('模型')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)

        Blank()

        Column() {
          TextInput({ 
            text: this.selectedModel, 
            placeholder: '模型名称' 
          })
            .width(180)
            .height(40)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .textAlign(TextAlign.End)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({
              left: DesignTokens.Spacing.SM,
              right: DesignTokens.Spacing.SM
            })
            .onChange((value: string) => {
              this.selectedModel = value;
            })

          this.showModelSuggestions()
        }
      }
      .width('100%')
      .height(56)
      .padding({
        left: DesignTokens.Spacing.LG,
        right: DesignTokens.Spacing.LG
      })
      .alignItems(VerticalAlign.Center)

      Divider().color(DesignTokens.Colors.GRAY_200).margin({
        left: DesignTokens.Spacing.LG
      })
    }
  }

  @Builder
  buildDataSyncSection() {
    Column() {
      Text('数据同步')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        // Export Button
        Button(this.isExporting ? '导出中...' : '导出数据')
          .width('100%')
          .height(48)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(this.isExporting ? 
            DesignTokens.Colors.GRAY_400 : 
            DesignTokens.Colors.PRIMARY
          )
          .borderRadius(DesignTokens.BorderRadius.LG)
          .enabled(!this.isExporting)
          .margin({
            top: DesignTokens.Spacing.LG
          })
          .onClick(() => {
            this.exportData();
          })

        if (this.exportResult.length > 0) {
          Text(this.exportResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.exportResult.includes('✅') ? 
              DesignTokens.Colors.SUCCESS : 
              DesignTokens.Colors.ERROR
            )
            .margin({
              top: DesignTokens.Spacing.SM
            })
            .textAlign(TextAlign.Center)
        }

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          top: DesignTokens.Spacing.MD
        })

        // Import Button
        Button(this.isImporting ? '导入中...' : '导入数据')
          .width('100%')
          .height(48)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(this.isImporting ? 
            DesignTokens.Colors.GRAY_400 : 
            DesignTokens.Colors.SUCCESS
          )
          .borderRadius(DesignTokens.BorderRadius.LG)
          .enabled(!this.isImporting)
          .margin({
            top: DesignTokens.Spacing.MD,
            bottom: DesignTokens.Spacing.LG
          })
          .onClick(() => {
            this.importData();
          })

        if (this.importResult.length > 0) {
          Text(this.importResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.importResult.includes('✅') ? 
              DesignTokens.Colors.SUCCESS : 
              DesignTokens.Colors.ERROR
            )
            .margin({
              bottom: DesignTokens.Spacing.LG
            })
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

  @Builder
  buildWebDavSection() {
    Column() {
      Text('WebDAV 同步与进化')
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
          .margin({
            top: DesignTokens.Spacing.LG,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        TextInput({ 
          text: this.webdavEndpoint, 
          placeholder: 'https://dav.example.com/dav/' 
        })
          .width('100%')
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })
          .onChange((value: string) => {
            this.webdavEndpoint = value;
          })

        // Username
        Text('账号')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        TextInput({ 
          text: this.webdavUsername, 
          placeholder: 'username' 
        })
          .width('100%')
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })
          .onChange((value: string) => {
            this.webdavUsername = value;
          })

        // Password
        Text('密码')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          TextInput({ 
            text: this.webdavPassword, 
            placeholder: 'password' 
          })
            .type(this.showWebdavPassword ? InputType.Normal : InputType.Password)
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.SM
            })
            .onChange((value: string) => {
              this.webdavPassword = value;
            })

          Button(this.showWebdavPassword ? '隐藏' : '显示')
            .margin({
              left: DesignTokens.Spacing.SM,
              right: DesignTokens.Spacing.LG
            })
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .backgroundColor(DesignTokens.Colors.GRAY_200)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .onClick(() => {
              this.showWebdavPassword = !this.showWebdavPassword;
            })
        }

        // Sync password
        Text('同步密码（用于 AES 加密）')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          TextInput({ 
            text: this.webdavSyncPassword, 
            placeholder: 'sync password' 
          })
            .type(this.showWebdavSyncPassword ? InputType.Normal : InputType.Password)
            .layoutWeight(1)
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.SM
            })
            .onChange((value: string) => {
              this.webdavSyncPassword = value;
            })

          Button(this.showWebdavSyncPassword ? '隐藏' : '显示')
            .margin({
              left: DesignTokens.Spacing.SM,
              right: DesignTokens.Spacing.LG
            })
            .height(44)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_700)
            .backgroundColor(DesignTokens.Colors.GRAY_200)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .onClick(() => {
              this.showWebdavSyncPassword = !this.showWebdavSyncPassword;
            })
        }

        // Root path
        Text('远端目录')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        TextInput({ 
          text: this.webdavRemoteRoot, 
          placeholder: '/weiyu_sync' 
        })
          .width('100%')
          .height(44)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .backgroundColor(DesignTokens.Colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })
          .onChange((value: string) => {
            this.webdavRemoteRoot = value;
          })

        // Primary actions (default visible)
        Row() {
          Button(this.webdavBusy ? '处理中...' : '立即同步')
            .layoutWeight(1)
            .height(48)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.webdavBusy ? 
              DesignTokens.Colors.GRAY_400 : 
              DesignTokens.Colors.SUCCESS
            )
            .borderRadius(DesignTokens.BorderRadius.LG)
            .accessibilityText('立即同步')
            .enabled(!this.webdavBusy)
            .onClick(async () => {
              await this.webdavBackup();
            })

          Button(this.webdavBusy ? '处理中...' : '从云端恢复')
            .layoutWeight(1)
            .height(48)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.webdavBusy ? 
              DesignTokens.Colors.GRAY_400 : 
              DesignTokens.Colors.WARNING
            )
            .borderRadius(DesignTokens.BorderRadius.LG)
            .accessibilityText('从云端恢复')
            .enabled(!this.webdavBusy)
            .margin({
              left: DesignTokens.Spacing.SM
            })
            .onClick(async () => {
              await this.webdavRestore();
            })
        }
        .margin({
          top: DesignTokens.Spacing.MD,
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // More actions (collapsed)
        Row() {
          Text('更多操作')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)

          Blank()

          Text(this.showWebdavMore ? '收起' : '展开')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.PRIMARY)
        }
        .width('100%')
        .height(48)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })
        .onClick(() => {
          this.showWebdavMore = !this.showWebdavMore;
        })

        if (this.showWebdavMore) {
          // Advanced actions
          Divider().color(DesignTokens.Colors.GRAY_200).margin({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })

          Row() {
            Button(this.webdavBusy ? '处理中...' : '保存设置')
              .layoutWeight(1)
              .height(44)
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.WHITE)
              .backgroundColor(this.webdavBusy ? 
                DesignTokens.Colors.GRAY_400 : 
                DesignTokens.Colors.GRAY_600
              )
              .borderRadius(DesignTokens.BorderRadius.MD)
              .enabled(!this.webdavBusy)
              .onClick(() => {
                this.saveWebDavSettings();
              })

            Button(this.webdavBusy ? '处理中...' : '测试连接')
              .layoutWeight(1)
              .height(44)
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.WHITE)
              .backgroundColor(this.webdavBusy ? 
                DesignTokens.Colors.GRAY_400 : 
                DesignTokens.Colors.PRIMARY
              )
              .borderRadius(DesignTokens.BorderRadius.MD)
              .enabled(!this.webdavBusy)
              .margin({
                left: DesignTokens.Spacing.SM
              })
              .onClick(async () => {
                await this.webdavTest();
              })
          }
          .margin({
            top: DesignTokens.Spacing.SM,
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })

          // Advanced actions (collapsed)
          Row() {
            Text('高级/开发')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)

            Blank()

            Text(this.showWebdavAdvanced ? '收起' : '展开')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.PRIMARY)
          }
          .width('100%')
          .height(48)
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })
          .onClick(() => {
            this.showWebdavAdvanced = !this.showWebdavAdvanced;
          })

          if (this.showWebdavAdvanced) {
            Divider().color(DesignTokens.Colors.GRAY_200).margin({
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })

            Row() {
              Button(this.webdavBusy ? '处理中...' : '上传复习日志')
                .layoutWeight(1)
                .height(44)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(this.webdavBusy ? 
                  DesignTokens.Colors.GRAY_400 : 
                  DesignTokens.Colors.PURPLE
                )
                .borderRadius(DesignTokens.BorderRadius.MD)
                .enabled(!this.webdavBusy)
                .onClick(async () => {
                  await this.webdavUploadEvents();
                })

              Button(this.webdavBusy ? '处理中...' : '进化一次')
                .layoutWeight(1)
                .height(44)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(this.webdavBusy ? 
                  DesignTokens.Colors.GRAY_400 : 
                  DesignTokens.Colors.INDIGO
                )
                .borderRadius(DesignTokens.BorderRadius.MD)
                .enabled(!this.webdavBusy)
                .margin({
                  left: DesignTokens.Spacing.SM
                })
                .onClick(async () => {
                  await this.webdavEvolve();
                })
            }
            .margin({
              top: DesignTokens.Spacing.SM,
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })

            // Optional offline template pack (stored locally, fetched via WebDAV)
            Row() {
              Text(`离线模板包：已加载 ${this.offlineTemplatePackCount} 条`)
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(DesignTokens.Colors.GRAY_600)

              Blank()

              Button('清除本地')
                .height(32)
                .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(DesignTokens.Colors.GRAY_600)
                .borderRadius(DesignTokens.BorderRadius.MD)
                .enabled(!this.webdavBusy)
                .onClick(() => {
                  this.clearLocalTemplatePack();
                })
            }
            .margin({
              top: DesignTokens.Spacing.MD,
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })

            if (this.templatePackStatus.length > 0) {
              Column() {
                Text(this.templatePackStatus)
                  .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                  .fontColor(DesignTokens.Colors.GRAY_600)

                Progress({
                  value: this.templatePackProgress,
                  total: 100,
                  type: ProgressType.Linear
                })
                  .width('100%')
                  .height(6)
                  .color(DesignTokens.Colors.SUCCESS)
                  .backgroundColor(DesignTokens.Colors.GRAY_200)
                  .borderRadius(DesignTokens.BorderRadius.FULL)
              }
              .width('100%')
              .margin({
                top: DesignTokens.Spacing.SM,
                left: DesignTokens.Spacing.LG,
                right: DesignTokens.Spacing.LG
              })
            }

            Row() {
              Button(this.webdavBusy ? '处理中...' : '下载模板包')
                .layoutWeight(1)
                .height(44)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(this.webdavBusy ? 
                  DesignTokens.Colors.GRAY_400 : 
                  DesignTokens.Colors.GRAY_600
                )
                .borderRadius(DesignTokens.BorderRadius.MD)
                .enabled(!this.webdavBusy)
                .onClick(async () => {
                  await this.webdavDownloadTemplatePack();
                })

              Button(this.webdavBusy ? '处理中...' : '上传模板包')
                .layoutWeight(1)
                .height(44)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.WHITE)
                .backgroundColor(this.webdavBusy ? 
                  DesignTokens.Colors.GRAY_400 : 
                  DesignTokens.Colors.BROWN
                )
                .borderRadius(DesignTokens.BorderRadius.MD)
                .enabled(!this.webdavBusy)
                .margin({
                  left: DesignTokens.Spacing.SM
                })
                .onClick(async () => {
                  await this.webdavUploadTemplatePack();
                })
            }
            .margin({
              top: DesignTokens.Spacing.SM,
              left: DesignTokens.Spacing.LG,
              right: DesignTokens.Spacing.LG
            })
          }
        }

        if (this.webdavResult.length > 0) {
          Text(this.webdavResult)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.webdavResult.includes('✅') ? 
              DesignTokens.Colors.SUCCESS : 
              DesignTokens.Colors.GRAY_600
            )
            .margin({
              top: DesignTokens.Spacing.SM,
              bottom: DesignTokens.Spacing.LG
            })
            .textAlign(TextAlign.Center)
        }
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

      Column() {
        Text('词书许可证')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
          .fontColor(DesignTokens.Colors.GRAY_800)
          .margin({ bottom: DesignTokens.Spacing.SM })

        Text('NYIST-OS/WordList · MIT License')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .lineHeight(18)

        Text('包含 CET-4/CET-6/考研词表，详见 third_party/wordlists/NOTICE.md')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .lineHeight(18)
          .margin({ top: DesignTokens.Spacing.XS })
      }
      .width('100%')
      .padding(DesignTokens.Spacing.LG)
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .margin({ top: DesignTokens.Spacing.LG })
      .shadow({
        color: DesignTokens.Colors.SHADOW_LIGHT,
        radius: DesignTokens.Shadows.RADIUS_SM,
        offsetX: DesignTokens.Shadows.OFFSET_X_SM,
        offsetY: DesignTokens.Shadows.OFFSET_Y_SM
      })
    }
    .width('100%')
  }

  private async runWebDavAction(fn: () => Promise<WebDavSyncResult>): Promise<void> {
    this.webdavBusy = true;
    try {
      const res = await fn();
      if (res.success) {
        this.webdavResult = `✅ ${res.message}`;
      } else {
        this.webdavResult = `⚠️ ${res.message}${res.detail.length > 0 ? '：' + res.detail : ''}`;
      }
      promptAction.showToast({ message: res.message, duration: 1200 });
    } finally {
      this.webdavBusy = false;
    }
  }

  private async webdavTest(): Promise<void> {
    this.saveWebDavSettings();
    await this.runWebDavAction(() => this.webdavManager.testConnection());
  }

  private async webdavBackup(): Promise<void> {
    this.saveWebDavSettings();
    await this.runWebDavAction(() => this.webdavManager.backupToCloud());
  }

  private async webdavRestore(): Promise<void> {
    this.saveWebDavSettings();
    await this.runWebDavAction(() => this.webdavRestoreWithPreview());
  }

  private async webdavRestoreWithPreview(): Promise<WebDavSyncResult> {
    const download = await this.webdavManager.downloadBackupPlain(false);
    if (!download.result.success) return download.result;
    if (download.plain.length === 0) return download.result;

    const preview = await this.syncManager.previewImport(download.plain);
    if (preview.errors.length > 0) {
      return WebDavSyncResult.fail('预览失败', preview.errors.join('; '));
    }

    const sample = preview.sampleUpdatedWords.length > 0 ? 
      `\n示例：${preview.sampleUpdatedWords.join('、')}` : '';
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

  private async webdavUploadEvents(): Promise<void> {
    this.saveWebDavSettings();
    await this.runWebDavAction(() => this.webdavManager.uploadReviewEvents());
  }

  private async webdavEvolve(): Promise<void> {
    this.saveWebDavSettings();
    await this.runWebDavAction(() => this.webdavManager.evolveNow());
  }

  private async webdavDownloadTemplatePack(): Promise<void> {
    this.saveWebDavSettings();
    this.templatePackStatus = '下载中...';
    this.templatePackProgress = 30;
    await this.runWebDavAction(async () => {
      const res = await this.webdavManager.downloadTemplatePack();
      this.offlineTemplatePackCount = TemplateManager.getInstance().getExternalTemplateCount();
      return res;
    });
    this.templatePackProgress = 100;
    this.templatePackStatus = '下载完成';
  }

  private async webdavUploadTemplatePack(): Promise<void> {
    this.saveWebDavSettings();
    await this.runWebDavAction(() => this.webdavManager.uploadTemplatePack());
  }

  private clearLocalTemplatePack(): void {
    TemplateManager.getInstance().clearExternalTemplatePack();
    this.offlineTemplatePackCount = 0;
    this.templatePackStatus = '已清除本地模板包';
    this.templatePackProgress = 0;
    promptAction.showToast({ message: '已清除本地离线模板包', duration: 1200 });
  }

  private estimateVignetteWords(): number {
    const estimated = Math.round(this.vignetteCacheMaxMB * 120);
    return Math.max(50, estimated);
  }

  @Builder
  buildPreferencesSection() {
    Column() {
      Text('偏好设置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        // Daily New Words
        Text('每日新词')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.LG,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          Text(`${this.dailyNewWords}`)
            .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)

          Blank()

          Text('每天学习的新单词数量')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Slider({
          value: this.dailyNewWords,
          min: 5,
          max:  30,
          step:  5,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .padding({
            left: DesignTokens.Spacing.LG,
            right: DesignTokens.Spacing.LG
          })
          .blockColor(DesignTokens.Colors.PRIMARY)
          .trackColor(DesignTokens.Colors.GRAY_300)
          .selectedColor(DesignTokens.Colors.PRIMARY)
          .showTips(true)
          .onChange((value: number) => {
            this.dailyNewWords = Math.round(value);
          })

        Row() {
          Text('5')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_500)
          Blank()
          Text('30')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_500)
        }
        .width('100%')
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          bottom: DesignTokens.Spacing.SM
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Enable TTS
        Row() {
          Column() {
            Text('启用发音')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)
            Text('在学习过程中播放单词发音')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }

          Blank()

          Toggle({ type: ToggleType.Switch, isOn: this.enableTTS })
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .switchPointColor(DesignTokens.Colors.WHITE)
            .onChange((isOn: boolean) => {
              this.enableTTS = isOn;
            })
        }
        .width('100%')
        .height(64)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Newbie Mode
        Row() {
          Column() {
            Text('新手模式')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)
            Text('为新用户提供更友好的学习体验')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
          }

          Blank()

          Toggle({ type: ToggleType.Switch, isOn: this.newbieMode })
            .selectedColor(DesignTokens.Colors.PRIMARY)
            .switchPointColor(DesignTokens.Colors.WHITE)
            .onChange((isOn: boolean) => {
              this.newbieMode = isOn;
            })
        }
        .width('100%')
        .height(64)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Theme
        Text('主题')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          this.buildThemeOption('light', '浅色')
          this.buildThemeOption('dark', '深色')
          this.buildThemeOption('auto', '自动')
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          top: DesignTokens.Spacing.MD
        })

        // Context Style
        Text('语境风格')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Column() {
          Row() {
            this.buildContextStyleOption(ContextStyle.CONVERSATIONAL, '对话')
            this.buildContextStyleOption(ContextStyle.FORMAL, '正式')
            this.buildContextStyleOption(ContextStyle.HUMOROUS, '幽默')
          }
          .margin({
            bottom: DesignTokens.Spacing.SM
          })

          Row() {
            this.buildContextStyleOption(ContextStyle.NARRATIVE, '叙述')
            this.buildContextStyleOption(ContextStyle.TECHNICAL, '技术')
            this.buildContextStyleOption(ContextStyle.CUSTOM, '自定义')
          }
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        // Custom Style Input
        if (this.selectedContextStyle === ContextStyle.CUSTOM) {
          Column() {
            Text('自定义风格描述')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .margin({
                top: DesignTokens.Spacing.MD,
                left: DesignTokens.Spacing.LG,
                bottom: DesignTokens.Spacing.XS
              })

            TextInput({
              text: this.customContextStyle,
              placeholder: '输入自定义风格描述，如：科幻、古风、商务'
            })
              .width('100%')
              .height(44)
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .backgroundColor(DesignTokens.Colors.GRAY_100)
              .borderRadius(DesignTokens.BorderRadius.MD)
              .padding({
                left: DesignTokens.Spacing.LG,
                right: DesignTokens.Spacing.LG
              })
              .onChange((value: string) => {
                this.customContextStyle = value;
              })
          }
        }

        Divider().color(DesignTokens.Colors.GRAY_200).margin({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG,
          top: DesignTokens.Spacing.MD
        })

        // Difficulty Level
        Text('难度级别')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            top: DesignTokens.Spacing.MD,
            left: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Row() {
          this.buildDifficultyOption(DifficultyLevel.BEGINNER, '入门')
          this.buildDifficultyOption(DifficultyLevel.CET4, '四级')
          this.buildDifficultyOption(DifficultyLevel.CET6, '六级')
          this.buildDifficultyOption(DifficultyLevel.ADVANCED, '高级')
        }
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })
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

  @Builder
  buildThemeOption(value: string, label: string) {
    Column() {
      Circle()
        .width(40)
        .height(40)
        .fill(this.selectedTheme === value ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_200)
        .onClick(() => {
          this.selectedTheme = value;
        })

      Text(label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(DesignTokens.Colors.GRAY_600)
        .margin({
          top: DesignTokens.Spacing.XS
        })
    }
    .alignItems(HorizontalAlign.Center)
    .margin({ right: DesignTokens.Spacing.LG })
  }

  @Builder
  buildContextStyleOption(value: ContextStyle, label: string) {
    Text(label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(this.selectedContextStyle === value ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_700)
      .backgroundColor(this.selectedContextStyle === value ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_200)
      .padding({
        left: DesignTokens.Spacing.MD,
        right: DesignTokens.Spacing.MD,
        top: DesignTokens.Spacing.XS,
        bottom: DesignTokens.Spacing.XS
      })
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ right: DesignTokens.Spacing.SM })
      .onClick(() => {
        this.selectedContextStyle = value;
      })
  }

  @Builder
  buildDifficultyOption(value: DifficultyLevel, label: string) {
    Text(label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(this.selectedDifficultyLevel === value ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_700)
      .backgroundColor(this.selectedDifficultyLevel === value ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_200)
      .padding({
        left: DesignTokens.Spacing.MD,
        right: DesignTokens.Spacing.MD,
        top: DesignTokens.Spacing.XS,
        bottom: DesignTokens.Spacing.XS
      })
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({ right: DesignTokens.Spacing.SM })
      .onClick(() => {
        this.selectedDifficultyLevel = value;
      })
  }

  @Builder
  buildAboutSection() {
    Column() {
      Text('关于')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        Text('微语单词 v1.0.0')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)
          .margin({
            top: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Text('让单词学习更有趣')
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            bottom: DesignTokens.Spacing.LG
          })

        Divider().color(DesignTokens.Colors.GRAY_200)

        Row() {
          Text('学习算法')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_700)

          Blank()

          Text(SCHEDULER_OPTIONS[this.schedulerModeIndex].value)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.PRIMARY)
        }
        .height(48)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })

        Divider().color(DesignTokens.Colors.GRAY_200)

        Row() {
          Text('模型版本')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.GRAY_700)

          Blank()

          Text(this.formatModelSummary())
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(DesignTokens.Colors.GRAY_600)
        }
        .height(48)
        .padding({
          left: DesignTokens.Spacing.LG,
          right: DesignTokens.Spacing.LG
        })
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

  @Builder
  buildSaveButton() {
    Button('保存设置')
      .width('100%')
      .height(56)
      .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
      .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
      .fontColor(DesignTokens.Colors.WHITE)
      .backgroundColor(DesignTokens.Colors.PRIMARY)
      .borderRadius(DesignTokens.BorderRadius.FULL)
      .margin({
        top: DesignTokens.Spacing.XXL,
        bottom: DesignTokens.Spacing.XXXL
      })
      .shadow(DesignTokens.Shadows.LG)
      .stateEffect(true)
      .onClick(async () => {
        await this.saveSettings();
        promptAction.showToast({ message: '设置已保存', duration: 1500 });
      })
  }
}
