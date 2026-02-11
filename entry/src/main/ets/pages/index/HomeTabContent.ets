import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { HeroSection } from './components/HeroSection';
import { DBManager } from '../../database/DBManager';
import { BuiltInWordBooks, buildWordItemsForBook, loadWordBookWords, WordBookDefinition } from '../../model/WordBookCatalog';
import { WordItem, WordStatus, QueueItem, AppSettings } from '../../model/WordModel';
import { SessionTransferStore } from '../../utils/SessionTransferStore';
import { CurrentBookStore } from '../../utils/CurrentBookStore';
import { BookKind, classifyBookId } from '../../utils/BookIdClassifier';
import { SettingsStore } from '../../utils/SettingsStore';
import { SecureStorage } from '../../utils/SecureStorage';
import { RouterParams } from './IndexTypes';
import { DesignTokens } from '../../model/DesignTokens';

@Component
export struct HomeTabContent {
  @State currentBookName: string = '未选择词书';
  @State currentBookId: string = '';
  @State dailyNewWords: number = 10;
  @State isApiConfigured: boolean = false;

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';
  private readonly STORAGE_KEY_SETTINGS: string = 'app_settings';

  async aboutToAppear() {
    this.context = getContext(this) as common.UIAbilityContext;
    await this.loadSettings();
    await this.loadCurrentBook();
  }

  async onPageShow() {
    await this.loadSettings();
    await this.loadCurrentBook();
  }

  private async loadSettings(): Promise<void> {
    try {
      const settingsStore = SettingsStore.getInstance();
      const persisted = await settingsStore.getSettings();
      let settings: AppSettings;
      
      if (persisted !== null) {
        settings = persisted;
      } else {
        const settingsJson = AppStorage.get<string>(this.STORAGE_KEY_SETTINGS);
        if (settingsJson && settingsJson.length > 0) {
          settings = AppSettings.fromJSON(settingsJson);
        } else {
          settings = new AppSettings();
        }
      }
      
      this.dailyNewWords = settings.dailyNewWords;
      
      const secureStorage = SecureStorage.getInstance();
      const apiKey = await secureStorage.getApiKey();
      this.isApiConfigured = settings.apiBaseUrl.length > 0 && apiKey.length > 0;
    } catch (e) {
      this.isApiConfigured = false;
    }
  }

  private async loadCurrentBook(): Promise<void> {
    let stored = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
    if (stored.length === 0) {
      const fallback = await CurrentBookStore.getInstance().getCurrentBookId();
      if (fallback.trim().length > 0) {
        stored = fallback;
        AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, stored);
      }
    }
    this.currentBookId = stored;
    if (stored.length === 0) {
      this.currentBookName = '未选择词书';
      return;
    }
    const builtIn = BuiltInWordBooks.find((book) => book.id === stored);
    if (builtIn) {
      this.currentBookName = builtIn.name;
      return;
    }
    try {
      const userBooks = await this.dbManager.getUserWordBooks();
      for (const book of userBooks) {
        if (book.id === stored) {
          this.currentBookName = book.name;
          return;
        }
      }
    } catch (e) {
      // ignore
    }
    this.currentBookName = stored;
  }

  private jumpToWordList(): void {
    router.pushUrl({
      url: 'pages/WordBookManagerPage'
    });
  }

  private navigateToSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' });
  }

  private async ensureSystemBookImported(bookId: string): Promise<void> {
    const normalizedBookId = bookId.trim();
    if (normalizedBookId.length === 0) {
      return;
    }
    if (this.context === null) {
      return;
    }
    const def = BuiltInWordBooks.find((b: WordBookDefinition) => b.id === normalizedBookId);
    if (!def) {
      return;
    }
    const rm = this.context.resourceManager;
    const fileWords = await loadWordBookWords(rm, def);
    const fileCount = fileWords.length;
    if (fileCount === 0) {
      return;
    }
    const imported = await this.dbManager.getSystemWordBookWordCount(normalizedBookId);
    if (imported > 0 && imported >= fileCount) {
      return;
    }
    const words = await buildWordItemsForBook(def, rm);
    for (const w of words) {
      await this.dbManager.insertWord(w);
      await this.dbManager.addWordToSystemWordBook(def.id, w.word);
    }
  }

  private async startSession(): Promise<void> {
    if (this.currentBookId.length === 0) {
      promptAction.showDialog({
        title: '未选择词书',
        message: '请先选择或导入词书再开始学习。',
        buttons: [
          { text: '前往词书', color: '#2196F3' },
          { text: '取消', color: '#666666' }
        ]
      }).then((result) => {
        if (result.index === 0) {
          this.jumpToWordList();
        }
      });
      return;
    }
    if (!this.isApiConfigured) {
      promptAction.showDialog({
        title: 'API未配置',
        message: '请在设置中配置API密钥以生成情境故事。',
        buttons: [
          { text: '前往设置', color: '#2196F3' },
          { text: '继续', color: '#666666' }
        ]
      }).then((result) => {
        if (result.index === 0) {
          this.navigateToSettings();
        } else {
          this.doStartSession();
        }
      });
    } else {
      this.doStartSession();
    }
  }

  private async doStartSession(): Promise<void> {
    try {
      const kind = classifyBookId(this.currentBookId);
      if (kind === BookKind.System) {
        await this.ensureSystemBookImported(this.currentBookId);
      }
      const queueWords = kind === BookKind.System
        ? await this.dbManager.getLearningQueueByBook(this.currentBookId, this.dailyNewWords)
        : await this.dbManager.getLearningQueueByUserWordBook(this.currentBookId, this.dailyNewWords);

      if (queueWords.length === 0) {
        promptAction.showDialog({
          title: '没有可学习的单词',
          message: '当前词书没有可学习的单词，请导入或切换词书。',
          buttons: [
            { text: '前往词书', color: '#2196F3' },
            { text: '取消', color: '#666666' }
          ]
        }).then((result) => {
          if (result.index === 0) {
            this.jumpToWordList();
          }
        });
        return;
      }

      const queue: QueueItem[] = queueWords.map((word: WordItem) => {
        const priority = word.status === WordStatus.NEW ? 1 : 0;
        return new QueueItem(word, priority);
      });

      const validQueue = queue.filter((item: QueueItem): boolean => {
        if (!item || !item.word) {
          return false;
        }
        return true;
      });

      if (validQueue.length === 0) {
        promptAction.showToast({ message: '学习队列中存在无效数据', duration: 2000 });
        return;
      }

      const sessionId = SessionTransferStore.getInstance().put(validQueue);
      const params: RouterParams = { sessionId: sessionId };
      router.pushUrl({
        url: 'pages/ReadPage',
        params: params
      });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `无法开始学习会话: ${errMsg}`, duration: 2000 });
    }
  }

  build() {
    Column() {
      HeroSection({
        currentBookName: this.currentBookName,
        onStartSession: () => this.startSession(),
        onManageBooks: () => this.jumpToWordList()
      })
    }
    .width('100%')
    .padding({
      left: DesignTokens.Layout.CONTAINER_PADDING,
      right: DesignTokens.Layout.CONTAINER_PADDING,
      bottom: DesignTokens.Spacing.MD
    })
  }
}
