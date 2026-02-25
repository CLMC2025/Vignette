import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AutoWebDavSyncManager } from '../sync/AutoWebDavSyncManager';
import { WordLevelLoader } from '../manager/WordLevelLoader';
import { SessionTransferStore } from '../utils/SessionTransferStore';
import { ReadPersistenceController } from '../pages/ReadPersistenceController';
import { SeenContextStore } from '../utils/SeenContextStore';

const DOMAIN = 0x0000;
const TAG = 'WeiyuApp';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode.Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    const ctx = this.context;
    
    SessionTransferStore.getInstance().injectContext(ctx);
    SessionTransferStore.getInstance().initialize().then(() => {
      hilog.info(DOMAIN, TAG, 'SessionTransferStore initialized successfully');
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to initialize SessionTransferStore: %{public}s', err.message);
    });
    
    ReadPersistenceController.getInstance().injectContext(ctx);
    ReadPersistenceController.getInstance().initialize().then(() => {
      hilog.info(DOMAIN, TAG, 'ReadPersistenceController initialized successfully');
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to initialize ReadPersistenceController: %{public}s', err.message);
    });
    
    SeenContextStore.getInstance('seen_context_ids_v2', 2000).injectContext(ctx);
    SeenContextStore.getInstance('seen_context_ids_v2', 2000).initialize().then(() => {
      hilog.info(DOMAIN, TAG, 'SeenContextStore initialized successfully');
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to initialize SeenContextStore: %{public}s', err.message);
    });
    
    WordLevelLoader.getInstance().setResourceManager(ctx.resourceManager);
    WordLevelLoader.getInstance().initialize().then(() => {
      hilog.info(DOMAIN, TAG, 'WordLevelLoader preloaded successfully');
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to preload WordLevelLoader: %{public}s', err.message);
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content.Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    const ctx = this.context;
    AutoWebDavSyncManager.getInstance().initialize(ctx).then(() => {
      AutoWebDavSyncManager.getInstance().tryRun('foreground');
    }).catch(() => {
      return;
    });
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
