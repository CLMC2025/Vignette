import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type resourceManager from '@ohos.resourceManager';
import type common from '@ohos.app.ability.common';
import notificationManager from '@ohos.notificationManager';
import { DesignTokens } from '../model/DesignTokens';
import { LoadingAnimation, LoadingType } from '../ui/LoadingAnimations';
import { TopNavigation } from './index/components/TopNavigation';
import { PrivacyPolicyDialog } from './index/components/PrivacyPolicyDialog';
import { DBManager } from '../database/DBManager';
import { SecureStorage } from '../utils/SecureStorage';
import { ContextDefinitionStore } from '../utils/ContextDefinitionStore';
import { SettingsStore } from '../utils/SettingsStore';
import { CelebrationParticles } from '../ui/CelebrationParticles';
import { WebDavManifest, WebDavSettings } from '../sync/WebDavSyncManager';
import { FeatureFlags } from '../utils/FeatureFlags';
import { CurrentBookStore } from '../utils/CurrentBookStore';
import { logger } from '../utils/Logger';
import { Base64Util } from '../sync/webdav/Base64Util';
import { AppNotificationRequest } from './index/IndexTypes';
import { HomeTabContent } from './index/HomeTabContent';
import { DictionaryManager } from '../manager/DictionaryManager';
import { ThemeManager } from '../manager/ThemeManager';
import { ContextStyle, DifficultyLevel } from '../context/TemplateManager';
import { GuideManager } from '../manager/GuideManager';
import { ColorsInterface } from '../model/TokenInterfaces';

@Entry
@Component
struct Index {
  @State private showCelebration: boolean = false;
  @State private celebrationSeed: number = 0;
  @State private showPrivacyDialog: boolean = false;
  @State private privacyLines: string[] = [];
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private context: common.UIAbilityContext | null = null;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  private privacyLoaded: boolean = false;
  private onboardingPushed: boolean = false;
  private readonly STORAGE_KEY_CELEBRATE_MS: string = 'today_session_complete_ms';
  private readonly STORAGE_KEY_FIRST_RUN_MS: string = 'first_run_ms';
  private readonly STORAGE_KEY_BACKUP_REMINDER_MS: string = 'last_backup_reminder_ms';

  private storesInitialized: boolean = false;
  private privacyChecked: boolean = false;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.resourceMgr = this.context.resourceManager;
    CurrentBookStore.getInstance().injectContext(this.context);
    SecureStorage.getInstance().injectContext(this.context);
    ContextDefinitionStore.getInstance().injectContext(this.context);
    SettingsStore.getInstance().injectContext(this.context);
    
    this.loadBuiltInDictionaryInBackground();
    
    void this.bootstrapApp();
  }

  onPageShow(): void {
    this.maybeTriggerCelebration();
    AppStorage.setOrCreate('home_refresh_token', Date.now());
    if (!this.privacyChecked) {
      void this.checkPrivacyConsent();
    }
    void this.maybeShowOnboarding();
  }

  private loadBuiltInDictionaryInBackground(): void {
    if (this.resourceMgr === null) {
      return;
    }
    const dictManager = DictionaryManager.getInstance();
    dictManager.setResourceManager(this.resourceMgr);
    dictManager.initializeBuiltInDictionary().then(() => {
      logger.info('App', '内置词典加载完成');
    }).catch((err: Error) => {
      logger.error('App', '内置词典加载失败', err.message);
    });
  }

  private async bootstrapApp(): Promise<void> {
    logger.info('App', '后台初始化开始');
    try {
      if (this.context !== null) {
        await Promise.all([
          this.initializeStores(),
          DBManager.getInstance().initialize(this.context)
        ]);
      } else {
        await this.initializeStores();
      }
      if (AppStorage.get<string>(this.STORAGE_KEY_FIRST_RUN_MS) === undefined) {
        AppStorage.setOrCreate(this.STORAGE_KEY_FIRST_RUN_MS, String(Date.now()));
      }
      logger.info('App', '后台初始化完成');
    } catch (e) {
      logger.error('App', '后台初始化失败', e);
    }
    this.runDeferredTasks();
    void this.maybeShowOnboarding();
  }

  private runDeferredTasks(): void {
    setTimeout(() => {
      void this.checkBackupReminder();
    }, 500);
  }

  private async maybeShowOnboarding(): Promise<void> {
    if (this.onboardingPushed) {
      return;
    }
    if (this.showPrivacyDialog) {
      return;
    }
    try {
      const store = SettingsStore.getInstance();
      const accepted = await store.getPrivacyConsent();
      if (!accepted) {
        return;
      }
      const guideManager = GuideManager.getInstance();
      guideManager.injectContext(this.context!);
      await guideManager.initialize();
      const state = await guideManager.getOnboardingState();
      if (state.hasSeenOnboarding) {
        return;
      }
      this.onboardingPushed = true;
      router.pushUrl({ url: 'pages/OnboardingPage' });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      logger.error('App', 'Failed to check onboarding state', errMsg);
    }
  }

  private async initializeStores(): Promise<void> {
    if (this.storesInitialized) {
      return;
    }
    try {
      await Promise.all([
        CurrentBookStore.getInstance().initialize(),
        SecureStorage.getInstance().initialize(),
        ContextDefinitionStore.getInstance().initialize(),
        SettingsStore.getInstance().initialize()
      ]);
      this.storesInitialized = true;
      if (this.context) {
        await logger.initialize(this.context, false);
      }
      void this.configureDictionaryManager();
    } catch (e) {
      logger.error('App', '初始化存储失败', e);
    }
  }

  private async configureDictionaryManager(): Promise<void> {
    try {
      const settings = await SettingsStore.getInstance().getSettings();
      if (settings === null) {
        return;
      }
      ThemeManager.getInstance().setTheme(settings.theme ?? 'light');
      const apiKey = await SecureStorage.getInstance().getApiKey();
      if (settings.apiBaseUrl.trim().length === 0 || apiKey.trim().length === 0) {
        return;
      }
      const dictManager = DictionaryManager.getInstance();
      dictManager.configure(settings.apiBaseUrl, apiKey, settings.apiModel);
      dictManager.setContextPreferences(this.mapContextStyle(settings.contextStyle), this.mapDifficultyLevel(settings.difficultyLevel), settings.customContextStyle);
      dictManager.setVignetteCacheSettings(settings.enableVignetteCache, settings.vignetteCacheMaxBytes, 300);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      logger.error('App', 'Failed to configure dictionary manager', errMsg);
    }
  }

  private mapContextStyle(raw: string): ContextStyle {
    switch (raw) {
      case ContextStyle.RANDOM:
        return ContextStyle.RANDOM;
      case ContextStyle.CONVERSATIONAL:
        return ContextStyle.CONVERSATIONAL;
      case ContextStyle.FORMAL:
        return ContextStyle.FORMAL;
      case ContextStyle.HUMOROUS:
        return ContextStyle.HUMOROUS;
      case ContextStyle.NARRATIVE:
        return ContextStyle.NARRATIVE;
      case ContextStyle.TECHNICAL:
        return ContextStyle.TECHNICAL;
      case ContextStyle.CUSTOM:
        return ContextStyle.CUSTOM;
      default:
        return ContextStyle.RANDOM;
    }
  }

  private mapDifficultyLevel(raw: number): DifficultyLevel {
    switch (raw) {
      case DifficultyLevel.BEGINNER:
        return DifficultyLevel.BEGINNER;
      case DifficultyLevel.CET4:
        return DifficultyLevel.CET4;
      case DifficultyLevel.CET6:
        return DifficultyLevel.CET6;
      case DifficultyLevel.POSTGRADUATE:
        return DifficultyLevel.POSTGRADUATE;
      case DifficultyLevel.IELTS:
        return DifficultyLevel.IELTS;
      case DifficultyLevel.TOEFL:
        return DifficultyLevel.TOEFL;
      case DifficultyLevel.SAT:
        return DifficultyLevel.SAT;
      case DifficultyLevel.GRE:
        return DifficultyLevel.GRE;
      case DifficultyLevel.ADVANCED:
        return DifficultyLevel.ADVANCED;
      default:
        return DifficultyLevel.CET4;
    }
  }

  private maybeTriggerCelebration(): void {
    const raw = AppStorage.get<string>(this.STORAGE_KEY_CELEBRATE_MS);
    if (!raw) return;
    const ms = Number(raw);
    if (!Number.isFinite(ms) || ms <= 0 || Date.now() - ms > 60 * 1000) {
      AppStorage.setOrCreate(this.STORAGE_KEY_CELEBRATE_MS, '');
      return;
    }
    AppStorage.setOrCreate(this.STORAGE_KEY_CELEBRATE_MS, '');
    this.celebrationSeed = this.celebrationSeed + 1;
    this.showCelebration = true;
    setTimeout(() => { this.showCelebration = false; }, 1600);
  }

  private async publishBackupReminderNotification(): Promise<void> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled && this.context) {
        try { await notificationManager.requestEnableNotification(this.context); } catch (_) {}
      }
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
      const req: AppNotificationRequest = {
        id: Number(Date.now()),
        slotId: 'backup_reminder',
        content: { content: { contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, normal: { title: '备份提醒', text: '已超过3天未备份，建议立即在设置页执行备份。' } } }
      };
      await notificationManager.publish(req as notificationManager.NotificationRequest);
    } catch (e) {
      promptAction.showToast({ message: '已超过3天未备份，请在设置中备份', duration: 2000 });
    }
  }

  private async checkBackupReminder(): Promise<void> {
    try {
      if (!FeatureFlags.isBackupReminderEnabled()) return;
      const settingsJson = AppStorage.get<string>('webdav_settings') ?? '';
      if (!settingsJson) return;
      const settings = WebDavSettings.fromJSON(settingsJson);
      if (!settings.endpoint || !settings.username) return;

      const now = Date.now();
      const firstRunMs = Number(AppStorage.get<string>(this.STORAGE_KEY_FIRST_RUN_MS) ?? String(now));
      let deviceId = AppStorage.get<string>('device_id') ?? '';
      if (!deviceId) {
        deviceId = `dev_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
        AppStorage.setOrCreate('device_id', deviceId);
      }
      const manifest = WebDavManifest.fromJSON(AppStorage.get<string>('webdav_manifest') ?? '', deviceId);
      const lastBackupMs = manifest.lastBackupUploadMs > 0 ? manifest.lastBackupUploadMs : firstRunMs;

      if (now - lastBackupMs < 3 * 24 * 3600 * 1000) return;
      const lastRemindMs = Number(AppStorage.get<string>(this.STORAGE_KEY_BACKUP_REMINDER_MS) ?? '0');
      if (now - lastRemindMs < 24 * 3600 * 1000) return;

      AppStorage.setOrCreate(this.STORAGE_KEY_BACKUP_REMINDER_MS, String(now));
      await this.publishBackupReminderNotification();
    } catch (e) { /* ignore */ }
  }

  private async checkPrivacyConsent(): Promise<void> {
    if (this.privacyChecked) {
      return;
    }
    try {
      await this.loadPrivacyPolicy();
      const settingsStore = SettingsStore.getInstance();
      if (!(await settingsStore.getPrivacyConsent())) {
        this.showPrivacyDialog = true;
      }
      this.privacyChecked = true;
    } catch (e) {
      this.showPrivacyDialog = true;
      this.privacyChecked = true;
    }
  }

  private async loadPrivacyPolicy(): Promise<void> {
    if (this.privacyLoaded) return;
    try {
      if (!this.resourceMgr && this.context) this.resourceMgr = this.context.resourceManager;
      if (!this.resourceMgr) return;
      const data = await this.resourceMgr.getRawFileContent('privacy.md');
      const content = Base64Util.utf8Decode(data);
      const lines = content.split(/\r?\n/).filter(l => l.trim().length > 0 && l.trim() !== '---');
      if (lines.length > 0) this.privacyLines = lines;
      this.privacyLoaded = true;
    } catch (e) { this.privacyLoaded = true; }
  }

  private getPrivacyPolicyLines(): string[] {
    if (this.privacyLines.length > 0) return this.privacyLines;
    return ['最后更新日期：2026年2月', '引言', '微语单词尊重并保护所有用户的隐私权...', '同意声明', '使用本应用即表示您同意本隐私政策。'];
  }

  build() {
    Stack() {
      Column() {
        TopNavigation({ onSettingsClick: () => router.pushUrl({ url: 'pages/SettingsPage' }) })

        Scroll() {
          HomeTabContent()
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_SECONDARY)

      if (this.showCelebration) {
        CelebrationParticles({ seed: this.celebrationSeed }).width('100%').height('100%').enabled(false)
      }
      if (this.showPrivacyDialog) {
        PrivacyPolicyDialog({
          privacyLines: this.getPrivacyPolicyLines(),
          onAccept: async () => {
            if (await SettingsStore.getInstance().setPrivacyConsent(true)) {
              this.showPrivacyDialog = false;
              void this.maybeShowOnboarding();
            } else {
              promptAction.showToast({ message: '保存失败', duration: 2000 });
            }
          },
          onReject: async () => {
            await SettingsStore.getInstance().setPrivacyConsent(false);
            promptAction.showToast({ message: '已拒绝，应用将退出', duration: 2000 });
            if (this.context) await this.context.terminateSelf();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .id('index_' + this.themeRefreshToken)
  }
}
