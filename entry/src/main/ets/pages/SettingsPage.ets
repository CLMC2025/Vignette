// =====================================================
// SettingsPage.ets - App Configuration Page
// API Key management and user preferences
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type resourceManager from '@ohos.resourceManager';
import type common from '@ohos.app.ability.common';
import { AppSettings } from '../model/WordModel';
import { DictionaryManager } from '../manager/DictionaryManager';
import { ThemeManager } from '../manager/ThemeManager';
import { DataSyncManager } from '../sync/DataSyncManager';
import { WebDavSyncManager } from '../sync/WebDavSyncManager';
import { ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import { SecureStorage } from '../utils/SecureStorage';
import { SettingsStore } from '../utils/SettingsStore';
import { DesignTokens } from '../model/DesignTokens';
import { WebDavStateStore } from '../utils/WebDavStateStore';
import { ColorsInterface } from '../model/TokenInterfaces';
import { logger } from '../utils/Logger';
import { buildUserFacingError } from '../utils/ErrorClassifier';

// Refactored Components
import { SettingsSectionItem } from './settings/SettingsCommon';
import { APIConfigSection, API_PROVIDERS } from './settings/APIConfigSection';
import { PreferencesSection } from './settings/PreferencesSection';
import { SettingsSyncSection } from './settings/SettingsSyncSection';
import { SettingsBackupSection } from './settings/SettingsBackupSection';
import { SettingsAboutSection } from './settings/SettingsAboutSection';
import { SettingsPrivacyDialog } from './settings/SettingsPrivacyDialog';
import { SettingsSyncDialog } from './settings/SettingsSyncDialog';
import { FSRSOptimizationSection } from './settings/FSRSOptimizationSection';
import { ExternalDictionarySection } from './settings/ExternalDictionarySection';

const SETTINGS_SECTIONS: SettingsSectionItem[] = [
  { id: 'preferences', title: '学习与偏好', subtitle: '任务计划、语音、难度与语境' },
  { id: 'dictionary', title: '外部词典', subtitle: '外链词典模板配置' },
  { id: 'fsrs', title: 'FSRS优化', subtitle: '根据记忆表现优化算法参数' },
  { id: 'api', title: 'API配置', subtitle: '提供商、接口与模型选择' },
  { id: 'sync', title: 'WebDAV 配置', subtitle: '云端连接与自动同步设置' },
  { id: 'backup', title: '备份与恢复', subtitle: '云端/本地数据导入导出' },
  { id: 'logger', title: '日志与调试', subtitle: '查看、导出与持久化策略（默认 WARN/ERROR）' },
  { id: 'about', title: '关于', subtitle: '版本、隐私与开源信息' }
];

interface LearningOrderPolicyJson {
  learningOrderPolicy?: string;
}

interface DialogIndexResult {
  index: number;
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
  @State dailyTotalTasks: number = 20;
  @State dailyReviewWords: number = 20;
  @State studyFlowMode: string = 'combined';
  @State learningOrderPolicy: string = 'due_first';
  @State enableTTS: boolean = true;
  @State pronunciationMode: string = 'auto';
  @State newbieMode: boolean = true;
  @State themeId: string = 'light';

  // Offline vignette cache
  @State enableVignetteCache: boolean = true;
  @State vignetteCacheMaxMB: number = 2;

  // Context preferences
  @State selectedContextStyle: ContextStyle = ContextStyle.RANDOM;
  @State customContextStyle: string = '';
  @State selectedDifficultyLevel: DifficultyLevel = DifficultyLevel.CET4;
  @State contextLengthMin: number = 0;
  @State contextLengthMax: number = 0;
  @State learningStepMinutes: number[] = [5, 120];

  // Timebox settings
  @State timeboxEnabled: boolean = true;
  @State timeboxLimitMinutes: number = 30;
  @State timeboxReminderMinutes: number = 5;

  @State externalDictEnabled: boolean = true;
  @State externalDictUrlTemplate: string = 'https://www.youdao.com/result?word={word}&lang=en';

  // Data Sync Dialog State
  @State showSyncDialog: boolean = false;
  @State syncDialogTitle: string = '';
  @State syncDialogMessage: string = '';
  @State syncDialogData: string = '';
  @State syncDialogIsImport: boolean = false;

  // Sync Manager
  private syncManager: DataSyncManager = DataSyncManager.getInstance();

  // Theme refresh
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  // WebDAV Sync & Evolve
  @State webdavEndpoint: string = '';
  @State webdavUsername: string = '';
  @State webdavPassword: string = '';
  @State webdavSyncPassword: string = '';
  @State webdavRemoteRoot: string = '/weiyu_sync';
  @State showWebdavPassword: boolean = false;
  @State showWebdavSyncPassword: boolean = false;
  @State webdavAutoSyncEnabled: boolean = true;
  @State webdavAutoSyncIntervalIndex: number = 2;
  @State webdavAutoSyncUploadModelEnabled: boolean = true;
  @State webdavAutoSyncUploadBackupEnabled: boolean = false;
  @State webdavAutoSyncLastSuccessMs: number = 0;
  @State webdavAutoSyncLastError: string = '';

  private webdavManager: WebDavSyncManager = WebDavSyncManager.getInstance();
  private webdavStateStore: WebDavStateStore = WebDavStateStore.getInstance();

  // UI State
  @State activeSectionId: string = '';
  @State showPrivacyDialog: boolean = false;

  // Storage keys
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';

  private parseLearningOrderPolicy(settingsJson: string): string {
    try {
      const parsed = JSON.parse(settingsJson) as LearningOrderPolicyJson;
      const v = parsed.learningOrderPolicy;
      if (typeof v === 'string' && v.length > 0) {
        return v;
      }
    } catch (e) {}
    return 'due_first';
  }

  aboutToAppear(): void {
    const secureStorage = SecureStorage.getInstance();
    const settingsStore = SettingsStore.getInstance();
    const context = getContext(this) as common.UIAbilityContext;
    secureStorage.injectContext(context);
    settingsStore.injectContext(context);
    this.webdavStateStore.injectContext(context);
    void this.initializePage(context);
  }

  aboutToDisappear(): void {
    void this.saveSettings(false);
  }

  private async initializePage(context: common.UIAbilityContext): Promise<void> {
    await this.loadSettings();
    await this.webdavManager.initialize(context);
    await this.webdavStateStore.initialize();
    this.loadWebDavSettings();
    await this.loadWebDavAutoSyncSettings();
    logger.info('Settings', '进入设置页');
  }

  private handleHeaderBack(): void {
    if (this.activeSectionId.length > 0) {
      this.activeSectionId = '';
      return;
    }
    void this.saveSettings(false).finally(() => {
      router.back();
    });
  }

  private getActiveSectionTitle(): string {
    if (this.activeSectionId.length === 0) {
      return '设置';
    }
    const item = SETTINGS_SECTIONS.find(s => s.id === this.activeSectionId);
    return item ? item.title : '设置';
  }

  private loadWebDavSettings(): void {
    const s = this.webdavManager.getSettings();
    this.webdavEndpoint = s.endpoint;
    this.webdavUsername = s.username;
    this.webdavPassword = s.password;
    this.webdavSyncPassword = s.syncPassword;
    this.webdavRemoteRoot = s.remoteRoot;
  }

  private async loadWebDavAutoSyncSettings(): Promise<void> {
    this.webdavAutoSyncEnabled = await this.webdavStateStore.getAutoSyncEnabled();
    const hours = await this.webdavStateStore.getAutoSyncIntervalHours();
    const HOURS = [1, 3, 6, 12, 24];
    const idx = HOURS.indexOf(hours);
    this.webdavAutoSyncIntervalIndex = idx >= 0 ? idx : 2;
    this.webdavAutoSyncUploadModelEnabled = await this.webdavStateStore.getAutoSyncUploadModelEnabled();
    this.webdavAutoSyncUploadBackupEnabled = await this.webdavStateStore.getAutoSyncUploadBackupEnabled();
    this.webdavAutoSyncLastSuccessMs = await this.webdavStateStore.getAutoSyncLastSuccessMs();
    this.webdavAutoSyncLastError = await this.webdavStateStore.getAutoSyncLastError();
  }

  private async loadSettings(): Promise<void> {
    try {
      const secureStorage = SecureStorage.getInstance();
      this.apiKey = await secureStorage.getApiKey();
      
      const settingsStore = SettingsStore.getInstance();
      const persisted = await settingsStore.getSettings();
      
      let settings = persisted;
      if (!settings) {
        const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
        if (settingsJson && settingsJson.length > 0) {
          settings = AppSettings.fromJSON(settingsJson);
          await settingsStore.saveSettings(settings);
        }
      }

      if (settings) {
        if (!persisted) { // If loaded from AppStorage, sync to AppStorage again? No, just load vars
           AppStorage.setOrCreate(this.STORAGE_KEY_SETTINGS, settings.toJSON());
        } else {
           AppStorage.setOrCreate(this.STORAGE_KEY_SETTINGS, settings.toJSON());
        }
        
        this.apiBaseUrl = settings.apiBaseUrl;
        this.selectedModel = settings.apiModel;
        this.selectedContextStyle = settings.contextStyle as ContextStyle;
        this.customContextStyle = settings.customContextStyle;
        this.selectedDifficultyLevel = settings.difficultyLevel as DifficultyLevel;
        this.dailyNewWords = settings.dailyNewWords;
        this.dailyTotalTasks = settings.dailyTotalTasks;
        this.dailyReviewWords = settings.dailyReviewWords;
        this.studyFlowMode = settings.studyFlowMode;
        this.learningOrderPolicy = this.parseLearningOrderPolicy(settings.toJSON());
        this.enableTTS = settings.enableTTS;
        this.pronunciationMode = settings.pronunciationMode;
        this.newbieMode = settings.newbieMode;
        this.themeId = settings.theme ?? 'light';
        ThemeManager.getInstance().setTheme(this.themeId);
        this.contextLengthMin = settings.contextLengthMin;
        this.contextLengthMax = settings.contextLengthMax;
        this.learningStepMinutes = settings.learningStepMinutes.length > 0
          ? settings.learningStepMinutes
          : [5, 120];
        this.enableVignetteCache = settings.enableVignetteCache;
        this.vignetteCacheMaxMB = Math.max(1, Math.round(settings.vignetteCacheMaxBytes / 1_000_000));
        this.timeboxEnabled = settings.timeboxEnabled;
        this.timeboxLimitMinutes = settings.timeboxLimitMinutes;
        this.timeboxReminderMinutes = settings.timeboxReminderMinutes;
        this.externalDictEnabled = settings.externalDictEnabled;
        this.externalDictUrlTemplate = settings.externalDictUrlTemplate;
        this.updateProviderFromUrl(settings.apiBaseUrl);
      }
    } catch (e) {
      console.warn('[SettingsPage] loadSettings: Failed to load settings:', e);
    }
  }

  private updateProviderFromUrl(url: string): void {
    const normalized = this.normalizeApiBaseUrl(url);
    for (let i = 0; i < API_PROVIDERS.length - 1; i++) {
      const providerUrl = this.normalizeApiBaseUrl(API_PROVIDERS[i].baseUrl);
      if (providerUrl === normalized) {
        this.selectedProviderIndex = i;
        const models = API_PROVIDERS[i].models;
        if (models.length > 0 && models.indexOf(this.selectedModel) < 0) {
          this.selectedModel = models[0];
        }
        return;
      }
    }
    this.selectedProviderIndex = API_PROVIDERS.length - 1;
  }

  private normalizeApiBaseUrl(url: string): string {
    let base = url.trim();
    while (base.endsWith('/')) {
      base = base.slice(0, base.length - 1);
    }
    const versionPaths = ['/v1', '/v2', '/v4', '/api/v3', '/compatible-mode/v1'];
    for (const path of versionPaths) {
      if (base.endsWith(path)) {
        base = base.slice(0, base.length - path.length);
        break;
      }
    }
    return base;
  }

  private async saveSettings(showToast: boolean = true): Promise<boolean> {
    try {
      const cacheMaxBytes: number = Math.max(100_000, Math.round(this.vignetteCacheMaxMB * 1_000_000));
      const normalizedUrl = this.normalizeApiBaseUrl(this.apiBaseUrl);
      this.apiBaseUrl = normalizedUrl;

      const secureStorage = SecureStorage.getInstance();
      const keySaved = await secureStorage.saveApiKey(this.apiKey);
      if (!keySaved) {
        promptAction.showToast({ message: 'API密钥保存失败', duration: 2000 });
        return false;
      }

      const settings = new AppSettings(
        normalizedUrl, this.selectedModel, this.dailyNewWords, this.dailyTotalTasks, this.dailyReviewWords,
        this.studyFlowMode, this.learningOrderPolicy, this.enableTTS, this.pronunciationMode, this.newbieMode, this.themeId,
        this.selectedContextStyle, this.customContextStyle, this.selectedDifficultyLevel,
        this.enableVignetteCache, cacheMaxBytes, this.contextLengthMin, this.contextLengthMax,
        this.learningStepMinutes, 2, this.timeboxEnabled, this.timeboxLimitMinutes, this.timeboxReminderMinutes,
        this.externalDictEnabled, this.externalDictUrlTemplate
      );

      AppStorage.setOrCreate(this.STORAGE_KEY_SETTINGS, settings.toJSON());
      const settingsStore = SettingsStore.getInstance();
      const persisted = await settingsStore.saveSettings(settings);
      
      const dictManager = DictionaryManager.getInstance();
      dictManager.configure(normalizedUrl, this.apiKey, this.selectedModel);
      dictManager.setContextPreferences(this.selectedContextStyle, this.selectedDifficultyLevel, this.customContextStyle);
      dictManager.setVignetteCacheSettings(this.enableVignetteCache, cacheMaxBytes, 300);

      const currentRouterStack = parseInt(router.getLength());
      if (persisted) {
        ThemeManager.getInstance().setTheme(this.themeId);
        AppStorage.setOrCreate('home_refresh_token', Date.now());
      }
      if (showToast && currentRouterStack > 0 && persisted) {
        promptAction.showToast({ message: '配置保存成功', duration: 2000 });
      }
      return persisted;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      const errorInfo = buildUserFacingError(errMsg);
      promptAction.showToast({ 
        message: `${errorInfo.title}：${errorInfo.userMessage}`, 
        duration: 3000 
      });
      logger.error('SettingsPage', `Failed to save settings: ${errMsg}`);
      return false;
    }
  }

  private displaySyncDialog(title: string, message: string, data: string, isImport: boolean = false): void {
    this.syncDialogTitle = title;
    this.syncDialogMessage = message;
    this.syncDialogData = data;
    this.syncDialogIsImport = isImport;
    this.showSyncDialog = true;
  }

  private async confirmImportFromDialog(jsonData: string): Promise<void> {
    const preview = await this.syncManager.previewImport(jsonData);
    if (preview.errors.length > 0) {
      const firstError = preview.errors[0] || '数据格式错误';
      const errorInfo = buildUserFacingError(firstError);
      promptAction.showToast({ 
        message: `❌ 导入失败：${errorInfo.userMessage}`, 
        duration: 3000 
      });
      logger.error('SettingsPage', `Import preview failed: ${preview.errors.join(', ')}`);
      return;
    }

    const sample = preview.sampleUpdatedWords.length > 0 ? `\n示例：${preview.sampleUpdatedWords.join('、')}` : '';
    const msg = `将覆盖更新 ${preview.updated} 词，新增 ${preview.imported} 词，共 ${preview.total} 词。${sample}\n确认继续导入？`;
    const clicked = await (promptAction.showDialog({
      title: '导入预览',
      message: msg,
      buttons: [
        { text: '取消', color: String(this.colors.TEXT_SECONDARY) },
        { text: '继续导入', color: String(this.colors.PRIMARY) }
      ]
    }) as Promise<DialogIndexResult>);

    if (clicked.index === 0) return;

    const result = await this.syncManager.importData(jsonData);
    if (result.hasErrors()) {
      const firstError = result.errors[0] || '导入过程出错';
      const errorInfo = buildUserFacingError(firstError);
      promptAction.showToast({ 
        message: `❌ 导入失败：${errorInfo.userMessage}`, 
        duration: 3000 
      });
      logger.error('SettingsPage', `Import data failed: ${result.errors.join(', ')}`);
    } else {
      promptAction.showToast({ 
        message: `✅ 导入成功！${result.getSummary()}`, 
        duration: 2500 
      });
      this.showSyncDialog = false;
    }
  }

  @Builder
  buildSectionContent() {
    if (this.activeSectionId === 'preferences') {
      PreferencesSection({
        dailyNewWords: $dailyNewWords,
        dailyTotalTasks: $dailyTotalTasks,
        dailyReviewWords: $dailyReviewWords,
        studyFlowMode: $studyFlowMode,
        learningOrderPolicy: $learningOrderPolicy,
        enableTTS: $enableTTS,
        pronunciationMode: $pronunciationMode,
        newbieMode: $newbieMode,
        themeId: $themeId,
        selectedContextStyle: $selectedContextStyle,
        customContextStyle: $customContextStyle,
        selectedDifficultyLevel: $selectedDifficultyLevel,
        contextLengthMin: $contextLengthMin,
        contextLengthMax: $contextLengthMax,
        learningStepMinutes: $learningStepMinutes,
        timeboxEnabled: $timeboxEnabled,
        timeboxLimitMinutes: $timeboxLimitMinutes,
        timeboxReminderMinutes: $timeboxReminderMinutes
      })
    }
    if (this.activeSectionId === 'dictionary') {
      ExternalDictionarySection({
        externalDictEnabled: $externalDictEnabled,
        externalDictUrlTemplate: $externalDictUrlTemplate
      })
    }
    if (this.activeSectionId === 'fsrs') {
      FSRSOptimizationSection()
    }
    if (this.activeSectionId === 'api') {
      APIConfigSection({
        selectedProviderIndex: $selectedProviderIndex,
        apiBaseUrl: $apiBaseUrl,
        apiKey: $apiKey,
        selectedModel: $selectedModel,
        showApiKey: $showApiKey,
        onSave: () => { void this.saveSettings(true); }
      })
    }
    if (this.activeSectionId === 'sync') {
      SettingsSyncSection({
        webdavEndpoint: $webdavEndpoint,
        webdavUsername: $webdavUsername,
        webdavPassword: $webdavPassword,
        webdavSyncPassword: $webdavSyncPassword,
        webdavRemoteRoot: $webdavRemoteRoot,
        showWebdavPassword: $showWebdavPassword,
        showWebdavSyncPassword: $showWebdavSyncPassword,
        webdavAutoSyncEnabled: $webdavAutoSyncEnabled,
        webdavAutoSyncIntervalIndex: $webdavAutoSyncIntervalIndex,
        webdavAutoSyncUploadModelEnabled: $webdavAutoSyncUploadModelEnabled,
        webdavAutoSyncUploadBackupEnabled: $webdavAutoSyncUploadBackupEnabled,
        webdavAutoSyncLastSuccessMs: $webdavAutoSyncLastSuccessMs,
        webdavAutoSyncLastError: $webdavAutoSyncLastError
      })
    }
    if (this.activeSectionId === 'backup') {
      SettingsBackupSection({
        onShowDialog: (title, message, data, isImport) => {
          this.displaySyncDialog(title, message, data, isImport);
        }
      })
    }
    if (this.activeSectionId === 'about') {
      SettingsAboutSection({
        onShowPrivacy: () => { this.showPrivacyDialog = true; },
        onOpenOnboarding: () => { router.pushUrl({ url: 'pages/OnboardingPage' }); }
      })
    }
  }

  build() {
    Stack() {
      Column() {
        // Header
        Row() {
          Text('←')
            .fontSize(DesignTokens.Typography.FONT_SIZE_2XL)
            .fontColor(this.colors.GRAY_900)
            .onClick(() => { this.handleHeaderBack(); })
          
          Text(this.getActiveSectionTitle())
            .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
            .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
            .fontColor(this.colors.GRAY_900)
            .margin({ left: DesignTokens.Spacing.LG })
          
          Blank()
        }
        .width('100%')
        .height(56)
        .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING })
        .backgroundColor(this.colors.SURFACE_ELEVATED)
        .shadow({ color: this.colors.SHADOW_LIGHT, radius: 4, offsetX: 0, offsetY: 2 })

        Scroll() {
          Column() {
            if (this.activeSectionId.length === 0) {
              Column() {
                ForEach(SETTINGS_SECTIONS, (item: SettingsSectionItem) => {
                  Column() {
                    Row() {
                      Column() {
                        Text(item.title)
                          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                          .fontColor(this.colors.GRAY_900)
                          .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
                        Text(item.subtitle)
                          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
                          .fontColor(this.colors.GRAY_600)
                          .margin({ top: 4 })
                      }
                      .layoutWeight(1)
                      Text('›').fontSize(DesignTokens.Typography.FONT_SIZE_LG).fontColor(this.colors.GRAY_400)
                    }
                    .width('100%')
                    .height(64)
                    .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
                    .alignItems(VerticalAlign.Center)
                    .onClick(() => {
                      if (item.id === 'logger') {
                        router.pushUrl({ url: 'pages/LoggerPage' });
                      } else {
                        this.activeSectionId = item.id;
                      }
                    })
                    
                    Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
                  }
                }, (item: SettingsSectionItem) => item.id)
              }
              .width('100%')
              .backgroundColor(this.colors.SURFACE_PRIMARY)
              .borderRadius(DesignTokens.BorderRadius.LG)
              .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
              .margin({ top: DesignTokens.Spacing.LG })
            } else {
              this.buildSectionContent()
            }
          }
          .width('100%')
          .padding(DesignTokens.Layout.CONTAINER_PADDING)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_PRIMARY)

      // Dialogs
      SettingsPrivacyDialog({ visible: $showPrivacyDialog })
      
      SettingsSyncDialog({
        visible: $showSyncDialog,
        title: $syncDialogTitle,
        message: $syncDialogMessage,
        data: $syncDialogData,
        isImport: $syncDialogIsImport,
        onImport: (data) => { this.confirmImportFromDialog(data); }
      })
    }
    .id('settings_' + this.themeRefreshToken)
  }
}
